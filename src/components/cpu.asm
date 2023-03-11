; ///////////////////////////////////////////////////////////////////////////
; // File:     Name:        cpu.asm                                        //
; //           Language:    x86_64 NASM assembly                           //
; //                                                                       //
; // Details:  this file contains the code responsible for initializing    //
; //           the CPU                                                     //
; //                                                                       //
; // Author:   Name:        Marijn Verschuren                              //
; //           Email:       email@address.com                              //
; //                                                                       //
; // Date:     2023-03-11                                                  //
; ///////////////////////////////////////////////////////////////////////////


init_cpu:
	; disable Cache
	mov rax, cr0
	btr rax, 29                         ; clear no write-thru   (bit 29)
	bts rax, 30                         ; set cache disable     (bit 30)
	mov cr0, rax

	wbinvd                              ; flush cache

	; disable global paging extensions
	mov rax, cr4
	btr rax, 7                          ; clear paging global extensions (bit 7)
	mov cr4, rax
	mov rax, cr3
	mov cr3, rax

	; disable MTRRs and configure default memory type to UC
	mov ecx, 0x000002FF
	rdmsr
	and eax, 0xFFFFF300                 ; clear MTRR enable (bit 11), fixed range MTRR enable (bit 10), and default memory type (bits 7:0) to UC (0x00)
	wrmsr

	; setup variable-size address ranges
	; cache 0-64 MiB as type 6 (WB) cache
	;	mov ecx, 0x00000200             ; MTRR_Phys_Base_MSR(0)
	;	mov edx, 0x00000000             ; base is EDX:EAX, 0x0000000000000006
	;	mov eax, 0x00000006             ; type 6 (write-back cache)
	;	wrmsr
	;	mov ecx, 0x00000201             ; MTRR_Phys_Mask_MSR(0)
	;	mov edx, 0x00000000             ; mask is EDX:EAX, 0x0000000001000800 (because bochs sucks)
	;	mov eax, 0x01000800             ; bit 11 set for valid
	;	mov edx, 0x0000000F             ; mask is EDX:EAX, 0x0000000F80000800 (2 GiB)
	;	mov eax, 0x80000800             ; bit 11 set for Valid
	;	wrmsr

	; enable MTRRs
	mov ecx, 0x000002FF
	rdmsr
	bts eax, 11                         ; set MTRR enable (bit 11), only enables variable range MTRR's
	wrmsr

	; flush cache
	wbinvd

	; Enable Cache
	mov rax, cr0
	btr rax, 29                         ; clear no write-thru (bit 29)
	btr rax, 30                         ; clear CD (bit 30)
	mov cr0, rax

	; enable global paging extensions
	;	mov rax, cr4
	;	bts rax, 7                      ; set paging global extensions (bit 7)
	;	mov cr4, rax

	; enable floating point unit
	mov rax, cr0
	bts rax, 1                          ; set monitor co-processor (bit 1)
	btr rax, 2                          ; clear emulation (bit 2)
	mov cr0, rax

	; enable SSE
	mov rax, cr4
	bts rax, 9                          ; set operating system support for FXSAVE and FXSTOR instructions (bit 9)
	bts rax, 10                         ; set operating system support for unmasked SIMD floating-point exceptions (bit 10)
	mov cr4, rax

	; enable math co-processor
	finit

	; enable and configure local APIC
	mov rsi, [os_LocalAPICAddress]
	test rsi, rsi
	je noMP                             ; skip MP init if we didn't get a valid LAPIC address

	xor eax, eax                        ; clear task priority (bits 7:4) and priority sub-class (bits 3:0)
	mov dword [rsi+0x80], eax           ; Task Priority Register (TPR)

	mov eax, 0x01000000                 ; set bits 31-24 for all cores to be in group 1
	mov dword [rsi+0xD0], eax           ; Logical Destination Register (LDR)

	xor eax, eax
	not eax                             ; set EAX to 0xFFFFFFFF; bits 31-28 set for flat mode
	mov dword [rsi+0xE0], eax           ; Destination Format Register (DFR)

	mov eax, dword [rsi+0xF0]           ; Spurious Interrupt Vector Register (SIVR)
	mov al, 0xF8
	bts eax, 8                          ; enable APIC (bit 8)
	mov dword [rsi+0xF0], eax

	mov eax, dword [rsi+0x320]          ; LVT timer register
	bts eax, 16                         ; set bit 16 for masked interrupts
	mov dword [rsi+0x320], eax

	; configure Local Vector Table (LVT)
	;	mov eax, dword [rsi+0x350]      ; LVT LINT0 register
	;	mov al, 0                       ; set interrupt vector (bits 7:0)
	;	bts eax, 8                      ; delivery mode (111b=ExtlNT] (bits 10:8)
	;	bts eax, 9
	;	bts eax, 10
	;	bts eax, 15                     ; bit15:set trigger mode to Level (0=Edge, 1=Level)
	;	btr eax, 16                     ; bit16:unmask interrupts (0=Unmasked, 1=Masked)
	;	mov dword [rsi+0x350], eax

	;	mov eax, dword [rsi+0x360]      ; LVT LINT1 register
	;	mov al, 0                       ; set interrupt vector (bits 7:0)
	;	bts eax, 8                      ; delivery Mode (111b=ExtlNT] (bits 10:8)
	;	bts eax, 9
	;	bts eax, 10
	;	bts eax, 15                     ; bit15:set trigger mode to Edge (0=Edge, 1=Level)
	;	btr eax, 16                     ; bit16:unmask interrupts (0=Unmasked, 1=Masked)
	;	mov dword [rsi+0x360], eax

	;	mov eax, dword [rsi+0x370]      ; LVT error register
	;	mov al, 0                       ; set interrupt vector (bits 7:0)
	;	bts eax, 16                     ; bit16:mask interrupts (0=Unmasked, 1=Masked)
	;	mov dword [rsi+0x370], eax

	ret