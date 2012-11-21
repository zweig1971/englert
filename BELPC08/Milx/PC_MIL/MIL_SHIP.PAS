program Mil_Ship;                  {Programm MIL_SHIP.PAS mit Unit DATECH.PAS}
{ Autor: Gerhard Englert                              Turbo-Pascal Version 7.0
  17.01.94 Et    Umstellung auf neue DATECH-Version ohne Mil_Lib
  08.02.94       Umstellung  Rd_Istwert, Ersatz v. PCMil.xxx durch Mil.xxx
  28.02.94       Zeitanzeige Formieren statt 100 jetzt 1 sec
}
{$S-}
uses Crt, WinDos, Datech;

const
 Head_Line =
      'Datentechnik                        MIL-PC   ' +
      '                       [28.02.1994]'+
      '                       SHIP-SERVICE   [IFC-Karte FG 429.044]        ';

 DevMax    = 16;    {z.Zt. 15, vorsorglich auf 16 GerÑte: Magnete u. Hochspg.}
 SwTabMax  = 16;                                {maximal 16 Sollwert-Tabellen}
 IwMax     = $7FFF;                                  {maximaler Istwert BinÑr}
 SwMaxTime = 30;             {Formieren: Max. Sollwert 30 sec stehen gelassen}
 FormierStepMax  = 10;                                {Anzahl Formierschritte}
 FormierSecClk   = 100000;                                             {1 sec}
 FormierStepTime = 100000; {1 sec }       {Zeitschritt zum Formieren in 10 us}
 FormierDispTime = 100000; {1 sec }
 Adr_Fname = 'C:\SHIP_ADR.TAB';
 Sw_Fname  = 'C:\SHIP_SW.TAB';   {Filenames}

type
 Str4    = string[4];
 Str8    = string[8];
 Num_Str = string[10];

 TFormParam = record
               Adr : Byte;
               MaxWert: Integer;
              end;

 TStatDisp= record
             DevAdr  : Byte;
             DispMode: (Einzel, Alle);
            end;

 TDevAdr  = record
              Adr     : Byte;       {IFC-Adresse}
              Nomen   : string[8];  {Nomenklatur}
              MaxWert : Integer;    {Maximale physikalische Einheit 300 Volt}
              PhysEinh: string[2];  {Physikalische Ma·einheit z.B. kV, mA}
            end;
 TDevAdr_Ary  = array [1..DevMax] of TDevAdr;
 TFile_DevAdr = file of TDevAdr_Ary;

 TSwTab      = record
                Name  : string[8];
                SwAry : array [1..DevMax] of Integer;
               end;
 TSwTabAry   = array [1..SwTabMax] of TSwTab;    {maximal 16 Sollwert-Tabellen}
 TFile_SwTab = file of TSwTabAry;

var
 Mil        : T_Mil;               {Type OBJECT: in Unit Datech.pas definiert}
 AdrTab     : TDevAdr_Ary;
 AdrFile    : TFile_DevAdr;
 SwTab      : TSwTabAry;
 SwFile     : TFile_SwTab;
 ValSwTab   : TSwTab;            {Aktuelle Sollwert-Tabelle: Arbeitstabelle}
 AktSwTab   : Byte;              {Aktuelle Sollwert Tabellen-Nr}
 ifb_online : ARRAY[1..255] OF BOOLEAN;

 ifc_test_nr: Byte;
 Loop       : Boolean;
 User_Input : Char;
 I,N        : Byte;

  StatC0 : record case Byte of          {1 = ok, 0 = Error!}
            1: ( Lbyte : set of
                  (Ng,           {Bit0}
                   Uspg,
                   Temp,
                   Frei03,
                   Ustrm,
                   Frei05,
                   TLast,
                   Frei07);      {Bit7}
                  );
            2: ( w: WORD;);
           end;

  StatC1 : record case Byte of
            1: ( Lbyte : set of
                  (Frei10,       {Bit0}
                   Frei11,
                   Frei12,
                   TrErr,
                   Frei14,
                   Frei15,
                   Bereit,
                   Erde);        {Bit7}
                  );
            2: ( w: WORD;);
           end;

  StatC3 : record case Byte of
            1: ( Lbyte : set of
                  (RH,           {Bit0}
                   Frei31,
                   Frei32,
                   Frei33,
                   Frei34,
                   Frei35,
                   Frei36,
                   Frei37);      {Bit7}
                  );
            2: ( w: WORD;);
           end;

FUNCTION menue_win: CHAR;
VAR answer: CHAR;
begin
  Ini_Headl_Win;
  Write(head_line);
  Ini_Text_Win;
  GotoXY(12, 03);
  Writeln('*********************  TEST-MENUE  *********************** ');
  GotoXY(12, 05);
  Writeln('[0]<-- Welche IFC am MIL-Bus?          PrÅfe IFC-Adr -->[A]');
  GotoXY(12, 06);
  Writeln('[1]<-- Anzeigen     IFC-Adr + Nomenklatur     éndern -->[B]');
  GotoXY(12, 07);
  Writeln('[2]<-- Anzeigen       Sollwert-Tabellen       éndern -->[C]');
  GotoXY(12, 08);
  Writeln('[3]<-- Anzeigen Istw     EinzelgerÑt    Sollw éndern -->[D]');
  GotoXY(12, 09);
  Writeln('[4]<-- Einzel       Istwert+Status anzeigen     Alle -->[E]');
  GotoXY(12, 10);
  Writeln('[5]<-- Einzel             Formieren             Alle -->[F]');
  GotoXY(12, 11);
  Writeln('[6]<-- Einzel       GerÑte auf Null setzen      Alle -->[G]');
  GotoXY(12, 12);
  Writeln('                                                           ');
  GotoXY(12, 13);
  Writeln('         [K]<--  GerÑte nach Sollwert-Tabelle setzen     ');
  GotoXY(12, 14);
  Writeln('         [L]<--  Aktuelle Sollwert-Tabelle neu wÑhlen    ');
  GotoXY(12, 15);
  Writeln('         [M]<--  Zahlenformat 0..10.000 anzeigen         ');
  Ini_Msg_Win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
  Answer := Readkey;
  if answer in ['0'..'9','A'..'N','a'..'n','x','X'] then
   menue_win := answer;
 end; {menue_win}

 PROCEDURE mil_detect_ifc;
  CONST start_zeile = 3;
  VAR ifc_total  : WORD;
      ifb_online : ARRAY[1..255] OF BOOLEAN;
      ifb_adr    : WORD;
      zeile      : BYTE;
      hex_str    : STRING[10];
      i          : WORD;
      ch         : Char;

  Begin
   ifc_total := 0;
   ini_msg_win;
   GotoXY(1, 1);
   write('Bitte warten. IFC-Karten am Mil-Bus werden gesucht!');

   FOR ifb_adr := 1 TO 255 DO                                 { Clear Array }
     ifb_online[ifb_adr] := FALSE;

   FOR ifb_adr := 1 TO 255 DO                 { Fill Array with actual data }
    Begin
     IF Mil.Ifc_Online (Ifb_Adr) THEN
      Begin
       ifb_online[ifb_adr] := TRUE;
       ifc_total := ifc_total + 1;
      End;
   End; {FOR}
   zeile := start_zeile;
   i := 0;
   ini_text_win;
   GotoXY(1, start_zeile - 1);
   write('              Am MIL-Bus melden sich folgende IFC-Karten: ');
   FOR ifb_adr := 1 TO 255 DO
     Begin
       IF ifb_online[ifb_adr] THEN
         Begin
          i := i + 1;
          GotoXY(5, zeile);
          hex_str := hex_byte(ifb_adr);
          write('Activ: ',ifb_adr:3,'  ',hex_str,' [Hex]'); ClrEol;
          IF (i > 15)  THEN
            Begin
              ini_err_win;
              GotoXY(1, 1);
              write('Mehr als 15 Karten!!    Any key to go on!');
              ch := READKEY;
              FOR zeile := start_zeile TO start_zeile + 16 DO
                Begin  GotoXY(1, zeile); ClrEol; End;
              zeile := start_zeile;
            End;
          zeile := zeile + 1;
         End;
     End;
   ini_msg_win;
   write('IFC-Karten total: ',ifc_total,'                               Weiter mit beliebiger Taste!');
   ch := READKEY;
  End; {detect_ifc}

procedure Disp_Ifc_Nomen;
var M, ZStart : Byte;
 begin
  ZStart := 3;
  Ini_Text_Win;
  GotoXY(03,01);
  Writeln('  Inhalt des Files: ',Adr_Fname);
  Writeln(' Num IFC-Adr[Hex]  Nomenklatur  MaxWert ');
  Writeln(' ---------------------------------------- ');
  for M := 1 to DevMax do
   begin
      GotoXY(03, M+ZStart); Write(M:2);
      if AdrTab [M].Adr <> 0 then
       begin
        GotoXY(11, M+ZStart); Write(Hex_Byte(AdrTab [M].Adr));
        GotoXY(21, M+ZStart); Write(AdrTab [M].Nomen);
        GotoXY(32, M+ZStart); Write(AdrTab [M].MaxWert:4);
        GotoXY(38, M+ZStart); Write('[  ]');
        GotoXY(39, M+ZStart); Write(AdrTab [M].PhysEinh);
       end;
   end;
 end;

procedure Ship_Nomen;
label 1;
const ZStart = 3;
var I : Word;
    Index_Ok : Boolean;
    Num : Byte;
    Ch  : Char;
    Ifc_Adr : Byte;
    File_Ok : Boolean;

begin
  File_Ok := False;
  I := 0;
  Assign (AdrFile, Adr_Fname);
  {$I-}                            {Compiler Check aus, Error selber abfangen}
  Reset(AdrFile);
  {$I+}
  if IoResult <> 0 then                             {PrÅfe, ob File existiert}
    begin
     Ini_Text_Win;
     Ini_Err_Win;
     Write('ERROR: Datei ',Adr_Fname,' nicht gefunden. Leere Datei anlegen? [J/N]: ');
     if ReadKey in ['j','J'] then
      begin
       for I := 1 to DevMax do                        {Init fÅr Tabelle}
         begin
           AdrTab [I].Adr     := I;
           AdrTab [I].Nomen   := 'Y_______';
           AdrTab [I].MaxWert := 0;
           AdrTab [I].PhysEinh:= ' A';
        end;
        ReWrite(AdrFile);                        {existiert nicht: File erzeugen}
        Write(AdrFile,AdrTab);                   {Tabelle in File speichern}
        Close(AdrFile);
        File_Ok := True;
       end; {if j}
    end
   else
    begin
     Read (AdrFile, AdrTab);                   { File existiert: Lese Tabelle}
     Close(AdrFile);
     File_Ok := True;
    end;

  if loop then     {Ñndern}
   begin
     if not File_Ok then Goto 1;               {Abbrechen}
     Disp_Ifc_Nomen;
     repeat
      Num:= 0;
      Ini_Msg_Win;
      Write('Welche Zuordnung Ñndern? Bitte Nummer eingeben oder [Q]uit: ');
      {$I-}                            {Compiler Check aus, Error selber abfangen}
      Readln(Num);
      {$I+}
      if IoResult <> 0 then Goto 1;

      if not (Num in [1..DevMax]) then
       begin
        Index_Ok := False;
        Ini_Err_Win;
        Write('Num nicht im erlaubten Bereich 1..',DevMax,'! Weiter mit beliebiger Taste oder [Q]uit: ');
        Ch := ReadKey;
        if Ch in ['q','Q'] then Goto 1;
       end
      else
        Index_Ok := True;
     until Index_Ok;

     Ini_Msg_Win;
     Write('Aktuelle Adr = ',Hex_Byte(AdrTab [Num].Adr),' [Hex]               éndern? [J/N/(Q)uit]: ');
     Ch := Readkey;
     if Ch in ['q','Q'] then Goto 1;
     if Ch in ['j','J'] then
       begin
        Set_Text_Win;
        GotoXY(1,22);  ClrEoL;
        Write('Neue Adresse eingeben!');
        Ini_Msg_Win;
        Ifc_Adr := Ask_Hex_Byte;
        AdrTab [Num].Adr := Ifc_Adr;
       end;

     Ini_Msg_Win;
     Write('Aktuelle Nomenklatur = ',AdrTab [Num].Nomen,'           éndern? [J/N/(Q)uit]: ');
     Ch := Readkey;
     if Ch in ['q','Q'] then Goto 1;
     if Ch in ['j','J'] then
       begin
        Set_Text_Win;
        GotoXY(1,22);  ClrEoL;
        Ini_Msg_Win;
        Write('Bitte neue Nomenklatur eingeben: ');
        Readln(AdrTab [Num].Nomen);
       end;

     Ini_Msg_Win;
     Write('Aktueller MaxWert = ',AdrTab [Num].MaxWert:4,'           éndern? [J/N/(Q)uit]: ');
     Ch := Readkey;
     if Ch in ['q','Q'] then Goto 1;
     if Ch in ['j','J'] then
       begin
        Set_Text_Win;
        GotoXY(1,22);  ClrEoL;
        Ini_Msg_Win;
        Write('Bitte neuen MaxWert eingeben: ');
        Readln(AdrTab [Num].MaxWert);
       end;

     Ini_Msg_Win;
     Write('Aktuelle physikalische Einheit = ',AdrTab [Num].PhysEinh,'           éndern? [J/N/(Q)uit]: ');
     Ch := Readkey;
     if Ch in ['q','Q'] then Goto 1;
     if Ch in ['j','J'] then
       begin
        Set_Text_Win;
        GotoXY(1,22);  ClrEoL;
        Ini_Msg_Win;
        Write('Bitte neue physikal. Einheit eingeben: ');
        Readln(AdrTab [Num].PhysEinh);
       end;
      Disp_Ifc_Nomen;
      Ini_Msg_Win;
      Write('Soll geÑnderte Tabelle SHIP_ADR.TAB auf Disk abgespeichert werden?  [J/N]: ');
      Ch := Readkey;
      if Ch in ['j','J'] then
       begin                               {Tabelle auf File schreiben!}
        ReWrite(AdrFile);                  {ôffne File fÅr Schreiben}
        Write(AdrFile,AdrTab);            {Daten zum File}
        Close(AdrFile);                    {File schlie·en}
        Goto 1;
       end
      else
        Goto 1;
     end    {if loop}
   else    {loop=false}
    begin  {nur anzeigen, nicht Ñndern}
     if not File_Ok then Goto 1;
     Disp_Ifc_Nomen;
     Ini_Msg_Win;
     Write('Weiter mit beliebiger Taste!! ');
     ReadKey;
    end; {if loop}
1:
end; {ship_ifc_nomen}

function Ship_Rd_AdrTab: BOOLEAN;              {Lese Adressentabelle von Disk}
begin
  Assign (AdrFile, Adr_Fname);     { Adressen_File îffnen und lesen}
  {$I-}                            {Compiler Check aus, Error selber abfangen}
  Reset(AdrFile);
  {$I+}
  if IoResult <> 0 then                             {PrÅfe, ob File existiert}
    begin
     Ship_Rd_AdrTab := False;
     Ini_Err_Win;
     Write('ERROR: File ',Adr_Fname,'  nicht gefunden. Weiter mit beliebiger Taste! ');
     ReadKey;
    end
   else
    begin
     Ship_Rd_AdrTab := True;
     Read (AdrFile, AdrTab);                   { File existiert: Lese Tabelle}
     Close(AdrFile);
    end;
end; {Ship_Rd_AdrTab}

 procedure Disp_Sw_Tab (TabNr: Word);
  const ZStart = 3;
  var x    : Word;
      Param: TRealSw;
  begin
   Ini_Text_Win;
   GotoXY(05,1);
   Writeln('        Sollwert-Tabelle: ',SwTab[TabNr].Name);
   Writeln(' Num     Sollwert     Maxwert IFC-Adr[Hex] Nomenklatur ');
   Writeln(' ----------------------------------------------------- ');
   for X := 1 to DevMax do
    begin
      GotoXY(03, X+ZStart); Write(X:2);
      if  AdrTab [X].Adr > 0 then         {Nur anzeigen bei IFC-Adr > 0}
       begin
        Param.Sw   := SwTab[TabNr].SwAry[X];
        Param.Maxw := AdrTab [X].MaxWert;
        GotoXY(08, X+ZStart); Write_Real_Sw (Param);
        GotoXY(17, X+ZStart); Write('[  ]');
        GotoXY(18, X+ZStart); Write(AdrTab [X].PhysEinh);
        GotoXY(25, X+ZStart); Write(AdrTab [X].MaxWert);
        GotoXY(36, X+ZStart); Write(Hex_Byte(AdrTab [X].Adr));
        GotoXY(46, X+ZStart); Write(AdrTab [X].Nomen);
       end;
    end; {for}
  end; {disp_Sw_Tab}

function Ship_Rd_SwTab: BOOLEAN;              {Lese Sollw-Tabellen von Disk}
var I,N : Byte;
begin
  Assign (SwFile, Sw_Fname);
  {$I-}                            {Compiler Check aus, Error selber abfangen}
  Reset(SwFile);
  {$I+}
  if IoResult <> 0 then                       {PrÅfe, ob File existiert}
    begin
     Ship_Rd_SwTab:= False;
     Ini_Err_Win;
     Write('ERROR: File ',Sw_Fname,' nicht gefunden. Leere Datei anlegen? [J/N]: ');
     if ReadKey in ['j','J'] then
      begin
       ReWrite(SwFile);                         {existiert nicht: File erzeugen}
       for N := 1 to SwTabMax do                {Init alle Tabelllen}
        begin
         SwTab[N].Name    := 'NoName';
         for I := 1 to DevMax do                 {Init alle Sollwerte}
           SwTab[N].SwAry[I]  := 0;
        end;
        SwTab[1].Name    := 'STANDARD';           {Tabelle 1 ist immer Standard}
        Write(SwFile,SwTab);                      {Tabelle in File speichern}
      end; {if ja}
    end
   else
    begin
     Ship_Rd_SwTab:= True;
     Read (SwFile, SwTab);                     { File existiert: Lese Tabelle}
     Close(SwFile);
    end;
end;

procedure Ship_Sollw_Tab;
label 1,2;
const ZStart = 3;
var I,N  : Word;
    Ch,Answer : Char;
    Result: BOOLEAN;
    Param : TRealSw;
