PROGRAM Mil_Gate;
{ Autor des Basis-Programmes Mil_Base.Pas: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS

  Autor der Erweiterungen   : N.N.
  énderungen:
  02.06.95    Umstellung MIL_Gate.pas Version 5.5 auf Version 7.0

}
{$S-}
uses Crt, WinDos, Datech, Datech_1;

CONST
 head_line =
      'Datentechnik                         MIL-GATE   ' +
      '                    [26.11.1996]'+
      '                          Gatepuls-Generator FG 463.000     (Turbo Pascal V7.0)';

 msg_single_step =
      'Loop- u. Single-Test mit [Q] beenden!    Single-Step mit [SPACE] ';
 msg_timer_auto =
      'Automat. Timertest mit [Q] beenden!                              ';

 fct_set_soll1    = $06;
 fct_set_soll2    = $07;
 fct_set_soll3    = $08;
 fct_set_soll4    = $09;
 fct_int_start    = $14;
 fct_rd_hw_status = $82;
 fct_rd_ist1      = $81;


 hw_stat_extern   = 1;    {Stellung Jumper intern/extern}
 hw_stat_rfl      = 2;    {Stellung Jumper vfl/rfl}
 dy_stat_wait     = 1;
 dy_stat_ovr      = 2;
 dy_stat_start_on = 4;    {Start-Counter lÑuft}
 dy_stat_start_off= 8;    {Start-Counter abgelaufen}
 dy_stat_stop_on  = $10;  {Stop-Counter lÑuft}
 dy_stat_stop_off = $20;  {Stop-Counter abgelaufen}

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
  Write(head_line);
  Menue_Base;              {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}

  GotoXY(12, 14);
  Writeln('         [M]<-- Reset Gate-Generator                            ');
  GotoXY(12, 15);
  Writeln('         [N]<-- Start-ZÑhler setzen                             ');
  GotoXY(12, 16);
  Writeln('         [O]<-- Stop- ZÑhler setzen                             ');
  GotoXY(12, 17);
  Writeln('         [P]<-- Start per Software [mit Funktionscode]          ');
  GotoXY(12, 18);
  Writeln('         [Q]<-- Status  1 lesen (Hardw. Status)                 ');
  GotoXY(12, 19);
  Writeln('         [R]<-- Istwert 1 lesen (Dynam. Status)                 ');
  GotoXY(12, 20);
  Writeln('         [S]<-- Test intern Trigger (Reset, Start, Stop)        ');
  GotoXY(12, 21);
  Writeln('         [T]<-- Test extern Trigger (Reset, Start, Stop)        ');
  GotoXY(12, 22);
  Write  ('         [U]<-- Overrun-Test (ext. 1kHz-Trigger 1:1)            ');

  ini_msg_win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
 End; {menue_win}


