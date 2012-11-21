program mil_test;
{ Turbo Pascal 5.5 example  16. 3. 93 Et

                    Test fÅr PC-MIL Hardware:
  Timeout fÅr MIL-Transfers Åber Software, weil ja Hardw-Timer erst getestet wird!
  30.04.93 Timertest zugefÅgt
  02.06.93 Timeout-Bit im Status Register testen
  03.06.93 FIFO-Tests
  11.06.93 Set DRY,DRQ,INTL
  02.08.93 Timer 2 Test eingebaut
  23.08.93 IFC-Online
           ifc-test-nr
}
{$S-}
uses Crt, Win, Mil_lib,syshlp;

CONST
 head_line = 'Datentechnik                      MIL-PC     ' +
             '                      [17.09.1993]';

 stat_port  = $220;
 data_port  = $222;
 mode_port  = $224;
 rset_port  = $226;
 intr_port  = $228;   {wichtig fÅr GerÑte-Simulation: Interrupts setzen}
 timer1_port= $22A;   {set and start timer}
 timer2_port= $22C;   {set and start timer}
 time2_port = $22E;   {Schaltet Clock fÅr Timer2 auf 1 ms; nach Reset: 10us}


 dta_mode   = 0;
 cmd_mode   = 1;
 reset_mil  = 1;
 set_itl    = 0; {Interlock}
 set_dry    = 1; {Setze Bit Data Ready: FÅr GerÑtesimulation }
 set_req    = 2; {Data Request}

 stat_timeout2 = $400;  { 0: no , 1: yes}
 stat_timeout1 = $200;  { 0: no , 1: yes}
 stat_cmd_rcv  = $100;
 stat_cmd_mode = $80;
 stat_ffo_ful  = $40;
 stat_ffo_ety  = $20;
 stat_val_wrd  = $10;
 stat_wrt_rdy  = $08;
 stat_dta_req  = $04;
 stat_dta_rdy  = $02;
 stat_intlock  = $01;

 fct_set_soll1 = $06;
 fct_read_ist2 = $81;
 fct_read_stat = $C9;

 mil_timeout   = $1000;
 hardw_timer_timeout = 1000000;

TYPE
 str2    = STRING[2];
 str4    = STRING[4];
 num_str = STRING[10];

VAR
 pcmil      : Tmil;          { Type OBJECT: In UNIT Mil deklariert!! }
 ifc_test_nr: BYTE;
 mil_data  : WORD;
 read_data : WORD;
 write_data: WORD;
 read_str  : str4;
 bit16_str : STRING[19];

 status    : BOOLEAN;
 time      : LONGINT;
 timer_port: WORD;
 stat_timeout : WORD;

 wr_timeout: BOOLEAN;
 rd_timeout: BOOLEAN;
 transf_cnt: LONGINT;
 timout_cnt: LONGINT;
 timout_rd : LONGINT;
 timout_wr : LONGINT;
 user_input: CHAR;
 ch        : CHAR;
 loop      : BOOLEAN;
 timer_aktiv : WORD;
 fct_word  : WORD;

