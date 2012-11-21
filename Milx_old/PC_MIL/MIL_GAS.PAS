program MIL_GAS;                                        {Programm MIL_GAS.PAS}
{ Autor: Gerhard Englert                              Turbo-Pascal Version 7.0
  ******************* Manuelle Bedienung fÅr GAS-Recycling ******************
  Anwender: Eickhoff (Tel.2368) / Reich oder Spiller (Tel.2405) Raum
                                  Teststand          (Tel.2250)

              Handsteuerung gebaut von APL/Gro· auf Basis APL-IO-BUS
  Besonderheit:
  Eine I/O-Karte FG 385.030 ist auf Output geschaltet.
  Die Daten fÅr diese Karte werden gelatched und sind rÅcklesbar.

  Status-Signale sind durch Pullup's "aktiv low"
  Ventil-Status wird Åber 2 Bit zurÅckgemeldet: z. B. Bit0 = "0" = Auf
                                                      Bit1 = "0" = Zu
                                                      Bit0=Bit1= "0"= undef.
  Befehle an Ventile oder Pumpen: nur 1 Bit: "0" = Zu; "1" = Auf
  VH = Ventile Hand werden im Status nicht Åberwacht.

  16.02.94      Erstellung
  02.03.94      Rechner/Hand-Abfrage  Bitbelegung noch ÅberprÅfen!!!!!!!!
                Schaltoperationen laufen Åber Relais! Entprellen beachten!!
  04.03.94      Auslesung ADC-Karte FG 385, 12-Bit-ADC, 12 KanÑle
                Problem: ADC-Konversion und Daten gÅltig
  30.05.94      öbernahme Bitbezeicnung lt. Gro·
  01.06.94      Set_Color ist neu
  06.06.94      BetriebszustÑnde Array
  21.06.94      Rd_Zustand procedure
  24.06.94      Diagramm
  11.11.96      Bedingte Compilierung
                ADC's werden nicht genutzt!!
  27.11.96      Status Valid Åberarbeitet
  28.11.96      Version 1
  29.11.96      Aktuelle Handeinstellung Åbernehmen


  03.12.96      Achtung: Weil Test-PC von Herrn Reich ein TYPE 386:
                "Optionen" -Compiler auf 286-Instuktionen  und
                                   Gleitkomma-Emulation
}

{$S-}
{$DEFINE NoTest}      {Test: Dummy-Daten aktivieren    NoTest: Arbeitsversion}
uses Crt, WinDos, Datech, Datech_1;
const
 Head_Line =
      'Datentechnik                        MIL_GAS  ' +
      '                       [03.12.1996]'+
      '                  GAS-Recycling Handsteuerung   [IFC-Karte FG 380.122]        ';

 Ifc_Nr      = $01;   {IFK am MIL-Bus FG 380.122 = fest verdrahtet!!}
 IoA_Stat    = $10;   {IoBus-Karte 1 fÅr Status-Bits  FG 385.030}
 IoA_Diag    = $20;   {IoBus-Karte 2 Adr. fÅr Diagnose-Bits  FG 385.030}
 IoA_Cmd     = $40;   {IoBus-Karten Adr. fÅr Command-Bits FG 385.030}
 IoA_Adc     = $60;   {IoBus-Karten Adr. fÅr 12-Bit-ADC   FG 385.040}
 DevMax_Stat = 32;    {Status von max. GerÑte: Ventile, Pumpen usw. }
 DevMax_Cmd  = 22;    {Commands u. Status an/von max. GerÑte: Ventile, Pumpen usw. }
 Zustand_Max = 14;    {Anzahl der BetriebszustÑnde}
 Trans_Max   = 08;    {Erlaubte öbergÑnge von einem zum nÑchsten Zustand}

 Kanal_Max   = 12;    {Max. Anzahl ADC-KanÑle}
 SubAdrMax   = 11;    {Max-Anzahl Subadr 0..11 wegen ADC, sonst 0..7}
 R_H_Sub     = 3;     {Iob-Subadr fÅr Status Rechner/Hand-Stellung}
 R_H_BitNr   = 1;     {Bitnummer fÅr R/H-Stellung}
 Wait_Read   = 10000;

type
 TZ_Mode = (Aktiv, Inaktiv, Transfer, Undef);    {Zustands-Modi der Anlage}
 Str4    = string[4];
 Str8    = string[8];
 Num_Str = string[10];
 TStat_Property = (N, V); {Normal, Ventil: Status fÅr Ventile liegt auf zwei Bits}
 TDev    = record      {Status-Bits u. Cmd-Bits auf verschiedenen IO-Karten!!}
            Dv       : string[6];
            Txt      : string[8];
            Adr      : Byte;          {I/O-Karten.-Adr}
            Sta_Sub  : Byte;          {IO-Sub-Adresse fÅr Status}
            Sta_BitNr: Byte;          {Bit-Nr 0..7 im Status-Byte}
            Sta_Pro  : TStat_Property;{Bei Ventilen zwei Bits fÅr auf/zu}
            Cmd_Sub  : Byte;          {IO-Sub-Adresse fÅr Command}
            Cmd_BitNr: Byte;          {Bit-Nr 0..7 im Command-Byte}
            B0 : string[4];           {Bedeutung fÅr Bit = '0'}
            B1 : string[4];           {Bedeutung fÅr Bit = '1'}
           end;

 TDevAry = array [1..DevMax_Stat] of TDev;

const            {VH = Ventile Hand werden im Status nicht Åberwacht}
Dev: TDevAry =
(                { Status-Info: aktiv low, wegen Pullup-Widerstand}
(Dv:'V1    '; Txt:'Anlag IN'; Adr: IoA_Stat; Sta_Sub:0; Sta_BitNr: 0; Sta_Pro:V; Cmd_Sub:0; Cmd_BitNr: 0; B0:'Auf'; B1:'Zu '),
(Dv:'V2    '; Txt:'By MB602'; Adr: IoA_Stat; Sta_Sub:0; Sta_BitNr: 2; Sta_Pro:V; Cmd_Sub:0; Cmd_BitNr: 1; B0:'Auf'; B1:'Zu '),
(Dv:'V3    '; Txt:'By Reing'; Adr: IoA_Stat; Sta_Sub:0; Sta_BitNr: 4; Sta_Pro:V; Cmd_Sub:0; Cmd_BitNr: 2; B0:'Auf'; B1:'Zu '),
(Dv:'V4    '; Txt:'Rein  IN'; Adr: IoA_Stat; Sta_Sub:0; Sta_BitNr: 6; Sta_Pro:V; Cmd_Sub:0; Cmd_BitNr: 3; B0:'Auf'; B1:'Zu '),
(Dv:'V5    '; Txt:'Rein OUT'; Adr: IoA_Stat; Sta_Sub:1; Sta_BitNr: 0; Sta_Pro:V; Cmd_Sub:0; Cmd_BitNr: 4; B0:'Auf'; B1:'Zu '),
(Dv:'V6    '; Txt:'KoMPr IN'; Adr: IoA_Stat; Sta_Sub:1; Sta_BitNr: 2; Sta_Pro:V; Cmd_Sub:0; Cmd_BitNr: 5; B0:'Auf'; B1:'Zu '),
(Dv:'V7    '; Txt:'CDP>Komp'; Adr: IoA_Stat; Sta_Sub:1; Sta_BitNr: 4; Sta_Pro:V; Cmd_Sub:0; Cmd_BitNr: 6; B0:'Auf'; B1:'Zu '),
(Dv:'V8    '; Txt:'KMP>Cool'; Adr: IoA_Stat; Sta_Sub:1; Sta_BitNr: 6; Sta_Pro:V; Cmd_Sub:0; Cmd_BitNr: 7; B0:'Auf'; B1:'Zu '),

(Dv:'V9    '; Txt:'KoMPr By'; Adr: IoA_Stat; Sta_Sub:2; Sta_BitNr: 0; Sta_Pro:V; Cmd_Sub:1; Cmd_BitNr: 0; B0:'Auf'; B1:'Zu '),
(Dv:'V10   '; Txt:'Anlg OUT'; Adr: IoA_Stat; Sta_Sub:2; Sta_BitNr: 2; Sta_Pro:V; Cmd_Sub:1; Cmd_BitNr: 1; B0:'Auf'; B1:'Zu '),
(Dv:'V11   '; Txt:'KMP>Entn'; Adr: IoA_Stat; Sta_Sub:2; Sta_BitNr: 4; Sta_Pro:V; Cmd_Sub:1; Cmd_BitNr: 2; B0:'Auf'; B1:'Zu '),
(Dv:'V12   '; Txt:'Entn 20b'; Adr: IoA_Stat; Sta_Sub:2; Sta_BitNr: 6; Sta_Pro:V; Cmd_Sub:1; Cmd_BitNr: 3; B0:'Auf'; B1:'Zu '),
(Dv:'V13   '; Txt:'Entn  1b'; Adr: IoA_Stat; Sta_Sub:3; Sta_BitNr: 0; Sta_Pro:V; Cmd_Sub:1; Cmd_BitNr: 4; B0:'Auf'; B1:'Zu '),
(Dv:'V14   '; Txt:'CDP>Entn'; Adr: IoA_Stat; Sta_Sub:3; Sta_BitNr: 2; Sta_Pro:V; Cmd_Sub:1; Cmd_BitNr: 5; B0:'Auf'; B1:'Zu '),
(Dv:'V15   '; Txt:'WKP<1bar'; Adr: IoA_Stat; Sta_Sub:3; Sta_BitNr: 4; Sta_Pro:V; Cmd_Sub:1; Cmd_BitNr: 6; B0:'Auf'; B1:'Zu '),
(Dv:'V16   '; Txt:'><20b/1b'; Adr: IoA_Stat; Sta_Sub:3; Sta_BitNr: 6; Sta_Pro:V; Cmd_Sub:1; Cmd_BitNr: 7; B0:'Auf'; B1:'Zu '),

(Dv:'V17   '; Txt:'Neugas  '; Adr: IoA_Stat; Sta_Sub:4; Sta_BitNr: 0; Sta_Pro:V; Cmd_Sub:2; Cmd_BitNr: 0; B0:'Auf'; B1:'Zu '),
(Dv:'V18   '; Txt:'Vorvakum'; Adr: IoA_Stat; Sta_Sub:4; Sta_BitNr: 2; Sta_Pro:V; Cmd_Sub:2; Cmd_BitNr: 1; B0:'Auf'; B1:'Zu '),
(Dv:'MB602 '; Txt:'Dv MB602'; Adr: IoA_Stat; Sta_Sub:4; Sta_BitNr: 4; Sta_Pro:V; Cmd_Sub:2; Cmd_BitNr: 2; B0:'Auf'; B1:'Zu '),
(Dv:'KOMPR '; Txt:'Dv KOMPR'; Adr: IoA_Stat; Sta_Sub:4; Sta_BitNr: 6; Sta_Pro:V; Cmd_Sub:2; Cmd_BitNr: 3; B0:'Auf'; B1:'Zu '),
(Dv:'CDP40 '; Txt:'Dv CDP40'; Adr: IoA_Diag; Sta_Sub:0; Sta_BitNr: 0; Sta_Pro:V; Cmd_Sub:2; Cmd_BitNr: 4; B0:'Auf'; B1:'Zu '),
(Dv:'DUO12A'; Txt:'Dv DUO12'; Adr: IoA_Diag; Sta_Sub:0; Sta_BitNr: 2; Sta_Pro:V; Cmd_Sub:2; Cmd_BitNr: 5; B0:'Auf'; B1:'Zu '),

(Dv:'Heizng'; Txt:'Reinig  '; Adr: IoA_Diag; Sta_Sub:0; Sta_BitNr: 4; Sta_Pro:V; Cmd_Sub:2; Cmd_BitNr: 6; B0:'An '; B1:'Aus '),
(Dv:'------'; Txt:'        '; Adr: IoA_Diag; Sta_Sub:0; Sta_BitNr: 6; Sta_Pro:V; Cmd_Sub:2; Cmd_BitNr: 6; B0:'---'; B1:'---'),

(Dv:'Reinig'; Txt:'Stîrung '; Adr: IoA_Diag; Sta_Sub:1; Sta_BitNr: 0; Sta_Pro:N; Cmd_Sub:5; Cmd_BitNr: 0; B0:'nein'; B1:' ja'),
(Dv:'KOMPR '; Txt:'Stîrung '; Adr: IoA_Diag; Sta_Sub:1; Sta_BitNr: 1; Sta_Pro:N; Cmd_Sub:5; Cmd_BitNr: 0; B0:'nein'; B1:' ja'),
(Dv:'KOMPR '; Txt:'MemBruch'; Adr: IoA_Diag; Sta_Sub:1; Sta_BitNr: 2; Sta_Pro:N; Cmd_Sub:5; Cmd_BitNr: 0; B0:'nein'; B1:' ja'),
(Dv:'CDPTem'; Txt:'Stîrung '; Adr: IoA_Diag; Sta_Sub:1; Sta_BitNr: 3; Sta_Pro:N; Cmd_Sub:5; Cmd_BitNr: 0; B0:'nein'; B1:' ja'),
(Dv:'DUO12 '; Txt:'Stîrung '; Adr: IoA_Diag; Sta_Sub:1; Sta_BitNr: 4; Sta_Pro:N; Cmd_Sub:5; Cmd_BitNr: 0; B0:'nein'; B1:' ja'),
(Dv:'ABGAS '; Txt:'Geschlos'; Adr: IoA_Diag; Sta_Sub:1; Sta_BitNr: 5; Sta_Pro:N; Cmd_Sub:5; Cmd_BitNr: 0; B0:'nein'; B1:' ja'),
(Dv:'Reinig'; Txt:'Temp ok?'; Adr: IoA_Diag; Sta_Sub:1; Sta_BitNr: 6; Sta_Pro:N; Cmd_Sub:5; Cmd_BitNr: 0; B0:'nein'; B1:' ja'),
(Dv:'------'; Txt:'        '; Adr: IoA_Diag; Sta_Sub:1; Sta_BitNr: 7; Sta_Pro:N; Cmd_Sub:5; Cmd_BitNr: 0; B0:'----'; B1:'---')
);

