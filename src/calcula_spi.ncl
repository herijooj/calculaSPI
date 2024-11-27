; calcula_spi.ncl

; Implementado por Eduardo Machado
; 2015

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

begin
  dirIn = getenv("DIRIN")
  dirOut = getenv("DIROUT")
  fileIn = getenv("FILEIN")
  prefixo = getenv("PREFIXO")
  nMesesSpi = toint(getenv("N_MESES_SPI"))
  variable_name = getenv("VARIABLE_NAME")

  ; Verifica se nMesesSpi é um número válido
  if (ismissing(nMesesSpi)) then
    print("Erro: N_MESES_SPI não é um número válido.")
    exit
  end if

  ; Abre o arquivo NetCDF
  f = addfile(dirIn + fileIn, "r")

  ; Lê a variável especificada
  prc = flt2dble(f->$variable_name$)
  pmsg = prc@_FillValue

  printVarSummary(prc)
  printMinMax(prc, 0)

  dimprc = dimsizes(prc)
  mlon = dimprc(0)
  nlat = dimprc(1)
  ntim = dimprc(2)

  spi = dim_spi_n(prc, nMesesSpi, False, 0)
  asciiwrite(dirOut + prefixo + "_" + nMesesSpi + ".txt", spi)
  spi@long_name = "SPI"
  spi@units = "run=" + nMesesSpi
  copy_VarCoords(prc, spi)
end
; end path: src/calcula_spi.ncl