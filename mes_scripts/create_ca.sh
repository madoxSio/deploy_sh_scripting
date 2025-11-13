#!/bin/bash

echo "---création de l'autorité de certification---" 

 source "$(dirname "$0")/../variables.conf"

mkdir -p $CA_DIR
mkdir -p $SERVER_DIR
mkdir -p $CLIENT_DIR

echo "on génere la clé privée de la CA"

openssl genpkey -algorithm RSA -pkopt rsa_keygen_bits:4096 \
    -aes256 -passout pass:$CA_PASS \
    -out $CA_DIR/ca.key


#[ $? -ne 0 ] → signifie “si le code de retour n’est pas égal à 0”
if [ $? -ne 0 ]; then
    echo "ERREUR: Échec de la génération de la clé CA"
    exit 1
fi

echo "Génération du certificat auto-signé"

openssl req -x509 -new -nodes \
    -key $CA_DIR/ca.key \
    -passin pass:$CA_PASS \
    -sha256 -days 365 \
    -subj "/C=FR/ST=France/L=Paris/O=ESGI/CN=esgi CA" \
    -out $CA_DIR/ca.crt

if [ $? -ne 0 ]; then
    echo "ERREUR: Échec de la génération de la clé CA"
    exit 1
fi