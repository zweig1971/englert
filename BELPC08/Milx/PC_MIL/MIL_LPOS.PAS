PROGRAM Mil_LPOS;
{ Autor des Basis-Programmes MIL_BASE.PAS: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS

  Steuerung des LinearPositionierer LP der Firma G.A.S. GmbH
  Gesellschaft fÅer Antriebs u. Steuerungstechnik, Leopoldstr 1
  D-78112 St. Georgen; Tel. 07724-8801-31 Hr. Ganter; Fax.       8801-13

  Ansprechpartner GSI: Doktorand Hr. Groening Tel. 2401 Raum 3.001
                  Uni Gie·en: Adreas Hoffknecht, Dipl. Phys.
                  Institut fÅr Kernphysik, Strahlenzentrum
                  Leihgesternerweg 217, 35392 Gie·en
                  Mail: Andreas.Hoffknecht@strz.uni-giessen.de
                  Betreuer Hr. Steck, Bourgeois (GSI)
                  13.9.00 Herr JÅrgen Krieg Tel. 2350/2352
  énderungs-Protokoll:
  10.07.97  Et        V24-Piggy FG402.000
  01.09.97  Et        Normierung
  23.02.00  Et        wegen MIL-Timeout neu compiliert
  13.09.00  Et        Darstellung der Status-Signale Åber Schaltkarte
  03.11.00 Et         Info Status-Signale korrigiert
  16.11.00 Et         Nach dem Ausschalten der SPS muss ein erweitertes
                      Kommando fÅr eine Referenzfahrt benutzt werden!
                      Deshalb wird grundsÑtzlich nicht nur $/0  gesendet
                      Das Powerup-Bit auf der Schaltkarte wird mit Fct-Code 05
                      geîscht!
}
{$S-}
uses Crt, WinDos, Dos, Datech, Datech_0, Datech_1;    {spez. MIL-Routinen in Units Datech..}

