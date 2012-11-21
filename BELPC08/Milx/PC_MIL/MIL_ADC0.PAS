PROGRAM mil_tst;   { Programm MIL_adc0.PAS mit OOP-Unit MIL.TPU}
{
  Tibor ADC-DAC-Tests mit OOP
}

{$S-}
uses Crt, Win, Mil,syshlp;

CONST
 datum_str     = '[23. Juni 1993]';
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

 fct_set_soll1   = $06;
 fct_set_soll2   = $07;
 fct_set_soll3   = $08;
 fct_set_soll4   = $09;

 fct_read_ist1   = $80;
 fct_read_ist2   = $81;
 fct_read_ist3   = $82;
 fct_read_ist4   = $83;

 fct_read_status = $C9;

 scale_null      = $0;     scale_null_str = '  0,000 00 V';
 scale_pos_full  = $7FFF;  scale_pos_str  = ' +9,999 60 V';
 scale_neg_full  = $8000;  scale_neg_str  = '-10,000 00 V';

 dac_set20  = $7FFF;  dac_str20 = '+ 9,999 60 V';
 dac_set19  = $7332;  dac_str19 = '+ 8,999 64 V';
 dac_set18  = $6665;  dac_str18 = '+ 7,999 68 V';
 dac_set17  = $5998;  dac_str17 = '+ 6,999 72 V';
 dac_set16  = $4CCC;  dac_str16 = '+ 5,999 76 V';
 dac_set15  = $3FFF;  dac_str15 = '+ 4,999 80 V';
 dac_set14  = $3332;  dac_str14 = '+ 3,999 84 V';
 dac_set13  = $2666;  dac_str13 = '+ 2,999 88 V';
 dac_set12  = $1999;  dac_str12 = '+ 1,999 92 V';
 dac_set11  = $0CCC;  dac_str11 = '  0,999 96 V';
 dac_set10  = $0000;  dac_str10 = '  0,000 00 V';
 dac_set9   = $F331;  dac_str9  = '- 1,000 00 V';
 dac_set8   = $E664;  dac_str8  = '- 2,000 00 V';
 dac_set7   = $D997;  dac_str7  = '- 3,000 00 V';
 dac_set6   = $CCCB;  dac_str6  = '- 4,000 00 V';
 dac_set5   = $BFFF;  dac_str5  = '- 5,000 00 V';
 dac_set4   = $B331;  dac_str4  = '- 6,000 00 V';
 dac_set3   = $A665;  dac_str3  = '- 7,000 00 V';
 dac_set2   = $9998;  dac_str2  = '- 8,000 00 V';
 dac_set1   = $8CCB;  dac_str1  = '- 9,000 00 V';
 dac_set0   = $8000;  dac_str0  = '-10,000 00 V';

TYPE
 str4    = STRING[4];
 num_str = STRING[10];

