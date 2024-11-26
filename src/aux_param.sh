#!/bin/bash

# Script convertido do original em csh para bash por:
# 2024 - Heric Camargo

# Definindo as variáveis de entrada a partir dos argumentos passados
DIRIN="$1"
DIROUT="$2"
FILEIN="$3"
PREFIXO="$4"
N_MESES_SPI="$5"

# Exportando as variáveis para que o NCL possa acessá-las
export DIRIN
export DIROUT
export FILEIN
export PREFIXO
export N_MESES_SPI

# Executando o script NCL para calcular o SPI
ncl ./src/calcula_spi.ncl