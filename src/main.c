#include <efi.h>
#include <efilib.h>


/*
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
*/
/*
EFI_STATUS efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
	// InitializeLib(ImageHandle, SystemTable);  => ERROR
	ST = SystemTable;
	ST->ConOut->OutputString(ST->ConOut, L"Only Ring-0 (oR0) Boot Manager.\r\nCopyright (C) oR0 Project 2022.\r\n\r\n");
	return EFI_SUCCESS;
}
 */


EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
	EFI_STATUS status = uefi_call_wrapper(
			SystemTable->ConOut->OutputString,
			2,
			SystemTable->ConOut,
			L"Hello, World!\n"
	);
	return status;
}