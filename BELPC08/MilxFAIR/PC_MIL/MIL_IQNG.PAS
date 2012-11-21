PROGRAM Mil_IQNG;
{ Autor des Basis-Programmes Mil_Base.Pas: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen


  Autor der Erweiterungen   : G. ENGLERT
  énderungen:
  27.04.95    Erweitert fÅr Bedienung Ionenquellen-NetzgerÑt (M. Khaouli)

}
{$S-}
uses Crt, WinDos, Datech;

CONST
 head_line =
      'Datentechnik                         MIL-IQNG   ' +
      '                    [28.04.1995]'+
      '                         Bedienung Ionenquellen-NetzgerÑt   (Turbo Pascal V7.0)';

 msg_single_step =
      'Loop- u. Single-Test mit [Q] beenden!    Single-Step mit [SPACE] ';
 msg_timer_auto =
      'Automat. Timertest mit [Q] beenden!                              ';


{Sub-Adressen fÅr APL-IO-Bus Identifizierung: gÅltig fÅr alle Karten}
             {Antwort als 16-Bit-Wert fÅr Adr. FE, FC, FA}
 IOsub_Adr_CardID = $FE;  {gerade   Adr: hibyte}
 IOsub_Adr_VgID   = $FF;  {ungerade Adr: lobyte}

 IOsub_Adr_Skal   = $FC;  {gerade   Adr: hibyte}
 IOsub_Adr_ModAdr = $FD;  {ungerade Adr: lobyte}

 IOsub_Adr_Epld   = $FA;  {gerade   Adr: hibyte}
 IOsub_Adr_Frei   = $FB;  {ungerade Adr: lobyte}

  {Function-Codes Ionenquellen}
 IQ_Fct_Pwron   = $02;
 IQ_Fct_Pwroff  = $03;
 IQ_Fct_Sollw   = $06;
 IQ_Fct_IwStrom = $81;
 IQ_Fct_IwSpang = $82;

 Wait_1_Sec  =  1000 * 100;  {Zeit: 1 sec warten 1000 * 100 *10 us}


TYPE
 str4    = STRING[4];
 num_str = STRING[10];
 T_Dual  = record
            Adr   : Byte;
            Fct   : Byte;
            Dta_ok: Boolean;
            Dta   : Word;
           end;

VAR
 Mil        : T_Mil;               {Type OBJECT: in Unit Datech.Pas definiert}
 status    : BOOLEAN;
 loop      : BOOLEAN;
 rd_timeout: BOOLEAN;
 read_data : WORD;
 write_data: WORD;
 mil_data  : WORD;
 ifc_test_nr:BYTE;

 transf_cnt: LONGINT;
 time      : LONGINT;

 timout_cnt: LONGINT;
 timout_rd : LONGINT;
 timout_wr : LONGINT;

 ch,key    : CHAR;
 user_input: CHAR;
 read_str  : str4;
 Bit16_Str : Str19;
 Dual      : array [1..2] of T_Dual;     {Globale Variable fÅr Mil_Dual_Mode}
 Fct_11_Dta: Word;                       {Global fÅr io/bus-Tests}

procedure menue_win;
VAR answer: CHAR;
begin
  Ini_Headl_Win;
  Write(head_line);
  ini_text_win;
  GotoXY(12, 3);
  Writeln('**************************  TEST-MENUE  *************************');
  GotoXY(12, 4);
  Writeln('[A]<--   Welche IFC testen?         Welche IFC am MIL-Bus? -->[0]');
  GotoXY(12, 5);
  Writeln('[B]<--   Lese Status von IFC    (Fct-Code C9H: Intr-Mask usw.)  ');
  GotoXY(12, 6);
  Writeln('[C]<--   Lese Status Intr-Leitung an PC-Karte (Intl, Drdy, Dreq)');
  GotoXY(12, 7);
  Writeln('[D]<--   Lese Daten aus Receive-Register der PC-Karte           ');
  GotoXY(12, 8);
  Writeln('[E]<--   Lese Daten von IFC                                     ');
  GotoXY(12, 9);
  Writeln('[F]<--   ---                                                    ');
  GotoXY(12, 10);
  Writeln('[G]<--   Sende Daten zur IFC  (ohne Fct-Code)                   ');
  GotoXY(12, 11);
  Writeln('[H]<--   Sende Fct-Code zur IFC                                 ');
  GotoXY(12, 12);
  Writeln('[I]<--   Sende Daten zur IFC  (mit Fct-Code)                    ');
  GotoXY(12, 13);
  Writeln('[J]<--   Sende/Lese User-Definierte Daten                       ');
  GotoXY(12, 14);
  Writeln('[K]<--   Sende/Lese Daten (0..FFFF)                             ');
  GotoXY(12, 15);
  Writeln('[L]<--   Sende ein (zwei) Fct-Codes an ein (zwei) IFC-Adr       ');
  GotoXY(12, 16);
  Writeln('         [M]<-- Welche I/O-Module am MIL-Bus?                   ');
  GotoXY(12, 17);
  Writeln('         [N]<-- NetzgerÑte-Status lesen                         ');
  GotoXY(12, 18);
  Writeln('         [O]<-- Istwerte Strom/Spannung lesen                   ');
  GotoXY(12, 19);
  Writeln('         [P]<-- Strom Ein/Aus                                   ');
  GotoXY(12, 20);
  Writeln('         [Q]<-- Sollwert Strom setzen                           ');
  GotoXY(12, 21);
  Writeln('         [R]<--                                                 ');
  GotoXY(12, 22);
  Writeln('         [S]<--                                                 ');
  GotoXY(12, 23);
  Writeln('                    [T]<--                                                 ');

  ini_msg_win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
 End; {menue_win}


 PROCEDURE convert_to_hex (in_string  : str4;
                           VAR hex_out: WORD;
                           VAR status : BOOLEAN);
  VAR
   offset,i : INTEGER;
   dummy    : WORD;
  Begin
   offset := ORD('A') - ORD('a');
   status := TRUE;
   hex_out:= 0;
   FOR i :=  1 TO 4 DO
    Begin
     IF in_string[i] <> ' ' THEN
       Begin
         IF in_string[i] IN ['a'..'f'] THEN
            in_string[i] := CHR(offset + ORD(in_string[i]));
         IF in_string[i] IN ['0'..'9'] THEN
          hex_out := hex_out * 16 + (ORD(in_string[i]) - ORD('0'))
         ELSE
          Begin
            IF in_string[i] IN ['A' ..'F'] THEN
              hex_out := hex_out * 16 + (ORD(in_string[i]) - ORD('A') + 10)
            ELSE
             status := FALSE;
          End; {IF IN 0..9}
       End; {IF<>blank}
    End; {FOR i}
  End;

  FUNCTION timeout: BOOLEAN;
    Begin
     timeout := FALSE;
     IF time = 0 THEN timeout := TRUE  ELSE  time := time - 1;
    End;

  FUNCTION check_ifc_adr: BOOLEAN;
  Begin
    check_ifc_adr := TRUE;
    IF  NOT (ifc_test_nr IN [1..255]) THEN
     Begin
      check_ifc_adr := FALSE;
      ini_err_win;
      GotoXY(1, 1);
      write ('ABORT: IFC-Karten-Nr. undefiniert!!  Press any key to go on! '); ch := readkey;
     End;
  End; {check_ifc_adr}


 PROCEDURE mil_detect_ifc;
  CONST start_zeile = 5;
  VAR ifc_total  : WORD;
      ifb_online : ARRAY[1..255] OF BOOLEAN;
      ifb_adr    : WORD;
      zeile      : BYTE;
      hex_str    : STRING[10];
      i          : WORD;
  Begin
   ini_text_win;
   ifc_total := 0;
   ini_msg_win;
   GotoXY(1, 1);
   write('Bitte warten. IFC-Karten am Mil-Bus werden gesucht!');

   FOR ifb_adr := 1 TO 255 DO                                  { Clear Array }
     ifb_online[ifb_adr] := FALSE;

   FOR ifb_adr := 1 TO 255 DO                  { Fill Array with actual data }
    Begin
     IF mil.ifc_online (ifb_adr) THEN
      Begin
       ifb_online[ifb_adr] := TRUE;
       ifc_total := ifc_total + 1;
      End;
   End; {FOR}
   zeile := start_zeile;
   i := 0;
   ini_text_win;
   GotoXY(1, start_zeile - 1); ClrEol;
   write('              Am MIL-Bus melden sich folgende IFC-Karten: ');
   FOR ifb_adr := 1 TO 255 DO
     Begin
       IF ifb_online[ifb_adr] THEN
         Begin
          i := i + 1;
          GotoXY(5, zeile);
          hex_str := hex_byte(ifb_adr);
          write('Activ: ',ifb_adr:3,'  ',hex_str,' [Hex]'); ClrEol;
          IF (i > 15)  THEN
            Begin
              ini_err_win;
              GotoXY(1, 1);
              write('Mehr als 15 Karten!!    Any key to go on!');
              ch := READKEY;
              FOR zeile := start_zeile TO start_zeile + 16 DO
                Begin  GotoXY(1, zeile); ClrEol; End;
              zeile := start_zeile;
            End;
          zeile := zeile + 1;
         End;
     End;
   ini_msg_win;
   GotoXY(1, 1);
   write('IFC-Karten total: ',ifc_total,'     Any key to go on!');
   ch := READKEY;
  End; {detect_ifc}


 PROCEDURE Mil_Ask_Ifc;
  VAR answer : CHAR;
  Begin
    status := FALSE;
    WHILE NOT status DO
     Begin
      Ini_Text_Win;
      GotoXY(5, 22);
      write ('Welche IFC-Karten-Adr. testen?');
      ifc_test_nr := ask_hex_byte;
      IF ifc_test_nr IN [1..255] THEN status := TRUE;
     End;
  End; {ask_ifc}

