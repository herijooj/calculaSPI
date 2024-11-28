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

# Testa se está em um terminal para exibir cores
if [ -t 1 ] && ! grep -q -e '--no-color' <<<"$@"
then
    set_colors
fi

# Determina o diretório onde o script está localizado
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Função de ajuda
function show_help() {
    echo -e "${YELLOW}Uso:${NC} ${GREEN}./calcula_spi.sh${NC} ${BLUE}[Arq .ctl]${NC} ${BLUE}[Nº de meses...]${NC} ${GREEN}[--var VARIABLE]${NC} ${GREEN}[--out PREFIX]${NC} ${GREEN}[-s]${NC}"
    echo -e "   Esse script calcula o SPI a partir de um arquivo .ctl"
    echo -e "   O script gera um arquivo .bin e um arquivo .ctl com a variável 'spi'"
    echo -e "${RED}ATENÇÃO!${NC} Rode na Chagos. Na minha máquina local não funciona."
    echo -e "${YELLOW}Opções:${NC}"
    echo -e "  ${GREEN}-h${NC}, ${GREEN}--help${NC}\t\t\tMostra essa mensagem de ajuda e sai"
    echo -e "  ${GREEN}--var VARIABLE${NC}, ${GREEN}-v VARIABLE${NC}\t(Opcional) Especifica a variável a ser processada (padrão 'cxc')"
    echo -e "  ${GREEN}--out DIR${NC}, ${GREEN}-o DIR${NC}\t\t(Opcional) Especifica o diretório de saída (padrão: diretório atual com prefixo 'saida_')"
    echo -e "  ${GREEN}-s${NC}, ${GREEN}--silent${NC}\t\t\t(Recomendado) Modo silencioso - reduz a saída de mensagens"
    echo -e "${YELLOW}Exemplo:${NC}"
    echo -e "  ${GREEN}./calcula_spi.sh${NC} ${BLUE}./arquivos/precipitacao.ctl${NC} ${BLUE}3 6 9 12${NC} ${GREEN}--var cxc${NC} ${GREEN}--out resultado_${NC} ${GREEN}-s${NC}"
}

# Inicializa a variável de nome de variável padrão
VARIABLE_NAME="cxc"
SILENT_MODE=false

# Inicializa as variáveis
CTL_IN=""
N_MESES_SPI_LIST=()

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
                echo -e "${RED}ERRO!${NC} A opção '--out' requer um diretório."
                show_help
                exit 1
            fi
            ;;
        -*)
            echo -e "${RED}Opção desconhecida:${NC} $1"
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

# Verifica se o arquivo .ctl foi especificado
if [[ -z "$CTL_IN" ]]; then
    echo -e "${RED}ERRO!${NC} O arquivo .ctl não foi especificado."
    show_help
    exit 1
fi

