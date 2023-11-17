; //////////////////////////////////////////////////////////////////////////////
; // File:     Name:        multiboot_1.asm                                   //
; //           Language:    x86_64 NASM assembly                              //
; //                                                                          //
; // Details:  this file contains the multiboot header (multiboot 1)          //
; //           this code may be loaded from another bootloader like GRUB      //
; //                                                                          //
; // Author:   Name:        Marijn Verschuren                                 //
; //           Email:       email@address.com                                 //
; //                                                                          //
; // Date:     2023-11-17                                                     //
; //////////////////////////////////////////////////////////////////////////////


[BITS 32]
[ORG 0x100000]
[global _start]

MAGIC           equ 0xE85250D6
ARCHITECHTURE   equ 0               ; TODO
HEADER_LENGTH   equ multiboot_header_end - multiboot_header_start
CHECKSUM        equ 0x100000000 - (MAGIC + ARCHITECHTURE + HEADER_LENGTH)

VBE_BIT_DEPTH       equ 32          ; 24
VBE_X_RES           equ 800         ; 1024
VBE_Y_RES           equ 600         ; 768

_start:
	xor eax, eax                    ; clear eax
	xor ebx, ebx                    ; clear ebx
	jmp multiboot_entry             ; jump past the multiboot header


[ALIGN 8]
multiboot_header_start:
	dd MAGIC
	dd ARCHITECHTURE
	dd HEADER_LENGTH
	dd CHECKSUM
entry_address_tag_start:
	dw 3                            ; TODO: note
	dw 0                            ; TODO: note
	dd entry_address_tag_end - entry_address_tag_start
	dq multiboot_entry
entry_address_tag_end:
frame_buffer_tag_start:
        dw 5                        ; TODO: note
        dw 0                        ; TODO: note
        dd frame_buffer_tag_end - frame_buffer_tag_start
        dd VBE_X_RES
        dd VBE_Y_RES
        dd VBE_BIT_DEPTH
frame_buffer_tag_end:
	dw 0                            ; end type
	dw 0                            ; TODO: note
	dd 8                            ; TODO: note
multiboot_header_end:

multiboot_entry:
	cmp eax, 0x36D76289             ; magic number
	jne halt
halt:
	hlt
	jmp halt
