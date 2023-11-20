; //////////////////////////////////////////////////////////////////////////////
; // File:     Name:        uefi.asm                                          //
; //           Language:    x86_64 NASM assembly                              //
; //                                                                          //
; // Details:  this file contains the uefi header so that this loader can run //
; //           natively on modern BOISes                                      //
; //                                                                          //
; // Author:   Name:        Marijn Verschuren                                 //
; //           Email:       email@address.com                                 //
; //                                                                          //
; // Date:     2023-11-18                                                     //
; //////////////////////////////////////////////////////////////////////////////


SCREEN_X_RES    equ 640                                 ; 1024
SCREEN_Y_RES    equ 480                                 ; 768
TIME_STAMP      equ 1670698099                          ; number of seconds since 1970 since when the file was created TODO

SIGNATURE       equ 0x424F4F54

[BITS 64]
[ORG 0x00400000]
%define u(x) __utf16__(x)

START:
PE:
HEADER:
DOS_HEADER:                                             ; 128 bytes
DOS_SIGNATURE:              db 'MZ', 0x00, 0x00         ; the DOS signature
DOS_HEADERS:                times 56 db 0x00            ; the DOS headers
SIGNATURE_POINTER:          dd PE_SIGNATURE - START     ; pointer to the PE signature
DOS_STUB:                   times 64 db 0x00            ; the DOS stub (fill with zeros)
PE_HEADER:                                              ; 24 bytes
PE_SIGNATURE:               db 'PE', 0x00, 0x00         ; this is the PE signature
MACHINE_TYPE:               dw 0x8664                   ; targeting the x86-64 machine
NUMBER_OF_SECTIONS:         dw 2                        ; number of sections, indicates size of section table that immediately follows the headers
CREATED_DATE_TIME:          dd TIME_STAMP
SYMBOL_TABLE_POINTER:       dd 0x00
NUMBER_OF_SYMBOLS:          dd 0
OHEADER_SIZE:               dw O_HEADER_END - O_HEADER  ; size of the optional header
CHARACTERISTICS:            dw 0x222E                   ; attributes of the file TODO: note

O_HEADER:
MAGIC_NUMBER:               dw 0x020B                   ; PE32+ (PE64) magic number
MAJOR_LINKER_VERSION:       db 0
MINOR_LINKER_VERSION:       db 0
SIZE_OF_CODE:               dd CODE_END - CODE          ; the size of the code section
INITIALIZED_DATA_SIZE:      dd DATA_END - DATA          ; size of initialized data section
UNINITIALIZED_DATA_SIZE:    dd 0x00                     ; size of uninitialized data section
ENTRY_POINT_ADDRESS:        dd entry_point - START      ; address of entry point relative to image base when the image is loaded in memory
BASE_OF_CODE_ADDRESS:       dd CODE - START             ; relative address of base of code
IMAGE_BASE:                 dq 0x00400000               ; where in memory we would prefer the image to be loaded at
SECTION_ALIGNMENT:          dd 0x1000                   ; alignment in bytes of sections when they are loaded in memory, align to page boundary to 4KiB
FILE_ALIGNMENT:             dd 0x1000                   ; alignment of sections in the file, align to 4kb
MAJOR_OS_VERSION:           dw 0
MINOR_OS_VERSION:           dw 0
MAJOR_IMAGE_VERSION:        dw 0
MINOR_IMAGE_VERSION:        dw 0
MAJOR_SUBSYS_VERSION:       dw 0
MINOR_SUBSYS_VERSION:       dw 0
WIN32_VERSION_VALUE:        dd 0                        ; reserved, must be 0
IMAGE_SIZE:                 dd END - START              ; the size in bytes of the image when loaded in memory including all headers
HEADERS_SIZE:               dd HEADER_END - HEADER      ; size of all the headers
CHECKSUM:                   dd 0x00
SUBSYSTEM:                  dw 10                       ; the subsystem, in this case we're making a UEFI application.
DLL_CHARACTERISTICS:        dw 0x00
STACK_RESERVE_SIZE:         dq 0x00200000               ; reserve 2MB for the stack
STACK_COMMIT_SIZE:          dq 0x1000                   ; commit 4KB of the stack
HEAP_RESERVE_SIZE:          dq 0x00200000               ; reserve 2MB for the heap
HEAP_COMMIT_SIZE:           dq 0x1000                   ; commit 4KB of heap
LOADER_FLAGS:               dd 0x00                     ; reserved, must be zero
NUMBER_OF_RVA_AND_SIZES:    dd 0x00                     ; number of entries in the data directory
O_HEADER_END:

SECTION_HEADERS:
SECTION_CODE:
.name                       db ".text", 0x00, 0x00, 0x00
.virtual_size               dd CODE_END - CODE
.virtual_address            dd CODE - START
.size_of_raw_data           dd CODE_END - CODE
.pointer_to_raw_data        dd CODE - START
.pointer_to_relocations     dd 0x00
.pointer_to_line_numbers    dd 0x00
.number_of_relocations      dw 0
.number_of_line_numbers     dw 0
.characteristics            dd 0x70000020               ; TODO: note

SECTION_DATA:
.name                       db ".data", 0x00, 0x00, 0x00
.virtual_size               dd DATA_END - DATA
.virtual_address            dd DATA - START
.size_of_raw_data           dd DATA_END - DATA
.pointer_to_raw_data        dd DATA - START
.pointer_to_relocations     dd 0x00
.pointer_to_line_numbers    dd 0x00
.number_of_relocations      dw 0
.number_of_line_numbers     dw 0
.characteristics            dd 0xD0000040               ; TODO: note

HEADER_END:

times 1024-($-PE) db 0x00


CODE:
entry_point:
	; save the values passed by UEFI
	mov [EFI_IMAGE_HANDLE], rcx
	mov [EFI_SYSTEM_TABLE], rdx
	mov [EFI_RETURN], rsp
	sub rsp, 56                                         ; fix stack

	; when calling an EFI function the caller must pass the first 4 integer values in registers
	; via RCX, RDX, R8, and R9 then the rest is put on the stack after the 32 byte shadow space

	; save entry addresses
	mov rax, [EFI_SYSTEM_TABLE]
	mov rax, [rax + EFI_SYSTEM_TABLE_BOOT_SERVICES]
	mov [BS], rax
	mov rax, [EFI_SYSTEM_TABLE]
	mov rax, [rax + EFI_SYSTEM_TABLE_RUNTIME_SERVICES]
	mov [RTS], rax
	mov rax, [EFI_SYSTEM_TABLE]
	mov rax, [rax + EFI_SYSTEM_TABLE_CONFIGURATION_TABLE]
	mov [CONFIG], rax
	mov rax, [EFI_SYSTEM_TABLE]
	mov rax, [rax + EFI_SYSTEM_TABLE_CONSOLE_OUT]
	mov [OUTPUT], rax
	
	; set screen colour attributes
	mov rcx, [OUTPUT]                                   ; EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL* console
	mov rdx, 0x7F                                       ; light grey background, white foreground
	call [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_SET_ATTRIBUTE]

	; clear screen
	mov rcx, [OUTPUT]                                   ; EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL* console
	call [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_CLEAR_SCREEN]

	; find the address of the ACPI data from the UEFI configuration table
	mov rax, [EFI_SYSTEM_TABLE]
	mov rcx, [rax + EFI_SYSTEM_TABLE_NUMBER_OF_ENTRIES]
	shl rcx, 3                                          ; quick multiply by 8 TODO: valid?
	mov rsi, [CONFIG]
