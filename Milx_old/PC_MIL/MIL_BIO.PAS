PROGRAM Mil_Bio;
{ Autor des Basis-Programmes Mil_Base.Pas: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS

  Autor der Erweiterungen   :
  énderungen:
  24.06.96    Englert   MIL-Base geÑndert fÅr Biophysik Hr. Becher Tel. 2692
  Im  fertigen System  ist die IFC-Adr fix EFh; Basis-Adr der I/O-Karte = 00

  ErlÑuterung zur APL-I/O-Bus Karte 5 x 8 Bit (FG 385 ...)
  - die I/O-Karten werden Åber eine Standard IFC-Karte (FG 380 122) angesteuert
  - durch BrÅcken auf der Karte byteweise auf Input oder Output einstellbar
  - Write/Read byteweise
  - es sind 32 I/O-Karten adressierbar, jede Karte verwendet max. 8 Bytes
  - die Basis-Adr (Karten-) wird Åber Schalter eingestellt 00, 08, 10h usw.
  - um 1 Bit zu Adressieren benîtigt man: IFC-Adr, Karten-Adr, Byte-Nr, Bit-Nr
  - Output-Bytes kînnen zurÅckgelesen werden;

  07.03.97       Array von 1..Ventil_Max  statt 0..

}
{$S-}
uses Crt, WinDos, Datech, Datech_1;
    {Auf besonderen Wunsch der BIO-Menschen startet das Programm ohne MenÅ!}
const
  Stat_Line1 =
    'Datentechnik                      MIL_BIO       ' +
    '                    [07.03.1997]' +
    '                           Steuerung IC-Stack Cave M                      ';

  Bio_Ifc_Adr    = $EF;     {IFC-Adr     ist festverdrahtet}
  Bio_IoCard_Adr = $00;     {I/O-Bus-Adr der Karte ist festverdrahtet}
  Ventil_Max     = 10;

  Wait_Time = 5000;
  S_Aktiv   = 33;
  Z_Aktiv   = 02;
  Z_Base    = 5;      {Basis-Zeile fÅr Anzeige}
  S_Base    = 20;     {Basis-Spalte           }

type
 Richtung  = (Rein,Raus);
 Bedienung = (Hand,Rechner);

 TBitAdr   = record
              Sub  : Byte;    {Sub-Adr. bzw. Byte-Positon lt. Tabelle BIO}
              BitNr: Byte;    {Bitposition innerhalb eines Datenbytes}
             end;

 TVent_Adr = record
              Cmd  : TBitAdr; {Ventil bzw. Platte rein/raus fahren}
              EndI : TBitAdr; {Endschalter innen = Platte im Strahl}
              EndA : TBitAdr; {Endschalter au·en = Platte aus dem Strahl}
             end;

   {Achtung: Im  Vent_Adr_Ary[0].Cmd  ist die Freigabe-Adresse definiert
             und Vent_Adr_Ary[0].EndI der Status Lokal/Rechner}
 TVent_Adr_Ary = array [0..Ventil_Max] of TVent_Adr;

 TVent_Stat = record
               EndI : Boolean; {Endschalter innen = Platte im Strahl}
               EndA : Boolean; {Endschalter au·en = Platte aus dem Strahl}
              end;

 TVent_SI   = record               {Soll-Ist-Zustand}
               Soll: TVent_Stat;
               Ist : TVent_Stat;
              end;

 TVent_Stat_Ary = array [1..Ventil_Max] of TVent_SI;

 const                        {Init-Werte fÅr  Arrays}
