PROGRAM Mil_Tif;
{ Autor des Basis-Programmes Mil_Base.Pas: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS

  Autor der Erweiterungen   :
  énderungen:
  03.01.96    Et        Anpassung fÅr Loos/APL fÅr TIF-Tests
  05.01.96    Et        Event-Tabellen auf Disk
  17.11.98    Et        neue Compilierung und Ask Event neu
  23.02.00    Et        wegen MIL-Timeout neu compiliert
}
{$S-}
uses Crt, WinDos, Datech, Datech_0, Datech_1;

CONST
 head_line =
      'Datentechnik                         MIL_TIF    ' +
      '                    [23.02.2000]' +
      '                                Event-Code zum TIF          (Turbo Pascal V7.0)';

 msg_single_step =
      'Loop- u. Single-Test mit [Q] beenden!    Single-Step mit [SPACE] ';
 msg_timer_auto =
      'Automat. Timertest mit [Q] beenden!                              ';
 Cpu_Time = 24;   {MIL-Transfer[20] + Pentium P75[4]: Konstante fÅr Event-Daten Delay}

TYPE
 str4    = STRING[4];
 num_str = STRING[10];
 T_Dual  = record
            Adr   : Byte;
            Fct   : Byte;
            Dta_ok: Boolean;
            Dta   : Word;
           end;

VAR
 Mil        : T_Mil;               {Type OBJECT: in Unit Datech.Pas definiert}
 status    : BOOLEAN;
 loop      : BOOLEAN;
 rd_timeout: BOOLEAN;
 read_data : WORD;
 write_data: WORD;
 mil_data  : WORD;

 transf_cnt: LONGINT;
 time      : LONGINT;

 timout_cnt: LONGINT;
 timout_rd : LONGINT;
 timout_wr : LONGINT;
 ch,key    : CHAR;
 user_input: CHAR;
 read_str  : str4;
 Bit16_Str : Str19;
 Dual      : array [1..2] of T_Dual;     {Globale Variable fÅr Mil_Dual_Mode}
 User_In   : Word;
 Evt_Code  : Byte;  {Global Var fÅr APL/TIF}
 Virt_Acc  : Byte;
 Sup_Cycl  : Byte;

procedure menue_win;
VAR answer: CHAR;
begin
  Ini_Headl_Win;
  Write(head_line);
  Menue_Base;              {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}

  TextColor(Blue);
  GotoXY(5, 14);
  Writeln('       [M]<-- Sende 1 x 16-bit Event-Daten  (Manuelle Dateneingabe   )   ');
  GotoXY(5, 15);
  Writeln('       [N]<-- Sende n x 16-bit Event-Daten  (Daten aus Event-Tabellen)   ');
  GotoXY(5, 16);
  Writeln('       [O]<-- Editiere Event-Tabellen       (File  C:\EVENT.TAB      )   ');

  ini_msg_win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
 End; {menue_win}