FUNCTION Ask_Data: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    Ini_text_win;
    GotoXY(5, 22);
    write ('FÅr den MIL-Transfer-Test werden die WRITE-Daten benîtigt!! ');
    ini_msg_win;
    write   ('--> Bitte 4-stellige Hex-Daten eingeben: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
      Begin
       ini_err_win;
       writeln('ERROR: Sorry, USER: das war keine 4-stell. Hexzahl!!');
      End;
   End; {WHILE}
  ask_data := in_data;
 End; {Ask_Data}


 PROCEDURE displ_ifc_stat;
  Begin
     {Info-Anzeige der Bit-Belegung IFC-Status}
      ini_info_win;
      writeln('Bit 15: Intrlck_Mask  0-Disabl');
      writeln('Bit 14: Dta_Rdy_Mask  0-Disabl');
      writeln('Bit 13: Dta_Req_Mask  0-Disabl');
      writeln('Bit 12: Intrlck-Sign  1-aktiv ');
      writeln('Bit 11: Dta-Rdy-Sign  1-aktiv ');
      writeln('Bit 10: Dta-Req-Sign  1-aktiv ');
      writeln('Bit 09: frei                  ');
      writeln('Bit 08: frei                  ');
      writeln;
      writeln('Bit 07: A7 IFC-Adr            ');
      writeln(' "  |   |    "                ');
      write  ('Bit 00: A0 IFC-Adr            ');
   End; {displ_ifc_stat}

 PROCEDURE displ_pc_stat;
  Begin
     {Info-Anzeige der Bit-Belegung Hardware-Status}
      ini_info_win;
      writeln('Bit 11: Timer2: 0=10us  1=1ms');
      writeln('Bit 10: Timer2: Timeout      ');
      writeln('Bit 09: Timer1: Timeout      ');
      writeln('Bit 08: CMD/DATA receive     ');
      writeln('Bit 07: CMD/DATA transmit    ');
      writeln('Bit 06: Fifo full            ');
      writeln('Bit 05: Fifo empty           ');
      writeln('Bit 04: Valid Word           ');
      writeln('Bit 03: Ready for Write      ');
      writeln('Bit 02: Data Req             ');
      writeln('Bit 01: Data Ready           ');
      write  ('Bit 00: Interlock            ');
   End; {displ_dyn_stat_bits}

 PROCEDURE mil_rd_ifc_stat;
  Label 99;
  VAR read_data,fct_code : WORD;
      MilErr : TMilErr;
      Fct    : TFct;

   PROCEDURE show_stat_reg;
    Begin
     Mil.Rd (read_data, Fct, MilErr);
     GotoXY(28, 14);  write(hex_word(read_data));
     Hex_Bin_Str (read_data,bit16_str);
     GotoXY(22, 16);  write(bit16_str);
    End;

  Begin
    Ini_Text_Win;
    displ_ifc_stat;
    set_text_win;

    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Fct_Rd_Status;

    transf_cnt := 0;
    timout_cnt := 0;
    GotoXY(02,02); write('Hinweis: Mit dem MIL-Monitor (F 414) im ACTIV-Mode kînnen DReq, DRdy, Intl ');
    GotoXY(02,03); write('ÅberprÅft werden. Dazu am Monitor die Knîpfe INTRL, DRDY, DREQ betÑtigen!  ');
    GotoXY(22,06); write('----- Lese Status von der IFC-Karte -----');
    GotoXY(25,07); write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');

    GotoXY(06,11);  write('Rd_Stat_Cnt:');
    GotoXY(26,12);  write('^  ^');
    GotoXY(06,14);  write('Stat-Data[Hex]');
    GotoXY(06,16);  write('Stat-Data[Bin]');
    GotoXY(22,17);  write('MSB             LSB');

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
      repeat until KeyPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(20, 11); write(transf_cnt:12);
      show_stat_reg;
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
 End; {mil_rd_ifc_stat}


 PROCEDURE mil_rd_status;     {Internes Register PC-Karte}
  Label 99;                   {Direkter Zugriff auf Port ist hier Ausnahme!!}
  VAR read_data : WORD;

   PROCEDURE show_stat_reg;
    Begin
     read_data := PORTW [Port_Stat]; {sonst nur Åber Variable Mil : T_Mil}
     GotoXY(28, 15);  write(hex_word(read_data));
     Hex_Bin_Str (read_data,bit16_str);
     GotoXY(22, 16);  write(bit16_str);
    End;

   Begin
    Ini_Text_Win;            {Defin. Fenster, lîsche Fenster}
    displ_pc_stat;           {Zeige die Bitbelegung als Info}
    set_text_win;            {Textfenster restaurieren ohne Info zu lîschen}
    transf_cnt := 0;
    timout_cnt := 0;

    GotoXY(02,02); write('Hinweis: DReq, DRdy, Intl erscheinen normalerweise nur, wenn auf der IFC die');
    GotoXY(02,03); write('Intr-Maske mit Fct-Code [12H] enabled wurde bzw. wenn am MIL-Monitor (F 414)');
    GotoXY(02,04); write('im PASSIV-Mode die Leitungen INTRL, DRDY, DREQ betÑtigt werden!             ');

    GotoXY(21,07); write('----- Interner Status PC-Karte -----');
    GotoXY(06,11); write('Rd_Stat_Cnt:');
    GotoXY(26,12); write('^  ^');
    GotoXY(06,15); write('Stat-Data[HEX]');
    GotoXY(06,16); write('Stat-Data[BIN]');
    GotoXY(22,17); write('MSB             LSB');

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
      repeat until KeyPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(20, 11); write(transf_cnt:12);
      show_stat_reg;
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
  End; {mil_rd_status}

  PROCEDURE Mil_Rd_Fifo;       {Lese internes Rcv-Datenreg}
  Label 99;
  VAR read_data : WORD;        {Direkter Zugriff auf Port ist hier Ausnahme!!}
   Begin
    Ini_Text_Win;
    transf_cnt := 0;
    GotoXY(16,07);  write('----- Lese Datenregister der PC-Karte -----');
    GotoXY(6, 11);  writeln('Rd_Data_Cnt:');
    GotoXY(26,12);  writeln('^  ^');
    GotoXY(6, 14);  writeln('Read-Data[H]');

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
      repeat until KeyPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(20, 11); write(transf_cnt:12);
      read_data := PORTW [Port_Data];    {sonst nur Åber Variable Mil : T_Mil}
      GotoXY(28, 14);  write(hex_word(read_data));
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
 End; {mil_rd_fifo}

 PROCEDURE Mil_Rd_Data;
  Label 99;
  VAR read_data,pc_status : WORD;
      rd_timeout : BOOLEAN;
      MilErr : TMilErr;
      Fct    : TFct;
      Fct_ok : Boolean;

   PROCEDURE get_data;
    Begin
     Mil.Rd (read_data, Fct, MilErr);
     IF MilErr  <> No_Err THEN
      Begin
        timout_cnt := timout_cnt + 1;
        rd_timeout := TRUE;
        GotoXY(22,12); write(timout_cnt:12);
      End
     ELSE
      Begin  {kein Timeout}
       rd_timeout := FALSE;
       GotoXY(28, 17);  write(hex_word(read_data));
       Hex_Bin_Str (read_data,bit16_str);
       GotoXY(22, 18);  write(bit16_str);
      End;
    End; {get_data}

   Begin
    transf_cnt := 0;
    timout_cnt := 0;
    Fct_ok     := False;

    Fct.B.Adr := Ifc_Test_Nr;
    repeat
      Ini_Text_Win;
      GotoXY(5, 22);
      write ('Welchen READ-Function-Code [80H...FFH] ??');
      Fct.B.Fct := ask_hex_byte;
      if Fct.B.Fct < $80 then
       begin
         Ini_Err_Win;
         write ('Error: Read-Function-Code nicht 80H..FFh!!! Weiter mit <Space> ');
         repeat until keypressed;
         Ch := ReadKey;
       end
      else
       Fct_ok := True;
    until Fct_ok;

    Ini_Text_Win;
    GotoXY(22,05); write('----- Lese Daten von der IFC-Karte -----');
    GotoXY(25,09); write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
    GotoXY(06,11); writeln('Rd_Data_Cnt  :');
    GotoXY(26,12); writeln('^  ^');
    GotoXY(06,12); writeln('Timeout_Count: ');
    GotoXY(22,12); writeln(timout_cnt:12);

    GotoXY(06,17); writeln('MIL-Data[H]:');
    GotoXY(13,18); writeln('[Bin]');
    GotoXY(22,19); writeln('MSB             LSB');

    IF (Fct.B.Fct AND $C9) = $C9 THEN
     begin
      displ_ifc_stat;                         {Anzeige nur bei C9-Fct-Code}
      set_text_win;            {Textfenster restaurieren ohne Info zu lîschen}
     end;

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
      repeat until KeyPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(22, 11); write(transf_cnt:12);
      get_data;
      IF rd_timeout THEN
       begin
        GotoXY(28, 17);  write('    ');
        GotoXY(22, 18);  write('                   ');
        mil.reset;
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
  End; {mil_rd_data}

 PROCEDURE Mil_Wr_Fctcode;
 Label 99;
 VAR
    MilErr : TMilErr;
    Fct    : TFct;
   Begin
    Ini_Text_Win;
    GotoXY(5, 22);
    write ('Welchen Function-Code ??');
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := ask_hex_byte;
    Ini_Text_Win;

    transf_cnt := 0;
    GotoXY(19,05); write('----- Schreibe Function-Code zur IFC-Karte -----');
    GotoXY(25,08); write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
    GotoXY(25,08); write  ('Function: ',hex_word(Fct.W),' [H]');
    GotoXY(6, 11); writeln('Wr_Fct_Cnt :');
    GotoXY(26,12); writeln('^  ^');
   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
      repeat until KeyPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(20, 11); write(transf_cnt:12);
      Mil.WrFct (Fct, MilErr);
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
  End; {mil_wr_fctcode}

procedure Mil_WrData (mil_data: Word);   {nur Datenschreiben, ohne Fct-Code}
 label 99;
 VAR  MilErr : TMilErr;

   Begin
    Ini_Text_Win;
    transf_cnt:= 0;
    GotoXY(15,05); write('----- Schreibe Daten auf den MIL-BUS ohne Fct-Code -----');

    GotoXY(20, 8);
    write  ('MIL-Daten: ',hex_word(mil_data),' [H]');
    GotoXY(6, 11); writeln('Datentransf:');
    GotoXY(29,12); writeln('^  ^');

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
      repeat until KeyPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,11);  Write(Transf_Cnt:10);
      Mil.WrDta (mil_data, MilErr);
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
End; {Mil_WrData}


 Procedure Mil_Wr (Write_Data: WORD);
  LABEL 99;
   VAR
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;

   Begin
    Ini_Text_Win;
    GotoXY(5, 22);
    write ('Welchen Write-Function-Code ??');
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := ask_hex_byte;
    Ini_Text_Win;

    transf_cnt := 0;
    error_cnt  := 0;
    timout_wr  := 0;

    GotoXY(15,05); write('----- Schreibe Daten auf den MIL-BUS mit Fct-Code -----');
    GotoXY(25,08); write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
    GotoXY(6, 11); writeln('Wr-Data-Cnt:              Write-Data[H]:                ');
    GotoXY(22,12); writeln('^  ^');
    GotoXY(53,11); write('Timeout:');
    GotoXY(61,11); write(timout_wr:10);
    GotoXY(47,11); write(hex_word(write_data));

    Mil.Reset;                            { clear fifo }
    Ch := ' ';
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyPressed;
       Ch := ReadKey;
       if  Ch in ['x','X'] then Goto 99;
      end;

    repeat
     repeat
       Set_Text_win;
       Transf_Cnt := Transf_Cnt+ 1;
       GotoXY(18,11); write(transf_cnt:10);
       Mil.Wr (Write_Data, Fct, MilErr);
       if MilErr <> No_err then
        begin
         timout_wr := timout_wr + 1;
         GotoXY(61, 11); write(timout_wr:10);
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
End; {mil_wr}

 procedure Mil_Wr_Rd (Write_Data: WORD);
  Label 99;
   VAR
    i,pc_status: WORD;
    error_cnt  : LONGINT;
    wr_fct_code: WORD;
    rd_fct_code: WORD;
    MilErr     : TMilErr;
    Fct        : TFct;

    function Get_Data: WORD;
     var read_data : Word;
     begin
      Fct.B.Fct := rd_fct_code;
      Mil.Rd (read_data, Fct, MilErr);
      if MilErr  <> No_Err then
       begin
        rd_timeout := TRUE;
        timout_rd := timout_rd + 1;
       end
      else
       begin  {kein Timeout}
        rd_timeout:= FALSE;
        get_data  := read_data;
       end;
     end; {Get_Data}

   Begin
    Ini_Text_Win;
    transf_cnt := 0;
    error_cnt := 0;
    timout_wr := 0; timout_rd := 0;
    Fct.B.Adr := Ifc_Test_Nr;

    GotoXY(5, 22);
    write ('Welchen Write-Function-Code ??');
    wr_fct_code := ask_hex_byte;
    Ini_Text_Win;

    GotoXY(5, 22);
    write ('Welchen Read-Function-Code  ??');
    rd_fct_code := ask_hex_byte;
    Ini_Text_Win;

    GotoXY(15,05); write('----- Daten zur IFC: schreiben/lesen und ÅberprÅfen -----');
    Fct.B.Fct := wr_fct_code;
    GotoXY(25, 8);  write ('WR-Fct: ',hex_word(Fct.W),' [H]   RD-Fct: ');
    Fct.B.Fct := rd_fct_code; write(hex_word(Fct.W),' [H]');
    GotoXY(6, 11);  writeln('Wr_Data_Cnt:              Write-Data[H]:                ');
    GotoXY(6, 14);  writeln('Error_Count:              Read-Data [H]:                ');
    GotoXY(18,14);  write(error_cnt:10);
    GotoXY(22,12);  writeln('^  ^');
    GotoXY(22,15);  writeln('^  ^');
    GotoXY(53,11);  write('Timeout:');
    GotoXY(53,14);  write('Timeout:');
    GotoXY(61,14);  write(timout_rd:10);
    GotoXY(61,11);  write(timout_wr:10);

    Mil.reset;      {Clear Fifo}
    Ch := ' ';
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyPressed;
       Ch := ReadKey;
       if  Ch in ['x','X'] then Goto 99;
      end;

    repeat
     repeat
       Set_Text_win;
       Transf_Cnt := Transf_Cnt+ 1;
       GotoXY(18,11); write(transf_cnt:10);
       GotoXY(47,11); write(hex_word(write_data));
       Fct.B.Fct := wr_fct_code;
       Mil.Wr (write_data, Fct, MilErr);
       read_data := get_data;
       IF rd_timeout THEN
         Begin
           GotoXY(61,14); write(timout_rd:10);
           GotoXY(47,14); write('    ');
           mil.reset;
         End
       ELSE
         Begin
           GotoXY(47,14);  write(hex_word(read_data));
         End;
       IF (NOT rd_timeout) AND (read_data <> write_data) THEN
        Begin
         error_cnt := error_cnt + 1;
         GotoXY(18,14); write(error_cnt:10);
        End;
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
 End; {Mil_Wr_Rd}


 PROCEDURE Mil_Loop;
   LABEL 99;
   VAR
    i,pc_status: WORD;
    error_cnt  : LONGINT;
    mil_status : WORD;
    wr_fct_code, rd_fct_code : WORD;
    MilErr     : TMilErr;
    Fct        : TFct;

    function Get_Data: WORD;
     var read_data : Word;
     begin
      Fct.B.Fct := Rd_Fct_Code;
      Mil.Rd (Read_Data, Fct, MilErr);
      if MilErr  <> No_Err then
       begin
        rd_timeout := TRUE;
        timout_rd := timout_rd + 1;
       end
      else
       begin  {kein Timeout}
        rd_timeout:= FALSE;
        get_data  := read_data;
       end;
     end; {Get_Data}

   Begin
    Ini_Text_Win;
    transf_cnt:= 0;
    error_cnt := 0;
    timout_wr := 0; timout_rd := 0;
    Fct.B.Adr := Ifc_Test_Nr;

    GotoXY(5, 22);
    write ('Welchen Write-Function-Code ??');
    wr_fct_code := ask_hex_byte;
    Ini_Text_Win;

    GotoXY(5, 22);
    write ('Welchen Read-Function-Code  ??');
    rd_fct_code := ask_hex_byte;
    Ini_Text_Win;

    GotoXY(02,04); write('---- Daten (0000 .. FFFF) im Loop zur IFC: schreiben/lesen und ÅberprÅfen ----');
    GotoXY(4,07);
    write('Achtung: Dieser Test benîtigt eine IFC-Karte am MIL-BUS mit (FCT + ADR): ');

    GotoXY(15,08);
    Fct.B.Fct := wr_fct_code;
    write  ('Wr-Fct-Code: ', hex_word(Fct.W),'[H]     ');
    Fct.B.Fct := rd_fct_code;
    write  ('Rd-Fct-Code: ', hex_word(Fct.W),'[H]');

    GotoXY(6, 11);
    writeln('Wr_Data_Cnt:              Write-Data[H]:                ');
    GotoXY(6, 14);
    writeln('Error_Count:              Read-Data [H]:                ');
    GotoXY(18,14); write(error_cnt:10);
    GotoXY(22,12);  writeln('^  ^');
    GotoXY(22,15);  writeln('^  ^');
    GotoXY(53,11);  write('Timeout:');
    GotoXY(53,14);  write('Timeout:');
    GotoXY(61,14);  write(timout_rd:10);
    GotoXY(61,11);  write(timout_wr:10);

    mil.reset;      {Clear Fifo}

    Ch := ' ';
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyPressed;
       Ch := ReadKey;
       if  Ch in ['x','X'] then Goto 99;
      end;

    i := 0;
    repeat
     repeat
       Set_Text_win;
       transf_cnt:= transf_cnt+ 1;
       GotoXY(18,11); write(transf_cnt:10);
       GotoXY(47,11); write(hex_word(i));

       Fct.B.Fct := wr_fct_code;
       Mil.Wr (i, Fct, MilErr);
       read_data := get_data;
       IF rd_timeout THEN
         Begin
           GotoXY(61,14); write(timout_rd:10);
           GotoXY(47,14); write('    ');
           mil.reset;
         End
       ELSE
         Begin
           GotoXY(47,14);  write(hex_word(read_data));
         End;

       IF (NOT rd_timeout) AND (read_data <> i) THEN
         Begin
           error_cnt := error_cnt + 1;
           GotoXY(18,14); write(error_cnt:10);
         End;
       i := i + 1;
       if (i = $FFFF + 1) then i := 0;
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
 End; {mil_loop}

