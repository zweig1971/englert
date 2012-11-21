program mydriver_project;

uses
    WinDrvr in 'e:\windriver\delphi\include\windrvr.pas',
    Bits in 'e:\windriver\delphi\samples\shared\bits.pas',
    Print_Struct in 'e:\windriver\delphi\samples\shared\print_struct.pas',
    WinDrvr_Int_Thread in 'e:\windriver\delphi\include\windrvr_int_thread.pas',
    PCI_Regs in 'e:\windriver\delphi\samples\shared\pci_regs.pas',
    PCI_diag_lib in 'e:\windriver\delphi\samples\shared\pci_diag_lib.pas',
    mydriver_lib in 'mydriver_lib.pas',
    mydriver_diag in 'mydriver_diag.pas';


begin
    main();
end.