{xxx}  {Ab hier sollten User-Erweiterungen beginnen!!}

 PROCEDURE Mil_Start_Sollw;
  label 99;
  var Sollw1, Sollw2 : Word;
      MilErr : TMilErr;
      Fct    : TFct;

  begin
   repeat
    Ini_Text_Win;
    GotoXY(20, 05); write('----- Start-ZÑhler -----');
    GotoXY(15, 10); write ('     Sollwert(1)        Sollwert(2)');
    GotoXY(15, 11); write ('Hex');
    GotoXY(15, 12); write ('Bit [31........16]     [15.......00]');

    GotoXY(5, 22);
    write ('Bitte Sollwert(1) eingeben: ');
    Sollw1 := Ask_Hex_Word;
    Set_Text_Win;
    GotoXY(24, 11); write(hex_word(Sollw1));
    GotoXY(05, 22);  write ('Bitte Sollwert(2) eingeben: ');

    Sollw2 := Ask_Hex_Word;
    Set_Text_Win;
    GotoXY(42, 11); write(hex_word(Sollw2));
    GotoXY(05, 22);  write ('                            ');
    Ini_Msg_Win;
    write('Eingabe richtig [J/N]: ');
    Ch := ReadKey;
   until Ch in ['j','J'];

    Ini_Text_Win;
    transf_cnt := 0;
    GotoXY(15,05); write('----- Schreibe Daten in den Start-ZÑhler -----');
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := fct_set_soll1;
    GotoXY(15,07); write  ('Function-Word Sollw(1) (Fct + Adr): ',hex_word(Fct.W),' [H]');
    Fct.B.Fct := fct_set_soll2;
    GotoXY(15,08); write  ('Function-Word Sollw(2) (Fct + Adr): ',hex_word(Fct.W),' [H]');

    GotoXY(06, 11); writeln('Transf-Cnt :');
    GotoXY(16, 14); write ('      Sollwert(1)     Sollwert(2)');
    GotoXY(06, 16); write ('Bit');

    GotoXY(20, 16); write ('[31........16]   [15.......00]');
    GotoXY(06, 15); write ('Data[Hex]');
    GotoXY(25, 15); write(hex_word(Sollw1));
    GotoXY(42, 15); write(hex_word(Sollw2));

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
      Fct.B.Fct := fct_set_soll1 ;
      Mil.Wr (Sollw1, Fct, MilErr);

      Fct.B.Fct := fct_set_soll2 ;
      Mil.Wr (Sollw2, Fct, MilErr);
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
  end; {mil_start_soll}

 PROCEDURE Mil_Stop_Sollw;
  label 99;
  var Sollw3, Sollw4 : Word;
      MilErr : TMilErr;
      Fct    : TFct;

  begin
   repeat
    Ini_Text_Win;
    GotoXY(21, 05); write('----- Stop-ZÑhler -----');
    GotoXY(15, 10); write ('     Sollwert(3)        Sollwert(4)');
    GotoXY(15, 11); write ('Hex');
    GotoXY(15, 12); write ('Bit [31........16]     [15.......00]');

    GotoXY(5, 22);
    write ('Bitte Sollwert(3) eingeben: ');
    Sollw3 := Ask_Hex_Word;
    Set_Text_Win;
    GotoXY(24, 11); write(hex_word(Sollw3));
    GotoXY(05, 22);  write ('Bitte Sollwert(4) eingeben: ');

    Sollw4 := Ask_Hex_Word;
    Set_Text_Win;
    GotoXY(42, 11); write(hex_word(Sollw4));
    GotoXY(05, 22);  write ('                            ');
    Ini_Msg_Win;
    write('Eingabe richtig [J/N]: ');
    Ch := ReadKey;
   until Ch in ['j','J'];

    Ini_Text_Win;
    transf_cnt := 0;
    GotoXY(15,05); write('----- Schreibe Daten in den Stop-ZÑhler -----');
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := fct_set_soll3;
    GotoXY(15,07); write  ('Function-Word Sollw(3) (Fct + Adr): ',hex_word(Fct.W),' [H]');
    Fct.B.Fct := fct_set_soll4;
    GotoXY(15,08); write  ('Function-Word Sollw(4) (Fct + Adr): ',hex_word(Fct.W),' [H]');

    GotoXY(06, 11); writeln('Transf-Cnt :');
    GotoXY(16, 14); write ('      Sollwert(3)     Sollwert(4)');
    GotoXY(06, 16); write ('Bit');

    GotoXY(20, 16); write ('[31........16]   [15.......00]');
    GotoXY(06, 15); write ('Data[Hex]');
    GotoXY(25, 15); write(hex_word(Sollw3));
    GotoXY(42, 15); write(hex_word(Sollw4));

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
      Fct.B.Fct := fct_set_soll3 ;
      Mil.Wr (Sollw3, Fct, MilErr);

      Fct.B.Fct := fct_set_soll4 ;
      Mil.Wr (Sollw4, Fct, MilErr);
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
  end; {mil_stop_soll}

 PROCEDURE displ_hw_stat_bits;
  Begin
     {Info-Anzeige der Bit-Belegung Hardware-Status}
      ini_info_win;
      writeln(' -----  Hardware Status  -----');
      writeln('                              ');
      writeln('                              ');
      writeln('                              ');
      writeln('Bit 07: User 5                ');
      writeln('Bit 06: User 4                ');
      writeln('Bit 05: User 3                ');
      writeln('Bit 04: User 2                ');
      writeln('Bit 03: User 1                ');
      writeln('Bit 02: User 0                ');
      writeln('Bit 01: 0=Stop Vorderfl.1=RÅck');
      write  ('Bit 00: 0=Trig. intern, 1=ext ');
   End; {displ_hw_stat_bits}

 PROCEDURE mil_rd_hwstatus;
 label 99;
 var Read_Data: Word;
     MilErr : TMilErr;
     Fct    : TFct;

  begin
   transf_cnt := 0;
   timout_cnt := 0;
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := fct_rd_hw_status;

   Ini_Text_Win;
   GotoXY(15,05); write('----- Lese Hardware-Status des Gatepuls Generators -----');
   GotoXY(06, 08);  writeln('Rd_Stat_Count :');
   GotoXY(06, 09);  writeln('Timeout_Count :');
   GotoXY(06, 14);  writeln('Stat-Data[Hex]:');
   GotoXY(06, 16);  writeln('Stat-Data[Bin]:');
   GotoXY(12, 17); writeln('          MSB             LSB');

   displ_hw_stat_bits;

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
      Mil.Reset;                                   {Clear FIFO}

      Mil.Rd (Read_Data, Fct, MilErr);
      if MilErr  <> No_Err then
       begin
         timout_cnt := timout_cnt + 1;
         GotoXY(28, 14);  write('    ');
         GotoXY(22, 16);  write('                   ');
       end
      else
       begin  {kein Timeout}
         GotoXY(28, 14);  write(hex_word(Read_Data));
         Hex_Bin_Str (read_data,bit16_str);
         GotoXY(22, 16);  write(bit16_str);
       end;

      GotoXY(20, 08); write(transf_cnt:12);
      GotoXY(20, 09); write(timout_cnt:12);
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
 end; {mil_rd_hwstatus}

  PROCEDURE displ_dyn_stat_bits;
  Begin
     {Info-Anzeige der Bit-Belegung Hardware-Status}
      ini_info_win;
      writeln(' ----  Dynamischer Status ----');
      writeln('                              ');
      writeln('                              ');
      writeln('                              ');
      writeln('Bit 07: frei                  ');
      writeln('Bit 06: frei                  ');
      writeln('Bit 05: Stop Counter abgel.   ');
      writeln('Bit 04: Stop Counter lÑuft    ');
      writeln('Bit 03: Start Counter abgel.  ');
      writeln('Bit 02: Start Counter lÑuft   ');
      writeln('Bit 01: Trigger overrun       ');
      write  ('Bit 00: Waiting for Trigger   ');
   End; {displ_hw_stat_bits}


 PROCEDURE Mil_Rd_DynStat;
 label 99;
 var Read_Data: Word;
     MilErr : TMilErr;
     Fct    : TFct;

  begin
   transf_cnt := 0;
   timout_cnt := 0;
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := fct_rd_ist1;

   Ini_Text_Win;
   GotoXY(15,05); write('----- Lese Dynamischen Status des Gatepuls Generators  -----');

   GotoXY(06, 08);  write('Rd_Istw_Count :');
   GotoXY(06, 09);  write('Timeout_Count :');
   GotoXY(06, 14);  write('Istw-Data[Hex]:');
   GotoXY(06, 16);  write('Istw-Data[Bin]:');
   GotoXY(12, 17); write ('          MSB             LSB');

   displ_dyn_stat_bits;

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
      Mil.Reset;                                   {Clear FIFO}

      Mil.Rd (Read_Data, Fct, MilErr);
      if MilErr  <> No_Err then
       begin
         timout_cnt := timout_cnt + 1;
         GotoXY(28, 14);  write('    ');
         GotoXY(22, 16);  write('                   ');
       end
      else
       begin  {kein Timeout}
         GotoXY(28, 14);  write(hex_word(Read_Data));
         Hex_Bin_Str (read_data,bit16_str);
         GotoXY(22, 16);  write(bit16_str);
       end;

      GotoXY(20, 08); write(transf_cnt:12);
      GotoXY(20, 09); write(timout_cnt:12);
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
 end; {Mil_Rd_DynStat}

  FUNCTION check_extern: BOOLEAN;      {PrÅfe, ob Jumper auf extern}
   LABEL 99;
   var Status_Data: Word;
       MilErr     : TMilErr;
       Fct        : TFct;
   Begin
    mil.reset;
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := fct_rd_hw_status;;

    Mil.Rd (Status_Data, Fct, MilErr);
    if MilErr  <> No_Err then
     begin
       Ini_Err_Win;
       write('ERROR: MIL-Timeout! Kein Status von IFC.  Ende mit <CR>');
       repeat until keypressed;
       Goto 99;
     end
    else
     begin  {kein Timeout}
      IF (Status_Data AND hw_stat_extern) = hw_stat_extern THEN
       Begin
        check_extern  := TRUE;
       End
      ELSE
       Begin
        check_extern := FALSE;
       End;
     end;
