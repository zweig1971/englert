PROGRAM Mil_HFRA;             {Rampen mit Funktionsgenerator}
{ Autor des Basis-Programmes Mil_BASE.PAS: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS

  FÅr Test-Rampen im SIS-ESR-HF Herrn Kaspar

  Autor der Erweiterungen   :
  énderungen:
  12.09.96    Et        Erstellung
  03.03.97    Et        Ifc-Nr. Kava1, -F1 war zweimal
  10.03.97              Fehler-Anzeige beim Rampenfahren
                        Wartezeit bei Rampen Sync verdoppelt
  14.03.97              Warte zwischen Zyklen auf 500 ms
                        Status-Anzeige
                        Prozent-Eingabe
  15.01.98              Umbenennung in MIL_HDRA (alt: MIL_RAMP)
  22.06.99              Anpassung an neue FG Firmware V08
                        Bei SW3-Timeout bleibt neurdings der FG stehen!
                        Function "FG_Rampe" entsprechend geÑndert.

  Sollwert4: D7 : Frequenz      0=Intern, 1=externe Frequenz
             D6 : Master/Slave  0=Master, 1=Slave
             D5 :
             D4 :
             D3 :

  Im SIS und ESR: je 2 KavitÑten mit je einer IFK = 4 IFK
  Zwei benachbarte IFK z. B. Adr 4 u. 5 bilden ein Paar (Amplitude u. Frequenz)



}
{$S-}
{$DEFINE NoTest}      {Test: Dummy-Daten aktivieren    NoTest: Arbeitsversion}
uses Crt,WinDos,Dos,Datech,Datech_0,Datech_1,Datech_2;    {spez. MIL-Routinen in Units Datech..}