{xxx}  {Ab hier sollten User-Erweiterungen beginnen!!}
function Ask_Event_Data (var Data: Word): Boolean;
 label 99;
 var    Dummy    : Word;
        User_Int : Integer;
 begin
   repeat
    Ask_Event_Data := False;
    Ini_Msg_Win;
    Write ('Zuerst wird Event-Code [Bit 7..0] dezimal benîtigt. Weiter <CR>');
    NewReadKey;
    if not Read_Int (0,255,User_Int) then
     begin
      Ini_Err_Win;
      Write ('ERROR: Event_Code nicht [0..255]!!  Abbruch mit beliebiger Taste.');
      repeat until KeyPressed;
      Exit;
     end
    else
     begin
      Ini_Info_Win;
      Evt_Code := Lo(User_Int);
     end;

    Ini_Info_Win;
    Writeln ('Aktuelle Keyboard-Eingabe:     ');
    Writeln ('           [Dez]   [Hex]');
    Writeln ('Event-Code: ', Evt_Code:3,'      ',hex_byte(Evt_Code));

    repeat
      Ini_Msg_Win;
      Write ('Bitte virt. Beschleuniger (Bit 8..11) dezimal [0..15] oder <A>bort: ');
      {$I-}                            {Compiler Check aus, Error selber abfangen}
      Readln (Virt_Acc);
      {$I+}
      if IoResult <> 0 then
       begin
        Ini_Err_Win;
        Write ('ERROR: Falsche Eingabe Virt. Beschleuniger !!  Abbruch mit beliebiger Taste.');
        repeat until KeyPressed;
        goto 99;
       end;

      if not Virt_Acc in [0..15] then
       begin
         Ini_Err_Win;
         Write ('ERROR: virtueller Beschleuniger nicht [0..15]!!  Weiter mit beliebiger Taste.');
         repeat until Keypressed;
       end;
    until Virt_Acc in [0..15];
    Ini_Info_Win;
    Writeln ('Aktuelle Keyboard-Eingabe:     ');
    Writeln ('           [Dez]   [Hex]');
    Writeln ('Event-Code: ', Evt_Code:3,'      ',hex_byte(Evt_Code):2);
    Writeln ('Virt-Acc. : ', Virt_Acc:3,'      ',hex_byte(Virt_Acc):2);
    repeat
      Ini_Msg_Win;
      Write ('Bitte Super Zyklus (Bit 12..15) dezimal eingeben [0..15] oder <A>bort: ');
      {$I-}                            {Compiler Check aus, Error selber abfangen}
      Readln (Sup_Cycl);
      {$I+}
      if IoResult <> 0 then
       begin
        Ini_Err_Win;
        Write ('ERROR: Falsche Eingabe Super Zyklus !!  Abbruch mit beliebiger Taste.');
        repeat until KeyPressed;
        goto 99;
       end;

      if not Sup_Cycl in [0..15] then
       begin
         Ini_Err_Win;
         Write ('ERROR: Super Zyklus nicht [0..15]!!  Weiter mit beliebiger Taste.');
         repeat until Keypressed;
       end;
    until Sup_Cycl in [0..15];

    Ini_Info_Win;
    Writeln ('Aktuelle Keyboard-Eingabe:     ');
    Writeln ('           [Dez]   [Hex]');
    Writeln ('Event-Code: ', Evt_Code:3,'      ',hex_byte(Evt_Code):2);
    Writeln ('Virt-Acc. : ', Virt_Acc:3,'      ',hex_byte(Virt_Acc):2);
    Writeln ('Sup Zyklus: ', Sup_Cycl:3,'      ',hex_byte(Sup_Cycl):2);

    Ini_Msg_Win;
    Write ('Ist die Eingabe korrekt? [J/N] oder <A>bort: ');
    repeat until Keypressed;
    Ch := ReadKey;
    if Ch in ['j','J'] then
      begin
        Ask_Event_Data := True;
        Data := Sup_Cycl shl 12;
        Data := Data or (Virt_Acc shl 8);
        Data := Data or Evt_Code;
        goto 99;
      end;
    if Ch in ['a','A'] then goto 99;
   until Ch in ['j','J'];

99: Ini_Info_Win;
 end; {Ask_Event_Data}


procedure Mil_Single_Evt;
 label 99;
 var Event_Data : Word;
     Event_Delay: Word;
     MilErr     : TMilErr;
     Fct        : TFct;
     Event_Delay_Old : Byte;

 begin
  Ini_Text_Win;            {Defin. Fenster, lîsche Fenster}
  Evt_Code := 0;
  Virt_Acc := 0;
  Sup_Cycl := 0;
  transf_cnt  := 0;
  Event_Delay := 0; {Default Einstellung}

  if not Ask_Event_Data (Event_Data) then goto 99;

  Ini_Text_Win;            {Defin. Fenster, lîsche Fenster}
  TextColor(Red);
  GotoXY(10,02); write('Achtung: Im Loop-Mode aus Timing-GrÅnden kein Bildschirm-Update!!');
  TextColor(Blue);
  GotoXY(17,04); write('----- Schreibe Event-Daten auf den MIL-BUS  -----');

  GotoXY(6, 10); writeln('Wr-Data-Cnt:                 Event-Data[H]:                ');
  GotoXY(50,10); write(hex_word(Event_Data));
  GotoXY(22,11); writeln('^  ^');

  GotoXY(06,14); write('          [Dez] [Hex]');
  GotoXY(06,15); write('Evt-Code: ',Evt_Code:3,'    ', Hex_Byte(Evt_Code):2);
  GotoXY(06,16); write('Virt-Acc: ',Virt_Acc:3,'    ', Hex_Byte(Virt_Acc):2);
  GotoXY(06,17); write('Sup-Cycl: ',Sup_Cycl:3,'    ', Hex_Byte(Sup_Cycl):2);
  GotoXY(06,19); write('Event-Abstand: ',Event_Delay * 10 + Cpu_Time,' [us]');
  TextColor(Yellow);
  GotoXY(06,21); write ('(Event-Abstand = MIL-Transfer [20us] + Rechnerzeit + Delay-Time)');
  GotoXY(01,22); write (' Rechnerzeit Pentium 75 Mhz = 4 us; Delay_Time in 10-us-Schritten einstellbar');
  TextColor(Black);

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR>, Delay-<T>ime    Ende mit [X]');
      Ch := NewReadKey;
      if  Ch in ['x','X'] then Goto 99;
      if Ch in ['t','T'] then
       begin
        Ini_Msg_Win;
        Event_Delay_Old := Event_Delay;
        Write ('Welche Delay-Time zwischen Event-Codes [us]: ');
        {$I-}                            {Compiler Check aus, Error selber abfangen}
        Readln (Event_Delay);
        {$I+}
        if IoResult <> 0 then
         Event_Delay := Event_Delay_Old
        else
         Event_Delay := Event_Delay div 10;
        Ini_Msg_Win;
        Write('Stop/Single Step mit <SPACE>, Loop mit <CR>, Delay-<T>ime    Ende mit [X]');
        Set_Text_Win;
        GotoXY(06,19); write('Event-Abstand: ',Event_Delay * 10 + Cpu_Time,' [us]');
       end;

      if Ch = chr($0D) then      {Carriage Return = Loop}
       begin
         Set_Text_Win;
         TextBackground(Green);
         GotoXY(18,10);
         TextColor(Red +128); {  TextColor(Blink);  }
         Write('    Loop  ');
         TextColor(Black);
       end;
     end; {Ch = ' '}

   Fct.W := Event_Data;
   repeat
    repeat
      Mil.WrFct (Fct, MilErr);       {Daten werden im Command-Mode gesendet}
      Mil.Timer2_Wait(Event_Delay);
    until KeyPressed or (Ch = ' ');

    if Keypressed then Ch := ReadKey;
    if Ch = ' ' then
      begin
       Set_Text_win;
       Transf_Cnt := Transf_Cnt+ 1;
       GotoXY(18,10);  Write(Transf_Cnt:10);
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR>, Delay-<T>ime    Ende mit [X]');
       repeat until KeyPressed;
      end;

    if Ch in ['t','T'] then
     begin
      Ini_Msg_Win;
      Event_Delay_Old := Event_Delay;
      Write ('Welche Delay-Time zwischen Event-Codes [us]: ');
      {$I-}                            {Compiler Check aus, Error selber abfangen}
      Readln (Event_Delay);
      {$I+}
      if IoResult <> 0 then
       Event_Delay := Event_Delay_Old
      else
       Event_Delay := Event_Delay div 10;
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR>, Delay-<T>ime    Ende mit [X]');
      Set_Text_Win;
      GotoXY(06,19); write('Event-Abstand: ',Event_Delay * 10 + Cpu_Time,' [us]');
     end;  {if T}

    if Ch = chr($0D) then      {Carriage Return = Loop}
     begin
       Set_Text_Win;
       TextBackground(Green);
       GotoXY(18,10);
       TextColor(Red +128); { TextColor(Blink);}
       Write('    Loop  ');
       TextColor(Black);
     end;
   until Ch in ['x','X'];
