# cd to build dir
cd build

# create gpt image
dd if=/dev/zero of=fat.img bs=1k count=1440
mformat -i fat.img -f 1440 ::
mmd -i fat.img ::/EFI
mmd -i fat.img ::/EFI/BOOT
mcopy -i fat.img BOOTX64.EFI ::/EFI/BOOT

# create iso
[[ ! -e iso ]] && mkdir iso
cp fat.img iso
xorriso -as mkisofs -R -f -e fat.img -no-emul-boot -o bootman.iso iso

# go back
cd ..