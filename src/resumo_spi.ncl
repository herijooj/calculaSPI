; resumo_spi.ncl

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

begin
  dirIn = getenv("DIRIN")
  fileIn = getenv("FILEIN")
  variable_name = getenv("VARIABLE_NAME")

  ; Abre o arquivo NetCDF
  f = addfile(dirIn + fileIn, "r")

  ; Lê a variável especificada
  prc = flt2dble(f->$variable_name$)

  ; Exibe os resumos
  printVarSummary(prc)
  printMinMax(prc, 0)
end