# Nome do compilador Fortran
FC = gfortran

# Opções de compilação
FFLAGS = -O2 -Wall

# Nome do programa
TARGET = converte_txt_bin

# Arquivos fonte
SRC = converte_txt_bin.f90

# Diretório de destino do binário
BINDIR = ../bin

# Regra padrão para compilar o programa
all: $(BINDIR)/$(TARGET)

$(BINDIR)/$(TARGET): $(SRC)
	$(FC) $(FFLAGS) -o $(TARGET) $(SRC)
	mkdir -p $(BINDIR)
	mv $(TARGET) $(BINDIR)

# Regra para limpar os arquivos de compilação
clean:
	rm -f $(BINDIR)/$(TARGET) *.o *.mod

# Regra para recompilar o programa
rebuild: clean all