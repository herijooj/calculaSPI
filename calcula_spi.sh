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
    echo -e "${YELLOW}Uso:${NC} ${GREEN}./calcula_spi.sh${NC} ${BLUE}[Arquivos .ctl ou .nc...]${NC} ${BLUE}[Nº de meses...]${NC} ${GREEN}[--var VARIABLE]${NC} ${GREEN}[--out PREFIX]${NC} ${GREEN}[-s]${NC}"
    echo -e "   Esse script calcula o SPI a partir de um ou mais arquivos .ctl ou .nc"
    echo -e "   O script gera um arquivo .bin e um arquivo .ctl com a variável 'spi'"
    echo -e "${RED}ATENÇÃO!${NC} Rode na Chagos. Na minha máquina local não funciona."
    echo -e "${YELLOW}Opções:${NC}"
    echo -e "  ${GREEN}-h${NC}, ${GREEN}--help${NC}\t\t\tMostra essa mensagem de ajuda e sai"
    echo -e "  ${GREEN}--var VARIABLE${NC}, ${GREEN}-v VARIABLE${NC}\t(Opcional) Especifica a variável a ser processada (padrão 'cxc' ou 'precip' ou 'pr')"
    echo -e "  ${GREEN}--out DIR${NC}, ${GREEN}-o DIR${NC}\t\t(Opcional) Especifica o diretório de saída (padrão: diretório atual com sufixo '_spi')"
    echo -e "  ${GREEN}-s${NC}, ${GREEN}--silent${NC}\t\t\t(Recomendado) Modo silencioso - reduz a saída de mensagens"
    echo -e "  ${GREEN}-w${NC}, ${GREEN}--workers NUM${NC}\t\t(Opcional) Número máximo de processos paralelos (padrão: 4)"
    echo -e "${YELLOW}Nota:${NC}"
    echo -e "  Se não especificar os meses, serão usados: 1 3 6 9 12 24 48 60"
    echo -e "  Múltiplos arquivos serão processados sequencialmente"
    echo -e "${YELLOW}Exemplos:${NC}"
    echo -e "  ${GREEN}./calcula_spi.sh${NC} ${BLUE}./arquivos/precipitacao.ctl${NC} ${BLUE}3 6 9 12${NC} ${GREEN}--var precip${NC} ${GREEN}--out resultado_${NC} ${GREEN}-s${NC}"
    echo -e "  ${GREEN}./calcula_spi.sh${NC} ${BLUE}arquivo1.ctl arquivo2.ctl arquivo3.ctl${NC} ${BLUE}1 3 6 12${NC} ${GREEN}--out saida${NC}"
}

# Inicializa a variável de nome de variável padrão
VARIABLE_NAME=""
SILENT_MODE=false

# Inicializa as variáveis
CTL_FILES=()
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
            # Verifica se é um arquivo .ctl ou .nc
            if [[ "$1" == *.ctl || "$1" == *.nc || "$1" == *.NC || "$1" == *.netcdf ]]; then
                CTL_FILES+=("$1")
            # Se for um número, assume que é um período SPI
            elif [[ "$1" =~ ^[0-9]+$ ]]; then
                N_MESES_SPI_LIST+=("$1")
            else
                echo -e "${RED}ERRO: ${NC}Argumento inválido: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Verifica se pelo menos um arquivo foi especificado