procedure Mil_Dual_Mode;
 label 99;
 var  MilErr : TMilErr;
      Fct    : TFct;

  Begin
    Dual[1].Dta_ok := False;
    Dual[2].Dta_ok := False;

    ini_text_win;
    GotoXY(03,04); write('--- Dual Mode: Sende 2 Fct-Codes und/oder 2 Daten auf 1 oder 2 Adressen ---');
    GotoXY(5, 22);
    write ('Welche MIL-Adr Nr. 1 ?');
    Dual[1].Adr := ask_hex_byte;

    ini_text_win;
    GotoXY(03,04); write('--- Dual Mode: Sende 2 Fct-Codes und/oder 2 Daten auf 1 oder 2 Adressen ---');
    GotoXY(5, 15);  write (' Adr 1      : ', hex_byte(Dual[1].Adr));
    GotoXY(5, 22);
    write ('Welche MIL-Adr Nr. 2 ?');
    Dual[2].Adr := ask_hex_byte;

    ini_text_win;
    GotoXY(03,04); write('--- Dual Mode: Sende 2 Fct-Codes und/oder 2 Daten auf 1 oder 2 Adressen ---');
    GotoXY(5, 15);  write (' Adr 1      : ', hex_byte(Dual[1].Adr));
    GotoXY(5, 16);  write (' Adr 2      : ', hex_byte(Dual[2].Adr));
    GotoXY(5, 22);
    write ('Welchen Function-Code Nr. 1 ?');
    Dual[1].Fct := ask_hex_byte;

    Ini_Text_Win;
    GotoXY(03,04); write('--- Dual Mode: Sende 2 Fct-Codes und/oder 2 Daten auf 1 oder 2 Adressen ---');
    GotoXY(5, 15);  write (' Adr 1      : ', hex_byte(Dual[1].Adr));
    GotoXY(5, 16);  write (' Adr 2      : ', hex_byte(Dual[2].Adr));
    GotoXY(5, 17);  write (' Fct 1      : ', hex_byte(Dual[1].Fct));
    GotoXY(5, 22);
    write ('Welchen Function-Code Nr. 2 ?');
    Dual[2].Fct := ask_hex_byte;

    Ini_Text_Win;
    GotoXY(03,04); write('--- Dual Mode: Sende 2 Fct-Codes und/oder 2 Daten auf 1 oder 2 Adressen ---');
    GotoXY(5, 15);  write (' Adr 1      : ', hex_byte(Dual[1].Adr));
    GotoXY(5, 16);  write (' Adr 2      : ', hex_byte(Dual[2].Adr));
    GotoXY(5, 17);  write (' Fct 1      : ', hex_byte(Dual[1].Fct));
    GotoXY(5, 18);  write (' Fct 2      : ', hex_byte(Dual[2].Fct));

    Ini_Msg_Win;
    write ('Sollen zu Fct-Code 1 auch Daten gesendet werden? [J/N]: ');
    repeat until KeyPressed;
    Ch := ReadKey;
    if Ch in ['j','J'] then
     begin
       Dual[1].Dta    := Ask_Data;
       Dual[1].Dta_ok := True;
       Ini_Text_Win;
       GotoXY(03,04); write('--- Dual Mode: Sende 2 Fct-Codes und/oder 2 Daten auf 1 oder 2 Adressen ---');
       GotoXY(5, 15);  write (' Adr 1      : ', hex_byte(Dual[1].Adr));
       GotoXY(5, 16);  write (' Adr 2      : ', hex_byte(Dual[2].Adr));
       GotoXY(5, 17);  write (' Fct 1      : ', hex_byte(Dual[1].Fct));
       GotoXY(5, 18);  write (' Fct 2      : ', hex_byte(Dual[2].Fct));
       GotoXY(5, 19);  write (' Dat 1      : ', hex_word(Dual[1].Dta));
     end
    else
     begin
      Dual[1].Dta_ok := False;
      Set_Text_Win;
      GotoXY(5, 22);
      write ('                                                                ');
     end;

    Ini_Msg_Win;
    write ('Sollen zu Fct-Code 2 auch Daten gesendet werden? [J/N]: ');
    repeat until KeyPressed;
    Ch := ReadKey;
    if Ch in ['j','J'] then
     begin
       Dual[2].Dta    := Ask_Data;
       Dual[2].Dta_ok := True;
       Ini_Text_Win;
       GotoXY(03,04); write('--- Dual Mode: Sende 2 Fct-Codes und/oder 2 Daten auf 1 oder 2 Adressen ---');
       GotoXY(5, 15);  write (' Adr 1      : ', hex_byte(Dual[1].Adr));
       GotoXY(5, 16);  write (' Adr 2      : ', hex_byte(Dual[2].Adr));
       GotoXY(5, 17);  write (' Fct 1      : ', hex_byte(Dual[1].Fct));
       GotoXY(5, 18);  write (' Fct 2      : ', hex_byte(Dual[2].Fct));
       if Dual[1].Dta_ok then
        begin
         GotoXY(5, 19);  write (' Dat 1      : ', hex_word(Dual[1].Dta));
        end;
       GotoXY(5, 20);  write (' Dat 2      : ', hex_word(Dual[2].Dta));
     end
    else
     begin
      Dual[2].Dta_ok := False;
      Ini_Text_Win;
      GotoXY(03,04); write('--- Dual Mode: Sende 2 Fct-Codes und/oder 2 Daten auf 1 oder 2 Adressen ---');
      GotoXY(5, 15);  write (' Adr 1      : ', hex_byte(Dual[1].Adr));
      GotoXY(5, 16);  write (' Adr 2      : ', hex_byte(Dual[2].Adr));
      GotoXY(5, 17);  write (' Fct 1      : ', hex_byte(Dual[1].Fct));
      GotoXY(5, 18);  write (' Fct 2      : ', hex_byte(Dual[2].Fct));
      if Dual[1].Dta_ok then
       begin
        GotoXY(5, 19);  write (' Dat 1      : ', hex_word(Dual[1].Dta));
       end;
     end;

    Ini_Msg_Win;
    write ('Dateneingabe ok? [J/N]: ');
    repeat until KeyPressed;
    Ch := ReadKey;
    if Ch in ['n','N'] then Goto 99;

    Ini_Text_Win;
    transf_cnt := 0;
    GotoXY(03,04); write('--- Dual Mode: Sende 2 Fct-Codes und/oder 2 Daten auf 1 oder 2 Adressen ---');
    GotoXY(15,07); write  ('Function-Word1: ',hex_byte(Dual[1].Fct),hex_byte(Dual[1].Adr) ,' [H]');
    GotoXY(15,08); write  ('Function-Word2: ',hex_byte(Dual[2].Fct),hex_byte(Dual[2].Adr) ,' [H]');

    GotoXY(50,07);
    if Dual[1].Dta_ok then write ('Data 1: ',hex_word(Dual[1].Dta),' [H]')
    else  write ('                        ');

    GotoXY(50,08);
    if Dual[2].Dta_ok then write  ('Data 2: ',hex_word(Dual[2].Dta),' [H]')
    else  write ('                        ');

    GotoXY(6, 11); writeln('Wr_Fct_Cnt :');
    GotoXY(29,12); writeln('^  ^');

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
      repeat until KeyPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,11);  Write(Transf_Cnt:10);

      if  Dual[1].Dta_ok then
       begin
        Mil.Timer2_Wait(5);
        Mil.WrDta (Dual[1].Dta, MilErr);
       end;

      Mil.Timer2_Wait(5);
      Fct.B.Adr := Dual[1].Adr;
      Fct.B.Fct := Dual[1].Fct;
      Mil.WrFct (Fct, MilErr);

      if  Dual[2].Dta_ok then
       begin
        Mil.Timer2_Wait(5);
        Mil.WrDta (Dual[2].Dta, MilErr);
       end;

      Mil.Timer2_Wait(5);                                     { Wartet 5x10us}
      Fct.B.Adr := Dual[2].Adr;;
      Fct.B.Fct := Dual[2].Fct;;
      Mil.WrFct (Fct, MilErr);

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
End; {Mil_WrDual_Fct}

