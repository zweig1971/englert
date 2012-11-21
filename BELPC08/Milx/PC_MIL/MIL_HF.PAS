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
  08.02.96    Anpassung an mil_base
  05.02.97    Anzeige Bit 15 bei Istwert-Wert
  07.02.97    Im MenÅ M: F9 In Strahl schalten hinzugefÅgt
  12.02.97    Versenden von Events: Fct + Adr als Event!
  20.10.00    Et: neue compiliert
}

{$S-}
uses Crt, WinDos, Dos, Datech, Datech_0, Datech_1;    {spez. MIL-Routinen in Units Datech..}

CONST
 HF_Dta       = $0080;
 Wait_Test    = 50 * 100;  {max. 10,0 msec warten}
 Wait_Status  = 30000;  {0,3 sec}


 hardw_timer_timeout = 1000000;

 head_line =
      'Datentechnik                       MIL_HF    ' +
      '                       [20.10.2000]'+
      '                   UNILAC-HF EinzelReson. (Turbo_Pascal V7.0)';

TYPE
num_str = STRING[10];

procedure menue_win;
VAR answer: CHAR;
begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;            {Festliegender Teil des MenÅs: s. a. DATECH_0.PAS}
  TextColor(Blue);

  GotoXY(5, 14);
  Writeln('       [M]<-- HF-Kommandos u. Status lesen (C0H)          ');
  GotoXY(5, 15);
  Writeln('       [N]<-- SW Amplitude Lesen/Schreiben (84H/06H)      ');
  GotoXY(5, 16);
  Writeln('       [O]<-- SW Phase     Eingabe in Grad (07H)          ');
{
  GotoXY(5, 18);
  Writeln('       [P]<--        ');
}
  TextColor(Yellow);
  GotoXY(5, 17);
  Writeln('                     (Spezielle Testprogramme fÅrs Labor)                       ');
  TextColor(Black);
  GotoXY(5, 18);
  Writeln('       [Q]<-- HF-Kommandos                 (02..19H)                      ');
  GotoXY(5, 19);
  Writeln('       [R]<-- SW-Amp(06H) Hex/Bitshift    SW-Pha(07H) Data auto 0/1-->[U]');
  GotoXY(5, 20);
  Writeln('       [S]<-- SW-Pha(07H)    "            PhasSchi Li E/A (17/19H) -->[V]');
  GotoXY(5, 21);
  Write('       [T]<-- SW-Amp(06H) Data auto 0/1   PhasSchi Re E/A (18/19H) -->[W]');
  GotoXY(5, 22);
  Write('       [U]<-- Sende feste Eventfolge fÅr ER-Tests');

  ini_msg_win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
 End; {menue_win}

 procedure New_Ifc_Adr;
  VAR answer : CHAR;
  Begin
    status := FALSE;
    WHILE NOT status DO
     Begin
      Ifc_Test_Nr := Ask_Hex_Byte;
      IF ifc_test_nr IN [1..255] THEN status := TRUE;
     End;
  End; {ask_ifc}


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


Procedure Mil_Hf_SwAmpl (Test_Data: Word);
  LABEL 99;
  CONST HF_Fct = $06;

   VAR
     Bit16_Strg:  String[19];
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
     Bit16_Strg: String[19];
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
     Bit16_Strg: String[19];
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
     Bit16_Strg: String[19];
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
     Bit16_Str  : Str19 ;
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
   Hex_Bin_Str (Test_data, bit16_str);
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
     Bit16_Strg: Str19 ;
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
   Hex_Bin_Str (Test_data,bit16_strg);
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
  CONST HF_Fct_C0    = $C0;
        Spalte_Stat  = 50;
        Wait_Time    = 120000; {1 sec}
  VAR
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;
     bit16_str : Str19;

  procedure Ini_TastHf_Win;
   begin
    Window(02, 20, 40, 23);
    TextBackground(Green);
    ClrScr;
    TextColor(Yellow);
    GotoXY(01, 01); Write('F1: GenEin  F5: Quit    F9 :          ');
    GotoXY(01, 02); Write('F2: GenAus  F6: PhaLi   F10: IfcAdr   ');
    GotoXY(01, 03); Write('F3: HfEin   F7: PhaRe   F11: Strahl   ');
    GotoXY(01, 04); Write('F4: HfAus   F8: PhaStop F12: Pause    ');
    TextColor(Black);
   end;

  procedure Displ_C0_Stat;
   begin                            {Info-Anzeige der Bit-Belegung IFC-Status}
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
  end; {displ_ifc_stat}

  FUNCTION get_data: WORD;
    var rd_data : Word;
    Begin
     Fct.B.Fct := Fct_Rd_Stat0;
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


  type TSP_Mode = (Strahl, Pause);

  procedure S_P (Mode: TSP_Mode);
   var IW, SW : Word;
   begin
     Fct.B.Fct := Fct_Rd_Ist4;
     Fct.B.Adr := Ifc_Test_Nr;
     Mil.Rd (IW, Fct, MilErr);
     IF MilErr <> No_Err THEN
      begin
        Ini_Err_Win;
        Write ('ERROR: Fehler beim Istwert lesen!  Weiter mit <CR>  ');
        repeat until KeyEPRessed;
      end
     else
      begin
        Fct.B.Fct := Fct_Wr_Sw1;  {Write Sollwert}
        case Mode of
         Strahl : begin
                    SW := BitSet (IW,15);
                    Ini_Err_Win;
                    Write('Vorsicht: Bit15 = 1 -> Sender in Strahl! Kann Betrieb stîren.  Weiter [J/N]?: ');
                    repeat until KeyEPressed;
                    Ch := NewReadKey;
                    if (Ch in ['j','J']) then
                     begin
                       Mil.Wr (SW, Fct, MilErr);
                       Set_Text_Win;
                       GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                     end;
                  end;
         Pause  : begin
                    SW := BitClr (IW,15);
                    Ini_Err_Win;
                    Write('Vorsicht: Bit15 = 0 -> Sender in Pause!  Weiter [J/N]?: ');
                    repeat until KeyEPressed;
                    Ch := NewReadKey;
                    if (Ch in ['j','J']) then
                     begin
                       Mil.Wr (SW, Fct, MilErr);
                       Set_Text_Win;
                       GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                     end;
                  end;
        end; {case}
      end; {id MilErr}
   end; {S_P}

  begin
   Mil_Ask_Ifc;
   Ini_Text_Win;
   timout_rd := 0;
   Transf_Cnt:= 0;
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Rd_Stat0;

   {Init Display}
   GotoXY(22,03); Write('********** LESE HF-GERéTE-STATUS **********');
   GotoXY(08,05);  write  ('Read-Status  :  Function-Word (Fct + Adr): ');
   GotoXY(Spalte_Stat ,05);  write (hex_word(Fct.W),' [H]');

   Fct.B.Fct := 0; {Write Function noch unbestimmt}
   GotoXY(08,06);  write  ('Write-Command:  Function-Word (Fct + Adr): ');
   GotoXY(Spalte_Stat ,06);  write (hex_word(Fct.W),' [H]');

   GotoXY(08,10);  Write('Transfer-Count: ');
   GotoXY(08,11);  Write('Timeout       : ');
   GotoXY(08,13);  Write('Data     [Hex]: ');
   GotoXY(08,14);  write('Stat-Data[BIN]:');
   GotoXY(25,15);  write('MSB             LSB');
   GotoXY(25,10);  Write(Transf_Cnt:10);
   GotoXY(25,11);  write(timout_rd:10);


   TextColor(Brown);
   GotoXY(50, 08); Write ('Belegung HF-Status-Register: ');
   Displ_C0_Stat;

   Ini_TastHf_Win;
   Set_Text_Win;
   TextColor(Brown);
   GotoXY(02, 17); Write ('Belegung Funktionstasten: ');

   Ini_Msg_Win;
   Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
   Set_Text_Win;


   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
      repeat until KeyEPressed;
      Ch := NewReadKey;
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
         GotoXY(31,13);  write('    ');
         TextColor (Red);
         GotoXY(25, 14); write('    Read Error!!   ');
         TextColor (Black);
        End
      ELSE
        Begin
          GotoXY(31,13);  write(hex_word(read_data));
          Hex_Bin_Str (read_data,bit16_str);
          GotoXY(25, 14);  write(bit16_str);
        End;
      GotoXY(25,11);  write(timout_rd:10);
      Mil.Timer2_Wait(Wait_Status);
    until KeyEPressed or (Ch = ' ');

    if KeyEPressed then Ch := NewReadKey;
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
       repeat until KeyEPressed;
      end;

    if Ch = #0 then
     begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    Fct.B.Fct := 02;  {Generator ein}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                    Ini_Err_Win;
                    Write(' Generator EIN');
                    Mil.WrFct (Fct, MilErr);
                    Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                   end;

        Taste_F2 : begin
                    Fct.B.Fct := 03;  {Generator Aus}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                    Ini_Err_Win;
                    Write(' Generator AUS');
                    Mil.WrFct (Fct, MilErr);
                    Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                   end;

        Taste_F3 : begin
                    Fct.B.Fct := $14;  {HF Ein}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                    Ini_Err_Win;
                    Write(' Hf EIN');
                    Mil.WrFct (Fct, MilErr);
                    Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                   end;

        Taste_F4 : begin
                    Fct.B.Fct := $15;  {HF Aus}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                    Ini_Err_Win;
                    Write(' Hf AUS');
                    Mil.WrFct (Fct, MilErr);
                    Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                   end;

        Taste_F5 : begin
                    Fct.B.Fct := $16;  {Quit}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                    Ini_Err_Win;
                    Write(' QUIT');
                    Mil.WrFct (Fct, MilErr);
                    Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                   end;

        Taste_F6 : begin
                    Fct.B.Fct := $17;  {Phase Links}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                    Ini_Err_Win;
                    Write(' Phase LINKS');
                    Mil.WrFct (Fct, MilErr);
                    Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                   end;

        Taste_F7 : begin
                    Fct.B.Fct := $18;  {Phase Rechts}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                    Ini_Err_Win;
                    Write(' Phase RECHTS');
                    Mil.WrFct (Fct, MilErr);
                    Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                   end;

        Taste_F8 : begin
                    Fct.B.Fct := $19;  {Phase STOP}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                    Ini_Err_Win;
                    Write(' Phase STOP');
                    Mil.WrFct (Fct, MilErr);
                    Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                   end;

        Taste_F9 : begin
                   end;

        Taste_F10: begin
                    New_Ifc_Adr;
                    Fct.B.Adr := Ifc_Test_Nr;
                    Fct.B.Fct := Fct_Rd_Stat0;
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,05);  write (hex_word(Fct.W));
                    Fct.B.Fct := 0;  {Default fÅr Write Function}
                    GotoXY(Spalte_Stat ,06);  write (hex_word(Fct.W));

                    Ini_Msg_Win;
                    Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
                    repeat until KeyEPressed;
                    Ch := ' ';
                   end; {Taste_F10}
        Taste_F11 : begin
                      S_P (Strahl);
                    end;
        Taste_F12 : begin
                      S_P (Pause);
                    end;
       end;  {Case}
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
     end;   {if Ch=#0}
   until Ch in ['x','X'];
99:
End; {Mil_Hf_StatC0}

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
    ini_text_win;
    Displ_Cmd_Codes;
    Set_Text_win;
    GotoXY(5, 22);  write ('Welchen Function-Code ??');

    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := ask_hex_byte;
    transf_cnt:= 0;
    ini_text_win;

    GotoXY(20, 8);
    write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
    GotoXY(6, 11); writeln('Wr_Fct_Cnt :');
    GotoXY(29,12); writeln('^  ^');

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
      repeat until KeyEPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,11);  Write(Transf_Cnt:10);
      Mil.WrFct (Fct, MilErr);
    until KeyEPressed or (Ch = ' ');
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyEPressed;
      end;
    Ch := ReadKey;
   until Ch in ['x','X'];
