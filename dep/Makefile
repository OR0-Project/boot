default:
	git clone https://git.code.sf.net/p/gnu-efi/code gnu-efi
	cd gnu-efi && make
	mkdir ovmf
	cp /usr/share/edk2-ovmf/x64/OVMF_CODE.fd ovmf/
	cp /usr/share/edk2-ovmf/x64/OVMF_VARS.fd ovmf/

clean:
	rm gnu-efi/ -rf