# Bootloader makefile
# x86_64-w64-mingw32-gcc

C = x86_64-w64-mingw32-gcc
C_FLAGS = -ffreestanding -I/usr/include/efi -I/usr/include/efi/x86_64 -I/usr/include/efi/protocol -c

# -initrd ../rootfs.gz
EMUlATOR = qemu-system-x86_64
EMULATOR_FLAGS = -bios /usr/share/edk2-ovmf/x64/OVMF.fd -enable-kvm -serial /dev/stdout -monitor stdio -net none -cpu host -smp 2


default: bootman
clean:
	rm bin/*
	rm iso/*


bootman:
	$(C) $(C_FLAGS) -o int/main.o src/main.c
	$(C) $(C_FLAGS) -o int/data.o src/data.c
	$(C) -nostdlib -Wl,-dll -shared -Wl,--subsystem,10 -e efi_main -o bin/BOOTX64.EFI int/main.o int/data.o


iso: clean bootman
	# create gpt image
	dd if=/dev/zero of=bin/fat.img bs=1k count=1440
	mformat -i bin/fat.img -f 1440 ::
	mmd -i bin/fat.img ::/EFI
	mmd -i bin/fat.img ::/EFI/BOOT
	mcopy -i bin/fat.img bin/BOOTX64.EFI ::/EFI/BOOT
	# create iso
	cp bin/fat.img iso
	xorriso -as mkisofs -R -f -e fat.img -no-emul-boot -o iso/bootman.iso iso
	rm iso/fat.img


run: iso
	$(EMUlATOR) $(EMULATOR_FLAGS) -drive format=raw,file=iso/bootman.iso