const
 Head_Line =
      'BELAB                                MIL_LPOS   ' +
      '                    [01.06.2001]' +
      '                 LinearPositionierer LP mit V24-Piggy FG402.000                ';

 procedure menue_win;
  var answer: CHAR;
 begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;            {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}
  TextColor(Blue);

   {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}
  GotoXY(5, 14);
  Writeln('       [M]<-- Kommandos mit Tastatur-Eingabe (Terminal-Funktion)        ');
  GotoXY(5, 15);
  Writeln('       [N]<-- Kommandos mit Funktionstasten (Ref.Fahrt jetzt fÅr Powerup)');
  GotoXY(5, 16);
  Writeln('       [O]<-- Normierungsparameter lesen/schreiben               ');
  GotoXY(5, 17);
  Writeln('       [P]<-- Technische Daten V24-Anschlu·                             ');
  GotoXY(5, 18);
  Writeln('       [Q]<-- Spez.Kabel f. Verbindung: DEC-VT320 Terminal <--> SPS MC04');
  GotoXY(5, 19);
  Writeln('       [R]<-- Zeige Status-Signale (Byte1 der Schaltkarte FG 407070)     ');
{
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
  Fct_ClearPwrup   = $05;   {fÅr Schaltkarte: Poerup-Bit lîschen!!}
  SPS_Wait         = 50000; {Wartezeit bei Referenzfahrt}

  LineFeed  = 10;
  CarReturn = 13;
  Z_CmdWin_Base = 4;
  S_CmdWin_Base = 49;
  Z_NormTxt_WinBase = 4;
  S_NormTxt_WinBase = 55;
  Z_FTastNorm_Win   = 20;
  S_FTastNorm_Win   = 02;

 {Cmd_Anfang      = '$';}
  Cmd_Ende        = '*';
  Cmd_NormWrite   = 'mm';
  Cmd_Ini_Baudrate= '%';
  { Nach einem Powerup der SPS ist eine Referenzfahrt nur mit einer Folge von
    Kommandos mîglich: Cmd_Anfang, _Ini, _Kom_Source, _Ref
    Jedoch mÅssen Wartezeiten zwischen den Befehlen eingehalten werden, da die
    SPS auf jedes Kommando antwortet! }

  Cmd_Anfang      = '$';
  Cmd_Dummy       = '$*';        {Kommando Sequenzen an SPS}
  Cmd_Ini         = '$ab*';
  Cmd_Kom_Source  = '$kre*';
  Cmd_Ref         = '$/0*';
  Cmd_Istw        = '$cc*';
  Cmd_Norm        = '$mm*';
  Cmd_Rd_Error    = '$fa*';
  Cmd_Version     = '$vn*';
  Cmd_Anschlag_Li = '$dpx+003250*';   {Li Endschalter aktiv; bei 3250 normales Ende}
  Cmd_Anschlag_Re = '$dpx+000010*';   {Re Endschalter aktiv; bei 000000            }
  Cmd_Soft_Li     = '$dpx+002900*';   {Li 3 mm Distanz bis zum Endanschlag}
  Cmd_Soft_Re     = '$dpx+000300*';   {Re 3 mm Distanz bis zum Endanschlag}
{In der Normierung definieren Software-Endlage li u. re den Bereich fÅr dpx-Kommando}
  Default_Norm    = '-00100104011+005000+000000+000000';  {Ende links bei 5000 ist erlaubt}

 procedure Ini_NormTxt_Win;
  begin
   Window(S_NormTxt_WinBase, Z_NormTxt_WinBase, S_NormTxt_WinBase+(79-S_NormTxt_WinBase ), Z_NormTxt_WinBase+19);
   TextBackground(Cyan);
   TextColor(Black);               {Setze Schriftfarbe}
   ClrScr;
  end;

 procedure Ini_FTast_Norm_Win;
  begin
   Window(S_FTastNorm_Win,  Z_FTastNorm_Win , S_FTastNorm_Win+50 , Z_FTastNorm_Win+3);
   TextBackground(Cyan);
   ClrScr;
  end;
 procedure Set_FTast_Norm_Win;
  begin
   Window(S_FTastNorm_Win,  Z_FTastNorm_Win , S_FTastNorm_Win+50 , Z_FTastNorm_Win+3);
   TextBackground(Cyan);
   TextColor(Yellow);               {Setze Schriftfarbe}
  end;


 procedure FTast_NormText_Win;
  begin
   Window(S_NormTxt_WinBase, Z_NormTxt_WinBase, S_NormTxt_WinBase+(79-S_NormTxt_WinBase ), Z_NormTxt_WinBase+19);
   TextBackground(Cyan);
   TextColor(Brown);               {Setze Schriftfarbe}
   ClrScr;
  end;

 procedure Ini_Cmd_Win;
  begin
   Window(02,Z_CmdWin_Base + 4, 45, 23);
   TextBackground(Cyan);
   TextColor(Black);               {Setze Schriftfarbe}
   ClrScr;
  end;

 procedure Set_Cmd_Win;
  begin
   Window(02, Z_CmdWin_Base + 4, 45, 23);
   TextBackground(Cyan);
   TextColor(Black);               {Setze Schriftfarbe}
  end;

 procedure Ini_CmdList_Win;
  begin
   Window(S_CmdWin_Base, Z_CmdWin_Base, 79, 23);
   TextBackground(Cyan);
   TextColor(Black);               {Setze Schriftfarbe}
   ClrScr;
  end;

 procedure Clr_CmdList_Win;
  begin
   Window(S_CmdWin_Base, Z_CmdWin_Base, 79, 23);
   TextBackground(White);
   TextColor(Black);               {Setze Schriftfarbe}
   ClrScr;
  end;

 PROCEDURE Displ_Commands;
  Begin
     {Info-Anzeige Terminal-Commands}
      Ini_CmdList_Win; TextColor(Brown);
      Writeln('Befehls-Liste (Auszug):       '); TextColor(Black);
      Writeln('%     Baudraten anpassen      ');
      write  ('$*    Leerbefehl: Antwort ist U');
      writeln('$ab*  Rechnerbetrieb Ein      ');
      writeln('$/0*  Ref.Fahrt + Nullpos     ');
      writeln('$cc*  akt. Pos. in 1/100 mm   ');
      writeln('$dpx+000000* direkt Pos 0,01mm');
      writeln('$ai*  Pos erreicht 0=nein 1=ja');
      writeln('$cc*  akt. Pos. in 1/100 mm   ');
      writeln('$mm*  Normierungsdaten lesen  ');
      writeln('$vn*  Betriebssystem Version  ');
      writeln('$br*  kBaud:0=4.8;1=9.6;2=19.2');
      writeln('$vt*  Ventil Test ok= 000 ??  ');
{      writeln('$md*  Druckwerte              '); }
      writeln('$fa*  Fehleranzeige  [Z = ok] ');
      writeln('$fr*  Fehler Reset            ');

                                                 TextColor(Brown);
      writeln('Antwort auf Befehle:          '); TextColor(Black);
      writeln('Z   Befehl ok.                ');
      writeln('V   Fehlerfall                ');
      writeln('Y   Befehl aktuell unzulÑssig ');
      write  ('U   Befehl unbekannt          ');
  End; {Displ_Commands}

 PROCEDURE Displ_Response;
  Begin
     {Info-Anzeige Terminal-Commands}
      Ini_CmdList_Win;                           TextColor(Brown);
      writeln('Belegung Funktionstasten:     '); TextColor(Magenta);
      write  ('F1 :'); TextColor(Black);
      writeln    (' Li (Endanschlag - 3,0 mm)');
      writeln('F2 : Re (Endanschlag + 3,0 mm)');
      writeln('F3 : Ist-Position anzeigen    ');
      writeln('F4 : Referenz-Pos anfahren    '); TextColor(Magenta);

      write  ('F5 :');                           TextColor(Black);
      Writeln (' Lebenszeichen abfragen ');
      writeln('F6 :                         ');
      writeln('F7 : Li mechan. Endanschlag  ');
      writeln('F8 : Re mechan. Endanschlag  ');  TextColor(Magenta);

      write  ('F9 :');                           TextColor(Black);
      Writeln (' Normierungsdaten anzeigen');
      writeln('F10: Fehlernr auslesen Z = ok ');
      writeln('F11: Reset PC-Mil Karte       ');
      write  ('F12: Init Baudrate, Rechnerbetr');
      write  ('    + Referenzposition anfahren');;
                                                  TextColor(Brown);
      Writeln('Antwort-Kode der SPS:         ');  TextColor(Black);
      writeln('Z   Befehl ok.                ');
      writeln('V   Fehlerfall                ');
      writeln('Y   Befehl aktuell unzulÑssig ');
      write  ('U   Befehl unbekannt          ');
  End; {displ_ifc_stat}

 procedure Hinweis;
 const Hinw_Base = 5;
 begin
   Ini_Text_Win; TextColor(Brown);
   GotoXY(02, Hinw_Base);
   Write ('Achtung: Nach Powerup der SPS mÅssen 2 Kommandos an die SPS geschickt werden: ');
   GotoXY(05, Hinw_Base+2);
   Write ('1. ');  TextColor(Yellow); Write('$ab*'); TextColor(Brown);
   Write ('       Steuerung aktivieren bzw. Auf Rechner schalten');
   GotoXY(05, Hinw_Base+3);
   Write ('2. ');  TextColor(Yellow); Write('$/0*'); TextColor(Brown); Write ('       Referenzfahrt        ');
   GotoXY(05, Hinw_Base+5);
   Write ('Ohne diese Kommandos nimmt die SPS keine Befehle an!! ');

   GotoXY(01, Hinw_Base+10); TextColor(Blue);
   Writeln (' Im Terminal-Mode: ');
   Write   (' Mit dem Dummy-Befehl '); TextColor(Black); Write ('$*'); Textcolor(Blue);
   Write   (' und der korrekten SPS-Antwort '); TextColor(red); Write('U');   TextColor(Blue);
   Writeln (' kann man die ');
   Write   (' einwandfreie Kommunikation zur SPS ÅberprÅfen [Kabel, Baudrate, Powerup-Init]');
   Writeln; TextColor(Brown);
   Write   (' Falls ein Fahrfehler auftrat, schafft eine Referenzfahrt wieder');
   Write   (' klare VerhÑltnisse.');
   Ini_Msg_Win;
   Write ('Weiter mit <CR> ');
   Ch := NewReadKey;
   Ch := '?';
 end; {Hinweis}


procedure V24_Terminal;
 label 99;
 const Rcv_Fifo_Empty_Bitnr = 11;
       CursorY_Max = 22;
 var
  MilErr : TMilErr;
  Fct    : TFct;
  Wr_Data: Word;
  Rd_Data: Word;
  Rd_Zeichen : Char;
  CursorY_Act: Byte;

  function Mil_RcvChar (var Rd_Char: Char): Boolean;
   var Fifo_Data : Word;
       Ifc_Status: Word;
       Rd_Byte   : Byte;
   begin
    Mil_RcvChar := False;
    Fct.B.Fct   := Fct_Rd_Status;    {IFC-Status: Zustand des Rcv-Fifo testen}
    Mil.Rd (Ifc_Status, Fct, MilErr);
    if MilErr <> No_Err then Exit;
    if not BitTst (Ifc_Status, Rcv_Fifo_Empty_Bitnr) then
     begin                                                    {Fifo not empty}
       Fct.B.Fct   := Fct_Rd_Ist1;
       Mil.Rd (Fifo_Data, Fct, MilErr);               {Zeichen aus Fifo lesen}
       if MilErr <> No_Err then Exit;
       Rd_Byte     := Lo (Fifo_Data);

       Rd_Char     := Chr (Rd_Byte);
       Mil_RcvChar := True;
     end;
   end; {Mil_RcvChar}


 begin
    Hinweis;
    Ini_Text_Win;
    Fct.B.Adr := Ifc_Test_Nr;
    Cursor(False);
    Ini_Msg_Win;
    Write ('Keyboard-Eingabe ('); TextColor(Black); Write('sw'); TextColor(Yellow);
    Write(')'); Write(' -> V24;  V24-Input -> Display ('); TextColor (Red);
    Write ('rot'); TextColor(Yellow); Write (')      Abort Esc-Taste!');

    Displ_Commands;
    Set_Text_Win;
    GotoXY(01, 01);    {Cursor auf Anfang Display}
    TextColor(Yellow+128);
    Cursor(True);
    Write (chr(Cursor_Solid ));
    GotoXY(01, 01);    {Cursor auf Anfang Display}

    repeat
     if KeyEPressed then
      begin
       Cursor(False);
       TextColor(Black);
       Ch := NewReadKey;
       if Ch = #0 then                {Sonder-Tasten Abfrage}
        begin                         {ohne Auswirkung, da nicht belegt}
         Ch := NewReadKey;
        end;
      if Ch = chr(CarReturn)  then
       begin
       end
      else
       begin
         Write (Ch);                            {Zeichen zum PC-Display}
         Wr_Data := ord (Ch);
         Fct.B.Fct := Fct_Wr_Sw1;
         Mil.Wr (Wr_Data, Fct, MilErr);         {Zeichen zum Milbus}
       end; {if CarReturn}
      end; {if keypressed}

     while Mil_RcvChar (Rd_Zeichen) do         {Lese Daten aus Fifo bis empty}
      begin
        CursorY_Act:= WhereY;
        TextColor(Red);
        if (Rd_Zeichen = chr(CarReturn)) then
         begin
             if CursorY_Act = CursorY_Max then
              begin
                Clr_CmdList_Win;
                Set_Text_Win;
                GotoXY(50, 5); Write ('               ');  {Text lîschen}
                GotoXY(01, CursorY_Max);
                Writeln;
                GotoXY(50, 5); TextColor(Brown);
                Writeln ('Befehls-Liste: '); TextColor(Black);
                Displ_Commands;
                Set_Text_Win;
                GotoXY(01, CursorY_Max);
              end
             else
               Writeln; {(Rd_Zeichen); }
          end
        else
         begin
          if not (Rd_Zeichen = chr(LineFeed)) then     {Linefeed unterdrÅcken}
           begin
            Write (Rd_Zeichen);                  {Read-Zeichen auf Bildschirm}
            TextColor(Black);
           end; {IF NOT Linefeed}
         end;  {Rd_Zeichen = chr(CarReturn }
      end;
    until Ch = #27;
    Ch := '?';       {Wichtig: ESC-Zeichen lîschen!}
 99:  Cursor(True);
 end; {V24_Terminal }

procedure V24_Connector;
 const
  Z_Dip_Base = 3;
  Z_Pin_Base = 15;
  S_Dip_Base = 2;
  S_OffSet1  = 40;
  S_OffSet2  = 60;
  S_Pin_Base = 2;

 begin
  Ini_Text_Win; TextColor(Blue);
  GotoXY(S_Dip_Base, Z_Dip_Base-1); Write('Einstellung DIP-Schalter auf dem V24-Piggy ');
  Write('[8 Databits, 2 Stopbits, No Parity]');

  TextColor(Brown);
  GotoXY(S_Dip_Base, Z_Dip_Base+1); Write('8  7  6  5  4  3  2  1');
  GotoXY(S_Dip_Base, Z_Dip_Base+2); {1} Write(chr($FE),'  ');
                          {2} Write(chr($FE),'  ');
                          {3} Write(chr($FE),'  ');
                          {4} Write(chr($FE),'  ');
                          {5} Write(chr($FE),'  ');
                          {6} Write(chr($FE),'  ');
                          {7} Write(chr($FE),'  ');
                          {8} Write(chr($FE),'  '); Write(chr($2E)); {Punkt}
                              Write('  Off');

  GotoXY(S_Dip_Base, Z_Dip_Base+3); Writeln;
  GotoXY(S_Dip_Base, Z_Dip_Base+4);
                          {1} Write(chr($20),'  ');
                          {2} Write(chr($20),'  ');
                          {3} Write(chr($20),'  ');
                          {4} Write(chr($20),'  ');
                          {5} Write(chr($20),'  ');
                          {6} Write(chr($20),'  ');
                          {7} Write(chr($20),'  ');
                          {8} Write(chr($20),'  ');  Write(chr($1F)); {Pfeil}
                              Write('  On');

  TextColor(Brown);
  GotoXY(S_Dip_Base+S_OffSet1, Z_Dip_Base+1); Write('3  2  1');
  GotoXY(S_Dip_Base+S_OffSet1, Z_Dip_Base+2);
                          {3} Write(chr($FE),'  ');
                          {2} Write(chr($FE),'  ');
                          {1} Write(chr($20),'  ');

  GotoXY(S_Dip_Base+S_OffSet1, Z_Dip_Base+3); Writeln;
  GotoXY(S_Dip_Base+S_OffSet1, Z_Dip_Base+4);
                          {3} Write(chr($20),'  ');
                          {2} Write(chr($20),'  ');
                          {1} Write(chr($FE),'  ');

  GotoXY(S_Dip_Base+S_OffSet2, Z_Dip_Base+1); Write('3  2  1');
  GotoXY(S_Dip_Base+S_OffSet2, Z_Dip_Base+2);
                          {3} Write(chr($FE),'  ');
                          {2} Write(chr($20),'  ');
                          {1} Write(chr($20),'  ');

  GotoXY(S_Dip_Base+S_OffSet2, Z_Dip_Base+3); Writeln;
  GotoXY(S_Dip_Base+S_OffSet2, Z_Dip_Base+4);
                          {3} Write(chr($20),'  ');
                          {2} Write(chr($FE),'  ');
                          {1} Write(chr($FE),'  ');


  TextColor(Black);
  GotoXY(S_Dip_Base+ 5          , Z_Dip_Base+5); Write ('19,2 kBaud');
  TextColor(Yellow);
  GotoXY(S_Dip_Base+ S_OffSet1-1, Z_Dip_Base+5); Write (' 9,6 kBaud');
  TextColor(Black);
  GotoXY(S_Dip_Base+ S_OffSet2-1, Z_Dip_Base+5); Write (' 4,8 kBaud');



  GotoXY(S_Pin_Base+24, Z_Pin_Base-4); Write('v-- Kabel-Anpassung --v');

  TextColor(Brown);
  GotoXY(S_Pin_Base+0,  Z_Pin_Base-2); Write('MIL-V24-Piggy');
  GotoXY(S_Pin_Base+21, Z_Pin_Base-3); Write('Hier wahlweise V24-Piggy oder');
  GotoXY(S_Pin_Base+19, Z_Pin_Base-2); Write('Kabel 1:1 von PC Com1 anschlie·en');
  GotoXY(S_Pin_Base+61, Z_Pin_Base-2); Write('SPS MC04');


  GotoXY(S_Pin_Base+5,  Z_Pin_Base-1); Write(chr($1F));
  GotoXY(S_Pin_Base+35, Z_Pin_Base-1); Write(chr($1F));
  GotoXY(S_Pin_Base+65, Z_Pin_Base-1); Write(chr($1F));
  TextColor(Black);
  GotoXY(S_Pin_Base+0,  Z_Pin_Base+0); Write('RCV  2 o--------------------');
  GotoXY(S_Pin_Base+30, Z_Pin_Base+0); Write('RCV  2 o--------------------');
  GotoXY(S_Pin_Base+60, Z_Pin_Base+0); Write('-<-o 2 TRM');

  GotoXY(S_Pin_Base+0,  Z_Pin_Base+1); Write('TRM  3 o--------------------');
  GotoXY(S_Pin_Base+30, Z_Pin_Base+1); Write('TRM  3 o--------------------');
  GotoXY(S_Pin_Base+60, Z_Pin_Base+1); Write('->-o 3 RCV');

  GotoXY(S_Pin_Base+0,  Z_Pin_Base+2); Write('DSR 20 o--------------------');
  GotoXY(S_Pin_Base+30, Z_Pin_Base+2); Write('DSR  6 o--'); Write(chr($C2)); Write('-----------------');
  GotoXY(S_Pin_Base+60, Z_Pin_Base+2); Write('-<-o 4 RTS');

  GotoXY(S_Pin_Base+0,  Z_Pin_Base+3); Write('                            ');
  GotoXY(S_Pin_Base+30, Z_Pin_Base+3); Write('     8 o--'); Write(chr($D9));
  GotoXY(S_Pin_Base+60, Z_Pin_Base+3); Write('');

  GotoXY(S_Pin_Base+0,  Z_Pin_Base+4); Write('DTR  6 o--------------------');
  GotoXY(S_Pin_Base+30, Z_Pin_Base+4); Write('DTR  4 o--------------------');
  GotoXY(S_Pin_Base+60, Z_Pin_Base+4); Write('->-o 5 CTS');

  GotoXY(S_Pin_Base+0,  Z_Pin_Base+5); Write('GND  7 o--------------------');
  GotoXY(S_Pin_Base+30, Z_Pin_Base+5); Write('GND  5 o--------------------');
  GotoXY(S_Pin_Base+60, Z_Pin_Base+5); Write('---o 7 GND');
  TextColor(Blue);
  GotoXY(S_Pin_Base+5,  Z_Pin_Base+6); Write('25-pol Buchse');
  GotoXY(S_Pin_Base+35, Z_Pin_Base+6); Write('9-pol Buchse             9-pol Buchse');

  Ini_Msg_Win;
  Write ('Weiter mit <CR>  ');

  repeat
   if KeyEPressed then Ch := NewReadKey;
  until Ch = #13;
  Ch := '?';
 end; {V24_Connector}


procedure VT320_Kabel;
 const
  Z_Dip_Base = 3;
  Z_Pin_Base = 10;
  S_Dip_Base = 2;
  S_OffSet1  = 40;
  S_OffSet2  = 60;
  S_Pin_Base = 2;

 begin
  Ini_Text_Win; TextColor(Brown);
  GotoXY(S_Dip_Base+20, Z_Dip_Base-1);
  Writeln('Einstellung DEC-Terminal VT320:'); TextColor(Blue);
  Write  (' 9600 Baud, 2 Stopbits, 8 Databits, No Parity, Local Echo, ');
  Write  ('RS232 DataLeads only');

  TextColor(Brown);
  GotoXY(S_Pin_Base+0,  Z_Pin_Base-2); Write('DEC VT320');
  GotoXY(S_Pin_Base+61, Z_Pin_Base-2); Write('SPS MC04');
  GotoXY(S_Pin_Base+5,  Z_Pin_Base-1); Write(chr($1F));
  GotoXY(S_Pin_Base+65, Z_Pin_Base-1); Write(chr($1F));

  TextColor(Black);
  GotoXY(S_Pin_Base+0,  Z_Pin_Base+0); Write('RCV  3 o----------------------');
  GotoXY(S_Pin_Base+30, Z_Pin_Base+0); Write('------------------------------');
  GotoXY(S_Pin_Base+60, Z_Pin_Base+0); Write('-<-o 2 TRM');

  GotoXY(S_Pin_Base+0,  Z_Pin_Base+1); Write('TRM  2 o----------------------');
  GotoXY(S_Pin_Base+30, Z_Pin_Base+1); Write('------------------------------');
  GotoXY(S_Pin_Base+60, Z_Pin_Base+1); Write('->-o 3 RCV');

  GotoXY(S_Pin_Base+0,  Z_Pin_Base+2); Write('CTS  5 o--'); Write(chr($C2));  Write('--------------------');
  GotoXY(S_Pin_Base+30, Z_Pin_Base+2); Write('------------------------------');
  GotoXY(S_Pin_Base+60, Z_Pin_Base+2); Write('-<-o 4 RTS');

  GotoXY(S_Pin_Base+0,  Z_Pin_Base+3); Write('DSR  6 o--'); Write(chr($D9));

  GotoXY(S_Pin_Base+0,  Z_Pin_Base+4); Write('DTR 20 o----------------------');
  GotoXY(S_Pin_Base+30, Z_Pin_Base+4); Write('------------------------------');
  GotoXY(S_Pin_Base+60, Z_Pin_Base+4); Write('->-o 5 CTS');

  GotoXY(S_Pin_Base+0,  Z_Pin_Base+5); Write('GND  7 o----------------------');
  GotoXY(S_Pin_Base+30, Z_Pin_Base+5); Write('------------------------------');
  GotoXY(S_Pin_Base+60, Z_Pin_Base+5); Write('---o 7 GND');

  TextColor(Blue);
  GotoXY(S_Pin_Base+10, Z_Pin_Base+6); Write('<-- 25-polig Buchse');
  Write('----  Kabel ---- ');
  Write('9-polig Pin -->');

  Ini_Msg_Win;
  Write ('Weiter mit <CR>  ');

  repeat
   if KeyEPressed then Ch := NewReadKey;
  until Ch = #13;
  Ch := '?';
 end; {VT320_Kabel}


procedure Normierung;
  label 99;
  const
   Rcv_Fifo_Empty_Bitnr = 11;

   S_Text       = 02;
   S_Ist        = S_Text+31;
   S_Soll       = S_Ist +13;

   Z_Max        = 10;
   Z_Achse      = 05;
   Z_RfrzRicht  = Z_Achse+1;
   Z_Speed      = Z_RfrzRicht+1;
   Z_Beschl     = Z_Speed+1;
   Z_Toleranz   = Z_Beschl+1;
   Z_Hub        = Z_Toleranz+1;
   Z_Aufloes    = Z_Hub+1;
   Z_SoftEnd_Li = Z_Aufloes+1;
   Z_SoftEnd_Re = Z_SoftEnd_Li+1;
   Z_RefNullPkt = Z_SoftEnd_Re+1;

  type
   TCmdStr   = String [80];
   TNorm_Str = String [33];
   TDispl_Mode = (Normal, Clear);

  var
   MilErr : TMilErr;
   Fct    : TFct;
   Wr_Data: Word;
   Rd_Data: Word;
   N,I,X  : Integer;
   Cmd    : TCmdStr;
   Wait_Send: LongInt;
   User_Int : Integer;
   Line_Count : Integer;
   Cmd_Win_X  : Byte;
   Cmd_Win_Y  : Byte;

   Default_Str: TNorm_Str;
   Soll_Str   : TNorm_Str;
   Ist_Str    : TNorm_Str;
   Ask_Str    : TAsk_String;
   User_Str   : Str80;
   Life_Mode  : TLife_XY;

 procedure Norm_Msg;
  begin
    Ini_Msg_Win;
    Write ('Lesen Normierungsdaten von SPS mit <Space>                Abort mit Taste <Esc>');
  end;

 function Mil_RcvChar (var Rd_Char: Char): Boolean;
  var Fifo_Data : Word;
      Ifc_Status: Word;
      Rd_Byte   : Byte;
   begin
    Mil_RcvChar := False;
    Fct.B.Fct   := Fct_Rd_Status;    {IFC-Status: Zustand des Rcv-Fifo testen}
    Mil.Rd (Ifc_Status, Fct, MilErr);
    if MilErr <> No_Err then Exit;
    if not BitTst (Ifc_Status, Rcv_Fifo_Empty_Bitnr) then
     begin                                                    {Fifo not empty}
       Fct.B.Fct   := Fct_Rd_Ist1;
       Mil.Rd (Fifo_Data, Fct, MilErr);           {Zeichen aus V24-Fifo lesen}
       if MilErr <> No_Err then Exit;
       Rd_Byte     := Lo (Fifo_Data);
       Rd_Char     := chr(Rd_Byte);
       Mil_RcvChar := True;
     end;
   end; {Mil_RcvChar}

 procedure Send_Norm_String (var CmdStr: TCmdStr);
  var Num_Char : Byte;
      Z        : Byte;
      Write_Data: Word;
  begin
   Fct.B.Fct := Fct_Wr_Sw1;
   Num_Char  := Byte(CmdStr[0]);
   if Num_Char > 0 then
    begin
     for Z:=1 to Num_Char do
      begin
       Write_Data := ord (CmdStr[Z]);
       Mil.Wr (Write_Data, Fct, MilErr);         {Zeichen zum Milbus}
       Mil.Timer2_Wait(Wait_Send*100);
      end;
    end; {if}
  end; {Send_Cmd_String}


 procedure Displ_Norm_Str (var Norm_Str: TNorm_Str; Spalte: Byte; Mode: TDispl_Mode);
  var Str2 : string[2];
      Str7 : string[7];
      I    : Byte;
  begin
    Set_Text_Win;
    if Mode = Clear then      {Spalte lîschen}
     begin
      for I := 0 to 10 do
       begin
         GotoXY(Spalte-1, Z_Achse + I); Write ('        ');
       end; {for}
      Exit;
     end; {if Mode=Clear}

    Str2 := '  ';
    Str7 := '       '; {Init String auf LÑnge 7}
    Set_Text_Win;
    GotoXY(Spalte, Z_Achse);
    case Norm_Str[1]  of
     '+' : Write ('+');
     '-' : Write ('-');
    else
     Write('?');
    end;

    GotoXY(Spalte, Z_RfrzRicht);
    case Norm_Str[2]  of
     '-' : Write ('pos.');
     '0' : Write ('neg.');
    else
     Write('???');
    end;
    GotoXY(Spalte, Z_Speed);  Write (Norm_Str[3]); Write (Norm_Str[4]); Write (Norm_Str[5]);
    GotoXY(Spalte, Z_Beschl); Write (Norm_Str[6]); Write (Norm_Str[7]);
    GotoXY(Spalte, Z_Toleranz );
    case Norm_Str [9] of
     '1' : Write ('0,01');
     '2' : Write ('0,02');
     '3' : Write ('0,05');
     '4' : Write ('0,10');
     '5' : Write ('0,20');
     '6' : Write ('0,05');
     '7' : Write ('1,00');
     '8' : Write ('2,00');
     '9' : Write ('5,00');
    end;

    Str2[1] := Norm_Str [10]; Str2[2] := Norm_Str [11];
    GotoXY(Spalte-2, Z_Hub);
    if Str2 = '00' then Write ('< 100');
    if Str2 = '01' then Write ('  100');
    if Str2 = '02' then Write ('  200');
    if Str2 = '03' then Write ('  300');
    if Str2 = '04' then Write ('  400');
    if Str2 = '05' then Write ('  500');
    if Str2 = '06' then Write ('  600');
    if Str2 = '07' then Write ('  700');
    if Str2 = '08' then Write ('  800');
    if Str2 = '09' then Write ('  900');
    if Str2 = '10' then Write (' 1000');
    if Str2 = '11' then Write (' 1100');
    if Str2 = '12' then Write (' 1200');
    if Str2 = '13' then Write (' 1300');
    if Str2 = '14' then Write (' 1400');
    if Str2 = '15' then Write (' 1500');

    GotoXY(Spalte, Z_Aufloes);
    case Norm_Str [12] of
     '0' : Write ('0,005');
     '1' : Write ('0,010');
    else
     Write ('?,???');
    end;

    GotoXY(Spalte-1, Z_SoftEnd_Li);
    for I := 1 to 7 do Str7[I] := Norm_Str [12+I];
    Write (Str7);
    GotoXY(Spalte-1, Z_SoftEnd_Re);
    for I := 1 to 7 do
     Str7[I] := Norm_Str [19+I];
    Write (Str7);
    GotoXY(Spalte-1, Z_RefNullPkt);
    for I := 1 to 7 do
     Str7[I] := Norm_Str [26+I];
    Write (Str7);
  end; {Displ_Norm_Str}


 function Read_NormParam (var Rd_Str: TNorm_Str): Boolean;
  const Max_Num_NormChar = 33;
  var I : Byte;
      Response_Str : TCmdStr;
      Rd_Zeichen   : Char;
  begin
    Mil.Reset;          {Fifo lîschen}
    Read_NormParam := False;
    Rd_Str [0]     := chr(0);  {Anzahl Zeichen default}
    Cmd := Cmd_Norm;
    Send_Norm_String (Cmd);
    Mil.Timer2_wait (10000);   {Wegen Baudrate warten}

              {1. Zeichen ist immer ein Linefeed #10}
    I:= 0;          {Lese inklusive CarriageReturn + Linefeed am Ende}
    while Mil_RcvChar(Rd_Zeichen) and (Rd_Zeichen <> chr(CarReturn) {(#13)} ) do
     begin
        if not (Rd_Zeichen = chr(LineFeed)  {#10}) or (Rd_Zeichen = chr(CarReturn)   {#13}) then
         begin                                 {CR oder LF nicht abspeichern}
          I := I+1;
          Response_Str [I] := Rd_Zeichen;
         end;
     end; {while}

    If I = Max_Num_NormChar then
     begin
      for I := 1 to Max_Num_NormChar do Rd_Str[I] := Response_Str [I]; {Kopieren}
      Read_NormParam := True;
      Rd_Str [0]     := chr(Max_Num_NormChar);         {#33;}
     end;
  end; {Read_NormParam}

 procedure Set_Marker (Zeile : Byte);           {Markiert FTasten-Eingabe}
  var Z : Byte;
  begin                                         {Immer Spalte 1}
   Set_Text_Win;
   for Z := Z_Achse to (Z_Achse+ Z_Max-1) do    {alle Marker lîschen}
     begin GotoXY(01,Z); Write (' '); end;
   if Zeile > 0 then
    begin
      TextColor(Yellow);
      GotoXY(01,Zeile); Write ('>');
    end;
  end;  {Set_Marker}


 begin          {Programm Normierung}
    Life_Mode.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
    Life_Mode.PosX    := S_Ist+2 ;
    Life_Mode.PosY    := Z_Achse-3 ;
    Life_Mode.Time    := Life_Time_Fast;
    Life_Mode.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}

    Hinweis;
    Default_Str := Default_Norm;
    Soll_Str    := Default_Str;

    Fct.B.Adr   := Ifc_Test_Nr;
    Ini_Text_Win;
    GotoXY(S_NormTxt_WinBase, 01);
    TextColor(Blue); Write ('F-Tasten Legende:');

    GotoXY(02,  Z_Achse-2);       Write ('Normierungsdaten ');
    GotoXY(S_Ist -2,  Z_Achse-2); Write ('-- Ist --');
    GotoXY(S_Soll-2, Z_Achse-2);  Write ('-- Soll --');
    TextColor(Brown);
    GotoXY(S_Text, Z_Achse);      Write ('Achs-Orientierung     [+/-]: ');
    GotoXY(S_Text, Z_RfrzRicht ); Write ('Ref. Fahrichtg +/- Anschlag: ');
    GotoXY(S_Text, Z_Speed  );    Write ('Geschwindigkeit   [0.01m/s]: ');
    GotoXY(S_Text, Z_Beschl);     Write ('Max. Beschleunigung     [g]: ');
    GotoXY(S_Text, Z_Toleranz );  Write ('Standard Toleranz      [mm]: ');
    GotoXY(S_Text, Z_Hub  );      Write ('Nennhub Klasse         [mm]: ');
    GotoXY(S_Text, Z_Aufloes);    Write ('Messystem Auflîsung    [mm]: ');
    GotoXY(S_Text, Z_SoftEnd_Li); Write ('SoftwareEndlage Li [0.01mm]: ');
    GotoXY(S_Text, Z_SoftEnd_Re); Write ('SoftwareEndlage Re [0.01mm]: ');
    GotoXY(S_Text, Z_RefNullPkt); Write ('Referenz Nullpunkt [0.01mm]: ');

    Ini_FTast_Norm_Win;
    Set_FTast_Norm_Win;
    GotoXY(01,01); Write ('F1: Achse   F5: Refernz Richtng  F9 : Toleranz    ');
    GotoXY(01,02); Write ('F2: Hub     F6: Refernz NulPnkt  F10: Auflîsung   ');
    GotoXY(01,03); Write ('F3: Speed   F7: SoftEndlage li   F11: Sollw=Default');
    GotoXY(01,04); Write ('F4: Beschl  F8: SoftEndlage re   F12: Sollw Senden');
    Set_Text_Win;
    TextColor(Brown);
    GotoXY(S_FTastNorm_Win, Z_FTastNorm_Win-3);
    Write ('Sollwert verÑndern mit Funktionstasten: ');
    FTast_NormText_Win;
    Displ_Norm_Str (Soll_Str, S_Soll, Normal);

    Cursor(False);
    Norm_Msg;

    repeat
     if KeyEPressed then
      begin
         Ch:= NewReadKey;
         if Ch = ' ' then
          begin
           Norm_Msg;
           Life_Sign_XY (Life_Mode);
           if Read_NormParam (Ist_Str) then Displ_Norm_Str (Ist_Str, S_Ist, Normal)
           else
             begin
              Displ_Norm_Str (Ist_Str, S_Ist, Clear);
              Ini_Err_Win;
              Write('ERROR: Mil Lesefehler!!     Weiter mit  <CR> ');
              Ch := NewReadKey;
              Ch := '?';
              Norm_Msg;
             end;
          end;

         if Ch = #0 then                  {Sonder-Tasten Abfrage}
          begin
           Ch := NewReadKey;
           case ord (Ch) of
            Taste_F1 : begin
                         Set_Marker (Z_Achse);
                         FTast_NormText_Win;
                         Write ('Die Achsorientierung ist ');
                         Write ('standardmÑ·ig negativ u. ');
                         Write ('kann hier nicht geÑndert ');
                         Write ('werden. Falls doch nîtig:');
                         Write ('dann direkt Åber Terminal');
                         Write ('eingeben und entsprechend');
                         Write ('Vorzeichen bei Positions-');
                         Write ('angaben beachten!!       ');
                         Writeln;
                         Write ('Durch die Festlegung auf ');
                         Write ('  "negativ" kînnen alle  ');
                         Write ('Positionsangaben als pos.');
                         Write ('    Werte erfolgen.      ');
                         Set_Marker (0);
                         Norm_Msg;
                       end;
            Taste_F2 : begin
                         Set_Marker (Z_Hub);
                         FTast_NormText_Win;
                         Write ('Die Nennhubklasse reicht ');
                         Write ('von <100 mm bis 1500 mm. ');
                         Write ('                         ');
                         Write ('Tastatur-Eingabe:        ');
                         Write ('0   -> kleiner 100 mmm   ');
                         Write ('1   ->  100 mm           ');
                         Write ('2   ->  200 mm           ');
                         Write ('3   ->  300 mmm          ');
                         Write ('4   ->  400 mmm          ');
                         Write ('5   ->  500 mmm          ');
                         Write ('6   ->  600 mmm          ');
                         Write ('7   ->  700 mmm          ');
                         Write ('8   ->  800 mmm          ');
                         Write ('9   ->  900 mmm          ');
                         Write ('10  -> 1000 mmm          ');
                         Write ('11  -> 1100 mmm          ');
                         Write ('12  -> 1200 mmm          ');
                         Write ('13  -> 1300 mmm          ');
                         Write ('14  -> 1400 mmm          ');
                         Write ('15  -> 1500 mmm  ');

                         Ask_Str := 'Hubklasse  0..15  eingeben ';
                         if Ask_String_Break (Ask_Str, User_Str) then
                          begin
                            I := Byte (User_Str[0]);
                            if I in [1..2] then
                              begin
                                Soll_Str[10] := '0';  Soll_Str[11] := '0';
                                X := 1;
                                for N := I downto 1 do
                                 begin
                                   Soll_Str[12-N] := User_Str[X];
                                   X := X +1;
                                 end;
                              end;
                            Displ_Norm_Str (Soll_Str, S_Soll, Normal);
                          end;
                         Set_Marker(0);
                         Norm_Msg;
                       end;
            Taste_F3 : begin
                         Set_Marker (Z_Speed);
                         FTast_NormText_Win;
                         Write ('Die max. Geschwindigkeit ');
                         Write ('reicht von 0,01 bis 4 m/s');
                         Writeln;
                         Write ('Tastatur-Eingabe:        ');
                         Write ('       1 .... 400        ');
                         Ask_Str := 'Geschwindigkeit 1..400 eingeben ';
                         if Ask_String_Break (Ask_Str, User_Str) then
                          begin
                            I := Byte (User_Str[0]);
                            if I in [1..3] then
                              begin
                                Soll_Str[3] := '0';  Soll_Str[4] := '0'; Soll_Str[5] := '0';
                                X := 1;
                                for N := I downto 1 do
                                 begin
                                   Soll_Str[6-N] := User_Str[X];
                                   X := X +1;
                                 end;
                              end;
                            Displ_Norm_Str (Soll_Str, S_Soll, Normal);
                          end;
                        Set_Marker(0);
                        Norm_Msg;
                       end;
            Taste_F4 : begin
                         Set_Marker(Z_Beschl);
                         FTast_NormText_Win;
                         Write ('Die max. Beschleunigung  ');
                         Write ('ist von 1 g bis 10 g     ');
                         Writeln;
                         Write ('Tastatur-Eingabe: 1 .. 10');
                         Ask_Str := 'Beschleunigung 1..10 eingeben ';
                         if Ask_String_Break (Ask_Str, User_Str) then
                          begin
                            I := Byte (User_Str[0]);
                            if I in [1..2] then
                              begin
                                Soll_Str[6] := '0';  Soll_Str[7] := '0';
                                X := 1;
                                for N := I downto 1 do
                                 begin
                                   Soll_Str[8-N] := User_Str[X];
                                   X := X +1;
                                 end;
                              end;
                            Displ_Norm_Str (Soll_Str, S_Soll, Normal);
                           end;
                         Norm_Msg;
                       end;
            Taste_F5 : begin
                         Set_Marker (Z_RfrzRicht);
                         FTast_NormText_Win;
                         Write ('Die Referenzfahrrichtung ');
                         Write ('zÑhlt standardmÑ·ig vom  ');
                         Write ('negativen Anschlag aus   ');
                         Write ('[schwarzer Plastikklotz  ');
                         Write ('bzw. rechter mechanischer');
                         Write ('Anschlag] u. kann hier   ');
                         Write ('nicht verÑndert werden!  ');
                         Writeln;
                         Write ('Falls nîtig mit Terminal-');
                         Write ('Programm direkt eingeben.');

                         Ask_Str := 'Richtung vom -/+ Anschlag eingeben ';
                         if Ask_String_Break (Ask_Str, User_Str) then
                          begin
                            if User_Str [1] = '+' then Soll_Str[2] := '-';
                            if User_Str [1] = '-' then Soll_Str[2] := '0';
                            Displ_Norm_Str (Soll_Str, S_Soll, Normal);
                          end;
                         Set_Marker(0);
                         Norm_Msg;
                       end;
            Taste_F6 : begin
                         Set_Marker(Z_RefNullPkt);
                         FTast_NormText_Win;
                         Write ('Der Referenz Nullpunkt   ');
                         Write ('liegt standardmÑ·ig bei  ');
                         Write ('+000000 d.h. am rechten  ');
                         Write ('mechan. Endanschlag      ');
                         Write (' [Endlagenschalter bzw.  ');
                         Write (' schwarzer Plastikklotz].');
                         Write ('  Eingabe in 0.01 mm     ');
                         Write ('Das Vorzeichen ist immer ');
                         Write ('positiv; kann hier nicht ');
                         Write ('geÑndert werden. Falls   ');
                         Write ('doch nîtig: direkt Åber  ');
                         Write ('Terminal eingeben!!      ');
                         Write ('Nach Powerup mu· erst die');
                         Write ('Referenz-Fahrt ausgefÅhrt');
                         Write ('werden: automatisch wird ');
                         Write ('mit 1/10 der eingestellt ');
                         Write ('Speed bis zum re mechan. ');
                         Write ('Anschlag gefahren        ');
                         Write ('= allgemeiner Bezugspunkt');

                         Ask_Str := 'Bitte Zahl mit max. 6 Stellen eingeben ';
                         if Ask_String_Break (Ask_Str, User_Str) then
                          begin
                            I := Byte (User_Str[0]);
                            if I in [1..6] then
                              begin
                                Soll_Str[28]:='0';  Soll_Str[29]:='0';  {alte werte lîschen}
                                Soll_Str[30]:='0';  Soll_Str[31]:='0';
                                Soll_Str[32]:='0';  Soll_Str[33]:='0';

                                X := 1;
                                for N := I downto 1 do
                                 begin
                                   Soll_Str[34-N] := User_Str[X];
                                   X := X +1;
                                 end;
                              end;
                            Displ_Norm_Str (Soll_Str, S_Soll, Normal);
                          end;
                         Set_Marker(0);
                         Norm_Msg;
                        end;
            Taste_F7 : begin
                         Set_Marker(Z_SoftEnd_Li);
                         FTast_NormText_Win;
                         Write ('Die SoftwareEndlage links');
                         Write ('definiert Distanz vom    ');
                         Write ('Referenz-Nullpunkt       ');
                         Write ('[Strecke von rechtem     ');
                         Write ('mechan. Anschlag bzw.    ');
                         Write ('schwarzem Plastikklotz]. ');
                         Write ('  Eingabe in 0.01 mm     ');
                         Write ('Das Vorzeichen ist immer ');
                         Write ('positiv; kann hier nicht ');
                         Write ('geÑndert werden.         ');
                         Write ('Die SoftEndlage li legt  ');
                         Write ('max. Wert fÅr das Fahren ');
                         Write ('nach links fest (-> dpx).');
                         Write ('Positionen grî·er diesem ');
                         Write ('Wert werden ignoriert.   ');
                         Ask_Str := 'Bitte Zahl mit max. 6 Stellen eingeben ';
                         if Ask_String_Break (Ask_Str, User_Str) then
                          begin
                            I := Byte (User_Str[0]);
                            if I in [1..6] then
                              begin
                                Soll_Str[14]:='0';  Soll_Str[15]:='0';  {alte werte lîschen}
                                Soll_Str[16]:='0';  Soll_Str[17]:='0';
                                Soll_Str[18]:='0';  Soll_Str[19]:='0';

                                X := 1;
                                for N := I downto 1 do
                                 begin
                                   Soll_Str[20-N] := User_Str[X];
                                   X := X +1;
                                 end;
                              end;
                            Displ_Norm_Str (Soll_Str, S_Soll, Normal);
                          end;
                         Set_Marker(0);
                         Norm_Msg;
                        end;
            Taste_F8 : begin
                         Set_Marker(Z_SoftEnd_Re);
                         FTast_NormText_Win;
                         Write ('Die SoftwarEndlage rechts');
                         Write ('definiert Distanz vom    ');
                         Write ('Referenz-Nullpunkt       ');
                         Write ('[Strecke von rechtem     ');
                         Write ('mechan. Anschlag bzw.    ');
                         Write ('schwarzem Plastikklotz]. ');
                         Write ('  Eingabe in 0.01 mm     ');
                         Write ('Das Vorzeichen ist immer ');
                         Write ('positiv; kann hier nicht ');
                         Write ('geÑndert werden.         ');
                         Write ('Die SoftEndlage re legt  ');
                         Write ('max. Wert fÅr das Fahren ');
                         Write ('nach rechts fest (->dpx).');
                         Write ('Positionen kleiner diesem');
                         Write ('Wert werden ignoriert.   ');
                         Writeln;
                         Write ('Die SoftwEndlage re wird ');
                         Write ('automatisch nach einer   ');
                         Write ('Referenzfahrt eingestellt');

                         Ask_Str := 'Bitte Zahl mit max. 6 Stellen eingeben ';
                         if Ask_String_Break (Ask_Str, User_Str) then
                          begin
                            I := Byte (User_Str[0]);
                            if I in [1..6] then
                              begin
                                Soll_Str[21]:='0';  Soll_Str[22]:='0';  {alte werte lîschen}
                                Soll_Str[23]:='0';  Soll_Str[24]:='0';
                                Soll_Str[25]:='0';  Soll_Str[26]:='0';

                                X := 1;
                                for N := I downto 1 do
                                 begin
                                   Soll_Str[27-N] := User_Str[X];
                                   X := X +1;
                                 end;
                              end;
                            Displ_Norm_Str (Soll_Str, S_Soll, Normal);
                          end;
                         Set_Marker(0);
                         Norm_Msg;
                        end;

            Taste_F9 : begin
                         Set_Marker(Z_Toleranz);
                         FTast_NormText_Win;
                         Write ('Die Standard Toleranz    ');
                         Write ('reicht von 0,01 mm bis   ');
                         Write ('5,00 mm                  ');
                         Writeln;
                         Write ('Tastatur-Eingabe:        ');
                         Write ('1   -> 0,01 mmm          ');
                         Write ('2   -> 0,02 mmm          ');
                         Write ('3   -> 0,05 mmm          ');
                         Write ('4   -> 0,10 mmm          ');
                         Write ('5   -> 0,20 mmm          ');
                         Write ('6   -> 0,50 mmm          ');
                         Write ('7   -> 1,00 mmm          ');
                         Write ('8   -> 2,00 mmm          ');
                         Write ('9   -> 5,00 mmm          ');
                         Ask_Str := 'Bitte Dezimal-Zahl 1..9 eingeben ';
                         if Ask_String_Break (Ask_Str, User_Str) then
                          begin
                            if User_Str[1] in ['1'..'9'] then
                            Soll_Str[9] := User_Str[1];
                            Displ_Norm_Str (Soll_Str, S_Soll, Normal);
                          end;
                         Set_Marker(0);
                         Norm_Msg;
                       end;
            Taste_F10: begin
                         Set_Marker(Z_Aufloes);
                         FTast_NormText_Win;
                         Write ('Die Me·system-Auflîsung  ');
                         Write ('bietet nur zwei Werte:   ');
                         Write ('0,005 mm und 0,010 mm    ');
                         writeln;
                         Write ('Tastatur-Eingabe:        ');
                         Write ('0   -> 0,005 mm          ');
                         Write ('1   -> 0,010 mm          ');
                         Ask_Str := 'Eingeben 0 fÅr [0,005 mm] oder 1 fÅr [0,010 mm] ';
                         if Ask_String_Break (Ask_Str, User_Str) then
                          begin
                            if User_Str [1] = '0' then Soll_Str[12] := '0';
                            if User_Str [1] = '1' then Soll_Str[12] := '1';
                            Displ_Norm_Str (Soll_Str, S_Soll, Normal);
                          end;
                         Set_Marker(0);
                         Norm_Msg;
                        end;
            Taste_F11: begin
                         Soll_Str := Default_Str;
                         Displ_Norm_Str (Soll_Str, S_Soll, Normal);
                       end;
            Taste_F12: begin
                         Ini_Err_Win;
                         Write('Achtung: aktuelle Normierungsparamter wirklich Åberschreiben? [J/N<CR>]: ');
                         Ch := NewReadkey;
                         if Ch in ['j','J'] then
                           begin
                            Cmd := Cmd_Anfang;    Send_Norm_String (Cmd);
                            Cmd := Cmd_NormWrite; Send_Norm_String (Cmd);

                            Cmd := Soll_Str;      Send_Norm_String (Cmd);
                            Cmd := Cmd_Ende;      Send_Norm_String (Cmd);
                           end;
                         {Clear Istwert-Anzeige}
                         Life_Mode.PosX    := S_Soll+2 ;
                         Life_Sign_XY (Life_Mode);
                         Life_Mode.PosX    := S_Ist+2 ;
                         Norm_Msg;
                       end;
          end;  {Case}
       end;
     end; {if Keypressed}
   until Ch = #27;
   Ch := '?';       {Wichtig: ESC-Zeichen lîschen!}
 99:  Cursor(True);
 end; {Norm}


procedure FTast_Cmd;
  label 99;
  const Rcv_Fifo_Empty_Bitnr = 11;

  type TCmdStr = String[80];

  var
   MilErr : TMilErr;
   Fct    : TFct;
   Wr_Data: Word;
   Rd_Data: Word;
   N      : Integer;
   Cmd    : TCmdStr;
   Wait_Send: LongInt;
   User_Int : Integer;
   Line_Count : Integer;
   Cmd_Win_X  : Byte;
   Cmd_Win_Y  : Byte;

 function Mil_RcvChar (var Rd_Char: Char): Boolean;
  var Fifo_Data : Word;
      Ifc_Status: Word;
      Rd_Byte   : Byte;
   begin
    Mil_RcvChar := False;
    Fct.B.Fct   := Fct_Rd_Status;    {IFC-Status: Zustand des Rcv-Fifo testen}
    Mil.Rd (Ifc_Status, Fct, MilErr);
    if MilErr <> No_Err then Exit;
    if not BitTst (Ifc_Status, Rcv_Fifo_Empty_Bitnr) then
     begin                                                    {Fifo not empty}
       Fct.B.Fct   := Fct_Rd_Ist1;
       Mil.Rd (Fifo_Data, Fct, MilErr);               {Zeichen aus Fifo lesen}
       if MilErr <> No_Err then Exit;
       Rd_Byte     := Lo (Fifo_Data);
       Rd_Char     := chr(Rd_Byte);
       Mil_RcvChar := True;
     end;
   end; {Mil_RcvChar}


 procedure Send_Cmd_String (var CmdStr: TCmdStr);
  var Num_Char : Byte;
      Z        : Byte;
      Write_Data: Word;
  begin
   Set_Cmd_Win;
   GotoXY(Cmd_Win_X, Cmd_Win_Y);  Write(CmdStr);
   Cmd_Win_X := WhereX;
   Cmd_Win_Y := WhereY;

   Fct.B.Fct := Fct_Wr_Sw1;
   Num_Char  := Byte(CmdStr[0]);
   if Num_Char > 0 then
    begin
     for Z:=1 to Num_Char do
      begin
       Write_Data := ord (CmdStr[Z]);
       Mil.Wr (Write_Data, Fct, MilErr);         {Zeichen zum Milbus}
       Mil.Timer2_Wait(Wait_Send*100);
      end;
    end; {if}
  end; {Send_Cmd_String}

 procedure Read_Rcv_Fifo;
  var Rd_Zeichen : Char;
  begin
   if Mil_RcvChar (Rd_Zeichen) then           {Lese Daten aus Fifo bis empty}
    begin
      Set_Cmd_Win;
      GotoXY(Cmd_Win_X, Cmd_Win_Y);
      TextColor(Red);
      Write (Rd_Zeichen);                       {Read-Zeichen auf Bildschirm}
      Cmd_Win_X := WhereX;
      Cmd_Win_Y := WhereY;
    end;
  end; {Read_Rcv_Fifo}

 const
  S_Wait = 20;
  Z_Wait = 03;

 procedure Show_Wait_Send;
  begin
    Set_Text_Win; TextColor(Black);
    GotoXY(S_Wait+40, Z_Wait); Write(Wait_Send:4);
  end;

 procedure Referenz_Powerup; {Nach einem Powerup der SPS geht eine Referenz-
                              fahrt nur mit nachfolgender Kommandofolge }
  begin
    Cmd := Cmd_Anfang;
    Send_Cmd_String (Cmd);
    Mil.Timer2_Wait (SPS_Wait);
    Cmd := Cmd_Ini;
    Send_Cmd_String (Cmd);
    Mil.Timer2_Wait (SPS_Wait);
    Cmd := Cmd_Kom_Source;
    Send_Cmd_String (Cmd);
    Mil.Timer2_Wait (SPS_Wait);
    Cmd := Cmd_Ref;
    Send_Cmd_String (Cmd);
    Mil.Timer2_Wait (SPS_Wait);
  end;

 begin
    Cmd_Win_X := 01;
    Cmd_Win_Y := 01;
    Hinweis;
    Wait_Send := 0;
    Fct.B.Adr := Ifc_Test_Nr;
    Ini_Text_Win;
    GotoXY(10, 2); TextColor(Magenta); Writeln ('*** Command-String Test ***');
{    TextColor(Brown);
    GotoXY(S_Wait, Z_Wait); Write('Wartezeit zwischen Ascii-Zeichen [ms]: ');
    Show_Wait_Send;
}   TextColor(Brown);
    GotoXY(02, Z_CmdWin_Base+1); Writeln ('V24-Kommunikation:');
    Displ_Response;
    Cursor(False);
    Ini_Msg_Win;
    Write ('Befehle ('); TextColor(Black); Write ('sw'); TextColor(Yellow);
    Write (') mit F-Tasten (Antwort in '); TextColor(Red); Write ('rot');
    TextColor (Yellow); Write (').         Abort mit Esc-Taste!');
    Ini_Cmd_Win;

    repeat
     if KeyEPressed then
      begin
         Ch:= NewReadKey;
         if Ch = #0 then                  {Sonder-Tasten Abfrage}
          begin
           Ch := NewReadKey;
           case ord (Ch) of
            Taste_F1 : begin
                        Cmd := Cmd_Soft_Li;
                        Send_Cmd_String (Cmd);
                       end;
            Taste_F2 : begin
                        Cmd := Cmd_Soft_Re;
                        Send_Cmd_String (Cmd);
                       end;
            Taste_F3 : begin
                        Cmd := Cmd_Istw;
                        Send_Cmd_String (Cmd);
                       end;
            Taste_F4 : begin  {Die Referenzfahrt musste erweitert werden}
{                       Cmd := Cmd_Ref;  ohne Powerup reicht dies Kommando
                        Send_Cmd_String (Cmd); }
                        Ini_Err_Win;
                        Write ('Bitte einige Sekunden warten. Referenzfahrt wird ausgefÅhrt!');
                        Referenz_Powerup;
 Ini_Msg_Win;
 Write ('Befehle ('); TextColor(Black); Write ('sw'); TextColor(Yellow);
 Write (') mit F-Tasten (Antwort in '); TextColor(Red); Write ('rot');
 TextColor (Yellow); Write (').         Abort mit Esc-Taste!');
 Ini_Cmd_Win;
                      end;
            Taste_F5 : begin
                        Cmd := Cmd_Dummy;
                        Send_Cmd_String (Cmd);
                       end;
            Taste_F6 : begin
                       end;
            Taste_F7 : begin
                        Cmd := Cmd_Soft_Li ;     {erst in die NÑhe fahren}
                        Send_Cmd_String (Cmd);
                        Mil.Timer2_Set (10000);  {Warte auf Cr + Lf}
                        while not Mil.Timeout2 do Read_Rcv_Fifo;
                        Cmd :=Cmd_Anschlag_Li;   {an mechan. Anschlag}
                        Send_Cmd_String (Cmd);
                       end;
            Taste_F8 : begin
                        Cmd :=Cmd_Soft_Re ;      {erst in die NÑhe fahren}
                        Send_Cmd_String (Cmd);
                        Mil.Timer2_Set (10000);  {Warte auf Cr + Lf}
                        while not Mil.Timeout2 do Read_Rcv_Fifo;
                        Cmd :=Cmd_Anschlag_Re;
                        Send_Cmd_String (Cmd);   {an mechan. Anschlag}
                       end;
            Taste_F9 : begin
                        Cmd := Cmd_Norm;
                        Send_Cmd_String (Cmd);
                       end;
            Taste_F10: begin
                        Cmd := Cmd_Rd_Error;
                        Send_Cmd_String (Cmd);
                       end;
            Taste_F11: begin
                         Mil.Reset;
                         Ini_Err_Win;
                         Write ('Reset PC-Mil Karte!! ');
                         Mil.Timer2_Wait (100000);
                         Ini_Msg_Win;
                         Write ('Abort Esc-Taste!');
                         Set_Cmd_Win;
                        end;
            Taste_F12: begin
                        Cmd := Cmd_Ini_Baudrate; {Baudrate SPS auf Rechnerbaudrate synchronisieren}
                        Send_Cmd_String (Cmd);
                        Mil.Timer2_Set (10000);  {Warte auf Cr + Lf}
                        while not Mil.Timeout2 do Read_Rcv_Fifo;
                        Cmd := Cmd_Ini;          {Auf Rechner schalten}
                        Send_Cmd_String (Cmd);
                        Mil.Timer2_Set (10000);  {Warte auf Cr + Lf}
                        while not Mil.Timeout2 do Read_Rcv_Fifo;
                    {    Cmd := Cmd_Ref;       musste erweitert werden
                        Send_Cmd_String (Cmd);  }
                        Ini_Err_Win;
                        Write ('Bitte einige Sekunden warten. Referenzfahrt wird ausgefÅhrt!');
                        Referenz_Powerup;
 Ini_Msg_Win;
 Write ('Befehle ('); TextColor(Black); Write ('sw'); TextColor(Yellow);
 Write (') mit F-Tasten (Antwort in '); TextColor(Red); Write ('rot');
 TextColor (Yellow); Write (').         Abort mit Esc-Taste!');
 Ini_Cmd_Win;
                       end;
          end;  {Case}
       end;
     end; {if Keypressed}
    Read_Rcv_Fifo;
   until Ch = #27;
   Ch := '?';       {Wichtig: ESC-Zeichen lîschen!}
 99:  Cursor(True);
 end; {FTast_Cmd}

 procedure Lpos_Status;     {geÑnderte Version von Mil-Status_All}
  Label 99;
  const Z_C0 = 14;
        Z_C1 = 15;
        Z_C2 = 16;
        Z_C3 = 17;
        Z_Stat = 19;

  type Tstat = record case Byte of
              1: ( adr     : Byte;
                   c0      : Byte;
                   c1      : Byte;
                   c2      : Byte;
                   Count   : Byte;
                  );
              2: ( adrc0 : Word;
                   c1c2  : Word;
                 );
              end;

  var Bit16_Strg: Str19;
      read_data,fct_code : WORD;
      MilErr : TMilErr;
      Fct    : TFct;
      transf_cnt : LongInt;
      timout_cnt : LongInt;
      Ch         : Char;
      Stat       : Tstat;
      Temp       : Byte;
      X          : Byte;
      Adress     : Word;

   procedure Status_Init;
    begin
      Stat.Adrc0    := 0;
      Stat.C1c2     := 0;
      Stat.Count    := 0;
    end;

   PROCEDURE Show_Stat_Reg (Funct_Code: Byte);
    var Zeile : Byte;
        N     : Byte;
    Begin
     Fct.B.Adr := Ifc_Test_Nr;
     case Funct_Code of
      $C0 : begin Fct.B.Fct:= Fct_Rd_Stat0; Zeile := Z_C0; end;
      $C1 : begin Fct.B.Fct:= Fct_Rd_Stat1; Zeile := Z_C1; end;
      $C2 : begin Fct.B.Fct:= Fct_Rd_Stat2; Zeile := Z_C2; end;
     end;

     Read_Data := 0;
     Set_Text_Win;
     GotoXY(03,Z_C0);  write('  ');
     GotoXY(03,Z_C1);  write('  ');
     GotoXY(03,Z_C2);  write('  ');
     TextColor(Yellow);
     GotoXY(03,Zeile); write('->');
     TextColor(Black);
     Mil.Rd (Read_Data, Fct, MilErr);
     if MilErr <> No_Err then
      begin
       timout_cnt := timout_cnt + 1;
       GotoXY(22, Zeile);
       TextColor(Red);
       write('    Read Error!!                    ');
       TextColor(Black);
      end
     else                     {Kein Mil-Error}
      begin                   {Rette Adr und sukzessive alle 3 Status-Werte}
        GotoXY(48, Zeile);  Write(hex_word(Read_Data));
        Hex_Bin_Str (Read_Data,Bit16_Strg);
        GotoXY(22, Zeile);  Write(Bit16_Strg);

        {PrÅfe zuerst, ob IFK Soll=Ist-Adresse: gilt nur fÅr C0 Hex}
        if Funct_Code = $C0 then
         begin
         end;

          if Lo (Read_Data) <> Fct.B.Adr then
           begin
            Ini_Err_Win;
            Write ('ERROR: Antwort v. falscher IFK-Adr!  '); TextColor(Yellow+128);
            Write('Soll: ', Hex_Byte(Fct.B.Adr),'[H]  Ist: ', Hex_Byte(Lo(Read_Data)),'[H]');
            TextColor(Red); Write ('  Weiter <Space> ');
            Ch := NewReadKey;
           end;        {if Soll-Adr<> ist-Adr}


{Darstellung als 32-Bit-Word wie SE, wegen besserem Vergleich mit PR-Gruppe}
        case Funct_Code of
         $C0 : begin
                 Stat.AdrC0 := Read_Data;  {Low-Word mit Adresse !!}
                 Stat.Count := 1;
               end;
         $C1 : begin
                 Stat.C1    := Hi(Read_Data);
                 Stat.Count := Stat.Count + 1;
               end;
         $C2 : begin
                 Stat.C2    := Hi(Read_Data);
                 Stat.Count := Stat.Count + 1;
               end;
        end; {case}
      end;   {if errer}

       if Funct_Code = $C2 then
        begin
          if Stat.Count = 3 then
           begin
            Hex_Bin_Str (Stat.AdrC0,bit16_strg);    {Darstellung als 2 x 16 Bit}
            GotoXY(42, Z_Stat); write(bit16_strg);
            Hex_Bin_Str (Stat.C1c2,bit16_strg);
            GotoXY(22, Z_Stat); write(bit16_strg);
           end
          else
           begin
            GotoXY(22, Z_Stat); ClrEol;
           end;
         end; {if fct_code}
     Mil.Timer2_Wait (8000);  {warte}
    End; {show_stat_reg}

 procedure Displ_Status;
  begin
   Set_Text_win;
   Transf_Cnt := Transf_Cnt+ 1;
   GotoXY(20, 09); write(transf_cnt:12);
   GotoXY(20, 11); write(timout_cnt:12);

   Status_Init;
   show_stat_reg ($C0);
   show_stat_reg ($C1);
   show_stat_reg ($C2);
  end;


 procedure C0_FTast_Win;
  const Z_Tast_Win = 13;
  begin
   Set_Text_Win; TextColor(Brown);
   GotoXY(60,Z_Tast_Win); Write ('Belegung F-Tasten: ');
   Window(60,Z_Tast_Win+3, 79, Z_Tast_Win+6);
   TextBackground(Green); TextColor(Yellow);
   GotoXY(1,1);   Write ('F10: Ifk-Adr        ');
   GotoXY(1,2);   Write ('F12: Clear PwrUp-Bit');
  end;

  procedure Ini_Lpos_win;
   begin
    Window(55, 05, 80, 12);
    TextBackground(Cyan);
    TextColor(Blue);               {Setze Schriftfarbe}
   { ClrScr;}
   end;

 PROCEDURE Displ_Lpos_Statbits;
  Begin
     {Info-Anzeige der Bit-Belegung Hardware-Status}
      Ini_Lpos_Win;
      TextColor(Blue);
      writeln('Bit15: 1= Betrieb Hand   ');
      writeln('Bit14: 1= Powerup        ');
      writeln('Bit13: 0= Notaus aktiv   ');
      writeln('Bit12: 1= Kabel ok       ');
      writeln('Bit11: 1= Druckluft fehlt');
      writeln('Bit10: 1= Druckluft da   ');
      writeln('Bit09: 1= Endlage innen  ');
      write  ('Bit08: 1= Endlage au·en  ');
      TextColor(Black);
   End; {displ_dyn_stat_bits}

  Begin
    Cursor(False);
    Status_Init;
    Ini_Text_Win;
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Fct_Rd_Status;

    transf_cnt := 0;
    timout_cnt := 0;

    Set_Text_Win; TextColor(Brown);
    GotoXY(55,02); write ('C0-Status:');
    GotoXY(06,04); write ('Lese Status C0, C1, C2   von der IFC-Karte');

    GotoXY(06,07); write ('IFC-Adr: '); TextColor(Blue);
    Write (Hex_Byte(Fct.B.Adr)); TextColor(Brown); Write(' [H]');

    GotoXY(22,Z_C0-1); write('+STATUS + +ADRESSE+');
    GotoXY(47,Z_C0-1); write('+DATA+');

    GotoXY(06,09);  write('Rd_Stat_Cnt:');
    GotoXY(26,10);  write('^  ^');
    GotoXY(06,11);  write('Rd_Error   :');

    GotoXY(05,Z_C0); write('Status    C0 >');
    GotoXY(05,Z_C1); write('Status    C1 >');
    GotoXY(05,Z_C2); write('Status    C2 >');
    GotoXY(22,Z_C3+0);   write('[MSB           LSB]       [Hex]');
    GotoXY(05,Z_Stat);   write ('32-Bit-Status:');
    GotoXY(05,Z_Stat+2); write ('Bit-Nummer   :');

    GotoXY(05,Z_Stat+1);
    for X := 0 to 3 do     {senkrechte Pfeile}
     begin
       GotoXY(22+X*8+X*2,Z_Stat+1);  Write(chr($18));
     end;
    GotoXY(60, Z_Stat+1);  Write(chr($18));

    {Bit-Zahlen}
    GotoXY(22, Z_Stat+2);  Write(31);
    GotoXY(32, Z_Stat+2);  Write(23);
    GotoXY(42, Z_Stat+2);  Write(15);
    GotoXY(52, Z_Stat+2);  Write(07); Write('  Adr  ');
    GotoXY(60, Z_Stat+2);  Write(00);
    C0_FTast_Win;
    Displ_Lpos_Statbits;
    TextColor(Black);
    Cursor(False);
    Std_Msg;
    Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Displ_Status;
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Displ_Status;
      end;

     if Ch = #0 then                  {Sonder-Tasten Abfrage}
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F10: begin
                     if Ask_Hex_Break (Adress, Byt) then
                      begin
                       Ifc_Test_Nr := Adress;
                       Fct.B.Adr := Ifc_Test_Nr;
                       Set_Text_Win;
                       TextColor(Brown); GotoXY(35,07); write  ('IFC-Adr: '); TextColor(Blue);
                       Write (Hex_Byte(Fct.B.Adr)); TextColor(Brown); Write(' [H]');
                       Std_Msg;
                      end;
                   end;
        Taste_F12: begin
                    Fct.B.Fct := Fct_ClearPwrup;
                    Mil.WrFct (Fct, MilErr);
                    Ini_Err_Win;
                    Write('Reset Powerup-Bit!');
                    Mil.Timer2_Wait(100000);          {Wartet mit Timer2}
                    Std_Msg;
                   end;
      end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
 end; {Lpos-Status}


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
                  if Check_Ifc_Adr(Ifc_Test_Nr) then Mil_Rd_HS_Ctrl (Ifc_Test_Nr);
                end;
     '3'      : begin
                  if Check_Ifc_Adr(Ifc_Test_Nr) then Mil_Rd_HS_Status (Ifc_Test_Nr);
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
                  if Check_Ifc_Adr(Ifc_Test_Nr) then Mil_HS_Stat_Cmd (Ifc_Test_Nr);
                end;
     '8'      : begin

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
     'y', 'Y' : begin
                  Modul_Bus;
                end;
     'z', 'Z' : begin
                  Telefon;
                end;
     {Ab hier User-Erweiterungen!!}
          'm', 'M' : begin
                       Mil_Ask_Ifc;
                       V24_Terminal;
                     end;
          'n', 'N' : begin
                       Mil_Ask_Ifc;
                       FTast_Cmd;
                     end;
          'o', 'O' : begin
                       Mil_Ask_Ifc;
                       Normierung;
                     end;
          'p', 'P' : begin
                       V24_Connector;
                     end;
          'q', 'Q' : begin
                       VT320_Kabel;
                     end;
          'r', 'R' : begin
                       Mil_Ask_Ifc;
                       Lpos_Status;
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
end. {mil_lpos}