Vent_Adr : TVent_Adr_Ary =   {Ventil-Array legt Bit-Adressen eindeutig fest}
(    {in der 1. Zeile Cmd: Adr. Freigabe-Bit, EndI: Lokal/Rechner}
{00} (Cmd: (Sub:03; BitNr:06); EndI: (Sub:04; BitNr:07); EndA: (Sub:00; BitNr:00)),
{01} (Cmd: (Sub:00; BitNr:00); EndI: (Sub:01; BitNr:00); EndA: (Sub:02; BitNr:00)),
{02} (Cmd: (Sub:00; BitNr:01); EndI: (Sub:01; BitNr:01); EndA: (Sub:02; BitNr:01)),
{03} (Cmd: (Sub:00; BitNr:02); EndI: (Sub:01; BitNr:02); EndA: (Sub:02; BitNr:02)),
{04} (Cmd: (Sub:00; BitNr:03); EndI: (Sub:01; BitNr:03); EndA: (Sub:02; BitNr:03)),
{05} (Cmd: (Sub:00; BitNr:04); EndI: (Sub:01; BitNr:04); EndA: (Sub:02; BitNr:04)),
{06} (Cmd: (Sub:00; BitNr:05); EndI: (Sub:01; BitNr:05); EndA: (Sub:02; BitNr:05)),
{07} (Cmd: (Sub:00; BitNr:06); EndI: (Sub:01; BitNr:06); EndA: (Sub:02; BitNr:06)),
{08} (Cmd: (Sub:03; BitNr:00); EndI: (Sub:04; BitNr:00); EndA: (Sub:04; BitNr:03)),
{09} (Cmd: (Sub:03; BitNr:01); EndI: (Sub:04; BitNr:01); EndA: (Sub:04; BitNr:04)),
{10} (Cmd: (Sub:03; BitNr:02); EndI: (Sub:04; BitNr:02); EndA: (Sub:04; BitNr:05))
);

 var
  Vent_Stat : TVent_Stat_Ary;  {Globales Array fÅr den Soll-Ist-Status}
  MilErr: TMilErr;

 function Iob_Ask_IoAdr: Byte;
  var Status: Boolean;
      Iob_Adr: Byte;
  begin
    Status := False;
    while not Status do
     begin
      Ini_Text_Win;
      GotoXY(1, 22);
      Write ('Basis-Adr fÅr I/O-Bus Testkarte? (00, 08, 10H, 18H .. F8) [Hex]: ');
      Iob_Adr := Ask_Hex_Byte;
      if (Iob_Adr in [00..$F8]) and (Iob_Adr mod 8 = 0) then
        Status := True
      else
       begin
        Ini_Err_Win;
        Write('Error: Diese I/O-Bus Karten-Adr ist nicht erlaubt! Weiter beliebige Taste.');
        repeat until KeyPressed;
       end;
     end; {while}
     Iob_Ask_IoAdr := Iob_Adr;
  end; {Iob_Ask_Subadr}

 procedure Ini_Stat_Win;
 begin                             {Definitionen gelten bis neu definiert}
  Window(1, 1, 80, 2);             {Definiert ein Textfenster: Spalte/Zeile}
  TextBackground(Magenta);         {Setze Hintergrund fÅr Textfenster}
  TextColor(Yellow);               {Setze Schriftfarbe}
  ClrScr;                          {Clear Window}
  GotoXY(1, 1);                    {Cursor auf Anfang Fenster}
 end;

 procedure Set_TastBio_Win;
  begin
   Window(43, 22, 79, 24);
   TextBackground(Green);
   TextColor(Black);               {Setze Schriftfarbe}
  end;

  procedure Set_Leg_Win;
   begin
    Window(02, 22, 38, 24);
    TextBackground(Cyan);
    TextColor(Black);               {Setze Schriftfarbe}
   end;

 procedure Slow_Key;
  begin
    repeat
     if KeyEpressed then NewReadKey;
    until not KeyEpressed;
  end;

 procedure Life_Sign;
  begin
    Cursor (False);
    Set_Text_Win;
    TextColor(Yellow);
    GotoXY(S_Aktiv, Z_Aktiv);  Write (chr($7C)); Mil.Timer2_Wait (Wait_Time);
    GotoXY(S_Aktiv, Z_Aktiv);  Write ('/');      Mil.Timer2_Wait (Wait_Time);
    GotoXY(S_Aktiv, Z_Aktiv);  Write (chr($2D)); Mil.Timer2_Wait (Wait_Time);
    GotoXY(S_Aktiv, Z_Aktiv);  Write ('\');      Mil.Timer2_Wait (Wait_Time);
    TextColor(Black);
  end; {Life_Sign}

 function Rd_Schalter: Bedienung;     {Stellung Schalter Rechner/Lokal}
  var IO_Data : Word;
      IO_Adr  : TIoAdr;
      Bit_Nr  : Byte;
      Vent_Nr : Byte;
  begin
    Vent_Nr := 0;         {Bit-Adr fÅr Lokal/Rechner ist im Adr-Array[0].EndI}
    IO_Adr.IfcAdr  := Ifc_Test_Nr;
    IO_Adr.IoCard  := Bio_IoCard_Adr;             {Kartenadr IO-Bus}

    IO_Adr.IoSub   := Vent_Adr[Vent_Nr].EndI.Sub; {Subadr fÅr Lokal-Byte}
    Mil.Rd_IoBus (IO_Data, IO_Adr, MilErr);       {Cmd-Bits rÅcklesen: Bit0..7 sind Daten}
    Bit_Nr  := Vent_Adr[Vent_Nr].EndI.BitNr;      {Bit  Rechner/Hand}
    if BitTst (IO_Data, Bit_Nr) then
     Rd_Schalter := Hand                          {lt. Hr. Becher v. 18. 6. 96}
    else                                          {1 = Lokal}
     Rd_Schalter := Rechner;                      {0 = Rechner}
  end;

 procedure Disp_Stat_Mask;
   begin
    Ini_Stat_Win;  Write(Stat_Line1);
    Ini_Text_Win;
    GotoXY(S_Aktiv+2, Z_Aktiv);  TextColor(Brown);  Write ('Lesen aktiv!');
    TextColor(Black);
    GotoXY (03,02); Write (' SCHALTER');
    GotoXY (65,02); Write (' FREIGABE');
    TextColor(Brown);
    GotoXY (01,03); Write ('[Lokal/Rechner]: ');
    GotoXY (65,03); Write ('[Soll=Ist]: ');

    GotoXY (S_Base,Z_Base);
    Write (' -------- PLATTENSTELLUNG --------                 '); GotoXY (S_Base,Z_Base+1);
    Write ('Platte   im Strahl   aus dem Strahl                '); GotoXY (S_Base,Z_Base+2);
    Write ('  Nr.    [Soll:Ist]    [Soll:Ist]                  '); GotoXY (S_Base,Z_Base+3);
    Write ('   0          :             :       Plattenblock 1 '); GotoXY (S_Base,Z_Base+4);
    Write ('   1          :             :       .              '); GotoXY (S_Base,Z_Base+5);
    Write ('   2          :             :       .              '); GotoXY (S_Base,Z_Base+6);
    Write ('   3          :             :       .              '); GotoXY (S_Base,Z_Base+7);
    Write ('   4          :             :       .              '); GotoXY (S_Base,Z_Base+8);
    Write ('   5          :             :       .              '); GotoXY (S_Base,Z_Base+9);
    Write ('   6          :             :       .              '); GotoXY (S_Base,Z_Base+10);
    Write ('   A          :             :       Plattenblock 2 '); GotoXY (S_Base,Z_Base+11);
    Write ('   B          :             :       .              '); GotoXY (S_Base,Z_Base+12);
    Write ('   C          :             :       .              ');
  end;

 procedure Disp_Stat (MIL_Rd_Status: Boolean);       {Aktuellen Status aus dem Status-Array anzeigen}
 const
  Z_SI = 03;
  S_SI = 77;
  Z_RH = 3;
  S_RH = 18;

  var N : Byte;
      S_Soll_Innen : Byte;
      S_Soll_Ausen : Byte;
      Z_Stat       : Byte;
      Freigabe     : Boolean;
      IO_Data : Word;
      IO_Adr  : TIoAdr;
      Bit_Nr  : Byte;

  begin
   Set_Text_Win;
   TextColor(Yellow);
   if Rd_Schalter = Rechner then
    begin
      GotoXY (S_RH,Z_RH); Write ('R');
    end
   else
    begin
      GotoXY (S_RH,Z_RH); Write ('L');
    end;

   {Das Output-Bit "Freigabe" wird nur gesetzt, wenn alles ok. ist}
   Freigabe := True;                                          {Default}
     {Erlaubt ist: Endlage Innen: (Soll=1 Ist=1) and Au·en (Soll=0 Ist=0)
      oder         Endlage Innen: (Soll=0 Ist=0) and Au·en (Soll=1 Ist=1)
     }
   for N := 1 to Ventil_Max do
    begin
     if not( ((Vent_Stat[N].Soll.EndI   = Vent_Stat[N].Ist.EndI)      and
           (not Vent_Stat[N].Soll.EndA  = not Vent_Stat[N].Ist.EndA)) or

           ((not Vent_Stat[N].Soll.EndI = not Vent_Stat[N].Ist.EndI)  and
                (Vent_Stat[N].Soll.EndA = Vent_Stat[N].Ist.EndA)))
        then Freigabe := False;
    end;
   if not MIL_Rd_Status then Freigabe := False; {Mil-Lesefehler: keine Freigabe!!}

   IO_Adr.IfcAdr  := Ifc_Test_Nr;                  {Hole Adr fÅr Freigabe-Bit}
   IO_Adr.IoCard  := Bio_IoCard_Adr;
   IO_Adr.IoSub   := Vent_Adr[0].Cmd.Sub;
   Mil.Rd_IoBus (IO_Data, IO_Adr, MilErr);         {Bit0..7 sind Daten}
   Bit_Nr := Vent_Adr[0].Cmd.BitNr;

   GotoXY (S_SI,Z_SI);
   if Freigabe then
    begin
     IO_Data := BitSet (IO_Data, Bit_Nr);           {Bit dazu "odern" = 1}
     Mil.Wr_IoBus (IO_Data, IO_Adr, MilErr);        {Cmd-Bits zurÅckschreiben}
     Write (' Ja ');
    end
   else
    begin
     IO_Data := BitClr (IO_Data, Bit_Nr);           {Bit auf 0}
     Mil.Wr_IoBus (IO_Data, IO_Adr, MilErr);        {Cmd-Bits zurÅckschreiben}
     Write ('Nein');
    end;

   TextColor(Black);
   S_Soll_Innen := S_Base+12;
   S_Soll_Ausen := S_Base+26;
   Z_Stat       := Z_Base+ 3;

   for N := 1 to Ventil_Max do
    begin
      GotoXY (S_Soll_Innen  ,Z_Stat); if Vent_Stat[N].Soll.EndI then Write ('1') else Write('0');
      GotoXY (S_Soll_Innen+4,Z_Stat); if Vent_Stat[N].Ist .EndI then Write ('1') else Write('0');
      GotoXY (S_Soll_Ausen  ,Z_Stat); if Vent_Stat[N].Soll.EndA then Write ('1') else Write('0');
      GotoXY (S_Soll_Ausen+4,Z_Stat); if Vent_Stat[N].Ist .EndA then Write ('1') else Write('0');
      Z_Stat := Z_Stat + 1;
    end;  {for}
  end; {Disp_Stat}

 function Ask_Vent_Nr (var Num: Byte): Boolean;
  begin
    Ask_Vent_Nr:= True;
    repeat until KeyEPressed;
    Ch := NewReadKey;
    if Ch in ['0'..'6','A','a','B','b','C','c'] then
     begin
       case Ch of
         '0'     : Num := 1;
         '1'     : Num := 2;
         '2'     : Num := 3;
         '3'     : Num := 4;
         '4'     : Num := 5;
         '5'     : Num := 6;
         '6'     : Num := 7;
         'a','A' : Num := 8;
         'b','B' : Num := 9;
         'c','C' : Num := 10;
       else
        begin
          Ini_Err_Win;
          Write ('ERROR: Ventil-Nummer ungÅltig!!      Weiter mit <CR> ');
          repeat until KeyEPressed;
          Ask_Vent_Nr := False;
        end;
       end; {case}
     end;
  end; {Ask_Vent_Nr}

 procedure Vent_Move (Vent_Nr: Byte; Direct: Richtung); {Ventil rein/raus}
  var IO_Data : Word;
      IO_Adr  : TIoAdr;
      Bit_Nr  : Byte;
  begin
   IO_Adr.IfcAdr  := Ifc_Test_Nr;
   IO_Adr.IoCard  := Bio_IoCard_Adr;             {Kartenadr IO-Bus}
   IO_Adr.IoSub   := Vent_Adr[Vent_Nr].Cmd.Sub;  {Subadr fÅr Cmd-Byte}
   Mil.Rd_IoBus (IO_Data, IO_Adr, MilErr);       {Cmd-Bits rÅcklesen: Bit0..7 sind Daten}
   Bit_Nr  := Vent_Adr[Vent_Nr].Cmd.BitNr;       {mit diesem Bit kann Ventil gefahren werden}
x
   { Zuerst Stellung Rechner/Lokal-Schalter prÅfen!!}
   if Rd_Schalter = Rechner then
    begin
     if Direct = Rein then    {Ventil reinfahren}
      begin
       IO_Data := BitSet (IO_Data, Bit_Nr);           {Bit dazu "odern"}
       Mil.Wr_IoBus (IO_Data, IO_Adr, MilErr);        {Cmd-Bits zurÅckschreiben}
      end;

     if Direct = Raus then    {Ventil rausfahren}
      begin
       IO_Data := BitClr (IO_Data, Bit_Nr);           {Bit auf Null setzen}
       Mil.Wr_IoBus (IO_Data, IO_Adr, MilErr);        {Cmd-Bits zurÅckschreiben}
      end;
    end
   else
    begin                       {Kein Fahren der Ventile wegen Schalter LOKAL}
      Ini_Err_Win;
      Write ('ERROR: Kein Zugriff -> Schalter steht auf "LOKAL" !!   <CR> ');
      repeat until KeyEPressed;
      Ini_Msg_Win;
      Write('Plattenpositionen werden im Loop gelesen!                          Ende mit [X]');
      Set_Text_Win;
    end;
  end; {Vent_Move }

  procedure Status_Update;
   var N       : Byte;
       IO_Data : Word;
       IO_Adr  : TIoAdr;
       Bit_Nr  : Byte;
   begin
    IO_Adr.IfcAdr  := Ifc_Test_Nr;
    IO_Adr.IoCard  := Bio_IoCard_Adr;              {Kartenadr IO-Bus}

     for N := 1 to Ventil_Max do
      begin
        Bit_Nr       := Vent_Adr[N].EndI.BitNr;
        IO_Adr.IoSub := Vent_Adr[N].EndI.Sub;       {Subadr fÅr Endlage Innen}
        Mil.Rd_IoBus (IO_Data, IO_Adr, MilErr);
        if BitTst (IO_Data, Bit_Nr) then
          Vent_Stat[N].Ist.EndI := True             {Ist-Status EndlageInnen}
        else
          Vent_Stat[N].Ist.EndI := False;           {Ist-Status EndlageInnen}

        Bit_Nr       := Vent_Adr[N].EndA.BitNr;
        IO_Adr.IoSub := Vent_Adr[N].EndA.Sub;       {Subadr fÅr Endlage Au·en}
        Mil.Rd_IoBus (IO_Data, IO_Adr, MilErr);
        if BitTst (IO_Data, Bit_Nr) then
          Vent_Stat[N].Ist.EndA := True             {Ist-Status EndlageAu·en}
        else
          Vent_Stat[N].Ist.EndA := False;           {Ist-Status EndlageAu·en}
      end; {for}
   end; {Status_Update}

 procedure MIL_Ventil;
 label 99;
 var
   MilErr    : TMilErr;
   Fct       : TFct;
   Adr       : TIoAdr;
   RetAdr    : Byte;
   OnlineErr : TOnlineErr;
   X         : Byte;
   VNum      : Byte;
   Status_MIL_Rd : Boolean;
   Rd_Err_Old : Boolean;

 begin
  Cursor (False);
  Rd_Err_Old := False;
  Adr.IfcAdr := Ifc_Test_Nr;
  Mil.Ifc_Online (Ifc_Test_Nr, RetAdr, OnlineErr);
  if  OnlineErr <> NoErr then
   begin
    Ini_Text_Win;
    Writeln (' Wegen eines Hardware-Fehlers ist die Kontrolle der Ventile nicht mîglich!! ');
    Writeln (' Das Programm lÑuft zu Testzwecke weiter, aber kein sinnvolles Arbeiten.    ');
    Writeln;
    Writeln (' Fehlerursachen: ');
    Writeln (' 1. Das Kabel zur MIL-Interface-Karte (IFC) ist nicht angeschlosssen');
    Writeln (' 2. Die IFC ist nicht vorhanden oder defekt');
    Writeln (' 3. Die I/O-Karte FG 385 .. ist nicht vorhanden, hat falsche Basis-Adresse [00]');
    Writeln ('    oder ist defekt');
    Ini_Err_Win;
    Write ('Hardware-ERROR: IFC-Karte [',Hex_Byte (Ifc_Test_Nr),' Hex] meldet sich nicht!  Weiter mit <CR>');
    repeat until KeyEPressed;
    Set_Text_Win;
   end; {if Online_Error}

  Disp_Stat_Mask;
  for X := 1 to VEntil_Max do     {Init Status-Array}
   begin
     Vent_Stat[X].Soll.EndI := False;
     Vent_Stat[X].Soll.EndA := False;
     Vent_Stat[X].Ist.EndI  := False;
     Vent_Stat[X].Ist.EndA  := False;
   end;

  TextColor(Brown);
  GotoXY(02, 19); Write ('Legende Platten-Position: ');
  GotoXY(43, 19); Write ('Belegung Funktionstasten: ');

  Set_Leg_Win;  TextColor(Black);
  GotoXY(01, 01); Write('0 = keine Endlage !!                ');
  GotoXY(01, 02); Write('1 = Endlage erreicht                ');

  Set_TastBio_Win; TextColor(Black);
  GotoXY(01, 01); Write('F1: Platte REIN                     ');
  GotoXY(01, 02); Write('F5: Platte RAUS      F12: Hardw.Info');
  Set_Text_Win; TextColor(Black);

  Ini_Msg_Win;
  Write('Plattenpositionen werden im Loop gelesen!                          Ende mit [X]');
  Ch := '-';

  repeat
   Mil.Ifc_Online (Ifc_Test_Nr, RetAdr, OnlineErr);
   if  OnlineErr <> NoErr then  Status_MIL_Rd := False else Status_MIL_Rd := True;

   Status_Update;                   {Lese aktuelle Ventil-Stellungen}
   Disp_Stat (Status_MIL_Rd);

   if Ch = #0 then
    begin
      Ch := NewReadKey;
      case ord (Ch) of
       Taste_F1 : begin
                   Slow_Key;
                   Ini_Msg_Win;
                   Write('Welche Platte REIN ? Nr. [0..C]: '); {Endlage innen}
                   if Ask_Vent_Nr (VNum) then
                    begin
                      Vent_Stat[VNum].Soll.EndI := True;
                      Vent_Stat[VNum].Soll.EndA := False;
                      Vent_Move (VNum, Rein);
                    end;
                   Ch := ' ';  {um Eingabe X zu verhindern wegen Abort}
                  end;
       Taste_F5 : begin
                   Slow_Key;
                   Ini_Msg_Win;
                   Write('Welche Platte RAUS ? Nr. [0..C]: ');
                   if Ask_Vent_Nr (VNum) then
                    begin
                      Vent_Stat[VNum].Soll.EndA := True;
                      Vent_Stat[VNum].Soll.EndI := False;
                      Vent_Move (VNum, Raus);
                    end;
                   Ch := ' ';  {um Eingabe X zu verhindern wegen Abort}
                 end;
       Taste_F12 : begin
                   Ini_Msg_Win;
                   Write('Hardware-Voraussetzung: IFC-Nr = EF [Hex] und I/O-Karte Basis-Adr: 00;     <CR>');
                   repeat until KeyEPressed;
                 end;
      end;  {Case}

     Ini_Msg_Win;
     Write('Plattenpositionen werden im Loop gelesen!                          Ende mit [X]');
   end; {if Ch = #0 }

   Life_Sign;
    {Damit nicht unterste Zeile dauernd beschrieben werden mu·:
     prÅfe ob Text geÑndert werden mu·}

   if Rd_Err_Old then
    begin                         {Fehlertext ist bereits geschrieben}
      if Status_MIL_Rd then       {kein Lesefehler mehr: neuen Text schreiben}
        begin
          Rd_Err_Old := False;
          Ini_Msg_Win;
          Write('Plattenpositionen werden im Loop gelesen!                          Ende mit [X]');
        end;
    end
   else
    begin                         {es war vorher kein Fehler}
      if not Status_MIL_Rd then   {Lesefehler: Fehlertext schreiben}
        begin
          Rd_Err_Old := True;
          Ini_Err_Win;
          Write('ERROR: Keine IFC-Karte online!!                                   Ende mit [X]');
        end;
    end;
   if KeyEpressed then Ch := NewReadKey;
  until Ch in ['x','X'];
  99: Cursor (True);
 end; {MIL-Ventil}

BEGIN   { Hauptprogramm }
  Ifc_Test_Nr := Bio_Ifc_Adr;         {Speziell fÅr BIO-Physik geÑndert}
  MIL_Ventil;
  Window(1, 1, 80, 25);
  TextBackground(Black);
  ClrScr;
END. {mil_base}