99:
End; {Mil_Hf_Cmd}

Procedure Mil_Hf_WrSwAnalo;
  LABEL 99;
  CONST HF_Fct = $06;

  VAR
     Bit16_Str: Str19;
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
   repeat until KeyEPressed;
   Ch := ReadKey;
   if (Ch in ['j','J']) then
    begin                             {in Strahl}
     Write_Data:= Write_Data or $8000;
     if BitTst (Write_Data,15) then
      begin
       Ini_Err_Win;
       Write('Vorsicht: Bit 15 = Sender in Strahl. Kann Betrieb stîren!! Weiter [J/N]?: ');
       repeat until KeyEPressed;
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
      repeat until KeyEPressed;
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
    until KeyEPressed or (Ch = ' ');
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyEPressed;
      end;
    Ch := ReadKey;
   until Ch in ['x','X'];
99:
End; {Mil_Hf_WrSwAnalog}

{xxx}
procedure Mil_Hf_WrPhAnalog;
 label 99;
 type TPhas = record
               Code: Word;
               Text: string[3];
              end;

 CONST HF_Fct = $07;   {Phasensollwert}
  Wait_Pha  = 50000;  {0,5 sec}

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
      P      : Byte;
      Status : Boolean;
      Bit16_Str : Str19;

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

  procedure Ini_TastPha_Win;
   begin
    Set_Text_Win;
    Window(10, 22, 40, 23);
    TextBackground(Green);
    ClrScr;
    TextColor(Yellow);
    GotoXY(01, 01); Write('F1 : Phase in Grad');
    GotoXY(01, 02); Write('F10: IfcAdr       ');
    TextColor(Black);
   end;

  function Ask_Phase_Code (var I : Byte): Boolean;
   label 1;
   var Status : Boolean;
   begin
    Ask_Phase_Code := False;
    status := False;
    while not status do
     begin
      Ini_Msg_Win;
      write   ('--> Welche Nr. fÅr Phasen-Einstellung: ');
      {$I-}                            {Compiler Check aus, Error selber abfangen}
       Readln(I);
      {$I+}
      if IoResult <> 0 then
       begin
        ini_err_win;
        write('ERROR: Sorry, USER: keine gÅltige Eingabe!  Weiter mit <CR> oder e[X]it: ');
        Ch := ReadKey;
        if Ch in ['x','X'] then goto 1;
       end
      else
       begin
        if not I in [1..12] then
         begin
          ini_err_win;
          write('ERROR: Sorry, USER: das war keine Nr 1..12 !  Weiter mit <CR> oder e[X]it:');
          Ch := ReadKey;
          if Ch in ['x','X'] then goto 1;
         end
        else
         Status         := True;
         Ask_Phase_Code := True;
       end;
     end; {while}