next_entry:
	dec rcx
	cmp rcx, 0
	je error                                            ; error if no ACPI data was detected
	mov rdx, [ACPI_TABLE_GUID]                          ; first 64 bits of the ACPI GUID
	lodsq
	cmp rax, rdx                                        ; compare the table data to the expected GUID data
	jne next_entry
	mov rdx, [ACPI_TABLE_GUID+8]                        ; second 64 bits of the ACPI GUID
	lodsq
	cmp rax, rdx                                        ; compare the table data to the expected GUID data
	jne next_entry
	lodsq                                               ; load the address of the ACPI table
	mov [ACPI], rax                                     ; save the address

	; find the interface to GRAPHICS_OUTPUT_PROTOCOL via its GUID
	mov rcx, EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID
	mov rdx, 0                                          ; void* registration (optional)
	mov r8, VIDEO                                       ; void** interface
	mov rax, [BS]
	mov rax, [rax + EFI_BOOT_SERVICES_LOCATE_PROTOCOL]
	call rax
	cmp rax, EFI_SUCCESS
	jne error

	; parse the graphics information
	; mode structure:
	;   0x00: uint32_t                              max_mode
	;   0x04: uint32_t                              mode
	;   0x08: EFI_GRAPHICS_OUTPUT_MODE_INFORMATION* info
	;   0x10: uint64_t                              size_of_info
	;   0x18: EFI_PHYSICAL_ADDRESS                  frame_buffer_base
	;   0x20: uint64_t                              frame_buffer_size
	mov rax, [VIDEO]
	add rax, EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE
	mov rax, [rax]                                      ; RAX holds the address of the mode structure
	mov eax, [rax]                                      ; RAX holds 'max_node'
	mov [video_max], rax
	jmp query_video

next_video_mode:
	mov rax, [video_mode]
	add rax, 1                                          ; increment the mode TODO: check
	mov [video_mode], rax
	mov rdx, [video_max]
	cmp rax, rdx
	je skip_video_mode                                  ; if we have reached the max then exit

query_video:
	mov rcx, [VIDEO]                                    ; EFI_GRAPHICS_OUTPUT_PROTOCOL*             screen
	mov rdx, [video_mode]                               ; uint32_t                                  mode_number
	lea r8, [video_size]                                ; uint64_t*                                 size_of_info
	lea r9, [video_info]                                ; EFI_GRAPHICS_OUTPUT_MODE_INFORMATION**    info
	call [rcx + EFI_GRAPHICS_OUTPUT_PROTOCOL_QUERY_MODE]

	; check mode settings
	mov rsi, [video_info]
	lodsd                                               ; uint32_t                                  version
	lodsd                                               ; uint32_t                                  x_resolution
	cmp eax, SCREEN_X_RES
	jne next_video_mode
	lodsd                                               ; uint32_t                                  y_resolution
	cmp eax, SCREEN_Y_RES
	jne next_video_mode
	lodsd                                               ; EFI_GRAPHICS_PIXEL_FORMAT                 pixel_format (uint32_t)
	bt eax, 0                                           ; bit 0 is set for 32-bit colour mode
	jnc next_video_mode

	; set the video mode
	mov rcx, [VIDEO]                                    ; EFI_GRAPHICS_OUTPUT_PROTOCOL*             screen
	mov rdx, [video_mode]                               ; uint32_t                                  mode_number
	call [rcx + EFI_GRAPHICS_OUTPUT_PROTOCOL_SET_MODE]

