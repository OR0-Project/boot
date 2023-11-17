; //////////////////////////////////////////////////////////////////////////////
; // File:     Name:        mbr.asm                                           //
; //           Language:    x86_64 NASM assembly                              //
; //                                                                          //
; // Details:  this file contains mbr (master boot record) which is booted    //
; //           when running in legacy mode                                    //
; //                                                                          //
; // Author:   Name:        Marijn Verschuren                                 //
; //           Email:       email@address.com                                 //
; //                                                                          //
; // Date:     2023-11-14                                                     //
; //////////////////////////////////////////////////////////////////////////////


; defines
%define VBE_BIT_DEPTH 32
%define VBE_X_RES 800
%define VBE_Y_RES 600

%define DAP_SECTORS 64
%define DAP_START_SECTOR 16
%define DAP_ADDRESS 0x8000
%define DAP_SEGMENT 0x0000

%define DAP_SIGNATURE 0x424F4F54


BITS 16
org 0x7C00


mbr:
	cli
	cld                             ; clear DF (direction flag)
	xor eax, eax                    ; clear eax
	mov ss, ax                      ; clear ss
	mov es, ax                      ; clear es
	mov ds, ax                      ; clear ds
	mov sp, 0x7C00                  ; set stack pointer
	sti                             ; enable interrupts

	mov [DriveNumber], dl           ; BIOS passes drive number in DL

	mov ah, 0
	mov al, 11100011b               ; 9600bps, no parity, 1 stop bit, 8 data bits
	mov dx, 0                       ; serial port 0
	int 0x14                        ; configure serial port

E820:   ; load the BIOS E820 Memory Map
	mov edi, 0x00006000             ; location for E820 memory map
	xor ebx, ebx                    ; clear ebx
	xor bp, bp                      ; clear bp (entry count)
	mov edx, 0x0534D4150            ; move "SMAP" into edx
	mov eax, 0xe820                 ; move 0xe820 into eax
	mov [es:di + 20], dword 1       ; force a valid ACPI 3.X entry
	mov ecx, 24                     ; request 24 bytes
	int 0x15                        ; request entry
	jc .no_map                      ; if CF is set we have reached the end of the E820_MAP
	mov edx, 0x0534D4150            ; repair edx (may be erased by some BIOSes)
	cmp eax, edx                    ; on success, eax must have been set to "SMAP"
	jne .no_map
	test ebx, ebx                   ; ebx = 0 implies list is only 1 entry long (failure)
	jz .no_map
	jmp .continue
.next:
	mov eax, 0xe820                 ; eax, ecx get trashed on every int 0x15 call
	mov [es:di + 20], dword 1       ; force a valid ACPI 3.X entry
	mov ecx, 24                     ; request 24 bytes
	int 0x15                        ; request entry
	jc .done              ; if C    F is set we have reached the end of the E820_MAP
	mov edx, 0x0534D4150            ; repair edx
.continue:
	jcxz .skip_entry                ; skip any 0 length entries
	cmp cl, 20                      ; check for 24 byte ACPI 3.X response
	jbe .no_text                    ; handle no text if so
	test byte [es:di + 20], 1       ; check if the "ignore this data" bit is set
	je .skip_entry                  ; skip if so
.no_text:
	mov ecx, [es:di + 8]            ; get lower dword of memory region size
	test ecx, ecx                   ; > 0
	jnz .add_entry
	mov ecx, [es:di + 12]           ; get upper dword of memory region size
	jecxz .skip_entry               ; skip entry (ecx) if zero
.add_entry:
	inc bp                          ; increment bp (count)
	add di, 32                      ; move to the next slot in memory
.skip_entry:
	test ebx, ebx                   ; if ebx resets to 0, list is complete
	jne .next
.no_map:
;	mov byte [cfg_e820], 0          ; no memory map function
.done:
	xor eax, eax                    ; create a blank record for termination (32 bytes)
	mov ecx, 8
	rep stosd


A20:    ; enable the A20 gate
	in al, 0x64                     ; TODO: note
	test al, 0x02                   ; TODO: note
	jnz A20                         ; retry if error occurred
	mov al, 0xD1                    ; TODO: note
	out 0x64, al                    ; TODO: note
.check:
	in al, 0x64                     ; TODO: note
	test al, 0x02                   ; TODO: note
	jnz .check                      ; retry if error occurred
	mov al, 0xDF                    ; TODO: note
	out 0x60, al                    ; TODO: note
	mov si, msg_start
	call print_string_16
	mov cx, 0x4000 - 1              ; start looking from 0x4000 to 0x4FFF
