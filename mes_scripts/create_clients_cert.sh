#!/bin/bash
#
# SCRIPT 3: CRÉATION D'UN CERTIFICAT CLIENT
#
# But: Créer un certificat pour un utilisateur (ex: un admin)
#      pour l'authentification mutuelle (mTLS).
#

# 0. Charger nos variables
source "$(dirname "$0")/../variables.conf"

echo "--- 3. Création du certificat client pour $CLIENT_CERT_NAME ---"

# 1. Générer la clé privée du client
echo "Génération de la clé privée client..."
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out $CLIENT_DIR/$CLIENT_CERT_NAME.key

# 2. Générer la demande (CSR) pour le client
echo "Génération de la demande (CSR) client..."
openssl req -new -key $CLIENT_DIR/$CLIENT_CERT_NAME.key \
  -out $CLIENT_DIR/$CLIENT_CERT_NAME.csr \
  -subj "/C=FR/O=ESGI/CN=$CLIENT_CERT_NAME"

# 3. Signer la demande du client avec notre CA
echo "Signature du certificat client par la CA..."
openssl x509 -req \
  -in $CLIENT_DIR/$CLIENT_CERT_NAME.csr \
  -CA $CA_DIR/ca.crt \
  -CAkey $CA_DIR/ca.key \
  -CAcreateserial \
  -passin pass:$CA_PASS \
  -out $CLIENT_DIR/$CLIENT_CERT_NAME.crt \
  -days 365

# 4. Créer le package .p12 (le fichier à importer dans le navigateur)
# Ce fichier contient : la clé privée du client + le certificat du client + le certificat de la CA
echo "Création du package P12..."
openssl pkcs12 -export \
  -out $CLIENT_DIR/$CLIENT_CERT_NAME.p12 \
  -inkey $CLIENT_DIR/$CLIENT_CERT_NAME.key \
  -in $CLIENT_DIR/$CLIENT_CERT_NAME.crt \
  -certfile $CA_DIR/ca.crt \
  -passout pass:$CLIENT_CERT_PASS # Protégé par le mot de passe client

# 5. Nettoyage
rm $CLIENT_DIR/$CLIENT_CERT_NAME.csr

echo "--- Certificat client $CLIENT_CERT_NAME.p12 créé avec succès ---"