99:
 end; {Mil_Single_Evt}

{        Speziell fÅr Event-Tabellen}
const
 EvtMax    = 20;    {Anzahl Events in einer Tabelle}
 EvtTabMax = 20;    {Anzahl Event-Tabellen}
 Evt_Fname = 'C:\EVENT.TAB';   {Filename der Event-Tabellen}

type
 TEvtTab      = record
                 Name  : string[16];
                 Count : Byte;
                 EvtAry : array [1..EvtMax] of Word;
                end;
 TEvtTabAry   = array [1..EvtTabMax] of TEvtTab;
 TFile_EvtTab = file of TEvtTabAry;

var
    EvtFile  : TFile_EvtTab;
    EvtTab   : TEvtTabAry;


procedure Disp_Evt_Tab;
var M, ZStart : Byte;
 begin
  ZStart := 2;
  Ini_Text_Win;
  GotoXY(55,01); Write ('Filename: ', Evt_Fname);
  GotoXY(03,01);
  Write ('Num  Bezeichnung      Evt-Anzahl');
  GotoXY(03,02);
  Write ('---  ----------------    -- ');
  for M := 1 to EvtTabMax do
   begin
      GotoXY(03, M+ZStart); Write(M:2);
       begin
        GotoXY(08, M+ZStart);  Write(EvtTab [M].Name);
        GotoXY(28, M+ZStart);  Write(EvtTab [M].Count:2);
      end;
   end;
 end;

function Mil_Rd_EvtTab: BOOLEAN;              {Lese Event-Tabellen von Disk}
var I,N : Byte;
begin
  Assign (EvtFile, Evt_Fname);
  {$I-}                            {Compiler Check aus, Error selber abfangen}
  Reset(EvtFile);
  {$I+}
  if IoResult <> 0 then                         {PrÅfe, ob File existiert}
    begin
     Mil_Rd_EvtTab:= False;
     Ini_Err_Win;
     Write('ERROR: File ',Evt_Fname,' nicht gefunden. Leere Datei anlegen? [J/N]: ');
     if ReadKey in ['j','J'] then
      begin
       ReWrite(EvtFile);                         {existiert nicht: File erzeugen}
       for N := 1 to EvtTabMax do                {Init alle Tabelllen}
        begin
         EvtTab[N].Name    := 'NoName';
         EvtTab[N].Count   := 0;
         for I := 1 to EvtMax do                 {Init alle Events}
           EvtTab[N].EvtAry[I]  := 0;
        end;
        EvtTab[1].Name    := 'STANDARD********';         {Tabelle 1 ist immer Standard}
        Write(EvtFile,EvtTab);                   {Tabelle in File speichern}
      end; {if ja}
    end
   else
    begin
     Mil_Rd_EvtTab:= True;
     Read (EvtFile, EvtTab);                     { File existiert: Lese Tabelle}
     Close(EvtFile);
    end;