begin
  Ini_Text_Win;
  Result:= Ship_Rd_SwTab;
  if not Result then Goto 1;
  Result := Ship_Rd_AdrTab;                            {Lese Adr-Tab von Disk}
  if not Result then Goto 1;                                           {Abort}

  Ini_Text_Win;
  GotoXY(01,2 );
  Write('Die Sollwert-Tabellen sind im File: "',Sw_Fname,'" abgelegt!');
  GotoXY(01,4 );
  Write('v--- Existierende Sollwert-Tabellen ---v ');
  GotoXY(1,5 );
  for N := 1 to SwTabMax do
   begin
     Writeln('         Tabelle [',N:2,']: ', SwTab[N].Name);
   end;

  Ini_Msg_Win;
  Write('Mit <CR> wird STANDARD-Tabelle angezeigt! FÅr andere Tabelle <A> eingeben!');
  N := 1;               {Default ist STANDARD}
  Ch := ReadKey;
  if Ch in ['a','A'] then
   begin          {Neue Tabelle anzeigen}
    Ini_Msg_Win;
    Write('Bitte Tabellen-Nr eingeben [1..',SwTabMax,']: ');
    Readln(N);
    if not (N in [1..SwTabMax]) then
     begin
       Ini_Err_Win;
       Write('ERROR: Tabellen-Nr nicht im zulÑssigen Bereich. Weiter mit beliebiger Taste!');
       ReadKey;
       N := 1;
     end;
   end;

  Disp_Sw_Tab (N);
  if loop then    {Sollwert-Tab Ñndern}
   begin
      Ini_Msg_Win;
      Write('Tabelle Ñndern? [J/N/(Q)uit]: ');
      Answer := ReadKey;
      if Answer in ['q','Q'] then Goto 1;
      if Answer in ['J','j'] then
        begin
         Ini_Msg_Win;
         Write('Tabellen-Namen Ñndern? [J/N]: ');
         Answer := ReadKey;
         if Answer in ['J','j'] then
          begin
           Ini_Msg_Win;
           Write('Bitte neuen Tabellen-Namen eingeben [max. 8 Zeichen]: ');
           Readln(SwTab[N].Name);
          end;
         for I := 1 to DevMax  do
          begin
           Disp_Sw_Tab(N);
           Ini_Msg_Win;
           Write('Der alte Sollwert fÅr GerÑt Nr.[',I:2,'] = ');

           Param.Sw   := SwTab[N].SwAry[I];
           Param.Maxw := AdrTab [I].MaxWert;
           Write_Real_Sw (Param);
           Write('        éndern? [J/N/(E)nde]:');
           Answer := ReadKey;
           if Answer in ['e','E'] then Goto 2;
           if Answer in ['J','j'] then
            begin
               Disp_Sw_Tab(N);
               Ini_Msg_Win;
               Write('Neuer Sollwert fÅr GerÑt Nr.[',I:2,'] = ');
               SwTab[N].SwAry[I] := Rd_Real_Sw(AdrTab [I].MaxWert);
            end;
          end; {for DevMax}

2:        Disp_Sw_Tab(N);
          Ini_Msg_Win;
          Write(' énderungen auf Disk speichern? [J/N]: ');
          Answer := ReadKey;
          if Answer in ['J','j'] then
            begin
              ReWrite(SwFile);                  {ôffne File fÅr Schreiben}
              Write(SwFile,SwTab);                 {Tabelle in File speichern}
              Close(SwFile);
            end;
        end; {Ñndern}
   end  {if loop}
  else            {Sollwert-Tab nur anzeigen}
   begin
    Ini_Msg_Win;
    Write('Weiter mit beliebiger Taste!');
    ReadKey;
   end; {if loop}
1:
end; {Ship_Sollw_Tab}

function Ifc_Nomen: Boolean;
  const ZStart = 3;
  var I : Word;
   begin
    Assign (AdrFile, Adr_Fname);
    {$I-}                            {Compiler Check aus, Error selber abfangen}
    Reset(AdrFile);
    {$I+}
    if IoResult <> 0 then                             {PrÅfe, ob File existiert}
     begin
      Ifc_Nomen := False;
      Ini_Err_Win;
      Write('ERROR: Datei ',Adr_Fname,' nicht gefunden. Weiter mit beliebiger Taste!');
      Ini_Text_Win;
      Readkey;
     end
    else
     begin
      Ifc_Nomen := True;
      Read (AdrFile, AdrTab);                   { File existiert: Lese Tabelle}
      Close(AdrFile);
      Disp_Ifc_Nomen;
     end;
end; {ifc_nomen}

function Rd_Ifc_Nomen: Boolean;
  var I : Word;
   begin
    Assign (AdrFile, Adr_Fname);
    {$I-}                            {Compiler Check aus, Error selber abfangen}
    Reset(AdrFile);
    {$I+}
    if IoResult <> 0 then                             {PrÅfe, ob File existiert}
     begin
      Rd_Ifc_Nomen := False;
     end
    else
     begin
      Rd_Ifc_Nomen := True;
      Read (AdrFile, AdrTab);                   { File existiert: Lese Tabelle}
      Close(AdrFile);
     end;
end; {rd_ifc_nomen}

function Check_Num (Num: Byte): Boolean;
label 1;
var Result : Boolean;
begin                    {PrÅfe, ob Nummer lt. IFC-Nomen-File erlaubt ist}
    Check_Num:= False;
    Result := Rd_Ifc_Nomen;
    if not Result then
     begin
      Ini_Err_Win;
      Write('ERROR: Datei ',Adr_Fname,' nicht gefunden. Weiter mit beliebiger Taste!');
      ReadKey;
      Goto 1;
     end;
    if not (Num in [1..DevMax]) then
      begin
        Ini_Err_Win;
        Write('Nummer nicht erlaubt! Weiter mit beliebiger Taste!');
        ReadKey;
        Goto 1;
      end;
    if (AdrTab[Num].Adr = 0) then
      begin
        Ini_Err_Win;
        Write('ERROR: Lt. Adr-Tab IFC-Adr=0 -> unerlaubte Adresse! Weiter mit beliebig. Taste!');
        ReadKey;
        Goto 1;
      end;
    if not Mil.Ifc_Online (AdrTab[Num].Adr) then
      begin
        Ini_Err_Win;
        Write('GerÑte-Adr: ',Hex_Byte(AdrTab[Num].Adr),' [H] meldet sich nicht am MIL-BUS!  Weiter mit beliebiger Taste!');
        ReadKey;
        Goto 1;
      end;
    Check_Num := True;
1:
end; {Check_Num}

procedure disp_all;
label 1;
var I : LongInt;
    Z_Start: Word;
    Result, Disp_Loop: Boolean;
    RdParam  : TRdData;
    Param    : TRealSw;
    Delta    : Real;
    Sollwert : Integer;
    Ch       : Char;
    Istwert  : Integer;
    Read_Data: Word;
    Fct      : TFct;
    MilErr   : TMilErr;

begin
  Disp_Loop := FALSE;
  if not Rd_Ifc_Nomen then
   begin
     Ini_Err_Win;
     Write('ERROR: Datei ',Adr_Fname,' nicht gefunden. Weiter mit beliebiger Taste!');
     Ini_Text_Win;
     Readkey;
     Goto 1;     {Abort wegen Error}
   end;
            {Lese alle SW-Tabs von Disk, gebe Namen fÅr aktuelle Tab aus}
  Result:= Ship_Rd_SwTab;
  if not Result then Goto 1;
  ini_text_win;
  GotoXY(02,02);
  Writeln('Aktuelle SollWert-Tabelle = ',SwTab [AktSwTab].Name);
  GotoXY(56,02);
  Writeln('v------ Status ------v ');

  GotoXY(1,3 );
  Writeln('Num IFC-Adr[Hex]  Nomenkl. SollWert  IstWert  Abweichg Power  Bereit   R/H   ');
  Writeln(' ----------------------------------------------------------------------------');
  Z_Start := 4;
  RdParam.FctCode:= Fct_Rd_Ist1;   {FunctionCode fÅr Istwert1}
  repeat
   for I := 1 to DevMax do
    begin
     if AdrTab [I].Adr > 0 then             {Null-Adr wird nicht angezeigt}
      begin
       GotoXY(03,Z_Start+I); Write(I:2);
       GotoXY(10,Z_Start+I); Write(Hex_Byte(AdrTab [I].Adr));
       GotoXY(19,Z_Start+I); Write(AdrTab [I].Nomen);

       Param.Sw   := SwTab[AktSwTab].SwAry[I];
       Param.Maxw := AdrTab [I].MaxWert;
       GotoXY(28,Z_Start+I); Write_Real_Sw (Param);

       Fct.B.Adr := AdrTab [I].Adr;
       Fct.B.Fct := Fct_Rd_Ist1;
       Mil.Rd (Read_Data, Fct, MilErr);
       Istwert   := Read_Data;               {wegen Vorzeichen}

       Param.Sw   := Istwert;
       Param.Maxw := AdrTab [I].MaxWert;
       GotoXY(38,Z_Start+I); Write_Real_Sw (Param);

       Sollwert := SwTab[AktSwTab].SwAry[I];
       Delta := ((Istwert-Sollwert)/Sollwert) * 100;
       GotoXY(48,Z_Start+I); Write('       ');            {Lîschen alten Wert}
       GotoXY(48,Z_Start+I); Write(Delta:6:1,'%');

       Fct.B.Fct := Fct_Rd_Stat0; ;                           {Lese Status C0}
       Mil.Rd (Read_Data, Fct, MilErr);
       StatC0.W := Read_Data; ;
       GotoXY(57,Z_Start+I);
       if [Ng] <= StatC0.Lbyte   then Write('Ein') else Write('AUS');

       Fct.B.Fct := Fct_Rd_Stat1;                             {Lese Status C1}
       Mil.Rd (Read_Data, Fct, MilErr);
       StatC1.W  := Read_Data;
       GotoXY(64,Z_Start+I);
       if [Bereit] <= StatC1.Lbyte   then Write('Ja') else Write('Nein');

       Fct.B.Fct := Fct_Rd_Stat3;;                            {Lese Status C3}
       Mil.Rd (Read_Data, Fct, MilErr);
       StatC3.W  := Read_Data;
       GotoXY(71,Z_Start+I);
       if [RH] <= StatC3.Lbyte   then Write('Rechner') else Write('Hand');
      end;
   end; {for}

   if Disp_Loop then                             {Loop}
       begin
        if KeyPressed then Disp_Loop := False;
        for I := 1 to 500000 do ; {Wait}
       end
      else
       begin                  {Einzelschritt}
         Ini_Msg_Win;
         Write('Datenaufnahme angehalten.           Neustart mit Leertaste bzw. [L]oop [Q]uit!');
         Ch := ReadKey;
         if Ch in ['q','Q'] then Goto 1;
         if Ch in ['l','L'] then
          begin
           Disp_Loop := True;
           Ini_Msg_Win;
           Write('Status fÅr GerÑt wird im Loop stÑndig erneuert!  Anhalten mit beliebiger Taste!');
          end;
         Set_Text_Win;
       end;
       Mil.Reset;        {Wegen manueller Unterbrechung: Clear all}
  until 1=2;