type
 TBit           = 0..1;
 TZuMuster      = packed array [1..DevMax_Cmd] of TBit;
 TZuAry         = array [1..Zustand_Max] of TZuMuster;
 TZustnd_Txt    = string[17];
 TZustnd_TxtAry = array [1..Zustand_Max] of TZustnd_Txt;

 TTrans         = array [1..Trans_Max] of Byte;     {Anzahl erlaubter öbergange}
 TTrans_Ary     = array [1..Zustand_Max] of TTrans; {FÅr jeden Zustand}

const { Die BetriebszustÑnde werden in einem Array definiert            }
      {"0"= Ventil "zu" bzw. Pumpe "aus", "1"= Ventil auf oder Pumpe ein}
Zustnd: TZuAry =
{ 1 2 3 4 5 6 7 8 9 10 1 2 3 4 5 6 7 8 9 20 1 2    <--  Dev-Nr.           }
(                                                  { v-- Betriebs Zustand   }
( 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0 ), {01: Anlage Aus          }
( 0,1,1,1,1,1,1,1,1,0, 1,0,0,1,0,1,0,1,0,0, 0,1 ), {02: Standby ohne Gas    }
( 0,1,1,1,1,1,1,1,1,0, 1,1,1,1,0,1,1,1,0,0, 0,1 ), {03: Abpumpen Vorrat     }
( 0,0,0,1,1,1,1,1,0,0, 1,0,0,1,0,0,1,0,0,0, 0,0 ), {04: Standby mit Gas     }
( 0,1,1,0,0,1,1,1,1,0, 1,0,0,1,0,1,0,0,0,0, 0,0 ), {05: Vorbereitg o. Reinig}
{ 1 2 3 4 5 6 7 8 9 10 1 2 3 4 5 6 7 8 9 20 1 2    <--  Dev-Nr. }
( 0,1,1,0,0,1,1,1,0,1, 1,0,0,1,0,0,0,0,0,0, 0,0 ), {06: FÅllen mit Gas      }
( 1,0,1,0,0,1,1,1,0,1, 1,0,0,1,0,0,0,0,1,1, 0,0 ), {07: Betrieb ohne Reinig }
( 0,1,1,1,1,1,1,1,0,0, 1,1,0,1,0,0,0,0,0,0, 0,0 ), {08: FÅll m. Vorrat Gas A}
( 1,0,0,1,1,1,1,1,0,0, 0,1,1,0,1,1,0,0,1,1, 0,0 ), {09: FÅll m. Vorrat Gas B}
( 0,0,0,1,1,1,1,1,0,0, 1,0,0,1,0,0,1,0,1,1, 0,0 ), {10: Int Betrb. m. Reinig}
{ 1 2 3 4 5 6 7 8 9 10 1 2 3 4 5 6 7 8 9 20 1 2    <--  Dev-Nr. }
( 1,0,0,1,1,1,1,1,0,1, 1,0,0,1,0,0,1,0,1,1, 0,0 ), {11: Betrieb m. Reinigumg}
( 0,1,1,1,1,1,1,1,0,0, 1,0,0,1,0,0,1,0,0,0, 0,0 ), {12: FÅllen mit Edelgas  }
( 1,1,1,1,1,0,1,0,0,1, 1,1,0,0,1,0,0,0,1,1, 1,0 ), {13: Entnahme 20 bar     }
( 0,1,1,1,1,1,0,1,1,0, 1,0,1,1,0,1,0,0,1,0, 1,0 )  {14: Entnahme 1 bar      }
);
 {Zustand 4}
 Test_Zustand: TZuMuster = ( 0,0,0,1,1,1,1,1, 0,0,1,0,0,1,0,0, 1,0,0,0, 0,0 );

 Zustnd_TxtAry : TZustnd_TxtAry =
 (                       {Zustand}
 ('Anlage AUS       '),    {1}
 ('Standby ohne GAS '),    {2}
 ('Abpump. Vorratfl '),    {3}
 ('Standby mit  GAS '),    {4}
 ('Vorber. o. Reinig'),    {5}
 ('FÅllen mit   GAS '),    {6}
 ('Betrieb o. Reinig'),    {7}
 ('FÅllen mit  GAS A'),    {8}
 ('FÅllen mit  GAS B'),    {9}
 ('IntBetr m. Reinig'),    {10}
 ('Betrieb m. Reinig'),    {11}
 ('FÅll. mit EdelGAS'),    {12}
 ('Entnahme 20 bar  '),    {13}
 ('Entnahme  1 bar  ')     {14}
 );

{Im Trans-Array sind die erlaubten öbergÑnge von einem zum nÑchsten Zustand
 definiert. Abgeleitet aus dem öbersichts-Diagramm. Auch auf eigenen Zustand }
Transition : TTrans_Ary =
{ 1   2  3  4  5  6  7 8 }
{ v--------------------<----ø  <- erlaubte öbergÑnge zu neuem Zustand }
(                          {v-- Ausgangs-Zustand                      }
( 1,  2, 4, 0, 0, 0, 0,0), {01 Zustand}
( 2,  1, 3, 5, 8,12, 0,0), {02 Zustand}
( 3,  2, 0, 0, 0, 0, 0,0), {03 Zustand}
( 4,  1,10, 0, 0, 0, 0,0), {04 Zustand}
( 5,  6, 2, 0, 0, 0, 0,0), {05 Zustand}
( 6,  7, 5, 0, 0, 0, 0,0), {06 Zustand}
( 7,  6, 0, 0, 0, 0, 0,0), {07 Zustand}
( 8,  9, 0, 0, 0, 0, 0,0), {08 Zustand}
( 9, 10, 0, 0, 0, 0, 0,0), {09 Zustand}
(10,  4,11,13, 0, 0, 0,0), {10 Zustand}
(11, 10, 0, 0, 0, 0, 0,0), {11 Zustand}
(12, 10, 0, 0, 0, 0, 0,0), {12 Zustand}
(13, 14, 0, 0, 0, 0, 0,0), {13 Zustand}
(14,  2, 0, 0, 0, 0, 0,0)  {14 Zustand}
);

var
 Mil        : T_Mil;               {Type OBJECT: in Unit Datech.Pas definiert}
 Iob_Stat_Nr: Byte;
 Iob_Cmd_Nr : Byte;
 Zstand     : TZuMuster;
 Z_Mod_Ist  : TZ_Mode;
 Z_Mod_Soll : TZ_Mode;
 Z_Mod_Test : TZ_Mode;

 Loop       : Boolean;
 User_Input : Char;
 Ch         : Char;
 I          : WORD;
 Ret_Adr    : Byte;
 OnlineErr  : TOnlineErr;
 Single_Step: Boolean;

procedure menue_win;
var answer: CHAR;
begin
  Ini_Headl_Win;
  Write(head_line);
  Ini_Text_Win;

{$IFDEF Test}
  GotoXY(27, 02); TextColor(Yellow + 128);
  Write ('Test-Version mit Dummy-Daten!!');
{$ENDIF}

  GotoXY(12, 03); TextColor(Brown);
  Writeln('**********************   TEST-MENUE   ************************');
  GotoXY(12, 05); TextColor(Black);
  Writeln('[A]<-- Zeige fixe MIL/IOB-Adr    Welche IFC am MIL-Bus? -->[0]');
  GotoXY(12, 06);
  Writeln('[B]<-- 1_Kanal             ADC-Lesen           12_Kanal -->[1]');
  GotoXY(12, 07);
  Writeln('[C]<-- 1_SubAdr      Lese Iob-Status-Bits      8_SubAdr -->[2]');
  GotoXY(12, 08);
  Writeln('[D]<-- 1_SubAdr      Lese Iob-Command-Bits     8_SubAdr -->[3]');
  GotoXY(12, 09);
  Writeln('[E]<-- öbersichts-Diagramm der Anlagen-ZustÑnde               ');
  GotoXY(12, 10);
  Writeln('[F]<-- Zeige SOLL-Status der GerÑte je Anlagen-Zustand        ');
  GotoXY(12, 11);
  Writeln('[G]<-- Testzustand                                            ');

  GotoXY(12, 12);
  Writeln('       [K]<--  Anlagenzustand anzeigen/Ñndern             ');
  GotoXY(12, 13);
  Writeln('       [L]<--  Zustand der GerÑte anzeigen/Ñndern         ');
  GotoXY(12, 14);
  Writeln('       [M]<--  Zeige Stellung R/H-Schalter                ');
  GotoXY(12, 15);
  Writeln('       [N]<--  PrÅfe, ob Statusbits eindeutig             ');
  GotoXY(12, 16);
  Writeln('       [O]<--  PrÅfe den Betriebszustand der Anlage       ');
  GotoXY(12, 17);
  Writeln('       [P]<--  Handzustand fÅr Rechner Åbernehmen         ');
  GotoXY(12, 18);
  Writeln('       [R]<--  ANLAGE AUS: Reset IFC- + IOB-Karte (Fct 01)');

  Ini_Msg_Win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
 end; {menue_win}


procedure Mil_Ifc_Reset;
 var IobErr : TMilErr;
      Fct    : TFct;
 begin
   Fct.B.Adr := Ifc_Nr;
   Fct.B.Fct := Fct_Reset ;
   Ini_Err_Win;
   Write('Vorsicht: Wirklich alles lîschen mit Reset?? [J/N]: ');
   Ch := ReadKey;
   if Ch in ['j','J'] then
    begin
     Mil.WrFct (Fct, IobErr);
     Ini_Msg_Win;
     Write('Reset IFC ausgefÅhrt. Weiter mit irgendeiner Taste!');
     repeat until KeyPressed;
    end;
end;

procedure Show_IFC (X: Byte; Y :Byte);
 begin
   Set_Text_Win;
   TextColor (Brown);
   GotoXY(X, Y);
   Write ('IFC-Adresse: ', Hex_Byte (Ifc_Nr));
   TextColor (Black);
 end; {Show_IFC}

procedure Test_Hand (var Hnd: Boolean; var Hnd_Err: TMilErr);
                                    {Rechner/Handschalter auf der Bedientafel}
 var
  Stat_Adr : TIoAdr;
  IobErr   : TMilErr;
  RdData   : Word;
 begin
   Hnd := True;                                          {Default auf Hand}
   Stat_Adr.IfcAdr:= Ifc_Nr;                             {Adresse MIL-IFC}
   Stat_Adr.IoCard:= IoA_Diag;                           {Adresse IOB-Status}
   Stat_Adr.IoSub := R_H_Sub;                            {Sub-Adr- Status}
   Mil.Rd_IoBus (RdData, Stat_Adr, IobErr);              {Status nur byteweise}

   Hnd_Err := IobErr;
   if IobErr = No_Err then
     begin
      if BitTst(RdData,R_H_BitNr) then  Hnd := False;
     end;
 end; {Test_Hand}

procedure show_hand;
var Hand : Boolean;
    Hand_Err: TMilErr;
begin
   Ini_Text_Win;
   Test_Hand (Hand,Hand_Err);
   if Hand_Err = No_Err then
    begin
     Ini_Msg_Win;
     if Hand then
      begin
       Write('Der Rechner/Hand-Schalter steht auf --> [ '); TextColor (Red);
       Write('Hand '); TextColor(Yellow); Write('].              Weiter mit <CR>')
      end
     else
      begin
       Write('Der Rechner/Hand-Schalter steht auf --> ['); TextColor (Red);
       Write('Rechner'); TextColor(Yellow); Write('].             Weiter mit <CR>');
      end;
    end
   else
    begin
     Ini_Err_Win;
     Write('Error: Stellung Rechner/Hand nicht lesbar! Weiter mit beliebiger Taste. ');
    end;
   repeat until KeyPressed;
