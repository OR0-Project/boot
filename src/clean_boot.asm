; //////////////////////////////////////////////////////////////////////////////
; // File:     Name:        clean_boot.asm                                    //
; //           Language:    x86_64 NASM assembly                              //
; //                                                                          //
; // Details:  this file holds the entrypoint for the cleanboot bootloader    //
; //                                                                          //
; // Author:   Name:    Marijn Verschuren                                     //
; //           Email:   email@address.com                                     //
; //                                                                          //
; // Date:     2023-03-10                                                     //
; //////////////////////////////////////////////////////////////////////////////


BITS 32
ORG 0x00008000
CLEANBOOT equ 4096                              ; pad cleanboot to this length


; ///////////////////////////////////////////////////////////////////////////
; entry point ///////////////////////////////////////////////////////////////
start:
	jmp start32                                 ; this command will be replaced with 'NOP's before the AP's are started
	nop
	db 0x36, 0x34                               ; '64' marker


; ///////////////////////////////////////////////////////////////////////////
; AP startup ////////////////////////////////////////////////////////////////
BITS 16
	cli	                                        ; clear interrupts (mask all)
	xor eax, eax                                ; clear all general purpose registers
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp
	mov ds, ax                                  ; clear all data segment registers
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax
	mov esp, 0x8000                             ; set a known free location for the stack

%include "components/smp_ap.asm"	        	; AP's will start execution at 0x8000 and fall through to this code


; ///////////////////////////////////////////////////////////////////////////
; 32-bit mode ///////////////////////////////////////////////////////////////
BITS 32
start32:
	mov eax, 16                                 ; initializing the segment registers
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax

	mov edi, 0x5000                             ; clear the info map and system variable
	xor eax, eax
	mov ecx, 768
	rep stosd

	xor eax, eax                                ; clear all general purpose registers
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp
	mov esp, 0x8000                             ; set a known free location for the stack


; set up Real Time Clock (RTC)
; port 0x70 is RTC Address, and 0x71 is RTC Data
rtc_poll:
	mov al, 0x0A                                ; status register A
	out 0x70, al                                ; select the address
	in al, 0x71                                 ; read the data
	test al, 0x80                               ; check if there is an update in progress
	jne rtc_poll                                ; if so then keep polling
	mov al, 0x0A                                ; status register A
	out 0x70, al                                ; select the address
	mov al, 00100110b                           ; UIP (0), RTC@32.768KHz (010), Rate@1024Hz (0110)
	out 0x71, al                                ; write the data

	; remap PIC IRQ's
	mov al, 00010001b                           ; begin PIC 1 initialization
	out 0x20, al
	mov al, 00010001b                           ; begin PIC 2 initialization
	out 0xA0, al
	mov al, 0x20                                ; IRQ 0-7: interrupts 20h-27h
	out 0x21, al
	mov al, 0x28                                ; IRQ 8-15: interrupts 28h-2Fh
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
	mov dx, 0x03F9                              ; interrupt enable (0x03F8 + 1)
	mov al, 0x00                                ; disable all interrupts
	out dx, al
	mov dx, 0x03FB                              ; line control (0x03F8 + 3)
	mov al, 80
	out dx, al
	mov dx, 0x03F8                              ; divisor latch (0x03F8 + 0)
	mov ax, 1                                   ; 1 = 115200 baud
	out dx, ax
	mov dx, 0x03FB                              ; line control (0x03F8 + 3)
	mov al, 3                                   ; 8 bits, no parity, one stop bit
	out dx, al
	mov dx, 0x03FC                              ; modem control (0x03F8 + 4)
	mov al, 3
	out dx, al
	mov al, 0xC7                                ; enable FIFO, clear them, with 14-byte threshold
	mov dx, 0x03FA                              ; (0x03F8 + 2)
	out dx, al

	; clear out the first 20KiB of memory. this will store the 64-bit IDT, GDT, PML4, PDP Low, and PDP High
	mov ecx, 5120
	xor eax, eax
	mov edi, eax
	rep stosd

	; clear memory for the page descriptor entries (0x10000 - 0x5FFFF)
	mov edi, 0x00010000
	mov ecx, 81920
	rep stosd                                   ; write 320 KiB

	; copy the GDT to its final location in memory
	mov esi, gdt64
	mov edi, 0x00001000                         ; GDT address
	mov ecx, (gdt64_end - gdt64)
	rep movsb                                   ; move it to final pos

	; create the level 4 page map. (maps 4GiBs of 2MiB pages)
	; first create a PML4 entry.
	; PML4 is stored at 0x0000000000002000, create the first entry there
	; a single PML4 entry can map 512GB with 2MB pages.
	cld
	mov edi, 0x00002000                         ; create a PML4 entry for the first 4GB of RAM
	mov eax, 0x00003007                         ; location of low PDP
	stosd
	xor eax, eax
	stosd

	mov edi, 0x00002800                         ; create a PML4 entry for higher half (starting at 0xFFFF800000000000)
	mov eax, 0x00004007		                    ; location of high PDP
	stosd
	xor eax, eax
	stosd

	; create the PDP entries.
	; the first PDP is stored at 0x0000000000003000 and contais 512 entries (4 KiB total)
	; a single Page Directory Pointer Entry (PDPE) can map 1 GiB with 2 MiB pages (each page directory contains 512 page tables)
	mov ecx, 4                                  ; number of PDPE's to make.. each PDPE maps 1GB of physical memory
	mov edi, 0x00003000                         ; location of low PDPE
	mov eax, 0x00010007                         ; location of first low PD