end;

procedure Hex_To_Event (Evt_Data: Word;
                        var Sup, Virt, Code: Byte);
 begin
   Code := Evt_Data  and $00FF;
   Virt := (Evt_Data and $0F00) shr 8;
   Sup  := (Evt_Data and $F000) shr 12;
 end; {Hex_To_Event}


procedure Disp_Events (TabNr: Word; Flag_Index: Byte);  {Flag: Markiere Zeile}
 const ZStart = 2;
       Name_Off = 14;
 var   x      : Word;
       EvtData: Word;
       Evt_Supr, Evt_Virt, Evt_Code : Byte;
 begin
   Ini_Text_Win; TextColor (Brown); GotoXY(01,01);
   Write ('Evt_Tab['); TextColor (Black); Write(TabNr:2); TextColor (Brown);  Write (']  ');
   GotoXY(Name_Off,01); Write ('Tab-Name >'); TextColor (Black);
   Write(EvtTab[TabNr].Name);
   GotoXY(Name_Off+26,01); TextColor (Brown);
   Write('<    Event_Anzahl: '); TextColor (Black);
   Write (EvtTab[TabNr].Count:2); TextColor (Black);

   GotoXY(02,2);
   TextColor (Magenta);
   Writeln('Num  Evt_Data[H]  Sup  Virt  Event');
   TextColor (Black);
   for X := 1 to EvtTab[TabNr].Count  do
    begin
       begin
        EvtData := EvtTab[TabNr].EvtAry[X];
        Hex_To_Event (EvtData,  Evt_Supr, Evt_Virt, Evt_Code);
        if X = Flag_Index then
         begin
           TextColor (Red);
           GotoXY(01, X+ZStart); Write('>');
           TextColor (Black);
         end;
        GotoXY(03, X+ZStart); Write(X:2);
        GotoXY(10, X+ZStart); Write (Hex_Word(EvtData));
        GotoXY(21, X+ZStart); Write (Evt_Supr:2);
        GotoXY(27, X+ZStart); Write (Evt_Virt:2);
        GotoXY(33, X+ZStart); Write (Evt_Code:3);
      end;
    end; {for}
  end; {Disp_Events}

procedure Mil_Edit_EvtAry;
label 99, 1;
type
 TEvtTab      = record
                 Name  : string[16];
                 Count : Byte;
                 EvtAry : array [1..EvtMax] of Word;
                end;
 TEvtTabAry   = array [1..EvtTabMax] of TEvtTab;
 TFile_EvtTab = file of TEvtTabAry;

var I,N      : Word;
    Index_Ok : Boolean;
    Num      : Byte;
    Ch       : Char;
    File_Ok  : Boolean;
    EvtNum   : Byte;
    EvtTabNr : Byte;

   procedure Evt_Edit (TabNr: Byte);
    label 99;
    var Evt_Nr   : Byte;
        Evt_Data : Word;
        Index    : Byte;
    begin
     if (EvtTab[TabNr].Count = 0) then
      begin
        Ini_Err_Win;
        Write ('ERROR: Kein Event vorhanden!!  Weiter mit beliebiger Taste!');
        repeat until Keypressed;
        Ch := ' ';
        goto 99;
      end;

     Ini_Msg_Win;
     Write ('Welchen Event Ñndern? [Num]: ');
     {$I-}                            {Compiler Check aus, Error selber abfangen}
     Readln (Index);
     {$I+}
     if (IoResult <> 0) or (not Index in [1..EvtMax]) then
       begin
         Ini_Err_Win;
         Write ('ERROR: Eingabe falsch. Weiter mit beliebiger Taste!');
         repeat until Keypressed;
         Ch := ' ';
       end
     else
       begin
        if (Index > EvtTab[TabNr].Count) or (Index = 0) then
          begin
            Ini_Err_Win;
            Write ('ERROR: Event [',Index:2,'] nicht editierbar!!  Weiter mit beliebiger Taste!');
            repeat until Keypressed;
            Ch := ' ';
            goto 99;
          end;
        Disp_Events (TabNr,Index);
        if Ask_Event_Data (Evt_Data) then
         begin
           EvtTab[TabNr].EvtAry[Index]:= Evt_Data;
           Disp_Events (TabNr,Index);
         end;
       end;