VAR
 pcmil     : Tmil;          { Type OBJECT: In UNIT Mil deklariert!! }

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
 timout_rd : LONGINT;
 timout_wr : LONGINT;
 user_input: CHAR;
 ch        : CHAR;
 loop      : BOOLEAN;

 scale     : BYTE;
 soll_activ: BYTE;
 sollwert  : WORD;
 ist_activ : BYTE;
 ifc_test_nr : BYTE;
 fct_code  : WORD;
 bit16_str : STRING[19];


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

  PROCEDURE ini_test_win;
   Begin
    CheckBreak := False;
    TextAttr := Black + LightGray * 16;
    Window(1, 2, 80, 24);
    FillWin(#178, {Magenta + Black * 16} red);
    Window(1, 1, 80, 25);
    GotoXY(1, 1);
    Write(' Datentechnik                      MIL-PC      '  +
          '                 ',datum_str);
    GotoXY(1, 25);
    Write(' Loop- u. Single-Test mit [Q] beenden!    Single-Step mit [SPACE] ');
    ClrEol;
   End;


PROCEDURE reset_win;
 Begin
  Window(1, 1, 80, 25);
  NormVideo;
  ClrScr;
 End;

FUNCTION ask_data: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    GotoXY(5, 22);
    write ('Fr die MIL-Transfer-Tests werden vom USER die WRITE-Daten ben”tigt!! ');
    GotoXY(5, 23);
    write   ('--> Bitte 4-stellige Hex-Daten eingeben: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
      writeln('ERROR: Sorry, VACLAV: das war keine 4-stell. Hexzahl!!');
   End; {WHILE}
  ask_data := in_data;
 End;



  PROCEDURE mil_set_soll (sollwert:WORD);
   Begin
    ini_test_win;
    CASE soll_activ OF
       1: fct_code := fct_set_soll1;
       2: fct_code := fct_set_soll2;
       3: fct_code := fct_set_soll3;
       4: fct_code := fct_set_soll4;
    End; {case}
    fct_code := fct_code * 256;             { ins HI-Byte }
    fct_code := fct_code + ifc_test_nr;     { icf_adr ins Lo-Byte }

    transf_cnt := 0;
    GotoXY(6, 9);
    writeln('Function-Code + IFC-Adr[H]: ',hex_word(fct_code));
    GotoXY(6, 11);
    writeln('Wr_Data_Cnt:');
    GotoXY(26,12);
    writeln('^  ^');
    GotoXY(6, 14);
    writeln('Write-Data[H]');
    GotoXY(28, 14);  write(hex_word(sollwert));

    IF loop THEN
    Begin
     REPEAT
      transf_cnt:= transf_cnt+ 1;
      GotoXY(20, 11);
      write(transf_cnt:12);
      pcmil.write_data(sollwert);
      pcmil.wr_fct_code(fct_code);
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
         pcmil.write_data(sollwert);
         pcmil.wr_fct_code(fct_code);
        End;
      UNTIL ch IN ['q','Q'];
    End; {Loop}
  End; {mil_set_soll}


 PROCEDURE mil_detect_ifc;
  CONST start_zeile = 5;

  VAR ifc_total  : WORD;
      ifb_online : ARRAY[1..255] OF BOOLEAN;
      ifb_adr    : WORD;
      zeile      : BYTE;
      hex_str    : STRING[10];
      i          : WORD;
  Begin
   ini_test_win;
   ifc_total := 0;
   GotoXY(1, 25); ClrEol;
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
   GotoXY(1, start_zeile - 2); ClrEol;
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
              GotoXY(1, 25); ClrEol;
              write('Mehr als 15 Karten!!    Any key to go on!');
              ch := READKEY;
              FOR zeile := start_zeile TO start_zeile + 16 DO
                Begin  GotoXY(1, zeile); ClrEol; End;
              zeile := start_zeile;
            End;
          zeile := zeile + 1;
         End;
     End;
   GotoXY(1, 25); ClrEol;
   write('IFC-Karten total: ',ifc_total,'     Any key to go on!');
   ch := READKEY;
  End; {detect_ifc}

FUNCTION menue_win: CHAR;
VAR answer: CHAR;
begin
  CheckBreak := False;
  TextAttr := Black + LightGray * 16;
  Window(1, 2, 80, 24);
  FillWin(#178, {Magenta + Black * 16} red);
  Window(1, 1, 80, 25);
  GotoXY(1, 1);
  Write(' Datentechnik                       MIL-PC   ' +
        '                  ',datum_str);
  ClrEol;
  GotoXY(20, 2);
  Writeln('        (FG 429.042   16-Bit DAC/ADC)      ');

  GotoXY(20, 4);
  Writeln('                TEST-MENUE                  ');
  GotoXY(20, 5);
  Writeln('                ==========                  ');
  GotoXY(12, 7);
  Writeln('     +-- SINGLE --+                    +-- LOOP --+      ');
  GotoXY(12, 8);
  Writeln('[1]<-- Welche IFC am Bus?           Defin. IFC-Adr -->[A]');
  GotoXY(12, 9);
  Writeln('[2]<--      Lesen PC MIL-Status (Interrupt usw.)   -->[B]');
  GotoXY(12, 10);
  Writeln('[3]<--             Setzen DAC (Sollwert)           -->[C]');
  GotoXY(12, 11);
  Writeln('[4]<--          Lesen/Abgleich ADC (Istwert)       -->[D]');
  GotoXY(12, 12);
  Writeln('[5]<--  DAC (Offset,+/-Gain)          Oszi-Ansicht -->[E]');
  GotoXY(12, 13);
  Writeln('[6]<--               Linearit„t DAC                -->[F]');
{  GotoXY(12, 16);
  Writeln('[7]<--                                             -->[G]');
  GotoXY(12, 17);
  Writeln('[8]<--                                             -->[H]');
}
  GotoXY(1, 25);
  Write('                                EXIT: X-Taste ');
  ClrEol;

  GotoXY(28, 20);
  Write(' Bitte Auswahl eingeben: '); answer := readkey;
  IF answer IN ['1'..'8','A'..'H','a'..'h','x','X'] THEN
   menue_win := answer;
 End; {menue_win}


  PROCEDURE mil_rd_status;
  VAR read_data : WORD;
   Begin
    ini_test_win;
    transf_cnt := 0;
    timout_cnt := 0;
    GotoXY(6, 11);
    writeln('Rd_Stat_Cnt:');
    GotoXY(26,12);
    writeln('^  ^');
    GotoXY(6, 14);
    writeln('Stat-Data[Hex]');
    GotoXY(6, 16);
    writeln('Stat-Data[Bin]');
    GotoXY(12, 17);  writeln('          MSB             LSB');

    IF loop THEN
    Begin
     REPEAT
     transf_cnt:= transf_cnt+ 1;
     GotoXY(20, 11);
     write(transf_cnt:12);
     read_data  := pcmil.rd_status;
     GotoXY(28, 14);  write(hex_word(read_data));
     hex_bin (read_data);
     GotoXY(22, 16);  write(bit16_str);
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
         read_data  := pcmil.rd_status;
         GotoXY(28, 14);  write(hex_word(read_data));
         hex_bin (read_data);
         GotoXY(22, 16);  write(bit16_str);
        End;
      UNTIL ch IN ['q','Q'];
    End; {Loop}
  End; {mil_rd_status}

  PROCEDURE mil_rd_ist;
  VAR read_data : WORD;
      read_status: WORD;

   Begin
    ini_test_win;
    transf_cnt := 0;
    GotoXY(6, 11);
    writeln('Rd_Data_Cnt:');
    GotoXY(29,12);
    writeln('^  ^');
    GotoXY(6, 14);
    writeln('Read-Data[Hex]');

    GotoXY(6, 16);
    writeln('Read-Data[Bin]');
    GotoXY(22, 17);  writeln('MSB             LSB');


    CASE ist_activ OF
       1: fct_code := fct_read_ist1;
       2: fct_code := fct_read_ist2;
       3: fct_code := fct_read_ist3;
       4: fct_code := fct_read_ist4;
    End; {case}
    fct_code := fct_code * 256;             { ins HI-Byte }
    fct_code := fct_code + ifc_test_nr;     { icf_adr ins Lo-Byte }

    transf_cnt := 0;
    GotoXY(6, 9);
    writeln('Function-Code + IFC-Adr[H]: ',hex_word(fct_code));

    IF loop THEN
    Begin
     REPEAT
      transf_cnt:= transf_cnt+ 1;
      GotoXY(23, 11);
      write(transf_cnt:12);
      pcmil.wr_fct_code(fct_code);
      read_data  := pcmil.read_data;
      GotoXY(31, 14);  write(hex_word(read_data));
      hex_bin (read_data);
      GotoXY(22, 16);  write(bit16_str);
     UNTIL keypressed;
    End
   ELSE
    Begin
      REPEAT
       ch := READKEY;
       IF ch = ' ' THEN
        Begin
         transf_cnt:= transf_cnt+ 1;
         GotoXY(23, 11);
         write(transf_cnt:12);
         pcmil.wr_fct_code(fct_code);
         read_data  := pcmil.read_data;
         GotoXY(31, 14);  write(hex_word(read_data));
         hex_bin (read_data);
         GotoXY(22, 16);  write(bit16_str);
        End;
      UNTIL ch IN ['q','Q'];
    End; {Loop}
  End; {mil_rd_ist}


Procedure mil_wr_rd (write_data: WORD);
  LABEL 99;
   CONST
    wr_fct_code = $0677; {Adr. 77, wr-fct 06}
    rd_fct_code = $8177; {Adr. 77, rd_fct 81}

   VAR
    i : WORD;
    error_cnt : LONGINT;

   Begin
    ini_test_win;
    transf_cnt := 0;
    error_cnt := 0;
    timout_wr := 0; timout_rd := 0;

    GotoXY(6, 8);
    write  ('IFC-Adr: 77           Wr-Fct-Code: 06[H]       Rd-Fct_Code: 81[H]');
    GotoXY(6, 11);
    writeln('Wr_Data_Cnt:              Write-Data[H]:                ');
    GotoXY(6, 14);
    writeln('Error_Count:              Read-Data [H]:                ');
    GotoXY(22,12);
    writeln('^  ^');
    GotoXY(22,15);
    writeln('^  ^');
    GotoXY(53,11);
    write('Timeout:');
    GotoXY(53,14);
    write('Timeout:');
    GotoXY(61, 14);
    write(timout_rd:10);
    GotoXY(61, 11);
    write(timout_wr:10);
    GotoXY(6, 14);

    IF loop THEN
    Begin
     REPEAT
        transf_cnt:= transf_cnt+ 1;
        GotoXY(18, 11);
        write(transf_cnt:10);

        wr_timeout := FALSE;
        pcmil.write_data(mil_data);
        IF pcmil.wr_timeout THEN
          Begin
           wr_timeout:= TRUE;
           timout_wr := timout_wr + 1;
           GotoXY(61, 11);
           write(timout_wr:10);
          End;

        GotoXY(47, 11);      write(hex_word(i));
        pcmil.wr_fct_code(wr_fct_code);
        pcmil.wr_fct_code(rd_fct_code);
        rd_timeout := FALSE;
        read_data := pcmil.read_data;
        IF pcmil.rd_timeout THEN
          Begin
           rd_timeout:= TRUE;
           timout_rd := timout_rd + 1;
           GotoXY(61, 14);
           write(timout_rd:10);
          End;

        GotoXY(47, 14);  write(hex_word(read_data));
        IF (NOT(wr_timeout OR rd_timeout)) AND (read_data <> i) THEN
         Begin
          error_cnt := error_cnt + 1;
          GotoXY(18, 14);
          write(error_cnt:10);
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
          GotoXY(18, 11);
          write(transf_cnt:10);
          wr_timeout := FALSE;

          pcmil.write_data(mil_data);
          IF pcmil.wr_timeout THEN
           Begin
            wr_timeout:= TRUE;
            timout_wr := timout_wr + 1;
            GotoXY(61, 11);
            write(timout_wr:10);
           End;

          GotoXY(47, 11);      write(hex_word(i));
          pcmil.wr_fct_code(wr_fct_code);
          pcmil.wr_fct_code(rd_fct_code);
          rd_timeout := FALSE;
          read_data := pcmil.read_data;
          IF pcmil.rd_timeout THEN
           Begin
            rd_timeout:= TRUE;
            timout_rd := timout_rd + 1;
            GotoXY(61, 14);
            write(timout_rd:10);
           End;

           GotoXY(47, 14);  write(hex_word(read_data));
           IF (NOT(wr_timeout OR rd_timeout)) AND (read_data <> i) THEN
              Begin
               error_cnt := error_cnt + 1;
               GotoXY(18, 14);
               write(error_cnt:10);
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
   CONST
    wr_fct_code = $0106; {Adr. 01, wr-fct 06}
    rd_fct_code = $0181; {Adr. 01, rd_fct 81}

   VAR
    i : WORD;
    error_cnt : LONGINT;

   Begin
    ini_test_win;
    transf_cnt := 0;
    error_cnt := 0;
    timout_wr := 0; timout_rd := 0;

    GotoXY(6, 8);
    write  ('IFC-Adr: 01           Wr-Fct-Code: 81[H]       Rd-Fct_Code: 06[H]');
    GotoXY(6, 11);
    writeln('Wr_Data_Cnt:              Write-Data[H]:                ');
    GotoXY(6, 14);
    writeln('Error_Count:              Read-Data [H]:                ');
    GotoXY(22,12);
    writeln('^  ^');
    GotoXY(22,15);
    writeln('^  ^');
    GotoXY(53,11);
    write('Timeout:');
    GotoXY(53,14);
    write('Timeout:');
    GotoXY(61, 14);
    write(timout_rd:10);
    GotoXY(61, 11);
    write(timout_wr:10);
    GotoXY(6, 14);

    IF loop THEN
    Begin
     REPEAT
      FOR i := 0 TO $FFFF DO
       Begin
        transf_cnt:= transf_cnt+ 1;
        GotoXY(18, 11);
        write(transf_cnt:10);

        wr_timeout := FALSE;
        pcmil.write_data (i);
        IF pcmil.wr_timeout THEN
          Begin
           wr_timeout:= TRUE;
           timout_wr := timout_wr + 1;
           GotoXY(61, 11);
           write(timout_wr:10);
          End;

        GotoXY(47, 11);      write(hex_word(i));
        pcmil.wr_fct_code(wr_fct_code);
        pcmil.wr_fct_code(rd_fct_code);
        rd_timeout := FALSE;
        read_data  := pcmil.read_data;
        IF pcmil.rd_timeout THEN
          Begin
           rd_timeout:= TRUE;
           timout_rd := timout_rd + 1;
           GotoXY(61, 14);
           write(timout_rd:10);
          End;

        GotoXY(47, 14);  write(hex_word(read_data));
        IF (NOT(wr_timeout OR rd_timeout)) AND (read_data <> i) THEN
         Begin
          error_cnt := error_cnt + 1;
          GotoXY(18, 14);
          write(error_cnt:10);
         End;
        IF keypressed THEN GOTO 99;
       End;
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
             GotoXY(18, 11);
             write(transf_cnt:10);
             wr_timeout := FALSE;
             pcmil.write_data (i);
             IF pcmil.wr_timeout THEN
              Begin
               wr_timeout:= TRUE;
               timout_wr := timout_wr + 1;
               GotoXY(61, 11);
               write(timout_wr:10);
              End;

             GotoXY(47, 11);      write(hex_word(i));
             pcmil.wr_fct_code(wr_fct_code);
             pcmil.wr_fct_code(rd_fct_code);
             rd_timeout := FALSE;
             read_data := pcmil.read_data;                      {Mil-Daten lesen}
             IF pcmil.rd_timeout THEN
              Begin
               rd_timeout:= TRUE;
               timout_rd := timout_rd + 1;
               GotoXY(61, 14);
               write(timout_rd:10);
              End;

             GotoXY(47, 14);  write(hex_word(read_data));
             IF (NOT(wr_timeout OR rd_timeout)) AND (read_data <> i) THEN
              Begin
               error_cnt := error_cnt + 1;
               GotoXY(18, 14);
               write(error_cnt:10);
              End;
            End
           ELSE
             Begin
              IF ch IN ['q','Q'] THEN GOTO 99;
             End; {IF ch}
          End;
    End; {Loop}
99:
  End; {ifc_loop}

  PROCEDURE mil_ask_ifc;
  Begin
    status := FALSE;
    WHILE NOT status DO
     Begin
      GotoXY(5, 22); clreol;
      write ('Welche IFC-Karten-Nr.(1..255) testen?: '); readln(ifc_test_nr);
      IF ifc_test_nr IN [1..255] THEN status := TRUE;
     End; {WHILE}
  End; {ask_ifc}

  FUNCTION check_ifc_adr: BOOLEAN;
  Begin
    check_ifc_adr := TRUE;
    IF  NOT (ifc_test_nr IN [1..255]) THEN
     Begin
      check_ifc_adr := FALSE;
      GotoXY(5, 22); clreol;
      write ('ABORT: IFC-Karten-Nr. undefiniert!!  Press any key to go on! '); ch := readkey;
     End;
  End; {check_ifc_adr}

 PROCEDURE ask_ist;
 Begin
   REPEAT
    GotoXY(1, 22); clreol;
    write ('Welche DAC/ADC-Karte 1..4 ->(Fct-Code) 1->(80H) 2->(81H) 3->(82H) 4=(83H)? ');
    readln(ist_activ);
   UNTIL ist_activ IN [1..4];
 End; {ask_ist}

 PROCEDURE ask_soll;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    REPEAT
     GotoXY(1, 22); clreol;
     write ('Welche DAC/ADC-Karte 1..4 ->(Fct-Code) 1->(06H) 2->(07H) 3->(08H) 4->(09H)? ');
     readln(soll_activ);
    UNTIL soll_activ IN [1..4];
    GotoXY(1, 23);
    write ('--> Bitte 16-Bit Daten [4-stellig Hex] eingeben: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
      writeln('ERROR: Sorry, TIBOR: Das war keine 4-stellige Hexzahl!!');
   End; {WHILE}
  sollwert := in_data;
 End; {ask_soll}


 PROCEDURE ask_soll_nr;
 Begin
    REPEAT
     GotoXY(1, 22); clreol;
     write ('Welche DAC/ADC-Karte 1..4 ->(Fct-Code) 1->(06H) 2->(07H) 3->(08H) 4->(09H)? ');
     readln(soll_activ);
    UNTIL soll_activ IN [1..4];
 End; {ask_scale}

 PROCEDURE ask_ist_nr;
 Begin
    REPEAT
     GotoXY(1, 22); clreol;
     write ('Welche DAC/ADC-Karte 1..4 ->(Fct-Code) 1->(80H) 2->(81H) 3->(82H) 4=(83H)? ');
     readln(soll_activ);
    UNTIL soll_activ IN [1..4];
 End; {ask_scale}


 PROCEDURE ask_soll_scale;
 Begin
    REPEAT
     GotoXY(1, 22); clreol;
     write ('Welchen Abgleichwert (1=Null, 2=Pos.FScale, 3=Neg.FScale)? '); readln(scale);
    UNTIL scale IN [1..3];

    REPEAT
     GotoXY(1, 22); clreol;
     write ('Welche DAC/ADC-Karte 1..4 ->(Fct-Code) 1->(06H) 2->(07H) 3->(08H) 4->(09H)? ');
     readln(soll_activ);
    UNTIL soll_activ IN [1..4];
 End; {ask_soll_scale}

PROCEDURE mil_abgleich;
VAR scale_str : STRING[12];
Begin
    ini_test_win;
    CASE soll_activ OF
       1: fct_code := fct_set_soll1;
       2: fct_code := fct_set_soll2;
       3: fct_code := fct_set_soll3;
       4: fct_code := fct_set_soll4;
    End; {case}
    fct_code := fct_code * 256;             { ins HI-Byte }
    fct_code := fct_code + ifc_test_nr;     { icf_adr ins Lo-Byte }

    transf_cnt := 0;
    GotoXY(6, 9);
    writeln('Function-Code + IFC-Adr[H]: ',hex_word(fct_code));
    GotoXY(6, 11);
    writeln('Wr_Data_Cnt:');
    GotoXY(26,12);
    writeln('^  ^');

    IF loop THEN
    Begin
     GotoXY(6, 14);
     writeln('Write-Data[H]');
     GotoXY(28, 14);  write(hex_word(scale_null));
     GotoXY(40, 14);  write(hex_word(scale_pos_full));
     GotoXY(54, 14);  write(hex_word(scale_neg_full));
     GotoXY(26, 15);  write(scale_null_str);
     GotoXY(40, 15);  write(scale_pos_str);
     GotoXY(54, 15);  write(scale_neg_str);

     REPEAT
      pcmil.write_data(scale_null);      { Abgleich auf Null }
      pcmil.wr_fct_code(fct_code);
      transf_cnt:= transf_cnt+ 1;

      pcmil.write_data(scale_pos_full);  { Abgleich auf pos. Fullscale }
      pcmil.wr_fct_code(fct_code);
      transf_cnt:= transf_cnt+ 1;

      pcmil.write_data(scale_neg_full);  { Abgleich auf pos. Fullscale }
      pcmil.wr_fct_code(fct_code);
      transf_cnt:= transf_cnt+ 1;

      GotoXY(20, 11);
      write(transf_cnt:12);
     UNTIL keypressed;
    End
   ELSE
    Begin
      CASE scale OF
       1: Begin sollwert := scale_null;     scale_str:= scale_null_str; End;
       2: Begin sollwert := scale_pos_full; scale_str:= scale_pos_str;  End;
       3: Begin sollwert := scale_neg_full; scale_str:= scale_neg_str;  End;
      End; {case}

      GotoXY(6, 14);
      writeln('Write-Data[H]');
      GotoXY(28, 14);  write(hex_word(sollwert));
      GotoXY(26, 15);  write(scale_str);

      REPEAT
        transf_cnt:= transf_cnt+ 1;
        GotoXY(20, 11);
        write(transf_cnt:12);
        pcmil.write_data(sollwert);
        pcmil.wr_fct_code(fct_code);
      UNTIL keypressed;
    End; {Loop}
  End; {mil_abgleich}

 PROCEDURE mil_dac_lin;
  VAR dac_lin : ARRAY [0..20] OF WORD;
      dac_str : ARRAY [0..20] OF STRING[13];
      dac_text: STRING[13];
      i       : BYTE;
      up      : BOOLEAN;

  PROCEDURE ini_dac_lin;
   Begin
     dac_lin[0] :=dac_set0;
     dac_lin[1] :=dac_set1;  dac_lin[2] :=dac_set2;  dac_lin[3]:=dac_set3;
     dac_lin[4] :=dac_set4;  dac_lin[5] :=dac_set5;  dac_lin[6]:=dac_set6;
     dac_lin[7] :=dac_set7;  dac_lin[8] :=dac_set8;  dac_lin[9]:=dac_set9;
     dac_lin[10]:=dac_set10; dac_lin[11]:=dac_set11; dac_lin[12]:=dac_set12;
     dac_lin[13]:=dac_set13; dac_lin[14]:=dac_set14; dac_lin[15]:=dac_set15;
     dac_lin[16]:=dac_set16; dac_lin[17]:=dac_set17; dac_lin[18]:=dac_set18;
     dac_lin[19]:=dac_set19; dac_lin[20]:=dac_set20;
     dac_str[0] :=dac_str0;
     dac_str[1] :=dac_str1;  dac_str[2] :=dac_str2;  dac_str[3] :=dac_str3;
     dac_str[4] :=dac_str4;  dac_str[5] :=dac_str5;  dac_str[6] :=dac_str6;
     dac_str[7] :=dac_str7;  dac_str[8] :=dac_str8;  dac_str[9] :=dac_str9;
     dac_str[10]:=dac_str10; dac_str[11]:=dac_str11; dac_str[12]:=dac_str12;
     dac_str[13]:=dac_str13; dac_str[14]:=dac_str14; dac_str[15]:=dac_str15;
     dac_str[16]:=dac_str16; dac_str[17]:=dac_str17; dac_str[18]:=dac_str18;
     dac_str[19]:=dac_str19; dac_str[20]:=dac_str20;
   End;
  Begin
    ini_dac_lin;
    ini_test_win;
    CASE soll_activ OF
       1: fct_code := fct_set_soll1;
       2: fct_code := fct_set_soll2;
       3: fct_code := fct_set_soll3;
       4: fct_code := fct_set_soll4;
    End; {case}
    fct_code := fct_code * 256;             { ins HI-Byte }
    fct_code := fct_code + ifc_test_nr;     { icf_adr ins Lo-Byte }

    transf_cnt := 0;
    GotoXY(6, 9);
    writeln('Function-Code + IFC-Adr[H]: ',hex_word(fct_code));
    GotoXY(6, 11);
    writeln('Wr_Data_Cnt:');
    GotoXY(26,12);
    writeln('^  ^');
    GotoXY(6, 14);
    writeln('Write-Data[H]');

    IF loop THEN
    Begin
     REPEAT
      FOR i := 0 TO 20 DO
       Begin
        sollwert := dac_lin[i];
        transf_cnt:= transf_cnt+ 1;
        GotoXY(20, 11);
        write(transf_cnt:12);
        GotoXY(28, 14);  write(hex_word(sollwert));
        pcmil.write_data(sollwert);
        pcmil.wr_fct_code(fct_code);
       End; {FOR}

      FOR i := 20 DOWNTO 0 DO
       Begin
        sollwert := dac_lin[i];
        transf_cnt:= transf_cnt+ 1;
        GotoXY(20, 11);
        write(transf_cnt:12);
        GotoXY(28, 14);  write(hex_word(sollwert));
        pcmil.write_data(sollwert);
        pcmil.wr_fct_code(fct_code);
       End; {FOR}
     UNTIL keypressed;
    End
   ELSE
    Begin
      i  := 0;
      up := TRUE;

      REPEAT
       ch := READKEY;
       IF ch = ' ' THEN
        Begin
         sollwert := dac_lin[i];
         dac_text := dac_str[i];
         transf_cnt:= transf_cnt+ 1;
         GotoXY(20, 11);
         write(transf_cnt:12);
         GotoXY(40, 14);  write(dac_text);
         GotoXY(28, 14);  write(hex_word(sollwert));
         pcmil.write_data(sollwert);
         pcmil.wr_fct_code(fct_code);

         IF up AND (i = 20)    THEN up := FALSE;
         IF (NOT up) AND (i=0) THEN up := TRUE;
         IF  up    THEN i := i + 1;
         IF NOT up THEN i := i - 1;
        End;
      UNTIL ch IN ['q','Q'];
    End; {Loop}
  End; {mil_dac_lin}


BEGIN   { Hauptprogramm }
  ifc_test_nr := 0;
  REPEAT
    user_input := menue_win;
    loop := TRUE;
    IF user_input IN ['0'..'9'] THEN loop := FALSE;
    CASE user_input OF
     '1'      : mil_detect_ifc;
     'a', 'A' : mil_ask_ifc;
     '2', 'b', 'B' : mil_rd_status;
     '3', 'c', 'C' : Begin
                       pcmil.reset;
                       ask_soll;
                       IF check_ifc_adr THEN mil_set_soll(sollwert);
                     End;
     '4', 'd', 'D' : Begin
                       pcmil.reset;
                       ask_ist;
                       IF check_ifc_adr THEN mil_rd_ist;
                     End;
     '5'           : Begin
                       pcmil.reset;
                       ask_soll_scale;
                       IF check_ifc_adr THEN mil_abgleich;
                     End;
          'e', 'E' : Begin
                       pcmil.reset;
                       ask_soll_nr;
                       IF check_ifc_adr THEN mil_abgleich;
                     End;
     '6', 'f', 'F' : Begin
                       pcmil.reset;
                       ask_soll_nr;
                       IF check_ifc_adr THEN mil_dac_lin;
                     End;
     '7', 'g', 'G' : Begin
                       pcmil.reset;
                       ask_soll_nr;
                       IF check_ifc_adr THEN mil_rd_ist;
                     End;
     '8', 'h', 'H' : Begin
                       pcmil.reset;
                       mil_loop;
                     End;
    End; {CASE}
  UNTIL (user_input = 'x') OR (user_input = 'X');
  reset_win;
END. {mil_tst}
