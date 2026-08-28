#!/usr/bin/env bash
#
# Donne a Jenkins (execute dans WSL) l'acces au cluster Minikube heberge par
# Docker Desktop cote Windows.
#
# A relancer apres chaque "minikube start" : Minikube publie l'API sur un port
# localhost tire au hasard, reattribue a chaque demarrage. Le kubeconfig Windows
# est mis a jour automatiquement, ceux de WSL et de l'utilisateur jenkins non.
#
# Usage (en root) :  sudo bash scripts/refresh-kubeconfig.sh [profil]
set -euo pipefail

PROFIL="${1:-projet-ipssi}"
UTILISATEUR_WINDOWS="${WIN_USER:-holal}"

WIN_KUBECONFIG="/mnt/c/Users/$UTILISATEUR_WINDOWS/.kube/config"
WIN_MINIKUBE="/mnt/c/Users/$UTILISATEUR_WINDOWS/.minikube"
JENKINS_HOME="/var/lib/jenkins"

if [ "$(id -u)" -ne 0 ]; then
  echo "A lancer en root : sudo bash $0 $PROFIL" >&2
  exit 1
fi

[ -f "$WIN_KUBECONFIG" ] || { echo "Kubeconfig Windows introuvable : $WIN_KUBECONFIG" >&2; exit 1; }
[ -d "$WIN_MINIKUBE/profiles/$PROFIL" ] || { echo "Profil Minikube introuvable : $PROFIL" >&2; exit 1; }

echo "Profil cible : $PROFIL"

# 1) Kubeconfig pour root : chemins Windows reecrits vers /mnt/c
mkdir -p /root/.kube
sed -e "s|C:\\\\Users\\\\$UTILISATEUR_WINDOWS|/mnt/c/Users/$UTILISATEUR_WINDOWS|g" \
    -e 's|\\|/|g' \
    "$WIN_KUBECONFIG" > /root/.kube/config
chmod 600 /root/.kube/config

# 2) Meme kubeconfig pour les utilisateurs de WSL
for home in /home/*; do
  [ -d "$home" ] || continue
  utilisateur="$(basename "$home")"
  id "$utilisateur" >/dev/null 2>&1 || continue
  mkdir -p "$home/.kube"
  cp /root/.kube/config "$home/.kube/config"
  chown "$utilisateur:$utilisateur" "$home/.kube/config"
  chmod 600 "$home/.kube/config"
done

# 3) Jenkins : les certificats sont copies dans son home, les permissions du
#    montage /mnt/c n'etant pas garanties pour un compte de service.
mkdir -p "$JENKINS_HOME/.kube" "$JENKINS_HOME/.minikube/profiles/$PROFIL"
cp "$WIN_MINIKUBE/ca.crt"                          "$JENKINS_HOME/.minikube/ca.crt"
cp "$WIN_MINIKUBE/profiles/$PROFIL/client.crt"     "$JENKINS_HOME/.minikube/profiles/$PROFIL/client.crt"
cp "$WIN_MINIKUBE/profiles/$PROFIL/client.key"     "$JENKINS_HOME/.minikube/profiles/$PROFIL/client.key"

sed -e "s|/mnt/c/Users/$UTILISATEUR_WINDOWS/.minikube|$JENKINS_HOME/.minikube|g" \
    /root/.kube/config > "$JENKINS_HOME/.kube/config"

chown -R jenkins:jenkins "$JENKINS_HOME/.kube" "$JENKINS_HOME/.minikube"
chmod 600 "$JENKINS_HOME/.kube/config"

echo "Endpoint : $(grep -m1 'server:' /root/.kube/config | tr -d ' ')"
echo
echo "--- acces root ---"
kubectl get nodes
echo
echo "--- acces jenkins ---"
sudo -u jenkins kubectl get nodes
