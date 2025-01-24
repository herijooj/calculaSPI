      
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
    BOLD='\033[1m'           # Negrito
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
    echo -e "  ${GREEN}--var VARIABLE${NC}, ${GREEN}-v VARIABLE${NC}\t(Opcional) Especifica a variável a ser processada (padrão 'cxc' ou 'precip' ou 'pr')"
    echo -e "  ${GREEN}--out DIR${NC}, ${GREEN}-o DIR${NC}\t\t(Opcional) Especifica o diretório de saída (padrão: diretório atual com prefixo 'saida_')"
    echo -e "  ${GREEN}-s${NC}, ${GREEN}--silent${NC}\t\t\t(Recomendado) Modo silencioso - reduz a saída de mensagens"
    echo -e "  ${GREEN}-w${NC}, ${GREEN}--workers NUM${NC}\t\t(Opcional) Número máximo de processos paralelos (padrão: 4)"
    echo -e "${YELLOW}Nota:${NC}"
    echo -e "  Se não especificar os meses, serão usados: 1 3 6 9 12 24 48 60"
    echo -e "${YELLOW}Exemplo:${NC}"
    echo -e "  ${GREEN}./calcula_spi.sh${NC} ${BLUE}./arquivos/precipitacao.ctl${NC} ${BLUE}3 6 9 12${NC} ${GREEN}--var precip${NC} ${GREEN}--out resultado_${NC} ${GREEN}-s${NC}"
}

# Inicializa a variável de nome de variável padrão
VARIABLE_NAME=""
SILENT_MODE=false

# Inicializa as variáveis
CTL_IN=""
N_MESES_SPI_LIST=()

# Inicializa a variável de workers com o número de CPUs
#MAX_WORKERS=$(nproc)
MAX_WORKERS=4 # mais sensato com seus colegas.

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

if [ "$SILENT_MODE" = false ]; then
    echo -e "${GREEN}${BOLD}Configurações do SPI:${NC} ${BLUE}${N_MESES_SPI_LIST[@]}${NC}"
    echo -e "${GREEN}Arquivo CTL de entrada:${NC} ${BLUE}${CTL_IN}${NC}"
fi


# Definir DIR_IN e PREFIXO aqui, após garantir que CTL_IN existe
DIR_IN=$(cd "$(dirname "${CTL_IN}")" && pwd)
CTL_BASENAME=$(basename "${CTL_IN}")
PREFIXO=$(basename "${CTL_BASENAME}" .ctl)

# se OUT_DIR não foi especificado, use o diretório atual com prefixo 'saida_'
if [[ -z "$OUT_DIR" ]]; then
    OUT_DIR="$(pwd)/saida_${PREFIXO}"
fi

# Verifica se o diretório de saída existe; se não, cria
if [[ ! -d "${OUT_DIR}" ]]; then
    mkdir -p "${OUT_DIR}"
fi