FUNCTION menue_win: CHAR;
VAR answer: CHAR;
begin
  CheckBreak := False;
  TextAttr := Black + LightGray * 16;
  Window(1, 2, 80, 24);
  FillWin(#178, {Magenta + Black * 16} red);
  Window(1, 1, 80, 25);
  GotoXY(1, 1);
  Write(head_line);
  ClrEol;
  GotoXY(20, 3);
  Writeln('              MIL-Test-Menue             ');
  GotoXY(20, 4);
  Writeln('              ==============             ');
  GotoXY(15, 5);
  Writeln('     +-- SINGLE --+               +-- LOOP --+     ');
  GotoXY(15, 7);
  Writeln('[0] Welche IFC vorhanden?        Define IFC-Adr [A]');
  GotoXY(15, 8);
  Writeln('[1]<---             Reset MIL-PC            --->[B]');
  GotoXY(15, 9);
  Writeln('[2]<--- Set DTA Mode           Set CMD Mode --->[C]');
  GotoXY(15, 10);
  Writeln('[3]<---           Read Status MIL-PC        --->[D]');
  GotoXY(15, 11);
  Writeln('[4]<---            Read FIFO Data           --->[E]');
  GotoXY(15, 12);
  Writeln('[5]<---             Read MIL Data           --->[F]');
  GotoXY(15, 13);
  Writeln('[6]<---       Write Data to PC-Data-Port    --->[G]');
  GotoXY(15, 14);
  Writeln('[7]<---          Write Function Code        --->[H]');
  GotoXY(15, 15);
  Writeln('[8]<---           Write Data to MIL         --->[I]');
  GotoXY(15, 16);
  Writeln('[9]<---       Wr/Rd_MIL (User defined)      --->[J]');
  GotoXY(15, 17);
  Writeln('         [K]    Wr/Rd-Loop(0..FFFF)                ');
  GotoXY(15, 18);
  Writeln('         [L]    Set Timer                          ');
  GotoXY(15, 19);
  Writeln('         [M]    Test Timeoutbit                    ');
  GotoXY(15, 20);
  Writeln('         [N]    MIL Fifo-Test                      ');
  GotoXY(15, 21);
  Writeln('         [O]    MIL Interrupt Set                  ');

  GotoXY(1, 25);
  Write('                                EXIT: X-Taste ');
  ClrEol;

  GotoXY(28, 22);
  Write(' Bitte Auswahl eingeben: '); answer := readkey;
  IF answer IN ['0'..'9','A'..'O','a'..'o','x','X'] THEN
   menue_win := answer;
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

  FUNCTION hex_byte(b: BYTE): num_str;
   CONST hex_num : STRING[16] = '0123456789ABCDEF';
  Begin
   hex_byte := hex_num[(b shr 4) + 1] + hex_num[(b AND $0F) + 1];
  End;

  FUNCTION hex_word(w: WORD): num_str;
   Begin
    hex_word := hex_byte(HI (w)) + hex_byte(LO (w));
   End; {hex_word}

   FUNCTION timeout: BOOLEAN;
    Begin
     timeout := FALSE;
     IF time = 0 THEN timeout := TRUE  ELSE  time := time - 1;
    End; {Timeout}

   FUNCTION read_mil_data : WORD;
    VAR mil_status: WORD;
        i : LONGINT;
    Begin
      time := mil_timeout;
      REPEAT
        mil_status := PORTW [stat_port];
      UNTIL ((mil_status AND stat_val_wrd) = stat_val_wrd) OR timeout;
      IF NOT timeout THEN
        read_mil_data := PORTW [data_port];               {Mil-Daten lesen}
    End; {read_mil}


   PROCEDURE write_mil_data (data: WORD);
    VAR mil_status: WORD;
    Begin
      time := mil_timeout;
      REPEAT
        mil_status := PORTW [stat_port];
      UNTIL ((mil_status AND stat_wrt_rdy) = stat_wrt_rdy)  OR timeout;
      IF NOT timeout THEN
        PORTW [data_port] := data;                         {Mil-Daten schreiben}
     End; {write_mil}


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


procedure ini_test_win;
begin
  CheckBreak := False;
  TextAttr := Black + LightGray * 16;
  Window(1, 2, 80, 24);
  FillWin(#178, {Magenta + Black * 16} red);
  Window(1, 1, 80, 25);
  GotoXY(1, 25);
  Write(' Loop- u. Single-Test mit [Q] beenden!    Single-Step mit [SPACE] ');
  ClrEol;
end;

  FUNCTION check_ifc_adr: BOOLEAN;
  Begin
    check_ifc_adr := TRUE;
    IF NOT (ifc_test_nr IN [1..255]) THEN
     Begin
      check_ifc_adr := FALSE;
      GotoXY(5, 22); clreol;
      write ('ABORT: IFC-Karten-Nr. undefiniert!!  Press any key to go on! '); ch := readkey;
     End;
  End; {check_ifc_adr}


 PROCEDURE mil_detect_ifc;
  LABEL 99;
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
              GotoXY(1, 25); ClrEol;
              write('Mehr als 15 Karten!!  [Q]uit  bzw.  Any key to go on!');
              ch := READKEY;
              IF ch IN ['q','Q'] THEN GOTO 99;
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
99:  End; {detect_ifc}

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


FUNCTION ask_data: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    GotoXY(5, 22);
    write ('FÅr die MIL-Transfer-Tests werden vom USER die WRITE-Daten benîtigt!! ');
    GotoXY(5, 23);
    write   ('--> Bitte 4-stellige Hex-Daten eingeben: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
      writeln('ERROR: Sorry, VACLAV: das war keine 4-stell. Hexzahl!!');
   End; {WHILE}
  ask_data := in_data;
 End;  {ask_data}

FUNCTION ask_wr_fct: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    GotoXY(5, 22);  clreol;
    write ('Welchen WRITE-Function-Code [im Hi-Byte] ??');
    GotoXY(5, 23);  clreol;
    write   ('--> Bitte 4-stellig HEX eingeben [DD00]: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
      writeln('ERROR: Sorry, USER: das war keine 4-stell. Hexzahl!!');
   End; {WHILE}
  ini_test_win;
  ask_wr_fct := (in_data AND $FF00) + ifc_test_nr;
 End;  {ask_wr_fct}

 FUNCTION ask_rd_fct: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    GotoXY(5, 22);  clreol;
    write ('Welchen READ-Function-Code [im Hi-Byte] ??');
    GotoXY(5, 23);  clreol;
    write   ('--> Bitte 4-stellig HEX eingeben [DD00]: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
      writeln('ERROR: Sorry, USER: das war keine 4-stell. Hexzahl!!');
   End; {WHILE}
  ini_test_win;
  ask_rd_fct := (in_data AND $FF00) + ifc_test_nr;
 End;  {ask_rd_fct}

FUNCTION ask_fctcode: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    GotoXY(5, 22);  clreol;
    write ('Welchen Function-Code [im Hi-Byte] ??');
    GotoXY(5, 23);  clreol;
    write   ('--> Bitte 4-stellig HEX eingeben [DD00]: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
      writeln('ERROR: Sorry, USER: das war keine 4-stell. Hexzahl!!');
   End; {WHILE}
  ini_test_win;
  ask_fctcode := (in_data AND $FF00) + ifc_test_nr;
 End;  {ask_fctcode}

  FUNCTION create_mil_fctcode (code: WORD): WORD;
   VAR function_code : WORD;
   Begin
    function_code := code;
    function_code := function_code * 256;             { ins HI-Byte }
    function_code := function_code + ifc_test_nr;     { icf_adr ins Lo-Byte }
    create_mil_fctcode := function_code;
   End;

FUNCTION ask_timer_data: WORD;
 VAR in_data : WORD;
       answer: CHAR;

 Begin
    GotoXY(5, 22); clreol;
    IF timer_aktiv = 1 THEN
     write ('Timer1-Daten: 1 Tick=10 us! Timeout -> im Statusregister Bit 200[H]!')
    ELSE
     Begin
       GotoXY(5, 22); clreol;
       write ('Welche Clock fÅr Timer 2 ?? [1]= 10us [2]= 1ms : ');
       REPEAT
         read(answer);
       UNTIL  answer IN ['1','2'];
       IF answer = '1' THEN
        Begin
         PORTW [rset_port] := reset_mil;  { Set clock for Timer 2: 10us }
         GotoXY(5, 22); clreol;
         write ('Timer2-Daten: 1 Tick=10 us! Timeout -> im Statusregister Bit 400[H]!')
        End
       ELSE
        Begin
          PORTW [time2_port] := 0;  {Dummy write to set timer2 to 1ms}
          GotoXY(5, 22); clreol;
          write ('Timer2-Daten: 1 Tick= 1 ms! Timeout -> im Statusregister Bit 400[H]!');
        End;
     End;

  status := FALSE;
  WHILE NOT status DO
   Begin
    GotoXY(5, 23); clreol;
    write   ('--> Bitte 4-stellige Hex-Daten eingeben: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
      writeln('ERROR: Sorry, USER: das war keine 4-stell. Hexzahl!!');
   End; {WHILE}
  ask_timer_data := in_data;
 End; {ask_timer_data}

 FUNCTION ask_timer_aktiv: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    GotoXY(5, 22); ClrEol;
    write ('Welchen Timer testen? [1 oder 2] :');
    readln(in_data);
    IF in_data IN [1..2] THEN status := TRUE;
   End; {WHILE}
  ask_timer_aktiv := in_data;
 End; {ask_timer_aktiv}

 FUNCTION ask_fifo_data: WORD;
 VAR in_data : WORD;
 Begin
  status := FALSE;
  WHILE NOT status DO
   Begin
    GotoXY(5, 22);
    write ('Wieviel MIL-Daten-Worte sollen ins RCV-FIFO transferiert werden?');
    GotoXY(5, 23);
    write   ('--> Bitte 4-stellige Hex-Daten eingeben: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
      writeln('ERROR: Sorry, VACLAV: das war keine 4-stell. Hexzahl!!');
   End; {WHILE}
  ask_fifo_data := in_data;
 End; {ask_fifo_data}

 PROCEDURE displ_pc_stat;
  Begin
     {Info-Anzeige der Bit-Belegung Hardware-Status}
      GotoXY(50, 12);
      writeln('Bit 11: Timer2: 0=10us  1=1ms ');
      GotoXY(50, 13);
      writeln('Bit 10: Timer2: Timeout       ');
      GotoXY(50, 14);
      writeln('Bit 09: Timer1: Timeout       ');
      GotoXY(50, 15);
      writeln('Bit 08: CMD/DATA receive      ');
      GotoXY(50, 16);
      writeln('Bit 07: CMD/DATA transmit     ');
      GotoXY(50, 17);
      writeln('Bit 06: Fifo full             ');
      GotoXY(50, 18);
      writeln('Bit 05: Fifo empty            ');
      GotoXY(50, 19);
      writeln('Bit 04: Valid Word            ');
      GotoXY(50, 20);
      writeln('Bit 03: Ready for Write       ');
      GotoXY(50, 21);
      writeln('Bit 02: Data Req              ');
      GotoXY(50, 22);
      writeln('Bit 01: Data Ready            ');
      GotoXY(50, 23);
      writeln('Bit 00: Interlock             ');
   End; {displ_dyn_stat_bits}

Procedure mil_wr_rd (write_data: WORD);
  LABEL 99;
   VAR
    i : WORD;
    error_cnt : LONGINT;
    wr_fct_code, rd_fct_code : WORD;

   Begin
    ini_test_win;
    transf_cnt := 0;
    error_cnt := 0;
    timout_wr := 0; timout_rd := 0;

    wr_fct_code := ask_wr_fct;
    rd_fct_code := ask_rd_fct;

    GotoXY(25, 8);
    write  ('WR-Fct: ',hex_word(wr_fct_code),' [H]   RD-Fct: ',
    hex_word(rd_fct_code),' [H]');
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

    PORTW [rset_port] := reset_mil;  { clear fifo }

    IF loop THEN
    Begin
     REPEAT
        transf_cnt:= transf_cnt+ 1;
        GotoXY(18, 11);
        write(transf_cnt:10);

        wr_timeout := FALSE;
        PORTW [mode_port] := dta_mode;
        write_mil_data(mil_data);                   {Mil-Daten schreiben}
        IF timeout THEN
          Begin
           wr_timeout:= TRUE;
           timout_wr := timout_wr + 1;
           GotoXY(61, 11);
           write(timout_wr:10);
          End;

        GotoXY(47, 11);      write(hex_word(i));
        PORTW [mode_port] := cmd_mode;
        write_mil_data(wr_fct_code);                     {Fct-Code schreiben}

        write_mil_data(rd_fct_code);                     {Fct-Code schreiben}
        rd_timeout := FALSE;
        read_data := read_mil_data;                      {Mil-Daten lesen}
        IF timeout THEN
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
             PORTW [mode_port] := dta_mode;
             write_mil_data(mil_data);                 {Mil-Daten schreiben}
             IF timeout THEN
              Begin
               wr_timeout:= TRUE;
               timout_wr := timout_wr + 1;
               GotoXY(61, 11);
               write(timout_wr:10);
              End;

             GotoXY(47, 11);      write(hex_word(i));
             PORTW [mode_port] := cmd_mode;
             write_mil_data(wr_fct_code);                     {Fct-Code schreiben}
             write_mil_data(rd_fct_code);                     {Fct-Code schreiben}
             rd_timeout := FALSE;
             read_data := read_mil_data;                      {Mil-Daten lesen}
             IF timeout THEN
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

PROCEDURE reset_win;
 Begin
  Window(1, 1, 80, 25);
  NormVideo;
  ClrScr;
 End;

 PROCEDURE mil_reset;
  VAR reset_cnt: LONGINT;
  Begin
   ini_test_win;
   GotoXY(1, 25);
   reset_cnt := 0;
   GotoXY(6, 11);
   writeln('Reset_Cnt:');
   GotoXY(26,12);
   writeln('^  ^');

   IF loop THEN
    Begin
     REPEAT
      reset_cnt := reset_cnt + 1;
      GotoXY(20, 11);
      write(reset_cnt:12);
      PORTW [rset_port] := reset_mil;                {Mil-Daten schreiben}
     UNTIL keypressed;
    End
   ELSE
    Begin
      REPEAT
       ch := READKEY;
       IF ch = ' ' THEN
        Begin
         reset_cnt := reset_cnt + 1;
         GotoXY(20, 11);
         write(reset_cnt:12);
         PORTW [rset_port] := reset_mil;                {Mil-Daten schreiben}
       End;
      UNTIL ch IN ['q','Q'];
    End; {Loop}
  End; {mil-reset}

 PROCEDURE  mil_set_dta_mode;
  VAR dta_mode_cnt: LONGINT;
  Begin
   ini_test_win;
   dta_mode_cnt:= 0;
   GotoXY(6, 11);
   writeln('SetMode_Cnt:');
   GotoXY(26,12);
   writeln('^  ^');
      REPEAT
       ch := READKEY;
       IF ch = ' ' THEN
        Begin
         dta_mode_cnt:= dta_mode_cnt+ 1;
         GotoXY(20, 11);
         write(dta_mode_cnt:12);
         PORTW [mode_port] := dta_mode;                {Mil-Daten schreiben}
        End;
      UNTIL ch IN ['q','Q'];
  End; { mil_set_dta_mode}

 PROCEDURE  mil_set_cmd_mode;
  VAR cmd_mode_cnt: LONGINT;
  Begin
   ini_test_win;
   cmd_mode_cnt:= 0;
   GotoXY(6, 11);
   writeln('SetMode_Cnt:');
   GotoXY(26,12);
   writeln('^  ^');
      REPEAT
       ch := READKEY;
       IF ch = ' ' THEN
        Begin
         cmd_mode_cnt:= cmd_mode_cnt+ 1;
         GotoXY(20, 11);
         write(cmd_mode_cnt:12);
         PORTW [mode_port] := cmd_mode;                {Mil-Daten schreiben}
        End;
      UNTIL ch IN ['q','Q'];
  End; { mil_set_cmd_mode}

  PROCEDURE mil_rd_status;
  VAR read_data : WORD;
   PROCEDURE show_stat_reg;
    Begin
     read_data   := PORTW [stat_port];
     GotoXY(28, 17);  write(hex_word(read_data));
     hex_bin (read_data);
     GotoXY(22, 18);  write(bit16_str);
    End;

   Begin
    ini_test_win;
    transf_cnt := 0;
    timout_cnt := 0;
    GotoXY(6, 11);
    writeln('Rd_Stat_Cnt:');
    GotoXY(26,12);
    writeln('^  ^');
    GotoXY(6, 17);
    writeln('Stat-Data[H]');
    displ_pc_stat;

    IF loop THEN
    Begin
     REPEAT
     transf_cnt:= transf_cnt+ 1;
     GotoXY(20, 11);
     write(transf_cnt:12);
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
         GotoXY(20, 11);
         write(transf_cnt:12);
         show_stat_reg;
        End;
      UNTIL ch IN ['q','Q'];
    End; {Loop}
  End; {mil_rd_status}

  PROCEDURE mil_rd_fifo;
  VAR read_data : WORD;
   Begin
    ini_test_win;
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
      read_data := PORTW [data_port];                {Mil-Daten lesen}
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
         read_data := PORTW [data_port];                {Mil-Daten lesen}
         GotoXY(28, 14);  write(hex_word(read_data));
        End;
      UNTIL ch IN ['q','Q'];
    End; {Loop}
  End; {mil_rd_fifo}

  PROCEDURE mil_wr_data(write_data:WORD);
   Begin
    ini_test_win;
    transf_cnt := 0;

    GotoXY(10,5);
    write(' Daten werden in den DATA-Port des PC-Interfaces geschrieben!!');

    GotoXY(06,11); writeln('Wr_Data_Cnt:');
    GotoXY(26,12); writeln('^  ^');
    GotoXY(06,14); writeln('Write-Data[H]');
    GotoXY(28,14); write(hex_word(write_data));

    IF loop THEN
    Begin
     REPEAT
      transf_cnt:= transf_cnt+ 1;
      GotoXY(20, 11);
      write(transf_cnt:12);
      PORTW [data_port] := write_data;                {Mil-Daten schreiben}
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
         PORTW [data_port] := write_data;                {Mil-Daten schreiben}
        End;
      UNTIL ch IN ['q','Q'];
    End; {Loop}
  End; {mil_wr_data}


  PROCEDURE mil_loop;
   LABEL 99;
   VAR
    i : WORD;
    error_cnt : LONGINT;
    mil_status : WORD;
    wr_fct_code, rd_fct_code : WORD;

   Begin

    ini_test_win;
    transf_cnt := 0;
    error_cnt := 0;
    timout_wr := 0; timout_rd := 0;

    wr_fct_code := ask_wr_fct;
    rd_fct_code := ask_rd_fct;

    GotoXY(4,03);
    write('Achtung: Dieser Test benîtigt eine IFC-Karte am MIL-BUS mit (FCT + ADR): ');
    GotoXY(15,04);
    write  ('Wr-Fct-Code: ', hex_word(wr_fct_code),'[H]     ', +
            'Rd-Fct-Code: ', hex_word(rd_fct_code),'[H]');

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

    PORTW [rset_port] := reset_mil;  { clear fifo }

    IF loop THEN
    Begin
     REPEAT
      FOR i := 0 TO $FFFF DO
       Begin
        transf_cnt:= transf_cnt+ 1;
        GotoXY(18, 11);
        write(transf_cnt:10);

        wr_timeout := FALSE;
        PORTW [mode_port] := dta_mode;
        write_mil_data(i);                              {Mil-Daten schreiben}
        IF timeout THEN
          Begin
           wr_timeout:= TRUE;
           timout_wr := timout_wr + 1;
           GotoXY(61, 11);
           write(timout_wr:10);
          End;

        GotoXY(47, 11);      write(hex_word(i));
        PORTW [mode_port] := cmd_mode;
        write_mil_data(wr_fct_code);                     {Fct-Code schreiben}

        write_mil_data(rd_fct_code);                     {Fct-Code schreiben}
        rd_timeout := FALSE;
        read_data := read_mil_data;                      {Mil-Daten lesen}
        IF timeout THEN
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
             PORTW [mode_port] := dta_mode;
             write_mil_data(i);                              {Mil-Daten schreiben}
             IF timeout THEN
              Begin
               wr_timeout:= TRUE;
               timout_wr := timout_wr + 1;
               GotoXY(61, 11);
               write(timout_wr:10);
              End;

             GotoXY(47, 11);      write(hex_word(i));
             PORTW [mode_port] := cmd_mode;
             write_mil_data(wr_fct_code);                     {Fct-Code schreiben}
             write_mil_data(rd_fct_code);                     {Fct-Code schreiben}
             rd_timeout := FALSE;
             read_data := read_mil_data;                      {Mil-Daten lesen}
             IF timeout THEN
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

  PROCEDURE mil_timer(write_data:WORD);
   Begin
    ini_test_win;
    transf_cnt := 0;
    GotoXY(6, 11);
    writeln('Wr_Data_Cnt:');
    GotoXY(26,12);
    writeln('^  ^');
    GotoXY(6, 14);
    writeln('Write-Data[H]');
    GotoXY(28, 14);  write(hex_word(write_data));
    GotoXY(6, 5);
    writeln('Es wird getestet Timer Nr.: ');

    IF timer_aktiv = 1 THEN
     Begin
       timer_port  := timer1_port;
       stat_timeout:= stat_timeout1;
     End;
    IF timer_aktiv = 2 THEN
     Begin
       timer_port  := timer2_port;
       stat_timeout:= stat_timeout2;
     End;
    GotoXY(36, 5);
    write(timer_aktiv);

      REPEAT
       ch := READKEY;
       IF ch = ' ' THEN
        Begin
         transf_cnt:= transf_cnt+ 1;
         GotoXY(20, 11);
         write(transf_cnt:12);
         PORTW [timer_port] := write_data;                {Mil-Daten schreiben}
        End;
      UNTIL ch IN ['q','Q'];
  End; {mil_timer}


  PROCEDURE mil_timeout_bit;
   LABEL 99;
   VAR err_count,ok_count : LONGINT;
       i : WORD;

   Begin
    ok_count   := 0;
    err_count  := 0;
    time := hardw_timer_timeout;
    PORTW [rset_port] := reset_mil;  { Set clock for Timer2 to 10us }

    ini_test_win;
    transf_cnt := 0;
    GotoXY(6, 5);
    writeln('Es wird getestet Timer Nr.: ');

    GotoXY(6, 11);
    writeln('Wr_Timer_Cnt:                   Timeout_Bit ok   : ');
    GotoXY(26,12);
    writeln('^  ^');
    GotoXY(6, 14);
    writeln('Timer_Data[H]:                  Timeout_Bit Error: ');
    GotoXY(57, 14);
    write(err_count:12);
    GotoXY(57, 11);
    write(ok_count:12);

    IF timer_aktiv = 1 THEN
     Begin
       timer_port  := timer1_port;
       stat_timeout:= stat_timeout1;
     End;
    IF timer_aktiv = 2 THEN
     Begin
       timer_port  := timer2_port;
       stat_timeout:= stat_timeout2;
     End;
    GotoXY(36, 5);
    write(timer_aktiv);

    IF loop THEN
    Begin
     REPEAT
      {Falls Timer2: teste zuerst die 1 ms-Clock}
      IF timer_aktiv = 2 THEN
       Begin
{xxx}    PORTW [rset_port] := reset_mil;   { Set clock for Timer2 to 10us }
         PORTW [time2_port] := 0;         {Dummy write to set timer2 to 1ms}
         write_data := 1000;               {1 s}
         PORTW [timer_port] := write_data; {Timer-Daten schreiben u. Timerstart}
         REPEAT
         UNTIL timeout OR (PORTW [stat_port] AND stat_timeout = stat_timeout);
         IF timeout THEN
          Begin
           err_count := err_count + 1;
           GotoXY(57, 14);
           write(err_count:12);
           GotoXY(45,05);
           write('Timer 2-Test mit 1ms-Clock: Not ok!! ');
          End
         ELSE
          Begin
           GotoXY(45,05);
           write('Timer 2-Test mit 1ms-Clock: ok!! ');
          End;
        End;

      PORTW [rset_port] := reset_mil;   { Set clock for Timer2 to 10us }
      write_data := 1;
      FOR i := 1 TO 15 DO     {Jedes Bit testen}
       Begin
        PORTW [timer_port] := write_data; {Timer-Daten schreiben u. Timerstart}
        GotoXY(28, 14);  write(hex_word(write_data));
        REPEAT
        UNTIL timeout OR (PORTW [stat_port] AND stat_timeout = stat_timeout);
        IF timeout THEN
         Begin
           err_count := err_count + 1;
           GotoXY(57, 14);
           write(err_count:12);
         End
        ELSE
         Begin
           ok_count := ok_count + 1;
           GotoXY(57, 11);
           write(ok_count:12);
         End;
        transf_cnt:= transf_cnt+ 1;
        GotoXY(20, 11);
        write(transf_cnt:12);
        time := hardw_timer_timeout; {Software-Timeout erneut setzen!!}
        IF keypressed THEN GOTO 99;
        write_data := write_data shl 1;
       End; {FOR i}
      UNTIL keypressed;
    End; {Loop}
99:
  End; {mil_timeout_bit}


 PROCEDURE mil_fifo;
 { In diesem Test wird das FIFO mit Daten gefÅllt und der FÅllstand im
   Status-Register angezeigt  sowie Daten aus dem FIFO gelesen.
   Dazu mu· eine IFC am MIL-Bus sein.
 }
   LABEL 99;
   VAR
    i : WORD;
    error_cnt : LONGINT;
    test_count: WORD;
    wr_fct_code, rd_fct_code : WORD;

   Begin
    ini_test_win;
    transf_cnt  := 0;
    error_cnt   := 0;
    timout_wr   := 0;
    timout_rd   := 0;
    wr_fct_code := create_mil_fctcode (fct_set_soll1);
    rd_fct_code := create_mil_fctcode (fct_read_ist2);

    test_count := mil_data; {--> user-input}
    displ_pc_stat;
    GotoXY(1, 3);
    write('Achtung: Dieser Test benîtigt eine IFC-Karte am MIL-BUS mit FCT-Code 06 u. 81[H]');

    GotoXY(6,04);
    write  ('IFC-Adr: ',hex_byte(ifc_test_nr),'            Wr-Fct-Code: 06[H]      Rd-Fct_Code: 81[H]');
    GotoXY(6,08);
    writeln('Wr_Data_Cnt:              Write-Data[H]:                ');
    GotoXY(6,10);
    writeln('Error_Count:              Read-Data [H]:                ');
    GotoXY(22,11);
    writeln('^  ^');

    GotoXY(53,08); write('WR-Timeout: ');
    GotoXY(65,08); write(timout_wr:6);

    GotoXY(53,10); write('Soll-Data : ');
    GotoXY(65,10); write(timout_rd:6);
    GotoXY(22,10); write(error_cnt:6);

    GotoXY(06,17); writeln('Stat-Data[Hex]');
    GotoXY(06,18); writeln('Stat-Data[Bin]');
    GotoXY(22,19); writeln('MSB             LSB');

    PORTW [rset_port] := reset_mil;  { clear fifo }
    read_data   := PORTW [stat_port];
    GotoXY(28, 17);  write(hex_word(read_data));
    hex_bin (read_data);
    GotoXY(22, 18);  write(bit16_str);

    GotoXY(1, 25); ClrEol;
    Write('Zustand des Status-Registers vor dem Test!!  Weiter mit [SPACE] ');
    REPEAT
      ch := READKEY;
    UNTIL ch = ' ';

    IF loop THEN
     Begin
      PORTW [rset_port] := reset_mil;  { clear fifo }
      FOR i:= 1 TO test_count DO
       Begin
        transf_cnt:= transf_cnt+ 1;
        GotoXY(18,08); write(transf_cnt:10);
        wr_timeout := FALSE;
        PORTW [mode_port] := dta_mode;
        write_mil_data(i);                   {Mil-Daten schreiben}
        IF timeout THEN
          Begin
           wr_timeout:= TRUE;
           timout_wr := timout_wr + 1;
           GotoXY(61,08); write(timout_wr:10);
          End;

        GotoXY(47,08);      write(hex_word(i));
        PORTW [mode_port] := cmd_mode;
        write_mil_data(wr_fct_code);                     {Fct-Code schreiben}

        { transferiere Daten von der IFC-Karte ins FIFO }
        write_mil_data(rd_fct_code);                     {Fct-Code schreiben}

        read_data   := PORTW [stat_port];
        GotoXY(28, 17);  write(hex_word(read_data));
        hex_bin (read_data);
        GotoXY(22, 18);  write(bit16_str);
      End; {FOR i..}

     GotoXY(1, 25);
     Write('Daten im FIFO!!  Weiter mit [SPACE] ');
     ClrEol;
     REPEAT
       ch := READKEY;
     UNTIL ch = ' ';

     {FiFo-Daten jetzt zurÅcklesen und prÅfen}
     GotoXY(1, 25);
     Write('Lese Daten aus dem FIFO. Beenden mit [Q]uit');
     ClrEol;

     FOR i:= 1 TO test_count DO
       Begin
        read_data := PORTW [data_port];                 {Mil-Daten lesen}
        IF NOT (i = read_data) THEN
         Begin
           error_cnt := error_cnt +1;
           GotoXY(22,10); write(error_cnt:6);
           GotoXY(67,10);  write(hex_word(i));         {Soll-Daten}
           GotoXY(47,10); write(hex_word(read_data)); {Error-Daten}
           GotoXY(1, 25);  write('FIFO Read-Error!!  Weiter mit [SPACE] oder [Q]uit! ');
           ClrEol;
           REPEAT
            ch := READKEY;
            IF ch IN ['q','Q'] THEN GOTO 99;
           UNTIL ch = ' ';
         End;
       End; {FOR i}

       read_data   := PORTW [stat_port];
       GotoXY(28, 17);  write(hex_word(read_data));
       hex_bin (read_data);
       GotoXY(22, 18);  write(bit16_str);

       GotoXY(1, 25);
       Write('FIFO-Test beendet!!           Weiter [Q]uit! ');
       ClrEol;

     REPEAT
      ch := READKEY;
      IF ch IN ['q','Q'] THEN GOTO 99;
     UNTIL 1=2;
   End; {Loop}
99:
  End; {mil_fifo}

 FUNCTION ask_intr_data: WORD;
 VAR in_data : WORD;
     input_ok: BOOLEAN;
 Begin
  status  := FALSE;
  input_ok:= FALSE;
  WHILE NOT input_ok DO
   Begin
    GotoXY(5, 22);
    write ('Welches Signal: [0001]=Intlock, [0002]=DtaRdy, [0004]=DtaReq ?');
    GotoXY(5, 23);
    write   ('--> Bitte 4-stellige Hex-Daten eingeben: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF (NOT status) OR NOT (in_data < 8) THEN
      writeln('ERROR: Sorry, VACLAV: das war keine 4-stell. Hexzahl!!')
    ELSE
      input_ok := TRUE;
   End; {WHILE}
  ask_intr_data := in_data;
 End; {ask_intr_data}


 PROCEDURE mil_intr;
 { Die 3 Intr-Bits ITL, DRQ, DRY werden auf dem MIL-BUS ausgegeben }
   LABEL 99;

   PROCEDURE show_stat_reg;
    Begin
     read_data   := PORTW [stat_port];
     GotoXY(28, 17);  write(hex_word(read_data));
     hex_bin (read_data);
     GotoXY(22, 18);  write(bit16_str);
    End;

   Begin
    ini_test_win;
    displ_pc_stat;
    transf_cnt := 0;
    GotoXY(6, 11);  writeln('Set_Int_Cnt:');
    GotoXY(26,12);  writeln('^  ^');
    GotoXY(20, 11); write(transf_cnt:10);
    GotoXY(6, 17);  writeln('Stat-Data[Hex]');
    GotoXY(6, 18);  writeln('Stat-Data[Bin]');
    GotoXY(12, 19); writeln('          MSB             LSB');
    show_stat_reg;
    GotoXY(1, 25);  ClrEol;
    Write('Zustand des Status-Registers vor dem Test!!  Weiter mit [SPACE] ');

    REPEAT
     ch:= READKEY;
    UNTIL ch = ' ';
    ch := '1';     {dummy}

    GotoXY(1, 25); ClrEol;
    Write(' Single-Test mit [Q] beenden!    Single-Step mit [SPACE] ');
    REPEAT
      ch := READKEY;
      IF ch = ' ' THEN
      Begin
       transf_cnt:= transf_cnt+ 1;
       GotoXY(20, 11);
       write(transf_cnt:10);
       PORTW [intr_port] := mil_data; {user-input}
       show_stat_reg;
      End;
    UNTIL  ch IN ['q','Q'];
99:
  End; {mil_intr}

 PROCEDURE displ_ifc_stat;
  Begin
     {Info-Anzeige der Bit-Belegung IFC-Status}
      GotoXY(50, 13);
      writeln('Bit 15: Intrlck_Mask  0-Disabl');
      GotoXY(50, 14);
      writeln('Bit 14: Dta_Rdy_Mask  0-Disabl');
      GotoXY(50, 15);
      writeln('Bit 13: Dta_Req_Mask  0-Disabl');
      GotoXY(50, 16);
      writeln('Bit 12: Intrlck-Sign  0-aktiv ');
      GotoXY(50, 17);
      writeln('Bit 11: Dta-Rdy-Sign  0-aktiv ');
      GotoXY(50, 18);
      writeln('Bit 10: Dta-Req-Sign  0-aktiv ');
      GotoXY(50, 19);
      writeln('Bit 09: frei                  ');
      GotoXY(50, 20);
      writeln('Bit 08: frei                  ');
      GotoXY(50, 21);
      writeln('Bit 07: A7 IFC-Adr            ');
      GotoXY(50, 22);
      writeln(' "   I   I    "               ');
      GotoXY(50, 23);
      writeln('Bit 00: A0 IFC-Adr            ');
   End; {displ_ifc_stat}

 PROCEDURE mil_rd_data;
  VAR read_data,pc_status : WORD;
      rd_timeout : BOOLEAN;
   PROCEDURE get_data;
    Begin
     pcmil.wr_fct_code(fct_word);
     pcmil.hw_timer1_set (10);
     REPEAT      {Warte bis Daten im FIFO}
       pc_status  := pcmil.rd_status;
     UNTIL (pc_status AND stat_val_wrd=stat_val_wrd) OR pcmil.hw_timeout1;
     IF pcmil.hw_timeout1 THEN
      Begin
        timout_cnt := timout_cnt + 1;
        rd_timeout := TRUE;
        GotoXY(56,11); writeln(timout_cnt:12);
      End
     ELSE
      Begin  {kein Timeout}
       rd_timeout := FALSE;
       read_data := pcmil.read_data;
       GotoXY(28, 17);  write(hex_word(read_data));
       hex_bin (read_data);
       GotoXY(22, 18);  write(bit16_str);
      End;
    End; {get_data}

   Begin
    ini_test_win;
    transf_cnt := 0;
    timout_cnt := 0;
    fct_word   := ask_rd_fct;
    GotoXY(25, 8);
    write  ('Function-Word (Fct + Adr): ',hex_word(fct_word),' [H]');

    IF (fct_word AND $C900) = $C900 THEN
      displ_ifc_stat;                         {Anzeige nur bei C9-Fct-Code}
    GotoXY(06,11); writeln('Rd_Data_Cnt:');
    GotoXY(26,12); writeln('^  ^');
    GotoXY(40,11); writeln('Timeout_Count: ');
    GotoXY(56,11); writeln(timout_cnt:12);
    GotoXY(06,17); writeln('MIL-Data[H]:');
    GotoXY(13,18); writeln('[Bin]');
    GotoXY(22,19); writeln('MSB             LSB');

    IF loop THEN
     Begin
      REPEAT
       transf_cnt:= transf_cnt+ 1;
       GotoXY(20, 11);
       write(transf_cnt:12);
       get_data;
       IF rd_timeout THEN
        Begin
         GotoXY(28, 17);  write('    ');
         GotoXY(22, 18);  write('                   ');
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
         GotoXY(20, 11);
         write(transf_cnt:12);
         get_data;
         IF rd_timeout THEN
          Begin
           GotoXY(28, 17);  write('    ');
           GotoXY(22, 18);  write('                   ');
          End;
        End;
      UNTIL ch IN ['q','Q'];
    End; {Loop}
  End; {mil_rd_data}

 PROCEDURE mil_wr_fctcode (mil_data: WORD);
 VAR fct_code : WORD;
   Begin
    ini_test_win;
    fct_code := ask_fctcode;
    transf_cnt := 0;
    GotoXY(25, 8);
    write  ('Function: ',hex_word(fct_code),' [H]');
    GotoXY(6, 11); writeln('Wr_Fct_Cnt :');
    GotoXY(26,12); writeln('^  ^');

   IF loop THEN
    Begin
     REPEAT
      transf_cnt:= transf_cnt+ 1;
      GotoXY(20, 11);
      write(transf_cnt:12);
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
         pcmil.wr_fct_code(fct_code);
        End;
      UNTIL ch IN ['q','Q'];
    End; {Loop}
  End; {mil_wr_fctcode}

Procedure mil_wr(write_data: WORD);
  LABEL 99;
   VAR
    i : WORD;
    error_cnt  : LONGINT;
    wr_fct_code: WORD;

   Begin
    ini_test_win;
    transf_cnt := 0;
    error_cnt := 0;
    timout_wr := 0;
    wr_fct_code := ask_wr_fct;
    GotoXY(25, 8);
    write  ('WR-Fct: ',hex_word(wr_fct_code),' [H]');
    GotoXY(6, 11);
    writeln('Wr_Data_Cnt:              Write-Data[H]:                ');

    GotoXY(53,11); write('Timeout:');
    GotoXY(61,11); write(timout_wr:10);
    PORTW [rset_port] := reset_mil;  { clear fifo }
    IF loop THEN
    Begin
     REPEAT
        transf_cnt:= transf_cnt+ 1;
        GotoXY(18, 11); write(transf_cnt:10);
        wr_timeout := FALSE;
        PORTW [mode_port] := dta_mode;
        write_mil_data(mil_data);                   {Mil-Daten schreiben}
        IF timeout THEN
          Begin
           wr_timeout:= TRUE;
           timout_wr := timout_wr + 1;
           GotoXY(61, 11);
           write(timout_wr:10);
          End;

        GotoXY(47, 11);  write(hex_word(i));
        PORTW [mode_port] := cmd_mode;
        write_mil_data(wr_fct_code);                     {Fct-Code schreiben}
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
             PORTW [mode_port] := dta_mode;
             write_mil_data(mil_data);                 {Mil-Daten schreiben}
             IF timeout THEN
              Begin
               wr_timeout:= TRUE;
               timout_wr := timout_wr + 1;
               GotoXY(61, 11);
               write(timout_wr:10);
              End;

             GotoXY(47, 11);      write(hex_word(i));
             PORTW [mode_port] := cmd_mode;
             write_mil_data(wr_fct_code);                     {Fct-Code schreiben}
            End
           ELSE
             Begin
              IF ch IN ['q','Q'] THEN GOTO 99;
             End; {IF ch}
        UNTIL 1 = 2;
    End; {Loop}
99:
End; {mil_wr}


BEGIN
  ifc_test_nr := 0;
  REPEAT
    user_input := menue_win;
    loop := TRUE;
    IF user_input IN ['0'..'9'] THEN loop := FALSE;
    CASE user_input OF
     '0'      : mil_detect_ifc;
     'a', 'A' : mil_ask_ifc;
     '1', 'b', 'B' : mil_reset;
     '2'           : mil_set_dta_mode;
          'c', 'C' : mil_set_cmd_mode;
     '3', 'd', 'D' : mil_rd_status;
     '4', 'e', 'E' : mil_rd_fifo;
     '5', 'f', 'F' : Begin
                       IF check_ifc_adr THEN
                         mil_rd_data;
                     End;
     '6', 'g', 'G' : Begin
                       mil_data := ask_data;
                       mil_wr_data(mil_data);
                     End;
     '7', 'h', 'H' : Begin
                       IF check_ifc_adr THEN
                        Begin
                         mil_wr_fctcode(mil_data);
                        End;
                     End;
     '8', 'i', 'I' : Begin
                       IF check_ifc_adr THEN
                        Begin
                         mil_data := ask_data;
                         mil_wr(mil_data);
                        End;
                     End;
     '9', 'j', 'J' : Begin
                       IF check_ifc_adr THEN
                        Begin
                         mil_data := ask_data;
                         mil_wr_rd(mil_data);
                        End;
                     End;
          'k', 'K' : Begin
                       IF check_ifc_adr THEN mil_loop;
                     End;
          'l', 'L' : Begin
                       timer_aktiv := ask_timer_aktiv;
                       mil_data := ask_timer_data;
                       mil_timer(mil_data);
                     End;
          'm', 'M' : Begin
                       timer_aktiv := ask_timer_aktiv;
                       mil_timeout_bit;
                     End;
          'n', 'N' : Begin
                       IF check_ifc_adr THEN
                        Begin
                          mil_data := ask_fifo_data;
                          mil_fifo;
                        End;
                     End;
          'o', 'O' : Begin
                       mil_data := ask_intr_data;
                       mil_intr;
                     End;
    End; {CASE}
  UNTIL (user_input = 'x') OR (user_input = 'X');
  reset_win;
END.  {MIL-TEST}

