PROGRAM Anfeinh_54;
{Programm derzeit nur fÅr IFK bis FG 380.211 vorgesehen; sollen
 Folgekarten verwendet werden, dann mu· die Procedure IFK_DA
 entsprechend angepa·t werden.
Change History:
 erstellt am
 24.11.1999     R. Pfeil (ehem. Husterer)

}

{$S-}
{spez. MIL-Routinen in Units Datech..}


{  Aus Datech werden folgende Mil- Proceduren verwendet:

*fÅr Mil-Befehle zum Auslesen von Infos in 32Bit I/O-Registern*
   procedure Wr_ModBus (    Data: Word; Adr: TModAdr;  var MilErr: TMilErr);
   procedure Rd_ModBus (var Data: Word; Adr: TModAdr;  var MilErr: TMilErr);

   !!! Record zur Eingabe von: Adresse
   TModAdr = record                       (FÅr I/O-Karte APL FG 450....)
             AdrIfc : Byte;   (MIL-IFC-Adressse 8 Bit)
             AdrCard: Byte;   (APL-Mod-Bus Karten-Adr. Bit 13..8 = 5 Bit)
             AdrSub : Byte;   (APL-Mod-Bus Sub-Adr.    Bit  7..0 = 8 Bit)
             AdrMode: TAdrMode; (auf vorherige oder neue Adr schreiben/lesen)
            end;

   TAdrMode = (AdrNew, AdrOld); (Modulbus: Adresse neu schreiben bzw.
                                           alte Adresse benutzen: spart Zeit)

*fÅr Mil-Befehle zum Auslesen von Infos in IFK-Registern*
   procedure Wr (    Data: Word; Fct: TFct; var MilErr: TMilErr);
   procedure Rd (var Data: Word; Fct: TFct;  var MilErr: TMilErr);

   TFct = record case Byte of      !!! Record zur Eingabe von:
            1: (B: packed record         Adresse und Funktionscode
                     Adr : Byte;
                     Fct : Byte
                   end;    );
            2: (W: Word );
          end;

*fÅr beide Mil-Proceduraufrufe* *auch fÅr Mil-Befehle*
   TMilErr = (No_Err, Fc_To, Rd_To, Wr_To, Io_Adr, Io_AdrMode);
}

uses Crt, WinDos, Dos, Datech, Datech_0, Datech_1;

const
  Head_Line =
      'BELAB                                MIL_AnfE   ' +
      '                    [24.11.1999]' +
      '                 Testprogramm fÅr Anfordereinheit  AFE F423                   ';

 {IfcAdr := Ifc_Test_Nr, Adr.AdrIfc := IfcAdr, Adr_Fct.B.Adr := IfcAdr und
  Adr.AdrMode := AdrNew werden in jeder UntermenÅhauptprocedure zugewiesen}

 {folgende Konstanten werden in den Proceduren zugewiesen wo man sie braucht}
 {Sub_Adresssen fÅr Zugriffe auf die IO-Karten}
 SubAdrCh_0 = $00;  {Daten[15..0] Kanal 0 wird angesprochen zum Rd oder Wr}
 SubAdrCh_1 = $02;  {Daten[15..0] Kanal 1 wird angesprochen zum Rd oder Wr}
 SubAdr_Out_Rueck_Ch1 = $06;  {Output von Kanal 1 wird rÅckgelesen }
 SubAdr_Out_Rueck_Ch0 = $04;  {Output von Kanal 0 wird rÅckgelesen }
 SubAdr_Skal = $FC; {ergibt Ch-Belegung IN/Out und Bit-Mode 16/32}
 SubAdr_Modul_ID = $FE; {ergibt Modul_ID von LP im HByte und VG im LByte}
 SubAdr_StatusRegister_Ch1_Rd = $18; {ergibt APK-ID der Karte an Ch 1}
 SubAdr_StatusRegister_Ch0_Rd = $16; {ergibt APK-ID der Karte an Ch 0}
 {Funktionscode fÅr Zugriffe auf IFK-Register}
 FC_EPLD_Versions_Reg = $CD;  {kennzeichnet die EPLD-Version}
 FC_Contr_Reg = $CA;    {Aussage, ob VG-Leiste im Modulbus-Mode}
 FC_IFA_Mode_Reg = $97; {Aussage, ob IFK im Modulbus-Mode (Jmp)}
 {Io-Card-Adresskonstanten}
 IoCard_St1 = $01;      {Therapie-Stecker-1(Out) hÑngt an der 1. I/O Karte }
 IoCard_St2 = $02;      {Therapie-Stecker-2(Out) hÑngt an der 2. I/O Karte }
 IoCard_St3 = $03;      {Therapie-Stecker-3(In) hÑngt an der 3. I/O Karte }
 IoCard_St4 = $04;      {Therapie-Stecker-4(In) hÑngt an der 4. I/O Karte }
 IoCard_BDU_2_3 = $05;    {BDU_2 und BDU_3 hÑngen an der 5. I/O Karte }
 IoCard_BDU_1 = $06;    {BDU_1 hÑngt an der 6. I/O Karte }
 IoCard_Displ = $07;    {das Display hÑngt an der 7. I/O Karte }
 IoCard_Zus_St = $08;   {die Zusatzstecker hÑngen an der 8. I/O Karte }
 Nichts = $00;          {2.öbergabeparameter in Proc. Zweite_Wahl u. in APK}

 Return = #13;   {verwendet bei allen Loop-Schleifen}
 Esc = 27;       {Escape zum Abbruch}

type
  {TFct und TModAdr siehe oben, in Datech deklariert}
  DRec = record case Byte of
           1: ( B: packed record
                     DLowB : byte; {ASCII- Code 0..255, Rd - Position }
                     DHighB : byte {Position 0..EF, F0..FF Steuercode}
                   end;            );
           2: ( W: Word );       {16 bit Daten}
         end;

   TEin_Rec = record case Word of     { !!! Record zum Teilen von:  }
                1: (W: packed record  { 32bit Eingabe in 16bit HWord und LWord}
                         EinLow : Word;
                         EinHigh : Word
                       end;    );
                2: (L: Longint );
              end;


   t_IFC_Type = (No_IFC, IFC_old, IFC_201, IFC_203, IFC_210);{fÅr proc Wolfg}

var
  DStat, DLes, DSchreib : DRec;
  Abbruch : Char;

function Hex_Byte(b: Byte): String;
  const
    Hex_Num : String [16] = '0123456789ABCDEF';
  begin
  Hex_Byte := Hex_Num[(b shr 4) + 1] + Hex_num[(b and $0F) + 1];
  Hex_Byte[0] := CHR(2);
end; {Hex_Byte}

function Hex_Word(w: word): String;
  begin
  Hex_Word := Hex_Byte(HI(w)) + Hex_Byte(LO(w));
  Hex_Word[0] := CHR(4);
end; {Hex_Word}

{gibt ein Word (data) als String (word_bin) wieder aus}
{data muss vom Typ Word sein, sonst gibt es eine BereichsÅberschreitung}
function word_bin(data : word) : String;
  var
    i : Integer;
  begin
  for i := 1 to 16 do begin
    if (Data and $8000) <> 0 then
      Word_bin[i] := '1'
    else
      Word_Bin[i] := '0';
    Data := Data shl 1;
  end;
    Word_Bin[0] := CHR(16);
end; {Word_Bin}

procedure menue_win;
  var
    answer : Char;
  begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;        {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}
  TextColor(Blue);

  {Menuepunkte von Anf_Einh. die zusaetzlich bei der Auswahl erscheinen}
  GotoXY(5, 14);
  Writeln('       [M]<-- Display                                                         ');
  GotoXY(5, 15);
  Writeln('       [N]<-- Hardware                                                        ');
  GotoXY(5, 16);
  Writeln('       [O]<-- BDU_1                                                           ');
  GotoXY(5, 17);
  Writeln('       [P]<-- BDU_2                                                           ');
  GotoXY(5, 18);
  Writeln('       [Q]<-- BDU_3                                                           ');
  GotoXY(5, 19);
  Writeln('       [R]<-- Therapiestecker / Zusatzstecker                                 ');

  Ini_Msg_Win;
  Write('Bitte Auswahl eingeben:                                         EXIT: X-Taste ');
end; {menue_win}

{Aufforderung zur FKT-Tasten-Wahl oder Exit, unterste gruene Zeile}
procedure Fkt_Tast_Auswahl_Msg;
  begin
  ini_msg_win;
  Write(' Bitte Funktionstastenauswahl eingeben:                   EXIT: X-Taste ');
end; {Fkt_Tast_Auswahl_Msg}

{Informationsfenster z.B. bei BDU_2 fÅr MustererklÑrung verwendet}
procedure Ini_Info_Win_1;
  begin
  Window(60, 14, 79, 23);
  TextBackground(Cyan);
  TextColor(Blue);
  ClrScr;
end; {Ini_Info_Win_1}

{unterste  Zeile nur grÅn}
procedure Null_Msg;
  begin
  ini_msg_win;
  Write('                                                                        ');
end; {Null_Msg}

{Aufforderung zur Wiederholung: ' ' oder Exit: X, unterste gruene Zeile}
procedure Kleine_Auswahl_Msg;
  begin
  ini_msg_win;
  Write(' Single Step <Space>                                      EXIT: X-Taste ');
end; {Kleine_Auswahl_Msg}

{Loescht Ueberschrift Submenue}
procedure Clr_F_Tast_Topline;
  begin
  Window(1, 4, 80, 4);
  TextBackground(White);
  ClrScr;
end; {Clr_F_Tast_Topline}

{Loescht von Fehler- bzw. Erfolgsmelung bis 'Fkt-Tasten-Belegung'}
procedure Clr_F_Tast_Err_Succ;
  begin
  Window(1, 7, 80, 19);
  TextBackground(White);
  ClrScr;
end; {Clr_F_Tast_Err_Succ}

{Loescht vom 1 aufgfÅhrten Fehler bis 'Fkt-Tasten-Belegung'}
procedure Clr_F_List;
  begin
  Window(1, 9, 80, 18);
  TextBackground(White);
  ClrScr;
 end; {Clr_F_List}

{Loescht von Ueberschrift Submenue bis 'Fkt-Tasten-Belegung'}
procedure Clr_F_Tast_Output;
  begin
  Window(1, 4, 80, 10);  {von 18 auf 10 geÑndert, wegen Textfenster}
  TextBackground(White);
  ClrScr;
end; {Clr_F_Tast_Output}

{Loescht von Ueberschrift Submenue bis 'Fkt-Tasten-Belegung'}
procedure Clr_Displ_Text_Warn;
  begin
  Window (1, 10, 80, 10);
  TextBackground(White);
  ClrScr;
end; {Clr_Displ_Text_Warn}

{Lîscht Funktionstasten-AuswahlmenÅ mit öberschrift}
procedure Clr_Fkt_Tast_Win;
  begin
  Window (2, 19, 59, 23);
  TextBackground(white);
  ClrScr;
end; {Clr_Fkt_Tast_Win}

{Loescht SubmenÅtext in der 4., 5. und 6. Zeile}
procedure Clr_Sub_Menue_Text;
  begin
  Window(1, 4, 80, 6);
  TextBackground(White);
  ClrScr;
end; {Clr_Sub_Menue_Text}

{Loescht Info-Fenster und öberschrift}
procedure Clr_Info_Win_1;
  begin
  Window(60, 13, 80, 23);
  TextBackground(White);
  ClrScr;
end; {Clr_Info_Win_1}

{Loescht von Ueberschrift Submenue bis 'Fkt-Tasten-Belegung'
 und bereitet fuer neues Submenue Ueberschrift vor}
procedure Prep_Sub_Menue_Topl;
  begin
  Clr_Sub_Menue_Text;
  Set_Text_Win;
  TextColor(blue);
  GotoXY(02, 02);
end; {Prep_Sub_Menue_Topl}

{Erzeugt einen kurzen Piepton}
procedure Beep;
  begin
  Sound (220);     {Ton : 220 Hz}
  Delay (200);     {Zeit : 200 ms}
  NoSound;
end; {Beep}

{erzwungener Programmabbruch mit x-Taste, Beep bei anderem Tastendruck
 Anweisung fÅr Abbruch mit x-Taste auf Fusszeile}
procedure Programm_Abbruch_mit_Beep;
  begin
  Ini_Msg_Win;
  Write (' Abbruch!                                          EXIT : X-Taste');
  repeat
    Abbruch := NewReadKey;
      {Programmabbruch ins HauptmenÅ mu· mit X duchgefÅhrt werden,
      ansonsten Warnung bei falschem Tastendruck mit Piepton}
    if not (Abbruch in ['x','X']) then Beep
  until Abbruch in ['x','X'];
  Exit;
end; {Programm_Abbruch_mit_Beep}

{Einsatz bei Mil_Fehler: gibt Fehlermeldung aus und erzwingt
 Abbruch durch Eingabe von x mit Exit}
procedure Abbruch_Mil_Fehler_Display;
  begin
  Set_Text_Win;
  TextColor(red);
  GotoXY(02, 04);
  Write (' Nicht durchfÅhrbar, da Mil-Transfer-Fehler ! ');
  Programm_Abbruch_mit_Beep;
end; {Abbruch_Mil_Fehler_Display}

{Einsatz bei Mil_Fehler: gibt Fehlermeldung aus und erzwingt
 Abbruch durch Eingabe von x mit Exit}
