PROGRAM mil_pc;                 { Programm MIL_PC.PAS mit OOP-Unit DATECH.TPU}
{ Autor: Gerhard Englert
  Einige Tests mit dem PC-MIL-Interfaces:
  Am MIL-BUS sollte das TestgerÑt "DATECH MIL-Monitor" vorhanden sein!

  28.10.93: Dieses Programm wurde auf Turbo-Pascal Version 7.0 umgestellt.
  Neu: der Bildschirm ist in 3 Windows eingeteilt (s. a. ini_headl_win,
  ini_text_win und ini_msg_win). In jedem Window sind Grî·e, Hintergrund-
  Farbe und Schriftfarbe definiert, die der Anwender geÑndern darf.
  Modifikationen:
  Der SDuP benutzt die 3 MIL-Intr-Leitungen wie folgt:
      Intl   (1) : Transfer-Fehler zum uP (Synchr, Checksum, Wordcount)
      DtaRdy (1) : uP bereit zum Senden
      DtaReq (1) : uP nicht bereit zum Empfang (Busy)

  03.03.94    Umstellung auf DATECH.TPU
  18.03.94    Erweiterung fÅr SD-uP-Tests
  30.03.94    Testpattern fÅr SDuP
  06.04.94    Fehler rd-Data C9 beseitigt
  20.03.95    MenÅ erweitert: FIFO-Test
  24.03.95    nur Datenschreiben wegen Hardware-Tests
              Anzeige Status: Wartezeit INTR-Leitungen 50 us eingefÅhrt
  27.03.95    W: Zwei Funktionskodes fÅr Testzwecke
  09.02.96    MIL.IFC_Online umgestellt
  22.10.97    SingleLoop(Key); totgelegt
}

{$S-}
uses Crt, WinDos, Datech,Datech_1;

CONST
 hardw_timer_timeout = 1000000;
 SndMax = 10;                 {Sd-uP: max. Anzahl SendDaten}
 RcvMax = 1024;               {Sd-uP: max. Anzahl RcvDaten}
 SDuP_Wait_Rdy  =  500 * 100;  {max. 0,5 sec warten bis SDuP ready ist}
 SDuP_Wait_Dta  =  3000 * 100; {max. 3,0 sec warten bis Daten vom SDuP}
 SDuP_Wait_Ptrn =  10 * 100;   {max. 10,0 msec warten bis Daten vom SDuP}

 head_line =
      'Datentechnik                      MIL-PC     ' +
      '                       [22.10.1997]'+
      '                 PC-Interface- u. MIL-Tests (Turbo_Pascal V7.0)';

 msg_single_step =
      'Loop- u. Single-Test mit [Q] beenden!    Single-Step mit [SPACE] ';
 msg_timer_auto =
      'Automat. Timertest mit [Q] beenden!                              ';

TYPE
 str4    = STRING[4];
 num_str = STRING[10];

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
 timer_aktiv: WORD;
 timout_cnt: LONGINT;
 timout_rd : LONGINT;
 timout_wr : LONGINT;
 ch,key    : CHAR;
 user_input: CHAR;
 read_str  : str4;
 Bit16_Str : Str19;
                                        {SDuP}
 TmpAry    : array [0..SndMax] of Word; {0 = Anzahl der Snddaten}
 SndAry    : array [0..SndMax] of Word; {0 = Anzahl der Snddaten}
 RcvAry    : array [0..RcvMax] of Word; {0 = Anzahl der Rcvdaten}
 DispMode  : Boolean; {SduP Sende- u. Empfangsbuffer anzeigen}





procedure menue_win;
VAR answer: CHAR;
begin
  Ini_Headl_Win;
  Write(head_line);
  ini_text_win;
  GotoXY(12, 2);
  Writeln('*********************  TEST-MENUE  ********************* ');
  GotoXY(12, 3);
  Writeln('     +-- SINGLE --+                    +-- LOOP --+      ');
  GotoXY(12, 4);
  Writeln('[0]<-- Welche IFC am MIL-Bus?       Defin. IFC-Adr -->[A]');
  GotoXY(12, 5);
  Writeln('[1]<--      Lese Status-Register PC-Interface      -->[B]');
  GotoXY(12, 6);
  Writeln('[2]<--                Lese FIFO-Daten              -->[C]');
  GotoXY(12, 7);
  Writeln('[3]<--    Lese IFC-Status (Intr-Mask usw. [C9H])   -->[D]');
  GotoXY(12, 8);
  Writeln('[4]<--           Lese Daten von IFC-Karte          -->[E]');
  GotoXY(12, 9);
  Writeln('[5]<--     Schicke Funktionscode zur IFC-Karte     -->[F]');
  GotoXY(12, 10);
  Writeln('[6]<--        Schreibe Daten zur IFC-Karte         -->[G]');
  GotoXY(12, 11);
  Writeln('[7]<--     Schreibe/Lese IFC-Karte (User-Daten)    -->[H]');
  GotoXY(12, 12);
  Writeln('[8]<--    Schreibe/Lese IFC-Karte (Daten=0..FFFF)  -->[I]');
  GotoXY(12, 13);
  Writeln('[9]<--             Set Timer 1 u. 2                -->[J]');
  GotoXY(12, 14);
  Writeln('            [K]<--  Timeout-Bits: Autom. Test            ');
  GotoXY(12, 15);
  Writeln('            [L]<--  Reset PC-MIL Interface               ');
  GotoXY(12, 16);
  Writeln('            [M]<--  Reset IFC-Karte (Fctcode 01)         ');
  GotoXY(12, 17);
  Writeln('            [N]<--  MIL Fifo-Test (1k...64k)             ');
  GotoXY(12, 18);
  Writeln('            [R]<--  Set MIL Interrupt-Leitungen          ');
  GotoXY(12, 19);
  Writeln('            [S]<--  SD-uP:  Daten zum uP                 ');
  GotoXY(12, 20);
  Writeln('            [T]<--  SD-uP:  Automat. Testpattern         ');
  GotoXY(12, 21);
  Writeln('            [U]<--  SD-uP:  Status anzeigen              ');
  GotoXY(12, 22);
  Writeln('            [V]<--  MIL-Daten schreiben                  ');
  GotoXY(12, 23);
  Writeln('                       [W]<--  Sende 2 verschied. Funktionscodes    ');

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


  PROCEDURE mil_ask_ifc;
  VAR answer : CHAR;
  Begin
    status := FALSE;
    WHILE NOT status DO
     Begin
      ini_text_win;
      GotoXY(5, 22);
      write ('Welche IFC-Karten-Adr. testen?');
      ifc_test_nr := ask_hex_byte;
      IF ifc_test_nr IN [1..255] THEN status := TRUE;
     End;
  End; {ask_ifc}

FUNCTION ask_data: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    ini_text_win;
    GotoXY(5, 22);
    write ('FÅr die MIL-Transfer-Tests werden vom USER die WRITE-Daten benîtigt!! ');
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
 End;

 FUNCTION ask_timer_aktiv: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    ini_text_win;
    ini_msg_win;
    write ('Welchen Timer testen? [1 oder 2] :');
    readln(in_data);
    IF in_data IN [1..2] THEN status := TRUE;
   End; {WHILE}
  ask_timer_aktiv := in_data;
 End; {ask_timer_aktiv}

 FUNCTION ask_timer_data: WORD;
 VAR in_data : WORD;
       answer: CHAR;
 Begin
    ini_text_win;
    GotoXY(5, 22);
    IF timer_aktiv = 1 THEN
     write ('Timer1-Daten: 1 Tick=10 us! Timeout -> im Statusregister Bit 200[H]!')
    ELSE
     Begin
       ini_msg_win;
       write ('Welche Clock fÅr Timer 2 ?? [1]= 10us [2]= 1ms : ');
       REPEAT
         read(answer);
       UNTIL  answer IN ['1','2'];

       ini_text_win;
       GotoXY(5, 22);
       IF answer = '1' THEN
        Begin
         Portw[Port_Tmr2_1ms] := 0;                        {auf 10us schalten}
         write ('Timer2-Daten: 1 Tick=10 us! Timeout -> im Statusregister Bit 400[H]!')
        End
       ELSE
        Begin
          Portw[Port_Tmr2_1ms] := 1;                       {auf 1 ms schalten}
          write ('Timer2-Daten: 1 Tick= 1 ms! Timeout -> im Statusregister Bit 400[H]!');
        End;
     End;

  status := FALSE;
  WHILE NOT status DO
   Begin
    ini_msg_win;
    write   ('--> Bitte 4-stellige Hex-Daten eingeben: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
      writeln('ERROR: Sorry, USER: das war keine 4-stell. Hexzahl!!');
   End; {WHILE}
  ask_timer_data := in_data;
 End; {ask_timer_data}

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

 PROCEDURE mil_ifc_reset;
 var IobErr : TMilErr;
      Fct    : TFct;
  Begin
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Reset ;
   Mil.WrFct (Fct, IobErr);

   ini_err_win;
   GotoXY(1, 1);
   write('Reset IFC ausgefÅhrt. Weiter mit irgendeiner Taste!');
   REPEAT UNTIL keypressed;
  End;


  PROCEDURE mil_rd_fifo;
  VAR read_data : WORD;
   Begin
    ini_text_win;
    transf_cnt := 0;
    GotoXY(6, 11);
    writeln('Rd_Data_Cnt:');
    GotoXY(26,12);
    writeln('^  ^');
    GotoXY(6, 14);
    writeln('Read-Data[H]');

    IF loop THEN
    Begin
     REPEAT
      transf_cnt:= transf_cnt+ 1;
      GotoXY(20, 11);
      write(transf_cnt:12);
      read_data := PORTW [Port_Data];                {Mil-Daten lesen}
      GotoXY(28, 14);  write(hex_word(read_data));
     UNTIL keypressed;
    End
   ELSE
    Begin
      REPEAT
       ch := READKEY;
       IF ch = ' ' THEN
        Begin
         transf_cnt:= transf_cnt+ 1;
         GotoXY(20, 11);
         write(transf_cnt:12);
         read_data := PORTW [Port_Data];                {Mil-Daten lesen}
         GotoXY(28, 14);  write(hex_word(read_data));
        End;
      UNTIL ch IN ['q','Q'];
    End; {Loop}
  End; {mil_rd_fifo}

 PROCEDURE mil_rd_status;
  VAR read_data : WORD;
   PROCEDURE show_stat_reg;
    Begin
     read_data := PORTW [Port_Stat];;
     GotoXY(28, 15);  write(hex_word(read_data));
     Hex_Bin_Str (read_data,bit16_str);
     GotoXY(22, 16);  write(bit16_str);
    End;

   Begin
    ini_text_win;            {Defin. Fenster, lîsche Fenster}
    displ_pc_stat;           {Zeige die Bitbelegung als Info}
    set_text_win;            {Textfenster restaurieren ohne Info zu lîschen}
    transf_cnt := 0;
    timout_cnt := 0;
    GotoXY(06,11); write('Rd_Stat_Cnt:');
    GotoXY(26,12); write('^  ^');
    GotoXY(06,15); write('Stat-Data[HEX]');
    GotoXY(06,16); write('Stat-Data[BIN]');
    GotoXY(22,17); write('MSB             LSB');

    IF loop THEN
    Begin
     REPEAT
     transf_cnt:= transf_cnt+ 1;
     GotoXY(20, 11); write(transf_cnt:12);
     show_stat_reg;
     UNTIL keypressed;
    End
   ELSE
    Begin
      REPEAT
       ch := READKEY;
       IF ch = ' ' THEN
        Begin
         transf_cnt:= transf_cnt+ 1;
         GotoXY(20, 11); write(transf_cnt:12);
         show_stat_reg;
        End;
      UNTIL ch IN ['q','Q'];
    End; {Loop}
  End; {mil_rd_status}

 PROCEDURE mil_rd_ifc_stat;
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
    ini_text_win;
    displ_ifc_stat;
    set_text_win;

    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Fct_Rd_Status;

    transf_cnt := 0;
    timout_cnt := 0;
    GotoXY(06,11);  write('Rd_Stat_Cnt:');
    GotoXY(26,12);  write('^  ^');
    GotoXY(06,14);  write('Stat-Data[Hex]');
    GotoXY(06,16);  write('Stat-Data[Bin]');
    GotoXY(22,17);  write('MSB             LSB');
    IF loop THEN
    Begin
     REPEAT
      transf_cnt:= transf_cnt+ 1;
      GotoXY(20, 11); write(transf_cnt:12);
      show_stat_reg;
     UNTIL keypressed;
    End
   ELSE
    Begin
      REPEAT
       ch := READKEY;
       IF ch = ' ' THEN
        Begin
         transf_cnt:= transf_cnt+ 1;
         GotoXY(20, 11); write(transf_cnt:12);
         show_stat_reg;
        End;
      UNTIL ch IN ['q','Q'];
    End; {Loop}
  End; {mil_rd_ifc_stat}

 PROCEDURE mil_timer(write_data:WORD);
  VAR I,read_data : WORD;
   PROCEDURE show_stat_reg;
    Begin
     read_data := PORTW [Port_Stat];;
     Hex_Bin_Str (read_data,bit16_str);
     GotoXY(22, 18);  write(bit16_str);
    End;

   Begin
    ini_text_win;            {Defin. Fenster, lîsche Fenster}
    displ_pc_stat;           {Zeige die Bitbelegung als Info}
    set_text_win;            {Textfenster restaurieren ohne Info zu lîschen}
    transf_cnt := 0;
    GotoXY(06,11);  writeln('Wr_Data_Cnt:');
    GotoXY(26,12);  writeln('^  ^');
    GotoXY(06,14);  writeln('Write-Data[H]');
    GotoXY(28,14);  write(hex_word(write_data));
    GotoXY(06,05);  write('Es wird getestet Timer Nr.: ');
    GotoXY(36,05);  write(timer_aktiv);

    if not Loop then
     begin
      GotoXY(06,18);  write('Stat-Data[BIN]');
      GotoXY(22,19);  write('MSB             LSB');
     end;

    if loop then
     begin    {loop}
      ini_msg_win;
      write('Timer wird im Loop gesetzt.       Stop mit beliebiger Taste!');
      set_text_win;            {Textfenster restaurieren ohne Info zu lîschen}
      repeat
         transf_cnt:= transf_cnt+ 1;
         GotoXY(20, 11); write(transf_cnt:12);
         IF timer_aktiv = 1 THEN
           begin
             Mil.Timer1_Set(write_data);          { Startet Timer1: time*10us}
             repeat until Mil.Timeout1;
           end;

         IF timer_aktiv = 2 THEN
           begin                                   { Startet Timer2}
           {Mil.Timer2_Set(write_data); hier nicht verwenden, wegen LONGINT}
            Portw[Port_Tmr2]     := write_data;
            repeat until Mil.Timeout2;
           end;
      until keypressed;
     end
    else
     begin    {einzel}
      REPEAT
       ch := READKEY;
       IF ch = ' ' THEN
        Begin
         transf_cnt:= transf_cnt+ 1;
         GotoXY(20, 11); write(transf_cnt:12);
         IF timer_aktiv = 1 THEN   Mil.Timer1_Set(write_data);
         IF timer_aktiv = 2 THEN   Portw[Port_Tmr2] := write_data;
         {Mil.Timer2_Set(write_data); hier nicht verwenden, wegen LONGINT }
         REPEAT
           show_stat_reg;
         UNTIL keypressed;
        End;
      UNTIL ch IN ['q','Q'];
     end;
  End; {mil_timer}

  PROCEDURE mil_timeout;
   LABEL 99;
   VAR err_count,ok_count : LONGINT;
       i : WORD;
       timer2_err : LONGINT;
   Begin
    ok_count   := 0;
    err_count  := 0;
    timer2_err := 0;
    time := hardw_timer_timeout;   {globale variable}
    mil.reset;                     { Set clock for Timer2 to 10us }
    ini_text_win;
    ini_msg_win;
    write(msg_timer_auto);
    ini_text_win;
    transf_cnt := 0;
    GotoXY(06,05); writeln('Es werden Timer 1 u. 2 getestet!');
    GotoXY(06,11); writeln('Wr_Timer_Cnt:                   Timeout_Bit ok   : ');
    GotoXY(26,12); writeln('^  ^');
    GotoXY(06,14); writeln('Timer_Data[H]:                  Timeout_Bit Error: ');
    GotoXY(57,14); write(err_count:12);
    GotoXY(57,11); write(ok_count:12);

    GotoXY(38,16); write('Timer 2 Error    : ');
    GotoXY(57,16); write(timer2_err:12);

    IF loop THEN
    Begin
     REPEAT
        mil.reset;
        Mil.Timer2_Set(100000);
         REPEAT
         UNTIL timeout OR (PORTW [Port_Stat] AND stat_timeout2 = stat_timeout2);

         IF timeout THEN
          Begin
	   timer2_err:= timer2_err + 1;
	   GotoXY(57,16);  write(timer2_err:12);
           GotoXY(45,05);  write('Timer 2-Test mit 1ms-Clock: Not ok!! ');
          End
         ELSE
          Begin
           GotoXY(45,05);  write('Timer 2-Test mit 1ms-Clock: ok!! ');
          End;

      {Timer1 mit 10 us testen}
      Mil.reset;                                   {Timer1 u. Timer2 to 10 us}
      write_data := 1;
      FOR i := 1 TO 15 DO                 {Jedes Bit testen}
       Begin
        GotoXY(28, 14);  write(hex_word(write_data));
        {Timer1 mit 10 us-Ticks testen}
        Mil.Timer1_Set(write_data);
        REPEAT
        UNTIL timeout OR (PORTW [Port_Stat] AND stat_timeout1 = stat_timeout1);
        IF timeout THEN
         Begin
           err_count := err_count + 1;
           GotoXY(57, 14); write(err_count:12);
         End
        ELSE
         Begin
           ok_count := ok_count + 1;
           GotoXY(57, 11); write(ok_count:12);
         End;

      {Timer2 mit 10 us testen}
	mil.reset;                        {Timer1 u. Timer2 to 10 us}
        Mil.Timer2_Set(write_data);
	time := hardw_timer_timeout;       {Software-Timeout erneut setzen!!}
        REPEAT
	UNTIL timeout OR (PORTW [Port_Stat] AND stat_timeout2 = stat_timeout2);
        IF timeout THEN
         Begin
	   timer2_err:= timer2_err + 1;
	   GotoXY(57,16); write(timer2_err:12);
	   GotoXY(45,05);  write('Timer 2-Test mit 10us-Clock: Not ok!! ');
         End
        ELSE
         Begin
           ok_count := ok_count + 1;
           GotoXY(57, 11); write(ok_count:12);
         End;
        transf_cnt:= transf_cnt+ 1;
        GotoXY(20, 11);  write(transf_cnt:12);
        time := hardw_timer_timeout;    {Software-Timeout erneut setzen!!}
        IF keypressed THEN GOTO 99;
        write_data := write_data shl 1;
       End; {FOR i}
      UNTIL keypressed;
    End; {Loop}
99:
  End; {mil_timeout_bit}

 PROCEDURE  mil_reset;
  Begin
   ini_text_win;
   mil.reset;
   ini_err_win;
   write('Reset PC-Interface ausgefÅhrt. Weiter mit irgendeiner Taste!');
   REPEAT UNTIL keypressed;
  End;

FUNCTION ask_fctcode: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    ini_text_win;
    GotoXY(5, 22);
    write ('Welchen Function-Code [im Hi-Byte] ??');
    ini_msg_win;
    write   ('--> Bitte 4-stellig HEX eingeben [DD00]: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
     Begin
      ini_err_win;
      writeln('ERROR: Sorry, USER: das war keine 4-stell. Hexzahl!!');
     End;
   End; {WHILE}
  ini_text_win;
  ask_fctcode := (in_data AND $FF00) + ifc_test_nr;
 End;  {ask_fctcode}


 FUNCTION ask_rd_fct: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    ini_text_win;
    GotoXY(5, 22);
    write ('Welchen READ-Function-Code [im Hi-Byte] ??');
    ini_msg_win;
    write   ('--> Bitte 4-stellig HEX eingeben [DD00]: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
     Begin
       ini_err_win;
       writeln('ERROR: Sorry, USER: das war keine 4-stell. Hexzahl!!');
     End;
   End; {WHILE}
  ini_text_win;
  ask_rd_fct := (in_data AND $FF00) + ifc_test_nr;
 End;  {ask_rd_fct}

FUNCTION ask_wr_fct: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    ini_text_win;
    GotoXY(5, 22);
    write ('Welchen WRITE-Function-Code [im Hi-Byte] ??');
    ini_msg_win;
    write   ('--> Bitte 4-stellig HEX eingeben [DD00]: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
     Begin
       ini_err_win;
       writeln('ERROR: Sorry, USER: das war keine 4-stell. Hexzahl!!');
     End;
   End; {WHILE}
  ini_text_win;
  ask_wr_fct := (in_data AND $FF00) + ifc_test_nr;
 End;  {ask_wr_fct}

 PROCEDURE mil_rd_data;
  VAR read_data,pc_status : WORD;
      rd_timeout : BOOLEAN;
      MilErr : TMilErr;
      Fct    : TFct;

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
    ini_text_win;
    GotoXY(5, 22);
    write ('Welchen READ-Function-Code ??');
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := ask_hex_byte;
    ini_text_win;

    GotoXY(25, 6);
    write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
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

    IF loop THEN
     Begin
      REPEAT
       transf_cnt:= transf_cnt+ 1;
       GotoXY(22, 11); write(transf_cnt:12);
       get_data;
       IF rd_timeout THEN
        Begin
         GotoXY(28, 17);  write('    ');
         GotoXY(22, 18);  write('                   ');
         mil.reset;
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
	 GotoXY(22, 11); write(transf_cnt:12);
         get_data;
         IF rd_timeout THEN
          Begin
           GotoXY(28, 17);  write('    ');
           GotoXY(22, 18);  write('                   ');
           mil.reset;
          End;
        End;
      UNTIL ch IN ['q','Q'];
    End; {Loop}
  End; {mil_rd_data}

 PROCEDURE mil_wr_fctcode;
 VAR
      MilErr : TMilErr;
      Fct    : TFct;
   Begin
    ini_text_win;
    GotoXY(5, 22);
    write ('Welchen Function-Code ??');
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := ask_hex_byte;
    ini_text_win;

    transf_cnt := 0;
    GotoXY(25,08); write  ('Function: ',hex_word(Fct.W),' [H]');
    GotoXY(6, 11); writeln('Wr_Fct_Cnt :');
    GotoXY(26,12); writeln('^  ^');

   IF loop THEN
    Begin
     REPEAT
      transf_cnt:= transf_cnt+ 1;
      GotoXY(20, 11); write(transf_cnt:12);
      Mil.WrFct (Fct, MilErr);
     UNTIL keypressed;
    End
   ELSE
    Begin
      REPEAT
       ch := READKEY;
       IF ch = ' ' THEN
        Begin
         transf_cnt:= transf_cnt+ 1;
	 GotoXY(20, 11); write(transf_cnt:12);
         Mil.WrFct (Fct, MilErr);
        End;
      UNTIL ch IN ['q','Q'];
    End; {Loop}
  End; {mil_wr_fctcode}


 Procedure mil_wr (write_data: WORD);
  LABEL 99;
   VAR
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;

   Begin
    ini_text_win;
    GotoXY(5, 22);
    write ('Welchen Write-Function-Code ??');
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := ask_hex_byte;
    ini_text_win;

    transf_cnt := 0;
    error_cnt  := 0;
    timout_wr  := 0;

    GotoXY(25,08);  write  ('WR-Fct: ',hex_word(Fct.W),' [H]');
    GotoXY(6, 11);  writeln('Wr_Data_Cnt:              Write-Data[H]:                ');
    GotoXY(53,11); write('Timeout:');
    GotoXY(61,11); write(timout_wr:10);

    Mil.Reset;                            { clear fifo }
    IF loop THEN
    Begin
     REPEAT
        transf_cnt:= transf_cnt+ 1;
	GotoXY(18,11); write(transf_cnt:10);
        Mil.Wr (write_data, Fct, MilErr);
        if MilErr <> No_err then
         begin
          timout_wr := timout_wr + 1;
          GotoXY(61, 11); write(timout_wr:10);
         end
        else
         begin
	   GotoXY(47, 11);  write(hex_word(write_data));
         end;
     UNTIL keypressed;
    End
   ELSE
    Begin
         REPEAT
           ch := READKEY;
           IF ch = ' ' THEN
            Begin
             transf_cnt:= transf_cnt+ 1;
	     GotoXY(18, 11); write(transf_cnt:10);
             Mil.Wr (write_data, Fct, MilErr);
             if MilErr <> No_err then
              begin
               timout_wr := timout_wr + 1;
               GotoXY(61, 11); write(timout_wr:10);
              end
             else
              begin
               GotoXY(47, 11);  write(hex_word(write_data));
              end;
	    End
           ELSE
             Begin
              IF ch IN ['q','Q'] THEN GOTO 99;
             End; {IF ch}
        UNTIL 1 = 2;
    End; {Loop}
99:
End; {mil_wr}

Procedure mil_wr_rd (write_data: WORD);
  LABEL 99;
   VAR
    i,pc_status : WORD;
    error_cnt : LONGINT;
    wr_fct_code, rd_fct_code : WORD;
       MilErr : TMilErr;
       Fct    : TFct;


   FUNCTION get_data: WORD;
    var read_data : Word;
    Begin
     Fct.B.Fct := rd_fct_code;
     Mil.Rd (read_data, Fct, MilErr);
     IF MilErr  <> No_Err THEN
      Begin
        rd_timeout := TRUE;
        timout_rd := timout_rd + 1;
      End
     ELSE
      Begin  {kein Timeout}
       rd_timeout:= FALSE;
       get_data  := read_data;
      End;
    End; {get_data}

   Begin
    ini_text_win;
    transf_cnt := 0;
    error_cnt := 0;
    timout_wr := 0; timout_rd := 0;
    Fct.B.Adr := Ifc_Test_Nr;

    GotoXY(5, 22);
    write ('Welchen Write-Function-Code ??');
    wr_fct_code := ask_hex_byte;
    ini_text_win;

    GotoXY(5, 22);
    write ('Welchen Read-Function-Code  ??');
    rd_fct_code := ask_hex_byte;
    ini_text_win;
    Fct.B.Fct := wr_fct_code;
    GotoXY(25, 8);
    write  ('WR-Fct: ',hex_word(Fct.W),' [H]   RD-Fct: ');
    Fct.B.Fct := rd_fct_code;
    write(hex_word(Fct.W),' [H]');
    GotoXY(6, 11);
    writeln('Wr_Data_Cnt:              Write-Data[H]:                ');
    GotoXY(6, 14);
    writeln('Error_Count:              Read-Data [H]:                ');
    GotoXY(18,14);  write(error_cnt:10);
    GotoXY(22,12);  writeln('^  ^');
    GotoXY(22,15);  writeln('^  ^');
    GotoXY(53,11);  write('Timeout:');
    GotoXY(53,14);  write('Timeout:');
    GotoXY(61,14);  write(timout_rd:10);
    GotoXY(61,11);  write(timout_wr:10);

    Mil.reset;      {Clear Fifo}
    IF loop THEN
    Begin
     REPEAT
        transf_cnt:= transf_cnt+ 1;
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
     UNTIL keypressed;
    End
   ELSE
    Begin
         REPEAT
           ch := READKEY;
           IF ch = ' ' THEN
            Begin
              transf_cnt:= transf_cnt+ 1;
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
            End
           ELSE
             Begin
              IF ch IN ['q','Q'] THEN GOTO 99;
             End; {IF ch}
        UNTIL 1 = 2;
    End; {Loop}
 99:
 End; {mil_rd_wr}


 PROCEDURE mil_loop;
   LABEL 99;
   VAR
    i,pc_status : WORD;
    error_cnt : LONGINT;
    mil_status : WORD;
    wr_fct_code, rd_fct_code : WORD;
       MilErr : TMilErr;
       Fct    : TFct;

   FUNCTION get_data: WORD;
    var read_data : Word;
    Begin
     Fct.B.Fct := rd_fct_code;
     Mil.Rd (read_data, Fct, MilErr);
     IF MilErr  <> No_Err THEN
      Begin
        rd_timeout := TRUE;
        timout_rd := timout_rd + 1;
      End
     ELSE
      Begin  {kein Timeout}
       rd_timeout:= FALSE;
       get_data  := read_data;
      End;
    End; {get_data}

   Begin
    ini_text_win;
    transf_cnt:= 0;
    error_cnt := 0;
    timout_wr := 0; timout_rd := 0;
    Fct.B.Adr := Ifc_Test_Nr;

    GotoXY(5, 22);
    write ('Welchen Write-Function-Code ??');
    wr_fct_code := ask_hex_byte;
    ini_text_win;

    GotoXY(5, 22);
    write ('Welchen Read-Function-Code  ??');
    rd_fct_code := ask_hex_byte;
    ini_text_win;

    GotoXY(4,04);
    write('Achtung: Dieser Test benîtigt eine IFC-Karte am MIL-BUS mit (FCT + ADR): ');
    GotoXY(15,05);
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
    IF loop THEN
    Begin
     REPEAT
      FOR i := 0 TO $FFFF DO
       Begin
         transf_cnt:= transf_cnt+ 1;
         GotoXY(18,11);  write(transf_cnt:10);
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
         IF keypressed THEN GOTO 99;
        End; {FOR}
     UNTIL keypressed;
    End
   ELSE
    Begin
         FOR i := 0 TO $FFFF DO
          Begin
           ch := READKEY;
           IF ch = ' ' THEN
            Begin
             transf_cnt:= transf_cnt+ 1;
             GotoXY(18,11);  write(transf_cnt:10);
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
            End
           ELSE
             Begin
              IF ch IN ['q','Q'] THEN GOTO 99;
             End; {IF ch}
          End;
    End; {Loop}
  99:
  End; {mil_loop}

procedure IniSndAry;
 var I : Word;
 begin
  for I := 0 to SndMax do
    SndAry[I] := 0;
 end; {asksnddata}

procedure IniRcvAry;
 var I : Word;
 begin
  for I := 0 to RcvMax do
    RcvAry[I] := 0;
 end; {IniRcvAry}

procedure AskSndData;
 var I       : Word;
     SndNum  : Word;
     Checksum: Word;
     Input_Ok: Boolean;

     procedure  Displ_TmpAry;          {TmpAry[0] = incl. Checksum}
      var N : Word;
      begin
        Ini_Text_Win;
        Writeln ('Send-WordCount: ',  Hex_Word(TmpAry[0]),' [Hex]');
        for N := 1 to TmpAry[0] do
         begin
           if N = (TmpAry[0]) then
             Writeln ('Send-Checksum : ', Hex_Word(TmpAry[N]),' [Hex]')
           else
             Writeln ('Send-Daten[',N:2,']: ', Hex_Word(TmpAry[N]),' [Hex]');
         end;
      end; {Displ_TmpAry}

      procedure  Displ_SndAry;
      var N : Word;
      begin
        Ini_Text_Win;
        Writeln ('Send-WordCount: ',  Hex_Word(SndAry[0]),' [Hex]');
         for N := 1 to SndAry[0] do
          begin
           if N = (SndAry[0]) then
             Writeln ('Send-Checksum : ', Hex_Word(SndAry[N]),' [Hex]')
           else
             Writeln ('Send-Daten[',N:2,']: ', Hex_Word(SndAry[N]),' [Hex]');
          end;
      end; {Displ_SndAry}

 begin
  Ini_Msg_Win;
  if SndAry[0] = 0 then
   begin
     Write('Keine Senddaten vorhanden! Sollen Daten eingeben werden? [J/N]: ');
   end
  else
   begin
     Displ_SndAry;
     Ini_Msg_Win;
     Write('Senddaten vorhanden. Neu eingeben? [J/N]: ');
   end;
  Ch := ReadKey;
  if Ch in ['j','J'] then
   begin
    Ini_Text_Win;
    for I := 0 to SndMax do TmpAry[I] := 0;    {Init Arry}

    input_ok := False;
    repeat
     Ini_Msg_Win;
     Write('Bitte Anzahl der zu sendenden 16-Bit-Daten eingeben: ');
     Readln (SndNum);
     if SndNum > SndMax then
      begin
       Ini_Err_Win;
       Write('Error: Maximal nur ',SndMax,' Daten erlaubt!     Weiter mit beliebiger Taste.');
       repeat until KeyPressed;
      end
     else
      input_ok := True;
    until input_ok;

    TmpAry[0] := SndNum+1;
    for I:=1 to SndNum do
     begin
      Ini_Text_Win;
      GotoXY(01,22); Write('Bitte Daten-Wort [',I:2,'] eingeben: ');
      TmpAry[I] := Ask_Hex_Word;
     end;

    Checksum := 0;
    for I:=1 to SndNum do Checksum := Checksum + TmpAry[I];
    Checksum := not Checksum;                             {Bits invertieren}
    TmpAry[SndNum+1] := Checksum;

    Displ_TmpAry;
    Ini_Msg_Win;
    Write('Neue Daten (incl. Checksum) als gÅltig akzeptieren ?? [J/N]: ');
    Ch := ReadKey;
    if Ch in ['j','J'] then  for I:=0 to SndMax+1 do SndAry[I] := TmpAry[I];
   end;
 end; {AskSndData}

procedure  Mil_SDuP_Stat;
 var
  Fct     : TFct;
  MilErr  : TMilErr;
  RdData  : Word;
  WrData  : Word;
  Mil_Timout : Boolean;
  PcStat  : TPcStat;

 begin
   Ini_Text_Win;
   Ch := ' ';
   Transf_Cnt := 0;
   GotoXY(6, 11);  Writeln('Display_Cnt: ');
   GotoXY(10,15);  Writeln('Interl = ');
   GotoXY(10,16);  Writeln('DtaRdy = ');
   GotoXY(10,17);  Writeln('DtaReq = ');

   GotoXY(25,15);  Write('[Transfer-Fehler: Synchr, Checksum, Wordcount]');
   GotoXY(25,16);  Write('[SDuP bereit zum Senden]');
   GotoXY(25,17);  Write('[SDuP Busy: nicht bereit zum Empfang]');

   WrData    := Ifc_Irmask_All; {IFC: Enable Intr.> Test im PC-Status ist schneller}
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Set_IntMask;
   Mil.Wr (WrData, Fct, MilErr);
   Ini_Msg_Win;
   Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');

   repeat
     repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1; GotoXY(18,11);  Write(Transf_Cnt:10);
      PcStat.W := Port[Port_Stat];            {Lese internen Status}
      GotoXY(20,15);  if [Intl] <= PcStat.B then  Write('"1"') else Write('"0"');
      GotoXY(20,16);  if [Drdy] <= PcStat.B then  Write('"1"') else Write('"0"');
      GotoXY(20,17);  if [Dreq] <= PcStat.B then  Write('"1"') else Write('"0"');
     until KeyPressed or (Ch = ' ');
     if Ch = ' ' then
       begin
        Ini_Msg_Win;
        Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
        repeat until KeyPressed;
       end;
     Ch := ReadKey;
   until Ch in ['x','X'];

   WrData    := Ifc_Irmask_Dis; {IFC: Disable Intr.}
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Set_IntMask;
   Mil.Wr (WrData, Fct, MilErr);
 end; {Mil_SDuP_Stat}

function SDuP_Snd: Boolean;     {Sende Daten aus dem Send-Array}
 label 1;
 var I : Word;
    Fct: TFct;
    WrData : Word;
    MilErr : TMilErr;
    PcStat : TPcStat;

 begin
  Fct.B.Adr := Ifc_Test_Nr;
  Fct.B.Fct := Fct_Wr_Sw1;
  SDuP_Snd  := False;
  if not (SndAry[0] = 0) or (SndAry[0] > SndMax) then
   begin         {PrÅfe mit Timeout, ob  SDuP bereit ist fÅr DatenÅbertragung}
     Mil.Timer2_Set (SDuP_Wait_Rdy);
     repeat
      PcStat.W := Port[Port_Stat];                       {Lese internen Status}
     until (not ([Dreq] <= PcStat.B)) or Mil.Timeout2;         {DtaReq= False: Ready}
     if Mil.Timeout2 then
     begin
      Ini_Err_Win;
      Write('Error: Timeout! (Dreq) > SDuP nicht bereit.   Weiter mit beliebiger Taste!');
      ReadKey;
      SDuP_Snd := False;
      goto 1;
     end;

     Mil.Reset;                                  {Rcv-Fifo lîschen}
     WrData := $A55A;                            {Synchwort an SDuP}
     Mil.Wr (WrData, Fct, MilErr);
     for I:=0 to SndAry[0]  do                {Wordcount + Daten + Checksum}
      begin
        Mil.Timer2_Wait(10);                      {warte auf SDuP}
        Mil.Timer2_Set (SDuP_Wait_Rdy);
        repeat
         PcStat.W := Port[Port_Stat];                   {Lese internen Status}
        until (not ([Dreq] <= PcStat.B)) or Mil.Timeout2;  {DtaReq= False: Ready}
        if Mil.Timeout2 then
        begin
         Ini_Err_Win;
         Write('Error: Timeout! (Dreq) > SDuP nicht bereit.   Weiter mit beliebiger Taste!');
         ReadKey;
         SDuP_Snd := False;
         goto 1;
        end;

        Mil.Timer2_Wait(10);                      {warte auf SDuP  ??}
        WrData := SndAry[I];
        Mil.Wr (WrData, Fct, MilErr);
        if MilErr <> No_Err then
         begin
          Ini_Err_Win;
          Write('Error: SDuP > Write Mil nicht mîglich!   Weiter mit beliebiger Taste!');
          ReadKey;
          SDuP_Snd := False;
          goto 1;
         end;
      end; {for I..}
      SDuP_Snd := True;
     end
  else
   begin              {Anzahl Daten Falsch}
    Ini_Err_Win;
    Write('Error: Anzahl Send-Daten = 0 oder > ',SndMax,'!    Weiter mit beliebiger Taste!');
    ReadKey;
   end;
1:
 end; {SDuP_Snd}

procedure SDuP_Read (var Data: Word; Fct : TFct; var MilErr: TMilErr);
  var Time_Out: Boolean;
  begin
   Portw[Port_Tmr1] := TimeWrRdy;                           {Timer 1 starten}
   repeat
    Time_Out := Mil.Timeout1;
   until ((Portw[Port_Stat] and Stat_Wrt_Rdy) = Stat_Wrt_Rdy) or Time_Out;

   if ((Portw[Port_Stat] and Stat_Wrt_Rdy) = Stat_Wrt_Rdy) then
    begin
     Portw[Port_Mode] := Cmd_Mode;
     Portw[Port_Data] := Fct.W;                     {Funktionscode schreiben}
     Portw[Port_Tmr1] := 20;   {SDuP sollte in 100 us antworten}
     repeat
      Time_Out:= Mil.Timeout1;
     until ((Portw[Port_Stat] and Stat_Val_Wrd) = Stat_Val_Wrd) or Time_Out;
     if ((Portw[Port_Stat] and Stat_Val_Wrd) = Stat_Val_Wrd) then
      begin
       Data   := Portw[Port_Data];                         {Mil-Daten lesen}
       MilErr := No_Err;
      end
     else
       MilErr := Rd_To;
    end
   else
      MilErr  := Fc_To;
 end; {mil.rd }

procedure  SDuP_Rcv(Rd_Timeout: LongInt);
 label 1,2;
 var I      : Word;
     PcStat : TPcStat;
     Fct    : TFct;
     MilErr : TMilErr;
     RdData : Word;
 begin
  I := 0;
  RcvAry[0] := 0;                               {Default Anzahl der Rcv-Daten}
  Fct.B.Adr := Ifc_Test_Nr;
  Fct.B.Fct := Fct_Rd_Ist1;
  Mil.Timer2_Set (Rd_timeout);               {Wartezeit hÑngt vom Testmode ab}
  repeat
      repeat
       PcStat.W := Port[Port_Stat];
      until ([Drdy] <= PcStat.B) or Mil.Timeout2;
      if Mil.Timeout2 then goto 1;                              {uP Send-Ende}

      SDuP_Read (Read_Data, Fct, MilErr);     {wegen Checksum auf 2 ms erhîht}
       if MilErr = No_Err then
        begin
         I := I + 1;
         RcvAry[I] := Read_Data;
         RcvAry[0] := I;                                  {Rette Anzahl Rcv-Data}
        end
      else
        begin
         RcvAry[0] := I;                                  {Rette Anzahl Rcv-Data}
         Ini_Err_Win;
         Write('Error: SDuP Mil-Rcv, Rcv-Count= ',I:4,'.  Weiter mit beliebiger Taste!');
         ReadKey;
        end;
  until (I=RcvMax) or not (MilErr=No_Err);

1:
  PcStat.W := Port[Port_Stat];
  if (I=RcvMax) and ([Drdy] <= PcStat.B) then
    begin
     Ini_Err_Win;
     Write('Error: Entweder RcvCount>', I:4,'? od. DtaRdy-Status.? Weiter mit beliebiger Taste!');
     ReadKey;
     goto 2;
    end;

  if not ([FfoEty] <= PcStat.B) then
    begin
     Ini_Err_Win;
     Write('Error: SDuP_Rcv Count [', I:4,'] -> Fifo nicht leer!  Weiter mit beliebiger Taste!');
     ReadKey;
     goto 2;
     end;
2:
 end; {SDuP_Rcv}

function  SDuP_Displ_RcvDta: Char;
 label 1;
 const
  Zeile_Ini  = 5;  {Start Zeile  fÅr Tabdarstellung}
 var I : Integer;
     Zeile, Spalte : WORD;
     answer : Char;

  procedure Disp_Rcv_Dta (Index: Word);   {Nx16 Zeilen der Tabelle darstellen}
   var Z,S : Integer;
   begin
     ini_text_win;
     GotoXY(20, 01);
     Write(' Anzeige der Rcv-Daten!      Total-Rcv_Count: ',RcvAry[0]);
     for S:= 1 to 6 do
      begin
        Spalte := S*13-12;   Zeile:= Zeile_Ini;
        GotoXY(Spalte, 03);  Write('Idex  Data');
        GotoXY(Spalte, 04);  Write('----  ----');
        for Z := 1 to 16 do                    {jeweils 16 Zeilen im Textfenster}
         begin
          if Index <= RcvMax then
           begin
            GotoXY(Spalte  ,Zeile);  Write(Index:4);
            GotoXY(Spalte+6,Zeile);  Write(Hex_Word(RcvAry[Index]));
            Zeile := Zeile + 1;
            Index := Index + 1;
           end;
         end; {for Z}
      end; {for}
   end; {Displ_Tab}

 begin
   I:= 1;
   while True do begin
    Disp_Rcv_Dta (I);
    Ini_Msg_Win;
    Write('Weitere Daten mit <Space>, [R]ÅckwÑrts  bzw. [Q]uit or e[X]it ');
    Answer := ReadKey;
    if Answer in ['q','Q','x','X'] then
     begin
      Ini_Text_Win;
      SDuP_Displ_RcvDta:= Answer;
      goto 1;
     end;

    if Answer = ' ' then
     begin
       if I >= (RcvMax - 96) then I:=RcvMax-95 else I:=I+96;
     end;

    if Answer in ['r','R'] then
     begin
      if (I-96) < 1 then I:=1  else I:=I-96;
     end;
   end; {while}

   Ini_Msg_Win;
   Write('Weiter mit beliebiger Taste!');
   Readkey;
   Ini_Text_Win;
1:
 end;

procedure Mil_SDuP_Snd;
 label 1;
 var
  Fct     : TFct;
  MilErr  : TMilErr;
  RdData  : Word;
  WrData  : Word;
  Mil_Timout : Boolean;
  PcStat  : TPcStat;
  SndRcvMode : Boolean; {False: nur Senden}
  SndStat : Boolean;
  RcvStat : Boolean;
  RcvCnt  : Word;
  Ret_Adr : Byte;
  Onl_Err : TOnlineErr;

  procedure Displ_Text;
   begin
    Ini_Text_Win;
    GotoXY(6, 11);  writeln('Transfr_Cnt: ');
    GotoXY(22,12);  writeln('^  ^');

    GotoXY(53,11);  write('Timeout:');
    GotoXY(61,11);  write(timout_wr:10);
    Ini_Msg_Win;
    Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');
    Set_Text_win;
   end;

 begin
   Transf_Cnt := 0;
   Timout_Wr  := 0;
   Timout_Rd  := 0;
   RcvCnt     := 0;
   SndRcvMode := False;   {Default nur senden}

   Mil.Ifc_Online (Ifc_Test_Nr, Ret_Adr, Onl_Err);
   if (Onl_Err <> NoErr) then
    begin
     Ini_Text_Win;
     Ini_Err_Win;
     Write('Error: IFC-Karte ', Hex_Byte(Ifc_Test_Nr),' [Hex] nicht vorhanden!    Weiter mit beliebiger Taste.');
     ReadKey;
     goto 1;
    end;

   WrData    := Ifc_Irmask_All; {IFC: Enable Intr.> Test im PC-Status ist schneller}
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Set_IntMask;
   Mil.Wr (WrData, Fct, MilErr);

   Ini_Text_Win;
   AskSndData;
   Ini_Msg_Win;
   Write('Daten zum SD-uP nur [S]enden, senden/[E]mpfangen, [Q]uit: ');
   Key := ReadKey;
   if (Key in ['e','E']) then SndRcvMode := True;
   if (Key in ['q','Q']) then goto 1;

   Ini_Msg_Win;
   Write('Jetzt Daten an den SD-uP senden? [J/N]:  ');
   Key := ReadKey;
   if not (Key in ['j','J']) then goto 1;
   Displ_Text;

   Key := ' ';
   repeat
     repeat
       Displ_Text;
       Transf_Cnt := Transf_Cnt +1;
       GotoXY(18,11);  Write(Transf_Cnt:10);

       Mil.Reset;                                 {Lîsche evtl. alte Info}
       PcStat.W := Port[Port_Stat];               {Fehler nur anzeigen}
       if ([Intl] <= PcStat.B) then
        begin
         Ini_Err_Win;
         Write('Error: SDuP-Status vor Senden: Intl (Transf-Err).  Send mit beliebiger Taste.');
         ReadKey;
        end;

       if SndRcvMode then                            {Senden/Empfangen}
        begin
         IniRcvAry;
         SndStat := SDuP_Snd;
         if SndStat then
          begin
           SDuP_Rcv(SDuP_Wait_Dta);
           SDuP_Displ_RcvDta;
          end;

         Key := ' ';
         Displ_Text;
         GotoXY(18,11);  Write(Transf_Cnt:10);
        end
       else
        begin
          SndStat := SDuP_Snd;                      {Nur senden}
          Key := ' ';                               {Loop ausschlie·en}
          Mil.Timer2_Wait(100000);
          PcStat.W := Port[Port_Stat];
          if ([Intl] <= PcStat.B) then
           begin
            Ini_Err_Win;
            Write('Error: SDuP-Stat nach Senden: Intl (Transf-Err!). Weiter mit beliebiger Taste.');
            ReadKey;
           end;
        end;
      until KeyPressed or (Key = ' ');
      Displ_Text;
      GotoXY(18,11);  Write(Transf_Cnt:10);
      {Single_Loop(Key);  }
     until Key in ['x','X'];

1: WrData    := Ifc_Irmask_Dis; {IFC: Disable Intr.}
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Set_IntMask;
   Mil.Wr (WrData, Fct, MilErr);
 end;  {Mil_SDuP_Snd}

 FUNCTION ask_intr_data: WORD;
 VAR in_data : WORD;
     input_ok: BOOLEAN;
 Begin
  input_ok:= FALSE;
  WHILE NOT input_ok DO
   Begin
    Ini_Text_Win;
    GotoXY(5, 22);
    write ('Welches Signal: [0001]=Intlock, [0002]=DtaRdy, [0004]=DtaReq ?');
    In_Data := Ask_Hex_Word;
    IF NOT (in_data < 8) THEN
      begin
        Ini_Err_Win;
        write('ERROR: Sorry, User: Zahl darf nur max. 7 sein!!');
        ReadKey;
      end
    ELSE
      input_ok := TRUE;
   End; {WHILE}
  ask_intr_data := in_data;
 End; {ask_intr_data}

procedure MIL_Set_Intr;
 label 1;
 var
  WrData  : Word;
  I       : LongInt;

   PROCEDURE show_stat_reg;
    var Read_Data : Word;
    Begin
     read_data   := PORTW [Port_Stat];
     GotoXY(28, 17);  write(hex_word(read_data));
     Hex_Bin_Str (read_data, Bit16_Str);
     GotoXY(22, 18);  write(bit16_str);
    End;

  procedure Displ_Text;
   begin
    Ini_Text_Win;
    GotoXY(6, 11);  writeln('Transfr_Cnt: ');
    GotoXY(22,12);  writeln('^  ^');
    GotoXY(6, 17);  writeln('Stat-Data[Hex]');
    GotoXY(6, 18);  writeln('Stat-Data[Bin]');
    GotoXY(12, 19); writeln('          MSB             LSB');
    displ_pc_stat;           {Zeige die Bitbelegung als Info}
    Ini_Msg_Win;
    Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');
    Set_Text_win;
   end;

 begin
   Transf_Cnt := 0;
   WrData := ask_intr_data;
   Displ_Text;
   Key := ' ';
   repeat
     repeat
       Set_Text_Win;
       GotoXY(18,11);  Write(Transf_Cnt:10);
       PORTW [Port_Intr] := WrData;                               {user-input}
       Mil.Timer2_Wait(5);                                     { Wartet 5x10us}
       show_stat_reg;
       Transf_Cnt := Transf_Cnt + 1;
       for I := 1 to 10000 do;                              {Slowdown display}
     until KeyPressed or (Key = ' ');
    { Single_Loop(Key); }
   until Key in ['x','X'];
1:
   PORTW [Port_Intr] := 0; {Interuupts wieder lîschen}
 end; {MIL_Set_Intr;  }

procedure  Displ_TmpAry;          {TmpAry[0] = incl. Checksum}
 var N : Word;
 begin
   Ini_Text_Win;
   Writeln ('Send-WordCount: ',  Hex_Word(TmpAry[0]),' [Hex]');
   for N := 1 to TmpAry[0] do
    begin
      if N = (TmpAry[0]) then
        Writeln ('Send-Checksum : ', Hex_Word(TmpAry[N]),' [Hex]')
      else
        Writeln ('Send-Daten[',N:2,']: ', Hex_Word(TmpAry[N]),' [Hex]');
    end;
 end; {Displ_TmpAry}

procedure Create_SndTstAry (SndNum: Word);
 var I       : Word;
     Checksum: Word;
     Input_Ok: Boolean;
 begin
    IniSndAry;
    for I := 0 to SndMax do TmpAry[I] := 0;    {Init Arry}
    TmpAry[1] := 127; {7F}                          {Sd-Command: SndTestpattern}
    if SndNum > 1 then
        for I := 2 to SndNum do TmpAry[I] := I-1;
    TmpAry[0] := SndNum+1;
    Checksum := 0;
    for I:=1 to SndNum do Checksum := Checksum + TmpAry[I];
    Checksum := not Checksum;                             {Bits invertieren}
    TmpAry[SndNum+1] := Checksum;
    for I:=0 to SndMax+1 do SndAry[I] := TmpAry[I];

    if DispMode then
     begin
      Displ_TmpAry;
      Ini_Msg_Win;
      Write('Anzeige des Send_Cmd_Paketes! Weiter mit irgend einer Taste! ');
      Ch := ReadKey;
     end;
 end; {Create_SndTstAry}


procedure  Create_RdTstAry;
 var I       : Word;
     SndNum  : Word;
     Checksum: Word;
     Input_Ok: Boolean;
 begin
    IniSndAry;
    SndNum := 1;
    for I := 0 to SndMax do TmpAry[I] := 0;    {Init Arry}
    TmpAry[1] := $FE;                          {Sd-Command: Read Testpattern}
    TmpAry[0] := SndNum+1;
    Checksum := 0;
    for I:=1 to SndNum do Checksum := Checksum + TmpAry[I];
    Checksum := not Checksum;                             {Bits invertieren}
    TmpAry[SndNum+1] := Checksum;
    for I:=0 to SndMax+1 do SndAry[I] := TmpAry[I];

    if DispMode then
     begin
      Displ_TmpAry;
      Ini_Msg_Win;
      Write('Anzeige des Rcv_Cmd_Paketes! Weiter mit irgendeiner Taste! ');
      Ch := ReadKey;
     end;
 end; {Create_RdTstAry}

procedure Mil_SDuP_Pattern;
 label 1;
 var
  N,I     : Word;
  Fct     : TFct;
  MilErr  : TMilErr;
  RdData  : Word;
  WrData  : Word;
  Mil_Timout : Boolean;
  PcStat  : TPcStat;
  SndStat : Boolean;
  RcvStat : Boolean;
  RcvCnt  : Word;
  SndNr   : Word;
  Checksum : Word;
  ErrCnt  : LongInt;
  Ret_Adr : Byte;
  Onl_Err : TOnlineErr;


  procedure Displ_Text;
   begin
    Ini_Text_Win;
    GotoXY(3, 11);  writeln('Transfr_Cnt: ');
    GotoXY(19,12);  writeln('^  ^');

    GotoXY(33,11);  writeln('Error_Count: ');
    GotoXY(47,11);  write(ErrCnt:8);

    GotoXY(60,11);  write('Timeout: ');
    GotoXY(70,11);  write(timout_wr:8);
    Ini_Msg_Win;
    Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');
    Set_Text_win;
   end;

 begin
   Transf_Cnt := 0;
   Timout_Wr  := 0;
   Timout_Rd  := 0;
   RcvCnt     := 0;
   ErrCnt     := 0;
   DispMode := False;   {Buffer nicht anzeigen}

   Mil.Ifc_Online (Ifc_Test_Nr, Ret_Adr, Onl_Err);
   if (Onl_Err <> NoErr) then
   begin
     Ini_Text_Win;
     Ini_Err_Win;
     Write('Error: IFC-Karte ', Hex_Byte(Ifc_Test_Nr),' [Hex] nicht vorhanden!    Weiter mit beliebiger Taste.');
     ReadKey;
     goto 1;
    end;

   Ini_Text_Win;
   Ini_Msg_Win;
   Write('Sollen Sende- und Empfangsdaten angezeigt werden? [J/N]: ');
   Key := ReadKey;
   if Key in ['j','J'] then DispMode := True;

   WrData    := Ifc_Irmask_All; {IFC: Enable Intr.> Test im PC-Status ist schneller}
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Set_IntMask;
   Mil.Wr (WrData, Fct, MilErr);

   Displ_Text;
   Key := ' ';
   N := 2;
   repeat
     repeat
       Mil.Reset;
       Mil.Ifc_Online (Ifc_Test_Nr, Ret_Adr, Onl_Err);
       if (Onl_Err <> NoErr) then
        begin
{         Ini_Text_Win;  }
         Ini_Err_Win;
         Write('Error: IFC-Karte ', Hex_Byte(Ifc_Test_Nr),' [Hex] nicht vorhanden!    Weiter mit beliebiger Taste.');
         ReadKey;
         goto 1;
        end;

       Displ_Text;
       IniRcvAry;
       Transf_Cnt := Transf_Cnt +1;
       GotoXY(18,11);  Write(Transf_Cnt:8);

       PcStat.W := Port[Port_Stat];               {Fehler nur anzeigen}
       if ([Intl] <= PcStat.B) then
        begin
         Mil.Reset;                               {Fehler lîschen ?}
         Ini_Err_Win;
         Write('Error: SDuP-Status vor Senden: Intl (Transf-Err).  Ende mit beliebiger Taste.');
         ReadKey;
         goto 1;
        end;

       PcStat.W := Port[Port_Stat];               {Fehler nur anzeigen}
       if ([DRdy] <= PcStat.B) then
        begin
         Mil.Reset;                               {Fehler lîschen ?}
         Ini_Err_Win;
         Write('Error: SDuP-Status vor Send: DtaRdy (Daten bereit).  Ende mit beliebiger Taste.');
         ReadKey;
         goto 1;
        end;

       Create_SndTstAry (N);                 {Command mit Testpattern an SDuP}
       SndStat := SDuP_Snd;
       if not SndStat then goto 1;

       Create_RdTstAry;
       SndStat := SDuP_Snd;
       if not SndStat then goto 1;
       SDuP_Rcv(SDuP_Wait_Ptrn);           {Timeout fÅr PatternTest Åbergeben}
       Checksum := 0;
       if N > 1 then                                 {PrÅfe das Empfangspaket}
        begin
         if RcvAry[0] = 0 then
          begin
           Timout_Wr:=Timout_Wr+1;
           if DispMode then
            begin
             Ini_Err_Win;
             Write('Error: Keine Empfangsdaten!       Weiter mit beliebiger Taste!');
             Key := ReadKey;
            end;
          end
         else
          begin
            for I:= 2 to RcvAry[0] - 1 do      {ohne Checksum}
             begin
               Checksum := Checksum + I-1;
               if (I-1) <> RcvAry[I] then
                begin
                 ErrCnt := ErrCnt + 1;
                 if DispMode then
                 begin
                  Ini_Err_Win;
                  Write('Error: Rcv-Pattern! Index[',I:4,'] Soll-Dta: ', Hex_Word(N-1));
                  Write(' Ist-Dta: ',Hex_Word(RcvAry[I]),' [Q]uit');
                  Key := ReadKey;
                  if Key in ['q','Q'] then goto 1;
                 end;
                end;  {if}
             end;     {for}
            Checksum := not Checksum;                             {Bits invertieren}
            if Checksum <> RcvAry[RcvAry[0]] then
              begin
               ErrCnt := ErrCnt + 1;
               if DispMode then
                begin
                 Ini_Err_Win;
                 Write('Error: Checksum-Error in Rcv-Daten!   Weiter mit beliebiger Taste');
                 ReadKey;
                end;
              end;  {if Checksum}
            if DispMode then
             begin
               Ch := SDuP_Displ_RcvDta;
               if Ch in ['x','X'] then goto 1;
             end;
        end; {if N > 1}
       end;
{       Key := ' ';  }                             {Loop ausschlie·en}
     Displ_Text;
     GotoXY(18,11);  Write(Transf_Cnt:8);
     GotoXY(47,11);  Write(ErrCnt:8);

     N := N + 1;
     if N > 9 then N := 2;                 {Mehr als 9 kann  SDuP nicht}
    until KeyPressed or (Key = ' ');
    Displ_Text;
    GotoXY(18,11);  Write(Transf_Cnt:8);
    GotoXY(47,11);  Write(ErrCnt:8);
   { Single_Loop (Key); }
   until Key in ['x','X'];

1: WrData    := Ifc_Irmask_Dis; {IFC: Disable Intr.}
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Set_IntMask;
   Mil.Wr (WrData, Fct, MilErr);
 end; {SDuP-Pattern}

 PROCEDURE mil_fifo;
 { In diesem Test wird das FIFO mit Daten gefÅllt und der FÅllstand im
   Status-Register angezeigt  sowie Daten aus dem FIFO gelesen.
   Dazu mu· eine IFC am MIL-Bus sein.
 }
   LABEL 99, 1;
   VAR
    i : WORD;
    error_cnt : LONGINT;
    test_count: WORD;
    fifo_err  : BOOLEAN;
    fifo_64k  : Boolean;
    wr_fct_code, rd_fct_code : WORD;
    PcStat  : TPcStat;
    Fct     : TFct;
    MilErr  : TMilErr;
    Ret_Adr : Byte;
    Onl_Err : TOnlineErr;

   procedure Wr_Rd_Mil (N: Word);
    begin
      Set_Text_win;
      Transf_Cnt := Transf_Cnt + 1;
      GotoXY(18,05);  Writeln(Transf_Cnt:10);
      GotoXY(47,05);  Writeln(hex_word(N));                      {Write-Daten}

      Fct.B.Fct :=  Fct_Wr_Sw1;
      Mil.Wr (N, Fct, MilErr);                       {Daten zur IFC schreiben}
      if MilErr <> No_err then
      begin
       Timout_Wr:= Timout_Wr +1;
       GotoXY(65,05);  writeln(timout_wr:6);
       end;

      Fct.B.Fct := Fct_Rd_Ist1;           {RÅcklesen Daten = Transfer in Fifo}
      Mil.WrFct (Fct, MilErr);
      Mil.Timer2_Wait(5);                                     { Wartet 5x10us}
      Read_Data := PortW[Port_Stat];                    {zeige Status-port an}
      GotoXY(28, 17);  Writeln(hex_word(read_data));
      Hex_Bin_Str (read_data, Bit16_Str);
      GotoXY(22, 18);  Writeln(bit16_str);
    end; {Wr_Rd_Mil}

   procedure Rd_Fifo (N: Word);
    begin
      Set_Text_win;
      Read_Data    := PortW[Port_Data];                  {Daten aus FIFO lesen}
      Transf_Cnt   := Transf_Cnt + 1;
      GotoXY(18,06);  Writeln(Transf_Cnt:10);
      GotoXY(47,05);  writeln(hex_word(N));                   {Soll-Write-Daten}
      GotoXY(47,06);  writeln(hex_word(read_data));        {Anzeigen Fifo-Daten}

      IF NOT (N = read_data) THEN
       Begin
         error_cnt := error_cnt + 1;
         GotoXY(47,06); writeln(hex_word(read_data));
         GotoXY(65,06); writeln(error_cnt:6);
         if not Fifo_Err then                 {Fehlertext nur beim ersten Mal}
          begin
           Ini_Err_Win;
           write('FIFO Read-Error!!  Weiter mit <Space> ');
           repeat until keypressed;
           Ini_Msg_Win;
           Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');
           Ch := ' ';
          end;
         Fifo_Err := True;
       End;

      Set_Text_win;
      read_data   :=  PortW[Port_Stat]; ;
      GotoXY(28, 17);  writeln(hex_word(read_data));
      Hex_Bin_Str (read_data, Bit16_Str);
      GotoXY(22, 18);  writeln(bit16_str);
    end; {Rd_Fifo}

   Begin
    fifo_64k    := False; {Default: bei 64k fifo-full nicht testen}
    transf_cnt  := 0;
    error_cnt   := 0;
    timout_wr   := 0;
    timout_rd   := 0;
    Fct.B.Adr := Ifc_Test_Nr;

    Ini_Text_Win;
    GotoXY(08,22);
    write('Dieser Test benîtigt eine MIL-IFC mit Function-Code 06 u. 81[H]!');
    Ini_Msg_Win;
    write('Bei 64k-FIFO (wegen Fifo-Full) die Eingabe FFFF [Hex] um + 1 erhîhen? [J/N] ');
    repeat until keypressed;
    ch := READKEY;
    if Ch in ['j','J'] then fifo_64k := True;

    Ini_Text_Win;
    GotoXY(5, 22);
    write ('Wieviel MIL-Daten-Worte sollen ins RCV-FIFO transferiert werden?');
    test_count := Ask_Hex_Word; {--> user-input}

    Ini_Text_Win;
    GotoXY(6,03);
    write  ('IFC-Adr: ',hex_byte(ifc_test_nr),'            Wr-Fct-Code: 06[H]      Rd-Fct_Code: 81[H]');
    GotoXY(06,05); write('Wr_Data_Cnt:            ');
    GotoXY(32,05); write('Write-Data[H]:     ');
    GotoXY(53,05); write('WR-Timeout: ');
    GotoXY(65,05); write(timout_wr:6);

    GotoXY(06,06); write('Rd_Fifo_Cnt:            ');
    GotoXY(32,06); write('Fifo-Data [H]:     ');
    GotoXY(53,06); write('Error-Cnt : ');
    GotoXY(65,06); write(error_cnt:6);

    GotoXY(06,17); writeln('Stat-Data[Hex]');
    GotoXY(06,18); writeln('Stat-Data[Bin]');
    GotoXY(22,19); writeln('MSB             LSB');

    Mil.Reset;                                      { clear fifo }
    read_data := PortW[Port_Stat];                   {lese internen PC-Status}
    GotoXY(28, 17);  write(hex_word(read_data));
    Hex_Bin_Str (read_data, Bit16_Str);
    GotoXY(22, 18);  write(bit16_str);
    displ_pc_stat;                               {Anzeigen internen PC-Status}

    Ini_Msg_Win;
    write('Status-Register nach Reset Fifo!  Weiter mit <Space> ');
    repeat until keypressed;
    Ch := Readkey;

    Mil.Ifc_Online (Ifc_Test_Nr, Ret_Adr, Onl_Err);
    if (Onl_Err <> NoErr) then
     begin
      Ini_Err_Win;
      write('ERROR: IFC-Karte Nr.: ',hex_byte(Ifc_Test_Nr),' [H] nicht vorhanden!!  Ende mit <CR>');
      Readln (Ch);
      goto 99;
     end;

    Ini_Msg_Win;
    Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');

    Mil.Reset;                                      { clear fifo }
    transf_cnt  := 0;
    Ch := ' ';
    FOR i:= 1 TO test_count DO                                 {Daten zur IFC}
     begin
      Wr_Rd_Mil (i);
      IF  Ch = ' ' then
       begin
         Ini_Msg_Win;
         Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');
         repeat until keypressed;
         Ch := ReadKey;
         Set_Text_win;
       end;
      if  Ch in ['x','X'] then goto 99;
      if Fifo_64k and (i=$FFFF) then Wr_Rd_Mil($FFFF);
     End; {for}


    Ini_Msg_Win;
    Write('Daten im FIFO!!  Weiter: Auslesen Fifo und ÅberprÅfen mit [W] ');
    repeat
      ch := READKEY;
    until ch in ['w','W'];

    Ini_Msg_Win;
    Set_Text_win;
    GotoXY(32,05); write('Soll-Data [H]:     ');

                  {FiFo-Daten jetzt zurÅcklesen und prÅfen}
    transf_cnt  := 0;
    fifo_err    := False;
    Ch := ' ';
    FOR i:= 1 TO test_count DO
     Begin
      Rd_Fifo (i);
      IF  Ch = ' ' then
       begin
         Ini_Msg_Win;
         Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');
         repeat until keypressed;
         Ch := ReadKey;
         Set_Text_win;
       end;
      IF  Ch in ['x','X'] then goto 1;
      if Fifo_64k and (i=$FFFF) then Rd_Fifo($FFFF);
    End; {FOR i}

1:  Ini_Msg_Win;
    Write('FIFO-Test beendet!!  Beenden mit beliebiger Taste! ');
    repeat until keypressed;
    Set_Text_win;
99:
  End; {mil_fifo}


procedure Mil_WrData (mil_data: Word);   {nur Datenschreiben, ohne Fct-Code}
 label 99;
 VAR
      MilErr : TMilErr;

   Begin
    ini_text_win;
    transf_cnt:= 0;

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
End; {Mil_Hf_Cmd}


procedure Mil_WrDual_Fct;
 label 99;
 VAR
    MilErr : TMilErr;
    Fct    : TFct;
    Fct_Code1, Fct_Code2 : Byte;
    Adr1, Adr2           : Byte;

   Begin
    Adr1      := Ifc_Test_Nr;
    ADr2      := Ifc_Test_Nr + 1;

    ini_text_win;
    GotoXY(5, 22);
    write ('Welchen Function-Code Nr. 1 ??');
    Fct_Code1 := ask_hex_byte;

    ini_text_win;
    GotoXY(5, 22);
    write ('Welchen Function-Code Nr. 2 ??');
    Fct_Code2 := ask_hex_byte;

    ini_text_win;
    transf_cnt := 0;
    GotoXY(25,07); write  ('Function-Word1: ',hex_byte(Fct_Code1),hex_byte(Adr1) ,' [H]');
    GotoXY(25,08); write  ('Function-Word2: ',hex_byte(Fct_Code2),hex_byte(Adr2) ,' [H]');

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
      GotoXY(25,11);  Write(Transf_Cnt:10);

      Mil.Timer2_Wait(5);
      Fct.B.Adr := Adr1;
      Fct.B.Fct := Fct_Code1;
      Mil.WrFct (Fct, MilErr);

      Mil.Timer2_Wait(5);                                     { Wartet 5x10us}
      Fct.B.Adr := Adr2;
      Fct.B.Fct := Fct_Code2;
      Mil.WrFct (Fct, MilErr);
{xxx}
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


BEGIN   { Hauptprogramm }
  Ifc_Test_Nr := 0;
  IniSndAry;
  IniRcvAry;
  DispMode := False;  {SduP Sende- u. Empfangsbuffer anzeigen}

  REPEAT
    menue_win;
    User_Input := ReadKey;
    loop := TRUE;
    IF User_Input IN ['0'..'9'] THEN loop := FALSE;
    CASE User_Input OF
     '0'      : mil_detect_ifc;
     'a', 'A' : mil_ask_ifc;
     '1', 'b', 'B' : Begin
                       mil_rd_status;
                     End;
     '2', 'c', 'C' : Begin
                       mil_rd_fifo;
                     End;
     '3', 'd', 'D' : Begin
                       IF check_ifc_adr THEN mil_rd_ifc_stat;
                     End;
     '4','e', 'E' :  Begin
		       IF check_ifc_adr THEN mil_rd_data;
		     End;
     '5', 'f', 'F' : Begin
		       IF check_ifc_adr THEN mil_wr_fctcode;
		     End;
     '6', 'g', 'G' : Begin
		       IF check_ifc_adr THEN
			 Begin
			  mil_data := ask_data;
			  mil_wr(mil_data);
 			 End;
		     End;
     '7', 'h', 'H' : Begin
                       IF check_ifc_adr THEN
                        Begin
                         mil_data := ask_data;
                         mil_wr_rd(mil_data);
                        End;
                     End;
     '8', 'i', 'I' : Begin
                       IF check_ifc_adr THEN
                        Begin
                         mil_loop;
                        End;
                     End;
     '9', 'j', 'J' : Begin
                       timer_aktiv:= ask_timer_aktiv;
                       mil_data   := ask_timer_data;
                       mil_timer(mil_data);
                     End;
          'k', 'K' : Begin
                       mil_timeout;
                    End;
          'l', 'L' : Begin
                       mil_reset;
                      End;
          'm', 'M' : Begin
                       IF check_ifc_adr THEN mil_ifc_reset;
                     End;
          'n', 'N' : Begin
                       IF check_ifc_adr THEN
                        begin
                          mil_fifo;
                        end;
                     End;
          'r', 'R' : Begin
                          MIL_Set_Intr;
                     End;
          's', 'S' : Begin
                       IF check_ifc_adr THEN Mil_SDuP_Snd;
                     End;
          't', 'T' : Begin
                       IF check_ifc_adr THEN Mil_SDuP_Pattern;
                     End;
          'u', 'U' : Begin
                       IF check_ifc_adr THEN Mil_SDuP_Stat; ;
                     End;
          'v', 'V' : Begin
                       IF check_ifc_adr THEN
                        begin
			  mil_data := ask_data;
			  Mil_WrData(mil_data);
                        end;
                     End;
          'w', 'W' : Begin
                       IF check_ifc_adr THEN
                        begin
			 Mil_WrDual_Fct;
                        end;
                     End;
    End; {CASE}
  UNTIL user_input in ['x','X'];
  Window(1, 1, 80, 25);
  TextBackground(Black);
  ClrScr;
END. {mil_pc}





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

   FOR ifb_adr := 1 TO 255 DO                                 { Clear Array }
     ifb_online[ifb_adr] := FALSE;

   FOR ifb_adr := 1 TO 255 DO                 { Fill Array with actual data }
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
