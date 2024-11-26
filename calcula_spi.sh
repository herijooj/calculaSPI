#!/bin/bash

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
    echo -e "${YELLOW}Uso:${NC} ${GREEN}./calcula_spi.sh${NC} ${BLUE}[Arq .ctl]${NC} ${BLUE}[Nº de meses]${NC}"
    echo -e "Esse script calcula o SPI a partir de um arquivo .ctl"
    echo -e "O arquivo .ctl deve conter a variável 'cxc'."
    echo -e "O script gera um arquivo .bin e um arquivo .ctl com a variável 'spi'"
    echo -e "Tome cuidado com o nome do arquivo de entrada, o script é sensível a isso."
    echo -e "${RED}ATENÇÃO!${NC} Rode na Chagos. na minha máquina local não funciona."
    echo -e "${YELLOW}Opções:${NC}"
    echo -e "  ${GREEN}-h${NC}, ${GREEN}--help${NC}\t\tMostra essa mensagem de ajuda e sai"
    echo -e "${YELLOW}Exemplo:${NC}"
    echo -e "  ${GREEN}./calcula_spi.sh${NC} ${BLUE}./arquivos/precipitacao.ctl${NC} ${BLUE}3${NC}"
}

# Verifica se a opção de ajuda foi chamada
if [[ $1 == "-h" || $1 == "--help" ]]; then
    show_help
    exit 0
fi

if [[ $# != 2 ]]; then
    #echo -e "${RED}ERRO!${NC} Parâmetros errados! Utilize:"
    show_help
    exit 1
else
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf -- "$TEMP_DIR"' EXIT

    CTL_IN=$1
    echo -e "${GREEN}CTL_IN:${NC} ${BLUE}${CTL_IN}${NC}"
    FILE_NAME=$(basename "$CTL_IN" .ctl)
    if [[ ${#FILE_NAME} -lt 2 ]]; then
        echo -e "${RED}ERRO!${NC} O nome do arquivo de entrada deve conter mais de uma letra."
        exit 1
    fi

    # Verifica se a variável 'cxc' existe no arquivo ctl
    if ! grep -q "^cxc" "${CTL_IN}"; then
        echo -e "${RED}ERRO!${NC} O arquivo ctl deve conter a variável 'cxc'."
        exit 1
    fi
    
    N_MESES_SPI=$2
    PREFIXO=$(basename "${CTL_IN}" .ctl)
    NX=$(grep xdef "${CTL_IN}" | tr "\t" " " | tr -s " " | cut -d" " -f2)
    NY=$(grep ydef "${CTL_IN}" | tr "\t" " " | tr -s " " | cut -d" " -f2)
    NT=$(grep tdef "${CTL_IN}" | tr "\t" " " | tr -s " " | cut -d" " -f2)

    cd "$(dirname "${CTL_IN}")"
    pwd > "${TEMP_DIR}/temp"
    DIR_IN=$(cat "${TEMP_DIR}/temp")
    cd -

    DIR_OUT="${DIR_IN}/saida_${PREFIXO}"
    CTL_IN=$(basename "${CTL_IN}")
    if [[ ! -e "${DIR_OUT}" ]]; then
        mkdir "${DIR_OUT}"
    fi

    # Copy input file to temp directory for processing
    cp "${DIR_IN}/${PREFIXO}.bin" "${TEMP_DIR}/"
    cp "${DIR_IN}/${CTL_IN}" "${TEMP_DIR}/"
    
    # Convert to NetCDF in temp directory
    cdo -f nc import_binary "${TEMP_DIR}/${CTL_IN}" "${TEMP_DIR}/${PREFIXO}.nc"

    # Define environment variables to point to temp directory
    export DIRIN="${TEMP_DIR}/"
    export DIROUT="${TEMP_DIR}/"
    export FILEIN="${PREFIXO}.nc"
    export PREFIXO="${PREFIXO}"
    export N_MESES_SPI="${N_MESES_SPI}"

    # Executando o script NCL para calcular o SPI
    echo -e "${GREEN}Calculando o SPI...${NC}"
    ncl ./src/calcula_spi.ncl

    # Move result to final destination
    mv "${TEMP_DIR}/${PREFIXO}_${N_MESES_SPI}.txt" "${DIR_OUT}/"

    if [[ ! -e "${DIR_OUT}/${PREFIXO}_${N_MESES_SPI}.txt" ]]; then
        echo -e "${RED}ERRO!${NC} O arquivo de saída não foi gerado."
        exit 1
    fi

    # Chamar o script Python para converter o arquivo
    echo -e "${GREEN}Convertendo o arquivo para bin...${NC}"
    python3 ./src/converte_txt_bin.py "${DIR_OUT}/${PREFIXO}_${N_MESES_SPI}.txt" "${DIR_OUT}/${PREFIXO}_spi${N_MESES_SPI}.bin" "${NX}" "${NY}" "${NT}"

    echo -e "${GREEN}Escrevendo arquivo CTL...${NC}"
    ARQ_BIN_IN="$(grep dset "${DIR_IN}/${CTL_IN}" | tr -s " " | cut -d"^" -f2)"
    ARQ_BIN_OUT="${PREFIXO}_spi${N_MESES_SPI}.bin"
    CTL_OUT="${PREFIXO}_spi${N_MESES_SPI}.ctl"

    cp "${DIR_IN}/${CTL_IN}" "${DIR_OUT}/${CTL_OUT}"

    ARQ_BIN_IN_ESCAPED=$(printf '%s' "$(basename "$ARQ_BIN_IN" .bin)" | sed 's/[][\/$*.^|]/\\&/g')
    ARQ_BIN_OUT_ESCAPED=$(printf '%s' "$(basename "$ARQ_BIN_OUT" .bin)" | sed 's/[][\/$*.^|]/\\&/g')

    # Substituir apenas na linha que começa com 'dset'
    sed -i "/^dset/s#${ARQ_BIN_IN_ESCAPED}#${ARQ_BIN_OUT_ESCAPED}#g" "${DIR_OUT}/${CTL_OUT}"

    # Substituir 'cxc' por 'spi' apenas entre 'vars' e 'endvars'
    sed -i "/^vars/,/^endvars/s#cxc#spi#g" "${DIR_OUT}/${CTL_OUT}"

    echo -e "${GREEN}Limpando arquivos temporários...${NC}"
    rm "${DIR_OUT}/${PREFIXO}_${N_MESES_SPI}.txt"
    # No need to remove TEMP_DIR explicitly, trap will handle it
fi