skip_video_mode:
	; gather video mode details
	mov rcx, [VIDEO]
	add rcx, EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE
	mov rcx, [rcx]                                      ; RCX holds the address of the mode structure
	mov rax, [rcx + 0x18]                               ; RAX holds the frame_buffer_base
	mov [FB], rax                                       ; save the frame_buffer_base
	mov rax, [rcx + 0x20]                               ; RAX holds the frame_buffer_size
	mov [FBS], rax                                      ; save the frame_buffer_size
	mov rcx, [rcx + 0x08]                               ; RCX holds the address of the EFI_GRAPHICS_OUTPUT_MODE_INFORMATION structure
	; EFI_GRAPHICS_OUTPUT_MODE_INFORMATION structure
	;   0x00: uint32_t                  version
	;   0x04: uint32_t                  y_resolution
	;   0x08: uint32_t                  x_resolution
	;   0x0C: EFI_GRAPHICS_PIXEL_FORMAT pixel_format            (uint32_t)
	;   0x10: EFI_PIXEL_BITMASK         pixel_information       (uint32_t[4] -> red_mask, green_mask, blue_mask, reserved_mask)
	;   0x20: uint32_t                  pixels_per_scan_line    (should be the same as x_resolution)
	mov eax, [rcx + 0x04]                               ; RAX holds the x_resolution
	mov [X_RES], rax                                    ; save the x_resolution
	mov eax, [rcx + 0x08]                               ; RAX holds the y_resolution
	mov [Y_RES], rax                                    ; save the y_resolution

	; copy PAYLOAD to the correct memory address
	mov rsi, PAYLOAD
	mov rdi, 0x8000
	mov rcx, 61440                                      ; copy the 60KiB
	rep movsb
	;start: <- loaded @LOAD_ADDRESS
	;   jmp start32                                     ; jmp 32-bit-address    -> 5 bytes
	;   nop                                             ; nop                   -> 1 byte
	;   dd 0x........                                   ; @(LOAD_ADDRESS + 6)
	mov eax, [0x8006]
	cmp eax, SIGNATURE                                  ; match against loader signature
	jne signature_fail

	; signal to the OS that it was booted via UEFI
	mov al, 'U'
	mov [0x8005], al

	; save video values to the area of memory where the loader expects them
	mov rdi, 0x00005C00 + 0x28                          ; VBE_mode_info_block->physical_base_pointer
	mov rax, [FB]
	stosd
	mov rdi, 0x00005C00 + 0x12                          ; VBE_mode_info_block->x_resolution, VBE_mode_info_block->y_resolution
	mov rax, [X_RES]
	stosw
	mov rax, [Y_RES]
	stosw
	mov rdi, 0x00005C00 + 0x19                          ; VBE_mode_info_block->bits_per_pixel
	mov rax, 32
	stosb

	mov rcx, [OUTPUT]                                   ; EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*  screen
	lea rdx, [ok_message]                               ; int16_t*                          string
	call [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OUTPUT_STRING]

get_memory_map:
	lea rcx, [memory_map_size]                          ; uint64_t*                         memory_map_size
	lea rdx, 0x6000                                     ; EFI_MEMORY_DESCRIPTOR*            memory_map
	lea r8, [memory_map_key]                            ; uint64_t*                         map_key
	lea r9, [memory_map_descriptor_size]                ; uint64_t*                         descriptor_size
	lea r10, [memory_map_descriptor_version]            ; uint32_t*                         descriptor_version
	sub rsp, 32                                         ; shadow space
	push r10
	mov rax, [BS]
	call [rax + EFI_BOOT_SERVICES_GET_MEMORY_MAP]
	pop r10
	add rsp, 32
	cmp al, 5                                           ; EFI_BUFFER_TOO_SMALL
	je get_memory_map                                   ; retry if so
	cmp rax, EFI_SUCCESS
	jne error
	; output at 0x6000 is as follows:
	;   0x00: uint32_t              type
	;   0x08: EFI_PHYSICAL_ADDRESS  physical_start
	;   0x10: EFI_VIRTUAL_ADDRESS   virtual_start
	;   0x18: uint64_t              number_of_pages
	;   0x20: uint64_t              attribute
	;   0x28: uint64_t              blank

	; exit boot services as EFI is no longer needed
	mov rcx, [EFI_IMAGE_HANDLE]                         ; EFI_HANDLE    image_handle
	mov rdx, [memory_map_key]                           ; uint64_t      map_key
	mov rax, [BS]
	call [rax + EFI_BOOT_SERVICES_EXIT_BOOT_SERVICES]
	cmp rax, EFI_SUCCESS
	jne exit_failure

	cli                                                 ; clear interrupts

	; build a 32-bit memory table for 4GiB of identity mapped memory
	mov rdi, 0x200000
	mov rax, 0x00000083
	mov rcx, 1024