99:
  end; {Evt_Edit}

   procedure Evt_Neu (TabNr: Byte);
    label 100;
    var Evt_Nr   : Byte;
        Evt_Data : Word;
        Index    : Byte;
        N        : Byte;

    begin
     Ini_Msg_Win;
     Write ('An welchen Event anfÅgen ?'); TextColor (Red);
     if (EvtTab[TabNr].Count = EvtMax) then
       Write ('  [Num 0..', (EvtTab[TabNr].Count-1):2,']: ')
     else
       Write ('  [Num 0..', (EvtTab[TabNr].Count):2,']: ');

     {$I-}                            {Compiler Check aus, Error selber abfangen}
     Readln (Index);
     {$I+}
     if (IoResult <> 0) or (not Index in [0..EvtMax-1]) then
       begin
         Ini_Err_Win;
         Write ('ERROR: Eingabe falsch. Ende mit beliebiger Taste!');
         repeat until Keypressed;
         Ch := ' ';
       end
     else
       begin                                           {i/o-Result ok}
         if (Index > EvtTab[TabNr].Count) or (Index = EvtMax) then
           begin
             Ini_Err_Win;
             if Index > EvtTab[TabNr].Count then
               Write ('ERROR: Num darf nur [0..', (EvtTab[TabNr].Count):2,'] betragen! Ende beliebige Taste!');
             if Index = EvtMax then
               Write ('ERROR: Num darf nur [0..', (EvtTab[TabNr].Count-1):2,'] betragen! Ende beliebige Taste!');
             repeat until KeyPressed;
             goto 100;
           end;

         if not Ask_Event_Data (Evt_Data) then
          begin
           Ini_Info_Win;
           goto 100;
          end;

         if Index = (EvtTab[TabNr].Count)  then
          begin                                            {event an-fÅgen}
            if (Index >= EvtMax-1) then
             begin
               Index := EvtMax;
               EvtTab[TabNr].EvtAry[Index]:= Evt_Data;
               Disp_Events (TabNr,0);
               EvtTab[TabNr].Count := EvtMax;
               Disp_Events (TabNr,0);
             end
            else
             begin
               Index := EvtTab[TabNr].Count + 1;
               EvtTab[TabNr].EvtAry[Index]:= Evt_Data;
               if not (Index >= EvtMax) then
                 EvtTab[TabNr].Count := EvtTab[TabNr].Count + 1;
               Disp_Events (TabNr,0);
             end;
           end
         else
          begin                                             {event ein-fÅgen}
            if not (Index > EvtMax-1) then
             begin
               N := EvtTab[TabNr].Count + 1;
               repeat
                 N := N - 1;
                 EvtTab[TabNr].EvtAry[N+1] := EvtTab[TabNr].EvtAry[N];
                 if N = Index + 1 then  EvtTab[TabNr].EvtAry[N] := Evt_Data;
               until N = Index + 1;

               if EvtTab[TabNr].Count < EvtMax then
                 EvtTab[TabNr].Count := EvtTab[TabNr].Count + 1;
               Disp_Events (TabNr,0);
             end; {if Index}
          end;
        end;  {I/O-Result ok}
   100:
   end; {Evt_Neu}


   procedure Evt_Del (TabNr: Byte);
    var Evt_Nr   : Byte;
        Evt_Data : Word;
        Index    : Byte;
        Count_Old: Byte;
        N        : Byte;

    begin
     Ini_Msg_Win;
     Write ('Welchen Event lîschen? [Num]: ');
     {$I-}                            {Compiler Check aus, Error selber abfangen}
     Readln (Index);
     {$I+}
     if (IoResult <> 0) or (not Index in [1..EvtMax]) then
       begin
         Ini_Err_Win;
         Write ('ERROR: Eingabe falsch. Ende mit beliebiger Taste!');
         repeat until Keypressed;
         Ch := ' ';
       end
     else
       begin
         for N := 1 to EvtTab[TabNr].Count do  {alle events}
          begin
            if N >= Index then
             begin
               if  N = EvtTab[TabNr].Count then     {Letzter Event?}
                 EvtTab[TabNr].EvtAry[N] := 0
               else                                 {verschiebe nach unten}
                 EvtTab[TabNr].EvtAry[N] := EvtTab[TabNr].EvtAry[N+1];
             end; {if N=Index}
          end;    {for N}

         EvtTab[TabNr].Count := EvtTab[TabNr].Count - 1;
         Disp_Events (TabNr,0);
     end;  {I/O-Result ok}
    end; {Evt_Lîsch}

   procedure Evt_TabInit (Nr: Byte);
    var Z : Byte;
    begin
      Ini_Err_Win;
      Write ('Wirklich die Tabelle auf Null setzen? [J/N] : N');
      Ch := Readkey;
      if Ch in ['j','J'] then
       begin
         EvtTab[Nr].Name       := 'NoName';
         EvtTab[Nr].Count      := 0;
         for Z := 1 to EvtMax do                 {Init alle Events}
           EvtTab[Nr].EvtAry[Z]:= 0;
         Disp_Events (EvtTabNr,0);
       end;
    end; {Evt_TabInit}

  procedure  Evt_TabName (Nr: Byte);
   begin
    Ini_Msg_Win;
    Write ('Neuen Namen (max. 16 Zeichen) fÅr die Tabelle[', Nr:2, '] eingeben: ');
    Readln (EvtTab[Nr].Name);
    Disp_Events (Nr,0);
   end;  {Evt_TabName}

  function Ask_Evt_TabNr: Byte;
   var Tab_Nr : Byte;
   begin
     Disp_Evt_Tab;
     Ini_Msg_Win;
     Write ('Welche Event-Tabelle? Bitte Zahl eingeben [Num]: ');
     {$I-}                            {Compiler Check aus, Error selber abfangen}
     Readln (Tab_Nr);
     {$I+}
     if (IoResult <> 0) or (Tab_Nr > EvtTabMax) then Tab_Nr := 1;
     Ask_Evt_TabNr := Tab_Nr;
   end;

