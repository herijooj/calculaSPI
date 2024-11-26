import sys
import numpy as np

# Leitura dos argumentos da linha de comando
arq_in = sys.argv[1]
arq_out = sys.argv[2]
nx = int(sys.argv[3])
ny = int(sys.argv[4])
nt = int(sys.argv[5])

# Carrega os dados do arquivo texto
data = np.loadtxt(arq_in, dtype='float32')

# Garante que o tamanho dos dados está correto
if data.size != nx * ny * nt:
    print("Erro: O tamanho dos dados não corresponde às dimensões especificadas.")
    sys.exit(1)

# Salva os dados em formato binário
data.tofile(arq_out)
