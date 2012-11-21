PROGRAM Mil_Werk;
{ Autor des Basis-Programmes Mil_Base.Pas: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS

  Autor der Erweiterungen   :
  énderungen:
  23.06.95    Englert   Funktionscode-Tabelle
  29.06.95    Englert   Statusbits fÅr C0, C1, C2, C3
  13.07.95    Et        neue Functions-Code-Tabelle
  23.08.95    Et        Statusbits-Tabellen
}
{$S-}
uses Crt, WinDos, Datech;

CONST
 head_line =
      'Datentechnik                         MIL_WERK   ' +
      '                    [08.02.1996]' +
      '                            Spezielle Hardware-Tests        (Turbo Pascal V7.0)';

 msg_single_step =
      'Loop- u. Single-Test mit [Q] beenden!    Single-Step mit [SPACE] ';
 msg_timer_auto =
      'Automat. Timertest mit [Q] beenden!                              ';

                       {Konstanten fÅr Werkmann}
const
 FktMax = 22;
 StatMax = 4;
 Wait_Fkt   =   500 * 100;  {max. 5,0 sec warten}

type
 TFkt_Ary  = array [1..FktMax]  of Byte;
 TStat_Ary = array [1..StatMax] of Byte;

const
 TstFkt : TFkt_Ary  = (01,02,03,01,02,03,05,04,05,04,$14,$15,$16,$17,$18,$19,$14,$15,$16,$17,$18,$19);
 TstStat: TStat_Ary = ($C0,$C1,$C2,$C3);


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