begin               {Mil_Edit_EvtAry}
  Ini_Text_Win;
  Mil_Rd_EvtTab;
  EvtTabNr := Ask_Evt_TabNr;
  Disp_Events (EvtTabNr,0);
  Ini_Msg_Win;
  Write ('[A]n-/einfÅg_Evt  [E]dit_Evt  [L]îsch_Evt  [I]nit_Tab  [N]ame_Tab  [Q]uit');
  repeat until KeyPressed;
  Ch := ReadKey;

  repeat
   repeat
    case Ch of
     'a', 'A' : Evt_Neu    (EvtTabNr);
     'e', 'E' : Evt_Edit   (EvtTabNr);
     'l', 'L' : Evt_Del    (EvtTabNr);
     'i', 'I' : Evt_TabInit(EvtTabNr);
     'n', 'N' : Evt_TabName(EvtTabNr);
     'q', 'Q' : goto 1;
    end; {case}

     Ini_Msg_Win;
     Write ('[A]n-/einfÅg_Evt  [E]dit_Evt  [L]îsch_Evt  [I]nit_Tab  [N]ame_Tab  [Q]uit');
     repeat until KeyPressed;
     Ch := ReadKey;
   until Ch in ['q','q'];

1:
   Ch := ' ';
   Disp_Evt_Tab;
   Ini_Msg_Win;
   Write (' [E]dit_Tab       e[X]it');
   repeat
     repeat until KeyPressed;
     Ch := ReadKey;
   until (Ch in ['e', 'E'])  or  (Ch in ['x', 'X']);

   case Ch of
     'e', 'E' : begin
                 EvtTabNr := Ask_Evt_TabNr;
                 Disp_Events (EvtTabNr,0);
                 Ini_Msg_Win;
                 Write ('[A]n-/einfÅg_Evt  [E]dit_Evt  [L]îsch_Evt  [I]nit_Tab  [N]ame_Tab  [Q]uit');
                 repeat until KeyPressed;
                 Ch := ReadKey;
                end;
     'x', 'X' : goto 99;
    end; {case}
 until  Ch in ['x','X'];

99:
  Disp_Evt_Tab;
  Ini_Err_Win;
  Write (' énderungen der Event-Tabellen auf Disk speichern [J/N]: N');
  repeat until KeyPressed;
  Ch := ReadKey;

  if Ch in ['J','j'] then
   begin
    ReWrite(EvtFile);                  {ôffne File fÅr Schreiben}
    Write(EvtFile,EvtTab);             {Tabelle in File speichern}
    Close(EvtFile);
   end;
 end; {Mil_Edit_EvtAry}

procedure Mil_Send_EvtAry;
label 99;
type
 TEvtTab      = record
                 Name  : string[16];
                 Count : Byte;
                 EvtAry : array [1..EvtMax] of Word;
                end;
 TEvtTabAry   = array [1..EvtTabMax] of TEvtTab;
 TFile_EvtTab = file of TEvtTabAry;

var I,N      : Word;
    Index_Ok : Boolean;
    Loop     : Boolean;
    Index    : Byte;
    Num      : Byte;
    Ch       : Char;
    MilErr   : TMilErr;
    Fct      : TFct;
    File_Ok  : Boolean;
    EvtNum   : Byte;
    EvtTabNr : Byte;
    Event_Data     : Word;
    Event_Delay    : Word;
    Event_Delay_Old: Word;

  procedure Disp_Evt_Dta (Evt_Dta: Word);
   begin
     Hex_To_Event (Evt_Dta, Sup_Cycl, Virt_Acc, Evt_Code);
     GotoXY(50,10); write(hex_word(Evt_Dta));
     GotoXY(06,15); write('Evt-Code: ',Evt_Code:3,'    ', Hex_Byte(Evt_Code):2);
     GotoXY(06,16); write('Virt-Acc: ',Virt_Acc:3,'    ', Hex_Byte(Virt_Acc):2);
     GotoXY(06,17); write('Sup-Cycl: ',Sup_Cycl:3,'    ', Hex_Byte(Sup_Cycl):2);
   end; {Disp_Evt_Dta}

