unit DATECH_0;      {Eine zusÑtzliche Datentechnik Library TURBO PASCAL V 7.0}
{
  Changes:
  19.11.97      Wegen Codegrenzen von Datech_1.pas neue Lib angelegt
                Hier hauptsÑchlich Modulbus-Routinen
  20.11.97      Byte u. Bits
  01.12.97      Mod24bit I/O Skalierung

}
{$S-}
interface                 { Teil der UNIT-Deklaration }
uses Crt, {WinDos,} Graph, Dos, Datech, Datech_1;   {graph, dos wegen cursor}

                 {Proceduren der Au·enwelt bekanntmachen}
procedure Telefon;
procedure Mil_Ask_Mod;    {Frage User nach I/O-Modul-Adresse}
procedure Modul_Bus;
procedure Check_ModBus_Ifk (Ifk_Nr: Byte; var Ret_Code: TIfk_IdErr);
procedure Ask_Ifc_Mod_Adr;

implementation                                    {Teil der UNIT-Deklaration}
 procedure Telefon;
  begin
   Ini_Text_Win;
   TextColor (Brown);
   GotoXY (20,01); Writeln (' Telefonliste mit wichtigen Service-Nummern');
   TextColor (Yellow);
   GotoXY (01,02); WriteLn (' HKR-UNILAC: 2222           HKR-SIS: 2221/2244             HKR-ESR: 2245/2315');
   TextColor (Blue);
   GotoXY (01,03); Writeln (' NAME                       TEL         PSA    RAUM         ABTEILUNG');
   TextColor (Brown);
                   Write (' Behr, Karl Heinz           ');                         TextColor(Black);
                                                       Writeln('2732/2730   8621   2.272  OS      KC     ');  TextColor(Brown);
                   Write (' Bock, Walter               ');                         TextColor(Black);
                                                       Writeln('2357/2353   3571   2.111  Nord    EET    ');  TextColor(Brown);
                   Write (' Breitenberger, Gerhard     ');                         TextColor(Black);
                                                       Writeln('2377        5271   2.146  Nord    EET    ');  TextColor(Brown);
                   Write (' Dick, Gerhard              ');                         TextColor(Black);
                                                       Writeln('2357/2353   3521   2.111  Nord    EET    ');  TextColor(Brown);
                   Write (' Fischer, Herbert           ');                         TextColor(Black);
                                                       Writeln('2357/2353   5301   2.007  SH4     EET    ');  TextColor(Brown);
                   Write (' Gro·, Hubert               ');                         TextColor(Black);
                                                       Writeln('2362               2.118  Nord    BELAB  ');  TextColor(Brown);
                   Write (' Hartmann, Rolf             ');                         TextColor(Black);
                                                       Writeln('2362               2.118  Nord    BELAB  ');  TextColor(Brown);
                   Write (' Hechler, Ludwig            ');                         TextColor(Black);
                                                       Writeln('2391/2267          2.161  Nord    PR     ');  TextColor(Brown);
                   Write (' Kainberger, Peter          ');                         TextColor(Black);
                                                       Writeln('2341/2267   3891   2.160  Nord    Fremdfirma');