99:
  End; {check_extern}

 FUNCTION check_rfl: BOOLEAN;      {PrÅfe, ob Jumper auf RÅckflanke}
   LABEL 99;
   var Status_Data: Word;
       MilErr     : TMilErr;
       Fct        : TFct;

   Begin
    Mil.Reset;
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Fct_Rd_Hw_Status;;

    Mil.Rd (Status_Data, Fct, MilErr);
    if MilErr  <> No_Err then
     begin
       Ini_Err_Win;
       write('ERROR: MIL-Timeout! Kein Status von IFC.  Ende mit <CR>');
       repeat until keypressed;
       Goto 99;
     end
    else
     begin  {kein Timeout}
      IF (Status_Data AND  hw_stat_rfl) =  hw_stat_rfl THEN
       Begin
        check_rfl := TRUE;
       End
      ELSE
       Begin
        check_rfl := FALSE;
       End;
99:  end;
   End; {check_rfl}


 PROCEDURE Mil_Int_Start;
 label 99;
 var Read_Data: Word;
     MilErr : TMilErr;
     Fct    : TFct;

  begin
   transf_cnt := 0;
   timout_cnt := 0;

   IF check_extern THEN
    Begin
      Ini_Err_Win;
      write('Jumper Int/Ext steht auf Extern. Kein interner Start mîglich!!  <CR>');
      REPEAT UNTIL keypressed;
      GOTO 99;
    End;

   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := fct_int_start;

   Ini_Text_Win;
   GotoXY(20,05); write('----- Interner Start per Functionscode  -----');

   GotoXY(15,07); write  ('Function-Word (Intern. Start)  (Fct + Adr): ',hex_word(Fct.W),' [H]');
   GotoXY(06, 09);  write('Wr_Fct_Count  :');


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
      Mil.Reset;                                   {Clear FIFO}

      Mil.Rd (Read_Data, Fct, MilErr);
      if MilErr  <> No_Err then
       begin
         timout_cnt := timout_cnt + 1;
         GotoXY(28, 14);  write('    ');
         GotoXY(22, 16);  write('                   ');
       end
      else
       begin  {kein Timeout}
         GotoXY(28, 14);  write(hex_word(Read_Data));
         Hex_Bin_Str (read_data,bit16_str);
         GotoXY(22, 16);  write(bit16_str);
       end;

      GotoXY(20, 09); write(transf_cnt:12);
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
 end; {Mil_Int_Start}

 PROCEDURE Mil_Puls_Intern;
 label 99;
 var Read_Data: Word;
     MilErr : TMilErr;
     Fct    : TFct;
     Sollw1,Sollw2,Sollw3,Sollw4 : Word;

     procedure Displ_Rd_Data;
      begin
        Set_Text_Win;
        Fct.B.Fct := Fct_Rd_Ist1;                   {Lese dyn. Status}
        Mil.Rd (Read_Data, Fct, MilErr);
        if MilErr  <> No_Err then
         begin
           timout_cnt := timout_cnt + 1;
           GotoXY(28, 14);  write('    ');
           GotoXY(22, 16);  write('                   ');
         end
        else
         begin  {kein Timeout}
           GotoXY(28, 14);  write (hex_word(Read_Data));
           Hex_Bin_Str (Read_data,bit16_str);
           GotoXY(22, 16);  write(bit16_str);
         end;
      end;

  begin
   transf_cnt := 0;
   timout_cnt := 0;
   Fct.B.Adr  := Ifc_Test_Nr;

   IF check_extern THEN
    Begin
      Ini_Err_Win;
      write('Jumper Int/Ext steht auf Extern. Kein interner Start mîglich!!  <CR>');
      REPEAT UNTIL keypressed;
      GOTO 99;
    End;

   IF check_rfl THEN
    Begin
      Ini_Err_Win;
      write('Jumper Vfl/Rfl steht auf RÅckflanke. Kein interner Start erlaubt!!  <CR>');
      REPEAT UNTIL keypressed;
      GOTO 99;
    End;

   repeat
    Ini_Text_Win;
    GotoXY(15, 09); write ('            START-ZéHLER           ');
    GotoXY(15, 10); write ('     Sollwert(1)        Sollwert(2)');
    GotoXY(15, 11); write ('Hex');
    GotoXY(15, 12); write ('Bit [31........16]     [15.......00]');

    GotoXY(5, 22);
    write ('Bitte Sollwert(1) eingeben: ');
    Sollw1 := Ask_Hex_Word;
    Set_Text_Win;
    GotoXY(24, 11); write(hex_word(Sollw1));
    GotoXY(05, 22);  write ('Bitte Sollwert(2) eingeben: ');

    Sollw2 := Ask_Hex_Word;
    Set_Text_Win;
    GotoXY(42, 11); write(hex_word(Sollw2));
    GotoXY(05, 22);  write ('                            ');
    Ini_Msg_Win;
    write('Eingabe richtig [J/N]: ');
    Ch := ReadKey;
   until Ch in ['j','J'];

   repeat
    Ini_Text_Win;
    GotoXY(15, 09); write ('              STOP-ZéHLER          ');
    GotoXY(15, 10); write ('     Sollwert(3)        Sollwert(4)');
    GotoXY(15, 11); write ('Hex');
    GotoXY(15, 12); write ('Bit [31........16]     [15.......00]');

    GotoXY(5, 22);
    write ('Bitte Sollwert(3) eingeben: ');
    Sollw3 := Ask_Hex_Word;
    Set_Text_Win;
    GotoXY(24, 11); write(hex_word(Sollw3));
    GotoXY(05, 22);  write ('Bitte Sollwert(4) eingeben: ');

    Sollw4 := Ask_Hex_Word;
    Set_Text_Win;
    GotoXY(42, 11); write(hex_word(Sollw4));
    GotoXY(05, 22);  write ('                            ');
    Ini_Msg_Win;
    write('Eingabe richtig [J/N]: ');
    Ch := ReadKey;
   until Ch in ['j','J'];

   Ini_Text_Win;
   GotoXY(15, 03); write('----- Gate-Puls intern per Functionscode triggern -----');

   GotoXY(08, 06); write('Start-Counter --> Sollwert 1: ',hex_word(sollw1),' [Hex]  ' +
                        'Sollwert 2: ',hex_word(sollw2),' [Hex]');
   GotoXY(08, 07); write('Stop-Counter  --> Sollwert 3: ',hex_word(sollw3),' [Hex]  ' +
                        'Sollwert 4: ',hex_word(sollw4),' [Hex]');

   GotoXY(06,11); write('Test_Count   :');
   GotoXY(06,14); write('Dyn.Stat[HEX]:');
   GotoXY(06,16); write('Dyn.Stat[BIN]:');
   GotoXY(22,17); write('MSB             LSB');

   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Reset;                {Reset fÅr IFC-Karte}
   Mil.WrFct (Fct, MilErr);

   Displ_Dyn_Stat_Bits;
   Displ_Rd_Data;

  { Fct.B.Fct := fct_int_start;  }

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
      Set_Text_Win;
      Transf_Cnt := Transf_Cnt+ 1;
      Fct.B.Fct := Fct_Reset;                {Reset fÅr IFC-Karte}
      Mil.WrFct (Fct, MilErr);

      Fct.B.Fct := fct_set_soll1 ;           {ZÑhler setzen}
      Mil.Wr (Sollw1, Fct, MilErr);

      Fct.B.Fct := fct_set_soll2 ;
      Mil.Wr (Sollw2, Fct, MilErr);

      Fct.B.Fct := fct_set_soll3 ;
      Mil.Wr (Sollw3, Fct, MilErr);

      Fct.B.Fct := fct_set_soll4 ;
      Mil.Wr (Sollw4, Fct, MilErr);

      GotoXY(20, 11); write(transf_cnt:12);

             {Starte die Counter per Software}
      Fct.B.Fct := Fct_Int_Start;
      Mil.WrFct (Fct, MilErr);

      if Ch = ' ' then
       begin
         repeat
          Displ_Rd_Data;
         until Keypressed;
        end
       else
        begin
          Displ_Rd_Data;
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
 end; {Mil_Puls_Intern}


 PROCEDURE Mil_Puls_Extern;
 label 99;
 var Read_Data: Word;
     MilErr : TMilErr;
     Fct    : TFct;
     Sollw1,Sollw2,Sollw3,Sollw4 : Word;

     procedure Displ_Rd_Data;
      begin
        Set_Text_Win;
        Fct.B.Fct := Fct_Rd_Ist1;                   {Lese dyn. Status}
        Mil.Rd (Read_Data, Fct, MilErr);
        if MilErr  <> No_Err then
         begin
           timout_cnt := timout_cnt + 1;
           GotoXY(28, 14);  write('    ');
           GotoXY(22, 16);  write('                   ');
         end
        else
         begin  {kein Timeout}
           GotoXY(28, 14);  write(hex_word(Read_Data));
           Hex_Bin_Str (Read_data,bit16_str);
           GotoXY(22, 16);  write(bit16_str);
         end;
      end;

  begin
   transf_cnt := 0;
   timout_cnt := 0;
   Fct.B.Adr  := Ifc_Test_Nr;

   IF not check_extern THEN
    Begin
      Ini_Err_Win;
      write('Jumper Int/Ext steht auf Intern. Kein externer Start mîglich!!  <CR>');
      REPEAT UNTIL keypressed;
      GOTO 99;
    End;

   repeat
    Ini_Text_Win;
    GotoXY(15, 09); write ('            START-ZéHLER           ');
    GotoXY(15, 10); write ('     Sollwert(1)        Sollwert(2)');
    GotoXY(15, 11); write ('Hex');
    GotoXY(15, 12); write ('Bit [31........16]     [15.......00]');

    GotoXY(5, 22);
    write ('Bitte Sollwert(1) eingeben: ');
    Sollw1 := Ask_Hex_Word;
    Set_Text_Win;
    GotoXY(24, 11); write(hex_word(Sollw1));
    GotoXY(05, 22);  write ('Bitte Sollwert(2) eingeben: ');

    Sollw2 := Ask_Hex_Word;
    Set_Text_Win;
    GotoXY(42, 11); write(hex_word(Sollw2));
    GotoXY(05, 22);  write ('                            ');
    Ini_Msg_Win;
    write('Eingabe richtig [J/N]: ');
    Ch := ReadKey;
   until Ch in ['j','J'];

   repeat
    Ini_Text_Win;
    GotoXY(15, 09); write ('              STOP-ZéHLER          ');
    GotoXY(15, 10); write ('     Sollwert(3)        Sollwert(4)');
    GotoXY(15, 11); write ('Hex');
    GotoXY(15, 12); write ('Bit [31........16]     [15.......00]');

    GotoXY(5, 22);
    write ('Bitte Sollwert(3) eingeben: ');
    Sollw3 := Ask_Hex_Word;
    Set_Text_Win;
    GotoXY(24, 11); write(hex_word(Sollw3));
    GotoXY(05, 22);  write ('Bitte Sollwert(4) eingeben: ');

    Sollw4 := Ask_Hex_Word;
    Set_Text_Win;
    GotoXY(42, 11); write(hex_word(Sollw4));
    GotoXY(05, 22);  write ('                            ');
    Ini_Msg_Win;
    write('Eingabe richtig [J/N]: ');
    Ch := ReadKey;
   until Ch in ['j','J'];

   Ini_Text_Win;
   GotoXY(15, 03); write('----- Gate-Puls extern triggern  -----');

   GotoXY(08, 06); write('Start-Counter --> Sollwert 1: ',hex_word(sollw1),' [Hex]  ' +
                        'Sollwert 2: ',hex_word(sollw2),' [Hex]');
   GotoXY(08, 07); write('Stop-Counter  --> Sollwert 3: ',hex_word(sollw3),' [Hex]  ' +
                        'Sollwert 4: ',hex_word(sollw4),' [Hex]');

   GotoXY(06,11); write('Test_Count   :');
   GotoXY(06,14); write('Dyn.Stat[HEX]:');
   GotoXY(06,16); write('Dyn.Stat[BIN]:');
   GotoXY(22,17); write('MSB             LSB');

   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Reset;                {Reset fÅr IFC-Karte}
   Mil.WrFct (Fct, MilErr);

   Displ_Dyn_Stat_Bits;
   Displ_Rd_Data;

