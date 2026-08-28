pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  environment {
    TF_IN_AUTOMATION = "true"
  }

  stages {
    stage("Checkout") {
      steps {
        checkout scm
      }
    }

    stage("Init") {
      steps {
        sh "terraform init -input=false"
      }
    }

    stage("Validate") {
      steps {
        sh "terraform fmt -check -recursive"
        sh "terraform validate"
      }
    }

    stage("Plan") {
      steps {
        // Un seul plan pour les deux modules
        sh "terraform plan -out=tfplan -input=false"
        sh "terraform show -no-color tfplan > tfplan.txt"
      }
    }

    stage("Approve") {
      steps {
        // Pas d apply sans validation manuelle du plan
        input message: "Appliquer ECS + Kubernetes ?", ok: "Appliquer"
      }
    }

    stage("Apply") {
      steps {
        sh "terraform apply -input=false tfplan"
      }
    }

    stage("Verify") {
      parallel {
        stage("ECS") {
          steps {
            sh '''
              echo "Cible ECS : $(terraform output -raw ecs_url)"
              aws ecs describe-services \
                --cluster "$(terraform output -raw ecs_cluster_name)" \
                --services "$(terraform output -raw ecs_service_name)" \
                --query "services[0].[status,desiredCount,runningCount]" \
                --output text
            '''
          }
        }
        stage("Kubernetes") {
          steps {
            sh '''
              NS=$(terraform output -raw k8s_namespace)
              kubectl get deploy,svc,ingress,hpa -n "$NS"
            '''
          }
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: "tfplan, tfplan.txt", allowEmptyArchive: true
    }
    success {
      echo "Deploiement applique sur les deux cibles."
    }
  }
}