VBE_search:
	inc cx
	cmp cx, 0x5000
	je halt
	mov edi, VBE_mode_info_block       ; VBE data will be stored at this address
	mov ax, 0x4F01                  ; get SuperVGA mode information - http://www.ctyme.com/intr/rb-0274.htm
	mov bx, cx                      ; mode is saved to BX for the set command later
	int 0x10
	cmp ax, 0x004F                  ; return value in AX should equal 0x004F if command is supported and successful
	jne VBE_search                  ; try next mode
	cmp byte [VBE_mode_info_block.pixel_depth], VBE_BIT_DEPTH
	jne VBE_search                  ; try next mode if bit depth is not desired
	cmp word [VBE_mode_info_block.x_resolution], VBE_X_RES
	jne VBE_search                  ; try next mode if bit x-res is not desired
	cmp word [VBE_mode_info_block.y_resolution], VBE_Y_RES
	jne VBE_search                  ; try next mode if bit y-res is not desired

	or bx, 0x4000                   ; use linear/flat frame buffer model (set bit 14) TODO: notes
	mov ax, 0x4F02                  ; set SuperVGA video mode - http://www.ctyme.com/intr/rb-0275.htm
	int 0x10
	cmp ax, 0x004F                  ; return value in AX should equal 0x004F if supported and successful
	jne halt
load_32_bit_stage:
	mov ah, 0x42                    ; extended Read
	mov dl, [DriveNumber]           ; load drive number
	mov si, DAP                     ; load DAP information
	int 0x13                        ; read disk
	jc read_fail                    ; print error if CF is set
verify_32_bit_stage:
	;start: <- loaded @DAP_ADDRESS
	;   jmp start32                 ; jmp 32-bit-address    -> 5 bytes
	;   nop                         ; nop                   -> 1 byte
	;   dd 0x........               ; @(DAP_ADDRESS + 6)
	mov eax, dword[DAP_ADDRESS + 6] ; load os marker
	cmp eax, DAP_SIGNATURE          ; match magic number
	jne sig_fail                    ; print error if magic number is not found
	mov si, msg_ok                  ; print ok message on load success
	call print_string_16
jump_to_32_bit_stage:
	cli                             ; disable interrupts
	lgdt [cs:GDTR32]                ; load 32-bit GDT into register
	mov eax, cr0                    ; load CR0 (control register 0)
	or al, 0x01                     ; set protected mode bit
	mov cr0, eax                    ; set CR0 (control register 0)
	jmp 0x0008:DAP_ADDRESS          ; jump to 32-bit protected mode


read_fail:
	mov si, msg_read_fail           ; load read failure message
	call print_string_16
	jmp halt
sig_fail:
	mov si, msg_sig_fail            ; load signature failure message
	call print_string_16
halt:
	hlt
	jmp halt


; //////////////////////////////////////////////////////////////////////////////
; function to output a 16-bit string to the serial port
; IN:   SI - Address of start of string
serial_print_16:                    ; output string in SI to screen
	pusha
	mov dx, 0                       ; port 0
.loop:
	mov ah, 0x01                    ; serial - Write character to port
	lodsb                           ; get char from string
	cmp al, 0
	je .done                        ; if char is zero, end of string
	int 0x14                        ; output the character
	jmp short .repeat
.done:
	popa
	ret
; //////////////////////////////////////////////////////////////////////////////


align 16
GDTR32:                             ; GDTR (Global Descriptors Table Register)
dw gdt32_end - gdt32 - 1            ; limit of GDT (size - 1)
dq gdt32                            ; linear address of GDT

gdt32:
dw 0x0000, 0x0000, 0x0000, 0x0000   ; null descriptor
dw 0xFFFF, 0x0000, 0x9A00, 0x00CF   ; 32-bit code descriptor
dw 0xFFFF, 0x0000, 0x9200, 0x00CF   ; 32-bit data descriptor
gdt32_end:

msg_start       db 0x0A, "MBR: ",                   0x00
msg_ok          db "OK",                            0x00
msg_sig_fail    db "FAIL - bad signature",          0x00
msg_read_fail   db "FAIL - failed to read drive",   0x00



times 446-$+$$ db 0x00              ; partition information offset

; false partition table entry (required by some BIOSes)
db 0x80, 0x00, 0x01, 0x00, 0xEB, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF
DriveNumber db 0x00


times 476-$+$$ db 0x00              ; DAP (disk address packet) offset