FUNCTION Ask_IO_Adr: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    Ini_text_win;
    GotoXY(5, 22);
    write ('Bitte I/O-Adresse eingeben !! ');
    ini_msg_win;
    write   ('--> Bitte 4-stellige Hex-Adresse eingeben: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
      Begin
       ini_err_win;
       writeln('ERROR: Sorry, USER: das war keine 4-stell. Hexzahl!!');
      End;
   End; {WHILE}
  Ask_IO_Adr := in_data;
 End; { Ask_IO_Adr}

{xxx}  {Ab hier sollten User-Erweiterungen beginnen!!}
 function IO_Mod_Online (Ifc_Adr: Byte; Mod_Adr: Byte): Boolean;
  var
   MilErr : TMilErr;
   Fct    : TFct;
   Read_Data : Word;
  begin
    IO_Mod_Online := False;
    Fct_11_Dta:= (Mod_Adr*256) + IOsub_Adr_Skal;  {Modul-Adr is Hibyte, Subadr Lowbyte}
    Fct.B.Adr  := Ifc_Adr;
    Fct.B.Fct  := Fct_Wr_Iob_Adr;
    Mil.Wr (Fct_11_Dta, Fct, MilErr);                        {Adr zum I/O-Bus}

    Fct.B.Fct  :=  Fct_Rd_Iob_Dta;                {Lesen Daten von APL-IO-Bus}
    Mil.Rd (Read_Data, Fct, MilErr); {Anwort: Hibyte=Skalierng, Lobyte=Modadr}
    if MilErr = No_Err then
      if (Read_Data and $00FF) = Mod_Adr then IO_Mod_Online := True;
  end; {IO_Mod_Online}

 procedure Mil_Detect_IO_Modul;
   LABEL 99;
   const  Z_Mod_Start = 5;
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

   procedure Displ_Mod_Headline;
    begin
     Ini_Text_Win;
     GotoXY(15,01); write('----- Finde IFC-Karten, I/O-Module und Ident -----');
     GotoXY(05,03); write('IFC-Adr   Modul-Adr     ID-Crd ID-VG  Skal  Mod-Adr    EPLD  Frei ');
     GotoXY(05,04); write(' [Hex]      [Hex]        <FE    FF>    <FC    FD>      <FA    FB> ');
     Ini_Msg_Win;
     Write('Weiter mit  <SPACE>,  Ende mit [X]');
     Set_Text_Win;
    end;

   procedure Displ_Mod_Info (Ifc_Adr: Byte; Mod_Adr: Byte; Z_Mod: Byte);
    const S_Mod_ID_Dta  = 32;      {Default Spalte fÅr Modulidentdaten}
    var   IOsub_Adr    : Byte;
          Fct_11_Dta   : Word;
          S_Mod_Akt    : Byte;
          V            : Byte;
    begin
     Set_Text_Win;
     S_Mod_Akt := S_Mod_ID_Dta;
     GotoXY(08,Z_Mod); write(Hex_Byte(Ifc_Adr),'         ',Hex_Byte(Mod_Adr));
     IOsub_Adr := $FE;                               {Word-Adr fÅr Identdaten}

     for V := 1 to 3  do                         {Lese 3 Worte mit Identdaten}
      begin
        Fct.B.Adr  := Ifc_Adr;
        Fct_11_Dta:= (Mod_Adr*256) + IOsub_Adr;  {Modul-Adr ins Hibyte, Subadr Lowbyte}
        Fct.B.Fct  := Fct_Wr_Iob_Adr;
        Mil.Wr (Fct_11_Dta, Fct, MilErr);                     {Adr zum I/O-Bus}

        Fct.B.Fct  :=  Fct_Rd_Iob_Dta;             {Lesen Daten von APL-IO-Bus}
        Mil.Rd (Read_Data, Fct, MilErr);

        GotoXY(S_Mod_Akt,Z_Mod);
        Write (hex_word(Read_Data));
        S_Mod_Akt := S_Mod_Akt + 15;
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
      IF mil.ifc_online (ifb_adr) THEN
       Begin
        ifb_online[ifb_adr] := TRUE;
        ifc_total := ifc_total + 1;
       End;
    End;

    Ini_Text_Win;
    Displ_Mod_Headline;

     M := 0;
     Ifb_Adr := 1;
     Mod_Zeile := Z_Mod_Start;

     repeat
       Set_Text_win;
       if ifb_online [ifb_adr] then
         begin
           for M := 0 to $1F do            {alle mîglichen Modul-Adr abfragen}
             begin
               IF IO_Mod_Online (Ifb_Adr, M) THEN
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
                      Write('Weiter mit <SPACE>,   Ende mit [X]');
                      Ch := ReadKey;
                      if Ch in ['x','X'] then goto 99;
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
           Write('Ende mit beliebiger Taste!');
           repeat until KeyPressed;
           goto 99;
         end;
      until KeyPressed;
    99:
End; {Mil_Detect_IO_Modul}

 PROCEDURE Displ_NG_Stat_Info;
  Begin
     {Info-Anzeige der Bit-Belegung IFC-Status}
      ini_info_win;
      writeln('Bit 15: --                    ');
      writeln('Bit 14: --                    ');
      writeln('Bit 13: KÅhlwasser ok 1-aktiv ');
      writeln('Bit 12: Temperatur ok 1-aktiv ');
      writeln('Bit 11: Pulsbetrieb   1-aktiv ');
      writeln('Bit 10: Betriebsber.  1-aktiv ');
      writeln('Bit 09: Spannung > 0  1-aktiv ');
      writeln('Bit 08: GerÑt Ein/Aus 1-Ein   ');
      writeln;
      writeln('Bit 07: A7 IFC-Adr            ');
      writeln(' "  |   |    "                ');
      write  ('Bit 00: A0 IFC-Adr            ');
   End; {displ_ifc_stat}


Procedure Mil_IQ_Stat_NG;
  LABEL 99;
  CONST HF_Fct_C0 = $C0;

  VAR
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;

   FUNCTION get_data: WORD;
    var rd_data : Word;
    Begin
     Fct.B.Fct := $C0;
     Mil.Rd (rd_data, Fct, MilErr);
     IF MilErr  <> No_Err THEN
      Begin
        rd_timeout := TRUE;
        timout_rd := timout_rd + 1;
      End
     ELSE
      Begin  {kein Timeout}
       rd_timeout:= FALSE;
       get_data  := rd_data;
      End;
    End; {get_data}

  begin
   Ini_Text_Win;
   timout_rd := 0;
   Fct.B.Adr := Ifc_Test_Nr;
   Transf_Cnt:= 0;

   {Init Display}
   GotoXY(15,03); write('----- Lese den Status des Ionenquellen-NetzgerÑtes -----');
   GotoXY(08,10);  Write('Transfer-Count: ');
   GotoXY(08,11);  Write('Timeout       : ');
   GotoXY(08,12);  Write('Funktion [Hex]: ');
   GotoXY(33,12);  Write(Hex_Byte(HF_Fct_C0));
   GotoXY(08,13);  Write('Data     [Hex]: ');
   GotoXY(08,14);  write('Stat-Data[BIN]:');
   GotoXY(25,15);  write('MSB             LSB');
   GotoXY(25,10);  Write(Transf_Cnt:10);
   GotoXY(25,11);  write(timout_rd:10);

   Displ_NG_Stat_Info;
   Ini_Msg_Win;
   Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
      repeat until KeyPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,10);  Write(Transf_Cnt:10);

      read_data := get_data;
      IF rd_timeout THEN
        Begin
         GotoXY(31,13); write('    ');
        End
      ELSE
        Begin
          GotoXY(31,13);  write(hex_word(read_data));
        End;
      GotoXY(25,11);  write(timout_rd:10);

     Hex_Bin_Str (read_data,bit16_str);
     GotoXY(25, 14);  write(bit16_str);


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
End; {Mil_NG_Stat}