TextColor(Brown);  Write (' Krause, Udo                ');                         TextColor(Black);
                                                       Writeln('2387        6301   2.158a Nord    PR    ');   TextColor(Brown);
                   Write (' KÅhn, Maria                ');                         TextColor(Black);
                                                       Writeln('2391/2267          2.161  Nord    BELAB  ');  TextColor(Brown);
                   Write (' Matthîfer, Karl-Heinz      ');                         TextColor(Black);
                                                       Writeln('2357/2353   3551   2.111  Nord    EET    ');  TextColor(Brown);
                   Write (' Ninov, Viktor              ');                         TextColor(Black);
                                                       Writeln('2735/2736          2.275  OS      KC     ');  TextColor(Brown);
                   Write (' Ramakers, Heinz            ');                         TextColor(Black);
                                                       Writeln('2377        3771   2.146  Nord    EET    ');  TextColor(Brown);
                   Write (' Riehl, GÅnther             ');                         TextColor(Black);
                                                       Writeln('2390               2.160  Nord    PR     ');  TextColor(Brown);
                   Write (' Steck, Markus              ');                         TextColor(Black);
                                                       Writeln('2406               3.009  Nord    ESR    ');  TextColor(Brown);
                   Write ('    "   (HKR)               ');                         TextColor(Black);
                                                       Writeln('2315                                     ');  TextColor(Brown);
                   Write (' Steiner, Rudolf            ');                         TextColor(Black);
                                                       Writeln('2392        3691   2.165  Nord    BEL    ');  TextColor(Brown);
                   Write (' Werkmann, Reinhold         ');                         TextColor(Black);
                                                       Writeln('2364               2.118  Nord    BELAB  ');  TextColor(Brown);

   Ini_Msg_Win;
   Write ('                                                 Weiter mit beliebiger Taste!!');
   repeat until KeyEPressed;
  end; {Telefon}

   procedure Displ_Mod_Headline;
    begin
     Ini_Text_Win; TextColor(Blue);
     GotoXY(15,01); write('----- Finde IFC-Karten, I/O-Module und Ident -----');
     Set_Color_Alarm;
     GotoXY(01,02); write('IFC-Adr Modul-Adr  Ident Card  VG   Skl MoAdr  EPLD Frei  Sta2 Sta1  Sta4 Sta3');
     Set_Color_Norm;
     TextColor(Brown);
     GotoXY(01,03); write(' [Hex]    [Hex]    [Dez]-<FE  FF>   <FC  FD>   <FA  FB>   <F8  F9>   <F6  F7>');
     Ini_Msg_Win;
     Write('Weiter mit  <SPACE>,  Ende mit [X]');
     Set_Text_Win;
    end;

 procedure Mil_Displ_IO_Modul;
   LABEL 99;
   const  Z_Mod_Start = 4;
          Z_Mod_Max   = 18-Z_Mod_Start; {Max. Zeilen TextWindow minus Start-Zeile}
   VAR
     error_cnt : LONGINT;

     MilErr    : TMilErr;
     Fct       : TFct;
     Rcv_Data  : Word;
     M         : Byte;
     I         : Byte;
     Mod_Zeile : Word;

     Ifb_Online: ARRAY [1..255] OF BOOLEAN;
     Ifb_Adr   : Word;
     Ifc_Total : Word;
     Mod_Total : Word;
     Mod_RetAdr: Byte;
     Id_Dez    : Byte;
     Mod_Err   : TOnlineErr;
     Life_Mode   : TLife_XY;

   procedure Displ_Mod_Info (Ifc_Adr: Byte; Mod_Adr: Byte; Z_Mod: Byte);
    const S_Mod_ID_Dta  = 28;      {Default Spalte fÅr Modulidentdaten}
    var   IOsub_Adr    : Byte;
          Fct_11_Dta   : Word;
          S_Mod_Akt    : Byte;
          V            : Byte;
    begin
     Set_Text_Win;
     S_Mod_Akt := S_Mod_ID_Dta;
     GotoXY(04,Z_Mod); write(Hex_Byte(Ifc_Adr),'       ',Hex_Byte(Mod_Adr));
     IOsub_Adr := $FE;                           {Word-Adr fÅr Identdaten}

     for V := 1 to 5  do                         {Lese 3 Worte mit Identdaten}
      begin
        Fct.B.Adr  := Ifc_Adr;
        Fct_11_Dta:= (Mod_Adr*256) + IOsub_Adr;  {Modul-Adr ins Hibyte, Subadr Lowbyte}
        Fct.B.Fct  := Fct_Wr_Iob_Adr;
        Mil.Wr (Fct_11_Dta, Fct, MilErr);                     {Adr zum I/O-Bus}

        Fct.B.Fct  :=  Fct_Rd_Iob_Dta;             {Lesen Daten von APL-IO-Bus}
        Mil.Rd (Read_Data, Fct, MilErr);

        if (IOsub_Adr = $FE) then                  {ID auch dezimal ausgeben}
         begin
          GotoXY(S_Mod_Akt-7,Z_Mod);
          Id_Dez := (Read_Data and $FF00) shr 8;
          Write (Id_Dez:3);
         end;

        GotoXY(S_Mod_Akt,Z_Mod);
        Write (hex_word(Read_Data));
        S_Mod_Akt := S_Mod_Akt + 11;
        IOsub_Adr := IOsub_Adr - 2;
      end; {Displ_Mod_Info}
   end; {Displ_Mod_Info}

   Begin
    Life_Mode.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
    Life_Mode.PosX    := 01;        {02;}
    Life_Mode.PosY    := 01;        {12;}
    Life_Mode.Time    := Life_Time_Fast;
    Life_Mode.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}
    Life_Sign_XY (Life_Mode);

    transf_cnt := 0;
    error_cnt  := 0;
    timout_wr  := 0;
    Ifc_Total  := 0;
    Mod_Total  := 0;

    Ini_Text_Win;
    Mil_Ask_Ifc;
    Ini_Text_Win;
    Displ_Mod_Headline;
    Mod_Zeile := Z_Mod_Start;
    Ifb_Adr   := Ifc_Test_Nr;
    Std_Msg;
    Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
        Std_Msg;
        Single_Step := True;
        Set_Text_win; {Damit énderungen bemerkt werden: Display lîschen!!}
        for I := Z_Mod_Start to (Z_Mod_Max)  do
         begin
          GotoXY (01, I); ClrEol;
         end;
        M := 0;
        repeat
         M := M + 1;                   {alle mîglichen Modul-Adr abfragen}
         Mil.Mod_Online (Ifb_Adr, M, Mod_RetAdr, Mod_Err);
         If Mod_Err = NoErr then
          begin
            Displ_Mod_Info (Ifb_Adr, M, Mod_Zeile);
            Mod_Zeile := Mod_Zeile + 1;
            if (Mod_Zeile mod 23) = 0 then Mod_Zeile := Z_Mod_Start;
          end;

         if M > $1F then
           begin
             M := 0;
             Mod_Zeile := Z_Mod_Start;
           end;
         until M=0;
       Life_Sign_XY (Life_Mode);
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;
     if not Single_Step then
      begin
       M := 0;
       repeat
         M := M + 1;                   {alle mîglichen Modul-Adr abfragen}
         Mil.Mod_Online (Ifb_Adr, M, Mod_RetAdr, Mod_Err);
         If Mod_Err = NoErr then
          begin
            Displ_Mod_Info (Ifb_Adr, M, Mod_Zeile);
            Mod_Zeile := Mod_Zeile + 1;
            if (Mod_Zeile mod 23) = 0 then Mod_Zeile := Z_Mod_Start;
          end;

         if M > $1F then
           begin
             M := 0;
             Mod_Zeile := Z_Mod_Start;
           end;
        until M=0;
        Life_Sign_XY (Life_Mode);
       Set_Text_win;               {Damit énderungen bemerkt werden: }
       Mil.Timer2_Wait (10000);    {Display jedesmal lîschen!! }
       for I := Z_Mod_Start to (Z_Mod_Max) do
        begin
         GotoXY (01, I); ClrEol;
        end;
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
 99:  Cursor(True);
 end; {Mil_Displ_IO_Modul;}


 procedure Modul_Ident_List;
  const Z_Base = 6;
  begin
    Ini_Text_Win;
    TextColor(Yellow);
    GotoXY (20,Z_Base-4);  Write ('Liste der I/O-Karten Identkodes fÅr den MODUL-BUS: ');
    TextColor(Brown);
    GotoXY (02,Z_Base-3);  Write (' v-- Kode --v            ');
    GotoXY (02,Z_Base-2);  Write (' [Dez]  [Hex]   Beschreibung ');
    TextColor(Blue);
    GotoXY (02,Z_Base-1);  Write ('( 06     06)    ModulBus-Piggy fÅr FG 380.20x Ident lesen mit Fct 8E [H])!');
    GotoXY (02,Z_Base  );  Write ('(204     FD)    IFK fÅr Modulbus   FG 450.012 Ident lesen mit Fct CC [H])!');
    TextColor(Black);

    GotoXY (02,Z_Base+2);  Write ('  31     1F     FG 450.310 Schaltkarte                ');
    GotoXY (02,Z_Base+3);  Write ('  32     20     FG 450.320 Digital I/O                ');
    GotoXY (02,Z_Base+4);  Write ('  33     21     FG 450.330 Status-Karte               ');
    GotoXY (02,Z_Base+5);  Write ('  34     22     FG 450.340 Analog I/O (+/-10V) mit Mux');
    GotoXY (02,Z_Base+6);  Write ('  35     23     FG 450.350 12-fach Event-Generator    ');
    Ini_Msg_Win;
    Write ('Weiter mit <Space> ');
    Ch := NewReadKey;
  end;

 procedure Check_ModBus_Ifk (Ifk_Nr: Byte; var Ret_Code: TIfk_IdErr);
   { IfkID_450012    = $FD spezielle IFK fÅr Modulbus: lesen mit Fct CC[H] }
   { ModBus_Ifk_Pigy = $06 :IFK 380.201 mit Modulbus-Piggy       Fct 8E[H] }
  var Id_Data     : Word;
      Id_Pigy_Data: Word;
      MilErr      : TMilErr;
      Fct         : TFct;
  begin
    Ret_Code   := NoIdErr;
    Fct.B.Adr  := Ifk_Nr;
    Fct.B.Fct  := Fct_Rd_Ifk_ID;        {Lese Ident der IFK}
    Mil.Rd (Id_Data, Fct, MilErr);
    if MilErr = No_Err then
     begin
      if Ifc_Test_Nr <> Lo (Id_Data) then
       begin
        Ret_Code := IfkAdr;
        Exit;
       end;

      if not (Ifk_ID_ModBus = Hi(Id_Data)) then
       begin                  {keine modulbusfÑhige IFK FG450.012 vorhanden!}
         Fct.B.Fct  := Fct_Rd_Ident;         {Ident fÅr IFK-Piggy lesen}
         Mil.Rd (Id_Data, Fct, MilErr);
         if MilErr = No_Err then
          begin                              {ist IFK mit Modulbus-Piggy da?}
            if not (Ifk_Pigy_ModBus = Lo (Id_Data)) then
             begin                           {kein IFK-Piggy fÅr Modulbus da}
               Ret_Code := IfkID;
               Exit;
             end;
          end
         else
          begin
            Ret_Code := MilRd;
          end;
       end; {if not IfkID_45001}
     end
    else
     begin
       Ret_Code := MilRd;
     end;  {if MilErr bei Lesen des Ident der IFK}
  end; {Check_ModBus_Ifk}

 procedure Mil_Detect_IO_Modul;
   LABEL 99;
   const  Z_Mod_Start = 4;
   VAR
     error_cnt : LONGINT;
     MilErr    : TMilErr;
     Fct       : TFct;
     Rcv_Data  : Word;
     M         : Byte;
     I         : Byte;
     Mod_Zeile : Word;

     Ifb_Online: ARRAY [1..255] OF BOOLEAN;
     Ifb_Adr   : Word;
     Ifc_Total : Word;
     Mod_Total : Word;
     Id_Dez    : Byte;
     RetAdr     : Byte;
     OnlineErr  : TOnlineErr;
     Mod_RetAdr: Byte;
     Mod_Err   : TOnlineErr;

   procedure Displ_Mod_Info (Ifc_Adr: Byte; Mod_Adr: Byte; Z_Mod: Byte);
    const S_Mod_ID_Dta  = 28;      {Default Spalte fÅr Modulidentdaten}
    var   IOsub_Adr    : Byte;
          Fct_11_Dta   : Word;
          S_Mod_Akt    : Byte;
          V            : Byte;
    begin
     Set_Text_Win;
     S_Mod_Akt := S_Mod_ID_Dta;
     GotoXY(04,Z_Mod); write(Hex_Byte(Ifc_Adr),'       ',Hex_Byte(Mod_Adr));
     IOsub_Adr := $FE;                               {Word-Adr fÅr Identdaten}

     for V := 1 to 5  do                         {Lese 3 Worte mit Identdaten}
      begin
        Fct.B.Adr  := Ifc_Adr;
        Fct_11_Dta:= (Mod_Adr*256) + IOsub_Adr;  {Modul-Adr ins Hibyte, Subadr Lowbyte}
        Fct.B.Fct  := Fct_Wr_Iob_Adr;
        Mil.Wr (Fct_11_Dta, Fct, MilErr);                     {Adr zum I/O-Bus}

        Fct.B.Fct  :=  Fct_Rd_Iob_Dta;             {Lesen Daten von APL-IO-Bus}
        Mil.Rd (Read_Data, Fct, MilErr);
        if (IOsub_Adr = $FE) then                  {ID auch dezimal ausgeben}
         begin
          GotoXY(S_Mod_Akt-7,Z_Mod);
          Id_Dez := (Read_Data and $FF00) shr 8;
          Write (Id_Dez:3);
         end;

        GotoXY(S_Mod_Akt,Z_Mod);
        Write (hex_word(Read_Data));
        S_Mod_Akt := S_Mod_Akt + 11;
        IOsub_Adr := IOsub_Adr - 2;
      end; {Displ_Mod_Info}
   end; {Displ_Mod_Info}

   Begin
    transf_cnt := 0;
    error_cnt  := 0;
    timout_wr  := 0;
    Ifc_Total  := 0;
    Mod_Total  := 0;

    for ifb_adr := 1 to 255 do Ifb_Online[ifb_adr] := False;
    FOR ifb_adr := 1 TO 255 DO
     Begin
      mil.ifc_online (ifb_adr, RetAdr, OnlineErr);
      if OnlineErr = NoErr then
       Begin
        ifb_online[ifb_adr] := TRUE;
        ifc_total := ifc_total + 1;
       End;
    End;

    Ini_Text_Win;
    Displ_Mod_Headline;
    Ini_Msg_Win;
    Write('Weiter mit  <SPACE>,  Ende mit [X]');

    Set_Text_Win;
    M := 0;
    Ifb_Adr := 1;
    Mod_Zeile := Z_Mod_Start;

     repeat
       Set_Text_win;
       if ifb_online [ifb_adr] then
         begin
           for M := 0 to ModAdr_Max do   {alle erlaubten Modul-Adr abfragen}
             begin
              Mil.Mod_Online (Ifb_Adr, M, Mod_RetAdr, Mod_Err);
              If Mod_Err = NoErr then
                 begin
                   Mod_Total := Mod_Total + 1 ;
                   Displ_Mod_Info (Ifb_Adr, M, Mod_Zeile);
                   Mod_Zeile := Mod_Zeile + 1;
                   if (Mod_Zeile mod 21) = 0 then
                    begin
                      Mod_Zeile := Z_Mod_Start;
                      repeat until KeyPressed;
                      Ini_Text_Win;
                      Displ_Mod_Headline;
                      Ini_Msg_Win;
                      Write('Weiter mit  <SPACE>,  Ende mit [X]');
                      repeat until KeyPressed;
                      Ch := ReadKey;
                      if Ch in ['x','X'] then
                        begin
                         Ch := ' ';    {verhindert Abort}
                         goto 99;
                        end;
                     end;
                 end;
             end; {for m..}
         end; {if ifb_online}

       Ifb_Adr := Ifb_Adr + 1;
       if Ifb_Adr > $FF then
         begin
           if Mod_Total = 0 then
            begin
              GotoXY(05,10); write('Sorry, leider keine I/O-Karten gefunden!!');
            end;
           Ini_Msg_Win;
           Write('Ende mit <SPACE>');
           repeat until KeyPressed;
           Ch := ReadKey;
           Ch := ' ';                  {Abort wegen Eingabe von 'x' verhindern}
           goto 99;
         end;
      until KeyPressed {or (Ch = ' ')};
    99:
 End; {Mil_Detect_IO_Modul}


 PROCEDURE Mil_Ask_Mod;
  label 99;
  CONST start_zeile = 4;
        start_spalte =5;
        zeile_max    =22;
        spalte_offset=20;

  VAR answer : CHAR;
      Status : Boolean;
      Mod_total      : WORD;
      Mod_total_err  : WORD;
      Mod_Adr        : Integer;
      Mod_Online : ARRAY[0..ModAdr_Max] OF BOOLEAN;

      zeile,spalte: BYTE;
      hex_str    : STRING[10];
      i,n        : WORD;
      RetAdr     : Byte;
      OnlineErr  : TOnlineErr;
      Ende       : Boolean;
      Mod_RetAdr : Byte;

  begin
    Zeile := Start_Zeile;
    Spalte:= Start_Spalte;
    Mod_Total     := 0;
    Mod_Total_Err := 0;
    for I := 0 to ModAdr_Max do  Mod_Online [I] := False;

    Ini_Text_Win;
    Ini_Msg_Win;
    if Ifc_Test_Nr = 0 then
     begin
      Ini_Err_Win;
      Write ('ERROR: Nicht erlaubt IFK-Nr ', Hex_byte(Ifc_Test_Nr),' [Hex]!   Weiter mit <Space> ');
      Ch := NewReadKey;
      Exit;
     end;

    Mil.Ifc_Online (Ifc_Test_Nr, RetAdr, OnlineErr);
    if OnlineErr <> NoErr then
     begin
      Ini_Err_Win;
      Write ('ERROR: IFK-Nr ', Hex_Byte(Ifc_Test_Nr),' [Hex] meldet sich nicht!    Weiter mit <Space> ');
      Ch := NewReadKey;
      Exit;
     end
    else
     begin
      if RetAdr <> Ifc_Test_Nr then
       begin
        Ini_Err_Win;
        Write ('ERROR: Antwort v. falscher IFK-Adr!  '); TextColor(Yellow+128);
        Write('Soll: ', Hex_Byte(Ifc_Test_Nr),'[H]  Ist: ', Hex_Byte(RetAdr),'[H]');
        TextColor(Red); Write (' Weiter mit <Space> ');
        Ch := NewReadKey;
        Exit;
       end;
     end;

    {Die IFK ist also vorhanden und reagiert: jetzt vorhandene Module anzeigen}
    for Mod_Adr := 0 to ModAdr_Max do
      Begin
        Mil.Mod_Online (Ifc_Test_Nr, Mod_Adr, Mod_RetAdr, OnlineErr);
        If (OnlineErr = NoErr) and (Mod_Adr = Mod_RetAdr) then
         begin
            Mod_Online [Mod_Adr] := True;
            Set_Text_Win;  TextColor (Black);
            GotoXY (spalte, zeile);
            write(hex_Byte(Mod_Adr));                           {Solladresse}
            zeile := zeile + 1;
            IF (zeile > zeile_max )  THEN
             begin
               spalte := spalte + spalte_offset;
               zeile  := start_zeile;
             end;
            Mod_Total := Mod_Total + 1;
          end {if noerr}
         else
          begin   {Online-Error!!}
            if OnlineErr = AdrErr then
             begin
               Mod_Total_Err := Mod_Total_Err + 1;
               Ini_Err_Win;
               Write ('ERROR: Antwort v. falscher MOD-Adr!  '); TextColor(Yellow+128);
               Write('Soll: ', Hex_Byte(Mod_Adr),'[H]  Ist: ', Hex_Byte(Mod_RetAdr),'[H]');
               TextColor(Red); Write ('  [W]eiter [Q]uit');
               repeat
                 Ch := NewReadKey;
                 if Ch in ['q','Q'] then
                  begin
                   Ch := ' ';
                   Exit;
                  end;
               until Ch in ['w','W'];
             end; {OnlineErr = AdrErr}
          end;
    End; {FOR}

    Set_Text_Win;
    if  Mod_Total_Err <> 0 then
     begin
       TextColor(Red);
       GotoXY (03,01);
       Write ('Es melden sich ['); TextColor (Yellow);  Write (Mod_Total_Err); TextColor(Red);
       Write('] I/O-Karte(n) mit falscher Mod-Adresse!!!');
       TextColor(Black);
     end;

    GotoXY (03,02); TextColor(Blue);
    Write ('Es melden sich ['); TextColor (Yellow); Write (Mod_Total); TextColor(Blue);
    Write('] I/O-Karte(n) "ONLINE": '); TextColor (Black);

    if Mod_Total <> 0 then
     begin
       Mod_Adr := -1;
       repeat
        Mod_Adr     := Mod_Adr + 1;
        Mod_Test_Nr := Mod_Adr;
       until Mod_Online [Mod_Adr] or (Mod_Adr > ModAdr_Max);
     end
    else
     begin
      Ini_Err_Win;
      Write ('Keine I/O-Karte Online ! Hex-Adresse eingeben <J> oder Ende <CR> ');
      repeat until KeyEPressed;
      answer := NewReadKey;
      if answer in ['j','J'] then Mod_Test_Nr := Ask_Hex_Byte;
      goto 99;
     end;

    Ini_Msg_Win;
    Write ('Online Mod-Adr ['); TextColor(Red); Write (Hex_Byte(Mod_Test_Nr)); TextColor(Yellow);
    Write (']  Åbernehmen mit <CR>, Auswahl ',chr($19),' ',chr($18),' oder Hex-Eingabe <J>: ');
    answer := NewReadKey;

    repeat
       if KeyEPressed then answer := NewReadKey;

       if answer in ['j','J'] then
         begin
           Mod_Test_Nr := Ask_Hex_Byte;
           Ini_Msg_Win;
           Write ('Online Mod-Adr ['); TextColor(Red); Write (Hex_Byte(Mod_Test_Nr)); TextColor(Yellow);
           Write (']  Åbernehmen mit <CR>, Auswahl ',chr($19),' ',chr($18),' oder Hex-Eingabe <J>: ');
           answer :=  ' ';
         end;

       if answer = #0 then
        begin
         answer := NewReadKey;
         case ord (answer) of
         Taste_Pfeil_Auf  : begin
                             Mod_Adr := Mod_Test_Nr;
                             repeat
                              Mod_Adr := Mod_Adr + 1;
                              if Mod_Adr =  ModAdr_Max then Mod_Adr := ModAdr_Max;
                              if Mod_Online [Mod_Adr] then Mod_Test_Nr := Mod_Adr;
                             until Mod_Online [Mod_Adr] or (Mod_Adr = ModAdr_Max);
                             Ini_Msg_Win;
                             Write ('Online Mod-Adr ['); TextColor(Red); Write (Hex_Byte(Mod_Test_Nr)); TextColor(Yellow);
                             Write (']  Åbernehmen mit <CR>, Auswahl ',chr($19),' ',chr($18),' oder Hex-Eingabe <J>: ');
                            end;

          Taste_Pfeil_Ab  : begin
                             Mod_Adr := Mod_Test_Nr;
                             repeat
                              Mod_Adr := Mod_Adr - 1;
                              if Mod_Adr = -1 then Mod_Adr := 0;
                              if Mod_Online [Mod_Adr] then Mod_Test_Nr := Mod_Adr;
                             until Mod_online [Mod_Adr] or (Mod_Adr = 0);
                             Ini_Msg_Win;
                             Write ('Online Mod-Adr ['); TextColor(Red); Write (Hex_Byte(Mod_Test_Nr)); TextColor(Yellow);
                             Write (']  Åbernehmen mit <CR>, Auswahl ',chr($19),' ',chr($18),' oder Hex-Eingabe <J>: ');
                            end;
         end;  {Case}
     end;
    until answer = chr($0D);
  99:
 end;  {MIL_Ask_Mod}

 procedure Ask_Ifc_Mod_Adr;
  begin
   Ini_Text_Win;
   Mil_Ask_Ifc;      {globale IFK:         Ifc_Test_Nr}
   Mil_Ask_Mod;      {globale Modul-Karte: Mod_Test_Nr}
  end; {Test_Adr}

  procedure Ini_Online_Win;
   begin
    Window(73, 10, 79, 23);
    TextBackground(Cyan);
    TextColor(Brown);               {Setze Schriftfarbe}
    ClrScr;
   end;

  procedure Clr_Online_Win;
   begin
    Window(73, 10, 79, 23);
    TextBackground(White);
    TextColor(Black);               {Setze Schriftfarbe}
    ClrScr;
   end;
{x}
 procedure Show_Ifk_Online;
  var I        : Word;
      RetAdr   : Byte;
      OnlineErr: TOnlineErr;
  begin
    Ini_Online_Win;
    Write ('- IFK -'); Write ('online:'); TextColor(Black);

    for I := 1 to 255 do
     begin
       Mil.Ifc_Online (I, RetAdr, OnlineErr);
       if OnlineErr = NoErr then Writeln ('  ',(Hex_Byte (RetAdr)));
     end; {for}
  end; {Show_Ifk_Online}

 procedure Show_Mod_Online;
  var I         : Word;
      Mod_RetAdr: Byte;
      OnlineErr : TOnlineErr;
  begin
    Ini_Online_Win;
    Write ('IFK: '); TextColor(Blue); Write(Hex_Byte(Ifc_Test_Nr)); TextColor(Brown);
    Write ('Module '); Write ('online:');
    TextColor(Black);
    if Ifc_Test_Nr = 0 then
     begin
       Writeln;
       Write (' ??? ');
     end
    else
     begin
       for I := 0 to $1F do
        begin
          Mil.Mod_Online (Ifc_Test_Nr, I, Mod_RetAdr, OnlineErr);
          if OnlineErr = NoErr then Writeln ('  ',(Hex_Byte (Mod_RetAdr)));
        end; {for}
     end; {if Test=0}
  end; {Show_Mod_Online}

 procedure Show_Bit_Zuordnung (S_Base: Byte; ZBase: Byte);
  const S_Off = 40;
  begin
    Set_Text_Win; TextColor(Blue);
    GotoXY(S_Base, ZBase  );  Write ('    v--------- Sub-Adr 0 --------v    '); TextColor(Yellow);
    GotoXY(S_Base, ZBase+1);  Write ('      - Byte 4 -      - Byte 3 -      ');
    GotoXY(S_Base, ZBase+2);  Write ('    Bit         Bit Bit         Bit   '); TextColor(Black);
    GotoXY(S_Base, ZBase+3);  Write ('    31...........24 23...........16   ');
    TextColor(Blue);
    GotoXY(S_Off, ZBase  );   Write ('    v--------- Sub-Adr 2 --------v    '); TextColor(Yellow);
    GotoXY(S_Off, ZBase+1);   Write ('      - Byte 2 -      - Byte 1 -      ');
    GotoXY(S_Off, ZBase+2);   Write ('    Bit         Bit Bit         Bit   '); TextColor(Black);
    GotoXY(S_Off, ZBase+3);   Write ('    15...........08 07...........00   ');
  end;

 procedure Modul_Bit_Zuordnung;
  begin
    Ini_Text_Win;
    Show_Bit_Zuordnung (02, 10);   {Spalte, Zeile}
    Ini_Msg_Win;
    Write ('Weiter mit beliebiger Taste : ');
    Ch := NewReadKey;
    Ch:= '?';
  end; {Modul_Bit_Zuordnung}

 procedure  Ini_TastMod_Win;
  begin
   Window(02, 19, 70, 24); TextBackground(Green); TextColor(Yellow);
   Writeln ('v----------- WRITE -------------v   v----- READ -----v');
   Writeln ('F1: Mod-Adr        F5: Sub0  [Hex]  F9 : Mod-Adr      ');
   Writeln ('F2: Ifk-Adr        F6: Sub2  [Hex]  F10: Ifk-Adr      ');
   Writeln ('F3: Sub0 Ein/Aus   F7: Sub0/2 <-->  F11: Sub0  Ein/Aus');
   Write   ('F4: Sub2    "      F8: Wr-Data 0.0  F12: Sub2     "   ');
  end;

  const
   Z_Info     = 01;
   S_Info     = 15;

   Z_Data     = 8;
   S_Data     = 04;
   Z_Sub0_Hex = Z_Data+2;
   Z_Sub2_Hex = Z_Sub0_Hex+1;
   Z_Sub0_Bin = Z_Sub2_Hex+2;
   Z_Sub2_Bin = Z_Sub0_Bin+1;
   Z_Sub0_Life= Z_Sub0_Hex;
   Z_Sub2_Life= Z_Sub2_Hex;

   Z_Ifk_Adr   = Z_Data -2;
   Z_Mod_Adr   = Z_Data -1;
   S_Ifk_WrAdr = 40;
   S_Mod_WrAdr = S_Ifk_WrAdr;
   S_Ifk_RdAdr = S_Ifk_WrAdr+18;
   S_Mod_RdAdr = S_Ifk_RdAdr;

   S_WrData_Hex= S_Ifk_WrAdr-6;
   S_RdData_Hex= S_Ifk_RdAdr-7;
   S_WrData_Bin= S_Ifk_WrAdr-17;
   S_RdData_Bin= S_Ifk_RdAdr-12;

   Z_RdLife    = Z_Data;
   S_RdLife    = S_Mod_RdAdr-12;
   Z_WrLife    = Z_Data;
   S_WrLife    = S_Mod_WrAdr-12;

 type
  TModeSubAdr = record
                 WrMode : Boolean;  {Anzeigen und Schreiben: Ja/Nein}
                 WrSub0 : Boolean;
                 WrSub2 : Boolean;
                 RdSub0 : Boolean;
                 RdSub2 : Boolean;
               end;


  TCardAdr =  record
               IfkNr  : Byte;
               ModAdr : Byte;
              end;

  TBackColor = (Gruen, Rot, Weiss, Gelb, Blank);


 procedure Modul_WrRd;     {Sehr wichtige SubRoutine!!}
  label 99;
  type TWrRd = (Wr, Rd);

  var User_In     : Word;
      Mod_Adr     : Byte;
      Sub_Adr     : Byte;
      Rd_Sub0_Err : LONGINT;
      Rd_Sub2_Err : LONGINT;
      Ifk_AdrWr   : Byte;
      Ifk_AdrRd   : Byte;
      Mod_AdrWr   : Byte;
      Mod_AdrRd   : Byte;
      Mode_SubAdr : TModeSubAdr;
      RModCrd     : TCardAdr;
      WModCrd     : TCardAdr;
      Wr_Data_Sub0: Word;
      Wr_Data_Sub2: Word;
      Shift_Mode_Sub0 : Boolean;

   procedure Display_Adr;
    begin
     Set_Text_Win;
     TextColor(Blue);
     GotoXY(S_Ifk_WrAdr,Z_Ifk_Adr);   write(Hex_Byte(WModCrd.IfkNr));
     GotoXY(S_Mod_WrAdr,Z_Mod_Adr);   write(Hex_Byte(WModCrd.ModAdr));
     GotoXY(S_Ifk_RdAdr,Z_Ifk_Adr);   write(Hex_Byte(RModCrd.IfkNr));
     GotoXY(S_Mod_RdAdr,Z_Mod_Adr);   write(Hex_Byte(RModCrd.ModAdr));
    end;

   procedure Display_Ini;
   begin
    Ini_Text_Win;        TextColor(Brown);
    GotoXY(18,Z_Info  ); write('----- Modul-Bus Daten schreiben/lesen -----');
    GotoXY(08,Z_Info+1); write('Setze Modul-Adr mit Fct-Code 11 [H], Wr/Rd mit Fct-Code 10/90 [H]');
    GotoXY(17,Z_Info+2); write('     v--- Sub-Adr[0] ---v   v--- Sub-Adr[2] ---v    ');
    GotoXY(17,Z_Info+3); write('[Bit 31................16   15................00 Bit]');
    TextColor(Magenta);
    GotoXY(S_Ifk_WrAdr-12,Z_Ifk_Adr); write('IFK-Adr[H]: ');
    GotoXY(S_Mod_WrAdr-12,Z_Mod_Adr); write('Mod-Adr[H]: ');

    GotoXY(S_Ifk_RdAdr-12,Z_Ifk_Adr); write('IFK-Adr[H]: ');
    GotoXY(S_Mod_RdAdr-12,Z_Mod_Adr); write('Mod-Adr[H]: ');
    Display_Adr;

    TextColor(Brown);
    GotoXY(S_Data,Z_Data  );    writeln('Wr-Data-Cnt:               Write-Data        Read-Data               ');
    GotoXY(S_Data,Z_Data+1);    writeln('                 ^  ^         [Hex]            [Hex]                 ');
    GotoXY(S_Data,Z_Sub0_Hex);  writeln('Sub-Adr[0]: ');
    GotoXY(S_Data,Z_Sub2_Hex);  writeln('Sub-Adr[2]: ');
    GotoXY(S_Data,Z_Sub0_Bin);  writeln('Sub-Adr[0]: ');
    GotoXY(S_Data,Z_Sub2_Bin);  writeln('Sub-Adr[2]: ');

    GotoXY(S_WrData_Bin, Z_Sub2_Bin+1); writeln('MSB             LSB');
    GotoXY(S_RdData_Bin, Z_Sub2_Bin+1); writeln('MSB             LSB');
   end;

  procedure Life_Sign_ModWrRd (DispMode: TWrRd);
   var Wr_Param, Rd_Param: TLife_XY;
   begin
    if DispMode = Wr then
     begin                    GotoXY(S_RdLife ,Z_RdLife);
       Wr_Param.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
       Wr_Param.PosX    := S_WrLife;;
       Wr_Param.PosY    := Z_WrLife;
       Wr_Param.Time    := Life_Time_Super;
       Wr_Param.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}
       Life_Sign_XY (Wr_Param);
     end;

    if DispMode = Rd then
     begin
       Rd_Param.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
       Rd_Param.PosX    := S_RdLife;
       Rd_Param.PosY    := Z_RdLife;
       Rd_Param.Time    := Life_Time_Super;
       Rd_Param.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}
       Life_Sign_XY (Rd_Param);
     end;
   end; {Life_Sign_ModWrRd}


