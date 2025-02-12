#!/bin/bash

# Diretório base do script
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Variáveis padrão
readonly DEFAULT_VARIABLE_NAMES=("cxc" "precip" "pr")
readonly DEFAULT_SPI_MONTHS=(1 3 6 9 12 24 48 60)
readonly DEFAULT_MAX_WORKERS=4
readonly DEFAULT_UNDEF_VALUE="-7777.7"

# Configurações de arquivos
readonly SUPPORTED_EXTENSIONS=(".ctl" ".CTL" ".nc" ".NC" ".netcdf")
readonly DEFAULT_TIME_STEP="1mo"        # É usada apenas se não for possível determinar o incremento temporal
readonly DEFAULT_START_DATE="01jan1900" # É usada apenas se não for possível determinar a data inicial

# Opções CDO e NCL
readonly CDO_SILENT_OPTS="-s"
readonly NCL_SILENT_OPTS="-Q"
readonly CDO_NORMAL_OPTS=""
readonly NCL_NORMAL_OPTS=""

# Diretórios do projeto
readonly NCL_SCRIPTS_DIR="${SCRIPT_DIR}/src"
readonly TEMP_DIR_PREFIX="calculaspi_"

# Function to check if a file exists efficiently
file_exists () {
  [[ -f "$1" ]]
}

process_arguments () {
    # Processa os argumentos
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--silent)
                SILENT_MODE=true
                shift
                ;;
            --var|-v)
                VARIABLE_NAME="$2"
                shift 2
                ;;
            --out|-o)
                if [[ -n "$2" && "$2" != -* ]]; then
                    OUT_DIR="$2"
                    shift 2
                else
                    echo -e "${RED}ERRO: ${NC}A opção '--out' requer um diretório."
                    show_help
                    exit 1
                fi
                ;;
            -w|--workers)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    MAX_WORKERS="$2"
                    shift 2
                else
                    echo -e "${RED}ERRO: ${NC}A opção '--workers' requer um número."
                    show_help
                    exit 1
                fi
                ;;
            -*)
                echo -e "${RED}ERRO: ${NC}Opção desconhecida: $1"
                exit 1
                ;;
            *)
                if [[ -z "$CTL_IN" ]]; then
                    CTL_IN="$1"
                else
                    N_MESES_SPI_LIST+=("$1")
                fi
                shift
                ;;
        esac
    done
}

# Exporta todas as constantes
export SCRIPT_DIR
export DEFAULT_VARIABLE_NAMES DEFAULT_SPI_MONTHS DEFAULT_MAX_WORKERS DEFAULT_UNDEF_VALUE
export SUPPORTED_EXTENSIONS DEFAULT_TIME_STEP DEFAULT_START_DATE
export CDO_SILENT_OPTS NCL_SILENT_OPTS CDO_NORMAL_OPTS NCL_NORMAL_OPTS
export NCL_SCRIPTS_DIR TEMP_DIR_PREFIX