# Verifica se pelo menos um número de meses foi especificado
if [[ ${#N_MESES_SPI_LIST[@]} -eq 0 ]]; then
    echo -e "${RED}ERRO!${NC} Nenhum número de meses foi especificado."
    show_help
    exit 1
fi

# Verifica se o arquivo .ctl existe
if [[ ! -f "${CTL_IN}" ]]; then
    echo -e "${RED}ERRO!${NC} O arquivo ${CTL_IN} não existe."
    exit 1
fi

echo -e "${GREEN}SPI's: ${NC} ${BLUE}${N_MESES_SPI_LIST[@]}${NC}"
echo -e "${GREEN}CTL_IN:${NC} ${BLUE}${CTL_IN}${NC}"

# Definir DIR_IN e PREFIXO aqui, após garantir que CTL_IN existe
DIR_IN=$(cd "$(dirname "${CTL_IN}")" && pwd)
CTL_BASENAME=$(basename "${CTL_IN}")
PREFIXO=$(basename "${CTL_BASENAME}" .ctl)

# se OUT_DIR não foi especificado, use o diretório atual com prefixo 'saida_'
if [[ -z "$OUT_DIR" ]]; then
    OUT_DIR="${DIR_IN%/}/saida_${PREFIXO}"
fi

# Verifica se o diretório de saída existe; se não, cria
if [[ ! -d "${OUT_DIR}" ]]; then
    mkdir -p "${OUT_DIR}"
fi

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

# Chamar parse_ctl_file com o caminho completo do arquivo .ctl
parse_ctl_file "${DIR_IN}/${CTL_BASENAME}"

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

# Determinar o caminho completo do arquivo binário de entrada:
ARQ_BIN_IN="${DSET_DIR}/${DSET_FILE}"
echo -e "${GREEN}BIN_IN:${NC} ${BLUE}${ARQ_BIN_IN}${NC}"

# Verificar se o arquivo binário existe:
if [[ ! -f "${ARQ_BIN_IN}" ]]; then
    echo -e "${RED}ERRO!${NC} O arquivo binário ${ARQ_BIN_IN} não existe."
    exit 1
fi

# Cria diretório temporário
TEMP_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEMP_DIR"' EXIT

# Converte para NetCDF no diretório temporário
if [ "$SILENT_MODE" = true ]; then
    CDO_OPTS="-s"
    NCL_OPTS="-Q"
fi

echo -e "${GREEN}Convertendo o arquivo binário para NetCDF...${NC}"
cdo $CDO_OPTS -f nc import_binary "${DIR_IN}/${CTL_BASENAME}" "${TEMP_DIR}/${PREFIXO}.nc"

# Define variáveis de ambiente para apontar para o diretório temporário
export DIRIN="${TEMP_DIR}/"
export DIROUT="${TEMP_DIR}/"
export FILEIN="${PREFIXO}.nc"
export PREFIXO="${PREFIXO}"
export VARIABLE_NAME="${VARIABLE_NAME}"


if [ "$SILENT_MODE" = false ]; then
    echo -e "${GREEN}Detalhes:${NC}"
    cdo -V 2>&1 | head -n 1 # CDO version
    ncl $NCL_OPTS "${SCRIPT_DIR}/src/resumo_spi.ncl" # Detalhes do arquivo de entrada
fi


# Loop sobre cada valor de N_MESES_SPI em paralelo
for N_MESES_SPI in "${N_MESES_SPI_LIST[@]}"; do
    (
        export N_MESES_SPI="${N_MESES_SPI}"

        # Executando o script NCL para calcular o SPI
        echo -e "${GREEN}Calculando o SPI ${N_MESES_SPI}...${NC}"
        ncl -Q "${SCRIPT_DIR}/src/calcula_spi.ncl" # silent by default

        # Move resultado para o destino final
        mv "${TEMP_DIR}/${PREFIXO}_${N_MESES_SPI}.txt" "${TEMP_DIR}/saida_${N_MESES_SPI}.txt"

        if [[ ! -e "${TEMP_DIR}/saida_${N_MESES_SPI}.txt" ]]; then
            echo -e "${RED}ERRO!${NC} O arquivo de saída para o SPI ${N_MESES_SPI} não foi gerado."
            exit 1
        fi

        # Chamar o script Python para converter o arquivo
        echo -e "${GREEN}Convertendo o arquivo .txt para .bin para o SPI ${N_MESES_SPI}...${NC}"
        python3 "${SCRIPT_DIR}/src/converte_txt_bin.py" "${TEMP_DIR}/saida_${N_MESES_SPI}.txt" "${OUT_DIR}/${PREFIXO}_spi${N_MESES_SPI}.bin" "${NX}" "${NY}" "${NT}"

        echo -e "${GREEN}Escrevendo arquivo CTL e BIN para O SPI ${N_MESES_SPI}...${NC}"
        CTL_OUT="${OUT_DIR%/}/${PREFIXO}_spi${N_MESES_SPI}.ctl"

        cp "${DIR_IN}/${CTL_BASENAME}" "${CTL_OUT}"
        #echo -e "${GREEN}DIR_OUT para N_MESES_SPI=${N_MESES_SPI}:${NC} ${BLUE}${OUT_DIR}${NC}"
        
        # Ajustar a substituição no arquivo .ctl de saída
        sed -i "/^dset/s#^dset.*#dset \^${PREFIXO}_spi${N_MESES_SPI}.bin#g" "${CTL_OUT}"

        # Substituir a variável especificada por 'spi' entre 'vars' e 'endvars'
        sed -i -E "/^vars/,/^endvars/{
            s/^(${VARIABLE_NAME}([[:space:]]*=>[[:space:]]*[^[:space:]]*)?)([[:space:]].*)/spi\3/
        }" "${CTL_OUT}"
    ) &
done
wait

echo -e "${GREEN}DIR_OUT:${NC} ${BLUE}${OUT_DIR}${NC}"

echo -e "${GREEN}Processamento concluído!${NC}"