{ TMode SubAdr = record
                  WrSub0 : Boolean;
                  WrSub2 : Boolean;
                  RdSub0 : Boolean;
                  RdSub2 : Boolean;
                end; }


 procedure Win_Hex4_Xy (X: Byte; Y: Byte; WData: Word; BackColor: TBackColor; RdError: Boolean);
  begin
   if BackColor = Gruen then TextBackground(Green);
   if BackColor = Rot   then TextBackground(Red);
   if BackColor = Weiss then TextBackground(White);
   if BackColor = Gelb  then TextBackground(Yellow);
   if BackColor = Blank then TextBackground(White);
   GotoXY (X,Y);  TextColor(Black);
   if (BackColor = Blank) then
     Write ('    ')
   else
     if RdError then Write ('Err!') else Write (Hex_Word(WData))
  end; {Win_Hex4_Xy}

 procedure Win_Bin_Xy (X: Byte; Y: Byte; WData: Word; BackColor: TBackColor; RdError: Boolean);
  var  Bit16_Strg: Str19;
  begin
   if BackColor = Gruen then TextBackground(Green);
   if BackColor = Rot   then TextBackground(Red);
   if BackColor = Weiss then TextBackground(White);
   if BackColor = Gelb  then TextBackground(Yellow);
   if BackColor = Blank then TextBackground(White);
   Hex_Bin_Str (WData, Bit16_Strg);
   GotoXY(X,Y);   TextColor(Black);
   if (BackColor = Blank) then
     Write ('                   ')
   else
     if RdError then Write ('    Read Error!    ') else Write(Bit16_Strg)
  end; {Win_Bin_Xy}


 procedure Transf_And_Displ_ModbusData  (DispMode : TModeSubAdr;
                                         RdCard   : TCardAdr;
                                         WrCard   : TCardAdr;
                                         Sub0WrDta: Word;
                                         Sub2WrDta: Word);
  var Color   : TBackColor;
      ModRdDta: Word;
      WrAdr   : TModAdr;
      RdAdr   : TModAdr;
      MilErr  : TMilErr;
      RdErr   : Boolean;
  begin                                             {DataTo_ModBus_And_Displ}
    if DispMode.WrMode then          {Daten schreiben und nicht nur anzeigen}
     begin
       if DispMode.WrSub0 then
        begin                                {Daten schreiben}
          WrAdr.AdrIfc  := WrCard.IfkNr;
          WrAdr.AdrCard := WrCard.ModAdr;
          WrAdr.AdrSub  := 0;
          WrAdr.AdrMode := AdrNew;
          Mil.Wr_ModBus (Sub0WrDta, WrAdr, MilErr);
          Life_Sign_ModWrRd (Wr);
        end;
       if DispMode.WrSub2 then
        begin                                 {Daten schreiben}
          WrAdr.AdrIfc  := WrCard.IfkNr;
          WrAdr.AdrCard := WrCard.ModAdr;
          WrAdr.AdrSub  := 2;
          WrAdr.AdrMode := AdrNew;
          Mil.Wr_ModBus (Sub2WrDta, WrAdr, MilErr);
          Life_Sign_ModWrRd (Wr);
        end;
     end; {if DispMode.WrMode}

                        {Ab hier Daten nur anzeigen}
    Set_Text_Win;
    if DispMode.WrSub0 then Color := Gruen else Color := Weiss;
    Win_Hex4_XY (S_WrData_Hex, Z_Sub0_Hex, Sub0WrDta, Color, False);
    Win_Bin_XY  (S_WrData_Bin, Z_Sub0_Bin, Sub0WrDta, Color, False);

    if DispMode.WrSub2 then Color := Gruen else Color := Weiss;
    Win_Hex4_XY (S_WrData_Hex, Z_Sub2_Hex, Sub2WrDta, Color, False);
    Win_Bin_XY  (S_WrData_Bin, Z_Sub2_Bin, Sub2WrDta, Color, False);

    if DispMode.RdSub0 then
     begin
      Color := Gruen; Life_Sign_ModWrRd (Rd); RdErr := False;
      RdAdr.AdrIfc  := RdCard.IfkNr;
      RdAdr.AdrCard := RdCard.ModAdr;
      RdAdr.AdrSub  := 0;
      RdAdr.AdrMode := AdrNew;
      Mil.Rd_ModBus (ModRdDta,RdAdr,MilErr);
      if MilErr <> No_Err then RdErr := True;
     end
    else Color := Blank;
    Win_Hex4_XY (S_RdData_Hex, Z_Sub0_Hex, ModRdDta, Color, RdErr);
    Win_Bin_XY  (S_RdData_Bin, Z_Sub0_Bin, ModRdDta, Color, RdErr);

    if DispMode.RdSub2 then
     begin Color := Gruen; Life_Sign_ModWrRd (Rd); RdErr := False;
      RdAdr.AdrIfc  := RdCard.IfkNr;
      RdAdr.AdrCard := RdCard.ModAdr;
      RdAdr.AdrSub  := 2;
      RdAdr.AdrMode := AdrNew;
      Mil.Rd_ModBus (ModRdDta,RdAdr,MilErr);
      if MilErr <> No_Err then RdErr := True;
     end
    else Color := Blank;
    Win_Hex4_XY (S_RdData_Hex, Z_Sub2_Hex, ModRdDta, Color, RdErr);
    Win_Bin_XY  (S_RdData_Bin, Z_Sub2_Bin, ModRdDta, Color, RdErr);
  end;   {DataTo_ModBus_And_Displ}

 procedure Show_Shift_Mode (ShifMod0: Boolean);
  begin
   Set_Text_Win; TextColor(Yellow);
   if ShifMod0 then
    begin
      GotoXY (02,Z_Sub0_Hex); Write (chr($1D));   {waagrechter Doppelpfeil}
      GotoXY (02,Z_Sub2_Hex); Write (' ');
    end
   else
    begin
      GotoXY (02,Z_Sub2_Hex); Write (chr($1D));
      GotoXY (02,Z_Sub0_Hex); Write (' ');
    end;
   TextColor(Yellow);
  end;

  begin    {Modbus_WrRd}
    Ask_Ifc_Mod_Adr;                {Ifc_Test_Nr u. Modul_Test_Nr erfragen}
    WModCrd.IfkNr  := Ifc_Test_Nr;  {Ifk_AdrWr}
    WModCrd.ModAdr := Mod_Test_Nr;  {Mod_AdrWr}
    RModCrd.IfkNr  := Ifc_Test_Nr;  {Ifk_AdrRd}
    RModCrd.ModAdr := Mod_Test_Nr;  {Mod_AdrRd}

    Mode_SubAdr.WrMode := False;  {Anzeigen und Schreiben: Ja/Nein}
    Mode_SubAdr.WrSub0 := False;  {fÅr jede Adresse Wr/Rd-Mode festlegen}
    Mode_SubAdr.WrSub2 := False;
    Mode_SubAdr.RdSub0 := True;
    Mode_SubAdr.RdSub2 := True;

    Wr_Data_Sub0 := 0;
    Wr_Data_Sub2 := 0;
    Shift_Mode_Sub0  := False;

    Ini_Text_Win;
    Display_Ini;
    Ini_TastMod_Win;
    Show_Shift_Mode (Shift_Mode_Sub0);
    Cursor(False);       {Software-Gerippe fÅr Single-Step und Loop}
    Std_Msg;
    Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step        := True;
       Mode_SubAdr.WrMode := True; {falls enabled: auch Daten schreiben}
       Transf_And_Displ_ModbusData (Mode_SubAdr, RModCrd, WModCrd, Wr_Data_Sub0, Wr_Data_Sub2);
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;
     if not Single_Step then
      begin
       Mode_SubAdr.WrMode := True; {falls enabled: auch Daten schreiben}
       Transf_And_Displ_ModbusData (Mode_SubAdr, RModCrd, WModCrd, Wr_Data_Sub0, Wr_Data_Sub2);
      end;

     if Ch = #0 then                  {Sonder-Tasten Abfrage}
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    Show_Mod_Online;
                    if Ask_Hex_Break (User_In, Byt) then
                      begin
                       WModCrd.ModAdr:= User_In;
                       Display_Adr;
                      end;
                    Clr_Online_Win;
                    Std_Msg;
                   end;
        Taste_F2 : begin
                    Show_Ifk_Online;
                    if Ask_Hex_Break (User_In, Byt) then
                      begin
                        WModCrd.IfkNr := User_In;
                        Display_Adr;
                      end;
                    Clr_Online_Win;
                    Std_Msg;
                   end;
        Taste_F3:  begin
                     if   Mode_SubAdr.WrSub0 then Mode_SubAdr.WrSub0 := False
                     else Mode_SubAdr.WrSub0 := True;
                     Mode_SubAdr.WrMode := False;
                     Transf_And_Displ_ModbusData (Mode_SubAdr, RModCrd, WModCrd, Wr_Data_Sub0, Wr_Data_Sub2);
                   end;
        Taste_F4: begin
                     if   Mode_SubAdr.WrSub2 then Mode_SubAdr.WrSub2 := False
                     else Mode_SubAdr.WrSub2 := True;
                     Mode_SubAdr.WrMode := False;
                     Transf_And_Displ_ModbusData (Mode_SubAdr, RModCrd, WModCrd, Wr_Data_Sub0, Wr_Data_Sub2);
                   end;
        Taste_F5: begin
                    if Ask_Hex_Break (User_In, Wrd) then
                     begin
                      Wr_Data_Sub0 := User_In;
                      Mode_SubAdr.WrMode := False;
                      Transf_And_Displ_ModbusData (Mode_SubAdr, RModCrd, WModCrd, Wr_Data_Sub0, Wr_Data_Sub2);
                     end;
                    Std_Msg;
                  end;
        Taste_F6: begin
                    if Ask_Hex_Break (User_In, Wrd) then
                     begin
                      Wr_Data_Sub2 := User_In;
                      Mode_SubAdr.WrMode := False;
                      Transf_And_Displ_ModbusData (Mode_SubAdr, RModCrd, WModCrd, Wr_Data_Sub0, Wr_Data_Sub2);
                     end;
                    Std_Msg;
                  end;
        Taste_F7: begin
                    if Shift_Mode_Sub0 then Shift_Mode_Sub0 := False
                    else Shift_Mode_Sub0 := True;
                    Show_Shift_Mode (Shift_Mode_Sub0);
                    Mode_SubAdr.WrMode := False;
                    Transf_And_Displ_ModbusData (Mode_SubAdr, RModCrd, WModCrd, Wr_Data_Sub0, Wr_Data_Sub2);
                   end;
        Taste_F8: begin                     {Write Data 0}
                    Wr_Data_Sub0 := 0;
                    Wr_Data_Sub2 := 0;
                    Mode_SubAdr.WrMode := False;
                    Transf_And_Displ_ModbusData (Mode_SubAdr, RModCrd, WModCrd, Wr_Data_Sub0, Wr_Data_Sub2);
                   end;
        Taste_F9: begin
                    Show_Mod_Online;
                    if Ask_Hex_Break (User_In, Byt) then
                      begin
                       RModCrd.ModAdr:= User_In;
                       Display_Adr;
                      end;
                    Clr_Online_Win;
                    Std_Msg;
                   end;
        Taste_F10: begin
                    Show_Ifk_Online;
                    if Ask_Hex_Break (User_In, Byt) then
                      begin
                        RModCrd.IfkNr := User_In;
                        Display_Adr;
                      end;
                    Clr_Online_Win;
                    Std_Msg;
                   end;
        Taste_F11: begin
                     if   Mode_SubAdr.RdSub0 then Mode_SubAdr.RdSub0 := False
                     else Mode_SubAdr.RdSub0 := True;
                     Mode_SubAdr.WrMode := False;
                     Transf_And_Displ_ModbusData (Mode_SubAdr, RModCrd, WModCrd, Wr_Data_Sub0, Wr_Data_Sub2);
                   end;
        Taste_F12: begin
                     if   Mode_SubAdr.RdSub2 then Mode_SubAdr.RdSub2 := False
                     else Mode_SubAdr.RdSub2 := True;
                     Mode_SubAdr.WrMode := False;
                     Transf_And_Displ_ModbusData (Mode_SubAdr, RModCrd, WModCrd, Wr_Data_Sub0, Wr_Data_Sub2);
                   end;
       Taste_Pfeil_Links : begin
                            if Shift_Mode_Sub0 then
                              begin
                                if Wr_Data_Sub0 = $0000 then Wr_Data_Sub0 := $1
                                else Wr_Data_Sub0 := Wr_Data_Sub0 shl 1;
                              end {if Shift-Mode}
                            else
                              begin
                                if Wr_Data_Sub2 = $0000 then Wr_Data_Sub2 := $1
                                else Wr_Data_Sub2 := Wr_Data_Sub2 shl 1;
                              end; {if Shift-Mode}
                            Mode_SubAdr.WrMode := False;
                            Transf_And_Displ_ModbusData (Mode_SubAdr, RModCrd, WModCrd, Wr_Data_Sub0, Wr_Data_Sub2);
                           end;  {Taste_Pfeil_Links}
        Taste_Pfeil_Rechts: begin
                            if Shift_Mode_Sub0 then
                              begin
                                if Wr_Data_Sub0 = $0000 then Wr_Data_Sub0 := $1
                                else Wr_Data_Sub0 := Wr_Data_Sub0 shr 1;
                              end {if Shift-Mode}
                            else
                              begin
                                if Wr_Data_Sub2 = $0000 then Wr_Data_Sub2 := $1
                                else Wr_Data_Sub2 := Wr_Data_Sub2 shr 1;
                              end; {if Shift-Mode}
                            Mode_SubAdr.WrMode := False;
                            Transf_And_Displ_ModbusData (Mode_SubAdr, RModCrd, WModCrd, Wr_Data_Sub0, Wr_Data_Sub2);
                         end;  {Taste_Pfeil_Rechts}
      end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
  end; {Modbus_WrRd}


 type
   TSkal= record
            Mod_Id : Byte;
            FG_Nr  : String[9];
            Name   : String[16];
            SkalBit0_False:String[8];
            SkalBit0_True :String[8];
            SkalBit1_False:String[8];
            SkalBit1_True :String[8];
            SkalBit2_False:String[8];
            SkalBit2_True :String[8];
            SkalBit3_False:String[8];
            SkalBit3_True :String[8];
            SkalBit4_False:String[8];
            SkalBit4_True :String[8];
            SkalBit5_False:String[8];
            SkalBit5_True :String[8];
            SkalBit6_False:String[8];
            SkalBit6_True :String[8];
            SkalBit7_False:String[8];
            SkalBit7_True :String[8];
           end;

  const
   ID_24Bit_IO  = $20;
   ID_24Bit_Sta = $21;

   Skal_24BitIO: TSkal =
   (Mod_Id : ID_24Bit_IO;
    FG_Nr  : 'FG450.320';
    Name   : '24-Bit I/O-Modul';
    SkalBit0_False: '  In    ';
    SkalBit0_True : '  Out   ';
    SkalBit1_False: '  In    ';
    SkalBit1_True : '  Out   ';
    SkalBit2_False: '  In    ';
    SkalBit2_True : '  Out   ';
    SkalBit3_False: '        ';
    SkalBit3_True : '        ';
    SkalBit4_False: 'Hi-Aktiv';
    SkalBit4_True : 'Lo-Aktiv';
    SkalBit5_False: 'Hi-Aktiv';
    SkalBit5_True : 'Lo-Aktiv';
    SkalBit6_False: 'Hi-Aktiv';
    SkalBit6_True : 'Lo-Aktiv';
    SkalBit7_False: '        ';
    SkalBit7_True : '        ');

  Skal_24BitStat: TSkal =
   (Mod_Id : ID_24Bit_Sta;
    FG_Nr  : 'FG450.330';
    Name   : '24-Bit Status   ';
    SkalBit0_False: '  In    ';
    SkalBit0_True : '  Out   ';
    SkalBit1_False: '  In    ';
    SkalBit1_True : '  Out   ';
    SkalBit2_False: '  In    ';
    SkalBit2_True : '  Out   ';
    SkalBit3_False: '        ';
    SkalBit3_True : '        ';
    SkalBit4_False: 'Hi-Aktiv';
    SkalBit4_True : 'Lo-Aktiv';
    SkalBit5_False: 'Hi-Aktiv';
    SkalBit5_True : 'Lo-Aktiv';
    SkalBit6_False: 'Hi-Aktiv';
    SkalBit6_True : 'Lo-Aktiv';
    SkalBit7_False: '        ';
    SkalBit7_True : '        ');

  const
   Z_BaseKonfig = 08;
   S_BaseKonfig = 02;
   Z_IfkAdr     = Z_BaseKonfig-5;
   S_IfkAdr     = S_BaseKonfig+18;
   S_HexWert    = S_IfkAdr    +16;
   S_FGNr       = S_IfkAdr    +25;
   Z_ModAdr     = Z_IfkAdr+1;
   Z_ModId      = Z_IfkAdr+2;
   Z_ModSkal    = Z_IfkAdr+3;

  var
   Life_Mode   : TLife_XY;

  procedure Show_Mod_Adr;
   begin
    GotoXY (S_HexWert, Z_IfkAdr); Write(Hex_Byte(Ifc_Test_Nr));
    GotoXY (S_HexWert, Z_ModAdr); Write(Hex_Byte(Mod_Test_Nr));
   end; {Show_Mod_Adr}

  procedure Show_ModKonfig;
   var
    ModRdAdr  : TModAdr;
    Mod_Data  : Word;
    MilErr    : TMilErr;
    CardID    : Byte;
    Modul_Skal: TSkal;
   begin
     Set_Text_Win;
     Life_Sign_XY (Life_Mode);

     ModRdAdr.AdrIfc  := Ifc_Test_Nr;
     ModRdAdr.AdrCard := Mod_Test_Nr;
     {Lese zuerst den Modul Ident}
     ModRdAdr.AdrSub  := ModSub_Adr_ID; {Hi-Byt: Card-ID (LP), Lo-Byt: VG-ID = SlotID (VG)}
     ModRdAdr.AdrMode := AdrNew;
     Mil.Rd_ModBus (Mod_Data, ModRdAdr, MilErr);
     GotoXY (S_HexWert,Z_ModId);
     if MilErr = No_Err then
      begin
        CardID := Hi(Mod_Data);
        Write (Hex_Word(Mod_Data)); Write ('    ');
      end
     else
      begin
        Write ('Rd Error');
      end;

     {Lese die Skalierung}
     ModRdAdr.AdrSub  := ModSub_Adr_ModAdr;  {Hi: Skal, Lo: ModAdr}
     ModRdAdr.AdrMode := AdrNew;
     Mil.Rd_ModBus (Mod_Data, ModRdAdr, MilErr);
     GotoXY (S_HexWert,Z_ModSkal);
     if MilErr = No_Err then
      begin
        Write (Hex_Word(Mod_Data)); Write ('    ');
        case Hi(Mod_Data) of
         ID_24Bit_IO  : Modul_Skal := Skal_24BitIO;
         ID_24Bit_Sta : Modul_Skal := Skal_24BitStat;
        end; {Case}
      end
     else
      begin
        Write ('Rd Error');
      end;
   end; {Show_ModKonfig}

  begin
    Life_Mode.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
    Life_Mode.PosX    := S_IfkAdr - 2;
    Life_Mode.PosY    := Z_IfkAdr;
    Life_Mode.Time    := Life_Time_Slow;
    Life_Mode.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}

   Ask_Ifc_Mod_Adr;                {Ifc_Test_Nr u. Modul_Test_Nr erfragen}
   Ini_Text_Win; TextColor(Brown); GotoXY (7, 02);
   Write ('---- I/O-Konfiguration (Skalierung) fÅr 24- u. 32-Bit I/O-Module ----'); TextColor(Brown);

   GotoXY (S_IfkAdr, Z_IfkAdr);  Write ('IFK-Adr   [H] : ');
   GotoXY (S_IfkAdr, Z_ModAdr);  Write ('Mod-Adr   [H] : ');
   GotoXY (S_IfkAdr, Z_ModId );  Write ('Mod-Ident [H] : ');
   GotoXY (S_IfkAdr, Z_ModSkal); Write ('Mod-Skal  [H] : ');

   GotoXY (S_FGNr, Z_ModId );  Write ('FG-Nr: ');
   GotoXY (S_FGNr, Z_ModSkal); Write ('Name : ');
   Show_Bit_Zuordnung (S_BaseKonfig,Z_BaseKonfig);            {Spalte, Zeile}
   Show_Mod_Adr;
   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;

   repeat
    if Ch = ' ' then
     begin
      Std_Msg;
      Single_Step := True;
      Show_ModKonfig;
      repeat until KeyEPressed;
      Ch := NewReadKey;
     end;

    if Ch = #13 then Single_Step := False;
    if not Single_Step then
     begin
      Show_ModKonfig;
     end;

    if Ch = #0 then                  {Sonder-Tasten Abfrage}
     begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                   end;
        Taste_F12: begin
                   end;
        Taste_Pfeil_Links : begin
                            end;
        Taste_Pfeil_Rechts: begin
                            end;
       end;  {Case}
     end;   {if Ch}
   if KeyEPressed then Ch := NewReadKey;
  until Ch in ['x','X'];
  Cursor(True);
  Ch := '?';
 end; {Modul_24BitIO_Konfig}

