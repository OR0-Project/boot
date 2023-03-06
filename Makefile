# Bootloader makefile
# x86_64-w64-mingw32-gcc

C =					x86_64-w64-mingw32-gcc
LINK =				x86_64-w64-mingw32-ld
OCP =				objcopy

EMU =				qemu-system-x86_64


SRC = src/
INC = inc/
INT = int/
BIN = bin/
OUT = iso/


C_FLAGS =			-I/usr/include/efi							\
					-I/usr/include/efi/x86_64					\
					-I/usr/include/efi/protocol					\
					-ffreestanding								\
					-fno-stack-protector						\
					-fno-merge-constants						\
					-fno-strict-aliasing						\
					-fshort-wchar								\
					-fpic										\
					-mno-red-zone								\
					-Wno-pointer-sign							\
					-Wall										\
					-DEFI_APP									\
					-DBOOT_LOADER								\
					-DCONFIG_x86_64								\
					-DEFI_FUNCTION_WRAPPER						\
					-c
C_RELEASE_FLAGS =	-O2
C_DEBUG_FLAGS =		-O0											\
					-DDEBUG										\
					-DEFI_DEBUG=1								\
					-g
LINK_FLAGS =		-nostdlib									\
					-shared										\
					-Bsymbolic									\
					--subsystem=10
LINK_DEBUG_FLAGS =	-g
OCP_FLAGS =			-j .text									\
					-j .sdata									\
					-j .data									\
					-j .dynamic									\
					-j .dynsym									\
					-j .rel.*									\
					-j .rela.*									\
					-j .reloc									\
					--target=efi-app-x86_64						\
					--subsystem=10

EMU_FLAGS =			-bios /usr/share/edk2-ovmf/x64/OVMF.fd		\
					-enable-kvm									\
					-serial /dev/stdout							\
					-monitor stdio								\
					-net none									\
					-cpu host									\
					-smp 2


default: bootman
clean:
	rm $(INT)* -f
	rm $(BIN)* -f
	rm $(OUT)* -f


bootman:
	$(C) $(C_FLAGS) -o $(INT)main.o $(SRC)main.c
	$(C) $(C_FLAGS) -o $(INT)data.o $(SRC)lib.c
	#$(LINK) $(LINK_FLAGS) -e efi_main -o $(BIN)main.so $(INT)main.o $(INT)data.o
	#$(OCP) $(OCP_FLAGS) $(BIN)main.so $(BIN)main.efi
	$(C) -v -Wl,-v -nostdlib -Wl,-dll -shared -Wl,--subsystem,10 -e efi_main -o bin/BOOTX64.EFI int/main.o int/data.o


iso: clean bootman
	# create gpt image
	dd if=/dev/zero of=$(BIN)boot.img bs=1k count=1440
	mformat -i $(BIN)boot.img -f 1440 ::
	mmd -i $(BIN)boot.img ::/EFI
	mmd -i $(BIN)boot.img ::/EFI/BOOT
	mcopy -i $(BIN)boot.img $(BIN)main.efi ::/EFI/BOOT
	# create iso
	cp $(BIN)boot.img iso
	xorriso -as mkisofs -R -f -e boot.img -no-emul-boot -o iso/boot.iso iso
	rm iso/boot.img


run: iso
	$(EMU) $(EMU_FLAGS) -drive format=raw,file=iso/boot.iso
