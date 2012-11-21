PROGRAM mil_vaku;           { Programm MIL_PC.PAS mit OOP-Unit MIL_LIB.TPU}
{ Autor: Gerhard Englert                            Turbo-Pascal Version 7.0

  Datenaufnahme und FLASH-EPROM Programmierung fÅr Vakuum-Me·gerÑt
  APL/Eick und Folger.
  öber 2 IFC-ADC-Karten werden Thermocouple-Spannungen gemessen und als
  Korrektur-Werte in ein FLASH-Eprom geschrieben.

}
{$S-}
uses Crt, WinDos, Mil_Lib, Mil_Flsh, syshlp;

CONST
 head_line =
      'Datentechnik                      MIL-PC     ' +
      '                       [23.11.1993]'+
      '            EPROMs f. Vakuum-Me·gerÑt FG_465_010 (Turbo_Pascal V7.0)';

 Vak_Fname = 'c:\vakuum.tab';

  msg_any_key =
      'Weiter mit beliebiger Taste!                                     ';
 msg_single_step =
      'Loop- u. Single-Test mit [Q] beenden!    Single-Step mit [SPACE] ';
 msg_ifc_equal =
      'IFC-Adr.  Ref,Mess,Flash mÅssen verschieden sein!  Weiter mit einer Taste: ';

 fct_rd_ist1    = $81;  {Lese ADC-Wert}

TYPE
 str4    = STRING[4];
 num_str = STRING[10];

  TDispl_Str     = record
                    Cor_Val:  Byte;       {Korrekturwert}
                    Dis_Val:  string[4];  {zugehîrige ASCII-Anzeige}
                   end;
  TDispl_Str_Ary = array [0..255] of TDispl_Str;
  TFile_Displ    = file of TDispl_Str_Ary;

 var         {Die Korrektur u. ASCII-Anzeige-Tabelle werden auf Disk abgelegt}
  Vak_File  : TFile_Displ; {File Korr-Werten u. 4-stell. ASCII-Strings f. dig. Anzeige}
  Ascii_Tab : TDispl_Str_Ary;

  pcmil       : Tmil;          { Type OBJECT: In UNIT Mil_Lib.PAS deklariert!! }
  Flash       : TFlash;
  Flash_Param : Tflash_data;   { In UNIT Mil_Flsh.lib deklariert!! }


 status       : BOOLEAN;
 ifc_adr_ref  : BYTE;     {Referenz-Spannungsmessung-ADC}
 ifc_adr_mess : BYTE;     {Me·-Spannungs-ADC-Karte  }
 ifc_adr_flash: BYTE;     {IFC-Programmierkarte fÅr FLASH-PROM}
 ifc_test_nr  : BYTE;
 pc_status    : WORD;

 loop      : BOOLEAN;
 rd_timeout: BOOLEAN;
 read_data : WORD;
 write_data: WORD;
 mil_data  : WORD;
 fct_code  : WORD;

 transf_cnt: LONGINT;
 time      : LONGINT;
 timout_cnt: LONGINT;
 timout_rd : LONGINT;
 timout_wr : LONGINT;
 ch        : CHAR;
 user_input: CHAR;
 read_str  : str4;
 bit16_str : STRING[19];