1:
end; {disp_all}

procedure Disp_Dev_Status(Param: TStatDisp);
label 1;
const Z_Base    = 8;             {Display Zeilen}
      Z_Bereit  = Z_Base+1;
      Z_Ng      = Z_Bereit+1;
      Z_Istw    = Z_Ng+1;
      Z_RH      = Z_Istw+1;
      Z_NewLine = Z_RH+1;
      Z_Uspg    = Z_NewLine+1;
      Z_Temp    = Z_Uspg+1;
      Z_Ustrm   = Z_Temp+1;
      Z_TLast   = Z_Ustrm+1;
      Z_TrErr   = Z_TLast+1;
      Z_Erde    = Z_TrErr+1;

var RdParam : TRdData;
    Result  : Boolean;
    Disp_Loop : Boolean;
    Spalte, Zeile: Byte;
    SpaltStat : Byte;
    Ch : Char;
    I : LongInt;
    Read_Data: Word;
    Fct      : TFct;
    MilErr   : TMilErr;


 begin
  Disp_Loop := False;
  SpaltStat := 26;             {Displ-Spalte fÅr akt. Status EinzelgerÑt}
  if Param.DispMode = Einzel then
   begin  {Status fÅr einzelnes GerÑt}
    Ini_Msg_Win;
    Write('Status fÅr GerÑt wird im Loop stÑndig erneuert!  Anhalten mit beliebiger Taste!');
    Ini_Text_Win;
    GotoXY(15,01); Write('AusfÅhrlicher GerÑte-Status von IFC-Adr[Hex]: ',Hex_Byte(Param.DevAdr));

    GotoXY(27,03); Write('Fct-Code[H]  Status[H]');
    GotoXY(27,04); Write('----------------------');
    GotoXY(31,05); Write('C0');
    GotoXY(31,06); Write('C1');
    GotoXY(31,07); Write('C3');

    Spalte:= 10;
    GotoXY(Spalte,Z_Bereit); Write('Betriebsbereit: ');
    GotoXY(Spalte,Z_Ng);     Write('Power         : ');
    GotoXY(Spalte,Z_Istw);   Write('Istwert       : ');
    GotoXY(Spalte,Z_RH);     Write('Rechner/Hand  : ');
    GotoXY(Spalte,Z_NewLine);WriteLn;
    GotoXY(Spalte,Z_Uspg);   Write('Unterspannung : ');
    GotoXY(Spalte,Z_Temp);   Write('Temperatur    : ');
    GotoXY(Spalte,Z_Ustrm);  Write('öberstrom     : ');
    GotoXY(Spalte,Z_TLast);  Write('Temperat. Last: ');
    GotoXY(Spalte,Z_TrErr);  Write('Trans. Fehler : ');
    GotoXY(Spalte,Z_Erde);   Write('Erdschlu·     : ');

    Fct.B.Adr := Param.DevAdr;
    repeat
      Fct.B.Fct := Fct_Rd_Stat0;                              {Lese Status C0}
      Mil.Rd (Read_Data, Fct, MilErr);
      StatC0.W := Read_Data;
      GotoXY(43,05); Write(Hex_Byte(StatC0.W));
      GotoXY(SpaltStat,Z_Ng);
      if [Ng] <= StatC0.Lbyte    then Write('Ein') else Write('Aus');
      GotoXY(SpaltStat,Z_Uspg);
      if [Uspg] <= StatC0.Lbyte  then Write('ok') else Write('Error');
      GotoXY(SpaltStat,Z_Temp);
      if [Temp] <= StatC0.Lbyte  then Write('ok') else Write('Error');
      GotoXY(SpaltStat,Z_Ustrm);
      if [Ustrm] <= StatC0.Lbyte then Write('ok') else Write('Error');
      GotoXY(SpaltStat,Z_TLast);
      if [TLast] <= StatC0.Lbyte then Write('ok') else Write('Error');

      Fct.B.Fct := Fct_Rd_Stat1;                              {Lese Status C1}
      Mil.Rd (Read_Data, Fct, MilErr);
      StatC1.W := Read_Data;
      GotoXY(43,06); Write(Hex_Byte(StatC1.W));
      GotoXY(SpaltStat,Z_TrErr);
      if [TrErr] <= StatC1.Lbyte   then Write('ok') else Write('Error');
      GotoXY(SpaltStat,Z_Bereit);
      if [Bereit] <= StatC1.Lbyte  then Write('Ja') else Write('Nein');
      GotoXY(SpaltStat,Z_Erde);
      if [Erde] <= StatC1.Lbyte    then Write('ok') else Write('Error');

      Fct.B.Fct := Fct_Rd_Stat3;                              {Lese Status C3}
      Mil.Rd (Read_Data, Fct, MilErr);
      StatC3.W := Read_Data;
      GotoXY(43,07); Write(Hex_Byte(StatC3.W));
      GotoXY(SpaltStat,Z_RH);
      if [RH] <= StatC3.Lbyte   then Write('Rechner') else Write('Hand   ');

      Fct.B.Fct := Fct_Rd_Ist1;                                {Istwert lesen}
      Mil.Rd (Read_Data, Fct, MilErr);
      GotoXY(SpaltStat,Z_Istw);
      Write('                    ');
      if MilErr = No_Err then
       begin
         GotoXY(SpaltStat,Z_Istw);
         Write_Real_10 (Read_Data); Write(' [Volt]');
       end
      else
       begin
         GotoXY(SpaltStat,Z_Istw);
         Write('Read Error!');
       end;
      if Disp_Loop then                             {Loop}
       begin
        if KeyPressed then Disp_Loop := False;
        for I := 1 to 500000 do ; {Wait}
       end
      else
       begin                  {Einzelschritt}
         Ini_Msg_Win;
         Write('Datenaufnahme angehalten.           Neustart mit Leertaste bzw. [L]oop [Q]uit!');
         Ch := ReadKey;
         if Ch in ['q','Q'] then Goto 1;
         if Ch in ['l','L'] then
          begin
           Disp_Loop := True;
           Ini_Msg_Win;
           Write('Status fÅr GerÑt wird im Loop stÑndig erneuert!  Anhalten mit beliebiger Taste!');
          end;
         Set_Text_Win;
       end;
       Mil.Reset;                   {Wegen manueller Unterbrechung: Clear all}
   until 1=2;
   end    {Status EinzelgerÑt}
  else
   begin  {status fÅr alle GerÑte}
    Ini_Text_Win;
    Disp_All;
   end; {if dispMode alle}
1:
end; {Disp_Dev_Status}

procedure Ship_Disp_Status;
label 1;
var I : Word;
    DispParam : TStatDisp;
    Dev_Adr,Num : Byte;
    DevAdr_Ok, DevOnline_Ok: Boolean;
    Answer  : Char;

begin
   if Loop then   {Status fÅr alle GerÑte anzeigen}
    begin
      DispParam.DevAdr  := 0;
      DispParam.DispMode:= Alle;
      Disp_Dev_Status(DispParam);      {Display-Routine aufrufen}
    end
   else
    begin   {AusfÅhrlichen Status fÅr EinzelgerÑt anzeigen}
     while True do begin
       Ifc_Nomen;                        {Zeige dem User die mîglichen Adressen}
       repeat                            {Device Adr ok}
        DevAdr_Ok    := False;
        GotoXY(1,22);
        Ini_Msg_Win;
        Write('Status von welchem GerÑt? Bitte Nummer eingeben oder [Q]uit: ');
        {$I-}                            {Compiler Check aus, Error selber abfangen}
        Readln(Num);
        {$I+}
        if IoResult <> 0 then Goto 1;
        if  Check_Num (Num) then DevAdr_Ok := True;
      until DevAdr_Ok;

      DispParam.DevAdr  := AdrTab [Num].Adr;
      DispParam.DispMode:= Einzel;
      Disp_Dev_Status(DispParam);
     end; {while}
    end;  {If Loop}