end;

procedure  Disp_Adr;
 begin
  Ini_Text_Win;
  TextColor(Brown);
  GotoXY(10,5);
  Writeln ('Folgende MIL- und I/O-Bus-Adressen sind vordefiniert: ');
  Writeln;
  TextColor(Brown);
   Write (' Mil-Ifc-Adr (FG 380.122) I/O-Bus-Drv    [Hex]: '); TextColor(Black);  Writeln (Hex_Byte(Ifc_Nr));
  TextColor(Brown);
   Write (' I/O-Bus-Adr (FG 385.030) Status  (Nr.1) [Hex]: '); TextColor(Black);  Writeln (Hex_Byte(IoA_Stat));
  TextColor(Brown);
   Write (' I/O-Bus-Adr (FG 385.030) Diagnose(Nr.2) [Hex]: '); TextColor(Black);  Writeln (Hex_Byte(IoA_Diag));
  TextColor(Brown);
   Write (' I/O-Bus-Adr (FG 385.030) Command        [Hex]: '); TextColor(Black);  Writeln (Hex_Byte(IoA_Cmd));
  TextColor(Brown);
   Write (' I/O-Bus-Adr (FG 385.040) 12-Bit ADC     [Hex]: '); TextColor(Black);  Writeln (Hex_Byte(IoA_Adc));
  TextColor(Black);
  Ini_Msg_Win;
  Write('Weiter mit beliebiger Taste! ');
  Ch := ReadKey;
 end;


function Iob_Ask_SubAdr(IobCard: Byte): Byte;
 var Status: Boolean;
     SubAdr: Byte;
 begin
   Ini_Text_Win;
   Status := False;
   while not Status do
    begin
     Ini_Msg_Win;
     Write ('Welche Subadresse testen ['); TextColor(Red);
     Write ('0..',SubAdrMax);  TextColor (Yellow); Write(']? : ');
     {$I-}                            {Compiler Check aus, Error selber abfangen}
     readln(SubAdr);
     {$I+}
     if IoResult = 0 then                             {PrÅfe, ob Nr ok}
      begin
       Iob_Ask_SubAdr:= SubAdr;
       if (SubAdr in [0..SubAdrMax]) then Status := True
       else
        begin
         Ini_Err_Win;
         Write('Error: Nur Subadresse [0..',SubAdrMax,'] erlaubt! Weiter beliebige Taste.');
         ReadKey;
        end;
      end
     else
      begin
       Ini_Err_Win;
       Write('Error: Keine gÅltige Zahleneingabe! Weiter beliebige Taste.');
       Readkey;
      end;   {if IoResult}
    end; {while}
 end; {Iob_Ask_Subadr}


function Iob_Ask_IoAdr: Byte;
 var Status: Boolean;
     Iob_Adr: Word;
 begin
   Status := False;
   while not Status do
    begin
     Ini_Text_Win;
     GotoXY(1, 22);
     Write ('Basis-Adr fÅr I/O-Bus Testkarte? (00, 08, 10H, 18H .. F8) [Hex]: ');

     if not  Ask_Hex_Break (Iob_Adr, Byt) then
      begin
       Ini_Err_Win;
       Write('Basis-Adr wird auf [00] gesetzt!! Weiter mit beliebiger Taste');
       ReadKey;
       Iob_Adr:= 0;
      end;

     if (Iob_Adr in [00..$F8]) and (Iob_Adr mod 8 = 0) then
       Status := True
     else
      begin
       Ini_Err_Win;
       Write('Error: Diese I/O-Bus Karten-Adr ist nicht erlaubt! Weiter beliebige Taste.');
       ReadKey;
      end;
    end; {while}
    Iob_Ask_IoAdr := Iob_Adr;
 end; {Iob_Ask_Subadr}


procedure Iob_Rd_Stat;                 {Lese Status-Bits von IO-Bus}
 const
     S_Hex = 47;
     S_Bit = 47;
     Z_Hex = 11;
     Z_Bit = Z_Hex+2;
     Z_MSB = Z_Bit+1;

 var A       : Word;
     Adr     : TIoAdr;
     IobErr  : TMilErr;
     Card_Adr: Byte;
     RdData  : Word;
     WrData  : Word;
     Mil_Timout : Boolean;

     Transf_Cnt: LongInt;
     Error_Cnt : LongInt;
     Timout_Cnt: LongInt;
     Timout_Rd : LongInt;
     Timout_Wr : LongInt;
     Bit16_Strg: Str19;

  begin
   Ini_Text_Win;
   Ch := ' ';
   Transf_Cnt := 0;
   Error_Cnt  := 0;
   Timout_Wr  := 0;
   Timout_Rd  := 0;
   Adr.IfcAdr := Ifc_Nr;
   Mil.Ifc_Online (Ifc_Nr, Ret_Adr, OnlineErr);
   if OnlineErr <> NoErr then
    begin
      Ini_Err_Win;
      Write ('ERROR: IFC-Karte [', Hex_Byte(Ifc_Nr), '] nicht Online!!      Weiter mit beliebiger Taste');
      ReadKey;
      Exit;
    end;

   Adr.IoCard := Iob_Ask_IoAdr;
   if not loop then Adr.IoSub := Iob_Ask_SubAdr(Adr.IoCard);

   Ini_Text_Win;
   Ini_Text_Win;
   GotoXY(06,08);  Writeln('Iob-Adr[Hex]:       ', Hex_Byte(Adr.IoCard));
   GotoXY(6, 11);
   writeln('Transfr_Cnt:              Read-Data [H]:                ');
   GotoXY(22,12);  writeln('^  ^');
   GotoXY(06, Z_Bit);
   writeln('                                  [Bit]:                ');
   GotoXY(S_Bit, Z_Msb);  write('MSB             LSB');

   GotoXY(53,11);  write('Timeout:');
   GotoXY(61,11);  write(timout_wr:10);
   Show_IFC (30,5);

   Ini_Msg_Win;
   Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');
   A := 0;
   if Loop then                                     {Alle Subadresssen}
    begin
      repeat
       repeat
         Set_Text_win;
         Mil_Timout := False;
         Transf_Cnt := Transf_Cnt+ 1;
         GotoXY(18,11);  Write(Transf_Cnt:10);
         Adr.IoSub := A;
         GotoXY(06,09);  Writeln('Sub-Adr     :', Adr.IoSub:9);

         Mil.Rd_IoBus (RdData, Adr, IobErr);
         if IobErr <> No_err then
           begin
            Mil_Timout := True;
            Timout_Wr:= Timout_Wr +1;
            TextColor(Red);
            GotoXY(61,11);  write(timout_wr:10);
            TextColor(Black);
           end
         else
          begin
            GotoXY(S_Hex, Z_Hex);  Write(Hex_Word(RdData));
            Hex_Bin_Str (RdData, Bit16_Strg);
            GotoXY(S_Bit, Z_Bit);  write(Bit16_Strg);
          end;

          A := A + 1;
          if A > 5 then A := 0;
          Mil.Timer2_Wait(Wait_Read);          {Read-Time abwarten; Basis 10 us}
       until KeyPressed or (Ch = ' ');
       if Ch = ' ' then
         begin
          Ini_Msg_Win;
          Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
          repeat until KeyPressed;
         end;
       Ch := ReadKey;
      until Ch in ['x','X'];
  end {if loop= yes}
 else
  begin                                      {nur eine Subadresse}
   repeat
    repeat
      Set_Text_win;
      Mil_Timout := False;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(06,09);  Writeln('Sub-Adr     :', Adr.IoSub:9);
      GotoXY(18,11);  Write(Transf_Cnt:10);

      Mil.Rd_IoBus (RdData, Adr, IobErr);
      if IobErr <> No_err then
       begin
        Mil_Timout := True;
        Timout_Wr:= Timout_Wr +1;
        GotoXY(61,11);  write(timout_wr:10);
       end
      else
       begin
         GotoXY(S_Hex, Z_Hex);  Write(Hex_Word(RdData));
         Hex_Bin_Str (RdData, Bit16_Strg);
         GotoXY(S_Bit, Z_Bit);  write(Bit16_Strg);
       end;
      GotoXY(61,11);  write(timout_wr:10);
    until KeyPressed or (Ch = ' ');
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyPressed;
      end;
    Ch := ReadKey;
   until Ch in ['x','X'];
  end; {if loop = no}
 end; {Iob_Rd_Stat;}


{***************************************************************************}
  procedure Set_Color_OK;
   begin
    TextBackground(Green);
    TextColor(Yellow);
{    TextBackground(Green);
    TextColor(Red);
}   end;


procedure DevStatDisp (DevNr: Byte);
 const
   Z_Base   = 2;
   Z_Titel  = Z_Base -1;
   Z_Uscore = Z_Base;

   Off_Left = 5;    {Linke HÑlfte}
   Off_Right= 45;   {Rechte HÑlfte}
   Off_Dev  = 5;
   Off_Txt  = 13;
   Off_Bt0  = 24;
   Off_Bt1  = 28;
   Clr_Text = '          ';
var
  Stat_Adr : TIoAdr;
  Cmd_Adr  : TIoAdr;
  IobErr   : TMilErr;
  RdData   : Word;
  S_Base   : Byte;
  Off_DevNr: Byte;
  Bit_1,Bit_2 : Boolean;

 begin
   Cursor (False);
   Set_Text_Win;                                     {Bildschirm in 2 HÑlften}
   TextColor(Brown);
   GotoXY(Off_Left,Z_Titel);          Write('NUM');
   GotoXY(Off_Left+Off_Dev,Z_Titel);  Write('GERéT');
   GotoXY(Off_Left+Off_Txt,Z_Titel);  Write('ORT');
   GotoXY(Off_Left+Off_Bt0,Z_Titel);  Write('ZUSTAND');

   GotoXY(Off_Right,Z_Titel);         Write('NUM');
   GotoXY(Off_Right+Off_Dev,Z_Titel); Write('GERéT');
   GotoXY(Off_Right+Off_Txt,Z_Titel); Write('ORT');
   GotoXY(Off_Right+Off_Bt0,Z_Titel); Write('ZUSTAND');
   GotoXY(Off_Left,Z_UScore);
   Write('---------------------------------------------------------------------');
   TextColor(Black);

   if DevNr <= (DevMax_Stat div 2)  then              {DevNr beginnt bei 1}
    begin
     Off_DevNr := DevNr;
     S_Base    := Off_Left
    end
   else
    begin
     Off_DevNr := DevNr-(DevMax_Stat div 2);
     S_Base    := Off_Right;
    end;

   GotoXY(S_Base,Z_Base+Off_DevNr); Write(DevNr);
   GotoXY(S_Base+Off_Dev,Z_Base+Off_DevNr); Write(Dev[DevNr].Dv);
   GotoXY(S_Base+Off_Txt,Z_Base+Off_DevNr); Write(Dev[DevNr].Txt);

   Stat_Adr.IfcAdr := Ifc_Nr;
   Stat_Adr.IoCard := Dev[DevNr].Adr;   {fÅr den Status gibt es zwei Adressen}
   Stat_Adr.IoSub  := Dev[DevNr].Sta_Sub;
   Mil.Rd_IoBus (RdData, Stat_Adr, IobErr);                  {Status nur byteweise}

