# compile: (flags before -o become CFLAGS in the Makefile)
x86_64-w64-mingw32-gcc -ffreestanding -I/usr/include/efi -I/usr/include/efi/x86_64 -I/usr/include/efi/protocol -c -o build/main.o src/main.c
x86_64-w64-mingw32-gcc -ffreestanding -I/usr/include/efi -I/usr/include/efi/x86_64 -I/usr/include/efi/protocol -c -o build/data.o src/data.c
# link: (flags before -o become LDFLAGS in the Makefile)
x86_64-w64-mingw32-gcc -nostdlib -Wl,-dll -shared -Wl,--subsystem,10 -e efi_main -o build/BOOTX64.EFI build/main.o build/data.o