1:
end; {Ship_Disp_Status}

procedure Real_Test;
var Real_Zahl : Real;
    Hex_Zahl  : Word;
    Ch        : Char;
begin
  Ini_Text_Win;
  GotoXY(1,2 );
  Writeln('  Die verwendete ADC/DAC-Karte FG 429.042 verarbeitet +/- 10 Volt als 16 Bit: ');
  Writeln('15 Bit Daten und 1 Bit Vorzeichen. Daraus ergibt sich eine Auflîsung von 305 uV.');
  Writeln(' ');
  Writeln(' ');
  Writeln('     Manuelle Eingaben von Sollwerten in Flie·komma werden intern als ');
  Writeln('     16-Bit Worte gespeichert. Dadurch ergeben sich Rundungsfehler,   ');
  Writeln('     die in der unteren Zeile ÅberprÅft werden kînnen.  ');
  Writeln(' ');

  Ini_Msg_Win;
  Hex_Zahl:= Rd_Real_10;;
  Ini_Msg_Win;
  Write('Die Eingabe war: '); Write_Real_10 (Hex_Zahl);
  Write(' [interne Hex-Zahl: ', Hex_Word(Hex_Zahl),']');
  Write('           Weiter mit [Q]uit:');
  repeat
   ch := ReadKey;
  until ch in ['q','Q'];
end;

procedure Ship_Check_Ifc;
label 1;
const  start_zeile = 5;
  VAR ifc_total  : WORD;
      ifb_adr    : WORD;
      zeile      : BYTE;
      hex_str    : STRING[10];
      M          : WORD;
      ch         : Char;
      Result     : BOOLEAN;
  Begin
   Ifc_Total := 0;
   Ini_Text_win;
   Ini_Msg_Win;
   write('Bitte warten. IFC-Karten am Mil-Bus werden gesucht!');
   for M := 1 to 255 do Ifb_Online[M] := False;                { Clear Array }

   for M := 1 to 255 do                        { Fill Array with actual data }
    begin
     if  Mil.Ifc_Online (M) then
      begin
       ifb_online[M] := TRUE;
       ifc_total := ifc_total + 1;
      end;
     end; {FOR}

  Result := Ship_Rd_AdrTab;                            {Lese Adr-Tab von Disk}
  if not Result then
   begin
     Ini_Err_Win;
     Write('ERROR: Datei ',Adr_Fname,'nicht gefunden. Weiter mit beliebiger Taste! ');
     ReadKey;
     goto 1;
   end;

   ini_text_win;
   Writeln('  Die MIL-BUS Adressen aus der IFC-Adr + Nomenklatur Tabelle werden mit den ');
   Writeln('       am MIL-Bus tatsÑchlich vorhandenen IFC-Karten-Adr verglichen! ');
   Writeln;
   Writeln('  Nomenkl.-Tab   ',Adr_Fname);
   Writeln('    ADR[Hex]       Am  MIL-BUS: ');
   Writeln('  ----------------------------- ');
   for  M := 1 to DevMax do
    begin
     ifb_adr := AdrTab [M].Adr;
     if ifb_adr <> 0 then
       begin
         Write('      ',Hex_Byte(Ifb_Adr));
         if Ifb_Online[Ifb_Adr] then
           Writeln('                vorhanden')
         else
           Writeln('          nicht vorhanden');
       end
    end; {for M}

   ini_msg_win;
   write('Anzahl IFC-Karten am MIL-BUS: ',ifc_total,'               Weiter mit beliebiger Taste!');
   ch := READKEY;
1:
end; {Ship_Check_Ifc}

procedure Ship_Single_Dev;
label 1;
var SwParam : TAdrSw;
    RdParam : TRdData;
    Param   : TRealSw;
    Result  : Boolean;
    Dev_Adr,Num : Byte;
    DevAdr_Ok, DevOnline_Ok: Boolean;
    Answer  : Char;
    I       : LongInt;
    Write_Data: Word;
    Sollwert  : Integer;
    Istwert   : Integer;
    Read_Data : Word;
    Fct       : TFct;
    MilErr    : TMilErr;

begin
     while True do begin                 {for ever}
       Ifc_Nomen;                        {Zeige dem User die mîglichen Adressen}
       repeat                            {Device Adr ok}
        DevAdr_Ok    := False;
        GotoXY(1,22);
        Ini_Msg_Win;
        if Loop then
          Write('Welches GerÑt auf defin. Sollw setzen? Bitte Nummer eingeben oder [Q]uit:')
        else
          Write('Istwert von welchem GerÑt lesen? Bitte Nummer eingeben oder [Q]uit: ');
        {$I-}                            {Compiler Check aus, Error selber abfangen}
        Readln(Num);
        {$I+}
        if IoResult <> 0 then Goto 1;
        if  Check_Num (Num) then DevAdr_Ok := True;
      until DevAdr_Ok;

      Dev_Adr   := AdrTab [Num].Adr;
      Fct.B.Adr := Dev_Adr;
      Fct.B.Fct := Fct_Rd_Ist1;                 {Lese den Istwert des GerÑtes}
      Ini_Msg_Win;
      Write('Der Istwert fÅr GerÑte-Adr [',Hex_Byte(Dev_Adr),'] = ');
      Mil.Rd (Read_Data, Fct, MilErr);

      Param.Sw  := Read_Data;                                        {Istwert}
      Param.Maxw:= AdrTab [Dev_Adr].MaxWert;
      Write_Real_Sw (Param);
      if Loop then                                     {Sollwert Ñndern}
        Write('       Sollwert Ñndern? [J/N/(Q)uit]:')
      else
        begin
          Write('         Weiter mit beliebiger Taste!');
          ReadKey;
          goto 1;
        end;
      Answer := ReadKey;
      if Answer in ['q','Q'] then Goto 1;
      if Answer in ['J','j'] then
        begin
         Ini_Text_Win;
         GotoXY(1,22);  ClrEoL;
         Write('Bitte neuen Sollwert eingeben!');
         Sollwert := Rd_Real_Sw (AdrTab [Dev_Adr].MaxWert);
         Ini_Text_Win;
         Ini_Msg_Win;
         Write('Der neue Sollwert fÅr GerÑt Nr.[',Hex_Byte(Dev_Adr),'] = ');
         Param.Sw   := Sollwert;
         Param.Maxw := AdrTab [Dev_Adr].MaxWert;
         Write_Real_Sw (Param);

         Write('   Wirklich Ñndern? [J/N/(Q)uit]:');
         Answer := ReadKey;
         if Answer in ['q','Q'] then Goto 1;
         if Answer in ['J','j'] then
          begin                             {zeige sollwert + istwert im loop}
            Fct.B.Adr  := Dev_Adr;
            Fct.B.Fct  := Fct_Wr_Sw1;
            Mil.Wr (Sollwert, Fct, MilErr);
            repeat
             Ini_Msg_Win;
             Param.Sw := Sollwert;                          {Sollwert}
             Write('Sollw: ');  Write_Real_Sw (Param);
             Fct.B.Fct := Fct_Rd_Ist1;                      {Lese den Istwert}
             Mil.Rd (Read_Data, Fct, MilErr);
             Param.Sw := Read_Data;
             Write(' Istw: '); Write_Real_Sw (Param);
             Write('        Stop Anzeige-Loop mit beliebiger Taste!');
             for I := 1 to 500000 do ; {Wait}
            until KeyPressed;
          end;   {if j}
        end;
     end;   {while im edit-mode}
1:
end; {Ship_Single_Dev}

procedure  Ship_Sel_SwTab;
label 1;
var Result: Boolean;
    N     : Byte;
begin
  Ini_Text_Win;
  Result:= Ship_Rd_SwTab;
  if not Result then  Goto 1;
  GotoXY(23,02 );
  Write(' Aktuelle Sollwert-Tabelle: ',SwTab[AktSwTab].Name);
  GotoXY(01,4 );
  Write('v--- Existierende Sollwert-Tabellen ---v ');
  GotoXY(1,5 );
  for N := 1 to SwTabMax do
   begin
     Writeln('         Tabelle [',N:2,']: ', SwTab[N].Name);
   end;

  Ini_Msg_Win;
  Write('Andere aktuelle Sollwert-Tabelle wÑhlen?                       [J/N/(Q)uit]: ');
  if ReadKey in ['j','J'] then
   begin
    Ini_Msg_Win;
    Write('Bitte neue Nummer der Sollwert-Tab eingeben [1..',SwTabMax,'] : ');
    Readln(N);
    if N in [1..SwTabMax] then
     begin
      Ini_Msg_Win;
      Write('Neue aktuelle Sollwert-Tab = ',SwTab[N].Name,'        Wirklich Ñndern? [J/N/(Q)uit]: ' );
      if ReadKey in ['j','J'] then AktSwTab := N;
     end;
   end;
1:
end; {Ship_Sel_SwTab}