{$IFDEF Test}
   IOBERR := No_Err;  { Io_Adr; }
   RDDATA := $55;     {testweise}
{$ENDIF}

   if IobErr <> No_err then
     begin
      Set_Color_Alarm;
      GotoXY(S_Base+Off_Bt0,Z_Base+Off_DevNr); Write('Read Error');
      Set_Color_Norm;
    end
   else
    begin                     {Normale Bit-Belegung: Info ist in "0" und "1"}   {kein Lesefehler}
      GotoXY(S_Base+Off_Bt0,Z_Base+Off_DevNr);               {Clear Info}
      Write (Clr_Text);

      if (Dev[DevNr].Sta_Pro = N) then
       begin
        if BitTst(RdData,Dev[DevNr].Sta_BitNr) then
         begin                                          {Bit = 1: Stîrung}
           GotoXY(S_Base+Off_Bt1,Z_Base+Off_DevNr);
           Set_Color_Alarm;
           Write(Dev[DevNr].B1);
           Set_Color_Norm;
         end
        else
         begin
           GotoXY(S_Base+Off_Bt0,Z_Base+Off_DevNr);     {Bit = 0: ok}
           Set_Color_OK;
           Write(Dev[DevNr].B0);
         end;
       end; {if N}

         {bei Ventilen ist Info "Auf" u. "Zu" auf zwei Bits verteilt!!}
      if (Dev[DevNr].Sta_Pro = V) then
       begin
        Bit_1 := False;
        Bit_2 := False;
        if BitTst(RdData,Dev[DevNr].Sta_BitNr + 0) then
          Bit_1 := True;                                       {1. Bit = 1}
        if BitTst(RdData,Dev[DevNr].Sta_BitNr + 1) then
          Bit_2 := True;

        GotoXY(S_Base+Off_Bt0,Z_Base+Off_DevNr);
        Write(Clr_Text);

        {Ventile undefin. falls sie gerade am Fahren sind: dauert ca. 100 ms?}
        if (Bit_1 and Bit_2) or ((not Bit_1) and (not Bit_2)) then
          begin
           GotoXY(S_Base+Off_Bt0,Z_Base+Off_DevNr);
           Set_Color_Alarm;
           Write('undef.');
           Set_Color_Norm;
          end
        else
          begin
           if not Bit_1 then                           {1. Bit = 0}
            begin                                      {Bit ist nullaktiv}
             GotoXY(S_Base+Off_Bt0,Z_Base+Off_DevNr);
             TextColor(Yellow);
             Write(Dev[DevNr].B0);                     {Text B0}
            end;

           if not Bit_2 then
            begin
             GotoXY(S_Base+Off_Bt1,Z_Base+Off_DevNr);  {2. Bit = 0}
             TextColor(Yellow);
             Write(Dev[DevNr].B1);                                   {Text B1}
            end;
          end;
      end; {if V}
    end;  {if IOb-Err}
 end; {DevStatDisp}


procedure DevStatDisp_Soll (Z_Soll: Byte);
 const
   Z_Base   = 4;
   Z_Titel  = Z_Base -1;
   Z_Uscore = Z_Base;

   Off_Left = 5;    {Linke HÑlfte}
   Off_Right= 45;   {Rechte HÑlfte}
   Off_Dev  = 5;
   Off_Txt  = 13;
   Off_Bt0  = 24;
   Off_Bt1  = 28;
   Clr_Text = '          ';
var
  Stat_Adr : TIoAdr;
  Cmd_Adr  : TIoAdr;
  IobErr   : TMilErr;
  RdData   : Word;
  S_Base   : Byte;
  Off_DevNr: Byte;
  Bit_1,Bit_2 : Boolean;
  I        : Byte;
  DevNr    : Byte;

 begin
   Cursor (False);
   Set_Text_Win;                                     {Bildschirm in 2 HÑlften}
   TextColor(Brown);
   GotoXY(Off_Left+15,Z_Titel-1);
   Write ('SOLL-STATUS fÅr ANLAGEN-ZUSTAND NR: '); Textcolor(White);
   Write (Z_Soll);

 for I := 1 to DevMax_Cmd do
  begin
   DevNr := I;
   TextColor(Brown);
   GotoXY(Off_Left,Z_Titel);          Write('NUM');
   GotoXY(Off_Left+Off_Dev,Z_Titel);  Write('GERéT');
   GotoXY(Off_Left+Off_Txt,Z_Titel);  Write('ORT');
   GotoXY(Off_Left+Off_Bt0,Z_Titel);  Write('ZUSTAND');

   GotoXY(Off_Right,Z_Titel);         Write('NUM');
   GotoXY(Off_Right+Off_Dev,Z_Titel); Write('GERéT');
   GotoXY(Off_Right+Off_Txt,Z_Titel); Write('ORT');
   GotoXY(Off_Right+Off_Bt0,Z_Titel); Write('ZUSTAND');
   GotoXY(Off_Left,Z_UScore);
   Write('---------------------------------------------------------------------');
   TextColor(Black);

   if DevNr <= (DevMax_Stat div 2)  then              {DevNr beginnt bei 1}
    begin
     Off_DevNr := DevNr;
     S_Base    := Off_Left
    end
   else
    begin
     Off_DevNr := DevNr-(DevMax_Stat div 2);
     S_Base    := Off_Right;
    end;

   GotoXY(S_Base,Z_Base+Off_DevNr); Write(DevNr);
   GotoXY(S_Base+Off_Dev,Z_Base+Off_DevNr); Write(Dev[DevNr].Dv);
   GotoXY(S_Base+Off_Txt,Z_Base+Off_DevNr); Write(Dev[DevNr].Txt);

      GotoXY(S_Base+Off_Bt0,Z_Base+Off_DevNr);               {Clear Info}
      Write (Clr_Text);

        if Zustnd[Z_Soll][I] = 0  then
         begin                                          {Bit = 1: Stîrung}
           GotoXY(S_Base+Off_Bt1,Z_Base+Off_DevNr);
           Set_Color_OK;
           Write(Dev[DevNr].B1);
           Set_Color_Norm;
         end
        else
         begin
           GotoXY(S_Base+Off_Bt0,Z_Base+Off_DevNr);     {Bit = 0: ok}
           Set_Color_OK;
           Write(Dev[DevNr].B0);
           Set_Color_Norm;
         end;
  end; { for I}
 end; {DevStatDisp_Soll}



procedure Gas_Dev_Disp;
  const Wait_Time = 1000;
  var   Life_Mode  : TLife_XY;
  begin
   Ini_Text_Win;
   Life_Mode.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
   Life_Mode.PosX    := 02;
   Life_Mode.PosY    := 01;
   Life_Mode.Time    := Life_Time_Slow;
   Life_Mode.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}

   Cursor (False);
   Std_Msg;
   repeat
    repeat
      for I := 1 to DevMax_Stat do DevStatDisp(I);
      Life_Sign_XY (Life_Mode);
    until KeyPressed or (Ch = ' ');
    if Ch = ' ' then
      begin
       Std_Msg;
       repeat until KeyPressed;
      end;
    Ch := ReadKey;
   until Ch in ['x','X'];
   Cursor (True);
 end; {Gas-Dev_Disp}


procedure Rd_Adc;
 const
     S_Hex = 47;
     S_Bit = 47;
     Z_Hex = 11;
     Z_Bit = Z_Hex+2;
     Z_MSB = Z_Bit+1;

 var A       : Word;
     Adr     : TIoAdr;
     IobErr  : TMilErr;
     RdData  : Word;
     WrData  : Word;
     Mil_Timout : Boolean;

     Transf_Cnt: LongInt;
     Error_Cnt : LongInt;
     Timout_Cnt: LongInt;
     Timout_Rd : LongInt;
     Timout_Wr : LongInt;
     Bit16_Strg: Str19;

  begin
   Ini_Text_Win;
   Ch := ' ';
   Transf_Cnt := 0;
   Error_Cnt  := 0;
   Timout_Wr  := 0;
   Timout_Rd  := 0;

   Adr.IfcAdr := Ifc_Nr;
   Adr.IoCard := IoA_Adc;

   Mil.Ifc_Online (Ifc_Nr, Ret_Adr, OnlineErr);
   if OnlineErr <> NoErr then
    begin
      Ini_Err_Win;
      Write ('ERROR: IFC-Karte [', Hex_Byte(Ifc_Nr), '] nicht Online!!      Weiter mit beliebiger Taste');
      ReadKey;
      Exit;
    end;

   if not loop then Adr.IoSub := Iob_Ask_SubAdr(IoA_Stat);

   Ini_Text_Win;
   GotoXY(06,08);  Writeln('Iob-Adr[Hex]:       ', Hex_Byte(Adr.IoCard));
   GotoXY(6, 11);
   writeln('Transfr_Cnt:              Read-Data [H]:                ');
   GotoXY(22,12);  writeln('^  ^');
   GotoXY(06, Z_Bit);
   writeln('                                  [Bit]:                ');
   GotoXY(S_Bit, Z_Msb);  write('MSB             LSB');
   GotoXY(53,11);  write('Timeout:');
   GotoXY(61,11);  write(timout_wr:10);
   Show_IFC (30,5);

   Ini_Msg_Win;
   Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
   A := 0;
   if Loop then                                     {Alle Subadresssen}
    begin
      repeat
       repeat
         Set_Text_win;
         Mil_Timout := False;
         Transf_Cnt := Transf_Cnt+ 1;
         GotoXY(18,11);  Write(Transf_Cnt:10);
         Adr.IoSub := A;
         GotoXY(06,09);  Writeln('Sub-Adr     :', Adr.IoSub:9);

         Mil.Rd_IoBus (RdData, Adr, IobErr); {Dummy Read: Start ADC-Konversion}
         Mil.Rd_IoBus (RdData, Adr, IobErr);
         if IobErr <> No_err then
           begin
            Mil_Timout := True;
            Timout_Wr:= Timout_Wr +1;
            TextColor(Red);
            GotoXY(61,11);  write(timout_wr:10);
            TextColor(Black);
           end
         else
          begin
            GotoXY(S_Hex, Z_Hex);  Write(Hex_Word(RdData));
            Hex_Bin_Str (RdData, Bit16_Strg);
            GotoXY(S_Bit, Z_Bit);  write(Bit16_Strg);
          end;

          A := A + 1;
          if (A > Kanal_Max - 1) then A := 0;
          Mil.Timer2_Wait(Wait_Read);
       until KeyPressed or (Ch = ' ');
       if Ch = ' ' then
         begin
          Ini_Msg_Win;
          Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
          repeat until KeyPressed;
         end;
       Ch := ReadKey;
      until Ch in ['x','X'];
  end {if loop= yes}
 else
  begin                                      {nur eine Subadresse}
   repeat
    repeat
      Set_Text_win;
      Mil_Timout := False;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(06,09);  Writeln('Sub-Adr     :', Adr.IoSub:9);
      GotoXY(18,11);  Write(Transf_Cnt:10);

      Mil.Rd_IoBus (RdData, Adr, IobErr);   {Dummy Read: Start ADC-Konversion}
      Mil.Rd_IoBus (RdData, Adr, IobErr);
      if IobErr <> No_err then
       begin
        Mil_Timout := True;
        Timout_Wr:= Timout_Wr +1;
        TextColor(Red);
        GotoXY(61,11);  write(timout_wr:10);
        TextColor(Black);
       end
      else
       begin
         GotoXY(S_Hex, Z_Hex);  Write(Hex_Word(RdData));
         Hex_Bin_Str (RdData, Bit16_Strg);
         GotoXY(S_Bit, Z_Bit);  write(Bit16_Strg);
       end;
    until KeyPressed or (Ch = ' ');
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyPressed;
      end;
    Ch := ReadKey;
   until Ch in ['x','X'];
  end; {if loop = no}
end; {RdAdc}

procedure DevChange_Hand (Num: Byte);
 var
  Stat_Adr : TIoAdr;
  Cmd_Adr  : TIoAdr;
  IobErr   : TMilErr;
  RdData   : Word;
  CmdData  : Word;
  Bit_1,Bit_2: Boolean;

 begin
   Set_Text_Win;
   Cmd_Adr.IfcAdr := Ifc_Nr;
   Cmd_Adr.IoCard := IoA_Cmd;
   Cmd_Adr.IoSub  := Dev[Num].Cmd_Sub;

   Stat_Adr.IfcAdr:= Ifc_Nr;                            {Adresse MIL-IFC}
   Stat_Adr.IoCard:= Dev[Num].Adr;                      {Adresse IOB-Status}
   Stat_Adr.IoSub := Dev[Num].Sta_Sub;                  {Sub-Adr- Status}

   Mil.Rd_IoBus (RdData, Stat_Adr, IobErr);             {Status nur byteweise}

