# Bootloader makefile

C = x86_64-w64-mingw32-gcc
CFLAGS = -ffreestanding -I/usr/include/efi -I/usr/include/efi/x86_64 -I/usr/include/efi/protocol -c

default: bootman

bootman:
	$(C) $(CFLAGS) -o build/main.o src/main.c
	$(C) $(CFLAGS) -o build/data.o src/data.c
	$(C) -nostdlib -Wl,-dll -shared -Wl,--subsystem,10 -e efi_main -o build/BOOTX64.EFI build/main.o build/data.o