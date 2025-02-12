#!/bin/bash

# Implementado por Eduardo Machado
# 2015

# Modificado por Heric Camargo
# 2024

# Determina o diretório onde o script está localizado
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carrega as bibliotecas
source "${SCRIPT_DIR}/src/config.sh"
source "${SCRIPT_DIR}/src/logging.sh"
source "${SCRIPT_DIR}/src/parser.sh"

# Testa se está em um terminal para exibir cores
if [ -t 1 ] && ! grep -q -e '--no-color' <<<"$@"
then
    set_colors
fi

# Inicializa a variável de nome de variável padrão
VARIABLE_NAME=""
SILENT_MODE=false

# Inicializa as variáveis
CTL_IN=""
N_MESES_SPI_LIST=()

# Inicializa a variável de workers
MAX_WORKERS=4

# Processa os argumentos
process_arguments "$@"

# Verifica se o arquivo .ctl foi especificado
if [[ -z "$CTL_IN" ]]; then
    echo -e "${RED}ERRO: ${NC}O arquivo .ctl não foi especificado."
    show_help
    exit 1
fi

# Verifica se pelo menos um número de meses foi especificado
if [[ ${#N_MESES_SPI_LIST[@]} -eq 0 ]]; then
    # Use os meses padrão se nenhum for especificado
    N_MESES_SPI_LIST=(1 3 6 9 12 24 48 60)
fi

# Verifica se o arquivo .ctl existe
if [[ ! -f "${CTL_IN}" ]]; then
    echo -e "${RED}ERRO: ${NC}O arquivo ${CTL_IN} não existe."
    exit 1
fi

# Detectar tipo de arquivo
FILE_TYPE=""
if [[ "${CTL_IN}" == *.ctl ]]; then
    FILE_TYPE="CTL"
elif [[ "${CTL_IN}" == *.nc || "${CTL_IN}" == *.NC || "${CTL_IN}" == *.netcdf ]]; then
    FILE_TYPE="NC"
else
    echo -e "${RED}ERRO: ${NC}Tipo de arquivo não suportado. Use .ctl ou .nc"
    exit 1
fi

if [ "$SILENT_MODE" = false ]; then
    echo -e "${GREEN}${BOLD}Configurações do SPI:${NC} ${BLUE}${N_MESES_SPI_LIST[@]}${NC}"
    echo -e "${GREEN}Arquivo de entrada:${NC} ${BLUE}${CTL_IN}${NC}"
fi


# Definir DIR_IN e PREFIXO aqui, após garantir que CTL_IN existe
DIR_IN=$(cd "$(dirname "${CTL_IN}")" && pwd)
CTL_BASENAME=$(basename "${CTL_IN}")
if [ "$FILE_TYPE" = "CTL" ]; then
    PREFIXO=$(basename "${CTL_BASENAME}" .ctl)
else
    PREFIXO=$(basename "${CTL_BASENAME}" .nc)
fi

# se OUT_DIR não foi especificado, use o diretório atual com sufixo '_spi'
if [[ -z "$OUT_DIR" ]]; then
    OUT_DIR="$(pwd)/${PREFIXO}_spi"
fi

# Verifica se o diretório de saída existe; se não, cria
if [[ ! -d "${OUT_DIR}" ]]; then
    mkdir -p "${OUT_DIR}"
fi

# Processar arquivo de acordo com seu tipo
if [ "$FILE_TYPE" = "CTL" ]; then
    parse_ctl_file "${DIR_IN}/${CTL_BASENAME}"
else
    parse_nc_file "${CTL_IN}"
fi

# Verifica se as dimensões foram encontradas
if [[ -z "$NX" || -z "$NY" || -z "$NT" ]]; then
    echo -e "${RED}ERRO: ${NC}Não foi possível obter as dimensões do arquivo ctl."
    exit 1
fi

# Verifica se a variável especificada existe no arquivo ctl
if [[ -z "$VARIABLE_NAME" ]]; then
    if [[ " ${VARIABLES[@]} " =~ " cxc " ]]; then
        VARIABLE_NAME="cxc"
    elif [[ " ${VARIABLES[@]} " =~ " precip " ]]; then
        VARIABLE_NAME="precip"
    elif [[ " ${VARIABLES[@]} " =~ " pr " ]]; then
        VARIABLE_NAME="pr"
    else
        # Se nenhuma variável padrão for encontrada, use a primeira variável encontrada
        VARIABLE_NAME="${VARIABLES[0]}"
        echo -e "${YELLOW}AVISO: ${NC}Nenhuma variável padrão encontrada. Usando a variável '${VARIABLE_NAME}' do arquivo ctl."
    fi
elif [[ ! " ${VARIABLES[@]} " =~ " ${VARIABLE_NAME} " ]]; then
    echo -e "${RED}ERRO: ${NC}O arquivo ctl deve conter a variável '${VARIABLE_NAME}'."
    exit 1
fi

# Determinar o caminho completo do arquivo binário de entrada
ARQ_BIN_IN="${DSET_DIR}/${DSET_FILE}"
if [ "$FILE_TYPE" = "CTL" ]; then
    if [ "$SILENT_MODE" = false ]; then
        echo -e "${GREEN}Arquivo BIN de entrada:${NC} ${BLUE}${ARQ_BIN_IN}${NC}"
    fi
fi

# Verificar se o arquivo binário existe:
if [[ ! -f "${ARQ_BIN_IN}" ]]; then
    echo -e "${RED}ERRO: ${NC}O arquivo binário ${ARQ_BIN_IN} não existe."
    exit 1
fi

# Cria diretório temporário
TEMP_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEMP_DIR"' EXIT

# Converte para NetCDF no diretório temporário
if [ "$SILENT_MODE" = true ]; then
    CDO_OPTS="-s"
    NCL_OPTS="-Q"
else
    CDO_OPTS=""
    NCL_OPTS=""
    echo -e ""
fi

if [ "$FILE_TYPE" = "CTL" ]; then
    if [ "$SILENT_MODE" = false ]; then
        echo -e "${GREEN}${BOLD}Passo 1: Convertendo BIN para NetCDF...${NC}"
    fi
    cdo $CDO_OPTS -P $MAX_WORKERS -f nc import_binary "${DIR_IN}/${CTL_BASENAME}" "${TEMP_DIR}/${PREFIXO}.nc"
else
    if [ "$SILENT_MODE" = false ]; then
        echo -e "${GREEN}${BOLD}Passo 1: Copiando arquivo NetCDF...${NC}"
    fi
    cp "${CTL_IN}" "${TEMP_DIR}/${PREFIXO}.nc"
fi

# Define variáveis de ambiente para apontar para o diretório temporário
export DIRIN="${TEMP_DIR}/"
export DIROUT="${OUT_DIR}/"
export FILEIN="${PREFIXO}.nc"
export PREFIXO="${PREFIXO}"
export VARIABLE_NAME="${VARIABLE_NAME}"

if [ "$SILENT_MODE" = false ]; then
    echo -e "${GREEN}${BOLD}Detalhes do Processamento:${NC}"
    echo -e "${YELLOW}  Versão do CDO:${NC}"
    cdo -V 2>&1 | head -n 1 # CDO version
    echo -e "${YELLOW}  Resumo do arquivo de entrada (NCL):${NC}"
    ncl $NCL_OPTS "${SCRIPT_DIR}/src/resumo_spi.ncl" | tail -n +7 # Detalhes do arquivo de entrada
fi

if [ "$SILENT_MODE" = false ]; then
    echo -e "${GREEN}${BOLD}Passo 2: Calculando os SPI's:${NC} ${BLUE}${N_MESES_SPI_LIST[@]}${NC}${GREEN}${NC}"
elif [ "$SILENT_MODE" = true ]; then
    echo -e "${GREEN}${BOLD}Calculando os SPI's:${NC} ${BLUE}${N_MESES_SPI_LIST[@]}${NC}${GREEN}${NC}"
fi

# Função para processar um único SPI
process_spi() {
    local N_MESES_SPI=$1
    export N_MESES_SPI="${N_MESES_SPI}"

    if [ "$SILENT_MODE" = false ]; then
        echo -e "${GREEN}  Calculando SPI-${N_MESES_SPI}...${NC}"
    fi
    # Executando o script NCL para calcular o SPI
    ncl -Q "${SCRIPT_DIR}/src/calcula_spi.ncl" # silent by default

    if ! file_exists "${DIROUT}/${PREFIXO}_spi${N_MESES_SPI}.bin"; then
        echo -e "${RED}  ERRO: SPI-${N_MESES_SPI} não foi gerado.${NC}"
        return 1
    fi

    # 2. Gera CTL a partir do template original
    CTL_OUT="${OUT_DIR}/${PREFIXO}_spi${N_MESES_SPI}.ctl"
    if [ "$FILE_TYPE" = "CTL" ]; then
        # Usar o CTL original como template
        cp "${CTL_IN}" "${CTL_OUT}"
        sed -i \
            -e "s|^dset .*|dset ^${PREFIXO}_spi${N_MESES_SPI}.bin|" \
            -e "s|^title.*|title SPI${N_MESES_SPI} do ${TITLE}|" \
            -e "/^vars/,/^endvars/s/${VARIABLE_NAME}/spi${N_MESES_SPI}/" \
            -e "/^vars/,/^endvars/s/\(\w\+\)[[:space:]]*=>.*/spi${N_MESES_SPI} 0 99 SPI-${N_MESES_SPI}/" \
            "${CTL_OUT}"
    else
        # Criar um novo CTL para o arquivo binário
        cat > "${CTL_OUT}" << EOF
dset ^${PREFIXO}_spi${N_MESES_SPI}.bin
title SPI${N_MESES_SPI} do ${TITLE}
undef -9999.9
xdef ${NX} linear 1 1
ydef ${NY} linear 1 1
tdef ${NT} linear ${FORMATTED_DATE} ${TIME_STEP}
vars 1
spi${N_MESES_SPI} 0 99 SPI-${N_MESES_SPI}
endvars
EOF
    fi
}

# Modified process_spis function
process_spis() {
    JOB_QUEUE=()  # Reset global queue
    
    for N_MESES_SPI in "${N_MESES_SPI_LIST[@]}"; do
        # Limit concurrent jobs
        while (( ${#JOB_QUEUE[@]} >= MAX_WORKERS )); do
            # Remove finished jobs from queue
            for idx in "${!JOB_QUEUE[@]}"; do
                kill -0 "${JOB_QUEUE[idx]}" 2>/dev/null || unset "JOB_QUEUE[$idx]"
            done
            JOB_QUEUE=("${JOB_QUEUE[@]}")  # Reindex array
            sleep 0.1
        done

        process_spi "$N_MESES_SPI" &
        JOB_QUEUE+=($!)
    done
    
    # Wait for remaining jobs
    wait
}

# Run processing
process_spis

if [ "$SILENT_MODE" = false ]; then
    echo -e "${GREEN}${BOLD}Diretório de Saída:${NC} ${BLUE}${OUT_DIR}${NC}"
    echo -e "${GREEN}${BOLD}Processamento Finalizado com Sucesso!${NC}"
elif [ "$SILENT_MODE" = true ]; then
    echo -e "${GREEN}Processamento concluído! Arquivos SPI gerados em: ${BLUE}${OUT_DIR}${NC}"
fi