const
 Head_Line =
      'BELAB                                MIL_HFRA   ' +
      '                    [25.06.1999]' +
      '         Test-Rampen fÅr SIS/ESR-HF mit Funktionsgenerator [FG 380 540]        ';

 procedure menue_win;
  var answer: CHAR;
 begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;              {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}
  TextColor(Blue);

  {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}
  GotoXY(5, 14);
  Writeln('       [M]<-- Adressen IFK u. Funktions-Gen-Typen am MIL-Bus ');
  GotoXY(5, 15);
  Writeln('       [N]<-- Status der Anlage                              ');
  GotoXY(5, 16);
  Writeln('       [O]<-- Rampen-Test SIS/ESR HF-KavitÑten               ');
{
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
 Hf_Parm_Max  = 2;

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


 THf_Acc_Ary = array [1..Hf_Parm_Max] of THf_Acc;

 const                  {Testparameter fÅr Rampentests festlegen}
  SIS : THf_Acc_Ary =
  (
   (A: (MilAdr: 132; Nomen: 'S02BE1A '; SwMin: 0.00; SWMax: 10.0; FScale_Real: 20.0; FScale_Int: $7FFF0000);
    F: (MilAdr: 133; Nomen: 'S02BE1FS'; SwMin: 0.85; SWMax:  5.4; FScale_Real: 12.5; FScale_Int: $7FFF0000)),

   (A: (MilAdr:  04; Nomen: 'S08BE2A '; SwMin: 0.00; SWMax: 10.0; FScale_Real: 20.0; FScale_Int: $7FFF0000);
    F: (MilAdr:  05; Nomen: 'S08BE2FS'; SwMin: 0.85; SWMax:  5.4; FScale_Real: 12.5; FScale_Int: $7FFF0000))
  );

  ESR : THf_Acc_Ary =
  (
   (A: (MilAdr:  04; Nomen: 'E02BE1A '; SwMin: 0.00; SWMax: 4.0; FScale_Real:  5.0; FScale_Int: $7FFF0000);
    F: (MilAdr:  05; Nomen: 'E02BE1FS'; SwMin: 0.85; SWMax: 5.4; FScale_Real: 12.5; FScale_Int: $7FFF0000)),

   (A: (MilAdr: 132; Nomen: 'E01BE2A '; SwMin: 0.00; SWMax: 4.0; FScale_Real:  5.0; FScale_Int: $7FFF0000);
    F: (MilAdr: 133; Nomen: 'E01BE2FS'; SwMin: 0.85; SWMax: 5.4; FScale_Real: 12.5; FScale_Int: $7FFF0000))
  );

var
  MilErr : TMilErr;
  Fct    : TFct;
  Ifc_Freq_Nr, Ifc_Ampl_Nr : Byte;                {Global fÅr SIS- u. ESR-HF}
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
{xxx}
 type TRunMode = (Init, Sync);

 procedure Set_Sw4_Freq (VAR Sw4: WORD; VAR Dreq_Time, StuetzPkt: LONGINT);
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

 {xxx}
 function FG_Rampe (Ifc      : Byte;
                    RunMode  : TRunMode; {Start Rampe oder Synchr. auf DREQ}
                    Sw3_Delta: Word;     {Addierwert}
                    SW3_Count: Integer;  {Anzahl Addierungen}
                    Drq_Time : Word      {Zeit zwischen zwei DREQ}
                   )         : Boolean;  {SW3 Timeout}
  var I: LongInt; Timeout: Boolean; Temp : Word;
  begin
   FG_Rampe  := True;                              {Default: alles ok}
   Fct.B.Adr := Ifc;
   I := 0;
   {if RunMode = Sync then : kann wegen neuer Firmware V08 jetzt entfallen}
   {Vor jedem Start SW3-TimeoutBit lîschen durch Lesen Status1}
   Fct.B.Fct := Fct_Status1;
   Mil.Rd(Temp, Fct, MilErr);
   Set_IntMask (Ifc, Ifc_Irmask_Dreq, MilErr);          {Enable DREQ auf Ifc}
   Fct.B.Fct := Fct_Wr_Sw3;  {Rampe rauf/runter gemÑ· Vorzeichen Sw3_Delta}
   repeat
      Mil.Wr(Sw3_Delta, Fct, MilErr);  {Starte Rampe durch Write SW3}
      Mil.Timer2_Wait (6);         {MIL-Transfer abwarten, bis SW3 im FG ist}
      Mil.Timer2_Set (Drq_Time + 10);    {max. warten bis DREQ kommen sollte}
      I := I+1;
      repeat
        Timeout := Mil.Timeout2;
      until ((PORTW[Port_Stat] and Stat_Dta_Req) = Stat_Dta_Req) or Timeout;
      if Timeout then
       begin
         FG_Rampe:= False;
         Ini_Err_Win;
         Write('ERROR: DREQ-Timeout wÑhrend einer Rampe! Nr.',I,' Weiter: <Space> ');
         REPEAT UNTIL keypressed;
         Std_Msg;
         Set_Text_Win;
         Exit;
     end;
   until I = SW3_Count;  {es lÑuft jetzt noch der letzte Teil der Rampe}

   {Warte bis SW3-Timeoutbit gesetzt ist. FG bleibt auf letztem Wert stehen!}
   {Das Lesen von Status2 lîscht das SW3-Timout-Bit nicht}
   Mil.Timer2_Set(100000);  {Abort nach 1 sec, falls SW3-Timeout versagt}
   repeat
     Timeout   := Mil.Timeout2;
     Fct.B.Fct := Fct_Status2;
     Mil.Rd(Temp, Fct, MilErr);
   until (BitTst(Temp,8) or Timeout);
   Set_IntMask (Ifc, Ifc_Irmask_Dis, MilErr);   {Disable DREQ auf dieser Ifc}
  end; {FG_Rampe}

{xxx}
 procedure  Duo_Rampe;
  label 99;
  const
   F_Add_Amp    = 1.024;   {in Mhz. Vorsicht: Auch Set_Sw4_Ampl mit Ñndern!!}
   F_Add_Freq   = 1.024;   {in Mhz. Vorsicht: Auch Set_Sw4_Freq mit Ñndern!!}
   Anstieg_Amp  =    80;  {40} {in ms: Anstieg- u. Abfall-Rampe Amplitude}
   Anstieg_Freq =   600;  {300}{in ms: Anstieg- u. Abfall-Rampe Frequenz }

   Wait_Top_AF  =  2000;   {x10 us = 20 ms: Wartezeite Ampl - Freq}
   Wait_Top_FA  = 10000;   {Wartezeite Freq - Ampl}
   Wait_Bot_AF  = 20000;   {Wartezeit Bottom = Minimalwert}
   Wait_Bot_FA  = 50000;   {Wartezeit Bottom = Minimalwert}

   Z_Base  = 3;              {Zeilen und Spalten fÅr Display-Darstellung}
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

  var
   Adress                   : Word;
   Sw1, Sw4, Sw5            : Word;
   Sw3                      : Integer;
   Sw1_AmpMax, Sw1_FreqMax  : Integer;
   Sw1_AmpMin, Sw1_FreqMin  : Integer;
   Sw3_Delta_Ampl           : Integer;
   Sw3_Delta_Ampl_Hex       : Word;
   Sw3_Delta_Freq           : Integer;
   SW3_Count_Ampl           : Integer; { 10; }
   SW3_Count_Freq           : Integer;  { 25;}

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
   Ramp_Err_Ampl            : LongInt;
   Ramp_Err_Freq            : LongInt;
   Prozent                  : Integer;
   Prozent_Real             : Real;
   I : Byte;

  begin
   Ini_Text_Win;
   Ini_Msg_Win;
   Ramp_Err_Ampl := 0; Ramp_Err_Freq  := 0;
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
      Ifc_Kav2A :=  SIS[2].A.MilAdr;
      Ifc_Kav2F :=  SIS[2].F.MilAdr;
    end
   else
    begin
      Ifc_Kav1A :=  ESR[1].A.MilAdr;
      Ifc_Kav1F :=  ESR[1].F.MilAdr;
      Ifc_Kav2A :=  ESR[2].A.MilAdr;
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
       Ifc_Nr := Ifc_Kav2A ;                         {2. IFK-Paar vorhanden?}
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

   Ini_Msg_Win;
   Write ('Amplitude in ['); TextColor(red); Write ('P'); TextColor(Yellow);
   Write(']rozent vom Maximalwert bzw. [<CR> = Standard-Werte]: ');
   Ch := NewReadKey;
   if (Ch in ['p','P']) then        {Abfrage ob %-Wert oder Default Werte}
    begin
     if Read_Int (1, 100, Prozent) then
      begin
        Prozent_Real := abs (Prozent / 100);
        for I := 1 to Hf_Parm_Max do
         begin
          SIS[I].A.SwMax :=  SIS[I].A.FScale_Real * (Prozent_Real);
          ESR[I].A.SwMax :=  ESR[I].A.FScale_Real * (Prozent_Real);
         end;
      end;
    end; {if P}

   Set_Text_Win;
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
   Fct.B.Fct := Fct_Reset;       {SW1+SW2: Dig. Ausgang clear Hi u. Lo = 0}
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
   Summand1.Li   := round (SW_Real);     {In Integer wandeln}
   Sw3_Delta_Ampl:= Summand1.r.lw;
                                {Anzahl der DREQ berechnen}
   SW3_Count_Ampl := round ((Anstieg_Amp) / (Dreq_Time_Ampl /100));  {Zeiten in ms}

(*{$IFDEF Test}*)
   Dreq_Time_Real := Dreq_Time_Ampl /100;  TextColor(Brown);
   GotoXY(S_SwAmp+4, Z_Sw3-1); Write (' FG Amplitude: ');  TextColor(Black);
   GotoXY(S_SwAmp, Z_Sw3);     Write ('Anstieg   [ms]:    ',Anstieg_Amp:3);
   GotoXY(S_SwAmp, Z_Sw3+1);   Write ('Add-Freq [Mhz]:  ',  F_Add_Amp:5:3);
   GotoXY(S_SwAmp, Z_Sw3+2);   Write ('DRQ-Time  [ms]:  ',  dreq_time_Real: 5:2);
   GotoXY(S_SwAmp, Z_Sw3+3);   Write ('Anzahl DREQ   :    ',SW3_Count_Ampl:3);
   GotoXY(S_SwAmp, Z_Sw3+4);   Write ('SW3_Amp [Real]: ',   Sw_real:6:0);
   GotoXY(S_SwAmp, Z_Sw3+5);   Write ('SW3_Amp [Int ]:  ',  Sw3_Delta_Ampl);
(*{$ENDIF}*)

                     {Testparamter fÅr Freq-Rampe festlegen}
   Fct.B.Adr := Ifc_Freq_Nr ;
   Fct.B.Fct := Fct_Reset;       {SW1+SW2: Dig. Ausgang clear}
   Mil.WrFct (Fct, MilErr);

                  {Minimum Freq schreiben: Nur HiWord, Lw =0}
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

                                                  {SW3 fÅr Frequenz berechnen}
   SW_Real := Sw1_FreqMax - Sw1_FreqMin;              {F = Frequenz in Mhz}
   SW_Real := ((Sw_Real * $7FFF) / (Anstieg_Freq * 1000.0)) * (1/F_Add_Freq); {Anstieg in ms}
   Summand1.Li:= round (SW_Real);
   Sw3_Delta_Freq:= Summand1.r.lw;
                                                   {Anzahl der DREQ berechnen}
   SW3_Count_Freq := round ((Anstieg_Freq) / (Dreq_Time_Freq /100));  {Zeiten in ms}

(*{$IFDEF Test}*)
   Dreq_Time_Real := Dreq_Time_Freq /100;  TextColor(Brown);
   GotoXY(S_SwFreq+4, Z_Sw3-1); Write (' FG Frequenz: ');  TextColor(Black);
   GotoXY(S_SwFreq, Z_Sw3);     Write ('Anstieg   [ms]:    ',Anstieg_Freq:3);
   GotoXY(S_SwFreq, Z_Sw3+1);   Write ('Add-Freq [Mhz]:  ', F_Add_Freq:5:3);
   GotoXY(S_SwFreq, Z_Sw3+2);   Write ('DRQ-Time  [ms]:  ',  dreq_time_Real: 5:2);
   GotoXY(S_SwFreq, Z_Sw3+3);   Write ('Anzahl DREQ   :    ',SW3_Count_Freq:3);
   GotoXY(S_SwFreq, Z_Sw3+4);   Write ('SW3_Freq[Real]: ', Sw_real:6:0);
   GotoXY(S_Swfreq, Z_Sw3+5);   Write ('SW3_Freq[Int ]:   ', Sw3_Delta_Freq);
(*{$ENDIF}*)

   {Die Funktionsgeneratoren sind mit allen statischen Parametern versorgt}
   Mil.Reset;                                        {PC-Interface clearen}

   {PrÅfe, ob von Frequenz-Funktionsgen. schon vorzeitig DREQ vorliegt!}
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

   {PrÅfe, ob von Amplitude-Funktionsgen. schon vorzeitig DREQ vorliegt!}
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
   Write ('Rampenfahren mit ['); TextColor(Red); Write ('S'); TextColor(Yellow);
   Write(']tart beginnen oder Ende mit <CR>:  ');
   Ch := NewReadKey;
   if not (Ch in ['s','S']) then Exit;

   Ramp_Err_Ampl := 0;
   Ramp_Err_Freq := 0;
   Ini_Msg_Win;
   Write ('Funktionsgen. Ampl u. Freq im '); TextColor(Red +128);
   Write('Dauertest'); TextColor(Yellow); Write('!    Stop mit <Space>,   Ende mit <X>: ');
   Cursor(False);

repeat   {Beide Rampen zum ersten Mal starten}    {Amplitude rauf}
   if FG_Rampe (Ifc_Ampl_Nr, Init, Sw3_Delta_Ampl, SW3_Count_Ampl, Dreq_Time_Ampl)
   then Ramp_Err_Ampl  := Ramp_Err_Ampl  + 1;
   Mil.Timer2_Wait (Wait_Top_AF);  {Wartezeit bis zur Freq.}  {Freq. rauf}
   if FG_Rampe (Ifc_Freq_Nr, Init, Sw3_Delta_Freq, SW3_Count_Freq, Dreq_Time_Freq)
   then Ramp_Err_Freq  := Ramp_Err_Freq  + 1 ;

   repeat
     Mil.Timer2_Wait (Wait_Top_FA);    {Amplitude runter}
     if FG_Rampe (Ifc_Ampl_Nr, Sync, -Sw3_Delta_Ampl, SW3_Count_Ampl, Dreq_Time_Ampl)
     then Ramp_Err_Ampl  := Ramp_Err_Ampl  + 1; ;
                   {Harten Minimum-Wert fÅr Amplitude}
     Fct.B.Adr     := Ifc_Ampl_Nr;
     Summand1.Li   := 0;
     Summand1.r.hw := Sw1_AmpMin;
     Fct.B.Fct     := Fct_Wr_Sw1;
     Mil.Wr (Summand1.r.hw, Fct, MilErr);
     Fct.B.Fct := Fct_Wr_Sw2;
     Mil.Wr(Summand1.r.lw, Fct, MilErr);

     Mil.Timer2_Wait (Wait_Bot_AF);
     {Freq runter}
     if FG_Rampe (Ifc_Freq_Nr, Sync, -Sw3_Delta_Freq, SW3_Count_freq, Dreq_Time_Freq)
     then Ramp_Err_Freq  := Ramp_Err_Freq  + 1;
                    {Harten Minimum-Wert fÅr Frequenz}
     Fct.B.Adr     := Ifc_Freq_Nr;
     Summand1.Li   := 0;
     Summand1.r.hw := Sw1_FreqMin;
     Fct.B.Fct     := Fct_Wr_Sw1;
     Mil.Wr (Summand1.r.hw, Fct, MilErr);
     Fct.B.Fct := Fct_Wr_Sw2;
     Mil.Wr(Summand1.r.lw, Fct, MilErr);

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
          Write ('Funktionsgen. Ampl u. Freq im '); TextColor(Red +128);
          Write('Dauertest'); TextColor(Yellow); Write('!    Stop mit <Space>,   Ende mit <X>: ');
          Ch := '?';
         end;
      end;

     if Ch in  ['x','X'] then Exit;
     Mil.Timer2_Wait (Wait_Bot_FA); {Wartezeit bis nÑchste Sequenz} {Ampl. rauf}
     if FG_Rampe (Ifc_Ampl_Nr, Init, Sw3_Delta_Ampl, SW3_Count_Ampl, Dreq_Time_Ampl)
     then  Ramp_Err_Ampl  := Ramp_Err_Ampl  + 1;;
     Mil.Timer2_Wait (Wait_Top_AF); {Wartezeit bis zur Freq.}  {Freq. rauf}
     if FG_Rampe (Ifc_Freq_Nr, Init, Sw3_Delta_Freq, SW3_Count_Freq, Dreq_Time_Freq)
     then Ramp_Err_Freq  := Ramp_Err_Freq  + 1;
  until 1=2;
until 1=2;

   Set_Text_Win;
   GotoXY(S_SwFreq, Z_Sw3+6);   Write ('Rampen-Err_Freq:  ',Ramp_Err_Freq);
   GotoXY(S_SwAmp , Z_Sw3+6);   Write ('Rampen-Err_Ampl:  ',Ramp_Err_Ampl);
   REPEAT UNTIL keypressed;

 {Runterfahren der Rampen nicht nîtig, weil Abbruch bereits bei Nullwerten!!}
  99:  Cursor(True);
 end; {Duo_Rampe}


{Ab hier Status Display: wie Magnetsteuerung}

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

const
 Z_SW    = 22;
 S_Loop  = 7;
 S_RdErr = 9;
 S_SWH   = 23;   {Sollwert Hex}
 S_SWV   = 34;   {Sollwert Volt}
 S_SWA   = 52;   {Sollwert Ampere}
 S_SWX   = 73;   {Sollwert MaxAmpere}
 Sw_Amax: Real   = 0.0;     {MaxAmpere vorbesetzen}

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



 procedure Mil_Stat_Tabelle;  {Bits, die sich verÑndern werden farblich markiert}
  label 99;
  const
   Tab_Max = $13;

   Stat_Line =
       'Status-Bits                          MAGNETE    ' +
       '                    [25.02.1997]' +
       '                                Tabellen-öbersicht                             ';
   Zeile_Start  = 01;
   Spalte_Start = 01;
   Wait_Time    = 200000; {2 sec}
   SW_Plus      = $2000;  {+2,500 Volt}
   SW_Minus     = $E000;  {-2,500 Volt}
   Loop_Wait1: LongInt = 10000;  {0,10 sec}
   Loop_Wait2: LongInt = 100;
   Stat_Byte_Max= 2;
   Err_Bits_Max = 7;

  type
   TStat_Byte_Ary   = array [0..2] of Byte;
   TStat_Error_Byte = array [0..7] of Boolean;
   TStat_Error_Ary  = array [0..2] of TStat_Error_Byte;

  var
   Stat_Old_Bytes : TStat_Byte_Ary;
   Stat_Err_Ary   : TStat_Error_Ary;
   Loop_Wait      : LongInt;
   Read_Data,Fct_Code: Word;
   MilErr : TMilErr;
   Fct    : TFct;

   Tab_Nr    : Word;
   Zeile_Act : Byte;
   Spalte_Act: Byte;
   Data_Act  : Byte;
   Mode_Act  : Boolean;
   Byte_Act  : Byte;     {aktuelle Daten-Byte Nr}
   transf_cnt: LongInt;
   timout_cnt: LongInt;
   Ch        : Char;
   LastNr    : Byte;
   IW1, IW2  : Integer;
   First_Online: Byte;
   N,M       : Word;
   RetAdr    : Byte;
   OnlineErr : TOnlineErr;
   SW_Act    : Integer;
   SW_Valid  : Boolean;
   Sonder_Zeichen : Char;
   Stat_Valid: Boolean; {FehlerprÅfung nur nach dem 1. Lesen von 3 Status-Bytes}
   Stat_Init : Boolean;
   Err_Stat_Intrl: Boolean;
   Interl_Old    : Boolean;
   Interl_Ini    : Boolean;
   Adress        : Word;
   Displ_counter : Word;
   Single_Step   : Boolean;
   Sollw         : TSw;
   R_Zahl        : Real;
   Rampe_On      : Boolean;


 procedure Life_Sign (Mode: TLife);
  const S_Aktiv   = 7;
        Z_Aktiv   = 21;
        Life_Time1 = 5000;
        Life_Time2 = 2000;

  var Life_Wait : LongInt;
      Loop_Wait : LongInt;

  begin
    Cursor(False);
    Set_Text_Win;
    if Mode = Norm then
     begin
      If Loop_Wait = Loop_Wait1 then Life_Wait := Life_Time1
      else  Life_Wait := Life_Time2;
      Set_Text_Win;
      TextColor(Yellow);
      GotoXY(S_Aktiv, Z_Aktiv);  Write (chr($7C)); Mil.Timer2_Wait (Life_Wait);
      GotoXY(S_Aktiv, Z_Aktiv);  Write ('/');      Mil.Timer2_Wait (Life_Wait);
      GotoXY(S_Aktiv, Z_Aktiv);  Write (chr($2D)); Mil.Timer2_Wait (Life_Wait);
      GotoXY(S_Aktiv, Z_Aktiv);  Write ('\');      Mil.Timer2_Wait (Life_Wait);
      TextColor(Black);
     end
    else
     begin
       TextColor(Red+128);
       GotoXY(S_Aktiv, Z_Aktiv); Write (chr($DB));
       TextColor(Black);
     end;
   end; {Life_Sign}

type
 TSpeed     = (Slow, Medium, Fast);

const
 Fct_SW1 = $06;
 Fct_SW3 = $08;
 Fct_SW4 = $09;

 Sw1_Slow = $1000;     {Anfangsbedingung}
 Sw3_Slow = $1000;     {+10V=1.. Steigung oder-10V = F..}
 Sw4_Slow =   $30;     {Frequenz}
 Sw1_Fast = $1000;     {}
 Sw3_Fast = $1000;     {}
 Sw4_Fast =   $38;     {}

var
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


 procedure FG_Rampe_Fix (Speed: TSpeed);
  label 99;

  begin
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
   Start_Rampe;
 end; {FG_Rampe_Fix}

  procedure Displ_Stat_Bits (D_Spalte, D_Zeile, D_Byte:Byte; D_Mode: Boolean; Byte_Index: Byte);
   var Idx : Byte;
       Blink_Offset: Byte;
   begin
    Blink_Offset := 0;
    Set_Text_Win;
    if D_Mode = False then                   {Fehler beim Datenlesen: Lîsche}
     begin
      for Idx := 0 to 7 do
       begin
         GotoXY(D_Spalte, D_Zeile);
         TextColor(Red);
         Write ('F');
         D_Zeile := D_Zeile + 1;
       end;
     end
    else
     begin                       {kein Fehler beim Datenlesen: Bits anzeigen!}
      for Idx := 0 to 7 do
       begin
        Blink_Offset := 0;
        GotoXY(D_Spalte, D_Zeile);

       {Vergleiche alte Statusbits mit neuem Wert, bei énderung Error-Bit setzen}
       {Falls neues Bit=1 and altes Bit=0, oder neues Bit=0 and altes Bit=1}
       if Stat_Valid then     {nur wenn Vergleichsdaten vorliegen: auswerten}
        begin
         if not (((BitTst(D_Byte,Idx) and BitTst(Stat_Old_Bytes[Byte_Index],Idx)))
                or
                (not BitTst (D_Byte,Idx) and not BitTst(Stat_Old_Bytes[Byte_Index],Idx)))
         then Stat_Err_Ary[Byte_Index,Idx] := True;
         if Stat_Err_Ary[Byte_Index,Idx] then Blink_Offset := 128;
        end;
{xxx}
       if BitTst (D_Byte, Idx) then
        begin
          TextColor(Blue+Blink_Offset);
          Write ('1');                      {kein Fehler}
        end
       else
        begin
          TextColor(Red+Blink_Offset);      {Fehler}
          Write ('0');
        end;  {Bit 0/1}

       D_Zeile := D_Zeile + 1;
      end;   {for}
    Stat_Old_Bytes[Byte_Index] := D_Byte; {Save neuen Wert zum nÑchsten Vergleich}
    if Byte_Index=Stat_Byte_Max then Stat_Valid:=True; {Vergleich erst, wenn 3x8Bit gespeichert}
   end; {D_Mode}
 end; {Displ_Stat_Bits}

   procedure Ini_Stat_Win;
   begin                             {Definitionen gelten bis neu definiert}
    Window(1, 1, 80, 2);             {Definiert ein Textfenster: Spalte/Zeile}
    TextBackground(Magenta);         {Setze Hintergrund fÅr Textfenster}
    TextColor(Yellow);               {Setze Schriftfarbe}
    ClrScr;                          {Clear Window}
    GotoXY(1, 1);                    {Cursor auf Anfang Fenster}
   end;

  procedure Slow_Key;
   var Zeichen : Char;
   begin
     repeat
      if KeyEpressed then
       begin
         Zeichen := NewReadKey;
         if Zeichen = #0 then Zeichen :=NewReadKey;
       end;
     until not KeyEpressed;
   end;

 procedure Displ_FTasten;
  begin
   Set_TastMag_Win;
   TextColor(Yellow);
   GotoXY(01, 01); Write('F1:Res ', 'F4:Last   ', 'F7:SW 0.0   ', 'F10:Adr  ');
   GotoXY(01, 02); Write('F2:Ein ', 'F5:+/-    ', 'F8:SW V/A/H ', 'F11:Quick');
   GotoXY(01, 03); Write('F3:Aus ', 'F6:SW 5.0 ', 'F9:FG Rampe ', 'F12:Init');
   TextColor(Black);
   Set_Text_Win;
  end;

{
   GotoXY(01, 01); Write('F1:Res ',  ' F4:+    ', 'F7:SW 0.0  ',  ' F10:Adr   ');
   GotoXY(01, 02); Write('F2:Ein ',  ' F5:-    ', 'F8:SW V/A/H',  ' F11:Quick ');
   GotoXY(01, 03); Write('F3:Aus ',  ' F6:Last ', 'F9:FG Rampe',  ' F12:Init');
}



  procedure Ini_Stat_Ary;
   var N, M : Word;
   begin
     for N := 0 to Stat_Byte_Max do
      begin
       Stat_Old_Bytes[N] := 0;
       for M := 0 to Err_Bits_Max do Stat_Err_Ary[N,M] := False;
      end;
   end;

 procedure Run_Tab (Tab_Num: Word);  {Tabellen in Lib: hier nur SIS-HF zulassen}
  begin
     case Tab_Num of
{       1 : Status_Tab1  (Spalte_Start, Zeile_Start);
       2 : Status_Tab2  (Spalte_Start, Zeile_Start);
       3 : Status_Tab3  (Spalte_Start, Zeile_Start);
       4 : Status_Tab4  (Spalte_Start, Zeile_Start);
       5 : Status_Tab5  (Spalte_Start, Zeile_Start);
       6 : Status_Tab6  (Spalte_Start, Zeile_Start);
       7 : Status_Tab7  (Spalte_Start, Zeile_Start);
       8 : Status_Tab8  (Spalte_Start, Zeile_Start);
       9 : Status_Tab9  (Spalte_Start, Zeile_Start);
      $A : Status_TabA  (Spalte_Start, Zeile_Start);
      $B : Status_TabB  (Spalte_Start, Zeile_Start);
      $C : Status_TabC  (Spalte_Start, Zeile_Start);
      $D : Status_TabD  (Spalte_Start, Zeile_Start);
      $E : Status_TabE  (Spalte_Start, Zeile_Start);
}
      $F : Status_TabF  (Spalte_Start, Zeile_Start);
{     $10: Status_Tab10 (Spalte_Start, Zeile_Start);
      $11: Status_Tab11 (Spalte_Start, Zeile_Start);
      $12: Status_Tab12 (Spalte_Start, Zeile_Start);
      $13: Status_Tab13 (Spalte_Start, Zeile_Start);
}    end; {case}
  end; {Run_Tab}

 begin                 {Ab hier: MainBody Mil_Stat_Tab}
  Cursor(False);
  Stat_Valid    := False;  {Noch kein Status gelesen}
  Interl_Old    := False;
  Interl_Ini    := True;   {Interlock-Status ist im INIT-Mode}
  Err_Stat_Intrl:= False;
  Single_Step   := True;
  SW_Act        := 0;

  Ini_Stat_Ary;         {Init Status-Error-Bits und Status-Old-Arrray}
  GotoXY(Spalte_Start+01, Zeile_Start);
  Mil_Ask_Ifc;

  Fct.B.Adr := Ifc_Test_Nr;
  Ini_Stat_Win;
  Write(Stat_Line);
  Ini_Text_Win;
  TextColor(Brown);
  GotoXY(07, 01); Write ('Tabellen mit Belegungen der STATUS-Bits fÅr Funktionscodes C0, C1, C2 ');
  TextColor(Yellow);
  GotoXY(07, 02); Write ('Hinweis: Die Bit-Anzeige 0/1 wird ROT, falls der Status sich Ñndert!! ');
  TextColor(Black);

     Ini_Msg_Win;
     Write ('Weiter mit   <CR> ');
     Ch := NewReadKey;
{
  GotoXY(01, 03);
  Write   ('    01 : SIS-Magnete SVE (JÑger) ');  Write ('['); TextColor (Red);
                                          Write('Standard');   TextColor (Black);  Writeln (']');
  Writeln ('    02 : Tekelec-Umlenker   (grÅn) EH-Keller (MU) ');
  Writeln ('    03 : Tekelec-NetzgerÑte (grÅn) LSB4          ');
  Writeln ('    04 : Danfysik-NetzgerÑte EH- u. HLI-Keller   ');
  Writeln ('    05 : AEG SVE 1:  SIS                         ');
  Writeln ('    06 : AEG SVE 2:  SIS                         ');
  Writeln ('    07 : AEG SVE 1, 2, 3:     ESR                ');
  Writeln ('    08 : SVE 5, 6, 7, 10, 12: ESR                ');
  Writeln ('    09 : SVE 4, 9:            ESR                ');
  Writeln ('    0A : SVE 2 - H; 3 - H                        ');
  Writeln ('    0B : SVE Brucker mit Einschub                ');
  Writeln ('    0C : SVE Brucker 8-Bit-Stat (Steerer H,V usw)');
  Writeln ('    0D : EZR-MV (Microwelle)                     ');
  Writeln ('    0E : Hochspannung                            ');
  Writeln ('    0F : HF: SIS + ESR                           ');
  Writeln ('    10 : 8-Bit-Status o. Schaltkarte             ');
  Writeln ('    11 : Phasensonden (DPX)                      ');
  Writeln ('    12 : SIS-Magnet S11MU3R (JÑger)              ');
  Writeln ('    13 : SIS + ESR mit DAC (Fîldi)               ');

  GotoXY(05, 22); TextColor(Brown);
  Write ('Welche Status-Tabelle anzeigen ?');
  GotoXY(50, 08);  write('Belegung Funktionstasten: '); TextColor(Black);
  Displ_FTasten_Liste;

  if not (Ask_Hex_Break (Tab_Nr, Byt)) then goto 99;
  if Tab_Nr in [1..Tab_Max] then Run_Tab (Tab_Nr) else goto 99;
}
       Tab_Nr := $0F;   {FÅr SIS-Hf}
       Run_Tab (Tab_Nr);

  Ini_IstwMag_Win;
  Ini_TastMag_Win;
  Transf_Cnt := 0;
  Timout_Cnt := 0;
  SW_Valid   := False;           {User hat noch keinen Sollwert definiert}
  Loop_Wait  := Loop_Wait1;
  Rampe_On   := False;
  Single_Step := True;
  Displ_FTasten;

  repeat
    repeat
     Set_Text_win;
     Fct.B.Fct := Fct_Rd_Stat0;   { Lese C0-Status und zeige in bitweise an }
     Mil.Rd (read_data, Fct, MilErr);
     if MilErr <> No_Err then
      begin
        Mode_Act   := False;
        Timout_Cnt := Timout_Cnt +1;
      end
     else
      begin  {kein Timeout}
        Mode_Act := True;
        {Hier ÅberprÅfen, ob IFK-Return-Adr = Solladr! Tîdlicher Fehler!!}
        if Lo (Read_Data) <> Lo (Fct.B.Adr) then
         begin
           Ini_Err_Win;
           Write ('ERROR: Antwort v. falscher IFK-Adr!  '); TextColor(Yellow+128);
           Write('Soll: ', Hex_Byte(Fct.B.Adr),'[H]  Ist: ', Hex_Byte(Lo(Read_Data)),'[H]');
           TextColor(Red); Write ('  [W]eiter E[x]it');
           repeat
            repeat until KeyEPressed;
             begin
              Ch := NewReadKey;
              if Ch in  ['x','X'] then Exit;
              if Ch = #0 then
               begin
                 Ch := NewReadKey;
                 case ord (Ch) of
                   Taste_F10: begin
                                Slow_Key;
                                if Ask_Hex_Break (Adress, Byt) then
                                  begin
                                   Ifc_Test_Nr := Adress;
                                   Fct.B.Adr   := Ifc_Test_Nr;
                                   Ini_Stat_Win;
                                   Write(Stat_Line);
                                   Run_Tab (Tab_Nr);
                                   Std_Msg;
                                  end;
                              end; {Taste_F10}
                 end; {case}
                end; {Ch=0}
             end;
           until Ch in ['w','W'];
           Std_Msg;
         end;

        Data_Act := Read_Data shr 8;
      end;

{xxx Data_Act := $A5; testweise}
     Byte_Act  := 0;                 {Byte-Markierung}
     Zeile_Act := 01;
     Spalte_Act:= 02;
     Displ_Stat_Bits (Spalte_Act,  Zeile_Act, Data_Act, Mode_Act, Byte_Act);

                { Lese C1-Status und zeige in bitweise an }
     Fct.B.Fct := Fct_Rd_Stat1;
     Mil.Rd (read_data, Fct, MilErr);
     if MilErr <> No_Err then
      begin
        Mode_Act := False;
        Timout_Cnt := Timout_Cnt +1;
      end
     else
      begin  {kein Timeout}
        Mode_Act := True;
        {Hier ÅberprÅfen, ob IFK-Return-Adr = Solladr! Tîdlicher Fehler!!}
        if Lo (Read_Data) <> Lo (Fct.B.Adr) then
         begin
           Ini_Err_Win;
           Write ('ERROR: Antwort v. falscher IFK-Adr!  '); TextColor(Yellow+128);
           Write('Soll: ', Hex_Byte(Fct.B.Adr),'[H]  Ist: ', Hex_Byte(Lo(Read_Data)),'[H]');
           TextColor(Red); Write ('  [W]eiter E[x]it');
           repeat
            repeat until KeyEPressed;
             begin
              Ch := NewReadKey;
              if Ch in  ['x','X'] then Exit;
              if Ch = #0 then
               begin
                 Ch := NewReadKey;
                 case ord (Ch) of
                   Taste_F10: begin
                                Slow_Key;
                                if Ask_Hex_Break (Adress, Byt) then
                                  begin
                                   Ifc_Test_Nr := Adress;
                                   Fct.B.Adr   := Ifc_Test_Nr;
                                   Ini_Stat_Win;
                                   Write(Stat_Line);
                                   Run_Tab (Tab_Nr);
                                   Std_Msg;
                                  end;
                              end; {Taste_F10}
                 end; {case}
                end; {Ch=0}
             end;
           until Ch in ['w','W'];
           Std_Msg;
         end;
        Data_Act := Read_Data shr 8;
      end;
    Byte_Act  := 1;                 {Byte-Markierung}
    Zeile_Act := 10;
    Spalte_Act:= 02;
    Displ_Stat_Bits (Spalte_Act,  Zeile_Act, Data_Act, Mode_Act, Byte_Act);

                { Lese C2-Status und zeige in bitweise an }
     Fct.B.Fct := Fct_Rd_Stat2;
     Mil.Rd (read_data, Fct, MilErr);
     if MilErr <> No_Err then
      begin
        Mode_Act := False;
        Timout_Cnt := Timout_Cnt +1;
      end
     else
      begin  {kein Timeout}
        Mode_Act := True;
        {Hier ÅberprÅfen, ob IFK-Return-Adr = Solladr! Tîdlicher Fehler!!}
        if Lo (Read_Data) <> Lo (Fct.B.Adr) then
         begin
           Ini_Err_Win;
           Write ('ERROR: Antwort v. falscher IFK-Adr!  '); TextColor(Yellow+128);
           Write('Soll: ', Hex_Byte(Fct.B.Adr),'[H]  Ist: ', Hex_Byte(Lo(Read_Data)),'[H]');
           TextColor(Red); Write ('  [W]eiter E[x]it');
           repeat
            repeat until KeyEPressed;
             begin
              Ch := NewReadKey;
              if Ch in  ['x','X'] then Exit;
              if Ch = #0 then
               begin
                 Ch := NewReadKey;
                 case ord (Ch) of
                   Taste_F10: begin
                                Slow_Key;
                                if Ask_Hex_Break (Adress, Byt) then
                                  begin
                                   Ifc_Test_Nr := Adress;
                                   Fct.B.Adr   := Ifc_Test_Nr;
                                   Ini_Stat_Win;
                                   Write(Stat_Line);
                                   Run_Tab (Tab_Nr);
                                   Std_Msg;
                                  end;
                              end; {Taste_F10}
                 end; {case}
                end; {Ch=0}
             end;
           until Ch in ['w','W'];
           Std_Msg;
         end;
        Data_Act := Read_Data shr 8;
      end;
    Byte_Act  := 2;                 {Byte-Markierung}
    Zeile_Act := 01;
    Spalte_Act:= 43;
    Displ_Stat_Bits (Spalte_Act,  Zeile_Act, Data_Act, Mode_Act, Byte_Act);

    Life_Sign (Norm);
    TextColor(Black);
    GotoXY (S_RdErr,Z_SW); Write (Timout_Cnt:7);

            {Lese Summeninterlock aus dem Status-Reg. der IFC}
    Set_Text_Win;
    GotoXY(43, 10); Write ('SUM-IL intern (0-aktiv): ');
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Fct_Rd_Status;
    Mil.Rd (Read_Data, Fct, MilErr);
    if MilErr = No_Err then
     begin                   {énderung des Intrl-Status: mit blink markieren!!}
      if BitTst (Read_Data, 12) then              {Interlock?}
       begin                  {Kein Interlock!!}
        TextColor(Blue);
        if not Interl_Ini then
         begin
          if Interl_Old then  Err_Stat_Intrl:= True;   {vorher war Interlock}
         end;
        If Err_Stat_Intrl then TextColor(Blue+128);    {blinken}
        write(' 1 ');
        Interl_Old := False;
        Interl_Ini := False;  {Nach dem 1. Durchlauf bleibt Status False}
       end
      else
       begin                        {Ja, Interlock-Fall}
         TextColor(Red);
         if not Interl_Ini then
          begin
           if not Interl_Old then Err_Stat_Intrl:= True;  {vorher kein Interl}
          end;
         if Err_Stat_Intrl then TextColor(Red+128);       {mit blinekn}
         write(' 0 ');
         Interl_Old := True;
         Interl_Ini := False;  {Nach dem 1. Durchlauf bleibt Status False}
       end;
     end
    else
     begin
       write('   ');
     end;

    Sonder_Zeichen := chr(124);  {Absolut Zeichen}
    TextColor(Black);

    {Zeige stÑndig auch den Istwert}
    Set_IstwMag_Win;
    TextColor(Brown);
    GotoXY(01, 01); Write ('ISTWERT ->  ');
    GotoXY(13, 01); Write ('IW1 [',hex_byte(Fct_Rd_Ist1),'H]');
    Write ('      IW2 [',hex_byte(Fct_Rd_Ist2),'H]');
    GotoXY(01, 02); Write ('[Hex] : '); ClrEol;
    GotoXY(01, 03); Write ('[Volt]: '); ClrEol;
    GotoXY(01, 04); Write (Sonder_Zeichen);  Write ('Hex-Diff');
                    Write (Sonder_Zeichen);  Write (': '); ClrEol;
    GotoXY(01, 05); Write ('IW1-SW [V]: ');  ClrEol;
    TextColor(Black);

    Fct.B.Fct := Fct_Rd_Ist1;
    Mil.Rd (Word(IW1), Fct, MilErr);   {Lese Istwert}
    if MilErr = No_Err then
     begin
       Fct.B.Fct := Fct_Rd_Ist2;
       Mil.Rd (Word(IW2), Fct, MilErr);   {Lese Istwert}
       GotoXY(15, 02);         Write (Hex_Word(IW1));
       Write ('           ');  Write (Hex_Word(IW2));
       GotoXY(13, 03);         Write_Real_10V_Bipol (IW1);
       Write ('     ');        Write_Real_10V_Bipol (IW2);

       GotoXY(15, 04);
       if SW_Valid = True then
        begin
          Write (Hex_Word (abs(IW1-SW_Act)));
          GotoXY(13, 05);  Write_Real_10V_Bipol(IW1-SW_Act);
        end;
     end; {no error}  {Ende: Set_IstwMag_Win;}

    Set_Text_Win;
    TextColor(Black);

    if SW_Valid then
     begin
       GotoXY (S_SWH,  Z_SW); Write (Hex_Word(SW_Act));
       GotoXY (S_SWV,  Z_SW); Write_Real_10V_Bipol (SW_Act);
     end
    else
     begin
       GotoXY (S_SWH,  Z_SW); Write ('    ');
       GotoXY (S_SWV,  Z_SW); Write ('         ');
     end;

    if Sw_Amax = 0 then
     begin
       GotoXY (S_SWA,  Z_SW); Write('         ');
       GotoXY (S_SWX,  Z_SW); Write(' undef.');
     end
    else
     begin
       GotoXY (S_SWA,  Z_SW); Write_Real_10A_Bipol (SW_Act);
       GotoXY (S_SWX,  Z_SW); Write (Sw_Amax:7:1);
     end;

    Std_Msg;
    Set_Text_Win;
    Mil.Timer2_Wait (Loop_Wait);
   until KeyEPressed {or (Ch = ' ')};

   if KeyEPressed then Ch := NewReadKey;

   if Ch = ' ' then
     begin
      Std_Msg;
      Life_Sign (Blink);
      repeat until KeyEPressed;
      Single_Step := True;
     end;

   if Ch = Taste_Return then Single_Step := False;
   if Ch = #0 then
    begin
      Ch := NewReadKey;
      case ord (Ch) of
       Taste_F1 : begin
                   Slow_Key;
                   Fct.B.Fct := Fct_Reset;
                   Mil.WrFct (Fct, MilErr);
                   Rampe_On := False;
                   Ini_Err_Win;
                   Write(' RESET');
                   Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                  end;
       Taste_F2 : begin
                   Slow_Key;
                   Fct.B.Fct := Fct_NG_Ein;
                   Mil.WrFct (Fct, MilErr);
                   Ini_Err_Win;
                   Write(' EIN');
                   Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                  end;
       Taste_F3 : begin
                   Slow_Key;
                   Fct.B.Fct := Fct_NG_Aus;
                   Mil.WrFct (Fct, MilErr);
                   Ini_Err_Win;
                   Write(' AUS');
                   Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                 end;
       Taste_F4 : begin
                   Slow_Key;
                   if Get_LastNr (LastNr) then
                    begin
                      case LastNr of
                        0 : Fct.B.Fct := Fct_NG_Last0;
                        1 : Fct.B.Fct := Fct_NG_Last1;
                        2 : Fct.B.Fct := Fct_NG_Last2;
                        3 : Fct.B.Fct := Fct_NG_Last3;
                        4 : Fct.B.Fct := Fct_NG_Last4;
                        5 : Fct.B.Fct := Fct_NG_Last5;
                      end;
                     Mil.WrFct (Fct, MilErr);
                     Ini_Err_Win;
                     Write(' LAST-Nr: ',LastNr);
                     Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                    end;
                   Std_Msg;
                  end;
       Taste_F5 : begin
                   Ini_Msg_Win;
                   Write ('Bitte PolaritÑt eingeben [+/-] : ');
                   Ch := NewReadKey;
                   case Ch of
                   '+' : begin
                          Slow_Key;
                          Fct.B.Fct := Fct_NG_Plus;
                          Mil.WrFct (Fct, MilErr);
                          Ini_Err_Win;
                          Write(' PLUS');
                          Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                         end;
                   '-' : begin
                          Slow_Key;
                          Fct.B.Fct := Fct_NG_Minus;
                          Mil.WrFct (Fct, MilErr);
                          Ini_Err_Win;
                          Write(' MINUS');
                          Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                         end;
                    end; {case}
                   Std_Msg;
                  end;
       Taste_F6 : begin
                   Slow_Key;
                   Fct.B.Fct :=  Fct_Wr_Sw1;
                   Mil.Wr ($4000 , Fct, MilErr);
                   SW_Act := $4000;
                   SW_Valid := True;
                  end; {Taste_F6}
       Taste_F7 : begin
                   Slow_Key;
                   Fct.B.Fct :=  Fct_Wr_Sw1;
                   Mil.Wr (0 , Fct, MilErr);
                   SW_Act := 0;
                   SW_Valid := True;
                  end;

       Taste_F8 : begin
                   Slow_Key;
                    Cursor(True);
                    Ini_Msg_Win;
                    Write ('Sollwert in [V]olt, [H]ex, [A]mpere, [M]axAmp        Bitte Auswahl eingeben: ');
                    repeat until KeyEPressed;
                    Ch := NewReadKey;
                    case Ch of
                     'v','V': begin
                                Sollw.Mode:= V;
                                Sollw.Max := 10.0;
                                if Ask_Sw_Break (Sollw) then
                                 begin
                                  SW_Act := Sollw.User;
                                  Fct.B.Fct :=  Fct_Wr_Sw1;
                                  Mil.Wr (SW_Act , Fct, MilErr);
                                  SW_Valid := True;
                                 end;
                              end;
                     'a','A': begin
                               if Sw_Amax = 0 then
                                begin
                                  Ini_Err_Win;
                                  Write('Achtung: max. Stromsollwert nicht definiert!!   Weiter mit <CR> ');
                                  Ch := NewReadKey;
                                  Ch := '=';   {Dummy}
                                 end
                               else
                                 begin
                                  Sollw.Mode:= A;
                                  Sollw.Max := Sw_Amax;
                                  if Ask_Sw_Break (Sollw) then
                                   begin
                                    SW_Act := Sollw.User;
                                    Fct.B.Fct :=  Fct_Wr_Sw1;
                                    Mil.Wr (SW_Act , Fct, MilErr);
                                    SW_Valid := True;
                                   end;
                                  end;
                              end;
                     'h','H': begin
                                Sollw.Mode:= H;
                                if Ask_Sw_Break (Sollw) then
                                  begin
                                   SW_Act := Sollw.User;
                                   Fct.B.Fct :=  Fct_Wr_Sw1;
                                   Mil.Wr (SW_Act , Fct, MilErr);
                                   SW_Valid := True;
                                  end;
                              end;
                     'm','M': begin                     {maximalen Stromwert definieren}
                                Ini_Msg_Win;
                                Write('max. Strom als Floating-Point Zahl oder <Q + CR> eingeb. [0000.000]: ');
                                {$I-}                    {Fehleingabe zulassen: Compiler-Check ausschalten}
                                Readln (R_Zahl);
                                {$I+}
                                if (IoResult <> 0) then Exit             {Fehler selber abfangen!}
                                else  Sw_Amax := abs (R_Zahl);
                              end;
                    end; {case}

                   if Sw_Amax = 0 then
                    begin
                     GotoXY (S_SWA,  Z_SW); Write('         ');
                     GotoXY (S_SWX,  Z_SW); Write(' undef.');
                    end;

                   if SW_Valid then
                    begin
                      Set_Text_Win;
                      TextColor(Black);
                      GotoXY (S_SWH,  Z_SW); Write (Hex_Word(SW_Act));
                      GotoXY (S_SWV,  Z_SW); Write_Real_10V_Bipol (SW_Act);
                      if Sw_Amax = 0 then
                       begin
                         GotoXY (S_SWA,  Z_SW); Write('         ');
                       end
                      else
                       begin
                         GotoXY (S_SWA,  Z_SW); Write_Real_10A_Bipol (SW_Act);
                         GotoXY (S_SWX,  Z_SW); Write (Sw_Amax:7:1);
                        end;
                     end; {if sw_valid}
                  end; {F8}
       Taste_F9 : begin       {Einfache Rampe fÅr Funktionsgen}
                    FG_Rampe_Fix (Slow);
                    Rampe_On := True;
                    Ini_Err_Win;
                    Write(' START RAMPE +/- 10V Slow');
                    Mil.Timer2_Wait(Wait_Time);          { Wartet mit Timer2}
                    Std_Msg;
                  end;
       Taste_F10: begin
                   Slow_Key;
                   if Ask_Hex_Break (Adress, Byt) then
                     begin
                      Ifc_Test_Nr := Adress;
                      Fct.B.Adr   := Ifc_Test_Nr;
                      Ini_Stat_Win;
                      Write(Stat_Line);
                      Run_Tab (Tab_Nr);
                     end;
                  end; {Taste_F10}
       Taste_F11: begin
                    If Loop_Wait = Loop_Wait1 then Loop_Wait := Loop_Wait2
                    else
                     Loop_Wait := Loop_Wait1;
                  end; {Taste_F11}
       Taste_F12: begin
                   Slow_Key;
                   Stat_Valid := False;  {Noch kein Status gelesen}
                   Ini_Stat_Ary;         {Init Status-Error-Bits und Status-Old-Arrray}
                   {Akt. Interl-Zustand als Referenz fÅr énderungsÅberwachg}
                   Err_Stat_Intrl := False;
                   Fct.B.Adr := Ifc_Test_Nr;
                   Fct.B.Fct := Fct_Rd_Status;
                   Mil.Rd (Read_Data, Fct, MilErr);
                   if BitTst (Read_Data, 12) then
                     Interl_Old := False     {Kein Interlock!!}
                    else
                     Interl_Old := True;     {Interlock!!}

                   Timout_Cnt := 0;
                  end; {Taste_F12}
      end;  {Case}

     if not Single_Step then
      begin
       Life_Sign (Norm);
       Run_Tab (Tab_Nr);
      end;
     Displ_FTasten;
     Std_Msg;
    end; {if Ch = #0 }
  until Ch in ['x','X'];
 99:   Cursor(True);
       if Rampe_On then Stop_Rampe;  {GerÑte im definierten Zustand lassen}
 end; {Mil_Stat_Tabelle}



begin                      { Hauptprogramm HF-Ramp}
  Ifc_Test_Nr := 0;
  Ifc_Ampl_Nr := 0;
  Ifc_Freq_Nr := 0;

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
                 Mil_Stat_Tabelle;
                end;
     'o', 'O' : begin
                 Duo_Rampe;
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
end. {mil_Hfra}

