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
; port 0x70 is RTC Address, and 0x71 is RTC Data
rtc_poll:
	mov al, 0x0A                        ; status register A
	out 0x70, al                        ; select the address
	in al, 0x71                         ; read the data
	test al, 0x80                       ; check if there is an update in progress
	jne rtc_poll                        ; if so then keep polling
	mov al, 0x0A                        ; status register A
	out 0x70, al                        ; select the address
	mov al, 00100110b                   ; UIP (0), RTC@32.768KHz (010), Rate@1024Hz (0110)
	out 0x71, al                        ; write the data

	; remap PIC IRQ's
	mov al, 00010001b                   ; begin PIC 1 initialization
	out 0x20, al
	mov al, 00010001b                   ; begin PIC 2 initialization
	out 0xA0, al
	mov al, 0x20                        ; IRQ 0-7: interrupts 20h-27h
	out 0x21, al
	mov al, 0x28                        ; IRQ 8-15: interrupts 28h-2Fh
	out 0xA1, al
	mov al, 4
	out 0x21, al
	mov al, 2
	out 0xA1, al
	mov al, 1
	out 0x21, al
	out 0xA1, al

	; mask all PIC interrupts
	mov al, 0xFF
	out 0x21, al
	out 0xA1, al

	; configure serial port at 0x03F8
	mov dx, 0x03F9                      ; interrupt enable (0x03F8 + 1)
	mov al, 0x00                        ; disable all interrupts
	out dx, al
	mov dx, 0x03FB                      ; line control (0x03F8 + 3)
	mov al, 80
	out dx, al
	mov dx, 0x03F8                      ; divisor latch (0x03F8 + 0)
	mov ax, 1                           ; 1 = 115200 baud
	out dx, ax
	mov dx, 0x03FB                      ; line control (0x03F8 + 3)
	mov al, 3                           ; 8 bits, no parity, one stop bit
	out dx, al
	mov dx, 0x03FC                      ; modem control (0x03F8 + 4)
	mov al, 3
	out dx, al
	mov al, 0xC7                        ; enable FIFO, clear them, with 14-byte threshold
	mov dx, 0x03FA                      ; (0x03F8 + 2)
	out dx, al

	; clear out the first 20KiB of memory. this will store the 64-bit IDT, GDT, PML4, PDP Low, and PDP High
	mov ecx, 5120
	xor eax, eax
	mov edi, eax
	rep stosd

	; clear memory for the page descriptor entries (0x10000 - 0x5FFFF)
	mov edi, 0x00010000
	mov ecx, 81920
	rep stosd                           ; write 320 KiB

	; copy the GDT to its final location in memory
	mov esi, gdt64
	mov edi, 0x00001000                 ; GDT address
	mov ecx, (gdt64_end - gdt64)
	rep movsb                           ; move it to final pos

	; TODO: continue
	; create the level 4 page map. (maps 4GBs of 2MB pages)
	; first create a PML4 entry.
	; PML4 is stored at 0x0000000000002000, create the first entry there
	; a single PML4 entry can map 512GB with 2MB pages.
	cld
	mov edi, 0x00002000                 ; create a PML4 entry for the first 4GB of RAM
	mov eax, 0x00003007                 ; location of low PDP
	stosd
	xor eax, eax
	stosd

	mov edi, 0x00002800		; Create a PML4 entry for higher half (starting at 0xFFFF800000000000)
	mov eax, 0x00004007		; location of high PDP
	stosd
	xor eax, eax
	stosd

; Create the PDP entries.
; The first PDP is stored at 0x0000000000003000, create the first entries there
; A single PDP entry can map 1GB with 2MB pages
	mov ecx, 4			; number of PDPE's to make.. each PDPE maps 1GB of physical memory
	mov edi, 0x00003000		; location of low PDPE
	mov eax, 0x00010007		; location of first low PD