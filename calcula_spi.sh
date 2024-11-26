#!/bin/bash

# Implementado por Eduardo Machado
# 2015

# Modificado por Heric Camargo
# 2024

# Cores
RED='\033[1;31m'        # Vermelho brilhante
GREEN='\033[1;32m'      # Verde brilhante
YELLOW='\033[1;93m'     # Amarelo claro
BLUE='\033[1;36m'       # Azul claro ciano
NC='\033[0m'            # Sem cor (reset)

# Função de ajuda
function show_help() {
    echo -e "${YELLOW}Uso:${NC} ${GREEN}./calcula_spi.sh${NC} ${BLUE}[Arq .ctl]${NC} ${BLUE}[Nº de meses]${NC}"
    echo -e "Esse script calcula o SPI a partir de um arquivo .ctl"
    echo -e "O arquivo .ctl deve conter a variável 'cxc'."
    echo -e "O script gera um arquivo .bin e um arquivo .ctl com a variável 'spi'"
    echo -e "Tome cuidado com o nome do arquivo de entrada, o script é sensível a isso."
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
    CTL_IN=$1
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
    pwd > temp
    DIR_IN=$(cat temp)
    rm temp
    cd -

    DIR_OUT="${DIR_IN}/saida_${PREFIXO}"
    CTL_IN=$(basename "${CTL_IN}")

    if [[ ! -e "${DIR_OUT}" ]]; then
        mkdir "${DIR_OUT}"
    fi

    cdo -f nc import_binary "${DIR_IN}/${CTL_IN}" "${DIR_IN}/${PREFIXO}.nc"

    ./src/aux_param.sh "${DIR_IN}/" "${DIR_OUT}/" "${PREFIXO}.nc" "${PREFIXO}" "${N_MESES_SPI}"
    ./bin/converte_txt_bin "${PREFIXO}_${N_MESES_SPI}.txt" "${PREFIXO}_spi${N_MESES_SPI}.bin" "${DIR_OUT}" "${DIR_OUT}" "${NX}" "${NY}" "${NT}"

    ARQ_BIN_IN="$(grep dset "${DIR_IN}/${CTL_IN}" | tr -s " " | cut -d"^" -f2)"
    ARQ_BIN_OUT="${PREFIXO}_spi${N_MESES_SPI}.bin"
    CTL_OUT="${PREFIXO}_spi${N_MESES_SPI}.ctl"

    cp "${DIR_IN}/${CTL_IN}" "${DIR_OUT}/${CTL_OUT}"

    ARQ_BIN_IN_ESCAPED=$(printf '%s' "$(basename "$ARQ_BIN_IN" .bin)" | sed 's/[][\/$*.^|]/\\&/g') # Escapar caracteres especiais, caso o nome do arquivo contenha +_[](){}^$*.?|\
    ARQ_BIN_OUT_ESCAPED=$(printf '%s' "$(basename "$ARQ_BIN_OUT" .bin)" | sed 's/[][\/$*.^|]/\\&/g') # 

    # Substituir apenas na linha que começa com 'dset'
    sed -i "/^dset/s#${ARQ_BIN_IN_ESCAPED}#${ARQ_BIN_OUT_ESCAPED}#g" "${DIR_OUT}/${CTL_OUT}" 

    # Substituir 'cxc' por 'spi' apenas entre 'vars' e 'endvars'
    sed -i "/^vars/,/^endvars/s#cxc#spi#g" "${DIR_OUT}/${CTL_OUT}"

    rm "${DIR_OUT}/${PREFIXO}_${N_MESES_SPI}.txt"
    rm "${DIR_IN}/${PREFIXO}.nc"
fi
