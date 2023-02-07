#include <efi.h>
#include <efilib.h>

// void cpuid(int32_t *peax, int32_t *pebx, int32_t *pecx, int32_t *pedx)
// {
//     __asm(
//         "CPUID"
//         : "=a"(*peax), "=b"(*pebx), "=c"(*pecx), "=d"(*pedx)
//         : "a"(*peax)
//     );
// }

void draw_menu() {
    ST->ConOut->OutputString(ST->ConOut, L"╔══════════════════════════════════════════╗\r\n");
    ST->ConOut->OutputString(ST->ConOut, L"║ Only Ring-0   --   Boot Menu             ║\r\n");
    ST->ConOut->OutputString(ST->ConOut, L"╠══════════════════════════════════════════╣\r\n");
    ST->ConOut->OutputString(ST->ConOut, L"║ 1. Start Operating System                ║\r\n");
    ST->ConOut->OutputString(ST->ConOut, L"║                                          ║\r\n");
    ST->ConOut->OutputString(ST->ConOut, L"║ 2. Shut-Down                             ║\r\n");
    ST->ConOut->OutputString(ST->ConOut, L"║                                          ║\r\n");
    ST->ConOut->OutputString(ST->ConOut, L"║ 3. Reboot                                ║\r\n");
    ST->ConOut->OutputString(ST->ConOut, L"╚══════════════════════════════════════════╝\r\n");
}

EFI_STATUS efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
    EFI_STATUS Status;
    EFI_INPUT_KEY Key;
 
    /* Store the system table for future use in other functions */
    ST = SystemTable;
 
    // Clear console
    Status = ST->ConOut->ClearScreen(ST->ConOut);
    
    if (EFI_ERROR(Status))
        return Status;
 
    ST->ConOut->OutputString(ST->ConOut, L"Only Ring-0 (oR0) Boot Manager.\r\nCopyright (C) oR0 Project 2022.\r\n\r\n");

    // Draw the menu
    draw_menu();

    /* Now wait for a keystroke before continuing, otherwise your
       message will flash off the screen before you see it.
 
       First, we need to empty the console input buffer to flush
       out any keystrokes entered before this point */
    Status = ST->ConIn->Reset(ST->ConIn, FALSE);

    if (EFI_ERROR(Status))
        return Status;

    /* Now wait until a key becomes available.  This is a simple
       polling implementation.  You could try and use the WaitForKey
       event instead if you like */
    while ((Status = ST->ConIn->ReadKeyStroke(ST->ConIn, &Key)) == EFI_NOT_READY) ;
 
    return Status;
}