procedure Formiere_Einzel_Magnet (Num: Byte);
{ Magnet in 60 sec von 0 auf Maxwert fahren , in 10% Schritten
  Danach auf halbem Maxwert stehen lassen. }
label 1;
const steps = 10;
      SwMaxTime = 30;  {Maximaler Sollwert wird 30 sec stehen gelassen}
var I : Integer;
    FormStep: Integer;
    FormSw  : Integer;
    Result  : Boolean;
    SwParam : TAdrSw;
    SkalFact: Real;
    SwStep  : Real;
    SwPhys  : Real;
    Sollwert: Integer;
    RdParam : TRdData;
    Param   : TRealSw;
    Istwert : Integer;
    Fct     : TFct;
    MilErr  : TMilErr;
    RdData  : Word;

    procedure Displ_Istwert;
     begin
       Fct.B.Adr := AdrTab [Num].Adr;
       Fct.B.Fct := Fct_Rd_Ist1;
       Mil.Rd (RdData, Fct, MilErr);
       Istwert := RdData;               {wegen Vorzeichen}
       if MilErr = No_Err then
        begin
         GotoXY(15,11);
         Write('     Istwert : ');  Write_Real_10 (Istwert); Write(' [Volt]');
         Param.Sw   := Istwert;
         Param.Maxw := AdrTab [Num].MaxWert;
         Write('   bzw.  '); Write_Real_Sw (Param); Write(' [Ampere]');
        end
       else
        begin
         GotoXY(15,11);
         Write('     Istwert : ');  Write('Read Error!                     ');
        end;

       Mil.Timer1_Set ($FFFF);               {Warte 0,65 sec}
       repeat  until  Mil.Timeout1;
     end;

begin
  Ini_Text_Win;
  Ini_Msg_Win;
  Write('Wirklich den Magnet formieren ???  [J/N]: ');
  if not (ReadKey in ['j','J']) then goto 1;
  Ini_Msg_Win;
  Write('Sollwert-Sequenz in 10%-Schritten lÑuft!');
  Ini_Text_win;
  SkalFact := AdrTab [Num].MaxWert/32767; {Skalierungsfaktor f. physkal. Anzeige}

  FormStep  := 32767 div Steps;
  SwStep    := Round(FormStep * SkalFact);
  Fct.B.Adr := AdrTab [Num].Adr;;

  GotoXY(15,02);  Write('************** Magnet wird formiert! ****************');
  GotoXY(02,04);  Write('GerÑte-Nomenklatur          : ',AdrTab [Num].Nomen);
  GotoXY(02,05);  Write('Anzahl der Sollwert-Schritte: ',Steps:3);
  GotoXY(02,06);  Write('Zeit fÅr einen Schritt   [s]: ',FormierStepTime DIV 1000:3);
  GotoXY(02,07);  Write('Maximalwert (100%)          : ',AdrTab [Num].MaxWert); {  FormParam.MaxWert); }
  GotoXY(02,08);  Write('Schrittweite (10%)          : ',SwStep:3:0);

  for I:= 1 to 10 do                      {Formier-Zyklus starten}
   begin
     Sollwert  := FormStep * I;
     SwPhys    := Round(Sollwert * SkalFact);
     SwParam.Sw:= Sollwert;
     GotoXY(02,10); Write('Schritt: ',I:2);
     GotoXY(15,10);
     Write('     Sollwert: ');  Write_Real_10 (SwParam.Sw); Write(' [Volt]');
     Write('   bzw.   ',SwPhys:7:3,' [Ampere]');

     Fct.B.Fct := Fct_Wr_Sw1;
     Mil.Wr (Sollwert, Fct, MilErr);
     Mil.Timer2_Set (FormierStepTime);
     repeat
       Displ_Istwert;                {Zeige wÑhrend der Wartezeit den Istwert}
     until  Mil.Timeout2;                                       {6 sec warten}
   end; {for I}

   for I := 1 to SwMaxTime do
    begin
     Ini_Msg_Win;
     Write('Maximaler Sollwert bleibt ',SwMaxTime,' [sec] stehen!!  Zeitanzeige: ',I:2,' [sec]');

     Mil.Timer2_Set (100000);  {1 sec}
     repeat
      Set_Text_Win;
      Displ_Istwert;
     until  Mil.Timeout2;
    end; {for swmaxtime}

    Set_Text_Win;
    Sollwert  := IwMax Div 2;            {Auf halbem max. Wert stehen lassen}
    SwPhys    := Round(Sollwert * SkalFact);
    SwParam.Sw:= Sollwert;

    GotoXY(02,10); Write('Schritt: Ende');
    GotoXY(15,10);
    Write('     Sollwert: ');  Write_Real_10 (SwParam.Sw); Write(' [Volt]');
    Write('   bzw.   ',SwPhys:7:3,' [Ampere]');

    Fct.B.Fct := Fct_Wr_Sw1;
    Mil.Wr (Sollwert, Fct, MilErr);
    Ini_Msg_Win;
    Write('Formierung beendet. Magnet steht auf 1/2 Max-Wert. Weiter mit beliebiger Taste!');
    repeat
      Set_Text_Win;
      Displ_Istwert;
    until KeyPressed;;
1:
end;  {Formiere Magnet}

procedure Formiere_All_Magnet;
{ Magnete in 60 sec von 0 auf Maxwert fahren , in 10% Schritten
  Danach auf halbem Maxwert stehen lassen. }
label 1;
var I : Integer;
    Z_Start : Byte;
    FormSw  : Integer;
    Result  : Boolean;
    SwParam : TAdrSw;
    SkalFact: Real;
    SwStep  : Real;
    SwPhys  : Real;
    RdParam : TRdData;
    Param   : TRealSw;
    Sollwert: Integer;
    Istwert : Integer;
    Num     : Byte;
    FormStep: Integer;
    Fct      : TFct;
    MilErr   : TMilErr;
    RdData   : Word;


    function check_dev_magnet (Number: Byte): Boolean;
     begin
       if (AdrTab[Number].PhysEinh = ' A') or           {PrÅfe ob GerÑt ein Magnet}
          (AdrTab[Number].PhysEinh = 'A ') or
          (AdrTab[Number].PhysEinh = 'kA') or
          (AdrTab[Number].PhysEinh = 'KA') then
         check_dev_magnet := True
       else
         check_dev_magnet := False;
     end;

    procedure Displ_All_Iw;
     var I : LongInt;
     begin
      for I := 1 to DevMax do
       begin
        if AdrTab [I].Adr > 0 then             {Null-Adr wird nicht angezeigt}
         begin
          GotoXY(03,Z_Start+I); Write(I:2);
          GotoXY(10,Z_Start+I); Write(Hex_Byte(AdrTab [I].Adr));
          GotoXY(20,Z_Start+I); Write(AdrTab [I].Nomen);
          if check_dev_magnet (I) then             {PrÅfe ob GerÑt ein Magnet}
           begin
             Fct.B.Adr := AdrTab [I].Adr;
             Fct.B.Fct := Fct_Rd_Ist1;
             Mil.Rd (RdData, Fct, MilErr);

             GotoXY(30,Z_Start+I); Write('                                ');
             if MilErr=No_Err then
               begin
                Istwert    := RdData;          {wegen Vorzeichen}
                Param.Sw   := Istwert;
                Param.Maxw := AdrTab [I].MaxWert;
                GotoXY(30,Z_Start+I); Write_Real_Sw (Param);
                GotoXY(39,Z_Start+I); Write('[',AdrTab[I].PhysEinh,']');
                GotoXY(45,Z_Start+I);
                Write_Real_10 (Param.Sw); Write(' [Volt]');
               end
              else
               begin
                  GotoXY(35,Z_Start+I); Write('Read Error!');
               end; {if Result}
           end {if magnet}
          else
           begin
             GotoXY(35,Z_Start+I);
             Write('Kein Magnet!');
           end; {if magnet}
        end;  {if adr > 0}
       end; {for}
       for I := 1 to 800000 do ;        {Warte}
     end;   {displ_all_iw}