begin               {Mil_Send_EvtAry}
  Ini_Text_Win;
  Mil_Rd_EvtTab;
  Disp_Evt_Tab;
  Loop := False;
  Event_Delay := 0; {Default Einstellung}
  Transf_Cnt  := 0;

  Ini_Msg_Win;
  Write ('Welche Event-Tabelle? Bitte Zahl eingeben [Num]: ');
  {$I-}                            {Compiler Check aus, Error selber abfangen}
  Readln (EvtTabNr);
  {$I+}
  if IoResult <> 0 then EvtTabNr := 1;
  if EvtTabNr >  EvtTabMax then EvtTabNr := 1;

  Disp_Events (EvtTabNr,0);
  Ini_Msg_Win;
  Write('Weiter mit <Space> ! ');
  repeat until KeyPressed;
  Ch := ReadKey;

  Ini_Text_Win;            {Defin. Fenster, lîsche Fenster}
  TextColor(Red);
  GotoXY(10,02); write('Achtung: Im Loop-Mode aus Timing-GrÅnden kein Bildschirm-Update!!');
  TextColor(Black);
  GotoXY(17,04); write('----- Schreibe Event-Daten auf den MIL-BUS  -----');
  GotoXY(23,06); write('Event-Tabelle [',EvtTabNr:2,']     Name: ',EvtTab[EvtTabNr].Name);
  GotoXY(23,07); write('Anzahl Events : ', EvtTab[EvtTabNr].Count);

  GotoXY(6, 10); writeln('Wr-Data-Cnt:                 Event-Data[H]:                ');
  GotoXY(22,11); writeln('^  ^');
  GotoXY(06,14); write('          [Dez] [Hex]');

  GotoXY(06,19); write('Event-Abstand: ',Event_Delay * 10 + Cpu_Time,' [us]');
  TextColor(Brown);
  GotoXY(06,21); write ('(Event-Abstand = MIL-Transfer [20us] + Rechnerzeit + Delay-Time)');
  GotoXY(01,22); write (' Rechnerzeit Pentium 75 Mhz = 4 us; Delay_Time in 10-us-Schritten einstellbar');
  TextColor(Black);

   Ch := ' ';
   if Ch = ' ' then
     begin
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR>, Delay-<T>ime    Ende mit [X]');
      repeat until KeyPressed;
      Ch := ReadKey;
      if  Ch in ['x','X'] then Goto 99;
      if Ch in ['t','T'] then
       begin
        Ini_Msg_Win;
        Event_Delay_Old := Event_Delay;
        Write ('Welche Delay-Time zwischen Event-Codes [us]: ');
        {$I-}                            {Compiler Check aus, Error selber abfangen}
        Readln (Event_Delay);
        {$I+}
        if IoResult <> 0 then
         Event_Delay := Event_Delay_Old
        else
         Event_Delay := Event_Delay div 10;
        Ini_Msg_Win;
        Write('Stop/Single Step mit <SPACE>, Loop mit <CR>, Delay-<T>ime    Ende mit [X]');
        Set_Text_Win;
        GotoXY(06,19); write('Event-Abstand: ',Event_Delay * 10 + Cpu_Time,' [us]');
       end;

      if Ch = chr($0D) then      {Carriage Return = Loop}
       begin
         Set_Text_Win;
         TextBackground(Green);
         GotoXY(18,10);
         TextColor(Blink);
         Write('    Loop  ');
         TextColor(Black);
       end;
     end; {Ch = ' '}

   Index := 0;
   repeat
    repeat
      Index := Index + 1;
      Fct.W := EvtTab[EvtTabNr].EvtAry[Index];
      Mil.WrFct (Fct, MilErr);         {Daten werden im Command-Mode gesendet}
      if Index = EvtTab[EvtTabNr].Count then Index := 0;
      Mil.Timer2_Wait(Event_Delay);
    until KeyPressed or (Ch = ' ');

    if Keypressed then Ch := ReadKey;
    if Ch = ' ' then
      begin
       Set_Text_win;
       Transf_Cnt := Transf_Cnt+ 1;
       GotoXY(18,10);  Write(Transf_Cnt:10);
       Disp_Evt_Dta (Fct.W);                       {Im Single-Step Event_Data}

       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR>, Delay-<T>ime    Ende mit [X]');
       repeat until KeyPressed;
      end;

    if Ch in ['t','T'] then
     begin
      Ini_Msg_Win;
      Event_Delay_Old := Event_Delay;
      Write ('Welche Delay-Time zwischen Event-Codes [us]: ');
      {$I-}                            {Compiler Check aus, Error selber abfangen}
      Readln (Event_Delay);
      {$I+}
      if IoResult <> 0 then
       Event_Delay := Event_Delay_Old
      else
       Event_Delay := Event_Delay div 10;
      Ini_Msg_Win;
      Write('Stop/Single Step mit <SPACE>, Loop mit <CR>, Delay-<T>ime    Ende mit [X]');
      Set_Text_Win;
      GotoXY(06,19); write('Event-Abstand: ',Event_Delay * 10 + Cpu_Time,' [us]');
     end;  {if T}

    if Ch = chr($0D) then      {Carriage Return = Loop}
     begin
       Set_Text_Win;
       TextBackground(Green);
       GotoXY(18,10);
       TextColor(Blink);
       Write('    Loop  ');
       TextColor(Black);
     end;
   until Ch in ['x','X'];