x

 procedure Modul_Bus;
 const Z_Base = 15;
       Z_Max  = 6;
 var User_Int : Integer;
 begin
  repeat
   Ini_Text_Win;
   TextColor(Blue);               {Setze Schriftfarbe}
   GotoXY(02, Z_Base-1); Write ('Test-Routinen fÅr Modul-Bus bzw. I/O-Bus');
   TextColor(Brown);
   GotoXY(02, Z_Base+0); Write ('0: IFKs und I/O-Module am DeviceBus anzeigen         ');
   GotoXY(02, Z_Base+1); Write ('1: Module an einer IFK anzeigen                      ');
   GotoXY(02, Z_Base+2); Write ('2: Modul  Schreiben/Lesen                            ');
   GotoXY(02, Z_Base+3); Write ('3: Modul  Konfiguration 24-Bit I/O [Skalierung]      ');
   GotoXY(02, Z_Base+4); Write ('4: Ident-Kode-Liste fÅr Modulbus-Karten              ');
   GotoXY(02, Z_Base+5); Write ('5: Zuordnung Bit-, Byte- und Sub-Adr am Modulbus     ');
   Ini_Msg_Win;
   Write ('Bitte Auswahl-Nummer oder E[X]it eingeben: ');
   Ch := NewReadKey;
      case Ch of                 { 0 : Ask_Ifc_Mod_Adr; }
       '0' : Mil_Detect_IO_Modul;
       '1' : Mil_Displ_IO_Modul;
       '2' : Modul_WrRd;
       '3' : Modul_24BitIO_Konfig;
       '4' : Modul_Ident_List;
       '5' : Modul_Bit_Zuordnung;
       'x','X' : Exit;
      end;
   until 1=2;
   Ch := '?';
 end; {Modul_Bus}
