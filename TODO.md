# TODO:
## project
* acpi.asm
* pic.ams
* smp.asm
* interrupt.asm
* sysvar.asm
* MakeFile
* test kernel
* test
* 
* change all occurrences of email@address.com
* read: https://wiki.osdev.org/Memory_Map_(x86)
* document @clean_boot.asm:265
* document all the boot code

## code
> ### undefined references
> * cs:GDTR32                           @smp_ap.asm:41
> * GDTR64                              @smp_ap.asm:70, @smp_ap.asm:143
> * IDTR64                              @smp_ap.asm:144
> * SYS64_CODE_SEL                      @smp_ap.asm:93
> * cpu_activated                       @smp_ap.asm:156
> * os_LocalAPICAddress                 @cpu.asm:86, @smp_ap.asm:135, @smp_ap.asm:147, @smp_ap.asm:158
> * gdt64                               @clean_boot.asm:140, @clean_boot.asm:142
> * gdt64_end                           @clean_boot.asm:142

> ### commented
> * variable sized address ranges       @cpu.asm:37
> * global paging extensions            @cpu.asm:65
> * local vector table (LVT)            @cpu.asm:109

> ### TODOs
> * TODO: fix this as it is a terrible hack (uefi memory map)                   @clean_boot.asm:320
> * TODO: this isn't the exact math but good enough (page directory table)      @clean_boot.asm:331
> * serial boot message                                                         @clean_boot.asm:533