begin
  Ini_Text_Win;
  Ini_Msg_Win;
  Write('Wirklich alle Magnete formieren ???  [J/N]: ');
  if not (ReadKey in ['j','J']) then goto 1;

  Result := Rd_Ifc_Nomen;
  if not Result then
   begin
    Ini_Err_Win;
    Write('ERROR: Datei ',Adr_Fname,' nicht gefunden.      Weiter mit beliebiger Taste! ');
    Goto 1;
   end;

  Ini_Msg_Win;
  Write('Sollwert-Sequenz in 10%-Schritten lÑuft!');
  Ini_Text_win;

  FormStep := IwMax div FormierStepMax ;
  Z_Start := 6;
  GotoXY(10,01);  Write('************** Alle Magnete werden formiert! ****************');
  GotoXY(02,02);  Write('Anzahl der Sollwert-Schritte: ', FormierStepMax :3);
  GotoXY(45,02);  Write('Zeit fÅr einen Schritt [s]: ', FormierStepTime DIV 100000:3);
  GotoXY(01,05);  Writeln('Num IFC-Adr[Hex]  Nomenkl.      IstWert ');
  GotoXY(01,06);  Writeln(' ----------------------------------------------------------------------------');

  for I:= 1 to FormierStepMax  do         {Formier-Zyklus in 10 Steps starten}
   begin
     Z_Start := 6;
     GotoXY(25,04);  Write('Aktueller Sollwert [',(100 div FormierStepMax)*I:3,'] % ');
     for Num := 1 to DevMax do
      begin
       if check_dev_magnet(Num) then                      {ist GerÑt ein Magnet?}
        begin
         Fct.B.Adr := AdrTab [Num].Adr;;
         Fct.B.Fct := Fct_Wr_Sw1;
         Sollwert  := FormStep * I;
         Mil.Wr (Sollwert, Fct, MilErr);
         Mil.Timer2_Set (FormierStepTime);
         repeat                      {Zeige wÑhrend der Wartezeit den Istwert}
          Ini_Msg_Win;
          Write('GerÑt Nr. [',Num:3,'] wird auf aktuellen Sollwert gesetzt!');
          Set_Text_Win;
          Displ_All_Iw;
         until  Mil.Timeout2;                                     {sec warten}
        end;
      end; {for Num}
   end; {for I}

   for I := 1 to SwMaxTime do
    begin
     Ini_Msg_Win;
     Write('Maximaler Sollwert bleibt ',SwMaxTime,' [sec] stehen!!  Zeitanzeige: ',I:2,' [sec]');
     Mil.Timer2_Set (FormierSecClk);
     repeat
      Set_Text_Win;
      Displ_All_Iw;
     until Mil.Timeout2;
    end; {for swmaxtime}

    Set_Text_Win;
    Sollwert  := IwMax Div 2;             {Auf halbem max. Wert stehen lassen}
    Fct.B.Fct := Fct_Wr_Sw1;
    GotoXY(25,04);  Write('Aktueller Sollwert [',(100 div 2):3,'] % ');
    {alle GerÑte auf halben Sollwert setzen!!}
    for I := 1 to DevMax do
     begin
      if check_dev_magnet(I) then                      {ist GerÑt ein Magnet?}
       begin
         Fct.B.Adr := AdrTab [I].Adr;
         Mil.Wr (Sollwert, Fct, MilErr);
         Mil.Timer2_Set (FormierDispTime);           {GerÑte im Abstand 1 sec}
{ xxx        Mil.Timer2_Set (100); }          {GerÑte im Abstand 1 sec}
         repeat                      {Zeige wÑhrend der Wartezeit den Istwert}
          Ini_Msg_Win;
          Write('GerÑt Nr. [',I:3,'] wird auf halben Sollwert gesetzt!');
          Set_Text_Win;
          Displ_All_Iw;
         until  Mil.Timeout2;
       end; {if check..}
     end;

    Ini_Msg_Win;
    Write('Ende Formierung. Magnete stehen auf 1/2 MaxWert. Weiter mit [Q]uit!');
    repeat
     Set_Text_Win;
     Displ_All_Iw;
     if KeyPressed then if ReadKey in ['q','Q'] then goto 1;
    until  1=2;
1:
end;  {Formiere All Magnet}

procedure Ship_Formieren;
label 1;
var Result   : Boolean;
    Num      : Byte;
    FormParam: TFormParam;
begin
  Ini_Text_Win;
  if Loop then  {alle formieren}
   begin
     Formiere_All_Magnet;
     Goto 1;
   end
  else
   begin           {Einzel Magneten formieren}
    Ifc_Nomen;     {Mil-Bus-adressen lesen u. dem  User anzeigen}
    Ini_Msg_Win;
    Write('Welches GerÑt formieren?    Bitte Nummer eingeben oder [Q]uit:  ');
    {$I-}                            {Compiler Check aus, Error selber abfangen}
     Readln(Num);
    {$I+}
    if IoResult <> 0 then Goto 1;
    if not Check_Num (Num) then  Goto 1;

    if (AdrTab [Num].PhysEinh = 'kV') or (AdrTab [Num].PhysEinh = 'KV') or
       not (AdrTab [Num].PhysEinh = ' A') then
      begin
        Ini_Err_Win;
        Write('ERROR: GerÑt kein Magnet! Physikal. Einheit = ',AdrTab [Num].PhysEinh,'   Weiter mit beliebiger Taste!');
        ReadKey;
        Goto 1;
      end;
    Ini_Msg_Win;
    Write('Formiert wird GerÑt mit IFC-Adr: ',Hex_Byte(AdrTab [Num].Adr),' [H]   Maxwert: ',AdrTab [Num].MaxWert:4);
    Write(' [',AdrTab [Num].PhysEinh,']    [J/N]: ');
    if ReadKey in ['j','J'] then
     begin
      FormParam.Adr    := AdrTab [Num].Adr;
      FormParam.MaxWert:= AdrTab [Num].MaxWert;
      Formiere_Einzel_Magnet(Num);
      Goto 1;
     end
    else
     Goto 1;
   end;  {if not loop}
1:
end;

procedure Ship_Zero;
label 1;
var Num   : Byte;
    Ch    : Char;
    I     : LongInt;
    SkalFact: Real;
    SwParam : TAdrSw;
    RdParam : TRdData;
    Param   : TRealSw;
    Result,Disp_Loop  : Boolean;
    Z_Start  : Word;
    Read_Data: Word;
    Sollwert : Integer;
    Istwert  : Integer;
    Fct      : TFct;
    MilErr   : TMilErr;
    RdData   : Word;
    RdFct    : TFct;
    RdMilErr : TMilErr;



begin
  Result := Ship_Rd_AdrTab;
  if  not Result then Goto 1;                               {Abort bei Fehler}
  if Loop then                                   {alle GerÑte auf Null setzen}
   begin
     Ini_Text_Win;
     Disp_Loop := False;
     Ini_Msg_Win;
     Write('Wirklich alle GerÑte (Magnete und Hochspannung) auf Null setzen? [J/N]: ');
     Ch := ReadKey;
     if not (Ch in ['j','J']) then goto 1;

     Z_Start := 4;
     Ini_Text_win;
     GotoXY(15,2 );
     Write('Die GerÑte werden im Abstand von 1 Sek. auf Null gesetzt!! ');
     GotoXY(1,3 );
     Writeln(' Num IFC-Adr[H]  Nomenkl.          IstWert ');
     Writeln(' ----------------------------------------------------------------------------');
     repeat
      for I := 1 to DevMax do
       begin
        if AdrTab [I].Adr > 0 then             {Null-Adr wird nicht angezeigt}
         begin
           GotoXY(03,Z_Start+I); Write(I:2);
           GotoXY(10,Z_Start+I); Write(Hex_Byte(AdrTab [I].Adr));
           GotoXY(18,Z_Start+I); Write(AdrTab [I].Nomen);

           Fct.B.Adr := AdrTab [I].Adr;
           Fct.B.Fct := Fct_Wr_Sw1;
           Sollwert  := 0;
           Mil.Wr (Sollwert, Fct, MilErr);

           Fct.B.Fct := Fct_Rd_Ist1;
           Mil.Rd (Read_Data, Fct, MilErr);
           GotoXY(25,Z_Start+I); Write('                ');  {Clear old text}
           if MilErr = No_Err then
             begin
              Istwert    := Read_Data;
              Param.Sw   := Istwert;
              Param.Maxw := AdrTab [I].MaxWert;
              GotoXY(30,Z_Start+I); Write_Real_Sw (Param);
              Write(' [',AdrTab [I].PhysEinh,']');
             end
           else
             begin
              GotoXY(35,Z_Start+I); Write('Read-Error!');
             end;
         end;
         Mil.Timer2_Set (100000);        {GerÑte im Abstand von 1sec auf Null}
         repeat until Mil.Timeout2;
      end; {for}

      if Disp_Loop then                             {Loop}
          begin
           if KeyPressed then Disp_Loop := False;
           for I := 1 to 500000 do ; {Wait}
          end
         else
          begin                  {Einzelschritt}
            Ini_Msg_Win;
            Write('Istwert-Anzeige angehalten.        Neustart mit Leertaste bzw. [L]oop [Q]uit!');
            Ch := ReadKey;
            if Ch in ['q','Q'] then Goto 1;
            if Ch in ['l','L'] then
             begin
              Disp_Loop := True;
              Ini_Msg_Win;
              Write('Istwert-Anzeige wird im Loop stÑndig erneuert!   Anhalten mit beliebiger Taste!');
             end;
            Set_Text_Win;
          end;
          Mil.Reset;        {Wegen manueller Unterbrechung: Clear all}
     until 1=2;
   end             {if loop: Ende alle GerÑte auf Null}
  else
   begin           {Einzel-GerÑt auf Null setzen}
    Ifc_Nomen;     {Mil-Bus-Adressen u. Nomenklatur lesen u. dem User anzeigen}
    Ini_Msg_Win;
    Write('Welches GerÑt auf Null setzen? Bitte Nummer eingeben oder [Q]uit: ');
    {$I-}                            {Compiler Check aus, Error selber abfangen}
     Readln(Num);
    {$I+}
    if IoResult <> 0 then Goto 1;
    if not Check_Num (Num) then  Goto 1;

    Ini_Msg_Win;
    Write('Auf Null setzen GerÑt mit IFC-Adr: ',Hex_Byte(AdrTab [Num].Adr),' [H]');
    Write('   (',AdrTab [Num].Nomen,')     [J/N]: ');
    Ch := ReadKey;
    if Ch in ['j','J'] then
     begin
       Ini_Text_Win;
       GotoXY(01,22); Write('GerÑt auf Null gesetzt!  Anzeige des Istwertes im Loop! ');
       RdFct.B.Adr :=  AdrTab [Num].Adr;
       RdFct.B.Fct :=  Fct_Rd_Ist1;

       Sollwert  := 0;
       Fct.B.Adr := AdrTab [Num].Adr;
       Fct.B.Fct := Fct_Wr_Sw1;
       Mil.Wr (Sollwert, Fct, MilErr);
       repeat
         Mil.Rd (RdData, RdFct, RdMilErr);
         Istwert    := RdData;
         Param.Sw   := RdData;       {RdParam.RdData;} ;
         Param.Maxw := AdrTab [Num].MaxWert;
         Ini_Msg_Win;
         Write(' Istwert : ');  Write_Real_10 (Istwert); Write(' [V]');
         Write('  bzw. ');      Write_Real_Sw (Param);
         Write(' [',AdrTab[Num].PhysEinh,']   Ende Loop mit beliebiger Taste!');
         Mil.Timer1_Set ($FFFF);               {Warte 0,65 sec}
         repeat  until  Mil.Timeout1;
        until KeyPressed;

      Ini_Msg_Win;
      Write('Ende Nullsetzen!  Weiter mit beliebiger Taste. ');
      ReadKey;
     end
    else
     Goto 1;
   end;