procedure Mil_IQ_Istw;
  label 99;
  const Off_Strom = 30;

  VAR
     Bit16_Strg: Str19;
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;
     Read_Data : Word;

   FUNCTION get_dta: WORD;
    var rd_data : Word;
    Begin
     Mil.Rd (rd_data, Fct, MilErr);
     IF MilErr  <> No_Err THEN
      Begin
        rd_timeout := TRUE;
        timout_rd := timout_rd + 1;
      End
     ELSE
      Begin  {kein Timeout}
       rd_timeout:= FALSE;
       get_dta  := rd_data;
      End;
    End; {get_data}

  begin
   Ini_Text_Win;
   transf_cnt:= 0;
   timout_cnt:= 0;
   Fct.B.Adr := Ifc_Test_Nr;

   GotoXY(15,03); write('----- Istwerte Strom u. Spannung von NetzgerÑt IQ lesen -----');
   Fct.B.Fct := IQ_Fct_IwSpang;
   GotoXY(30,05);  write  ('Function-Word (Fct + Adr): ');
   GotoXY(15,06);  write  ('Istw-Spannung: ',hex_word(Fct.W),' [H]');

   Fct.B.Fct := IQ_Fct_IwStrom;
   GotoXY(20+Off_Strom,06);  write  ('Istw-Strom: ',hex_word(Fct.W),' [H]');
   GotoXY(06,11); writeln('Read_Count   :');
   GotoXY(26,12); writeln('^  ^');
   GotoXY(06,12); writeln('Timeout_Read : ');
   GotoXY(22,12); writeln(timout_cnt:12);
   GotoXY(22,11); writeln(transf_cnt:12);
   GotoXY(24,15); writeln('v-- Spannung --v');
   GotoXY(54,15); writeln('v--- Strom  ---v');
   GotoXY(06,16); writeln('MIL-DATA');
   GotoXY(12,17); writeln('[Hex]:');
   GotoXY(12,18); writeln('[Bin]:');
   GotoXY(12,18); writeln('[Bin]:');

   GotoXY(22,19);           writeln('MSB             LSB');
   GotoXY(22+Off_Strom,19); writeln('MSB             LSB');
   GotoXY(11,20);           Writeln('[Volt]:');

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
      repeat until KeyPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt + 1;
      GotoXY(22,11); write(transf_cnt:12);

      {Zuerst den Istwert Spannung lesen}
      Fct.B.Fct := IQ_Fct_IwSpang;
      Read_Data := Get_Dta;
      IF rd_timeout THEN
        Begin
         GotoXY(28, 17);  write('    ');
         GotoXY(22, 18);  write('                   ');
         timout_cnt := timout_cnt + 1;
         GotoXY(22,12); write(timout_cnt:12);
        End
      else
        begin
         GotoXY(28, 17);  write(hex_word(read_data));
         Hex_Bin_Str (read_data,bit16_str);
         GotoXY(22, 18);  write(bit16_str);
         GotoXY(26, 20);  Write_Real_10 (Read_Data);
        end;

      {Danach den Istwert Strom lesen}
      Fct.B.Fct := IQ_Fct_IwStrom;
      Read_Data := Get_Dta;
      IF rd_timeout THEN
        Begin
         GotoXY(28+Off_Strom, 17);  write('    ');
         GotoXY(22+Off_Strom, 18);  write('                   ');
         timout_cnt := timout_cnt + 1;
         GotoXY(22,12); write(timout_cnt:12);
        End
      else
        begin
         GotoXY(28+Off_Strom, 17);  write(hex_word(read_data));
         Hex_Bin_Str (read_data,bit16_str);
         GotoXY(22+Off_Strom, 18);  write(bit16_str);
         GotoXY(26+Off_Strom, 20);  Write_Real_10 (Read_Data);
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
End; {Mil_IQ_Istw;}

