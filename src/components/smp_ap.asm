; //////////////////////////////////////////////////////////////////////////////
; // File:     Name:        smp_ap.asm                                        //
; //           Language:    x86_64 NASM assembly                              //
; //                                                                          //
; // Details:  this file contains the code responsible for initializing       //
; //           the symmetric multiprocessing system for the                   //
; //           application processor                                          //
; //                                                                          //
; // Author:   Name:        Marijn Verschuren                                 //
; //           Email:       email@address.com                                 //
; //                                                                          //
; // Date:     2023-03-10                                                     //
; //////////////////////////////////////////////////////////////////////////////



; ///////////////////////////////////////////////////////////////////////////
; 16-bit (real) mode ////////////////////////////////////////////////////////
BITS 16

init_smp_ap:
	jmp 0x0000:config_ap

config_ap:

; enable and check the A20 gate
set_ap_A20:
	in al, 0x64
	test al, 0x02
	jnz set_A20_ap
	mov al, 0xD1
	out 0x64, al
check_ap_A20:
	in al, 0x64
	test al, 0x02
	jnz check_A20_ap
	mov al, 0xDF
	out 0x60, al

	; after the A20 gate is configured we can enter 32-bit mode
	lgdt [cs:GDTR32]                    ; load 32-bit GDT temporarily
	mov eax, cr0                        ; switch to 32-bit protected mode
	or al, 1
	mov cr0, eax
	jmp 8:start_ap32

align 16


; ///////////////////////////////////////////////////////////////////////////
; 32-bit mode ///////////////////////////////////////////////////////////////
BITS 32

start_ap32:
	mov eax, 16                         ; load 4 GB data descriptor
	mov ds, ax                          ; copy it to all data segment registers
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	xor eax, eax                        ; clear all general purpose registers
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp                        ; clear basepointer
	mov esp, 0x8000                     ; set a known free location for the stack

	lgdt [GDTR64]                       ; load GDT

	; enable extended properties
	mov eax, cr4
	or eax, 0x0000000B0                 ; PGE (bit 7), PAE (bit 5) and PSE (bit 4)
	mov cr4, eax

	; point cr3 at PML4
	mov eax, 0x00002008                 ; write-thru (bit 3)
	mov cr3, eax

	; enable long mode and SYSCALL/SYSRET
	mov ecx, 0xC0000080                 ; EFER MSR number
	rdmsr                               ; Read EFER
	or eax, 0x00000101                  ; LME (bit 8)
	wrmsr                               ; write EFER

	; enable paging to activate long mode
	mov eax, cr0
	or eax, 0x80000000                  ; PG (bit 31)
	mov cr0, eax

	; enter 64-bit long mode
	jmp SYS64_CODE_SEL:start_ap64

align 16


; ///////////////////////////////////////////////////////////////////////////
; 64-bit (long) mode ////////////////////////////////////////////////////////
BITS 64

start_ap64:
	xor eax, eax                        ; aka r0
	xor ebx, ebx                        ; aka r3
	xor ecx, ecx                        ; aka r1
	xor edx, edx                        ; aka r2
	xor esi, esi                        ; aka r6
	xor edi, edi                        ; aka r7
	xor ebp, ebp                        ; aka r5
	xor esp, esp                        ; aka r4
	xor r8, r8
	xor r9, r9
	xor r10, r10
	xor r11, r11
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15

	mov ds, ax                          ; clear the legacy segment registers
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax

	mov rax, config_ap64
	jmp rax
	nop

config_ap64:
	xor eax, eax                        ; clear eax

	; reset the stack (each CPU gets unique a 1024-byte stack location)
	; it is unsafe to call os_smp_get_id at this time because the stack is not defined yet
	mov rsi, [os_LocalAPICAddress]
	add rsi, 0x20
	lodsd                               ; load a 32-bit value
	shr rax, 24                         ; shift to the right and AL now holds the CPU's APIC ID (8 high bits)
	shl rax, 10                         ; shift left 10 bits for a 1024byte stack
	add rax, 0x0000000000050400         ; stacks decrement when you "push", start at 1024 bytes in
	mov rsp, rax                        ; cleanboot leaves 0x50000-0x9FFFF free so we use that

	lgdt [GDTR64]                       ; load the GDT
	lidt [IDTR64]                       ; load the IDT

	; enable local APIC on AP
	mov rsi, [os_LocalAPICAddress]
	add rsi, 0x00f0                     ; offset to Spurious Interrupt Register
	mov rdi, rsi
	lodsd
	or eax, 0000000100000000b
	stosd

	call init_cpu                       ; initialize CPU

	lock inc word [cpu_activated]
	xor eax, eax
	mov rsi, [os_LocalAPICAddress]
	add rsi, 0x20                       ; add the offset for the APIC ID location
	lodsd                               ; APIC ID is stored in bits 31:24
	shr rax, 24                         ; AL now holds the CPU's APIC ID (0 - 255)
	mov rdi, 0x00005700                 ; the location where the cpu values are stored
	add rdi, rax                        ; RDI points to infomap CPU area + APIC ID. ex F701 would be APIC ID 1
	mov al, 1
	stosb
	sti                                 ; activate interrupts for SMP
	jmp ap_suspend


align 16

ap_suspend:
	hlt                                 ; suspend CPU until an interrupt is received
	jmp ap_suspend                      ; just-in-case of an NMI
