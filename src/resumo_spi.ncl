; resumo_spi.ncl
; Script para exibir um resumo dos dados de precipitação
; que serão usados para o cálculo do SPI

load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/calendar_decode2.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

begin
  ; Obtém variáveis de ambiente
  dirin   = getenv("DIRIN")
  filein  = getenv("FILEIN")
  varname = getenv("VARIABLE_NAME")
  
  ; Abre o arquivo
  f = addfile(dirin+filein, "r")
  
  ; Obtém a variável principal e suas dimensões
  data = f->$varname$
  dims = dimsizes(data)
  
  ; Obtém informações de latitudes e longitudes
  if (isfilevar(f, "lat")) then
    lat = f->lat
  else if (isfilevar(f, "latitude")) then
    lat = f->latitude
  else if (isfilevar(f, "LAT")) then
    lat = f->LAT
  else if (isfilevar(f, "LATITUDE")) then
    lat = f->LATITUDE
  else
    lat = ispan(1, dims(1), 1)
  end if
  end if
  end if
  end if
  
  if (isfilevar(f, "lon")) then
    lon = f->lon
  else if (isfilevar(f, "longitude")) then
    lon = f->longitude
  else if (isfilevar(f, "LON")) then
    lon = f->LON
  else if (isfilevar(f, "LONGITUDE")) then
    lon = f->LONGITUDE
  else
    lon = ispan(1, dims(2), 1)
  end if
  end if
  end if
  end if
  
  ; Obtém informações temporais
  if (isfilevar(f, "time")) then
    time = f->time
    timeUnits = time@units
  else if (isfilevar(f, "TIME")) then
    time = f->TIME
    timeUnits = time@units
  else
    time = ispan(0, dims(0)-1, 1)
    timeUnits = "months since 1800-01-01"
  end if
  end if
  
  ; Calcula estatísticas básicas
  dataMin = min(data)
  dataMax = max(data)
  dataMean = avg(data)
  
  ; Exibe informações
  print("Resumo dos dados de entrada:")
  print("  Arquivo: " + dirin + filein)
  print("  Variável: " + varname)
  print("  Dimensões: " + dims(0) + " x " + dims(1) + " x " + dims(2))
  print("  Período temporal: " + dims(0) + " meses")
  print("  Resolução espacial: " + dims(1) + " x " + dims(2))
  print("  Valor mínimo: " + dataMin)
  print("  Valor máximo: " + dataMax)
  print("  Média: " + dataMean)
end