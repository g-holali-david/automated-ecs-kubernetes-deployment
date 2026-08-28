# VPC par defaut : AWS Academy ne laisse pas creer de VPC.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Registre d'images

resource "aws_ecr_repository" "app" {
  name = var.projet

  # Un tag ne peut pas etre reecrit.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Groupes de securite 

# L'ALB est le seul point d'entree public
resource "aws_security_group" "alb" {
  name        = "${var.projet}-alb-sg"
  description = "Entree HTTP publique vers ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP depuis Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Les taches n'acceptent QUE le trafic venant de l'ALB, jamais d'Internet
resource "aws_security_group" "tasks" {
  name        = "${var.projet}-tasks-sg"
  description = "Trafic autorise uniquement depuis ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Depuis ALB uniquement"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Repartiteur de charge

resource "aws_lb" "app" {
  name               = "${var.projet}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = slice(data.aws_subnets.default.ids, 0, 2)
}

resource "aws_lb_target_group" "app" {
  # name_prefix + create_before_destroy : le listener empeche de supprimer
  # l ancien target group, il faut donc creer le nouveau avant.
  name_prefix = "btq-"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip" # impose par le mode reseau awsvpc de Fargate

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Journalisation

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.projet}"
  retention_in_days = 7
}

# Cluster et service

resource "aws_ecs_cluster" "app" {
  name = "${var.projet}-cluster"
}

resource "aws_ecs_cluster_capacity_providers" "app" {
  cluster_name       = aws_ecs_cluster.app.name
  capacity_providers = ["FARGATE"]
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.projet
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory

  # LabRole : AWS Academy interdit la creation de roles IAM
  execution_role_arn = var.lab_role_arn

  container_definitions = jsonencode([
    {
      name      = "web"
      image     = var.image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      # Pas de base sur cette cible : l application tourne en mode degrade.
      environment = [
        { name = "APP_ENV", value = "production" },
        { name = "APP_NOM", value = "Boutique IPSSI" },
        { name = "APP_AUTEURS", value = var.auteurs },
        { name = "APP_CIBLE", value = "ecs" },
        { name = "TP_NAME", value = "PROJET" },
        { name = "TP_TITRE", value = "Orchestration automatisee : ECS et Kubernetes" },
        { name = "TP_OBJECTIF", value = "Deployer la meme application sur deux orchestrateurs et industrialiser leur deploiement via une chaine unique Terraform + Jenkins." },
        { name = "TP_CONCERNE", value = "Cible ECS Fargate : taches derriere un ALB, execution role LabRole, Security Group n'autorisant que l'ALB. Sans base de donnees, l'application tourne en mode degrade." },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "web"
        }
      }
    }
  ])
}

data "aws_region" "current" {}

resource "aws_ecs_service" "app" {
  name            = "${var.projet}-svc"
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = slice(data.aws_subnets.default.ids, 0, 2)
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = true # necessaire pour joindre ECR sans NAT Gateway
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "web"
    container_port   = var.container_port
  }

  # Rollback automatique si le deploiement echoue
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Aucune capacite perdue pendant une mise a jour
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  depends_on = [aws_lb_listener.http]
}