{
   Farbnamen fÅr Fenster und Schrift:
   Black, Blue, Green, Cyan, Red, Magenta, Brown, Yellow, White, Blink
}
  PROCEDURE ini_headl_win;
   Begin                             {Definitionen gelten bis neu definiert}
    Window(1, 1, 80, 2);             {Definiert ein Textfenster: Spalte/Zeile}
    TextBackground(Magenta);         {Setze Hintergrund fÅr Textfenster}
    TextColor(Yellow);               {Setze Schriftfarbe}
    ClrScr;                          {Clear Window}
    GotoXY(1, 1);                    {Cursor auf Anfang Fenster}
    Write(head_line);
   End;

  PROCEDURE ini_text_win;
   Begin
    Window(1, 3, 80, 24);
    TextBackground(White);
    TextColor(Yellow);               {Setze Schriftfarbe}
    ClrScr;
   End;

  PROCEDURE set_text_win;
   Begin
    Window(1, 3, 80, 24);
    TextBackground(White);
    TextColor(Yellow);               {Setze Schriftfarbe}
   End;


  PROCEDURE ini_msg_win;
   Begin
    Window(1, 25, 80, 25);
    TextBackground(Green);
    TextColor(Black);               {Setze Schriftfarbe}
    ClrScr;
   End;

  PROCEDURE ini_test_win;
   Begin
    ini_msg_win;
    write(msg_single_step);
    ini_text_win;
   End;


  PROCEDURE ini_err_win;
   Begin
    Window(1, 25, 80, 25);
    TextBackground(Green);
    TextColor(Red);               {Setze Schriftfarbe}
    ClrScr;
   End;

  PROCEDURE ini_info_win;
   Begin
    Window(50, 11, 80, 22);
    TextBackground(Cyan);
    TextColor(Black);               {Setze Schriftfarbe}
    ClrScr;
   End;

