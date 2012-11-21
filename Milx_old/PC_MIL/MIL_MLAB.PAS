PROGRAM Mil_MLAB;     {Rampen mit Funktionsgenerator fÅr Magnetlabor}
{ Autor des Basis-Programmes Mil_BASE.PAS: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS

  Autor der Erweiterungen   :
  énderungen:
  12.11.97    Et        Erstellung
  15.01.97    Et        Reduzierung auf das Nîtige

  Sollwert4: D7 : Frequenz      0=Intern, 1=externe Frequenz
             D6 : Master/Slave  0=Master, 1=Slave
             D5 :
             D4 :
             D3 :
}
{$S-}
{$DEFINE NoTest}      {Test: Dummy-Daten aktivieren    NoTest: Arbeitsversion}

uses Crt, WinDos, Dos, Datech, Datech_1;    {spez. MIL-Routinen in Units Datech..}

const
 Head_Line =
      'Datentechnik                         MIL_MLAB   ' +
      '                    [17.03.1998]' +
      '            MagnetLabor: Rampen mit Funktionsgenerator [FG 380 540]            ';

 procedure menue_win;
  var answer: CHAR;
 begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;              {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}

  {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}
  GotoXY(5, 14);
  Writeln('       [M]<-- Adressen IFK u. Funktions-Gen-Typen am MIL-Bus ');
  GotoXY(5, 15);
  Writeln('       [N]<-- Rampen-Test                                    ');
{
  GotoXY(5, 16);
  Writeln('       [O]<-- Rampen-Test SIS/ESR HF-KavitÑten               ');
  GotoXY(5, 17);
  Writeln('       [P]<-- ');
  GotoXY(5, 18);
  Writeln('       [Q]<--  ');
  GotoXY(5, 19);
  Writeln('       [R]<--  ');
  GotoXY(5, 20);
  Write  ('       [S]<--  ');
  GotoXY(5, 21);
  Write  ('       [T]<--                                                            ');
  GotoXY(5, 22);
  Write  ('       [U]<--                                                            ');
}
  Ini_Msg_Win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
 end; {menue_win}

var
 Single_Step: Boolean;              {Globale Variable}



const
 Fct_SW1 = $06;
 Fct_SW3 = $08;
 Fct_SW4 = $09;
 Fct_SW5 = $0A;     {nur fÅr neuen Funktionsgen}

 Fct_Status1  = $91;
 Fct_Status2  = $92;
 Fct_Status3  = $93;     {Dummy Code}
{ Hf_Parm_Max  = 2; }

type
 TFG_Typ   = (Offline, Neu, Alt);
 TLife     = (Norm, Blink);
 TSpeed    = (Slow, Medium, Fast);

 TSummand1 = record case Byte of
                1: ( r : PACKED RECORD
                           lw   : WORD;
                           hw   : WORD;
                         END;
                   );
                2: ( li: LONGINT; );
              end;

 TMag_Parm  = record
               SwMin  : Real;
               SwMax  : Real;
               FScale_Real : Real;
               FScale_Int  : LongInt;
             end;


 TSw_Mode= (V, H, A, R);    {Eingabe-Einheiten: Volt, Ampere, Hex, Real}
 TSw   = record
          Mode : TSw_Mode;
          Max  : Real;
          Float: Real;
          User : Integer;
         end;

               {Testparameter fÅr Rampentests festlegen}
 const
  MagRampe : TMag_Parm =
  (SwMin: -10.00; SWMax: 10.0; FScale_Real: 10.0; FScale_Int: $7FFF0000);

 var
  MilErr : TMilErr;
  Fct    : TFct;

 function Ask_Sw_Break (var SW : TSw): Boolean;    {wahlweise Volt, Hex, Amp}
  var  Real_Zahl : Real;     {Einlesen von User-Daten mit Abort Mîglichkeit!!}
       User_Hex  : Word;     {+/- 10V, 15 Bit mit Vorzeichen }
  begin
   Ask_Sw_Break := False;
   case SW.Mode of
    R : begin                          {+/- 10V, 15 Bit mit Vorzeichen}
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
          Sw.Float     := Real_Zahl;
          Ask_Sw_Break := True;
        end;

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



 procedure Life_Sign_XY (Mode: TLife; X: Byte; Y: Byte; Speed: TSpeed);
  const Life_Time1 = 5000;
        Life_Time2 = 2000;
  var   Life_Wait : LongInt;
        Loop_Wait : LongInt;
  begin
    Cursor(False);
    Set_Text_Win;
    if Mode = Norm then
     begin
      case Speed of
       Slow : Life_Wait := Life_Time1;
       Fast : Life_Wait := Life_Time2;
      else
       Life_Wait := Life_Time1;
      end;

      Set_Text_Win;
      TextColor(Yellow);
      GotoXY(X, Y);  Write (chr($7C)); Mil.Timer2_Wait (Life_Wait);
      GotoXY(X, Y);  Write ('/');      Mil.Timer2_Wait (Life_Wait);
      GotoXY(X, Y);  Write (chr($2D)); Mil.Timer2_Wait (Life_Wait);
      GotoXY(X, Y);  Write ('\');      Mil.Timer2_Wait (Life_Wait);
      TextColor(Black);
     end
    else
     begin
       TextColor(Red+128);
       GotoXY(X, Y); Write (chr($DB));
       TextColor(Black);
     end;
   end; {Life_Sign}


 procedure Detect_FG_Type (Ifc_Nr: Word; var FG_Typ : TFG_Typ; var Version: Byte);
  var Rd_Word  : Word;
      Rd_Int   : Integer;
      Wr_Word  : Word;
      RetAdr   : Byte;
      Vers_Nr  : Byte;
      OnlineErr: TOnlineErr;
      Vers_Tst : Boolean;
      Trepp_Mod: Boolean;

   begin
    FG_Typ    := Offline;   {Default}
    Vers_Tst  := False;
    Trepp_Mod := False;
    Version   := 0;

    Fct.B.Adr := Ifc_Nr;
    Mil.Ifc_Online (Ifc_Nr, RetAdr, OnlineErr);
    if (OnlineErr = NoErr) or (OnlineErr = AdrErr) then
     begin                            {Ifc online}
      if RetAdr <> Ifc_Nr then
       begin
        Ini_Err_Win;
        Write ('ERROR: Antwort v. falscher IFK-Adr!  '); TextColor(Yellow+128);
        Write('Soll: ', Hex_Byte(Ifc_Nr),'[H]  Ist: ', Hex_Byte(RetAdr),'[H]');
        TextColor(Red); Write ('  [W]eiter');
        repeat
          Ch := NewReadKey;
        until Ch in ['w','W'];
        Exit;  {Fehler: Offline}
       end;

      FG_Typ:=  Alt;                  {Online Default}
      Fct.B.Fct := Fct_Status2;
      Mil.Rd (Rd_Word, Fct, MilErr);  {Lese Status}
      Vers_Nr := Lo(Rd_Word);
      {Hat Versionsnr. einen plausiblen Wert?}
      if (Vers_Nr < $FF) and (Vers_Nr > 04) then
       begin
        Vers_Tst := True;
        Version  := Vers_Nr;
       end;
      {LÑ·t sich der "Treppchen-Mode ein/aus schalten?}
      Fct.B.Fct := Fct_SW5;              {nur fÅr neuen Funktionsgen}
      Wr_Word   := 0;                    {Trepp-Mode EIN}
      Mil.Wr (Wr_Word, Fct, MilErr);

      Fct.B.Fct := Fct_Status2;
      Mil.Rd (Rd_Word, Fct, MilErr);      {Lese Status}
      if BitTst (Rd_Word, 12) then Exit;  {PrÅfe Bit D12: Falls "1" > Error}

      Fct.B.Fct := Fct_SW5;               {nur fÅr neuen Funktionsgen}
      Wr_Word   := 1;                     {Trepp-Mode AUS}
      Mil.Wr (Wr_Word, Fct, MilErr);

      Fct.B.Fct := Fct_Status2;
      Mil.Rd (Rd_Word, Fct, MilErr);          {Lese Status}
      if not BitTst (Rd_Word, 12) then Exit;  {PrÅfe Bit D12: Falls "0" > Error}
      Trepp_Mod := True;                      {Falls man hierher kommt: alles Paletti}

      if Trepp_Mod and Vers_Tst then FG_Typ:=  Neu;
     end;  {No OnlineErr}
   end; {Detect_FG_Type}


 procedure Show_FG_Typen;
  label 99;
  CONST start_zeile = 4;
        start_spalte =5;
        zeile_max    =22;
        spalte_offset=25;

  VAR answer : CHAR;
      Status : Boolean;
      ifc_total      : WORD;
      ifc_total_err  : WORD;
      ifb_online : ARRAY[0..255] OF BOOLEAN;
      ifb_adr    : Integer;
      zeile,spalte: BYTE;
      hex_str    : STRING[10];
      i,n        : WORD;
      RetAdr     : Byte;
      OnlineErr  : TOnlineErr;
      Ende       : Boolean;
      FG_Typ     : TFG_Typ;
      Firm_Vers  : Byte;     {Firmware Version}

  begin
    Zeile := Start_Zeile;
    Spalte:= Start_Spalte;
    Ifc_Total     := 0;
    Ifc_Total_Err := 0;

    Ini_Text_Win;
    FOR ifb_adr := 0 TO 255 DO ifb_online [Ifb_Adr] := False;

    FOR Ifb_Adr := 0 TO 255 DO
      Begin
       Detect_FG_Type (Ifb_Adr, FG_Typ, Firm_Vers);

 {if Ifb_Adr in [00..50] then  FG_Typ := Neu;}   {Testweise}
       If FG_Typ <> Offline then
         begin
            ifb_online [Ifb_Adr] := True;
            Set_Text_Win;
            GotoXY (spalte, zeile);
            write(hex_Byte(Ifb_Adr));
            TextColor(Brown);
            case FG_Typ of
             Alt : begin Write (' FG Alt ?        '); Write ('   ');     end;
             Neu : begin Write (' FG Neu Version: '); Write (Firm_Vers); end;
            end; {case}
            TextColor(Black);
            zeile := zeile + 1;
            IF (zeile > zeile_max )  THEN
             begin
               spalte := spalte + spalte_offset;
               if spalte > (80 - spalte_offset) then
                begin
                  Ini_Err_Win;
                  Write ('ERROR: Zuviele Fehler!!  Abbruch!! Weiter beliebige Taste!');
                  repeat until KeyEPressed;
                  Exit; {Zuviele Spalten}
                end;
                zeile  := start_zeile;
             end;
            ifc_total := ifc_total + 1;
          end {if noerr}
         else
          begin   {Online-Error!!}
            if OnlineErr = AdrErr then
             begin
               Ifc_Total_Err := Ifc_Total_Err + 1;
               Ini_Err_Win;
               Write ('ERROR: Antwort v. falscher IFK-Adr!  '); TextColor(Yellow+128);
               Write('Soll: ', Hex_Byte(ifb_adr),'[H]  Ist: ', Hex_Byte(RetAdr),'[H]');
               TextColor(Red); Write ('  [W]eiter [Q]uit');
               repeat
                 Ch := NewReadKey;
                 if Ch in ['q','Q'] then
                  begin
                   Ch := ' ';
                   Exit;
                  end;
               until Ch in ['w','W'];
             end; {OnlineErr = AdrErr}
          end;
    End; {FOR}

    Set_Text_Win;
    if  Ifc_Total_Err <> 0 then
     begin
       TextColor(Red);
       GotoXY (03,01);
       Write ('Es melden sich ['); TextColor (Yellow);  Write (ifc_total_err); TextColor(Red);
       Write('] IFK-Karten mit falschen IFC-Adressen!!!');
       TextColor(Black);
     end;

    Set_Text_Win;
    GotoXY (03,02);
    Write ('Es melden sich ['); TextColor (Yellow); Write (ifc_total); TextColor(Black);
    Write('] IFK-Karten "ONLINE": ');

    if ifc_total <> 0 then
     begin
       Ifb_Adr := -1;
       repeat
        Ifb_Adr := Ifb_Adr + 1;
        Ifc_Test_Nr := Ifb_Adr;
       until ifb_online [Ifb_Adr] or (Ifb_Adr > 255);
       Ini_Msg_Win;
       Write('Ende mit beliebiger Taste!!  ');
       repeat until KeyEPressed;
     end
    else
     begin
      Ini_Err_Win;
      Write ('Keine IFC Online !             Ende <CR> ');
      repeat until KeyEPressed;
      answer := NewReadKey;
      goto 99;
     end;
  99:
 end;  {Show_FG_Typen}



                      {Konstanten fÅr neuen Funktionsgenerator}
const
   Freq_Intern  = $7F;
   Freq_Extern  = $80;

   Freq_16      = 0;     {kHz}
   Freq_32      = 1;
   Freq_64      = 2;
   Freq_128     = 3;
   Freq_256     = 4;
   Freq_512     = 5;
   Freq_1024    = 6;
   Freq_2048    = 7;

   Stuetz_32768 = 0;
   Stuetz_16384 = 1;
   Stuetz_8192  = 2;
   Stuetz_4096  = 3;
   Stuetz_2048  = 4;
   Stuetz_1024  = 5;
   Stuetz_512   = 6;
   Stuetz_256   = 7;


 procedure Set_IntMask (Ifc: Byte; Intr_Mask: Word; VAR MilErr: TMilErr);
  begin
   Fct.B.Adr := Ifc;
   Fct.B.Fct := Fct_Set_IntMask;
   Mil.Wr (Intr_Mask, Fct, MilErr);
  end; { set_Dreq_mask }


 PROCEDURE Set_Sw4_Ampl (VAR Sw4: WORD; VAR Dreq_Time, StuetzPkt: LONGINT);
  var AddierFreq,Disp_AddierFreq : Integer;
      Disp_StuetzPunkt :  LongInt;
   begin
    Sw4 := 0;                    {Master}
    Sw4 := Sw4 and Freq_Intern;  {Freq Intern}
    AddierFreq := Freq_1024;     {2048}
    StuetzPkt:= Stuetz_8192;
    Sw4 := Sw4 or ((AddierFreq shl 3) + StuetzPkt);

    addierfreq  :=   1 shl (7-addierfreq);
    stuetzpkt := 256 shl (7-stuetzpkt);
    Dreq_Time  := (addierfreq * stuetzpkt div 20)+1;  {x 10 us}
   end;


 PROCEDURE Set_Sw4_Freq (VAR Sw4: WORD; VAR Dreq_Time, StuetzPkt: LONGINT);
  var AddierFreq,Disp_AddierFreq : Integer;
      Disp_StuetzPunkt :  LongInt;
   begin
    Sw4 := 0;                    {Master}
    Sw4 := Sw4 and Freq_Intern;  {Freq Intern}
    AddierFreq := Freq_1024;
    StuetzPkt:= Stuetz_4096;   {Stuetz_4096}
    Sw4 := Sw4 or ((AddierFreq shl 3) + StuetzPkt);

    addierfreq  :=   1 shl (7-addierfreq);
    StuetzPkt := 256 shl (7-StuetzPkt);
    Dreq_Time  := (AddierFreq * StuetzPkt div 20)+1;  {x 10 us}
   end;

 type TRunMode = (Init, Sync);

 function FG_Rampe (Ifc      : Byte;
                    RunMode  : TRunMode; {Start Rampe oder Synchr. auf DREQ}
                    Sw3_Delta: Integer;  {Addierwert}
                    SW3_Count: Integer;  {Anzahl Addierungen}
                    Drq_Time : Word      {Zeit zwischen zwei DREQ}
                   )         : Boolean;  {SW3 Timeout}

  var FG_Status: Word; I: LongInt; SW: Integer; Timeout: Boolean;
      Summand1: TSummand1;

  begin
   FG_Rampe  := True;                              {Default: alles ok}
   Fct.B.Adr := Ifc;
   I := 0;
   Set_IntMask (Ifc, Ifc_Irmask_Dreq, MilErr);     {Enable DREQ auf Ifc}
   Mil.Timer2_Wait (3);                            {MIL-TRansferzeit abwarten}

   if RunMode = Sync then          {Gleich Sw3 schreiben oder auf Dreq warten?}
    begin                          {Auf nÑchsten Dreq warten}
      SW := 0;                     {Bei Null oder Flattop: Sw3 erzwingt DREQ}
      Fct.B.Fct := Fct_Wr_Sw3;
      Mil.Wr(SW, Fct, MilErr);
      Mil.Timer2_Wait (4);         {MIL-Transfer abwarten, bis SW3 im FG ist}

      Mil.Timer2_Set (2*Drq_Time+3); {Timer2_starten: Zeit verdoppelt!! 10.3.97}
      repeat
        Timeout := Mil.Timeout2;
      until ((PORTW[Port_Stat] and Stat_Dta_Req)=Stat_Dta_Req) or Timeout;
      if Timeout then
        begin
         FG_Rampe:= False;
         Exit;               {Abbruch!!}
        end;
    end; {if RunMode = Sync}

                          {Starte Rampe durch Write SW3}
      Fct.B.Fct := Fct_Wr_Sw3;  {Rampe rauf/runter gemÑ· Vorzeichen Sw3_Delta}
      repeat
        Mil.Wr(Sw3_Delta, Fct, MilErr);
        Mil.Timer2_Wait (4);        {MIL-Transfer abwarten, bis SW3 im FG ist}
        Mil.Timer2_Set (Drq_Time + 3);    {max. warten bis DREQ kommen sollte}
        I := I+1;
        repeat
          Timeout := Mil.Timeout2;
        until ((PORTW[Port_Stat] and Stat_Dta_Req) = Stat_Dta_Req) or Timeout;
        if Timeout then
          begin
             FG_Rampe:= False;
             Exit;
          end;
       until I = SW3_Count;

    {Am Ende einer Rampe, egal ob auf oder ab: Sw3=0, damit FG weiter addiert}
    {Der jeweilige FG-Endwert bleibt dadurch erhalten}
    SW := 0;
    Fct.B.Fct := Fct_Wr_Sw3;
    Mil.Wr(SW, Fct, MilErr);
    Set_IntMask (Ifc, Ifc_Irmask_Dis, MilErr);   {Disable DREQ auf dieser Ifc}
   end; {FG_Rampe}


 const Z_Tast_Win = 20;
{xxx}
 procedure  Ini_Tast_Win;
  begin
   Window(03, Z_Tast_Win, 48, Z_Tast_Win+3);
   TextBackground(Green);
   TextColor(Yellow);
   GotoXY(01, 01); Write('F1: Sollw Max eingeben   F5: Time Top    [ms]');
   GotoXY(01, 02); Write('F2: Sollw Min eingeben   F6: Time Bottom [ms]');
   GotoXY(01, 03); Write('F3: Sollw fix +/- 5.0V   F7:                 ');
   GotoXY(01, 04); Write('F4: Sollw fix +/-10.0V   F8:                 ');
   TextColor(Black);
  end;

 procedure  Single_Rampe;
  label Start, 99;
  const
   F_Add_Amp    = 1.024;   {in Mhz. Vorsicht: Auch Set_Sw4_Ampl mit Ñndern!!}
   Anstieg_Amp  =   100;   {in ms: Anstieg- u. Abfall-Rampe Amplitude}

   Wait_Top_Def = 20;   {ms: Wartezeite Ampl - Freq}
   Wait_Bot_Def = 20;   {ms: Wartezeit Bottom = Minimalwert}

   Z_Base  = 3;              {Zeilen und Spalten fÅr Display-Darstellung}
   Z_Text  = Z_Base  + 2;
   Z_Amp   = Z_Text  + 3;
   Z_Freq  = Z_Amp   + 1;

   S_Nomen = 12;
   S_Adr   = S_Nomen +10;
   S_Min   = S_Adr   +15;
   S_Max   = S_Min   +20;

   Z_Sw3   = 8;             {nur Testwerte anzuzeigen}
   S_SwAmp = 10;
   S_SwFreq= S_SwAmp + 30;

   Life_Sign_X = 10;
   Life_Sign_Y = 3;
   Interpol_Yes= 0;
   Interpol_No = 1;

  var
   Adress         : Word;
   Sw1, Sw4, Sw5  : Word;
   Sw3            : Integer;
   Sw1_AmpMax     : Integer;
   Sw1_AmpMin     : Integer;
   Sw3_Delta_Ampl : Integer;
   SW3_Count_Ampl : Integer; { 10; }

   AddierFreq     : INTEGER;
   StuetzPunkt    : LONGINT;
   Dreq_Time_Real :  Real;

   Dreq_Time_Freq, Dreq_Time_Ampl :  LONGINT;
   Summand1, Istwert, Endwert: TSummand1;
   Pc_Stat          : TPcStat;
   Timeout          : BOOLEAN;
   Wr_Count         : LongInt;
   Mode_An, Mode_Ab : Boolean;
   FG_Stat          : Word;
   Ifc_Nr, RetAdr   : Byte;
   OnlineErr        : TOnlineErr;
   Index_Parm       : Byte;
   SW_real          : Real;
   Ramp_Err_Ampl    : LongInt;
   Prozent          : Integer;
   Prozent_Real     : Real;
   I                : Byte;
   Neustart         : Boolean;
   Wait_Top         : LongInt;
   Wait_Bot         : LongInt;
   Sollw            : TSw;
   Real_Zahl        : Real;
   Sw1_AmpMax_Real  : Real;
   Sw1_AmpMin_Real  : Real;
   User_Time        : Integer;

  begin
   Mil_Ask_Ifc;
   Ini_Text_Win;
   Ramp_Err_Ampl := 0;
   Wait_Top := Wait_Top_Def;  {Default-werte laden}
   Wait_Bot := Wait_Bot_Def;
   MagRampe.SwMax := 10.0;
   MagRampe.SwMin :=-10.0;
   Ini_Tast_Win;
   Set_Text_Win;
   GotoXY(03,Z_Tast_Win-3); TextColor(Brown);
   Write('Belegung der Funktionstasten: ');

{
   Ini_Msg_Win;
   Write ('Amplitude in ['); TextColor(red); Write ('P'); TextColor(Yellow);
   Write(']rozent vom Maximalwert bzw. [<CR> = 100%]: ');
   Ch := NewReadKey;
   if (Ch in ['p','P']) then
    begin
     if Read_Int (1, 100, Prozent) then
      begin
        Prozent_Real := abs (Prozent / 100);
        for I := 1 to 1 do
         begin
          MagRampe.SwMax :=  MagRampe.FScale_Real * (Prozent_Real);
        end;
      end;
    end;
}

 Start:
{
   Ini_Msg_Win;
   Write ('Rampen-Test '); TextColor( red + 128);
   Write('angehalten'); TextColor(Yellow); Write('!               Fortsetzen mit <CR>  oder Ende mit <X>:  ');
}
                  { Betriebswerte berechnen und anzeigen}
   {Integer Sollwert = (Sw_Max / SW-Fullscale) * Integer_Max}
        {Rd_Real_Sw := Round(Real_Zahl); = Real-Zahl in Integer umwandeln}
{  Summand1.Li := Round ((MagRampe.SwMax / MagRampe.FScale_Real) * MagRampe.FScale_Int);
   Sw1_AmpMax  := Summand1.r.hw;
   Summand1.Li := Round ((MagRampe.SwMin / MagRampe.FScale_Real) * MagRampe.FScale_Int);
   Sw1_AmpMin  := Summand1.r.hw;
}
{
   Summand1.Li := Round ((MagRampe.SwMax / MagRampe.FScale_Real) * MagRampe.FScale_Int);
}
   if MagRampe.SwMax > 9.999694825 then MagRampe.SwMax := 9.999694825;
   Sw1_AmpMax_Real:= (MagRampe.SwMax/305.1757813) * 1000000;
   Summand1.Li    := Round (Sw1_AmpMax_Real);  {Umwandlung in Interger}
   Sw1_AmpMax     := Summand1.r.lw;

   Sw1_AmpMin_Real:= (MagRampe.SwMin/305.1757813) * 1000000;
   Summand1.Li    := Round (Sw1_AmpMin_Real);  {Umwandlung in Interger}
   Sw1_AmpMin     := Summand1.r.lw;

                          {FunktionsGen vorbereiten}
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Reset;      {SW1+SW2: Dig. Ausgang clear Hi u. Lo = 0}
   Mil.WrFct (Fct, MilErr);

                   {Minimum Amplitude schreiben: Nur HiWord, Lw =0}
   Summand1.Li   := 0;
   Summand1.r.hw := Sw1_AmpMin;
   Fct.B.Fct     := Fct_Wr_Sw1;
   Mil.Wr (Summand1.r.hw, Fct, MilErr);

   Fct.B.Fct := Fct_Wr_Sw2;
   Mil.Wr(Summand1.r.lw, Fct, MilErr);

   SW5 := Interpol_Yes;
   SW5 := SW5 AND $FD;   {kein Sw3 shift}
   Fct.B.Fct := Fct_SW5;
   Mil.Wr(SW5, Fct, MilErr);

   Set_Sw4_Ampl (Sw4, Dreq_Time_Ampl, StuetzPunkt);
   Fct.B.Fct := Fct_Wr_Sw4;
   Mil.Wr (Sw4, Fct, MilErr);

                           {SW3 berechnen}
   SW_Real := Sw1_AmpMax_Real - (Sw1_AmpMin_Real);       {F = Frequenz in Mhz}
   SW_Real := ((Sw_Real * $7FFF) / (Anstieg_Amp * 1000.0)) * (1/F_Add_Amp); {Anstieg in ms}
   Summand1.Li   := Round (SW_Real);     {In Integer wandeln}
   Sw3_Delta_Ampl:= Summand1.r.lw;

                                {Anzahl der DREQ berechnen}
   SW3_Count_Ampl := round ((Anstieg_Amp) / (Dreq_Time_Ampl /100));  {Zeiten in ms}
   Dreq_Time_Real := Dreq_Time_Ampl /100;  TextColor(Brown);

   Set_Text_Win;                                          TextColor(Brown);
   GotoXY(S_SwAmp+11, Z_Sw3-5); Write ('[Volt]');
   GotoXY(S_SwAmp+19, Z_Sw3-5); Write ('[Hex]');
   GotoXY(S_SwAmp+0, Z_Sw3-4);  Write (' SW-Max: ');  TextColor(Black);  Write (MagRampe.SwMax:8:2,'   ');
                                                      TextColor(Blue);   Write (Hex_Word (Sw1_AmpMax));
                                                      TextColor(Brown);
   GotoXY(S_SwAmp+0, Z_Sw3-3);  Write (' SW-Min: ');  TextColor(Black);  Write (MagRampe.SwMin:8:2,'   ');
                                                      TextColor(Blue);   Write (Hex_Word (Sw1_AmpMin));
                                                      TextColor(Brown);

   GotoXY(S_SwAmp+40,Z_Sw3-4);  Write ('Time Top    [ms]: '); TextColor(Black);
                                Write (Wait_Top:5);     TextColor(Brown);
   GotoXY(S_SwAmp+40,Z_Sw3-3);  Write ('Time Bottom [ms]: '); TextColor(Black);
                                Write (Wait_Bot:5);     TextColor(Brown);

   GotoXY(S_SwAmp+4, Z_Sw3-1);  Write (' FG Amplitude: ');  TextColor(Black);
   GotoXY(S_SwAmp, Z_Sw3);      Write ('Anstieg   [ms]:    ',Anstieg_Amp:3);
   GotoXY(S_SwAmp, Z_Sw3+1);    Write ('Add-Freq [Mhz]:  ',  F_Add_Amp:5:3);
   GotoXY(S_SwAmp, Z_Sw3+2);    Write ('DRQ-Time  [ms]:  ',  dreq_time_Real: 5:2);
   GotoXY(S_SwAmp, Z_Sw3+3);    Write ('Anzahl DREQ   :    ',SW3_Count_Ampl:3);
   GotoXY(S_SwAmp, Z_Sw3+4);    Write ('SW3_Amp [Real]: ',   Sw_Real:6:0);
   GotoXY(S_SwAmp, Z_Sw3+5);    Write ('SW3_Amp [Int ]: ',  Sw3_Delta_Ampl:6);
   GotoXY(S_SwAmp, Z_Sw3+6);    Write ('SW3_Amp [Hex ]:   ',   Hex_Word(Sw3_Delta_Ampl));
{
   GotoXY(S_SwAmp+30, Z_Sw3+4); Write ('SW3_Amp [Hex ]: ',   Hex_Word(Sw3_Delta_Ampl));
}
(*{$IFDEF Test}*)
(*{$ENDIF}*)

   {Der Funktionsgenerator ist mit allen statischen Parametern versorgt}
   Mil.Reset;                                        {PC-Interface clearen}


   {PrÅfe, ob von Funktionsgen. schon vorzeitig DREQ vorliegt!}
   Set_IntMask (Ifc_Test_Nr, Ifc_Irmask_Dreq, MilErr);
   IF ((PORTW[Port_Stat] AND stat_dta_req)=stat_dta_req) THEN  {PrÅfe, ob bereits ohne SW3 ein Interrupt ansteht}
    BEGIN
     Ini_Err_Win;
     Write('ERROR: Intr DREQ liegt von Ampl-FG bereits ohne SW3 vor! Weiter: <Space> ');
     REPEAT UNTIL keypressed;
     Std_Msg;
     Set_Text_Win;
    END;
   Set_IntMask (Ifc_Test_Nr,  Ifc_Irmask_Dis, MilErr);
{

   Ini_Msg_Win;
   Write ('Rampenfahren mit ['); TextColor(Red); Write ('S'); TextColor(Yellow);
   Write(']tart beginnen oder Ende mit <CR>:  ');
   Ch := NewReadKey;

   if not (Ch in ['s','S']) then Exit;
   Ini_Msg_Win;
   Write ('Funktionsgen. Amplitude im '); TextColor(Red +128);
   Write('Dauertest'); TextColor(Yellow); Write('!    Stop mit <Space>,   Ende mit <X>: ');

   Ramp_Err_Ampl := 0;
}
{  Ini_Msg_Win;
   Write ('Funktionsgen. Ampl im '); TextColor(Red +128);
   Write('Dauertest'); TextColor(Yellow); Write('!    Stop mit <Space>,   Ende mit <X>: ');
}
   Cursor(False);
   Neustart := False;    {Solange User keine neuen Parameter eingibt}
   Ch := ' ';
   if Ch = ' ' then
    begin
      Ini_Msg_Win;
      Write ('Rampen-Test '); TextColor( red + 128);
      Write('angehalten'); TextColor(Yellow); Write('!               Fortsetzen mit <CR>  oder Ende mit <X>:  ');
      Ch := NewReadKey;
      if Ch in  ['x','X'] then Exit;
     if Ch = Taste_Return then
       begin
        Ini_Msg_Win;
        Write ('Funktionsgen. Amplitude im '); TextColor(Red +128);
        Write('Dauertest'); TextColor(Yellow); Write('!    Stop mit <Space>,   Ende mit <X>: ');
        Ch := '?';
       end;
    end; {if ch=' '}

   if Ch = #0 then                  {Sonder-Tasten Abfrage}
    begin
     Ch := NewReadKey;
     case ord (Ch) of
      Taste_F1 : begin
                   Sollw.Mode:= R;
                   Sollw.Max := 10.0;
                   if Ask_Sw_Break (Sollw) then
                    begin
                     MagRampe.SwMax := Sollw.Float;
                    end;
                   Neustart := True;
                 end;
      Taste_F2 : begin
                   Sollw.Mode:= R;
                   Sollw.Max := 10.0;
                   if Ask_Sw_Break (Sollw) then
                    begin
                     MagRampe.SwMin := Sollw.Float;
                    end;
                   Neustart       := True;
                 end;
      Taste_F3 : begin
                   MagRampe.SwMin:= -5.00;
                   MagRampe.SWMax:= +5.00;
                   Neustart := True;
                 end;
      Taste_F4 : begin
                   MagRampe.SwMin:= -10.00;
                   MagRampe.SWMax:= +10.00;
                   Neustart := True;
                 end;
      Taste_F5 : begin
                   if Read_Int (1, $7FFF, User_Time ) then
                    begin
                      Wait_Top := User_Time;
                    end;
                   Ini_Msg_Win; Write ('Bitte ein wenig Geduld: Timer lÑuft!');
                   Neustart := True;
                 end;
      Taste_F6 : begin
                   if Read_Int (1, $7FFF, User_Time ) then
                    begin
                      Wait_Bot := User_Time;
                    end;
                   Ini_Msg_Win; Write ('Bitte ein wenig Geduld: Timer lÑuft!');
                   Neustart := True;
                 end;
     end; {case}
    end;  {if ch=0}
   if Ch in  ['x','X'] then Exit;

 repeat
   {Rampe zum ersten Mal starten}
   if FG_Rampe (Ifc_Test_Nr, Init, +(Sw3_Delta_Ampl), SW3_Count_Ampl, Dreq_Time_Ampl)
   then Ramp_Err_Ampl  := Ramp_Err_Ampl  + 1;
   Mil.Timer2_Wait (Wait_Top*100);
   repeat
     Mil.Timer2_Wait (Wait_Top*100);
                {Ampl runter: aber synchronisiert mit DREQ}
     if FG_Rampe (Ifc_Test_Nr, Sync, -(Sw3_Delta_Ampl), SW3_Count_Ampl, Dreq_Time_Ampl)
     then Ramp_Err_Ampl  := Ramp_Err_Ampl  + 1; ;

                {Harte Minimum-SW-Vorgabe fÅr Amplitude}
     Mil.Timer2_Wait (Dreq_Time_Ampl);    {Vorsichtig warten!!}
     Summand1.Li := 0;
     Summand1.r.hw:= Sw1_AmpMin;
     Fct.B.Fct := Fct_Wr_Sw1;             {Stoppt FGEN}
     Mil.Wr (Summand1.r.hw, Fct, MilErr);
     Fct.B.Fct := Fct_Wr_Sw2;
     Mil.Wr (Summand1.r.lw, Fct, MilErr);

     Mil.Timer2_Wait (Wait_Bot*100);               {Warte bis zur nÑchsten Rampe}
     if KeyEPressed then Ch := NewReadKey;     {Abbruch nur wenn Rampen unten}
     if Ch = ' ' then
      begin
        Ini_Msg_Win;
        Write ('Rampen-Test '); TextColor( red + 128);
        Write('angehalten'); TextColor(Yellow); Write('!               Fortsetzen mit <CR>  oder Ende mit <X>:  ');
        Ch := NewReadKey;
        if Ch in  ['x','X'] then Exit
        else
         begin
          Ini_Msg_Win;
          Write ('Funktionsgen. Amplitude im '); TextColor(Red +128);
          Write('Dauertest'); TextColor(Yellow); Write('!    Stop mit <Space>,   Ende mit <X>: ');
          Ch := '?';
         end;
      end; {if ch=' '}

     if Ch = #0 then                  {Sonder-Tasten Abfrage}
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                     Sollw.Mode:= R;
                     Sollw.Max := 10.0;
                     if Ask_Sw_Break (Sollw) then
                      begin
                       MagRampe.SwMax := Sollw.Float;
                      end;
                     Neustart       := True;
                   end;
        Taste_F2 : begin
                     Sollw.Mode:= R;
                     Sollw.Max := 10.0;
                     if Ask_Sw_Break (Sollw) then
                      begin
                       MagRampe.SwMin := Sollw.Float;
                      end;
                     Neustart := True;
                   end;
        Taste_F3 : begin
                     MagRampe.SwMin:= -5.00;
                     MagRampe.SWMax:= +5.00;
                     Neustart := True;
                   end;
        Taste_F4 : begin
                     MagRampe.SwMin:= -10.00;
                     MagRampe.SWMax:= +10.00;
                     Neustart := True;
                   end;
        Taste_F5 : begin
                     if Read_Int (1, $7FFF, User_Time ) then
                      begin
                        Wait_Top := User_Time;
                      end;
                     Ini_Msg_Win; Write ('Bitte ein wenig Geduld: Timer lÑuft!');
                     Neustart := True;
                   end;
        Taste_F6 : begin
                     if Read_Int (1, $7FFF, User_Time ) then
                      begin
                        Wait_Bot := User_Time;
                      end;
                     Ini_Msg_Win; Write ('Bitte ein wenig Geduld: Timer lÑuft!');
                     Neustart := True;
                   end;
       end; {case}
      end;  {if ch=0}

     if Ch in  ['x','X'] then Exit;
     if Neustart then  begin Neustart := False;  goto Start; end; {Parameter neu berechnen}
     if FG_Rampe (Ifc_Test_Nr, Init, Sw3_Delta_Ampl, SW3_Count_Ampl, Dreq_Time_Ampl)
     then  Ramp_Err_Ampl  := Ramp_Err_Ampl  + 1;;
   until 1=2;
 until 1=2;
 {Runterfahren der Rampen nicht nîtig, weil Abbruch bereits bei Nullwerten!!}
 99:  Cursor(True);
end; {Single_Rampe}


begin                      { Hauptprogramm MIL-Ramp}
  Ifc_Test_Nr := 0;

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
     'm', 'M' : begin
                  Show_FG_Typen;
                end;
     'n', 'N' : begin
                  Single_Rampe;
                end;
     'o', 'O' : begin
                end;
     'p', 'P' : begin
                end;
     'q', 'Q' : begin
                end;
     'r', 'R' : begin
                end;
     's', 'S' : begin
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
end. {mil_fgen}

