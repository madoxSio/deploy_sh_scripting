#!/bin/bash
# =========================================================
# SCRIPT DE DÉPLOIEMENT AUTOMATISÉ - DOLIBARR & GLPI
# =========================================================

# 0. Configuration initiale
# "set -e" : le script s'arrête si une commande échoue. Essentiel.
set -e

# Vérifier qu'on est root (nécessaire pour apt, systemctl...)
if [ "$EUID" -ne 0 ]; then
  echo "ERREUR: Ce script doit être lancé avec sudo (sudo ./deploy.sh)"
  exit 1
fi

# Charger notre panneau de configuration
if ! source variables.conf; then
    echo "ERREUR: Fichier variables.conf introuvable. Avez-vous pensé à le créer ?"
    exit 1
fi

echo ">>> DÉBUT DU DÉPLOIEMENT <<<"

# === ÉTAPE 1: Installation des Paquets ===
echo "--- [1/8] Installation des paquets (Apache, MariaDB, PHP...) ---"
apt update
apt install -y apache2 mariadb-server \
  php php-mysql php-gd php-curl php-ldap php-xmlrpc php-mbstring \
  php-intl php-json php-bz2 php-zip php-apcu php-xml \
  libapache2-mod-php unzip wget \
  gettext-base # Outil pour remplacer les variables dans les configs

# === ÉTAPE 2: Configuration de la Base de Données ===
echo "--- [2/8] Appel du script de configuration MariaDB ---"
bash mes_scripts/setup_database.sh

# === ÉTAPE 3: Création de l'infrastructure de sécurité (PKI) ===
echo "--- [3/8] Appel du script de création de la CA ---"
bash mes_scripts/create_ca.sh

echo "--- [4/8] Appel du script de création des certificats serveur ---"
bash mes_scripts/create_server_cert.sh dolibarr
bash mes_scripts/create_server_cert.sh glpi

echo "--- [5/8] Appel du script de création du certificat client ---"
bash mes_scripts/create_clients_cert.sh

# === ÉTAPE 4: Installation des Applications ===
echo "--- [6/8] Téléchargement et installation de Dolibarr & GLPI ---"
# AJOUTE CE BLOC DE NETTOYAGE (si jamais il existe déjà):
echo "Nettoyage des dossiers d'installation existants..."
sudo rm -rf /var/www/html/dolibarr
sudo rm -rf /var/www/html/glpi

# Dolibarr (ajuste le lien si besoin)
echo "Installation de Dolibarr..."
wget https://github.com/Dolibarr/dolibarr/archive/refs/tags/19.0.2.zip -O /tmp/dolibarr.zip
unzip -q /tmp/dolibarr.zip -d /tmp
mv /tmp/dolibarr-19.0.2 /var/www/html/dolibarr
rm /tmp/dolibarr.zip

# GLPI (ajuste le lien si besoin)
echo "Installation de GLPI..."
wget https://github.com/glpi-project/glpi/releases/download/10.0.15/glpi-10.0.15.tgz -O /tmp/glpi.tgz
tar -xzf /tmp/glpi.tgz -C /var/www/html/
rm /tmp/glpi.tgz

echo "Définition des permissions www-data..."
chown -R www-data:www-data /var/www/html/dolibarr
chown -R www-data:www-data /var/www/html/glpi
# On donne aussi les droits sur les configs SSL, mais en LECTURE SEULE
chmod 755 -R /var/www/html/
chmod 644 $PKI_DIR/ca/ca.crt
chmod 644 $SERVER_DIR/*

# === ÉTAPE 5: Configuration d'Apache ===
echo "--- [7/8] Configuration d'Apache (Auth & Sites SSL) ---"

echo "Création du fichier d'authentification et ajout de l'utilisateur $APACHE_USER..."

# 1. Créer le fichier .htpasswd s'il n'existe pas (garantie de la cible)
touch /etc/apache2/.htpasswd

# 2. Utiliser printf pour injecter le mot de passe sur l'entrée standard (le pipe |)
# L'option -i dit à htpasswd de lire depuis cette entrée.
# On utilise bien les guillemets doubles pour s'assurer que les variables passent sans être cassées.

printf '%s\n' "$APACHE_PASS" | htpasswd -B -i /etc/apache2/.htpasswd "$APACHE_USER"

echo "CHECK: Fin htpasswd"
cp configs/000-default.conf /etc/apache2/sites-available/000-default.conf

# Point 2 du sujet: Mettre en place les certificats
# Astuce: On exporte les variables pour "envsubst"
export DOMAIN_DOLIBARR DOMAIN_GLPI SERVER_DIR CA_DIR
# "envsubst" va lire les templates et remplacer $DOMAIN_DOLIBARR par sa valeur
echo "Création des vhosts SSL..."
envsubst < config/apache_dolibarr.conf > /etc/apache2/sites-available/$DOMAIN_DOLIBARR.conf
envsubst < config/apache_glpi.conf > /etc/apache2/sites-available/$DOMAIN_GLPI.conf

# === ÉTAPE 6: Activation Finale ===
echo "--- [8/8] Activation des modules et redémarrage ---"
a2enmod ssl headers rewrite authn_file
a2ensite $DOMAIN_DOLIBARR.conf
a2ensite $DOMAIN_GLPI.conf

# On désactive le site par défaut en http (000-default)
# On ne garde que la page par défaut en 80 avec l'auth

echo "Redémarrage d'Apache et MariaDB..."
systemctl reload apache2
systemctl restart mariadb

echo " "
echo "========================================================="
echo ">>> DÉPLOIEMENT TERMINÉ AVEC SUCCÈS ! <<<"
echo "========================================================="
echo "Actions manuelles restantes sur VOTRE PC (pas la VM) :"
echo "  1. Récupérez les fichiers suivants (avec 'scp') :"
echo "     - $CA_DIR/ca.crt"
echo "     - $CLIENT_DIR/$CLIENT_CERT_NAME.p12"
echo "  2. Importez 'ca.crt' dans les 'Autorités' de votre navigateur."
echo "  3. Importez '$CLIENT_CERT_NAME.p12' dans 'Vos certificats'."
echo "  4. Ajoutez au fichier 'hosts' de votre PC :"
echo "     $IP_VM $DOMAIN_DOLIBARR $DOMAIN_GLPI"
echo "========================================================="