{$IFDEF Test}
   RdData := $55;
  { IobErr := Rd_To;}
{$ENDIF}
   if IobErr <> No_err then
    begin
      Ini_Err_Win;
      Write('Status Read Error! GerÑt [',Dev[Num].Dv,']                         Weiter mit <CR>');
      repeat until KeyPressed;
    end
   else
    begin                                                    {kein Lesefehler}
     Ini_Msg_Win;
     Write('Status GerÑt [',Dev[Num].Dv,']  = ');
     Set_Text_Win;
     if (Dev[Num].Sta_Pro = N) then                      {Normale Bitbelegung}
      begin
       if BitTst(RdData,Dev[Num].Sta_BitNr) then
          Write(Dev[Num].B1)
       else
          Write(Dev[Num].B0);
      end; {if N}

        {bei Ventilen ist Info "Auf" u. "Zu" auf zwei Bits verteilt!!}
     if (Dev[Num].Sta_Pro = V) then
      begin
       Bit_1 := False;
       Bit_2 := False;
       Ini_Msg_Win;
       Write('Status GerÑt [',Dev[Num].Dv,']  = ');

       if BitTst(RdData,Dev[Num].Sta_BitNr + 0) then
        begin
         Bit_1 := True;
        end;
       if BitTst(RdData,Dev[Num].Sta_BitNr + 1) then
        begin
         Bit_2 := True;
        end;

       if (Bit_1 and Bit_2) or ((not Bit_1) and (not Bit_2)) then
         begin
          Ini_Err_Win;
          Write(' Zustand undefiniert!                                       Weiter mit <CR>');
          repeat until KeyPressed;
          Exit;
         end
       else
         begin
          TextColor(Red);
          if not Bit_1 then  Write(Dev[Num].B0);     {1. Bit = 0}  {Text B0}
          if not Bit_2 then  Write(Dev[Num].B1);     {2. Bit = 0}  {Text B1}
          TextColor(Yellow);
          Write('          éndern? [J/N] : ');
         end;
      end; {if V}

     Ch := ReadKey;
     if Ch in ['j','J'] then
      begin
        Mil.Rd_IoBus (RdData, Cmd_Adr, IobErr);             {Cmd-Status lesen}
        Ini_Msg_Win;
        if IobErr <> No_err then
         begin
          Ini_Err_Win;
          Write('Command Read Error! GerÑt [',Dev[Num].Dv,']');
          Write('              Weiter mit <CR>');
          repeat until KeyPressed;
         end
        else
         begin  {aktueller Command-Status > kein Lesefehler: Bit invertieren}
          CmdData := BitInv(RdData,Dev[Num].Cmd_BitNr);
          Mil.Wr_IoBus (CmdData, Cmd_Adr, IobErr);          {Befehl an Device}
          if IobErr <> No_err then
           begin
            Ini_Err_Win;
            Write('Command Write Error! GerÑt [',Dev[Num].Dv,']');
            Write('              Weiter mit <CR>');
            repeat until KeyPressed;
           end;
       end; {if Iob_Err}
      end; {if J}
    end;
 end; {DevChange_Hand}


procedure Gas_Dev_Change;
 label 1;
 var Num : Byte;
    Hand : Boolean;
    Hand_Err: TMilErr;
    Life_Mode  : TLife_XY;
  begin
   Life_Mode.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
   Life_Mode.PosX    := 02;
   Life_Mode.PosY    := 01;
   Life_Mode.Time    := Life_Time_Slow;
   Life_Mode.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}

   Ini_Msg_Win;
   Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,'); TextColor(Red);
   Write(' éndern mit <S>'); TextColor(Yellow); Write(' , Ende mit [X]');
   Ini_Text_Win;

   repeat
    repeat
     for I := 1 to DevMax_Stat do DevStatDisp(I);
     Life_Sign_XY (Life_Mode);
    until KeyPressed or (Ch = ' ');

    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,'); TextColor(Red);
       Write(' éndern mit <S>'); TextColor(Yellow); Write(' , Ende mit [X]');
       repeat until KeyPressed;
      end;

    if KeyPressed then Ch := ReadKey;
    if Ch in ['s','S'] then
     begin
      Test_Hand (Hand,Hand_Err);
      if Hand_Err <> No_Err then
       begin
        Ini_Err_Win;
        Write ('Error: Stellung Rechner/Hand nicht lesbar! Weiter mit beliebiger Taste.');
        repeat until Keypressed;
        Exit;
       end;
{$IFDEF Test}
  hand := False;
{$ENDIF}
      if hand then                                {keine Aktion, falls auf Hand}
        begin
         Ini_Err_Win;
         Write('Error: Keine Aktion mîglich, da Bedientafel auf Hand!');
         Write('           Weiter mit <CR>');
         Repeat until KeyPressed;
         Ini_Msg_Win;
         Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,'); TextColor(Red);
         Write(' éndern mit <S>'); TextColor(Yellow); Write(' , Ende mit [X]');
        end
      else
        begin                                        {Bedientafel auf Rechner}
          Ini_Msg_Win;
          Write('Welches GerÑt Ñndern? Bitte Nummer (NUM) eingeben oder [Q]uit: ');
          {$I-}                    {Fehleingabe zulassen: Compiler-Check ausschalten}
          Readln (Num);
          {$I+}
          if (IoResult = 0) then              {Fehler selber abfangen!}
           begin
             if Num in [1..DevMax_Cmd+1] then  {wegen Ventil 23: +1}
               begin
                DevChange_Hand (Num);
                Ini_Msg_Win;
                Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,'); TextColor(Red);
                Write(' éndern mit <S>'); TextColor(Yellow); Write(' , Ende mit [X]');
               end
             else
               begin
                Ini_Err_Win;
                Write('Nummer nicht erlaubt! Weiter mit <Space>! ');
               end;
            end {if I/O Result}
           else
            begin
              Ini_Msg_Win;
              Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,'); TextColor(Red);
              Write(' éndern mit <S>'); TextColor(Yellow); Write(' , Ende mit [X]');
            end; {if I/O Result}
        end; {if hand}
     end;
   until Ch in ['x','X'];
1:
 end; {Gas-Dev_Change}


function Dev_Status_Valid: Boolean;  {PrÅft alle Devices auf gÅltigen Status}
{ Der Status von Ventilen oder Pumpen wird Åber Endlagenkontakte gemeldet.
  Wird ein Ventil betÑtigt, dauert es u. U. Sekunden, bis ein gÅltiger neuer
  Status gemeldet wird. In dieser Zeit ist der Betriebszustand undefiniert!
}
 label 1;
 var DevNr      : Word;
    Bit_1,Bit_2 : Boolean;
    Stat_Adr    : TIoAdr;
    IobErr      : TMilErr;
    RdData      : Word;
 begin
   Stat_Adr.IfcAdr  := Ifc_Nr;                               {Adresse MIL-IFC}
   Dev_Status_Valid := True;                                         {Default}
   for  DevNr := 1 to DevMax_Cmd do                     {Alle GerÑte abfragen}
    begin
     Stat_Adr.IoCard:= Dev[DevNr].Adr;                    {Adresse IOB-Status}
     Stat_Adr.IoSub := Dev[DevNr].Sta_Sub;                   {Sub-Adr- Status}
     Mil.Rd_IoBus (RdData, Stat_Adr, IobErr);           {Status nur byteweise}
     if IobErr <> No_Err then
      begin
        Dev_Status_Valid := False;
        goto 1;                      {abbrechen, sobald ein Fehler auftritt!!}
      end
     else
      begin                      {RdData ok: PrÅfen, ob Status-Bits eindeutig}
       if (Dev[DevNr].Sta_Pro = V) then
        begin   {bei Ventilen ist Info "Auf" u. "Zu" auf zwei Bits verteilt!!}
         Bit_1 := False;
         Bit_2 := False;
         if BitTst(RdData,Dev[DevNr].Sta_BitNr + 0) then
           Bit_1 := True;                                         {1. Bit = 1}
         if BitTst(RdData,Dev[DevNr].Sta_BitNr + 1) then
           Bit_2 := True;                                         {2. Bit = 1}
         if (Bit_1 and Bit_2) or ((not Bit_1) and (not Bit_2)) then
          begin                       {Error, falls beide gleiche Werte haben}
           Dev_Status_Valid := False;
           goto 1;                   {abbrechen, sobald ein Fehler auftritt!!}
          end;
        end;
      end;  {if IobErr}
    end; {for}
1:
{$IFDEF Test}
  Dev_Status_Valid := True;
{$ENDIF}
 end; {Dev_Status_Valid}


procedure Check_Status_Valid;
 label 99;
 var Transf_Cnt : LongInt;
     OnlineErr  : TOnlineErr;
     RetAdr     : Byte;

 procedure Test_Status;
  begin
   Mil.Ifc_Online (Ifc_Nr, RetAdr, OnlineErr);
   if OnlineErr = NoErr then
     begin
       Std_Msg;
       Set_Text_Win;
       if  Dev_Status_Valid then
        begin
          TextBackground(Green);
          TextColor(Yellow);
          GotoXY(20,14);  Write('Status der GerÑte ist   eindeutig!');
        end
       else
        begin
          TextBackground(Red);
          TextColor(Yellow);
          GotoXY(20,14);  Write('Status der GerÑte nicht eindeutig!');
        end;
       Set_Color_Norm;
      end
     else
      begin
       Ini_Err_Win;
       Write ('ERROR: IFK-Karte ['); TextColor(White); Write(Hex_Byte(Ifc_Test_Nr));
       TextColor(Red); Write('H] Offline!!       Weiter mit <Space>, <CR>  oder E[X]it:');
      end;
     Set_Text_Win;
     Transf_Cnt := Transf_Cnt+ 1;
     GotoXY(18,11);  Write(Transf_Cnt:10);
     Mil.Timer2_Wait(Wait_Read);          {Read-Time abwarten; Basis 10 us}
  end; {Test_Status}


 begin
   Ch := ' ';
   Transf_Cnt := 0;
   Ini_Text_Win;     TextColor(Brown);
   GotoXY(30, 06);
   write('PrÅfung GerÑte-Status');
   GotoXY(30, 07);
   write('=====================');
   GotoXY(6, 10);
   write('IFK-Adr [H]: '); TextColor(White);  Write (Hex_Byte(Ifc_Test_Nr));
   TextColor(Brown); GotoXY(6, 11);
   writeln('Transfr_Cnt: ');
   GotoXY(22,12);  writeln('^  ^');
   GotoXY(06,14);  Write('Resultat   :'); TextColor(Black);

   Cursor(False);
   Std_Msg;
   Single_Step := False;

   repeat
    if Ch = ' ' then
     begin
      Std_Msg;
      Single_Step := True;
      Test_Status;
      repeat until KeyEPressed;
      Ch := NewReadKey;
     end;

    if Ch = #13 then Single_Step := False;

    if not Single_Step then
     begin
       Test_Status;
     end;

   if KeyEPressed then Ch := NewReadKey;
  until Ch in ['x','X'];
99:  Cursor(True);
 end; {Check_Status_Valid}


{procedure Find_Zustand (var Ist_Zustand: TZuMuster; var Z_Nr:Word);}
procedure Find_Zustand (Ist_Zustand: TZuMuster; var Z_Nr: Word);
 label 1;            {Vergleiche den Istzustand mit allen erlaubten ZustÑnden}
 var N,I : Word;
     Z   : TZuMuster;
     Match_Count : Word;
 begin
   Z_Nr  := 0;                                 {Default: Zustand nicht gÅltig}
   for N := 1 to Zustand_Max do     {vergleiche mit allen erlaubten ZustÑnden}
    begin
      Z :=  Zustnd[N];                                {hole Zustand aus Array}
      Match_Count := 0;
      for I := 1 to DevMax_Cmd do
       begin
         if Z[I] = Ist_Zustand[I] then  {Vergleich jedes GerÑt bzw. jedes Bit}
           Match_Count := Match_Count + 1;
       end; {for I}
      if Match_Count = DevMax_Cmd then       {Betriebszustand ist definiert!!}
        begin
         Z_Nr := N;
         goto 1;
        end;
    end; {for N}
1:
{$IFDEF Test}
  Z_Nr  := 2;
{$ENDIF}
 end; {Find_Zustand}


procedure Rd_Zustand (var Zustand: TZuMuster; var Rd_Err: TMilErr);
          {Trage den Status der Devices in Variable Zustand ein}
 label 1;
 var
  Dev_Num : Word;
  State   : TBit;
  Stat_Adr : TIoAdr;
  IobErr  : TMilErr;
  RdData  : Word;
  Bit_1,Bit_2 : Boolean;
 begin
  Rd_Err := No_Err;
  Stat_Adr.IfcAdr:= Ifc_Nr;                                 {Adresse MIL-IFC}
  if not Dev_Status_Valid then  {PrÅfe, ob fÅr alle Devices eindeutiger Status}
    Rd_Err:= Rd_To
  else
   begin                                                     {Status eindeutig}
    for  Dev_Num := 1 to DevMax_Cmd do                   {Alle GerÑte abfragen}
     begin
      Stat_Adr.IoCard:= Dev[Dev_Num].Adr;                      {Adresse IOB-Status}
      Stat_Adr.IoSub := Dev[Dev_Num].Sta_Sub;                  {Sub-Adr- Status}
      Mil.Rd_IoBus (RdData, Stat_Adr, IobErr);             {Status nur byteweise}
      if IobErr <> No_Err then
       begin
         Rd_Err:= Rd_To;
         goto 1;
       end;

      Bit_1 := False; Bit_2 := False;
      if BitTst(RdData,Dev[Dev_Num].Sta_BitNr + 0) then Bit_1 := True;
      if BitTst(RdData,Dev[Dev_Num].Sta_BitNr + 1) then Bit_2 := True;
                       {vorsichtshalber nochmals prÅfen, ob Zustand eindeutig}
      if (Bit_1 and Bit_2) or ((not Bit_1) and (not Bit_2)) then
       begin
         Rd_Err:= Rd_To;
         goto 1;
       end;

      {aktiv low: Bit_1 = Auf, Bit_2 = Zu;  Umsetzung 2-Bit auf 1-Bit-Info}
      if not Bit_1 then
       Zustand[Dev_Num] := 1       {Im Zustandsarray bedeutet 1=auf, 0=zu}
      else
       Zustand[Dev_Num] := 0;      {Im Zustandsarray bedeutet 1=auf, 0=zu}
     end; {for}
   end; {if Dev_Status_Valid}
 1:
{$IFDEF Test}
   Zustand := Test_Zustand;
   Rd_Err  := No_Err;
{$ENDIF}

 end; {Rd_Zustand}


