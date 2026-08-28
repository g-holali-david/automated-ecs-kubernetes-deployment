#!/usr/bin/env bash
# Recopie les identifiants AWS Academy vers le compte jenkins.
# A relancer a chaque nouvelle session AWS Academy, les jetons etant temporaires.
#
# Usage : sudo bash scripts/sync-aws-credentials.sh
set -euo pipefail

UTILISATEUR_WINDOWS="${WIN_USER:-holal}"
SOURCE="/mnt/c/Users/$UTILISATEUR_WINDOWS/.aws"
JENKINS_HOME="/var/lib/jenkins"

if [ "$(id -u)" -ne 0 ]; then
  echo "A lancer en root : sudo bash $0" >&2
  exit 1
fi

[ -f "$SOURCE/credentials" ] || { echo "Identifiants introuvables : $SOURCE/credentials" >&2; exit 1; }

mkdir -p "$JENKINS_HOME/.aws"
cp "$SOURCE/credentials" "$JENKINS_HOME/.aws/credentials"
[ -f "$SOURCE/config" ] && cp "$SOURCE/config" "$JENKINS_HOME/.aws/config"

chown -R jenkins:jenkins "$JENKINS_HOME/.aws"
chmod 700 "$JENKINS_HOME/.aws"
chmod 600 "$JENKINS_HOME/.aws"/*

echo "Identite vue par jenkins :"
sudo -u jenkins aws sts get-caller-identity --output text
