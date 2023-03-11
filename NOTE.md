# Clean Boot Technical SPEC
## Memory Map
this memory map shows how physical memory looks after boot

| Start Address      | End Address        | Size    | Description                                                        |
|--------------------|--------------------|---------|--------------------------------------------------------------------|
| 0x0000000000000000 | 0x0000000000000FFF | 4   KiB | IDT -        256 descriptors (each descriptor is 16 bytes)         |
| 0x0000000000001000 | 0x0000000000001FFF | 4   KiB | GDT -        256 descriptors (each descriptor is 16 bytes)         |
| 0x0000000000002000 | 0x0000000000002FFF | 4   KiB | PML4 -       512 entries     (first entry points to PDP at 0x3000) |
| 0x0000000000003000 | 0x0000000000003FFF | 4   KiB | PDP low -    512 entries                                           |
| 0x0000000000004000 | 0x0000000000004FFF | 4   KiB | PDP high -   512 entries                                           |
| 0x0000000000005000 | 0x0000000000007FFF | 12  KiB | clean boot data                                                    |
| 0x0000000000008000 | 0x000000000000FFFF | 32  KiB | clean boot - when the OS is running this memory is free            |
| 0x0000000000010000 | 0x000000000001FFFF | 64  KiB | PD low -     entries are 8 bytes per 2MiB page                     |
| 0x0000000000020000 | 0x000000000005FFFF | 256 KiB | PD high -    entries are 8 bytes per 2MiB page                     |
| 0x0000000000060000 | 0x000000000009FFFF | 256 KiB | free                                                               |
| 0x00000000000A0000 | 0x00000000000FFFFF | 384 KiB | ROM                                                                |
| ROM + 0x0000000000 | ROM + 0x0000018000 | 128 KiB | VGA                                                                |
| ROM + 0x0000018000 | ROM + 0x0000020000 | 8   KiB | VGA color text                                                     |
| ROM + 0x0000020000 | ROM + 0x0000030000 | 64  KiB | BIOS video                                                         |
| ROM + 0x0000050000 | ROM + 0x0000060000 | 64  KiB | motherboard BIOS                                                   |
| 0x0000000000100000 | 0xFFFFFFFFFFFFFFFF | ~16 EiB | free                                                               |

when creating your operating system you can use any memory area marked as free, however it is recommended that the memory at `0x0000000000100000` is used


## Information Table
clean boot stores an information table in memory that contains various pieces of data about the computer before it passes control over to the kernel
the information table is located at `0x0000000000005000` and ends at `0x00000000000057FF` (2 KiB)

| Address | Size   | Name          | Description                                                                 |
|---------|--------|---------------|-----------------------------------------------------------------------------|
| 0x5000  | 64-bit | ACPI          | address of the ACPI tables                                                  |
| 0x5008  | 32-bit | BSP_ID        | APIC ID of the BSP                                                          |
| 0x5010  | 16-bit | CPU_SPEED     | clock speed of the CPUs in Mega Hertz (MHz)                                 |
| 0x5012  | 16-bit | CORES_ACTIVE  | the number of active CPU cores                                              |
| 0x5014  | 16-bit | CORES_DETECT  | the number of detected CPU cores                                            |
| 0x5016  | 10  B  | reserved      |                                                                             |
| 0x5020  | 32-bit | RAM_SIZE      | amount of system RAM in Mebibytes (MiB)                                     |
| 0x5024  | 12  B  | reserved      |                                                                             |
| 0x5030  | 8-bit  | IO_APIC_COUNT | number of IO-APICs                                                          |
| 0x5031  | 15  B  | reserved      |                                                                             |
| 0x5040  | 64-bit | HPET          | base memory address for the High Precision Event Timer                      |
| 0x5048  | 24  B  | reserved      |                                                                             |
| 0x5060  | 64-bit | LOCAL_APIC    | local APIC address                                                          |
| 0x5068  | 24  B  | IO_APIC       | IO-APIC addresses (up to 3 entries, based on IO_APIC_COUNT)                 |
| 0x5080  | 32-bit | VIDEO_BASE    | video memory base (in graphics mode)                                        |
| 0x5084  | 16-bit | VIDEO_WIDTH   | video width                                                                 |
| 0x5086  | 16-bit | VIDEO_HEIGHT  | video height                                                                |
| 0x5088  | 8-bit  | VIDEO_DEPTH   | video color depth                                                           |
| 0x5089  | 119 B  | reserved      |                                                                             |
| 0x5100  | 768 B  | APIC_ID       | APIC ID's for the valid CPU cores (up to 768 entries based on CORES_ACTIVE) |
| 0x5400  | 1 KiB  | reserved      |                                                                             |

a copy of the E820 system memory map is stored at memory address `0x0000000000006000`
each record is 32 bytes and the map is terminated with a blank record
for more information on the E820 Memory Map: <a href="http://wiki.osdev.org/Detecting_Memory_%28x86%29">OSDev wiki on E820</a>

| Variable            | Variable Size | Description                                       |
|---------------------|---------------|---------------------------------------------------|
| starting address    | 64-bit        | the memory address                                |
| length              | 64-bit        | the length of the allocated memory at the address |
| memory type         | 32-bit        | 1 = usable_memory, 2 = non_usable_memory          |
| extended attributes | 32-bit        | ACPI 3.0 extended attributes bitfield             |
| padding             | 32-bit        | padding for 32-byte alignment                     |


## Memory-Type Range Registers (MTRR) Notes
| Address                   | Size      |
|---------------------------|-----------|
| Base + 0x0000000000000000 | 0     MiB |
| Base + 0x0000000080000000 | 2048  MiB |
| Base + 0x0000000100000000 | 4096  MiB |
| Mask + 0x0000000F80000000 | 2048  MiB |
| Mask + 0x0000000FC0000000 | 1024  MiB |
| Mask + 0x0000000FFC000000 | 64    MiB |