99:
 end; {Mil_Send_EvtAry}



BEGIN   { Hauptprogramm }
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
                  Mil_Single_Evt;
                end;
     'n', 'N' : begin
                  Mil_Send_EvtAry;
                end;
     'o', 'O' : begin
                  Mil_Edit_EvtAry;
                end;

    End; {CASE}
  UNTIL user_input in ['x','X'];
  Window(1, 1, 80, 25);
  TextBackground(Black);
  ClrScr;
END. {mil_base}



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



function Ask_Event_Data (var Data: Word): Boolean;
 label 99;
 var    Dummy    : Word;
 begin
   repeat
    Ini_Info_Win;
    Ask_Event_Data := False;
    Ini_Msg_Win;
    Write ('Bitte Event-Code (Bit 0..7) dezimal eingeben [0..255] oder <A>bort:');
    {$I-}                            {Compiler Check aus, Error selber abfangen}
    Readln (Evt_Code);
    {$I+}
    if IoResult <> 0 then
     begin
      Ini_Err_Win;
      Write ('ERROR: Event_Code nicht [0..255]!!  Abbruch mit beliebiger Taste.');
      repeat until KeyPressed;
      goto 99;
     end;

    Ini_Info_Win;
    Writeln ('Aktuelle Keyboard-Eingabe:     ');
    Writeln ('           [Dez]   [Hex]');
    Writeln ('Event-Code: ', Evt_Code:3,'      ',hex_byte(Evt_Code));

    repeat
      Ini_Msg_Win;
      Write ('Bitte virt. Beschleuniger (Bit 8..11) dezimal [0..15] oder <A>bort: ');
      {$I-}                            {Compiler Check aus, Error selber abfangen}
      Readln (Virt_Acc);
      {$I+}
      if IoResult <> 0 then
       begin
        Ini_Err_Win;
        Write ('ERROR: Falsche Eingabe Virt. Beschleuniger !!  Abbruch mit beliebiger Taste.');
        repeat until KeyPressed;
        goto 99;
       end;

      if not Virt_Acc in [0..15] then
       begin
         Ini_Err_Win;
         Write ('ERROR: virtueller Beschleuniger nicht [0..15]!!  Weiter mit beliebiger Taste.');
         repeat until Keypressed;
       end;
    until Virt_Acc in [0..15];
    Ini_Info_Win;
    Writeln ('Aktuelle Keyboard-Eingabe:     ');
    Writeln ('           [Dez]   [Hex]');
    Writeln ('Event-Code: ', Evt_Code:3,'      ',hex_byte(Evt_Code):2);
    Writeln ('Virt-Acc. : ', Virt_Acc:3,'      ',hex_byte(Virt_Acc):2);
    repeat
      Ini_Msg_Win;
      Write ('Bitte Super Zyklus (Bit 12..15) dezimal eingeben [0..15] oder <A>bort: ');
      {$I-}                            {Compiler Check aus, Error selber abfangen}
      Readln (Sup_Cycl);
      {$I+}
      if IoResult <> 0 then
       begin
        Ini_Err_Win;
        Write ('ERROR: Falsche Eingabe Super Zyklus !!  Abbruch mit beliebiger Taste.');
        repeat until KeyPressed;
        goto 99;
       end;

      if not Sup_Cycl in [0..15] then
       begin
         Ini_Err_Win;
         Write ('ERROR: Super Zyklus nicht [0..15]!!  Weiter mit beliebiger Taste.');
         repeat until Keypressed;
       end;
    until Sup_Cycl in [0..15];

    Ini_Info_Win;
    Writeln ('Aktuelle Keyboard-Eingabe:     ');
    Writeln ('           [Dez]   [Hex]');
    Writeln ('Event-Code: ', Evt_Code:3,'      ',hex_byte(Evt_Code):2);
    Writeln ('Virt-Acc. : ', Virt_Acc:3,'      ',hex_byte(Virt_Acc):2);
    Writeln ('Sup Zyklus: ', Sup_Cycl:3,'      ',hex_byte(Sup_Cycl):2);

    Ini_Msg_Win;
    Write ('Ist die Eingabe korrekt? [J/N] oder <A>bort: ');
    repeat until Keypressed;
    Ch := ReadKey;
    if Ch in ['j','J'] then
      begin
        Ask_Event_Data := True;
        Data := Sup_Cycl shl 12;
        Data := Data or (Virt_Acc shl 8);
        Data := Data or Evt_Code;
        goto 99;
      end;
    if Ch in ['a','A'] then goto 99;
   until Ch in ['j','J'];

99: Ini_Info_Win;
 end; {Ask_Event_Data}


