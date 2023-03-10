; ///////////////////////////////////////////////////////////////////////////
; // File:     clean_boot.asm                                              //
; // Details:  this file holds the entrypoint for the cleanboot bootloader //
; //           written in x86_64 NASM assembly                             //
; //                                                                       //
; // Author:   Name:    Marijn Verschuren                                  //
; //           Email:   email@address.com                                  //
; //                                                                       //
; // Date:     2023-03-10                                                  //
; ///////////////////////////////////////////////////////////////////////////


BITS 32
ORG 0x00008000
CLEANBOOT equ 4096                      ; pad cleanboot to this length


; ///////////////////////////////////////////////////////////////////////////
; entry point ///////////////////////////////////////////////////////////////
start:
	jmp start32                         ; this command will be replaced with 'NOP's before the AP's are started
	nop
	db 0x36, 0x34                       ; '64' marker


; ///////////////////////////////////////////////////////////////////////////
; AP startup ////////////////////////////////////////////////////////////////
BITS 16
	cli	                                ; clear interrupts (mask all)
	xor eax, eax                        ; clear all general purpose registers
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp
	mov ds, ax                          ; clear all data segment registers
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax
	mov esp, 0x8000                     ; set a known free location for the stack

%include "components/smp_ap.asm"		; AP's will start execution at 0x8000 and fall through to this code


; ///////////////////////////////////////////////////////////////////////////
; 32-bit mode ///////////////////////////////////////////////////////////////
BITS 32
start32:
	mov eax, 16                         ; initializing the segment registers
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax

	mov edi, 0x5000                     ; clear the info map and system variable
	xor eax, eax
	mov ecx, 768
	rep stosd

	xor eax, eax                        ; clear all general purpose registers
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp
	mov esp, 0x8000                     ; set a known free location for the stack


; set up Real Time Clock (RTC)
; TODO: put into included file (ln 74)