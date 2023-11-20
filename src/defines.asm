; //////////////////////////////////////////////////////////////////////////////
; // File:     Name:        defines.asm                                       //
; //           Language:    x86_64 NASM assembly                              //
; //                                                                          //
; // Details:  this file contains all required defines                        //
; //                                                                          //
; //                                                                          //
; // Author:   Name:        Marijn Verschuren                                 //
; //           Email:       email@address.com                                 //
; //                                                                          //
; // Date:     2023-11-20                                                     //
; //////////////////////////////////////////////////////////////////////////////


message:                                db 10, 'OS - OK', 10

; configuration
config_smp:                             db 1                            ; smp is enabled by default

; memory mapping
IDT:                                    equ 0x0000000000000000
GDT:                                    equ 0x0000000000001000
E820_map:                               equ 0x0000000000004000
info_map:                               equ 0x0000000000005000
system_variables:                       equ 0x0000000000005A00
VBE_mode_info:                          equ 0x0000000000005C00
mapping_end:                            equ 0x0000000000005D00


[ALIGN 16]
GDTR32:                                 ; 32-bit global descriptors table register
dw GDT32_end - GDT32 - 1                ; limit of GDT (size - 1)
dq GDT32                                ; linear address of GDT

GDT32:
dq 0x0000000000000000                   ; null descriptor
dq 0x00CF9A000000FFFF                   ; 32-bit code descriptor -> granularity 4KiB, size 32-bit, present, code/data, executable, readable
dq 0x00CF92000000FFFF                   ; 32-bit data descriptor -> granularity 4KiB, size 32-bit, present, code/data, writeable
GDT32_end:

GDTR64:                                 ; 64-bit global descriptors table register
dw GDT64_end - GDT64 - 1                ; limit of GDT (size - 1)
dq GDT                                  ; linear address of GDT (0x0000000000001000)

GDT64:                                  ; copied to the correct location later on
SYS64_NULL_SEL equ $-GDT64              ; null Segment
dq 0x0000000000000000
SYS64_CODE_SEL equ $-GDT64              ; Code segment, read/execute, nonconforming
dq 0x00209A0000000000                   ; long mode code, present, code/data, executable, readable
SYS64_DATA_SEL equ $-GDT64              ; data segment, read/write, expand down
dq 0x0000920000000000                   ; present, code/data, writable
GDT64_end:

IDTR64:                                 ; 64-bit interrupt descriptor table register
dw 256*16-1                             ; limit of IDT (size - 1) (256 entries of size 16)
dq IDT                                  ; linear address of IDT (0x0000000000000000)


; system_variable table
os_ACPI_table_address:                  equ system_variables + 0x00
os_local_X2_APIC_address:               equ system_variables + 0x10
os_timer_counter:                       equ system_variables + 0x18
os_RTC_counter:                         equ system_variables + 0x20
os_local_APIC_address:                  equ system_variables + 0x28
os_IO_APIC_address:                     equ system_variables + 0x30
os_HPET_address:                        equ system_variables + 0x38

os_BSP:                                 equ system_variables + 0x80
memory_size:                            equ system_variables + 0x84     ; in MiB

cpu_speed:                              equ system_variables + 0x100
cpu_activated:                          equ system_variables + 0x102
cpu_detected:                           equ system_variables + 0x104

os_IO_APIC_count:                       equ system_variables + 0x180
boot_mode:                              equ system_variables + 0x181    ; 'U' if UEFI


; mandatory information for all VBE revisions
VBE_mode_info.mode_attributes           equ VBE_mode_info + 0x00        ; DW - mode attributes
VBE_mode_info.window_a_attributes       equ VBE_mode_info + 0x02        ; DB - window A attributes
VBE_mode_info.window_b_attributes       equ VBE_mode_info + 0x03        ; DB - window B attributes
VBE_mode_info.window_granularity        equ VBE_mode_info + 0x04        ; DW - window granularity in KB
VBE_mode_info.window_size               equ VBE_mode_info + 0x06        ; DW - window size in KB
VBE_mode_info.window_a_segment          equ VBE_mode_info + 0x08        ; DW - window A start segment
VBE_mode_info.window_b_segment          equ VBE_mode_info + 0x0A        ; DW - window B start segment
VBE_mode_info.window_function           equ VBE_mode_info + 0x0C        ; DD - real mode pointer to window function
VBE_mode_info.bytes_per_scan_line       equ VBE_mode_info + 0x10        ; DW - bytes per scan line
; mandatory information for VBE 1.2 and above
VBE_mode_info.x_resolution              equ VBE_mode_info + 0x12        ; DW - horizontal resolution in pixels or characters
VBE_mode_info.y_resolution              equ VBE_mode_info + 0x14        ; DW - vertical resolution in pixels or characters
VBE_mode_info.x_char_size               equ VBE_mode_info + 0x16        ; DB - character cell width in pixels
VBE_mode_info.y_char_size               equ VBE_mode_info + 0x17        ; DB - character cell height in pixels
VBE_mode_info.number_of_planes          equ VBE_mode_info + 0x18        ; DB - number of memory planes
VBE_mode_info.pixel_depth               equ VBE_mode_info + 0x19        ; DB - bits per pixel
VBE_mode_info.number_of_banks           equ VBE_mode_info + 0x1A        ; DB - number of banks
VBE_mode_info.memory_model              equ VBE_mode_info + 0x1B        ; DB - memory model type
VBE_mode_info.bank_size                 equ VBE_mode_info + 0x1C        ; DB - bank size in KB
VBE_mode_info.number_of_image_pages     equ VBE_mode_info + 0x1D        ; DB - number of image pages
VBE_mode_info.reserved_0                equ VBE_mode_info + 0x1E        ; DB - reserved (0x00 for VBE 1.0-2.0, 0x01 for VBE 3.0)
; direct color fields (required for direct/6 and YUV/7 memory models)
VBE_mode_info.red_mask_size             equ VBE_mode_info + 0x1F        ; DB - size of direct color red mask in bits
VBE_mode_info.red_field_position        equ VBE_mode_info + 0x20        ; DB - bit position of lsb of red mask
VBE_mode_info.green_mask_size           equ VBE_mode_info + 0x21        ; DB - size of direct color green mask in bits
VBE_mode_info.green_field_position      equ VBE_mode_info + 0x22        ; DB - bit position of lsb of green mask
VBE_mode_info.blue_mask_size            equ VBE_mode_info + 0x23        ; DB - size of direct color blue mask in bits
VBE_mode_info.blue_field_position       equ VBE_mode_info + 0x24        ; DB - bit position of lsb of blue mask
VBE_mode_info.reserved_mask_size        equ VBE_mode_info + 0x25        ; DB - size of direct color reserved mask in bits
VBE_mode_info.reserved_field_position   equ VBE_mode_info + 0x26        ; DB - bit position of lsb of reserved mask
VBE_mode_info.direct_color_mode         equ VBE_mode_info + 0x27        ; DB - direct color mode attributes
; mandatory information for VBE 2.0 and above
VBE_mode_info.physical_base_pointer     equ VBE_mode_info + 0x28        ; DD - physical address for flat memory frame buffer
VBE_mode_info.reserved_1                equ VBE_mode_info + 0x2C        ; DD - reserved - always set to 0
VBE_mode_info.reserved_2                equ VBE_mode_info + 0x30        ; DD - reserved - always set to 0