if [[ ${#CTL_FILES[@]} -eq 0 ]]; then
    echo -e "${RED}ERRO: ${NC}Nenhum arquivo .ctl ou .nc especificado."
    show_help
    exit 1
fi

# Verifica se pelo menos um número de meses foi especificado
if [[ ${#N_MESES_SPI_LIST[@]} -eq 0 ]]; then
    # Use os meses padrão se nenhum for especificado
    N_MESES_SPI_LIST=(1 3 6 9 12 24 48 60)
fi

# Função para processar um único SPI para um único arquivo
process_spi() {
    local N_MESES_SPI=$1
    export N_MESES_SPI="${N_MESES_SPI}"

    if [ "$SILENT_MODE" = false ]; then
        echo -e "${GREEN}  Calculando SPI-${N_MESES_SPI}...${NC}"
    fi
    # Executando o script NCL para calcular o SPI
    ncl -Q "${SCRIPT_DIR}/src/calcula_spi.ncl" # silent by default

    if ! [[ -f "${DIROUT}/${PREFIXO}_spi${N_MESES_SPI}.bin" ]]; then
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

# Modified process_spis function for one file
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
        # Valores padrão se não conseguir encontrar
        FORMATTED_DATE="01jan1900"
        TIME_STEP="1mo"
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

# Função principal para processar um arquivo
process_file() {
    local CTL_IN="$1"
    
    # Verifica se o arquivo existe
    if [[ ! -f "${CTL_IN}" ]]; then
        echo -e "${RED}ERRO: ${NC}O arquivo ${CTL_IN} não existe."
        return 1
    fi
    
    # Detectar tipo de arquivo
    FILE_TYPE=""
    if [[ "${CTL_IN}" == *.ctl ]]; then
        FILE_TYPE="CTL"
    elif [[ "${CTL_IN}" == *.nc || "${CTL_IN}" == *.NC || "${CTL_IN}" == *.netcdf ]]; then
        FILE_TYPE="NC"
    else
        echo -e "${RED}ERRO: ${NC}Tipo de arquivo não suportado. Use .ctl ou .nc"
        return 1
    fi

    if [ "$SILENT_MODE" = false ]; then
        echo -e "\n${GREEN}${BOLD}Processando arquivo:${NC} ${BLUE}${CTL_IN}${NC}"
        echo -e "${GREEN}${BOLD}Configurações do SPI:${NC} ${BLUE}${N_MESES_SPI_LIST[@]}${NC}"
    else
        echo -e "${GREEN}Processando:${NC} ${BLUE}${CTL_IN}${NC} -> SPIs: ${BLUE}${N_MESES_SPI_LIST[@]}${NC}"
    fi
    
    # Definir DIR_IN e PREFIXO 
    DIR_IN=$(cd "$(dirname "${CTL_IN}")" && pwd)
    CTL_BASENAME=$(basename "${CTL_IN}")
    if [ "$FILE_TYPE" = "CTL" ]; then
        PREFIXO=$(basename "${CTL_BASENAME}" .ctl)
    else
        PREFIXO=$(basename "${CTL_BASENAME}" .nc)
    fi
    
    # se OUT_DIR não foi especificado, usar o diretório atual com sufixo '_spi'
    if [[ -z "$OUT_DIR_BASE" ]]; then
        OUT_DIR="$(pwd)/${PREFIXO}_spi"
    else
        # Se processando múltiplos arquivos, criar subdiretórios para cada um
        if [[ ${#CTL_FILES[@]} -gt 1 ]]; then
            OUT_DIR="${OUT_DIR_BASE}/${PREFIXO}"
        else
            OUT_DIR="${OUT_DIR_BASE}"
        fi
    fi

    # Verificar se o diretório de saída existe; se não, criar
    if [[ ! -d "${OUT_DIR}" ]]; then
        mkdir -p "${OUT_DIR}"
    fi
    
    # Processar arquivo de acordo com seu tipo
    if [ "$FILE_TYPE" = "CTL" ]; then
        parse_ctl_file "${DIR_IN}/${CTL_BASENAME}"
    else
        parse_nc_file "${CTL_IN}"
    fi
    
    # Verificar se as dimensões foram encontradas
    if [[ -z "$NX" || -z "$NY" || -z "$NT" ]]; then
        echo -e "${RED}ERRO: ${NC}Não foi possível obter as dimensões do arquivo."
        return 1
    fi
    
    # Verificar se a variável especificada existe no arquivo
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
            echo -e "${YELLOW}AVISO: ${NC}Nenhuma variável padrão encontrada. Usando a variável '${VARIABLE_NAME}' do arquivo."
        fi
    elif [[ ! " ${VARIABLES[@]} " =~ " ${VARIABLE_NAME} " ]]; then
        echo -e "${RED}ERRO: ${NC}O arquivo deve conter a variável '${VARIABLE_NAME}'."
        return 1
    fi
    
    # Determinar o caminho completo do arquivo binário de entrada
    ARQ_BIN_IN="${DSET_DIR}/${DSET_FILE}"
    if [ "$FILE_TYPE" = "CTL" ] && [ "$SILENT_MODE" = false ]; then
        echo -e "${GREEN}Arquivo BIN de entrada:${NC} ${BLUE}${ARQ_BIN_IN}${NC}"
    fi
    
    # Verificar se o arquivo binário existe:
    if [[ ! -f "${ARQ_BIN_IN}" ]]; then
        echo -e "${RED}ERRO: ${NC}O arquivo binário ${ARQ_BIN_IN} não existe."
        return 1
    fi
    
    # Criar diretório temporário
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf -- "$TEMP_DIR"' EXIT
    
    # Converter para NetCDF no diretório temporário
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
    
    # Definir variáveis de ambiente para apontar para o diretório temporário
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
        ncl $NCL_OPTS "${SCRIPT_DIR}/src/resumo_spi.ncl" | sed -n '3p;7,$p' # Detalhes do arquivo de entrada
    fi
    
    if [ "$SILENT_MODE" = false ]; then
        echo -e "${GREEN}${BOLD}Passo 2: Calculando os SPI's:${NC} ${BLUE}${N_MESES_SPI_LIST[@]}${NC}${GREEN}${NC}"
    fi
    
    # Processar os SPIs
    process_spis
    
    # Limpar diretório temporário
    rm -rf "$TEMP_DIR"
    
    if [ "$SILENT_MODE" = false ]; then
        echo -e "${GREEN}Arquivo processado com sucesso:${NC} ${BLUE}${CTL_IN}${NC}"
    fi
    
    return 0
}

# Salvar diretório de saída original
OUT_DIR_BASE="${OUT_DIR}"

# Processar cada arquivo sequencialmente
for CTL_IN in "${CTL_FILES[@]}"; do
    process_file "$CTL_IN"
done

if [ "$SILENT_MODE" = false ]; then
    echo -e "\n${GREEN}${BOLD}Diretório de Saída:${NC} ${BLUE}${OUT_DIR_BASE:-"diretórios individuais"}${NC}"
    echo -e "${GREEN}${BOLD}Processamento Finalizado com Sucesso!${NC}"
elif [ "$SILENT_MODE" = true ]; then
    echo -e "${GREEN}Processamento concluído! Arquivos SPI gerados em: ${BLUE}${OUT_DIR_BASE:-"diretórios individuais"}${NC}"
fi

