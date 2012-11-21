PROGRAM Mil_RTRA;
{ Autor des Basis-Programmes Mil_Base.PAS: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS
  Spezielles Prgramm fÅr Resonanten Trafo FG 429.100 Steiner/Panschow

  Die Triggerung des ADC fÅr den Resonanten Trafo hÑngt von der Stellung des
  HW-Jumpers ab:
   ohne Jumper mu· der ADC 1x gestartet werden
   mit  Jumper konvertiert er selber und kann jederzeit ausgelesen werden

  énderungs-Protokoll:
  23.04.98    Et        Erstellt
  23.02.00    Et        wegen MIL-Timeout neu compiliert

}
{$S-}
uses Crt, WinDos, Dos, Datech, Datech_0, Datech_1;    {spez. MIL-Routinen in Units Datech..}

const
 Head_Line =
      'BELAB                                MIL_RTRA   ' +
      '                    [23.02.2000]' +
      '                           Resonanter Trafo FG 429 100                         ';

 procedure menue_win;
  var answer: CHAR;
 begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;            {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}
  TextColor(Blue);

   {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}
  GotoXY(5, 14);
  Writeln('       [M]<-- Istwert u. Status Resonanter Trafo                                                            ');
{  GotoXY(5, 15);
  Writeln('       [N]<--                                                            ');
  GotoXY(5, 16);
  Writeln('       [O]<--                                                            ');
  GotoXY(5, 17);
  Writeln('       [P]<--                                                            ');
  GotoXY(5, 18);
  Writeln('       [Q]<--                                                            ');
  GotoXY(5, 19);
  Writeln('       [R]<--                                                            ');
  GotoXY(5, 20);
  Write  ('       [S]<--                                                            ');
  GotoXY(5, 21);
  Write  ('       [T]<--                                                            ');
  GotoXY(5, 22);
  Write  ('       [U]<--                                                            ');
}
  Ini_Msg_Win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
 end; {menue_win}
{
Bisherige Routinen f. alle Anwender gleich! Ab hier spezielle User-Routinen
}


 procedure Trafo_Read;
  label 99;
  const
   Fct_Gain1    = $20;
   Fct_Gain10   = $22;
   Fct_Gain100  = $24;
   Fct_Start_ADC= $30;
   Fct_Selftest = $32;
   Fct_RdStatus = $90;    {speziell fÅr Resonanten Trafo}

   Z_Base    = 6;
   Z_IW_Hex  = Z_Base + 3;
   Z_IW_Bin  = Z_IW_Hex+1;
   Z_IW_Volt = Z_IW_Hex+2;
   Z_Stat_Bin= Z_IW_Bin+2;
   Z_HW_Jump = Z_Base-3;

   S_Base    = 3;
   S_IW1_Hex = S_Base    + 23;
   S_IW2_Hex = S_IW1_Hex + 23;
   S_IW1_Bin = S_IW1_Hex - 6;
   S_IW2_Bin = S_IW2_Hex - 6;

  var
   Ifk_Adr1   : Byte;
   Ifk_Adr2   : Byte;
   RdFct_Ifk1 : Byte;
   RdFct_Ifk2 : Byte;
   User_In    : Word;
   MilErr     : TMilErr;
   Fct        : TFct;
   Bit16_Str  : Str19 ;
   Life_Mode  : TLife_XY;

  procedure Ini_Status_Win;
   begin
    Window(65, 08, 79, 23);
    TextBackground(Cyan);
    TextColor(Brown);               {Setze Schriftfarbe}
    ClrScr;
    Write ('Bit15: EPLDBit3');
    Write ('Bit14: EPLDBit2');
    Write ('Bit13: EPLDBit1');
    TextColor(Magenta);
    Write ('Bit12:'); TextColor(Brown); Write(' EPLDBit0');
    Write ('Bit11: frei    ');
    Write ('Bit10: frei    ');
    Write ('Bit09: frei    ');
    TextColor(Magenta);
    Write ('Bit08:'); TextColor(Brown); Write(' frei    ');
    Write ('Bit07: frei    ');
    Write ('Bit06: frei    ');
    Write ('Bit05: HW-Test ');
    TextColor(Magenta);
    Write ('Bit04:'); TextColor(Brown); Write(' SW-Test ');
    Write ('Bit03: GainBit1');
    Write ('Bit02: GainBit0');
    Write ('Bit01: -15V ok ');
    Write ('Bit00: +15V ok');
    Set_Text_Win;
    TextColor(Brown);
    GotoXY(65, 05); Write ('Status-Bits: ');
   end;

  procedure Ini_Tast_Win;
   begin
    Set_Text_Win; TextColor(Brown);
    GotoXY(02, 17);
    Write ('Belegung Funktions-Tasten: ');
    Window(02, 20, 50, 23);
    TextBackground(Green);
    TextColor(Yellow);               {Setze Schriftfarbe}
    GotoXY(01, 01); Write('F1: Ifk-Adr  1  F5: IFk-Adr  2 ');
    GotoXY(01, 02); Write('F2: RdFctCode1  F6: RdFctCode2 ');
    GotoXY(01, 03); Write('F3: Gain  Adr1  F7: Gain  Adr2 ');
    GotoXY(01, 04); Write('F4: Selftest 1  F8: Selftest 2 ');
   end;

  procedure Displ_AdrFct;
   begin
   Set_Text_Win;
   TextColor(Blue);
   GotoXY(S_IW1_Hex+10, Z_Base);   Write(Hex_Byte(Ifk_Adr1));
   GotoXY(S_IW2_Hex+10, Z_Base);   Write(Hex_Byte(Ifk_Adr2));
   GotoXY(S_IW1_Hex+10, Z_Base+1); Write(Hex_Byte(RdFct_Ifk1));
   GotoXY(S_IW2_Hex+10, Z_Base+1); Write(Hex_Byte(RdFct_Ifk2));
   TextColor(Black);
   end;

  procedure Read_Dual_Ifk;
   var Read_Data_Dual : Word;
       HW_Jumper1     : Boolean;
       HW_Jumper2     : Boolean;

   begin
     Set_Text_Win;
     {Status 1 lesen}
     Fct.B.Adr := Ifk_Adr1;
     Fct.B.Fct := Fct_RdStatus;
     Mil.Rd (Read_Data_Dual, Fct, MilErr);
     if MilErr = No_Err then
      begin                       {PrÅfe, ob Hardare-Jumper gesteckt}
       if BitTst (Read_Data_Dual, 5) then
        begin
          HW_Jumper1 := True; TextColor (Yellow);
          GotoXY(3,Z_HW_Jump); Write('IFK1 HW-Jumper '); TextColor(Red+128);
          Write('on'); TextColor(Yellow); Write(' -> ADC freilaufend!');
        end
       else
        begin
          HW_Jumper1 := False;
          GotoXY(3,Z_HW_Jump); Write('                                     ');
        end;

       TextColor(Black);
       Hex_Bin_Str (Read_Data_Dual, Bit16_str);
       GotoXY(S_IW1_Bin,Z_Stat_Bin);  Write(Bit16_str);
      end
     else
      begin                  {Mil-Error!}
        TextColor (Yellow);
        GotoXY(3,Z_HW_Jump); Write('IFK1 HW-Jumper '); TextColor(Red+128);
        Write('??'); TextColor(Yellow); ClrEol;
        GotoXY(S_IW1_Bin,Z_Stat_Bin);  Write('                   ');
      end;

     {Istwert 1 lesen}
     Fct.B.Adr := Ifk_Adr1;
     Fct.B.Fct := RdFct_Ifk1;
     Mil.Rd (Read_Data_Dual, Fct, MilErr);
     if MilErr = No_Err then
      begin
       GotoXY(S_IW1_Hex,Z_IW_Hex);    Writeln(hex_word(Read_Data_Dual));
       GotoXY(S_IW1_Hex-2,Z_IW_Volt); Write_Real_10V_Bipol (Read_Data_Dual);
       Hex_Bin_Str (Read_Data_Dual, Bit16_str);
       GotoXY(S_IW1_Bin,Z_IW_Bin);  Write(Bit16_str);
      end
     else
      begin
       TextBackground(Red);
       TextColor(Yellow);               {Setze Schriftfarbe}
       GotoXY(S_IW1_Hex,Z_IW_Hex); writeln('MIL?');
       TextBackground(White);
       TextColor(Black);
       GotoXY(S_IW1_Bin,Z_IW_Bin); Write('                   ');
      end;

     {Status 2 lesen}
     Fct.B.Adr := Ifk_Adr2;
     Fct.B.Fct := Fct_RdStatus;
     Mil.Rd (Read_Data_Dual, Fct, MilErr);
     if MilErr = No_Err then
      begin
       if BitTst (Read_Data_Dual, 5) then
        begin
          HW_Jumper2 := True; TextColor (Yellow);
          GotoXY(43,Z_HW_Jump); Write('IFK2 HW-Jumper '); TextColor(Red+128);
          Write('on'); TextColor(Yellow); Write(' -> ADC freilaufend!');
        end
       else
        begin
          HW_Jumper1 := False;
          GotoXY(43,Z_HW_Jump); ClrEol;
        end;

       TextColor(Black);
       Hex_Bin_Str (Read_Data_Dual, Bit16_str);
       GotoXY(S_IW2_Bin,Z_Stat_Bin);  Write(Bit16_str);
      end
     else
      begin
        TextColor (Yellow);
        GotoXY(43,Z_HW_Jump); Write('IFK2 HW-Jumper '); TextColor(Red+128);
        Write('??'); TextColor(Yellow); ClrEol;
        GotoXY(S_IW2_Bin,Z_Stat_Bin);  Write('                   ');
      end;

     {Istwert 2 lesen}
     Fct.B.Adr := Ifk_Adr2;
     Fct.B.Fct := RdFct_Ifk2;
     Mil.Rd (Read_Data_Dual, Fct, MilErr);
     if MilErr = No_Err then
      begin
       GotoXY(S_IW2_Hex,Z_IW_Hex);    Writeln(hex_word(Read_Data_Dual));
       GotoXY(S_IW2_Hex-2,Z_IW_Volt); Write_Real_10V_Bipol (Read_Data_Dual);
       Hex_Bin_Str (Read_Data_Dual, Bit16_str);
       GotoXY(S_IW2_Bin,Z_IW_Bin);  Write(Bit16_str);
      end
     else
      begin
       TextBackground(Red);
       TextColor(Yellow);               {Setze Schriftfarbe}
       GotoXY(S_IW2_Hex,Z_IW_Hex); writeln('MIL?');
       TextBackground(White);
       TextColor(Black);               {Setze Schriftfarbe}
       GotoXY(S_IW2_Bin,Z_IW_Bin); Write('                   ');
      end;
   end;

  procedure Start_ADC;         {Falls HW-Jumper nicht gesteckt, mu· einmal}
   begin                       {der ADC gestartet werden}
     Fct.B.Adr := Ifk_Adr1;
     Fct.B.Fct := Fct_Start_ADC;
     Mil.WrFct (Fct, MilErr);

     Fct.B.Adr := Ifk_Adr2;
     Fct.B.Fct := Fct_Start_ADC;
     Mil.WrFct (Fct, MilErr);
     Mil.Timer2_Wait (30);       {Warte 300us bevor gelsen werden kann}
   end;


  begin
   Life_Mode.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
   Life_Mode.PosX    := S_Base;
   Life_Mode.PosY    := Z_Base;
   Life_Mode.Time    := Life_Time_Slow;
   Life_Mode.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}

   Mil_Ask_Ifc;
   Ifk_Adr1  :=  Ifc_Test_Nr;
   Ifk_Adr2  :=  Ifc_Test_Nr;
   RdFct_Ifk1:=  $80;
   RdFct_Ifk2:=  $80;

   Ini_Text_Win;
   TextColor(Brown);
   GotoXY(04, Z_Base-4);
   Write('Lese Istwert u. Status (Fct-Code 90H) von 2 verschiedenen Interface-Karten ');

   GotoXY(S_IW1_Hex-6, Z_Base);   Write('Ifk-Adr1   [H]: ');
   GotoXY(S_IW2_Hex-6, Z_Base);   Write('Ifk-Adr2   [H]: ');
   GotoXY(S_IW1_Hex-6, Z_Base+1); Write('Rd-Fct-Code[H]: ');
   GotoXY(S_IW2_Hex-6, Z_Base+1); Write('Rd-Fct-Code[H]: ');

   GotoXY(S_Base, Z_IW_Hex);        Write('IstWert [Hex]: ');
   GotoXY(S_Base, Z_IW_Bin);        Write('   "    [Bin]: ');
   GotoXY(S_Base, Z_IW_Volt);       Write('   "   [Volt]: ');

   GotoXY(S_Base, Z_Stat_Bin);      Write('Status  [Bin]: ');
   GotoXY(S_IW1_Bin, Z_Stat_Bin+1); Write('MSB             LSB');
   GotoXY(S_IW2_Bin, Z_Stat_Bin+1); Write('MSB             LSB');

   Displ_AdrFct;
   Ini_Tast_Win;
   Ini_Status_Win;

   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;
   Start_ADC;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Start_ADC;
       Read_Dual_Ifk;
       Life_Sign_XY (Life_Mode);
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then
      begin
       Start_ADC;               {sicherheitshalber nochmals starten}
       Single_Step := False;
      end;

     if not Single_Step then
      begin
       Read_Dual_Ifk;
       Life_Sign_XY (Life_Mode);
      end;

     if Ch = #0 then                  {Sonder-Tasten Abfrage}
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    if  Ask_Hex_Break (User_In, Byt) then
                      begin
                        Ifk_Adr1 := User_In;
                        Displ_AdrFct;
                        Start_ADC;    {mindestens 1x starten}
                      end;
                    Std_Msg;
                   end;
        Taste_F2 : begin
                    if  Ask_Hex_Break (User_In, Byt) then
                      begin
                        RdFct_Ifk1 := User_In;
                        Displ_AdrFct;
                      end;
                    Std_Msg;
                   end;
        Taste_F3 : begin
                    Cursor(True);
                    Ini_Msg_Win;
                    Write ('FÅr IFK-1: auswÑhlen GAIN_1 ->['); Textcolor(Blue); Write('1'); TextColor(Yellow);
                    Write ('], Gain_10 -> [');                 Textcolor(Blue); Write('2'); TextColor(Yellow);
                    Write ('], Gain_100 -> [');                Textcolor(Blue); Write('3'); TextColor(Yellow);
                    Write ('] : ');
                    Ch := NewReadKey;
                    Fct.B.Adr := Ifk_Adr1;
                    case Ch of
                     '1' : begin
                            Fct.B.Fct := Fct_Gain1;
                            Mil.WrFct (Fct, MilErr);
                           end;
                     '2' : begin
                            Fct.B.Fct := Fct_Gain10;
                            Mil.WrFct (Fct, MilErr);
                           end;
                     '3' : begin
                            Fct.B.Fct := Fct_Gain100;
                            Mil.WrFct (Fct, MilErr);
                           end;
                    end;  {case}
                    if Ch in ['1'..'3'] then
                     begin
                       Ini_Err_Win;
                       Write ('Neue GAIN!');
                       Mil.Timer2_Wait (200000);
                     end;
                    Ch := '?';
                    Std_Msg;
                   end;
        Taste_F4 : begin
                    Fct.B.Adr := Ifk_Adr1;
                    Fct.B.Fct := Fct_Selftest;
                    Mil.WrFct (Fct, MilErr);
                    Ini_Err_Win;
                    Write ('Selbst-Test Ifk-1!');
                    Mil.Timer2_Wait (200000);
                    Std_Msg;
                   end;

        Taste_F5 : begin
                    if  Ask_Hex_Break (User_In, Byt) then
                      begin
                        Ifk_Adr2 := User_In;
                        Displ_AdrFct;
                        Start_ADC;        {mindestens 1x starten}
                      end;
                    Std_Msg;
                   end;
        Taste_F6 : begin
                    if  Ask_Hex_Break (User_In, Byt) then
                      begin
                        RdFct_Ifk2 := User_In;
                        Displ_AdrFct;
                      end;
                    Std_Msg;
                   end;
        Taste_F7 : begin
                    Ini_Msg_Win;
                    Write ('FÅr IFK-2: auswÑhlen GAIN_1 ->['); Textcolor(Blue); Write('1'); TextColor(Yellow);
                    Write ('], Gain_10 -> [');                 Textcolor(Blue); Write('2'); TextColor(Yellow);
                    Write ('], Gain_100 -> [');                Textcolor(Blue); Write('3'); TextColor(Yellow);
                    Write ('] : ');
                    Ch := NewReadKey;
                    Fct.B.Adr := Ifk_Adr2;
                    case Ch of
                     '1' : begin
                            Fct.B.Fct := Fct_Gain1;
                            Mil.WrFct (Fct, MilErr);
                           end;
                     '2' : begin
                            Fct.B.Fct := Fct_Gain10;
                            Mil.WrFct (Fct, MilErr);
                           end;
                     '3' : begin
                            Fct.B.Fct := Fct_Gain100;
                            Mil.WrFct (Fct, MilErr);
                           end;
                    end;  {case}
                    if Ch in ['1'..'3'] then
                     begin
                       Ini_Err_Win;
                       Write ('Neue GAIN!');
                       Mil.Timer2_Wait (200000);
                     end;
                    Ch := '?';
                    Std_Msg;
                   end;
        Taste_F8 : begin
                    Fct.B.Adr := Ifk_Adr2;
                    Fct.B.Fct := Fct_Selftest;
                    Mil.WrFct (Fct, MilErr);
                    Ini_Err_Win;
                    Write ('Selbst-Test Ifk-2!');
                    Mil.Timer2_Wait (200000);
                    Std_Msg;
                   end;

        Taste_F12: begin
                   end;
        Taste_Pfeil_Links : begin
                            end;
        Taste_Pfeil_Rechts: begin
                            end;
      end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
 99:  Cursor(True);
  end; {Trafo_Read}

begin                      { Hauptprogramm }
  Ifc_Test_Nr := 0;
  Mod_Test_Nr := 0;
  repeat
    Menue_Win;
    User_Input  := NewReadKey;
    Single_Step := True;
    case User_Input of
     '0'      : Mil_Detect_Ifc;
     '1'      : Mil_Detect_Ifc_Compare;
     '2'      : begin
		  Mil_Ask_Ifc;
                  Mil_Rd_HS_Ctrl (Ifc_Test_Nr);
                end;
     '3'      : begin
		  Mil_Ask_Ifc;
                  Mil_Rd_HS_Status (Ifc_Test_Nr);
                end;
     '4'      : begin
		  Mil_Ask_Ifc;
                  Mil_Stat_All (Ifc_Test_Nr);
                end;
     '5'      : begin
                  Convert_Hex_Volt;
                end;
     '6'      : begin
                  Int_Mask;
                end;
     '7'      : begin
		  Mil_Ask_Ifc;
                  Mil_HS_Stat_Cmd (Ifc_Test_Nr);
                end;
     '9'      : begin
		  Mil_Ask_Ifc ;
                  Mil_Echo (Ifc_Test_Nr);
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
		  Mil_Ask_Ifc;
                  Mil_Rd_Data;
		end;
     'f', 'F' : begin
                  Functioncode_Table;
                end;
     'g', 'G' : begin
		  Mil_Ask_Ifc;
                  if Ask_Data_Break (Mil_Data) then Mil_WrData (Mil_Data);
                end;
     'h', 'H' : begin
		  Mil_Ask_Ifc;
		  Mil_Wr_Fctcode;
                end;
     'i', 'I' : begin
		  Mil_Ask_Ifc;
                  Mil_Data := 0;
                  Mil_Wr (Mil_Data);
                end;
     'j', 'J' : begin
		  Mil_Ask_Ifc;
                  if Ask_Data_Break (Mil_Data) then Mil_Wr_Rd (Mil_Data);
                end;
     'k', 'K' : begin
		  Mil_Ask_Ifc;
		  Mil_Loop;
                end;
     'l', 'L' : begin
                  Mil_Dual_Mode;
                end;
     'y', 'Y' : begin
                  Modul_Bus;
                end;
     'z', 'Z' : begin
                  Telefon;
                end;
     {Ab hier User-Erweiterungen!!}
          'm', 'M' : begin
                       Trafo_Read;
                     end;
          'n', 'N' : begin
                     end;
          'o', 'O' : begin
                     end;
          'p', 'P' : begin
                     end;
          'q', 'Q' : begin
                     end;
          'r', 'R' : begin
                     end;
          'S', 'S' : begin
                     end;
          't', 'T' : begin
                     end;
          'u', 'U' : begin
                     end;
    end; {CASE}
  until user_input in ['x','X'];
  Window(1, 1, 80, 25);
  TextBackground(Black);
  ClrScr;
end. {mil_base}


                     {Software-Gerippe fÅr Single-Step und Loop}
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

     if Ch = #0 then                  {Sonder-Tasten Abfrage}
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                   end;
        Taste_F12: begin
                   end;
        Taste_Pfeil_Links : begin
                            end;
        Taste_Pfeil_Rechts: begin
                            end;
      end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
 99:  Cursor(True);


