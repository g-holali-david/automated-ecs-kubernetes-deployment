# Etat partage entre le poste de travail et Jenkins.
# Le bucket est versionne et chiffre, et l'etat n'est jamais versionne dans Git.
terraform {
  backend "s3" {
    bucket  = "tfstate-ipssi-674501463174"
    key     = "projet-final/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
