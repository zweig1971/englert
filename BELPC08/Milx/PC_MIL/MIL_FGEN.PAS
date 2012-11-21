PROGRAM Mil_FGen;             {Funktionsgenerator}
{ Autor des Basis-Programmes Mil_BASE.PAS: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS

  Autor der Erweiterungen   :
  énderungen:
  12.09.96    Et        Erstellung


  Sollwert4: D7 : Frequenz      0=Intern, 1=externe Frequenz
             D6 : Master/Slave  0=Master, 1=Slave
             D5 :
             D4 :
             D3 :

  Im SIS und ESR: je 2 KavitÑten mit je einer IFK = 4 IFK
  Zwei benachbarte IFK z. B. Adr 4 u. 5 bilden ein Paar (Frequenz und Amplitude)

}
{$S-}
{$DEFINE Test}      {Test: Dummy-Daten aktivieren    NoTest: Arbeitsversion}
uses Crt, WinDos, Dos, Datech, Datech_1;    {spez. MIL-Routinen in Units Datech..}

const
 Head_Line =
      'Datentechnik                         MIL_FGEN   ' +
      '                    [27.02.1997]' +
      '                Test f. Funktionsgenerator [FG 380 505 u. 540]                 ';

 procedure menue_win;
  var answer: CHAR;
 begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;              {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}

  {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}
  GotoXY(5, 14);
  Writeln('       [M]<-- Zeige IFK u. Funktions-Gen-Typen am MIL-Bus                ');
  GotoXY(5, 15);
  Writeln('       [N]<-- SIS/ESR HF-KavitÑten Rampen-Test                ');
  GotoXY(5, 16);
  Writeln('       [O]<--  ');
  GotoXY(5, 17);
  Writeln('       [P]<-- ');
  GotoXY(5, 18);
  Writeln('       [Q]<--  ');
  GotoXY(5, 19);
  Writeln('       [R]<--  ');
  GotoXY(5, 20);
  Write  ('       [S]<--  ');
{
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
{
Bisherige Routinen f. alle Anwender gleich! Ab hier spezielle User-Routinen
}

const
 Fct_SW1 = $06;
 Fct_SW3 = $08;
 Fct_SW4 = $09;
 Fct_SW5 = $0A;     {nur fÅr neuen Funktionsgen}

 Fct_Status1  = $91;
 Fct_Status2  = $92;
 Fct_Status3  = $93;     {Dummy Code}

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

 THf_Parm  = record
               MilAdr : Byte;
               Nomen  : String[8];
               SwMin  : Real;
               SwMax  : Real;
               FScale_Real : Real;
               FScale_Int  : LongInt;
             end;

 THf_Acc     = record
                A : THf_Parm;
                F : THf_Parm;
               end;

 THf_Acc_Ary = array [1..2] of THf_Acc;

 const                  {Testparameter fÅr Rampentests festlegen}
  SIS : THf_Acc_Ary =
  (
   (A: (MilAdr: 132; Nomen: 'S02BE1A '; SwMin: 0.0; SWMax: 8.0; FScale_Real: 16.0; FScale_Int: $7FFF0000);
    F: (MilAdr: 133; Nomen: 'S02BE1FS'; SwMin: 0.8; SWMax: 5.4; FScale_Real: 12.5; FScale_Int: $7FFF0000)),

   (A: (MilAdr:  04; Nomen: 'S08BE2A '; SwMin: 0.0; SWMax: 8.0; FScale_Real: 16.0; FScale_Int: $7FFF0000);
    F: (MilAdr:  05; Nomen: 'S08BE2FS'; SwMin: 0.8; SWMax: 5.4; FScale_Real: 12.5; FScale_Int: $7FFF0000))
  );

  ESR : THf_Acc_Ary =
  (
   (A: (MilAdr: 132; Nomen: 'E02BE1A '; SwMin: 0.0; SWMax: 4.0; FScale_Real:  5.0; FScale_Int: $7FFF0000);
    F: (MilAdr: 133; Nomen: 'E02BE1FS'; SwMin: 0.8; SWMax: 5.4; FScale_Real: 12.5; FScale_Int: $7FFF0000)),

   (A: (MilAdr:  04; Nomen: 'E01BE2A '; SwMin: 0.0; SWMax: 8.0; FScale_Real:  5.0; FScale_Int: $7FFF0000);
    F: (MilAdr:  05; Nomen: 'E01BE2FS'; SwMin: 0.8; SWMax: 5.4; FScale_Real: 12.5; FScale_Int: $7FFF0000))
  );

var
  MilErr : TMilErr;
  Fct    : TFct;
  Ifc_Freq_Nr, Ifc_Ampl_Nr : Byte;  {Global fÅr SIS- u. ESR-HF}
  Acc_Mode    : (SIS_Acc, ESR_Acc);


 procedure Life_Sign_XY (Mode: TLife; X: Byte; Y: Byte; Speed: TSpeed);
  const
   Life_Time1 = 5000;
   Life_Time2 = 2000;

  var
   Life_Wait : LongInt;
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


procedure Displ_FG_Typen;
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
     end
    else
     begin
      Ini_Err_Win;
      Write ('Keine IFC Online ! Hex-Adresse eingeben <J> oder Ende <CR> ');
      repeat until KeyEPressed;
      answer := NewReadKey;
      if answer in ['j','J'] then Ifc_Test_Nr := Ask_Hex_Byte;
      goto 99;
     end;

    Ini_Msg_Win;
    Write ('Online IFC-Adr ['); TextColor(Red); Write (Hex_Byte(Ifc_Test_Nr)); TextColor(Yellow);
    Write (']  Åbernehmen mit <CR>, Auswahl ',chr($19),' ',chr($18),' oder Hex-Eingabe <J>: ');
    answer := NewReadKey;

    repeat
       if KeyEPressed then answer := NewReadKey;

       if answer in ['j','J'] then
         begin
           Ifc_Test_Nr := Ask_Hex_Byte;
           Ini_Msg_Win;
           Write ('Online IFC-Adr ['); TextColor(Red); Write (Hex_Byte(Ifc_Test_Nr)); TextColor(Yellow);
           Write (']  Åbernehmen mit <CR>, Auswahl ',chr($19),' ',chr($18),' oder Hex-Eingabe <J>: ');
           answer :=  ' ';
         end;

       if answer = #0 then
        begin
         answer := NewReadKey;
         case ord (answer) of
         Taste_Pfeil_Auf  : begin
                             Ifb_Adr := Ifc_Test_Nr;
                             repeat
                              Ifb_Adr := Ifb_Adr + 1;
                              if ifb_adr = 256 then ifb_Adr := 255;
                              if ifb_online [Ifb_Adr] then Ifc_Test_Nr := Ifb_Adr;
                             until ifb_online [Ifb_Adr] or (Ifb_Adr = 255);
                             Ini_Msg_Win;
                             Write ('Online IFC-Adr ['); TextColor(Red); Write (Hex_Byte(Ifc_Test_Nr)); TextColor(Yellow);
                             Write (']  Åbernehmen mit <CR>, Auswahl ',chr($19),' ',chr($18),' oder Hex-Eingabe <J>: ');
                            end;

          Taste_Pfeil_Ab  : begin
                             Ifb_Adr := Ifc_Test_Nr;
                             repeat
                              Ifb_Adr := Ifb_Adr - 1;
                              if Ifb_Adr = -1 then ifb_Adr := 0;
                              if ifb_online [Ifb_Adr] then Ifc_Test_Nr := Ifb_Adr;
                             until ifb_online [Ifb_Adr] or (Ifb_Adr = 0);
                             Ini_Msg_Win;
                             Write ('Online IFC-Adr ['); TextColor(Red); Write (Hex_Byte(Ifc_Test_Nr)); TextColor(Yellow);
                             Write (']  Åbernehmen mit <CR>, Auswahl ',chr($19),' ',chr($18),' oder Hex-Eingabe <J>: ');
                            end;
         end;  {Case}
     end;
    until answer = chr($0D);
  99:
 end;  {Displ_FG_Typen}


 procedure Show_FG_Typen; {Ohne öbernahme der IFK-Nr, weil zweifach Nummern fÅr SIS-HF}
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



 procedure FG_Type;       {Bestimme Type des Funktionsgen.}
  label 99;
  var
   Typ_Result: TFG_Typ;
   Firmware  : Byte;

 begin  {FG_Type}
  Show_FG_Typen;
  99:  Cursor(True);
 end; {FG_Type}


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
{xxx}

 PROCEDURE Set_Sw4_Ampl (VAR Sw4: WORD; VAR Dreq_Time, StuetzPunkt: LONGINT);
  var AddierFreq,Disp_AddierFreq : Integer;
      Disp_StuetzPunkt :  LongInt;

   begin
    Sw4 := 0;                    {Master}
    Sw4 := Sw4 and Freq_Intern;  {Freq Intern}
    AddierFreq := Freq_1024;     {2048}
    StuetzPunkt:= Stuetz_4096;
    Sw4 := Sw4 or ((AddierFreq shl 3) + StuetzPunkt);

    addierfreq  :=   1 shl (7-addierfreq);
    stuetzpunkt := 256 shl (7-stuetzpunkt);
    Dreq_Time  := (addierfreq * stuetzpunkt div 20)+1;  {x 10 us}
   end;


 PROCEDURE Set_Sw4_Freq (VAR Sw4: WORD; VAR Dreq_Time, StuetzPunkt: LONGINT);
  var AddierFreq,Disp_AddierFreq : Integer;
      Disp_StuetzPunkt :  LongInt;
      Dreq_Time_Real   :  Real;
   begin
    Sw4 := 0;                    {Master}
    Sw4 := Sw4 and Freq_Intern;  {Freq Intern}
    AddierFreq := Freq_1024;
    StuetzPunkt:= Stuetz_4096;
    Sw4 := Sw4 or ((AddierFreq shl 3) + StuetzPunkt);

    addierfreq  :=   1 shl (7-addierfreq);
    stuetzpunkt := 256 shl (7-stuetzpunkt);
    Dreq_Time  := (addierfreq * stuetzpunkt div 20)+1;  {x 10 us}
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
   Set_IntMask (Ifc, Ifc_Irmask_Dreq, MilErr);       {Enable DREQ auf Ifc}
   Mil.Timer2_Wait (3);                              {MIL-TRansferzeit abwarten}

   if RunMode = Sync then              {Gleich Sw3 schreiben oder auf Dreq warten?}
    begin                              {Auf nÑchsten Dreq warten}
{      Fct.B.Fct := Fct_Rd_FGStat1; }    {SW3-Timeout durch Status lesen lîschen}
{      Mil.Wr (FG_Status, Fct, MilErr);} {Status lesen lîscht Sw3-Timeout}

      SW := 0;                         {Bei Null oder Flattop: Sw3 erzwingt DREQ}
      Fct.B.Fct := Fct_Wr_Sw3;
      Mil.Wr(SW, Fct, MilErr);
      Mil.Timer2_Wait (4);        {MIL-Transfer abwarten, bis SW3 im FG ist}

      Mil.Timer2_Set (Drq_Time+2);       {timer2_starten }
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
        Mil.Timer2_Set (Drq_Time + 2);    {max. warten bis DREQ kommen sollte}
        I := I +1;
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


 procedure  Duo_Rampe;
  label 99;
  const
   F_Add_Amp  = 1.024;      {in Mhz. Vorsicht: Auch Set_Sw4_Ampl mit Ñndern!!}
   F_Add_Freq = 1.024;      {in Mhz. Vorsicht: Auch Set_Sw4_Freq mit Ñndern!!}
   Anstieg_Amp  = 40;   {in ms: Anstiegszeit Rampe Amplitude}
   Anstieg_Freq = 100;  {in ms: Anstiegszeit Rampe frequenz }

   Z_Base  = 3;
   Z_Text  = Z_Base  + 2;
   Z_Amp   = Z_Text  + 3;
   Z_Freq  = Z_Amp   + 1;

   S_Nomen = 12;
   S_Adr   = S_Nomen +10;
   S_Min   = S_Adr   +15;
   S_Max   = S_Min   +20;

   Z_Sw3   = 15;             {nur Testwerte anzuzeigen}
   S_SwAmp = 10;
   S_SwFreq= S_SwAmp + 30;

   Life_Sign_X = 10;
   Life_Sign_Y = 3;
   Interpol_Yes= 0;
   Interpol_No = 1;

   SW3_Count_Ampl  = 10;
   SW3_Count_Freq  = 25;

  var
   Adress                   : Word;
   Sw1, Sw4, Sw5            : Word;
   Sw3                      : Integer;
   Sw1_AmpMax, Sw1_FreqMax  : Integer;
   Sw1_AmpMin, Sw1_FreqMin  : Integer;
   Sw3_Delta_Ampl, Sw3_Delta_Freq : Integer;

   AddierFreq               : INTEGER;
   StuetzPunkt              : LONGINT;
   Dreq_Time_Real           :  Real;

   Dreq_Time_Freq, Dreq_Time_Ampl :  LONGINT;
   Summand1, Istwert, Endwert: TSummand1;
   Pc_Stat                  : TPcStat;
   Timeout                  : BOOLEAN;
   Wr_Count                 : LongInt;
   Mode_An, Mode_Ab         : Boolean;
   FG_Stat                  : Word;
   Ifc_Nr, RetAdr           : Byte;
   OnlineErr                : TOnlineErr;
   Ifc_Paar1, Ifc_Paar2     : Boolean;
   Ifc_Kav1A, Ifc_Kav1F     : Byte;
   Ifc_Kav2A, Ifc_Kav2F     : Byte;
   Index_Parm               : Byte;
   SW_real                  : Real;

  begin
   Ini_Text_Win;
   Ini_Msg_Win;
   Write ('An welchem Beschleuniger testen?  [');  TextColor(Red); Write('E'); TextColor(Yellow);
   Write(']SR oder ['); TextColor(Red); Write('S');TextColor(Yellow);
   Write(']IS bzw. <CR>=SIS:  ');
   Ch := NewReadKey;
   if Ch in ['e', 'E'] then Acc_Mode := ESR_Acc else Acc_Mode := SIS_Acc;

   Ifc_Paar1  := False;              {Welches IFC-Paar ist vorhanden?}
   Ifc_Paar2  := False;
   Index_Parm := 0;                  {Index fÅr Parameter-Array }
   if Acc_Mode = SIS_Acc then
    begin
      Ifc_Kav1A :=  SIS[1].A.MilAdr;
      Ifc_Kav1F :=  SIS[1].F.MilAdr;
      Ifc_Kav2A :=  SIS[2].F.MilAdr;
      Ifc_Kav2F :=  SIS[2].F.MilAdr;
    end
   else
    begin
      Ifc_Kav1A :=  ESR[1].A.MilAdr;
      Ifc_Kav1F :=  ESR[1].F.MilAdr;
      Ifc_Kav2A :=  ESR[2].F.MilAdr;
      Ifc_Kav2F :=  ESR[2].F.MilAdr;
    end;

        {Stelle fest, ob Åberhaupt zwei zusammengehîrige IFK vorhanden sind}
   Ifc_Nr := Ifc_Kav1A ;
   Mil.Ifc_Online (Ifc_Nr, RetAdr, OnlineErr);        {1. IFK-Paar vorhanden?}
   if OnlineErr = NoErr then
     begin                                              {1. Karte vorhanden}
       Ifc_Nr := Ifc_Kav1F ;
       Mil.Ifc_Online (Ifc_Nr, RetAdr, OnlineErr);
       if OnlineErr = NoErr then Ifc_Paar1 := True;     {2. Karte vorhanden}
     end
   else
     begin
       Ifc_Nr := Ifc_Kav2A ;                        {2. IFK-Paar vorhanden?}
       Mil.Ifc_Online (Ifc_Nr, RetAdr, OnlineErr);
       if OnlineErr = NoErr then
         begin                                            {1. Karte vorhanden}
           Ifc_Nr := Ifc_Kav2F ;
           Mil.Ifc_Online (Ifc_Nr, RetAdr, OnlineErr);
           if OnlineErr = NoErr then Ifc_Paar2 := True;   {2. Karte vorhanden}
         end;
     end;

{$IFDEF Test}
   Ifc_Paar1 := True;
{$ENDIF}

   if not(Ifc_Paar1) and not(Ifc_Paar2) then   {Test nicht mîglich}
     begin
      Ini_Err_Win;
      Write ('ERROR: Am MIL-BUS '); TextColor(Yellow); Write('keine');
      TextColor(Red); Write(' zusammengehîrigen IFK-Paare!');
      Write ('             Weiter <');
      TextColor(Yellow); Write ('CR'); TextColor (red); Write ('>');
      Ch := NewReadKey;
      Exit;                {Abort}
     end;

   if Ifc_Paar1 and Ifc_Paar2 then
    begin
      Ini_Err_Win;
      Write ('Am MIL-BUS zwei IFK-Paare!');
      Write (' Nur Adr[Hex]: ', Hex_Byte (Ifc_Kav1A ), ' u. ');
      Write (Hex_Byte (Ifc_Kav1F ),' akzeptiert.   Weiter <');
      TextColor(Yellow); Write ('<CR'); TextColor (red); Write ('>');
      Ch := NewReadKey;
      Ifc_Freq_Nr := Ifc_Kav1A ;
      Ifc_Ampl_Nr := Ifc_Kav1F ;
      Index_Parm := 1;
    end
   else
    begin
      if Ifc_Paar1 then
       begin
         Ifc_Ampl_Nr := Ifc_Kav1A ;
         Ifc_Freq_Nr := Ifc_Kav1F ;
         Index_Parm  := 1;
       end
      else
       begin
         Ifc_Ampl_Nr := Ifc_Kav2A ;
         Ifc_Freq_Nr := Ifc_Kav2F ;
         Index_Parm  := 2;
       end;
    end;

   Ini_Msg_Win;
   Std_Msg;
   Set_Text_Win;
{$IFDEF Test}
   GotoXY(27, Z_Base-2); TextColor(Yellow + 128);
   Write ('Test-Version mit Dummy-Daten!!');
   Ifc_Ampl_Nr := $AA;
   Ifc_Freq_Nr := $11;
{$ENDIF}

   TextColor(Brown);
   GotoXY(25, Z_Base); Write ('Rampe fÅr Beschleuniger: '); TextColor(Yellow);
   if Acc_Mode = SIS_Acc then Write ('SIS') else Write ('ESR');

   TextColor(Brown);
   GotoXY(S_Nomen, Z_Text); Write('NOMEN-');
   GotoXY(S_Adr+2, Z_Text); Write('MIL-ADR');
   GotoXY(S_Min+4, Z_Text); Write('SW-MIN');
   GotoXY(S_Max+4, Z_Text); Write('SW-MAX');

   GotoXY(S_Nomen, Z_Text+1); Write('KLATUR');
   GotoXY(S_Adr,   Z_Text+1); Write('[Dez] [Hex]');
   GotoXY(S_Min,   Z_Text+1); Write('[Einh.]  [Dez]');
   GotoXY(S_Max,   Z_Text+1); Write('[Einh.]  [Dez]');

   GotoXY(02,      Z_Amp );  Write('AMPL ->');
   GotoXY(02,      Z_Freq ); Write('FREQ ->');
   GotoXY(S_Max+17,Z_Amp );  Write('[kVolt]');
   GotoXY(S_Max+17,Z_Freq ); Write('[MHz]  ');
   TextColor(Black);

   GotoXY(S_Nomen-1, Z_Amp ); if Acc_Mode = SIS_Acc then Write(SIS[Index_Parm].A.Nomen) else  Write(ESR[Index_Parm].A.Nomen);
   GotoXY(S_Nomen-1, Z_Freq); if Acc_Mode = SIS_Acc then Write(SIS[Index_Parm].F.Nomen) else  Write(ESR[Index_Parm].F.Nomen);

   GotoXY(S_Adr+1, Z_Amp );  Write(Ifc_Ampl_Nr:3);
   GotoXY(S_Adr+1, Z_Freq);  Write(Ifc_Freq_Nr:3);
   GotoXY(S_Adr+7, Z_Amp );  Write(Hex_Byte(Ifc_Ampl_Nr));
   GotoXY(S_Adr+7, Z_Freq);  Write(Hex_Byte(Ifc_Freq_Nr));

   GotoXY(S_Min,   Z_Amp );
     if Acc_Mode = SIS_Acc then Write(SIS[Index_Parm].A.SwMin:5:2) else  Write(ESR[Index_Parm].A.SwMin:5:2);
   GotoXY(S_Min,   Z_Freq);
     if Acc_Mode = SIS_Acc then Write(SIS[Index_Parm].F.SwMin:5:2) else  Write(ESR[Index_Parm].F.SwMin:5:2);

   GotoXY(S_Max,   Z_Amp );
     if Acc_Mode = SIS_Acc then Write(SIS[Index_Parm].A.SwMax:5:2) else  Write(ESR[Index_Parm].A.SwMax:5:2);
   GotoXY(S_Max,   Z_Freq);
     if Acc_Mode = SIS_Acc then Write(SIS[Index_Parm].F.SwMax:5:2) else  Write(ESR[Index_Parm].F.SwMax:5:2);


                    { Betriebswerte berechnen und anzeigen}
     {Integer Sollwert = (Sw_Max / SW-Fullscale) * Integer_Max}
   if Acc_Mode = SIS_Acc then    {Rd_Real_Sw := Round(Real_Zahl); = Real-Zahl in Integer umwandeln}
    begin        {SIS}
     Summand1.Li := Round ((SIS[Index_Parm].A.SwMax / SIS[Index_Parm].A.FScale_Real) * SIS[Index_Parm].A.FScale_Int);
     Sw1_AmpMax  := Summand1.r.hw;
     Summand1.Li := Round ((SIS[Index_Parm].A.SwMin / SIS[Index_Parm].A.FScale_Real) * SIS[Index_Parm].A.FScale_Int);
     Sw1_AmpMin  := Summand1.r.hw;
     Summand1.Li := Round ((SIS[Index_Parm].F.SwMax / SIS[Index_Parm].F.FScale_Real) * SIS[Index_Parm].F.FScale_Int);
     Sw1_FreqMax := Summand1.r.hw;
     Summand1.Li := Round ((SIS[Index_Parm].F.SwMin / SIS[Index_Parm].F.FScale_Real) * SIS[Index_Parm].F.FScale_Int);
     Sw1_FreqMin := Summand1.r.hw;
    end
   else
    begin        {ESR}
     Summand1.Li := Round ((ESR[Index_Parm].A.SwMax / ESR[Index_Parm].A.FScale_Real) * ESR[Index_Parm].A.FScale_Int);
     Sw1_AmpMax  := Summand1.r.hw;
     Summand1.Li := Round ((ESR[Index_Parm].A.SwMin / ESR[Index_Parm].A.FScale_Real) * ESR[Index_Parm].A.FScale_Int);
     Sw1_AmpMin  := Summand1.r.hw;
     Summand1.Li := Round ((ESR[Index_Parm].F.SwMax / ESR[Index_Parm].F.FScale_Real) * ESR[Index_Parm].F.FScale_Int);
     Sw1_FreqMax := Summand1.r.hw;
     Summand1.Li := Round ((ESR[Index_Parm].F.SwMin / ESR[Index_Parm].F.FScale_Real) * ESR[Index_Parm].F.FScale_Int);
     Sw1_FreqMin := Summand1.r.hw;
    end;

   GotoXY(S_Min+9, Z_Amp );  Write (Sw1_AmpMin );   {Anzeige als Dezimalwert}
   GotoXY(S_Min+9, Z_Freq);  Write (Sw1_FreqMin);

   GotoXY(S_Max+9, Z_Amp );  Write (Sw1_AmpMax );
   GotoXY(S_Max+9, Z_Freq);  Write (Sw1_FreqMax);

                          {FunktionsGen Amplitude vorbereiten}
   Fct.B.Adr := Ifc_Ampl_Nr ;
   Fct.B.Fct := Fct_Reset;       {SW1+SW2: Dig. Ausgang clear}
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

                               {SW3 fÅr Amplitude berechnen}
   SW_Real := Sw1_AmpMax - Sw1_AmpMin;                   {F = Frequenz in Mhz}
   SW_Real := ((Sw_Real * $7FFF) / (Anstieg_Amp * 1000.0)) * (1/F_Add_Amp); {Anstieg in ms}
   Summand1.Li:= round (SW_Real);
   Sw3_Delta_Ampl:= Summand1.r.lw;

{$IFDEF Test}
   Dreq_Time_Real := Dreq_Time_Ampl /100;  TextColor(Brown);
   GotoXY(S_SwAmp+4, Z_Sw3-1); Write (' FG Amplitude: ');  TextColor(Black);
   GotoXY(S_SwAmp, Z_Sw3);     Write ('Anstieg   [ms]:    ',  Anstieg_Amp:3);
   GotoXY(S_SwAmp, Z_Sw3+1);   Write ('Add-Freq [Mhz]:  ', F_Add_Amp:5:3);
   GotoXY(S_SwAmp, Z_Sw3+2);   Write ('DRQ-Time  [ms]: ',  dreq_time_Real: 5:2);
   GotoXY(S_SwAmp, Z_Sw3+3);   Write ('SW3_Amp [Real]: ',  Sw_real:6:0);
   GotoXY(S_SwAmp, Z_Sw3+4);   Write ('SW3_Amp [Int ]:  ', Sw3_Delta_Ampl);
{$ENDIF}

                          {Testparamter fÅr Freq-Rampe festlegen}
   Fct.B.Adr := Ifc_Freq_Nr ;
   Fct.B.Fct := Fct_Reset;       {SW1+SW2: Dig. Ausgang clear}
   Mil.WrFct (Fct, MilErr);

                  {Minimum Amplitude schreiben: Nur HiWord, Lw =0}
   Summand1.Li   := 0;
   Summand1.r.hw := Sw1_FreqMin;
   Fct.B.Fct     := Fct_Wr_Sw1;
   Mil.Wr (Summand1.r.hw, Fct, MilErr);
   Fct.B.Fct := Fct_Wr_Sw2;
   Mil.Wr(Summand1.r.lw, Fct, MilErr);

   SW5 := Interpol_Yes;
   SW5 := SW5 AND $FD;   {kein Sw3 shift}
   Fct.B.Fct := Fct_SW5;
   Mil.Wr(SW5, Fct, MilErr);

   Set_Sw4_Ampl (Sw4, Dreq_Time_Freq, StuetzPunkt);
   Fct.B.Fct := Fct_Wr_Sw4;
   Mil.Wr (Sw4, Fct, MilErr);

                               {SW3 fÅr Frequnz berechnen}
   SW_Real := Sw1_FreqMax - Sw1_FreqMin;              {F = Frequenz in Mhz}
   SW_Real := ((Sw_Real * $7FFF) / (Anstieg_Freq * 1000.0)) * (1/F_Add_Freq); {Anstieg in ms}
   Summand1.Li:= round (SW_Real);
   Sw3_Delta_Freq:= Summand1.r.lw;

{$IFDEF Test}
   Dreq_Time_Real := Dreq_Time_Freq /100;  TextColor(Brown);
   GotoXY(S_SwFreq+4, Z_Sw3-1); Write (' FG Frequenz: ');  TextColor(Black);
   GotoXY(S_SwFreq, Z_Sw3);     Write ('Anstieg   [ms]:    ',  Anstieg_Freq:3);
   GotoXY(S_SwFreq, Z_Sw3+1);   Write ('Add-Freq [Mhz]:  ', F_Add_Freq:5:3);
   GotoXY(S_SwFreq, Z_Sw3+2);   Write ('DRQ-Time  [ms]: ',  dreq_time_Real: 5:2);
   GotoXY(S_SwFreq, Z_Sw3+3);   Write ('SW3_Freq [Real]: ',  Sw_real:6:0);
   GotoXY(S_Swfreq, Z_Sw3+4);   Write ('SW3_Freq [Int ]:  ', Sw3_Delta_Freq);
{$ENDIF}

   {Die Funktionsgeneratoren sind mit allen statischen Parametern versorgt}
   Mil.Reset;                                        {PC-Interface clearen}

   {PrÅfe, ob von Funktionsgen. schon vorzeitig DREQ vorliegt!}
   Set_IntMask (Ifc_Freq_Nr, Ifc_Irmask_Dreq, MilErr);
   IF ((PORTW[Port_Stat] AND stat_dta_req)=stat_dta_req) THEN  {PrÅfe, ob bereits ohne SW3 ein Interrupt ansteht}
    BEGIN
     Ini_Err_Win;
     Write('ERROR: Intr DREQ liegt von FREQ-FG bereits ohne SW3 vor! Weiter: <Space> ');
     REPEAT UNTIL keypressed;
     Std_Msg;
     Set_Text_Win;
    END;
   Set_IntMask (Ifc_Freq_Nr,  Ifc_Irmask_Dis, MilErr);


   {PrÅfe, ob von Funktionsgen. schon vorzeitig DREQ vorliegt!}
   Set_IntMask (Ifc_Ampl_Nr, Ifc_Irmask_Dreq, MilErr);
   IF ((PORTW[Port_Stat] AND stat_dta_req)=stat_dta_req) THEN  {PrÅfe, ob bereits ohne SW3 ein Interrupt ansteht}
    BEGIN
     Ini_Err_Win;
     Write('ERROR: Intr DREQ liegt von Ampl-FG bereits ohne SW3 vor! Weiter: <Space> ');
     REPEAT UNTIL keypressed;
     Std_Msg;
     Set_Text_Win;
    END;
   Set_IntMask (Ifc_Ampl_Nr,  Ifc_Irmask_Dis, MilErr);


   Ini_Msg_Win;
   Write ('Start mit <CR>!! ');
   repeat until KeyEPressed;
   Ch := NewReadKey;
   Ini_Msg_Win;
   Std_Msg;
   Cursor(False);

                     {Beide Rampen zum ersten Mal starten}
   if FG_Rampe (Ifc_Ampl_Nr, Init, +Sw3_Delta_Ampl, SW3_Count_Ampl, Dreq_Time_Ampl)
   then  ;

   Mil.Timer2_Wait (500);             {Wartezeit bis zur Freq.}
   if FG_Rampe (Ifc_Freq_Nr, Init, +Sw3_Delta_Freq, SW3_Count_freq,Dreq_Time_Freq)
   then  ;

   repeat
     Mil.Timer2_Wait (1000);
     {Ampl runter: aber synchronisiert mit DREQ}
     if FG_Rampe (Ifc_Ampl_Nr, Sync, -(Sw3_Delta_Ampl), SW3_Count_Ampl, Dreq_Time_Ampl)
     then  ;

     {Harte Minimum-SW-Vorgabe}
     Mil.Timer2_Wait (Dreq_Time_Ampl);   {Vorsichtig warten!!}
     Fct.B.Adr   := Ifc_Ampl_Nr;
     Summand1.Li := 0;
     Summand1.r.hw:= Sw1_AmpMin;
     Fct.B.Fct := Fct_Wr_Sw1;            {Stop FGEN}
     Mil.Wr (Summand1.r.hw, Fct, MilErr);
     Fct.B.Fct := Fct_Wr_Sw2;
     Mil.Wr(Summand1.r.lw, Fct, MilErr);

     Mil.Timer2_Wait (500);
     {Freq runter: aber synchronisiert mit DREQ}
     if FG_Rampe (Ifc_Freq_Nr, Sync, -(Sw3_Delta_Freq), SW3_Count_freq,Dreq_Time_Freq)
     then  ;
       {Harte Minimum-SW-Vorgabe}
       Mil.Timer2_Wait (Dreq_Time_Freq);   {Vorsichtig warten!!}
       Fct.B.Adr    := Ifc_Freq_Nr;
       Summand1.Li  := 0;
       Summand1.r.hw:= Sw1_FreqMin;
       Fct.B.Fct := Fct_Wr_Sw1;
       Mil.Wr (Summand1.r.hw, Fct, MilErr);
       Fct.B.Fct := Fct_Wr_Sw2;
       Mil.Wr(Summand1.r.lw, Fct, MilErr);

     Mil.Timer2_Wait (6000);                   {Wartezeit bis nÑchste Sequenz}
   if FG_Rampe (Ifc_Ampl_Nr, Init, Sw3_Delta_Ampl, SW3_Count_Ampl,Dreq_Time_Ampl)
   then  ;
   Mil.Timer2_Wait (500);                            {Wartezeit bis zur Freq.}
   if FG_Rampe (Ifc_Freq_Nr, Init, Sw3_Delta_Freq, SW3_Count_freq,Dreq_Time_Freq)
   then  ;

   if KeyEPressed then Ch := NewReadKey;
  until Ch in ['x','X'];
  99:  Cursor(True);
 end; {Duo_Freq_Ampl;}


begin                      { Hauptprogramm MIL-FGen }
  Ifc_Test_Nr := 0;
  Ifc_Freq_Nr := 0;
  Ifc_Ampl_Nr := 0;

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
     'm', 'M' : begin
                 FG_Type;
                end;
     'n', 'N' : begin
                 Duo_Rampe;
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


 procedure FG_Rampe_Fix (Speed: TSpeed);
  label 99;
  const
   Sw1_Slow = $1000;     {Frequenz}
   Sw3_Slow = $1000;     {Anfangsbedingung}
   Sw4_Slow =   $30;     {Steigung}
   Sw1_Fast = $4000;     {Frequenz}
   Sw3_Fast = $4000;     {Anfangsbedingung}
   Sw4_Fast =   $38;     {Steigung}

   Life_Sign_X = 10;
   Life_Sign_Y = 4;
  var
   Adress : Word;
   Sw1, Sw3, Sw4 : Word;

  procedure Start_Rampe;
   begin
     Fct.B.Adr := Ifc_Test_Nr;

     Fct.B.Fct := Fct_Reset;
     Mil.WrFct (Fct, MilErr);

     Fct.B.Fct := Fct_SW4;
     Mil.Wr (Sw4, Fct, MilErr);

     Fct.B.Fct := Fct_SW1;
     Mil.Wr (Sw1, Fct, MilErr);

     Fct.B.Fct := Fct_SW3;
     Mil.Wr (Sw3, Fct, MilErr);
   end;

  procedure Stop_Rampe;
   begin
     Fct.B.Adr := Ifc_Test_Nr;
     Fct.B.Fct := Fct_Reset;
     Mil.WrFct (Fct, MilErr);
   end;


  begin
   Single_Step   := True;
   Ini_Text_Win;
   Fct.B.Adr := Ifc_Test_Nr;
   GotoXY(10,02); write('----- Einfacher Rampentest  -----');

   case Speed of
    Slow : begin
             Sw1:= Sw1_Slow;
             Sw3:= Sw3_Slow;
             Sw4:= Sw4_Slow;
           end;
    Fast : begin
             Sw1:= Sw1_Fast;
             Sw3:= Sw3_Fast;
             Sw4:= Sw4_Fast;
           end;
   end;  {case}

   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;

   repeat
    if Ch = ' ' then
     begin
      Std_Msg;
      Single_Step := True;
      Start_Rampe;
      Life_Sign_XY (Norm, Life_Sign_X, Life_Sign_Y, Fast);

      {Stop Rampe nach einmal rauf/runter fahren}
      repeat until KeyEPressed;
      Ch := NewReadKey;
     end;

    if Ch = #13 then Single_Step := False;

    if not Single_Step then
     begin
      Life_Sign_XY (Norm, Life_Sign_X, Life_Sign_Y, Fast);
      Start_Rampe;
      {ohne Stop}
     end;

    if Ch = #0 then
     begin
      Ch := NewReadKey;
      case ord (Ch) of
      Taste_F10 : begin
                    Slow_Key;
                    if Ask_Hex_Break (Adress, Byt) then
                      begin
                       Ifc_Test_Nr := Adress;
                       Std_Msg;
                      end;
                  end; {Taste_F10}
      Taste_F12: begin
                 end; {Taste_F12}
     end;  {Case}
    end;
   if KeyEPressed then Ch := NewReadKey;
  until Ch in ['x','X'];
  99:  Cursor(True);
       Stop_Rampe;
 end; {FG_Rampe_Fix}


 PROCEDURE Set_Sw4_Et1 (VAR Sw4: WORD; VAR Dreq_Time, StuetzPunkt: LONGINT);
  var AddierFreq,Disp_AddierFreq : Integer;
      Disp_StuetzPunkt :  LongInt;
      Dreq_Time_Real   :  Real;
   begin
    Sw4 := 0;                    {Master}
    Sw4 := Sw4 and Freq_Intern;  {Freq Intern}
    AddierFreq := Freq_1024;
    StuetzPunkt:= Stuetz_8192;
    Sw4 := Sw4 or ((AddierFreq shl 3) + StuetzPunkt);

    addierfreq  :=   1 shl (7-addierfreq);
    stuetzpunkt := 256 shl (7-stuetzpunkt);
    Dreq_Time  := (addierfreq * stuetzpunkt div 20)+1;  {x 10 us}
     Dreq_Time_Real  := Dreq_Time /100;
    GotoXY(10,04+0);  writeln ('Data Request Time [ms]: ', dreq_time_Real: 5:2);
   end;

 procedure FG_Rampe_HF1;
  label 99;
  const
   Life_Sign_X = 10;
   Life_Sign_Y = 3;
   Interpol_Yes= 0;
   Interpol_No = 1;
   Sw3_Delta   = 20000;

  var
   Adress                : Word;
   Sw1, Sw4, Sw5         : Word;
   Sw3, Sw3_Aktuell       : Integer;
   AddierFreq            : INTEGER;
   Dreq_Time, StuetzPunkt: LONGINT;
   Summand1, Istwert, Endwert: TSummand1;
   Pc_Stat               : TPcStat;
   Timeout               : BOOLEAN;
   Wr_Count              : LongInt;
   Mode_An, Mode_Ab      : Boolean;


  begin
   Mil_Ask_Ifc;
   Ini_Text_Win;
   Ini_Msg_Win;
   Std_Msg;
   Set_Text_Win;
   Mode_An := False;
   Mode_Ab := False;

   Fct.B.Adr := Ifc_Test_Nr;
   GotoXY(10,02); write('----- Einfacher Rampentest fÅr HF -----');

                          {Testparamter festlegen}
   Summand1.Li := 0;     {SW1+SW2}
   Set_Sw4_Et1 (Sw4, Dreq_Time, StuetzPunkt);

   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Reset;
   Mil.WrFct (Fct, MilErr);

   Mil.Timer2_Wait (10);
   Fct.B.Fct := Fct_Wr_Sw4;
   Mil.Wr (Sw4, Fct, MilErr);

   Fct.B.Fct := Fct_Wr_Sw1;
   Mil.Wr (Summand1.r.hw, Fct, MilErr);

   Fct.B.Fct := Fct_Wr_Sw2;
   Mil.Wr(Summand1.r.lw, Fct, MilErr);

   SW5 := 1 ;            {nicht interpol}
   SW5 := SW5 AND $FD;   {kein Sw3 shift}
   Fct.B.Fct := Fct_SW3;
   Mil.Wr(SW5, Fct, MilErr);

   {Der Funktionsgenerator ist nun mit allen statischen Parametern versorgt}
   Mil.Reset;                                 {PC-Interface clearen}
   Set_Intr_mask (ifc_irmask_dreq, MilErr);
   IF ((PORTW[Port_Stat] AND stat_dta_req)=stat_dta_req) THEN  {PrÅfe, ob bereits ohne SW3 ein Interrupt ansteht}
    BEGIN
     Ini_Err_Win;
     Write('ERROR: Intr DREQ liegt bereits ohne SW3 vor! Weiter: <Space> ');
     REPEAT UNTIL keypressed;
     Std_Msg;
     Set_Text_Win;
    END;

   Ini_Msg_Win;
   Write ('Start mit <CR>!! ');
   repeat until KeyEPressed;
   Ch := NewReadKey;
   Ini_Msg_Win;
   Std_Msg;

   Cursor(False);
   Single_Step := False;
   Wr_Count := 0;
   Fct.B.Fct := Fct_Wr_Sw3;

   repeat{    if Ch = #13 then Single_Step := False; }
      Sw3 := Sw3_Delta;
      repeat
         Mil.Wr(Sw3, Fct, MilErr);
         Wr_Count := Wr_Count + 1;
         Mil.Timer2_Set (Dreq_Time+2); { timer2_starten }
         repeat
           Timeout := Mil.Timeout2;
         until ((PORTW[Port_Stat] and Stat_Dta_Req)=Stat_Dta_Req) or Timeout;
          {PrÅfe, ob bereits ohne SW3 ein Interrupt ansteht}
      until Wr_Count =10;

      Sw3 := 0;
      repeat
         Mil.Wr(Sw3, Fct, MilErr);
         Wr_Count := Wr_Count + 1;
         Mil.Timer2_Set (Dreq_Time+2); { timer2_starten }
         repeat
           Timeout := Mil.Timeout2;
         until ((PORTW[Port_Stat] and Stat_Dta_Req)=Stat_Dta_Req) or Timeout;
          {PrÅfe, ob bereits ohne SW3 ein Interrupt ansteht}
      until Wr_Count =20;

      Sw3 := -Sw3_Delta;
      repeat
         Mil.Wr(Sw3, Fct, MilErr);
         Wr_Count := Wr_Count + 1;
         Mil.Timer2_Set (Dreq_Time+2); { timer2_starten }
         repeat
           Timeout := Mil.Timeout2;
         until ((PORTW[Port_Stat] and Stat_Dta_Req)=Stat_Dta_Req) or Timeout;
          {PrÅfe, ob bereits ohne SW3 ein Interrupt ansteht}
      until Wr_Count =30;

      Sw3 := 0;
      repeat
         Mil.Wr(Sw3, Fct, MilErr);
         Wr_Count := Wr_Count + 1;
         Mil.Timer2_Set (Dreq_Time+2); { timer2_starten }
         repeat
           Timeout := Mil.Timeout2;
         until ((PORTW[Port_Stat] and Stat_Dta_Req)=Stat_Dta_Req) or Timeout;
          {PrÅfe, ob bereits ohne SW3 ein Interrupt ansteht}
      until Wr_Count =40;

      Fct.B.Fct := Fct_Wr_Sw1;
      Mil.Wr (Summand1.r.hw, Fct, MilErr);   {Stop FGen}
      Ini_Msg_Win;
      Write ('FGEN gestoppt!  Weiter mit <CR> ');
      repeat until KeyEPressed;
      Ch := NewReadKey;
      Exit;

      Wr_Count := 0;
{
      Mil.Wr(Sw3, Fct, MilErr);
      Wr_Count := Wr_Count + 1;

      Mil.Timer2_Set (Dreq_Time+2);
      repeat
        Timeout := Mil.Timeout2;
      until ((PORTW[Port_Stat] and Stat_Dta_Req)=Stat_Dta_Req) or Timeout;

      if Timeout then
        begin
          MilErr := No_Err;
          Set_Text_Win;
          gotoXY(1,22);
          WRITE('Data request timeout. FG als Slave und kein GATE-IN ?');
        end;
}
    if KeyEPressed then Ch := NewReadKey;
  until Ch in ['x','X'];
  99:  Cursor(True);
 end; {FG_Rampe_HF1}


 PROCEDURE set_intr_mask (Intr_Mask: WORD; VAR MilErr: TMilErr);
  Begin
   Fct.B.Fct := Fct_Set_IntMask;
   Mil.Wr (Intr_Mask, Fct, MilErr);
  End; { set_intr_mask }


 PROCEDURE Set_Sw4_Et (VAR Sw4: WORD; VAR Dreq_Time, StuetzPunkt: LONGINT);
  var AddierFreq,Disp_AddierFreq : Integer;
      Disp_StuetzPunkt :  LongInt;
   begin
    Sw4 := 0;                    {Master}
    Sw4 := Sw4 and Freq_Intern;  {Freq Intern}
    AddierFreq := Freq_2048;
    StuetzPunkt:= Stuetz_32768;
    Sw4 := Sw4 or ((AddierFreq shl 3) + StuetzPunkt);

    addierfreq  :=   1 shl (7-addierfreq);
    stuetzpunkt := 256 shl (7-stuetzpunkt);
    Dreq_Time  := (addierfreq * stuetzpunkt div 20)+1;  {x 10 us}
    GotoXY(10,04+0);  writeln ('Data request time: ', dreq_time);
    repeat until keypressed;
   end;

 procedure FG_Rampe_HF;
  label 99;
  const
   Life_Sign_X = 10;
   Life_Sign_Y = 3;
   Interpol_Yes= 0;
   Interpol_No = 1;

  var
   Adress                : Word;
   Sw1, Sw4, Sw5         : Word;
   Sw3                   : Integer;
   AddierFreq            : INTEGER;
   Dreq_Time, StuetzPunkt: LONGINT;
   Summand1, Istwert, Endwert: TSummand1;
   Pc_Stat               : TPcStat;
       timeout : BOOLEAN;

  begin
   Mil_Ask_Ifc;
   Ini_Text_Win;
   Ini_Msg_Win;
   Std_Msg;
   Set_Text_Win;

   Fct.B.Adr := Ifc_Test_Nr;
   GotoXY(10,02); write('----- Einfacher Rampentest fÅr HF -----');

                          {Testparamter festlegen}
   Summand1.Li := 0;     {SW1+SW2}
   Sw3 := 32767;
   Set_Sw4_Et (Sw4, Dreq_Time, StuetzPunkt);


   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Reset;
   Mil.WrFct (Fct, MilErr);

   Mil.Timer2_Wait (10);
   Fct.B.Fct := Fct_Wr_Sw4;
   Mil.Wr (Sw4, Fct, MilErr);

   Fct.B.Fct := Fct_Wr_Sw1;
   Mil.Wr (Summand1.r.hw, Fct, MilErr);

   Fct.B.Fct := Fct_Wr_Sw2;
   Mil.Wr(Summand1.r.lw, Fct, MilErr);

   SW5 := 1 ;           {nicht interpol}
   SW5 := SW5 AND $FD;  {kein Sw3 shift}
   Fct.B.Fct := Fct_SW3;
   Mil.Wr(SW5, Fct, MilErr);

   {Der Funktionsgenerator ist nun mit allen statischen Parametern versorgt}
   Mil.Timer2_Wait (10); {Warten, bvor Reset!!}
   Mil.Reset;                                 {PC-Interface clearen}

   Set_Intr_mask (ifc_irmask_dreq, MilErr);
   IF ((PORTW[Port_Stat] AND stat_dta_req)=stat_dta_req) THEN  {PrÅfe, ob bereits ohne SW3 ein Interrupt ansteht}
    BEGIN
     Ini_Err_Win;
     Write('ERROR: Intr DREQ liegt bereits ohne SW3 vor! Weiter: <Space> ');
     REPEAT UNTIL keypressed;
     Std_Msg;
     Set_Text_Win;
    END;


   Cursor(False);
   Single_Step := False;
{   Ch := NewReadKey;   }
   Fct.B.Fct := Fct_Wr_Sw3;

   repeat
{    if Ch = #13 then Single_Step := False; }
    if not Single_Step then
     begin
      if MilErr = No_Err then
        begin
          Mil.Wr(Sw3, Fct, MilErr);
        end; { hier muss noch geaendert werden !!!!!}

{      mil.timer1_wait(5); }
       Mil.Timer2_Set (Dreq_Time+2); { timer2_starten }
      repeat
        Timeout := Mil.Timeout2;
      until ((PORTW[Port_Stat] and Stat_Dta_Req)=Stat_Dta_Req) or Timeout;  {PrÅfe, ob bereits ohne SW3 ein Interrupt ansteht}
      if Timeout then
        begin
          MilErr := No_Err;
          Set_Text_Win;
          gotoXY(1,22);
          WRITE('Data request timeout. FG als Slave und kein GATE-IN ?');
        end;
      end;  {Loop}

   if KeyEPressed then Ch := NewReadKey;
  until Ch in ['x','X'];
  99:  Cursor(True);
 end; {FG_Rampe_HF}


 PROCEDURE Set_Sw4_Duo (VAR Sw4: WORD; VAR Dreq_Time, StuetzPunkt: LONGINT);
  var AddierFreq,Disp_AddierFreq : Integer;
      Disp_StuetzPunkt :  LongInt;
      Dreq_Time_Real   :  Real;
   begin
    Sw4 := 0;                    {Master}
    Sw4 := Sw4 and Freq_Intern;  {Freq Intern}
    AddierFreq := Freq_1024;
    StuetzPunkt:= Stuetz_8192;
    Sw4 := Sw4 or ((AddierFreq shl 3) + StuetzPunkt);

    addierfreq  :=   1 shl (7-addierfreq);
    stuetzpunkt := 256 shl (7-stuetzpunkt);
    Dreq_Time  := (addierfreq * stuetzpunkt div 20)+1;  {x 10 us}
     Dreq_Time_Real  := Dreq_Time /100;
    GotoXY(10,05+0);  writeln ('Data Request Time [ms]: ', dreq_time_Real: 5:2);
   end;



 procedure  Duo_Freq_Ampl;
  label 99;
  const
   Life_Sign_X = 10;
   Life_Sign_Y = 3;
   Interpol_Yes= 0;
   Interpol_No = 1;
   Sw3_Delta   = 20000;

  var
   Adress                   : Word;
   Sw1, Sw4, Sw5            : Word;
   Sw3, Sw3_Aktuell         : Integer;
   AddierFreq               : INTEGER;
   Dreq_Time, StuetzPunkt   : LONGINT;
   Summand1, Istwert, Endwert: TSummand1;
   Pc_Stat                  : TPcStat;
   Timeout                  : BOOLEAN;
   Wr_Count                 : LongInt;
   Mode_An, Mode_Ab         : Boolean;
   Ifc_Freq_Nr, Ifc_Ampl_Nr : Byte;
   FG_Stat                  : Word;

  begin
   Ini_Text_Win;
   Ini_Msg_Win;
   Std_Msg;
   Set_Text_Win;
   Mode_An := False;
   Mode_Ab := False;

   Ifc_Freq_Nr := $11;    {VorlÑufig feste Adressen: spÑter Abfragen}
   Ifc_Ampl_Nr := $AA;
   GotoXY(10,02); write('----- Rampentest mit 2 Funkt. Gen.: Freq. + Amplitude -----');
   GotoXY(10,03); write('IFK-Adr fÅr Frequenz : ', Hex_Byte(Ifc_Freq_Nr));
   GotoXY(10,04); write('IFK-Adr fÅr Amplitude: ', Hex_Byte(Ifc_Ampl_Nr));



{xxx]


                          {Testparamter fÅr Ampl-Rampe festlegen}
   Fct.B.Adr := Ifc_Ampl_Nr ;
   Fct.B.Fct := Fct_Reset;
   Mil.WrFct (Fct, MilErr);

   Summand1.Li := 0;                      {SW1+SW2: Dig. Ausgang clear}
   Fct.B.Fct := Fct_Wr_Sw1;
   Mil.Wr (Summand1.r.hw, Fct, MilErr);
   Fct.B.Fct := Fct_Wr_Sw2;
   Mil.Wr(Summand1.r.lw, Fct, MilErr);

                          {Testparamter fÅr Freq-Rampe festlegen}
   Set_Sw4_Duo (Sw4, Dreq_Time, StuetzPunkt);
   Fct.B.Adr := Ifc_Freq_Nr;
   Fct.B.Fct := Fct_Reset;
   Mil.WrFct (Fct, MilErr);

   Mil.Timer2_Wait (10);
   Fct.B.Fct := Fct_Wr_Sw4;
   Mil.Wr (Sw4, Fct, MilErr);

   Summand1.Li := 0;                      {SW1+SW2: Dig. Ausgang clear}
   Fct.B.Fct := Fct_Wr_Sw1;
   Mil.Wr (Summand1.r.hw, Fct, MilErr);
   Fct.B.Fct := Fct_Wr_Sw2;
   Mil.Wr(Summand1.r.lw, Fct, MilErr);

   SW5 := 1 ;            {nicht interpol}
   SW5 := SW5 AND $FD;   {kein Sw3 shift}
   Fct.B.Fct := Fct_SW3;
   Mil.Wr(SW5, Fct, MilErr);

   {Der Funktionsgenerator ist nun mit allen statischen Parametern versorgt}
   Mil.Reset;                                 {PC-Interface clearen}
   Set_Intr_mask (ifc_irmask_dreq, MilErr);
   IF ((PORTW[Port_Stat] AND stat_dta_req)=stat_dta_req) THEN  {PrÅfe, ob bereits ohne SW3 ein Interrupt ansteht}
    BEGIN
     Ini_Err_Win;
     Write('ERROR: Intr DREQ liegt bereits ohne SW3 vor! Weiter: <Space> ');
     REPEAT UNTIL keypressed;
     Std_Msg;
     Set_Text_Win;
    END;

   Ini_Msg_Win;
   Write ('Start mit <CR>!! ');
   repeat until KeyEPressed;
   Ch := NewReadKey;
   Ini_Msg_Win;
   Std_Msg;

   Cursor(False);
   Single_Step := False;
   Wr_Count := 0;

   repeat{    if Ch = #13 then Single_Step := False; }
      Fct.B.Adr := Ifc_Ampl_Nr ;       {Amplitude auf max. Wert}
      Summand1.Li := $599A0000;  {7.0V}      {SW1+SW2: Dig. Ausgang auf max. Ampl.}
      Fct.B.Fct := Fct_Wr_Sw1;
      Mil.Wr (Summand1.r.hw, Fct, MilErr);
      Fct.B.Fct := Fct_Wr_Sw2;
      Mil.Wr(Summand1.r.lw, Fct, MilErr);

      Mil.Timer2_Wait (1000);             {Wartezeit bis zur Freq.}

      Fct.B.Adr := Ifc_Freq_Nr;           {Rampe Freq. starten}
      Fct.B.Fct := Fct_Wr_Sw3;
      Sw3 := Sw3_Delta;
      repeat
         Mil.Wr(Sw3, Fct, MilErr);
         Wr_Count := Wr_Count + 1;
         Mil.Timer2_Set (Dreq_Time+2); { timer2_starten }
         repeat
           Timeout := Mil.Timeout2;
         until ((PORTW[Port_Stat] and Stat_Dta_Req)=Stat_Dta_Req) or Timeout;
      until Wr_Count =10;

      Sw3 := 0;                      {Freq. Flattop einschalten}
      Mil.Wr(Sw3, Fct, MilErr);

      Mil.Timer2_Wait (2000);

      Fct.B.Adr := Ifc_Ampl_Nr ;     {Amplitude auf Null setzen}
      Summand1.Li := $0;             {SW1+SW2: Dig. Ausgang}
      Fct.B.Fct := Fct_Wr_Sw1;
      Mil.Wr (Summand1.r.hw, Fct, MilErr);
      Fct.B.Fct := Fct_Wr_Sw2;
      Mil.Wr(Summand1.r.lw, Fct, MilErr);

      Mil.Timer2_Wait (10000);        {Wartezeit bis Freq. Abstieg}

      Wr_Count := 0;                  {Rampe abwÑrts}
      Fct.B.Adr := Ifc_Freq_Nr;
      Fct.B.Fct := Fct_Wr_Sw3;
      Sw3 := -Sw3_Delta -1;
      Mil.Timer2_Set (Dreq_Time+2); { timer2_starten }
      repeat
        Timeout := Mil.Timeout2;
      until ((PORTW[Port_Stat] and Stat_Dta_Req)=Stat_Dta_Req) or Timeout;

      Fct.B.Fct := Fct_Rd_FGStat1;
      Mil.Wr(FG_Stat, Fct, MilErr);     {Status lesen lîscht Sw3-Timeout}

      Fct.B.Fct := Fct_Wr_Sw3;
      repeat
         Mil.Wr(Sw3, Fct, MilErr);
         Wr_Count := Wr_Count + 1;
         Mil.Timer2_Set (Dreq_Time+2); { timer2_starten }
         repeat
           Timeout := Mil.Timeout2;
         until ((PORTW[Port_Stat] and Stat_Dta_Req)=Stat_Dta_Req) or Timeout;
      until Wr_Count =10;

      Sw3 := 0;                             {Freq. Null einschalten}
      Mil.Wr(Sw3, Fct, MilErr);
      Mil.Timer2_Wait (1000);


      Summand1.Li := $0;                    {Stop Freq. Gen }
      Fct.B.Fct := Fct_Wr_Sw1;
      Mil.Wr (Summand1.r.hw, Fct, MilErr);
      Fct.B.Fct := Fct_Wr_Sw2;
      Mil.Wr(Summand1.r.lw, Fct, MilErr);

      Mil.Timer2_Wait (15000);              {Wartezeit bis neue Sequenz}
      Wr_Count := 0;
    if KeyEPressed then Ch := NewReadKey;
  until Ch in ['x','X'];
  99:  Cursor(True);
 end; {Duo_Freq_Ampl;}