create_pdpe_low:
	stosd
	push eax
	xor eax, eax
	stosd
	pop eax
	add eax, 0x00001000                         ; 4 Kib later (512 records x 8 bytes)
	dec ecx
	cmp ecx, 0
	jne create_pdpe_low

	; create the low PD entries.
	mov edi, 0x00010000
	mov eax, 0x0000008F                         ; bits: 0 (P), 1 (R/W), 2 (U/S), 3 (PWT), and 7 (PS) set
	xor ecx, ecx
pd_low:                                         ; create a 2 MiB page
	stosd
	push eax
	xor eax, eax
	stosd
	pop eax
	add eax, 0x00200000
	inc ecx
	cmp ecx, 2048
	jne pd_low                                  ; create 2048 2 MiB page maps

	; load the GDT
	lgdt [GDTR64]

	; enable extended properties
	mov eax, cr4
	or eax, 0x0000000B0                         ; PGE (bit 7), PAE (bit 5), and PSE (bit 4)
	mov cr4, eax

	; point cr3 at PML4
	mov eax, 0x00002008                         ; write-thru enabled (bit 3)
	mov cr3, eax

	; enable long mode and SYSCALL/SYSRET
	mov ecx, 0xC0000080                         ; EFER MSR number
	rdmsr                                       ; read EFER
	or eax, 0x00000101                          ; LME (bit 8)
	wrmsr                                       ; write EFER

	; enable paging to activate long mode
	mov eax, cr0
	or eax, 0x80000000                          ; PG (Bit 31)
	mov cr0, eax

	jmp SYS64_CODE_SEL:start64                  ; Jump to 64-bit mode


; ///////////////////////////////////////////////////////////////////////////
; 64-bit mode ///////////////////////////////////////////////////////////////
align 16
BITS 64


start64:
	; clear all general purpose registers (except for the base pointer)
	xor eax, eax                                ; aka r0
	xor ebx, ebx                                ; aka r3
	xor ecx, ecx                                ; aka r1
	xor edx, edx                                ; aka r2
	xor esi, esi                                ; aka r6
	xor edi, edi                                ; aka r7
	xor ebp, ebp                                ; aka r5
	mov esp, 0x8000                             ; aka r4
	xor r8, r8
	xor r9, r9
	xor r10, r10
	xor r11, r11
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15

	; clear the legacy segment registers
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax

	mov rax, clearcs64                          ; a proper 64-bit jump like this should not be needed as the ...
	jmp rax                                     ; jmp SYS64_CODE_SEL:start64 would have sent us ...
	nop                                         ; out of compatibility mode and into 64-bit mode
clearcs64:
	xor eax, eax

	lgdt [GDTR64]                               ; reload the GDT

	; save the boot mode (it will be 'U' if started via UEFI)
	mov al, [0x8005]
	mov [BootMode], al                          ; save the byte as a boot mode flag

	; patch cleanboot AP code		        	; the AP's will be told to start execution at 0x8000 (see line 20 of this file)
	mov edi, start                              ; we need to remove the BSP jump call to get the AP's
	mov eax, 0x90909090                         ; to fall through to the AP init code
	stosd
	stosd                                       ; overwrite 8 bytes in total to overwrite the 'far jump' and marker

	mov al, [BootMode]
	cmp al, 'U'
	je uefi_memory_map

	; process the E820 memory map to find all possible 2 MiB pages that are free to use
    ; build a map at 0x400000
    xor ecx, ecx
    xor ebx, ebx                                ; counter for pages found
    mov esi, 0x00006000                         ; E820 map location

next_entry:
	add esi, 16                                 ; skip ESI to type marker
	mov eax, [esi]                              ; load the 32-bit type marker
	cmp eax, 0                                  ; check for end of the table
	je end_E820
	cmp eax, 1                                  ; check if it is marked present
	je process_free
	add esi, 16                                 ; skip ESI to start of next entry
	jmp next_entry