procedure Check_Betriebszustand;
 var Transf_Cnt : LongInt;
     Z          : TZuMuster;
     Z_Num      : WORD;
     Rd_Err     : TMilErr;

 begin
   Ch := ' ';
   Transf_Cnt := 0;
   Ini_Text_Win;
   TextColor(Brown);
   GotoXY(30, 06);
   write('PrÅfung Betriebszustand');
   GotoXY(30, 07);
   write('=======================');
   TextColor (Black);

   GotoXY(6, 11);
   writeln('Transfr_Cnt: ');
   GotoXY(22,12);  writeln('^  ^');
   GotoXY(06,14);  Write('Resultat   :');

   Ini_Msg_Win;
   Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');
   repeat
    repeat
      Set_Text_win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(18,11);  Write(Transf_Cnt:10);

      Rd_Zustand (Z, Rd_Err);
      if Rd_Err <> No_Err then
       begin
         TextBackground(Red);
         TextColor(Yellow);
         GotoXY(20,14);      Write('Error: Zustand nicht lesbar!');
       end
      else
       begin
         Find_Zustand (Z, Z_Num);
         if Z_Num = 0 then
           begin
             TextBackground(Red);
             TextColor(Yellow);
             GotoXY(20,14);  Write('Error: Zustand undefiniert !');
           end
         else
           begin
             TextBackground(Green); TextColor(Yellow);
             GotoXY(20,14);  Write('Der aktuelle Zustand=    ',Z_Num:2);
             TextColor(Blue);
             Write('  [', Zustnd_TxtAry[Z_Num], ']');
             TextColor(Black);
           end;
       end;

      Set_Color_Norm;
      Mil.Timer2_Wait(10000);
    until KeyPressed or (Ch = ' ');
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyPressed;
      end;
    Ch := ReadKey;
   until Ch in ['x','X'];
 end; {Check_Betriebszustand}


procedure Displ_Diagram (Z_Num: Byte; Z_Mode: TZ_Mode); {Zustands-Byte, -Mode}
 var Ch : Char;
     N,I: Word;
 const
  Z_Base       = 2;
  Z_Aus        = Z_Base+0;
  Z_Gas_Stdby  = Z_Base+2;
  Z_Vorb       = Z_Base+4;
  Z_Fill_G     = Z_Base+6;
  Z_Betr_ORein = Z_Base+8;
  Z_Fill_Ga    = Z_Base+11;
  Z_Fill_Gb    = Z_Base+13;
  Z_Betr_Int   = Z_Base+15;
  Z_Betr_mRein = Z_Base+17;
  Z_Ent_20b    = Z_Base+17;
  Z_Ent_1b     = Z_Base+19;
  Z_Legend     = Z_Base+20;

  Z_Arw_Aus_Stndby    = Z_Base+1;
  Z_Arw_Stndby_Abpump = Z_Gas_Stdby+1;
  Z_Arw_Vorb_Fill     = Z_Vorb+1;
  Z_Arw_Fill_Rein     = Z_Fill_G+1;
  Z_Arw_Int_Betr      = Z_Betr_Int+1;
  Z_Arw_Gasb_Int      = Z_Fill_Gb+1;
  Z_Arw_Stdby_Edelg   = Z_Fill_Ga-1;

  S_Aus       = 10;
  S_L         = 6;
  S_M         = 33;
  S_R         = 55;

  Double_Arrow = $17;    {graphische Zeichen}
  Up_Arrow     = $18;
  Down_Arrow   = $19;
  Right_Arrow  = $1A;
  Line_Ver     = $B3;
  Line_Hor     = $C4;
  Angle_0      = $C0;
  Angle_90     = $DA;
  Angle_180    = $D9;
  Angle_270    = $BF;
  Angle_Cross  = $C1;

 type
  TTxt = record
          X   : Byte;
          Y   : Byte;
          Text: String[80];
         end;
  TTxtAry = array [1..Zustand_Max] of TTxt;

 const
  Txt: TTxtAry =
(
(X: S_Aus; Y: Z_Aus;        Text:'1                        ANLAGE AUS                         '),
(X: S_L;   Y: Z_Gas_Stdby;  Text:'2                Standby ohne Gas              '),
(X: S_M;   Y: Z_Vorb ;      Text:'3      Abpumpen     '),
(X: S_R;   Y: Z_Gas_Stdby;  Text:'4  Standby mit Gas  '),
(X: S_L;   Y: Z_Vorb;       Text:'5  Vorber. o. Reinig'),
(X: S_L;   Y: Z_Fill_G;     Text:'6    FÅllen Gas     '),
(X: S_L;   Y: Z_Betr_oRein; Text:'7  Betrieb o. Reinig'),
(X: S_L;   Y: Z_Fill_Ga;    Text:'8    FÅllen Gas A   '),
(X: S_L;   Y: Z_Fill_Gb;    Text:'9    FÅllen Gas B   '),
(X: S_L;   Y: Z_Betr_Int;   Text:'10                  Interner Betrieb mit Reinigung                   '),
(X: S_M;   Y: Z_Betr_mRein; Text:'11 Betrieb m. Reinig'),
(X: S_M;   Y: Z_Fill_Ga;    Text:'12  FÅllen Edelgas  '),
(X: S_L;   Y: Z_Ent_20b;    Text:'13  Entnahme 20 bar '),
(X: S_L;   Y: Z_Ent_1b;     Text:'14  Entnahme  1 bar ')
);

  procedure Set_Color_Norm;
   begin
    TextBackground(White);
    TextColor(Black);
   end;

  procedure Set_Color_Arrow;
   begin
    TextBackground(White);
    TextColor(Yellow);
   end;

  procedure Set_Color_Aktiv;
   begin
    TextBackground(Green);
    TextColor(Red);
   end;

  procedure Set_Color_Inaktiv;
   begin
    TextBackground(Blue);
    TextColor(White);
   end;

  procedure Set_Color_Transfer;
   begin
    TextBackground(Cyan);
    TextColor(Blink);
   end;

  procedure Displ_Text (Z_Nr: Byte);     {Z_Nr = Zustandsnummer}
   begin
     GotoXY(Txt[Z_Nr].X, Txt[Z_Nr].Y);
     Write(Txt[Z_Nr].Text);
   end;

 begin
   if Z_Num = 0 then Exit;     {Unerlaubte Nummer}
   Cursor(False);
   Ini_Headl_Win;
   Write(head_line);
   Ini_Text_Win;
   Set_Color_Inaktiv;
   for N := 1 to Zustand_Max do
    begin
     Displ_Text (N);
    end;

{
   GotoXY(S_L, Z_Vorb      ); Write('5  Vorber. o. Reinig');
   GotoXY(S_L, Z_Fill_G    ); Write('6    FÅllen Gas     ');
   GotoXY(S_L, Z_Betr_oRein); Write('7  Betrieb o. Reinig');
   GotoXY(S_L, Z_Fill_Ga   ); Write('8    FÅllen Gas A   ');
   GotoXY(S_M, Z_Fill_Ga   ); Write('12  FÅllen Edelgas  ');

   GotoXY(S_L, Z_Fill_Gb   ); Write('9    FÅllen Gas B   ');
   GotoXY(S_L, Z_Betr_Int  );
   Write('10                  Interner Betrieb mit Reinigung                   ');
   GotoXY(S_M, Z_Betr_mRein); Write('11 Betrieb m. Reinig');
   GotoXY(S_L, Z_Ent_20b   ); Write('13  Entnahme 20 bar ');
   GotoXY(S_L, Z_Ent_1b    ); Write('14  Entnahme  1 bar ');
}
   Set_Color_Norm;
   GotoXY(65, Z_Legend-1);
   Write('Legende: ');

   GotoXY(59, Z_Legend);
   Set_Color_Aktiv;
   Write('Aktiv');

   TextBackground(Cyan);
   TextColor(Black);
   Write('Transfer');

   Set_Color_Inaktiv;
   Write('Inaktiv ');

   {Verbindungslinien und Pfeile (Arrow)}
   Set_Color_Arrow;
   Ch := chr(Double_Arrow);
   GotoXY(29, Z_Arw_Aus_Stndby);    Write(Ch);
   GotoXY(65, Z_Arw_Aus_Stndby);    Write(Ch);
   GotoXY(16, Z_Arw_Stndby_Abpump); Write(Ch);
   GotoXY(43, Z_Arw_Stndby_Abpump); Write(Ch);
   GotoXY(16, Z_Arw_Fill_Rein);     Write(Ch);
   GotoXY(16, Z_Arw_Vorb_Fill);     Write(Ch);
   GotoXY(43, Z_Arw_Int_Betr);      Write(Ch);

   Ch := chr(Up_Arrow);
    GotoXY(65, Z_Arw_Stndby_Abpump); Write(Ch);

   Ch := chr(Right_Arrow);
    GotoXY(S_L-1,Z_Gas_Stdby);       Write(Ch);

   Ch := chr(Down_Arrow);
    GotoXY(16, Z_Arw_Stdby_Edelg);   Write(Ch);
    GotoXY(43, Z_Arw_Stdby_Edelg);   Write(Ch);
    GotoXY(65, Z_Arw_Gasb_Int);      Write(Ch);
    GotoXY(16, Z_Arw_Gasb_Int-2);    Write(Ch);
    GotoXY(16, Z_Arw_Gasb_Int);      Write(Ch);
    GotoXY(43, Z_Arw_Gasb_Int);      Write(Ch);
    GotoXY(16, Z_Ent_20b-1);         Write(Ch);
    GotoXY(16, Z_Ent_1b-1);          Write(Ch);

   Ch := chr(Angle_0);
    GotoXY(S_L-2, Z_Ent_1b+1);       Write(Ch);

   Ch := chr(Angle_90);
    GotoXY(S_L-2, Z_Gas_Stdby);      Write(Ch);

   Ch := chr(Angle_180);
    GotoXY(16, Z_Ent_1b+1);          Write(Ch);

   Ch := chr(Angle_Cross);
    GotoXY(29, Z_Arw_Stdby_Edelg-1);   Write(Ch);

   Ch := chr(Line_Ver);
    for I := 1 to 17 do
     begin
      GotoXY(S_L-2, Z_Gas_Stdby+I);  Write(Ch);
     end;
    for I := 1 to 10 do
     begin
      GotoXY(65, Z_Arw_Stndby_Abpump+I); Write(Ch);
     end;
    for I := 0 to 5 do
     begin
      GotoXY(29, Z_Arw_Stndby_Abpump+I); Write(Ch);
     end;
    for I := 0 to 1 do
     begin
      GotoXY(43, Z_Arw_Gasb_Int-2+I);  Write(Ch);
     end;
    GotoXY(65, Z_Arw_Stdby_Edelg);   Write(Ch);
    GotoXY(65, Z_Arw_Stdby_Edelg-1); Write(Ch);

   Ch := chr(Line_Hor);
    for I := 0 to 10 do
     begin
      GotoXY(5+I, Z_Ent_1b+1); Write(Ch);
     end;
    for I := 0 to 11 do
     begin
      GotoXY(17+I, Z_Arw_Stdby_Edelg-1);   Write(Ch);
     end;
    for I := 0 to 12 do
     begin
      GotoXY(30+I, Z_Arw_Stdby_Edelg-1);   Write(Ch);
     end;
   Ch := chr(Angle_270);
      GotoXY(43, Z_Arw_Stdby_Edelg-1);   Write(Ch);
   Ch := chr(Angle_90);
      GotoXY(16, Z_Arw_Stdby_Edelg-1);   Write(Ch);

   case Z_Mode of
    aktiv    : Set_Color_Aktiv;
    inaktiv  : Set_Color_Inaktiv;
    transfer : Set_Color_Transfer;
   end; {case}

   if Z_Num in [1..Zustand_Max] then Displ_Text (Z_Num);
   Cursor(True);
 end; {Displ_Diagram}


