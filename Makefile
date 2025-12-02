# Makefile para el Juego de la Serpiente (Snake) en NASM x86
# Genera un archivo COM ejecutable para DOS/DOSBox

ASM = nasm
ASMFLAGS = -f bin
SRC = snake.asm
OUT = snake.com

.PHONY: all clean

all: $(OUT)

$(OUT): $(SRC)
	$(ASM) $(ASMFLAGS) $< -o $@

clean:
	rm -f $(OUT)

# Ejecutar en DOSBox (requiere DOSBox instalado)
run: $(OUT)
	dosbox $(OUT)
