#!/bin/bash

# Definição de cores
RED=''
GREEN=''
YELLOW=''
BLUE=''
NC=''
BOLD=''

# Configurar cores se estiver em um terminal
set_colors() {
    RED='\033[1;31m'        # Vermelho brilhante
    GREEN='\033[1;32m'      # Verde brilhante
    YELLOW='\033[1;93m'     # Amarelo claro
    BLUE='\033[1;36m'       # Azul claro ciano
    NC='\033[0m'            # Sem cor (reset)
    BOLD='\033[1m'          # Negrito
}

# Funções de log
log_error() {
    echo -e "${RED}ERRO: ${NC}$1" >&2
}

log_warning() {
    echo -e "${YELLOW}AVISO: ${NC}$1" >&2
}

log_info() {
    echo -e "${GREEN}$1${NC}"
}

log_detail() {
    echo -e "${BLUE}$1${NC}"
}

log_header() {
    echo -e "${GREEN}${BOLD}$1${NC}"
}

# Função de ajuda
show_help() {
    echo -e "${YELLOW}Uso:${NC} ${GREEN}./calcula_spi.sh${NC} ${BLUE}[Arq .ctl ou .nc]${NC} ${BLUE}[Nº de meses...]${NC} ${GREEN}[--var VARIABLE]${NC} ${GREEN}[--out PREFIX]${NC} ${GREEN}[-s]${NC}"
    echo -e "   Esse script calcula o SPI a partir de um arquivo .ctl ou .nc"
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
    echo -e "${YELLOW}Exemplo:${NC}"
    echo -e "  ${GREEN}./calcula_spi.sh${NC} ${BLUE}./arquivos/precipitacao.ctl${NC} ${BLUE}3 6 9 12${NC} ${GREEN}--var precip${NC} ${GREEN}--out resultado_${NC} ${GREEN}-s${NC}"
}

# Exporta as funções e variáveis
export RED GREEN YELLOW BLUE NC BOLD
export -f set_colors log_error log_warning log_info log_detail log_header show_help