procedure Iob_Rd_Cmd;               {Lese Zustand der Command-Bits von IO-Bus}
 const
     S_Hex = 47;
     S_Bit = 47;
     Z_Hex = 11;
     Z_Bit = Z_Hex+2;
     Z_MSB = Z_Bit+1;

 var A       : Word;
     Adr     : TIoAdr;
     IobErr  : TMilErr;
     RdData  : Word;
     WrData  : Word;
     Mil_Timout : Boolean;

     Transf_Cnt: LongInt;
     Error_Cnt : LongInt;
     Timout_Cnt: LongInt;
     Timout_Rd : LongInt;
     Timout_Wr : LongInt;
     Bit16_Strg: Str19;

  begin
   Ini_Text_Win;
   Ch := ' ';
   Transf_Cnt := 0;
   Error_Cnt  := 0;
   Timout_Wr  := 0;
   Timout_Rd  := 0;

   Adr.IfcAdr := Ifc_Nr;
   Mil.Ifc_Online (Ifc_Nr, Ret_Adr, OnlineErr);
   if OnlineErr <> NoErr then
    begin
      Ini_Err_Win;
      Write ('ERROR: IFC-Karte [', Hex_Byte(Ifc_Nr), '] nicht Online!!      Weiter mit beliebiger Taste');
      ReadKey;
      Exit;
    end;

   Adr.IoCard := IoA_Cmd;
   if not loop then Adr.IoSub := Iob_Ask_SubAdr(IoA_Stat);

   Ini_Text_Win;
   GotoXY(06,08);  Writeln('Iob-Adr[Hex]:       ', Hex_Byte(Adr.IoCard));
   GotoXY(6, 11);
   writeln('Transfr_Cnt:              Read-Data [H]:                ');
   GotoXY(22,12);  writeln('^  ^');
   GotoXY(06, Z_Bit);
   writeln('                                  [Bit]:                ');
   GotoXY(S_Bit, Z_Msb);  write('MSB             LSB');

   GotoXY(53,11);  write('Timeout:');
   GotoXY(61,11);  write(timout_wr:10);
   Ini_Msg_Win;
   Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');
   Show_IFC (30,5);

   A := 0;
   if Loop then                                     {Alle Subadresssen}
    begin
      repeat
       repeat
         Set_Text_win;
         Mil_Timout := False;
         Transf_Cnt := Transf_Cnt+ 1;
         GotoXY(18,11);  Write(Transf_Cnt:10);
         Adr.IoSub := A;
         GotoXY(06,09);  Writeln('Sub-Adr     :', Adr.IoSub:9);

         Mil.Rd_IoBus (RdData, Adr, IobErr);
         if IobErr <> No_err then
           begin
            Mil_Timout := True;
            Timout_Wr:= Timout_Wr +1;
            TextColor(Red);
            GotoXY(61,11);  write(timout_wr:10);
            TextColor(Black);
           end
         else
          begin
            GotoXY(S_Hex, Z_Hex);  Write(Hex_Word(RdData));
            Hex_Bin_Str (RdData, Bit16_Strg);
            GotoXY(S_Bit, Z_Bit);  write(Bit16_Strg);
          end;

          A := A + 1;
          if A > 5 then A := 0;
          Mil.Timer2_Wait(Wait_Read);          {Read-Time abwarten; Basis 10 us}
       until KeyPressed or (Ch = ' ');
       if Ch = ' ' then
         begin
          Ini_Msg_Win;
          Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
          repeat until KeyPressed;
         end;
       Ch := ReadKey;
      until Ch in ['x','X'];
  end {if loop= yes}
 else
  begin                                      {nur eine Subadresse}
   repeat
    repeat
      Set_Text_win;
      Mil_Timout := False;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(06,09);  Writeln('Sub-Adr     :', Adr.IoSub:9);
      GotoXY(18,11);  Write(Transf_Cnt:10);

      Mil.Rd_IoBus (RdData, Adr, IobErr);
      if IobErr <> No_err then
       begin
        Mil_Timout := True;
        Timout_Wr:= Timout_Wr +1;
        TextColor(Red);
        GotoXY(61,11);  write(timout_wr:10);
        TextColor(Black);
       end
      else
       begin
         GotoXY(S_Hex, Z_Hex);  Write(Hex_Word(RdData));
         Hex_Bin_Str (RdData, Bit16_Strg);
         GotoXY(S_Bit, Z_Bit);  write(Bit16_Strg);
       end;
    until KeyPressed or (Ch = ' ');
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyPressed;
      end;
    Ch := ReadKey;
   until Ch in ['x','X'];
  end; {if loop = no}
 end; {Iob_Rd_Cmd}


 function Get_Zustand (var ZuStnd_Num : Word): Boolean;
  var
   ZuStnd_Act : TZuMuster;
   Rd_Err     : TMilErr;
 begin
   Get_Zustand := False;
   ZuStnd_Num  := 0;
   Rd_Zustand (ZuStnd_Act, Rd_Err);
   if (Rd_Err = No_Err) then
    begin
     Find_Zustand (ZuStnd_Act, ZuStnd_Num);
     if ZuStnd_Num in [1..Zustand_Max] then Get_Zustand := True;
    end; {Rd_Err = No_Err}

{$IFDEF Test}
 Get_Zustand := True;
 ZuStnd_Num  := 2;
{$ENDIF}
 end; {Get_Zustand }


 function  Check_ZuStnd_Wechsel (New: Word; Old: Word): Boolean;
 {PrÅfe, ob ein Wechsel vom alten zum neuen Zustand erlaubt ist}
 var I : Byte;
 begin
  Check_ZuStnd_Wechsel := False;
  for I := 1 to Trans_Max do
   begin
    if Transition[Old][I] = New then
     begin
       Check_ZuStnd_Wechsel := True;
       Exit;
     end;
   end;
 end; {Check_ZuStnd_Wechsel}


 function Set_All_Dev (New_Zu: TZuMuster): Boolean; {Alle DevMax_Cmd GerÑte auf neuen Zustand einstellen}
 var
  Stat_Adr : TIoAdr;
  Cmd_Adr  : TIoAdr;
  IobErr   : TMilErr;
  RdData   : Word;
  CmdData  : Word;
  RdCmdData: Word;
  Bit_1,Bit_2: Boolean;
  I        : Byte;
  Z        : TZuMuster;      { packed array [1..DevMax_Cmd] of TBit}
  Dev_Ist  : Byte;

 begin
  Set_All_Dev    := False;
  Stat_Adr.IfcAdr:= Ifc_Nr;       {Adresse MIL-IFC   }
  Cmd_Adr.IfcAdr := Ifc_Nr;       {Adresse MIL-IFC   }
  Cmd_Adr.IoCard := IoA_Cmd;      {Adresse IOB-Status}
  Z := New_Zu;

  for I := 1 to DevMax_Cmd do     {I = Dev-Nr}
   begin
    Cmd_Adr.IoSub  := Dev[I].Cmd_Sub;                  {Sub-Adr- Command  }
    Stat_Adr.IoCard:= Dev[I].Adr;                      {Adresse IOB-Status}
    Stat_Adr.IoSub := Dev[I].Sta_Sub;                  {Sub-Adr- Status   }
    Mil.Rd_IoBus (RdData, Stat_Adr, IobErr);
    if IobErr <> No_Err then Exit;

    {Stelle den Ist-Status des GerÑtes fest}
    if (Dev[I].Sta_Pro = N) then                         {Normale Bitbelegung}
     begin
      if BitTst(RdData,Dev[I].Sta_BitNr) then Dev_Ist:=1 else Dev_Ist:=0;
     end
    else
     begin     {bei Ventilen ist Info "Auf" u. "Zu" auf zwei Bits verteilt!!}
      Bit_1 := False;   Bit_2 := False;
      if BitTst(RdData,Dev[I].Sta_BitNr + 0) then Bit_1 := True;
      if BitTst(RdData,Dev[I].Sta_BitNr + 1) then Bit_2 := True;
         {Im Zustandsarray bedeutet 1=auf, 0=zu}
         {aktiv low: Bit_1 = Auf, Bit_2 = Zu;  Umsetzung 2-Bit auf 1-Bit-Info}
      if (Bit_1 and Bit_2) or ((not Bit_1) and (not Bit_2)) then
         Exit                                           {Zustand undefiniert!}
      else
         if not Bit_1 then Dev_Ist := 1 else Dev_Ist := 0;
     end; {if N}

    if not (Z[I] = Dev_Ist) then                {Soll-Ist Zustandsvergleich}
     begin
      Mil.Rd_IoBus (RdCmdData, Cmd_Adr, IobErr);          {Cmd-Status lesen}
      CmdData := BitInv(RdCmdData,Dev[I].Cmd_BitNr);
{
      if  Z[I] = 0 then BitClr (RdCmdData,Dev[I].Cmd_BitNr)
                   else BitSet (RdCmdData,Dev[I].Cmd_BitNr);
}
      Mil.Wr_IoBus (CmdData, Cmd_Adr, IobErr);            {Befehl an Device}
      Mil.Timer2_Wait(50000);   {Damit nicht alle Ventile gleichzeitig schalten}
     end;
    if (I = DevMax_Cmd) then Set_All_Dev := True; {Uff, alles ok!!}
   end; {for I: fÅr alle GerÑte}

 end; {Set_All_Dev}


 procedure Change_ZuStnd (New_ZuStnd_Nr: Byte; Old_ZuStnd: Word);
  {vorher wurde geprÅft, da· Anlagenzustand eindeutig ist}
  var New_ZuStnd : TZuMuster;
      Change_Ok  : Boolean;
  begin
   Change_Ok := False;
   if New_ZuStnd_Nr in [1.. Zustand_Max] then
    begin
     New_ZuStnd :=  Zustnd[New_ZuStnd_Nr]; {Hole Soll-Zustand aus Zustandstabelle}
     Displ_Diagram (Old_ZuStnd, Transfer);        {Alten Zustand auf Transfer}
     Ini_Msg_Win;
     Write ('  Neuer Zustand: '); TextColor(Red); Write(New_ZuStnd_Nr);
     Mil.Timer2_Wait(150000);
     if  Set_All_Dev (New_ZuStnd) then Change_Ok := True;
{
     if  Set_All_Dev (New_ZuStnd) then
       Displ_Diagram (New_ZuStnd_Nr, Aktiv)
     else
       Displ_Diagram (New_ZuStnd_Nr, Transfer);
}

    end; {if }
  end; {Change_ZuStnd}


 procedure Displ_Status_Anlage;   {Zeige Zustand und lasse énderung zu}
 var Z_Modus    : TZ_Mode;
     ZuStnd_Act : TZuMuster;
     Rd_Err     : TMilErr;
     ZuStnd_Num : Word;
     Quit       : Boolean;
     Life_Mode  : TLife_XY;
     Z_Nr_Old   : Word;
     Err_Mode   : Boolean;
     Neu_ZuStnd : Integer;

 begin
    Ini_Text_Win;
    Life_Mode.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
    Life_Mode.PosX    := 02;
    Life_Mode.PosY    := 01;
    Life_Mode.Time    := Life_Time_Slow;
    Life_Mode.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}
    Quit     := False;
    Z_Nr_Old := 0;
    Err_Mode := False;

    while not Dev_Status_Valid do
     begin
       Ini_Text_Win;
       GotoXY(02,06);
       TextColor(Brown);
       Writeln (' Sorry, lieber USER: der Zustand der GerÑte ist nicht eindeutig feststellbar! ');
       Writeln (' z. B. zeigt ein Ventil gleichzeitig AUF und ZU.');
       Writeln (' Beim BetÑtigen von Ventilen kann so etwas kurzzeitig vorkommen.');
       Writeln (' Nur falls der Status ok. ist geht es weiter!');
       Writeln (' Es wird jetzt stÑndig der Status ausgelesen. ');
       Writeln;
       Writeln;   TextColor(Yellow);
       Writeln (' Service-Hinweis:  ');   TextColor(Brown);
       Writeln (' Im MenÅ unter "Zustand der GerÑte anzeigen/Ñndern" den Status der einzelnen');
       Writeln (' GerÑte ansehen!');
       Life_Sign_XY (Life_Mode);

       Ini_Err_Win;
       Write ('Beenden des Statuslesens mit E[X]it   ');
       Mil.Timer2_Wait(30000);
       if KeyEPressed then
        begin
         Ch := NewReadKey;
         if Ch in ['x','X']then Exit;
        end;
     end;  {while}

    while not Get_Zustand (ZuStnd_Num) do
     begin
       Ini_Text_Win;
       GotoXY(02,06);
       TextColor(Brown);
       Writeln (' Sorry, lieber USER: Aus dem Status der GerÑte lÑ·t sich nicht eindeutig ');
       Write   (' feststellen, in welchen der ['); TextColor(White);
       Write (Zustand_Max); TextColor(Brown);  Write('] mîglichen ZustÑnde sich');
       Writeln (' die Anlage befindet.  ');
       Writeln (' ');
       Writeln (' Nur falls ein erlaubter Zustand gefunden wird geht es weiter!');
       Writeln (' Es wird jetzt stÑndig versucht, den Zustand festzustellen! ');
       Writeln;
       Writeln;   TextColor(Yellow);
       Writeln (' Service-Hinweis:  ');   TextColor(Brown);
       Writeln (' Im MenÅ unter "Zustand der GerÑte anzeigen/Ñndern" den Status der einzelnen');
       Writeln (' GerÑte ansehen!');
       Life_Sign_XY (Life_Mode);

       Ini_Err_Win;
       Write ('Beenden des Statuslesens mit E[X]it   ');
       Mil.Timer2_Wait(30000);
       if KeyEPressed then
        begin
         Ch := NewReadKey;
         if Ch in ['x','X']then Exit;
        end;
     end; {while}

    repeat
     Life_Sign_XY (Life_Mode);
     if Dev_Status_Valid  then
      begin
        Z_Modus := Aktiv;
        Err_Mode:= False;                       {Refresh nur bei énderung}
        if Get_Zustand (ZuStnd_Num) then
         begin
          Displ_Diagram (ZuStnd_Num, Z_Modus);
          Z_Nr_Old := ZuStnd_Num;              {verhindert flackernde Anzeige}
          Mil.Timer2_Wait(10000);
         end;

        Ini_Msg_Win;
        Cursor(False);
        Write ('Bitte eingeben fÅr neuen ['); TextColor(Red); Write('Z'); TextColor(Yellow);
        Write(']ustand oder e['); TextColor(Red); Write ('X'); TextColor(Yellow); Write(']it: ');
        if KeyEPressed then
         begin
          Ch := NewReadKey;
          case Ch of
           'x','X': Exit;
           'z','Z': begin
                      Ini_Msg_Win;
                      Cursor(False);
                      Write('Bitte Nummer ['); TextColor(Red); Write('1..',Zustand_Max); TextColor(Yellow);
                      Write(']  fÅr neuen Zustand eingeben  oder ['); TextColor(Red);
                      Write ('0'); TextColor(Yellow); Write('] fÅr Abbruch: ');
                      repeat until KeyEPressed;
                      {$I-}                            {Compiler Check aus, Error selber abfangen}
                      readln (Neu_ZuStnd);
                      {$I+}                            {PrÅfe, ob Nr ok}
                      if ((IoResult = 0) and (Neu_ZuStnd in [1..Zustand_Max])) then
                       begin                           {PrÅfe, ob neuer Zustand erlaubt ist}
                        if Check_ZuStnd_Wechsel (Neu_ZuStnd, ZuStnd_Num) then
                         begin
                           Change_ZuStnd (Neu_ZuStnd, ZuStnd_Num);
                         end
                        else
                         begin
                           Ini_Err_Win;
                           Write ('ERROR: öbergang zu Zustand ['); TextColor(Yellow);
                           Write (Neu_ZuStnd); TextColor(Red); Write('] nicht erlaubt!');
                           Mil.Timer2_Wait(200000);
                         end; {if check..}
                       end  {if IoResult}
                      else
                       begin
                        if not Neu_ZuStnd = 0 then
                         begin                   {bei 0-Eingabe keine Ausgabe}
                          Ini_Err_Win;
                          Write ('ERROR: Eingabe fehlerhaft!!!');
                          Mil.Timer2_Wait(200000);
                         end;
                       end;
                      Z_Nr_Old := 0;    {Erzwinge Displ-Refresh}
                    end;  {case Z}
          end; {case}
         end; {if Keypressed}
      end {if dev_status}
     else
      begin                                          {Zustand nicht eindeutig}
       if not Err_Mode then              {wegen Flankern: nur einmal anzeigen}
        begin
          Displ_Diagram(1, Inaktiv);
        end;
          Ini_Err_Win;
          TextColor (red + 128);
          Write ('Status der Anlage nicht eindeutig!!                [Q]uit');
          if KeyEPressed then
           begin
            Ch := NewReadKey;
            if Ch in ['q','Q'] then  Exit;
           end;
          Err_Mode := True;

      end; {if Get_Zustand}
     Mil.Timer2_Wait(30000);
    until Quit;
  end;  {Displ_Status_Anlage}


