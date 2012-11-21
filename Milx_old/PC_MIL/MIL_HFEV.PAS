PROGRAM Mil_HfEv;         {MIL HF Events}
{ Autor des Basis-Programmes Mil_Base.Pas: G. Englert;      Erstellt 12.04.95

  Autor der Erweiterungen   :
  énderungen:
  14.08.96    Et        Test des Event-Piggy FG 495 010 zur Generierung von
                        Events fÅr ein TIF. Damit kann Pulszentrale
                        simuliert werden

}
{$S-}
uses Crt, WinDos, Datech, Datech_1;

CONST
 head_line =
      'Datentechnik                         MIL_HFEV   ' +
      '                    [05.02.1997]' +
      '                         Erzeugung von Events fÅr HF-ER                        ';

procedure menue_win;
VAR answer: CHAR;
begin
  Ini_Headl_Win;
  Write(head_line);
  Menue_Base;              {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}
  {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}

  GotoXY(5, 14);
  Writeln('       [M]<-- Lese  Piggy-Status + Setze ext. Event-Maske + Reset Pigy  ');
  GotoXY(5, 15);
  Writeln('       [N]<-- Lese  letzten Event                                       ');
  GotoXY(5, 16);
  Writeln('       [O]<-- Wr HF-Events                   ');
  GotoXY(5, 17);
  Write  ('       [P]<-- Sende Event (RÅcklesen Åber Event-Bus: ');
                         TextColor(Red); Write('spez. Kabel!!');  TextColor(Black); Write(')   ');
  GotoXY(5, 18);
  Writeln('       [Q]<-- Schreibe ext. Event-Daten [1..6] ins RAM + RÅcklesen      ');
  GotoXY(5, 19);
  Writeln('       [R]<-- Enable/Disable ext. Event                                 ');
{  GotoXY(5, 20);
  Write  ('       [S]<--                                                            ');
  GotoXY(5, 21);
  Write  ('       [T]<--                                                            ');
  GotoXY(5, 22);
  Write  ('       [U]<--                                                            ');
}
  Ini_Msg_Win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
 End; {menue_win}

var
Single_Step: Boolean;              {Globale Variable}

{xxx}  {Bisherige Routinen sind f. alle Anwender gleich!!
        Ab hier sollten spezielle User-Routinen beginnen}
const
{ Fct_Reset   = $14;  }
 Fct_Wr_Event       = $06;
 Fct_Wr_EventMask   = $07;
 Fct_En_ExtEvent    = $11;
 Fct_Dis_ExtEvent   = $12;
 Fct_EvtPiggy_Reset = $14;
 Fct_Rd_LastEvent   = $88;
 Fct_Rd_EventStatus = $8D;


procedure Evt_EnDis;
label 99;
var
     MilErr : TMilErr;
     Fct    : TFct;
     FTast  : Boolean;

  procedure  Set_TastEnDis_Win;
  begin
   Window(03, 21, 48, 23);
   TextBackground(Green);
   TextColor(Black);               {Setze Schriftfarbe}
  end;

 procedure Wr_Function (Fct_Code: TFct);
  begin
    Set_Text_Win;
    Transf_Cnt := Transf_Cnt+ 1;
    GotoXY(20, 11); write(transf_cnt:12);
    GotoXY(25,07); Write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
    Mil.WrFct (Fct_Code, MilErr);
  end; {Wr_Function}

begin
    Ini_Text_Win;
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Fct_En_ExtEvent;
    transf_cnt := 0;
    timout_wr  := 0;

    GotoXY(20,05); write('----- Schreibe Fct-Code auf den MIL-BUS -----');
    GotoXY(25,07); Write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
    GotoXY(6, 11); writeln('Wr-Data-Cnt: ');
    GotoXY(26,12); writeln('^  ^');

    Set_Text_Win;
    TextColor(Brown);
    GotoXY(03,18); write  ('Belegung der Funktions-Tasten:');
    TextColor(Black);

    Set_TastEnDis_Win;
    TextColor(Yellow);
    GotoXY(01, 01); Write('F1: Enable  ext. Event                  ');
    GotoXY(01, 02); Write('F4: Disable ext. Event                  ');
    FTast      := True;

    Ch := ' ';
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyEPressed;
      end;

    repeat
     repeat
      if not FTast then      {kein Mil-Transfer, falls F-Taste gedrÅckt}
        Wr_Function (Fct)
      else
        Ftast := False;
     until KeyEPressed or (Ch = ' ');
     Ch := NewReadKey;

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
       Taste_F1 : begin
                     Fct.B.Fct := Fct_En_ExtEvent;
                     Wr_Function (Fct);
                     Ini_Err_Win;
                     Write ('Ext. Event ENABLE!!!');
                     Mil.Timer2_Wait(100000);
                     Ini_Msg_Win;
                     Write('Stop/Single Step mit <SPACE>, Loop mit <CR>                       Ende mit [X]');
                     Ftast := True;
                     Ch := ' ';
                  end;
       Taste_F4 : begin
                     Fct.B.Fct := Fct_Dis_ExtEvent;
                     Wr_Function (Fct);
                     Ini_Err_Win;
                     Write ('Ext. Event DISABLE!!!');
                     Mil.Timer2_Wait(100000);
                     Ini_Msg_Win;
                     Write('Stop/Single Step mit <SPACE>, Loop mit <CR>                       Ende mit [X]');
                     Ftast := True;
                     Ch := ' ';
                  end;
       end;  {Case}
      end; {if}

     if Ch = ' ' then
       begin
        Ini_Msg_Win;
        Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
        repeat until KeyEPressed;
       end;
    until Ch in ['x','X'];
 99:
 end; {Evt_EnDis}