procedure Abbruch_Mil_Fehler (MilErr : TMilErr);
  var
    Mil_Fehler_Art : String;
  begin
  Set_Text_Win;
  TextColor(red);
  GotoXY(02, 04);
  case MilErr of
   { No_Err : Mil_Fehler_Art := 'kein Mil_Fehler'; {eigentlich unnîtig}
   { Timeoutfehler: Adresse kînnte falsch sein; To=Zeit die gewartet wird}
    Fc_To : Mil_Fehler_Art := 'Timeout wegen Funktionscode';
    Rd_To : Mil_Fehler_Art := 'Timeout beim Lesen';
    Wr_To : Mil_Fehler_Art := 'Timeout beim Schreiben';
    Io_Adr : Mil_Fehler_Art := 'Fehler in IO-Adresse';
    Io_AdrMode : Mil_Fehler_Art := 'IO-Adress-Mode nicht ok (AdrNew, AdrOld)';
  end;  {case MilErr }
  Write (' Nicht durchfÅhrbar, da Mil-Transfer-Fehler: ',Mil_Fehler_Art);
  Programm_Abbruch_mit_Beep;
end; {Abbruch_Mil_Fehler}

procedure Set_TastSoft_Win;
  begin
  Window(02, 20, 59, 23);
  TextBackground(Green);
  TextColor(Black);
end; {Set_TastSoft_Win}

procedure Auswahl_Menue_Head;
  begin
  TextColor(blue);
  GotoXY(02,17);
  Write ('Belegung der Funktions-Tasten:');
  Set_TastSoft_Win;
  TextColor(Yellow);
end; {Auswahl_Menue_Head}

{Hier wird das Feld der Frontplatte vordefiniert, in welches die
 Åbergebenen Werte eingetragen werden}
procedure Ini_Front_Win;
  begin
  Window(22, 10, 26, 18);
  TextBackground(Green);
  TextColor(Black);
  {ClrScr; ohne das, bleiben die eingetragenen Werte erhalten}
end;

{allgemeingÅltige Frontplattenanzeige fÅr BDU_1, _2, _3
 mit öberschrift, sowie den ZeilenNr. von 1 - 8}
procedure Set_Front_Anzeige;
  var
    ZeilenNr, Zeile, I : Integer;
  begin
  Set_Text_Win;
  TextColor(Yellow);
  GotoXY(17,05); Write ('Front-Anzeige');
  Window(20, 08, 26, 18);  {bis 18, obwohl das Fenster nur bis 17 geht}
  TextBackground(Green);
  TextColor(Black);
  for I :=  1 to 2 do begin
    GotoXY (20,I) ;
    Write ('       ');
  end;
  for ZeilenNr := 1 to 8 do begin
    Zeile := (ZeilenNr + 2);
    GotoXY(20,Zeile);
    Write (ZeilenNr,'      ');
  end;
end; {Set_Front_Anzeige}

procedure Display;
{in den Records DSchreib, oder DLes bedeuten die
 LowBytes: ASCII- Code 0..255 oder Rd - Position
 HighBytes: Position 0..EF oder F0..FF Steuercode }

  const
    Max = 240; {max Fehleranzahl bei Schreib-Lesefehler}

    {Feld zur Umsetzung der Tastendezimalwerte zu Displaydezimalwerte
    !! Die Vorzahl 0 der Pfeiltasten wird in 1 umgewandelt}
    LetterNr : array[0..255] of Byte
      =(1, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 13, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 27, 0, 0, 0, 0,
       32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,
       48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63,
       64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79,
       80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95,
       96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111,
      112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 0,
      199, 252, 233, 0, 228, 224, 229, 231, 0, 235, 232, 239, 0, 236, 196, 197,
      201, 230, 198, 0, 246, 242, 0, 249, 253, 214, 220, 0, 163, 127, 0, 130,
      225, 237, 0, 250, 241, 209, 170, 186, 191, 0, 172, 0, 0, 161, 171, 187,
        0, 0, 159, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 175, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 190, 0, 0, 0, 0,
      133, 223, 134, 182, 144, 135, 181, 141, 142, 169, 145, 240, 0, 216, 136, 0,
      146, 177, 153, 152, 0, 0, 148, 0, 0, 0, 183, 155, 0, 178, 0, 0    );

  type
    {Strings auf 8 Zeichen begrenzt, da sonst das Feld mit 240 Record-
    Elementen zu viel Platz benoetigen wuerde.
    ZSchrBin und ZLesBin  koennen auch direkt in der Fehlerausgabeproc.
    SL_Err_Output errechnet werden aus den Zeichen ZSchreib, ZLes }
    FRec = record
             FehlerNr : Integer;
             ZSchreib : Char;
             ZLes     : Char;
             ZSchrBin : String [8];
             ZLesBin  : String [8];
             X_Pos    : Integer;
             Y_Pos    : Integer;
             FZeit    : String [11];
           end;

    FRecArr = array [1..max] of FRec;

{Var Erweiterung fuer Display}

  var
    Zei, FMil : Byte;
    ErrL_Pos, MilErr_Les, ErrS_Pos, MilErr_Schreib : Integer;
    SchreibZ, LeseZ, Gew_Zeich : Char;
    Antw, Bleiben, Richtung : Char;
    Pos, XPos, YPos, CursorPos, SL_Fehl_Zaehl : Integer;
    Err_Zeichen : FRecArr;
    IfcAdr : Byte;
    Adr : TModAdr;
    Sing_Loop_X : Char;
    Loop_Zaehl : Integer;

  { öberschrift fuer simuliertes Textfenster}
  procedure Displ_Text_Topline;
    begin
    Set_Text_Win;
    TextColor(yellow);
    GotoXY(05, 09);
    Write('Darstellung des Displays');
  end; {Displ_Text_Topline}

  {Simuliertes Textfenster}
  procedure Displ_Text_Win;
    begin
    Window(5, 12, 46, 17);
    TextBackground(lightgreen);
    TextColor(black);
  end; {Displ_Text_Win}

  {Simuliertes Textfenster mit öberschrift und aktuellem Text}
  procedure Prep_Displ_Text_Win;
    begin
    Displ_Text_Topline ;
    Displ_Text_Win ;
  end; {Prep_Displ_Text_Win}

  {Displayzeichen wird in Tastaturzeichen umgesetzt}
  procedure Wandel (var LeseZ : Char);
    var
      L : Integer;
    begin
    for L := 0 to 255 do begin
      if (Ord(LeseZ)) = (LetterNr [L]) then begin
        LeseZ := Char(L);
        L := 255;
      end; {if}
    end; {for}
  end; {Wandel}

  {Das Tastaturzeichen wird mittels Feld in ein Displayzeichen umgesetzt
  Das Tastaturzeichen wird zur Monitorausgabe unter Gew_Zeich abgelegt
  und spÑter fÅr Fill_Displ_Text_Win gebraucht}
  procedure Letter (var SchreibZ, Gew_Zeich : Char);
    begin
    SchreibZ := Newreadkey;
    Gew_Zeich := SchreibZ;
    while LetterNr [Ord (SchreibZ)] = 0 do begin
      Set_Text_Win;
      TextColor(red);
      GotoXY(5, 8);
      Write ('Zeichen "',SchreibZ,'" nicht darstellbar! Andere Taste betÑtigen! ');
      SchreibZ := Newreadkey;
      if Ord(SchreibZ) = Esc then Exit;
      Gew_Zeich := SchreibZ;
      Clr_Displ_Text_Warn;
    end;{while}
    SchreibZ := Char (LetterNr [Ord (SchreibZ)]);
  end; {Letter}

  {Gibt die Systemzeit in der Form: StdStd:MinMin:SecSec,HSecHSec aus}
  function Zeit : string;
    var
      Std, Min, Sec, HSec : Word;
    {fÅgt bei einer einstelligen Zahl(w) die fuehrende Null hinzu( 0+w = s )}
    function FuehrendeNull (w : Word) : string;
      var
        s : string;
      begin  {FÅhrNull}
      Str (w, s);  {wandelt Zahlenwert w in String s; Str(w:f, s) fÅr f = 0}
      if Length (s) = 1 then  {Length(s) liefert LÑnge von String als Integer}
        s := '0' + s;
      FuehrendeNull := s;
    end;   {FÅhrNull}
    begin  {Zeit, Systemzeit wird ausgelesen und als String ausgegeben}
    GetTime (Std, Min, Sec, HSec);
    Zeit := FuehrendeNull(Std)+':'+FuehrendeNull(Min)+':'+FuehrendeNull(Sec)+','+FuehrendeNull(HSec);
  end;   {Zeit}

  {Display loeschen, Cursor auf Position 0}
  procedure Del_Displ;
    var
      MilErr : TMilErr;
    begin
    {Datenwort in Ch_0 wird mit Funktionscodes beschrieben}
    Adr.AdrSub := SubAdrCh_0;
    DStat.W := $FF00;   {FF Steuercode Displ loeschen}
    MilErr := No_Err;
    Mil.Wr_ModBus (DStat.W, Adr, MilErr);
    if MilErr = No_Err then begin
      Clr_F_Tast_Output;
      Clr_F_Tast_Err_Succ;
      Prep_Sub_Menue_Topl;
      Write('Display wurde soeben gelîscht  ');
    end else begin
      TextColor(Red);
      GotoXY(02, 02); Write('Mil-Fehler beim Schreiben des Steuercodes (Display lîschen)')
    end;
  end; {Del_Displ}

  {Darstellung des Positionswertes in X-Y-Koordinaten (X=Spalte 0 - 39,
   Y=Zeile 1 - 6) aus Pos = 85 wird XPos = 5 und YPos = 3 }
  procedure Pos_zu_XY (Pos : Integer; var XPos, YPos : Integer);
    var
      Differenz, Subtr : Integer;
    begin
    Differenz := Pos;
    Subtr := 1;
    while Differenz >= 40 do begin
      Differenz := Differenz - 40;
      Inc (Subtr);
    end; {while}
    XPos := Differenz;
    YPos := Subtr;
  end;{Pos_zu_XY}

  {Cursorpositionsanzeige aktualisieren; sie ist eins weiter als Pos}
  procedure Cursor_Pos_Anzeige (CursorPos : Integer);
    begin
    Pos_zu_XY (Cursorpos, XPos, YPos); {XPos = 0 - 39, angegeben als 1 - 40}
    if YPos = 7 then YPos := 1;
    Set_Text_Win;
    GotoXY (65, 13);
    Write ('[ ',YPos:2,'  /  ',(XPos + 1):2,'  ]');
  end; {Cursor_Pos_Anzeige}

  {Cursor in Textfenster platzieren}
  procedure Cursor_Pos_In_TextWin (Pos : Integer; var XPos, YPos : Integer);
    begin
    Pos_zu_XY (Pos, XPos, YPos );
    Displ_Text_Win;
    GotoXY (XPos + 1, YPos);
  end; {Cursor_Pos_In_TextWin}

  {éndern von YPos und XPos mit den Pfeiltasten; #0 wird als Vorcode
   fÅr die Pfeiltasten Åbergeben, der 2.Code wird direkt eingelesen}
  procedure Pfeiltasten (Richtung : Char; var XPos, YPos : Integer);
    begin
    Richtung := NewReadKey;
    if Ord(Richtung) = Esc then Exit;
    case ord (Richtung) of
      Taste_Pfeil_Auf : begin  {Zeile - 1}
        YPos := YPos - 1;
        if YPos = 0 then YPos := 6;
      end; {Taste_Pfeil_Auf}
      Taste_Pfeil_Ab : begin   {Zeile + 1}
        YPos := YPos + 1;
        if YPos = 7 then YPos := 1;
      end; {Taste_Pfeil_Ab}
      Taste_Pfeil_Rechts : begin   {Spalte + 1}
        XPos := XPos + 1;
        if XPos = 40 then XPos := 0;
      end; {Taste_Pfeil_Rechts}
      Taste_Pfeil_Links : begin   {Spalte - 1}
        XPos := XPos - 1;
        if XPos = -1 then XPos := 39;
      end; {Taste_Pfeil_Links}
    end; {case Richtung}
  end; {Pfeiltasten}

  {Setzt den Cursor im Textfeld und zeigt seine Koordinaten an}
  procedure Set_U_Show_Cursor (XPos, YPos : Integer);
    begin
    {Cursorposition aktualisieren}
    Set_Text_Win;
    GotoXY (65, 13);
    Write ('[ ',YPos:2,'  /  ',(XPos + 1):2,'  ]');
    {Cursor in Textfenster platzieren}
    Displ_Text_Win;
    GotoXY (XPos + 1, YPos);
  end;  {Set_U_Show_Cursor}

  {1 Position zurÅck, dort ein Leerzeichen schreiben und nicht weitergehen}
  procedure backspace (var SchreibZ, Gew_Zeich : Char; var Pos : Integer);
    begin
      Pos := Pos - 1;
      if Pos = -1 then Pos := 239;
      SchreibZ := ' ';
      Gew_Zeich := ' ';
  end; {backspace}

  {schreiben eines Leerzeichens und Ñndern der Position: XPos := 0,
   YPos := YPos + 1, d.h. neuer Zeilenanfang, dort stehen bleiben}
  procedure C_Return (var SchreibZ : Char; var Pos : Integer );
    var
      XPos, YPos : Integer;
    begin
    Pos_zu_XY (Pos, XPos, YPos );
    if YPos = 6 then YPos := 0;
    Pos := YPos * 40;
  end; {C_Return}

  {Mil-Transfer Wr. ohne folgende Positionierung, schreibt Char auf Pos.}
  procedure Schreiben (Pos : Integer; SchreibZ : Char; var FMil : Byte);
    var
      MilErr : TMilErr;
    begin
    FMil := 0;
    ErrS_Pos := 0;
    MilErr_Schreib := 0;
    Adr.AdrSub := SubAdrCh_0; {Zeichen und Pos werden im Ch-0 abgelegt}
    Zei := Ord (SchreibZ);
    DSchreib.B.DLowB := Zei;
    DSchreib.B.DHighB := Pos;
    MilErr := No_Err;
    Mil.Wr_ModBus (DSchreib.W, Adr, MilErr );
    if MilErr <> No_Err then begin
      FMil := 1;                         {Mil-Fehler-Anzeige}
      MilErr_Schreib := MilErr_Schreib + 1 ;
      ErrS_Pos := Pos;
      Clr_F_Tast_Output;
      Clr_F_Tast_Err_Succ;
      Set_Text_Win;
      TextColor(Red);
      GotoXY(02, 02);
      Write (MilErr_Schreib, '. Mil-Fehler beim Schreiben auf Position : ',ErrS_Pos);
    end; {if}
  end;   {Schreiben}

  {Mil-Transfer Rd. mit vorheriger Positionierung, liest Char auf Pos.}
  procedure Lesen (Pos : Integer; var LeseZ : Char; var FMil : Byte);
    var
      MilErr : TMilErr;
    begin
    FMil := 0;
    ErrL_Pos := 0;  {fuer Mil-Fehler}
    MilErr_Les := 0;
    Adr.AdrSub := SubAdrCh_0; {Funktionscod wird in Ch-0 geschrieben}
    DStat.B.DHighB := $F0;          {Status F0 = Cursor setzen, }
    DStat.B.DLowB := Pos ;        { Pos, z.B. 39 wird uebergeben }
    Mil.Wr_ModBus (DStat.W, Adr, MilErr );
    DStat.B.DHighB := $F1;          {Status F1 = lesen auf Pos }
    { DStat.B.DLowB := 00;           { Low Byte egal}
    Mil.Wr_ModBus (DStat.W, Adr, MilErr );
    {Hier ist eine Verzîgerung (1ms) notwendig, weil die Lese-
    procedur schneller ist als die Schreibprocedure}
    Delay(1);
    Adr.AdrSub := SubAdrCh_1; {Ch1 - Rd}
    MilErr := No_Err;  {??? wird das nicht automatisch gesetzt}
    Mil.Rd_ModBus (DLes.W, Adr, MilErr );
    LeseZ := Chr (DLes.B.DLowB);
    if MilErr <> No_Err then begin
      FMil := 2;     {Mil-Fehler-anzeige}
      MilErr_Les := MilErr_Les + 1 ;
      ErrL_Pos := Pos;
      Clr_F_Tast_Output;
      Clr_F_Tast_Err_Succ;
      Set_Text_Win;
      TextColor(Red);
      GotoXY(02, 03);
      Write (MilErr_Les, '. Mil-Fehler beim Lesen auf Position : ',ErrL_Pos);
    end; {if}
  end; {Lesen}

  {vergleicht geschriebenes- und gelesenes Zeichen, gibt FehlerzÑhler aus
   im Fehlerfall: - Fehlerzaehler hochgezaehlt
                  - Fehlerrecord als ein Feldelement beschrieben}
  procedure Vergleich (var SL_Fehl_Zaehl : Integer; Pos : Integer; SchreibZ,
                       LeseZ : Char; var Err_Zeichen : FRecArr);
    var
      I : Integer;
      ZSByte, ZLByte : String [8];
      SZ, LZ : Word;
    begin
    if (SchreibZ <> LeseZ) then begin
      {Fehlerzahl ermittelt}
      SL_Fehl_Zaehl := SL_Fehl_Zaehl + 1;
      {Darstellung des Positionswertes in X-Y-Koordinaten}
      Pos_zu_XY (Pos, XPos, YPos);
      {Umwandlung der Zeichen SchreibZ und LeseZ in ihre BinÑrwerte}
      SZ := Ord(SchreibZ);
      LZ := Ord(LeseZ);
      ZSByte := word_bin ( SZ );    { Ord('X') macht aus x Int.}
      ZLByte := word_bin ( LZ );    { word_bin, eine BinÑrzahl}
      {Fehlerwerte werden dem Record Åbergeben}
      I := SL_Fehl_Zaehl;
      with Err_Zeichen [I] do begin {statt z.B. Err_Zeichen[I].FehlerNr := I}
        FehlerNr := I;
        ZSchreib := SchreibZ;
        ZLes := LeseZ;
        ZSchrBin := ZSByte;
        ZLesBin := ZLByte;
        X_Pos := XPos;
        Y_Pos := YPos;
        FZeit := Zeit;
      end; {with}
    end; {SchreibZ <> LeseZ}
    {Ausgabe FehlerzÑhler}
    Set_Text_Win;
    TextColor(red);
    GotoXY(61, 03);
    Write ('FehlerzÑhler : ', SL_Fehl_Zaehl:4);
  end; {Vergleich}

  {Displ_Text_Win wird auf gleicher Pos mit gewÅnschtem Zeichen
   beschrieben wie Display; Cursor wird im Fenster gesetzt}
  procedure Fill_Displ_Text_Win (SchreibZ, Bleiben : Char; Pos : Integer);
    begin
    {-Zeichen auf Pos schreiben-}
    Pos_zu_XY (Pos, XPos, YPos );
    GotoXY (XPos + 1, YPos ); {Korrektur fÅr XPos, weil von 0 - 39}
    Write (SchreibZ);         {geschrieben wird in Spalte 1 - 40}
    {-Cursor auf Pos schreiben-}
    {Sonderbehandlung bei BS und CR; Cursor mu· stehen bleiben}
    if (Bleiben = 'j') then XPos := XPos + 1
    {Korrektur, weil Cursor hinter letztem Zeichen}
     else XPos := XPos + 2;
     {Cursor von Zeilenende auf Zeilenanfang der nÑchsten Zeile gesetzt;
      ist die nÑchste Zeile die letzte Zeile, dann geht es zum Anfang}
     if XPos = 41{39} then begin
       XPos := 1;
       YPos := YPos + 1;
       if YPos = 7 then YPos := 1;
     end; {if XPos = 41}
     GotoXY (XPos, YPos );
     Write ('');
  end; {Fill_Displ_Text_Win}

  {Zeigt das Display als Fenster in aktuellem Zustand auf Monitor
   an mit Cursorpositionsanzeige}
  procedure Refresh_Win ( var Pos : Integer);
    var
      MilErr : TMilErr;
      Poss : Integer;{Laufvar darf nicht in Proc Åbergeben werden}
    begin
    Set_Text_Win;
    GotoXY (65, 12);
    Write ('[Zeile/Spalte]');
    GotoXY (48, 13);
    Write ('Cursorposition :');
    for Poss := 239 downto 0 do begin
      Lesen (Poss, LeseZ, FMil);
      Wandel ( LeseZ ); {= Korrektur fÅr gelesenes Zeichen }
      if FMil > 0  then begin
        Abbruch_Mil_Fehler_Display;   {mit Exit}
      end;
      Cursor_Pos_Anzeige (Poss );
        {hinter Cursor wegen realer Cursorposition}
      Prep_Displ_Text_Win;
      Fill_Displ_Text_Win (LeseZ, Bleiben, Poss);
    end; {for}
    Pos := Poss;
  end; {Refresh_Win}

  {Gibt im Fehlerfall auf Wunsch geschriebenes Zeichen, gelesenes Zeichen
   Fehlerzeitpunkt und die Position aus}
  procedure SL_Err_Output ( Err_Zeichen : FRecArr; SL_Fehl_Zaehl : Integer);
    var
      N, Spalte, Zeile, K, Index, Neu_Nr : Integer;
      Ant : Char;
    begin
    Clr_F_Tast_Err_Succ;
    Set_Text_Win;
    GotoXY(02, 03);
    Writeln ('Unterschied zwischen geschriebenem- und gelesenem Zeichen ');
    Write (' auch als BinÑrcode auf der Position und zur Zeit : ');
    TextColor(red);
    GotoXY(01, 05);
    Writeln ('       Schreib Zeichen   Lese Zeichen      Position                   ');
    Write ('  Nr.  Char / BinÑr      Char / BinÑr    Spalte/Zeile     Zeit          ');
    Ant := 'J';
    Neu_Nr := 1;
    Index := 1;
    while ((Ant in ['j','J']) and (Neu_Nr < Max)) do begin
      Clr_F_List;
      Ant := 'N';
      Zeile := 6;
      for K := 1 to 10 do begin
        Zeile := Zeile + 1;
        Set_Text_Win;
        TextColor(Red);
        GotoXY (2, Zeile);    {?????  hier auch mit with ?????}
        Write (Err_Zeichen [Index]. FehlerNr:3,'    ');
        Write (Err_Zeichen [Index]. ZSchreib,'   ');
        Write (Err_Zeichen [Index]. ZSchrBin,'      ');
        Write (Err_Zeichen [Index]. ZLes,'   ');
        Write (Err_Zeichen [Index]. ZLesBin,'     ');
        Write (Err_Zeichen [Index]. X_Pos:2,'    ');
        Write (Err_Zeichen [Index]. Y_Pos:1,'     ');
        Write (Err_Zeichen [Index]. FZeit);
        Index := Index + 1;
        if Index > SL_Fehl_Zaehl then
          K := 10;
      end; {for K}
      Neu_Nr := Neu_Nr + 10;
      Ini_Msg_Win;
      if Index > SL_Fehl_Zaehl then
        Write ('Das waren alle Fehler! Ausgabe mit "N" beenden oder mit "J" neu starten.')
      else
        Write ('Weitere 10 Fehler auffÅhren?   J/N ');
      Ant := NewReadKey;   {gilt fÅr then und else}
      if Ord(Ant) = Esc then Exit;
      if (Ant in ['J','j']) and (Index > SL_Fehl_Zaehl) then begin
        Index := 1;
        Neu_Nr := 1;
      end; {if Ant.., Index..}
    end; {while}
  end; {SL_Err_Output}

  {Schreiben, Lesen, Vergleichen; bei Mil-Fehler, Angabe und Abbruch}
  procedure Schr_Les_Vergl (Pos : Integer; var FMil : Byte;
                            SchreibZ : Char; var SL_Fehl_Zaehl : Integer;
                            var Err_Zeichen : FRecArr);
    begin
    {fÅr Sonderzeichen kein Schreiben, Lesen oder Vergleichen}
    if Ord(SchreibZ) > 31 then begin
      Schreiben (Pos, SchreibZ, FMil);
      Lesen (Pos, LeseZ, FMil);
      {Mil_Fehler beim Schreiben oder Lesen fÅhrt zu FMil > 0}
      if FMil > 0  then  Abbruch_Mil_Fehler_Display;
      Vergleich (SL_Fehl_Zaehl, Pos, SchreibZ, LeseZ, Err_Zeichen);
    end; {Ord(SchreibZ) > 31}
  end; {Schr_Les_Vergl}

  {Meldung Åber Schreib-Lesefehler, (Ausgabe der Fehleranzahl in  proced
   Vergleich) auf Wunsch Einzelauflistung siehe SL_Err_Output }
  procedure SL_Fehl_Auswert (SL_Fehl_Zaehl : Integer;
                                           Err_Zeichen : FRecArr);
    begin
    if SL_Fehl_Zaehl > 0 then begin
      Clr_F_Tast_Err_Succ;
      Set_Text_Win;
      TextColor(red);
      GotoXY(02, 04);
      Write ('Es ist ein Schreib-Lese-Fehler aufgetreten !    ');
      GotoXY(02, 06);
      Write('Ist eine Einzelauflistung der Schreib-Lesefehler gewÅnscht ? J/N ');
      Antw := NewReadKey;
      if Ord(Antw) = Esc then Exit;
      if Antw in ['j','J'] then
        SL_Err_Output ( Err_Zeichen, SL_Fehl_Zaehl);
    end else begin
      Set_Text_Win;
      TextColor(yellow);
      GotoXY(02, 04);
      Write ('Es ist kein Schreib-Lese-Fehler aufgetreten');
    end;
  end; {SL_Fehl_Auswert}

  {Schreiben, Lesen, Vergleichen; Mil-Fehlererkennung;
    Schreib-Lesfehlerbehandlung  }
  procedure Wr_Rd_Err ;
    var
      Po : Integer;
    begin
    for Po := 0 to 239 do begin
      Pos := Po;
      Schr_Les_Vergl (Pos, FMil, SchreibZ, SL_Fehl_Zaehl, Err_Zeichen);
      {Bei Mil-Fehler: - in Schreiben, bzw. Lesen wird FMil <> 0 gesetzt
                       - mit öbergabe von FMil ins HauptmenÅ gesprungen}
      if FMil > 0 then Exit;  {auch in Loop und Single Step}
    end;{for}
    SL_Fehl_Auswert (SL_Fehl_Zaehl, Err_Zeichen);
  end; {Wr_Rd_Err}

  {einmalige AusfÅhrung fÅr Wr_Rd_Err mit FehlerzÑhler }
  procedure Single_Wr_Rd_Err ;
    begin
    SL_Fehl_Zaehl := 0;
    Wr_Rd_Err;
    ini_msg_win;
    Std_Msg;
    Sing_Loop_X := NewReadKey;
    if Ord(Sing_Loop_X) = Esc then Exit;
  end; {Single_Wr_Rd_Err}

  {Schleifen - AusfÅhrung fÅr Wr_Rd_Err; Fehler- und SchleifenzÑhler}
  procedure Loop_Wr_Rd_Err ;
    begin
    SL_Fehl_Zaehl := 0;
    {?? Loop_Zaehl := 0;}
    repeat
      Loop_Zaehl := Loop_Zaehl + 1;
      Set_Text_Win;
      GotoXY(58, 02);
      Write ('Schleifenanzahl : ', Loop_Zaehl:4);
      Wr_Rd_Err;
    until KeyEPressed;
    ini_msg_win;
    Std_Msg;
  end; {Loop_Wr_Rd_Err}

  {Hier evtl Textaenderung fuer displayspezifische Anzeigen}
  procedure Fkt_Tasten_Auswahl_Menue;
    begin
    Auswahl_Menue_Head;  {= Text: Belegung der Funktions-Tasten}
    GotoXY(01, 01); Write('F1:Display lîschen          F5:Text/Zeichen schreiben   ');
    GotoXY(01, 02); Write('F2:Test mit $55 {01010101}                              ');
    GotoXY(01, 03); Write('F3:Test mit $AA {10101010}                              ');
    GotoXY(01, 04); Write('F4:Leuchtpunkt-Test                                     ');
    TextColor(Black);
  end; {Fkt_Tasten_Auswahl_Menue}

  Begin  {Display}
  {IFK-Adresse; mit Poties auf Steckplatine an RÅckwand eingestellt
   IFK-Adr in proc.Mil_Ask_Ifc ermittelt und in Ifc_Test_Nr gespeichert}
  IfcAdr := Ifc_Test_Nr;
  Adr.AdrIfc := IfcAdr;
  Adr.AdrCard := IoCard_Displ;  {das Display hÑngt an der 7. IO-Card}
  Adr.AdrMode := AdrNew;  {die Mode-Adresse wird neu "berechnet"}
  {*** Sternchenteil Gerd***}
  Clr_Sub_Menue_Text;     {Lîscht Meldung Åber IFK- Anzahl und - Adresse}
  Set_Text_Win; TextColor(Yellow);
  GotoXY(02,01);
  Write('Test des Displays !');
  Fkt_Tasten_Auswahl_Menue;
  Abbruch := ' ';
  Fkt_Tast_Auswahl_Msg;  {Fkt-Taste oder X}
  Ch := NewReadKey;
  if Ord(Ch) = Esc then Exit;
  if Ch in ['x','X'] then Exit;
  repeat
    if Ch = #0 then begin
      Ch := NewReadKey;
      if Ord(Ch) = Esc then Exit;
      case ord (Ch) of

        Taste_F1 : begin      {clear Display}
          Clr_F_Tast_Output;
          Clr_F_Tast_Err_Succ;
          Del_Displ;
          Fkt_Tast_Auswahl_Msg;
          {feststellen, da· Ifk nicht ansprechbar ist Åber proc.Lesen}
          Pos := 2;
          Lesen (Pos, LeseZ, FMil);
          if FMil > 0  then begin
            Clr_F_Tast_Output;
            Clr_F_Tast_Err_Succ;
            Abbruch_Mil_Fehler_Display;  {Exit; schon mit drin}
          end;
        end; {F1-Taste}

        {Bit-01-Test wird einmal ausgefuehrt! evtl. ein-, oder mehrmals
        wiederholt; mit X befindet man sich wieder in der Funktionstastenwahl}
        Taste_F2 : begin      {Bit-Folge 0-1-0-1}
          Clr_Fkt_Tast_Win;
          SchreibZ := #$55;   {= #85}
          Clr_F_Tast_Output;
          Clr_F_Tast_Err_Succ;
          Prep_Sub_Menue_Topl;
          Writeln ('(F2-Taste): 0-1-Test wurde ausgefÅhrt ');
          Write (' Das Display zeigt auf jeder Position ein "U"');
          Single_Wr_Rd_Err;
          if FMil > 0 then Exit;
          {schon in Single_Wr_Rd_Err, darum entfernt; auch in F3 , F4}
          {Sing_Loop_X := NewReadKey;}
          if Ord(Sing_Loop_X) = Esc then Exit;
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                Clr_F_Tast_Output;
                Clr_F_Tast_Err_Succ;
                Prep_Sub_Menue_Topl;
                Write ('(F2-Taste): 0-1-Test wurde erneut ausgefÅhrt ');
                Single_Wr_Rd_Err;
                if FMil > 0 then Exit;
              end;  {' '}
              {Loop mit Ermittlung und Ausgabe des SchleifenzÑhlers }
              Return : begin
                Loop_Zaehl := 0;
                Clr_F_Tast_Output;
                Clr_F_Tast_Err_Succ;
                Prep_Sub_Menue_Topl;
                Write ('(F2-Taste): 0-1-Test wird dauerhaft ausgefÅhrt ');
                ini_msg_win;
                Write ('beliebiger Tastendruck fÅhrt zum Abbruch');
                Loop_Wr_Rd_Err;
                if FMil > 0 then Exit;
              end; {Return}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Fkt_Tasten_Auswahl_Menue;
          Fkt_Tast_Auswahl_Msg;
        end; {F2-Taste}

        {Bit-10-Test wird einmal ausgefuehrt! evtl. ein-, oder mehrmals
        wiederholt; mit X befindet man sich wieder in der Funktionstastenwahl}
        Taste_F3 : begin       {Bit-Folge 1-0-1-0}
          Clr_Fkt_Tast_Win;
          SchreibZ := #$AA;    {= #170}
          Clr_F_Tast_Output;
          Clr_F_Tast_Err_Succ;
          Prep_Sub_Menue_Topl;
          Writeln ('(F3-Taste): 1-0-Test wurde ausgefÅhrt ');
          Write (' Das Display zeigt auf jeder Position ein "a" unterstrichen');
          Single_Wr_Rd_Err;
          if FMil > 0 then Exit;
          if Ord(Sing_Loop_X) = Esc then Exit;
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                Clr_F_Tast_Output;
                Clr_F_Tast_Err_Succ;
                Prep_Sub_Menue_Topl;
                Write ('(F3-Taste): 1-0-Test wurde erneut ausgefÅhrt ');
                Single_Wr_Rd_Err;
                if FMil > 0 then Exit;
              end;  {' '}
              {Loop mit Ermittlung und Ausgabe des SchleifenzÑhlers }
              Return : begin
                Loop_Zaehl := 0;
                Clr_F_Tast_Output;
                Clr_F_Tast_Err_Succ;
                Prep_Sub_Menue_Topl;
                Write ('(F3-Taste): 1-0-Test wird dauerhaft ausgefÅhrt ');
                ini_msg_win;
                Write ('beliebiger Tastendruck fÅhrt zum Abbruch');
                Loop_Wr_Rd_Err;
                if FMil > 0 then Exit;
              end; {Return}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Fkt_Tasten_Auswahl_Menue;
          Fkt_Tast_Auswahl_Msg;
        end; {F3-Taste}

        Taste_F4 : begin       {optischer Test der Displayleuchtpunkte}
          Clr_Fkt_Tast_Win;
          SchreibZ := #$BE;    {= #190}
          Clr_F_Tast_Output;
          Clr_F_Tast_Err_Succ;
          Prep_Sub_Menue_Topl;
          Writeln ('(F4-Taste): Leuchtpunkttest wurde ausgefÅhrt');
          Write(' Bitte auf das Display sehen und Punkte ÅberprÅfen');
          Single_Wr_Rd_Err;
          if FMil > 0 then Exit;
          if Ord(Sing_Loop_X) = Esc then Exit;
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              ' ' : begin          {Single Step}
                Clr_F_Tast_Output;
                Clr_F_Tast_Err_Succ;
                Prep_Sub_Menue_Topl;
                Writeln ('(F4-Taste): Leuchtpunkttest wurde erneut ausgefÅhrt');
                Write(' Bitte auf das Display sehen und Punkte ÅberprÅfen');
                Single_Wr_Rd_Err;
                if FMil > 0 then Exit;
              end;  {' '}
              {Loop mit Ermittlung und Ausgabe des SchleifenzÑhlers }
              Return : begin
                Loop_Zaehl := 0;
                Clr_F_Tast_Output;
                Clr_F_Tast_Err_Succ;
                Prep_Sub_Menue_Topl;
                Writeln ('(F4-Taste): Leuchtpunkttest wurde ausgefÅhrt');
                Write(' Bitte auf das Display sehen und Punkte ÅberprÅfen');
                ini_msg_win;
                Write ('beliebiger Tastendruck fÅhrt zum Abbruch');
                Loop_Wr_Rd_Err;
                if FMil > 0 then Exit;
              end; {Return}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Del_Displ;
          Fkt_Tasten_Auswahl_Menue;
          Fkt_Tast_Auswahl_Msg;
        end; {F4-Taste}

        {beliebiger Text wird auf beliebige Position gesetzt;
         evtl. ein-, oder mehrmals wiederholt;
         mit X befindet man sich wieder in der Funktionstastenwahl}
        Taste_F5 : begin         { Text positionieren }
          Null_Msg;
          Clr_Fkt_Tast_Win;
          Sing_Loop_X := ' '; {Funktion entspricht 1. Wiederholung}
          SL_Fehl_Zaehl := 1;  {Refresh_Win wird ausgefÅhrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              ' ' : begin          {Single Step}
                {neues Display im Fall von Schr_Les_Fehler}
                if SL_Fehl_Zaehl > 0 then begin
                  Clr_F_Tast_Output;
                  Clr_F_Tast_Err_Succ;
                  Prep_Sub_Menue_Topl;
                  Refresh_Win (Pos);
                  if FMil > 0 then Exit;
                end;
                Clr_F_Tast_Output;
                TextColor(black);
                Write (' Bitte den Text eingeben! ');
                Writeln ('   "Esc" fÅhrt zur Beendigung der Texteingabe');
                Write (' (F5-Taste): GewÅnschtes Zeichen wird geschrieben ');
                SL_Fehl_Zaehl := 0;
                {spezielle Fusszeile fÅr Text}
                ini_msg_win;
                Write(' Texteingabe beenden mit "Esc"                     ');
                Cursor_Pos_In_TextWin (Pos, XPos, YPos);
                Letter (SchreibZ, Gew_Zeich);   {G_Z = eingetipptes Zeichen}
                {nÑchste Zeile wichtig, da FMil erst in Schr_Les_Vergl gesetzt wird}
                if SchreibZ = #27 then FMil := 0;
                while SchreibZ <> #27 do begin
                  {Cursorneuplatzierung wÑhrend des Schreibens}
                  while SchreibZ = #1 do begin
                    SchreibZ := #0; {zurÅcktauschen wegen proc.Pfeiltast.}
                    Pfeiltasten (SchreibZ, XPos, YPos);
                    Set_U_Show_Cursor (XPos, YPos);
                    Pos := (YPos - 1) * 40 + (XPos);
                    Letter (SchreibZ, Gew_Zeich);
                  end;
                  {nach Backspace und C_Return wird nicht an die nÑchste Position gehÅpft}
                  if ( (Ord(SchreibZ) = 8) or  (Ord(SchreibZ) = 13) )
                  then Bleiben := 'j'  {FÅr Pos Korrekturen bei BS und CR}
                  else Bleiben := 'n';
                  if Ord(SchreibZ) = 8 then
                    backspace (SchreibZ, Gew_Zeich, Pos);
                  if Ord(SchreibZ) = 13 then
                    C_Return (SchreibZ, Pos);
                  Schr_Les_Vergl (Pos, FMil, SchreibZ, SL_Fehl_Zaehl, Err_Zeichen);
                  if (Bleiben = 'j') then Pos := Pos - 1;
                  CursorPos := Pos + 1;
                  Cursor_Pos_Anzeige (CursorPos);
                  Prep_Displ_Text_Win; {Fenster bleibt, bis F5 verlassen}
                  if (Bleiben = 'j') then
                    Fill_Displ_Text_Win (Gew_Zeich, Bleiben, Pos + 1)
                  else
                    Fill_Displ_Text_Win (Gew_Zeich, Bleiben, Pos);
                  if FMil > 0 then Exit;
                  Pos := Pos + 1;
                  {schÅzt vor dem Beschreiben der 7. Zeile}
                  if Pos = 240 then Pos := 0;
                  Letter (SchreibZ, Gew_Zeich); {= eingetipptes Zeichen}
                end; {while}
                SL_Fehl_Auswert (SL_Fehl_Zaehl, Err_Zeichen);
                ini_msg_win;
                Kleine_Auswahl_Msg;
                Sing_Loop_X := NewReadKey;
                if Ord(Sing_Loop_X) = Esc then Exit;
              end;  {' '}
            end; {case}
            {nochmal ' ' ?; Sing_Loop_X := NewReadKey wÅrde reichen }
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Fkt_Tasten_Auswahl_Menue;
          Fkt_Tast_Auswahl_Msg;
        end; {F5-Taste}

      end; {case}
    end; {   if Ch = #0 then  }
    if KeyEPressed then Ch := NewReadKey;
    if Ord(Ch) = Esc then Exit;
  until Ch in ['x','X'];
End; {Display}


{ermittelt aus Statusregister, bzw. Skalierung Adressen von IFK und
 Modulen, sowie den Bit- Mode und die Verwendung der KanÑle;
 vergleicht die gefundenen Werte mit den Sollwerten und gibt dann
 eine ok-Meldung oder eine Fehlermeldung aus }
procedure Hardware;
  type
    {Record fÅr ok-Test und Fehlerausgabe}
    Skal_Rec = record
                 Skal_Bit15 : String [3];
                 Skal_Bit14 : String [3];
                 Skal_Bit13 : String [1];
                 Skal_Bit12 : String [6];
    {!!! end}  end;
    {FÅr jede I/O-Karte 1-8 ein Record mit 8 Strings fÅr Bit 12 - 15.
     Ist die 8.Karte nicht vorhanden, so bleibt das letzte Record unbeachtet}
     Skal_Rec_Arr = array [1..8] of Skal_Rec;
  var
    MilErr : TMilErr;
    IfcAdr : Byte;
    Adr : TModAdr;
    Sing_Loop_X : Char;
    Karte_8_da : Boolean;     {fÅr Proc APK und IO...}
    IO_Card_Max_Zahl : Word;  {fÅr Proc APK und IO...}

  {Ausgabe BDU3-Status entsprechend der öbergabeparameter, mit öberschrift }
  procedure BDU3_Ausgabe (Prell, V_wo, V_da : Integer);
    const
      EPrell : array [0..3] of String
                 = ('keine', '100Ês', '300Ês', '700Ês');
      Spng : array [0..3] of String
               = ('+15V extern', '+15V intern', 'vorhanden',
                  'nicht vorhanden');
    begin
    Clr_F_Tast_Err_Succ;
    Set_Text_Win;
    TextColor(Yellow);
    GotoXY(06,06); Write ('BDU3 Status; Entprellung und Spannungsversorgung:');
    TextColor(Black);
    GotoXY(06,08); Write ('eingestellte Entprellung: ');
    GotoXY(06,09); Write ('Spannung: ');
    TextColor(Blue);
    GotoXY(32,08); Write (EPrell[Prell]);
    {Fehlerauswertung in BDU3_Lies_Status}
    if V_da = 3 then TextColor(Red);
    {ab Position 15, weil bis dahin 'Spannung steht'}
    GotoXY(16,09); Write (Spng[V_wo],' ', Spng[V_da] );
  end; {BDU3_Ausgabe}

  {Ausgabe-Struktur fÅr Ausgabe_APK_Ok, mit öberschrift }
  procedure Ausgabe_Struktur_APK;
    begin
    Set_Text_Win;
    TextColor(Yellow);
    GotoXY(06,06); Write ('Infos zu den APK:');
    TextColor(Black);
    GotoXY(06,08); Write ('APK-ID [Hex]     Modul  Ch     APK-Name            ');
  end; {Ausgabe_Struktur_APK}

  {Ausgabe-Daten fÅr Ausgabe_APK_Ok}
  procedure Ausgabe_Daten_APK_Ok;
    begin
    Set_Text_Win;
    TextColor(Blue);
    GotoXY(06,09); Write ('    01             06    1     BDU1 FG 423 101      ');
    GotoXY(06,10); Write ('    02             05    1     BDU2 FG 423 201      ');
    GotoXY(06,11); Write ('    03             05    0     BDU2 FG 423 301      ');
    GotoXY(06,12); Write ('    04             07   1/0    ADI FG 423 400       ');
    GotoXY(06,13); Write ('    07             08    1     OUT50 FG 423 241/242 ');
    GotoXY(06,14); Write ('    07             08    0     OUT50 FG 423 241/242 ');
    if Not Karte_8_da then  {Ausgabe, wenn Zusatzkarte, 8.IO fehlt}
      begin
      GotoXY(06,13);
      Write ('APK fÅr die Zusatzstecker nicht getestet, da die    ');
      GotoXY(06,14);
      Write ('I/O Karte (Card_ID: 08) nicht vorhanden ist         ');
    end;
  end; {Ausgabe_Daten_APK_Ok}

  {Ausgabe-Struktur fÅr Ausgabe_I/O_Modul_Ok, mit öberschrift }
  procedure Ausgabe_Struktur_IO_Modul;
    begin
    Clr_F_Tast_Err_Succ;
    Set_Text_Win;
    TextColor(Yellow);
    GotoXY(06,06); Write ('Infos zu den I/O_Modulen:');
    TextColor(Black);
    GotoXY(06,07); Write ('alle gefundenen I/O-Module Nr.: FG 450361 mit Modul-ID 36 (dez):');
    GotoXY(06,08); Write ('Mod-Adr   Modul-ID: LP/VG   ??-Bit-Mode   Ch-1/APK   Ch-0/APK');
  end; {Ausgabe_Struktur_I/O_Modul}

  {Ausgabe-Daten fÅr Ausgabe_I/O_Modul_Standard_Ok}
  procedure Ausgabe_Daten_IO_Modul_Standard_Ok;
    begin
    Set_Text_Win;
    TextColor(Blue);
    GotoXY(06,09); Write ('  01   nicht bestÅckt!                                          ');
    GotoXY(06,10); Write ('  02   nicht bestÅckt!                                          ');
    GotoXY(06,11); Write ('  03   nicht bestÅckt!                                          ');
    GotoXY(06,12); Write ('  04   nicht bestÅckt!                                       ');
    GotoXY(06,13); Write ('  05        [Hex]   24 24     16-Bit      Out / J    In  / J ');
    GotoXY(06,14); Write ('  06        [Hex]   24 24     16-Bit      Out / J    In    -   ');
    GotoXY(06,15); Write ('  07        [Hex]   24 24     16-Bit      In  / J    Out / J ');
    GotoXY(06,16); Write ('  08        [Hex]   24 24     16-Bit      Out / J    Out / J ');
    if Not Karte_8_da then {Ausgabe, wenn Zusatzkarte, 8.IO fehlt}
      begin
      GotoXY(06,16);
      Write ('  Karte 08 fÅr die Zusatzstecker nicht vorhanden             ');
    end;
    TextColor(Black);
    GotoXY(06,17); Write ('Standardkonfiguration: ModulplÑtze 1-4 nicht bestÅckt !        ');
  end; {Ausgabe_Daten_I/O_Modul_Standard_Ok}

  {Ausgabe-Daten fÅr Ausgabe_I/O_Modul_Therapie_Ok}
  procedure Ausgabe_Daten_IO_Modul_Therapie_Ok;
    begin
    Set_Text_Win;
    TextColor(Blue);
    GotoXY(06,09); Write ('  01        [Hex]   24 24     16-Bit      Out / N    Out / N ');
    GotoXY(06,10); Write ('  02        [Hex]   24 24     16-Bit      Out / N    Out / N ');
    GotoXY(06,11); Write ('  03        [Hex]   24 24     16-Bit      In  / N    In  / N ');
    GotoXY(06,12); Write ('  04        [Hex]   24 24     16-Bit      In  / N    In  / N ');
    GotoXY(06,13); Write ('  05        [Hex]   24 24     16-Bit      Out / J    In  / J ');
    GotoXY(06,14); Write ('  06        [Hex]   24 24     16-Bit      Out / J    In  / - ');
    GotoXY(06,15); Write ('  07        [Hex]   24 24     16-Bit      In  / J    Out / J ');
    GotoXY(06,16); Write ('  08        [Hex]   24 24     16-Bit      Out / J    Out / J ');
    if Not Karte_8_da then   {Ausgabe, wenn Zusatzkarte, 8.IO fehlt}
      begin
      GotoXY(06,16);
      Write ('  Karte 08 fÅr die Zusatzstecker nicht vorhanden             ');
    end;
    TextColor(Black);
    GotoXY(06,17); Write ('Therapiekonfiguration: ModulplÑtze 1-4 bestÅckt !        ');
  end; {Ausgabe_Daten_I/O_Modul_Therapie_Ok}

  {Ausgabe-Struktur fÅr Ausgabe_IFK_Ok, mit öberschrift }
  procedure Ausgabe_Struktur_IFK;
    begin
    Set_Text_Win;
    TextColor(Yellow);
    GotoXY(06,06); Write ('Infos zur IFK:');
    TextColor(Black);
    GotoXY(06,08); Write ('IFK-Nr:                            IFK-Adresse [Hex]:      ');
    GotoXY(06,09); Write ('Verdrahtung:                       Karte:            ');
    GotoXY(06,10); Write ('EPLD: ');
  end; {Ausgabe_Struktur_IFK}

  {Ausgabe-Daten fÅr Ausgabe_IFK_Ok}
  procedure Ausgabe_Daten_IFK_Ok (IfcAdr_Hex : String);
    begin
    Set_Text_Win;
    TextColor(Blue);
    GotoXY(14,08); Write ('FG 380.211');
    GotoXY(60,08); Write (IfcAdr_Hex );
    GotoXY(19,09); Write ('fÅr Modulbusbetrieb ');
    GotoXY(48,09); Write ('im Modulbusbetrieb ');
    GotoXY(12,10); Write ('Version A ');
  end; {Ausgabe_Daten_IFK_Ok}

  {Struktur fÅr Fehlerausgabe}
  procedure Fehler_Ausgabe_IFK_Struktur;
    begin
    Set_Text_Win;
    TextColor(Yellow);
    GotoXY(06,06); Write ('Infos zur IFK:');
    TextColor(Red);
  end; {Fehler_Ausgabe_IFK_Struktur}

  {Funktionstastenauswahl Hardware}
  procedure Fkt_Tasten_Auswahl_MenueH;
    begin
    Auswahl_Menue_Head;
    GotoXY(01, 01); Write('F1: Hardwaretest der Gesamtkonfiguration                ');
    GotoXY(01, 02); Write('F2: BDU_3: Spannungsversorgung und Entprellung          ');
    TextColor(Black);
  end; {Fkt_Tasten_Auswahl_MenueH}

  {BDU3-Status auslesen umsetzen fÅr öbergabeparameter fÅr BDU3_Ausgabe}
  procedure BDU3_Lies_Status (var Prell, V_wo, V_da : Integer);
    var
      { MilErr : TMilErr; weg, weil global schon }
      BDU3_Status_Port, Status_Port_5Li, Status_Port_5Li13Re : Word;
      Status_Port_3Li, Status_Port_3Li15Re : Word;
      Status_Port_1Li, Status_Port_1Li14Re, Bit14_13 : Word;
    begin
    Adr.AdrCard := IoCard_BDU_2_3;
    Adr.AdrSub := SubAdr_StatusRegister_Ch0_Rd; { =$16}
    MilErr := No_Err;
    Mil.Rd_ModBus (DLes.W, Adr, MilErr );
    if MilErr <> No_Err then begin
      Clr_F_Tast_Output;
      Clr_F_Tast_Err_Succ;
      Abbruch_Mil_Fehler (MilErr); {mit Exit}
    end;
    BDU3_Status_Port := DLes.W;
    Status_Port_5Li := BDU3_Status_Port shl 5;
    Status_Port_5Li13Re := Status_Port_5Li shr 13;
    Prell := Status_Port_5Li13Re;                  {Entprellung}
    Status_Port_3Li := BDU3_Status_Port shl 3;
    Status_Port_3Li15Re := Status_Port_3Li shr 15;
    V_wo := Status_Port_3Li15Re;                   {extern/intern}
    Status_Port_1Li := BDU3_Status_Port shl 1;
    Status_Port_1Li14Re := Status_Port_1Li shr 14;
    Bit14_13 := Status_Port_1Li14Re;
    {V_wo = 1(int) und 13_14 = 1(int vorhanden) / 2(ext) und 0(ext vorhanden)}
    if (Bit14_13 = 0) or ((Bit14_13 + V_wo) = 2) then V_da := 2  {vorhanden}
    else V_da := 3; {nicht vorhanden}
  end; {BDU3_Lies_Status}

  {Status von BDU3 ermitteln (BDU3_Lies_Status) und ausgeben (BDU3_Ausgabe)}
  {prell (0-3): keine 100, 300, 700Ês
   V_wo (0-1): + 15V extern, + 15V intern
   V_da (2-3): vorhanden, nicht vorhanden}
  procedure BDU3_Status;
    var
      Prell, V_wo, V_da : Integer;
    begin
    BDU3_Lies_Status (Prell, V_wo, V_da);
    BDU3_Ausgabe (Prell, V_wo, V_da);
    if V_da = 3 then Programm_Abbruch_mit_Beep;
  end; {BDU3_Status}

  {Ausgabe des EPLD-Versions-Registers mit FC=CD; sind Bit 8..15 = 03, so liegt
   Version A vor, wenn nicht, keine Aussage }
  procedure EPLD_Versions_Register (var Version : Word);
    var
      { MilErr : TMilErr; weg, weil global schon}
      Adr_Fct : TFct;
      {Inhalt mu· hier gesondert angegeben werden als Word}
      Inh, EPLD_Vers_Regi, EPLD_Vers_Regi_8Re : Word;
    begin
    Adr_Fct.B.Adr := IfcAdr;
    Adr_Fct.B.Fct := FC_EPLD_Versions_Reg;
    MilErr := No_Err;
    Mil.Rd(Inh, Adr_Fct, MilErr);
    if MilErr <> No_Err then begin
      Clr_F_Tast_Output;
      Clr_F_Tast_Err_Succ;
      Abbruch_Mil_Fehler (MilErr); {mit Exit}
    end;
    EPLD_Vers_Regi := Inh;
    EPLD_Vers_Regi_8Re := EPLD_Vers_Regi Shr 8;
    Version := EPLD_Vers_Regi_8Re
  end;

  {Ausgabe des Control-Registers mit FC=CA; steht in Bit 12 des Registers
   eine 0, so ist die VG-Leiste fÅr Modulbus-Betrieb geeignet}
  procedure Control_Register (var Bit_12 : Word);
    var
      { MilErr : TMilErr; weg, weil global schon }
      Adr_Fct : TFct;
      {Inhalt mu· hier gesondert angegeben werden als Word}
      Inhalt, Control_Regi, CR_3Li, CR_3Li_15Re : Word;
    begin
    Adr_Fct.B.Adr := IfcAdr;
    Adr_Fct.B.Fct := FC_Contr_Reg;
    MilErr := No_Err;
    Mil.Rd(Inhalt, Adr_Fct, MilErr);
    if MilErr <> No_Err then begin
      Clr_F_Tast_Output;
      Clr_F_Tast_Err_Succ;
      Abbruch_Mil_Fehler (MilErr);  {mit Exit}
    end;
    Control_Regi := Inhalt;
    CR_3Li := Control_Regi SHL 3;
    CR_3Li_15Re := CR_3Li SHR 15; {entspricht Bit 12 des Control-Registers}
    Bit_12 := CR_3Li_15Re;
  end;

  {Ausgabe des IFA-Mode-Registers mit FC=97;
   Registerinhalt: 0 = IFA(allg.Ifk), 1 = FG, 2 = MB(Modulbus), 4 = Sweeper}
  procedure IFA_Mode_Register (var Daten : Word);
    var
      { MilErr : TMilErr; weg, weil global schon}
      Adr_Fct : TFct;
      DOut : Word;
      Bin_Daten, Hex_Daten : String;
    begin
    Adr_Fct.B.Adr := IfcAdr;
    Adr_Fct.B.Fct := FC_IFA_Mode_Reg;
    MilErr := No_Err;
    Mil.Rd(DOut, Adr_Fct, MilErr);
    if MilErr <> No_Err then begin
      Clr_F_Tast_Output;
      Clr_F_Tast_Err_Succ;
      Abbruch_Mil_Fehler (MilErr);  {mit Exit}
    end;
    Daten := DOut;{hier wird eine 2 fÅr Modulbusbetrieb erwartet,sonst Fehler}
  end;

  {IFC_DA ist eine Fkt. des AufzÑhlungstyps t_IFC_Type; somit kann eines
   der aufgezÑhlten Elementen dem Fkt.Namen zugewiesen werden.
   Elemente des AufzÑhlungstyps kînnen nicht gelesen und nicht geschrieben
   werden, deshalb kann auch 'IFC_DA' nicht geschrieben werden }

  {Liefert IFK_ID; mu· mit der Verwendung neuerer IFK's (>.211) angepa·t
   werden, indem der neue Status in die Case-Anweisung eingetragen wird}
  function IFC_DA(IfcAdr: byte) : t_IFC_Type;
    const
      c_fc_stat   = $C0;
      c_fc_ifk_id = $CC;
    var
      MilErr : TMilErr;  {hier drin lassen, weil procedur Wolfgang}
      Adr_Fct : TFct;
      Status : Word;
    begin
    Adr_Fct.B.Adr := IfcAdr;
    Adr_Fct.B.Fct := c_fc_stat;
    MilErr := No_Err;
    Mil.Rd(status, Adr_Fct, MilErr);
    if MilErr = No_Err then begin
      if (Status and $00FF) = IfcAdr then
        Adr_Fct.B.Fct := c_fc_ifk_id;
        Mil.Rd(status, Adr_Fct, MilErr);
        if MilErr = No_Err then begin
          if (Status and $00FF) = IfcAdr then
            IFC_DA := IFC_old
          else
            case status of
           {! $XXXX: IFC_DA := IFC_2XX; Erweiterung fÅr Folgekarten von .211}
           {! $XXXX: IFC_DA := IFC_2XX; Erweiterung fÅr Folgekarten von .211}
              $FB00: IFC_DA := IFC_210;
              $FC00: IFC_DA := IFC_203;
              $FE00: IFC_DA := IFC_201;
            else
              IFC_DA := IFC_old;
            end; {case}
        end {if MilErr}
      else
        IFC_DA := No_IFC;
    end {if MilErr}
  else
    IFC_DA := No_IFC;
  end; {IFC_DA}


  {IFK-Infos ermitteln, bewerten und Ausgabe veranlassen}
  procedure IFK;
{!!! noch weg   type   mit: CASE Konstante und Selektor haben verschiedene Datentypen
      t_IFC_Type = (No_IFC, IFC_old, IFC_201, IFC_203, IFC_210); }
    var
     Meldung, IfcAdr_Hex : String;
     Bit_12, Daten, Version : Word;
    begin
    case IFC_DA(IfcAdr) of
    No_IFC : Meldung := 'keine IFK vorhanden';
    IFC_old : Meldung := 'alte IFK vorhanden';
    IFC_210 : Meldung := 'IFK_ID: FG 380.211';
    {  IFC_2XX : Meldung := 'IFK_ID: FG 380.2XX'; }
    {  IFC_2XX : Meldung := 'IFK_ID: FG 380.2XX';}
    else Meldung := 'falsche IFK'
    end;  {case}
    {hier Ausgabe Åber falsche IFK, oder weitere PrÅfung}
    if (Meldung <> 'IFK_ID: FG 380.211') then
      begin
      Fehler_Ausgabe_IFK_Struktur;
      GotoXY(06,08); Write ('letzte IFK-Adresse [Dez]: ',IfcAdr );
      GotoXY(06,09); Write ('Version: FG 380.211 nicht gefunden; ', Meldung );
      Programm_Abbruch_mit_Beep;
    end; {if Meldung}
    { die Abfrage bezÅglich Abbruch hier, da die if-Schleife eh zu Ende ist}
    if (Abbruch in ['x','X']) then Exit;
    Control_Register (Bit_12); {Bit 12 sagt, ob VG-Leiste im Modulbusbetrieb}
    if Bit_12 = 1 then
      begin
      Fehler_Ausgabe_IFK_Struktur;
      GotoXY(06,08); Write ('VG-Leiste ist nicht fÅr Modulbusbetrieb verdrahtet ! ');
      Programm_Abbruch_mit_Beep;
      {hier diese Abfrage nach Abbruch, damit auch hier rausgesprungen wird}
      {if (Abbruch in ['x','X']) then Exit }
    end; {if Bit_12}
    if (Abbruch in ['x','X']) then Exit;
    IFA_Mode_Register (Daten); {fÅr welchen Mode ist der Jumper auf der IFK gesetzt?}
    if Daten <> 2 then
      begin
      Fehler_Ausgabe_IFK_Struktur;
      GotoXY(06,08); Write ('Jumper auf der IFK ist nicht fÅr ModulBus-Interface gesteckt ! ');
      Programm_Abbruch_mit_Beep;
      {hier diese Abfrage nach Abbruch, damit auch hier rausgesprungen wird}
      {if (Abbruch in ['x','X']) then Exit }
    end;{if Daten}
    if (Abbruch in ['x','X']) then Exit;
    {Ausgabe fÅr alles ok}
    IfcAdr_Hex := hex_word (IfcAdr);
    Ausgabe_Struktur_IFK;
    Ausgabe_Daten_IFK_Ok (IfcAdr_Hex);
    EPLD_Versions_Register (Version); {nur Test, ob Version A, wenn nicht, dann Ñndern}
    if Version <> 3 then
      begin
      GotoXY(12,10);
      Write ('keine Version erkennbar ');
    end; {if Version}
  end; {IFK}

  {Ausgabe-Daten im Fehlerfall; Fehler werden rot Åber ok-Ausgabe geschrieben}
  procedure Partielle_Fehler_Ausgabe (Skalierung_Bit12_15 : Skal_Rec_Arr;
                                      Auslegung : Char);
    var
      Zeile, Linie, Anfang, Karte : Word;
    begin
    Set_Text_Win;
    TextColor(red);
    if Auslegung = 'S' then Anfang := 5
    else Anfang := 1;

    for Karte := Anfang to IO_Card_Max_Zahl do { IO_Card_Max_Zahl := 8 od 8;}
      begin
      Zeile := 8 + Karte;  {8 ist Offset, Karte entspricht der Modul-ID}
      with Skalierung_Bit12_15[Karte] do  {Fehler ausgeben}
        begin
        if Skal_Bit12 <> '      ' then
          begin
          GotoXY(36, Zeile); Write (Skal_Bit12);
        end; {if Bit12}
        if Skal_Bit15 <> '   ' then
          begin
          GotoXY(48, Zeile); Write (Skal_Bit15);
        end; {if Bit15}
        if Skal_Bit13 <> ' ' then
          begin
          GotoXY(54, Zeile); Write (Skal_Bit13);
          GotoXY(65, Zeile); Write (Skal_Bit13);
        end; {if Bit13}
        if Skal_Bit14 <> '   ' then
          begin
          GotoXY(59, Zeile); Write (Skal_Bit14);
        end; {if Bit14}
      end; {with}
    end; {for Karte}
  end; {Partielle_Fehler_Ausgabe}

  {Skalier (= Soll) und Modul_Skalier_12Re (= Ist) werden verglichen; bei
   Ungleichheit  die falsche Info ins Feld : Skalierung_Bit12_15 gespeichert.
   Es ist nicht nîtig zwischen Therapie und Standard zu unterscheiden,
   dies wird automatisch Åber die Card-Adr eingestellt}
  procedure Check_Skalierung (var Skalierung_Bit12_15 : Skal_Rec_Arr;
                              Skalier, Modul_Skalier_12Re : Word;
                              Card_Adr : Integer);
    const
      Eins = $0001; {um Bit 12 auf 1 oder 0 festzulegen}
      Zwei = $0002; {in der Art 1100 and 0010 => Bit 12 = 0}
      Vier = $0004;
      Acht = $0008; {um Bit 15 auf 1 oder 0 festzulegen}
    var
      Bit15_Ist, Bit15_Soll, Bit14_Ist, Bit14_Soll : String [4];
      Bit13_Ist, Bit13_Soll : String[1];
      Bit12_Ist, Bit12_Soll : String[6];
    begin {Bestandsaufnahme Soll und Ist}
    if (Skalier and Acht) = 0 then Bit15_Soll := 'Out'
    else Bit15_Soll := 'In ';
    if (Modul_Skalier_12Re and Acht) = 0 then Bit15_Ist := 'Out'
    else Bit15_Ist := 'In ';
    if (Skalier and Vier) = 0 then Bit14_Soll := 'Out'
    else Bit14_Soll := 'In ';
    if (Modul_Skalier_12Re and Vier) = 0 then Bit14_Ist := 'Out'
    else Bit14_Ist := 'In ';
    if (Skalier and Zwei) = 0 then Bit13_Soll := 'N'
    else Bit13_Soll := 'J';
    if (Modul_Skalier_12Re and Zwei) = 0 then Bit13_Ist := 'N'
    else Bit13_Ist := 'J';
    if (Skalier and Eins) = 0 then Bit12_Soll := '32-Bit'
    else Bit12_Soll := '16-Bit';
    if (Modul_Skalier_12Re and Eins) = 0 then Bit12_Ist := '32-Bit'
    else Bit12_Ist := '16-Bit';
    with Skalierung_Bit12_15[Card_Adr] do
      begin  {Vergleich, Fehler ermitteln, Feld beschreiben}
      if Bit15_Soll = Bit15_Ist then  Skal_Bit15 := '   '
      else Skal_Bit15 := Bit15_Ist;
      if Bit14_Soll = Bit14_Ist then  Skal_Bit14 := '   '
      else Skal_Bit14 := Bit14_Ist;
      if Bit13_Soll = Bit13_Ist then  Skal_Bit13 := ' '
      else Skal_Bit13 := Bit13_Ist;
      if Bit12_Soll = Bit12_Ist then  Skal_Bit12 := '      '
      else Skal_Bit12 := Bit12_Ist;
    end; {with}
  end; {Check_Skalierung}

  {Skalierung einer IO_Card auslesen, verleichen; wenn alles ok, zurÅck
   zur aufrufenden Proc; bei Fehler Fehlerausgabe; !!! kein Exit,
   sonst fehlt evtl. die genaue Fehlerinfo}
  procedure Skalierung_auslesen (Card_Adr : Integer; Skalier : Word;
                                 var Modul_Skalier_12Re : Word);
    var
      Eingabe : Char;
      { MilErr : TMilErr; weg, weil global schon}
      Modul_Skalier : Word;
      Modul_Skalier_8Li_8Re, Skalier_Soll_Li12, Skalier_Ist_Li12  : Word;
      Modul_Skalier_8Li_8Re_Hex : String;
      {nur die ersten 4 Zeichen werden genommen, Rest vernachlÑssigt}
      Skalier_Soll_Li12_Bin, Skalier_Ist_Li12_Bin : String [4];
      {Modul_Skalier_8Li_8Re_Hex = Card-Adressse}
    begin
    Adr.AdrCard := Card_Adr;
    {ergibt Ch-Belegung IN/Out und Bit-Mode 16/32}
    Adr.AdrSub := SubAdr_Skal;
    MilErr := No_Err;
    Mil.Rd_ModBus (DLes.W, Adr, MilErr );
    if MilErr <> No_Err  then begin
      Clr_F_Tast_Output;
      Clr_F_Tast_Err_Succ;
      Abbruch_Mil_Fehler (MilErr);
    end;
    Modul_Skalier := DLes.W;
    Modul_Skalier_12Re := Modul_Skalier shr 12;
    if Modul_Skalier_12Re <> Skalier then
      begin
     {Ermittlung der Bit-Infos: Card Aresse [Hex], Skalier-Soll und-Ist [bin]}
      Modul_Skalier_8Li_8Re := (Modul_Skalier shl 8) shr 8;
      Modul_Skalier_8Li_8Re_Hex := hex_word (Modul_Skalier_8Li_8Re);
     {Umwandlung, da data vom Typ Word sein mu·, sonst BereichsÅberschreitung}
      {um 12 nach links verschieben, damit die ersten 4 Stellen relevant}
      Skalier_Soll_Li12 := Skalier shl 12;
      Skalier_Ist_Li12 := Modul_Skalier_12Re shl 12;
      Skalier_Soll_Li12_Bin := word_bin(Skalier_Soll_Li12);
      Skalier_Ist_Li12_Bin := word_bin(Skalier_Ist_Li12);
      {eigentliche Ausgabe}
      Ausgabe_Struktur_IO_Modul;
      GotoXY(06,07); Write ('Das I/O-Module Nr.: FG 450361 mit Modul-ID 36 (dez),                          ');
      GotoXY(06,08); Write ('hat die Mod-Adr: ',Modul_Skalier_8Li_8Re_Hex,'                                        ');
      GotoXY(06,09); Write ('die Modul-ID fÅr LP: [Hex] 24 und VG: [Hex] 24                                ');
      TextColor(Red);
      GotoXY(06,11); Write ('    Modul-Skalierung-Soll:      Modul-Skalierung-Ist: ');
      GotoXY(06,12); Write ('            ',Skalier_Soll_Li12_Bin,'                        ',Skalier_Ist_Li12_Bin);
      GotoXY(06,14); Write ('(           Bit 4:    Bit 3:      Bit 2:   Bit 1: )');
      GotoXY(06,15); Write ('( Pegel 1:  Ch1/IN,   Ch0/IN,    mit APK,  16Bit  )');
      GotoXY(06,16); Write ('( Pegel 0:  Ch1/Out,  Ch0/Out,  ohne APK,  32Bit  )');
      {hier kurz Halt, damit die Fehlerausgabe gesehen werden kann}
      ini_msg_win;
      Write (' Bitte mit <Space> fortfahren ');
      repeat
        Eingabe := Newreadkey;
      until Eingabe = ' ';
    end; {if Modul_Skalier_12Re}
  end; {Status_auslesen}

  {fÅr IO-Card_Adresse den Wert (24/24 = 9252 ) ermitteln in das Integer-
  Feld schreiben und das Feldelement in aufrufende Procedure Åbergeben}
  procedure Ermittle_Modul_ID (Card_Adr : Integer; var ID_Reg_Inh : Integer);
    { var
      MilErr : TMilErr; weg, weil global schon }
    begin
    Adr.AdrCard := Card_Adr;
    {ergibt Modul_ID von LP im HByte und VG im LByte}
    Adr.AdrSub := SubAdr_Modul_ID;
    Adr.AdrMode := AdrNew;
    MilErr := No_Err;
    Mil.Rd_ModBus (DLes.W, Adr, MilErr );
    if (MilErr <> No_Err) and (MilErr <> Rd_To) then begin
      Clr_F_Tast_Output;
      Clr_F_Tast_Err_Succ;
      Abbruch_Mil_Fehler (MilErr); {mit Exit; mit Halt kommt man direkt in den Programmcode}
    end;
    ID_Reg_Inh := DLes.W;
    {Wenn eine Karte nicht da ist: MilErr = Rd_To, soll '0' ins Feld }
    if MilErr = Rd_To then ID_Reg_Inh := 0;
  end; {Ermittle_Modul_ID}

  {alle IO-Karten von 1-8 werden auf gleiche VG- und LP- ID ÅberprÅft
   ebenso deren Skalierungsregister- Inhalt auf Richtigkeit;
   Fehler werden sofort angezeigt, ausgegeben und das Programm ?abgebrochen??}
  procedure Modul_32_Bit_IO;
    const
      VG_LP_ID_ok = 9252; {entspricht [Hex] 2424}
      Io_Card_Adr : array[1..8] of Integer  {Begriffe entsprechen Int Adress}
                      = (IoCard_St1, IoCard_St2, IoCard_St3,
                         IoCard_St4, IoCard_BDU_2_3, IoCard_BDU_1,
                         IoCard_Displ, IoCard_Zus_St);
      Skal : array[1..8] of Word {Bit 12-15 fÅr jede IO-Karte}
               = (1, 1, 13, 13, 7, 7, 11, 3);
    type
      Int_8_Feld = array[1..8] of Integer;
    var
      Auslegung : Char;
      Skalierung_Bit12_15 : Skal_Rec_Arr; {Arr. mit Rec. fÅr jede I/O-Karte }
      Skalier, Modul_Skalier_12Re : Word;                     {fÅr Strings Bit12-15 Ist und Soll}
      Modul_ID_Register : Int_8_Feld;
      ID_Fehler, ID_Reg_Inh : Integer;
      Card_Adr, IO_Card_Nr, Card : Integer;
      LP_Modul_ID, VG_Modul_ID : Integer;
      LP_Modul_ID_Hex, VG_Modul_ID_Hex : String;
    begin
    ID_Fehler := 0;
    {Modul-Id-Register-Inhalte ermitteln und ins Modul_ID_Register-Feld schre}
    for IO_Card_Nr := 1 to IO_Card_Max_Zahl do
      begin
      Card_Adr := Io_Card_Adr[IO_Card_Nr];
      Ermittle_Modul_ID (Card_Adr, ID_Reg_Inh);
      {wichtig zum rauskommen ins HP;  hier fÅr alle MilErr au·er Rd_To}
      if (Abbruch = 'x') or (Abbruch = 'X') then Exit;
      {Modul_ID_Register-Feld wird mit aktuellen Werten gefÅllt (z.B.:9252)}
      Modul_ID_Register [IO_Card_Nr] := ID_Reg_Inh;
    end; {for}
    {Modul_ID_Register-Feldinhalte von oben her (8-1) ÅberprÅfen}
    Card := IO_Card_Max_Zahl;
    while Modul_ID_Register [Card] = VG_LP_ID_ok do Card := Card - 1;
    if Card = 0 then
    {bei Karte 8-1 sind VG- und LP- ID gleich: Therapie-Status}
      begin
      Auslegung := 'T';
      for IO_Card_Nr := 1 to IO_Card_Max_Zahl do
        begin
        Card_Adr := Io_Card_Adr[IO_Card_Nr];
        Skalier := Skal[IO_Card_Nr];
        {Stop! weiter mit <Space>}
        Skalierung_auslesen (Card_Adr, Skalier, Modul_Skalier_12Re);
        Check_Skalierung (Skalierung_Bit12_15, Skalier, Modul_Skalier_12Re,
                          Card_Adr);
      end; {for IO_Card_Nr := 1}
      {wenn alle IO-Karten ok, also kein EXIT erfolgt}
      Ausgabe_Struktur_IO_Modul;
      Ausgabe_Daten_IO_Modul_Therapie_Ok;
      Partielle_Fehler_Ausgabe (Skalierung_Bit12_15, Auslegung);
    end; {If Card = 0}
    if Card = 4 then
    {bei Karte 8-5 sind VG- und LP- ID gleich: Standard-Status}
      begin
      if ((Modul_ID_Register[1] = 0) and (Modul_ID_Register[2] = 0) and
          (Modul_ID_Register[3] = 0) and (Modul_ID_Register[4] = 0)) then
        begin
        Auslegung := 'S';
        for IO_Card_Nr := 5 to IO_Card_Max_Zahl do
          begin
          Card_Adr := Io_Card_Adr[IO_Card_Nr];
          Skalier := Skal[IO_Card_Nr];
  { Check_Skalierung (Skalierung_Bit12_15, Skalier, Modul_Skalier_12Re, Card_Adr);}
          {Stop! weiter mit <Space>}
          Skalierung_auslesen (Card_Adr, Skalier, Modul_Skalier_12Re);
          Check_Skalierung (Skalierung_Bit12_15, Skalier, Modul_Skalier_12Re,
                            Card_Adr);
        end; {for IO_Card_Nr := 5 to 8}
        {wenn IO-Karten 5-8 ok, also kein EXIT erfolgte}
        Ausgabe_Struktur_IO_Modul;
        Ausgabe_Daten_IO_Modul_Standard_Ok;
        Partielle_Fehler_Ausgabe (Skalierung_Bit12_15, Auslegung);
      end {if Modul_ID_Register[1 2,3,4 ]}
      else ID_Fehler := 1; {wenn eine I/O-Karte (1-4) den Wert <> 0 hat}
    end {if Card = 4}
    else if Card <> 0 then ID_Fehler := 1;{! wichtig, sonst auch bei Card = 0}
    {ID- Fehler-Ermittlung und Ausgabe}
    if ID_Fehler = 1 then
      begin
      {bei 7/8 anfangen, weil die letzten 3/4 Karten immer da sein mÅssen}
      Card := IO_Card_Max_Zahl;
      {es wird automatisch nur bis card=1 abgezogen, denn spÑtestens da
       mu· der Fehler sein, sonst wÑre man nicht hierher gekommen }
      while Modul_ID_Register[Card] = VG_LP_ID_ok do Card := Card - 1;
      {Ausgabe und Abbruch, sobald der 1. Fehler festgestellt wird}
      LP_Modul_ID := Modul_ID_Register[Card] shr 8;
      LP_Modul_ID_Hex := hex_word (LP_Modul_ID);
      {hex_word wandelt ein Word in einen Hex- String um}
      VG_Modul_ID := Modul_ID_Register[Card] and $00FF;
      VG_Modul_ID_Hex := hex_word (VG_Modul_ID);
      Clr_F_Tast_Err_Succ;
      Set_Text_Win;
      TextColor(Yellow);
      GotoXY(06,06); Write ('Infos zu den I/O_Modulen:');
      TextColor(Red);
      GotoXY(06,07); Write ('Bei der Ermittlung der Modul-ID ist ein Fehler aufgetreten:');
      GotoXY(06,09); Write ('Die ',Card,'. IO-Karte ist falsch oder nicht vorhanden');
      GotoXY(06,10); Write ('VG-Modul-ID [Hex]: ',VG_Modul_ID_Hex);
      GotoXY(06,11); Write ('LP-Modul-ID [Hex]: ',LP_Modul_ID_Hex);
      Programm_Abbruch_mit_Beep;
    end; {ID_Fehler = 1}
  end; {Modul_32_Bit_IO}

  {APK-Infos ermitteln, bewerten und Ausgabe veranlassen}
  procedure APK;
    const
      Leer_ID = $FF;
      BDU_1_ID = $01;
      BDU_2_ID = $02;
      BDU_3_ID = $03;
      ADI_ID = $04;
      OUT50_ID = $07;          {wie bei alter 50Ohm-APK, oder auch bei neuer}
      OUT50_2_ID = $30;            {fÅr neue 50Ohm-APK; entspricht exakt $07}
      OUT50_2_ID_LED_Aus = $31;    {neue 50Ohm-APK; positive Logik; LED aus}
      OUT50_2_ID_Neg_LED_An = $32; {neue 50Ohm-APK; negative Logik; LED an}
      OUT50_2_ID_Neg_LED_Aus = $33;{neue 50Ohm-APK; negative Logik; LED aus}
      {ist keine APK da, dann gilt:00; ist nichts eingetragen, dann:FF}
      APK_ID : array[1..8] of Integer
                 = (BDU_2_ID, BDU_3_ID, BDU_1_ID, Leer_ID, Leer_ID,
                    ADI_ID, OUT50_ID, OUT50_ID);
      {APK-Namen zur genaueren Fehlerbeschreibung}
      APK_Name : array[1..8] of String
                 = ('BDU_2_ID', 'BDU_3_ID', 'BDU_1_ID', 'hier keine',
                    'hier keine', 'ADI_ID', 'OUT50_ID', 'OUT50_ID');
    var
      { MilErr : TMilErr; weg, weil global schon }
      Lauf, Status_Adr_Runde, IO_Adr_Runde : Integer;
      Kard_ID, Kard_ID_8Li, Kard_ID_8Li_8Re : Word;
      Kard_ID_Ist_Hex, Kard_ID_Soll_Hex : String;
      Channel : Char;
      Variante, Var_Ch1, Var_Ch0 : String;
      Kanal : Word;
      {dieses Feld nicht als const eingeben, da das 4.Element variabel}
      Adr_Io_Card : array[1..4] of Integer;

    begin
    Lauf := 0;
    Channel := '0';
    Adr.AdrSub := SubAdr_StatusRegister_Ch0_Rd;
    {Adr_Io_Cadr - Feld mit IO_Card_ID fÅllen: entweder 5-8, oder 5-7 und 0}
    Adr_Io_Card [1] := IoCard_BDU_2_3;
    Adr_Io_Card [2] := IoCard_BDU_1;
    Adr_Io_Card [3] := IoCard_Displ;
    if Karte_8_da then Adr_Io_Card [4] := IoCard_Zus_St
    else Adr_Io_Card [4] := Nichts;
    for IO_Adr_Runde := 1 to 4 do {weil 4 verschiedene IO-Karten}
      begin
      Adr.AdrCard := Adr_Io_Card[IO_Adr_Runde];
      if Adr.AdrCard <> Nichts then
        begin
        for Status_Adr_Runde := 1 to 2 do {weil 8 verschiedene APK-ID}
          begin
          Lauf := Lauf + 1;
          if Adr.AdrSub = SubAdr_StatusRegister_Ch0_Rd then
            begin
            Adr.AdrSub := SubAdr_StatusRegister_Ch1_Rd;
            Channel := '1';
          end {if Adr.AdrSub}
          else begin
            Adr.AdrSub := SubAdr_StatusRegister_Ch0_Rd;
            Channel := '0';
          end; {else begin}
          MilErr := No_Err;
          Mil.Rd_ModBus (DLes.W, Adr, MilErr );
          if MilErr <> No_Err then begin
            Clr_F_Tast_Output;
            Clr_F_Tast_Err_Succ;
            Abbruch_Mil_Fehler (MilErr);
          end; {if MilErr}
          Kard_ID := DLes.W;
          Kard_ID_8Li := Kard_ID shl 8;
          Kard_ID_8Li_8Re := Kard_ID_8Li shr 8; {das ist die APK-ID}
          Variante := ' ';
          Var_Ch1 := '07';
          Var_Ch0 := '07';
          {fÅr neue oder falsche APK-ID}
          if (Lauf in [7..8]) and (Kard_ID_8Li_8Re <> APK_ID[Lauf]) then
            begin
            case Kard_ID_8Li_8Re of
              OUT50_2_ID             : Variante := '30';
              OUT50_2_ID_LED_Aus     : Variante := '31';
              OUT50_2_ID_Neg_LED_An  : Variante := '32';
              OUT50_2_ID_Neg_LED_Aus : Variante := '33';
            else
              Variante := 'falsch'
             {Variante 07: nichts, Var31-33 Extraausgabe, sonst Variante falsch}
            end; {case}
            if Lauf = 7 then Var_Ch1 := Variante
            else  Var_Ch0 := Variante;  {fÅr Lauf = 8}
          end; {if (Lauf = 7) or}

          {Ausgabe im Fehlerfall}
          if ((Lauf in [1..6]) and (Kard_ID_8Li_8Re <> APK_ID[Lauf])) or (Variante = 'falsch') then
            begin
            Kard_ID_Ist_Hex := hex_word (Kard_ID_8Li_8Re);
            Kard_ID_Soll_Hex := hex_word (APK_ID[Lauf]);
            Ausgabe_Struktur_APK;
            TextColor(Red);
            GotoXY(06,08);
            Write ('APK-ID-Soll [Hex]   APK-ID-Ist [Hex]   IO-Modul-Adr   Ch');
            GotoXY(06,09);
            Write ('    ',Kard_ID_Soll_Hex,'                ',Kard_ID_Ist_Hex);
            Write ('                ',Adr_Io_Card[IO_Adr_Runde],'         ',Channel );
            GotoXY(06,11);
            Write ('Was ist mit APK: ',APK_Name[Lauf],' ?');
            Programm_Abbruch_mit_Beep;
          end; {if Kard_ID_8Li_8Re}
          {wichtig! sonst erfolgt erst Abbruch, wenn alle Karten ausgegeben }
          if (Abbruch = 'x') or (Abbruch = 'X') then Exit;
        end; {for Status_Adr_Runde }
      end; {if}
    end; {for IO_Adr_Runde}
    Ausgabe_Struktur_APK;
    Ausgabe_Daten_APK_Ok;
    {wenn letzte oder vorletzte APK eine andere richtige ID hat}
    if (Var_Ch1 <> '07') or (Var_Ch0 <> '07') then
      begin
        GotoXY(06,13);
        Write ('    ',Var_Ch1,'            08    1     OUT50 FG 423 242 ');
        GotoXY(06,14);
        Write ('    ',Var_Ch0,'            08    0     OUT50 FG 423 242 ');
    end; {if Variante = 'falsch'}
  end; {APK}

  {IFK-, IO- und APK-Test stÅckweise mit Useranforderung testen und ausgeben}
  procedure IFK_IO_APK;
    var
     i  : Integer;
     Weiter : Char;
    begin
    Clr_F_Tast_Err_Succ;
    IFK; {IFK-Infos ermitteln, bewerten und Ausgabe veranlassen}
    if (Abbruch = 'x') or (Abbruch = 'X') then Exit; {bei Fehler}
    ini_msg_Win;
    Write (' Bitte <Space> drÅcken um fortzufahren  Vorsicht! Ausgabe wird Åberschrieben');
    Weiter := NewReadkey;
    while Weiter <> ' ' do
      begin
      ini_err_win;
      Write (' Es geht nur mit Space weiter!');
      Weiter := NewReadkey;
    end; {while}
    Clr_F_Tast_Err_Succ;
    Modul_32_Bit_IO; {32Bit-IOInfos ermitteln, bewerten und ausgeben}
    if (Abbruch = 'x') or (Abbruch = 'X') then Exit; {bei Fehler}
    ini_msg_Win;
    Write (' Bitte <Space> drÅcken um fortzufahren  Vorsicht! Ausgabe wird Åberschrieben');
    Weiter := NewReadkey;
    while Weiter <> ' ' do
      begin
      ini_err_win;
      Write (' Es geht nur mit Space weiter!');
      Weiter := NewReadkey;
    end; {while}
    Clr_F_Tast_Err_Succ;
    APK; {APK-Infos ermitteln, bewerten und Ausgabe veranlassen}
    if (Abbruch = 'x') or (Abbruch = 'X') then Exit; {bei Fehler}
  end; {IFK_IO_APK}

  Begin  {Hardware}
  IfcAdr := Ifc_Test_Nr;   {IFK-Adr aus proc.Mil_Ask_Ifc in Ifc_Test_Nr}
  Adr.AdrIfc := IfcAdr;    {Ifk-Adresse fÅr Zugriffe auf IO-Card Åbergeben}
  Adr.AdrMode := AdrNew;   {die Mode-Adresse wird neu "berechnet"}
  {Check, ob 8.IO-Karte da ist}
  Adr.AdrCard := IoCard_Zus_St;
  Adr.AdrSub := SubAdr_StatusRegister_Ch0_Rd; { =$16 hier ging auch CH1}
  Mil.Rd_ModBus (DLes.W, Adr, MilErr );
  if MilErr = Rd_To then Karte_8_da := False
  else Karte_8_da := True;
  MilErr := No_Err;
  if Karte_8_da then IO_Card_Max_Zahl := 8  {Nur wenn die 8.IO-Karte da ist}
  else  IO_Card_Max_Zahl := 7;            {wird sie mitgetestet.}
  {bis hier Abfrage 8.Karte}
  Abbruch := ' ';
  Clr_Sub_Menue_Text;     {Lîscht Meldung Åber IFK- Anzahl und - Adresse}
  Set_Text_Win; TextColor(Yellow);
  GotoXY(02,01);
  Write('Hardware !');
  Fkt_Tasten_Auswahl_MenueH;
  Fkt_Tast_Auswahl_Msg;  {Fkt-Taste oder X}
  Ch := NewReadKey;
  if Ord(Ch) = Esc then Exit;
  if Ch in ['x','X'] then Exit;
  repeat
    if Ch = #0 then begin
      Ch := NewReadKey;
      if Ord(Ch) = Esc then Exit;
      case ord (Ch) of

        Taste_F1 : begin      {es werden IFK, IO-Card's und APK getestet}
          Clr_Fkt_Tast_Win;
          Prep_Sub_Menue_Topl;
          Writeln ('(F1-Taste): Hardwarekonfiguration, bezÅglich IFK, I/O und APK');
          Sing_Loop_X := ' ';
          if Ord(Sing_Loop_X) = Esc then Exit; {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                IFK_IO_APK; {Ermittlung und stÅckweise Ausgabe der Hardware}
                if (Abbruch = 'x') or (Abbruch = 'X') then Exit; {bei Fehler}
                Ini_Msg_Win;
                Kleine_Auswahl_Msg;
                Sing_Loop_X := NewReadKey;
                if Ord(Sing_Loop_X) = Esc then Exit;
              end;  {' '}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {while}
          Set_Text_Win;
          Fkt_Tasten_Auswahl_MenueH;
          Fkt_Tast_Auswahl_Msg;
        end; {F1-Taste}

        Taste_F2 : begin      {Entprellung und Spannung von BDU3 auslesen}
          Clr_Fkt_Tast_Win;
          Prep_Sub_Menue_Topl;
          Writeln ('(F2-Taste): BDU3 Status-Port: Entprellung und Spannung ');
          Sing_Loop_X := ' ';
          if Ord(Sing_Loop_X) = Esc then Exit;  {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                BDU3_Status;   {Ermittlung und Ausgabe des BDU3-Status}
                if (Abbruch = 'x') or (Abbruch = 'X') then Exit; {bei Fehler}
                Ini_Msg_Win;
                Kleine_Auswahl_Msg;
                Sing_Loop_X := NewReadKey;
                if Ord(Sing_Loop_X) = Esc then Exit;
              end;  {' '}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Set_Text_Win;
          Fkt_Tasten_Auswahl_MenueH;
          Fkt_Tast_Auswahl_Msg;
        end; {F2-Taste}

      end; {case}
    end; {   if Ch = #0 then  }
    if KeyEPressed then Ch := NewReadKey;
    if Ord(Ch) = Esc then Exit;
  until Ch in ['x','X'];
End;   {Hardware}


procedure BDU_1;
  const
    Beschleuniger : array[0..17] of String
                      = ('00','01','02','03','04','05','06','07','08','09',
                         '10','11','12','13','14','15','>>','--');
  var
    ACCEL, Zeile, Feld_Elem, Nr, Zaehler, Ende : Integer;
    Weiter : Char;
    IfcAdr : Byte;
    Adr : TModAdr;
    Sing_Loop_X : Char;
    Loop_Zaehl : Integer;

  {Ansicht der Frontplatte von BDU_1, mit erklÑrendem Text}
  procedure BDU_1_Front;
    var
      Z : Integer;
    begin
    Set_Text_Win;
    GotoXY(32,09); Write ('Zahlen von 00 - 15 entsprechen einer ACC_Nr.');
    GotoXY(32,11); Write ('"--" ist das Zeichen fÅr inaktiv');
    GotoXY(32,13); Write ('">>" bedeutet: nicht im GÅltigkeitsbereich');
    Set_Front_Anzeige;
    GotoXY(02,01); Write ('ACCEL');
    for Z := 3 to 10 do begin
      GotoXY (04,Z);
      Write ('--');
    end;
  end; {BDU_1_Front}

  {BDU_1 - Frontplatte wird aktualisiert}
  procedure Refresh_BDU_1_Front (ACCEL, Zeile : Integer);
    var
      Num : Integer;
      Ausdruck : String;
    begin
      Num := ACCEL;
      if ((Num >= 0) and (Num <= 15) or (Num = 17))  then Ausdruck := Beschleuniger[Num]
           else Ausdruck := Beschleuniger[16];
      Set_Text_Win;
      Textcolor (yellow);
      GotoXY(32,06); Write ('Bitte nebenstehende Anzeige mit der Frontplatte ');
      GotoXY(32,07); Write ('des GerÑtes ÅberprÅfen ');
      Ini_Front_Win;
      GotoXY (01, Zeile);
      Write (' ',Ausdruck);
  end; {Refresh_BDU_1_Front}

  {Funktionstastenwahl fÅr BDU_1 - Test}
  procedure Fkt_Tasten_Auswahl_Menue1;
    begin
    Auswahl_Menue_Head;
    GotoXY(01, 01); Write('F1: GewÅnschte ACC-Nr. in gewÅnschte Zeile              ');
    GotoXY(01, 02); Write('F2: ACC_Nr. 00-15 fortlaufend in alle Zeilen            ');
    GotoXY(01, 03); Write('F3: Festes Zahlenmuster 01-08 in den Zeilen 1-8         ');
    TextColor(Black);
  end; {Fkt_Tasten_Auswahl_Menue1}

  {AusfÅhren der Mil-Proceduren, mit Mil-Fehlerbehandlung!  Adressierung
   unter BDU_1 festgelegt, ACC-Nr im LB und Zeilen-Nr im HB von Data-Schreib}
  procedure Set_BDU_1 (ACCEL, Zeile : Integer);
    var
      MilErr : TMilErr;
      Segment_Anzeigen_Nr : Integer;
    begin
    if ACCEL = 17 then ACCEL := 45; {-- ist in BDU_1 durch 45 realisiert}
    DSchreib.B.DLowB := ACCEL;
    {"Monitoranzeige" Platz 1 - 8 wird mittels Dezimalzahl 0 - 7 eingegeben}
    Segment_Anzeigen_Nr := Zeile - 1;
    DSchreib.B.DHighB  := Segment_Anzeigen_Nr;
    MilErr := No_Err;
    Mil.Wr_ModBus (DSchreib.W, Adr, MilErr );
    if MilErr <> No_Err then begin
      Clr_F_Tast_Output;
      Clr_F_Tast_Err_Succ;
      Abbruch_Mil_Fehler (MilErr); {mit Exit}
    end;
  end; {Set_BDU_1}

  {Eingaberoutine der ACC-Nr und Zeilen-Nr (Fu·zeile) und Set_BDU_1
   ! es mu· sichergestellt sein, da· nur Integer Zahlen eingegeben werden!}
  procedure ACC_Line_Nr_In;
    begin
      Ini_Msg_Win;
      Write (' Zeilen-Nr zwischen 1 und 8 eingeben: ');
      Read (Zeile);
      if (Zeile < 1) or (Zeile > 8) then begin
        repeat
          Ini_Err_win;
          Write (' Diese Eingabe war falsch! Bitte Wert zwischen 1 und 8: ');
          Read (Zeile);
        until ((Zeile >= 1) and (Zeile <= 8));
      end; {if}
      Ini_Msg_Win;
      Write (' ACC_Nr zwischen 0 und 15, oder 17 fÅr inaktiv eingeben: ');
      Read (ACCEL);
      Refresh_BDU_1_Front (ACCEL, Zeile);
      Set_BDU_1 (ACCEL, Zeile);
  end; {ACC_Line_Nr_In; }

  {es werden alle Zeilen mit der selben ACC-Nr beschrieben}
  procedure All_Line_All_ACC (ACCEL : Integer);
    var
      Zei : Integer;
    begin
      for Zei := 1 to 8 do begin
        Zeile := Zei;
        Refresh_BDU_1_Front (ACCEL, Zeile);
        Set_BDU_1 (ACCEL, Zeile);
      end; {for}
  end; {All_Line_All_ACC; }

  {Toggelroutine zwischen Pattern (ACC-Nr = ZeilenNr) und inaktiv
   mit Space (Fu·zeile) und Set_BDU_1}
  procedure Fix_Pattern;
    var
      Zahl : Integer;
    begin
      for Zahl := 1 to 8 do begin
        ACCEL := Zahl;
        Zeile := Zahl;
        Refresh_BDU_1_Front (ACCEL, Zeile);
        Set_BDU_1 (ACCEL, Zeile);
      end; {for}
  end; {Fix_Pattern; }

  Begin  {BDU_1}
  {IFK-Adr in proc.Mil_Ask_Ifc ermittelt und in Ifc_Test_Nr gespeichert}
  IfcAdr := Ifc_Test_Nr;
  Adr.AdrIfc := IfcAdr;   {die ifk hat die Adresse 10}
  Adr.AdrCard := IoCard_BDU_1;  {BDU_1 hÑngt an der 6. IO-Card}
  Adr.AdrMode := AdrNew;  {die Mode-Adresse wird neu "berechnet"}
  Adr.AdrSub := SubAdrCh_1;  {Ch-1, Wr}
  Clr_Sub_Menue_Text;     {Lîscht Meldung Åber IFK- Anzahl und - Adresse}
  Set_Text_Win; TextColor(Yellow);
  GotoXY(02,01);
  Write('Test des Einschubs BDU_1 !');  {SubmenÅ Topline}
  Fkt_Tasten_Auswahl_Menue1;            {FunktionsmenÅ}
  BDU_1_Front;                          {SubmenÅ Frontplatte}
  Fkt_Tast_Auswahl_Msg;                 {Fkt-Taste oder X}
  Ch := NewReadKey;
  if Ord(Ch) = Esc then Exit;
  if Ch in ['x','X'] then Exit;
  repeat
    if Ch = #0 then begin
      Ch := NewReadKey;
      if Ord(Ch) = Esc then Exit;
      case Ord (Ch) of

        Taste_F1 : begin      {Wahl ACC- und Line-Nr}
          Clr_Fkt_Tast_Win;
          Prep_Sub_Menue_Topl;
          Writeln ('(F1-Taste): Freie Wahl von ACC-Nr. und Zeilen-Nr. ');
          {alle Zeilen auf '--', damit Frontpl. auf Monitor und GerÑt gleich}
          ACCEL := 17;
          All_Line_All_ACC (ACCEL);
          Sing_Loop_X := ' ';
          if Ord(Sing_Loop_X) = Esc then Exit;  {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                ACC_Line_Nr_In;
                Ini_Msg_Win;
                Kleine_Auswahl_Msg;
                Sing_Loop_X := NewReadKey;
                if Ord(Sing_Loop_X) = Esc then Exit;
              end;  {' '}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Set_Text_Win;
          Fkt_Tasten_Auswahl_Menue1;
          Fkt_Tast_Auswahl_Msg;
        end; {F1-Taste}

        Taste_F2 : begin      {All_Line_All_ACC}
          Clr_Fkt_Tast_Win;
          Prep_Sub_Menue_Topl;
          Writeln ('(F2-Taste): Durchtasten aller Zeichen (00-15, >>, --)  ');
          Write ('             in allen Zeilen mit der Space-Taste ');
          Sing_Loop_X := ' ';
          if Ord(Sing_Loop_X) = Esc then Exit;  {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                Ini_Msg_Win;
                Write(' Weiter mit <Space>                                      Ende mit <ESC> ');
                Zaehler := -1; {-1,um beim Durchtasten bei 0 anzufangen}
                {hier benîtigt man die Abfrage mit 'Weiter', um den
                 kompletten Durchlauf von 18 Zeichen zu realisieren}
                repeat
                  Weiter := Newreadkey;
                  if Weiter = ' 'then  begin
                    Zaehler := Zaehler + 1;
                    if Zaehler = 18 then Zaehler := 0;
                    ACCEL := Zaehler;
                    All_Line_All_ACC (ACCEL);
                  end; {if Weiter}
                until Ord(Weiter) = Esc;
                Ini_Msg_Win;
                Std_Msg;
                Sing_Loop_X := NewReadKey;
                if Ord(Sing_Loop_X) = Esc then Exit;
              end;  {' '}
              {Loop mit Ermittlung und Ausgabe des SchleifenzÑhlers }
              Return : begin
                Loop_Zaehl := 0;
                ini_msg_win;
                Write (' beliebiger Tastendruck fÅhrt zum Abbruch       ');
                repeat
                  Loop_Zaehl := Loop_Zaehl + 1;
                  Set_Text_Win;
                  GotoXY(58, 02);
                  Write ('Schleifenanzahl : ', Loop_Zaehl:4);
                  for Feld_Elem := 0 to 17 do begin
                  {bei Tastendruck sofortiges Beenden der Schleife mit -- }
                  if KeyEPressed then Feld_Elem := 17;
                  ACCEL := Feld_Elem;
                  All_Line_All_ACC (ACCEL);
                  Delay (400);     {Zeit : 400 ms}
                  end; {for}
                until KeyEPressed;
                 Ini_Msg_Win;
                Std_Msg;
              end; {Return}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Set_Text_Win;
          Fkt_Tasten_Auswahl_Menue1;
          Fkt_Tast_Auswahl_Msg;
        end; {F2-Taste}

        Taste_F3 : begin      {Festes Pattern 1-8}
          Clr_Fkt_Tast_Win;
          Prep_Sub_Menue_Topl;
          Writeln ('(F3-Taste): Wechsel zwischen festem Muster und inaktiv ');
          Sing_Loop_X := ' ';
          if Ord(Sing_Loop_X) = Esc then Exit;  {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                Ini_Msg_Win;
                Write(' Weiter mit <Space>                                      Ende mit <ESC> ');
                Ende := 0;
                {der ganze Aufwand mit dem 'Weiter' mu· wegen dem
                stÑndigen Wechsel zwischen ZAHL und -- sein.}
                repeat
                  Weiter := Newreadkey;
                  if Weiter = ' 'then begin
                    All_Line_All_ACC (17); {alle Zeilen auf '--'}
                    Weiter := Newreadkey;
                    if Weiter = ' 'then Fix_Pattern
                    else Ende := 1
                    end {if}
                  else Ende := 1;
                until Ende = 1;
                Ini_Msg_Win;
                Std_Msg;
                Sing_Loop_X := NewReadKey;
                if Ord(Sing_Loop_X) = Esc then Exit;
              end;  {' '}
              {Loop mit Ermittlung und Ausgabe des SchleifenzÑhlers }
              Return : begin
                Loop_Zaehl := 0;
                All_Line_All_ACC (17); {alle Zeilen auf '--' = 17}
                repeat
                  Loop_Zaehl := Loop_Zaehl + 1;
                  Set_Text_Win;
                  GotoXY(58, 02);
                  Write ('Schleifenanzahl : ', Loop_Zaehl:4);
                  Delay (400);     {Zeit : 400 ms}
                  Fix_Pattern;
                  Delay (400);     {Zeit : 400 ms}
                  All_Line_All_ACC (17); {alle Zeilen auf '--' = 17}
                  ini_msg_win;
                  Write (' beliebiger Tastendruck fÅhrt zum Abbruch');
                until KeyEPressed;
                Ini_Msg_Win;
                Std_Msg;
              end; {Return}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Set_Text_Win;
          Fkt_Tasten_Auswahl_Menue1;
          Fkt_Tast_Auswahl_Msg;
        end; {F3-Taste}
      end; {case Fkt-Tast}
    end; {   if Ch = #0 then  }
    if KeyEPressed then Ch := NewReadKey;
    if Ord(Ch) = Esc then Exit;
  until Ch in ['x','X'];
End;   {BDU_1}


procedure BDU_2;
  const
    {Multiplikationsfaktoren zur Ermittlung der Zeilenkombinationen}
    Zeilenfaktor : array[1..8] of Integer
                      = (1, 4, 16, 64, 256, 1024, 4096, 16384);
  var
    Pattern, Line, Zaehler, Feld_Elem, Line_Pattern : Integer;
    Weiter  : Char;
    IfcAdr : Byte;
    Adr : TModAdr;
    Sing_Loop_X{, Abbruch} : Char;
    Loop_Zaehl : Integer;

  {Ansicht der Frontplatte von BDU_2, mit erklÑrendem Text}
  procedure BDU_2_Front;
    var
      Z : Integer;
    begin
    Set_Text_Win;
    Textcolor (black);
    GotoXY(32,09); Write ('"G" = Grant, "A" = Aktiv, "E" = Error ');
    GotoXY(32,11); Write ('"O" = LED aus ');
    GotoXY(32,13); Write ('"X" = LED leuchtet');
    Set_Front_Anzeige;
    GotoXY(03,01); Write ('G A E');
    for Z := 3 to 10 do begin
      GotoXY (03, Z);
      Write ('O O O');
    end;
  end; {BDU_2_Front}

  {BDU_2 - Frontplatte wird aktualisiert }
  procedure Refresh_BDU_2_Front (Pattern, Line : Integer);
    var
      Ausdruck : String;
    begin
      case Pattern of
        0 : Ausdruck := 'O O O';
        1 : Ausdruck := 'X O O';
        2 : Ausdruck := 'X X O';
        3 : Ausdruck := 'X O X';
      end; {case}
      Set_Text_Win;
      Textcolor (yellow);
      GotoXY(32,06); Write ('Bitte nebenstehende Anzeige mit der Frontplatte ');
      GotoXY(32,07); Write ('des GerÑtes ÅberprÅfen ');
      Ini_Front_Win;
      GotoXY (01, Line);
      Write (Ausdruck);
      GotoXY (01, Line);{wichtig, damit bei F3 der Cursor IN der Zeile steht}
  end; {Refresh_BDU_2_Front}

  {Funktionstastenwahl fÅr BDU_2 - Test}
  procedure Fkt_Tasten_Auswahl_Menue2;
    begin
    Auswahl_Menue_Head;
    GotoXY(01, 01); Write('F1: Wahl der LED-Kombination und der Zeile              ');
    GotoXY(01, 02); Write('F2: Gesamt-LED-Test aller Kombinationen                 ');
    GotoXY(01, 03); Write('F3: Zeilenweiser LED-Test aller Kombinationen           ');
    TextColor(Black);
  end; {Fkt_Tasten_Auswahl_Menue2}

  {AusfÅhren der Mil-Proceduren, mit Mil-Fehlerbehandlung!  Adressierung
   unter BDU_2, Musterinformation = Line_Pattern in DSchreib verborgen}
  procedure Set_BDU_2 (Line_Pattern : Integer);
    var
      MilErr : TMilErr;
    begin
    DSchreib.W := Line_Pattern;
    MilErr := No_Err;
    Mil.Wr_ModBus (DSchreib.W, Adr, MilErr );
    if MilErr <> No_Err then begin
      Clr_F_Tast_Output;
      Clr_F_Tast_Err_Succ;
      Abbruch_Mil_Fehler (MilErr);   {mit Exit}
    end;
  end; {Set_BDU_2}

  {Stellt die 4 mîglichen LED-Muster in einem Info-Fenster dar}
  procedure Muster_Info_Win;
    begin
    Set_Text_Win;
    TextColor(blue);
    GotoXY(63, 11 ); Write('Info - Window ');
    Ini_Info_Win_1;
    GotoXY(01, 02 ); Write('LED-Muster: 0,1,2,3 ');
    GotoXY(03, 04 ); Write('Grant Aktiv Error');
    GotoXY(01, 05 ); Write('0:  O     O     O');
    GotoXY(01, 06 ); Write('1:  X     O     O');
    GotoXY(01, 07 ); Write('2:  X     X     O');
    GotoXY(01, 08 ); Write('3:  X     O     X');
  end; {Muster_Info_Win}

  {Eingaberoutine fÅr Muster und Zeile (Fu·zeile) + Verarbeitung + Anzeige
  ! es mu· sichergestellt sein, da· die Åbergebenen Zahlen korrekt sind!}
  procedure Muster_And_Line_In;
    begin
      Ini_Msg_Win;
      Write (' Zeilen-Nr zwischen 1 und 8 eingeben: ');
      Read (Line);
      if (Line < 1) or (Line > 8) then begin
        repeat
          Ini_Err_win;
          Write (' Diese Eingabe war falsch! Bitte Wert zwischen 1 und 8: ');
          Read (Line);
        until ((Line >= 1) and (Line <= 8));
      end; {if}
      Muster_Info_Win;
      Ini_Msg_Win;
      Write (' Zahl:0, 1, 2 oder 3 fÅr LED-Muster (blaues Info-Fenster) eingeben: ');
      Read (Pattern);
      if (Pattern < 0) or (Pattern > 3) then begin
        repeat
          Ini_Err_win;
          Write (' Diese Eingabe war falsch! Bitte Wert zwischen 0 und 3: ');
          Read (Pattern);
        until ((Pattern >= 0) and (Pattern <= 3));
      end; {if}
      Refresh_BDU_2_Front (Pattern, Line);
      {z.B.: 5.Zeile Muster: 2; Line_Pattern = 2*256}
      Line_Pattern := Pattern * Zeilenfaktor[Line];
      Set_BDU_2 (Line_Pattern);
  end; {Muster_And_Line_In }

  {es werden alle Zeilen mit dem selben LED-Muster beschrieben }
  procedure All_Line_Same_Pattern (Pattern : Integer);
    var
      Zei : Integer;
    begin
    Line_Pattern := 0;
    for Zei := 1 to 8 do begin
      Line := Zei;
      Refresh_BDU_2_Front (Pattern, Line);
      Line_Pattern := (Line_Pattern + (Pattern * Zeilenfaktor[Zei]));
    end; {for}
    {Line_Pattern ist die Summe aller ZeilenPattern}
     Set_BDU_2 (Line_Pattern);
  end; {All_Line_Same_Pattern  }

  {Toggelroutine zwischen den Pattern (0-3) mit den Fkt-Tasten F1-F8.
   Neues Fkt-Tasten-MenÅ}
  procedure One_Line_Four_Pattern;
    var
      LineOld  : Integer;
      Wahl, Taste : Char;

    {FunktionstastenmenÅ fÅr zeilenweisen Test}
    procedure Fkt_Tasten_Auswahl_Menue2b;
      begin
      Auswahl_Menue_Head;
      GotoXY(01, 01); Write('F1: Zeile 1 durchtasten        F5: Zeile 5 durchtasten  ');
      GotoXY(01, 02); Write('F2: Zeile 2 durchtasten        F6: Zeile 6 durchtasten  ');
      GotoXY(01, 03); Write('F3: Zeile 3 durchtasten        F7: Zeile 7 durchtasten  ');
      GotoXY(01, 04); Write('F4: Zeile 4 durchtasten        F8: Zeile 8 durchtasten  ');
      TextColor(Black);
    end; {Fkt_Tasten_Auswahl_Menue2b}

    begin {One_Line_Four_Pattern}
    Fkt_Tasten_Auswahl_Menue2b;            {FunktionsmenÅ}
    Fkt_Tast_Auswahl_Msg;                  {Wahl: Fkt-Tasten oder x}
    Wahl := NewReadKey;
    if Ord(Wahl) = Esc then Exit;
    if Wahl in ['x','X'] then Exit;
    Taste := Chr (Taste_Pfeil_Auf);          {Taste auf unmîglichen Wert gesetzt}
    repeat
      if Wahl = #0 then begin
        Wahl := NewReadKey;
        {Fu·zeile fÅr zeilenweises Durchtasten}
        Ini_Msg_Win;
        Write(' Single-Step: Fkt-Taste         Loop: CR-Taste         EXIT: X-Taste');
        if (Wahl = Taste) then begin{frÅhestens beim 2.Durchgang gÅltig}
          Pattern := Pattern + 1;
          if Pattern = 4 then Pattern := 0
        end {if (Wahl=Taste}
        {!!! zu Beginn ist Taste <> Wahl, d.h. Pattern wird 0 gesetzt}
        else Pattern := 0;                 {Pattern 0, 1, 2, 3 entspricht LED}
        LineOld := Line;
        case ord (Wahl) of
          Taste_F1 : Line := 1;      {entspricht Zeile 1}
          Taste_F2 : Line := 2;      {entspricht Zeile 2}
          Taste_F3 : Line := 3;      {entspricht Zeile 3}
          Taste_F4 : Line := 4;      {entspricht Zeile 4}
          Taste_F5 : Line := 5;      {entspricht Zeile 5}
          Taste_F6 : Line := 6;      {entspricht Zeile 6}
          Taste_F7 : Line := 7;      {entspricht Zeile 7}
          Taste_F8 : Line := 8;      {entspricht Zeile 8}
        end; {case}
        {alte Zeile wird genullt, wenn neue Zeile anfÑngt und auch auf 0 ist}
        Refresh_BDU_2_Front (Pattern, LineOld);
        Refresh_BDU_2_Front (Pattern, Line); {Line aus Fkt-Taste, Pattern s.o.}
        {z.B.: 5.Zeile Muster: 2; Line_Pattern = 2*256}
        Line_Pattern := (Pattern * Zeilenfaktor[Line]);
        Set_BDU_2 (Line_Pattern);
        Taste := Wahl; {gewÑhlte Taste Fx wird in Taste gemerkt}
      end; { if Wahl = #0 }
      Wahl := NewReadKey;
      {Schleife fÅr zuvor gewÑhlte Fkt-Taste mit SchleifenzÑhler}
      if Wahl = Return then begin
        Ini_Msg_Win;
        Write(' Stop/Single-Step: Fkt-Taste                                 EXIT: X-Taste');
        Loop_Zaehl := 0;
        repeat
          Loop_Zaehl := Loop_Zaehl + 1;
          Set_Text_Win;
          GotoXY(58, 02);
          Write ('Schleifenanzahl : ', Loop_Zaehl:4);
          Pattern := Pattern + 1;
          if Pattern = 4 then Pattern := 0;
          Refresh_BDU_2_Front (Pattern, Line); {Line aus Fkt-Taste, Pattern s.o.}
          {z.B.: 5.Zeile Muster: 2; Line_Pattern = 2*256}
          Line_Pattern := (Pattern * Zeilenfaktor[Line]);
          Set_BDU_2 (Line_Pattern);
          Delay (400);     {Zeit : 400 ms}
        until KeyEPressed;
        Wahl := NewReadKey;
      end; {Wahl = Return}
      if Ord(Wahl) = Esc then Exit;
  {if (Wahl Not In ['x','X']) And (Wahl <> #0) then Beep;  statt Zeile drÅber}
    until Wahl in ['x','X'];
  end; {One_Line_Four_Pattern}

  Begin  {BDU_2}
  {IFK-Adr in proc.Mil_Ask_Ifc ermittelt und in Ifc_Test_Nr gespeichert}
  IfcAdr := Ifc_Test_Nr;
  Adr.AdrIfc := IfcAdr;         {die ifk hat die Adresse 10}
  Adr.AdrCard := IoCard_BDU_2_3;  {BDU_2 hÑngt an der 05. IO-Card}
  Adr.AdrMode := AdrNew;        {die Mode-Adresse wird neu "berechnet"}
  Adr.AdrSub := SubAdrCh_1;     {Ch-1, Wr }
  Clr_Sub_Menue_Text;     {Lîscht Meldung Åber IFK- Anzahl und - Adresse}
  Set_Text_Win; TextColor(Yellow);
  GotoXY(02,01);
  Write('Test des Einschubs BDU_2 !');  {SubmenÅ Topline}
  Fkt_Tasten_Auswahl_Menue2;            {FunktionsmenÅ}
  BDU_2_Front;                          {SubmenÅ Frontplatte}
  Fkt_Tast_Auswahl_Msg;                 {Fkt-Taste oder X}
  Ch := NewReadKey;
  if Ord(Ch) = Esc then Exit;
  if Ch in ['x','X'] then Exit;
  repeat
    if Ch = #0 then begin
      Ch := NewReadKey;
      if Ord(Ch) = Esc then Exit;
      case ord (Ch) of

         Taste_F1 : begin      {Wahl Muster und Line-Nr}
          Clr_Fkt_Tast_Win;
          Prep_Sub_Menue_Topl;
          Writeln ('(F1-Taste): Freie Wahl von LED-Kombination und Zeilen-Nr. ');
          Sing_Loop_X := ' ';
          if Ord(Sing_Loop_X) = Esc then Exit; {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                {alle LED ausschalten}
                Pattern := 0;
                All_Line_Same_Pattern (Pattern);
                {neue Wahl und Anzeige}
                Muster_And_Line_In;
                Ini_Msg_Win;
                Kleine_Auswahl_Msg;
                Sing_Loop_X := NewReadKey;
                if Ord(Sing_Loop_X) = Esc then Exit;
              end;  {' '}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Set_Text_Win;
          Fkt_Tasten_Auswahl_Menue2;
          Fkt_Tast_Auswahl_Msg;
        end; {F1-Taste}

        Taste_F2 : begin      {gleiches Muster in allen Zeilen gleichzeitig}
          Clr_Info_Win_1;
          Clr_Fkt_Tast_Win;
          Prep_Sub_Menue_Topl;
          Writeln ('(F2-Taste): Durchtasten aller Muster (0, 1, 2, 3) in  ');
          Write ('             allen Zeilen gleichzeitig mit der Space-Taste ');
          Sing_Loop_X := ' ';
          if Ord(Sing_Loop_X) = Esc then Exit;  {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                {definierter Neuanfang: alle LED aus, also auf 0}
                Pattern := 0;
                All_Line_Same_Pattern (Pattern);
                Ini_Msg_Win;
                Write(' Weiter mit <Space>                                      Ende mit <ESC> ');
                Zaehler := -1; {-1,um beim Durchtasten bei 0 anzufangen}
                repeat
                  Weiter := Newreadkey;
                  if Weiter = ' 'then  begin
                    Zaehler := Zaehler + 1;  {ZÑhlerwert entspricht Muster}
                    if Zaehler = 4 then Zaehler := 0;
                    Pattern := Zaehler;
                    All_Line_Same_Pattern (Pattern);
                  end; {if Weiter}
                until Ord(Weiter) = Esc;
                Ini_Msg_Win;
                Std_Msg;
                Sing_Loop_X := NewReadKey;
                if Ord(Sing_Loop_X) = Esc then Exit;
              end;  {' '}
              {Loop mit Ermittlung und Ausgabe des SchleifenzÑhlers }
              Return : begin
                Loop_Zaehl := 0;
                repeat
                  Loop_Zaehl := Loop_Zaehl + 1;
                  Set_Text_Win;
                  GotoXY(58, 02);
                  Write ('Schleifenanzahl : ', Loop_Zaehl:4);
                  ini_msg_win;
                  Write (' beliebiger Tastendruck fÅhrt zum Abbruch       ');
                  for Feld_Elem := 0 to 3 do begin
                  Pattern := Feld_Elem;
                  All_Line_Same_Pattern (Pattern);
                  Delay (400);     {Zeit : 400 ms}
                  end; {for}
                until KeyEPressed;
                {alle LED ausschalten, fÅr definierten Neuanfang}
                Pattern := 0;
                All_Line_Same_Pattern (Pattern);
                Ini_Msg_Win;
                Std_Msg;
              end; {Return}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Set_Text_Win;
          Fkt_Tasten_Auswahl_Menue2;
          Fkt_Tast_Auswahl_Msg;
        end; {F2-Taste}

        Taste_F3 : begin      {Test einzelner Zeile im Loop und Single Step}
          {definierter Neuanfang: alle LED aus, also auf 0}
          Pattern := 0;
          All_Line_Same_Pattern (Pattern);
          Clr_Info_Win_1;
          Prep_Sub_Menue_Topl;
          Writeln ('(F3-Taste): Test einzelner Zeile im Loop und Single Step ');
          Sing_Loop_X := ' ';
          if Ord(Sing_Loop_X) = Esc then Exit;  {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                One_Line_Four_Pattern;
                Ini_Msg_Win;
                Kleine_Auswahl_Msg;
                Sing_Loop_X := NewReadKey;
                if Ord(Sing_Loop_X) = Esc then Exit;
              end;  {' '}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Clr_Fkt_Tast_Win;
          Set_Text_Win;
          Fkt_Tasten_Auswahl_Menue2;
          Fkt_Tast_Auswahl_Msg;
        end; {F3-Taste}
      end; {case}
    end; {   if Ch = #0 then  }
    if KeyEPressed then Ch := NewReadKey;
    if Ord(Ch) = Esc then Exit;
  until Ch in ['x','X'];
End;   {BDU_2}

procedure BDU_3;
  var
    ACCEL, Zeile, Feld_Elem, Nr, Zaehler, Ende : Integer;
    Weiter, Okay : Char;
    IfcAdr : Byte;
    Adr : TModAdr;
    Sing_Loop_X : Char;
    Loop_Zaehl : Integer;

  {Ansicht der Frontplatte von BDU_3, mit erklÑrendem Text}
  procedure BDU_3_Front;
    var
      Z : Integer;
    begin
    Set_Text_Win;
    Textcolor (black);
    GotoXY(32,09); Write ('Die LEDs zeigen die Anforderung an, die durch');
    GotoXY(32,10); Write ('einen 50 Ohm Abschlu· veranla·t wird  ');
    GotoXY(32,12); Write ('"O" = LED aus ');
    GotoXY(32,14); Write ('"X" = LED leuchtet');
    Set_Front_Anzeige;
    GotoXY(04,01); Write ('REQ');
    for Z := 3 to 10 do begin
      GotoXY (05,Z);
      Write ('O');
    end;
  end; {BDU_3_Front}

  {BDU_3 - Frontplatte wird aktualisiert}
  procedure Refresh_BDU_3_Front (Zeile : Integer);
    begin
      Ini_Front_Win;
      GotoXY (01, Zeile);
      Write ('  X');
  end; {Refresh_BDU_3_Front}

  {Begleittext fÅr BDU_3 - Frontplatte}
  procedure Text_For_BDU_3_Front;
    begin
      Set_Text_Win;
      Textcolor (yellow);
      GotoXY(32,06); Write ('Bitte nebenstehende Anzeige mit der Frontplatte ');
      GotoXY(32,07); Write ('des GerÑtes ÅberprÅfen ');
  end; {Text_For_BDU_3_Front}

  {Funktionstastenwahl fÅr BDU_3 - Test}
  procedure Fkt_Tasten_Auswahl_Menue3;
    begin
    Auswahl_Menue_Head;
    GotoXY(01, 01); Write('F1:LEMO-Buchsen Belegung / LED Anzeige   ');
    TextColor(Black);
  end; {Fkt_Tasten_Auswahl_Menue3}

  {AusfÅhren der Mil-Proceduren, mit Mil-Fehlerbehandlung!
   Adressierung unter BDU_3 festgelegt,
   LED-Zustand, sowie versteckte ZeilenNr in Data-Les, mit Ergebnis Åbergeben}
  procedure Take_BDU_3 (var Ergebnis : Integer);
    var
      MilErr : TMilErr;
      LeseLED : Integer;
    begin
    LeseLED := 0;
    MilErr := No_Err;
    Mil.Rd_ModBus (DLes.W, Adr, MilErr );
    LeseLED := DLes.W ;
    Ergebnis := LeseLED;
    {hex_word wandelt ein Word in einen Hex- String um
    BDU3_LED_Hex := hex_word (LeseLED);
    Writeln ('LED [Hex]:       ',BDU3_LED_Hex);
    {word_bin wandelt ein Word in einen BinÑren- String um
    BDU3_LED_Bin := word_bin (LeseLED); }
    if MilErr <> No_Err then begin
      Clr_F_Tast_Output;
      Clr_F_Tast_Err_Succ;
      Abbruch_Mil_Fehler (MilErr); {mit Exit}
    end;
  end; {Take_BDU_3}

  {Ausgaberoutine aller Zeilen-Nr, deren LED an ist (aus Take_BDU_3 )
   Aus dem Wert Ergebnis mÅssen die ZeilenNr ermittelt werden}
  procedure Schalter_Zeile_Nr_Out;
    const
      Wertigkeit : array[0..7] of Integer = (128, 64, 32, 16, 8, 4, 2, 1);
    var
      FElement, Ergebnis, Summe : Integer;
    begin
    Text_For_BDU_3_Front;
    Take_BDU_3 (Ergebnis); {LED-Zustand auslesen Åber Ergebnis}
    Summe := Ergebnis;
    for FElement := 0 to 7 do begin
      Summe := (Summe - Wertigkeit[FElement]);
      if Summe > 0 then Zeile := (8 - FElement);{nach -128 in 8.Zeile ein 'X'}
      if Summe < 0 then Summe := (Summe + Wertigkeit[FElement]);
      if Summe = 0 then begin
        Zeile := (8 - FElement);
        FElement := 7;
      end; {= 0}
      Refresh_BDU_3_Front (Zeile);
    end; {for FElement}
  end; {Schalter_Zeile_Nr_Out}

  Begin  {BDU_3}
  {IFK-Adr in proc.Mil_Ask_Ifc ermittelt und in Ifc_Test_Nr gespeichert}
  IfcAdr := Ifc_Test_Nr;
  Adr.AdrIfc := IfcAdr;   {die ifk hat die Adresse 10}
  Adr.AdrCard := IoCard_BDU_2_3;  {BDU_3 hÑngt an der 05. IO-Card}
  Adr.AdrMode := AdrNew;  {die Mode-Adresse wird neu "berechnet"}
  Adr.AdrSub := SubAdrCh_0;  {Ch-0,  Rd  }
  Clr_Sub_Menue_Text;     {Lîscht Meldung Åber IFK- Anzahl und - Adresse}
  Set_Text_Win; TextColor(Yellow);
  GotoXY(02,01);
  Write('Test des Einschubs BDU_3 !');  {SubmenÅ Topline}
  Fkt_Tasten_Auswahl_Menue3;            {FunktionsmenÅ}
  BDU_3_Front;                          {SubmenÅ Frontplatte}
  ini_msg_win;
  Write(' Bitte 50 Ohm AbschlÅsse setzen und mit Tastendruck bestÑtigen');
  {besser als READ; die Engabe erscheint nicht auf dem Monitor,
   au·erdem mu· 'Okay' so nicht zurÅckgesetzt werden}
  Okay := Newreadkey;
  Fkt_Tast_Auswahl_Msg;                          {Fkt-Taste oder X}
  Ch := NewReadKey;
  if Ord(Ch) = Esc then Exit;
  if Ch in ['x','X'] then Exit;
  repeat
    if Ch = #0 then begin
      Ch := NewReadKey;
      if Ord(Ch) = Esc then Exit;
      case Ord (Ch) of

        Taste_F1 : begin    {Info auslesen, anzeigen PC, optische Kontrolle}
          Clr_Fkt_Tast_Win;
          Prep_Sub_Menue_Topl;
          Writeln ('(F1-Taste): LED-Zustand (Strahlanforderung) auslesen ');
          Sing_Loop_X := ' ';
          if Ord(Sing_Loop_X) = Esc then Exit;  {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                BDU_3_Front;  {hier wird jede Zeile genullt}
                Schalter_Zeile_Nr_Out;
                Ini_Msg_Win;
                Std_Msg;
                Sing_Loop_X := NewReadKey;
                if Ord(Sing_Loop_X) = Esc then Exit;
              end;  {' '}
              {Loop mit Ermittlung und Ausgabe des SchleifenzÑhlers }
              Return : begin
                Loop_Zaehl := 0;
                ini_msg_win;
                Write ('beliebiger Tastendruck fÅhrt zum Abbruch');
                repeat
                  Loop_Zaehl := Loop_Zaehl + 1;
                  Set_Text_Win;
                  GotoXY(58, 02);
                  Write ('Schleifenanzahl : ', Loop_Zaehl:4);
                  BDU_3_Front;  {hier wird jede Zeile genullt}
                  Schalter_Zeile_Nr_Out;
                  {hier Delay, sonst kann man die Ausgabe nicht verfolgen }
                  Delay (400);     {Zeit : 400 ms}
                until KeyEPressed;
                ini_msg_win;
                Std_Msg;
              end; {Return}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Set_Text_Win;
          Fkt_Tasten_Auswahl_Menue3;
          Fkt_Tast_Auswahl_Msg;
        end; {F1-Taste}
      end; {case}
    end; {   if Ch = #0 then  }
    if KeyEPressed then Ch := NewReadKey;
    if Ord(Ch) = Esc then Exit;
  until Ch in ['x','X'];
End;   {BDU_3}


procedure Therapie_und_Zusatzstecker;
{Anordnung der Therapie Stecker bei Blick auf die RÅckwand von links nach
 rechts: Stecker Nr.4 (0-3 In), Nr.3 (4-7 In), Nr.2 (0-3 Out), Nr.1 (4-7 Out)
 Die Stecker Nr. sind entsprechend der verbundenen IO-Karten-Adressen}
{'Totschlagfunktion' fÅr F3, wenn IO-Karte 8 nicht vorhanden! siehe F3}
  const
    Text_1 = '     Output PZA 4-7 (Stecker 1)      Input PZA 4-7 (Stecker 3)';
    Text_2 = '     Output PZA 0-3 (Stecker 2)      Input PZA 0-3 (Stecker 4)';
    Text_3 = '          32bit Output (Zusatzstecker: Ch0 0-15, Ch1 16-32   )';
    {alle kombinationen fÅr 32 Bit, also fÅr Ch0 und Ch1}
    Bit_Komb_01 = $55555555;  {Bitfolge: 0101010101010101}
    Bit_Komb_10 = $AAAAAAAA;  {Bitfolge: 1010101010101010}
    Bit_Komb_Shl = $00000001; {Ausgangswert fÅr links schieben }
    Bit_Komb_Shr = $80000000; {Ausgangswert fÅr rechts schieben}
  var
    IfcAdr : Byte;
    Adr : TModAdr;
    Sing_Loop_X, Raus : Char;
    Loop_Zaehl : Integer;
    MilErr : TMilErr;

{Funktionstastenauswahl fÅr Therapie- Stecker- Test}
  procedure Fkt_Tasten_Auswahl_MenueT_Z;
    begin
    Auswahl_Menue_Head;
    GotoXY(01, 01); Write('F1: Stecker: 1 (Out 4-7) und 3 (In 4-7)');
    GotoXY(01, 02); Write('F2: Stecker: 2 (Out 0-3) und 4 (In 0-3)');
    GotoXY(01, 03); Write('F3: Zusatzstecker (32 Bit Output)      ');
    TextColor(Black);
  end; {Fkt_Tasten_Auswahl_MenueT}

{Funktionstastenauswahl fÅr Therapie- Stecker- Test}
  procedure Zweite_Wahl(Card_Kennung_1, Card_Kennung_2 : Word; Text : String;
                        var Raus : Char);
    var
      Wahl, Taste : Char;
      Eingabe, Eingabe1_und_16bit : Longint;
      Eingabe1, Eingabe0 : Word;
      Sing_Loop_X, Weiter : Char;
      Loop_Zaehl, Zaehler : Integer;

    {allgemeingÅltige Ausgabe Maske fÅr F1, F2, F3
    Bei F3 mu· in der Ausgabe mit Werten die Input-Wert-Zeile weg!}
    procedure Ausgabe_Maske_Output;
      begin
      Set_Text_Win;
      TextColor(Yellow);
      GotoXY(02, 07); Write (Text);
      GotoXY(02, 13);
      Write ('                           Bit             Bit Bit            Bit');
      GotoXY(02, 14);
      Write ('                            31..............16 15..............00 ');
      TextColor(Blue);
      GotoXY(02, 09);
      Write ('                      ------ Ch1 ------------   ------------ Ch0 ------');
      GotoXY(02, 10);
      Write ('                      [Hex]       [Bin]             [Bin]         [Hex]');
      GotoXY(02, 11); Write ('Output - Wert       : ');
      GotoXY(02, 12); Write ('Output - RÅckgelesen: ');
      GotoXY(02, 15); Write ('Input - Wert        : ');
    end; {Ausgabe_Maske_Output}

    {Eingabe (Output), RÅcklesen, Einlesen(Input) / Vergleich / Ausgabe}
    procedure Verarbeitung_Kontrolle_Ausgabe (Card_Kennung_1, Card_Kennung_2 : Word;
                                              Eingabe : Longint);
      var
        Wahl, Taste : Char;
        Adr : TModAdr;
        { MilErr : TMilErr; raus wegen Erweiterung in F3}
        DLes, DSchreib : DRec;
        Wert_Ein : TEin_Rec; {}
        Eingabe_1, Eingabe_0 : Word;
        {Bit-Kombinationen, welche zu den Outputsteckern geschoben werden}
        Eingabe_Bin_1, Eingabe_Hex_1, Eingabe_Bin_0, Eingabe_Hex_0 : String;
        {gelesene Bitkombinationen an Input-Stecker Kanal 1 und 0}
        Rd_Ch1, Rd_Ch0 : Word;
        Rd_Ch1_Bin, Rd_Ch1_Hex, Rd_Ch0_Bin, Rd_Ch0_Hex : String;
        {rÅckgelesene Bitkombination des Output-steckers an Ch0 und Ch1 }
        Rueck_Ch1, Rueck_Ch0 : Word;
        Rueck_Ch1_Bin, Rueck_Ch1_Hex, Rueck_Ch0_Bin, Rueck_Ch0_Hex : String;
        Rueck1, Wert_Rd1, Rueck2, Wert_Rd2 : String;
        {Eingabe_1 sind die oberen 16Bit von Eingabe_lang}

      {Bearbeitung, Mil-Proceduren, Hex- und Binumwandlungen}
      begin
      Wert_Ein.L := Eingabe;
      Eingabe_1 := Wert_Ein.W.EinHigh;
      Eingabe_0 := Wert_Ein.W.EinLow;
      Adr.AdrIfc := IfcAdr;   {die ifk hat die Adresse xx}
      Adr.AdrMode := AdrNew; {die Mode-Adresse wird neu "berechnet" ! Wichtig}
    {32Bit (Eingabe) (= Wert fÅr Ch1 und Ch0) in den Ausgangsstecker schreiben}
      Adr.AdrCard := Card_Kennung_1;
      Adr.AdrSub := SubAdrCh_1;
      DSchreib.W := Eingabe_1;
      Mil.Wr_ModBus (DSchreib.W, Adr, MilErr );
      if MilErr <> No_Err then begin
        Clr_F_Tast_Output;
        Clr_F_Tast_Err_Succ;
        Abbruch_Mil_Fehler (MilErr);  {mit Exit}
      end;
      Adr.AdrSub := SubAdrCh_0;
      DSchreib.W := Eingabe_0;
      Mil.Wr_ModBus (DSchreib.W, Adr, MilErr );
      if MilErr <> No_Err then begin
        Clr_F_Tast_Output;
        Clr_F_Tast_Err_Succ;
        Abbruch_Mil_Fehler (MilErr); {mit Exit}
      end;
      {Hier ist vielleicht eine Verzîgerung (1ms) notwendig, weil die Lese-
       procedur schneller ist als die Schreibprocedure}
      Delay(1);
    {RÅcklesen, der Werte, die in den Outputstecker geschrieben wurden}
      Adr.AdrSub := SubAdr_Out_Rueck_Ch1;
      Mil.Rd_ModBus (DLes.W, Adr, MilErr );
      if MilErr <> No_Err then begin
        Clr_F_Tast_Output;
        Clr_F_Tast_Err_Succ;
        Abbruch_Mil_Fehler (MilErr);  {mit Exit}
      end;
      Rueck_Ch1 := DLes.W ;
      Adr.AdrSub := SubAdr_Out_Rueck_Ch0;
      if MilErr <> No_Err then begin
        Clr_F_Tast_Output;
        Clr_F_Tast_Err_Succ;
        Abbruch_Mil_Fehler (MilErr);  {mit Exit}
      end;
      Mil.Rd_ModBus (DLes.W, Adr, MilErr );
      Rueck_Ch0 := DLes.W ;
    {Auslesen der Eingangssteckerwerte fÅr Therapie; bei Zusatzstecker nicht}
      if Card_Kennung_2 <> Nichts then
        begin
        Adr.AdrCard := Card_Kennung_2;
        Adr.AdrSub := SubAdrCh_1;
        if MilErr <> No_Err then begin
          Clr_F_Tast_Output;
          Clr_F_Tast_Err_Succ;
          Abbruch_Mil_Fehler (MilErr); {mit Exit}
        end;
        Mil.Rd_ModBus (DLes.W, Adr, MilErr );
        Rd_Ch1 := DLes.W ;
        Adr.AdrSub := SubAdrCh_0;
        if MilErr <> No_Err then begin
          Clr_F_Tast_Output;
          Clr_F_Tast_Err_Succ;
          Abbruch_Mil_Fehler (MilErr); {mit Exit}
        end;
        Mil.Rd_ModBus (DLes.W, Adr, MilErr );
        Rd_Ch0 := DLes.W ;
      end; {if Card_Kennung_2}
    {Hex- und Bin-Umwandlungen der Ergebnisse zur Anzeige}
      {hex_word wandelt ein Word in einen Hex- String um}
      {word_bin wandelt ein Word in einen BinÑren- String um}
      {Output-Werte}
      Eingabe_Hex_1 := hex_word (Eingabe_1);
      Eingabe_Hex_0 := hex_word (Eingabe_0);
      Eingabe_Bin_1 := word_bin (Eingabe_1);
      Eingabe_Bin_0 := word_bin (Eingabe_0);
      {RÅckgelesene Output-Werte}
      Rueck_Ch1_Hex := hex_word (Rueck_Ch1);
      Rueck_Ch1_Bin := word_bin (Rueck_Ch1);
      Rueck_Ch0_Hex := hex_word (Rueck_Ch0);
      Rueck_Ch0_Bin := word_bin (Rueck_Ch0);
      {Input-Werte}
      Rd_Ch1_Hex := hex_word (Rd_Ch1);
      Rd_Ch1_Bin := word_bin (Rd_Ch1);
      Rd_Ch0_Hex := hex_word (Rd_Ch0);
      Rd_Ch0_Bin := word_bin (Rd_Ch0);
      {Vergleich}
      Rueck1 := 'Richtig';
      Rueck2 := 'Richtig';
      Wert_Rd1 := 'Richtig';
      Wert_Rd2 := 'Richtig';
      if Eingabe_1 <> Rueck_Ch1 then Rueck1 := 'Falsch';
      if Eingabe_0 <> Rueck_Ch0 then Rueck2 := 'Falsch';
      if Eingabe_1 <> Rd_Ch1 then Wert_Rd1 := 'Falsch';
      if Eingabe_0 <> Rd_Ch0 then Wert_Rd2 := 'Falsch';
    {Ausgabe; falsche Werte werden rot ausgegeben}
      Ausgabe_Maske_Output; {fester Ausgabetext zur ErklÑrung}
      Set_Text_Win;
      TextColor(Black);
      GotoXY(24, 11);
      Write ( Eingabe_Hex_1,'   ',Eingabe_Bin_1,'   ',Eingabe_Bin_0,'   ',Eingabe_Hex_0);
      if Rueck1 = 'Falsch'then TextColor(Red);
      GotoXY(24, 12);
      Write (Rueck_Ch1_Hex,'   ', Rueck_Ch1_Bin,'   ');
      if Rueck2 = 'Falsch'then TextColor(Red)
      else TextColor(Black);
      Write (Rueck_Ch0_Bin,'   ', Rueck_Ch0_Hex);
      if Wert_Rd1 = 'Falsch'then TextColor(Red)
      else TextColor(Black);
    {Ausgabe der Inputstecker fÅr Therapie; Aufforderung zum Vergleich bei Zusatzstecker}
      if Card_Kennung_2 = Nichts then
        begin
        GotoXY(02, 15);
        TextColor (Red);
        Write ('Jede 1 fÅhrt auf den APKs und den LED-PrÅfsteckern zum Leuchten einer LED');
      end {then}
      else begin
        GotoXY(24, 15);
        Write (Rd_Ch1_Hex,'   ', Rd_Ch1_Bin,'   ');
        if Wert_Rd2 = 'Falsch'then TextColor(Red)
        else TextColor(Black);
        Write (Rd_Ch0_Bin,'   ', Rd_Ch0_Hex);
      end; {else}
    end; {Verarbeitung_Kontrolle_Ausgabe}

    {Funktionstastenauswahl der Testmîglichkeiten}
    procedure Fkt_Tasten_Auswahl_MenueT_Z_2;
      begin
      Auswahl_Menue_Head;
      GotoXY(01, 01); Write('F1: Bitfolge 10101010 ($AA) fÅr Ch1 und Ch0           ');
      GotoXY(01, 02); Write('F2: Bitfolge 01010101 ($55) fÅr Ch1 und Ch0           ');
      GotoXY(01, 03); Write('F3: Bitfolge nach Wahl fÅr Ch1 und Ch0                ');
      GotoXY(01, 04); Write('1 bit durchschieben:  F4: nach links   F5: nach rechts');
      {hier sind nur 4 Zeilen vorgesehen in dem Anzeigefenster}
      TextColor(Black);
    end; {Fkt_Tasten_Auswahl_MenueT_Z_2}

    {Frage, ob ein BrÅckenstecker bzw. die LED-Teststecker gesetzt sind}
    procedure Stecker_Warn_Msg;
      begin
      repeat
      TextColor(Red);
      ini_err_win;
        if Card_Kennung_2 = Nichts then
          Write (' Sind die AusgÑnge mit LED-PrÅfstecker versehen ?   J ')
        else
          Write (' Sind die In- und Outputstecker mit einer BrÅcke (pingetreu) verbunden?   J ');
      until Newreadkey in ['J', 'j'];
      TextColor(Black);
    end; {Stecker_Warn_Msg}

    begin
    Abbruch := ' ';
    Fkt_Tasten_Auswahl_MenueT_Z_2;       {FunktionsmenÅ}
    Stecker_Warn_Msg;      {rote Fu·zeile: Frage nach BrÅcke oder Stecker}
    Fkt_Tast_Auswahl_Msg;               {Wahl: Fkt-Tasten oder x}
    Wahl := NewReadKey;
    if Ord(Wahl) = Esc then Exit;
    if Wahl in ['x','X'] then Exit;
    repeat
    if Wahl = #0 then begin
      Wahl := NewReadKey;
      if Ord(Wahl) = Esc then Exit;
      case ord (Wahl) of

        Taste_F1 : begin  {Bitfolge 10 (=$A); Ausgang-BrÅckenstecker-Eingang}
        Clr_Fkt_Tast_Win;
        Prep_Sub_Menue_Topl;
        Writeln ('(F1-Taste): Aus-, Eingangstest mit der Bitfolge 10 ($AAAAAAAA)');
        Sing_Loop_X := ' ';
        if Ord(Sing_Loop_X) = Esc then Exit;  {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                Eingabe := Bit_Komb_10;
                Verarbeitung_Kontrolle_Ausgabe (Card_Kennung_1, Card_Kennung_2, Eingabe); {}
                if (Abbruch = 'x') or (Abbruch = 'X') then Exit; {bei Fehler}
                Ini_Msg_Win;
                Std_Msg;
                Sing_Loop_X := NewReadKey;
                if Ord(Sing_Loop_X) = Esc then Exit;
              end;  {' '}
              {Loop mit Ermittlung und Ausgabe des SchleifenzÑhlers }
              Return : begin
                Loop_Zaehl := 0;
                ini_msg_win;
                Write ('beliebiger Tastendruck fÅhrt zum Abbruch');
                repeat
                  Loop_Zaehl := Loop_Zaehl + 1;
                  Set_Text_Win;
                  GotoXY(67, 02);
                  Write ('Loop Nr.: ', Loop_Zaehl:4);
                  Verarbeitung_Kontrolle_Ausgabe (Card_Kennung_1, Card_Kennung_2, Eingabe);  {}
                  if (Abbruch in ['x','X']) then Exit;
                  {hier Delay, sonst kann man die Ausgabe nicht verfolgen }
                  Delay (400);     {Zeit : 400 ms}
                until KeyEPressed;
                ini_msg_win;
                Std_Msg;
              end; {Return}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Set_Text_Win;
          Fkt_Tasten_Auswahl_MenueT_Z_2;
          Fkt_Tast_Auswahl_Msg;
        end; {F1-Taste}

        Taste_F2 : begin  {Bitfolge 01 (=$55); Ausgang-BrÅckenstecker-Eingang}
        Clr_Fkt_Tast_Win;
        Prep_Sub_Menue_Topl;
        Writeln ('(F2-Taste): Aus-, Eingangstest mit der Bitfolge 01 ($55555555)');
        Sing_Loop_X := ' ';
        if Ord(Sing_Loop_X) = Esc then Exit; {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                Eingabe := Bit_Komb_01;
                Verarbeitung_Kontrolle_Ausgabe (Card_Kennung_1, Card_Kennung_2, Eingabe); {}
                if (Abbruch = 'x') or (Abbruch = 'X') then Exit; {bei Fehler}
                Ini_Msg_Win;
                Std_Msg;
                Sing_Loop_X := NewReadKey;
                if Ord(Sing_Loop_X) = Esc then Exit;
              end;  {' '}
              {Loop mit Ermittlung und Ausgabe des SchleifenzÑhlers }
              Return : begin
                Loop_Zaehl := 0;
                ini_msg_win;
                Write ('beliebiger Tastendruck fÅhrt zum Abbruch');
                repeat
                  Loop_Zaehl := Loop_Zaehl + 1;
                  Set_Text_Win;
                  GotoXY(67, 02);
                  Write ('Loop Nr.: ', Loop_Zaehl:4);
                  Verarbeitung_Kontrolle_Ausgabe (Card_Kennung_1, Card_Kennung_2, Eingabe);  {}
                  if (Abbruch in ['x','X']) then Exit;
                  {hier Delay, sonst kann man die Ausgabe nicht verfolgen }
                  Delay (400);     {Zeit : 400 ms}
                until KeyEPressed;
                ini_msg_win;
                Std_Msg;
              end; {Return}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Set_Text_Win;
          Fkt_Tasten_Auswahl_MenueT_Z_2;
          Fkt_Tast_Auswahl_Msg;
        end; {F2-Taste}

        Taste_F3 : begin  {Bitfolge nach Wahl; Ausgang-BrÅckenstecker-Eingang}
        Clr_Fkt_Tast_Win;
        Prep_Sub_Menue_Topl;
        Writeln ('(F3-Taste): Aus-, Eingangstest mit Bitfolge nach Wahl');
        Sing_Loop_X := ' ';
        if Ord(Sing_Loop_X) = Esc then Exit;  {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                repeat
                  {Eingabe von 2 4-stelligen Hex-zahlen}
                  ini_msg_win;
                  Write ('Zwei 4-stellige Hexzahlen (1.fÅr Ch1, 2.fÅr Ch0) eingeben dazu <Return> drÅcken');
                until Newreadkey = Return;
                Eingabe1 := Ask_Hex_Word;
                {! ohne nÑchste VerknÅpfung ergibt Eingabe1_lang shl 16 = 0}
                Eingabe1_und_16bit := Eingabe1 and $FFFFFFFF;
                Eingabe0 := Ask_Hex_Word;
                Eingabe := ((Eingabe1_und_16bit shl 16) or Eingabe0);
                Verarbeitung_Kontrolle_Ausgabe (Card_Kennung_1, Card_Kennung_2, Eingabe); {}
                if (Abbruch = 'x') or (Abbruch = 'X') then Exit; {bei Fehler}
                Ini_Msg_Win;
                Std_Msg;
                Sing_Loop_X := NewReadKey;
                if Ord(Sing_Loop_X) = Esc then Exit;
              end;  {' '}
              {Loop mit Ermittlung und Ausgabe des SchleifenzÑhlers }
              Return : begin
                Loop_Zaehl := 0;
                ini_msg_win;
                Write ('beliebiger Tastendruck fÅhrt zum Abbruch');
                repeat
                  Loop_Zaehl := Loop_Zaehl + 1;
                  Set_Text_Win;
                  GotoXY(67, 02);
                  Write ('Loop Nr.: ', Loop_Zaehl:4);
                  Verarbeitung_Kontrolle_Ausgabe (Card_Kennung_1, Card_Kennung_2, Eingabe);  {}
                  if (Abbruch in ['x','X']) then Exit;
                  {hier Delay, sonst kann man die Ausgabe nicht verfolgen }
                  Delay (400);     {Zeit : 400 ms}
                until KeyEPressed;
                ini_msg_win;
                Std_Msg;
              end; {Return}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Set_Text_Win;
          Fkt_Tasten_Auswahl_MenueT_Z_2;
          Fkt_Tast_Auswahl_Msg;
        end; {F3-Taste}

        Taste_F4 : begin  {bitweise shl; Ausgang-BrÅckenstecker-Eingang}
        Clr_Fkt_Tast_Win;
        Prep_Sub_Menue_Topl;
        Writeln ('(F4-Taste): 1 Bit durch alle 32 Bit nach links schieben');
        Sing_Loop_X := ' ';
        if Ord(Sing_Loop_X) = Esc then Exit;  {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                Ini_Msg_Win;
                Write(' Weiter mit <Space>                        Ende mit <ESC> ');
                Eingabe := Bit_Komb_Shl;
                Verarbeitung_Kontrolle_Ausgabe (Card_Kennung_1, Card_Kennung_2, Eingabe); {}
                if (Abbruch in ['x','X']) then Exit;
                Zaehler := 0; {-1,um beim Durchtasten bei 0 anzufangen}
                repeat
                  Weiter := Newreadkey;
                  if Weiter = ' ' then
                    begin
                    Zaehler := Zaehler + 1;  {ZÑhlerwert entspricht Muster}
                    Eingabe := Eingabe shl 1;
                    if Zaehler = 33 then
                      begin
                      Zaehler := 0;
                      Eingabe := Bit_Komb_Shl;
                    end; {Zaehler = 17}
                    Verarbeitung_Kontrolle_Ausgabe (Card_Kennung_1, Card_Kennung_2, Eingabe); {}
                    if (Abbruch in ['x','X']) then Exit;
                  end; {if Weiter}
                until Ord(Weiter) = Esc;
                if (Abbruch = 'x') or (Abbruch = 'X') then Exit; {bei Fehler}
                Ini_Msg_Win;
                Std_Msg;
                Sing_Loop_X := NewReadKey;
                if Ord(Sing_Loop_X) = Esc then Exit;
              end;  {' '}
              {Loop mit Ermittlung und Ausgabe des SchleifenzÑhlers }
              Return : begin
                Loop_Zaehl := 1;
                Set_Text_Win;
                GotoXY(67, 02);
                Write ('Loop Nr.: ', Loop_Zaehl:4);
                ini_msg_win;
                Write ('beliebiger Tastendruck fÅhrt zum Abbruch');
                Eingabe := Bit_Komb_Shl;
                Verarbeitung_Kontrolle_Ausgabe (Card_Kennung_1, Card_Kennung_2, Eingabe);  {}
                if (Abbruch in ['x','X']) then Exit;
                Zaehler := 0; {-1,um beim Durchtasten bei 0 anzufangen}
                Delay (400);     {Zeit : 400 ms}  {evtl. noch weg}
                repeat
                  Zaehler := Zaehler + 1;  {ZÑhlerwert entspricht Muster}
                  Eingabe := Eingabe shl 1;
                  if Zaehler = 33 then
                    begin
                    Loop_Zaehl := Loop_Zaehl + 1;
                    Set_Text_Win;
                    GotoXY(67, 02);
                    Write ('Loop Nr.: ', Loop_Zaehl:4);
                    Zaehler := 0;
                    Eingabe := Bit_Komb_Shl;
                  end; {Zaehler = 17}
                  Set_Text_win;
                  Verarbeitung_Kontrolle_Ausgabe (Card_Kennung_1, Card_Kennung_2, Eingabe);  {}
                  if (Abbruch in ['x','X']) then Exit;
                  {hier Delay, sonst kann man die Ausgabe nicht verfolgen }
                  Delay (400);     {Zeit : 400 ms}
                until KeyEPressed;
                ini_msg_win;
                Std_Msg;
              end; {Return}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Set_Text_Win;
          Fkt_Tasten_Auswahl_MenueT_Z_2;
          Fkt_Tast_Auswahl_Msg;
        end; {F4-Taste}

        Taste_F5 : begin  {bitweise shr; Ausgang-BrÅckenstecker-Eingang}
        Clr_Fkt_Tast_Win;
        Prep_Sub_Menue_Topl;
        Writeln ('(F5-Taste): 1 Bit durch alle 32 Bit nach links schieben');
        Sing_Loop_X := ' ';
        if Ord(Sing_Loop_X) = Esc then Exit;  {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                Ini_Msg_Win;
                Write(' Weiter mit <Space>                        Ende mit <ESC> ');
                Eingabe := Bit_Komb_Shr;
                Verarbeitung_Kontrolle_Ausgabe (Card_Kennung_1, Card_Kennung_2, Eingabe); {}
                if (Abbruch in ['x','X']) then Exit;
                Zaehler := 32; {32,um beim Durchtasten bei 31 anzufangen}
                repeat
                  Weiter := Newreadkey;
                  if Weiter = ' ' then
                    begin
                    Zaehler := Zaehler - 1;  {ZÑhlerwert entspricht Muster}
                    Eingabe := Eingabe shr 1;
                    if Zaehler = -1 then
                      begin
                      Zaehler := 32;
                      Eingabe := Bit_Komb_Shr;
                    end; {Zaehler = 17}
                    Verarbeitung_Kontrolle_Ausgabe (Card_Kennung_1, Card_Kennung_2, Eingabe); {}
                    if (Abbruch in ['x','X']) then Exit;
                  end; {if Weiter}
                until Ord(Weiter) = Esc;
                if (Abbruch = 'x') or (Abbruch = 'X') then Exit; {bei Fehler}
                Ini_Msg_Win;
                Std_Msg;
                Sing_Loop_X := NewReadKey;
                if Ord(Sing_Loop_X) = Esc then Exit;
              end;  {' '}
              {Loop mit Ermittlung und Ausgabe des SchleifenzÑhlers }
              Return : begin
                Loop_Zaehl := 1;
                Set_Text_Win;
                GotoXY(67, 02);
                Write ('Loop Nr.: ', Loop_Zaehl:4);
                ini_msg_win;
                Write ('beliebiger Tastendruck fÅhrt zum Abbruch');
                Eingabe := Bit_Komb_Shr;
                Verarbeitung_Kontrolle_Ausgabe (Card_Kennung_1, Card_Kennung_2, Eingabe);  {}
                if (Abbruch in ['x','X']) then Exit;
                Zaehler := 32; {32,um beim Durchtasten bei 31 anzufangen}
                Delay (400);     {Zeit : 400 ms}  {evtl. noch weg}
                repeat
                  Zaehler := Zaehler - 1;  {ZÑhlerwert entspricht Muster}
                  Eingabe := Eingabe shr 1;
                  if Zaehler = -1 then
                    begin
                    Loop_Zaehl := Loop_Zaehl + 1;
                    Set_Text_Win;
                    GotoXY(67, 02);
                    Write ('Loop Nr.: ', Loop_Zaehl:4);
                    Zaehler := 32;
                    Eingabe := Bit_Komb_Shr;
                  end; {Zaehler = 17}
                  Set_Text_win;
                  Verarbeitung_Kontrolle_Ausgabe (Card_Kennung_1, Card_Kennung_2, Eingabe);  {}
                  if (Abbruch in ['x','X']) then Exit;
                  {hier Delay, sonst kann man die Ausgabe nicht verfolgen }
                  Delay (400);     {Zeit : 400 ms}
                until KeyEPressed;
                ini_msg_win;
                Std_Msg;
              end; {Return}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Set_Text_Win;
          Fkt_Tasten_Auswahl_MenueT_Z_2;
          Fkt_Tast_Auswahl_Msg;
        end; {F5-Taste}

      end; {case}
    end; {   if Ch = #0 then  }
    if KeyEPressed then Wahl := NewReadKey;
    if Wahl in ['x', 'X'] then Raus := 'x';
    if Ord(Wahl) = Esc then Exit;
    until Wahl in ['x','X'];
  end; {Zweite_Wahl}

  Begin  {Therapie_Ein_Aus}
  {IFK-Adr in proc.Mil_Ask_Ifc ermittelt und in Ifc_Test_Nr gespeichert}
  IfcAdr := Ifc_Test_Nr;
  Adr.AdrIfc := IfcAdr;   {die ifk hat die Adresse 10}
  Adr.AdrMode := AdrNew;  {die Mode-Adresse wird neu "berechnet"}
  Abbruch := ' ';
  Clr_Sub_Menue_Text;     {Lîscht Meldung Åber IFK- Anzahl und - Adresse}
  Set_Text_Win; TextColor(Yellow);
  GotoXY(02,01);
  Write('Therapie- und Zusatzstecker !');  {SubmenÅ Topline}
  Fkt_Tasten_Auswahl_MenueT_Z;             {Auswahl: St1-3, St2-4, Zusatz}
  Fkt_Tast_Auswahl_Msg;                    {Fkt-Taste oder X}
  Ch := NewReadKey;
  if Ord(Ch) = Esc then Exit;
  if Ch in ['x','X'] then Exit;
  repeat
    if Ch = #0 then begin
      Ch := NewReadKey;
      if Ord(Ch) = Esc then Exit;
      case ord (Ch) of

        Taste_F1 : begin      {Auswahl Stecker 1 (4-7 Out) und St 3 (4-7 In)}
          Ini_Text_Win;
          Prep_Sub_Menue_Topl;
          TextColor(Yellow);
          Writeln ('(F1-Taste): Stecker 1 (4-7 Out) und Stecker 3 (4-7 In) ');
          Sing_Loop_X := ' ';
          if Ord(Sing_Loop_X) = Esc then Exit; {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                { Raus := ' '; mit dem: bei Abbruch mit ESC rote J/N Frage }
                {Testauswahl, sowie Verarbeitung und Ausgabe}
                Zweite_Wahl (IoCard_St1, IoCard_St3, Text_1, Raus);
                if (Abbruch in ['x','X']) then Exit;
                Sing_Loop_X := Raus;
              end;  {' '}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Clr_Fkt_Tast_Win;
          Set_Text_Win;
          Fkt_Tasten_Auswahl_MenueT_Z;
          Fkt_Tast_Auswahl_Msg;
        end; {F1-Taste}

        Taste_F2 : begin      {Auswahl Stecker 2 (0-3 out) und St 4 (0-3 In)}
          Ini_Text_Win;
          Prep_Sub_Menue_Topl;
          TextColor(Yellow);
          Writeln ('(F2-Taste): Stecker 2 (0-3 Out) und Stecker 4 (0-3 In) ');
          Sing_Loop_X := ' ';
          if Ord(Sing_Loop_X) = Esc then Exit; {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                {Testauswahl, sowie Verarbeitung und Ausgabe}
                Zweite_Wahl (IoCard_St2, IoCard_St4, Text_2, Raus);
                if (Abbruch in ['x','X']) then Exit;
                Sing_Loop_X := Raus;
              end;  {' '}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Clr_Fkt_Tast_Win;
          Set_Text_Win;
          Fkt_Tasten_Auswahl_MenueT_Z;
          Fkt_Tast_Auswahl_Msg;
        end; {F2-Taste}

        Taste_F3 : begin      {Auswahl Zusatzstecker: 32Bit out (0-15, 16-32)}
          Ini_Text_Win;
          Prep_Sub_Menue_Topl;
          {Check ob IO-Karte 8 da}

          Adr.AdrCard := IoCard_Zus_St;
          Adr.AdrSub := SubAdr_StatusRegister_Ch0_Rd; {hier ging auch CH1_Rd}
          Mil.Rd_ModBus (DLes.W, Adr, MilErr );
          if MilErr = Rd_To then
            begin
            TextColor(Red);
            Writeln ('(F3-Taste): Zusatzstecker nicht vorhanden! ');
            Sing_Loop_X := 'x';
          end
          else
            begin
            TextColor(Yellow);
            Writeln ('(F3-Taste): Zusatzstecker: 32Bit Out (0-15, 16-32) ');
            Sing_Loop_X := ' ';
          end;
          MilErr := No_Err;
          if Ord(Sing_Loop_X) = Esc then Exit; {kann weg wenn's stîrt}
          while Not(( Sing_Loop_X = 'x') or (Sing_Loop_X = 'X')) do begin
            case Sing_Loop_X of
              {Single Step}
              ' ' : begin
                {Testauswahl, sowie Verarbeitung und Ausgabe}
                Zweite_Wahl (IoCard_Zus_St, Nichts, Text_3, Raus);
                if (Abbruch in ['x','X']) then Exit;
                Sing_Loop_X := Raus;
              end;  {' '}
            end; {case}
            if KeyEPressed then Sing_Loop_X := NewReadKey;
            if Ord(Sing_Loop_X) = Esc then Exit;
          end; {While}
          Clr_Fkt_Tast_Win;
          Set_Text_Win;
          Fkt_Tasten_Auswahl_MenueT_Z;
          Fkt_Tast_Auswahl_Msg;
        end; {F3-Taste}

      end; {case}
    end; {   if Ch = #0 then  }
    if KeyEPressed then Ch := NewReadKey;
    if Ord(Ch) = Esc then Exit;
  until Ch in ['x','X'];
End;   {Therapie_und_Zusatzstecker}


BEGIN  { Hauptprogramm }
{Hier werden die ansich globalen Variablen aus den Bibliotheken Datech
 auf 0 gesetzt und in der proc.Mil_Ask_Ifc neu ermittelt }
Ifc_Test_Nr := 0;
Mod_Test_Nr := 0;
repeat
  Menue_Win;
  User_Input  := NewReadKey;
  Single_Step := True;
  case User_Input of
    '0' : Mil_Detect_Ifc;
    '1' : Mil_Detect_Ifc_Compare;
    '2' : begin
        Mil_Ask_Ifc;
        Mil_Rd_HS_Ctrl (Ifc_Test_Nr);
    end;
    '3' : begin
     {  Mil_Ask_Ifc;                    }
     {  Mil_Rd_HS_Status (Ifc_Test_Nr); }
    end;
    '4' : begin
        Mil_Ask_Ifc;
        Mil_Stat_All (Ifc_Test_Nr);
    end;
    '5' : begin
        Convert_Hex_Volt;
    end;
    '6' : begin
        Int_Mask;
    end;
    '7' : begin
     {  Mil_Ask_Ifc;
        Mil_HS_Stat_Cmd (Ifc_Test_Nr); }
    end;
    '9' : begin
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

    {Case Aufrufe der Prozeduren der Anf_Einh.}
    'm', 'M' : begin
             Mil_Ask_Ifc;
             Display;
    end;
    'n', 'N' : begin
             Mil_Ask_Ifc;
             Hardware;
    end;
    'o', 'O' : begin
             Mil_Ask_Ifc;
             BDU_1;
    end;
    'p', 'P' : begin
             Mil_Ask_Ifc;
             BDU_2;
    end;
    'q', 'Q' : begin
             Mil_Ask_Ifc;
             BDU_3;
    end;

    'r', 'R' : begin
             Mil_Ask_Ifc;
             Therapie_und_Zusatzstecker;
    end;
  end; {CASE}
until user_input in ['x','X'];
Window(1, 1, 80, 25);
TextBackground(Black);
ClrScr;
END. {Hauptprogramm  mil_base}









