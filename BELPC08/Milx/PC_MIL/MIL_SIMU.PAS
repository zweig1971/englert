PROGRAM mil_simu;   { Programm MIL_SIMU.PAS mit OOP-Unit MIL_LIB.TPU}
{ G. Englert
  31.08.93 IFC-Simulator fÅr EQM-Software-Entwicklung (MIL-SLAVE)

  Achtung: FÅr Laborumgebung kann die Standard-PC-Interface Karte
           benutzt werden, bei der die Signale INTRL, DREQ, DRDY nicht
           galvanisch entkoppelt sind.
           Am Beschleuniger mu· die Optokoppler-Version verwendet werden!

  UrsprÅnglich fÅr Turbo-Pascal Version 5.5 geschrieben.
  29.10.93: Dieses Programm wurde auf Turbo-Pascal Version 7.0 umgestellt.
  Da die Window-Routinen in dieser Version nicht kompatibel mit der
  Version 5.5 sind, mu·ten einige énderungen vorgenommen werden:
  Neu ist: der Bildschirm ist in 3 Windows eingeteilt (s. a. ini_headl_win,
  ini_text_win und ini_msg_win). In jedem Window sind Grî·e, Hintergrund-
  Farbe und Schriftfarbe definiert, die der Anwender geÑndern darf.
}

{$S-}
uses Crt, WinDos, Mil_Lib, SysHlp;

CONST
 head_line =
      'Datentechnik                      MIL-PC     ' +
      '                       [29.10.1993]'+
      '                Simulator fÅr MIL-Bus-GerÑte (Turbo-Pascal V7.0';

 msg_single_step =
      'Loop- u. Single-Test mit [Q] beenden!    Single-Step mit [SPACE] ';

 stat_cnt_out  = $200;
 stat_cmd_rcv  = $100;
 stat_cmd_mode = $80;
 stat_ffo_ful  = $40;
 stat_ffo_ety  = $20;
 stat_val_wrd  = $10;
 stat_wrt_rdy  = $08;
 stat_dta_req  = $04;
 stat_dta_rdy  = $02;
 stat_intlock  = $01;

 valid_cmd_mask = $110;   {Kombination von valid word und cmd-rcv}

 ifc_irmask_all  = $E000; {Interrupt Enable Maske auf der IFC-Karte}
 ifc_irmask_intl = $8000;
 ifc_irmask_drdy = $4000;
 ifc_irmask_dreq = $2000;

 ifc_stat_dreq   = $400;
 ifc_stat_drdy   = $800;
 ifc_stat_intl   = $1000;


 fct_ifc_reset    = $01;
 fct_set_soll1    = $06;
 fct_ifc_wait     = $0E;
 fct_ifc_release  = $0F;
 fct_set_intr_mask= $12;
 fct_rd_ist1      = $81;
 fct_read_status  = $C9;


TYPE
 str4    = STRING[4];
 num_str = STRING[10];

VAR
 pcmil      : Tmil;          { Type OBJECT: In UNIT Mil deklariert!! }
 ifc_test_nr: BYTE;
 sim_c9_stat: WORD;
 sim_sollw_1: WORD;
 sim_istw_1 : WORD;

 mil_status   : WORD;
 fifo_save_n  : WORD;
 fifo_save_n_1: WORD;


 mil_data  : WORD;
 read_data : WORD;
 write_data: WORD;
 read_str  : str4;
 status    : BOOLEAN;
 time      : LONGINT;
 wr_timeout: BOOLEAN;
 rd_timeout: BOOLEAN;
 transf_cnt: LONGINT;
 timout_cnt: LONGINT;
 error_cnt : LONGINT;
 timout_rd : LONGINT;
 timout_wr : LONGINT;
 user_input: CHAR;
 ch        : CHAR;
 loop      : BOOLEAN;

 fct_code    : WORD;
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

  PROCEDURE ini_err_win;
   Begin
    Window(1, 25, 80, 25);
    TextBackground(Green);
    TextColor(Red);               {Setze Schriftfarbe}
    ClrScr;
   End;

  PROCEDURE ini_test_win;
   Begin
    ini_msg_win;
    write(msg_single_step);
    ini_text_win;
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
  GotoXY(12, 3);
  Writeln('*********************  TEST-MENUE  ********************* ');
  GotoXY(12, 4);
  Writeln('     +-- SINGLE --+                    +-- LOOP --+      ');
  GotoXY(12, 5);
  Writeln('[0]<-- Welche IFC am Bus?           Defin. IFC-Adr -->[A]');
  GotoXY(12, 6);
  Writeln('[1]<-- IFC-Status definieren                       -->[B]');
  GotoXY(12, 7);
  Writeln('[2]<--                                             -->[C]');
  GotoXY(12, 8);
  Writeln('[3]<--                                             -->[D]');
  GotoXY(12, 9);
  Writeln('[4]<--                                             -->[E]');
  GotoXY(12, 10);
  Writeln('[5]<--                                             -->[F]');
  GotoXY(12, 11);
  Writeln('[6]<--                                             -->[G]');
  GotoXY(12, 12);
  Writeln('[7]<--                                             -->[H]');
  GotoXY(12, 13);
  Writeln('[8]<--                                             -->[I]');
  GotoXY(12, 14);
  Writeln('[9]<--                                             -->[J]');
  GotoXY(12, 15);
  Writeln('            [K]<-- Reset PC-Interface                    ');
  GotoXY(12, 16);
  Writeln('            [L]<-- Parameter der IFC-Karte listen        ');
  GotoXY(12, 17);
  Writeln('            [M]<--                                       ');
  GotoXY(12, 18);
  Writeln('            [N]<--                                       ');
  GotoXY(12, 19);
  Writeln('            [O]<--                                       ');
  GotoXY(12, 20);
  Writeln('            [P]<-- Start der Simulation                  ');

  ini_msg_win;
  Write('                                                                 EXIT: X-Taste ');
  GotoXY(1,1);
  Write('Bitte Auswahl eingeben: ');
  answer := readkey;
  IF answer IN ['0'..'9','A'..'R','a'..'r','x','X'] THEN
   menue_win := answer;
 End; {menue_win}

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

  FUNCTION hex_byte(b: BYTE): num_str;
   CONST hex_num : STRING[16] = '0123456789ABCDEF';
  Begin
   hex_byte := hex_num[(b shr 4) + 1] + hex_num[(b AND $0F) + 1];
  End;

  FUNCTION hex_word(w: WORD): num_str;
   Begin
    hex_word := hex_byte(HI (w)) + hex_byte(LO (w));
   End; {hex_word}

  PROCEDURE mil_ask_ifc;
  VAR answer : CHAR;
  Begin
    status := FALSE;
    WHILE NOT status DO
     Begin
      ini_msg_win;
      write ('Welche IFC-Karten-Nr.(1..255) testen?: '); readln(ifc_test_nr);
      IF ifc_test_nr IN [1..255] THEN status 