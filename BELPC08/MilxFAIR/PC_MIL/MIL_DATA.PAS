PROGRAM Mil_Dta;
{ Autor des Basis-Programmes Mil_Base.PAS: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS
  Wegen Jahr 2000: File-Datum unter DOS ist ab 1.1.2000 -> 01.01.80

  Spezial Testprogramm um HD 6408-Baustein durch Altera-Makro zu ersetzen
  Daten werden ohne Fct-Code gesendet und empfangen
  énderungs-Protokoll:
  19.01.2001          Englert
}
{$S-}
uses Crt, WinDos, Dos, Datech, Datech_0, Datech_1;    {spez. MIL-Routinen in Units Datech..}

const
 Head_Line =
      'BELAB                                MIL_Data   ' +
      '                    [22.01.2001]' +
      '               Devicebus Daten schreiben/lesen ohne Funktionskode              ';

 procedure menue_win;
  var answer: CHAR;
 begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;            {Festliegender Teil des MenÅs: s. a. DATECH_0.PAS}
  TextColor(Blue);

   {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}
  GotoXY(5, 14);
  Writeln('       [M]<-- Sende Daten ohne Fct-Code, warte auf Antwort      ');
{
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
  Ini_Msg_Win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
 end; {menue_win}
{
Bisherige Routinen f. alle Anwender gleich! Ab hier spezielle User-Routinen
}
 const
  Z_Base    = 10;
  Z_Wr      = Z_Base+1;
  Z_Rv      = Z_Base+2;
  Z_Err     = Z_Base+3;
  Z_Tim     = Z_Base+4;

  S_Cnt_Txt = 10;
  S_Cnt_Dta = 20;
  S_Dta_Txt = 40;
  S_Dta_Dta = 50;


 procedure NoFct_Send_Data_Wait;
  label 99;
  var
   Wr_Cnt  : LongInt;
   Rcv_Cnt : LongInt;
   Err_Cnt : LongInt;
   Tim_Cnt : LongInt;
   Wr_Data : Word;
   Rcv_Data: Word;
   MilErr  : TMilErr;
   User_InWord : Word;
   FixDataMode : Boolean;

 procedure  Ini_Tast_Win;
  begin
   Window(02, 22, 60, 24); TextBackground(Green); TextColor(Yellow);
   Writeln ('F1: Mod-Adr    F5: Wr-Data fix/var');
   Writeln ('F2: Ifk-Adr    F6: Wr-Data [Hex]  ');
  end;

 procedure Snd_Rcv (Snd_Dta: Word);
  var Pc_Stat   : TPcStat;
      Rcv_Timeout : Boolean;
  begin
    Rcv_Timeout := False;
    Set_Text_Win; TextColor(Blue);
    {PrÅfe, ob letzter Transfer zu Ende ist}
    repeat until ((Portw[Port_Stat] and Stat_Wrt_Rdy) = Stat_Wrt_Rdy);
    {Lîsche sicherheitshalber das Fifo}
    Mil.Reset;
    Wr_Cnt:= Wr_Cnt+1;
    Mil.WrDta (Snd_Dta, MilErr);
    Mil.Timer2_Wait(10); {Warte 100 us}
    {Lese jetzt, ob irgendwas im Fifo steht}
    Pc_Stat.W := PortW [Port_Stat];           {internen PC-Status lesen}
    if not (FfoEty in Pc_Stat.B) then         {ist Fifo leer?}
      begin
        Rcv_Cnt  := Rcv_Cnt +1;
        Rcv_Data := PORTW [Port_Data];        {Nein: also lesen Daten}
        if not (Rcv_Data = Snd_Dta) then
         begin
          Err_Cnt := Err_Cnt + 1;
          GotoXY(S_Cnt_Dta,Z_Err);   Write (Err_Cnt);
          GotoXY(S_Dta_Dta,Z_Wr);    Write (Hex_Word(Wr_Data));
          GotoXY(S_Dta_Dta,Z_Rv);    Write (Hex_Word(Rcv_Data));
         end;
      end
    else
      begin
        Rcv_Timeout := True;
        Tim_Cnt := Tim_Cnt + 1;               {Fifo ist leer: keine Daten zurÅck}
        GotoXY(S_Cnt_Dta,Z_Tim);   Write (Tim_Cnt);
        GotoXY(S_Dta_Dta,Z_Wr);    Write (Hex_Word(Wr_Data));
      end;

    {Anzeige optionen}
    if Single_Step then
     begin
      TextColor(Black);
      GotoXY(S_Cnt_Dta,Z_Wr);    Write (Wr_Cnt);
      GotoXY(S_Cnt_Dta,Z_Rv);    Write (Rcv_Cnt);
      GotoXY(S_Cnt_Dta,Z_Err);   Write (Err_Cnt);
      GotoXY(S_Cnt_Dta,Z_Tim);   Write (Tim_Cnt);

      GotoXY(S_Dta_Dta,Z_Wr);    Write (Hex_Word(Wr_Data));
      GotoXY(S_Dta_Dta,Z_Rv);
      if Rcv_Timeout then Write ('    ') else  Write (Hex_Word(Rcv_Data));
     end
    else
     begin  {Loop}
      GotoXY(S_Cnt_Dta,Z_Wr);    Write (Wr_Cnt);
      if Rcv_Timeout then Write ('    ');
     end;
  end; {Snd_Rcv}

 procedure Displ_FixDataMode;
  begin
   Set_Text_Win;
   GotoXY(S_Dta_Txt-4,Z_Wr);  TextColor(Yellow);
   if FixDataMode then Write ('fix') else Write ('var');
   TextColor(Black);
  end;

 begin
   Wr_Cnt   := 0;
   Rcv_Cnt  := 0;
   Err_Cnt  := 0;
   Tim_Cnt  := 0;
   Wr_Data  := $0;
   Rcv_Data := 0;
   FixDataMode:= True;

   Ini_Text_Win; TextColor(Blue);
   GotoXY(S_Cnt_Txt,Z_Base);  Write('COUNTER');    TextColor(Brown);
   GotoXY(S_Cnt_Txt,Z_Wr);    Write('Write  : ');
   GotoXY(S_Cnt_Txt,Z_Rv);    Write('Receive: ');
   GotoXY(S_Cnt_Txt,Z_Err);   Write('Error  : ');
   GotoXY(S_Cnt_Txt,Z_Tim);   Write('Timeout: ');
   Displ_FixDataMode;
{   TextColor(Black); }
   GotoXY(S_Cnt_Dta,Z_Wr);    Write (Wr_Cnt);
   GotoXY(S_Cnt_Dta,Z_Rv);    Write (Rcv_Cnt);
   GotoXY(S_Cnt_Dta,Z_Err);   Write (Err_Cnt);
   GotoXY(S_Cnt_Dta,Z_Tim);   Write (Tim_Cnt);      TextColor(Blue);

   GotoXY(S_Dta_Txt,Z_Base);  Write('DATA [H]');    TextColor(Brown);
   GotoXY(S_Dta_Txt,Z_Wr);    Write('Write  : ');
   GotoXY(S_Dta_Txt,Z_Rv);    Write('Receive: ');
   GotoXY(S_Dta_Dta,Z_Wr);    Write ('    ');
   GotoXY(S_Dta_Dta,Z_Rv);    Write ('    ');

   Ini_Tast_Win;
   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Snd_Rcv (Wr_Data);
       if not FixDataMode then  Wr_Data := Wr_Data + 1;
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then
      begin
       Single_Step := False;
       GotoXY(S_Dta_Dta,Z_Wr);    Write ('    ');
       GotoXY(S_Dta_Dta,Z_Rv);    Write ('    ');
      end;

     if not Single_Step then
      begin
       Snd_Rcv (Wr_Data);
       if not FixDataMode then  Wr_Data := Wr_Data + 1;
      end;

     if Ch = #0 then                  {Sonder-Tasten Abfrage}
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                   end;

        Taste_F5: begin
                    if FixDataMode then FixDataMode:=False else FixDataMode:=True;
                    Displ_FixDataMode;
                    Std_Msg;
                  end;

        Taste_F6:  begin
                    if Ask_Hex_Break (User_InWord, Wrd) then
                     begin
                      Wr_Data := User_InWord;
                      Set_Text_Win;
                      GotoXY(S_Dta_Dta,Z_Wr); Write (Hex_Word(Wr_Data));
                     end;
                    Std_Msg;
                    Ch := '?';
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
 end; {NoFct_Send_Data_Wait}


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
		{  Mil_Ask_Ifc;                    }
                {  Mil_Rd_HS_Status (Ifc_Test_Nr); }
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
     '8'      : begin
		  Mil_Ask_Ifc ;
                  Mil_Echo (Ifc_Test_Nr);
                end;
     '9'      : begin
		  Mil_Ask_Ifc ;
                  Mil_IfkMode;
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
                      NoFct_Send_Data_Wait;
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