end.  { UNIT DATECH_0 }




    repeat
     repeat
       Set_Text_win;
        repeat
         M := M + 1;                   {alle mîglichen Modul-Adr abfragen}
         Mil.Mod_Online (Ifb_Adr, M, Mod_RetAdr, Mod_Err);
         If Mod_Err = NoErr then
        { IF IO_Mod_Online (Ifb_Adr, M) THEN}
          begin
            Displ_Mod_Info (Ifb_Adr, M, Mod_Zeile);
            Mod_Zeile := Mod_Zeile + 1;
            if (Mod_Zeile mod 23) = 0 then Mod_Zeile := Z_Mod_Start;
          end;

         if M > $1F then
           begin
             M := 0;
             Mod_Zeile := Z_Mod_Start;
           end;
        until M = 0;
       Life_Sign_XY (Life_Mode);
       Set_Text_win;               {Damit énderungen bemerkt werden: }
       Mil.Timer2_Wait (10000);    {Display jedesmal lîschen!! }
       for I := Z_Mod_Start to (Z_Mod_Start+10) do
        begin
         GotoXY (01, I); ClrEol;
        end;
     until KeyPressed or (Ch = ' ');
      if Ch = ' ' then
        begin
         Ini_Msg_Win;
         Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
         repeat until KeyPressed;
        end;
      Ch := ReadKey;
     until Ch in ['x','X'];
     99:
