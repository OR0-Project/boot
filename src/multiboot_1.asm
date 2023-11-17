; //////////////////////////////////////////////////////////////////////////////
; // File:     Name:        multiboot_1.asm                                   //
; //           Language:    x86_64 NASM assembly                              //
; //                                                                          //
; // Details:  this file contains mbr (master boot record) which is booted    //
; //           when running in legacy mode                                    //
; //                                                                          //
; // Author:   Name:        Marijn Verschuren                                 //
; //           Email:       email@address.com                                 //
; //                                                                          //
; // Date:     2023-11-17                                                     //
; //////////////////////////////////////////////////////////////////////////////


[BITS 32]
[global _start]
[ORG 0x100000]

FLAG_ALIGN          equ 1<<0        ; align loaded modules on page boundaries
FLAG_MEMINFO        equ 1<<1        ; provide memory map
FLAG_VIDEO          equ 1<<2        ; set video mode
FLAG_AOUT_KLUDGE    equ 1<<16       ; indicate to GRUB we are not an ELF executable
; the fields:
;  * header address
;  * load address
;  * load end address
;  * bss
;  * end address
;  * entry address
; will be available in the multiboot header

MAGIC       equ 0x1BADB002          ; magic number GRUB checks for in the first 8Kib
FLAGS       equ FLAG_ALIGN | FLAG_MEMINFO | FLAG_VIDEO | FLAG_AOUT_KLUDGE
CHECKSUM    equ -(MAGIC + FLAGS)    ; checksum based on flags and magic number

mode_type   equ 0                   ; linear buffer type
width       equ 1024                ; x resolution
height      equ 768                 ; y resolution
depth       equ 24                  ; pixel depth

_start:
	xor eax, eax                    ; clear eax
	xor ebx, ebx                    ; clear ebx
	jmp multiboot_entry             ; jump past the multiboot header


[ALIGN 4]
multiboot_header:
	dd MAGIC                        ; magic
	dd FLAGS                        ; flags
	dd CHECKSUM                     ; checksum
	dd multiboot_header             ; header address
	dd _start                       ; load address of code entry point
	dd 0x00                         ; load end address  TODO
	dd 0x00                         ; bss end address   TODO
	dd multiboot_entry              ; entry address GRUB will start at
	dd mode_type                    ; screen buffer mode
	dd width                        ; screen x resolution
	dd height                       ; screen y resolution
	dd depth                        ; screen pixel depth


[ALIGN 16]
multiboot_entry:
	push 0
	popf                            ; clear flags
	cld                             ; clear direction flag
load_memory_map:
	mov esi, ebx                    ; GRUB stores the multiboot info table address in EBX
	mov edi, 0x6000                 ; put destination address (0x6000) into EDI
	add esi, 44                     ; memory map address at this offset in the mutliboot table
	lodsd                           ; load the memory map size in bytes
	mov ecx, eax
	lodsd                           ; load the memory map address
	mov esi, eax

memory_map_entry:
	lodsd                           ; size of entry
	cmp eax, 0
	je memory_map_end
	movsd                           ; base address low
	movsd                           ; base address high
	movsd                           ; length low
	movsd                           ; length high
	movsd                           ; type
	xor eax, eax
	stosd                           ; store padding
	stosd                           ; TODO: note
	stosd                           ; TODO: note
	jmp memory_map_entry

memory_map_end:
	xor eax, eax
	mov ecx, 8
	rep stosd

load:  ; load kernel and loader
	mov esi, multiboot_end
	mov edi, 0x00008000
	mov ecx, 8192                   ; copy 32Kib (8192 dwords)
	rep movsd                       ; copy to expected address
	cli
	jmp 0x00008000                  ; jump to loader address

times 512-$+$$ db 0
multiboot_end:
