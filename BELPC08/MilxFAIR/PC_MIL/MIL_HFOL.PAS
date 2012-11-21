PROGRAM Mil_Hf;                 { Programm MIL_PC.PAS mit OOP-Unit DATECH.TPU}
{ Autor: Gerhard Englert

  28.10.93: Dieses Programm wurde auf Turbo-Pascal Version 7.0 umgestellt.
  Neu: der Bildschirm ist in 3 Windows eingeteilt (s. a. ini_headl_win,
  ini_text_win und ini_msg_win). In jedem Window sind Grî·e, Hintergrund-
  Farbe und Schriftfarbe definiert, die der Anwender geÑndern darf.

  Modifikationen:
  26.10.94    Umstellung von MIL_PC.PAS auf MIL_HF.PAS
  24.11.94    Erweiterung fÅr Eingabe Phasen
  16.12.94    4-Bit Shift nach rechts fÅr Mil_Hf_WrSwAnalog;
  12.01.95    Volt-Anzeige in Mil_Hf_WrSwAnalog korrigiert
  26.05.95    Volt-Anzeige in Mil_Hf_WrSwAnalog nochmals korrigiert
  20.07.95    Online IFC neu
  13.09.95    Status-Bit Ext. Interl von 1 aktiv auf 0-aktiv
}

{$S-}
uses Crt, WinDos, Datech;

CONST
 HF_Dta    = $0080;
 Wait_Test = 50 * 100;  {max. 10,0 msec warten}

 hardw_timer_timeout = 1000000;
 SndMax = 10;                 {Sd-uP: max. Anzahl SendDaten}
 RcvMax = 1024;               {Sd-uP: max. Anzahl RcvDaten}
 SDuP_Wait_Rdy  =  500 * 100;  {max. 0,5 sec warten bis SDuP ready ist}
 SDuP_Wait_Dta  =  3000 * 100; {max. 3,0 sec warten bis Daten vom SDuP}
 SDuP_Wait_Ptrn =  10 * 100;   {max. 10,0 msec warten bis Daten vom SDuP}

 head_line =
      'Datentechnik                      MIL-PC     ' +
      '                       [13.09.1995]'+
      '                   UNILAC-HF u. MIL-Tests (Turbo_Pascal V7.0)';

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
{
 TmpAry    : array [0..SndMax] of Word;
 SndAry    : array [0..SndMax] of Word;
 RcvAry    : array [0..RcvMax] of Word;
 DispMode  : Boolean;
}

procedure menue_win;
VAR answer: CHAR;
begin
  Ini_Headl_Win;
  Write(head_line);
  ini_text_win;
  GotoXY(12, 1);
  Writeln('*********************  TEST-MENUE  ********************* ');
  GotoXY(12, 2);
  Writeln('     +-- SINGLE --+                    +-- LOOP --+      ');
  GotoXY(12, 3);
  Writeln('[0]<-- Welche IFC am MIL-Bus?        Defin. IFC-Adr -->[A]');
  GotoXY(12, 4);
  Writeln('[1]<--     Lese Status-Register PC-Interface        -->[B]');
  GotoXY(12, 5);
  Writeln('[2]<--     Lese IFC-Status (Intr-Mask usw. [C9H])   -->[C]');
  GotoXY(12, 6);
  Writeln('[3]<--     Lese Daten von IFC-Karte                 -->[D]');
  GotoXY(12, 7);
  Writeln('[4]<--     Schicke Funktionscode zur IFC-Karte      -->[E]');
  GotoXY(12, 8);
  Writeln('[5]<--     Schreibe Daten zur IFC-Karte             -->[F]');
  GotoXY(12, 9);
  Writeln('[6]<--     Schreibe/Lese IFC-Karte (User-Daten)     -->[G]');
  GotoXY(12,10);
  Writeln('           [I]--> GerÑte-Status lesen          (C0H)    ');
  GotoXY(12,11);
  Writeln('           [J]--> Istwert Amplitude lesen      (84H)    ');
  GotoXY(12,12);
  Writeln('           [K]--> SW Amplitude Eingabe in Volt (06H)    ');
  GotoXY(12,13);
  Writeln('           [L]--> SW Phase     Eingabe in Grad (07H)    ');
  GotoXY(12,14);
  Writeln('           [M]--> HF-Kommandos             (02..19H)    ');
  GotoXY(12,15);
  Writeln('         v--------- Spezielle Hardware-Tests --------v  ');
  GotoXY(12,16);
  Writeln('           [O]--> SW-Ampl. (Fct 06H), BinÑr-Eingabe     ');
  GotoXY(12,17);
  Writeln('           [P]--> SW-Phas. (Fct 07H), BinÑr-Eingabe     ');
  GotoXY(12,18);
  Writeln('           [Q]--> SW-Ampl. (Fct 06H), Daten autom. 0/1  ');
  GotoXY(12,19);
  Writeln('           [R]--> SW-Phas. (Fct 07H), Daten autom. 0/1  ');
  GotoXY(12,20);
  Writeln('           [S]--> Phas.Schieber Li Ein/Aus (Fct 17/19H) ');

  GotoXY(23,21);
  Writeln('[T]--> Phas.Schieber Re Ein/Aus (Fct 18/19H) ');
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

{
 PROCEDURE mil_detect_ifc;
  CONST start_zeile = 5;
  VAR ifc_total  : WORD;
      ifb_online : ARRAY[1..255] OF BOOLEAN;
      ifb_adr    : WORD;
      zeile      : BYTE;
      hex_str    : STRING[10];
      i          : WORD;
      retAdr     : Byte;
      OnlineErr  : TOnlineErr;
  Begin
   ini_text_win;
   ifc_total := 0;
   ini_msg_win;
   GotoXY(1, 1);
   write('Bitte warten. IFC-Karten am Mil-Bus werden gesucht!');

   FOR ifb_adr := 1 TO 255 DO
     ifb_online[ifb_adr] := FALSE;

   FOR ifb_adr := 1 TO 255 DO
    Begin
     Mil.Ifc_Online (Ifb_Adr, RetAdr, OnlineErr);
     IF OnlineErr = NoErr THEN
      Begin
       ifb_online[ifb_adr] := TRUE;
       ifc_total := ifc_total + 1;
      End;
   End;
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
  End;
}

 PROCEDURE mil_detect_ifc;
  label 99;
  CONST start_zeile = 4;
        start_spalte =5;
        zeile_max    =22;
        spalte_offset=20;

  VAR ifc_total  : WORD;
      ifb_online : ARRAY[0..255] OF BOOLEAN;
      ifb_adr    : WORD;
      zeile,spalte: BYTE;
      hex_str    : STRING[10];
      i,n        : WORD;
      RetAdr     : Byte;
      OnlineErr  : TOnlineErr;

  Begin
    ini_text_win;
    GotoXY (10, 02);
    writeln ('Start der Abfrage durch Eingabe gemÑ· unterster Zeile!!');

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
      ifc_total := 0;
      zeile := start_zeile;
      spalte:= start_spalte;
      ini_text_win;

      GotoXY(18,1); ClrEol;
      write('Am MIL-Bus melden sich insgesamt IFC-Karten: ');
      GotoXY(2,2);  write(' Soll--ADR--Ist      Soll--ADR--Ist      Soll--ADR--Ist      Soll--ADR--Ist');
      GotoXY(2,3);  write(' [Hex]....[Hex]      [Hex]....[Hex]      [Hex]....[Hex]      [Hex]....[Hex]');

      FOR ifb_adr := 0 TO 255 DO
        Begin
          mil.ifc_online (ifb_adr, RetAdr, OnlineErr);
{if ifb_adr in [1..60] then OnlineErr := NoErr;  }
          If OnlineErr = NoErr then
            begin
             if (ifb_adr=0) or (ifb_adr<>RetAdr) then TextColor(Red); {Setze Schriftfarbe}
             GotoXY (spalte, zeile);
             hex_str := hex_byte(ifb_adr);
             write(hex_Byte(Ifb_Adr));                           {Solladresse}
             GotoXY (spalte+8, zeile); write(hex_Byte(RetAdr));  {Istadr}
             TextColor(Black); ClrEol;                    {Setze Schriftfarbe}
             zeile := zeile + 1;
             IF (zeile > zeile_max )  THEN
              begin
                spalte := spalte + spalte_offset;
                zeile  := start_zeile;
              end;

             ifc_total := ifc_total + 1;
            end
          else
            begin     {Online-Error auswerten}

            end; {if OnlineErr}
        End; {FOR}

     GotoXY(63,01); write(ifc_total);
     Mil.Timer2_Wait(100000);
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
 End; {detect_ifc}



  PROCEDURE mil_ask_ifc;
  VAR answer : CHAR;
  Begin
    status := FALSE;
    WHILE NOT status DO
     Begin
      ini_test_win;
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

FUNCTION Ask_Sw_BitShift: Boolean;
 Begin
    ini_text_win;
    ini_msg_win;
    write   ('--> Sollwerteingabe als [B]inÑr-Wert oder Bit-[S]chieben? (Default [B]): ');
    Ch := ReadKey;
    if  Ch in ['s','S'] then
     Ask_Sw_BitShift := True
    else
     Ask_Sw_BitShift := False;
 End;

FUNCTION MIL_Hf_ask_data: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    ini_text_win;
    GotoXY(5, 22);
    write ('Beachten! FÅr Bit15 (MSB) gilt:  1 = Strahl, 0 = Pause) ');
    ini_msg_win;
    write   ('--> Bitte 4-stellige Hex-Daten eingeben: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
      Begin
       ini_err_win;
       writeln('ERROR: Sorry, USER: das war keine 4-stell. Hexzahl!!');
      End;
   End; {WHILE}
  MIL_Hf_ask_data := in_data;
 End;



 FUNCTION ask_timer_aktiv: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    ini_test_win;
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
    ini_test_win;            {Defin. Fenster, lîsche Fenster}
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
    ini_test_win;
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
    ini_test_win;
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
        time := hardw_timer_timeout; {Software-Timeout erneut setzen!!}
        IF keypressed THEN GOTO 99;
        write_data := write_data shl 1;
       End; {FOR i}
      UNTIL keypressed;
    End; {Loop}
99:
  End; {mil_timeout_bit}

 PROCEDURE  mil_reset;
  Begin
   ini_test_win;
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
  ini_test_win;
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
  ini_test_win;
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
  ini_test_win;
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
    ini_test_win;
    GotoXY(5, 22);
    write ('Welchen READ-Function-Code ??');
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := ask_hex_byte;
    ini_test_win;

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
    ini_test_win;
    GotoXY(5, 22);
    write ('Welchen Function-Code ??');
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := ask_hex_byte;
    ini_test_win;

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
    ini_test_win;
    GotoXY(5, 22);
    write ('Welchen Write-Function-Code ??');
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := ask_hex_byte;
    ini_test_win;

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
    ini_test_win;
    transf_cnt := 0;
    error_cnt := 0;
    timout_wr := 0; timout_rd := 0;
    Fct.B.Adr := Ifc_Test_Nr;

    GotoXY(5, 22);
    write ('Welchen Write-Function-Code ??');
    wr_fct_code := ask_hex_byte;
    ini_test_win;

    GotoXY(5, 22);
    write ('Welchen Read-Function-Code  ??');
    rd_fct_code := ask_hex_byte;
    ini_test_win;
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
       show_stat_reg;
       Transf_Cnt := Transf_Cnt + 1;
       for I := 1 to 10000 do;                              {Slowdown display}
     until KeyPressed or (Key = ' ');
     Single_Loop(Key);
   until Key in ['x','X'];
1:
   PORTW [Port_Intr] := 0; {Interrupts wieder lîschen}
 end; {MIL_Set_Intr;  }

Procedure Mil_Hf_SwAmpl (Test_Data: Word);
  LABEL 99;
  CONST HF_Fct = $06;

   VAR
     Bit16_Strg: Str19;
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;
     write_data : Word;

  begin
   Ini_Text_Win;
   Ch := ' ';
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct :=  HF_Fct;

   {Init Display}
   GotoXY(08,10);  Write('Transfer-Count: ');
   GotoXY(08,11);  Write('Timeout       : ');
   GotoXY(08,12);  Write('Funktion [Hex]: ');
   GotoXY(33,12);  Write(Hex_Byte(Fct.B.Fct));
   GotoXY(08,13);  Write('Data     [Hex]: ');


   Ini_Msg_Win;
   Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,10);  Write(Transf_Cnt:10);

      write_data := 0;
      Mil.Wr (write_data, Fct, MilErr);
      if MilErr <> No_err then
       begin
        Timout_Wr:= Timout_Wr +1;
        GotoXY(25,11);  write(timout_wr:10);
       end;
      GotoXY(25,11);  write(timout_wr:10);
      GotoXY(31,13);  write(hex_word(write_data));

      Mil.Timer2_Set(Wait_Test);
      repeat until Mil.Timeout2;

      write_data := Test_Data;
      Mil.Wr (write_data, Fct, MilErr);
      if MilErr <> No_err then
       begin
        Timout_Wr:= Timout_Wr +1;
        GotoXY(25,11);  write(timout_wr:10);
       end;
      GotoXY(25,11);  write(timout_wr:10);
      GotoXY(31,13);  write(hex_word(write_data));

      Mil.Timer2_Set(Wait_Test);
      repeat until Mil.Timeout2;

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
End; {Mil_Hf_SwAmpl}


Procedure Mil_Hf_SwPhas (Test_Data: Word);
  LABEL 99;
  CONST HF_Fct = $07;
  VAR
     Bit16_Strg: Str19;
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;
     write_data : Word;

  begin
   Ini_Text_Win;
   Ch := ' ';
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct :=  HF_Fct;

   {Init Display}
   GotoXY(08,10);  Write('Transfer-Count: ');
   GotoXY(08,11);  Write('Timeout       : ');
   GotoXY(08,12);  Write('Funktion [Hex]: ');
   GotoXY(33,12);  Write(Hex_Byte(Fct.B.Fct));
   GotoXY(08,13);  Write('Data     [Hex]: ');


   Ini_Msg_Win;
   Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,10);  Write(Transf_Cnt:10);

      write_data := 0;
      Mil.Wr (write_data, Fct, MilErr);
      if MilErr <> No_err then
       begin
        Timout_Wr:= Timout_Wr +1;
        GotoXY(25,11);  write(timout_wr:10);
       end;
      GotoXY(25,11);  write(timout_wr:10);
      GotoXY(31,13);  write(hex_word(write_data));

      Mil.Timer2_Set(Wait_Test);
      repeat until Mil.Timeout2;

      write_data := Test_Data;
      Mil.Wr (write_data, Fct, MilErr);
      if MilErr <> No_err then
       begin
        Timout_Wr:= Timout_Wr +1;
        GotoXY(25,11);  write(timout_wr:10);
       end;
      GotoXY(25,11);  write(timout_wr:10);
      GotoXY(31,13);  write(hex_word(write_data));

      Mil.Timer2_Set(Wait_Test);
      repeat until Mil.Timeout2;

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
End; {Mil_Hf_SwPha}

Procedure Mil_Hf_PhasLeft;
  LABEL 99;
  CONST HF_Fct_Left = $17;
        HF_Fct_Stop = $19;
  VAR
     Bit16_Strg: Str19;
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;

  begin
   Ini_Text_Win;
   Ch := ' ';
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := HF_Fct_Left;

   {Init Display}
   GotoXY(08,10);  Write('Transfer-Count: ');
   GotoXY(08,11);  Write('Timeout       : ');
   GotoXY(08,12);  Write('Funktion [Hex]: ');
   GotoXY(33,12);  Write(Hex_Byte(HF_Fct_Left));
   GotoXY(08,13);  Write('Funktion [Hex]: ');
   GotoXY(33,13);  Write(Hex_Byte(HF_Fct_Stop));

   Ini_Msg_Win;
   Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,10);  Write(Transf_Cnt:10);

      Fct.B.Fct := HF_Fct_Left;
      Mil.WrFct (Fct, MilErr);      if MilErr <> No_err then
       begin
        Timout_Wr:= Timout_Wr +1;
        GotoXY(25,11);  write(timout_wr:10);
       end;
      GotoXY(25,11);  write(timout_wr:10);

      Mil.Timer2_Set(Wait_Test);
      repeat until Mil.Timeout2;

      Fct.B.Fct := HF_Fct_Stop;
      Mil.WrFct (Fct, MilErr);      if MilErr <> No_err then
      if MilErr <> No_err then
       begin
        Timout_Wr:= Timout_Wr +1;
        GotoXY(25,11);  write(timout_wr:10);
       end;
      GotoXY(25,11);  write(timout_wr:10);

      Mil.Timer2_Set(Wait_Test);
      repeat until Mil.Timeout2;
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
End; {Mil_Hf_PhasLeft}

Procedure Mil_Hf_PhasRight;
  LABEL 99;
  CONST HF_Fct_Right = $18;
        HF_Fct_Stop  = $19;
  VAR
     Bit16_Strg: Str19;
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;

  begin
   Ini_Text_Win;
   Ch := ' ';
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := HF_Fct_Right;

   {Init Display}
   GotoXY(08,10);  Write('Transfer-Count: ');
   GotoXY(08,11);  Write('Timeout       : ');
   GotoXY(08,12);  Write('Funktion [Hex]: ');
   GotoXY(33,12);  Write(Hex_Byte(HF_Fct_Right));
   GotoXY(08,13);  Write('Funktion [Hex]: ');
   GotoXY(33,13);  Write(Hex_Byte(HF_Fct_Stop));

   Ini_Msg_Win;
   Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,10);  Write(Transf_Cnt:10);
      Fct.B.Fct := HF_Fct_Right;
      Mil.WrFct (Fct, MilErr);      if MilErr <> No_err then
       begin
        Timout_Wr:= Timout_Wr +1;
        GotoXY(25,11);  write(timout_wr:10);
       end;
      GotoXY(25,11);  write(timout_wr:10);

      Mil.Timer2_Set(Wait_Test);
      repeat until Mil.Timeout2;

      Fct.B.Fct := HF_Fct_Stop;
      Mil.WrFct (Fct, MilErr);      if MilErr <> No_err then
      if MilErr <> No_err then
       begin
        Timout_Wr:= Timout_Wr +1;
        GotoXY(25,11);  write(timout_wr:10);
       end;
      GotoXY(25,11);  write(timout_wr:10);

      Mil.Timer2_Set(Wait_Test);
      repeat until Mil.Timeout2;
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
End; {Mil_Hf_PhasLeft}


Procedure Mil_Hf_WrSwAmpl (Test_Data: Word);
  LABEL 99;
  CONST HF_Fct = $06;

  VAR
     Bit16_Strg: Str19;
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;
     write_data : Word;

  begin
   Ini_Text_Win;
   Ch := ' ';
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct :=  HF_Fct;

   {Init Display}
   GotoXY(08,10);  Write('Transfer-Count: ');
   GotoXY(08,11);  Write('Timeout       : ');
   GotoXY(08,12);  Write('Funktion [Hex]: ');
   GotoXY(33,12);  Write(Hex_Byte(Fct.B.Fct));
   GotoXY(08,13);  Write('Data     [Hex]: ');

   GotoXY(08,14);  write('Data     [BIN]:');
   GotoXY(25,15);  write('MSB             LSB');
{
   GotoXY(31,13);  write(hex_word(Test_Data));
   Hex_Bin_Str (Test_data,bit16_str);
   GotoXY(25, 14);  write(bit16_str);
}
   { PrÅfe, ob Strahl oder Pause. Falls Strahl, User nochmals fragen,
     da UNILAC-Betrieb gestîrt werden kann!!!
   }

   Ini_Err_Win;
   Write('Achtung! Soll Sender in Strahl? Kann Betrieb stîren!! Weiter [J/N]?: ');
   repeat until KeyPressed;
   Ch := ReadKey;
   if (Ch in ['j','J']) then
    begin                             {in Strahl}
     Test_Data:= Test_Data or $8000;
     if BitTst (Test_Data,15) then
      begin
       Ini_Err_Win;
       Write('Vorsicht: Bit 15 = Sender in Strahl. Kann Betrieb stîren!! Weiter [J/N]?: ');
       repeat until KeyPressed;
       Ch := ReadKey;
       if not (Ch in ['j','J']) then Test_Data := Test_Data and $7FFF;
      end;
    end
   else
    begin                             {nicht in Strahl}
     Test_Data := Test_Data and $7FFF;
    end;

   Set_Text_Win;
   GotoXY(31,13);  write(hex_word(Test_Data));
   Hex_Bin_Str (Test_data,bit16_str);
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

      write_data := Test_Data;
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
End; {Mil_Hf_WrSwAmpl}


Procedure Mil_Hf_WrSwPhas (Test_Data: Word);
  LABEL 99;
  CONST HF_Fct = $07;

   VAR
     Bit16_Strg: Str19;
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;
     write_data : Word;

  begin
   Ini_Text_Win;
   Ch := ' ';
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct :=  HF_Fct;

   {Init Display}
   GotoXY(08,10);  Write('Transfer-Count: ');
   GotoXY(08,11);  Write('Timeout       : ');
   GotoXY(08,12);  Write('Funktion [Hex]: ');
   GotoXY(33,12);  Write(Hex_Byte(Fct.B.Fct));
   GotoXY(08,13);  Write('Data     [Hex]: ');

   GotoXY(08,14);  write('Data     [BIN]:');
   GotoXY(25,15);  write('MSB             LSB');
   GotoXY(31,13);  write(hex_word(Test_Data));
   Hex_Bin_Str (Test_data,bit16_str);
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

      write_data := Test_Data;
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
End; {Mil_Hf_WrSwPhas}

Procedure Mil_Hf_StatC0;
  LABEL 99;
  CONST HF_Fct_C0 = $C0;

  VAR
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;

 PROCEDURE Displ_C0_Stat;
  Begin
     {Info-Anzeige der Bit-Belegung IFC-Status}
      ini_info_win;
      writeln('Bit 15: Ampl. Fehler  1-aktiv ');
      writeln('Bit 14: Ext. Interl.  0-aktiv ');
      writeln('Bit 13: Tank Resonanz 1-aktiv ');
      writeln('Bit 12: UG2 Endstufe  1-aktiv ');
      writeln('Bit 11: UG2 Treiber   1-aktiv ');
      writeln('Bit 10: HF-Ein        1-aktiv ');
      writeln('Bit 09: Phasen Fehler 1-aktiv ');
      writeln('Bit 08: Hand/Rechner  1-Rechnr');
      writeln;
      writeln('Bit 07: A7 IFC-Adr            ');
      writeln(' "  |   |    "                ');
      write  ('Bit 00: A0 IFC-Adr            ');
   End; {displ_ifc_stat}



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
   GotoXY(08,10);  Write('Transfer-Count: ');
   GotoXY(08,11);  Write('Timeout       : ');
   GotoXY(08,12);  Write('Funktion [Hex]: ');
   GotoXY(33,12);  Write(Hex_Byte(HF_Fct_C0));
   GotoXY(08,13);  Write('Data     [Hex]: ');
   GotoXY(08,14);  write('Stat-Data[BIN]:');
   GotoXY(25,15);  write('MSB             LSB');
   GotoXY(25,10);  Write(Transf_Cnt:10);
   GotoXY(25,11);  write(timout_rd:10);

   Displ_C0_Stat;
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
End; {Mil_Hf_StatC0}

procedure Mil_Hf_Istw;
  LABEL 99;
  CONST HF_Fct_RdIw = $84;

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
   Fct.B.Fct := HF_Fct_RdIw;

   GotoXY(25, 6);
   write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
   GotoXY(06,11); writeln('Rd_Data_Cnt  :');
   GotoXY(26,12); writeln('^  ^');
   GotoXY(06,12); writeln('Timeout_Count: ');
   GotoXY(22,12); writeln(timout_cnt:12);

   GotoXY(06,16); writeln('MIL-DATA');
   GotoXY(12,17); writeln('[Hex]:');
   GotoXY(12,18); writeln('[Bin]:');
   GotoXY(22,19); writeln('MSB             LSB');
   GotoXY(11,20); Writeln('[Volt]:');
   GotoXY(22,11); write(transf_cnt:12);

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
      GotoXY(22,12); write(timout_cnt:12);

      Read_Data := Get_Dta;
      IF rd_timeout THEN
        Begin
         GotoXY(28, 17);  write('    ');
         GotoXY(22, 18);  write('                   ');
         timout_cnt := timout_cnt + 1;
        End
      else
        begin
         Read_Data := Read_Data and $7FFF;
         GotoXY(28, 17);  write(hex_word(read_data));
         Hex_Bin_Str (read_data,bit16_str);
         GotoXY(22, 18);  write(bit16_str);
         GotoXY(25, 20);  Write_Real_10 (Read_Data);
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
End; {Mil_Hf_Istw}

procedure Mil_Hf_Cmd;
 label 99;
 VAR
      MilErr : TMilErr;
      Fct    : TFct;

 PROCEDURE Displ_Cmd_Codes;
  Begin
     {Info-Anzeige der Bit-Belegung IFC-Status}
      ini_info_win;
      writeln('+------ Function-Codes ------+');
      writeln('                              ');
      writeln('                              ');
      writeln('                              ');
      writeln(' 19: Phasen-Schieber Stop     ');
      writeln(' 18: Phasen-Schieber Rechts   ');
      writeln(' 17: Phasen-Schieber Links    ');
      writeln(' 16: Quittieren Stîrung       ');
      writeln(' 15: HF Aus                   ');
      writeln(' 14: HF Ein                   ');
      writeln(' 03: Generator Aus            ');
      write  (' 02: Generator Ein            ');
   End; {displ_ifc_stat}

   Begin
    ini_test_win;
    Displ_Cmd_Codes;
    Set_Text_win;
    GotoXY(5, 22);  write ('Welchen Function-Code ??');

    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := ask_hex_byte;
    transf_cnt:= 0;
    ini_test_win;

    GotoXY(20, 8);
    write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
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
End; {Mil_Hf_Cmd}

Procedure Mil_Hf_WrSwAnalog;
  LABEL 99;
  CONST HF_Fct = $06;

  VAR
     Bit16_Strg: Str19;
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;
     write_data,Displ_Data : Word;

  begin
   Ini_Text_Win;
   write_data := Rd_Real_10;
   {Shiften wird jetzt per Hardware gemacht, da Sollwert nur 10 bit,}
   {aber Rd_Real_10 auf 15 Bit + Vorz. normiert}
   { Write_Data := Write_Data shr 5; }
   Ini_Text_Win;

   Ch := ' ';
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct :=  HF_Fct;

   {Init Display}
   GotoXY(08,06);  Write('In diesem Test ist Amplituden-SW  Bit15 = 1 --> Strahl!');
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

   { PrÅfe, ob Strahl oder Pause. Falls Strahl, User nochmals fragen,
     da UNILAC-Betrieb gestîrt werden kann!!!}

   Ini_Err_Win;
   Write('Achtung! Soll Sender in Strahl? Kann Betrieb stîren!! Weiter [J/N]?: ');
   repeat until KeyPressed;
   Ch := ReadKey;
   if (Ch in ['j','J']) then
    begin                             {in Strahl}
     Write_Data:= Write_Data or $8000;
     if BitTst (Write_Data,15) then
      begin
       Ini_Err_Win;
       Write('Vorsicht: Bit 15 = Sender in Strahl. Kann Betrieb stîren!! Weiter [J/N]?: ');
       repeat until KeyPressed;
       Ch := ReadKey;
       if not (Ch in ['j','J']) then Write_Data := Write_Data and $7FFF;
      end;
    end
   else
    begin                             {nicht in Strahl}
     Write_Data := Write_Data and $7FFF;
    end;

   Set_Text_Win;
   GotoXY(28,17);  Write_Real_10 (Displ_Data);
   GotoXY(31,13);  write(hex_word(Write_Data));
   Hex_Bin_Str (Write_data,bit16_str);
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
End; {Mil_Hf_WrSwAnalog}

procedure Mil_Hf_WrPhAnalog;
 label 99;
 type TPhas = record
               Code: Word;
               Text: string[3];
              end;

 CONST HF_Fct = $07;   {Phasensollwert}
 Phas_Code_Ary :  array [1..12] of TPhas =        {Bit 0 =  0 }
                   ((Code: $05; Text: '  0'),     {Bit 1= 180 }
                    (Code: $09; Text: ' 30'),     {Bit 2 =  0 }
                    (Code: $11; Text: ' 60'),     {Bit 3 = 30 }
                    (Code: $21; Text: ' 90'),     {Bit 4 = 60 }
                    (Code: $41; Text: '120'),     {Bit 5 = 90 }
                    (Code: $81; Text: '150'),     {Bit 6 =120 }
                    (Code: $06; Text: '180'),     {Bit 7 =150 }
                    (Code: $0A; Text: '210'),
                    (Code: $12; Text: '240'),
                    (Code: $22; Text: '270'),
                    (Code: $42; Text: '300'),
                    (Code: $82; Text: '330')
                   );
 VAR
      MilErr : TMilErr;
      Fct    : TFct;
      I      : Byte;
      Status : Boolean;

 PROCEDURE Displ_Phas_Codes;
  Begin
     {Info-Anzeige der Bit-Belegung IFC-Status}
      ini_info_win;
      writeln('+------ Sollwert Phase ------+');
      writeln(' 12: Phase 330 (180 + 150)    ');
      writeln(' 11: Phase 300 (180 + 120)    ');
      writeln(' 10: Phase 270 (180 +  90)    ');
      writeln('  9: Phase 240 (180 +  60)    ');
      writeln('  8: Phase 210 (180 +  30)    ');
      writeln('  7: Phase 180 (180 +   0)    ');
      writeln('  6: Phase 150                ');
      writeln('  5: Phase 120                ');
      writeln('  4: Phase  90                ');
      writeln('  3: Phase  60                ');
      writeln('  2: Phase  30                ');
      write  ('  1: Phase   0                ');
   End; {displ_Phas_Codes}

   Begin
    ini_test_win;
    Displ_Phas_Codes;

  status := False;
  while not status do
   begin
    ini_msg_win;
    write   ('--> Welche Nr. fÅr Phasen-Einstellung: '); readln(I);
    if not I in [1..12] then
     begin
      ini_err_win;
      write('ERROR: Sorry, USER: das war keine Nr 1..12 !  Weiter mit <CR>');
      ReadKey;
     end
    else
     Status := True;
   end; {while}

   Write_Data := Phas_Code_Ary[I].Code;
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := HF_Fct;
   transf_cnt:= 0;
   ini_test_win;

   GotoXY(20, 8);
   write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
   GotoXY(6, 11); writeln('Wr_Fct_Cnt :');
   GotoXY(29,12); writeln('^  ^');
   GotoXY(08,13);  Write('Data     [Hex]: ');
   GotoXY(31,13);  write(hex_word(Write_Data));

   GotoXY(08,14);  write('Data     [BIN]:');
   GotoXY(25,15);  write('MSB             LSB');
   GotoXY(08,17);  write('Phase   [Grad]:');
   GotoXY(28,17);  Write(Phas_Code_Ary[I].Text);
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
      GotoXY(25,11);  Write(Transf_Cnt:10);
      Mil.Wr (Write_Data, Fct, MilErr);
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
End; {Mil_Hf_WrPhAnalog}

Procedure Mil_Hf_WrSwAmpl_Shift; {Sollwert bitweise schieben, Start mit 0}
  LABEL 99;                      {Bit 14..05 = 10 Bit; Bit 15= Strahl/Pause=0}
  CONST HF_Fct = $06;

  VAR
     Bit16_Strg: Str19;
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;
     write_data : Word;
     Test_Data  : Word;

  begin
   Ini_Text_Win;
   Ch := ' ';
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct :=  HF_Fct;

   GotoXY(05,06);  Write('Sollwert Amplitude: Bitweises Schieben, Sender nur in PAUSE [Bit 15=0] !!');
   GotoXY(35,07);  Write('[Bits 14..05]');

   {Init Display}
   GotoXY(08,10);  Write('Transfer-Count: ');
   GotoXY(08,11);  Write('Timeout       : ');
   GotoXY(08,12);  Write('Funktion [Hex]: ');
   GotoXY(33,12);  Write(Hex_Byte(Fct.B.Fct));
   GotoXY(08,13);  Write('Data     [Hex]: ');

   GotoXY(08,14);  write('Data     [BIN]:');
   GotoXY(25,15);  write('MSB             LSB');

   { PrÅfe, ob Strahl oder Pause. Falls Strahl, User nochmals fragen,
     da UNILAC-Betrieb gestîrt werden kann!!! }
   Test_Data := 0;
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
      GotoXY(31,13);  write(hex_word(Test_Data));
      Hex_Bin_Str (Test_data,bit16_str);
      GotoXY(25, 14);  write(bit16_str);

      write_data := Test_Data;
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
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> , [S]hift Bit,  Ende mit [X]');
       repeat until KeyPressed;
      end;

    Ch := ReadKey;
    if Ch in ['s','S'] then
      begin
       repeat
         case Test_Data of
               0 : Test_Data := $20;
           $4000 : Test_Data := 0;              {max.Bit 14..05 = 10 Bit shiften}
         else
           Test_Data := Test_Data shl 1;
         end;

         Set_Text_Win;
         GotoXY(31,13);  writeln(hex_word(Test_Data));
         Hex_Bin_Str (Test_data,bit16_str);
         GotoXY(25, 14);  writeln(bit16_str);

         write_data := Test_Data;
         Mil.Wr (write_data, Fct, MilErr);
         if MilErr <> No_err then
          begin
           Timout_Wr:= Timout_Wr +1;
           GotoXY(25,11);  write(timout_wr:10);
          end;
         GotoXY(25,11);  write(timout_wr:10);

         Ini_Msg_Win;
         Write('Stop/Single Step mit <SPACE>, Loop mit <CR> , [S]hift Bit,  Ende mit [X]');
         repeat until KeyPressed;
         Ch := ReadKey;
       until (Ch =' ') or  (Ch in ['x','X']);
      end; {if s}
   until Ch in ['x','X'];
99:
End; {Mil_Hf_WrSwAmpl_Shift}


Procedure Mil_Hf_WrSwPhas_Shift;
  LABEL 99;
  CONST HF_Fct = $07;

   VAR
     Bit16_Strg: Str19;
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;
     write_data : Word;
     Test_Data  : Word;

  begin
   Ini_Text_Win;
   Ch := ' ';
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct :=  HF_Fct;

   {Init Display}
   GotoXY(25,06);  Write('Sollwert Phase: Bitweises Schieben !!');
   GotoXY(35,07);  Write('[Bits 09..00]');
   GotoXY(08,10);  Write('Transfer-Count: ');
   GotoXY(08,11);  Write('Timeout       : ');
   GotoXY(08,12);  Write('Funktion [Hex]: ');
   GotoXY(33,12);  Write(Hex_Byte(Fct.B.Fct));
   GotoXY(08,13);  Write('Data     [Hex]: ');

   GotoXY(08,14);  write('Data     [BIN]:');
   GotoXY(25,15);  write('MSB             LSB');

   Test_Data := 0;
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
      GotoXY(31,13);  write(hex_word(Test_Data));
      Hex_Bin_Str (Test_data,bit16_str);
      GotoXY(25, 14);  write(bit16_str);

      write_data := Test_Data;
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
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> , [S]hift Bit,  Ende mit [X]');
       repeat until KeyPressed;
      end;
    Ch := ReadKey;
    if Ch in ['s','S'] then
      begin
       repeat
         case Test_Data of
             0 : Test_Data := 1;
          $200 : Test_Data := 0;              {max.Bit 09..00 = 10 Bit shiften}
          else
           Test_Data := Test_Data shl 1;
         end;

         Set_Text_Win;
         GotoXY(31,13);  writeln(hex_word(Test_Data));
         Hex_Bin_Str (Test_data,bit16_str);
         GotoXY(25, 14);  writeln(bit16_str);

         write_data := Test_Data;
         Mil.Wr (write_data, Fct, MilErr);
         if MilErr <> No_err then
          begin
           Timout_Wr:= Timout_Wr +1;
           GotoXY(25,11);  write(timout_wr:10);
          end;
         GotoXY(25,11);  write(timout_wr:10);

         Ini_Msg_Win;
         Write('Stop/Single Step mit <SPACE>, Loop mit <CR> , [S]hift Bit,  Ende mit [X]');
         repeat until KeyPressed;
         Ch := ReadKey;
       until (Ch =' ') or  (Ch in ['x','X']);
      end; {if s}
    until Ch in ['x','X'];
99:
End; {Mil_Hf_WrSwPhas_Shift}


BEGIN   { Hauptprogramm }
  Ifc_Test_Nr := 0;

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
                      IF check_ifc_adr THEN mil_rd_ifc_stat;
                      End;
     '3', 'd', 'D' : Begin
 		       IF check_ifc_adr THEN mil_rd_data;
                     End;
     '4','e', 'E' :  Begin
		       IF check_ifc_adr THEN mil_wr_fctcode;
		     End;
     '5', 'f', 'F' : Begin
		       IF check_ifc_adr THEN
			 Begin
			  mil_data := ask_data;
			  mil_wr(mil_data);
 			 End;
		     End;
     '6', 'g', 'G' : Begin
                       IF check_ifc_adr THEN
                        Begin
                         mil_data := ask_data;
                         mil_wr_rd(mil_data);
                        End;
 		     End;
     '7', 'h', 'H' : Begin
                     End;
          'i', 'I' : Begin
                       IF check_ifc_adr THEN Mil_Hf_StatC0;
                     End;
          'j', 'J' : Begin
 		       IF check_ifc_adr THEN Mil_Hf_Istw;
                     End;
          'k', 'K' : Begin
                       IF check_ifc_adr THEN Mil_Hf_WrSwAnalog;
                     End;
          'l', 'L' : Begin
                       IF check_ifc_adr THEN Mil_Hf_WrPhAnalog;
                     End;
          'm', 'M' : Begin
 		       IF check_ifc_adr THEN Mil_Hf_Cmd;;
                     End;
          'n', 'N' : Begin
                     End;
          'o', 'O' : Begin
                      IF check_ifc_adr then
                       begin
                        if Ask_Sw_BitShift then
                         begin
                          Mil_Hf_WrSwAmpl_Shift;
                         end
                        else
                         begin
                          mil_data := ask_data;
                          Mil_Hf_WrSwAmpl (mil_data);
                         end;
                       end;
                     End;
          'p', 'P' : Begin
                      IF check_ifc_adr then
                       begin
                        if Ask_Sw_BitShift then
                         begin
                          Mil_Hf_WrSwPhas_Shift;
                         end
                        else
                         begin
                          mil_data := ask_data;
                          Mil_Hf_WrSwPhas (mil_data);
                         end;
                       end;
                      End;
          'q', 'Q' : Begin
                       IF check_ifc_adr THEN
                        begin
                         mil_data := MIL_Hf_ask_data;
                         Mil_Hf_SwAmpl (mil_data);
                        end;
                     End;
          'r', 'R' : Begin
                       IF check_ifc_adr THEN
                        begin
                         mil_data := ask_data;
                         Mil_Hf_SwPhas (mil_data);
                        end;
                     End;
          's', 'S' : Begin
                       IF check_ifc_adr THEN Mil_Hf_PhasLeft;
                     End;
          't', 'T' : Begin
                       IF check_ifc_adr THEN Mil_Hf_PhasRight;
                     End;
    End; {CASE}
  UNTIL user_input in ['x','X'];
  Window(1, 1, 80, 25);
  TextBackground(Black);
  ClrScr;
END. {mil_pc}
