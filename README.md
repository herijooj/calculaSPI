# Calcula SPI

**Implementado por Eduardo Machado**  
**Ano: 2015**

**Alterações por:**
- **Heric Camargo**  
  **Ano: 2024**  
  **Detalhes:**
   - substituição do script em chsh por script em bash
   - alteração para ler arquivos com caracteres especiais
   - makefile
   - caminhos relativos
   - saidas de erro

Este conjunto de programas calcula o **Standardized Precipitation Index (SPI)** a partir de uma série de dados de precipitação mensal, utilizando uma abordagem em etapas que inclui a conversão de formatos de dados e o cálculo do SPI com o uso de **NCL** (NCAR Command Language) e **Fortran**.

## Visão Geral do Processo

O fluxo do programa é o seguinte:

1. **Entrada de Dados**: O programa recebe como entrada um arquivo de controle no formato `.ctl`, que contém dados de precipitação mensal.
2. **Conversão para Formato NetCDF**: O script converte os dados de precipitação para o formato `.nc` usando **CDO** (Climate Data Operators).
3. **Cálculo do SPI**: O cálculo do SPI é feito utilizando o script NCL (`calcula_spi.ncl`), que gera a saída em formato texto.
4. **Conversão de Dados para Binário**: A saída gerada é convertida para o formato binário usando o programa em **Fortran** (`converte_txt_bin.f90`).
5. **Geração de Arquivo de Controle**: Um novo arquivo `.ctl` é gerado, com as variáveis ajustadas para o cálculo do SPI.

## Requisitos

- **NCL** (NCAR Command Language) instalado no sistema.
- **CDO** (Climate Data Operators) para conversão de formatos de dados.
- **Fortran** para compilar o programa `converte_txt_bin.f90`.

## Como Usar

1. **Configuração Inicial**:
   - Abra o arquivo `/geral/programas/alias.txt` e copie todos os aliases.
   - Cole-os no arquivo `.bashrc` localizado na sua pasta pessoal para facilitar a execução dos programas.
   
2. **Execução**:
   No terminal, execute o comando:

   ```bash
   calcula_spi [ARQUIVO_CTL_ENTRADA] [N_MESES_SPI]
   ```

   Substitua:
   - `[ARQUIVO_CTL_ENTRADA]` pelo caminho do arquivo `.ctl` que contém os dados de precipitação.
   - `[N_MESES_SPI]` pelo número de meses a ser usado para o cálculo do SPI (ex: 3 para 3 meses, 12 para 12 meses).

   O script vai realizar as seguintes etapas:
   - **Conversão**: O arquivo `.ctl` será convertido para `.nc`.
   - **Cálculo do SPI**: O cálculo do SPI será realizado com o número de meses especificado.
   - **Conversão para Binário**: A saída será convertida para um arquivo binário.
   - **Arquivo de Controle**: Um novo arquivo `.ctl` será gerado, ajustando a variável `cxc` para `spi`.

3. **Ajuda**:
   Para ver as opções de ajuda, execute:

   ```bash
   calcula_spi -h
   ```

4. **Arquivos Gerados**:
   - **Saída em Binário**: O arquivo binário contendo os resultados do SPI será gerado no diretório de saída.
   - **Arquivo de Controle**: O arquivo `.ctl` ajustado será gerado, com a variável `spi` no lugar de `cxc`.

5. **Diretórios de Entrada e Saída**:
   - O programa cria um diretório de saída chamado `saida_[PREFIXO]` dentro do diretório de entrada para armazenar os arquivos gerados.
   
## Detalhes de Implementação

- O script principal `calcula_spi.sh` é responsável pela execução do fluxo de trabalho, incluindo a verificação dos parâmetros de entrada, conversão de dados, e execução do cálculo do SPI.
- O script em **Csh** (`aux_param.cshrc`) chama o script NCL para o cálculo do SPI.
- O programa em **Fortran** (`converte_txt_bin.f90`) converte a saída de texto para o formato binário esperado.

### Observações

- O nome do arquivo de entrada (`.ctl`) deve ter pelo menos dois caracteres, caso contrário, o programa retornará um erro.
- Certifique-se de que os nomes dos arquivos não contenham caracteres especiais que possam causar problemas ao ser processados pelo script em **Bash**.
- O arquivo `.ctl` de entrada deve conter a variável `cxc`, que é substituída por `spi` durante o processamento.

## Exemplo de Execução

```bash
calcula_spi dados_precipitacao.ctl 12
```

Este comando irá calcular o SPI com base nos dados de precipitação contidos no arquivo `dados_precipitacao.ctl`, usando uma janela de 12 meses.
