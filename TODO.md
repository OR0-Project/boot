# TODO:
## project
* change all occurrences of email@address.com

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