1:  end; {Ask_Phase_Code (P);}

 Begin
   Mil_Ask_Ifc;
{   Find_First_Online;}
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := HF_Fct;
   transf_cnt:= 0;
   Ini_Text_win;
   Displ_Phas_Codes;
   Ini_TastPha_Win;

   if Ask_Phase_Code (P) then
     Write_Data := Phas_Code_Ary[P].Code
   else
     begin
      Ini_Err_Win;
      Write('ERROR: Auswahl-Nr. falsch!!   Ende mit beliebiger Taste');
      repeat until KeyEPressed;
      goto 99;
     end;


   Ini_Text_Win;
   Displ_Phas_Codes;
   Set_Text_Win;

   GotoXY(22,03); Write('********** Schreibe PHASE **********');
   GotoXY(20,05); Write  ('Write  Function-Word (Fct + Adr): ');
   write (hex_word(Fct.W),' [H]');

   GotoXY(08,11); writeln('Wr_Fct_Cnt :');
   GotoXY(29,12); writeln('^  ^');
   GotoXY(08,13);  Write('Data     [Hex]: ');
   GotoXY(31,13);  write(hex_word(Write_Data));

   GotoXY(08,14);  write('Data     [BIN]:');
   GotoXY(25,15);  write('MSB             LSB');
   GotoXY(08,17);  write('Phase   [Grad]:');
   GotoXY(28,17);  Write(Phas_Code_Ary[P].Text);
   Hex_Bin_Str (Write_Data,bit16_str);
   GotoXY(25, 14);  write(bit16_str);
   Ini_TastPha_Win;

   Ini_Msg_Win;
   Write('Achtung: Ist IFC-ADR [', Hex_Byte(Ifc_Test_Nr),'] ok mit <J>,  Ñndern mit <CR>');
   Ch := ReadKey;

   if not (Ch in ['j','J']) then
    begin
      New_Ifc_Adr;
      Fct.B.Adr := Ifc_Test_Nr;
      Set_Text_Win;
      GotoXY(20,05); Write  ('Write  Function-Word (Fct + Adr): ');
      write (hex_word(Fct.W),' [H]');
   end;

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
      repeat until KeyEPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,11);  Write(Transf_Cnt:10);
      Mil.Wr (Write_Data, Fct, MilErr);
      Mil.Timer2_Wait (Wait_Pha);
    until KeyEPressed or (Ch = ' ');
    if KeyEPressed then Ch := ReadKey;

    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
       repeat until KeyEPressed;
      end;

    if Ch = #0 then
     begin
       Ch := ReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    Ask_Phase_Code (P);
                    Write_Data := Phas_Code_Ary[P].Code;
                    Set_Text_Win;
                    GotoXY(31,13);  write(hex_word(Write_Data));
                    Hex_Bin_Str (Write_Data,bit16_str);
                    GotoXY(25, 14);  write(bit16_str);
                    GotoXY(28,17);  Write(Phas_Code_Ary[P].Text);
 {                   Mil.Timer2_Wait(Wait_Pha);  }        { Wartet mit Timer2}
                   end;

        Taste_F10: begin
                    New_Ifc_Adr;
                    Fct.B.Adr := Ifc_Test_Nr;
                    Set_Text_Win;
                    GotoXY(20,05); Write  ('Write  Function-Word (Fct + Adr): ');
                    write (hex_word(Fct.W),' [H]');
                    Displ_Phas_Codes;
                    Ini_Msg_Win;
                    Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
                    repeat until KeyEPressed;
                    Ch := ' ';
                   end; {Taste_F10}
       end;  {Case}
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
     end;   {if Ch=#0}

   until Ch in ['x','X'];
99:
End; {Mil_Hf_WrPhAnalog}


Procedure Mil_Hf_WrSwAmpl_Shift; {Sollwert bitweise schieben, Start mit 0}
  LABEL 99;                      {Bit 14..05 = 10 Bit; Bit 15= Strahl/Pause=0}
  CONST HF_Fct = $06;

  VAR
     Bit16_Str: Str19;
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
      repeat until KeyEPressed;
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
    until KeyEPressed or (Ch = ' ');
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> , [S]hift Bit,  Ende mit [X]');
       repeat until KeyEPressed;
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
         repeat until KeyEPressed;
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
     Bit16_Str  : Str19;
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
      repeat until KeyEPressed;
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
    until KeyEPressed or (Ch = ' ');
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> , [S]hift Bit,  Ende mit [X]');
       repeat until KeyEPressed;
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
         repeat until KeyEPressed;
         Ch := ReadKey;
       until (Ch =' ') or  (Ch in ['x','X']);
      end; {if s}
    until Ch in ['x','X'];
99:
End; {Mil_Hf_WrSwPhas_Shift}

procedure Mil_Hf_Istw;
  LABEL 99;
  CONST HF_Fct_RdIw = $84;

  VAR
     Bit16_Str: Str19;
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
      repeat until KeyEPressed;
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
    until KeyEPressed or (Ch = ' ');
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyEPressed;
      end;
    Ch := ReadKey;
   until Ch in ['x','X'];
99:
End; {Mil_Hf_Istw}


Procedure Mil_Hf_WrSw;
  LABEL 99;
  CONST
        Spalte_Stat  = 51;
        Wait_Time    = 120000; {1 sec}
        Z_IW         = 15;
        Z_SW         = Z_IW+1;
        S_Hex        = 20;
        S_Volt       = S_Hex  + 10;
        S_Bin        = S_Volt + 13;
        Z_Title      = Z_IW-1;

  VAR
     Error_Cnt : LONGINT;
     MilErr    : TMilErr;
     Fct       : TFct;
     Mil_Timout: Boolean;
     bit16_str : Str19;
     N         : Word;
     RetAdr    : Byte;
     OnlineErr : TOnlineErr;
     SW_Data   : Word;
     Displ_Plus_Data: Word;

  procedure Ini_TastSw_Win;
   begin
    Window(50, 22, 80, 23);
    TextBackground(Green);
    ClrScr;
    TextColor(Yellow);
    GotoXY(01, 01); Write('F1: SW in Volt     F10: IfcAdr ');
    GotoXY(01, 02); Write('F2: SW in Hex                 ');
    TextColor(Black);
   end;

   FUNCTION get_data: WORD;
    var rd_data : Word;
    Begin
     Fct.B.Fct := Fct_Rd_Ist4;
     Mil.Rd (Rd_Data, Fct, MilErr);
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

   function Ask_SW_Hex: WORD;
    var in_data : WORD;
        Status : Boolean;
    Begin
     status := FALSE;
     WHILE NOT status DO
      Begin
       Ini_Msg_Win;
       write   ('--> Bitte 4-stellige Hex-Daten eingeben: '); readln(read_str);
       convert_to_hex (read_str,in_data,status);
       IF NOT status THEN
         Begin
          ini_err_win;
          writeln('ERROR: Sorry, USER: das war keine 4-stell. Hexzahl!!');
         End;
      End; {WHILE}
     Ask_SW_Hex := In_Data;
    End; {Ask_Data}

 begin
   Mil_Ask_Ifc;
   Ini_Text_Win;
   timout_rd := 0;
   Transf_Cnt:= 0;
   Fct.B.Adr := Ifc_Test_Nr;

   {Init Display}
   GotoXY(22,02); Write('*********** SCHREIBE HF-SOLLWERT **********');
   TextColor(Yellow);
   GotoXY(15,03);  Write('In diesem Test bedeutet Amplituden Bit15 = 1 --> Strahl!');
   TextColor(Black);

   Fct.B.Fct := Fct_Rd_Ist4;
   GotoXY(08,05);  write  ('Read  IstWert : Function-Word (Fct + Adr): ');
   GotoXY(Spalte_Stat ,05);  write (hex_word(Fct.W),' [H]');

   Fct.B.Fct := Fct_Wr_Sw1;
   GotoXY(08,06);  write  ('Write Sollwert: Function-Word (Fct + Adr): ');
   GotoXY(Spalte_Stat ,06);  write (hex_word(Fct.W),' [H]');
   GotoXY(08,10);  Write('Read Istwert  : ');
   GotoXY(08,11);  Write('Timeout       : ');

   TextColor(Brown);
   GotoXY(S_Hex,  Z_Title );  Write('[HEX]');
   GotoXY(S_Volt,  Z_Title);  Write('[VOLT]');
   GotoXY(S_Bin+8, Z_Title);  Write('[BIN]');
   TextColor(Black);
   GotoXY(02,Z_IW);  Write('Istwert : ');
   GotoXY(02,Z_SW);  Write('Sollwert: ');

   Ini_TastSw_Win;
   Ini_Msg_Win;
   Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
   Set_Text_Win;

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
      repeat until KeyEPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,10);  Write(Transf_Cnt:10);

      read_data := get_data;       {Lese Istwert}
      IF rd_timeout THEN
        Begin
         GotoXY(S_Hex,Z_IW);     write('    ');
         GotoXY(S_Volt-1,Z_IW);   write('          ');
         TextColor (Red);
         GotoXY(S_Bin, Z_IW); write('    Read Error!!   ');
         TextColor (Black);
        End
      ELSE
        Begin
          GotoXY(S_Hex,Z_IW);  write(hex_word(Read_Data));
          Hex_Bin_Str (read_data,bit16_str);
          GotoXY(S_Bin, Z_IW);  write(bit16_str);
          Displ_Plus_Data := Read_Data and $7FFF;  {Bit15 kein Vorzeichen!!}
          GotoXY(S_Volt-1,Z_IW);  Write_Real_10 (Displ_Plus_Data);
        End;
      GotoXY(25,11);  write(timout_rd:10);
      Mil.Timer2_Wait(Wait_Status);
    until KeyEPressed or (Ch = ' ');

    if KeyEPressed then Ch := ReadKey;
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
       repeat until KeyEPressed;
      end;

    if Ch = #0 then
     begin
       Ch := ReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    Fct.B.Fct := Fct_Wr_Sw1;  {Write Sollwert}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                    Write_Data  := Rd_Real_10;

                    { PrÅfe, ob Strahl oder Pause. Falls Strahl, User nochmals
                      fragen, da UNILAC-Betrieb gestîrt werden kann!!!}
                    Ini_Err_Win;
                    Write('Achtung! Soll Sender in Strahl? Kann Betrieb stîren!! Weiter [J/N]?: ');
                    repeat until KeyEPressed;
                    Ch := ReadKey;
                    if (Ch in ['j','J']) then
                     begin                             {in Strahl}
                      Write_Data:= Write_Data or $8000;
                      if BitTst (Write_Data,15) then
                       begin
                        Ini_Err_Win;
                        Write('Vorsicht: Bit15 = 1 -> Sender in Strahl! Kann Betrieb stîren.  Weiter [J/N]?: ');
                        repeat until KeyPressed;
                        Ch := ReadKey;
                        if not (Ch in ['j','J']) then Write_Data := Write_Data and $7FFF;
                       end;
                     end
                    else
                     begin                             {nicht in Strahl}
                      Write_Data := Write_Data and $7FFF;
                     end;

                    Mil.Wr (write_data, Fct, MilErr);
                    if MilErr <> No_err then
                     begin
                      Timout_Wr:= Timout_Wr +1;
                      GotoXY(25,11);  write(timout_wr:10);
                     end;
                    GotoXY(25,11);  write(timout_wr:10);

                    Ini_Err_Win;
                    Write(' Write SOLLWERT');
                    Set_Text_Win;

                    GotoXY(S_Hex,Z_SW);  write(hex_word(Write_Data));
                    Hex_Bin_Str (Write_Data,bit16_str);
                    GotoXY(S_Bin, Z_SW);  write(bit16_str);
                    Displ_Plus_Data := Write_Data and $7FFF;  {Bit15 kein Vorzeichen!!}
                    GotoXY(S_Volt-1,Z_SW);  Write_Real_10 (Displ_Plus_Data);

                    Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                   end;

        Taste_F2 : begin
                    Fct.B.Fct := Fct_Wr_Sw1;  {Write Sollwert}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                    Write_Data  := Ask_SW_Hex;

                    { PrÅfe, ob Strahl oder Pause. Falls Strahl, User nochmals
                      fragen, da UNILAC-Betrieb gestîrt werden kann!!!}
                    Ini_Err_Win;
                    Write('Achtung! Soll Sender in Strahl? Kann Betrieb stîren!! Weiter [J/N]?: ');
                    repeat until KeyEPressed;
                    Ch := ReadKey;
                    if (Ch in ['j','J']) then
                     begin                             {in Strahl}
                      Write_Data:= Write_Data or $8000;
                      if BitTst (Write_Data,15) then
                       begin
                        Ini_Err_Win;
                        Write('Vorsicht: Bit15 = 1 -> Sender in Strahl! Kann Betrieb stîren.  Weiter [J/N]?: ');
                        repeat until KeyEPressed;
                        Ch := ReadKey;
                        if not (Ch in ['j','J']) then Write_Data := Write_Data and $7FFF;
                       end;
                     end
                    else
                     begin                             {nicht in Strahl}
                      Write_Data := Write_Data and $7FFF;
                     end;

                    Mil.Wr (write_data, Fct, MilErr);
                    if MilErr <> No_err then
                     begin
                      Timout_Wr:= Timout_Wr +1;
                      GotoXY(25,11);  write(timout_wr:10);
                     end;
                    GotoXY(25,11);  write(timout_wr:10);

                    Ini_Err_Win;
                    Write(' Write SOLLWERT');
                    Set_Text_Win;

                    GotoXY(S_Hex,Z_SW);  write(hex_word(Write_Data));
                    Hex_Bin_Str (Write_Data,bit16_str);
                    GotoXY(S_Bin, Z_SW);  write(bit16_str);
                    Displ_Plus_Data := Write_Data and $7FFF;  {Bit15 kein Vorzeichen!!}
                    GotoXY(S_Volt-1,Z_SW);  Write_Real_10 (Displ_Plus_Data);

                    Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                   end;

        Taste_F10: begin
                    New_Ifc_Adr;
                    Fct.B.Adr := Ifc_Test_Nr;
                    Fct.B.Fct := Fct_Rd_Ist4;; {Read IW Function}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,05);  write (hex_word(Fct.W));
                    Fct.B.Fct := Fct_Wr_Sw1;   {Write Default Function}
                    GotoXY(Spalte_Stat ,06);  write (hex_word(Fct.W));

                    {Lîsche die Sollwert-Anzeige, da neue IFC_ADR}
                    GotoXY(S_Hex,Z_SW);     write('    ');
                    GotoXY(S_Volt-1,Z_SW);   write('          ');
                    TextColor (Red);
                    GotoXY(S_Bin, Z_SW); write('                   ');
                    TextColor (Black);

                    Ini_Msg_Win;
                    Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
                    repeat until KeyEPressed;
                    Ch := ' ';
                   end; {Taste_F10}
       end;  {Case}
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
     end;   {if Ch=#0}

   until Ch in ['x','X'];
99:
End; {Mil_Hf_WrSw}

{xxx}
Procedure Mil_Hf_WrSw_Evt;
  LABEL 99;
  CONST
        Spalte_Stat  = 51;
        Wait_Time    = 120000; {1 sec}
        Z_IW         = 15;
        Z_SW         = Z_IW+1;
        S_Hex        = 20;
        S_Volt       = S_Hex  + 10;
        S_Bin        = S_Volt + 13;
        Z_Title      = Z_IW-1;

  VAR
     Error_Cnt : LONGINT;
     MilErr    : TMilErr;
     Fct       : TFct;
     Mil_Timout: Boolean;
     bit16_str : Str19;
     N         : Word;
     RetAdr    : Byte;
     OnlineErr : TOnlineErr;
     SW_Data   : Word;
     Displ_Plus_Data: Word;

  procedure Ini_TastSw_Win;
   begin
    Window(50, 22, 80, 23);
    TextBackground(Green);
    ClrScr;
    TextColor(Yellow);
    GotoXY(01, 01); Write('F1: SW in Volt     F10: IfcAdr ');
    GotoXY(01, 02); Write('F2: SW in Hex                 ');
    TextColor(Black);
   end;

   FUNCTION get_data: WORD;
    var rd_data : Word;
    Begin
     Fct.B.Fct := Fct_Rd_Ist4;
     Mil.Rd (Rd_Data, Fct, MilErr);
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

   function Ask_SW_Hex: WORD;
    var in_data : WORD;
        Status : Boolean;
    Begin
     status := FALSE;
     WHILE NOT status DO
      Begin
       Ini_Msg_Win;
       write   ('--> Bitte 4-stellige Hex-Daten eingeben: '); readln(read_str);
       convert_to_hex (read_str,in_data,status);
       IF NOT status THEN
         Begin
          ini_err_win;
          writeln('ERROR: Sorry, USER: das war keine 4-stell. Hexzahl!!');
         End;
      End; {WHILE}
     Ask_SW_Hex := In_Data;
    End; {Ask_Data}

 begin
   Mil_Ask_Ifc;
   Ini_Text_Win;
   timout_rd := 0;
   Transf_Cnt:= 0;
   Fct.B.Adr := Ifc_Test_Nr;

   {Init Display}
   GotoXY(22,02); Write('*********** SCHREIBE HF-SOLLWERT **********');
   TextColor(Yellow);
   GotoXY(15,03);  Write('In diesem Test bedeutet Amplituden Bit15 = 1 --> Strahl!');
   TextColor(Black);

   Fct.B.Fct := Fct_Rd_Ist4;
   GotoXY(08,05);  write  ('Read  IstWert : Function-Word (Fct + Adr): ');
   GotoXY(Spalte_Stat ,05);  write (hex_word(Fct.W),' [H]');

   Fct.B.Fct := Fct_Wr_Sw1;
   GotoXY(08,06);  write  ('Write Sollwert: Function-Word (Fct + Adr): ');
   GotoXY(Spalte_Stat ,06);  write (hex_word(Fct.W),' [H]');
   GotoXY(08,10);  Write('Read Istwert  : ');
   GotoXY(08,11);  Write('Timeout       : ');

   TextColor(Brown);
   GotoXY(S_Hex,  Z_Title );  Write('[HEX]');
   GotoXY(S_Volt,  Z_Title);  Write('[VOLT]');
   GotoXY(S_Bin+8, Z_Title);  Write('[BIN]');
   TextColor(Black);
   GotoXY(02,Z_IW);  Write('Istwert : ');
   GotoXY(02,Z_SW);  Write('Sollwert: ');

   Ini_TastSw_Win;
   Ini_Msg_Win;
   Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
   Set_Text_Win;

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
      repeat until KeyEPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,10);  Write(Transf_Cnt:10);

      read_data := get_data;       {Lese Istwert}
      IF rd_timeout THEN
        Begin
         GotoXY(S_Hex,Z_IW);     write('    ');
         GotoXY(S_Volt-1,Z_IW);   write('          ');
         TextColor (Red);
         GotoXY(S_Bin, Z_IW); write('    Read Error!!   ');
         TextColor (Black);
        End
      ELSE
        Begin
          GotoXY(S_Hex,Z_IW);  write(hex_word(Read_Data));
          Hex_Bin_Str (read_data,bit16_str);
          GotoXY(S_Bin, Z_IW);  write(bit16_str);
          Displ_Plus_Data := Read_Data and $7FFF;  {Bit15 kein Vorzeichen!!}
          GotoXY(S_Volt-1,Z_IW);  Write_Real_10 (Displ_Plus_Data);
        End;
      GotoXY(25,11);  write(timout_rd:10);
      Mil.Timer2_Wait(Wait_Status);
    until KeyEPressed or (Ch = ' ');

    if KeyEPressed then Ch := ReadKey;
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
       repeat until KeyEPressed;
      end;

    if Ch = #0 then
     begin
       Ch := ReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    Fct.B.Fct := Fct_Wr_Sw1;  {Write Sollwert}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                    Write_Data  := Rd_Real_10;

                    { PrÅfe, ob Strahl oder Pause. Falls Strahl, User nochmals
                      fragen, da UNILAC-Betrieb gestîrt werden kann!!!}
                    Ini_Err_Win;
                    Write('Achtung! Soll Sender in Strahl? Kann Betrieb stîren!! Weiter [J/N]?: ');
                    repeat until KeyEPressed;
                    Ch := ReadKey;
                    if (Ch in ['j','J']) then
                     begin                             {in Strahl}
                      Write_Data:= Write_Data or $8000;
                      if BitTst (Write_Data,15) then
                       begin
                        Ini_Err_Win;
                        Write('Vorsicht: Bit15 = 1 -> Sender in Strahl! Kann Betrieb stîren.  Weiter [J/N]?: ');
                        repeat until KeyEPressed;
                        Ch := ReadKey;
                        if not (Ch in ['j','J']) then Write_Data := Write_Data and $7FFF;
                       end;
                     end
                    else
                     begin                             {nicht in Strahl}
                      Write_Data := Write_Data and $7FFF;
                     end;

                    Mil.Wr (write_data, Fct, MilErr);
                    if MilErr <> No_err then
                     begin
                      Timout_Wr:= Timout_Wr +1;
                      GotoXY(25,11);  write(timout_wr:10);
                     end;
                    GotoXY(25,11);  write(timout_wr:10);

                    Ini_Err_Win;
                    Write(' Write SOLLWERT');
                    Set_Text_Win;

                    GotoXY(S_Hex,Z_SW);  write(hex_word(Write_Data));
                    Hex_Bin_Str (Write_Data,bit16_str);
                    GotoXY(S_Bin, Z_SW);  write(bit16_str);
                    Displ_Plus_Data := Write_Data and $7FFF;  {Bit15 kein Vorzeichen!!}
                    GotoXY(S_Volt-1,Z_SW);  Write_Real_10 (Displ_Plus_Data);

                    Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                   end;

        Taste_F2 : begin
                    Fct.B.Fct := Fct_Wr_Sw1;  {Write Sollwert}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                    Write_Data  := Ask_SW_Hex;

                    { PrÅfe, ob Strahl oder Pause. Falls Strahl, User nochmals
                      fragen, da UNILAC-Betrieb gestîrt werden kann!!!}
                    Ini_Err_Win;
                    Write('Achtung! Soll Sender in Strahl? Kann Betrieb stîren!! Weiter [J/N]?: ');
                    repeat until KeyEPressed;
                    Ch := ReadKey;
                    if (Ch in ['j','J']) then
                     begin                             {in Strahl}
                      Write_Data:= Write_Data or $8000;
                      if BitTst (Write_Data,15) then
                       begin
                        Ini_Err_Win;
                        Write('Vorsicht: Bit15 = 1 -> Sender in Strahl! Kann Betrieb stîren.  Weiter [J/N]?: ');
                        repeat until KeyEPressed;
                        Ch := ReadKey;
                        if not (Ch in ['j','J']) then Write_Data := Write_Data and $7FFF;
                       end;
                     end
                    else
                     begin                             {nicht in Strahl}
                      Write_Data := Write_Data and $7FFF;
                     end;

                    Mil.Wr (write_data, Fct, MilErr);
                    if MilErr <> No_err then
                     begin
                      Timout_Wr:= Timout_Wr +1;
                      GotoXY(25,11);  write(timout_wr:10);
                     end;
                    GotoXY(25,11);  write(timout_wr:10);

                    Ini_Err_Win;
                    Write(' Write SOLLWERT');
                    Set_Text_Win;

                    GotoXY(S_Hex,Z_SW);  write(hex_word(Write_Data));
                    Hex_Bin_Str (Write_Data,bit16_str);
                    GotoXY(S_Bin, Z_SW);  write(bit16_str);
                    Displ_Plus_Data := Write_Data and $7FFF;  {Bit15 kein Vorzeichen!!}
                    GotoXY(S_Volt-1,Z_SW);  Write_Real_10 (Displ_Plus_Data);

                    Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                   end;

        Taste_F10: begin
                    New_Ifc_Adr;
                    Fct.B.Adr := Ifc_Test_Nr;
                    Fct.B.Fct := Fct_Rd_Ist4;; {Read IW Function}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,05);  write (hex_word(Fct.W));
                    Fct.B.Fct := Fct_Wr_Sw1;   {Write Default Function}
                    GotoXY(Spalte_Stat ,06);  write (hex_word(Fct.W));

                    {Lîsche die Sollwert-Anzeige, da neue IFC_ADR}
                    GotoXY(S_Hex,Z_SW);     write('    ');
                    GotoXY(S_Volt-1,Z_SW);   write('          ');
                    TextColor (Red);
                    GotoXY(S_Bin, Z_SW); write('                   ');
                    TextColor (Black);

                    Ini_Msg_Win;
                    Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
                    repeat until KeyEPressed;
                    Ch := ' ';
                   end; {Taste_F10}
       end;  {Case}
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
     end;   {if Ch=#0}

   until Ch in ['x','X'];
99:
End; {Mil_Hf_WrSw}

 procedure Evt_Wr_HF;
 { Simuliert einen Event-Generator fÅr die unteren 8-Bit eines Events.
   Bipolare Daten des MIL-Busses mÅssen Åber einen Umsetzer auf Unipolar
   umgesetzt werden, um TIF-kompatibel zu sein
 }
  label 99;
  const
   EvtMax = 6;
   Z_Evt  = 8;
   S_Num  = 12;
   S_Time = S_Num  + 18;
   S_Text = S_Time + 20;

  type
   TEvt  = record
            Num      : Byte;          {Event-Nr 00..255, ohne Superzykl.}
            Time     : LongInt;       {Wartezeit nach dem Event}
            Text      : string[16];   {Offizielle Bezeichnung am Unilac}
           end;
   TEvtAry = array [1..EvtMax] of TEvt;

 const                         {alle Wartezeiten zusammen = 20 ms -> 50Hz !!}
   Event : TEvtAry =
           (
           (Num: 16; Time:   50; Text: 'Prep_Next_Acc '),  {Zeit: x 10us}
           (Num:255; Time: 1000; Text: 'Command       '),
           (Num: 01; Time:  200; Text: 'Start_RF       '),
           (Num: 06; Time:  500; Text: 'Beam_On        '),
           (Num: 08; Time:  100; Text: 'Beam_Off       '),
           (Num: 12; Time:  150; Text: 'Stop_RF        ')
           );
 var
    error_cnt  : LONGINT;
    MilErr     : TMilErr;
    Fct        : TFct;
    Life_Mode  : TLife_XY;

   procedure Wr_HF_Evts;
     var I : Byte;
     procedure Wr_Event (Data: Byte);
     begin
       Fct.B.Adr := Data;            {Adr = Lowbyte des Events}
       Fct.B.Fct := 0;               {Hibyte des events       }
       Mil.WrFct (Fct, MilErr);
       if Single_Step then
         begin
          Set_Text_Win;
          TextColor(Brown);
          GotoXY(22,03);
          Write  ('Wr-Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
          TextColor(Black);
         end;
   {    Mil.Wr (Data, Fct, MilErr); }
     end; {Wr-Data}

    begin   {Wr_HF_Evts}
      for I := 1 to EvtMax do
       begin
         Wr_Event (Event[I].Num);
         Mil.Timer2_Wait(Event[I].Time);  {Wartezeit  n a c h  Event-Versenden}
       end;
    end; {Wr_HF_Evts}

   procedure Evt_Disp;
    var N : Byte;
        Time_Real : Real;
    begin
      TextColor(Brown);
      GotoXY(02 ,Z_Evt-1); write(' Mode ');

      GotoXY(S_Num    ,Z_Evt-1); write('Event-Nr');
      GotoXY(S_Num    ,Z_Evt);   write(' [Dez]');

      GotoXY(S_Time-3 ,Z_Evt-1); write('Time to Next-Event');
      GotoXY(S_Time ,Z_Evt);   write('     [ms]         ');

      GotoXY(S_Text ,Z_Evt-1); write('Event Bezeichnung');
      GotoXY(S_Text ,Z_Evt);   write('   [fÅr Unilac]  ');

      TextColor(Black);
      for N := 1 to EvtMax do
       begin
         GotoXY (S_Num+2 ,Z_Evt+N);  Write (Event[N].Num:3);
         Time_Real := Event[N].Time/100;
         GotoXY (S_Time  ,Z_Evt+N);  Write (Time_Real:10:3);
         GotoXY (S_Text  ,Z_Evt+N);  Write (Event[N].Text);
       end;
    end; {Evt_Disp}


  begin
    Fct.B.Adr := 0;   {In diesem Falle: 8-bit Event-Code}
    Fct.B.Fct := 0;   {       Supercyclus + Virt-Beschl.}
    Ini_Text_Win;
    TextColor(Brown);
    GotoXY(20,02); write('----- Sende Event-Folge fÅr HF-ER -----');
    GotoXY(22,03); Write  ('Wr-Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
    TextColor(Yellow);
    GotoXY(05,04); write('  Umsetzer Timing-Kasten Bipolar nach Unipolar mu· direkt an MIL-Bus');

    TextColor(Black);
    Evt_Disp;
    Cursor(False);
    Std_Msg;
    Ch := NewReadKey;
    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Wr_HF_Evts;
       Set_Text_Win;
       TextColor(White);
       GotoXY(02 ,Z_Evt);   Write ('Single');
       Life_Mode.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
       Life_Mode.PosX    := 04;
       Life_Mode.PosY    := Z_Evt+1;
       Life_Mode.Time    := Life_Time_Slow;
       Life_Mode.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}
       Life_Sign_XY (Life_Mode);

       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then
      begin
       Single_Step := False;
       Set_Text_Win;
       TextColor(Blue+128);
       GotoXY(02 ,Z_Evt);   Write (' Loop ');
       GotoXY(02 ,Z_Evt+1); Write ('      ');
      end;

     if not Single_Step then
      begin
       Wr_HF_Evts;
      end;

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
       Taste_F1 : begin
                  end;
       Taste_F12: begin
                  end; {Taste_F12}
       Taste_Pfeil_Links : begin
                            end;  {Taste_Pfeil_Links}
       Taste_Pfeil_Rechts: begin
                           end;  {Taste_Pfeil_Rechts}
      end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
 99:  Cursor(True);
 end; {Evt_Wr_HF}



BEGIN   { Hauptprogramm }
  Ifc_Test_Nr := 0; {Default}

  REPEAT
    menue_win;
    User_Input := ReadKey;
    loop := TRUE;
    IF User_Input IN ['0'..'9'] THEN loop := FALSE;
    CASE User_Input OF
     '0'      : Mil_Detect_Ifc;
     '1'      : Mil_Detect_Ifc_Compare;
     '2'      : begin
                  if Check_Ifc_Adr(Ifc_Test_Nr) then Mil_Rd_HS_Ctrl (Ifc_Test_Nr);
                end;
     '3'      : begin
                  if Check_Ifc_Adr(Ifc_Test_Nr) then Mil_Rd_HS_Status (Ifc_Test_Nr);
                end;
     '4'      : begin
                  if Check_Ifc_Adr(Ifc_Test_Nr) then Mil_Stat_All (Ifc_Test_Nr);
                end;
     '5'      : begin
                  Convert_Hex_Volt;
                end;
     '6'      : begin
                  Int_Mask;
                end;
     '7'      : begin
                  if Check_Ifc_Adr(Ifc_Test_Nr) then Mil_HS_Stat_Cmd (Ifc_Test_Nr);
                end;
     '9'      : begin
		  if Check_Ifc_Adr(Ifc_Test_Nr) then Mil_Echo (Ifc_Test_Nr);
                end;
     'a', 'A' : Mil_Ask_Ifc;
     'b', 'B' : begin
                  Mil_Ask_Ifc;
                  Mil_Rd_Ifc_Stat (Ifc_Test_Nr);
                end;
     'c', 'C' : begin
                  Mil_Rd_Status;
                end;
     'd', 'D' : begin
                  Mil_Rd_Fifo;
                end;
     'e', 'E' : begin
                  if Check_Ifc_Adr(Ifc_Test_Nr) then Mil_Rd_Data;
		end;
     'f', 'F' : begin
                  Functioncode_Table;
                end;
     'g', 'G' : begin
                  Mil_Data := Ask_Data;
		  Mil_WrData (Mil_Data);
                end;
     'h', 'H' : begin
		  if Check_Ifc_Adr(Ifc_Test_Nr) then Mil_Wr_Fctcode;
                end;
     'i', 'I' : begin
                  if Check_Ifc_Adr(Ifc_Test_Nr) THEN
                   begin
		     Mil_Data := Ask_Data;
		     Mil_Wr (Mil_Data);
                   end;
                end;
     'j', 'J' : begin
		  if Check_Ifc_Adr(Ifc_Test_Nr) then
		    begin
		     Mil_Data := Ask_Data;
		     Mil_Wr_Rd (Mil_Data);
 		    end;
                end;
     'k', 'K' : begin
		  if Check_Ifc_Adr(Ifc_Test_Nr) then Mil_Loop;
                end;

     'l', 'L' : begin
                  Mil_Dual_Mode;
                end;
          'm', 'M' : begin
                       Mil_Hf_StatC0;
                     end;
          'n', 'N' : begin
{ 		       IF check_ifc_adr(Ifc_Test_Nr) THEN Mil_Hf_Istw; }
                       Mil_Hf_WrSw;
                     end;
          'o', 'O' : begin
                       Mil_Hf_WrPhAnalog;
                     end;
          'p', 'P' : begin
                       Mil_Hf_WrSw_Evt;
                      end;
          'q', 'Q' : begin
 		       IF check_ifc_adr(Ifc_Test_Nr) THEN Mil_Hf_Cmd;;
                     end;

          'r', 'R' : begin
                      IF check_ifc_adr(Ifc_Test_Nr) then
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
                       end;
          's', 'S' : begin
                      IF check_ifc_adr(Ifc_Test_Nr) then
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
                   end;
          't', 'T' : begin
                       IF check_ifc_adr(Ifc_Test_Nr) THEN
                        begin
                         mil_data := MIL_Hf_ask_data;
                         Mil_Hf_SwAmpl (mil_data);
                        end;
                     end;
          'u', 'U' : begin
                        Evt_Wr_HF;
                     end;
          'v', 'V' : begin
                       IF check_ifc_adr(Ifc_Test_Nr) THEN Mil_Hf_PhasLeft;
                    end;
          'w', 'W' : begin
                       IF check_ifc_adr(Ifc_Test_Nr) THEN Mil_Hf_PhasRight;
                    end;
    End; {CASE}
  UNTIL user_input in ['x','X'];
  Window(1, 1, 80, 25);
  TextBackground(Black);
  ClrScr;
END. {mil_hf}




Procedure Mil_Hf_WrSw_Evt;
  LABEL 99;
  CONST
        Spalte_Stat  = 51;
        Wait_Time    = 120000; {1 sec}
        Z_IW         = 15;
        Z_SW         = Z_IW+1;
        S_Hex        = 20;
        S_Volt       = S_Hex  + 10;
        S_Bin        = S_Volt + 13;
        Z_Title      = Z_IW-1;

  VAR
     Error_Cnt : LONGINT;
     MilErr    : TMilErr;
     Fct       : TFct;
     Mil_Timout: Boolean;
     bit16_str : Str19;
     N         : Word;
     RetAdr    : Byte;
     OnlineErr : TOnlineErr;
     SW_Data   : Word;
     Displ_Plus_Data: Word;

  procedure Ini_TastSw_Win;
   begin
    Window(50, 22, 80, 23);
    TextBackground(Green);
    ClrScr;
    TextColor(Yellow);
    GotoXY(01, 01); Write('F1: SW in Volt     F10: IfcAdr ');
    GotoXY(01, 02); Write('F2: SW in Hex                 ');
    TextColor(Black);
   end;

   FUNCTION get_data: WORD;
    var rd_data : Word;
    Begin
     Fct.B.Fct := Fct_Rd_Ist4;
     Mil.Rd (Rd_Data, Fct, MilErr);
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

   function Ask_SW_Hex: WORD;
    var in_data : WORD;
        Status : Boolean;
    Begin
     status := FALSE;
     WHILE NOT status DO
      Begin
       Ini_Msg_Win;
       write   ('--> Bitte 4-stellige Hex-Daten eingeben: '); readln(read_str);
       convert_to_hex (read_str,in_data,status);
       IF NOT status THEN
         Begin
          ini_err_win;
          writeln('ERROR: Sorry, USER: das war keine 4-stell. Hexzahl!!');
         End;
      End; {WHILE}
     Ask_SW_Hex := In_Data;
    End; {Ask_Data}

 begin
   Mil_Ask_Ifc;
   Ini_Text_Win;
   timout_rd := 0;
   Transf_Cnt:= 0;
   Fct.B.Adr := Ifc_Test_Nr;

   {Init Display}
   GotoXY(22,02); Write('*********** SCHREIBE HF-SOLLWERT **********');
   TextColor(Yellow);
   GotoXY(15,03);  Write('In diesem Test bedeutet Amplituden Bit15 = 1 --> Strahl!');
   TextColor(Black);

   Fct.B.Fct := Fct_Rd_Ist4;
   GotoXY(08,05);  write  ('Read  IstWert : Function-Word (Fct + Adr): ');
   GotoXY(Spalte_Stat ,05);  write (hex_word(Fct.W),' [H]');

   Fct.B.Fct := Fct_Wr_Sw1;
   GotoXY(08,06);  write  ('Write Sollwert: Function-Word (Fct + Adr): ');
   GotoXY(Spalte_Stat ,06);  write (hex_word(Fct.W),' [H]');
   GotoXY(08,10);  Write('Read Istwert  : ');
   GotoXY(08,11);  Write('Timeout       : ');

   TextColor(Brown);
   GotoXY(S_Hex,  Z_Title );  Write('[HEX]');
   GotoXY(S_Volt,  Z_Title);  Write('[VOLT]');
   GotoXY(S_Bin+8, Z_Title);  Write('[BIN]');
   TextColor(Black);
   GotoXY(02,Z_IW);  Write('Istwert : ');
   GotoXY(02,Z_SW);  Write('Sollwert: ');

   Ini_TastSw_Win;
   Ini_Msg_Win;
   Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
   Set_Text_Win;

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
      repeat until KeyEPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,10);  Write(Transf_Cnt:10);

      read_data := get_data;       {Lese Istwert}
      IF rd_timeout THEN
        Begin
         GotoXY(S_Hex,Z_IW);     write('    ');
         GotoXY(S_Volt-1,Z_IW);   write('          ');
         TextColor (Red);
         GotoXY(S_Bin, Z_IW); write('    Read Error!!   ');
         TextColor (Black);
        End
      ELSE
        Begin
          GotoXY(S_Hex,Z_IW);  write(hex_word(Read_Data));
          Hex_Bin_Str (read_data,bit16_str);
          GotoXY(S_Bin, Z_IW);  write(bit16_str);
          Displ_Plus_Data := Read_Data and $7FFF;  {Bit15 kein Vorzeichen!!}
          GotoXY(S_Volt-1,Z_IW);  Write_Real_10 (Displ_Plus_Data);
        End;
      GotoXY(25,11);  write(timout_rd:10);
      Mil.Timer2_Wait(Wait_Status);
    until KeyEPressed or (Ch = ' ');

    if KeyEPressed then Ch := ReadKey;
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
       repeat until KeyEPressed;
      end;

    if Ch = #0 then
     begin
       Ch := ReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    Fct.B.Fct := Fct_Wr_Sw1;  {Write Sollwert}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                    Write_Data  := Rd_Real_10;

                    { PrÅfe, ob Strahl oder Pause. Falls Strahl, User nochmals
                      fragen, da UNILAC-Betrieb gestîrt werden kann!!!}
                    Ini_Err_Win;
                    Write('Achtung! Soll Sender in Strahl? Kann Betrieb stîren!! Weiter [J/N]?: ');
                    repeat until KeyEPressed;
                    Ch := ReadKey;
                    if (Ch in ['j','J']) then
                     begin                             {in Strahl}
                      Write_Data:= Write_Data or $8000;
                      if BitTst (Write_Data,15) then
                       begin
                        Ini_Err_Win;
                        Write('Vorsicht: Bit15 = 1 -> Sender in Strahl! Kann Betrieb stîren.  Weiter [J/N]?: ');
                        repeat until KeyEPressed;
                        Ch := ReadKey;
                        if not (Ch in ['j','J']) then Write_Data := Write_Data and $7FFF;
                       end;
                     end
                    else
                     begin                             {nicht in Strahl}
                      Write_Data := Write_Data and $7FFF;
                     end;

                    Mil.Wr (write_data, Fct, MilErr);
                    if MilErr <> No_err then
                     begin
                      Timout_Wr:= Timout_Wr +1;
                      GotoXY(25,11);  write(timout_wr:10);
                     end;
                    GotoXY(25,11);  write(timout_wr:10);

                    Ini_Err_Win;
                    Write(' Write SOLLWERT');
                    Set_Text_Win;

                    GotoXY(S_Hex,Z_SW);  write(hex_word(Write_Data));
                    Hex_Bin_Str (Write_Data,bit16_str);
                    GotoXY(S_Bin, Z_SW);  write(bit16_str);
                    Displ_Plus_Data := Write_Data and $7FFF;  {Bit15 kein Vorzeichen!!}
                    GotoXY(S_Volt-1,Z_SW);  Write_Real_10 (Displ_Plus_Data);

                    Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                   end;

        Taste_F2 : begin
                    Fct.B.Fct := Fct_Wr_Sw1;  {Write Sollwert}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,06); write (hex_word(Fct.W));
                    Write_Data  := Ask_SW_Hex;

                    { PrÅfe, ob Strahl oder Pause. Falls Strahl, User nochmals
                      fragen, da UNILAC-Betrieb gestîrt werden kann!!!}
                    Ini_Err_Win;
                    Write('Achtung! Soll Sender in Strahl? Kann Betrieb stîren!! Weiter [J/N]?: ');
                    repeat until KeyEPressed;
                    Ch := ReadKey;
                    if (Ch in ['j','J']) then
                     begin                             {in Strahl}
                      Write_Data:= Write_Data or $8000;
                      if BitTst (Write_Data,15) then
                       begin
                        Ini_Err_Win;
                        Write('Vorsicht: Bit15 = 1 -> Sender in Strahl! Kann Betrieb stîren.  Weiter [J/N]?: ');
                        repeat until KeyEPressed;
                        Ch := ReadKey;
                        if not (Ch in ['j','J']) then Write_Data := Write_Data and $7FFF;
                       end;
                     end
                    else
                     begin                             {nicht in Strahl}
                      Write_Data := Write_Data and $7FFF;
                     end;

                    Mil.Wr (write_data, Fct, MilErr);
                    if MilErr <> No_err then
                     begin
                      Timout_Wr:= Timout_Wr +1;
                      GotoXY(25,11);  write(timout_wr:10);
                     end;
                    GotoXY(25,11);  write(timout_wr:10);

                    Ini_Err_Win;
                    Write(' Write SOLLWERT');
                    Set_Text_Win;

                    GotoXY(S_Hex,Z_SW);  write(hex_word(Write_Data));
                    Hex_Bin_Str (Write_Data,bit16_str);
                    GotoXY(S_Bin, Z_SW);  write(bit16_str);
                    Displ_Plus_Data := Write_Data and $7FFF;  {Bit15 kein Vorzeichen!!}
                    GotoXY(S_Volt-1,Z_SW);  Write_Real_10 (Displ_Plus_Data);

                    Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                   end;

        Taste_F10: begin
                    New_Ifc_Adr;
                    Fct.B.Adr := Ifc_Test_Nr;
                    Fct.B.Fct := Fct_Rd_Ist4;; {Read IW Function}
                    Set_Text_Win;
                    GotoXY(Spalte_Stat ,05);  write (hex_word(Fct.W));
                    Fct.B.Fct := Fct_Wr_Sw1;   {Write Default Function}
                    GotoXY(Spalte_Stat ,06);  write (hex_word(Fct.W));

                    {Lîsche die Sollwert-Anzeige, da neue IFC_ADR}
                    GotoXY(S_Hex,Z_SW);     write('    ');
                    GotoXY(S_Volt-1,Z_SW);   write('          ');
                    TextColor (Red);
                    GotoXY(S_Bin, Z_SW); write('                   ');
                    TextColor (Black);

                    Ini_Msg_Win;
                    Write('Stop/Single Step mit <SPACE>, Loop mit <CR>,   Ende mit [X]');
                    repeat until KeyEPressed;
                    Ch := ' ';
                   end; {Taste_F10}
       end;  {Case}
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
     end;   {if Ch=#0}

   until Ch in ['x','X'];
99:
End; {Mil_Hf_WrSw}



  procedure Change_S_P;
   var IW, SW : Word;
   begin

{   end;} {Change_S/P}
