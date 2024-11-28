# Calcula SPI

![SPI](src/pics/spi.png)

**Implementado por Eduardo Machado**  
**Ano: 2015**

**Alterações por:**
- **Heric Camargo**  
  **Ano: 2024**  
  **Detalhes:**
   - Substituição do script em Csh por script em Bash
   - Alteração para ler arquivos com caracteres especiais
   - Substituição do script em Fortran por script em Python
   - Caminhos relativos
   - Saídas de erro aprimoradas
   - Permite calcular múltiplos SPIs em uma única execução
   - Melhorias no parsing do arquivo `.ctl`
   - Possibilidade de especificar a variável a ser processada com `--var`
   - Correção de substituições no `sed` para evitar substituições indesejadas
   - Suporte a nomes de arquivos com um único caractere ou caracteres especiais
   - Adicionada opção para definir o prefixo do diretório de saída com `--out`

Este conjunto de programas calcula o **Standardized Precipitation Index (SPI)** a partir de uma série de dados de precipitação mensal, utilizando uma abordagem em etapas que inclui a conversão de formatos de dados e o cálculo do SPI com o uso de **NCL** (NCAR Command Language) e **Python**.

## Visão Geral do Processo

O fluxo do programa é o seguinte:

1. **Entrada de Dados**: O programa recebe como entrada um arquivo de controle no formato `.ctl`, que contém dados de precipitação mensal.
2. **Conversão para Formato NetCDF**: O script converte os dados de precipitação para o formato `.nc` usando **CDO** (Climate Data Operators).
3. **Cálculo do SPI**: O cálculo do SPI é feito utilizando o script NCL (`calcula_spi.ncl`), que gera a saída em formato texto.
4. **Conversão de Dados para Binário**: A saída gerada é convertida para o formato binário usando um script em **Python** (`converte_txt_bin.py`).
5. **Geração de Arquivo de Controle**: Um novo arquivo `.ctl` é gerado, com as variáveis ajustadas para o cálculo do SPI.

## Requisitos

- **NCL** (NCAR Command Language) instalado no sistema.
- **CDO** (Climate Data Operators) para conversão de formatos de dados.
- **Python 3** para executar o script de conversão (`converte_txt_bin.py`).

## Como Usar

1. **Configuração Inicial**:
   - Certifique-se de que todas as dependências (NCL, CDO, Python 3) estão instaladas e configuradas no sistema.

2. **Execução**:
   No terminal, execute o comando:

   ```bash
   ./calcula_spi.sh [ARQUIVO_CTL_ENTRADA] [N_MESES_SPI...] [--var VARIABLE] [--out PREFIXO_DE_SAIDA]
   ```

   > **Atenção**: Este script deve ser executado na **Chagos**. Ele não funciona na minha máquina local.

   Substitua:
   - `[ARQUIVO_CTL_ENTRADA]` pelo caminho do arquivo `.ctl` que contém os dados de precipitação.
   - `[N_MESES_SPI...]` pelos números de meses a serem usados para o cálculo do SPI (ex: 3 6 9 12).
   - `--var VARIABLE` (opcional) para especificar a variável a ser processada (padrão é `cxc`).
   - `--out PREFIXO_DE_SAIDA` (opcional) para especificar o prefixo do diretório de saída (padrão é `saida_`).

   O script vai realizar as seguintes etapas:
   - **Conversão**: O arquivo `.ctl` será convertido para `.nc`.
   - **Cálculo do SPI**: O cálculo do SPI será realizado para cada número de meses especificado.
   - **Conversão para Binário**: A saída será convertida para um arquivo binário.
   - **Arquivo de Controle**: Um novo arquivo `.ctl` será gerado, ajustando a variável especificada para `spi`.

3. **Ajuda**:
   Para ver as opções de ajuda, execute:

   ```bash
   ./calcula_spi.sh --help
   ```

   **Exemplo de saída:**

   ```
   Uso: ./calcula_spi.sh [Arq .ctl] [Nº de meses...] [--var VARIABLE] [--out PREFIX]
      Esse script calcula o SPI a partir de um arquivo .ctl
      O script gera um arquivo .bin e um arquivo .ctl com a variável 'spi'
   ATENÇÃO! Rode na Chagos. Na minha máquina local não funciona.
   Opções:
   -h, --help			Mostra essa mensagem de ajuda e sai
   --var VARIABLE, -v VARIABLE	(Opcional) Especifica a variável a ser processada (padrão 'cxc')
   --out DIR, -o DIR		(Opcional) Especifica o diretório de saída (padrão: diretório atual com prefixo 'saida_')
   Exemplo:
   ./calcula_spi.sh ./arquivos/precipitacao.ctl 3 6 9 12 --var cxc --out resultado_
   ```

4. **Arquivos Gerados**:
   - **Saída**: Os arquivos CTL e Bin contendo os resultados do Calculo SPI serão gerados no diretório de saída especificado. Caso não especificado, no diretório onde foi chamado o script, com o prefixo `saida_`)
   - **Arquivo de Controle**: Arquivos `.ctl` ajustados serão gerados, com a variável `spi` no lugar da variável especificada.

5. **Diretórios de Entrada e Saída**:
   - O programa cria um diretório de saída chamado `[PREFIXO_DE_SAIDA][NOME_ARQUIVO]` dentro do diretório de entrada para armazenar os arquivos gerados.
     - O prefixo de saída padrão é `saida_`, mas pode ser alterado com a opção `--out`.

## Detalhes de Implementação

- O script principal `calcula_spi.sh` é responsável pela execução do fluxo de trabalho, incluindo a verificação dos parâmetros de entrada, conversão de dados, e execução do cálculo do SPI.
- O script em **Python** (`converte_txt_bin.py`) converte a saída de texto para o formato binário esperado.
- O script NCL (`calcula_spi.ncl`) foi ajustado para utilizar a variável especificada e processar os dados conforme necessário.

### Observações

- O script agora permite calcular múltiplos SPIs em uma única execução, especificando vários números de meses após o arquivo `.ctl`.
- É possível especificar a variável a ser processada usando a opção `--var VARIABLE`.
- O script lida corretamente com nomes de arquivos que possuem caracteres especiais ou que têm apenas um caractere.
- As substituições no arquivo `.ctl` são feitas de forma segura, evitando alterações indesejadas em outras partes do arquivo.
- O nome do arquivo de entrada (`.ctl`) não precisa mais ter pelo menos dois caracteres.

## Exemplo de Execução para Vários Meses

```bash
./calcula_spi.sh /dados/entrada/precipitacao.ctl 3 6 9 12 --var precip --out ./resultado_
```

Nesse exemplo:
- O script irá calcular o SPI para os períodos de 3, 6, 9 e 12 meses.
- A variável a ser processada é `precip`.
- Os resultados serão salvos no diretório `resultado_precipitacao` dentro do diretório de entrada.

![SPI](src/pics/terminal.png)

## Melhorias Futuras

1. A leitura agora é feita de forma robusta, evitando problemas com arquivos `.ctl` que contenham palavras-chave ou variáveis com nomes semelhantes ao nome do arquivo. (Corrigido!)
2. O programa permite especificar a variável a ser processada com a opção `--var VARIABLE`, não estando mais limitado à variável `cxc`. (Corrigido!)
3. Necessidade de adicionar aliases no `.bashrc` para funcionar.
4. Dependência do NCL, deveria estar dentro do src.
5. o NCL é EOL desde 2019, deveria ser substituído por outra coisa. (problema do técnico do futuro)