next_page:
	stosd
	add rax, 0x400000
	dec rcx
	cmp rcx, 0
	jne next_page

	lgdt [GDTR]                                         ; load the custom GDT

	; switch to compatibility mode
	mov rax, SYS32_CODE_SEL                             ; compatibility mode
	push rax
	lea rax, [compatible_mode]
	push rax
	retfq


[BITS 32]
compatible_mode:
	; set the segment registers
	mov eax, SYS32_DATA_SEL
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax

	; deactivate IA-32e mode by clearing CR0[PG]
	mov eax, cr0
	btc eax, 31                                         ; clear PG (bit 31)
	mov cr0, eax

	; load CR3
	mov eax, 0x00200000                                 ; address of memory map
	mov cr3, eax

	; disable IA-32e mode by setting IA32_EFER[LME] to 0
	mov ecx, 0xC0000080                                 ; EFER MSR number
	rdmsr                                               ; read EFER
	and eax, 0xFFFFFEFF                                 ; clear LME (bit 8)
	wrmsr                                               ; write EFER

	mov eax, 0x00000010                                 ; set PSE (bit 4)
	mov cr4, eax

	; enable legacy paged-protected mode by setting CR0[PG]
	mov eax, 0x00000001                                 ; set PM (bit 0)
	mov cr0, eax

	jmp SYS32_CODE_SEL:0x8000                           ; 32-bit jump to set CS


[BITS 64]
exit_failure:
	mov rdi, [FB]
	mov eax, 0x00FF0000                                 ; red
	mov rcx, [FBS]
	shr rcx, 2                                          ; divide by 4 (32-bit color)
	rep stosd
	jmp halt

error:
	mov rcx, [OUTPUT]                                   ; EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*  console
	lea rdx, [error_message]                            ; int16_t*                          string
	call [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OUTPUT_STRING]
	jmp halt

signature_fail:
	mov rcx, [OUTPUT]                                   ; EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*  console
	lea rdx, [signature_failure_message]                ; int16_t*                          string
	call [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OUTPUT_STRING]

halt:
	hlt
	jmp halt


align 2048
CODE_END:

; data begins here
DATA:
EFI_IMAGE_HANDLE:                                       dq 0x0      ; passed in RCX by EFI
EFI_SYSTEM_TABLE:                                       dq 0x0      ; passed in RDX by EFI
EFI_RETURN:                                             dq 0x0      ; passed in RSP by EFI
BS:                                                     dq 0x0      ; boot services
RTS:                                                    dq 0x0      ; runtime services
CONFIG:                                                 dq 0x0      ; config table address
ACPI:                                                   dq 0x0      ; ACPI table address
OUTPUT:                                                 dq 0x0      ; console output services
VIDEO:                                                  dq 0x0      ; video output services
FB:                                                     dq 0x0      ; frame buffer base address
FBS:                                                    dq 0        ; frame buffer size
X_RES:                                                  dq 0        ; horizontal resolution
Y_RES:                                                  dq 0        ; vertical resolution
memory_map_size:                                        dq 8192
memory_map_key:                                         dq 0x0
memory_map_descriptor_size:                             dq 0
memory_map_descriptor_version:                          dq 0
video_mode:                                             dq 0x0
video_max:                                              dq 0
video_size:                                             dq 0
video_info:                                             dq 0x0

ACPI_TABLE_GUID:                                        ; TODO: note
dd 0xeb9d2d30
dw 0x2d88, 0x11d3
db 0x9a, 0x16, 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d

EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID:                      ; TODO: note
dd 0x9042a9de
dw 0x23dc, 0x4a38
db 0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a

hex_table:                                              db '0123456789ABCDEF'
error_message:                                          dw u('error: '), 0
signature_failure_message:                              dw u('bad signature'), 0
ok_message:                                             dw u('OK'), 0


[ALIGN 16]
GDTR:                                                   ; global descriptors table register
dw GDT_end - GDT - 1                                    ; limit of GDT
dq GDT                                                  ; linear address of GDT