procedure Show_Soll_Zustand;
 label 1;
 var Num : Byte;
    Hand : Boolean;
    Hand_Err: TMilErr;
    Soll_ZuStnd_Nr : Byte;

  begin
   Ini_Text_Win;
   Ini_Msg_Win;
   Write ('Bitte Zustands-Nummer [1..', Zustand_Max , '] eingeben: ');
   {$I-}                            {Compiler Check aus, Error selber abfangen}
   readln(Soll_ZuStnd_Nr);
   {$I+}
   if (IoResult = 0)  and  (Soll_ZuStnd_Nr in [1..Zustand_Max])  then                             {PrÅfe, ob Nr ok}
    begin
     Ini_Msg_Win;
     Write ('Weiter mit beliebiger Taste ');
     DevStatDisp_Soll(Soll_ZuStnd_Nr);
     repeat until KeyPressed;
    end
   else
    begin
     Ini_Err_Win;
     Write ('ERROR: Falsche Eingabe!! Weiter mit belibiger Taste!! ');
     repeat until KeyPressed;
    end;
 end; {Show_Soll_Zustand;}

 {öbernehme akt. Zustand und setzte die CMD-Reg fÅr sto·freie Umschaltung}
 function Transfer_Hand_To_Rechner: Boolean;
  var
   Zustand_Akt : TZuMuster;
   Zustand_Neu : TZuMuster;
   Rd_Err      : TMilErr;

  begin
    Transfer_Hand_To_Rechner := False;
    Rd_Zustand (Zustand_Akt, Rd_Err);
    if Rd_Err = No_Err then
     begin
      if Set_All_Dev (Zustand_Akt) then Transfer_Hand_To_Rechner := True;
     end
    else
     begin {Fehler beim Lesen des aktuellen Zustandes}
       Exit;
     end; {if Rd_ZUst}
  end; {Transfer_Hand_To_Rechner}

 procedure Hand_To_Rechner;
  begin
   if not Transfer_Hand_To_Rechner then
    begin
     Ini_Err_Win;
     Write ('ERROR: Transfer Hand -> Rechner ');
    end
   else
    begin
     Ini_Msg_Win;
     TextColor (Blue);
     Write ('Transfer Hand -> Rechner erfolgreich');
     Mil.Timer2_Wait(200000);
    end;
   Mil.Timer2_Wait(200000);
  end;

BEGIN                        { Hauptprogramm }
  Z_Mod_Ist   := Undef;
  Z_Mod_Soll  := Undef;
  Ifc_Test_Nr := Ifc_Nr;

  REPEAT
    menue_win;
    User_Input := ReadKey;
    CASE user_input OF
     '0'      :      begin
                      Mil_Ask_Ifc;
                     end;
     '1'      :      begin
                      Loop := True;   {alle KanÑle}
                      Rd_Adc;
                     end;
     '2'      :      begin
                      Loop := True;   {alle KanÑle}
                      Iob_Rd_Stat;
                     end;
     '3'      :      begin
                      Loop := True;   {alle KanÑle}
                      Iob_Rd_Cmd;
                     end;
     'a', 'A' :      begin
                      Disp_Adr;
                     end;
     'b', 'B' :      begin
                      Loop := False;   {nur 1 Kanal}
                      Rd_Adc;
                     end;
     'c', 'C' :      begin
                      Loop := False;   {nur 1 Kanal}
                      Iob_Rd_Stat;
                     end;
     'd', 'D' :      begin
                      Loop := False;   {nur 1 Kanal}
                      Iob_Rd_Cmd;
                     end;
     'e', 'E' :     begin
                      Ini_Msg_Win;
                      Write('Nur öbersichts-Diagramm: kein aktueller Zustand der Anlage!!       Weiter <CR>');

                      Z_Mod_Test := Inaktiv;
                      Displ_Diagram (1, Z_Mod_Test);  {Zustand + Modus als Param}
                      Cursor(False);
                      repeat until KeyEPressed;
                      Cursor(True);
		     end;
     '5', 'f', 'F' : Begin
                       Show_Soll_Zustand;
       		     End;
     '6', 'g', 'G' : Begin
{Test_Zustand: TZuMuster = ( 0,1,1,1,1,1,1,1, 1,0,1,0,0,1,0,1,0,1,0,0, 0,1);}
                       if Set_All_Dev (Test_Zustand) then
                        begin
                         Ini_Msg_Win;
                         TextColor (Blue);
                         Write ('Transfer Hand -> Rechner erfolgreich');
                         Mil.Timer2_Wait(200000);
                        end;
 		     End;
     '7', 'h', 'H' : Begin
                      ;
		     End;
     '8', 'i', 'I' : begin
		     end;
          'k', 'K' : begin
                       Displ_Status_Anlage;
                     end;
          'l', 'L' : begin
                       Gas_Dev_Change;
                     end;
          'm', 'M' : begin
                       Show_Hand;
                     end;
          'n', 'N' : Begin
                       Check_Status_Valid;
                    End;
          'o', 'O' : Begin
                       Check_Betriebszustand;
                     End;
          'p', 'P' : Begin
                      Hand_To_Rechner;
                     End;
          'r', 'R' : begin
                      Ini_Text_Win;
                      Mil_Ifc_Reset;;
                     end;
    End; {CASE}
  UNTIL user_input in ['x','X'];
END. {mil_GAS}


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


  function Set_All_Dev (New_Zu: Word): Boolean; {Alle DevMax_Cmd GerÑte auf neuen Zustand einstellen}
 var
  Stat_Adr : TIoAdr;
  Cmd_Adr  : TIoAdr;
  IobErr   : TMilErr;
  RdData   : Word;
  CmdData  : Word;
  RdCmdData: Word;
  Bit_1,Bit_2: Boolean;
  I        : Byte;
  Z        : TZuMuster;      { packed array [1..DevMax_Cmd] of TBit}
  Dev_Ist  : Byte;

 begin
  Set_All_Dev    := False;
  Stat_Adr.IfcAdr:= Ifc_Nr;       {Adresse MIL-IFC   }
  Cmd_Adr.IfcAdr := Ifc_Nr;       {Adresse MIL-IFC   }
  Cmd_Adr.IoCard := IoA_Cmd;      {Adresse IOB-Status}
  Z :=  Zustnd[New_Zu];           {Hole Soll-Zustand aus Zustandstabelle}

  for I := 1 to DevMax_Cmd do     {I = Dev-Nr}
   begin
    Cmd_Adr.IoSub  := Dev[I].Cmd_Sub;                  {Sub-Adr- Command  }
    Stat_Adr.IoCard:= Dev[I].Adr;                      {Adresse IOB-Status}
    Stat_Adr.IoSub := Dev[I].Sta_Sub;                  {Sub-Adr- Status   }
    Mil.Rd_IoBus (RdData, Stat_Adr, IobErr);
    if IobErr <> No_Err then Exit;

{$IFDEF Test}
 RdData := 2;
{$ENDIF}
    {Stelle den Ist-Status des GerÑtes fest}
    if (Dev[I].Sta_Pro = N) then                         {Normale Bitbelegung}
     begin
      if BitTst(RdData,Dev[I].Sta_BitNr) then Dev_Ist:=1 else Dev_Ist:=0;
     end
    else
     begin     {bei Ventilen ist Info "Auf" u. "Zu" auf zwei Bits verteilt!!}
      Bit_1 := False;   Bit_2 := False;
      if BitTst(RdData,Dev[I].Sta_BitNr + 0) then Bit_1 := True;
      if BitTst(RdData,Dev[I].Sta_BitNr + 1) then Bit_2 := True;
         {Im Zustandsarray bedeutet 1=auf, 0=zu}
         {aktiv low: Bit_1 = Auf, Bit_2 = Zu;  Umsetzung 2-Bit auf 1-Bit-Info}
      if (Bit_1 and Bit_2) or ((not Bit_1) and (not Bit_2)) then
         Exit                                           {Zustand undefiniert!}
      else
         if not Bit_1 then Dev_Ist := 1 else Dev_Ist := 0;
     end; {if N}

    if not (Z[I] = Dev_Ist) then                {Soll-Ist Zustandsvergleich}
     begin
      Mil.Rd_IoBus (RdCmdData, Cmd_Adr, IobErr);          {Cmd-Status lesen}
      if  Z[I] = 0 then BitClr (RdCmdData,Dev[I].Cmd_BitNr)
                   else BitSet (RdCmdData,Dev[I].Cmd_BitNr);
      Mil.Wr_IoBus (CmdData, Cmd_Adr, IobErr);            {Befehl an Device}
      Mil.Timer2_Wait(50000);   {Damit nicht alle Ventile gleichzeitig schalten}
     end;
    if (I = DevMax_Cmd) then Set_All_Dev := True; {Uff, alles ok!!}
   end; {for I: fÅr alle GerÑte}

{$IFDEF Test}
  Set_All_Dev := True;
{$ENDIF}
 end; {Set_All_Dev}
