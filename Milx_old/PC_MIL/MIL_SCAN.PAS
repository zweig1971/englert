PROGRAM Mil_Scan;
{ Autor des Basis-Programmes Mil_Base.Pas: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS

  Autor der Erweiterungen   :
  énderungen:
  11.03.97   Zeiteingabe fÅr Scannertest auf LongInt umgestellt
}
{$S-}

uses Crt, WinDos, Datech, Datech_0, Datech_1;

CONST
 head_line =
      'Datentechnik                         MIL_SCAN   ' +
      '                    [03.12.1998]' +
      '                                  Magnetservice                                ';

procedure menue_win;
VAR answer: CHAR;
begin
  Ini_Headl_Win;
  Write(head_line);
  Menue_Base;              {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}

  {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}
  GotoXY(5, 15);
  Writeln('       [M]<-- Scanner Test (Sprunghafte énderung zwischen 2 Sollwerten) ');
{
  GotoXY(5, 15);
  Writeln('       [N]<-- Sende Sollwert (nach Tabelle, Incr oder Shift)             ');
  GotoXY(5, 16);
  Writeln('       [O]<-- Test fÅr gepulste NetzgerÑte (SOLL, IST, ZEIT: fix     )   ');
  GotoXY(5, 17);
  Writeln('       [P]<-- Test fÅr gepulste NetzgerÑte (SOLL, IST, ZEIT: variabel)   ');
  GotoXY(5, 18);
  Writeln('       [Q]<-- Test fÅr gerampte NetzgerÑte (0...+10V oder 0...-10V)      ');
  GotoXY(5, 19);
  Write  ('       [R]<-- Hallsonden Eichung (var. Tabelle,'); TextColor(Red);
                         write(' QUICK 1'); TextColor(Black); Write(' iterativ Rampe)    ');
  GotoXY(5, 20);
  Write  ('       [S]<-- Hallsonden Eichung (var. Tabelle,'); TextColor(Red);
                         write(' QUICK 2'); TextColor(Black);  Write(' iterativ bzw. Rampe)');
  GotoXY(5, 21);
  Write  ('       [T]<--                ');
  GotoXY(5, 22);
  Write  ('       [U]<--                 ');
}
  ini_msg_win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
 End; {menue_win}

 const
  Step_Time_Default = 50;           {500 us fÅr Quick2}
  Top_Time_Default  = 50000;       {1 sec       "   }

                     {Ab hier sollten User-Routinen beginnen!!}
  procedure Ini_IstwMag_Win;
   begin
    Window(43, 13, 80, 17);
    TextBackground(Cyan);
    TextColor(Black);               {Setze Schriftfarbe}
    ClrScr;
   end;

  procedure Set_IstwMag_Win;
   begin
    Window(43, 13, 79, 17);
    TextBackground(Cyan);
    TextColor(Black);               {Setze Schriftfarbe}
   end;

  procedure Ini_TastMag_Win;
   begin
    Window(43, 18, 80, 20);
    TextBackground(Green);
    TextColor(Black);               {Setze Schriftfarbe}
    ClrScr;
   end;

  procedure Set_TastMag_Win;
   begin
    Window(43, 18, 80, 20);
    TextBackground(Green);
    TextColor(Black);               {Setze Schriftfarbe}
   end;

  procedure Ini_IstwDisp_Win;
   begin
    Window(02, 15 , 79, 18);
    TextBackground(Cyan);
    TextColor(Black);               {Setze Schriftfarbe}
    ClrScr;
   end;

 procedure Set_IstwDisp_Win; far; {Routine als Prozedur-Parameter einsetzbar}
  begin
   Window(02, 15, 79, 18);
   TextBackground(Cyan);
   TextColor(Black);               {Setze Schriftfarbe}
  end;

 PROCEDURE Displ_FTasten_Liste;
  Begin
     {Info-Anzeige der Bit-Belegung Funktionstasten}
      ini_info_win;
      writeln('F1 : Reset     [Fct-Code  01H]');
      writeln('F2 : Ein       [Fct-Code  02H]');
      writeln('F3 : Aus       [Fct-Code  03H]');
      writeln('F4 : +         [Fct-Code  04H]');
      writeln('F5 : -         [Fct-Code  05H]');
      writeln('F6 : Last 0..5 [Fct-Cd 14-19H]');
      writeln('F7 : Sollw1= 0 [Fct-Code  06H]');
      writeln('F8 : Sollw1    [Volt/Amp/Hex ]');
      writeln('F9 : FGen: einfache Rampe     ');
      writeln('F10: IFK-Adresse Ñndern       ');
      writeln('F11: Abfrage-Rate Quick/Slow  ');
      write  ('F12: Init FehlerÅberwachung   ');
   End; {displ_HS_Status}

 function Get_LastNr (var Num: Byte): Boolean;
  var Answer: Char;
  begin
    Get_LastNr := FALSE;
    Ini_Msg_Win;
    Write ('Bitte Last-Nummer als Dezimalzahl [0..5]  oder  [Q]uit:');
    repeat until KeyEPressed;
    Answer := NewReadKey;
    case Answer of
     '0' : begin Num := 0; Get_LastNr := TRUE; end;
     '1' : begin Num := 1; Get_LastNr := TRUE; end;
     '2' : begin Num := 2; Get_LastNr := TRUE; end;
     '3' : begin Num := 3; Get_LastNr := TRUE; end;
     '4' : begin Num := 4; Get_LastNr := TRUE; end;
     '5' : begin Num := 5; Get_LastNr := TRUE; end;
    end; {case}
  end; {Get_LastNr}

procedure Mil_NG_Puls_Vari;     {Variable Eingabe fÅr Sollwert, Istwert, Zeit}
{ Drei Magnetsollwerte und Istwerte sollen in definierten AbstÑnden gesetzt/
  gelesen werden. Abweichungen Soll-Ist soll ermittelt und max. 10 Vergleiche
  angezeigt werden.
}
 label 99;
 const Hist_Max = 9;
       Top_Max  = 3;
       Z_Start  = 1;

 type
  TSollIst = record
              Soll     : Word;       {Sollwert}
              Ist      : Word;       {Istwert}
              S_I_Diff : Word;
              Rd_Error : Boolean;    {Zeigt Fehler beim Istwertlesen an}
              Zeit_Top : Word;       {Dauer des Flattop}
              Zeit_Wait: Word;       {Warte, bis Istwert gelesen werden kann}
              Hist_Diff: array [0..Hist_Max] of Word; {Historische Differenzen}
             end;
 var
  FlaTop : array [1..Top_Max] of TSollIst;
  Wr_Fct_Code, Rd_Fct_Code : Byte;
  MilErr : TMilErr;
  Fct    : TFct;
  RetAdr : Byte;
  OnlineErr: TOnlineErr;
  Status_Data: Word;
  Hist_Index : Byte;         {gilt fÅr Array mit den historischen Differenzen}
  Z : Byte;


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

  procedure Mag_Headline;
   begin
    Ini_Headl_Win;
    GotoXY(01,01);
    write('                            Test fÅr gepulste Magnete                           ');
    GotoXY(01,02);
    write('Schreibe in definierten AbstÑnden 3 Sollwerte u. lese Istwerte verzîgert zurÅck');
    ini_text_win;
    Ini_Msg_Win;
    Write ('Weiter mit <Space>    oder    E[X]it ');
    Set_Text_Win;
   end;

  procedure Ini_Flatop_Ary;
   var y,z : Byte;
   begin
    for y := 1 to Top_Max do
     begin
      Flatop[y].Soll     := 0;
      Flatop[y].Ist      := 0;
      Flatop[y].S_I_Diff := 0;
      Flatop[y].Rd_Error := False;
      Flatop[y].Zeit_Top := 0;
      Flatop[y].Zeit_Wait:= 0;
      for z:=0 to Hist_Max do Flatop[y].Hist_Diff[z] := 0;
     end; {for y}
   end; {Ini_Flatop_Ary}

  function Ask_Flatop (Num: Byte): Boolean;   {Erfrage Parameter von User}
   label 01;
   const Z_Start = 15;
   var Soll      : Word;
       Top, Wait : Byte;
   begin
     Ask_Flatop := True;
     Soll := Flatop[Num].Soll;                 {Rette alte Werte fÅr Abbruch}
     Top  := Flatop[Num].Zeit_Top;
     Wait := Flatop[Num].Zeit_Wait;

    repeat
      Ini_Text_Win;
      GotoXY(20,04); write(' Bitte Flat-Top Parameter eingeben!!');
      GotoXY(5,Z_Start);
      write ('Flat-Top Nummer         :      ', Num); ClrEol;

      GotoXY(5, 22);
      write ('Welchen Sollwert f. Flat-Top ', Num,' ?'); Clreol;
      Flatop[Num].Soll := Rd_Real_Sw (10.0);
      Set_Text_Win;
      GotoXY(5,Z_Start+1);
      write ('Flat-Top-Sollwert [Volt]:');
      Write_Real_10V_Bipol (Flatop[Num].Soll); ClrEol;

      Flatop[Num].Zeit_Top := 0;    {Default}
      repeat
        Set_Text_Win;
        GotoXY(1, 22); Clreol;
        Ini_Msg_Win;
        write ('Welche Dauer (max. 65 sec) fÅr FLAT-TOP ', Num, ' [ms] ?: ');
        {$I-}               {Fehleingabe zulassen: Compiler-Check ausschalten}
        readln (Flatop[Num].Zeit_Top);
        {$I+}
        if (IoResult <> 0) then
          Flatop[Num].Zeit_Top := 0    {Fehler}
        else
         begin
          if Flatop[Num].Zeit_Top = 0 then
           begin
             Ini_Err_Win;
             write ('Dauer fÅr FLAT-TOP mu· <> 0 sein!  Weiter mit beliebiger Taste');
             repeat until KeyEPressed;
           end;
         end;
      until  Flatop[Num].Zeit_Top > 0;

      Set_Text_Win;
      GotoXY(5,Z_Start+2);
      write ('Flat-Top-Dauer      [ms]:  ');
      write (Flatop[Num].Zeit_Top:5); ClrEol;


      Flatop[Num].Zeit_Wait := Flatop[Num].Zeit_Top + 1; {Als Fehler setzen}
      repeat
        Set_Text_Win;
        GotoXY(1, 22); Clreol;
        Ini_Msg_Win;
        write ('Wartezeit (max. 65 sec): Beginn Flat-Top bis Lesen Istwert ', Num, ' [ms] ? ');

        {$I-}               {Fehleingabe zulassen: Compiler-Check ausschalten}
        readln  (Flatop[Num].Zeit_Wait);
        {$I+}
        if (IoResult <> 0) then  {Fehler}
         begin
           Ini_Err_Win;
           write ('Eingabe-Fehler !!       Weiter mit beliebiger Taste ');
           repeat until KeyEPressed;
         end
        else
         begin
           Set_Text_Win;
           GotoXY(5,Z_Start+3);
           write ('Istwert lesen nach  [ms]:  ');
           write (Flatop[Num].Zeit_Wait:5); ClrEol;

           if Flatop[Num].Zeit_Wait > Flatop[Num].Zeit_Top then
            begin
              Ini_Err_Win;
              write ('Wartezeit grî·er als Flat-Top-Zeit!! Weiter mit beliebiger Taste ');
              repeat until KeyEPressed;
            end;
         end;
      until  Flatop[Num].Zeit_Wait <= Flatop[Num].Zeit_Top;

      Ini_Msg_Win;
      write ('Bisherige Eingaben akzeptieren [J/N] oder Abbruch [X]: ');
      repeat until KeyEPressed;
      Ch := NewReadKey;
    until (Ch in ['x','X']) or (Ch in ['j','J']);

    if Ch in ['x','X'] then
     begin                                          {Abbruch!}
      Ask_Flatop           := False;
      Flatop[Num].Soll     := Soll;             {Alte Werte restaurieren}
      Flatop[Num].Zeit_Top := Top;
      Flatop[Num].Zeit_Wait:= Wait;
     end;
   end;

  procedure Ini_Flat_Win;
    var Index : Byte;
    begin
     Ini_Text_Win;
     TextColor(Brown);               {Setze Schriftfarbe}
     GotoXY(01, Z_Start);
     Write ('Test_Count:            Status:      IFC-Adr[H]:     Wr-Fct[H]:     Rd-Fct[H]:   ');
     GotoXY(01, Z_Start+1);
     Write ('Aktives Flat-Top:      R/H   :      DataSet-Nr:                                  ');
     TextColor(Brown);               {Setze Schriftfarbe}

     GotoXY(01, Z_Start+3);
     Write ('Flatop Dauer  +Read    -- Sollwert --      Istwert         Diff. Soll-Ist       ');
     GotoXY(01, Z_Start+4);
     Write ('  Nr   [ms]    [ms]   [Volt]    [Hex]      [Volt]              [Volt]           ');
     TextColor(Black);               {Setze Schriftfarbe}

     GotoXY(01, Z_Start+5);
     Write ('  00                                                                            ');
     GotoXY(01, Z_Start+6);
     Write ('  01                                                                            ');
     GotoXY(01, Z_Start+7);
     Write ('  02                                                                            ');
     GotoXY(01, Z_Start+8);
     Write ('  03                                                                            ');

     TextColor(Brown);               {Setze Schriftfarbe}
     GotoXY(01, Z_Start+9);
     Write ('v-- Anzeige der letzten 10  Soll-Ist Differenz-Werte (N-1 = vorletzter Wert) --v');
     GotoXY(20, Z_Start+10); Write ('Diff- Flatop 1');
     GotoXY(41, Z_Start+10); Write ('Diff- Flatop 2');
     GotoXY(61, Z_Start+10); Write ('Diff- Flatop 3');

     for Index := 0 to Hist_Max do
      begin
        GotoXY(02, Z_Start+11+Index);
        Write ('N -',Index:2);
      end;
     TextColor(Black);               {Setze Schriftfarbe}
   end;

  procedure Disp_Flat_Active (Num : Byte);  {Aktives Flattop auf Bildschirm}
   var x : Byte;
   begin
     GotoXY(20, Z_Start+1); Write (Num);    {aktives Flattop}
     for x := 0 to 3 do                     {lîsche Zeiger}
      begin
        GotoXY(01, Z_Start+5+x);
        Write ('  ');
      end;

     case Num of
       0 : begin   GotoXY(01, Z_Start+5);  Write ('->');  end;
       1 : begin   GotoXY(01, Z_Start+6);  Write ('->');  end;
       2 : begin   GotoXY(01, Z_Start+7);  Write ('->');  end;
       3 : begin   GotoXY(01, Z_Start+8);  Write ('->');  end;
     end;
   end;

  function Flat_Top (Num: Byte): Boolean;
  { Die Dauer des Flattops und die Leseverzîgerung des Istwertes sollen Åber
    den Timer2 bestimmmt werden, da Timer1 fÅr MIL-Operationen reserviert ist.
    Zuerst wird Timer2 mit der Istwert-Verzîgerung geladen und dann mit
    der restlichen Zeit als Differenz: Flattop-Time minus Leseverzîgerung
  }
   var Top_Minus_Wait_Time : LongInt;
       Read_Time_10us      : LongInt;
       Soll_Ist_Diff       : Word;
   begin
    Flat_Top := False;         {Default}
    Disp_Flat_Active (Num);
    Top_Minus_Wait_Time:= Flatop[Num].Zeit_Top - Flatop[Num].Zeit_Wait; {ms!!}
    Top_Minus_Wait_Time:= Top_Minus_Wait_Time * 100;      {10 us * 100 = 1 ms}
    Read_Time_10us     := Flatop[Num].Zeit_Wait * 100;    {10 us * 100 = 1 ms}
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Wr_Fct_Code;
    Mil.Wr (Flatop[Num].Soll , Fct, MilErr);  {Setze Flattop Sollwert}

    Mil.Timer2_Wait(Read_Time_10us);          {Read-Time abwarten; Basis 10 us}
    Mil.Timer2_Set(Top_Minus_Wait_Time);      {Lade Ende des Flattops}
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Rd_Fct_Code;
    Mil.Rd ( Flatop[Num].Ist, Fct, MilErr);   {Lese Istwert}
    GotoXY(43, Z_Start+5+Num);                {Display-Position Istwert}
    if MilErr <> No_Err then
     begin
      Write ('  Rd_Err  ');
      Flatop[Num].Rd_Error := True;
      GotoXY(63, Z_Start+5+Num); Write('          ');
     end
    else
     begin
      Write_Real_10V_Bipol (Flatop[Num].Ist);
      Flatop[Num].Rd_Error := False;
      Flatop[Num].S_I_Diff := Flatop[Num].Soll - Flatop[Num].Ist;
      Flatop[Num].Hist_Diff[Hist_Index] := Flatop[Num].S_I_Diff;
      GotoXY(63, Z_Start+5+Num); Write_Real_10V_Bipol (Flatop[Num].S_I_Diff);
     end;

    repeat until Mil.Timeout2;   {Warte bis zum Ende des Flattops}
   end; {Flat_Top}

  procedure Flat_Zero;
   begin
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Wr_Fct_Code;
    Mil.Wr (0 , Fct, MilErr);  {Setze Flattop Sollwert}
    Disp_Flat_Active (0);
   end;


{Anzeige der alten Differenzwerte: falls nur eine Messung gemacht wurde, auch
nur eine Zeile anzeigen. Erst nach Hist_Max Messungen, werden alle historischen
Werte angezeigt}
 procedure Disp_Hist_Ary (Test_Count: Word);
   var Index       : Byte;
       Start_Index : Byte;
       Flat_Nr : Byte;
       Rd_Index  : Integer;
       DispLn_Num: Word;

   begin
     Set_Text_Win;
     Flat_Nr   := 1;
     if Test_Count > Hist_Max then DispLn_Num := Hist_Max
     else DispLn_Num := Test_Count - 1;          {Wenig Daten, wenig anzeigen}

     for Index := 0 to DispLn_Num do
     begin
       Rd_Index := (Hist_Index - Index) - 1;  {Hist_index zeigt auf next write}
       if Rd_Index < 0 then Rd_Index := Hist_Max + 1 + Rd_Index;
       GotoXY(22, Z_Start+11+Index);
       if Flatop[Flat_Nr].Rd_Error then
        Write ('Rd_Err')
       else
         Write_Real_10V_Bipol (Flatop[Flat_Nr].Hist_Diff[Rd_Index]);
      end;

     Flat_Nr   := 2;
     if Test_Count > Hist_Max then DispLn_Num := Hist_Max
     else DispLn_Num := Test_Count - 1;          {Wenig Daten, wenig anzeigen}

     for Index := 0 to DispLn_Num do
     begin
       Rd_Index := (Hist_Index - Index) - 1;  {Hist_index zeigt auf next write}
       if Rd_Index < 0 then Rd_Index := Hist_Max + 1 + Rd_Index;
       GotoXY(43, Z_Start+11+Index);
       if Flatop[Flat_Nr].Rd_Error then
        Write ('Rd_Err')
       else
         Write_Real_10V_Bipol (Flatop[Flat_Nr].Hist_Diff[Rd_Index]);
      end;

     Flat_Nr   := 3;
     if Test_Count > Hist_Max then DispLn_Num := Hist_Max
     else DispLn_Num := Test_Count - 1;          {Wenig Daten, wenig anzeigen}

     for Index := 0 to DispLn_Num do
     begin
       Rd_Index := (Hist_Index - Index) - 1;  {Hist_index zeigt auf next write}
       if Rd_Index < 0 then Rd_Index := Hist_Max + 1 + Rd_Index;
       GotoXY(63, Z_Start+11+Index);
       if Flatop[Flat_Nr].Rd_Error then
        Write ('Rd_Err')
       else
         Write_Real_10V_Bipol (Flatop[Flat_Nr].Hist_Diff[Rd_Index]);
      end;
   end; {Disp_Hist_Ary}

 procedure Clear_Hist_Disp;
  var Index : Byte;
   begin
     Set_Text_Win;
     for Index := 0 to Hist_Max  do
      begin
        GotoXY(01, Z_Start+11+Index); ClrEol;
      end;

     TextColor(Brown);               {Setze Schriftfarbe}
     for Index := 0 to Hist_Max  do
      begin
        GotoXY(02, Z_Start+11+Index);
        Write ('N -',Index:2);
      end;
     TextColor(Black);               {Setze Schriftfarbe}
   end;

 procedure Disp_R_H;
  begin
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Rd_Stat0;               {Status C0}
   Mil.Rd (Status_Data, Fct, MilErr);
   GotoXY(32, Z_Start);
   if BitTst (Status_Data, 8) then          {Bit 8 gibt Ein/Aus an}
     Write ('Ein')
   else
     Write ('Aus');

   Fct.B.Fct := Fct_Rd_Stat2;               {Status C2}
   Mil.Rd (Status_Data, Fct, MilErr);
   GotoXY(32, Z_Start+1);
   if BitTst (Status_Data, 8) then          {Bit 8 gibt R/H an}
     Write ('R')
   else
     Write ('H');
  end;

 begin                        {Mil_NG_Puls}
   Mil_Ask_Ifc;
   Fct.B.Adr := Ifc_Test_Nr;
   Hist_Index := 0;
   Transf_Cnt := 0;
   Ini_Flatop_Ary;
   Mag_Headline;
   Ini_Text_Win;

   GotoXY(5, 22);
   write ('Welchen Write-Function-Code fÅr Sollwert ??');
   Wr_Fct_Code := ask_hex_byte;
   Ini_Text_Win;

   GotoXY(5, 22);
   write ('Welchen Read-Function-Code fÅr Istwert ??');
   Rd_Fct_Code := ask_hex_byte;

   if not Ask_Flatop (1) then goto 99;
   if not Ask_Flatop (2) then goto 99;
   if not Ask_Flatop (3) then goto 99;

   Ini_Flat_Win;
   GotoXY(49, Z_Start+0); Write (Hex_Byte(Ifc_Test_Nr));
   GotoXY(64, Z_Start+0); Write (Hex_Byte(Wr_Fct_Code));
   GotoXY(79, Z_Start+0); Write (Hex_Byte(Rd_Fct_Code));

   GotoXY(22, Z_Start+5); Write_Real_10V_Bipol (0);
   GotoXY(33, Z_Start+5); Write (Hex_Word (0));

   GotoXY(07, Z_Start+6); Write (Flatop[1].Zeit_Top:5);
   GotoXY(15, Z_Start+6); Write (Flatop[1].Zeit_Wait:5);
   GotoXY(22, Z_Start+6); Write_Real_10V_Bipol (Flatop[1].Soll);
   GotoXY(33, Z_Start+6); Write (Hex_Word (Flatop[1].Soll));

   GotoXY(07, Z_Start+7); Write (Flatop[2].Zeit_Top:5);
   GotoXY(15, Z_Start+7); Write (Flatop[2].Zeit_Wait:5);
   GotoXY(22, Z_Start+7); Write_Real_10V_Bipol (Flatop[2].Soll);
   GotoXY(33, Z_Start+7); Write (Hex_Word (Flatop[2].Soll));

   GotoXY(07, Z_Start+8); Write (Flatop[3].Zeit_Top:5);
   GotoXY(15, Z_Start+8); Write (Flatop[3].Zeit_Wait:5);
   GotoXY(22, Z_Start+8); Write_Real_10V_Bipol (Flatop[3].Soll);
   GotoXY(33, Z_Start+8); Write (Hex_Word (Flatop[3].Soll));
   GotoXY(13, Z_Start);   Write (Transf_Cnt:8);
   Disp_Flat_Active (0);
   Disp_R_H;

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
      repeat until KeyEPressed;
      Ch := NewReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      Flat_Top (1);
      Flat_Top (2);
      Flat_Top (3);
      Hist_Index := Hist_Index + 1;                 {gilt fÅr alle drei Flattops}
      if Hist_Index = Hist_Max + 1 then Hist_Index := 0;
      GotoXY(13, Z_Start);
      Write (Transf_Cnt:8);
    until KeyEPressed or (Ch = ' ');

    if KeyEPressed then Ch := NewReadKey;
    if Ch = ' ' then
      begin
       Flat_Zero;                    {Setze Magnet auf Sollwert 0}
       Disp_Flat_Active (0);
       Disp_Hist_Ary (Transf_Cnt);                {Zeige letzte 10 Differenzwerte}
       Disp_R_H;
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR>, neue Mil-<A>dresse   Ende mit [X]');
       repeat until KeyEPressed;
      end;
    Ch := NewReadKey;

    if Ch in ['a','A'] then
     begin
       New_Ifc_Adr;
       Set_Text_Win;
       GotoXY(49, Z_Start+0); Write (Hex_Byte(Ifc_Test_Nr));
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR>, neue Mil-<A>dresse   Ende mit [X]');
       repeat until KeyEPressed;
       Ch := NewReadKey;
     end;

    Clear_Hist_Disp;
   until Ch in ['x','X'];
99: Flat_Zero;                    {Setze Magnet auf Sollwert 0}
 end; {Mil_NG_Puls_Vari}


procedure Mil_NG_Puls_Fix;     {Feste Werte fÅr Sollwert, Istwert, Zeit}
{ Drei Magnetsollwerte und Istwerte sollen in definierten AbstÑnden gesetzt/
  gelesen werden. Abweichungen Soll-Ist soll ermittelt und max. 10 Vergleiche
  angezeigt werden.
}
 label 99;
 const Hist_Max = 9;
       Top_Max  = 3;    {Anzahl der Daten pro Flattop: Soll, Top_time, Wait}
       Z_Start  = 1;
       Write_Fct_Code = $06;
       Read_Fct_Code  = $81;
       Flat_Ary_Max = 7;           {Anzahl der vordefinierten Test-DatensÑtze}
 type
  TSollIst = record
              Soll     : Word;       {Sollwert}
              Ist      : Word;       {Istwert}
              S_I_Diff : Word;
              Rd_Error : Boolean;    {Zeigt Fehler beim Istwertlesen an}
              Zeit_Top : Word;       {Dauer des Flattop}
              Zeit_Wait: Word;       {Warte, bis Istwert gelesen werden kann}
              Hist_Diff: array [0..Hist_Max] of Word; {Historische Differenzen}
             end;
  TFlatParm = record
               Soll     : Word;
               Top      : Word;
               Wait     : Word;
              end;
  TParmAry  = array [1..3] of TFlatParm;
  TFlatAry  = array [1..Flat_Ary_Max] of TParmAry;

 const
  FlatFix: TFlatAry =
  (
  ((Soll: $2000; Top: 1000; Wait:   50),
   (Soll: $0000; Top: 1000; Wait:   50),
   (Soll: $4000; Top: 1000; Wait:   50)),

  ((Soll: $4000; Top: 1000; Wait:   50),
   (Soll: $0000; Top: 1000; Wait:   50),
   (Soll: $7FFF; Top: 1000; Wait:   50)),

  ((Soll: $4000; Top: 1000; Wait:   50),
   (Soll: $0000; Top: 1000; Wait:   50),
   (Soll: $7FFF; Top: 1000; Wait:   50)),

  ((Soll: $7FFF; Top: 1000; Wait:   50),     {10 V 1,0 sec}
   (Soll: $0000; Top: 0500; Wait:   50),
   (Soll: $0000; Top: 0500; Wait:   50)),

  ((Soll: $7FFF; Top: 0500; Wait:   50),     {10 V 0,5 sec}
   (Soll: $0000; Top: 0250; Wait:   50),
   (Soll: $0000; Top: 0250; Wait:   50)),

  ((Soll: $4000; Top: 1000; Wait:   50),     { 5 V 1,0 sec}
   (Soll: $0000; Top: 0500; Wait:   50),
   (Soll: $0000; Top: 0500; Wait:   50)),

  ((Soll: $4000; Top: 0500; Wait:   50),     { 5 V 0,5 sec}
   (Soll: $0000; Top: 0250; Wait:   50),
   (Soll: $0000; Top: 0250; Wait:   50))
 );

 var
  FlaTop : array [1..Top_Max] of TSollIst;
  Wr_Fct_Code, Rd_Fct_Code : Byte;
  MilErr : TMilErr;
  Fct    : TFct;
  RetAdr : Byte;
  OnlineErr: TOnlineErr;
  Status_Data: Word;
  Hist_Index : Byte;         {gilt fÅr Array mit den historischen Differenzen}
  Z : Byte;
  Data_Set_Nr : Byte;


  procedure Mag_Headline;
   begin
    Ini_Headl_Win;
    GotoXY(01,01);
    write('                            Test fÅr gepulste Magnete                           ');
    GotoXY(01,02);
    write('Schreibe in definierten AbstÑnden 3 Sollwerte u. lese Istwerte verzîgert zurÅck');
    Ini_Text_Win;
    Ini_Msg_Win;
    Write ('Weiter mit <Space>    oder    E[X]it ');
    Set_Text_Win;
   end;

  procedure Ini_Flatop_Ary;
   var y,z : Byte;
   begin
    for y := 1 to Top_Max do
     begin
      Flatop[y].Soll     := 0;
      Flatop[y].Ist      := 0;
      Flatop[y].S_I_Diff := 0;
      Flatop[y].Rd_Error := False;
      Flatop[y].Zeit_Top := 0;
      Flatop[y].Zeit_Wait:= 0;
      for z:=0 to Hist_Max do Flatop[y].Hist_Diff[z] := 0;
     end; {for y}
   end; {Ini_Flatop_Ary}


  function Ask_Flat_Nr: Boolean;         {Erfrage Tabelle der fixen Parameter}
   label 01;
   const Z_Start = 10;
   var z,m : Byte;

   procedure Set_Flat_Parm (Num: Byte);
    var n : Byte;
    begin
     for n := 1 to 3 do
      begin
        Flatop[n].Soll      := FlatFix[Num,n].Soll;
        Flatop[n].Zeit_Top  := FlatFix[Num,n].Top;
        Flatop[n].Zeit_Wait := FlatFix[Num,n].Wait;
      end;
    end; {Set_Flat_Parm}

   begin
      Ask_Flat_Nr := False;
      Ini_Text_Win;
      GotoXY(06,04); write('Verschiedene, vordefinierte Flat-Top Parameter DatensÑtze auswÑhlbar!');

      GotoXY(01, Z_Start);
      TextColor(Brown);
      writeln (' Daten   v-- Flat-Top 1 --v     v-- Flat-Top 2 --v     v-- Flat-Top 3 --v');
      writeln (' Satz     Soll    Top  Read      Soll    Top  Read      Soll    Top  Read');
      writeln ('  Nr.    [Volt]   [ms] [ms]     [Volt]   [ms] [ms]     [Volt]   [ms] [ms]');
      TextColor(Black);

      for z := 1 to  Flat_Ary_Max do
       begin
         begin
           m := 1;
           GotoXY(04, Z_Start+3+z); Write (z);
           GotoXY(08, Z_Start+3+z); Write_Real_10V_Bipol (FlatFix[z,m].Soll);
           GotoXY(19, Z_Start+3+z); Write (FlatFix[z,m].Top:4);
           GotoXY(24, Z_Start+3+z); Write (FlatFix[z,m].Wait:4);

           m := 2;
           GotoXY(31, Z_Start+3+z); Write_Real_10V_Bipol (FlatFix[z,m].Soll);
           GotoXY(42, Z_Start+3+z); Write (FlatFix[z,m].Top:4);
           GotoXY(47, Z_Start+3+z); Write (FlatFix[z,m].Wait:4);

           m := 3;
           GotoXY(54, Z_Start+3+z); Write_Real_10V_Bipol (FlatFix[z,m].Soll);
           GotoXY(65, Z_Start+3+z); Write (FlatFix[z,m].Top:4);
           GotoXY(70, Z_Start+3+z); Write (FlatFix[z,m].Wait:4);
         end;
       end;

     Ini_Msg_Win;
     write ('Bitte Datensatz-Nr eingeben [1..',Flat_Ary_Max,'] oder Abbruch mit [Q]: ');
     repeat until KeyEPressed;
     Ch := NewReadKey;
     case Ch of
      '1' : begin Set_Flat_Parm (1); Data_Set_Nr:= 1; Ask_Flat_Nr := True; end;
      '2' : begin Set_Flat_Parm (2); Data_Set_Nr:= 2; Ask_Flat_Nr := True; end;
      '3' : begin Set_Flat_Parm (3); Data_Set_Nr:= 3; Ask_Flat_Nr := True; end;
      '4' : begin Set_Flat_Parm (4); Data_Set_Nr:= 4; Ask_Flat_Nr := True; end;
      '5' : begin Set_Flat_Parm (5); Data_Set_Nr:= 5; Ask_Flat_Nr := True; end;
      '6' : begin Set_Flat_Parm (6); Data_Set_Nr:= 6; Ask_Flat_Nr := True; end;
      '7' : begin Set_Flat_Parm (7); Data_Set_Nr:= 7; Ask_Flat_Nr := True; end;
      'q','Q' : goto 01;
     else
      begin
        Ini_Err_Win;
        write ('Keine gÅltige Datenssatz-Nr. !!    Weiter mit beliebiger Taste');
        repeat until KeyEPressed;
      end;
     end; {case}
  01:
  end; {Ask_Flat_Nr}

  procedure Ini_Flat_Win;
    var Index : Byte;
    begin
     Ini_Text_Win;
     TextColor(Brown);               {Setze Schriftfarbe}
     GotoXY(01, Z_Start);
     Write ('Test_Count:            Status:      IFC-Adr[H]:     Wr-Fct[H]:     Rd-Fct[H]:   ');
     GotoXY(01, Z_Start+1);
     Write ('Aktives Flat-Top:      R/H   :      DataSet-Nr:                                  ');
     TextColor(Brown);               {Setze Schriftfarbe}

     GotoXY(01, Z_Start+3);
     Write ('Flatop Dauer  +Read    -- Sollwert --      Istwert         Diff. Soll-Ist       ');
     GotoXY(01, Z_Start+4);
     Write ('  Nr   [ms]    [ms]   [Volt]    [Hex]      [Volt]              [Volt]           ');
     TextColor(Black);               {Setze Schriftfarbe}

     GotoXY(01, Z_Start+5);
     Write ('  00                                                                            ');
     GotoXY(01, Z_Start+6);
     Write ('  01                                                                            ');
     GotoXY(01, Z_Start+7);
     Write ('  02                                                                            ');
     GotoXY(01, Z_Start+8);
     Write ('  03                                                                            ');

     TextColor(Brown);               {Setze Schriftfarbe}
     GotoXY(01, Z_Start+9);
     Write ('v-- Anzeige der letzten 10  Soll-Ist Differenz-Werte (N-1 = vorletzter Wert) --v');
     GotoXY(20, Z_Start+10); Write ('Diff- Flatop 1');
     GotoXY(41, Z_Start+10); Write ('Diff- Flatop 2');
     GotoXY(61, Z_Start+10); Write ('Diff- Flatop 3');

     for Index := 0 to Hist_Max do
      begin
        GotoXY(02, Z_Start+11+Index);
        Write ('N -',Index:2);
      end;

     TextColor(Red);
     GotoXY(08, Z_Start+11+Hist_Max+1);
     Write ('[Im LOOP-MODE keine Anzeige der Soll-Ist Differenzen N-0 ... N-9 !]');
     TextColor(Black);               {Setze Schriftfarbe}
   end;

  procedure Disp_Flat_Active (Num : Byte);  {Aktives Flattop auf Bildschirm}
   var x : Byte;
   begin
     GotoXY(20, Z_Start+1); Write (Num);    {aktives Flattop}
     for x := 0 to 3 do                     {lîsche Zeiger}
      begin
        GotoXY(01, Z_Start+5+x);
        Write ('  ');
      end;

     case Num of
       0 : begin   GotoXY(01, Z_Start+5);  Write ('->');  end;
       1 : begin   GotoXY(01, Z_Start+6);  Write ('->');  end;
       2 : begin   GotoXY(01, Z_Start+7);  Write ('->');  end;
       3 : begin   GotoXY(01, Z_Start+8);  Write ('->');  end;
     end;
   end;

  function Flat_Top (Num: Byte): Boolean;
  { Die Dauer des Flattops und die Leseverzîgerung des Istwertes sollen Åber
    den Timer2 bestimmmt werden, da Timer1 fÅr MIL-Operationen reserviert ist.
    Zuerst wird Timer2 mit der Istwert-Verzîgerung geladen und dann mit
    der restlichen Zeit als Differenz: Flattop-Time minus Leseverzîgerung
  }
   var Top_Minus_Wait_Time : LongInt;
       Read_Time_10us      : LongInt;
       Soll_Ist_Diff       : Word;
   begin
    Flat_Top := False;         {Default}
    Disp_Flat_Active (Num);
    Top_Minus_Wait_Time:= Flatop[Num].Zeit_Top - Flatop[Num].Zeit_Wait; {ms!!}
    Top_Minus_Wait_Time:= Top_Minus_Wait_Time * 100;      {10 us * 100 = 1 ms}
    Read_Time_10us     := Flatop[Num].Zeit_Wait * 100;    {10 us * 100 = 1 ms}
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Wr_Fct_Code;
    Mil.Wr (Flatop[Num].Soll , Fct, MilErr);  {Setze Flattop Sollwert}

    Mil.Timer2_Wait(Read_Time_10us);          {Read-Time abwarten; Basis 10 us}
    Mil.Timer2_Set(Top_Minus_Wait_Time);      {Lade Ende des Flattops}
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Rd_Fct_Code;
    Mil.Rd ( Flatop[Num].Ist, Fct, MilErr);   {Lese Istwert}
    GotoXY(43, Z_Start+5+Num);                {Display-Position Istwert}
    if MilErr <> No_Err then
     begin
      Write ('  Rd_Err  ');
      Flatop[Num].Rd_Error := True;
      GotoXY(63, Z_Start+5+Num); Write('          ');
     end
    else
     begin
      Write_Real_10V_Bipol (Flatop[Num].Ist);
      Flatop[Num].Rd_Error := False;
      Flatop[Num].S_I_Diff := Flatop[Num].Soll - Flatop[Num].Ist;
      Flatop[Num].Hist_Diff[Hist_Index] := Flatop[Num].S_I_Diff;
      GotoXY(63, Z_Start+5+Num); Write_Real_10V_Bipol (Flatop[Num].S_I_Diff);
     end;

    repeat until Mil.Timeout2;   {Warte bis zum Ende des Flattops}
   end; {Flat_Top}

  procedure Flat_Zero;
   begin
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Wr_Fct_Code;
    Mil.Wr (0 , Fct, MilErr);  {Setze Flattop Sollwert}
    Disp_Flat_Active (0);
   end;

{Anzeige der alten Differenzwerte: falls nur eine Messung gemacht wurde, auch
nur eine Zeile anzeigen. Erst nach Hist_Max Messungen, werden alle historischen
Werte angezeigt}
 procedure Disp_Hist_Ary (Test_Count: Word);
   var Index       : Byte;
       Start_Index : Byte;
       Flat_Nr : Byte;
       Rd_Index  : Integer;
       DispLn_Num: Word;

   begin
     Set_Text_Win;
     Flat_Nr   := 1;
     if Test_Count > Hist_Max then DispLn_Num := Hist_Max
     else DispLn_Num := Test_Count - 1;          {Wenig Daten, wenig anzeigen}

     for Index := 0 to DispLn_Num do
     begin
       Rd_Index := (Hist_Index - Index) - 1;  {Hist_index zeigt auf next write}
       if Rd_Index < 0 then Rd_Index := Hist_Max + 1 + Rd_Index;
       GotoXY(22, Z_Start+11+Index);
       if Flatop[Flat_Nr].Rd_Error then
        Write ('Rd_Err')
       else
         Write_Real_10V_Bipol (Flatop[Flat_Nr].Hist_Diff[Rd_Index]);
      end;

     Flat_Nr   := 2;
     if Test_Count > Hist_Max then DispLn_Num := Hist_Max
     else DispLn_Num := Test_Count - 1;          {Wenig Daten, wenig anzeigen}

     for Index := 0 to DispLn_Num do
     begin
       Rd_Index := (Hist_Index - Index) - 1;  {Hist_index zeigt auf next write}
       if Rd_Index < 0 then Rd_Index := Hist_Max + 1 + Rd_Index;
       GotoXY(43, Z_Start+11+Index);
       if Flatop[Flat_Nr].Rd_Error then
        Write ('Rd_Err')
       else
         Write_Real_10V_Bipol (Flatop[Flat_Nr].Hist_Diff[Rd_Index]);
      end;

     Flat_Nr   := 3;
     if Test_Count > Hist_Max then DispLn_Num := Hist_Max
     else DispLn_Num := Test_Count - 1;          {Wenig Daten, wenig anzeigen}

     for Index := 0 to DispLn_Num do
     begin
       Rd_Index := (Hist_Index - Index) - 1;  {Hist_index zeigt auf next write}
       if Rd_Index < 0 then Rd_Index := Hist_Max + 1 + Rd_Index;
       GotoXY(63, Z_Start+11+Index);
       if Flatop[Flat_Nr].Rd_Error then
        Write ('Rd_Err')
       else
         Write_Real_10V_Bipol (Flatop[Flat_Nr].Hist_Diff[Rd_Index]);
      end;
   end; {Disp_Hist_Ary}

 procedure Clear_Hist_Disp;
  var Index : Byte;
   begin
     Set_Text_Win;
     for Index := 0 to Hist_Max  do
      begin
        GotoXY(01, Z_Start+11+Index); ClrEol;
      end;

     TextColor(Brown);               {Setze Schriftfarbe}
     for Index := 0 to Hist_Max  do
      begin
        GotoXY(02, Z_Start+11+Index);
        Write ('N -',Index:2);
      end;
     TextColor(Black);               {Setze Schriftfarbe}
   end;

 procedure Disp_R_H;
  begin
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Rd_Stat0;               {Status C0}
   Mil.Rd (Status_Data, Fct, MilErr);
   GotoXY(32, Z_Start);
   if BitTst (Status_Data, 8) then          {Bit 8 gibt Ein/Aus an}
     Write ('Ein')
   else
     Write ('Aus');

   Fct.B.Fct := Fct_Rd_Stat2;               {Status C2}
   Mil.Rd (Status_Data, Fct, MilErr);
   GotoXY(32, Z_Start+1);
   if BitTst (Status_Data, 8) then          {Bit 8 gibt R/H an}
     Write ('R')
   else
     Write ('H');
  end;

 begin                        {Mil_NG_Puls}
   Mil_Ask_Ifc;
   Fct.B.Adr := Ifc_Test_Nr;
   Hist_Index := 0;
   Transf_Cnt := 0;
   Ini_Flatop_Ary;
   Mag_Headline;
   Ini_Text_Win;

   Wr_Fct_Code := Write_Fct_Code;   {Fct-Code sind jetzt ebenso fest}
   Rd_Fct_Code := Read_Fct_Code;

   if not Ask_Flat_Nr then goto 99;
   Ini_Flat_Win;
   GotoXY(49, Z_Start+0); Write (Hex_Byte(Ifc_Test_Nr));
   GotoXY(64, Z_Start+0); Write (Hex_Byte(Wr_Fct_Code));
   GotoXY(79, Z_Start+0); Write (Hex_Byte(Rd_Fct_Code));

   GotoXY(22, Z_Start+5); Write_Real_10V_Bipol (0);
   GotoXY(33, Z_Start+5); Write (Hex_Word (0));

   GotoXY(07, Z_Start+6); Write (Flatop[1].Zeit_Top:5);
   GotoXY(15, Z_Start+6); Write (Flatop[1].Zeit_Wait:5);
   GotoXY(22, Z_Start+6); Write_Real_10V_Bipol (Flatop[1].Soll);
   GotoXY(33, Z_Start+6); Write (Hex_Word (Flatop[1].Soll));

   GotoXY(07, Z_Start+7); Write (Flatop[2].Zeit_Top:5);
   GotoXY(15, Z_Start+7); Write (Flatop[2].Zeit_Wait:5);
   GotoXY(22, Z_Start+7); Write_Real_10V_Bipol (Flatop[2].Soll);
   GotoXY(33, Z_Start+7); Write (Hex_Word (Flatop[2].Soll));

   GotoXY(07, Z_Start+8); Write (Flatop[3].Zeit_Top:5);
   GotoXY(15, Z_Start+8); Write (Flatop[3].Zeit_Wait:5);
   GotoXY(22, Z_Start+8); Write_Real_10V_Bipol (Flatop[3].Soll);
   GotoXY(33, Z_Start+8); Write (Hex_Word (Flatop[3].Soll));
   GotoXY(13, Z_Start);   Write (Transf_Cnt:8);
   GotoXY(50, Z_Start+1); Write (Data_Set_Nr);             {aktiver Datensatz}
   Disp_Flat_Active (0);
   Disp_R_H;

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR>, neue Adr mit <F10>   Ende mit [X]');
      repeat until KeyEPressed;
      Ch := NewReadKey;
      if  Ch in ['x','X'] then Goto 99;
     end;

   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      Flat_Top (1);
      Flat_Top (2);
      Flat_Top (3);
      Hist_Index := Hist_Index + 1;                 {gilt fÅr alle drei Flattops}
      if Hist_Index = Hist_Max + 1 then Hist_Index := 0;

      GotoXY(13, Z_Start);
      Write (Transf_Cnt:8);
    until KeyEPressed or (Ch = ' ');

    if Ch = ' ' then
      begin
       Flat_Zero;                    {Setze Magnet auf Sollwert 0}
       Disp_Flat_Active (0);
       Disp_Hist_Ary (Transf_Cnt);                {Zeige letzte 10 Differenzwerte}
       Disp_R_H;
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR>, neue Adr mit <F10>   Ende mit [X]');
       repeat until KeyEPressed;
      end;
    Ch := NewReadKey;

   if Ch = #0 then
    begin
      Ch := NewReadKey;
      case ord (Ch) of
       Taste_F10: begin
                    New_Ifc_Adr;
                    Set_Text_Win;
                    GotoXY(49, Z_Start+0); Write (Hex_Byte(Ifc_Test_Nr));
                    Ini_Msg_Win;
                    Write('Stop/Single Step mit <SPACE>, Loop mit <CR>, neue Adr mit <F10>   Ende mit [X]');
                    repeat until KeyEPressed;
                    Ch := ' ';
                  end; {Taste_F10}
      end;  {Case}
    end;
    Clear_Hist_Disp;
   until Ch in ['x','X'];
99: Flat_Zero;                    {Setze Magnet auf Sollwert 0}
    Disp_Flat_Active (0);
 end; {Mil_NG_Puls_Fix}

const             {Konstanten dÅr Mag-Tab-Darstellung}
 Z_SW    = 22;
 S_Loop  = 7;
 S_RdErr = 9;
 S_SWH   = 23;   {Sollwert Hex}
 S_SWV   = 34;   {Sollwert Volt}
 S_SWA   = 52;   {Sollwert Ampere}
 S_SWX   = 73;   {Sollwert MaxAmpere}
 Sw_Amax: Real   = 0.0;     {MaxAmpere vorbesetzen}

type
 TSw_Mode= (V, H, A);  {Eingabe-Einheiten: Volt, Ampere, Hex}
 TSw   = record
          Mode: TSw_Mode;
          Max : Real;
          User: Integer;
         end;


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

 procedure Write_Real_10A_Bipol (Data: Word);
  var Real_Zahl : Real;
      Int_Zahl  : Integer;
      Vorzeichen : Char;
 begin                        {Bit 15 ist Vorzeichen}
   if (Data and $8000) = 0 then
    begin     {positiv}
      Real_Zahl := Data * (Sw_Amax/32768);
      Vorzeichen:= '+';
    end
   else
    begin     {negativ}
      Data := (not Data) + 1;               {Zweier Komplement}
      Real_Zahl := Data * (Sw_Amax/32768);
      Vorzeichen:= '-';
   end;
   Write (Vorzeichen, Real_Zahl:9:3);
 end;



procedure Write_Real_200A_Bipol (Data: Word); {200A Endwert: Write_Real_10V_Bipol (Wr_Data);}
var Real_Zahl : Real;
    Int_Zahl  : Integer;
    Vorzeichen : Char;
begin                        {Bit 15 ist Vorzeichen}
  if (Data and $8000) = 0 then
   begin     {positiv}
      Real_Zahl := Data * 610.3515626/100000;
      Vorzeichen:= '+';
   end
  else
   begin     {negativ}
     Data := (not Data) + 1;               {Zweier Komplement}
{     Real_Zahl := Data * 305.1757813/1000000;  }
     Real_Zahl := Data * 610.3515626/100000;
     Vorzeichen:= '-';
  end;

  Write (Vorzeichen, Real_Zahl:7:3);
 end;


 procedure Set_TastHall_Win;
  begin
   Window(39, 20, 80, 23);
   TextBackground(Green);
   TextColor(Black);               {Setze Schriftfarbe}
  end;

 function Ask_Intervall: Byte;
  var answer : CHAR;
      Status : Boolean;
      Zeit   : Byte;
  begin
    Ini_Text_Win;
    GotoXY(01,22); ClrEol;
    Write('Am Ende einer Iteration kann eine Wartezeit eingefÅgt werden. 0 ergibt SÑgezahn');
    Ini_Msg_Win;
    Write ('Bitte Intervall-Zeit in 0,1s-Schritten eingeben [0...100]: ');
    readln (Zeit);
    Ask_Intervall := Zeit;
    if not Zeit in [0..100] then
     begin
       status := FALSE;
       WHILE NOT status DO
        begin
          Ini_Msg_Win;
          Write ('Bitte Intervall-Zeit in 0,1s-Schritten eingeben [0...100]: ');
          readln (Zeit);
          IF Zeit in [0..100] THEN
           begin
            Ask_Intervall:= Zeit;
            status := TRUE;
           end;
        end;
     end; {if j}
  End; {ask_ifc}

 function Ask_Prozent: Byte;
  const prozent_max = 25;
  var answer : CHAR;
      Status : Boolean;
      Przent: Byte;
  begin
    status := FALSE;
    Ini_Text_Win;
    GotoXY(01,22); ClrEol;
    Write('Bei 0-Prozent: keine Iteration --> Rampenverlauf!!');
    Ini_Msg_Win;
    Write ('Bitte maximale Prozent-Abweichnung vom Sollwert-Max eingeben [0..',prozent_max,']: ');
    readln (Przent);
    Ask_Prozent := Przent;
    if not (Przent in [0..prozent_max]) then
     begin
       WHILE NOT status DO
        begin
         Ini_Msg_Win;
         Write ('Bitte maximale Prozent-Abweichnung vom Sollwert-Max eingeben [');
         TextColor (Red);
         Write ('0..',prozent_max); TextColor (Yellow); Write (']: ');
         readln (Przent);
         IF Przent in [0..prozent_max] THEN
          begin
           status := TRUE;
           Ask_Prozent := Przent;
          end;
        end;
     end; {if j}
  End; {ask_ifc}

 function Ask_Step_Time: LongInt;
  var Step_In   : LongInt;
  begin
    status := FALSE;
    Ini_Msg_Win;
    Write ('Bitte Step_Time [x 10us] eingeben  oder  <Q>uit (Default=');
    Write (Step_Time_Default); Write ('): ');
    {$I-}                    {Fehleingabe zulassen: Compiler-Check ausschalten}
    Readln (Step_In );
    {$I+}
    if (IoResult <> 0) then
      Ask_Step_Time := Step_Time_Default             {Fehler selber abfangen!}
    else
      Ask_Step_Time := Step_In;
  End; {Ask_Step_Time}

 function Ask_Top_Time: LongInt;
  var Step_In   : LongInt;
  begin
    status := FALSE;
    Ini_Msg_Win;
    Write ('Wartezeit Top_Werte [x 10us] eingeben oder <Q>uit (Default=');
    Write(Top_Time_Default); Write('): ');
    {$I-}                    {Fehleingabe zulassen: Compiler-Check ausschalten}
    Readln (Step_In );
    {$I+}
    if (IoResult <> 0) then
      Ask_Top_Time := Top_Time_Default               {Fehler selber abfangen!}
    else
      Ask_Top_Time := Step_In;
  End; {Ask_Top_Time}


function Rd_Real: Real;    {Max. 65 sec, wegen Timer 2}
var Status    : Boolean;
    Real_Zahl : Real;
begin
  Status := FALSE;
  repeat
   Ini_Msg_Win;
   Write('Bitte Flie·komma-Zahl eingeben [Format 00.0]: ');
   {$I-}                    {Fehleingabe zulassen: Compiler-Check ausschalten}
   Readln(Real_Zahl);
   {$I+}
   if (IoResult <> 0) or (Real_Zahl > 65.0) or (Real_Zahl < 0.1) then
    begin                                           {Fehler selber abfangen!}
     Ini_Err_Win;
     Write('ERROR: Format falsch oder Zahl nicht 0.1..65.0 !! Weiter mit <CR>');
     ReadKey;
    end
   else
     Status := True;
  until Status = True;
  Rd_Real   := Real_Zahl;    {Real-Zahl in Integer umwandeln}
end; {Get_Real_10}



 procedure Mil_NG_Rampe;
 label 99;
 const Ref_Time       = 3.2;
       Write_Fct_Code = $06;
       Read_Fct_Code  = $81;
       Z_Base         = 15;

 type TVorz = (Plus, Minus, Bipolar);
      TDirection = (Up, Down);
 var
  MilErr  : TMilErr;
  Fct     : TFct;
  Polar   : TVorz;
  Delta_U : Integer;
  Delta_T : LongInt;
  Zeichen : Char;
  Zeit    : Real;
  Sollwert: LongInt;
  Direction: TDirection;

 function Ask_Time (var Mode: TVorz; var D_U: Integer; var D_T: LongInt): Boolean;
  label 1;
  var Factor : Real;
  begin
   Ask_Time := False;
   Mode := Plus;
   D_U  := 0;
   D_T  := 0;
   Ini_Text_Win;
   Ini_Msg_Win;                                            {, [B]ipolar}
   Write ('Vorzeichen f. Rampe eingeben: Abruch <Esc>, <CR> fÅr +, [M] fÅr -: ');
   Zeichen := NewReadKey;
   case Zeichen of
     #27    : goto 1;
    'm','M' : Mode := Minus;
   end;

   Ini_Text_Win;
   GotoXY(1, 22); Clreol;
   Write ('[Rampenzeit 0.1 ... 65.0 sec]');
   Zeit := Rd_Real;

   if Zeit = Ref_Time then   {Sollwert alle 100 us incrementieren = 3.2 sec}
    begin     {normalerweise Timer 2: Ein Tick = 10 us; 10 x 10 us = 100 us}
      D_U  := 1;        {Delta U: Spannung um 1 inkrementieren}
      D_T  := 3;        {bei 33 Mhz-CPU: Timer2 + 40 us MIL-Transfer + Software= 100us}
    end;

   if Zeit > Ref_Time then
    begin {wenn die Zeit > 3.2 sec: Zeit zwischen 2 Sollwerten lÑnger}
      D_U  := 1;
      D_T  := Round (10 * (Zeit/Ref_Time));
    end {Zeit > 3.2}
   else
    begin
      D_U  := Round (Ref_Time/Zeit);   {Spannungsstufen grî·er, min. Time}
      D_T  := 3; {bei 33 Mhz CPU:Timer2 + 40 us Mil-Transfer + 30us Software=100us}
    end; {Zeit < 3.2}
   Ask_Time := True;
1:
  end; {Ask_Time}


 begin
   Transf_Cnt:= 0;
   Mil_Ask_Ifc;
   if not Ask_Time (Polar, Delta_U, Delta_T) then goto 99;

   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Write_Fct_Code;

   Ini_Text_Win;
   GotoXY(25,02); Write('----- Rampentest fÅr Magnete -----');
   GotoXY(05,22); TextColor (Red);
   Write('Aus GeschwindigkeitsgrÅnden: Im Loop-Mode keine MIL-Transfer-Anzeige!!');
   TextColor (Black);
   GotoXY(25,05); write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');

   GotoXY(10,8);   Write ('Transfer-Count : ');
   GotoXY(10,9);   Write ('Data     [Hex] : ');
   TextColor (Yellow);
   GotoXY(27,11); write (chr($18));
   GotoXY(27,12); write ('Falls Cursor hier blinkt: Loop-Mode!!! ');
   TextColor(Black);
   GotoXY(10,10);  Write ('         [Volt]: ');

   GotoXY(10,Z_Base);   Write ('PolaritÑt           : ');
   if Polar = Plus then Write ('Plus ') else Write ('Minus');
   GotoXY(10,Z_Base+1); write ('Rampenzeit  [sec   ]:  '); Write (Zeit:4:1);
   GotoXY(10,Z_Base+2); write ('Zeitabstand [us    ]: '); Write (Delta_T * 10 + 40 + 30);
   GotoXY(10,Z_Base+3); write ('Inkremente  [Anzahl]: '); Write (Delta_U);
   GotoXY(10,Z_Base+4); write ('            [Volt  ]: '); Write_Real_10V_Bipol (Delta_U);

   Sollwert  := 0;
   Direction := Up;
   Mil.Wr (Sollwert, Fct, MilErr);    {Magnet auf Sollwert=0 einstellen}

                     {Software-Gerippe fÅr Single-Step und Loop}
    Cursor(False);
    Std_Msg;
    Ch := NewReadKey;

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




   repeat
    repeat
      if Polar = Plus then
       begin
         if Direction = Up then
          begin                                  {up}
            Sollwert := Sollwert + Delta_U;
            if Sollwert >= $7FFF then
             begin
              Sollwert  := $7FFF;
              Direction := Down;
             end;
          end
         else
          begin                                  {Down}
            Sollwert := Sollwert - Delta_U;
            if Sollwert <= 0 then
             begin
              Sollwert  := 0;
              Direction := Up;
             end;
          end; {if Direction}
       end
      else
       begin                                     {PolaritÑt Minus}
         if Direction = Up then
          begin                                  {up}
            Sollwert := Sollwert - Delta_U;
            if Sollwert < -$8000 then
             begin
              Sollwert  := $8000;
              Direction := Down;
             end;
          end
         else
          begin                                  {Down}
            Sollwert := Sollwert + Delta_U;
            if (Sollwert > $FFFF) then
             begin
              Sollwert  := 0;
              Direction := Up;
             end;
          end; {if Direction}
       end;

      Mil.Wr (Sollwert, Fct, MilErr);
      Mil.Timer2_Wait(Delta_T);
    until KeyEPressed or (Ch = ' ');

    if Ch = ' ' then
      begin
       Set_Text_win;
       Transf_Cnt := Transf_Cnt+ 1;
       GotoXY (27,8);  Write (Transf_Cnt);
       GotoXY (27,9);  Write (Hex_Word(Sollwert));
       GotoXY (27,10); Write_Real_10V_Bipol (Sollwert);

       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyEPressed;
       Set_Text_Win;
       GotoXY (27,8);  ClrEol;
       GotoXY (27,9);  ClrEol;
       GotoXY (27,10); ClrEol;
      end;
    Ch := NewReadKey;
   until Ch in ['x','X'];
 99:
 end; {Mil_NG_Rampe}


{ Ab hier SCAN}

const
  Z_Resul_Win = 14;
  Z_Delta_0   = 04;
  Z_Delta_1   = Z_Delta_0 + 1;
  Z_Delta_2   = Z_Delta_0 + 2;
  Z_Delta_3   = Z_Delta_0 + 3;
  Z_Delta_4   = Z_Delta_0 + 4;
  Z_Delta_5   = Z_Delta_0 + 5;
  Z_Delta_6   = Z_Delta_0 + 6;
  Sw_Fullscale= $7FFF;

  procedure Set_Result_Win;
   begin
    Window(02, Z_Resul_Win, 35, 23);
    TextBackground(Cyan);
    TextColor(Black);               {Setze Schriftfarbe}
   end;

  procedure Ini_Result_Win;
   var    Sonder_Zeichen : Char;
   begin
    Set_Result_Win;
    Sonder_Zeichen := chr(124);  {Absolut Zeichen}
    Window(02, Z_Resul_Win, 35, 23);
    TextBackground(Cyan);
    TextColor(Blue);               {Setze Schriftfarbe}
    ClrScr;
    GotoXY(01,01);  Write ('Anz. Me·-Zykl Vorgabe: ');
    GotoXY(01,02);  Write ('Anz. Iw-Msg.  aktuell: ');
    TextColor(Yellow);
    GotoXY(01,03); Write (Sonder_Zeichen); Write ('Delta'); Write (Sonder_Zeichen);
    Write(' SW [o/oo]FS'); Write ('  Verteilg[o/o]');

    TextColor(Brown);
    GotoXY(02,Z_Delta_0);  Write ('0  <  1: ');
    GotoXY(02,Z_Delta_1);  Write ('1  <  2: ');
    GotoXY(02,Z_Delta_2);  Write ('2  <  4: ');
    GotoXY(02,Z_Delta_3);  Write ('4  <  6: ');
    GotoXY(02,Z_Delta_4);  Write ('6  <  8: ');
    GotoXY(02,Z_Delta_5);  Write ('8  < 10: ');
    GotoXY(02,Z_Delta_6);  Write ('  => 10: ');
   end;

  procedure Set_SW_Win;
   begin
    Window(39, 20, 80, 23);
    TextBackground(Green);
    TextColor(Black);
   end;

 procedure Mil_SW_IW;
 label 99;
 const
   Z_Base   = 4;
   Z_Sw     = Z_Base+2;
   Z_Iw     = Z_Base+3;
   Z_Off    = Z_Base+4;

   S_Sw_Min = 22;
   S_Sw_Max = 45;
   S_Delay  = 68;
   S_Off    = 22;

   S_Delta_Res = 20;
   Prznt_Off   = 9;

   Anz_Delta= 6;
   Diff_0   = 0.1;    {Diff. zwischen SW - IW in %}
   Diff_1   = 0.2;
   Diff_2   = 0.4;
   Diff_3   = 0.6;
   Diff_4   = 0.8;
   Diff_5   = 1.0;


 var
   MilErr     : TMilErr;
   Fct        : TFct;
   Sonder_Zeichen : Char;
   Bit16_Str  : Str19 ;
   Real_Data  : Real;
   SW_Act     : Integer;
   Life_Mode  : TLife_XY;
   Sollw      : TSw;
   Data_Ask   : Word;
   Sw_Min, Sw_Max     : Integer;
   Iw_Min, Iw_Max     : Integer;
   Iw_Off             : Integer;
   Wr_Delay, Rd_Delay : LongInt;
   Count_Total   : LongInt;
   Delta_Ary     : array [0..Anz_Delta] of LongInt;
   Index         : Byte;
   User_Int      : Integer;
   Adress        : Word;
   User_Time     : LongInt;
   Zykl_Vorgabe   : Real;
   Zykl_Aktuell   : Real;
   Zykl_Startwert : Real;

 procedure Ini_Delta_Ary;
  var Idx : Byte;
  begin
    for Idx := 0 to Anz_Delta do Delta_Ary[Idx] := 0;
  end;

  procedure Clear_Result_Value;
   var I : Byte; Idx : Byte;
   begin
     GotoXY(S_Delta_Res,Z_Delta_0); Write ('          ');
     GotoXY(S_Delta_Res,Z_Delta_1); Write ('          ');
     GotoXY(S_Delta_Res,Z_Delta_2); Write ('          ');
     GotoXY(S_Delta_Res,Z_Delta_3); Write ('          ');
     GotoXY(S_Delta_Res,Z_Delta_4); Write ('          ');
     GotoXY(S_Delta_Res,Z_Delta_5); Write ('          ');
     GotoXY(S_Delta_Res,Z_Delta_6); Write ('          ');
     for I := 0 to Anz_Delta do
      begin
           GotoXY(S_Delta_Res + Prznt_Off , Z_Delta_0 + I);
           Write ('     ');
      end;
   end;

  procedure Sw_Displ;
   var I : Byte;
   begin
     Set_Text_Win;
{     if Sw_Min = 0 then TextColor (Black + 128);  }
     GotoXY(S_Sw_Min,   Z_Sw);   Write (hex_word(Sw_Min));
     GotoXY(S_Sw_Min+7, Z_Sw);   Write_Real_10V_Bipol (Sw_Min);

{     if Sw_Max = 0 then TextColor (Black + 128);  }
     GotoXY(S_Sw_Max,   Z_Sw);   Write (hex_word(Sw_Max));
     GotoXY(S_Sw_Max+7, Z_Sw);   Write_Real_10V_Bipol (Sw_Max);
     TextColor(Black);

     GotoXY(S_Delay+6,  Z_Sw);   Write ((Wr_Delay / 100):5:1);
     GotoXY(S_Delay+6,  Z_Iw);   Write ((Rd_Delay *  10):5);

     GotoXY(S_Sw_Min,   Z_Off);  Write (hex_word(Iw_Off));
     GotoXY(S_Sw_Min+7, Z_Off);  Write_Real_10V_Bipol (Iw_Off);

     {Immer wenn ein neuer Sollwert geschrieben wird: Iw-Anzeige lîschen}
     GotoXY(S_Sw_Min,   Z_Iw); Write ('    ');
     GotoXY(S_Sw_Min+7, Z_Iw); Write ('           ');
     GotoXY(S_Sw_Max,   Z_Iw); Write ('    ');
     GotoXY(S_Sw_Max+7, Z_Iw); Write ('           ');

     GotoXY(01, Z_Sw);
     if Single_Step then
      begin
       Write ('    ');
       Life_Sign_XY (Life_Mode);
      end
     else
      begin
        TextColor (Red + 128);
        Write ('Loop');
      end;

     Set_Result_Win;
     TextColor(Black);
     GotoXY(26,01);
     if Zykl_Vorgabe > 0 then  Write (Zykl_Vorgabe:8:0)
     else  Write ('    Nein');
     GotoXY(26,02);
     if Single_Step then  Write (Count_Total:8) else
      begin
        TextColor(Black);
        GotoXY(S_Delta_Res,Z_Delta_0); Write ('          ');
        GotoXY(S_Delta_Res,Z_Delta_1); Write ('          ');
        GotoXY(S_Delta_Res,Z_Delta_2); Write ('          ');
        GotoXY(S_Delta_Res,Z_Delta_3); Write ('          ');
        GotoXY(S_Delta_Res,Z_Delta_4); Write ('          ');
        GotoXY(S_Delta_Res,Z_Delta_5); Write ('          ');
        GotoXY(S_Delta_Res,Z_Delta_6); Write ('          ');

        for I := 0 to Anz_Delta do      {clear Anzeige}
         begin
           if Delta_Ary[I] > 0 then
            begin
              GotoXY(S_Delta_Res + Prznt_Off , Z_Delta_0 + I);
              Write ('     ');
            end;
         end;
      end;
    end;  {Sw_Displ}

  procedure Iw_Displ (Ist_Min, Ist_Max : Integer);
   begin
    Set_Text_Win;
    GotoXY(S_Sw_Min,   Z_Sw+1); Write (hex_word(Ist_Min));
    GotoXY(S_Sw_Min+7, Z_Sw+1); Write_Real_10V_Bipol (Ist_Min);
    GotoXY(S_Sw_Max,   Z_Sw+1); Write (hex_word(Ist_Max));
    GotoXY(S_Sw_Max+7, Z_Sw+1); Write_Real_10V_Bipol (Ist_Max);
   end;

 procedure Ini_All;
  begin
   Single_Step  := True;
   Count_Total  := 0;
   Zykl_Aktuell := 0;
   Zykl_Vorgabe := 0;
   Ini_Result_Win;
   Ini_Delta_Ary;
   Ini_Delta_Ary;
   Sw_Displ;
  end; {Ini_All}

  function WrRd_MinMax (W_Delay, R_Delay: LongInt): Boolean;
   var Delta       : Real;
       IwMin_Off   : Integer;
       IwMax_Off   : Integer;
   begin
     Iw_Min := 0;
     Iw_Max := 0;
     WrRd_MinMax := False;
     Mil.Timer2_Wait (W_Delay);            {Wartezeit zwischen SW_Min und SW_Max}

     Fct.B.Fct := Fct_Wr_Sw1;
     Mil.Wr (SW_Min, Fct, MilErr);         {minimal SW}
     Mil.Timer2_Wait (R_Delay);

     Fct.B.Fct := Fct_Rd_Ist1;
     Mil.Rd (Word(Iw_Min), Fct, MilErr);   {Lese Istwert}
     if MilErr <> No_Err then Exit;        {Abort}
     IwMin_Off := Iw_Min + Iw_Off;         {Istwert mit Offset korrigieren}

     Mil.Timer2_Wait (W_Delay);            {Wartezeit zwischen SW_Min und SW_Max}
     Fct.B.Fct := Fct_Wr_Sw1;
     Mil.Wr (SW_Max, Fct, MilErr);         {Maximal SW}

     Mil.Timer2_Wait (R_Delay);
     Fct.B.Fct := Fct_Rd_Ist1;
     Mil.Rd (Word(Iw_Max), Fct, MilErr);   {Lese Istwert}
     if  MilErr <> No_Err then Exit;       {Abort}
     IwMax_Off := Iw_Max + Iw_Off;         {Istwert mit Offset korrigieren}

     {Sollwert = 0 fÅhrt zu Division durch Null: wird nicht ausgewertet}
{     if (Sw_Min = 0) or (Sw_Max = 0) then
      begin
        WrRd_MinMax := True;
        Exit;
      end;
}
     {Beide Istwerte gelesen: Berechne und rette Differenz}

     Delta := (abs((IwMin_Off - Sw_Min)) / Sw_Fullscale) * 100;
     if  abs(Delta) <  Diff_0                            then Delta_Ary[0] := Delta_Ary[0] + 1;
     if (abs(Delta) >= Diff_0) and (abs(Delta) < Diff_1) then Delta_Ary[1] := Delta_Ary[1] + 1;
     if (abs(Delta) >= Diff_1) and (abs(Delta) < Diff_2) then Delta_Ary[2] := Delta_Ary[2] + 1;
     if (abs(Delta) >= Diff_2) and (abs(Delta) < Diff_3) then Delta_Ary[3] := Delta_Ary[3] + 1;
     if (abs(Delta) >= Diff_3) and (abs(Delta) < Diff_4) then Delta_Ary[4] := Delta_Ary[4] + 1;
     if (abs(Delta) >= Diff_4) and (abs(Delta) < Diff_5) then Delta_Ary[5] := Delta_Ary[5] + 1;
     if (abs(Delta) >= Diff_5)                           then Delta_Ary[6] := Delta_Ary[6] + 1;

     Delta := (abs((IwMax_Off - Sw_Max)) / Sw_Fullscale) * 100;
     if  abs(Delta) <  Diff_0                            then Delta_Ary[0] := Delta_Ary[0] + 1;
     if (abs(Delta) >= Diff_0) and (abs(Delta) < Diff_1) then Delta_Ary[1] := Delta_Ary[1] + 1;
     if (abs(Delta) >= Diff_1) and (abs(Delta) < Diff_2) then Delta_Ary[2] := Delta_Ary[2] + 1;
     if (abs(Delta) >= Diff_2) and (abs(Delta) < Diff_3) then Delta_Ary[3] := Delta_Ary[3] + 1;
     if (abs(Delta) >= Diff_3) and (abs(Delta) < Diff_4) then Delta_Ary[4] := Delta_Ary[4] + 1;
     if (abs(Delta) >= Diff_4) and (abs(Delta) < Diff_5) then Delta_Ary[5] := Delta_Ary[5] + 1;
     if (abs(Delta) >= Diff_5)                           then Delta_Ary[6] := Delta_Ary[6] + 1;

     Count_Total  := Count_Total  + 2;
     Zykl_Aktuell := Zykl_Aktuell + 1;
     WrRd_MinMax  := True;
   end; {WrRd_MinMax}

 procedure Displ_Result;
  var   Sum_Delta_Ary : Real;
        Prozent       : Real;
        I             : Byte;
  begin
    Set_Text_Win;
    Iw_Displ (Iw_Min, Iw_Max);
    Set_Result_Win;
    TextColor(Black);
    if Count_Total > 0 then
     begin
       GotoXY(26,02);  Write (Count_Total:8);
       GotoXY(S_Delta_Res,Z_Delta_0); Write (Delta_Ary[0]); { Write ('0  <  1: ');}
       GotoXY(S_Delta_Res,Z_Delta_1); Write (Delta_Ary[1]); { Write ('1  <  2: ');}
       GotoXY(S_Delta_Res,Z_Delta_2); Write (Delta_Ary[2]); { Write ('2  <  4: ');}
       GotoXY(S_Delta_Res,Z_Delta_3); Write (Delta_Ary[3]); { Write ('4  <  6: ');}
       GotoXY(S_Delta_Res,Z_Delta_4); Write (Delta_Ary[4]); { Write ('6  <  8: ');}
       GotoXY(S_Delta_Res,Z_Delta_5); Write (Delta_Ary[5]); { Write ('8  < 10: ');}
       GotoXY(S_Delta_Res,Z_Delta_6); Write (Delta_Ary[6]); { Write ('   => 10: ');}
     end;
                                {Prozent-Auswertung ausgeben}
    Sum_Delta_Ary := 0;
    for I := 0 to Anz_Delta do
     begin
      Sum_Delta_Ary := Sum_Delta_Ary + Delta_Ary[I];
     end;

    for I := 0 to Anz_Delta do
     begin
       if Delta_Ary[I] > 0 then
        begin
          Prozent := (Delta_Ary[I] / Sum_Delta_Ary) * 100;
          GotoXY(S_Delta_Res + Prznt_Off , Z_Delta_0 + I);
          Write (Prozent:5:1);
        end;
     end;
  end; {Displ_Result}


 begin
   Life_Mode.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
   Life_Mode.PosX    := 02;        {02;}
   Life_Mode.PosY    := Z_Sw;        {}
   Life_Mode.Time    := Life_Time_Slow;
   Life_Mode.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}

   Mil_Ask_Ifc;
   Transf_Cnt:= 0;
   Zykl_Startwert  :=   0;
   Zykl_Vorgabe    :=   0;
   Zykl_Aktuell    :=   0;
   Count_Total     :=   0;
   Wr_Delay        := 200;   {x 10us}
   Rd_Delay        :=  40;   {x 10 us}
   Ini_Delta_Ary;

   Sw_Min := 0;  Sw_Max := 0;
   Iw_Min := 0;  Iw_Max := 0;
   Iw_Off := 0;
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Wr_Sw1;
   Sonder_Zeichen := chr(124);  {Absolut Zeichen}

   Ini_Text_Win;
   TextColor(Brown);
   GotoXY(03,01); Write('Schreibe Sollwerte MIN/MAX in definierten AbstÑnden (Wr-Delay) und lese   ');
   GotoXY(03,02); Write('jeweils nach einstellbarer Verzîgerung (Rd-Delay) den zugehîrigen Istwert ');

   GotoXY(03,Z_Base); Write ('IFK-Nr [Hex]: '); TextColor(Yellow);
   GotoXY(17,Z_Base); Write (Hex_Byte(Ifc_Test_Nr));  TextColor(Brown);
   GotoXY(S_Sw_Min+5,Z_Base);   Write ('MIN');
   GotoXY(S_Sw_Max+5,Z_Base);   Write ('MAX');
   GotoXY(S_Delay ,Z_Base);     Write ('DELAY');

   GotoXY(S_Sw_Min,Z_Base+1); Write ('[Hex]  [Volt]');
   GotoXY(S_Sw_Max,Z_Base+1); Write ('[Hex]  [Volt]');

   GotoXY(S_Sw_Min-15,Z_Sw );   Write ('SW [', Hex_Byte (Fct_Wr_Sw1) ,'H]:');
   GotoXY(S_Sw_Min-15,Z_Iw );   Write ('IW [', Hex_Byte (Fct_Rd_Ist1),'H]:');
   GotoXY(S_Sw_Min-15,Z_Off);   Write ('IW: OFFSET-');
   GotoXY(S_Sw_Min-15,Z_Off+1); Write ('Kompensation');

   GotoXY(S_Delay-2,Z_Sw );     Write ('Wr[ms]: ');
   GotoXY(S_Delay-2,Z_Iw );     Write ('Rd[us]: ');

   TextColor (Black);
   Ini_Result_Win;
   Set_Text_Win;
   TextColor(Brown);
   GotoXY(39,17); write('Belegung Funktions- u. Sondertasten: ');
   Set_SW_Win;
   TextColor(Yellow);
   GotoXY(01, 01); Write('F1:Sw_Min    F5:Rd_200us  F9 :Ini %Anzeige');
   GotoXY(01, 02); Write('F2:Sw_Max    F6:Rd_300us  F10:Ifc-Adr     ');
   GotoXY(01, 03); Write('F3:Sw 0.0    F7:Rd_400us  F11:Offset Input');
   GotoXY(01, 04); Write('F4:Wr_Delay  F8:Rd_Delay  F12:MessZyklen ');

   Set_Text_Win;
   TextColor(Brown);
   GotoXY(02, Z_Resul_Win-3);  Write ('Resultat der Messungen: ');
   Set_Text_Win;
   SW_Displ;
                     {Software-Gerippe fÅr Single-Step und Loop}
   Cursor(False);
   Std_Msg;
   Single_Step := True;

   repeat
     if KeyEPressed then Ch := NewReadKey;
     if Ch = ' ' then Single_Step := True;

     if Single_Step then
      begin
       if not WrRd_MinMax (Wr_Delay, Rd_Delay) then
         begin
           Ini_Err_Win;
           Write ('ERROR: Wr-Rd-Zyklus fehlerhaft!!      Weiter mit <Space> ');
           Ch := NewReadKey;
         end;

       Sw_Displ;
       Displ_Result;
       Ini_Msg_Win;
       Write('Step/Stop <Space>, Loop <CR>, Funkt.- u. Sondertasten benutzen!   Ende mit [X]');
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then
      begin
       Single_Step := False;
       Clear_Result_Value;
       if  (Zykl_Aktuell = Zykl_Vorgabe) then
        begin
          Zykl_Vorgabe := Zykl_Vorgabe + Zykl_Startwert;
        end;
       Sw_Displ;
       Ini_Msg_Win;
       Write('Step/Stop <Space>, Loop <CR>, Funkt.- u. Sondertasten benutzen!   Ende mit [X]');
       Ch := '?';                {Sw nur 1 x anzeigen}
      end;

     if not Single_Step then
      begin
       if not WrRd_MinMax (Wr_Delay, Rd_Delay) then
         begin
           Ini_Err_Win;
           Write ('ERROR: Wr-Rd-Zyklus fehlerhaft!!      Weiter mit <Space> ');
           Ch := NewReadKey;
         end;

       if Zykl_Startwert <> 0 then
         begin
           if  (Zykl_Aktuell > (Zykl_Vorgabe * 1.0  - 2)) then
            begin
             Zykl_Vorgabe := Zykl_Vorgabe + Zykl_Startwert;
             Single_Step  := True;
             Sw_Displ;
             Displ_Result;
            end;
         end;
      end;   {if not Single_Step}

    if Ch = #0 then
     begin
       Ch := NewReadKey;
       case ord (Ch) of
       Taste_F1 : begin
                    Ini_Msg_Win;
                    Write ('Sw-Min in [V]olt oder [H]ex ?      Auswahl eingeben (Volt = <CR> oder <Esc>: ');
                    repeat until KeyEPressed;
                    Ch := NewReadKey;
                    case Ch of
                     'v','V',#13 : begin
                                    Sollw.Mode:= V;
                                    Sollw.Max := 10.0;
                                    if Ask_Sw_Break (Sollw) then SW_Min := Sollw.User;
                                    end;
                     'h','H': begin
                                Sollw.Mode:= H;
                                if Ask_Sw_Break (Sollw) then SW_Min := Sollw.User;
                              end;
                    end; {case}
                    Sw_Displ;
                    Ini_Msg_Win;
                    Write('Step/Stop <Space>, Loop <CR>, Funkt.- u. Sondertasten benutzen!   Ende mit [X]');
                    Single_Step := True;
                    Ini_All;
                  end;
       Taste_F2 : begin
                    Ini_Msg_Win;
                    Write ('Sw-Max in [V]olt oder [H]ex ?      Auswahl eingeben (Volt = <CR> oder <Esc>: ');
                    repeat until KeyEPressed;
                    Ch := NewReadKey;
                    case Ch of
                     'v','V',#13: begin
                                   Sollw.Mode:= V;
                                   Sollw.Max := 10.0;
                                   if Ask_Sw_Break (Sollw) then
                                    begin
                                     SW_Max := Sollw.User;
                                  end;
                              end;
                     'h','H': begin
                                Sollw.Mode:= H;
                                if Ask_Sw_Break (Sollw) then SW_Max := Sollw.User;
                              end;
                    end; {case}
                    Sw_Displ;
                    Ini_Msg_Win;
                    Write('Step/Stop <Space>, Loop <CR>, Funkt.- u. Sondertasten benutzen!   Ende mit [X]');
                    Single_Step := True;
                    Ini_All;
                  end;
       Taste_F3 : begin
                    Sw_Min := 0;
                    Sw_Max := 0;
                    Iw_Off := 0;
                    Ini_All;
                    Ini_Err_Win;
                    Write ('Bei Sollwert Null kein Lesen, weil %-Berechnung keine Div durch Null erlaubt!!');
                    Mil.Timer2_Wait (400000);
                    Ini_Msg_Win;
                    Write('Step/Stop <Space>, Loop <CR>, Funkt.- u. Sondertasten benutzen!   Ende mit [X]');
                  end;
       Taste_F4 : begin
                    Ini_Msg_Win;
                    Write ('Write-Verzîgerung zwischen SW-Min u. SW-Max eingeben [0.1ms] oder <Q>: ');
                    {$I-}               {Fehleingabe zulassen: Compiler-Check ausschalten}
                    Readln (User_Time);
                    {$I+}
                    if (IoResult <> 0) then
                     begin                   {Fehler}
                       Ini_Msg_Win;
                       Write('Step/Stop <Space>, Loop <CR>, Funkt.- u. Sondertasten benutzen!   Ende mit [X]');
                       Sw_Displ;
                     end
                    else
                     begin
                       Wr_Delay := User_Time * 10;
                       Ini_Msg_Win;
                       Write('Step/Stop <Space>, Loop <CR>, Funkt.- u. Sondertasten benutzen!   Ende mit [X]');
                       Sw_Displ;
                       Ini_All;
                     end;
                  end;
       Taste_F5 : begin
                    Rd_Delay := 20;
                    Ini_All;
                  end;
       Taste_F6 : begin
                    Rd_Delay := 30;
                    Ini_All;
                  end;
       Taste_F7 : begin
                    Rd_Delay := 40;
                    Ini_All;
                  end;
       Taste_F8 : begin
                    Ini_Msg_Win;
                    Write ('Read-Verzîgerung nach dem Sollwert-Schreiben eingeben [us] oder <Q>: ');
                    {$I-}               {Fehleingabe zulassen: Compiler-Check ausschalten}
                    Readln (User_Time);
                    {$I+}
                    if (IoResult <> 0) then
                     begin                   {Fehler}
                       Ini_Msg_Win;
                       Write('Step/Stop <Space>, Loop <CR>, Funkt.- u. Sondertasten benutzen!   Ende mit [X]');
                     end
                    else
                     begin
                       Rd_Delay := User_Time Div 10;
                       Ini_Msg_Win;
                       Write('Step/Stop <Space>, Loop <CR>, Funkt.- u. Sondertasten benutzen!   Ende mit [X]');
                     {  Sw_Displ;}
                       Ini_All;
                     end;
                  end;
       Taste_F9 : begin
                   Ini_All;
{                    Count_Total  := 0;
                    Zykl_aktuell := 0;
                    Ini_Result_Win;
                    Ini_Delta_Ary;
                    Sw_Displ;
                    Clear_Result_Value;
}                   end;
       Taste_F10: begin
                   if Ask_Hex_Break (Adress, Byt) then
                     begin
                      Ifc_Test_Nr := Adress;
                      Fct.B.Adr   := Ifc_Test_Nr;
                      Set_Text_Win; TextColor(Yellow);
                      GotoXY(17,Z_Base); Write (Hex_Byte(Ifc_Test_Nr));
                      Ini_Msg_Win;
                      Write('Step/Stop <Space>, Loop <CR>, Funkt.- u. Sondertasten benutzen!   Ende mit [X]');
{                      repeat until KeyEPressed;
}                     end;
                  end; {Taste_F10}
       Taste_F11 : begin
                    Ini_Msg_Win;
                    Write ('IW-Offset in [V]olt oder [H]ex ?    Auswahl eingeben (Volt = <CR> oder <Esc>: ');
                    repeat until KeyEPressed;
                    Ch := NewReadKey;
                    case Ch of
                     'v','V',#13 : begin
                                    Sollw.Mode:= V;
                                    Sollw.Max := 10.0;
                                    if Ask_Sw_Break (Sollw) then IW_Off := Sollw.User;
                                    end;
                     'h','H': begin
                                Sollw.Mode:= H;
                                if Ask_Sw_Break (Sollw) then IW_Off := Sollw.User;
                              end;
                    end; {case}
                    Sw_Displ;
                    Ini_Msg_Win;
                    Write('Step/Stop <Space>, Loop <CR>, Funkt.- u. Sondertasten benutzen!   Ende mit [X]');
                    Single_Step := True;
                    Ini_All;
                   end;
       Taste_F12 : begin
                    if  Read_Int (1, $7FFF, User_Int) then
                     begin
                       Zykl_Aktuell:= 0;
                       Count_Total := 0;
                       Ini_All;
                       Zykl_Startwert := User_Int;
                       Zykl_Vorgabe   := Zykl_Startwert;
                       Single_Step    := True;
                     end;
                    end;

       Taste_Pfeil_Links : begin
                           end;  {Taste_Pfeil_Links}
       Taste_Pfeil_Rechts: begin
                           end;  {Taste_Pfeil_Rechts}
       Taste_Pfeil_Auf   : begin
                           end;
       Taste_Pfeil_Ab   :  begin
                           end;
      end;  {Case}
     end; {if Ch = #0 }
  until Ch in ['x','X'];
99:
 end; {Mil_SW_IW}




{xxx}                                      {Bis hierher User-Erweiterungen !!}
BEGIN   { Hauptprogramm MIL-SCAN }
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

{Ab hier User-Erweiterungen!!}
     'm', 'M' : begin
                 Mil_SW_IW;
                end;
     'n', 'N' : begin
                 end;
     'o', 'O' : begin
                  Mil_NG_Puls_Fix;
                end;
     'p', 'P' : begin
                  Mil_NG_Puls_Vari;
                end;
     'q', 'Q' : begin
                  Mil_NG_Rampe;
                end;
     'r', 'R' : begin
                end;
     's', 'S' : begin
                end;
     't', 'T' : begin
                end;

     'u', 'U' : begin               {Testweise, soll S ersetzen}
                end;
    End; {CASE}
  UNTIL user_input in ['x','X'];
  Window(1, 1, 80, 25);
  TextBackground(Black);
  ClrScr;
END. {mil_mag}

F12                    Ini_Msg_Win;
                    Write ('Bitte Anzahl Test-Zyklen als Vorgabe eingeben: ');
                    Readln (Zykl_Vorgabe);
                    Zykl_Aktuell:= 0;
                    Count_Total := 0;
                    Ini_Delta_Ary;
                    Clear_Result_Value;
                    Single_Step := True;
                    Ini_Msg_Win;
                    Write('Step/Stop <Space>, Loop <CR>, Funkt.- u. Sondertasten benutzen!   Ende mit [X]');
                    Sw_Displ;
 
      if Zykl_Startwert <> 0 then
         begin
           if  (Zykl_Aktuell > (Zykl_Vorgabe * 1.0  - 2)) then
            begin
             Zykl_Vorgabe := Zykl_Vorgabe + Zyklus_Startwert;
             Single_Step  := True;
             Displ_Result;
            end;
         end;
 

   {
                   if Sw_Min <> 0 then
                    begin
                     Fct.B.Fct := Fct_Wr_Sw1;
                     Mil.Wr (SW_Min, Fct, MilErr);
                     Ini_Msg_Win;
                     TextColor(Yellow + 128);
                     Write ('Magnet wurde auf Sw-Min hochgefahren, anschlie·end 1 Sek. Wartezeit!');
                     Mil.Timer2_Wait (300000);
                     Iw_Displ (Iw_Min, Iw_Max);
                     Ini_Msg_Win;
                     Write('Step/Stop <Space>, Loop <CR>, Funkt.- u. Sondertasten benutzen!   Ende mit [X]');
                    end
                   else
                    begin
                      Ini_Err_Win;
                      Write ('ERROR: Magnet kann nicht hochfahren, weil Sw-Min = 0 !!');
                      Mil.Timer2_Wait (300000);
                    end;
}
