# CleanBoot
cleanboot is a bootloader that initializes the computer into a 64-bit state using a minimal amount of code.
it contains is as little redundant or outdated code as possible.


## System Requirements
* any x86-64 processor
* at least 2 MiB of RAM


## NASM Kernel example
this is a minimal kernel that just contains an infinite loop
``` asm
BITS 64
ORG 0x100000

start:
	jmp start
```
as you can see from the `ORG` statement the kernel has to be loaded at `0x100000 (1Mib)`


## GCC Kernel example
this is C code for the exact same kernel as before
``` C
void _start(void) {
	for (;;) {}
}
```
> a couple caveats of writing the kernel in C are:
> * the entry point is `_start` instead of `start`
> * the `ORG` cant be set from within the code and has to be defined in a linker script

### GCC Kernel Linker Script
this is the linker script that will set the `ORG` of your C code to `0x100000 (1Mib)`
``` linkerscript
OUTPUT_FORMAT("binary")
OUTPUT_ARCH("i386:x86-64")

SECTIONS
{
    . = 0x100000;
    .text : {
        *(.text)
    }
    .data : {
        *(.data)
    }
    .rodata : {
        *(.rodata)
    }
    .bss : {
        *(.bss)
    }
}
```

with this linker script you can compile your C kernel like so
``` makefile
gcc -c kernel.c -o kernel.o -mno-red-zone -fno-stack-protector -fomit-frame-pointer
ld -T kernel.ld -o kernel.bin kernel.o
```

## C Kernel Note
we have established that you use C you will have to define the `_start` symbol.
because of this you might want to create a separate file that calls a different function like `main` from `_start`
``` C
extern int main(void);

void _start(void) {
    main();
}
```
keep in mind that when you do this that you have to ***always*** keep the `_start` function at the start of your binary.
because of this you have to link the files containing the `_start` and `main` symbol
``` makefile
ld -T kernel.ld -o kernel.bin start.o kernel.o
```

## Creating a Boot Image
After building the kernel, bootloader and mbr you can combine them to create a bootable image
``` makefile
dd if=/dev/zero of=disk.img count=128 bs=1048576
cat clean_boot.sys kernel.bin > image.sys

dd if=mbr.sys of=disk.img conv=notrunc
dd if=image.sys of=disk.img bs=512 seek=16 conv=notrunc
```

after creating the boot image you can boot it using qemu-system-x86_64
``` makefile
qemu-system-x86_64 -drive format=raw,file=disk.img
```