# Resource monitoring function
declare -A completed_tasks
monitor_resources() {
    local pid=$1
    local total_jobs=$2
    local start_time=$(date +%s)
    local check_interval=5  # More relaxed interval

    echo ""
    while kill -0 $pid 2>/dev/null; do
        # Somamos CPU e MEM de todos os processos no mesmo SID
        local ps_output=$(ps --no-headers -o %cpu,%mem -g $(ps -o sid= -p "$pid"))
        local raw_values=($ps_output)
        local total_cpu=0
        local total_mem=0
        for ((i=0; i<${#raw_values[@]}; i+=2)); do
            total_cpu=$(awk "BEGIN {print $total_cpu+${raw_values[i]}}")
            total_mem=$(awk "BEGIN {print $total_mem+${raw_values[i+1]}}")
        done

        # Cache do progresso - simpler approach
        completed_jobs=0
        for month in "${N_MESES_SPI_LIST[@]}"; do
            if [[ -f "${TEMP_DIR}/saida_${month}.txt" ]]; then
                ((completed_jobs++))
            fi
        done

        # Calculate progress
        local progress=$((completed_jobs * 100 / total_jobs))
        local elapsed=$(($(date +%s) - start_time))

        # Create progress bar
        local bar_size=30
        local filled=$((progress * bar_size / 100))
        local empty=$((bar_size - filled))
        local bar=""
        for ((i=0; i<filled; i++)); do bar+="█"; done
        for ((i=0; i<empty; i++)); do bar+="░"; done

        # Move cursor up one line and clear it
        echo -en "\033[1A\033[K"
        # Show progress
        echo -ne "${BLUE}Progresso Geral: [${bar}] ${progress}% "
        echo -ne "CPU: ${total_cpu}% MEM: ${total_mem}% "
        echo -ne "Tempo Decorrido: ${elapsed}s${NC}"
        echo # New line to maintain space

        sleep $check_interval
    done
}

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
        # Remove espaços em branco no início e no fim and comments more robustly
        line="$(sed -e 's/#.*$//' <<<"$line")" # Remove comments after #
        line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        # Ignora linhas vazias
        if [[ -z "$line" ]]; then
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
        echo -e "${RED}ERRO: ${NC}O arquivo ctl não contém 'cxc' ou 'precip' ou 'pr'."
        exit 1
    fi
elif [[ ! " ${VARIABLES[@]} " =~ " ${VARIABLE_NAME} " ]]; then
    echo -e "${RED}ERRO: ${NC}O arquivo ctl deve conter a variável '${VARIABLE_NAME}'."
    exit 1
fi

# Determinar o caminho completo do arquivo binário de entrada:
ARQ_BIN_IN="${DSET_DIR}/${DSET_FILE}"
if [ "$SILENT_MODE" = false ]; then
    echo -e "${GREEN}Arquivo BIN de entrada:${NC} ${BLUE}${ARQ_BIN_IN}${NC}"
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
    echo -e "${GREEN}${BOLD}Passo 1: Convertendo BIN para NetCDF...${NC}"
fi


(
    # Divide o arquivo em chunks e processa em paralelo
    cdo $CDO_OPTS -P $MAX_WORKERS -f nc import_binary "${DIR_IN}/${CTL_BASENAME}" "${TEMP_DIR}/${PREFIXO}.nc"
)

# Define variáveis de ambiente para apontar para o diretório temporário
export DIRIN="${TEMP_DIR}/"
export DIROUT="${TEMP_DIR}/"
export FILEIN="${PREFIXO}.nc"
export PREFIXO="${PREFIXO}"
export VARIABLE_NAME="${VARIABLE_NAME}"


if [ "$SILENT_MODE" = false ]; then
    echo -e "${GREEN}${BOLD}Passo 1 Concluído.${NC}\n"
    echo -e "${GREEN}${BOLD}Detalhes do Processamento:${NC}"
    echo -e "${GREEN}  Versão do CDO:${NC}"
    cdo -V 2>&1 | head -n 1 # CDO version
    echo -e "${GREEN}  Resumo do arquivo de entrada (NCL):${NC}"
    ncl $NCL_OPTS "${SCRIPT_DIR}/src/resumo_spi.ncl" # Detalhes do arquivo de entrada
fi

if [ "$SILENT_MODE" = false ]; then
    echo -e "${GREEN}${BOLD}Passo 2: Calculando os SPI's:${NC} ${BLUE}${N_MESES_SPI_LIST[@]}${NC}${GREEN}${NC}"
elif [ "$SILENT_MODE" = true ]; then
    echo -e "${GREEN}${BOLD}Calculando os SPI's:${NC} ${BLUE}${N_MESES_SPI_LIST[@]}${NC}${GREEN}${NC}"
fi


# Função para log seguro
safe_echo() {
    # Move cursor up one line to clear progress bar area
    echo -en "\033[1A\033[K"
    # Print message
    echo -e "$@"
    # Print empty line for progress bar
    echo ""
}

# Function to check if a file exists efficiently
file_exists() {
  [[ -f "$1" ]]
}


# Função para processar um único SPI
process_spi() {
    local N_MESES_SPI=$1
    export N_MESES_SPI="${N_MESES_SPI}"

    if [ "$SILENT_MODE" = false ]; then
        safe_echo "${GREEN}  Calculando SPI-${N_MESES_SPI}...${NC}"
    fi

    # Executando o script NCL para calcular o SPI
    ncl -Q "${SCRIPT_DIR}/src/calcula_spi.ncl" # silent by default

    # Move resultado para o destino final
    mv "${TEMP_DIR}/${PREFIXO}_${N_MESES_SPI}.txt" "${TEMP_DIR}/saida_${N_MESES_SPI}.txt"

    if ! file_exists "${TEMP_DIR}/saida_${N_MESES_SPI}.txt"; then # More efficient file check
        safe_echo "${RED}ERRO: ${NC}O arquivo de saída para o SPI-${N_MESES_SPI} não foi gerado."
        exit 1
    fi

    if [ "$SILENT_MODE" = false ]; then
        safe_echo "${GREEN}  Convertendo .txt para .bin para SPI-${N_MESES_SPI}...${NC}"
    fi
    python3 "${SCRIPT_DIR}/src/converte_txt_bin.py" "${TEMP_DIR}/saida_${N_MESES_SPI}.txt" "${OUT_DIR}/${PREFIXO}_spi${N_MESES_SPI}.bin" "${NX}" "${NY}" "${NT}"

    CTL_OUT="${OUT_DIR%/}/${PREFIXO}_spi${N_MESES_SPI}.ctl"
    if [ "$SILENT_MODE" = false ]; then
        safe_echo "${GREEN}  Copiando e ajustando CTL para SPI-${N_MESES_SPI}...${NC}"
    fi
    cp "${DIR_IN}/${CTL_BASENAME}" "${CTL_OUT}"

    # Ajustar a substituição no arquivo .ctl de saída - simpler sed if possible
    sed -i "/^dset/s#^dset.*#dset \^${PREFIXO}_spi${N_MESES_SPI}.bin#g" "${CTL_OUT}"

    # Substituir a variável especificada por 'spi' entre 'vars' e 'endvars' - simpler sed if possible
    sed -i "/^vars/,/^endvars/{
        s/${VARIABLE_NAME}[[:space:]]*=>[[:space:]]*[^[:space:]]*/spi/
        s/${VARIABLE_NAME}[[:space:]]*/spi/
    }" "${CTL_OUT}"
}

# Função para processar os SPIs
process_spis() {
    local job_queue=()

    # Pré-aloca arrays para resultados
    declare -A job_status

    for N_MESES_SPI in "${N_MESES_SPI_LIST[@]}"; do
        while [ ${#job_queue[@]} -ge $MAX_WORKERS ]; do
            for i in "${!job_queue[@]}"; do
                if ! kill -0 ${job_queue[$i]} 2>/dev/null; then
                    unset job_queue[$i]
                    break
                fi
            done
            job_queue=("${job_queue[@]}")
            [[ ${#job_queue[@]} -ge $MAX_WORKERS ]] && sleep 0.1
        done

        process_spi "$N_MESES_SPI" &
        job_queue+=($!)
    done
    echo -e ""
    # Espera todos os jobs terminarem
    wait
}

# Inicia o processamento com monitoramento
if [ "$SILENT_MODE" = false ]; then
    echo -e "${GREEN}${BOLD}Passo 2: Iniciando o cálculo dos SPIs em paralelo...${NC}"
fi

(
    # Executa o processamento em background
    process_spis &
    MAIN_PID=$!

    # Inicia o monitoramento
    monitor_resources $MAIN_PID ${#N_MESES_SPI_LIST[@]}

    # Espera o processo principal terminar
    wait $MAIN_PID
)

if [ "$SILENT_MODE" = false ]; then
    echo -e "${GREEN}${BOLD}Passo 2 Concluído.${NC}\n"
    echo -e "${GREEN}${BOLD}Diretório de Saída:${NC} ${BLUE}${OUT_DIR}${NC}"
    echo -e "${GREEN}${BOLD}Processamento Finalizado com Sucesso!${NC}"
elif [ "$SILENT_MODE" = true ]; then
    echo -e "${GREEN}Processamento concluído! Arquivos SPI gerados em: ${BLUE}${OUT_DIR}${NC}"
fi

    