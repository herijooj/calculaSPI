#!/bin/bash
# calcula_spi.sh

# Implementado por Eduardo Machado
# 2015

# Modificado por Heric Camargo
# 2024

set_colors() {
    RED='\033[1;31m'        # Vermelho brilhante
    GREEN='\033[1;32m'      # Verde brilhante
    YELLOW='\033[1;93m'     # Amarelo claro
    BLUE='\033[1;36m'       # Azul claro ciano
    NC='\033[0m'            # Sem cor (reset)
}

# testa se está em um terminal para exibir cores
if [ -t 1 ] && ! grep -q -e '--no-color' <<<"$@"
then
    set_colors
fi

# Função de ajuda
function show_help() {
    echo -e "${YELLOW}Uso:${NC} ${GREEN}./calcula_spi.sh${NC} ${BLUE}[Arq .ctl]${NC} ${BLUE}[Nº de meses...]${NC} ${GREEN}[--var VARIABLE]${NC}"
    echo -e "Esse script calcula o SPI a partir de um arquivo .ctl"
    echo -e "O arquivo .ctl deve conter a variável especificada (padrão 'cxc')."
    echo -e "O script gera um arquivo .bin e um arquivo .ctl com a variável 'spi'"
    echo -e "Tome cuidado com o nome do arquivo de entrada, o script é sensível a isso."
    echo -e "${RED}ATENÇÃO!${NC} Rode na Chagos. Na minha máquina local não funciona."
    echo -e "${YELLOW}Opções:${NC}"
    echo -e "  ${GREEN}-h${NC}, ${GREEN}--help${NC}\t\tMostra essa mensagem de ajuda e sai"
    echo -e "  ${GREEN}--var VARIABLE${NC}\t\tEspecifica a variável a ser processada (padrão 'cxc')"
    echo -e "${YELLOW}Exemplo:${NC}"
    echo -e "  ${GREEN}./calcula_spi.sh${NC} ${BLUE}./arquivos/precipitacao.ctl${NC} ${BLUE}3 6 9 12${NC} ${GREEN}--var cxc${NC}"
}

# Inicializa a variável de nome de variável padrão
VARIABLE_NAME="cxc"

# Processa os argumentos da linha de comando
ARGS=()
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --var)
            VARIABLE_NAME="$2"
            shift 2
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Restaura os parâmetros posicionais
set -- "${ARGS[@]}"