FUNCTION menue_win: CHAR;
VAR answer: CHAR;
begin
  ini_headl_win;
  ini_text_win;


  GotoXY(12, 02);
  Writeln('*********************  TEST-MENUE  *********************** ');
  GotoXY(12, 03);
  Writeln('                                                           ');
  GotoXY(12, 04);
  Writeln('+------ SINGLE -------+             +------- LOOP --------+');
  GotoXY(12, 05);
  Writeln('[0]<-- Welche IFC am MIL-Bus?         Defin. IFC-Adr -->[A]');
  GotoXY(12, 06);
  Writeln('[1]<-- IFC-Adressen fÅr Ref, Me·, Flash anzeigen           ');
  GotoXY(12, 07);
  Writeln('[2]<--      Referenz + Mess-ADC lesen + anzeigen     -->[C]');
  GotoXY(12, 08);
  Writeln('[3]<-- Anzeige      Korr- + Vaku-Tabelle      éndern -->[D]');
  GotoXY(12, 09);
  Writeln('[4]<--                                               -->[E]');
  GotoXY(12, 10);
  Writeln('[5]<-- Flash-PROM lîschen                                  ');
  GotoXY(12, 11);
  Writeln('[6]<-- Anzeige            Flash-PROM          éndern -->[G]');
  GotoXY(12, 12);
  Writeln('[7]<-- Write Korrektur-Tab. ins FLASH-PROM   Lo-Byte       ');
  GotoXY(12, 13);
  Writeln('[8]<-- Write Vakuum-Tabelle ins FLASH-PROM   Lo-Byte       ');

  ini_msg_win;
  Write('                                                                 EXIT: X-Taste ');
  GotoXY(1,1);
  Write('Bitte Auswahl eingeben: ');
  answer := readkey;
  IF answer IN ['0'..'9','A'..'S','a'..'s','x','X'] THEN
   menue_win := answer;
 End; {menue_win}


  FUNCTION hex_byte(b: BYTE): num_str;
  CONST hex_num : STRING[16] = '0123456789ABCDEF';
  Begin
   hex_byte := hex_num[(b shr 4) + 1] + hex_num[(b AND $0F) + 1];
  End;

  FUNCTION hex_word(w: WORD): num_str;
   Begin
    hex_word := hex_byte(HI (w)) + hex_byte(LO (w));
   End; {hex_word}


 PROCEDURE hex_bin (data:WORD);       { Resultat im globalen bit16_str }
 VAR i,divisor,offset : WORD;
 Begin
  bit16_str := '0000 0000 0000 0000';
  divisor   := $8000;
  offset    := 0;
  FOR i := 1 TO 16 DO
   Begin
    IF (data AND divisor = divisor) THEN
     Begin
       IF i >  4 THEN offset:= 1;
       IF i >  8 THEN offset:= 2;
       IF i > 12 THEN offset:= 3;
       bit16_str[i+offset] := '1';
     End;
    divisor := divisor shr 1;
   End;
 End; {hex_bin}

 function ask_hex_byte: byte;
  var In_str : string[2];
      Status : boolean;
      Num    : byte;
      I      : word;
      Ch     : char;
  begin
   Status := FALSE;
   while not Status do
    begin
     ini_msg_win;
     write ('--> Bitte 2-stellige Hex-Daten eingeben: '); readln(In_str);
     IF (In_str[1] in ['0'..'9','a'..'f','A'..'F']) AND (In_str[2] in ['0'..'9','a'..'f','A'..'F']) THEN
            Status := TRUE;
     IF NOT status THEN
      Begin
       ini_err_win;
       write('ERROR: Sorry, USER: das war keine 2-stell. Hexzahl!! Weiter mit <G>');
       repeat
         Ch := readkey ;
       until Ch in ['G','g'];
      End;
    end;  {while}

    for I := 1 to 2 do
     begin
      if In_str[I] in ['a'..'f'] then In_str[I] := upcase(In_str[I]);
      if In_str[I] in ['0'..'9'] then
       num := num*16 + (Ord(In_str[I]) - Ord('0'));
      if In_str[I] in ['A'..'F'] then
       num := num*16 + (Ord(In_str[I]) - Ord('A')+10);
     end;
    ask_hex_byte := num;
  End;


  FUNCTION timeout: BOOLEAN;
    Begin
     timeout := FALSE;
     IF time = 0 THEN timeout := TRUE  ELSE  time := time - 1;
    End; {Timeout}

  FUNCTION create_mil_fctcode (code: WORD): WORD;
   VAR function_code : WORD;
   Begin
    function_code := code * 256;             { ins HI-Byte }
    function_code := function_code + ifc_test_nr;     { icf_adr ins Lo-Byte }
    create_mil_fctcode := function_code;
   End;

 PROCEDURE mil_detect_ifc;
  CONST start_zeile = 5;
  VAR ifc_total  : WORD;
      ifb_online : ARRAY[1..255] OF BOOLEAN;
      ifb_adr    : WORD;
      zeile      : BYTE;
      hex_str    : STRING[10];
      i          : WORD;
  Begin
   ifc_total := 0;
   ini_msg_win;
   GotoXY(1, 1);
   write('Bitte warten. IFC-Karten am Mil-Bus werden gesucht!');

   FOR ifb_adr := 1 TO 255 DO                                 { Clear Array }
     ifb_online[ifb_adr] := FALSE;

   FOR ifb_adr := 1 TO 255 DO                 { Fill Array with actual data }
    Begin
     IF pcmil.ifc_online (ifb_adr) THEN
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
   write('IFC-Karten total: ',ifc_total,'     Any key to go on!');
   ch := READKEY;
  End; {detect_ifc}

  PROCEDURE mil_ask_ifc;
  VAR answer : CHAR; status: BOOLEAN;
  Begin
    ini_text_win;
    GotoXY(1, 22);
    write ('Welche IFC-Karten-Nr.(1..255) als Referenz-Spannung ?');
    ifc_adr_ref := ask_hex_byte;;

    ini_text_win;
    GotoXY(1, 22);
    write ('Welche IFC-Karten-Nr.(1..255) als Vakuum-Messung ?');
    ifc_adr_mess := ask_hex_byte;;

    ini_text_win;
    GotoXY(1, 22);
    write ('Welche IFC-Karten-Nr.(1..255) als FLASH-PROM ?');
    ifc_adr_flash := ask_hex_byte;;

    IF (ifc_adr_flash=ifc_adr_mess)  OR (ifc_adr_flash=ifc_adr_ref) OR
        (ifc_adr_ref=ifc_adr_mess) THEN
      Begin
       ini_text_win;
       ini_err_win;
       write(msg_ifc_equal);
       readkey;
      End;
  End; {ask_ifc}

 PROCEDURE show_ifc_adr;
  Begin
    ini_text_win;
    GotoXY(5, 10);
    write ('Aktuelle IFC-Adressen fÅr:');
    GotoXY(8, 12);
    write ('Referenz-Messung : ',ifc_adr_ref,  '  ['); write(hex_byte(ifc_adr_ref),  ' Hex]');
    GotoXY(8, 13);
    write ('Vakuum-Messung   : ',ifc_adr_mess, '  ['); write(hex_byte(ifc_adr_mess), ' Hex]');
    GotoXY(8, 14);
    write ('Flash-Prom-Karte : ',ifc_adr_flash,'  ['); write(hex_byte(ifc_adr_flash),' Hex]');
    ini_msg_win;
    write(msg_any_key);
    ch := READKEY;
  End;

 FUNCTION check_ifc_adr_flash: BOOLEAN;
  Begin
    check_ifc_adr_flash := TRUE;
    IF  NOT (ifc_adr_flash IN [1..255]) THEN
     Begin
      check_ifc_adr_flash := FALSE;
      ini_err_win;
      GotoXY(1, 1);
      write ('ABORT: IFC-Karten-Nr. fÅr FLASH undefiniert!! Weiter mit beliebiger Taste'); ch := readkey;
     End;
  End; {check_ifc_adr}

 PROCEDURE Flash_Displ_Adc;
  var  fct_word, fct_wrd_rdmes, fct_wrd_rdref: WORD;
       read_data_ref, read_data_mes          : INTEGER;
       timout_cnt_ref, timout_cnt_mes        : LongInt;
       rd_timout_ref, rd_timout_mes          : BOOLEAN;
       real_data  : real;

   PROCEDURE Get_Data;
    Begin
     fct_word := fct_wrd_rdref;                {Lese den Referenz-ADC}
     pcmil.wr_fct_code(fct_word);
     pcmil.hw_timer1_set (10);                 {100 us}
     REPEAT      {Warte bis Daten im FIFO}
       pc_status  := pcmil.rd_status;
     UNTIL (pc_status AND stat_val_wrd=stat_val_wrd) OR pcmil.hw_timeout1;
     IF pcmil.hw_timeout1 THEN
      Begin
        timout_cnt_ref := timout_cnt_ref + 1;
        rd_timout_ref := TRUE;
      End
     ELSE
      Begin  {kein Timeout}
       rd_timout_ref:= FALSE;
       read_data_ref := pcmil.read_data;
    End;

     fct_word := fct_wrd_rdmes;               {Lese den Mess-ADC}
     pcmil.wr_fct_code(fct_word);
     pcmil.hw_timer1_set (10);                 {100 us}
     REPEAT      {Warte bis Daten im FIFO}
       pc_status  := pcmil.rd_status;
     UNTIL (pc_status AND stat_val_wrd=stat_val_wrd) OR pcmil.hw_timeout1;
     IF pcmil.hw_timeout1 THEN
      Begin
        timout_cnt_mes:= timout_cnt_mes + 1;
        rd_timout_mes := TRUE;
      End
     ELSE
      Begin  {kein Timeout}
       rd_timout_mes := FALSE;
       read_data_mes := pcmil.read_data;
    End;
   End; {get_data}

   begin
    ini_test_win;
    ifc_test_nr   := ifc_adr_ref;
    fct_wrd_rdref := create_mil_fctcode (fct_rd_ist1);
    ifc_test_nr   := ifc_adr_mess;
    fct_wrd_rdmes := create_mil_fctcode (fct_rd_ist1);
    read_data_ref := 0; read_data_mes := 0;

    transf_cnt := 0;
    timout_cnt_ref := 0;
    timout_cnt_mes := 0;
    GotoXY(03, 5);
    write  ('Funct-Word Ref (Fct+Adr): ',hex_word(fct_wrd_rdref),' [H]');
    GotoXY(45, 5);
    write  ('Funct-Word Mes (Fct+Adr): ',hex_word(fct_wrd_rdmes),' [H]');

    GotoXY(24,09); writeln('Read_Data_Count:');
    GotoXY(46,10); writeln('^  ^');

    GotoXY(06,12); writeln('v----- REFERENZ-ADC -----v');
    GotoXY(02,14); writeln('SPANNUNG   :');
    GotoXY(23,14); writeln('[Volt]');
    GotoXY(02,16); writeln('DATA  [Hex]:');
    GotoXY(21,16); writeln('Timeout:');
    GotoXY(31,16); writeln(timout_cnt_ref:6);
    GotoXY(08,17); writeln('[Bin]:');
    GotoXY(15,18); writeln('MSB             LSB');

    GotoXY(48,12); writeln('v-----   MESS-ADC   -----v');
    GotoXY(45,14); writeln('SPANNUNG   :');
    GotoXY(66,14); writeln('[Volt]');
    GotoXY(45,16); writeln('DATA  [Hex]:');
    GotoXY(64,16); writeln('Timeout:');
    GotoXY(74,16); writeln(timout_cnt_mes:6);

    GotoXY(51,17); writeln('[Bin]:');
    GotoXY(58,18); writeln('MSB             LSB');

    IF loop THEN
     Begin
      GotoXY(10, 3);
      write  ('Es werden im Sekunden Abstand Referenz- und Mess-ADC ausgelesen!');
      REPEAT
         pcmil.hw_timer1_set ($FFFF);                 {ca. 1 sec}
         REPEAT  UNTIL pcmil.hw_timeout1;
         transf_cnt:= transf_cnt+ 1;
	 GotoXY(40, 09); write(transf_cnt:12);
         get_data;
         IF rd_timout_ref THEN
           Begin
             GotoXY(31,16); writeln(timout_cnt_ref:6);
             GotoXY(15,16); write('    ');       {Daten lîschen, da ungÅltig}
             GotoXY(15,17); write('                   ');
             GotoXY(15,14); write('       ');
          End
         ELSE
           Begin
             GotoXY(15,16);  write(hex_word(read_data_ref));
             hex_bin (read_data_ref);
             GotoXY(15,17);  write(bit16_str);
             real_data := read_data_ref/3276.7;
             GotoXY(15,14); write('       ');
             GotoXY(15,14); write(real_data:2:3);
           End;

         IF rd_timout_mes THEN              {Daten lîschen, da ungÅltig}
           Begin
             GotoXY(74,16); writeln(timout_cnt_mes:6);
             GotoXY(58,16); write('    ');
             GotoXY(58,17); write('                   ');
             GotoXY(58,14); write('       ');
           End
         ELSE
           Begin
             GotoXY(58,16); write(hex_word(read_data_mes));
             hex_bin (read_data_mes);
             GotoXY(58,17); write(bit16_str);
             real_data := read_data_mes/3276.7;
             GotoXY(58,14); write('       ');
             GotoXY(58,14); write(real_data:2:3);
           End;
      UNTIL keypressed;
     End
    ELSE
     Begin
      REPEAT
       ch := READKEY;
       IF ch = ' ' THEN
        Begin
         transf_cnt:= transf_cnt+ 1;
	 GotoXY(40, 09); write(transf_cnt:12);
         get_data;
         IF rd_timout_ref THEN
           Begin
             GotoXY(31,16); writeln(timout_cnt_ref:6);
             GotoXY(15,16); write('    ');       {Daten lîschen, da ungÅltig}
             GotoXY(15,17); write('                   ');
             GotoXY(15,14); write('        ');
          End
         ELSE
           Begin
             GotoXY(15,16);  write(hex_word(read_data_ref));
             hex_bin (read_data_ref);
             GotoXY(15,17);  write(bit16_str);
             real_data := read_data_ref/3276.7;
             GotoXY(15,14); write('        ');
             Goto