align 4
DAP:
	db 0x10
	db 0x00
	dw DAP_SECTORS
	dw DAP_ADDRESS
	dw DAP_SEGMENT
	dq DAP_START_SECTOR


times 510-$+$$ db 0x00              ; end of sector offset
dw 0xAA55                           ; magic number for bootable sector

VBE_mode_info_block: equ 0x5C00        ; VESA
; mandatory information for all VBE revisions
VBE_mode_info_block.mode_attributes         equ VBE_mode_info_block + 0    ; DW - mode attributes
VBE_mode_info_block.window_a_attributes     equ VBE_mode_info_block + 2    ; DB - window A attributes
VBE_mode_info_block.window_b_attributes     equ VBE_mode_info_block + 3    ; DB - window B attributes
VBE_mode_info_block.window_granularity      equ VBE_mode_info_block + 4    ; DW - window granularity in KB
VBE_mode_info_block.window_size             equ VBE_mode_info_block + 6    ; DW - window size in KB
VBE_mode_info_block.window_a_segment        equ VBE_mode_info_block + 8    ; DW - window A start segment
VBE_mode_info_block.window_b_segment        equ VBE_mode_info_block + 10   ; DW - window B start segment
VBE_mode_info_block.window_function         equ VBE_mode_info_block + 12   ; DD - real mode pointer to window function
VBE_mode_info_block.bytes_per_scan_line     equ VBE_mode_info_block + 16   ; DW - bytes per scan line
; mandatory information for VBE 1.2 and above
VBE_mode_info_block.x_resolution            equ VBE_mode_info_block + 18   ; DW - horizontal resolution in pixels or characters
VBE_mode_info_block.y_resolution            equ VBE_mode_info_block + 20   ; DW - vertical resolution in pixels or characters
VBE_mode_info_block.x_char_size             equ VBE_mode_info_block + 22   ; DB - character cell width in pixels
VBE_mode_info_block.y_char_size             equ VBE_mode_info_block + 23   ; DB - character cell height in pixels
VBE_mode_info_block.number_of_planes        equ VBE_mode_info_block + 24   ; DB - number of memory planes
VBE_mode_info_block.pixel_depth             equ VBE_mode_info_block + 25   ; DB - bits per pixel
VBE_mode_info_block.number_of_banks         equ VBE_mode_info_block + 26   ; DB - number of banks
VBE_mode_info_block.memory_model            equ VBE_mode_info_block + 27   ; DB - memory model type
VBE_mode_info_block.bank_size               equ VBE_mode_info_block + 28   ; DB - bank size in KB
VBE_mode_info_block.number_of_image_pages   equ VBE_mode_info_block + 29   ; DB - number of image pages
VBE_mode_info_block.reserved_0              equ VBE_mode_info_block + 30   ; DB - reserved (0x00 for VBE 1.0-2.0, 0x01 for VBE 3.0)
; direct color fields (required for direct/6 and YUV/7 memory models)
VBE_mode_info_block.red_mask_size           equ VBE_mode_info_block + 31   ; DB - size of direct color red mask in bits
VBE_mode_info_block.red_field_position      equ VBE_mode_info_block + 32   ; DB - bit position of lsb of red mask
VBE_mode_info_block.green_mask_size         equ VBE_mode_info_block + 33   ; DB - size of direct color green mask in bits
VBE_mode_info_block.green_field_position    equ VBE_mode_info_block + 34   ; DB - bit position of lsb of green mask
VBE_mode_info_block.blue_mask_size          equ VBE_mode_info_block + 35   ; DB - size of direct color blue mask in bits
VBE_mode_info_block.blue_field_position     equ VBE_mode_info_block + 36   ; DB - bit position of lsb of blue mask
VBE_mode_info_block.reserved_mask_size      equ VBE_mode_info_block + 37   ; DB - size of direct color reserved mask in bits
VBE_mode_info_block.reserved_field_position equ VBE_mode_info_block + 38   ; DB - bit position of lsb of reserved mask
VBE_mode_info_block.direct_color_mode       equ VBE_mode_info_block + 39   ; DB - direct color mode attributes
; mandatory information for VBE 2.0 and above
VBE_mode_info_block.physical_base_pointer  equ VBE_mode_info_block + 40   ; DD - physical address for flat memory frame buffer
VBE_mode_info_block.reserved_1             equ VBE_mode_info_block + 44   ; DD - Reserved - always set to 0
VBE_mode_info_block.reserved_2             equ VBE_mode_info_block + 48   ; DD - Reserved - always set to 0