# Verifica se o número mínimo de argumentos foi fornecido
if [[ $# -lt 2 ]]; then
    show_help
    exit 1
else
    CTL_IN=$1
    shift
    N_MESES_SPI_LIST=("$@")

    # Verifica se o arquivo .ctl existe
    if [[ ! -f "${CTL_IN}" ]]; then
        echo -e "${RED}ERRO!${NC} O arquivo ${CTL_IN} não existe."
        exit 1
    fi

    echo -e "${GREEN}CTL_IN:${NC} ${BLUE}${CTL_IN}${NC}"
    FILE_NAME=$(basename "$CTL_IN" .ctl)
    # if [[ ${#FILE_NAME} -lt 2 ]]; then
    #     echo -e "${RED}ERRO!${NC} O nome do arquivo de entrada deve conter mais de uma letra."
    #     exit 1
    # fi

    # Função para analisar o arquivo .ctl
    parse_ctl_file() {
        local ctl_file="$1"
        # Inicializa variáveis
        NX=""
        NY=""
        NT=""
        DSET=""
        VARIABLES=()
        IN_VARS_BLOCK=false

        while read -r line; do
            # Remove espaços em branco no início e no fim
            line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            # Ignora linhas vazias ou comentários
            if [[ -z "$line" || "$line" =~ ^# ]]; then
                continue
            fi

            if [[ "$line" =~ ^xdef[[:space:]]+([0-9]+)[[:space:]]+.* ]]; then
                NX=${BASH_REMATCH[1]}
            elif [[ "$line" =~ ^ydef[[:space:]]+([0-9]+)[[:space:]]+.* ]]; then
                NY=${BASH_REMATCH[1]}
            elif [[ "$line" =~ ^tdef[[:space:]]+([0-9]+)[[:space:]]+.* ]]; then
                NT=${BASH_REMATCH[1]}
            elif [[ "$line" =~ ^dset[[:space:]]+\^*(.*) ]]; then
                DSET=${BASH_REMATCH[1]}
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

    parse_ctl_file "${CTL_IN}"

    # Verifica se as dimensões foram encontradas
    if [[ -z "$NX" || -z "$NY" || -z "$NT" ]]; then
        echo -e "${RED}ERRO!${NC} Não foi possível obter as dimensões do arquivo ctl."
        exit 1
    fi

    # Verifica se a variável especificada existe no arquivo ctl
    if [[ ! " ${VARIABLES[@]} " =~ " ${VARIABLE_NAME} " ]]; then
        echo -e "${RED}ERRO!${NC} O arquivo ctl deve conter a variável '${VARIABLE_NAME}'."
        exit 1
    fi

    # Verifica se o arquivo binário existe
    PREFIXO=$(basename "${CTL_IN}" .ctl)
    cd "$(dirname "${CTL_IN}")"
    DIR_IN=$(pwd)
    cd - >/dev/null

    if [[ ! -f "${DIR_IN}/${PREFIXO}.bin" ]]; then
        echo -e "${RED}ERRO!${NC} O arquivo binário ${DIR_IN}/${PREFIXO}.bin não existe."
        exit 1
    fi

    DIR_OUT="${DIR_IN}/saida_${PREFIXO}"
    CTL_IN=$(basename "${CTL_IN}")
    if [[ ! -e "${DIR_OUT}" ]]; then
        mkdir "${DIR_OUT}"
    fi

    # Cria diretório temporário
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf -- "$TEMP_DIR"' EXIT

    # Copia arquivos de entrada para o diretório temporário
    cp "${DIR_IN}/${PREFIXO}.bin" "${TEMP_DIR}/"
    cp "${DIR_IN}/${CTL_IN}" "${TEMP_DIR}/"

    # Converte para NetCDF no diretório temporário
    cdo -f nc import_binary "${TEMP_DIR}/${CTL_IN}" "${TEMP_DIR}/${PREFIXO}.nc"

    # Define variáveis de ambiente para apontar para o diretório temporário
    export DIRIN="${TEMP_DIR}/"
    export DIROUT="${TEMP_DIR}/"
    export FILEIN="${PREFIXO}.nc"
    export PREFIXO="${PREFIXO}"
    export VARIABLE_NAME="${VARIABLE_NAME}"

    # Loop sobre cada valor de N_MESES_SPI
    for N_MESES_SPI in "${N_MESES_SPI_LIST[@]}"; do
        export N_MESES_SPI="${N_MESES_SPI}"

        # Executando o script NCL para calcular o SPI
        echo -e "${GREEN}Calculando o SPI para N_MESES_SPI=${N_MESES_SPI}...${NC}"
        ncl ./src/calcula_spi.ncl

        # Move resultado para o destino final
        mv "${TEMP_DIR}/${PREFIXO}_${N_MESES_SPI}.txt" "${DIR_OUT}/"

        if [[ ! -e "${DIR_OUT}/${PREFIXO}_${N_MESES_SPI}.txt" ]]; then
            echo -e "${RED}ERRO!${NC} O arquivo de saída não foi gerado."
            exit 1
        fi

        # Chamar o script Python para converter o arquivo
        echo -e "${GREEN}Convertendo o arquivo para bin...${NC}"
        python3 ./src/converte_txt_bin.py "${DIR_OUT}/${PREFIXO}_${N_MESES_SPI}.txt" "${DIR_OUT}/${PREFIXO}_spi${N_MESES_SPI}.bin" "${NX}" "${NY}" "${NT}"

        echo -e "${GREEN}Escrevendo arquivo CTL...${NC}"
        ARQ_BIN_IN="${DSET}"
        ARQ_BIN_OUT="${PREFIXO}_spi${N_MESES_SPI}.bin"
        CTL_OUT="${PREFIXO}_spi${N_MESES_SPI}.ctl"

        cp "${DIR_IN}/${CTL_IN}" "${DIR_OUT}/${CTL_OUT}"

        # Escapa caracteres especiais em ARQ_BIN_IN e ARQ_BIN_OUT
        ARQ_BIN_IN_ESCAPED=$(printf '%s' "$(basename "$ARQ_BIN_IN")" | sed 's/[.[\*^$(){}+?|]/\\&/g')
        ARQ_BIN_OUT_ESCAPED=$(printf '%s' "$(basename "$ARQ_BIN_OUT")" | sed 's/[.[\*^$(){}+?|]/\\&/g')

        # Substituir apenas o nome do arquivo após '^' na linha que começa com 'dset'
        sed -i "/^dset/s#\^${ARQ_BIN_IN_ESCAPED}#^${ARQ_BIN_OUT_ESCAPED}#g" "${DIR_OUT}/${CTL_OUT}"

        # Substituir a variável especificada por 'spi' entre 'vars' e 'endvars'
        sed -i "/^vars/,/^endvars/{
            s/^\(${VARIABLE_NAME}\(\s*=>\s*[^[:space:]]*\)\?\)\(\s.*\)/spi\3/
        }" "${DIR_OUT}/${CTL_OUT}"

        echo -e "${GREEN}Limpando arquivos temporários...${NC}"
        rm "${DIR_OUT}/${PREFIXO}_${N_MESES_SPI}.txt"

    done

    # Não é necessário remover TEMP_DIR explicitamente, o trap irá cuidar disso
fi
# end path: calcula_spi.sh