process_free:
	sub esi, 16
	mov rax, [rsi]                              ; physical start address
	add esi, 8
	mov rcx, [rsi]			                    ; physical length
	add esi, 24
	shr rcx, 21                                 ; convert bytes to # of 2 MiB pages
	cmp rcx, 0                                  ; check that we have at least 1 page
	je next_entry
	shl rax, 1
	mov edx, 0x1FFFFF
	not rdx                                     ; clear bits 20 - 0
	and rax, rdx
	; at this point RAX points to the start and RCX has the # of pages
	shr rax, 21                                 ; page # to start on
	mov rdi, 0x400000                           ; 4 MiB into physical memory
	add rdi, rax
	mov al, 1
	add ebx, ecx
	rep stosb
	jmp next_entry

end_E820:
	shl ebx, 1
	mov dword [mem_amount], ebx
	shr ebx, 1
	jmp memory_map_end

uefi_memory_map:                                ; TODO: fix this as it is a terrible hack
	mov rdi, 0x400000
	mov al, 1
	mov rcx, 32
	rep stosb
	mov ebx, 64
	mov dword [mem_amount], ebx

memory_map_end:
	; create the high memory map
	mov rcx, rbx
	shr rcx, 9                                  ; TODO: this isn't the exact math but good enough
	add rcx, 1                                  ; number of PDPE's to make.. each PDPE maps 1GB of physical memory
	mov edi, 0x00004000                         ; location of high PDPE
	mov eax, 0x00020007                         ; location of first high PD (bits: 0 (P), 1 (R/W), and 2 (U/S) set)

create_pdpe_high:
	stosq
	add rax, 0x00001000                         ; 4K later (512 records x 8 bytes)
	dec ecx
	cmp ecx, 0
	jne create_pdpe_high

	; create the high PD entries
	; EBX contains the number of pages that should exist in the map, once they are all found bail out
	xor ecx, ecx
	xor eax, eax
	xor edx, edx
	mov edi, 0x00020000                         ; location of high PD entries
	mov esi, 0x00400000                         ; location of free pages map

pd_high:
	cmp rdx, rbx                                ; compare mapped pages to max pages
	je pd_high_done
	lodsb
	cmp al, 1
	je pd_high_entry
	add rcx, 1
	jmp pd_high

pd_high_entry:
	mov eax, 0x0000008F                         ; bits 0 (P), 1 (R/W), 2 (U/S), 3 (PWT), and 7 (PS) set
	shl rcx, 21
	add rax, rcx
	shr rcx, 21
	stosq
	add rcx, 1
	add rdx, 1                                  ; we have mapped a valid page
	jmp pd_high

pd_high_done:
	; build a temporary IDT
	xor edi, edi                                ; create the 64-bit IDT (at linear address 0x0000000000000000)
	mov rcx, 32


make_exception_gates:                           ; make gates for exception handlers
	mov rax, exception_gate
	push rax                                    ; save the exception gate to the stack for later use
	stosw                                       ; store the low word (15:0) of the address
	mov ax, SYS64_CODE_SEL
	stosw                                       ; store the segment selector
	mov ax, 0x8E00
	stosw                                       ; store exception gate marker
	pop rax                                     ; get the exception gate back
	shr rax, 16
	stosw                                       ; store the high word (31:16) of the address
	shr rax, 16
	stosd                                       ; store the extra high dword (63:32) of the address.
	xor rax, rax
	stosd                                       ; reserved
	dec rcx
	jnz make_exception_gates

	mov rcx, 256-32

make_interrupt_gates:                           ; make gates for the other interrupts
	mov rax, interrupt_gate
	push rax                                    ; save the interrupt gate to the stack for later use
	stosw                                       ; store the low word (15:0) of the address
	mov ax, SYS64_CODE_SEL
	stosw                                       ; store the segment selector
	mov ax, 0x8F00
	stosw                                       ; store interrupt gate marker
	pop rax                                     ; get the interrupt gate back
	shr rax, 16
	stosw                                       ; store the high word (31:16) of the address
	shr rax, 16
	stosd                                       ; store the extra high dword (63:32) of the address.
	xor eax, eax
	stosd                                       ; reserved
	dec rcx
	jnz make_interrupt_gates

	; set up the exception gates for all of the CPU exceptions
	; the following code will be seriously busted if the exception gates are moved above 16MB
	mov word [0x00*16], exception_gate_00
	mov word [0x01*16], exception_gate_01
	mov word [0x02*16], exception_gate_02
	mov word [0x03*16], exception_gate_03
	mov word [0x04*16], exception_gate_04
	mov word [0x05*16], exception_gate_05
	mov word [0x06*16], exception_gate_06
	mov word [0x07*16], exception_gate_07
	mov word [0x08*16], exception_gate_08
	mov word [0x09*16], exception_gate_09
	mov word [0x0A*16], exception_gate_10
	mov word [0x0B*16], exception_gate_11
	mov word [0x0C*16], exception_gate_12
	mov word [0x0D*16], exception_gate_13
	mov word [0x0E*16], exception_gate_14
	mov word [0x0F*16], exception_gate_15
	mov word [0x10*16], exception_gate_16
	mov word [0x11*16], exception_gate_17
	mov word [0x12*16], exception_gate_18
	mov word [0x13*16], exception_gate_19

	mov edi, 0x21                               ; set up Keyboard handler
	mov eax, keyboard
	call create_gate
	mov edi, 0x22                               ; set up cascade handler
	mov eax, cascade
	call create_gate
	mov edi, 0x28                               ; set up RTC handler
	mov eax, rtc
	call create_gate

	lidt [IDTR64]                               ; load IDT register

	; clear memory 0xf000 - 0xf7ff for the infomap (2 KiB)
	xor eax, eax
	mov ecx, 256
	mov edi, 0x0000F000

