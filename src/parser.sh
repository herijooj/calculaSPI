#!/bin/bash

# Função para analisar arquivo NetCDF
parse_nc_file() {
    local nc_file="$1"
    # Inicializa variáveis
    NX=$(ncdump -h "$nc_file" | grep -m1 "^[[:space:]]*\w* = " | awk '{print $3}')
    NY=$(ncdump -h "$nc_file" | grep -m2 "^[[:space:]]*\w* = " | tail -n1 | awk '{print $3}')
    NT=$(ncdump -h "$nc_file" | grep -m3 "^[[:space:]]*\w* = " | tail -n1 | awk '{print $3}')
    VARIABLES=($(ncdump -h "$nc_file" | awk '/float|double/ {print $2}' | sed 's/(.*//'))
    DSET="$nc_file"
    DSET_DIR=$(dirname "$nc_file")
    DSET_FILE=$(basename "$nc_file")

    # Tenta extrair o título do NetCDF
    TITLE=$(ncdump -h "$nc_file" | grep -i "title =" | cut -d'"' -f2 || \
           ncdump -h "$nc_file" | grep -i "title:" | cut -d'"' -f2)
    
    if [[ -z "$TITLE" ]]; then
        TITLE="Dados do arquivo $(basename "$nc_file")"
    fi

    # Extrai informações temporais do arquivo NC
    # Primeiro, tenta encontrar a variável de tempo (geralmente 'time' ou 'TIME')
    TIME_VAR=$(ncdump -h "$nc_file" | grep -i "time:units" | head -1 | cut -d'"' -f2)
    if [[ -z "$TIME_VAR" ]]; then
        # Se não encontrar units direto, procura pela variável tempo
        TIME_VAR=$(ncdump -h "$nc_file" | awk '/\t*time(\t|\s)/ {print $2}' | head -1)
    fi

    # Extrai a data inicial e o incremento temporal
    if [[ -n "$TIME_VAR" ]]; then
        # Usa CDO para obter informações temporais
        TIME_INFO=$(cdo -s showtimestamp "$nc_file" | head -1)
        INITIAL_DATE=$(echo "$TIME_INFO" | awk '{print $1}')
        
        # Converte para o formato "DDmmmYYYY"
        FORMATTED_DATE=$(date -d "$INITIAL_DATE" "+%d%b%Y" | tr '[:upper:]' '[:lower:]')
        
        # Define o incremento temporal (assume mensal por padrão)
        TIME_STEP="1mo"
    else
        # Se não encontrar informações temporais, use os valores padrão
        FORMATTED_DATE="$DEFAULT_START_DATE"
        TIME_STEP="$DEFAULT_TIME_STEP"
        echo -e "${YELLOW}AVISO: ${NC}Não foi possível determinar a data inicial. Usando padrão: ${FORMATTED_DATE}"
    fi

    # if [ "$SILENT_MODE" = false ]; then
        # echo "Detalhes do arquivo NetCDF:"
        # echo "  Título: ${TITLE}"
        # echo "  Dimensões: ${NX}x${NY}x${NT}"
        # echo "  Data Inicial: ${FORMATTED_DATE}"
        # echo "  Incremento: ${TIME_STEP}"
        # echo "  Variáveis: ${VARIABLES[@]}"
    # fi
}

# Função para analisar o arquivo .ctl
parse_ctl_file() {
    local ctl_file="$1"
    # Inicializa variáveis
    NX=""
    NY=""
    NT=""
    DSET=""
    TITLE=""
    VARIABLES=()
    IN_VARS_BLOCK=false

    while read -r line; do
        # Remove espaços em branco no início e no fim and comments more robustly
        line="$(sed -e 's/#.*$//' <<<"$line")" # Remove comments after #
        line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        # Ignora linhas vazias
        if [[ -z "$line" ]]; then
            continue
        fi

        if [[ "$line" =~ ^title[[:space:]]+(.*) ]]; then
            TITLE="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^xdef[[:space:]]+([0-9]+)[[:space:]]+.* ]]; then
            NX=${BASH_REMATCH[1]}
        elif [[ "$line" =~ ^ydef[[:space:]]+([0-9]+)[[:space:]]+.* ]]; then
            NY=${BASH_REMATCH[1]}
        elif [[ "$line" =~ ^tdef[[:space:]]+([0-9]+)[[:space:]]+.* ]]; then
            NT=${BASH_REMATCH[1]}
        elif [[ "$line" =~ ^dset[[:space:]]+(\^*)(.*) ]]; then
            DSET="${line#dset }"
            if [[ "${BASH_REMATCH[1]}" == "^" ]]; then
                DSET_DIR="${DIR_IN}"
                DSET_FILE="${BASH_REMATCH[2]}"
            else
                DSET_PATH="${BASH_REMATCH[2]}"
                DSET_DIR=$(dirname "${DSET_PATH}")
                DSET_FILE=$(basename "${DSET_PATH}")
            fi
        elif [[ "$line" =~ ^vars[[:space:]]+ ]]; then
            IN_VARS_BLOCK=true
        elif [[ "$line" =~ ^endvars ]]; then
            IN_VARS_BLOCK=false
        elif $IN_VARS_BLOCK; then
            # Pega o nome da variável
            var_line=$(echo "$line" | awk '{print $1}')
            var_name=$(echo "$var_line" | sed 's/[=>].*$//')
            VARIABLES+=("$var_name")
        fi
    done < "${ctl_file}"
}

# Exporta as funções e variáveis
export -f parse_nc_file parse_ctl_file