Procedure Mil_IQ_Sollw;
  LABEL 99;

  VAR
     Bit16_Strg: Str19;
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;
     write_data,Displ_Data : Word;

  begin
   Transf_Cnt := 0;
   Ini_Text_Win;
   Write_Data := Rd_Real_10;                         {Daten vom User erfragen}
   Ini_Text_Win;
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := IQ_Fct_Sollw;

   {Init Display}
   GotoXY(25,03); write('----- Sollwert Spannung setzen -----');
   GotoXY(08,10);  Write('Transfer-Count: ');
   GotoXY(08,11);  Write('Timeout       : ');
   GotoXY(08,12);  Write('Funktion [Hex]: ');
   GotoXY(33,12);  Write(Hex_Byte(Fct.B.Fct));
   GotoXY(08,13);  Write('Data     [Hex]: ');

   GotoXY(08,14);  write('Data     [BIN]:');
   GotoXY(25,15);  write('MSB             LSB');
   GotoXY(08,17);  write('Data    [Volt]:');
   Displ_Data := Write_Data;
   GotoXY(28,17);  Write_Real_10 (Displ_Data);

   GotoXY(31,13);  write(hex_word(Write_Data));
   Hex_Bin_Str (Write_Data,bit16_str);
   GotoXY(25, 14);  write(bit16_str);

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
      repeat until KeyPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,10);  Write(Transf_Cnt:10);

      Mil.Wr (write_data, Fct, MilErr);
      if MilErr <> No_err then
       begin
        Timout_Wr:= Timout_Wr +1;
        GotoXY(25,11);  write(timout_wr:10);
       end;
      GotoXY(25,11);  write(timout_wr:10);
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
End; {Mil_IQ_Sollw}