[ALIGN 16]
GDT:
SYS64_NULL_SEL equ $-GDT                                ; NULL segment
dq 0x0000000000000000
SYS32_CODE_SEL equ $-GDT                                ; 32-bit code descriptor
dq 0x00CF9A000000FFFF                                   ; granularity 4KiB, size 32-bit, present, code/data, executable, readable
SYS32_DATA_SEL equ $-GDT                                ; 32-bit data descriptor
dq 0x00CF92000000FFFF                                   ; granularity 4KiB, size 32-bit, present, code/data, writeable
SYS64_CODE_SEL equ $-GDT                                ; 64-bit code segment, read/execute, nonconforming
dq 0x00209A0000000000                                   ; long mode code, present, code/data, executable, readable
SYS64_DATA_SEL equ $-GDT                                ; 64-bit data segment, read/write, expand down
dq 0x0000920000000000                                   ; present, code/data, writable
GDT_end:


[ALIGN 4096]
PAYLOAD:

[ALIGN 65536]                                           ; pad out to 64KiB
DATA_END:
END:

; define the needed EFI constants and offsets here
EFI_SUCCESS                                             equ 0x0
EFI_LOAD_ERROR                                          equ 0x1
EFI_INVALID_PARAMETER                                   equ 0x2
EFI_UNSUPPORTED                                         equ 0x3
EFI_BAD_BUFFER_SIZE                                     equ 0x4
EFI_BUFFER_TOO_SMALL                                    equ 0x5
EFI_NOT_READY                                           equ 0x6
EFI_DEVICE_ERROR                                        equ 0x7
EFI_WRITE_PROTECTED                                     equ 0x8
EFI_OUT_OF_RESOURCES                                    equ 0x9
EFI_VOLUME_CORRUPTED                                    equ 0xA
EFI_VOLUME_FULL                                         equ 0xB
EFI_NO_MEDIA                                            equ 0xC
EFI_MEDIA_CHANGED                                       equ 0xD
EFI_NOT_FOUND                                           equ 0xE

EFI_SYSTEM_TABLE_CONSOLE_OUT                            equ 0x40
EFI_SYSTEM_TABLE_RUNTIME_SERVICES                       equ 0x58
EFI_SYSTEM_TABLE_BOOT_SERVICES                          equ 0x60
EFI_SYSTEM_TABLE_NUMBER_OF_ENTRIES                      equ 0x68
EFI_SYSTEM_TABLE_CONFIGURATION_TABLE                    equ 0x70

EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_RESET                   equ 0x00
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OUTPUT_STRING           equ 0x08
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_TEST_STRING             equ 0x10
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_QUERY_MODE              equ 0x18
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_SET_MODE                equ 0x20
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_SET_ATTRIBUTE           equ 0x28
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_CLEAR_SCREEN            equ 0x30
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_SET_CURSOR_POSITION     equ 0x38
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_ENABLE_CURSOR           equ 0x40
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_MODE                    equ 0x46

EFI_BOOT_SERVICES_GET_MEMORY_MAP                        equ 0x038
EFI_BOOT_SERVICES_LOCATE_HANDLE                         equ 0x0B0
EFI_BOOT_SERVICES_LOAD_IMAGE                            equ 0x0C8
EFI_BOOT_SERVICES_EXIT                                  equ 0x0D8
EFI_BOOT_SERVICES_EXIT_BOOT_SERVICES                    equ 0x0E8
EFI_BOOT_SERVICES_STALL                                 equ 0x0F8
EFI_BOOT_SERVICES_SET_WATCHDOG_TIMER                    equ 0x100
EFI_BOOT_SERVICES_LOCATE_PROTOCOL                       equ 0x140

EFI_GRAPHICS_OUTPUT_PROTOCOL_QUERY_MODE                 equ 0x00
EFI_GRAPHICS_OUTPUT_PROTOCOL_SET_MODE                   equ 0x08
EFI_GRAPHICS_OUTPUT_PROTOCOL_BLOCK_TRANSFER             equ 0x10
EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE                       equ 0x18

EFI_RUNTIME_SERVICES_RESET_SYSTEM                       equ 0x68