{   Fct.B.Fct := fct_int_start;}

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
      Fct.B.Fct := Fct_Reset;                {Reset fÅr IFC-Karte}
      Mil.WrFct (Fct, MilErr);

      Fct.B.Fct := fct_set_soll1 ;           {ZÑhler setzen}
      Mil.Wr (Sollw1, Fct, MilErr);

      Fct.B.Fct := fct_set_soll2 ;
      Mil.Wr (Sollw2, Fct, MilErr);

      Fct.B.Fct := fct_set_soll3 ;
      Mil.Wr (Sollw3, Fct, MilErr);

      Fct.B.Fct := fct_set_soll4 ;
      Mil.Wr (Sollw4, Fct, MilErr);

      GotoXY(20, 11); write(transf_cnt:12);

      if Ch = ' ' then
       begin
         repeat
          Displ_Rd_Data;
         until Keypressed;
        end
       else
        begin
          Displ_Rd_Data;
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
 end; {Mil_Puls_Extern}


 PROCEDURE Mil_Trig_Ovr;
 label 99;
 var Read_Data: Word;
     MilErr : TMilErr;
     Fct    : TFct;
     Sollw1,Sollw2,Sollw3,Sollw4 : Word;

   procedure set_counter;                    {Counter setzen u. starten}
    begin
      Fct.B.Fct := Fct_Reset;                {Reset fÅr IFC-Karte}
      Mil.WrFct (Fct, MilErr);
      Fct.B.Fct := fct_set_soll1 ;           {ZÑhler setzen}
      Mil.Wr (Sollw1, Fct, MilErr);
      Fct.B.Fct := fct_set_soll2 ;
      Mil.Wr (Sollw2, Fct, MilErr);
      Fct.B.Fct := fct_set_soll3 ;
      Mil.Wr (Sollw3, Fct, MilErr);
      Fct.B.Fct := fct_set_soll4 ;
      Mil.Wr (Sollw4, Fct, MilErr);           {Sollwert 4 startet}
    end;

  begin
   transf_cnt := 0;
   timout_cnt := 0;
   Fct.B.Adr  := Ifc_Test_Nr;
   Ini_Text_Win;

   IF not check_extern THEN
    Begin
      Ini_Err_Win;
      write('Jumper Int/Ext steht auf Intern. Kein externer Start mîglich!!  <CR>');
      REPEAT UNTIL keypressed;
      GOTO 99;
    End;

   IF check_rfl THEN
    Begin
      Ini_Err_Win;
      write('Jumper Vfl/Rfl steht auf RÅckflanke. Kein interner Start erlaubt!!  <CR>');
      REPEAT UNTIL keypressed;
      GOTO 99;
    End;

                     {Init Counter-Settings}
    sollw1 := 0;
    sollw2 := 60000; {x 50ns=3 ms}
    sollw3 := 0;
    sollw4 := 65000; {x 50ns=3,25 ms -> Gate-Puls = 250 us}

    Ini_Text_Win;
    GotoXY(20, 03); write('----- Automatischer Trigger-Over-Run Test  -----');
    GotoXY(05, 04); write('Hardware vorbereiten: Jumper extern, IN-Signal 1KHz, 1:1 Tastverh.       ');
    GotoXY(05, 05); write('Automat. Ablauf -> Bei Fehler Abbruch, Ursache wird angezeigt!           ');
    GotoXY(05, 06); write('Ohne ext. Trigger mu·  "Waiting for Trigger" als Fehler angezeigt werden!');
    GotoXY(06, 11); write('Test_Count   :');

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

      {PrÅfe indirekt, ob ext. Trig. vorhanden: Bit Waiting for Trigger}
      set_counter;                             {setze und starte Counter}
      Mil.Timer2_Wait(200);                        {setze 2ms}

                   {Lese den dynamischen Status}
      Fct.B.Fct := Fct_Rd_Ist1;                   {Lese dyn. Status}
      Mil.Rd (Read_Data, Fct, MilErr);
      if MilErr  <> No_Err then
       begin
         timout_cnt := timout_cnt + 1;
	 Ini_Err_Win;
	 write('ERROR: MIL-Timeout!!    Ende mit <CR>');
	 REPEAT UNTIL keypressed;
	 GOTO 99;
      end
      else
       begin  {kein Timeout}
        if (Read_Data and dy_stat_wait = dy_stat_wait) then
	  begin
	   Ini_Err_Win;
	   write('ERROR: Kein externer Trigger!! Ende mit <CR>');
	   REPEAT UNTIL keypressed;
	   GOTO 99;
	  end;
       end;

      {Test: Nach reset u. laden ohne Sollw4 mu· OVR nach max. 1ms gesetzt sein}
      Fct.B.Fct := Fct_Reset;                {Reset fÅr IFC-Karte}
      Mil.WrFct (Fct, MilErr);
      Fct.B.Fct := fct_set_soll1 ;           {ZÑhler setzen}
      Mil.Wr (Sollw1, Fct, MilErr);
      Fct.B.Fct := fct_set_soll2 ;
      Mil.Wr (Sollw2, Fct, MilErr);
      Fct.B.Fct := fct_set_soll3 ;
      Mil.Wr (Sollw3, Fct, MilErr);
      Mil.Timer2_Wait(200);                        {setze 2ms}

                    {Lese den dynamischen Status}
      Fct.B.Fct := Fct_Rd_Ist1;                   {Lese dyn. Status}
      Mil.Rd (Read_Data, Fct, MilErr);
      if MilErr  <> No_Err then
       begin
         timout_cnt := timout_cnt + 1;
	 Ini_Err_Win;
	 write('ERROR: MIL-Timeout!!    Ende mit <CR>');
	 REPEAT UNTIL keypressed;
	 GOTO 99;
       end
      else
       begin  {kein Timeout}
        IF NOT (read_data AND dy_stat_ovr = dy_stat_ovr) THEN
          Begin
	   Ini_Err_Win;
           write('ERROR: Nach Reset -> kein Overrun-Bit ohne SW4!! Ende mit <CR>');
           REPEAT UNTIL keypressed;
           GOTO 99;
          End;
       end;

              {Lade Start-ZÑhler u. prÅfe nach 2 ms ob ZÑhler lÑuft}
      set_counter;
      Mil.Timer2_Wait(200);                        {setze 2ms}
      Fct.B.Fct := Fct_Rd_Ist1;                   {Lese dyn. Status}
      Mil.Rd (Read_Data, Fct, MilErr);
      if MilErr  <> No_Err then
       begin
         timout_cnt := timout_cnt + 1;
	 Ini_Err_Win;
	 write('ERROR: MIL-Timeout!!    Ende mit <CR>');
	 REPEAT UNTIL keypressed;
	 GOTO 99;
       end
      else
       begin  {kein Timeout}
         IF NOT (read_data AND dy_stat_start_on = dy_stat_start_on) THEN
	   Begin
            Ini_Err_Win;
	    write('ERROR: Start-Counter-lÑuft-Bit im dyn. Status fehlt!! Ende mit <CR>');
	    REPEAT UNTIL keypressed;
	    GOTO 99;
	   End;
       end;

                     {PrÅfe, da· Start-Counter-abgelaufen Bit}
      set_counter;
      Mil.Timer2_Wait(700);                       {setze 7ms}
      Fct.B.Fct := Fct_Rd_Ist1;                   {Lese dyn. Status}
      Mil.Rd (Read_Data, Fct, MilErr);
      if MilErr  <> No_Err then
       begin
         timout_cnt := timout_cnt + 1;
	 Ini_Err_Win;
	 write('ERROR: MIL-Timeout!!    Ende mit <CR>');
	 REPEAT UNTIL keypressed;
	 GOTO 99;
       end
      else
       begin  {kein Timeout}
         IF NOT (read_data AND dy_stat_start_off = dy_stat_start_off) THEN
	   Begin
            Ini_Err_Win;
      	    write('ERROR: Start-Counter-abgelaufen-Bit im dyn. Status fehlt!!  <CR>');
	    REPEAT UNTIL keypressed;
	    GOTO 99;
	   End;
       end;

                              {PrÅfe Stop-Counter}
      set_counter;
      Mil.Timer2_Wait(200);                           {setze 2ms}
      Fct.B.Fct := Fct_Rd_Ist1;                   {Lese dyn. Status}
      Mil.Rd (Read_Data, Fct, MilErr);
      if MilErr  <> No_Err then
       begin
         timout_cnt := timout_cnt + 1;
	 Ini_Err_Win;
	 write('ERROR: MIL-Timeout!!    Ende mit <CR>');
	 REPEAT UNTIL keypressed;
	 GOTO 99;
       end
      else
       begin  {kein Timeout}
         IF NOT (read_data AND dy_stat_stop_on = dy_stat_stop_on) THEN
	   Begin
            Ini_Err_Win;
	    write('ERROR: Stop-Counter-lÑuft-Bit im dyn. Status fehlt!!  <CR>');
	    REPEAT UNTIL keypressed;
	    GOTO 99;
	   End;
       end;

                    {PrÅfe das Stop-Counter-abgelaufen Bit}
      set_counter;
      Mil.Timer2_Wait(700);                       {setze 7ms}
      Fct.B.Fct := Fct_Rd_Ist1;                   {Lese dyn. Status}
      Mil.Rd (Read_Data, Fct, MilErr);
      if MilErr  <> No_Err then
       begin
         timout_cnt := timout_cnt + 1;
	 Ini_Err_Win;
	 write('ERROR: MIL-Timeout!!    Ende mit <CR>');
	 REPEAT UNTIL keypressed;
	 GOTO 99;
       end
      else
       begin  {kein Timeout}
         IF NOT (read_data AND dy_stat_stop_off = dy_stat_stop_off) THEN
	   Begin
            Ini_Err_Win;
            write('ERROR: Stop-Counter-abgelaufen-Bit im dyn. Status fehlt!!  <CR>');
	    REPEAT UNTIL keypressed;
	    GOTO 99;
	   End;
       end;

      Fct.B.Fct := Fct_Reset;                {Reset fÅr IFC-Karte}
      Mil.WrFct (Fct, MilErr);
      GotoXY(20, 11); write(transf_cnt:12);
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
  end; {Mil_Trig_Ovr}


 procedure Mil_Reset;
  label 99;
  var
    MilErr : TMilErr;
    Fct    : TFct;

  begin
    Transf_Cnt := 0;
    Fct.B.Adr  := Ifc_Test_Nr;
    Fct.B.Fct := Fct_Reset;                {Reset fÅr IFC-Karte}

    Ini_Text_Win;
    GotoXY(26, 03); write('------- Reset IFC-Karte  -------');
    GotoXY(20, 05); write('Function-Word (Reset)  (Fct + Adr): ',hex_word(Fct.W),' [H]');
    GotoXY(06, 11); write('Test_Count   :');

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
      Mil.WrFct (Fct, MilErr);

      GotoXY(20, 11); write(transf_cnt:12);
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
  end;


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
     '1'      : Mil_Detect_Ifc_Compare;
     '2'      : begin
                  if Check_Ifc_Adr (Ifc_Test_Nr) then Mil_Rd_HS_Ctrl (Ifc_Test_Nr);
                end;
     '3'      : begin
                  if Check_Ifc_Adr (Ifc_Test_Nr) then Mil_Rd_HS_Status (Ifc_Test_Nr);
                end;
     '4'      : begin
                  if Check_Ifc_Adr (Ifc_Test_Nr) then Mil_Stat_All (Ifc_Test_Nr);
                end;
     '5'      : begin
                  Convert_Hex_Volt;
                end;
     '6'      : begin
                  Int_Mask;
                end;
     '7'      : begin
                  if Check_Ifc_Adr (Ifc_Test_Nr) then Mil_HS_Stat_Cmd (Ifc_Test_Nr);
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
		     Mil_Wr(Mil_Data);
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
     'z', 'Z' : begin
                  Telefon;
                end;

     'm', 'M' : begin
                 if Check_Ifc_Adr (Ifc_Test_Nr) then  Mil_Reset;
               end;
     'n', 'N' : begin
                 if Check_Ifc_Adr(Ifc_Test_Nr) then  Mil_Start_Sollw;
                 end;
     'o', 'O' : begin
                 if Check_Ifc_Adr(Ifc_Test_Nr) then  Mil_Stop_Sollw;
                end;
     'p', 'P' : begin
                 if Check_Ifc_Adr(Ifc_Test_Nr) then  Mil_Int_Start;
                end;
     'q', 'Q' : begin
                 if Check_Ifc_Adr(Ifc_Test_Nr) then  Mil_Rd_HwStatus;
                end;
     'r', 'R' : begin
                 if Check_Ifc_Adr(Ifc_Test_Nr) then  Mil_Rd_DynStat;
                end;
     's', 'S' : begin
                 if Check_Ifc_Adr(Ifc_Test_Nr) then  Mil_Puls_Intern;
                end;
     't', 'T' : begin
                 if Check_Ifc_Adr(Ifc_Test_Nr) then  Mil_Puls_Extern;
                end;
     'u', 'U' : begin
                 if Check_Ifc_Adr(Ifc_Test_Nr) then  Mil_Trig_Ovr;
                end;
     End; {CASE}
  UNTIL user_input in ['x','X'];
  Window(1, 1, 80, 25);
  TextBackground(Black);
  ClrScr;
END. {mil_pc}
