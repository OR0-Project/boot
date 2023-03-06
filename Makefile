C = gcc
ASM = nasm
CPP = g++
LINK = ld
OCP = objcopy

DD = dd
PART = parted
FORMAT = mformat
MKISO = xorriso
EMU = qemu-system-x86_64

ODMP = objdump

SRC = src/
INC = inc/
INT = int/
BIN = bin/
OUT = iso/


C_FLAGS =			-c 											\
					-Wall										\
					-Wno-pointer-sign							\
					-fno-stack-protector						\
					-fpic										\
					-fshort-wchar								\
					-mno-red-zone								\
					-fno-merge-constants						\
					-fno-strict-aliasing						\
					-maccumulate-outgoing-args					\
					-ffreestanding								\
					-I dep/gnu-efi/inc							\
					-DEFI_APP									\
					-DBOOT_LOADER								\
					-DCONFIG_x86_64								\
					-DEFI_FUNCTION_WRAPPER
C_RELEASE_FLAGS =	-O2
C_DEBUG_FLAGS =		-O0											\
					-ggdb3										\
					-DDEBUG										\
					-DEFI_DEBUG=1								\
					-g
LINK_FLAGS =		-nostdlib									\
					-znocombreloc								\
					-shared										\
					-Bsymbolic									\
					-L dep/gnu-efi/x86_64/lib					\
					-L dep/gnu-efi/x86_64/gnuefi				\
					-T dep/gnu-efi/gnuefi/elf_x86_64_efi.lds	\
					dep/gnu-efi/x86_64/gnuefi/crt0-efi-x86_64.o	\
					-lefi										\
					-lgnuefi
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
OCP_DEBUG_FLAGS =	-j .debug_info								\
					-j .debug_abbrev							\
					-j .debug_loc								\
					-j .debug_aranges							\
					-j .debug_line								\
					-j .debug_macinfo							\
					-j .debug_str								\
					-j .debug_line_str

DD_FLAGS =			bs=512
PART_FLAGS =		-s											\
					-a minimal
FORMAT_FLAGS =		-h 32										\
					-t 32										\
					-n 64										\
					-c 1
EMU_FLAGS =			-drive if=pflash,format=raw,unit=0,file=dep/ovmf/OVMF_CODE.fd,readonly=on					\
					-drive if=pflash,format=raw,unit=1,file=dep/ovmf/OVMF_VARS.fd								\
					-cpu host																					\
					-net none																					\
					-enable-kvm																					\
					-serial /dev/stdout																			\
					-monitor stdio																				\
					-m 1G
#					-nodefaults
#					-nographic

ODMP_FLAGS =		-xDSClge									\
					--all-headers


default: build
clean:
	rm $(BIN)* -f
	rm $(OUT)* -f


build:
	$(C) $(C_FLAGS) $(C_RELEASE_FLAGS) -o $(INT)main.o $(SRC)main.c
	$(LINK) $(LINK_FLAGS) -o $(BIN)main.so $(INT)main.o
	$(OCP) $(OCP_FLAGS) $(BIN)main.so $(BIN)main.efi

debug_build: build	# build normally before debug build to compare spec files
	$(C) $(C_FLAGS) $(C_DEBUG_FLAGS) -o $(INT)main.o $(SRC)main.c
	$(LINK) $(LINK_FLAGS) $(LINK_DEBUG_FLAGS) -o $(BIN)main.so $(INT)main.o
	$(OCP) $(OCP_FLAGS) $(OCP_DEBUG_FLAGS) $(BIN)main.so $(BIN)main_debug.efi
	$(ODMP) $(ODMP_FLAGS) $(BIN)main_debug.efi > $(BIN)main_debug.efi.spec
	$(ODMP) $(ODMP_FLAGS) $(BIN)main.efi > $(BIN)main.efi.spec

iso: clean build
	$(DD) $(DD_FLAGS) if=/dev/zero of=$(BIN)uefi.img count=93750
	$(PART) $(PART_FLAGS) $(BIN)uefi.img mklabel gpt
	$(PART) $(PART_FLAGS) $(BIN)uefi.img mkpart EFI FAT16 2048s 93716s
	$(PART) $(PART_FLAGS) $(BIN)uefi.img toggle 1 boot
	$(DD) $(DD_FLAGS) if=/dev/zero of=$(INT)tmp.img count=91669
	$(FORMAT) $(FORMAT_FLAGS) -i $(INT)tmp.img
	mcopy -i $(INT)tmp.img $(BIN)main.efi ::
	$(DD) $(DD_FLAGS) if=$(INT)tmp.img of=$(BIN)uefi.img seek=2048 conv=notrunc


run: iso
	$(EMU) $(EMU_FLAGS) -drive format=raw,file=$(BIN)uefi.img,if=ide