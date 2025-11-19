#!/bin/bash
#
# SCRIPT 2: CRÉATION D'UN CERTIFICAT SERVEUR
#
# But: Créer une clé, une demande (CSR), et la faire signer par notre CA
#      pour un de nos serveurs (Dolibarr ou GLPI).
#
# Utilisation: bash 2_create_server_cert.sh <nom>
#              (ex: bash 2_create_server_cert.sh dolibarr)
#

# 0. Charger nos variables et vérifier l'argument
source "$(dirname "$0")/../variables.conf"

if [ -z "$1" ]; then
  echo "ERREUR: Vous devez fournir un nom (ex: dolibarr ou glpi)"
  exit 1
fi

# 1. Définir les variables en fonction de l'argument
NOM=$1
DOMAIN=""
if [ "$NOM" == "dolibarr" ]; then
  DOMAIN=$DOMAIN_DOLIBARR
elif [ "$NOM" == "glpi" ]; then
  DOMAIN=$DOMAIN_GLPI
else
  echo "ERREUR: Nom '$NOM' non reconnu (doit être dolibarr ou glpi)."
  exit 1
fi

echo "--- 2. Création du certificat pour $DOMAIN ---"

# Définir les chemins des futurs fichiers
CERT_KEY="$SERVER_DIR/$DOMAIN.key"
CERT_CSR="$SERVER_DIR/$DOMAIN.csr"
CERT_CRT="$SERVER_DIR/$DOMAIN.crt"
SAN_CONFIG_FILE="/tmp/${DOMAIN}_san.cnf"

# 2. (TRÈS IMPORTANT) Créer le fichier de configuration SAN
# C'est cette étape qui évite l'erreur "SSL_BAD_CERT_DOMAIN"
# On dit que le certificat est valide pour le DNS (le nom) ET l'IP.
cat > $SAN_CONFIG_FILE <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = $DOMAIN
EOF

# 3. Générer la clé privée du serveur (SANS mot de passe)
# Apache doit pouvoir lire cette clé au démarrage, sans qu'on tape un mdp.
echo "Génération de la clé privée pour $DOMAIN..."
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out $CERT_KEY

# 4. Générer la demande de signature (CSR)
# [cite_start]On utilise "openssl req" [cite: 30] SANS -x509. On fait une simple DEMANDE.
# On lui passe notre fichier de config SAN
echo "Génération de la demande (CSR) pour $DOMAIN..."
openssl req -new -key $CERT_KEY -out $CERT_CSR \
  -subj "/C=FR/ST=France/O=ESGI/CN=$DOMAIN" \
  -config $SAN_CONFIG_FILE

# 5. Signer la demande avec notre CA (La préfecture signe le formulaire)
# C'est la commande "magique" de ton projet.
# [cite_start]On utilise "openssl x509" [cite: 37] pour manipuler un certificat
# On lui donne la DEMANDE (-in), la CA (-CA), et la CLE de la CA (-CAkey)
echo "Signature du certificat par la CA..."
openssl x509 -req \
  -in $CERT_CSR \
  -CA $CA_DIR/ca.crt \
  -CAkey $CA_DIR/ca.key \
  -CAcreateserial -out $CERT_CRT \
  -days 730 -sha256 \
  -passin pass:$CA_PASS \
  -extfile $SAN_CONFIG_FILE -extensions v3_req # On applique les SAN

# 6. Nettoyage
rm $SAN_CONFIG_FILE
rm $CERT_CSR # On n'a plus besoin de la demande

echo "--- Certificat pour $DOMAIN créé avec succès ($DOMAIN.crt) ---"