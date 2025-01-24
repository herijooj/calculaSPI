; calcula_spi.ncl

; Implementado por Eduardo Machado
; 2015
; Modificado para escrever binário diretamente

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

begin
  dirIn = getenv("DIRIN")
  dirOut = getenv("DIROUT")
  fileIn = getenv("FILEIN")
  prefixo = getenv("PREFIXO")
  nMesesSpi = toint(getenv("N_MESES_SPI"))
  variable_name = getenv("VARIABLE_NAME")

  ; Valida entrada
  if (ismissing(nMesesSpi)) then
    print("Erro: N_MESES_SPI inválido")
    exit
  end if

  ; Abre arquivo de entrada
  f = addfile(dirIn + fileIn, "r")
  prc = flt2dble(f->$variable_name$)  ; Lê dados brutos

  ; Calcula SPI
  spi = dim_spi_n(prc, nMesesSpi, False, 0)
  
  ; Converte para float32 (mesmo tipo do dado original)
  spi_float = tofloat(spi)
  copy_VarMeta(spi, spi_float)  ; Mantém metadados

  ; Escreve binário diretamente
  out_bin = dirOut + prefixo + "_spi" + nMesesSpi + ".bin"
  system("rm -f " + out_bin)  ; Limpa arquivo existente
  fbindirwrite(out_bin, spi_float)  ; Escreve em ordem X/Y/T
end