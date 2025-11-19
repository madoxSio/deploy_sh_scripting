#!/bin/bash
#
# SCRIPT 4: CONFIGURATION DE LA BASE DE DONNÉES
#
# But: Créer les BDD et les utilisateurs pour Dolibarr et GLPI
#

# 0. Charger mes variables
source "$(dirname "$0")/../variables.conf"

echo "--- 4. Configuration de MariaDB ---"

mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME_DOLIBARR;
CREATE USER IF NOT EXISTS '$DB_USER_DOLIBARR'@'localhost' IDENTIFIED BY '$DB_PASS_DOLIBARR';
GRANT ALL PRIVILEGES ON $DB_NAME_DOLIBARR.* TO '$DB_USER_DOLIBARR'@'localhost';

CREATE DATABASE IF NOT EXISTS $DB_NAME_GLPI;
CREATE USER IF NOT EXISTS '$DB_USER_GLPI'@'localhost' IDENTIFIED BY '$DB_PASS_GLPI';
GRANT ALL PRIVILEGES ON $DB_NAME_GLPI.* TO '$DB_USER_GLPI'@'localhost';

FLUSH PRIVILEGES;
EOF

if [ $? -ne 0 ]; then echo "ERREUR: Échec de la configuration de la BDD."; exit 1; fi

echo "--- Bases de données créées avec succès ---"