procedure menue_win;
VAR answer: CHAR;
begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;            {Festliegender Teil des MenÅs: s. a. DATECH_0.PAS}
  TextColor(Blue);

  GotoXY(5, 16);
  Writeln('       [M]<-- Sende 2 x Functioncode mit minimaler Pause                        ');
  GotoXY(5, 17);
  Writeln('       [N]<-- Sende Fct-Code mit 30 us Pause                             ');
  GotoXY(5, 18);
  Writeln('       [O]<-- Sende Fct-Code zur IFC (Adresse 00 mîglich)                ');
  GotoXY(5, 19);
  Writeln('       [P]<-- Sende Fct-Code + Daten zur IFC (Adresse 00 mîglich)        ');
  GotoXY(5, 20);
  Writeln('       [Q]<-- IFC-Adressen-Test (Spezial-Aufbau mit 2 Karten)            ');
  GotoXY(5, 21);
  Writeln('       [R]<-- Funktionscode-Test (fÅr Schaltkarte)                       ');
  GotoXY(5, 22);
  Writeln('       [S]<-- Sende 2 x Daten mit Fct-Code (minimale Pause)                                                           ');
{
  GotoXY(5, 23);
  Writeln('         [T]<--                                                        ');

  GotoXY(5, 24);
  Write('           [U]<--                                                       ');
}
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
      TextColor(Brown);
      write('Am MIL-Bus melden sich insgesamt IFC-Karten: ');
      GotoXY(2,2);  write(' Soll--ADR--Ist      Soll--ADR--Ist      Soll--ADR--Ist      Soll--ADR--Ist');
      GotoXY(2,3);  write(' [Hex]....[Hex]      [Hex]....[Hex]      [Hex]....[Hex]      [Hex]....[Hex]');
      TextColor(Black);

      FOR ifb_adr := 0 TO 255 DO
        Begin
          mil.ifc_online (ifb_adr, RetAdr, OnlineErr);
{if ifb_adr in [1..60] then OnlineErr := NoErr; }
          If OnlineErr = NoErr then
            begin
             if (ifb_adr=0) or (ifb_adr<>RetAdr) then
              begin
               TextColor(Red); {Setze Schriftfarbe}
               GotoXY (spalte, zeile);
               hex_str := hex_byte(ifb_adr);
               write(hex_Byte(Ifb_Adr));                           {Solladresse}
              end;

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
     Mil.Timer2_Wait(70000);
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

 PROCEDURE Displ_HS_Status;
  Begin
     {Info-Anzeige der Bit-Belegung Hochstrom-Maske}
      ini_info_win;
      writeln('Bit 15: HS Gate Enabl 0-Disabl');
      writeln('Bit 14: HS Enable     0-Disabl');
      writeln('Bit 13: HS v. Softw.  0-aktiv ');
      writeln('Bit 12: HS-SumIntl FF 0-aktiv ');
      writeln('Bit 11: HS-Sig live   0-aktiv ');
      writeln('Bit 10: HS-Sig FF     0-aktiv ');
      writeln('Bit 09: HS-Opto live  0-aktiv ');
      writeln('Bit 08: HS-Opto FF    0-aktiv ');
      writeln;
      writeln('Bit 07: A7 IFC-Adr            ');
      writeln(' "  |   |    "                ');
      write  ('Bit 00: A0 IFC-Adr            ');
   End; {displ_HS_Status}

 PROCEDURE Displ_HS_Ctrl;
  Begin
     {Info-Anzeige der Bit-Belegung Hochstrom-Maske}
      ini_info_win;
      writeln('Bit 15: MIL-Spg. 15V  1-aktiv');
      writeln('Bit 14: Sel Err Pigy  1-aktiv');
      writeln('Bit   :                      ');
      writeln('Bit   :                      ');
      writeln('Bit   :                      ');
      writeln('Bit   :                      ');
      writeln('Bit 09: Broadcast     1-aktiv');
      writeln('Bit 08: Receive Error 1-aktiv');
      writeln;
      writeln('Bit 07: A7 IFC-Adr            ');
      writeln(' "  |   |    "                ');
      write  ('Bit 00: A0 IFC-Adr            ');
  End; {displ_HS_Ctrl}


 PROCEDURE Displ_HS_Cmd;
  Begin
     {Info-Anzeige der Bit-Belegung Hochstrom-Maske}
      Set_Text_Win;
      Window(01, 11, 35, 22);
      TextBackground(Cyan);
      TextColor(Black);               {Setze Schriftfarbe}
      ClrScr;
      writeln('7F H : Set   Broadcast           ');
      writeln('7E H : Reset Broadcast           ');
      writeln('7D H : Reset RCV-Error (Val Word)');
      writeln('  ');
      writeln('  ');
      writeln('7C H : Enable  HS-INL    Gate    ');
      writeln('7B H : Disable HS-INL    Gate    ');
      writeln('7A H : Enable  HS-INL            ');
      writeln('79 H : Disable HS-INL            ');
      writeln('78 H : Set     HS-INL v. Rechner ');
      writeln('77 H : Reset   HS-INL v. Rechner ');
      write  ('76 H : Reset   HS-INL    Status  ');
   End; {Displ_HS_Cmd}

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
      Rd_Fct1, Rd_Fct2, Rd_Fct3 : Byte;
      N      : Byte;
      Anzahl : Byte;

   PROCEDURE get_data (Num : Byte);
    var Read_Data : Word;
        Bit16_Strg : Str19;
    Begin
     Mil.Rd (read_data, Fct, MilErr);
     IF MilErr  <> No_Err THEN
      Begin
        timout_cnt := timout_cnt + 1;
        rd_timeout := TRUE;
        TextColor (Red);
        GotoXY(22,12); write(timout_cnt:12);
        TextColor (Black);

        case Num of
         1: begin
              GotoXY(25, 17);  write('    ');
              GotoXY(17, 18);  write('                   ');
           end;
         2: begin
              GotoXY(46, 17);  write('    ');
              GotoXY(38, 18);  write('                   ');
            end;
         3: begin
              GotoXY(68, 17);  write('    ');
              GotoXY(60, 18);  write('                   ');
           end;
         end; {case}
        mil.reset;
      End
     ELSE
      Begin  {kein Timeout}
       rd_timeout := FALSE;
       case Num of
        1: begin
             GotoXY(25, 17);  write(hex_word(read_data));
             Hex_Bin_Str (read_data,bit16_strg);
             GotoXY(17, 18);  write(bit16_strg);
           end;
        2: begin
             GotoXY(46, 17);  write(hex_word(read_data));
             Hex_Bin_Str (read_data,bit16_strg);
             GotoXY(38, 18);  write(bit16_strg);
           end;
        3: begin
             GotoXY(68, 17);  write(hex_word(read_data));
             Hex_Bin_Str (read_data,bit16_strg);
             GotoXY(60, 18);  write(bit16_strg);
           end;
        end; {case}
      End;
    End; {get_data}

   procedure Ask_Fctcode (var Code: Byte; Nr: Byte);
    begin
     repeat
      Ini_Text_Win;
      GotoXY(5, 22);
      write ('Eingeben READ-Function-Code Nr. ',Nr,'  [80H...FFH] ??');
      Code := ask_hex_byte;
      if Code < $80 then
       begin
         Ini_Err_Win;
         write ('Error: Read-Function-Code nicht 80H..FFh!!! Weiter mit <Space> ');
         repeat until keypressed;
         Ch := ReadKey;
       end
      else
       Fct_ok := True;
     until Fct_ok;
    end; {Ask_Fctcode}

  Begin
    transf_cnt := 0;
    timout_cnt := 0;
    Fct_ok     := False;
    Fct.B.Adr  := Ifc_Test_Nr;

    Ini_Text_Win;
    Ini_Msg_Win;
    Write('Mit wieviel verschied. Funct_Codes lesen [1 oder 3]?  <CR> = 1: ');
    repeat until Keypressed;
    Ch := ReadKey;
    if Ch = '3' then
     begin
       Anzahl := 3;
       Readln;
     end
    else
       Anzahl := 1;

    if Anzahl = 3 then
     begin
      Ask_Fctcode (Rd_Fct1, 1);
      Ask_Fctcode (Rd_Fct2, 2);
      Ask_Fctcode (Rd_Fct3, 3);

      Ini_Text_Win;
      GotoXY(22,05); write('----- Lese Daten von der IFC-Karte -----');
      GotoXY(06,11); writeln('Rd_Data_Cnt  :');
      GotoXY(26,12); writeln('^  ^');
      GotoXY(06,12); writeln('Timeout_Count: ');
      GotoXY(22,12); writeln(timout_cnt:12);

      GotoXY(01,15); write('Fct-Word (Fct+Adr): ');
      Fct.B.Fct := Rd_Fct1;
      GotoXY(25,15); Write(hex_word(Fct.W),' [H]');
      Fct.B.Fct := Rd_Fct2;
      GotoXY(46,15); Write(hex_word(Fct.W),' [H]');
      Fct.B.Fct := Rd_Fct3;
      GotoXY(68,15); Write(hex_word(Fct.W),' [H]');

      GotoXY(01,17); writeln('MIL-Data[H]:');
      GotoXY(07,18); writeln('[Bin]:');
      GotoXY(17,19); writeln('MSB             LSB');
      GotoXY(38,19); writeln('MSB             LSB');
      GotoXY(60,19); writeln('MSB             LSB');

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
         Fct.B.Fct := Rd_Fct1;
         get_data (1);

         Transf_Cnt := Transf_Cnt+ 1;
         GotoXY(22, 11); write(transf_cnt:12);
         Fct.B.Fct := Rd_Fct2;
         get_data (2);

         Transf_Cnt := Transf_Cnt+ 1;
         GotoXY(22, 11); write(transf_cnt:12);
         Fct.B.Fct := Rd_Fct3;
         get_data (3);
       until KeyPressed or (Ch = ' ');
       if Ch = ' ' then
         begin
          Ini_Msg_Win;
          Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
          repeat until KeyPressed;
         end;
       Ch := ReadKey;
      until Ch in ['x','X'];
     end  {if Anzahl = 3}
    else
     begin {Anzahl = 1}
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
      GotoXY(25,07); write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
      GotoXY(06,11); writeln('Rd_Data_Cnt  :');
      GotoXY(26,12); writeln('^  ^');
      GotoXY(06,12); writeln('Timeout_Count: ');
      GotoXY(22,12); writeln(timout_cnt:12);

      GotoXY(01,17); writeln('MIL-Data[H]:');
      GotoXY(07,18); writeln('[Bin]:');
      GotoXY(17,19); writeln('MSB             LSB');

      IF (Fct.B.Fct = $C9) THEN
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
        get_data (1);
      until KeyPressed or (Ch = ' ');
      if Ch = ' ' then
        begin
         Ini_Msg_Win;
         Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
         repeat until KeyPressed;
        end;
      Ch := ReadKey;
     until Ch in ['x','X'];
    end; {if Anzahl = 1}
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

 procedure Functioncode_Table;
  label 99;

  procedure Code_Table1;
   begin
    Ini_Text_Win;
            {[Dez]-[Hex]--Funktion---------------v     [Dez]-[Hex]--Funktion---------------v'}
    write ('    0     0   Keine Funktion               128    80   Daten lesen              ');
    write ('    1     1   Schalter auf Standby (Reset) 129    81   Istwert 1 lesen          ');
    write ('    2     2   GerÑt einschalten            130    82   Istwert 2 lesen          ');
    write ('    3     3   GerÑt ausschalten            131    83   Istwert 3 lesen          ');
    write ('    4     4   PolaritÑt + setzen           132    84   Istwert 4 lesen          ');
    write ('    5     5   PolaritÑt - setzen           133    85   Istwert 5 lesen          ');
    write ('    6     6   Sollwert  1 setzen           134    86   Istwert 6 lesen          ');
    write ('    7     7   Sollwert  2 setzen           135    87   Istwert 7 lesen          ');
    write ('    8     8   Sollwert  3 setzen           136    88   Istwert 8 lesen          ');
    write ('    9     9   Sollwert  4 setzen           137    89   Echo-Sollwert rÅcklesen  ');
    write ('   10     A   Sollwert  5 setzen           138    8A   frei                     ');
    write ('   11     B   Sollwert  6 setzen           139    8B   .                        ');
    write ('   12     C   Sollwert  7 setzen           140    8C   .                        ');
    write ('   13     D   Sollwert  8 setzen           141    8D   frei                     ');
    write ('   14     E   Wait                         142    8E   Piggy-Back Ident.        ');
    write ('   15     F   Release                      143    8F   Datenblock v. SD-uP lesen');
  end;

  procedure Code_Table2;
   begin
    Ini_Text_Win;
            {[Dez]-[Hex]--Funktion---------------v     [Dez]-[Hex]--Funktion---------------v'}
    write ('   16    10   Datenbus Setzen              144    90   Datenbus lesen           ');
    write ('   17    11   Adressbus setzen             145    91   GerÑtedaten 1 lesen      ');
    write ('   18    12   Set_INR_Maske                146    92   GerÑtedaten 2 lesen      ');
    write ('   19    13   Echo-Sollwert setzen         147    93   GerÑtedaten 3 lesen      ');
    write ('   20    14   GerÑtefunktion  1            148    94   GerÑtedaten 4 lesen      ');
    write ('    |     |         |         |            149    95   GerÑtedaten 5 lesen      ');
    write ('    |     |         |         |            150    96   GerÑtedaten 6 lesen      ');
    write ('   39    27   GerÑtefunktion 20            151    97   GerÑtedaten 7 lesen      ');
    write ('   40    28   Status 1 anfordern           152    98   GerÑtedaten 8 lesen      ');
    write ('   41    29   Status 2 anfordern           153    99   frei                     ');
    write ('   42    2A   Status 3 anfordern           .           .                        ');
    write ('   43    2B   SIS_12 Betrieb               .           .                        ');
    write ('   44    2C   SIS_18 Betrieb               .           .                        ');
    write ('   45    2D   GerÑtefunktion 21            .           .                        ');
    write ('    |     |         |         |            .           .                        ');
    write ('    |     |         |         |            .           .                        ');
    write ('   94    5E   GerÑtefunktion 70            .           .                        ');
    write ('   95    5F   frei                         .           .                        ');
    write ('    .         .                            .           .                        ');
    write ('    .         .                            .           .                        ');
    write ('   116   74   frei                         191    BF   frei                   ');
   end;

  procedure Code_Table3;
   begin
    Ini_Text_Win;
            {[Dez]-[Hex]--Funktion---------------v     [Dez]-[Hex]--Funktion---------------v'}
    write ('   117   75   Reset SEL-Error (v. Piggy)   192    C0   Status-Byte 1 lesen      ');
    write ('   118   76   Reset HI-Interlock Status    193    C1   Status-Byte 2 lesen      ');
    write ('   119   77   Reset HI-INL (vom Rechner)   194    C2   Status-Byte 3 lesen      ');
    write ('   120   78   Set   HI-INL (vom Rechner)   195    C3   Status-Byte 4 lesen      ');
    write ('   121   79   Reset HI-INL Enable          196    C4   frei                     ');
    write ('   122   7A   Set   HI-INL Enable          .           .                        ');
    write ('   123   7B   Reset HI-INL Gate            .           .                        ');
    write ('   124   7C   Set   HI-INL Gate            200    C8   frei                     ');
    write ('   125   7D   Reset RCV-Error (VW Test)    201    C9   * Interrupt-Maske  lesen ');
    write ('   126   7E   Reset Broadcast              202    CA   * Ctrl-Register    lesen ');
    write ('   127   7F   Set   Broadcast              203    CB   * Maske HI-Interl  lesen ');
    write ('                                           204    CC   * IFK-Identcode    lesen ');
    write ('----- Ende der Read-Functioncodes ------   205    CD   * IFK-EPLD-Version lesen ');
    write ('    [ab 128 (80 Hex) WRITE-Functions]      206    CE   frei                     ');
    write ('                                           .           .                        ');
    write ('                                           223    DF   frei                     ');
    write ('                                           224    E0   # Piggy Identcode lesen  ');
    write ('                                           225    E1   # Piggy EPLD-Vers.lesen  ');
    write ('  Legende:                                 226    E2   frei                     ');
    write ('  * Register auf der Interface-Karte       .           .                        ');
    write ('  # Register auf dem Piggy                 255    FF   frei                    ');
   end;
  procedure Fct_Headline;
   begin
    Ini_Headl_Win;
    GotoXY(01,01);
    write('SCHREIBEN (SE->IFK)          Funktioncodes [13.07.1995]          LESEN (IFK->SE)');
    GotoXY(01,02);
    write(' [Dez]-[Hex]--Funktion---------------v    [Dez]-[Hex]--Funktion---------------v');
    ini_text_win;
    Ini_Msg_Win;
    Write ('Weiter mit <Space>    oder    E[X]it ');
    Set_Text_Win;
   end;

  begin
    Fct_Headline;
    Code_Table1;
    repeat until KeyPressed;
    Ch := ReadKey;
    if Ch in ['x','X']then Goto 99;

    Fct_Headline;
    Code_Table2;
    repeat until KeyPressed;
    Ch := ReadKey;
    if Ch in ['x','X']then Goto 99;

    Fct_Headline;
    Code_Table3;
    repeat until KeyPressed;
    Ch := ReadKey;
    if Ch in ['x','X']then Goto 99;

99:
  end;


 PROCEDURE Mil_Rd_HS_Status;
  Label 99;
  VAR read_data,fct_code : WORD;
      MilErr : TMilErr;
      Fct    : TFct;

   PROCEDURE show_stat_reg;
    Begin
     Mil.Rd (read_data, Fct, MilErr);
     if MilErr  <> No_Err then
      begin
       GotoXY(28, 14); write ('    ');
       GotoXY(22, 16);
       write('   Read Error!!    ');
      end
     else
      begin  {kein Timeout}
       GotoXY(28, 14);  write(hex_word(read_data));
       Hex_Bin_Str (read_data,bit16_str);
       GotoXY(22, 16);  write(bit16_str);
      end;
    End;

  Begin
    Ini_Text_Win;
    Displ_HS_Status;  {     displ_HS_mask; }

    set_text_win;

    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Fct_Rd_HS_Status;

    transf_cnt := 0;
    timout_cnt := 0;

    GotoXY(02,03); write('  Achtung: Diese Funktion nur mit der "neuen" IFC-Karte (z.B. FG 380.200)!!');

    GotoXY(15,06); write('----- Lese Hochstrom-Interlock-Maske von der IFC-Karte -----');
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
 End; {Mil_Rd_HS_Status}


 PROCEDURE Mil_Rd_HS_Ctrl;
  Label 99;
  VAR read_data,fct_code : WORD;
      MilErr : TMilErr;
      Fct    : TFct;

   PROCEDURE show_stat_reg;
    Begin
     Mil.Rd (read_data, Fct, MilErr);
     if MilErr  <> No_Err then
      begin
       GotoXY(28, 14); write ('    ');
       GotoXY(22, 16);
       write('   Read Error!!    ');
      end
     else
      begin  {kein Timeout}
       GotoXY(28, 14);  write(hex_word(read_data));
       Hex_Bin_Str (read_data,bit16_str);
       GotoXY(22, 16);  write(bit16_str);
      end;
    End;

  Begin
    Ini_Text_Win;
    Displ_HS_Ctrl;
    set_text_win;

    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Fct_Rd_HS_Ctrl;

    transf_cnt := 0;
    timout_cnt := 0;

    GotoXY(02,03); write('  Achtung: Diese Funktion nur mit der "neuen" IFC-Karte (z.B. FG 380.200)!!');

    GotoXY(15,06); write('----- Lese Hochstrom-Ctrl-Register von der IFC-Karte -----');
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
 End; {Mil_Rd_HS_Ctrl}


 PROCEDURE Mil_Echo;
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
      Fct.B.Fct := Fct_Rd_Echo;
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

    GotoXY(10,03); write('  MIL-ECHO-Funktion mit der "neuen" IFC-Karte oder MIL-Monitor!!');
    GotoXY(06,04); write('[Daten (0000 .. FFFF) im Loop zur IFC: schreiben/lesen und ÅberprÅfen]');
    GotoXY(4,07);
    write('Achtung: Test benîtigt IFC-Karte mit Fct-Code 13H u. 89H (z.B. FG 380.200)');

    GotoXY(20,08);
    Fct.B.Fct := Fct_Wr_Echo;
    write  ('Wr-Fct-Word: ', hex_word(Fct.W),'[H]     ');
    Fct.B.Fct := Fct_Rd_Echo;
    write  ('Rd-Fct-Word: ', hex_word(Fct.W),'[H]');

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

       Fct.B.Fct := Fct_Wr_Echo;
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
 End; {Mil_Echo}


 PROCEDURE Mil_HS_Stat_Cmd;
  Label 99;
  const S_Text = 20;
        S_Data = S_Text + 14;
        Z_Start= 4;

  VAR read_data,fct_code : WORD;
      MilErr : TMilErr;
      Fct    : TFct;
      Fct_HS : TFct;

   PROCEDURE show_stat_reg;
    Begin
     Set_Text_Win;
     Mil.Rd (read_data, Fct, MilErr);
     if MilErr  <> No_Err then
      begin
       GotoXY(S_Data+9, Z_Start+1); write ('    ');
       GotoXY(S_Data+2, Z_Start+2); write('   Read Error!!    ');
      end
     else
      begin  {kein Timeout}
       GotoXY(S_Data+9, Z_Start+1);  write(hex_word(read_data));
       Hex_Bin_Str (read_data,bit16_str);
       GotoXY(S_Data+2, Z_Start+2);  write(bit16_str);
      end;
    End;

  Begin
    Ini_Text_Win;
    Displ_HS_Status;
    Displ_HS_Cmd;
    set_text_win;
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Fct_Rd_HS_Status;

    transf_cnt := 0;
    timout_cnt := 0;
    GotoXY(03,01); write('  Achtung: Diese Funktion nur mit der "neuen" IFC-Karte (z.B. FG 380.200)!!');
    GotoXY(07,02); write('  Lese Status HS-Interlock mit Fct_Code CB[Hex] bzw. Sende Fct-Codes ');

    GotoXY(S_Text,Z_Start);      write('Rd_Stat_Cnt   :');
    GotoXY(S_Text,Z_Start+1);    write('Stat-Data[Hex]:');
    GotoXY(S_Text,Z_Start+2);    write('Stat-Data[Bin]:');
    GotoXY(S_Text+16,Z_Start+3); write('MSB             LSB');

    GotoXY(01,8);  write('HS-Kommandos');
    GotoXY(72,8);  write('HS-Status');

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
      GotoXY(S_Data+1,Z_Start); write(transf_cnt:12);
      show_stat_reg;
    until KeyPressed or (Ch = ' ');

    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> , [F]ct-Code, Ende mit [X]');
       repeat until KeyPressed;
      end;
    Ch := ReadKey;

    if Ch in ['f','F'] then
      begin
       Set_Text_Win;
       GotoXY(5, 22);
       write ('Welchen Write-Function-Code [01..7F] ??');
       Fct_HS.B.Adr := Ifc_Test_Nr;
       Fct_HS.B.Fct := ask_hex_byte;
       Set_Text_Win;
       GotoXY(5, 22); ClrEol;
       Mil.WrFct (Fct_HS, MilErr);
       show_stat_reg;
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> , [F]ct-Code, Ende mit [X]');
       Ch := ' ';
      end;
   until Ch in ['x','X'];
   99:
 End; {Mil_HS_Stat_Cmd}

 procedure Mil_Detect_Ifc_Compare;
  label 99;
  CONST start_zeile =  3;
        start_spalte = 5;
        zeile_max    = 18;
        spalte_offset= 20;
        spalte_akt   = 45;
        Online_Max   = 80;
        Disp_Index_Max = 60;     {Maximal darstellbare IFC}

  type
    TOnline_Stat = (On, Off);

    TIfb_Ary = record
                 Dis_Index   : Word;           {relative Position auf Display}
                 Err_Flag    : Boolean;                         {Summenfehler}
                 Adr_Soll    : Word;
                 Adr_Ist     : Word;
                 Adr_Diff_Cnt: LongInt;                            {Soll<>Ist}
                 Adr_Ist_Diff: LongInt;     {Istwert diff zum vorherigen Wert}
                 Stat_Act    : TOnline_Stat;
                 Stat_Old    : TOnline_Stat;
                 Stat_Err_Cnt: LongInt;               {Anzahl Status énderung}
               end;

  var
      Ifb_Adr    : Word;
      Ifb_Min    : Byte;
      Ifb_Max    : Byte;
      Ifb_Neu    : Byte;
      Ifb_Alt    : Byte;
      Ifb_Ary    : array [0..255] OF TIfb_Ary;

      Zeile,Spalte: BYTE;
      Hex_Str    : STRING[10];
      I,N,L      : WORD;
      RetAdr     : Byte;
      Test_Cnt   : LongInt;
      Disp_Index_Actuell : Byte;
      Disp_Sel_Adr: Byte;        {Selektive Anzeige fÅr eine IFC-Adr}


  procedure Ary_Init;
    var I : Byte;
    begin
      Test_Cnt := 0;
      Ifb_Min  := 0;
      Ifb_Max  := 0;
      Ifb_Neu  := 0;
      Ifb_Alt  := 0;

      for I := 0 to 255 do
       begin
         Ifb_Ary[I].Err_Flag    := False;
         Ifb_Ary[I].Dis_Index   := 0;
         Ifb_Ary[I].Adr_Ist     := $FFFF;
         Ifb_Ary[I].Adr_Soll    := $FFFF;
         Ifb_Ary[I].Adr_Diff_Cnt:= 0;
         Ifb_Ary[I].Adr_Ist_Diff:= 0;
         Ifb_Ary[I].Stat_Act    := Off;
         Ifb_Ary[I].Stat_Old    := Off;
         Ifb_Ary[I].Stat_Err_Cnt:= 0;
       end;
    end;

   procedure Update_Ifb_Online;
    var Ifb : Byte;
        OnlineErr : TOnlineErr;
    begin
      for Ifb := 0 TO 255 DO
        begin
          mil.ifc_online (Ifb, RetAdr, OnlineErr);
          If OnlineErr = NoErr then   {Es meldet sich eine Karte online}
            begin
              Ifb_Neu := Ifb_Neu + 1;
              Ifb_Ary[Ifb].Stat_Act := On;               {Status Online}
              Ifb_Ary[Ifb].Adr_Soll := Ifb;              {Soll-Adr festhalten}
              {Ist die RetAdr anders als die bisherige Return-Adr?}
              {Sinnvoll nur, wenn schon Daten fÅr diese Abfrage vorhanden}
              {Displ_Index gibt Position der Anzeige an; bei 0 ist Adr noch nicht auf Display}
              if Ifb_Ary[Ifb].Dis_Index <> 0 then   {Displ-Anzeige fÅr diese Adr vorhanden!}
               begin
                 if Ifb_Ary[Ifb].Adr_Ist <> RetAdr then
                  begin
                    Ifb_Ary[Ifb].Adr_Ist_Diff:= Ifb_Ary[Ifb].Adr_Ist_Diff + 1;  {Ist-Adr hat sich geÑndert}
                    Ifb_Ary[Ifb].Err_Flag := True;
                  end;
                     {Ifc war schon auf Display; ist jetzt wieder Online -> Error}
                 if Ifb_Ary[Ifb].Stat_Old = Off then
                    Ifb_Ary[Ifb].Stat_Err_Cnt := Ifb_Ary[Ifb].Stat_Err_Cnt + 1;
               end
              else
               begin  {Diese IFC-Adr noch nicht auf dem Display}
                 Disp_Index_Actuell     := Disp_Index_Actuell + 1;
                 Ifb_Ary[Ifb].Dis_Index := Disp_Index_Actuell; {Ifc-Adr an diese Displ.Pos}
               end;

              Ifb_Ary[Ifb].Adr_Ist  := RetAdr;    {neue Ist-Adr speichern}
              if Ifb <> RetAdr then               {Soll <> Ist Adr}
                begin
                  Ifb_Ary[Ifb].Adr_Diff_Cnt := Ifb_Ary[Ifb].Adr_Diff_Cnt + 1;
                  Ifb_Ary[Ifb].Err_Flag := True;
                end;
              Ifb_Ary[Ifb].Stat_Old := On;                    {Status Online}
            end  {if online NoErr}
          else
            begin  {Online_err: Diese karte meldet sich nicht!}
              if Ifb_Ary[Ifb].Stat_Old = On then
                begin
                  Ifb_Ary[Ifb].Err_Flag := True;                {Status Change}
                  Ifb_Ary[Ifb].Stat_Err_Cnt:= Ifb_Ary[Ifb].Stat_Err_Cnt + 1;
                end;
              Ifb_Ary[Ifb].Stat_Act := Off;                   {Status Offline}
              Ifb_Ary[Ifb].Stat_Old := Off;                   {Status Offline}
            end;  {if online Err}
        end; {FOR}
    end; {Update_Ifb_Online; }

  procedure Displ_Ifb_Ary;
   var I,N : Byte;
       DZeile,DSpalte: Byte;
   begin
{
Ifb_Ary[10].Dis_Index := 10;
Ifb_Ary[10].Adr_Ist   := 0;
}
{
for N := 5 to 40do
  begin
    Ifb_Ary[N].Adr_Ist   := N;
    Ifb_Ary[N].Dis_Index := N;
    if (n mod 4)=0 then
     begin
       Ifb_Ary[N].Err_Flag := True;
     end
    else
     Ifb_Ary[N].Adr_Soll := N+0;
  end;
}
    Set_Text_Win;
    TextColor(black);
    for I := 0 to 255 do
     begin
       if Ifb_Ary[I].Dis_Index > 0 then  {Index > 0: anzeigen}
        begin
          if (Ifb_Ary[I].Dis_Index mod Zeile_Max) = 0 then
            DZeile := Start_Zeile + 1
          else
            DZeile  := (Ifb_Ary[I].Dis_Index mod Zeile_Max) + Start_Zeile;

          DSpalte := Start_Spalte + (Ifb_Ary[I].Dis_Index DIV Zeile_Max) * Spalte_Offset;

          if Ifb_Ary[I].Err_Flag then  TextColor(Blink);
          if Ifb_Ary[I].Adr_Ist <> Ifb_Ary[I].Adr_Soll then
           begin
             TextColor(Red);
             GotoXY (DSpalte, DZeile);
             write(hex_Byte(Ifb_Ary[I].Adr_Soll));
           end;

          if Ifb_Ary[I].Stat_Act = Off then
           begin
             TextColor(Red);
           end;

          GotoXY (DSpalte+9, DZeile); write(hex_Byte(Ifb_Ary[I].Adr_Ist));  {Istadr}
          TextColor(black);                           {Setze Schriftfarbe}
        end;
     end; {for I}

     {FÅr eine ausgewÑhlte IFC-Adr alle Info's anzeigen}
     TextColor(Magenta);
     GotoXY (01, 22);
     write ('IFC: ');     write(hex_Byte(Disp_Sel_Adr));
     write ('  SAdr:');   write(hex_Byte(Ifb_Ary[Disp_Sel_Adr].Adr_Soll));
     write (' IAdr:');    write(hex_Byte(Ifb_Ary[Disp_Sel_Adr].Adr_Ist));
     write ('  EBit:');   if Ifb_Ary[Disp_Sel_Adr].Err_Flag    then write('1') else write('0');
     write ('  Line:');   if Ifb_Ary[Disp_Sel_Adr].Stat_Act = On then write('On ') else write('Off');
     write ('  S-I?: ');  write(Ifb_Ary[Disp_Sel_Adr].Adr_Diff_Cnt:4);
     write ('  IAd?: ');  write(Ifb_Ary[Disp_Sel_Adr].Adr_Ist_Diff:4);
     write ('  Sta?: ');  write(Ifb_Ary[Disp_Sel_Adr].Stat_Err_Cnt:4);
     ClrEol;
   end; {Displ_Ifb_Ary}

 begin             {Begin ifb_detect and compare}
    ini_text_win;
    Test_Cnt := 0;
    Disp_Sel_Adr := 0;
    Disp_Index_Actuell := 0;
    Ary_Init;
    GotoXY (10, 02);
    writeln ('Start der Abfrage durch Eingabe gemÑ· unterster Zeile!!');

    GotoXY(1,1);             Write ('TestCount: ',Test_Cnt);
    GotoXY(20,1);            Write('IFC-Karten am MIL-Bus ->');
    GotoXY(spalte_akt+00,1); Write('Neu:');
    GotoXY(spalte_akt+09,1); Write('Alt:');
    GotoXY(spalte_akt+18,1); Write('Min:');
    GotoXY(spalte_akt+27,1); Write('Max:');

    TextColor(Brown);
    GotoXY(2,2);  write(' Soll--ADR--Ist      Soll--ADR--Ist      Soll--ADR--Ist      Soll--ADR--Ist');
    GotoXY(2,3);  write(' [Hex]....[Hex]      [Hex]....[Hex]      [Hex]....[Hex]      [Hex]....[Hex]');
    TextColor(Black);

    Update_Ifb_Online;
    Ifb_Alt:= Ifb_Neu;
    Ifb_Min:= Ifb_Neu;
    Ifb_Max:= Ifb_Neu;

    Ch := ' ';
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> , <W>atch IFC    Ende mit [X]');
{       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
}       repeat until KeyPressed;
       Ch := ReadKey;
       if  Ch in ['x','X'] then Goto 99;
      end;

   repeat
    repeat
     Set_Text_win;
     Ifb_Neu := 0;
     zeile := start_zeile;
     spalte:= start_spalte;
     Update_Ifb_Online;
     Displ_Ifb_Ary;

     if Ifb_Neu > Ifb_Max then Ifb_Max := Ifb_Neu;
     if Ifb_Neu < Ifb_Min then Ifb_Min := Ifb_Neu;

     Test_Cnt := Test_Cnt +1;
     GotoXY(12,1);             write (Test_Cnt);
     GotoXY(spalte_akt+04,01); write('   ');        {Lîsche alten Wert}
     GotoXY(spalte_akt+04,01); write(Ifb_Neu:3);
     GotoXY(spalte_akt+13,01); write('   ');
     GotoXY(spalte_akt+13,01); write(Ifb_Alt:3);
     GotoXY(spalte_akt+22,01); write('   ');
     GotoXY(spalte_akt+22,01); write(Ifb_Min:3);
     GotoXY(spalte_akt+31,01); write('   ');
     GotoXY(spalte_akt+31,01); write(Ifb_Max:3);

     Mil.Timer2_Wait(4000);
    until KeyPressed or (Ch = ' ');

    if Ch = ' ' then
      begin
       Ifb_Alt := Ifb_Neu;
       Ini_Msg_Win;
{       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> , <W>atch IFC    Ende mit [X]');
}
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> , <W>atch IFC    Ende mit [X]');
       repeat until KeyPressed;
      end;
    Ch := ReadKey;

    if Ch in ['w','W'] then
      begin
       Set_Text_Win;
       GotoXY (01, 22);
       write ('Daten von welcher IFC-Adr beobachten [00..FF] ??'); ClrEol;
       Disp_Sel_Adr := ask_hex_byte;
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> , <W>atch IFC    Ende mit [X]');
      end;
   until Ch in ['x','X'];

 99:  TextColor(White);
  end; {Mil_Detect_Ifc_Compare}

procedure Convert_Hex_Volt;
 LABEL 99;
 VAR
   sollwert : Word;
   ch : char;
   Max_Wert : Real;
   V_Eingabe: Boolean;

   Begin
    V_Eingabe := True;
    Ini_Text_Win;
    Ini_Msg_Win;
    Write(' [H]ex oder [V]olt-Eingabe    bzw. Ende mit [X]');
    repeat until KeyPressed;
    Ch := ReadKey;
    if  Ch in ['x','X'] then Goto 99;
    if  Ch in ['h','H'] then V_Eingabe := False;;
    if  Ch in ['v','V'] then V_Eingabe := True;

    max_wert := 10.000;

    Ch := ' ';
    repeat
     repeat
       Ini_Text_Win;
       if V_Eingabe then     {Volt-Eingabe gewÅnscht}
        begin
          Sollwert := Rd_Real_Sw (10.0);
        end
       else                   {Hex-Eingabe gewÅnscht}
        begin
          Sollwert := Ask_Data;
        end;

       Ini_Text_Win;
       Writeln ('         [Hex]     [Volt]  ');
       Write   ('         ');
       write(hex_word(Sollwert));
       Write   ('     ');
       Write_Real_10V_Bipol (Sollwert); writeln;

       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, [W]echseln Hex <-> Volt,  Ende mit [X]');
       repeat until KeyPressed;

     until KeyPressed or (Ch = ' ');

     if Ch = ' ' then
       begin
        Ini_Msg_Win;
        Write('Stop/Single Step mit <SPACE>, [W]echseln Hex <-> Volt,  Ende mit [X]');
        repeat until KeyPressed;
       end;

     Ch := ReadKey;
     if Ch in ['w','W'] then V_Eingabe := not (V_Eingabe);
    until Ch in ['x','X'];
    99:
end; {Convert_Hex_Volt}


{xxx}  {Ab hier sollten User-Erweiterungen beginnen!!}
 Procedure Mil_Fct_Doppel;
  LABEL 99;
   VAR
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct_1  : TFct;
     Fct_2  : TFct;

   Begin
    Fct_1.B.Adr := Ifc_Test_Nr;
    Fct_2.B.Adr := Ifc_Test_Nr;

    Ini_Text_Win;
    GotoXY(5, 22);
    write ('Welchen Function-Code 1 ??');
    Fct_1.B.Fct := ask_hex_byte;

    Ini_Text_Win;
    GotoXY(5, 22);
    write ('Welchen Function-Code 2 ??');
    Fct_2.B.Fct := ask_hex_byte;

    Ini_Text_Win;
    GotoXY(15,05); write('----- Schreibe zwei Functioncodes auf den MIL-BUS  -----');
    GotoXY(02,06); write('Optimiert auf maximale Folgefrequenz. Daher keine Anzeige des Transfercounts!! ');

    GotoXY(25,08); write  ('Function-Word 1 (Fct + Adr): ',hex_word(Fct_1.W),' [H]');
    GotoXY(25,09); write  ('Function-Word 2 (Fct + Adr): ',hex_word(Fct_2.W),' [H]');

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

    if ((Portw[Port_Stat] and Stat_Wrt_Rdy) = Stat_Wrt_Rdy) then
       Portw[Port_Mode]:= Cmd_Mode;

     repeat
      repeat
       if ((Portw[Port_Stat] and Stat_Wrt_Rdy) = Stat_Wrt_Rdy) then
         Portw[Port_Data] := Fct_1.W; { Funktioncode schreiben }

       if ((Portw[Port_Stat] and Stat_Wrt_Rdy) = Stat_Wrt_Rdy) then
         Portw[Port_Data] := Fct_2.W; { Funktioncode schreiben }
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
End; {Mil_Fct_Doppel}

 Procedure Mil_Fct_30us;
  LABEL 99;
   VAR
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct_1  : TFct;
     Fct_2  : TFct;

   Begin
    Fct_1.B.Adr := Ifc_Test_Nr;
    Fct_2.B.Adr := Ifc_Test_Nr;

    Ini_Text_Win;
    GotoXY(5, 22);
    write ('Welchen Function-Code 1 ??');
    Fct_1.B.Fct := ask_hex_byte;

    Ini_Text_Win;
    GotoXY(15,05); write('----- Schreibe Functioncode im Abstand von 30 us auf den MIL-BUS  -----');
    GotoXY(02,06); write('Optimiert auf maximale Folgefrequenz. Daher keine Anzeige des Transfercounts!! ');

    GotoXY(25,08); write  ('Function-Word 1 (Fct + Adr): ',hex_word(Fct_1.W),' [H]');

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

    if ((Portw[Port_Stat] and Stat_Wrt_Rdy) = Stat_Wrt_Rdy) then
       Portw[Port_Mode]:= Cmd_Mode;

     repeat
      repeat
       if ((Portw[Port_Stat] and Stat_Wrt_Rdy) = Stat_Wrt_Rdy) then
         Portw[Port_Data] := Fct_1.W; { Funktioncode schreiben }

       Mil.Timer2_Wait(3);                                   { Wartet mit Timer2 }
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
End; {Mil_Fct_Doppel}

 PROCEDURE Mil_Wr_Fctcode_00;
 Label 99;
 VAR
    MilErr : TMilErr;
    Fct    : TFct;

    procedure Ask_Ifc;
     VAR answer : CHAR;
     Begin
       status := FALSE;
       WHILE NOT status DO
        Begin
         Ini_Text_Win;
         GotoXY(5, 22);
         write ('Welche IFC-Karten-Adr. testen?');
         ifc_test_nr := ask_hex_byte;
         IF ifc_test_nr IN [0..255] THEN status := TRUE;
        End;
     End; {ask_ifc}


   Begin
    Ask_Ifc;
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

 PROCEDURE Mil_Wr_Fctcode_Data_00 (Write_Data: WORD);
 Label 99;
 VAR
    MilErr : TMilErr;
    Fct    : TFct;

    procedure Ask_Ifc;
     VAR answer : CHAR;
     Begin
       status := FALSE;
       WHILE NOT status DO
        Begin
         Ini_Text_Win;
         GotoXY(5, 22);
         write ('Welche IFC-Karten-Adr. testen?');
         ifc_test_nr := ask_hex_byte;
         IF ifc_test_nr IN [0..255] THEN status := TRUE;
        End;
     End; {ask_ifc}


   Begin
    Ask_Ifc;
    Ini_Text_Win;
    GotoXY(5, 22);
    write ('Welchen Function-Code ??');
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := ask_hex_byte;
    Ini_Text_Win;

    transf_cnt := 0;
    GotoXY(19,05); write('----- Schreibe Function-Code zur IFC-Karte -----');
    GotoXY(25,08); write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
{    GotoXY(25,08); write  ('Function: ',hex_word(Fct.W),' [H]');
}    GotoXY(25,09); write  ('Data    : ',hex_word(Write_Data),' [H]');

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
      Mil.Wr (write_data, Fct, MilErr);

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
  End; {Mil_Wr_Fctcode_Data_00}





 PROCEDURE Mil_Adr_Test;    {mit 2 IFC-Karten und spezieller Backplane}
  label 99;
  CONST start_zeile = 4;
        start_spalte =5;
        zeile_max    =22;
        spalte_offset=20;

  type TIfb  = record
                Online : Boolean;
                SI_Err : Boolean;
                Ist_Adr: Byte;
               end;

  VAR ifc_total  : WORD;
      ifb_online : ARRAY[1..255] OF TIfb;
      ifb_adr    : WORD;
      zeile,spalte: BYTE;
      hex_str    : STRING[10];
      i,n        : WORD;
      RetAdr     : Byte;
      OnlineErr  : TOnlineErr;
      MilErr : TMilErr;
      Fct    : TFct;

  procedure Disp_Online_Array;
    var x : Byte;
    begin
      ifc_total := 0;
      for x := 1 to 255 do
       begin
        if ifb_online[x].Online  then
          begin
           if ifb_online[x].SI_Err then
            begin
             TextColor(Red);
             GotoXY (spalte  , zeile);   write(hex_Byte(x));
             GotoXY (spalte+8, zeile);   write(hex_Byte(ifb_online[x].Ist_Adr ));
             TextColor(Black);
             zeile := zeile + 1;
             ifc_total := ifc_total + 1;
            end;
          end
        else
          begin                                               {online = False}
            GotoXY (spalte+8, zeile);   write(hex_Byte(x));
            ifc_total := ifc_total + 1;
            zeile := zeile + 1;
        end;

       if (zeile > zeile_max )  then
        begin
          spalte := spalte + spalte_offset;
          zeile  := start_zeile;
        end;
       if ifc_total > 75 then  x := 255;
      end; {for}

     if ifc_total > 75 then
      begin
       GotoXY(71,01); write('>',ifc_total:3);
      end
     else
      begin
       GotoXY(71,01); write(' ',ifc_total:3);
      end;
   end; {Disp_Online_Array}

  Begin
    ini_text_win;
    GotoXY (30, 02);
    writeln ('MIL-ADRESSEN-TEST: ');
    writeln ('Funktionsweise: Mit einer speziellen Backplane fÅr 2 SteckplÑtze werden Åber');
    writeln ('eine IFC-Karte [Adresse 00] die Adressen 01..FF fÅr die zu testende Karte   ');
    writeln ('vorgegeben. Es wird geprÅft, ob fÅr jede Vorgabe-Adr sich die Testkarte');
    writeln ('"ONLINE" meldet. ');

    Ch := ' ';
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyPressed;
       Ch := ReadKey;
       if  Ch in ['x','X'] then Goto 99;
      end;
    Ch := ' ';

   repeat
    repeat
      Ini_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      zeile := start_zeile;
      spalte:= start_spalte;
      ini_text_win;

      GotoXY(01,1); ClrEol;
      TextColor(Black); ClrEol;
      write('Finde folgende IFC-Adressen'); TextColor(Red); write(' nicht');
      TextColor(Black);  write(' oder Soll <> Ist-Adresse --> Total: ');

{      write('Finde folgende IFC-Adressen nicht oder Soll <> Ist-Adresse!    Total: ');
}     TextColor(Brown);
      GotoXY(2,2);  write(' Soll--ADR--Ist      Soll--ADR--Ist      Soll--ADR--Ist      Soll--ADR--Ist');
      GotoXY(2,3);  write(' [Hex]....[Hex]      [Hex]....[Hex]      [Hex]....[Hex]      [Hex]....[Hex]');
      TextColor(Black);

      FOR Ifb_Adr := 1 TO 255 DO
        Begin
          {write Test-Adr auf Karte 2}
          Fct.B.Adr := 00;
          Fct.B.Fct := 06;

          Mil.Wr (Ifb_Adr, Fct, MilErr);            {Test-Adr zur IFC-Karte 0}
          Mil.Timer2_Wait (10);                                   { Wartet mit Timer2 }
          Mil.Ifc_Online (Ifb_Adr, RetAdr, OnlineErr);

          If OnlineErr = NoErr then
            begin
             ifb_online[Ifb_Adr].Online := True;
             ifb_online[Ifb_Adr].SI_Err := False;

             if Ifb_Adr <> RetAdr then
              begin
                ifb_online[Ifb_Adr].SI_Err := True;
                ifb_online[Ifb_Adr].Ist_Adr:= RetAdr;
              end
            end
           else
            begin        {Karte nicht Online}
              ifb_online[Ifb_Adr].Online := False;
              ifb_online[Ifb_Adr].SI_Err := False;
            end;
        End; {FOR}

       Disp_Online_Array;
    Mil.Timer2_Wait(70000);
    until KeyPressed or (Ch = ' ');
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyPressed;
       Ini_Text_Win;
      end;
    Ch := ReadKey;
   until Ch in ['x','X'];
   99:
 End; {Mil_Adr_Test}

Procedure Mil_Fct_Test;
  LABEL 99;
   VAR
     Bit16_Strg: Str19;
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;
     I          : Byte;

  begin
   I := 0;
   Ini_Text_Win;
   Ch := ' ';
   Fct.B.Adr := Ifc_Test_Nr;

   {Init Display}
   GotoXY(08,10);  Write('Transfer-Count: ');
{   GotoXY(08,11);  Write('Timeout       : '); }
   GotoXY(08,12);  Write('Funktion [Hex]: ');

   Ini_Msg_Win;
   Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');

   I := 1;
   repeat
    repeat
      Set_Text_win;
      Mil_Timout := False;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,10);  Write(Transf_Cnt:10);

      Fct.B.Fct := TstFkt[I];
      GotoXY(33,12);  Write(Hex_Byte(Fct.B.Fct));
      Mil.WrFct (Fct, MilErr);
{
      if MilErr <> No_err then
       begin
        Mil_Timout := True;
        Timout_Wr:= Timout_Wr +1;
        GotoXY(25,11);  write(timout_wr:10);
       end;
      GotoXY(25,11);  write(timout_wr:10);
}
     if  not (Ch = ' ') then
      begin
       Mil.Timer2_Set(Wait_Fkt);          { Startet Timer1: time*10us}
       repeat until Mil.Timeout2;
      end;

    if I >= FktMax then
     begin
      Ch := ' ';
      I := 1
     end
    else I := I + 1;

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
End; {mil_fct_test;}



BEGIN   { Hauptprogramm }
  Ifc_Test_Nr := 0;

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
     '1'      : begin
                  Mil_Detect_Ifc_Compare;
                end;
     '2'      : begin
                  if Check_Ifc_Adr then Mil_Rd_HS_Ctrl;
                end;
     '3'      : begin
                  if Check_Ifc_Adr then Mil_Rd_HS_Status;
                end;
     '4'      : begin
                  if Check_Ifc_Adr then Mil_Stat_All (Ifc_Test_Nr);
                end;
     '5'      : begin
                  Convert_Hex_Volt;
                end;
     '7'      : begin
                  if Check_Ifc_Adr then Mil_HS_Stat_Cmd;
                end;
     '9'      : begin
		  if Check_Ifc_Adr then Mil_Echo;
                end;
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
                  Functioncode_Table;
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
                 if Check_Ifc_Adr THEN
                  begin
		    Mil_Fct_Doppel;
                  end;
                end;
     'n', 'N' : begin
                 if Check_Ifc_Adr THEN
                  begin
		    Mil_Fct_30us;
                  end;
                end;
      'o', 'O' : begin
                  Mil_Wr_Fctcode_00;
                 end;
      'p', 'P' : begin
          	  Mil_Data := Ask_Data;
                  Mil_Wr_Fctcode_Data_00 (Mil_Data);
                 end;
      'q', 'Q' : begin
                  Mil_Adr_Test;
                 end;
      'r', 'R' : begin
		  if check_ifc_adr then Mil_Fct_Test
                 end;
          's', 'S' : begin
                     end;
          't', 'T' : begin
                     end;
    End; {CASE}
  UNTIL user_input in ['x','X'];
  Window(1, 1, 80, 25);
  TextBackground(Black);
  ClrScr;
END. {mil_base}

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