procedure Evt_Status;
  Label 99;
  const
   Z_Base = 5;

   Rd_Evt_Mask        = $003F;    {Ext. Maskenbits nur Bit 0..5}
   Rd_Evt_Mask1       = $0001;
   Rd_Evt_Mask2       = $0002;
   Rd_Evt_Mask3       = $0004;
   Rd_Evt_Mask4       = $0008;
   Rd_Evt_Mask5       = $0010;
   Rd_Evt_Mask6       = $0020;

 type
   TEvt_Mask_Bit  = (Mask1, Mask2, Mask3, Mask4, Mask5, Mask6);

  VAR read_data,fct_code : WORD;
      MilErr     : TMilErr;
      Fct        : TFct;
      Transf_Cnt : LongInt;
      Timout_Cnt : LongInt;
      Rd_Stat_Cnt:  LongInt;
      Adress     : Word;

  procedure  Set_TastEvt_Win;
  begin
   Window(03, 21, 48, 23);
   TextBackground(Green);
   TextColor(Black);               {Setze Schriftfarbe}
  end;

 procedure Ini_Event_Win;
  begin
   Window(50, 08, 80, 24);
   TextBackground(Cyan);
   TextColor(Black);               {Setze Schriftfarbe}
   ClrScr;
  end;

 PROCEDURE displ_ifk_stat;
  Begin
     {Info-Anzeige der Bit-Belegung IFC-Status}
      Ini_Event_Win;
      writeln('Bit 15: frei                  ');
      writeln('Bit 14: Puls Event6: 1=positiv');
      writeln('Bit 13: Puls Event5:     "    ');
      writeln('Bit 12: Puls Event4:     "    ');
      writeln('Bit 11: Puls Event3:     "    ');
      writeln('Bit 10: Puls Event2:     "    ');
      writeln('Bit 09: Puls Event1:     "    ');
      writeln('Bit 08: Ext.Evts Enable: 1=En ');
      writeln;
      writeln('Bit 07: Event Fehler  1=Error ');
      writeln('Bit 06: Evt ext. gen. 1=ja    ');
      writeln('Bit 05: Event-Mask 6: 1=Enable');
      writeln('Bit 04: Event-Mask 5:    "    ');
      writeln('Bit 03: Event-Mask 4:    "    ');
      writeln('Bit 02: Event-Mask 3:    "    ');
      writeln('Bit 01: Event-Mask 2:    "    ');
      write  ('Bit 00: Event-Mask 1:    "    ');
   End; {displ_ifc_stat}

   PROCEDURE show_stat_reg;
    var Bit16_Strg: Str19;
        Read_Data : Word;
    Begin
     Set_Text_Win;
     Rd_Stat_Cnt:= Rd_Stat_Cnt + 1;
     Fct.B.Adr  := Ifc_Test_Nr;
     Fct.B.Fct  := Fct_Rd_EventStatus;
     Mil.Rd (Read_data, Fct, MilErr);
     if MilErr = No_Err then
      begin
        GotoXY(28, Z_Base+7);  write(hex_word(read_data));
        Hex_Bin_Str (read_data, bit16_strg);
        GotoXY(22, Z_Base+8);  write(bit16_strg);
      end
     else
      begin
        GotoXY(28, Z_Base+7);  write('    ');
        TextColor (Red);
        GotoXY(22, Z_Base+8);  write('   Read Error!!    ');
        TextColor (Black);
      end;

     GotoXY(31, Z_Base+5); Write (Rd_Stat_Cnt:10);
     Fct.B.Fct := Fct_Rd_LastEvent;        {Letzten Event anzeigen}
     Mil.Rd (Read_data, Fct, MilErr);
     if MilErr = No_Err then
      begin
        GotoXY(28, Z_Base+10);  write(hex_word(read_data));
      end
     else
      begin
        GotoXY(28, Z_Base+10);  write('    ');
     end;
    End; {show_stat_reg; }

  procedure Evt_Mask_Toggle (Mask_Nr: TEvt_Mask_Bit);
   label 100;
   var Write_Data : Word;
       Rd_Data    : Word;
   begin
    Rd_Stat_Cnt:= Rd_Stat_Cnt + 1;
    Fct.B.Adr  := Ifc_Test_Nr;
    Fct.B.Fct  := Fct_Rd_EventStatus;
    Mil.Rd (Rd_Data, Fct, MilErr);
    if MilErr = No_Err then
     begin
      Fct.B.Fct := Fct_Wr_EventMask;
      Write_Data := Rd_Data and Rd_Evt_Mask; {Maskenbits nur Bit 0..5}
      case Mask_Nr of
        Mask1 : begin
                 if  BitTst (Write_Data, 0) then
                   Write_Data := BitClr (Write_Data,0)
                 else
                   Write_Data := BitSet (Write_Data,0);
                 Mil.Wr (Write_Data, Fct, MilErr);
                 Transf_Cnt := Transf_Cnt+ 1;
                end;
        Mask2 : begin
                 if  BitTst (Write_Data, 1) then
                   Write_Data := BitClr (Write_Data,1)
                 else
                   Write_Data := BitSet (Write_Data,1);
                 Mil.Wr (Write_Data, Fct, MilErr);
                 Transf_Cnt := Transf_Cnt+ 1;
                end;
        Mask3 : begin
                 if  BitTst (Write_Data, 2) then
                   Write_Data := BitClr (Write_Data,2)
                 else
                   Write_Data := BitSet (Write_Data,2);
                 Mil.Wr (Write_Data, Fct, MilErr);
                 Transf_Cnt := Transf_Cnt+ 1;
                end;
        Mask4 : begin
                 if  BitTst (Write_Data, 3) then
                   Write_Data := BitClr (Write_Data,3)
                 else
                   Write_Data := BitSet (Write_Data,3);
                 Mil.Wr (Write_Data, Fct, MilErr);
                 Transf_Cnt := Transf_Cnt+ 1;
                end;
        Mask5 : begin
                 if  BitTst (Write_Data, 4) then
                   Write_Data := BitClr (Write_Data,4)
                 else
                   Write_Data := BitSet (Write_Data,4);
                 Mil.Wr (Write_Data, Fct, MilErr);
                 Transf_Cnt := Transf_Cnt+ 1;
                end;
         Mask6 : begin
                 if  BitTst (Write_Data, 5) then
                   Write_Data := BitClr (Write_Data,5)
                 else
                   Write_Data := BitSet (Write_Data,5);
                 Mil.Wr (Write_Data, Fct, MilErr);
                 Transf_Cnt := Transf_Cnt+ 1;
                end;
      end; {Case}
      Show_Stat_Reg;
     end {if MilErr}
    else
     begin {Mil-Lesefehler}

     end;
    Set_Text_Win;
    GotoXY(31, Z_Base+3); write(transf_cnt:10);
    end; {Ifc_Mask_Toggle}

  Begin
   Ini_Text_Win;
   Displ_Ifk_Stat;
   Set_Text_Win;
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Rd_EventStatus;

   Rd_Stat_Cnt:= 0;
   transf_cnt := 0;
   timout_cnt := 0;
   GotoXY(16,01); write('------ Lese Status des Event-Piggy + Last-Event -----');
   GotoXY(16,02); write  ('Function-Word Read-Event-Status (Fct + Adr): ',hex_word(Fct.W),' [H]');
   TextColor(Yellow);
   GotoXY(15,03); write('Set/Clear Event-Maske[1..6]: mit F1..F6-Tasten toggeln! ');
   TextColor(Brown);
   GotoXY(50,05); write  ('Bedeutung der Event-Status-Bits');

   GotoXY(06,Z_Base+3);  write('Wr_Mask_Count :');
   GotoXY(06,Z_Base+5);  write('Stat-Rd-Count :');
   GotoXY(35,Z_Base+6);  write('^  ^');
   GotoXY(06,Z_Base+7);  write('Stat-Data[Hex]:');
   GotoXY(06,Z_Base+8);  write('Stat-Data[Bin]:');
   GotoXY(22,Z_Base+9);  write('MSB             LSB');
   GotoXY(06,Z_Base+10);  write('Last-Evnt[Hex]:');

   Set_Text_Win;
   TextColor(Brown);
   GotoXY(03,18); write  ('Belegung der Funktions-Tasten:');

   Set_TastEvt_Win;
   TextColor(Yellow);
   GotoXY(01, 01); Write('F1: Set Evt-Mask     F10: En  ext. Event');
   GotoXY(01, 02); Write(' ', (chr($7C)),'    [1..6]         F11: Dis ext. Event');
   GotoXY(01, 03); Write('F6: Set Evt-Mask     F12: Reset Evt-Pigy');
   TextColor(Black);

   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Set_Text_win;
       Show_Stat_Reg;
       Mil.Timer2_Wait(1000);
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Set_Text_win;
       Show_Stat_Reg;
       Mil.Timer2_Wait(1000);
      end;

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : Evt_Mask_Toggle (Mask1);
        Taste_F2 : Evt_Mask_Toggle (Mask2);
        Taste_F3 : Evt_Mask_Toggle (Mask3);
        Taste_F4 : Evt_Mask_Toggle (Mask4);
        Taste_F5 : Evt_Mask_Toggle (Mask5);
        Taste_F6 : Evt_Mask_Toggle (Mask6);
        Taste_F10: begin
                    Fct.B.Fct := Fct_En_ExtEvent ;
                    Mil.WrFct (Fct, MilErr);
                    Ini_Err_Win;
                    Write ('Ext. Event ENABLE!!!');
                    Mil.Timer2_Wait(150000);
                    Ini_Msg_Win;
                    Write('Stop/Single Step mit <SPACE>, Loop mit <CR>                       Ende mit [X]');
                    Ch := ' ';
                   end; {Taste_F10}

        Taste_F11: begin
                    Fct.B.Fct := Fct_Dis_ExtEvent;
                    Mil.WrFct (Fct, MilErr);
                    Ini_Err_Win;
                    Write ('Ext. Event DISABLE!!!');
                    Mil.Timer2_Wait(150000);
                    Ini_Msg_Win;
                    Write('Stop/Single Step mit <SPACE>, Loop mit <CR>                       Ende mit [X]');
                    Ch := ' ';
                   end; {Taste_F11}
        Taste_F12: begin
                     Fct.B.Fct := Fct_EvtPiggy_Reset;
                     Mil.WrFct (Fct, MilErr);
                     Ini_Err_Win;
                     Write ('Event-Piggy: RESET!!!');
                     Mil.Timer2_Wait(150000);
                     Ini_Msg_Win;
                     Write('Stop/Single Step mit <SPACE>, Loop mit <CR>                       Ende mit [X]');
                     Ch := ' ';
                   end; {Taste_F12}
       end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
 end; {Evt_Status}


 procedure Evt_Rd_Last;
  Label 99;
  VAR Read_Data,pc_status : WORD;
      rd_timeout : BOOLEAN;
      MilErr : TMilErr;
      Fct    : TFct;
      Fct_ok : Boolean;
      Rd_Fct1, Rd_Fct2, Rd_Fct3 : Byte;
      N      : Byte;
      Anzahl : Byte;

   PROCEDURE get_data;
    var Rd_Dta : Word;
        Bit16_Strg : Str19;
    Begin
     Fct.B.Fct := Fct_Rd_LastEvent;
     Mil.Rd (Rd_Dta, Fct, MilErr);
     IF MilErr  <> No_Err THEN
      Begin
        timout_cnt := timout_cnt + 1;
        rd_timeout := TRUE;
        TextColor (Red);
        GotoXY(22,12); write(timout_cnt:12);
        TextColor (Black);
        GotoXY(25, 17);  write('    ');
        GotoXY(17, 18);  write('                   ');
        Mil.reset;
      End
     ELSE
      Begin  {kein Timeout}
       rd_timeout := FALSE;
       GotoXY(25, 17);  write(hex_word(Rd_Dta));
       Hex_Bin_Str (Rd_Dta,bit16_strg);
       GotoXY(17, 18);  write(bit16_strg);
      End;
    End; {get_data}

  Begin
    transf_cnt := 0;
    timout_cnt := 0;
    Fct_ok     := False;
    Fct.B.Adr  := Ifc_Test_Nr;

    Ini_Text_Win;
    Fct.B.Fct := Fct_Rd_LastEvent;  {nur fÅr Anzeige}
    Ini_Text_Win;
    GotoXY(27,05); write('----- Lese letzten EVENT -----');
    GotoXY(25,07); write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
    GotoXY(06,11); writeln('Rd_Data_Cnt  :');
    GotoXY(26,12); writeln('^  ^');
    GotoXY(06,12); writeln('Timeout_Count: ');
    GotoXY(22,12); writeln(timout_cnt:12);

    GotoXY(02,17); writeln('MIL-Data[H]:');
    GotoXY(08,18); writeln('[Bin]:');
    GotoXY(17,19); writeln('MSB             LSB');

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
 end; {Evt_Rd_Last }


 procedure Evt_WrRAM;
  Label 99;
  const
   Z_Base     = 10;
   S_Base     = 40;
   S_RAM_Base = 6;
   Rd_Fct_Base = $80;  {Rd RAM1: Fct-Code 81H usw.}
   Wr_Fct_Base = 8;    {Wr RAM1: Fct-Code  9  usw. }

  var
   fct_code : WORD;
   MilErr : TMilErr;
   Fct    : TFct;
   Transf_Cnt: LongInt;
   Timout_Cnt: LongInt;
   Adress    : Word;

  procedure  Set_TastEvt_Win;
   begin
    Window(S_Base, 21, S_Base+40, 23);
    TextBackground(Green);
    TextColor(Black);               {Setze Schriftfarbe}
   end;

 type TLife = (Norm, Blink);

 procedure Life_Sign (Mode: TLife);
  const S_Aktiv   = S_RAM_Base+22;
        Z_Aktiv   = Z_Base+5;
        Life_Time1 = 5000;
        Life_Time2 = 2000;
  var Life_Wait : LongInt;
  begin
    Cursor (False);
    Set_Text_Win;
    if Mode = Norm then
     begin
      Life_Wait := Life_Time2;
      Set_Text_Win;
      TextColor(Yellow);
      GotoXY(S_Aktiv, Z_Aktiv);  Write (chr($7C)); Mil.Timer2_Wait (Life_Wait);
      GotoXY(S_Aktiv, Z_Aktiv);  Write ('/');      Mil.Timer2_Wait (Life_Wait);
      GotoXY(S_Aktiv, Z_Aktiv);  Write (chr($2D)); Mil.Timer2_Wait (Life_Wait);
      GotoXY(S_Aktiv, Z_Aktiv);  Write ('\');      Mil.Timer2_Wait (Life_Wait);
     end
    else
     begin
       TextColor(Red+128);
       GotoXY(S_Aktiv, Z_Aktiv); Write (chr($B2));
     end;
    TextColor(Black);
    Cursor(True);
   end; {Life_Sign}

 procedure Ini_Event_Win;
  begin
   Window(50, 08, 80, 24);
   TextBackground(Cyan);
   TextColor(Black);               {Setze Schriftfarbe}
   ClrScr;
  end;

 procedure Disp_EvtRAM;
  var I : Byte;
  begin
    Cursor(False);
    for I := 1 to 6 do
     begin
       Fct.B.Fct := Rd_Fct_Base + I;
       Mil.Rd (Read_Data, Fct, MilErr);
       GotoXY(S_RAM_Base+20,Z_Base+5+I);
       if MilErr = No_Err then
        begin
          Write (hex_word(Read_Data));
        end
       else
        begin
          Write ('    ');
        end;
     end; {for}
  end; {Disp-Ram}

 procedure Disp_WrData;
  var Bit16_Strg : Str19;
  begin
    TextColor(Black);
    Set_Text_Win;
    GotoXY(S_RAM_Base+20,Z_Base-1);
    Write (hex_word(Write_Data));
    Hex_Bin_Str (Write_Data,bit16_strg);
    GotoXY(S_RAM_Base+20,Z_Base);  write(bit16_strg);
  end; {Disp_WrDAta}

 procedure Wr_Evt_RAM (RAM_Nr: Byte; Data: Word);
  var N: Byte;
  begin
    if RAM_Nr in [1..6] then
     begin
      Fct.B.Fct := Wr_Fct_Base + RAM_Nr;
      Mil.Wr (Data, Fct, MilErr);
      Set_Text_Win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(22,06); write(transf_cnt:10);
      GotoXY(71,06); write(hex_Word(Fct.W));
      TextColor (Brown); Write(' [H]');  TextColor(Black);

      {Zeige auf RAM, in das geschrieben wurde}
      for N := 1 to 6 do
       begin
         GotoXY(S_RAM_Base-2,Z_Base+5+N);
         Write ('  ');
       end;
      GotoXY(S_RAM_Base-2,Z_Base+5+RAM_Nr);
      TextColor(Red);
      Write ('->');
      TextColor(Black);
     end;
  end; {Wr_Evt_RAM}

  Begin             {Evt_WrRAM}
   Cursor(False);
   Ini_Text_Win;
   Set_Text_Win;
   Fct.B.Adr := Ifc_Test_Nr;
   Write_Data:= 0;

   Fct.B.Fct := $81;
   transf_cnt := 0;
   timout_cnt := 0;
   GotoXY(22,01); write('----- Lesen/Schreiben Event-RAM -----');
   GotoXY(16,02); write  ('Function-Word Read-Event-RAM (Fct + Adr): ',hex_word(Fct.W));
   Fct.B.Fct := $86;  write ('..',hex_word(Fct.W),' [H]');
   TextColor(Yellow);
   GotoXY(15,03); write('Mit den F-Tasten [1..6] werden Wr-Data zum RAM geschrieben');

   TextColor(Brown);
   GotoXY(06,06);   write('Wr_RAM_Cnt     :');
   GotoXY(26,07);   write('^  ^');
   GotoXY(38,06);   write ('Fct-Word Wr-Event-RAM (Fct+Adr): ');

   GotoXY(06,Z_Base-1);              Write('Wr-Data   [Hex]: ');
   GotoXY(S_RAM_Base+20,Z_Base-1);   Write (hex_word(Write_Data));
   GotoXY(06,Z_Base+0);              Write('          [Bin]: ');
   GotoXY(S_RAM_Base+20,Z_Base+1);   Write('MSB             LSB');
   Disp_WrData;

   TextColor(Brown);
   GotoXY(S_RAM_Base,Z_Base+5);   write('- Read aktiv -->');
   GotoXY(S_RAM_Base,Z_Base+6);   write('RAM1-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base+7);   write('RAM2-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base+8);   write('RAM3-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base+9);   write('RAM4-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base+10);  write('RAM5-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base+11);  write('RAM6-Data [Hex]:');
   TextColor(Black);

   Set_TastEvt_Win;
   TextColor(Yellow);
   GotoXY(01, 01); Write('F1: Wr Evt-RAM[1]    F11: Wr-Data  = 0  ');
   GotoXY(01, 02); Write(' ', (chr($7C)),'     [1..6]        F12: Wr-Data [Hex] ');
   GotoXY(01, 03); Write('F6: Wr Evt-RAM[6]    <- -> Bit schieben ');

   Set_Text_Win;
   TextColor(Brown);
   GotoXY(S_Base,18); write  ('Belegung der Funktions-Tasten:');
   TextColor(Black);

   Cursor(True);
   Std_Msg;
   Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Life_Sign (Norm);
       Disp_EvtRAM;
       Mil.Timer2_Wait(1000);
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Set_Text_win;
       Life_Sign (Norm);
       Disp_EvtRAM;
       Mil.Timer2_Wait(1000);
      end;

    if Ch = #0 then
     begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin Wr_Evt_RAM(1, Write_Data); Disp_EvtRAM; Life_Sign (Norm); end;
        Taste_F2 : begin Wr_Evt_RAM(2, Write_Data); Disp_EvtRAM; Life_Sign (Norm); end;
        Taste_F3 : begin Wr_Evt_RAM(3, Write_Data); Disp_EvtRAM; Life_Sign (Norm); end;
        Taste_F4 : begin Wr_Evt_RAM(4, Write_Data); Disp_EvtRAM; Life_Sign (Norm); end;
        Taste_F5 : begin Wr_Evt_RAM(5, Write_Data); Disp_EvtRAM; Life_Sign (Norm); end;
        Taste_F6 : begin Wr_Evt_RAM(6, Write_Data); Disp_EvtRAM; Life_Sign (Norm); end;
        Taste_F11: begin
                    Write_Data := 0;
                    Disp_WrData;
                    Std_Msg;
                   end; {Taste_F10}
        Taste_F12: begin
                    if Ask_Hex_Break (Write_Data, Wrd) then Disp_WrData;
                    Std_Msg;
                   end; {Taste_F11}
       Taste_Pfeil_Links : begin
                            if Write_Data = $0000 then Write_Data := $1
                            else Write_Data := Write_Data shl 1;
                            Disp_WrData;
                            Std_Msg;
                            end;  {Taste_Pfeil_Links}
       Taste_Pfeil_Rechts: begin
                            if Write_Data = $0000 then Write_Data := $8000
                            else Write_Data := Write_Data shr 1;
                            Disp_WrData;
                            Std_Msg;
                           end;  {Taste_Pfeil_Rechts}
       end; {case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:    Cursor(True);
  end; {Evt_WrRAM}


 Procedure Evt_WrRD_Last;
  LABEL 99;
   VAR
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Bit16_Strg: Str19;
     Code   : Word;
     Adress : Word;
     Wr_Data: Word;
     Auto_Test   : Boolean;

  procedure  Set_TastWr_Win;
   begin
    Window(39, 21, 80, 23);
    TextBackground(Green);
    TextColor(Black);               {Setze Schriftfarbe}
   end;

   procedure Displ;
    begin
      Set_Text_Win;
      GotoXY(18,10); write(transf_cnt:10);
      GotoXY(48,10); write(hex_word(Wr_Data));
      if not Auto_Test then
       begin
        Hex_Bin_Str (Wr_Data,bit16_strg);
        GotoXY(42, 11);  write(bit16_strg);
       end
      else
       begin
         GotoXY(42, 11);  write('                   ');
       end;
      TextColor (Red);
      GotoXY(18, 12);  write(Error_Cnt:10);
      TextColor (Black);
     end; {Wr-Data}

  procedure Wr_SW (Data: Word);
   begin
     Transf_Cnt := Transf_Cnt+ 1;
     Fct.B.Adr := Ifc_Test_Nr;
     Fct.B.Fct := Fct_Wr_Event;
     Mil.Wr (Data, Fct, MilErr);
     Displ;
   end; {Wr-Data}

  PROCEDURE Get_Data (Snd_Dta: Word);
   var Rd_Data : Word;
       Bit16_Strg : Str19;
   Begin
    Set_Text_Win;
    Fct.B.Fct := Fct_Rd_LastEvent;
    Mil.Rd (Rd_Data, Fct, MilErr);
    IF MilErr  <> No_Err THEN
     Begin
       rd_timeout := TRUE;
       GotoXY(48, 13);  write('    ');
       TextColor(Red);
       GotoXY(42, 14);  write('   Read Timeout    ');
       TextColor(Black);
     End
    ELSE
     Begin  {kein Timeout}
      rd_timeout := FALSE;
      if Rd_Data = Snd_Dta then
        begin
         TextColor (Black);
         GotoXY(48, 13);  write(hex_word(Rd_Data));
         if not Auto_Test then
          begin
           Hex_Bin_Str (Rd_Data,bit16_strg);
           GotoXY(42, 14);  write(bit16_strg);
          end
         else
          begin
            GotoXY(42, 14);  write('                   ');
          end;
        end
      else
        begin
         TextColor(Red);
         GotoXY(48, 13);  write(hex_word(Rd_Data));
         if not Auto_Test then
          begin
           Hex_Bin_Str (Rd_Data,bit16_strg);
           GotoXY(42, 14);  write(bit16_strg);
          end
         else
          begin
            GotoXY(48, 13);  write('    ');
            GotoXY(42, 14);  write('                   ');
          end;
         Error_Cnt := Error_Cnt +1;
         GotoXY(18, 12);  write(Error_Cnt:10);
        end;
       end;
    Displ;
    TextColor(Black);
   End; {get_data}

   Begin
    Wr_Data    := 0;
    transf_cnt := 0;
    error_cnt  := 0;
    timout_wr  := 0;
    Single_Step:= True;
    Auto_Test  := False;

    Ini_Text_Win;
    Fct.B.Adr := Ifc_Test_Nr;

    Ini_Text_Win;
    GotoXY(15,03); write('----- Sende Event und lese als LAST-Event zurÅck -----');
    GotoXY(15,04); write('         Vergleiche Sende-Event und LAST-Event ');

    Fct.B.Fct  := Fct_Wr_Event;
    GotoXY(22,06); Write  ('Wr-Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
    Fct.B.Fct  :=  Fct_Rd_LastEvent;
    GotoXY(22,07); Write  ('Rd-Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');

    TextColor(Brown);
    GotoXY(5, 10); write('Wr-Data-Cnt:                Write-Data[H]:                ');
    GotoXY(22,11); write('^  ^');
    GotoXY(5, 12); write('Error-Count: ');
    GotoXY(05,13); write('                            Rd-Data [Hex]:');
    GotoXY(42,15); write('MSB             LSB');

    GotoXY(39,18); write('Belegung Funktions- u. Sondertasten: ');
    GotoXY(5, 18); write('Autom. Incr-Test: ');
    TextColor(Black);
    GotoXY(23,18); if Auto_Test then Write ('EIN') else Write ('AUS');

    Set_TastWr_Win;
    TextColor(Yellow);
    GotoXY(01, 01); Write('F1: Event [Hex]     F11: EIN Incr-Test   ');
    GotoXY(01, 02); Write('F5: Event = 0       F12: AUS Incr-Test   ');
    GotoXY(01, 03); Write('F9: Clr Err-Counts  <- -> Bit schieben   ');
    Displ;

    Mil.Reset;
    Std_Msg;                            { clear fifo }
    Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       if Auto_Test then Wr_Data := Wr_Data +1;
       Wr_SW    (Wr_Data);
       Get_Data (Wr_Data);
       Single_Step := True;
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       if Auto_Test then Wr_Data := Wr_Data +1;
       Wr_SW    (Wr_Data);
       Get_Data (Wr_Data);
       Displ;
      end;

    if KeyEPressed then Ch := NewReadkey;
     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
       Taste_F1 : begin
                   if Ask_Hex_Break (Wr_Data, Wrd) then Displ;
                   Std_Msg;
                  end;
       Taste_F2 : begin
                  end;
       Taste_F5 : begin
                   Wr_Data := 0;
                   Displ;
                  end;
       Taste_F9: begin
                   Error_Cnt := 0;
                   Displ;
                  end; {Taste_F12}
       Taste_F11: begin
                    Auto_Test:= True;
                    Set_Text_Win;
                    GotoXY(23,18); if Auto_Test then Write ('EIN') else Write ('AUS');
                 end; {Taste_F10}
       Taste_F12: begin
                    Auto_Test := False;
                    Set_Text_Win;
                    GotoXY(23,18); if Auto_Test then Write ('EIN') else Write ('AUS');
                  end; {Taste_F12}
       Taste_Pfeil_Links : begin
                             if Wr_Data = $0000 then Wr_Data := $1
                             else Wr_Data := Wr_Data shl 1;
                             Displ;
                            end;  {Taste_Pfeil_Links}
       Taste_Pfeil_Rechts: begin
                            if Wr_Data = $0000 then Wr_Data := $8000
                            else Wr_Data := Wr_Data shr 1;
                            Displ;
                           end;  {Taste_Pfeil_Rechts}
      end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
 99:
End; {Evt_WrRD_Last}



 procedure Evt_WrRd_Fifo;   {Daten werden direkt aus dem RCV-Fifo gelesen!!}
  LABEL 99;                 {u. a. weil kein Functionscode nîtig ist. }
   VAR
     Error_Cnt     : LONGINT;
     Fifo_Err_Cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Bit16_Strg: Str19;
     Code   : Word;
     Adress : Word;
     Wr_Data: Word;
     Auto_Test   : Boolean;

  procedure  Set_TastWr_Win;
   begin
    Window(39, 21, 80, 23);
    TextBackground(Green);
    TextColor(Black);               {Setze Schriftfarbe}
   end;

  procedure Std_Msg;
   begin
    Ini_Msg_Win;
    Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
   end;

   procedure Displ;
    begin
      Set_Text_Win;
      GotoXY(18,10); write(transf_cnt:10);
      GotoXY(48,10); write(hex_word(Wr_Data));
      if not Auto_Test then
       begin
        Hex_Bin_Str (Wr_Data,bit16_strg);
        GotoXY(42, 11);  write(bit16_strg);
       end
      else
       begin
         GotoXY(42, 11);  write('                   ');
       end;
      TextColor (Red);
      GotoXY(18, 12);  write(Error_Cnt:10);
      GotoXY(18, 13);  write(Fifo_Err_Cnt:10);

      TextColor (Black);
     end; {Wr-Data}

  procedure Wr_SW (Data: Word);
   begin
     Mil.Reset;          {Klare VerhÑltnisse! Vorsicht, lîscht alle Timer !!!}
     Transf_Cnt := Transf_Cnt+ 1;
     Displ;
     Fct.B.Adr := Ifc_Test_Nr;
     Fct.B.Fct := Fct_Wr_Event;
     Mil.Wr (Data, Fct, MilErr);
   end; {Wr-Data}

  PROCEDURE Get_Data (Snd_Dta: Word);
   var Rd_Data : Word;
       Bit16_Strg : Str19;
       Pc_Stat    : TPcStat;
   Begin
    Set_Text_Win;
      {Ist Fifo vor der Wartezeit leer? (leider von CPU-Speed beeinflu·t)}
{    Pc_Stat.W := PortW [Port_Stat];
    if not (FfoEty in Pc_Stat.B) then
     begin
      Fifo_Err_Cnt := Fifo_Err_Cnt + 1;
      rd_timeout := TRUE;
      GotoXY(48, 13);  write('    ');
      TextColor(Red);
      GotoXY(42, 14);  write('Snd: not Fifo empty');
      TextColor(Black);
      Ini_Err_Win;
      Write('ERROR: Nach Evt_Send bereits Daten im FIFO!!     Stop mit <Space> ');
      Mil.Timer2_Wait(150000);
      Std_Msg;
      Exit;
     end;
  }
    Mil.Timer2_Wait(5);             {mindestens 50 us warten = 2xMiltransfer}
    Pc_Stat.W := PortW [Port_Stat]; {internen PC-Status lesen}
    if (FfoEty in Pc_Stat.B) then   {ist Fifo leer?}
      MilErr := Rd_To               {Ja!}
    else
     begin
      MilErr  := No_Err;
      Rd_Data := PORTW [Port_Data];   {nur fÅr hardwarenahe Testzwecke erlaubt}
     end;

    IF MilErr <> No_Err THEN
     Begin
       Fifo_Err_Cnt := Fifo_Err_Cnt + 1;
       rd_timeout := TRUE;
       GotoXY(48, 13);  write('    ');
       TextColor(Red);
       GotoXY(42, 14);  write(' Rcv: FiFo empty!! ');
       TextColor(Black);
       Ini_Err_Win;
       Write('ERROR: Nach Wartezeit keine Daten im FIFO!!     Stop mit <Space>');
       Mil.Timer2_Wait(150000);       {mindestens 50 us warten = 2xMiltransfer}
       Std_Msg;
     End
    ELSE
     Begin  {kein Timeout}
      rd_timeout := FALSE;
      if Rd_Data = Snd_Dta then
        begin
         TextColor (Black);
         GotoXY(48, 13);  write(hex_word(Rd_Data));
         if not Auto_Test then
          begin
           Hex_Bin_Str (Rd_Data,bit16_strg);
           GotoXY(42, 14);  write(bit16_strg);
          end
         else
          begin
            GotoXY(42, 14);  write('                   ');
          end;
        end
      else
        begin
         TextColor(Red);
         GotoXY(48, 13);  write(hex_word(Rd_Data));
         if not Auto_Test then
          begin
           Hex_Bin_Str (Rd_Data,bit16_strg);
           GotoXY(42, 14);  write(bit16_strg);
          end
         else
          begin
            GotoXY(48, 13);  write('    ');
            GotoXY(42, 14);  write('                   ');
          end;
         Error_Cnt := Error_Cnt +1;
         GotoXY(18, 12);  write(Error_Cnt:10);
        end;
       end;
    Displ;
    TextColor(Black);
   End; {get_data}

   Begin
    Wr_Data     := 0;
    transf_cnt  := 0;
    error_cnt   := 0;
    Fifo_Err_Cnt:= 0;
    timout_wr   := 0;
    Single_Step := True;
    Auto_Test   := False;

    Ini_Text_Win;
    Fct.B.Adr := Ifc_Test_Nr;

    Ini_Text_Win;
    GotoXY(10,02); write('----- Sende Event und lese verzîgert direkt aus RCV-FIFO zurÅck -----');
    GotoXY(10,03); write('              Vergleiche Sende-Event und FIFO-Daten ');
    TextColor (Yellow);
    GotoXY(15,04); Write ('Achtung: Device-Stecker mit Event-Stecker verbinden!!!! ');
    TextColor (Black);
    TextColor(Brown);
    Fct.B.Fct  := Fct_Wr_Event;
    GotoXY(22,06); Write  ('Wr-Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
    GotoXY(5, 10); write('Wr-Data-Cnt:                Write-Data[H]:                ');
    GotoXY(22,11); write('^  ^');
    GotoXY(5, 12); write('Dta-Err-Cnt: ');
    GotoXY(33,13);                             write('Rd-Fifo [Hex]:');
    GotoXY(5, 13); write('Ffo-Err-Cnt: ');
    GotoXY(42,15); write('MSB             LSB');

    GotoXY(39,18); write('Belegung Funktions- u. Sondertasten: ');
    GotoXY(5, 18); write('Autom. Incr-Test: ');
    TextColor(Black);
    GotoXY(23,18); if Auto_Test then Write ('EIN') else Write ('AUS');

    Set_TastWr_Win;
    TextColor(Yellow);
    GotoXY(01, 01); Write('F1: Event [Hex]     F11: EIN Incr-Test   ');
    GotoXY(01, 02); Write('F5: Event = 0       F12: AUS Incr-Test   ');
    GotoXY(01, 03); Write('F9: Clr Err-Counts  <- -> Bit schieben   ');
    Displ;

    Mil.Reset;
    Std_Msg;                            { clear fifo }
    Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       if Auto_Test then Wr_Data := Wr_Data +1;
       Wr_SW    (Wr_Data);
       Get_Data (Wr_Data);
       Single_Step := True;
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = Taste_Return then Single_Step := False;

     if not Single_Step then
      begin
       if Auto_Test then Wr_Data := Wr_Data + 1;
       Wr_SW    (Wr_Data);
       Get_Data (Wr_Data);
       Displ;
      end;

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
       Taste_F1 : begin
                   if Ask_Hex_Break (Wr_Data, Wrd) then Displ;
                   Std_Msg;
                  end;
       Taste_F2 : begin
                  end;
       Taste_F5 : begin
                   Wr_Data := 0;
                   Displ;
                  end;
       Taste_F9: begin
                   Error_Cnt := 0;
                   Fifo_Err_Cnt := 0;
                   Displ;
                  end; {Taste_F12}
       Taste_F11: begin
                    Auto_Test:= True;
                    Set_Text_Win;
                    GotoXY(23,18); if Auto_Test then Write ('EIN') else Write ('AUS');
                 end; {Taste_F10}
       Taste_F12: begin
                    Auto_Test := False;
                    Set_Text_Win;
                    GotoXY(23,18); if Auto_Test then Write ('EIN') else Write ('AUS');
                  end; {Taste_F12}

       Taste_Pfeil_Links : begin
                             if Wr_Data = $0000 then Wr_Data := $1
                             else Wr_Data := Wr_Data shl 1;
                             Displ;
                            end;  {Taste_Pfeil_Links}
       Taste_Pfeil_Rechts: begin
                            if Wr_Data = $0000 then Wr_Data := $8000
                            else Wr_Data := Wr_Data shr 1;
                            Displ;
                           end;  {Taste_Pfeil_Rechts}
      end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:
 end; {Evt_WrRd_Fifo}


{xxx}
 Procedure Evt_Wr;
  LABEL 99;
  const PZ_IFK = 01;
   VAR
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Bit16_Strg: Str19;
     Code   : Word;
     Adress : Word;
     Wr_Data: Word;
     Auto_Test   : Boolean;

  procedure  Set_TastWr_Win;
   begin
    Window(39, 21, 80, 23);
    TextBackground(Green);
    TextColor(Black);               {Setze Schriftfarbe}
   end;

   procedure Displ;
    begin
      Set_Text_Win;
      GotoXY(18,10); write(transf_cnt:10);
      GotoXY(48,10); write(hex_word(Wr_Data));
      if not Auto_Test then
       begin
        Hex_Bin_Str (Wr_Data,bit16_strg);
        GotoXY(42, 11);  write(bit16_strg);
       end
      else
       begin
         GotoXY(42, 11);  write('                   ');
       end;
      TextColor (Red);
      GotoXY(18, 12);  write(Error_Cnt:10);
      TextColor (Black);
     end; {Wr-Data}

  procedure Wr_SW (Data: Word);
   begin
     Fct.B.Adr := Ifc_Test_Nr;
     Fct.B.Fct := Fct_Wr_Event;
     Mil.Wr (Data, Fct, MilErr);
   end; {Wr-Data}

  PROCEDURE Get_Data (Snd_Dta: Word);
   var Rd_Data : Word;
       Bit16_Strg : Str19;
   Begin
    Set_Text_Win;
    Fct.B.Fct := Fct_Rd_LastEvent;
    Mil.Rd (Rd_Data, Fct, MilErr);
    IF MilErr  <> No_Err THEN
     Begin
       rd_timeout := TRUE;
       GotoXY(48, 13);  write('    ');
       TextColor(Red);
       GotoXY(42, 14);  write('   Read Timeout    ');
       TextColor(Black);
     End
    ELSE
     Begin  {kein Timeout}
      rd_timeout := FALSE;
      if Rd_Data = Snd_Dta then
        begin
         TextColor (Black);
         GotoXY(48, 13);  write(hex_word(Rd_Data));
         if not Auto_Test then
          begin
           Hex_Bin_Str (Rd_Data,bit16_strg);
           GotoXY(42, 14);  write(bit16_strg);
          end
         else
          begin
            GotoXY(42, 14);  write('                   ');
          end;
        end
      else
        begin
         TextColor(Red);
         GotoXY(48, 13);  write(hex_word(Rd_Data));
         if not Auto_Test then
          begin
           Hex_Bin_Str (Rd_Data,bit16_strg);
           GotoXY(42, 14);  write(bit16_strg);
          end
         else
          begin
            GotoXY(48, 13);  write('    ');
            GotoXY(42, 14);  write('                   ');
          end;
         Error_Cnt := Error_Cnt +1;
         GotoXY(18, 12);  write(Error_Cnt:10);
        end;
       end;
    Displ;
    TextColor(Black);
   End; {get_data}

 procedure Wr_HF_Evts;     {alle Wartezeiten zusammen: 20 ms = 50Hz}
  procedure Wr_Event (Data: Word);
   begin
     Fct.B.Adr := PZ_IFK;
     Fct.B.Fct := Fct_Wr_Event;
     Mil.Wr (Data, Fct, MilErr);
   end; {Wr-Data}

    begin
     Wr_Event (16);                     {Vorbereitung}
     Mil.Timer2_Wait(1000);  {10 ms}
     Wr_Event (1);                      {Start_HF}
     Mil.Timer2_Wait(200);   {2 ms}
     Wr_Event (6);                      {Beam_on}
     Mil.Timer2_Wait(500);   {5 ms}
     Wr_Event (8);                      {Beam_off}
     Mil.Timer2_Wait(100);   {1 ms}
     Wr_Event (12);                     {Stop_HF}
     Mil.Timer2_Wait(200);   {2 ms}
    end;


   Begin
    Wr_Data    := 0;
    transf_cnt := 0;
    error_cnt  := 0;
    timout_wr  := 0;
    Single_Step:= True;
    Auto_Test  := False;

    Mil_Ask_Ifc;
    Ini_Text_Win;
    Fct.B.Adr := Ifc_Test_Nr;

    Ini_Text_Win;
    GotoXY(15,03); write('----- Sende Event-Folge fÅr HF-ER -----');

    Fct.B.Fct  := Fct_Wr_Event;
    GotoXY(22,06); Write  ('Wr-Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');

    TextColor(Brown);
    GotoXY(5, 10); write('Wr-Data-Cnt:                Write-Data[H]:                ');
    GotoXY(22,11); write('^  ^');
    GotoXY(5, 12); write('Error-Count: ');
    GotoXY(05,13); write('                            Rd-Data [Hex]:');
    GotoXY(42,15); write('MSB             LSB');

    GotoXY(39,18); write('Belegung Funktions- u. Sondertasten: ');
    GotoXY(5, 18); write('Autom. Incr-Test: ');
    TextColor(Black);

    Set_TastWr_Win;
    TextColor(Yellow);
    GotoXY(01, 01); Write('F1: Event [Hex]     F11:                 ');
    GotoXY(01, 02); Write('F5: Event = 0       F12:                 ');
    GotoXY(01, 03); Write('F9: Clr Err-Counts  <- -> Bit schieben   ');
    Displ;

    Mil.Reset;
    Std_Msg;                            { clear fifo }
    Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Wr_HF_Evts;
       Single_Step := True;
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Wr_HF_Evts;
      end;

    if KeyEPressed then Ch := NewReadkey;
     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
       Taste_F1 : begin
                   if Ask_Hex_Break (Wr_Data, Wrd) then Displ;
                   Std_Msg;
                  end;
       Taste_F2 : begin
                  end;
       Taste_F5 : begin
                   Wr_Data := 0;
                   Displ;
                  end;
       Taste_F9: begin
                   Error_Cnt := 0;
                   Displ;
                  end; {Taste_F12}
       Taste_F11: begin
                 end; {Taste_F10}
       Taste_F12: begin
                  end; {Taste_F12}
       Taste_Pfeil_Links : begin
                             if Wr_Data = $0000 then Wr_Data := $1
                             else Wr_Data := Wr_Data shl 1;
                             Displ;
                            end;  {Taste_Pfeil_Links}
       Taste_Pfeil_Rechts: begin
                            if Wr_Data = $0000 then Wr_Data := $8000
                            else Wr_Data := Wr_Data shr 1;
                            Displ;
                           end;  {Taste_Pfeil_Rechts}
      end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
 99:
End; {Evt_Wr}



{xxx}  {Bis hierher User-Erweiterungen !!}

BEGIN   { Hauptprogramm MIL-BASE }
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
    User_Input := NewReadKey;
    Single_Step := True;

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
     'a', 'A' :  Mil_Ask_Ifc;
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
                 if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
                 Evt_Status;
                end;
     'n', 'N' : begin
		  if Check_Ifc_Adr (Ifc_Test_Nr) then Evt_Rd_Last;
                end;
     'o', 'O' : begin
                 {if Check_Ifc_Adr (Ifc_Test_Nr) THEN }Evt_Wr;
                end;
     'p', 'P' : begin
                 if Check_Ifc_Adr (Ifc_Test_Nr) THEN Evt_WrRd_Fifo;
                end;
     'q', 'Q' : begin
                 if Check_Ifc_Adr(Ifc_Test_Nr) then Evt_WrRAM;
                end;
     'r', 'R' : begin
		 if Check_Ifc_Adr(Ifc_Test_Nr) then Evt_EnDis;
                 end;
     'S', 'S' : begin
                 if Check_Ifc_Adr (Ifc_Test_Nr) THEN Evt_Wr;
                end;
          't', 'T' : begin
                     end;
          'u', 'U' : begin
                     end;
    End; {CASE}
  UNTIL user_input in ['x','X'];
  Window(1, 1, 80, 25);
  TextBackground(Black);
  ClrScr;
END. {mil_base}


    Cursor(False);
    Std_Msg;
    Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       {User Action }
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       {User Action}
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
                             if Wr_Data = $0000 then Wr_Data := $1
                             else Wr_Data := Wr_Data shl 1;
                            end;  {Taste_Pfeil_Links}
       Taste_Pfeil_Rechts: begin
                            if Wr_Data = $0000 then Wr_Data := $8000
                            else Wr_Data := Wr_Data shr 1;
                           end;  {Taste_Pfeil_Rechts}
      end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
 99:  Cursor(True);




    Ch := ' ';
   Ini_Msg_Win;
   Write('Stop/Single Step mit <SPACE>, Loop mit <CR>                       Ende mit [X]');

   repeat
    repeat
      Set_Text_win;
      Show_Stat_Reg;
      Mil.Timer2_Wait(1000);
    until KeyEPressed or (Ch = ' ');

    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR>                       Ende mit [X]');
       repeat until KeyEPressed;
      end;

    if KeyEPressed then Ch := NewReadkey;
    if Ch = #0 then
     begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : Evt_Mask_Toggle (Mask1);
        Taste_F2 : Evt_Mask_Toggle (Mask2);
        Taste_F3 : Evt_Mask_Toggle (Mask3);
        Taste_F4 : Evt_Mask_Toggle (Mask4);
        Taste_F5 : Evt_Mask_Toggle (Mask5);
        Taste_F6 : Evt_Mask_Toggle (Mask6);
        Taste_F10: begin
                    Fct.B.Fct := Fct_En_ExtEvent ;
                    Mil.WrFct (Fct, MilErr);
                    Ini_Err_Win;
                    Write ('Ext. Event ENABLE!!!');
                    Mil.Timer2_Wait(150000);
                    Ini_Msg_Win;
                    Write('Stop/Single Step mit <SPACE>, Loop mit <CR>                       Ende mit [X]');
                    Ch := ' ';
                   end; {Taste_F10}

        Taste_F11: begin
                    Fct.B.Fct := Fct_Dis_ExtEvent;
                    Mil.WrFct (Fct, MilErr);
                    Ini_Err_Win;
                    Write ('Ext. Event DISABLE!!!');
                    Mil.Timer2_Wait(150000);
                    Ini_Msg_Win;
                    Write('Stop/Single Step mit <SPACE>, Loop mit <CR>                       Ende mit [X]');
                    Ch := ' ';
                   end; {Taste_F11}
        Taste_F12: begin
                     Fct.B.Fct := Fct_EvtPiggy_Reset;
                     Mil.WrFct (Fct, MilErr);
                     Ini_Err_Win;
                     Write ('Event-Piggy: RESET!!!');
                     Mil.Timer2_Wait(150000);
                     Ini_Msg_Win;
                     Write('Stop/Single Step mit <SPACE>, Loop mit <CR>                       Ende mit [X]');
                     Ch := ' ';
                   end; {Taste_F12}
       end; {case}
     end;
   until Ch in ['x','X'];
  99:
