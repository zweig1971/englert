PROGRAM Mil_KMRA;
{ Autor des Basis-Programmes Mil_Base.PAS: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS
  FÅr Eickhoff 19.3.97                 Tel. 2395
      Hardware FG 463.020 R. Hartmann  Tel. 2363
      Kamera : Herr Spiller            Tel. 2405

  énderungen:
  24.03.97    Et Steuerung fÅr TKR-Kamera im Cave-M
  26.03.97    "  Keine Init, damit aktueller Kamera-Status erhalten bleibt

  Frage: Pulsgenerator mit Delay Null geht nicht!!!
}
{$S-}
uses Crt, WinDos, Dos, Datech, Datech_1;    {spez. MIL-Routinen in Units Datech..}

const
 Head_Line =
      'BELAB                                MIL_KMRA   ' +
      '                    [27.03.1997]' +
      '                          Steuerung der TKR-Kamera CAVE-M                      ';

 procedure menue_win;
  var answer: CHAR;
 begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;              {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}

  {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}
  TextColor(Blue);
  GotoXY(5, 14);
  Writeln('       [M]<-- Kamera                                                           ');
{0
  GotoXY(5, 15);
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
  TextColor(Black);
  Ini_Msg_Win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
 end; {menue_win}

var
 Single_Step: Boolean;              {Globale Variable}
{
Bisherige Routinen f. alle Anwender gleich! Ab hier spezielle User-Routinen
}


function Ask_Sw_Break (var SW : TSw): Boolean;    {wahlweise Volt, Hex, Amp}
 var  Real_Zahl : Real;     {Einlesen von User-Daten mit Abort Mîglichkeit!!}
      User_Hex  : Word;     {+/- 10V, 15 Bit mit Vorzeichen }
 begin
  Ask_Sw_Break := False;
  case SW.Mode of
   V : begin                          {+/- 10V, 15 Bit mit Vorzeichen}
          Ini_Msg_Win;
          Write('Spannung als Floating-Point Zahl oder <Q + CR> eingeb. [+/- 00.000]: ');
          {$I-}                    {Fehleingabe zulassen: Compiler-Check ausschalten}
          Readln (Real_Zahl);
          {$I+}
          if (IoResult <> 0) then              {Fehler selber abfangen!}
           begin
            Exit;
           end
          else
           begin
             if abs (Real_Zahl) > Sw.Max then    {Absolutwert, weil +/- 10 Volt}
              begin
               Ini_Err_Win;
               Write('ERROR: +/- Sollwert grî·er als ',Sw.Max,' !   Weiter mit <CR>');
               ReadKey;
               Exit;
              end;
           end;

         if Real_Zahl > 9.999694825 then Real_Zahl := 9.999694825;
         Real_Zahl:= (Real_Zahl/305.1757813) * 1000000;
         Sw.User:= Round(Real_Zahl);         {Real-Zahl in Integer umwandeln}
         Ask_Sw_Break := True;
       end;

   A : begin      {Die Ampere-eingabe mu· auf den max. Wert normiert werden!!}
          Ini_Msg_Win;
          Write('Strom als Floating-Point Zahl oder <Q + CR> eingeb. [00000.0]: ');
          {$I-}                    {Fehleingabe zulassen: Compiler-Check ausschalten}
          Readln (Real_Zahl);
          {$I+}
          if (IoResult <> 0) then              {Fehler selber abfangen!}
           begin
            Exit;
           end
          else
           begin
             if abs (Real_Zahl) > Sw.Max then
              begin
               Ini_Err_Win;
               Write('ERROR: +/- Sollwert: ', Real_zahl:7:1,' grî·er als SW[Amax]: ',Sw.Max:7:1,' !   Weiter mit <CR>');
               ReadKey;
               Exit;
              end;
           end;

         if Real_Zahl > 0 then
           Real_Zahl := (Real_Zahl/Sw.Max) * 32767;
         if Real_Zahl < 0 then
           Real_Zahl := (Real_Zahl/Sw.Max) * 32768;
         Sw.User   := Round(Real_Zahl);         {Real-Zahl in Integer umwandeln}
         Ask_Sw_Break := True;
       end;

   H : begin
         if not (Ask_Hex_Break (User_Hex, Wrd)) then Exit
         else
          begin
           Sw.User      := Word(User_Hex);
           Ask_Sw_Break := True;
          end;
       end;
   end; {case}
 end; { Ask_Sw_Break }


 const
  Fct_Start_Count = $14;
  Fct_Stop_Count  = $15;
  Fct_Rd_Status2  = $92;

  Z_FTast_Win  = 21;
  FTast_WinSize= 2;
  Z_Basis      = 1;
  Z_Blende     = 8;
  S_Null       = 10;
  S_Blende     = S_Null   + 16;
  S_Trig       = S_Blende + 25;
  Z_Ifk        = Z_Basis  + 4;
  S_Ifk        = 43;
  S_Jumper     = 16;

  Counter_Resolution = 4.0;   {ms}

  procedure Ini_FTast_Win;
   begin
    Window(39, Z_FTast_Win, 80, Z_FTast_Win+FTast_WinSize);
    TextBackground(Green);
    TextColor(Black);
    ClrScr;
   end;

  procedure Set_FTast_Win;
   begin
    Window(39, Z_FTast_Win, 80, Z_FTast_Win+FTast_WinSize);
    TextBackground(Green);
    TextColor(Black);
   end;

  procedure Exit_Msg;
   begin
    Ini_Msg_Win;
    Write('Ende mit [X]');
   end;

type
 TTime = record case Byte of
                1: ( w : PACKED RECORD
                           lw   : WORD;
                           hw   : WORD;
                         END;
                   );
                2: ( li: LONGINT; );
         end;

 procedure Kamera;
  label 99;
  var
   Adress    : Word;
   MilErr    : TMilErr;
   Fct       : TFct;
   Sollw     : TSw;
   User_Time : LongInt;
   Blend_Time: LongInt;
   User_Real : Real;
   Blend_Sw  : Integer;
   Trig_Time : TTime;
   Trig_Delay: TTime;
   Puls_Stat : Word;
   Life_Mode  : TLife_XY;

  procedure Wr_Blende (Tim_Blend: LongInt; Sollw_Blend: Integer); {Blendenmotor fahren}
   begin
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Fct_Wr_Sw1;
    Mil.Wr (Sollw_Blend, Fct, MilErr);    {Sw_Blend = Vor-/RÅck Blendenbewegung}
    Mil.Timer2_Wait(Tim_Blend);       {Fahrdauer des Blendenmotors}
    Mil.Wr (0, Fct, MilErr);           {Spannung auf Null}
   end; {WR_Blende}

  procedure Sw_Displ;
   var Puls_Status : Word;
   begin
    Set_Text_Win;
    GotoXY(S_Blende  ,Z_Blende+1);    Write_Real_10V_Bipol (Blend_Sw);
    GotoXY(S_Blende+1,Z_Blende+2);    Write ((Blend_Time Div 100):5);
    GotoXY(S_Trig+20 ,Z_Blende+1);    Write ((Trig_Delay.li * 4):6);
    GotoXY(S_Trig+20 ,Z_Blende+2);    Write ((Trig_Time.li  * 4):6);

    Fct.B.Adr  := Ifc_Test_Nr;         {Status Trigger Pulsgen intern/extern}
    Fct.B.Fct  := Fct_Rd_Status2;
    Mil.Rd (Puls_Status, Fct, MilErr); {Lese Istwert}
    GotoXY(S_Jumper+43,Z_Basis+3);  TextColor(White);
    if BitTst (Puls_Status,0) then
       Write('extern')
    else
      begin
       TextColor(White + 128);
       Write('intern');
      end;
   end; {Sw_Displ}

  procedure Reset_All;
   begin
    Blend_Time   := 0;
    Blend_Sw     := 0;
    Trig_Time.li := 0;
    Trig_Delay.li:= 0;
    Sw_Displ;
    Fct.B.Adr  := Ifc_Test_Nr;
    Fct.B.Fct := Fct_Reset;     {Wirkt auf IFK + Pulsgen}
    Mil.WrFct (Fct, MilErr);

    Fct.B.Fct  := Fct_Wr_Sw1;   {Clear ADC}
    Mil.Wr (0, Fct, MilErr);    {Sw_Blend = Vor-/RÅck Blendenbewegung}
   end;

  begin
   Life_Mode.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
   Life_Mode.PosX    := S_Null-2;        {02;}
   Life_Mode.PosY    := Z_Blende;        {}
   Life_Mode.Time    := Life_Time_Slow;
   Life_Mode.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}

{  Reset_All; }      {Kein Init: Status erhalten!!}
   Mil_Ask_Ifc;
   Fct.B.Adr := Ifc_Test_Nr;

   Ini_Text_Win;
   TextColor(Brown);
   GotoXY(20,Z_Basis+2);           Write('Blenden- u. Trigger-Steuerung der TKR-Kamera');
   GotoXY(S_Jumper,Z_Basis+3);     Write('Jumper Triggerung Pulsgenerator steht auf: ');

   TextColor(Brown);
   GotoXY(S_Ifk-9,Z_Ifk);  Write ('IFK-Nr: '); TextColor(Black);
   GotoXY(S_Ifk,Z_Ifk);     Write (Hex_Byte(Ifc_Test_Nr)); TextColor(Brown);
   Write (' [H]');

   TextColor(Blue);
   GotoXY(S_Null,Z_Blende);    Write ('BLENDE Sollwert');
   GotoXY(S_Trig,Z_Blende);    Write ('TRIGGER Sollwert');
   TextColor(Brown);
   GotoXY(S_Null,Z_Blende+1);  Write ('Spannung  [V ]: ');
   GotoXY(S_Null,Z_Blende+2);  Write ('Zeit      [ms]: ');
   GotoXY(S_Trig,Z_Blende+1);  Write ('Delay      [ms]: ');
   GotoXY(S_Trig,Z_Blende+2);  Write ('Integr.Zeit[ms]: ');

   Set_FTast_Win;
   TextColor(Blue);
   GotoXY(01, 01); Write('[Blende]    [Trigger]      [IFK-Funktion]');
   TextColor(Yellow);
   GotoXY(01, 02); Write('F1: Volt    F5: Delay +    F9 : Reset All');
   GotoXY(01, 03); Write('F2: Send        Belichtung               ');

   Set_Text_Win;
   TextColor(Brown);
   GotoXY(39,Z_FTast_Win-3 ); write('Belegung Funktions- u. Sondertasten: ');
   Sw_Displ;

   Cursor(False);
   Exit_Msg;
   Ch := '?';

   repeat
     if Ch = ' ' then
      begin
       Exit_Msg;
       Single_Step := True;

       {User Action }
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = Taste_Return then Single_Step := False;
     if not Single_Step then
      begin

       {User Action}
      end;

     if Ch = #0 then                  {Sonder-Tasten Abfrage}
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    Sollw.Mode:= V;
                    Sollw.Max := 10.0;
                    if Ask_Sw_Break (Sollw) then
                     begin
                      Blend_Sw  := Sollw.User;
                      Sw_Displ;
                      Ini_Msg_Win;
                      Write ('Zeit fÅr Blende eingeben [ms] oder <Q + CR>: ');
                      {$I-}               {Fehleingabe zulassen: Compiler-Check ausschalten}
                      Readln (User_Time);
                      {$I+}
                      if (IoResult <> 0) then
                       begin                   {Fehler}
                        Exit;
                       end
                      else
                       begin
                         Blend_Time := User_Time * 100;
                         Sw_Displ;
                       end;
                     end;
                    Exit_Msg;
                   end;
        Taste_F2 : begin
                    if (Blend_Time = 0) and (Blend_Sw = 0) then
                     begin
                       Ini_Err_Win;
                       Write ('ERROR: Blendenwerte undefiniert!!');
                       Mil.Timer2_Wait(200000);
                       Ini_Msg_Win;
                       Exit_Msg;
                     end
                    else
                     begin
                       Wr_Blende (Blend_Time, Blend_Sw);
                       Life_Sign_XY (Life_Mode);
                       Ini_Msg_Win;
                       Exit_Msg;
                     end;
                   end;
       Taste_F5 : begin
                    Ini_Msg_Win;
                    Write ('Zeit fÅr Trigger-Delay ('); TextColor(Red);
                    Write('Auflîsung 4ms'); TextColor(Yellow); Write(') eingeben [ms] oder <Q + CR>: ');
                    {$I-}               {Fehleingabe zulassen: Compiler-Check ausschalten}
                    Readln (User_Real);
                    {$I+}
                    if (IoResult <> 0) then
                     begin                   {Fehler}
                      Exit;
                     end
                    else
                     begin
                       {Erst Trigger-Delay erfragen}
                       User_Real := abs(User_Real);
                       if User_Real > (65535 * Counter_Resolution) then User_Real := 65535 * Counter_Resolution;
                            {PrÅfe, ob Divison >0...<1 ergibt, denn Null Delay ist erlaubt!!}
                       if (User_Real/Counter_Resolution < 1) and (User_Real/Counter_Resolution > 0) then User_Real := 4;

                       Trig_Delay.li := round (User_Real/4);
                       Sw_Displ;
                       Fct.B.Adr := Ifc_Test_Nr;
                       Fct.B.Fct := Fct_Start_Count;
                       Mil.Wr (Trig_Delay.w.lw, Fct, MilErr);   {Start Counter laden}

                       {Jetzt die Trig-Time erfragen}
                       Ini_Msg_Win;
                       Write ('Zeit Belichtung ('); TextColor(Red);
                       Write('Auflîsung 4ms'); TextColor(Yellow); Write(') eingeben [ms] oder <Q + CR>: ');
                       {$I-}               {Fehleingabe zulassen: Compiler-Check ausschalten}
                       Readln (User_Real);
                       {$I+}
                       if (IoResult <> 0) then
                        begin                   {Fehler}
                         Trig_Delay.li := 0;
                         Trig_Time.li  := 0;
                         Sw_Displ;
                         Exit;
                        end
                       else
                        begin
                          User_Real := abs (User_Real);
                          if User_Real > (65535 * Counter_Resolution) then
                             User_Real := (65535 * Counter_Resolution) - (Trig_Delay.li * Counter_Resolution);
                          {Minimale Pulsbreite ist 1 Tick = 4ms}
                          if User_Real/Counter_Resolution < 1 then User_Real := 4;
                          Trig_Time.li := round (User_Real/4);
                          Trig_Time.li := Trig_Time.li + Trig_Delay.li;

                          Fct.B.Fct := Fct_Stop_Count;
                          Mil.Wr (Trig_Time.w.lw, Fct, MilErr);   {Start Counter laden}
                          {Nur tatsÑchliche PulslÑnge anzeigen}
                          Trig_Time.li := Trig_Time.li - Trig_Delay.li;
                          Sw_Displ;
                        end;
                     end; {if Trigger Delay}
                    Ini_Msg_Win;
                    Exit_Msg;
                   end;

        Taste_F9: begin
                   Reset_All;
                   Ini_Err_Win;
                   Write ('RESET: IFK, DAC, PULS-GENERATOR!! ');
                   Mil.Timer2_Wait(200000);
                   Ini_Msg_Win;
                   Exit_Msg;
                  end; {Taste_F9}
{
        Taste_F10: begin
                    if Ask_Hex_Break (Adress, Byt) then
                      begin
                       Ifc_Test_Nr := Adress;
                       Fct.B.Adr   := Ifc_Test_Nr;
                       Set_Text_Win;
                       GotoXY(S_Ifk,Z_Ifk);
                       Write (Hex_Byte(Ifc_Test_Nr));
                      end;
                     Ini_Msg_Win;
                     Exit_Msg;
                    end;
}
      end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
  end; {Kamera}


begin                      { Hauptprogramm MIL-BASE }
  Ifc_Test_Nr := 0;

  Dual[1].Adr := 0;        {Init Dual-Mode Array}
  Dual[1].Fct := 0;
  Dual[1].Dta_ok := False;
  Dual[1].Dta := 0;
  Dual[2].Adr := 0;
  Dual[2].Fct := 0;
  Dual[2].Dta_ok := False;
  Dual[2].Dta := 0;

  repeat
    Menue_Win;
    User_Input  := ReadKey;
    Single_Step := True;
    case User_Input of
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
                  if Check_Ifc_Adr(Ifc_Test_Nr) then
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
     'z', 'Z' : begin
                  Telefon;
                end;
     {Ab hier User-Erweiterungen!!}
          'm', 'M' : begin
                      Kamera;
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

     if Ch = Taste_Return then Single_Step := False;
{     if Ch = #13 then Single_Step := False; }
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


          Taste_F5 : begin
                    Ini_Msg_Win;
                    Write ('Zeit fÅr Trigger-Delay ('); TextColor(Red);
                    Write('Auflîsung 4ms'); TextColor(Yellow); Write(') eingeben [ms] oder <Q + CR>: ');
                    {$I-}               {Fehleingabe zulassen: Compiler-Check ausschalten}
                    Readln (User_Real);
                    {$I+}
                    if (IoResult <> 0) then
                     begin                   {Fehler}
                      Exit;
                     end
                    else
                     begin
                       User_Real := abs(User_Real);
                       if User_Real > (65535 * Counter_Resolution) then User_Real := 65535 * Counter_Resolution;
                       if User_Real/Counter_Resolution < 0 then User_Real := 4;
                       Trig_Delay.li := round (User_Real/4);
                       Sw_Displ;
                       Fct.B.Adr := Ifc_Test_Nr;
                       Fct.B.Fct := Fct_Start_Count;
                       Mil.Wr (Trig_Delay.w.lw, Fct, MilErr);   {Start Counter laden}
                     end;
                    Ini_Msg_Win;
                    Exit_Msg;
                   end;
       Taste_F6 : begin
                    Ini_Msg_Win;
                    Write ('Zeit Belichtung ('); TextColor(Red);
                    Write('Auflîsung 4ms'); TextColor(Yellow); Write(') eingeben [ms] oder <Q + CR>: ');
                    {$I-}               {Fehleingabe zulassen: Compiler-Check ausschalten}
                    Readln (User_Time);
                    {$I+}
                    if (IoResult <> 0) then
                     begin                   {Fehler}
                     end
                    else
                     begin
                       User_Real := abs (User_Real);
                       if User_Real > (65535 * Counter_Resolution) then User_Real := 65535 * Counter_Resolution;
                       if User_Real/Counter_Resolution < 0 then User_Real := 4;
                       Trig_Time.li := round (User_Real/4);
                       Trig_Time.li := Trig_Delay.li + Trig_Time.li;
                       Sw_Displ;
                       Fct.B.Adr := Ifc_Test_Nr;
                       Fct.B.Fct := Fct_Stop_Count;
                       Mil.Wr (Trig_Time.w.lw, Fct, MilErr);   {Start Counter laden}
                     end;
                    Ini_Msg_Win;
                    Exit_Msg;
                   end;
