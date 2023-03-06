default:
	git clone https://git.code.sf.net/p/gnu-efi/code gnu-efi
	cd gnu-efi && make
	mkdir ovmf

	#cd edk2 && git clone https://github.com/tianocore/edk2.git -b"stable/202011" edk2
	#cd edk2 && git clone https://github.com/tianocore/edk2-platforms.git edk2-platforms
	#cd edk2 && git clone https://github.com/tianocore/edk2-non-osi.git edk2-non-osi
	#cd edk2/edk2 && git submodule update --init
	#cd edk2/edk2-platforms && git submodule update --init

	cp /usr/share/edk2-ovmf/x64/OVMF_CODE.fd ovmf/
	cp /usr/share/edk2-ovmf/x64/OVMF_VARS.fd ovmf/

clean:
	rm gnu-efi/ -rf