Procedure Mil_IQ_Cmd;
  LABEL 99;
  VAR
     Bit16_Strg: Str19;
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;
     NG_Stat    : Word;

   function Get_C0_Stat (var Status: WORD; Ifc_Adr: Byte): Boolean;
    var MilErr : TMilErr;
        Fct    : TFct;
    begin
     Get_C0_Stat := False;
     Fct.B.Adr := Ifc_Adr;
     Fct.B.Fct := $C0;
     Mil.Rd (Status, Fct, MilErr);
     if MilErr  =  No_Err then Get_C0_Stat := True;
    end; {Get_C0_Stat}

  procedure Displ_NG_Status;
   begin
    Set_Text_win;
    if Get_C0_Stat (NG_Stat, Ifc_Test_Nr) then
     begin
      GotoXY(31,13);  write(hex_word(NG_Stat));
      Hex_Bin_Str (NG_Stat,bit16_str);
      GotoXY(25, 14);  write(bit16_str);
     end
    else
     begin
      Timout_Wr:= Timout_Wr +1;
      GotoXY(25,10);  write(timout_wr:10);
      GotoXY(31,13);  write('                    ');
      GotoXY(25, 14);  write('                   ');
     end;
   end; {Displ_NG_Status;}

  begin
    Ini_Text_Win;
    Fct.B.Adr := Ifc_Test_Nr;
    transf_cnt:= 0;

    Ini_Msg_Win;
    Write('Welche Funktion:  Strom [E]in, Strom [A]us oder e[X]it?? ');
    Ch := ReadKey;
    case Ch of
     'a','A': Fct.B.Fct := IQ_Fct_Pwroff;
     'e','E': Fct.B.Fct := IQ_Fct_Pwron;
    else
     goto 99;
    end; {case}

   {Init Display}
   Ini_Text_Win;
   GotoXY(20,03); write('----- IQ-NetzgerÑt: Strom [');
   if Ch in ['a','A'] then Write('AUS] schalten -----');
   if Ch in ['e','E'] then Write('EIN] schalten -----');
   GotoXY(25,05);  write ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
   GotoXY(27,06);  write ('Im Loop: Verzîgerung: [',Wait_1_Sec DIV 100000:2,'.0 sec] ');

   GotoXY(08,09);  Write('Transfer-Count: ');
   GotoXY(08,10);  Write('Timeout       : ');

   GotoXY(08,13);  Write('Stat-Data[Hex]: ');
   GotoXY(08,14);  write('         [BIN]:');
   GotoXY(25,15);  write('MSB             LSB');

   Displ_NG_Stat_Info;
   Displ_NG_Status;

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
      repeat until KeyPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,09);  Write(Transf_Cnt:10);
      Mil.WrFct (Fct, MilErr);
      if MilErr <> No_err then
       begin
        Timout_Wr:= Timout_Wr +1;
        GotoXY(25,10);  write(timout_wr:10);
       end;
      GotoXY(25,10);  write(timout_wr:10);

      Mil.Timer2_Set(Wait_1_Sec);
      repeat
       Displ_NG_Status;
      until Mil.Timeout2;
    until KeyPressed or (Ch = ' ');
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat Displ_NG_Status until KeyPressed;
      end;
    Ch := ReadKey;
   until Ch in ['x','X'];
