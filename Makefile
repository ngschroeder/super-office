# Super Office App — SNES ROM Build
# Assembler: WLA-DX (wla-65816 + wlalink)

ROM = super-office-app.smc
OBJ = super-office-app.o
SRC = src/main.s

AS      = wla-65816
ASFLAGS = -I src -I . -o
LINK    = wlalink
LNKFLAGS = -r

.PHONY: all clean

all: $(ROM)

$(OBJ): $(SRC) $(wildcard src/*.asm) $(wildcard gfx/*.asm) $(wildcard spc/*.asm)
	$(AS) $(ASFLAGS) $(OBJ) $(SRC)

$(ROM): $(OBJ) linkfile
	$(LINK) $(LNKFLAGS) linkfile $(ROM)

clean:
	rm -f $(OBJ) $(ROM)