1:
end;  {Ship_Zero}

procedure Ship_Set_SwTab;
label 1;
var N  : Word;
    I  : LongInt;
    Ch,Answer : Char;
    Result,Disp_Loop : BOOLEAN;
    Z_Start: Byte;
    TabNr  : Byte;
    SwParam: TAdrSw;
    RdParam : TRdData;
    Param   : TRealSw;

    Sollwert: Integer;
    Istwert : Integer;
    Fct      : TFct;
    MilErr   : TMilErr;
    RdData   : Word;


 procedure Displ_Iw (A: Byte);    {A = aktuelle GerÑte-Nr}
 var I : Byte;
  begin
   for I := 1 to A do                {zeige immer auch die bisherigen GerÑte}
     begin
     if AdrTab [I].Adr > 0 then         {nur anzeigen fÅr Adressen grî·er Null}
      begin
        Set_text_Win;
        GotoXY(40,Z_Start+I); Write('                    ');  {Clear old text}
        Fct.B.Adr := AdrTab [I].Adr;
        Fct.B.Fct := Fct_Rd_Ist1;
        Mil.Rd (RdData, Fct, MilErr);
        Istwert := RdData;               {wegen Vorzeichen}

        if MilErr = No_Err then
         begin
          Param.Sw   := Istwert;
          Param.Maxw := AdrTab [I].MaxWert;
          GotoXY(40,Z_Start+I); Write_Real_Sw (Param);
          Write(' [',AdrTab [I].PhysEinh,']');
         end
        else
         begin
          GotoXY(45,Z_Start+I); Write('Read-Error!');
         end;
     end; {if > 0}
   end; {for}
  end; {displ_Iw}

begin
  Ini_Text_Win;
  Disp_Loop := False;
  Result:= Ship_Rd_SwTab;
  if not Result then
   begin
    Ini_Err_Win;
    Write('ERROR: Sollwert-Tabelle ',Sw_Fname,' nicht gefunden.      Weiter mit beliebiger Taste!');
    ReadKey;
    Goto 1;
   end;

  Result := Ship_Rd_AdrTab;                            {Lese Adr-Tab von Disk}
  if NOT Result then Goto 1;                                           {Abort}

  Ini_Text_Win;
  GotoXY(01,2 );
  Write('Die Sollwert-Tabellen sind im File: "',Sw_Fname,'" abgelegt!');
  GotoXY(01,4 );
  Write('v--- Existierende Sollwert-Tabellen ---v ');
  GotoXY(1,5 );
  for N := 1 to SwTabMax do
   begin
     Writeln('         Tabelle [',N:2,']: ', SwTab[N].Name);
   end;

  N := 1;               {Default ist STANDARD}
  Set_Text_Win;
  GotoXY(1,22);  ClrEoL;
  Write('Nach welcher Tabelle sollen Sollwerte gesetzt werden? Bitte auswÑhlen!');
  Ini_Msg_Win;
  Write('Mit <CR> wird STANDARD-Tabelle angezeigt! FÅr andere Tabelle <A> eingeben!');
  Ch := ReadKey;
  if Ch in ['a','A'] then
   begin          {Neue Tabelle anzeigen}
    Ini_Msg_Win;
    Write('Bitte Tabellen-Nr eingeben [1..',SwTabMax,']: ');
    Readln(N);
    if not (N in [1..SwTabMax]) then
     begin
       Ini_Err_Win;
       Write('ERROR: Tabellen-Nr nicht im zulÑssigen Bereich. Weiter mit beliebiger Taste!');
       ReadKey;
       N := 1;
     end;
   end;

  Disp_Sw_Tab (N);
  Ini_Msg_Win;
  Write('GerÑte nach dieser Sollwert-Tabelle setzen? [J/N]: ');
  Ch := ReadKey;
  if Ch in ['j','J'] then
   begin
     TabNr    := N;
     AktSwTab := N;
     Ini_Msg_Win;
     Z_Start := 4;
     Ini_Text_win;
     GotoXY(20,01);
     Write('Die aktuelle Sollwert-Tabelle ist: ', SwTab[N].Name);
     GotoXY(02,02);
     Write('Die GerÑte werden im Abstand von 1 Sek. auf den jeweiligen Sollwert gesetzt!! ');
     GotoXY(1,3 );
     Writeln('Num IFC-Adr[Hex]  Nomenkl. Sollwert       IstWert ');
     Writeln(' ----------------------------------------------------------------------------');
     for I := 1 to DevMax do
       begin
        if AdrTab [I].Adr > 0 then             {Null-Adr wird nicht angezeigt}
         begin
           GotoXY(03,Z_Start+I); Write(I:2);
           GotoXY(10,Z_Start+I); Write(Hex_Byte(AdrTab [I].Adr));
           GotoXY(20,Z_Start+I); Write(AdrTab [I].Nomen);

           Param.Sw   := SwTab[TabNr].SwAry[I];           {Sollwert}
           Param.Maxw := AdrTab [I].MaxWert;
           GotoXY(27,Z_Start+I); Write_Real_Sw (Param);

           Fct.B.Adr := AdrTab [I].Adr;
           Fct.B.Fct := Fct_Wr_Sw1;
           Sollwert  := SwTab[TabNr].SwAry[I];
           Mil.Wr (Sollwert, Fct, MilErr);
           Mil.Timer2_Set (100000);      {GerÑte im Abstand von 1sec auf Null}
           Displ_Iw(I);
           repeat until Mil.Timeout2;
         end; {if adr}
      end; {for}
   end; {if GerÑte nach Sw-Tab setzen}

   repeat
    for I := 1 to DevMax do Displ_Iw(I);
    if Disp_Loop then                             {Loop}
      begin
       if KeyPressed then Disp_Loop := False;
       for I := 1 to 500000 do ; {Wait}
      end
    else
      begin                  {Einzelschritt}
       Ini_Msg_Win;
       Write('Istwert-Anzeige angehalten.     Neustart mit Leertaste bzw. [L]oop [Q]uit!');
       Ch := ReadKey;
       if Ch in ['q','Q'] then Goto 1;
       if Ch in ['l','L'] then
        begin
         Disp_Loop := True;
         Ini_Msg_Win;
         Write('Istwert-Anzeige wird im Loop stÑndig erneuert!  Anhalten mit beliebiger Taste!');
        end;
      end;
   until 1=2;
1:
end;  {Ship_set_swtab}

BEGIN                        { Hauptprogramm }
  AktSwTab := 1;                      {Aktuelle Sollwert Tabelle auf Default}
  SwTab[N].Name    := 'NoName';       {Init Sollwert-Tabelle}
  for I := 1 to DevMax do
    SwTab[N].SwAry[I]  := 0;
  REPEAT
    user_input := menue_win;
    loop := TRUE;
    IF user_input IN ['0'..'9'] THEN loop := FALSE;
    CASE user_input OF
     '0'      :     Begin
                      Ini_Text_Win;
                      Mil_Detect_Ifc;
                    End;
     'a', 'A' :        Ship_Check_Ifc;
     '1', 'b', 'B' : Begin
                       Ship_Nomen;
                     End;
     '2', 'c', 'C' : Begin
                      Ship_Sollw_Tab;
                     End;
     '3', 'd', 'D' : Begin
                       Ship_Single_Dev;
                     End;
     '4', 'e', 'E' : Begin
                       Ship_Disp_Status;
		     End;
     '5', 'f', 'F' : Begin
                       Ship_Formieren;
		     End;
     '6', 'g', 'G' : Begin
                       Ship_Zero;
		     End;
          'k', 'K' : Begin
                       Ship_Set_SwTab;
                     End;
          'l', 'L' : Begin
                       Ship_Sel_SwTab;
                     End;
          'm', 'M' : Begin
                       Real_Test;
                     End;
          'n', 'N' : Begin
                     End;
    End; {CASE}
  UNTIL (user_input = 'x') OR (user_input = 'X');
END. {mil_ship}