99:
End; {Mil_IQ_Cmd}


BEGIN   { Hauptprogramm }
  Ifc_Test_Nr := 0;

  Fct_11_Dta  := 0;
  Dual[1].Adr := 0;        {Init Dual-Mode Array}
  Dual[1].Fct := 0;
  Dual[1].Dta_ok := False;
  Dual[1].Dta := 0;
  Dual[2].Adr := 0;
  Dual[2].Fct := 0;
  Dual[2].Dta_ok := False;
  Dual[2].Dta := 0;

  REPEAT
    menue_win;
    User_Input := ReadKey;
    loop := TRUE;
    IF User_Input IN ['0'..'9'] THEN loop := FALSE;
    CASE User_Input OF
     '0'      : Mil_Detect_Ifc;
     'a', 'A' : Mil_Ask_Ifc;
     'b', 'B' : begin
                  if Check_Ifc_Adr then Mil_Rd_Ifc_Stat;
                end;
     'c', 'C' : begin
                  Mil_Rd_Status;
                end;
     'd', 'D' : begin
                  Mil_Rd_Fifo;
                end;
     'e', 'E' : begin
                  if Check_Ifc_Adr then Mil_Rd_Data;
		end;
     'f', 'F' : begin
                end;
     'g', 'G' : begin
                  Mil_Data := Ask_Data;
		  Mil_WrData (Mil_Data);
                end;
     'h', 'H' : begin
		  if Check_Ifc_Adr then Mil_Wr_Fctcode;
                end;
     'i', 'I' : begin
                  if Check_Ifc_Adr THEN
                   begin
		     Mil_Data := Ask_Data;
		     Mil_Wr (Mil_Data);
                   end;
                end;
     'j', 'J' : begin
		  if Check_Ifc_Adr then
		    begin
		     Mil_Data := Ask_Data;
		     Mil_Wr_Rd (Mil_Data);
 		    end;
                end;
     'k', 'K' : begin
		  if Check_Ifc_Adr then Mil_Loop;
                end;

     'l', 'L' : begin
                  Mil_Dual_Mode;
                end;
     'm', 'M' : begin
 		  Mil_Detect_IO_Modul;
                end;
     'n', 'N' : begin
                  if Check_Ifc_Adr then Mil_IQ_Stat_NG;
                 end;
     'o', 'O' : begin
                  if Check_Ifc_Adr then Mil_IQ_Istw;
                end;
     'q', 'Q' : begin
                  if Check_Ifc_Adr then Mil_IQ_Sollw;
                end;
     'p', 'P' : begin
                  if Check_Ifc_Adr then Mil_IQ_Cmd;
                end;
          't', 'T' : begin
                     end;
    End; {CASE}
  UNTIL user_input in ['x','X'];
  Window(1, 1, 80, 25);
  TextBackground(Black);
  ClrScr;
END. {mil_pc}

                {Loop- und Einzelschritt-Rahmen fÅr User-Erweiterungen }

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
      repeat until KeyPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;

    { hier kann der User seine eigenen Befehle einfÅgen!! }

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