clear_map_next:
	stosq
	dec ecx
	cmp ecx, 0
	jne clearmapnext

	; initialize devices
	call init_acpi                              ; find and process the ACPI tables
	call init_cpu                               ; configure the BSP CPU
	call init_pic                               ; configure the PIC(s), also activate interrupts
	call init_smp                               ; init of SMP

	; reset the stack to the proper location (was set to 0x8000 previously)
	mov rsi, [os_LocalAPICAddress]
	add rsi, 0x20
	lodsd                                       ; load a 32-bit value
	shr rax, 24                                 ; shift to the right and AL now holds the CPU's APIC ID (8 high bits)
	shl rax, 10                                 ; shift left 10 bits for a 1024byte stack
	add rax, 0x0000000000050400                 ; stacks decrement when you "push", start at 1024 bytes in
	mov rsp, rax                                ; cleanboot leaves 0x50000-0x9FFFF free so we use that

	; build the infomap
	xor edi, edi
	mov di, 0x5000
	mov rax, [os_ACPITableAddress]
	stosq
	mov eax, [os_BSP]
	stosd

	mov di, 0x5010
	mov ax, [cpu_speed]
	stosw
	mov ax, [cpu_activated]
	stosw
	mov ax, [cpu_detected]
	stosw

	mov di, 0x5020
	mov ax, [mem_amount]
	stosd

	mov di, 0x5030
	mov al, [os_IOAPICCount]
	stosb

	mov di, 0x5040
	mov rax, [os_HPETAddress]
	stosq

	mov di, 0x5060
	mov rax, [os_LocalAPICAddress]
	stosq
	xor ecx, ecx
	mov cl, [os_IOAPICCount]
	mov rsi, os_IOAPICAddress

next_IO_APIC:
	lodsq
	stosq
	sub cl, 1
	cmp cl, 0
	jne next_IO_APIC

	mov di, 0x5080
	mov eax, [VBEModeInfoBlock.PhysBasePtr]     ; base address of video memory (if graphics mode is set)
	stosd
	mov eax, [VBEModeInfoBlock.XResolution]     ; X and Y resolution (16-bits each)
	stosd
	mov al, [VBEModeInfoBlock.BitsPerPixel]     ; color depth
	stosb

	; move the trailing binary to its final location
	mov esi, 0x8000+PURE64SIZE                  ; memory offset to end of clean_boot.sys
	mov edi, 0x100000                           ; destination address at the 1 MiB mark
	mov ecx, ((32768 - PURE64SIZE) / 8)
	rep movsq                                   ; copy 8 bytes at a time

	; output message via serial port
	cld                                         ; clear the direction flag we want to increment through the string
	mov dx, 0x03F8                              ; address of first serial port
	mov rsi, message                            ; location of message
	mov cx, 11                                  ; length of message

serial_nextchar:
	jrcxz serial_done                           ; if RCX is 0 then the function is complete
	add dx, 5                                   ; offset to line status register
	in al, dx
	sub dx, 5                                   ; back to to base
	and al, 0x20
	cmp al, 0
	je serial_nextchar
	dec cx
	lodsb                                       ; get char from string and store in AL
	out dx, al                                  ; send the char to the serial port
	jmp serial_nextchar

serial_done:


; ///////////////////////////////////////////////////////////////////////////
; jump to kernel ////////////////////////////////////////////////////////////
	; clear all registers (skip the stack pointer)
	xor eax, eax                                ; These 32-bit calls also clear the upper bits of the 64-bit registers
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp
	xor r8, r8
	xor r9, r9
	xor r10, r10
	xor r11, r11
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15
	jmp 0x00100000


%include "components/acpi.asm"
%include "components/cpu.asm"
%include "components/pic.asm"
%include "components/smp.asm"
%include "components/interrupt.asm"
%include "sysvar.asm"

EOF:
	db 0xDE, 0xAD, 0xC0, 0xDE

; pad the binary to 4 KiB
times PURE64SIZE-($-$$) db 0x90
