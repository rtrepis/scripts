#!/bin/bash

# Incloure el fitxer tag_manager.sh
source ~/publish/tag_manager.sh

# Definir el directori de construcció i la versió per a la prova
BUILD_DIR="/mnt/c/Users/ramon.trepat/projects/bonarea/react/contactes/app-module-contactes"
VERSION="1.3.0"

# Cridar la funció manage_tag per provar la lògica de les etiquetes
manage_tag "$BUILD_DIR" "$VERSION"
