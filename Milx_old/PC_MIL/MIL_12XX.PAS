PROGRAM Mil_12EV;
{ Autor des Basis-Programmes Mil_Base.Pas: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS

  Autor der Erweiterungen   :
  énderungen:
  29.04.97   Et 12-fach Event-Generator mit externer Triggerung
             FG 450.350 auf Basis Modulbus


}
{$S-}
uses Crt, WinDos, Datech, Datech_1;
{USES Crt,Graph,Dos,Datech;  }
CONST
 head_line =
      'BELAB                               MIL_12EV  ' +
      '                      [09.05.1997]' +
      '                           12-fach Event-Generator          (Turbo Pascal V7.0)';
{
      '                      12-fach Event-Generator               (Turbo Pascal V7.0)';
}
{Sub-Adressen fÅr APL-IO-Bus Identifizierung: gÅltig fÅr alle Karten}
             {Antwort als 16-Bit-Wert fÅr Adr. FE, FC, FA}
 IOsub_Adr_CardID = $FE;  {gerade   Adr: hibyte}
 IOsub_Adr_VgID   = $FF;  {ungerade Adr: lobyte}

 IOsub_Adr_Skal   = $FC;  {gerade   Adr: hibyte}
 IOsub_Adr_ModAdr = $FD;  {ungerade Adr: lobyte}

 IOsub_Adr_Epld   = $FA;  {gerade   Adr: hibyte}
 IOsub_Adr_Frei   = $FB;  {ungerade Adr: lobyte}

 Wait_500_ms      = 50000;
 Fct_Rd_Dta = $90;
 Fct_Wr_Adr = $11;
 Fct_Wr_Dta = $10;


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

 Fct_11_Dta: Word;
 IO_ModAdr : Byte;


procedure menue_win;
VAR answer: CHAR;
begin
  Ini_Headl_Win;
  Write(head_line);
  Menue_Base;              {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}

  GotoXY(5, 14);
  Writeln('       [M]<-- Status 12-Ext-Event-I/O-Modul                   ');
  GotoXY(5, 15);
  Writeln('       [N]<--                                                 ');
  GotoXY(5, 16);
  Writeln('       [O]<--                                                 ');
  GotoXY(5, 17);
  Writeln('       [P]<-- Sende Fct-Code 11/10 m. Dummy I/O-Daten + SubAdr Incr.     ');
  GotoXY(5, 18);
  Writeln('       [Q]<-- Sende/Lese Fct-11/10/90 I/O-Daten (Manuell/Automatisch)    ');
  GotoXY(5, 19);
  Writeln('       [R]<-- Sollwert DAC, Istwert ADC                                  ');
  GotoXY(5, 20);
  Writeln('       [S]<-- Anzeigen Status SubAdr 0, 2, 4                             ');
  GotoXY(5, 21);
  Writeln('       [T]<-- Sende drei Fct-Codes (SEL, LESE, DE-SEL)                   ');

  ini_msg_win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
 End; {menue_win}


{xxx}  {Ab hier sollten User-Erweiterungen beginnen!!}
 function IO_Mod_Online (Ifc_Adr: Byte; Mod_Adr: Byte): Boolean;
  var
   MilErr  : TMilErr;
   Fct     : TFct;
   Rd_Data : Word;
   Fct_11_Data : Word;

  begin
    IO_Mod_Online := False;
    Fct_11_Data:= (Mod_Adr*256) + IOsub_Adr_Skal;  {Modul-Adr is Hibyte, Subadr Lowbyte}
    Fct.B.Adr  := Ifc_Adr;
    Fct.B.Fct  := Fct_Wr_Iob_Adr;
    Mil.Wr (Fct_11_Data, Fct, MilErr);                        {Adr zum I/O-Bus}

    Fct.B.Fct  :=  Fct_Rd_Iob_Dta;                {Lesen Daten von APL-IO-Bus}
    Mil.Rd (Rd_Data, Fct, MilErr); {Anwort: Hibyte=Skalierng, Lobyte=Modadr}
    if MilErr = No_Err then
      if (Rd_Data and $00FF) = Mod_Adr then IO_Mod_Online := True;
  end; {IO_Mod_Online}



 procedure Mil_Displ_IO_Modul;
   LABEL 99;
   const  Z_Mod_Start = 4;
   VAR
     error_cnt : LONGINT;

     MilErr    : TMilErr;
     Fct       : TFct;
     Rcv_Data  : Word;
     M         : Byte;
     I         : Byte;
     Mod_Zeile : Word;

     Ifb_Online: ARRAY [1..255] OF BOOLEAN;
     Ifb_Adr   : Word;
     Ifc_Total : Word;
     Mod_Total : Word;
     Mod_RetAdr: Byte;
     Id_Dez    : Byte;
     Mod_Err   : TOnlineErr;

   procedure Displ_Mod_Headline;
    begin
     Ini_Text_Win;
     GotoXY(15,01); write('----- Finde IFC-Karten, I/O-Module und Ident -----');
     Set_Color_Alarm;
     GotoXY(01,02); write('IFC-Adr Modul-Adr  ID-Card  ID-VG   Skl MoAdr  EPLD Frei  Sta2 Sta1  Sta4 Sta3');
     Set_Color_Norm;
     GotoXY(01,03); write(' [Hex]    [Hex]    [Dez] <FE  FF>   <FC  FD>   <FA  FB>   <F8  F9>   <F6  F7>');
     Ini_Msg_Win;
     Write('Weiter mit  <SPACE>,  Ende mit [X]');
     Set_Text_Win;
    end;

   procedure Displ_Mod_Info (Ifc_Adr: Byte; Mod_Adr: Byte; Z_Mod: Byte);
    const S_Mod_ID_Dta  = 28;      {Default Spalte fÅr Modulidentdaten}
    var   IOsub_Adr    : Byte;
          Fct_11_Dta   : Word;
          S_Mod_Akt    : Byte;
          V            : Byte;
    begin
     Set_Text_Win;
     S_Mod_Akt := S_Mod_ID_Dta;
     GotoXY(04,Z_Mod); write(Hex_Byte(Ifc_Adr),'       ',Hex_Byte(Mod_Adr));
     IOsub_Adr := $FE;                               {Word-Adr fÅr Identdaten}

     for V := 1 to 5  do                         {Lese 3 Worte mit Identdaten}
      begin
        Fct.B.Adr  := Ifc_Adr;
        Fct_11_Dta:= (Mod_Adr*256) + IOsub_Adr;  {Modul-Adr ins Hibyte, Subadr Lowbyte}
        Fct.B.Fct  := Fct_Wr_Iob_Adr;
        Mil.Wr (Fct_11_Dta, Fct, MilErr);                     {Adr zum I/O-Bus}

        Fct.B.Fct  :=  Fct_Rd_Iob_Dta;             {Lesen Daten von APL-IO-Bus}
        Mil.Rd (Read_Data, Fct, MilErr);

        if (IOsub_Adr = $FE) then                  {ID auch dezimal ausgeben}
         begin
          GotoXY(S_Mod_Akt-7,Z_Mod);
          Id_Dez := (Read_Data and $FF00) shr 8;
          Write (Id_Dez:3);
         end;

        GotoXY(S_Mod_Akt,Z_Mod);
        Write (hex_word(Read_Data));
        S_Mod_Akt := S_Mod_Akt + 11;
        IOsub_Adr := IOsub_Adr - 2;
      end; {Displ_Mod_Info}
   end; {Displ_Mod_Info}

   Begin
    transf_cnt := 0;
    error_cnt  := 0;
    timout_wr  := 0;
    Ifc_Total  := 0;
    Mod_Total  := 0;

    Ini_Text_Win;
    Mil_Ask_Ifc;
    Ini_Text_Win;
    Displ_Mod_Headline;
    M := 0;
    Mod_Zeile := Z_Mod_Start;

    Ifb_Adr := Ifc_Test_Nr;
    repeat
     repeat
       Set_Text_win;
           repeat
            M := M + 1;                         {alle mîglichen Modul-Adr abfragen}
{
     procedure Mod_Online (Ifc_Adr: Byte; Mod_Adr: Byte; var Mod_RetAdr: Byte; var OnlineErr: TOnlineErr);
}
            Mil.Mod_Online (Ifb_Adr, M, Mod_RetAdr, Mod_Err);
            If Mod_Err = NoErr then
           { IF IO_Mod_Online (Ifb_Adr, M) THEN}
             begin
               Displ_Mod_Info (Ifb_Adr, M, Mod_Zeile);
               Mod_Zeile := Mod_Zeile + 1;
               if (Mod_Zeile mod 23) = 0 then Mod_Zeile := Z_Mod_Start;
             end;
            if M > $1F then
              begin
                M := 0;
                Mod_Zeile := Z_Mod_Start;
              end;
           until M = 0;
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
End; {Mil_Displ_IO_Modul;}


 procedure Mil_Detect_IO_Modul;
   LABEL 99;
   const  Z_Mod_Start = 5;
   VAR
     error_cnt : LONGINT;
     MilErr    : TMilErr;
     Fct       : TFct;
     Rcv_Data  : Word;
     M         : Byte;
     I         : Byte;
     Mod_Zeile : Word;

     Ifb_Online: ARRAY [1..255] OF BOOLEAN;
     Ifb_Adr   : Word;
     Ifc_Total : Word;
     Mod_Total : Word;
     Id_Dez    : Byte;
     RetAdr     : Byte;
     OnlineErr  : TOnlineErr;
     Mod_RetAdr: Byte;
     Mod_Err   : TOnlineErr;


   procedure Displ_Mod_Headline;
    begin
     Ini_Text_Win;
     GotoXY(15,01); write('----- Finde IFC-Karten, I/O-Module und Ident -----');
     Set_Color_Alarm;
     GotoXY(01,03); write('IFC-Adr Modul-Adr  ID-Card  ID-VG   Skl MoAdr  EPLD Frei  Sta2 Sta1  Sta4 Sta3');
     Set_Color_Norm;
     GotoXY(01,04); write(' [Hex]    [Hex]    [Dez] <FE  FF>   <FC  FD>   <FA  FB>   <F8  F9>   <F6  F7>');
    end;

   procedure Displ_Mod_Info (Ifc_Adr: Byte; Mod_Adr: Byte; Z_Mod: Byte);
    const S_Mod_ID_Dta  = 28;      {Default Spalte fÅr Modulidentdaten}
    var   IOsub_Adr    : Byte;
          Fct_11_Dta   : Word;
          S_Mod_Akt    : Byte;
          V            : Byte;
    begin
     Set_Text_Win;
     S_Mod_Akt := S_Mod_ID_Dta;
     GotoXY(04,Z_Mod); write(Hex_Byte(Ifc_Adr),'       ',Hex_Byte(Mod_Adr));
     IOsub_Adr := $FE;                               {Word-Adr fÅr Identdaten}

     for V := 1 to 5  do                         {Lese 3 Worte mit Identdaten}
      begin
        Fct.B.Adr  := Ifc_Adr;
        Fct_11_Dta:= (Mod_Adr*256) + IOsub_Adr;  {Modul-Adr ins Hibyte, Subadr Lowbyte}
        Fct.B.Fct  := Fct_Wr_Iob_Adr;
        Mil.Wr (Fct_11_Dta, Fct, MilErr);                     {Adr zum I/O-Bus}

        Fct.B.Fct  :=  Fct_Rd_Iob_Dta;             {Lesen Daten von APL-IO-Bus}
        Mil.Rd (Read_Data, Fct, MilErr);

        if (IOsub_Adr = $FE) then                  {ID auch dezimal ausgeben}
         begin
          GotoXY(S_Mod_Akt-7,Z_Mod);
          Id_Dez := (Read_Data and $FF00) shr 8;
          Write (Id_Dez:3);
         end;

        GotoXY(S_Mod_Akt,Z_Mod);
        Write (hex_word(Read_Data));
        S_Mod_Akt := S_Mod_Akt + 11;
        IOsub_Adr := IOsub_Adr - 2;
      end; {Displ_Mod_Info}
   end; {Displ_Mod_Info}

   Begin
    transf_cnt := 0;
    error_cnt  := 0;
    timout_wr  := 0;
    Ifc_Total  := 0;
    Mod_Total  := 0;

    for ifb_adr := 1 to 255 do Ifb_Online[ifb_adr] := False;
    FOR ifb_adr := 1 TO 255 DO
     Begin
      mil.ifc_online (ifb_adr, RetAdr, OnlineErr);
      if OnlineErr = NoErr then
       Begin
        ifb_online[ifb_adr] := TRUE;
        ifc_total := ifc_total + 1;
       End;
    End;

    Ini_Text_Win;
    Displ_Mod_Headline;
    Ini_Msg_Win;
    Write('Weiter mit  <SPACE>,  Ende mit [X]');

    Set_Text_Win;
    M := 0;
    Ifb_Adr := 1;
    Mod_Zeile := Z_Mod_Start;

     repeat
       Set_Text_win;
       if ifb_online [ifb_adr] then
         begin
           for M := 0 to $1F do            {alle mîglichen Modul-Adr abfragen}
             begin

{               IF IO_Mod_Online (Ifb_Adr, M) THEN
}
            Mil.Mod_Online (Ifb_Adr, M, Mod_RetAdr, Mod_Err);
            If Mod_Err = NoErr then

                 begin
                   Mod_Total := Mod_Total + 1 ;
                   Displ_Mod_Info (Ifb_Adr, M, Mod_Zeile);
                   Mod_Zeile := Mod_Zeile + 1;
                   if (Mod_Zeile mod 21) = 0 then
                    begin
                      Mod_Zeile := Z_Mod_Start;
                      repeat until KeyPressed;
                      Ini_Text_Win;
                      Displ_Mod_Headline;
                      Ini_Msg_Win;
                      Write('Weiter mit  <SPACE>,  Ende mit [X]');
                      repeat until KeyPressed;
                      Ch := ReadKey;
                      if Ch in ['x','X'] then
                        begin
                         Ch := ' ';    {verhindert Abort}
                         goto 99;
                        end;
                     end;
                 end;
             end; {for m..}
         end; {if ifb_online}

       Ifb_Adr := Ifb_Adr + 1;
       if Ifb_Adr > $FF then
         begin
           if Mod_Total = 0 then
            begin
              GotoXY(05,10); write('Sorry, leider keine I/O-Karten gefunden!!');
            end;
           Ini_Msg_Win;
           Write('Ende mit <SPACE>');
           repeat until KeyPressed;
           Ch := ReadKey;
           Ch := ' ';                  {Abort wegen Eingabe von 'x' verhindern}
           goto 99;
         end;
      until KeyPressed {or (Ch = ' ')};
    99:
End; {Mil_Detect_IO_Modul}


FUNCTION Ask_IO_Adr (var In_Data: WORD): Boolean;
 Begin
    Ask_IO_Adr := False;
    Ini_text_win;
    GotoXY(2, 22);  TextColor (Brown);
    write ('Bitte 16-bit I/O-Adresse eingeben [Bit13..8 = Modul-Adr, Bit7..0 = Sub-Adr]!!');
{
    Ini_Msg_Win;
    Write   ('--> Bitte 4-stellige Hex-Adresse eingeben: '); readln(read_str);
    convert_to_hex (read_str,in_data,status);
    IF NOT status THEN
      Begin
       ini_err_win;
       writeln('ERROR: Sorry, USER: das war keine 4-stell. Hexzahl!!');
      End;
}
    if Ask_Hex_Break (In_Data, Wrd) then Ask_IO_Adr  := True;
 End; { Ask_IO_Adr}


  procedure Displ_IO_Status (Ifc_Adr: Byte;
                             Mod_Adr: Byte;
                             Sub_Adr: Byte;
                             Z_Start: Byte);      {Startzeile}
  label 99;
  const
        Z_Off_Data  = 11;
        S_Start     = 10;    {Spalte}
        S_Off_DAC   = 12;
        S_Off_IW1   = 33;
        S_Off_IW2   = 55;
  var
     Bit16_Strg: Str19;
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;
     Write_Data,Displ_Data : Word;
     Wr_Sw_Flag : Boolean;
     Fct_11_Dta : Word;
     Id_Dez     : Byte;

   procedure Displ_Mod_Headline;
    begin
     Set_Text_Win;
     GotoXY(01,Z_Start);
     write('v------------------- Karten-Status    (Sub-Adr: ',hex_byte(Sub_Adr),' [Hex]) ------------------- v');
     Set_Color_Alarm;
     GotoXY(01,Z_Start+1); write('IFC-Adr Modul-Adr  ID-Card  ID-VG   Skl MoAdr  EPLD Frei  Sta2 Sta1  Sta4 Sta3');
     Set_Color_Norm;
     GotoXY(01,Z_Start+2); write(' [Hex]    [Hex]    [Dez] <FE  FF>   <FC  FD>   <FA  FB>   <F8  F9>   <F6  F7>');
   end;

   procedure Displ_Mod_Info (Ifc_Adr: Byte; Mod_Adr: Byte; Z_Mod: Byte);
    const S_Mod_ID_Dta  = 28;      {Default Spalte fÅr Modulidentdaten}
    var   IOsub_Adr    : Byte;
          Fct_11_Dta   : Word;
          S_Mod_Akt    : Byte;
          V            : Byte;
          Fct_11_Data  : Word;
          Rd_Data      : Word;
    begin
     Set_Text_Win;
     S_Mod_Akt := S_Mod_ID_Dta;
     GotoXY(04,Z_Mod); write(Hex_Byte(Ifc_Adr),'       ',Hex_Byte(Mod_Adr));
     IOsub_Adr := $FE;                               {Word-Adr fÅr Identdaten}
     for V := 1 to 5  do                         {Lese 3 Worte mit Identdaten}
      begin
        Fct.B.Adr  := Ifc_Adr;
        Fct_11_Data:= (Mod_Adr*256) + IOsub_Adr;  {Modul-Adr ins Hibyte, Subadr Lowbyte}
        Fct.B.Fct  := Fct_Wr_Iob_Adr;
        Mil.Wr (Fct_11_Data, Fct, MilErr);                     {Adr zum I/O-Bus}

        Fct.B.Fct  :=  Fct_Rd_Iob_Dta;             {Lesen Daten von APL-IO-Bus}
        Mil.Rd (Rd_Data, Fct, MilErr);

        if (IOsub_Adr = $FE) then                  {ID auch dezimal ausgeben}
         begin
          GotoXY(S_Mod_Akt-7,Z_Mod);
          Id_Dez := (Rd_Data and $FF00) shr 8;
          Write (Id_Dez:3);
         end;

        GotoXY(S_Mod_Akt,Z_Mod);
        Write (hex_word(Rd_Data));
        S_Mod_Akt := S_Mod_Akt + 11;
        IOsub_Adr := IOsub_Adr - 2;
      end; {For V 1..5}
   end; {Displ_Mod_Info}

  begin
   timout_cnt := 0;
   Set_Text_Win;
{
   if not IO_Mod_Online (Ifc_Test_Nr, IO_ModAdr) then
    begin
      Ini_Text_Win;
      Ini_Err_Win;
      Write ('ERROR: I/O-Modul [',Hex_Byte(IO_ModAdr),']  nicht gefunden!!  Ende mit beliebiger Taste!');
      repeat until KeyPressed;
      goto 99;
    end;
}
   Set_Text_Win;
   Fct.B.Adr  := Ifc_Adr;
   Displ_Mod_Headline;
   Set_Text_win;
   Displ_Mod_Info (Ifc_Adr, Mod_Adr, Z_Start+3);
{   repeat until Keypressed;  }
99:
end; {Displ_I/O_Status}


 Procedure Mil_Wr_11 (Wr_Data: Word);
   LABEL 99;
   Const Delay = 200000;
         Z_Start = 18;                  {Startzeile fÅr IO-Display}
   VAR
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Send_Data : Word;
     Dummy_Data: Word;
     Delay_Wrd : Word;
     Mod_Adr,Sub_Adr: Byte;
     I : Word;

   Begin
    transf_cnt := 0;
    error_cnt  := 0;
    timout_wr  := 0;
    Delay_Wrd  :=  Delay Div 100000;

    Fct.B.Adr  := Ifc_Test_Nr;
    Fct.B.Fct  := $11;
    Fct_11_Dta := Wr_Data;

    Ini_Text_Win;
    GotoXY(15,06); write('----- Schreibe Daten auf den MIL-BUS mit Fct-Code -----');
    GotoXY(13,07); write('Automat. HochzÑhlen Subadr (Zeitverzîgerung im Loop: ', Delay_Wrd:2,' sec)');
    GotoXY(25,08); write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
    GotoXY(19,09); write  ('I/O-Basis-Adr (Modul + Sub-Adr): ',hex_word(Fct_11_Dta),' [H]');
    GotoXY(06,11); writeln('Wr-Data-Cnt:              Write-Data[H]:                ');
    GotoXY(22,12); writeln('^  ^');
    GotoXY(53,11); write('Timeout:');
    GotoXY(61,11); write(timout_wr:10);
    GotoXY(47,11); write(hex_word(Wr_Data));

    Ini_Msg_Win;
    Write('Sende I/O-Basis-Adresse mit <SPACE> ');
    repeat until KeyPressed;
    Ch := ReadKey;

    Set_Text_win;
    Mil.Reset;
    Mil.Wr (Fct_11_Dta, Fct, MilErr);
{
    Transf_Cnt := Transf_Cnt+ 1;
    GotoXY(18,11); writeln(transf_cnt:10);
}
    Dummy_Data:= $0000;
    Send_Data := Fct_11_Dta;
    Sub_Adr   := 00;
    Mod_Adr   := (Send_Data and $FF00) shr 8;           {Mod-Adr ins Low-Byte}

    if IO_Mod_Online (Ifc_Test_Nr, Mod_Adr) then
      begin
       Displ_IO_Status (Ifc_Test_Nr,Mod_Adr,Sub_Adr,Z_Start)
      end
    else
      begin
       GotoXY(10,Z_Start); write('ERROR: Modul-Nr.',hex_byte(Mod_Adr),' [Hex] ist nicht online!!');
      end;

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
       Sub_Adr := Send_Data and $00FF;        {Low-Byte der Daten ist Sub_Adr}
       Mod_Adr := (Send_Data and $FF00) shr 8;           {Hi-Byte ist Mod-Adr}

      if IO_Mod_Online (Ifc_Test_Nr, Mod_Adr) then
       begin
         for i := 0 to 3 do begin GotoXY(01,Z_Start + I); ClrEol; end;
         Displ_IO_Status (Ifc_Test_Nr,Mod_Adr,Sub_Adr,Z_Start)
        end
       else
        begin                     {Modul ist jetzt Offline}
         for i := 0 to 3 do begin GotoXY(01,Z_Start + I); ClrEol; end;
         GotoXY(10,Z_Start); write('ERROR: Modul-Nr.',hex_byte(Mod_Adr),' [Hex] ist nicht online!!');
       end;

       Transf_Cnt := Transf_Cnt+ 1;
       GotoXY(18,11); write(transf_cnt:10);
       Fct.B.Fct  := $11;
       GotoXY(25,08); write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
       GotoXY(47,11); write(hex_word(Send_Data));
       Mil.Wr (Send_Data, Fct, MilErr);
       if MilErr <> No_err then
        begin
         timout_wr := timout_wr + 1;
         GotoXY(61, 11); write(timout_wr:10);
        end;

       Transf_Cnt := Transf_Cnt+ 1;
       GotoXY(18,11); write(transf_cnt:10);
       Fct.B.Fct  := $10;
       GotoXY(25,08); write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
       Mil.Wr (Dummy_Data, Fct, MilErr);
       if MilErr <> No_err then
        begin
         timout_wr := timout_wr + 1;
         GotoXY(61, 11); write(timout_wr:10);
        end;

       Mil.Timer2_Set (Delay);
       repeat until (KeyPressed or Mil.Timeout2);

      Send_Data := Send_Data + 2;
      if (Send_Data and $00FF) >= $0F then Send_Data := Fct_11_Dta;
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
End; {Mil_Wr_11}


Procedure  Mil_Wr_Rd_11 (Wr_Data: Word);  {WR_Data in diesem Falle = IO-Adr}
{Wichtig: Die Reihenfolge write IO-Adr mit Fct-11, write IO-Data mit Fct-10
}
   LABEL 99, Loop;
   const  Z_Start = 18;

   VAR
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Send_Data : array [1..2] of Word;
     Read_Data : Word;
     I         : Word;
     rd_sub0_err : LONGINT;
     rd_sub2_err : LONGINT;
     Mod_Adr, Sub_Adr : Byte;
     Online_Old  : Boolean;    {Status nur anzeigen bei énderungen,}
     Online_New  : Boolean;    {da sonst Display flackert          }


   procedure Display_Ini;
   begin
    Ini_Text_Win;
    GotoXY(18,04); write('----- Schreibe/Lese Daten auf/von IO-BUS -----');
    GotoXY(15,05); write('       Setze I/O-Adr. mit Function-Code 11 [H]    ');
    GotoXY(25,07); write  ('Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
    GotoXY(25,08); write  ('I/O-Adr (Modul + Sub-Adr): ',hex_word(Fct_11_Dta),' [H]');
    GotoXY(03,10); writeln('Wr-Data-Cnt:               Write-Data     Read-Data      Data-Error');
    GotoXY(03,11); writeln('                 ^  ^         [Hex]         [Hex]                          ');
    GotoXY(03,12); writeln('Sub-Adr[0]: ');
    GotoXY(03,13); writeln('Sub-Adr[2]: ');
    GotoXY(03,15); writeln('Timeout   : ');
    GotoXY(28,15); write(timout_wr:10);
    GotoXY(42,15); write(timout_rd:10);
    GotoXY(60,12); write(rd_sub0_err:10);
    GotoXY(60,13); write(rd_sub2_err:10);
   end;


   Begin
    transf_cnt := 0;
    error_cnt  := 0;
    timout_wr  := 0;
    timout_rd  := 0;
    rd_sub0_err:= 0;
    rd_sub2_err:= 0;
    for I := 1 to 2 do  Send_Data[I] := 0;

    Fct.B.Adr  := Ifc_Test_Nr;
    Fct_11_Dta := Wr_Data;
    Fct.B.Fct  := Fct_Wr_Dta;
    Sub_Adr := Wr_Data and $00FF;             {Low-Byte der Daten ist Sub_Adr}
    Mod_Adr := (Wr_Data and $FF00) shr 8;                {Hi-Byte ist Mod-Adr}


    Ini_Text_Win;
    Ini_Msg_Win;
    write ('Test manuell <CR> oder [A]utomatisch');
    repeat until KeyPressed;

    Ch := ReadKey;
    if  Ch in ['a','A'] then Goto Loop;

    Ini_Text_Win;
    GotoXY(5, 22);
    write ('Welche Daten fÅr Sub-Adr[0] ?');  {nur das low-byte interessiert}
    Send_Data[1] := ask_hex_word and $00FF;

    Ini_Text_Win;
    GotoXY(5, 22);
    write ('Welche Daten fÅr Sub-Adr[2] ?');
    Send_Data[2] := ask_hex_word;
    Display_Ini;

    if IO_Mod_Online (Ifc_Test_Nr, Mod_Adr) then
      begin
       Online_New := True;
       Online_Old := Online_New;
       Displ_IO_Status (Ifc_Test_Nr,Mod_Adr,Sub_Adr,Z_Start)
      end
    else
      begin
       Online_New := FALSE;
       Online_Old := Online_New;
       Set_Text_Win;
       GotoXY(10,Z_Start); write('ERROR: Modul-Nr.',hex_byte(Mod_Adr),'[Hex] ist nicht online!!');
      end;
{yyy}
    Ch := ' ';
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyPressed;
        Ch := ReadKey;
       if  Ch in ['x','X'] then Goto 99;
      end;

    Mil.Reset;                                                  { clear fifo }
    repeat
     repeat
       Set_Text_win;       {Neue Anzeige nur, falls sich etwas geÑndert hat}
       Online_New := IO_Mod_Online (Ifc_Test_Nr, Mod_Adr);
       if Online_New <> Online_Old then
         begin
           Online_Old := Online_New;   {Rette den neuen Status}
           if Online_New then          {Modul ist jetzt Online}
             begin
              for i := 0 to 3 do begin GotoXY(01,Z_Start + I); ClrEol; end;
              Displ_IO_Status (Ifc_Test_Nr,Mod_Adr,Sub_Adr,Z_Start)
             end
           else
             begin                     {Modul ist jetzt Offline}
              for i := 0 to 3 do begin GotoXY(01,Z_Start + I); ClrEol; end;
              GotoXY(10,Z_Start); write('ERROR: Modul-Nr.',hex_byte(Mod_Adr),' [Hex] ist nicht online!!');
             end;
         end;
                                 {Sende Subadresse 0}
       Fct.B.Fct  := Fct_Wr_Adr;   {11}                      {Adr zum I/O-Bus}
       Mil.Wr (Fct_11_Dta + 0, Fct, MilErr);
       Transf_Cnt := Transf_Cnt + 1;

       Transf_Cnt := Transf_Cnt + 1;
       GotoXY(36,12); write(hex_byte(Send_Data[1]));
       Fct.B.Fct  := Fct_Wr_Dta;   {10}             {Sende Daten zur Subadr 0}
       Mil.Wr (Send_Data[1], Fct, MilErr);
       if MilErr <> No_err then
        begin
         timout_wr := timout_wr + 1;
         GotoXY(28,15); write(timout_wr:10);
        end;

       Set_Text_Win;
       Fct.B.Fct  := Fct_Wr_Adr;                    {Adr zum I/O-Bus   }
       Mil.Wr (Fct_11_Dta + 2, Fct, MilErr);        {Sende Subadresse 2}
       Transf_Cnt := Transf_Cnt + 1;

       Transf_Cnt := Transf_Cnt+ 1;
       GotoXY(34,13); write(hex_word(Send_Data[2]));
       Fct.B.Fct  := Fct_Wr_Dta;
       Mil.Wr (Send_Data[2], Fct, MilErr);          {Sende Daten zur Subadr 2}
       if MilErr <> No_err then
        begin
         timout_wr := timout_wr + 1;
         GotoXY(28,15); write(timout_wr:10);
        end;
      GotoXY(16,10); writeln(transf_cnt:10);

      if Ch = ' ' then
        begin
         Ini_Msg_Win;
         Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
         repeat until KeyPressed;
            Ch := ReadKey;
         if  Ch in ['x','X'] then Goto 99;
        end;

       {Ab hier Lesen}
      Set_Text_Win;
      Fct.B.Fct  := Fct_Wr_Adr;   {11}                       {Adr zum I/O-Bus}
      Mil.Wr (Fct_11_Dta + 0, Fct, MilErr);                        {Sub-Adr 0}
      Transf_Cnt := Transf_Cnt + 1;

      Fct.B.Fct := Fct_Rd_Dta;  {90}
      Mil.Rd (Read_Data, Fct, MilErr);               {Lese Daten von Subadr 0}
      Read_Data := Read_Data and $00FF;            {nur low-byte interessiert}
      if MilErr  <> No_Err then
       begin
        timout_rd := timout_rd + 1;
        GotoXY(42,15); write(timout_rd:10);
        GotoXY(48,12); write('    ');
       end
      else
       begin
         GotoXY(50,12); writeln(hex_byte(Read_Data));
         if Read_Data <> Send_Data[1]  then
           begin
            rd_sub0_err:= rd_sub0_err + 1;
            GotoXY(60,12); write(rd_sub0_err:10);
           end;
       end;

      Set_Text_Win;
      Fct.B.Fct  := Fct_Wr_Adr;                    {Adr zum I/O-Bus   }
      Mil.Wr (Fct_11_Dta + 2, Fct, MilErr);        {Sende Subadresse 2}
      Transf_Cnt := Transf_Cnt + 1;
      GotoXY(16,10); writeln(transf_cnt:10);

      Fct.B.Fct := Fct_Rd_Dta;
      Mil.Rd (Read_Data, Fct, MilErr);               {Lese Daten von Subadr 2}
      if MilErr  <> No_Err then
       begin
        timout_rd := timout_rd + 1;
        GotoXY(42,15); write(timout_rd:10);
        GotoXY(48,13); write('    ');
       end
      else
       begin
         GotoXY(48,13); write(hex_word(Read_Data));
         if Read_Data <> Send_Data[2]  then
           begin
            rd_sub2_err := rd_sub2_err + 1;
            GotoXY(60,13); write(rd_sub2_err:10);
           end;
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

 Loop:           {Daten automatisch generieren; Halt bei Error}
    begin
     Display_Ini;

     Ch := ' ';
     if Ch = ' ' then
       begin
        Ini_Msg_Win;
        Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
        repeat until KeyPressed;
        Ch := ReadKey;
        if  Ch in ['x','X'] then Goto 99;
       end;

      Mil.Reset;                                                  { clear fifo }
      Send_Data[1] := 0;
      Send_Data[2] := 0;
      repeat
       repeat
         Set_Text_win;                                      {Sende Subadresse 0}

         Online_New := IO_Mod_Online (Ifc_Test_Nr, Mod_Adr);
         if Online_New <> Online_Old then
           begin
             Online_Old := Online_New;   {Rette den neuen Status}
             if Online_New then          {Modul ist jetzt Online}
               begin
                for i := 0 to 3 do begin GotoXY(01,Z_Start + I); ClrEol; end;
                Displ_IO_Status (Ifc_Test_Nr,Mod_Adr,Sub_Adr,Z_Start)
               end
             else
               begin                     {Modul ist jetzt Offline}
                for i := 0 to 3 do begin GotoXY(01,Z_Start + I); ClrEol; end;
                GotoXY(10,Z_Start); write('ERROR: Modul-Nr.',hex_byte(Mod_Adr),' [Hex] ist nicht online!!');
               end;
           end;

         Fct.B.Fct  := Fct_Wr_Adr;   {11}                      {Adr zum I/O-Bus}
         Mil.Wr (Fct_11_Dta + 0, Fct, MilErr);
         Transf_Cnt := Transf_Cnt + 1;

         GotoXY(36,12); write(hex_byte(Send_Data[1]));
         Fct.B.Fct  := Fct_Wr_Dta;   {10}           {Sende Daten zur Subadr 0}
         Mil.Wr (Send_Data[1], Fct, MilErr);
         if MilErr <> No_err then
          begin
           timout_wr := timout_wr + 1;
           GotoXY(28,15); write(timout_wr:10);
          end;

         Set_Text_Win;
         Fct.B.Fct  := Fct_Wr_Adr;                    {Adr zum I/O-Bus   }
         Mil.Wr (Fct_11_Dta + 2, Fct, MilErr);        {Sende Subadresse 2}
         Transf_Cnt := Transf_Cnt + 1;

         Transf_Cnt := Transf_Cnt+ 1;
         GotoXY(34,13); write(hex_word(Send_Data[2]));
         Fct.B.Fct  := Fct_Wr_Dta;
         Mil.Wr (Send_Data[2], Fct, MilErr);          {Sende Daten zur Subadr 2}
         if MilErr <> No_err then
          begin
           timout_wr := timout_wr + 1;
           GotoXY(28,15); write(timout_wr:10);
          end;
        GotoXY(16,10); write(transf_cnt:10);


         {Ab hier Lesen}
        Set_Text_Win;
        Fct.B.Fct  := Fct_Wr_Adr;   {11}                       {Adr zum I/O-Bus}
        Mil.Wr (Fct_11_Dta + 0, Fct, MilErr);                        {Sub-Adr 0}
        Transf_Cnt := Transf_Cnt + 1;

        Fct.B.Fct := Fct_Rd_Dta;  {90}
        Mil.Rd (Read_Data, Fct, MilErr);             {Lese Daten von Subadr 0}
        Read_Data := Read_Data and $00FF;            {nur low-byte interessiert}
        if MilErr  <> No_Err then
         begin
          timout_rd := timout_rd + 1;
          GotoXY(42,15); write(timout_rd:10);
          GotoXY(48,12); write('    ');
         end
        else
         begin
           GotoXY(50,12); writeln(hex_byte(Read_Data));
           if Read_Data <> (Send_Data[1] and $00FF) then
             begin
              rd_sub0_err:= rd_sub0_err + 1;
              GotoXY(60,12); write(rd_sub0_err:10);
              GotoXY(16,10); write(transf_cnt:10);
              Ini_Err_Win;
              write('ERROR: Datenfehler Sub-Adr. 0!  Weiter mit <Space> oder e[X]it');
              repeat until KeyPressed;
              Ch := ReadKey;
              if Ch in ['x','X'] then goto 99 else Ch := 'a';  {Dummy};
              Ini_Msg_Win;
              Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
              Set_Text_Win;
             end;
         end;

        Fct.B.Fct  := Fct_Wr_Adr;                    {Adr zum I/O-Bus   }
        Mil.Wr (Fct_11_Dta + 2, Fct, MilErr);        {Sende Subadresse 2}
        Transf_Cnt := Transf_Cnt + 1;

        Fct.B.Fct := Fct_Rd_Dta;
        Mil.Rd (Read_Data, Fct, MilErr);               {Lese Daten von Subadr 2}
        if MilErr  <> No_Err then
         begin
          timout_rd := timout_rd + 1;
          GotoXY(42,15); write(timout_rd:10);
          GotoXY(48,13); write('    ');
         end
        else
         begin
           GotoXY(48,13); writeln(hex_word(Read_Data));
           if Read_Data <> Send_Data[2]  then
             begin
              rd_sub2_err := rd_sub2_err + 1;
              GotoXY(60,13); write(rd_sub2_err:10);
              GotoXY(16,10); write(transf_cnt:10);
              Ini_Err_Win;
              write('ERROR: Datenfehler Sub-Adr. 2!  Weiter mit <Space> oder e[X]it');
              repeat until KeyPressed;
              Ch := ReadKey;
              if Ch in ['x','X'] then goto 99 else Ch := 'a';  {Dummy};
              Ini_Msg_Win;
              Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
              Set_Text_Win;
             end;
         end;
        if Send_Data[2] = $FFFF then
         begin
           Send_Data[1] := 0;
           Send_Data[2] := 0;
         end
        else
         begin
           Send_Data[1] := Send_Data[1] + 1;
           Send_Data[2] := Send_Data[2] + 1;
         end;
         GotoXY(16,10); write(transf_cnt:10);
       until KeyPressed or (Ch = ' ');
       if Ch = ' ' then
         begin
          Ini_Msg_Win;
          Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
          repeat until KeyPressed;
         end;
       Ch := ReadKey;
      until Ch in ['x','X'];
    end; {Loop}
 99:
End; {Mil_Wr_Rd_11}


 Function Mil_Ask_ModAdr: Byte;
  VAR answer : CHAR;
      Status : Boolean;
      Mod_Adr: Byte;

  Begin
    Status := FALSE;
    WHILE NOT Status DO
     Begin
      Ini_Text_Win;
      GotoXY(5, 22);
      write ('Welche Modul-Adr. testen?');
      Mod_Adr := ask_hex_byte;
      IF Mod_Adr IN [0..255] THEN status := TRUE;
     End;
    Mil_Ask_ModAdr:= Mod_Adr;
  End; {Mil_Ask_ModAdr}


Procedure Mil_DAC_ADC;
  LABEL 99;
  const Sub_Adr_DAC = 0;
        Sub_Adr_IW1 = 2;
        Sub_Adr_IW2 = 4;
        Z_Start     = 4;
        Z_Off_Text  = 0;
        Z_Off_Data  = 11;

        S_Start     = 10;
        S_Off_DAC   = 12;
        S_Off_IW1   = 33;
        S_Off_IW2   = 55;

  VAR
     Bit16_Strg: Str19;
     error_cnt  : LONGINT;
     MilErr : TMilErr;
     Fct    : TFct;
     Mil_Timout : Boolean;
     Write_Data,Displ_Data : Word;
     Wr_Sw_Flag : Boolean;
     Fct_11_Dta : Word;
     ADC_Dta    : Word;
     DAC_Dta    : Word;
     Id_Dez     : Byte;
     Mod_Adress : Byte;
     Online_New : Boolean;
     Online_Old : Boolean;
     Sub_Adr    : Byte;
     I          : Byte;
{
   procedure Displ_Mod_Headline;
    begin
     Set_Text_Win;
     GotoXY(01,Z_Start);
     write('v----------------------------- Status I/O-Modul ---------------------------- v');
     Set_Color_Alarm;
     GotoXY(01,Z_Start+1); write('IFC-Adr Modul-Adr  ID-Card  ID-VG   Skl MoAdr  EPLD Frei  Sta2 Sta1  Sta4 Sta3');
     Set_Color_Norm;
     GotoXY(01,Z_Start+2); write(' [Hex]    [Hex]    [Dez] <FE  FF>   <FC  FD>   <FA  FB>   <F8  F9>   <F6  F7>');
   end;

}
   procedure Displ_Mod_Info (Ifc_Adr: Byte; Mod_Adr: Byte; Z_Mod: Byte);
    const S_Mod_ID_Dta  = 28;
    var   IOsub_Adr    : Byte;
          S_Mod_Akt    : Byte;
          V            : Byte;
          Fct_11_Data  : Word;
          Rd_Data      : Word;
    begin
     Set_Text_Win;
     S_Mod_Akt := S_Mod_ID_Dta;
     GotoXY(04,Z_Mod); write(Hex_Byte(Ifc_Adr),'       ',Hex_Byte(Mod_Adr));
     IOsub_Adr := $FE;

     for V := 1 to 5  do
      begin
        Fct.B.Adr  := Ifc_Adr;
        Fct_11_Data:= (Mod_Adr*256) + IOsub_Adr;
        Fct.B.Fct  := Fct_Wr_Iob_Adr;
        Mil.Wr (Fct_11_Data, Fct, MilErr);

        Fct.B.Fct  :=  Fct_Rd_Iob_Dta;
        Mil.Rd (Rd_Data, Fct, MilErr);

        if (IOsub_Adr = $FE) then
         begin
          GotoXY(S_Mod_Akt-7,Z_Mod);
          Id_Dez := (Rd_Data and $FF00) shr 8;
          Write (Id_Dez:3);
         end;

        GotoXY(S_Mod_Akt,Z_Mod);
        Write (hex_word(Rd_Data));
        S_Mod_Akt := S_Mod_Akt + 11;
        IOsub_Adr := IOsub_Adr - 2;
      end;
   end;

   function Get_Data (var ADC_Data: Word): Boolean;
    Begin
     Mil.Rd (ADC_Data, Fct, MilErr);
     IF MilErr  <> No_Err THEN
      Begin
       Get_Data := False;
      End
     ELSE
      Begin  {kein Timeout}
       Get_Data := True;
      End;
    End; {Get_Data}

  begin            { mainbody Mil_DAC_ADC }
   Sub_Adr := 0;
   Wr_Sw_Flag := True;
   timout_cnt := 0;
   Ini_Text_Win;
   Mod_Adress := Mil_Ask_ModAdr;

   if not IO_Mod_Online (Ifc_Test_Nr, Mod_Adress) then
    begin
      Ini_Text_Win;
      Ini_Err_Win;
      Write ('ERROR: I/O-Modul [',Hex_Byte(Mod_Adress),']  nicht gefunden!!  Ende mit beliebiger Taste!');
      repeat until KeyPressed;
      goto 99;
    end;


   Ini_Text_Win;
   GotoXY(01, 22);
   write ('Der SW DAC kann analog (+/- 10.000 V) oder digital (0000..FFFF) gesetzt werden! ');
   Ini_Msg_Win;
   Write('Sollwert DAC [A]nalog, [D]igital oder weiter mit <CR>');
   Ch := ReadKey;
   case Ch of
    'a', 'A' : begin
                Write_Data := Rd_Real_10;
               end;
    'd', 'D' : begin
                Write_Data := Ask_Data;;
               end;
   else
    Wr_Sw_Flag := False; {keinen Sollwert schreiben}
   end;  {case}

   Ini_Text_Win;
   Fct.B.Adr  := Ifc_Test_Nr;         {IFC-Adr einfÅgen}
   if Wr_Sw_Flag then
    begin
      Fct_11_Dta:= (Mod_Adress * 256) + Sub_Adr_DAC;  {Modul-Adr ins Hibyte, Subadr Lowbyte}
      Fct.B.Fct  := Fct_Wr_Adr;   {11}                      {Adr zum I/O-Bus}
      Mil.Wr (Fct_11_Dta, Fct, MilErr);

      Fct.B.Fct  := Fct_Wr_Dta;   {10}                {Sende Daten zur Subadr}
      Mil.Wr (Write_Data , Fct, MilErr);
    end;

{yyy}

   {Init Display}
   GotoXY(23,Z_Start-03); Write('-------- TESTPROGRAMM DAC/ADC --------');

{   Displ_Mod_Headline; }
   GotoXY(S_Start+S_Off_DAC+1,Z_Start+Z_Off_Data-2);   Write('[DAC]');
   GotoXY(S_Start+S_Off_IW1+1,Z_Start+Z_Off_Data-2);   Write('[IW1]');
   GotoXY(S_Start+S_Off_IW2+1,Z_Start+Z_Off_Data-2);   Write('[IW2]');

   GotoXY(01,Z_Start+Z_Off_Data-1);                   Write('Sub-Adr       :');
   GotoXY(S_Start+S_Off_DAC+2,Z_Start+Z_Off_Data-1);  Write('00');
   GotoXY(S_Start+S_Off_IW1+2,Z_Start+Z_Off_Data-1);  Write('02');
   GotoXY(S_Start+S_Off_IW2+2,Z_Start+Z_Off_Data-1);  Write('04');

   GotoXY(01,Z_Start+6);  Write('Transfer-Count: ');
   GotoXY(01,Z_Start+7);  Write('Timeout       : ');

   GotoXY(01,Z_Start+Z_Off_Data+0);  Write('Sollwert [Hex]:');
   GotoXY(01,Z_Start+Z_Off_Data+1);  Write('Istwert  [Hex]:');
   GotoXY(01,Z_Start+Z_Off_Data+2);  write('Istwert  [BIN]:');

   GotoXY(S_Start+S_Off_DAC-4+S_Off_DAC-12,Z_Start+Z_Off_Data+3);  write('MSB             LSB');
   GotoXY(S_Start+S_Off_DAC-4+S_Off_IW1-12,Z_Start+Z_Off_Data+3);  write('MSB             LSB');
   GotoXY(S_Start+S_Off_DAC-4+S_Off_IW2-12,Z_Start+Z_Off_Data+3);  write('MSB             LSB');
   GotoXY(01,Z_Start+Z_Off_Data+4);  write('Istwert [Volt]:');

   {Sollwert in Hex und Volt anzeigen}
   if  Wr_Sw_Flag then  {Sollwert schreiben}
    begin
      GotoXY(S_Start+S_Off_DAC+2,Z_Start+Z_Off_Data+0);  write(hex_word(Write_Data));
    end;

    if IO_Mod_Online (Ifc_Test_Nr, Mod_Adress) then
      begin
       Online_New := True;
       Online_Old := Online_New;
       Displ_IO_Status (Ifc_Test_Nr,Mod_Adress,Sub_Adr,Z_Start)
      end
    else
      begin
       Online_New := FALSE;
       Online_Old := Online_New;
       Set_Text_Win;
       GotoXY(10,Z_Start); write('ERROR: Modul-Nr.',hex_byte(Mod_Adress),'[Hex] ist nicht online!!');
      end;

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
        Online_New := IO_Mod_Online (Ifc_Test_Nr, Mod_Adress);
        if Online_New <> Online_Old then
          begin
            Online_Old := Online_New;   {Rette den neuen Status}
            if Online_New then          {Modul ist jetzt Online}
              begin
               for i := 0 to 3 do begin GotoXY(01,Z_Start + I); ClrEol; end;
               Displ_IO_Status (Ifc_Test_Nr,Mod_Adress,Sub_Adr,Z_Start)
              end
            else
              begin                     {Modul ist jetzt Offline}
               for i := 0 to 3 do begin GotoXY(01,Z_Start + I); ClrEol; end;
               GotoXY(10,Z_Start); write('ERROR: Modul-Nr.',hex_byte(Mod_Adress),' [Hex] ist nicht online!!');
              end;
          end;

       if Online_New then Displ_Mod_Info (Ifc_Test_Nr, Mod_Adress, Z_Start+3);

      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,10);  Write(Transf_Cnt:10);

      {Istwert DAC rÅcklesen }
      Fct_11_Dta:= (Mod_Adress * 256) + Sub_Adr_DAC;  {Modul-Adr ins Hibyte, Subadr Lowbyte}
      Fct.B.Fct  := Fct_Wr_Adr;   {11}                      {Adr zum I/O-Bus}
      Mil.Wr (Fct_11_Dta, Fct, MilErr);

      Fct.B.Fct := Fct_Rd_Dta;
      if Get_Data (DAC_Dta) then
       begin    {read daten ok}
        GotoXY(S_Start+S_Off_DAC+2,Z_Start+Z_Off_Data+1);  write(hex_word(DAC_Dta));
        GotoXY(S_Start+S_Off_DAC  ,Z_Start+Z_Off_Data+4);  Write_Real_10 (DAC_Dta);
        Hex_Bin_Str (DAC_Dta,bit16_str);
        GotoXY(S_Start+S_Off_DAC-4,Z_Start+Z_Off_Data+2);  write(bit16_str);
       end
      else
       begin    {read timeout}
         timout_cnt := timout_cnt + 1;
         GotoXY(S_Start+S_Off_DAC+2,Z_Start+Z_Off_Data+1);  write('     ');
         GotoXY(S_Start+S_Off_DAC  ,Z_Start+Z_Off_Data+4);  Write('        ');
         GotoXY(S_Start+S_Off_DAC-4,Z_Start+Z_Off_Data+2);  write('                   ');
       end;

      {Istwert 1 lesen}
      Fct_11_Dta:= (Mod_Adress * 256) +  Sub_Adr_IW1;  {Modul-Adr ins Hibyte, Subadr Lowbyte}
      Fct.B.Fct  := Fct_Wr_Adr;   {11}                      {Adr zum I/O-Bus}
      Mil.Wr (Fct_11_Dta, Fct, MilErr);

      Fct.B.Fct := Fct_Rd_Dta;
      if Get_Data (ADC_Dta) then
       begin    {read daten ok}
        GotoXY(S_Start+S_Off_IW1+2,Z_Start+Z_Off_Data+1);  write(hex_word(ADC_Dta));
        GotoXY(S_Start+S_Off_IW1  ,Z_Start+Z_Off_Data+4);  Write_Real_10 (ADC_Dta);
        Hex_Bin_Str (ADC_Dta,bit16_str);
        GotoXY(S_Start+S_Off_IW1-4,Z_Start+Z_Off_Data+2);  write(bit16_str);
       end
      else
       begin    {read timeout}
         timout_cnt := timout_cnt + 1;
         GotoXY(S_Start+S_Off_IW1+2,Z_Start+Z_Off_Data+1);  write('     ');
         GotoXY(S_Start+S_Off_IW1  ,Z_Start+Z_Off_Data+4);  Write('        ');
         GotoXY(S_Start+S_Off_IW1-4,Z_Start+Z_Off_Data+2);  write('                   ');
       end;

      {Istwert 2 lesen}
      Fct_11_Dta:= (Mod_Adress * 256) +  Sub_Adr_IW2;  {Modul-Adr ins Hibyte, Subadr Lowbyte}
      Fct.B.Fct  := Fct_Wr_Adr;   {11}                      {Adr zum I/O-Bus}
      Mil.Wr (Fct_11_Dta, Fct, MilErr);

      Fct.B.Fct := Fct_Rd_Dta;
      if Get_Data (ADC_Dta) then
       begin    {read daten ok}
        GotoXY(S_Start+S_Off_IW2+2,Z_Start+Z_Off_Data+1);  write(hex_word(ADC_Dta));
        GotoXY(S_Start+S_Off_IW2  ,Z_Start+Z_Off_Data+4);  Write_Real_10 (ADC_Dta);
        Hex_Bin_Str (ADC_Dta,bit16_str);
        GotoXY(S_Start+S_Off_IW2-4,Z_Start+Z_Off_Data+2);  write(bit16_str);
       end
      else
       begin    {read timeout}
         timout_cnt := timout_cnt + 1;
         GotoXY(S_Start+S_Off_IW2+2,Z_Start+Z_Off_Data+1);  write('     ');
         GotoXY(S_Start+S_Off_IW2  ,Z_Start+Z_Off_Data+4);  Write('        ');
         GotoXY(S_Start+S_Off_IW2-4,Z_Start+Z_Off_Data+2);   write('                   ');
       end;

      GotoXY(25,Z_Start+7);  write(timout_cnt:10);
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
End; {Mil_DAC_ADC}

{xxx}

procedure Mil_IO_Status;
  label 99;
  const Sub_Adr_DAC = 0;
        Sub_Adr_IW1 = 2;
        Sub_Adr_IW2 = 4;

        Z_Start     = 4;     {Zeile}
        Z_Off_Text  = 0;
        Z_Off_Data  = 11;

        S_Start     = 10;    {Spalte}
        S_Off_DAC   = 12;
        S_Off_IW1   = 33;
        S_Off_IW2   = 55;

  var
     Bit16_Strg : Str19;
     error_cnt  : LONGINT;
     MilErr     : TMilErr;
     Fct        : TFct;
     Mil_Timout : Boolean;
     Write_Data,Displ_Data : Word;
     Wr_Sw_Flag : Boolean;
     Fct_11_Dta : Word;
     ADC_Data   : Word;
     DAC_Data   : Word;
     Id_Dez     : Byte;

   procedure Displ_Mod_Headline;
    begin
     Set_Text_Win;
     GotoXY(05,02);
     Write ('FunctionCodes [Hex]:  Wr_AdrBus= [',Hex_byte (Fct_Wr_Adr),']   Wr_DtaBus= [', Hex_byte (Fct_Wr_Dta),']');
     Write ('    Rd_DtaBus= [', Hex_byte (Fct_Rd_Dta),']');

     GotoXY(01,Z_Start);
     write('v----------------------------- Status I/O-Modul ---------------------------- v');
     Set_Color_Alarm;
     GotoXY(01,Z_Start+1); write('IFC-Adr Modul-Adr  ID-Card  ID-VG   Skl MoAdr  EPLD Frei  Sta2 Sta1  Sta4 Sta3');
     Set_Color_Norm;
     GotoXY(01,Z_Start+2); write(' [Hex]    [Hex]    [Dez] <FE  FF>   <FC  FD>   <FA  FB>   <F8  F9>   <F6  F7>');
   end;

   procedure Displ_Mod_Info (Ifc_Adr: Byte; Mod_Adr: Byte; Z_Mod: Byte);
    const S_Mod_ID_Dta  = 28;      {Default Spalte fÅr Modulidentdaten}
    var   IOsub_Adr    : Byte;
          Fct_11_Data  : Word;
          Rd_Data      : Word;
          S_Mod_Akt    : Byte;
          V            : Byte;
    begin
     Set_Text_Win;
     S_Mod_Akt := S_Mod_ID_Dta;
     GotoXY(04,Z_Mod); write(Hex_Byte(Ifc_Adr),'       ',Hex_Byte(Mod_Adr));
     IOsub_Adr := $FE;                               {Word-Adr fÅr Identdaten}

     for V := 1 to 5  do                         {Lese 3 Worte mit Identdaten}
      begin
        Fct.B.Adr  := Ifc_Adr;
        Fct_11_Data:= (Mod_Adr*256) + IOsub_Adr;  {Modul-Adr ins Hibyte, Subadr Lowbyte}
        Fct.B.Fct  := Fct_Wr_Iob_Adr;
        Mil.Wr (Fct_11_Data, Fct, MilErr);                     {Adr zum I/O-Bus}

        Fct.B.Fct  :=  Fct_Rd_Iob_Dta;             {Lesen Daten von APL-IO-Bus}
        Mil.Rd (Rd_Data, Fct, MilErr);

        if (IOsub_Adr = $FE) then                  {ID auch dezimal ausgeben}
         begin
          GotoXY(S_Mod_Akt-7,Z_Mod);
          Id_Dez := (Rd_Data and $FF00) shr 8;
          Write (Id_Dez:3);
         end;

        GotoXY(S_Mod_Akt,Z_Mod);
        Write (hex_word(Rd_Data));
        S_Mod_Akt := S_Mod_Akt + 11;
        IOsub_Adr := IOsub_Adr - 2;
      end; {For V 1..5}
   end; {Displ_Mod_Info}


   function Get_Data (var ADC_Data: Word): Boolean;
    Begin
     Mil.Rd (ADC_Data, Fct, MilErr);
     IF MilErr  <> No_Err THEN
      Begin
       Get_Data := False;
      End
     ELSE
      Begin  {kein Timeout}
       Get_Data := True;
      End;
    End; {Get_Data}

  begin
   Wr_Sw_Flag := True;
   timout_cnt := 0;
   Ini_Text_Win;
   IO_ModAdr := Mil_Ask_ModAdr;

   if not IO_Mod_Online (Ifc_Test_Nr, IO_ModAdr) then
    begin
      Ini_Text_Win;
      Ini_Err_Win;
      Write ('ERROR: I/O-Modul [',Hex_Byte(IO_ModAdr),']  nicht gefunden!!  Ende mit beliebiger Taste!');
      repeat until KeyPressed;
      goto 99;
    end;

   Ini_Text_Win;
   Fct.B.Adr  := Ifc_Test_Nr;
   if Wr_Sw_Flag then
    begin
      Fct_11_Dta:= (IO_ModAdr * 256) + Sub_Adr_DAC;  {Modul-Adr ins Hibyte, Subadr Lowbyte}
      Fct.B.Fct  := Fct_Wr_Adr;   {11}                      {Adr zum I/O-Bus}
      Mil.Wr (Fct_11_Dta, Fct, MilErr);

      Fct.B.Fct  := Fct_Wr_Dta;   {10}                {Sende Daten zur Subadr}
      Mil.Wr (Write_Data , Fct, MilErr);
    end;

   {Init Display}
   GotoXY(15,Z_Start-03); Write('-------- IO-STATUS ANZEIGEN fÅr Sub-Adr 0, 2, 4 --------');
   Displ_Mod_Headline;

   GotoXY(S_Start+S_Off_DAC+0,Z_Start+Z_Off_Data-2);   Write('[STAT1]');
   GotoXY(S_Start+S_Off_IW1+0,Z_Start+Z_Off_Data-2);   Write('[STAT2]');
   GotoXY(S_Start+S_Off_IW2+0,Z_Start+Z_Off_Data-2);   Write('[STAT3]');

   GotoXY(01,Z_Start+Z_Off_Data-1);                   Write('Sub-Adr       :');
   GotoXY(S_Start+S_Off_DAC+2,Z_Start+Z_Off_Data-1);  Write('00');
   GotoXY(S_Start+S_Off_IW1+2,Z_Start+Z_Off_Data-1);  Write('02');
   GotoXY(S_Start+S_Off_IW2+2,Z_Start+Z_Off_Data-1);  Write('04');

   GotoXY(01,Z_Start+6);  Write('Transfer-Count: ');
   GotoXY(01,Z_Start+7);  Write('Timeout       : ');

   GotoXY(01,Z_Start+Z_Off_Data+1);  Write('Status   [Hex]:');
   GotoXY(01,Z_Start+Z_Off_Data+2);  write('Status   [BIN]:');

   GotoXY(S_Start+S_Off_DAC-4+S_Off_DAC-12,Z_Start+Z_Off_Data+3);  write('MSB             LSB');
   GotoXY(S_Start+S_Off_DAC-4+S_Off_IW1-12,Z_Start+Z_Off_Data+3);  write('MSB             LSB');
   GotoXY(S_Start+S_Off_DAC-4+S_Off_IW2-12,Z_Start+Z_Off_Data+3);  write('MSB             LSB');

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
      Displ_Mod_Info (Ifc_Test_Nr, IO_ModAdr, Z_Start+3);

      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(25,10);  Write(Transf_Cnt:10);

      {Istwert DAC rÅcklesen lesen}
      Fct_11_Dta:= (IO_ModAdr * 256) + Sub_Adr_DAC;  {Modul-Adr ins Hibyte, Subadr Lowbyte}
      Fct.B.Fct  := Fct_Wr_Adr;   {11}                      {Adr zum I/O-Bus}
      Mil.Wr (Fct_11_Dta, Fct, MilErr);

      Fct.B.Fct := Fct_Rd_Dta;
      if Get_Data (DAC_Data) then
       begin    {read daten ok}
        GotoXY(S_Start+S_Off_DAC+2,Z_Start+Z_Off_Data+1);  write(hex_word(DAC_Data));
        Hex_Bin_Str (DAC_Data,bit16_str);
        GotoXY(S_Start+S_Off_DAC-4,Z_Start+Z_Off_Data+2);  write(bit16_str);
       end
      else
       begin    {read timeout}
         timout_cnt := timout_cnt + 1;
       end;

      {Istwert 1 lesen}
      Fct_11_Dta:= (IO_ModAdr * 256) +  Sub_Adr_IW1;  {Modul-Adr ins Hibyte, Subadr Lowbyte}
      Fct.B.Fct  := Fct_Wr_Adr;   {11}                      {Adr zum I/O-Bus}
      Mil.Wr (Fct_11_Dta, Fct, MilErr);

      Fct.B.Fct := Fct_Rd_Dta;
      if Get_Data (ADC_Data) then
       begin    {read daten ok}
        GotoXY(S_Start+S_Off_IW1+2,Z_Start+Z_Off_Data+1);  write(hex_word(ADC_Data));
        Hex_Bin_Str (ADC_Data,bit16_str);
        GotoXY(S_Start+S_Off_IW1-4,Z_Start+Z_Off_Data+2);  write(bit16_str);
       end
      else
       begin    {read timeout}
         timout_cnt := timout_cnt + 1;
       end;

      {Istwert 2 lesen}
      Fct_11_Dta:= (IO_ModAdr * 256) +  Sub_Adr_IW2;  {Modul-Adr ins Hibyte, Subadr Lowbyte}
      Fct.B.Fct  := Fct_Wr_Adr;   {11}                      {Adr zum I/O-Bus}
      Mil.Wr (Fct_11_Dta, Fct, MilErr);

      Fct.B.Fct := Fct_Rd_Dta;
      if Get_Data (ADC_Data) then
       begin    {read daten ok}
        GotoXY(S_Start+S_Off_IW2+2,Z_Start+Z_Off_Data+1);  write(hex_word(ADC_Data));
        Hex_Bin_Str (ADC_Data,bit16_str);
        GotoXY(S_Start+S_Off_IW2-4,Z_Start+Z_Off_Data+2);  write(bit16_str);
       end
      else
       begin    {read timeout}
         timout_cnt := timout_cnt + 1;
       end;

      GotoXY(25,Z_Start+7);  write(timout_cnt:10);
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
end; {Mil_IO_Status}



 procedure Ask_Ifc_Mod_Adr;
  begin
   Ini_Text_Win;
   Mil_Ask_Ifc;
   Mil_Ask_Mod;
  end; {Test_Adr}

 const
  Ext_Evt_Max = 12;
  SubAdr_12Evt_Stat     = $0E; {Subadr f. Modul 12Evt Status       }
  SubAdr_12Evt_LastEvt  = $02; {Subadr f. Modul 12Evt letzter Event}
  SubAdr_12Evt_Mask     = $04; {Subadr f. Modul 12Evt MaskReg f. ext. Events}
  SubAdr_12Evt_EnExtEvt = $08; {Subadr f. Modul 12Evt Enable  ext. Events}
  SubAdr_12Evt_DisExtEvt= $0A; {Subadr f. Modul 12Evt Disable ext. Events}
  SubAdr_12Evt_Reset    = $0C; {Subadr f. Modul 12Evt Reset Karte}



 procedure Evt_Status;
  Label 99;
  const
   Z_Base = 5;
   Rd_Evt_Mask        = $003F;    {Ext. Maskenbits nur Bit 0..5}
   Rd_Evt_Mask1       = $0001;
   Rd_Evt_Mask2       = $0002;
   Rd_Evt_Mask3       = $0004;
   Rd_Evt_Mask4       = $0008;
   Rd_Evt_Mask5       = $0010;
   Rd_Evt_Mask6       = $0020;

 type
  TMask_Mode = (Enable, Disable);

  VAR read_data,fct_code : WORD;
      MilErr     : TMilErr;
      Fct        : TFct;
      Transf_Cnt : LongInt;
      Timout_Cnt : LongInt;
      Rd_Stat_Cnt:  LongInt;
      WrData     : Word;
      Adress     : Word;
      ModAdr     : TModAdr;

  procedure  Set_TastEvt_Win;
  begin
   Window(03, 21, 48, 23);
   TextBackground(Green);
   TextColor(Black);               {Setze Schriftfarbe}
  end;

 procedure Ini_Event_Win;
  begin
   Window(50, 08, 80, 24);
   TextBackground(Cyan);
   TextColor(Black);               {Setze Schriftfarbe}
   ClrScr;
  end;

 PROCEDURE displ_mod_stat;
  Begin
     {Info-Anzeige der Bit-Belegung IFC-Status}
      Ini_Event_Win;
      writeln('Bit 15:                       ');
      writeln('Bit 14:                       ');
      writeln('Bit 13:                       ');
      writeln('Bit 12:                       ');
      writeln('Bit 11:                       ');
      writeln('Bit 10:                       ');
      writeln('Bit 09:                       ');
      writeln('Bit 08:                       ');
      writeln;
      writeln('Bit 07:                       ');
      writeln('Bit 06:                       ');
      writeln('Bit 05:                       ');
      writeln('Bit 04: Int Freq 0=6 1=12 Mhz ');
      writeln('Bit 03: Timeout-Evt  1=erzeugt');
      writeln('Bit 02: Evt ext      1= Error ');
      writeln('Bit 01: Evt ext gen. 1= ja    ');
      write  ('Bit 00: Evt ext      1= Enable');
   End; {displ_ifc_stat}


  PROCEDURE show_stat_reg;
   var Bit16_Strg: Str19;
       Read_Data : Word;

    Begin
     Set_Text_Win;
     Rd_Stat_Cnt:= Rd_Stat_Cnt + 1;
     ModAdr.AdrIfc  := Ifc_Test_Nr;
     ModAdr.AdrCard := Mod_Test_Nr;
     ModAdr.AdrSub  := SubAdr_12Evt_Stat;
     ModAdr.AdrMode := AdrNew;

     Mil.Rd_ModBus (Read_Data, ModAdr, MilErr);
     if MilErr = No_Err then
      begin
        GotoXY(28, Z_Base+7);  write(hex_word(read_data));
        Hex_Bin_Str (read_data, bit16_strg);
        GotoXY(22, Z_Base+8);  write(bit16_strg);
      end
     else
      begin
        GotoXY(28, Z_Base+7);  write('    ');
        TextColor (Red);
        GotoXY(22, Z_Base+8);  write('   Read Error!!    ');
        TextColor (Black);
      end;

     GotoXY(31, Z_Base+5); Write (Rd_Stat_Cnt:10);

     ModAdr.AdrSub  := SubAdr_12Evt_LastEvt;  {nur die Subadr Ñndert sich}
     Mil.Rd_ModBus (Read_Data, ModAdr, MilErr);
     if MilErr = No_Err then
      begin
        GotoXY(28, Z_Base+11);  write(hex_word(read_data));
      end
     else
      begin
        GotoXY(28, Z_Base+11);  write('    ');
     end;
    End; {show_stat_reg; }


 procedure Evt_Mask_Toggle (Mask_Mode: TMask_Mode);
   label 1;
   var Wr_Data : Word;
       Rd_Data : Word;
       Mod_Adr : TModAdr;
       Mask_BitNr: Integer;
   begin
    if not Read_Int (1, Ext_Evt_Max, Mask_BitNr) then goto 1; {frage User nach Bitnummer}
    Rd_Stat_Cnt:= Rd_Stat_Cnt + 1;
    Mod_Adr.AdrIfc  := Ifc_Test_Nr;
    Mod_Adr.AdrCard := Mod_Test_Nr;
    Mod_Adr.AdrSub  := SubAdr_12Evt_Mask;
    Mod_Adr.AdrMode := AdrNew;
    Mil.Rd_ModBus (Rd_Data, Mod_Adr, MilErr);   {Lese Maskenregister}
    if MilErr <> No_Err then
     begin
       Ini_Err_Win;
       Write ('ERROR: Lesen des Maskenregisters fehlerhaft!');
       Mil.Timer2_Wait(200000);
       goto 1;
     end;

    case Mask_Mode of
       Enable : begin
                  Wr_Data := Rd_Data;            {Maskbits: D0..D11}
                  Wr_Data := BitSet (Wr_Data, Mask_BitNr-1);  {1= en ext. Evt}
                  Mil.Wr_ModBus (Wr_Data, Mod_Adr, MilErr);
                  Ini_Err_Win;
                  Write ('Enable ext. Event-Nr: ', Mask_BitNr);
                  Mil.Timer2_Wait(200000);
                end;

       Disable: begin
                  Wr_Data := Rd_Data;             {Maskbits: D0..D11}
                  Wr_Data := BitClr (Wr_Data, Mask_BitNr-1);  {1= en ext. Evt}
                  Mil.Wr_ModBus (Wr_Data, Mod_Adr, MilErr);
                  Ini_Err_Win;
                  Write ('Disable ext. Event-Nr: ', Mask_BitNr);
                  Mil.Timer2_Wait(200000);
                end;
    end; {case}
1:    Std_Msg;
   end; {Ifc_Mask_Toggle}

  Begin
   Ini_Text_Win;
   Displ_Mod_Stat;
   Set_Text_Win;

   Rd_Stat_Cnt:= 0;
   transf_cnt := 0;
   timout_cnt := 0;
   GotoXY(16,01); write('------ Lese Status des Event-Piggy + letzter Event -----');
   TextColor(Yellow);
   GotoXY(15,03); write('Set/Clear Event-Maske[1..12]: mit F1 bzw. F3-Tasten! ');
   TextColor(Brown);
   GotoXY(50,05); write  ('Bedeutung der Event Status-Bits');

   GotoXY(06,Z_Base+3);  write('Wr_Mask_Count :');
   GotoXY(06,Z_Base+5);  write('Stat-Rd-Count :');
   GotoXY(35,Z_Base+6);  write('^  ^');
   GotoXY(06,Z_Base+7);  write('Stat-Data[Hex]:');
   GotoXY(06,Z_Base+8);  write('Stat-Data[Bin]:');
   GotoXY(06,Z_Base+9);  write('Mask-Data[Bin]:');
   GotoXY(22,Z_Base+10); write('MSB             LSB');
   GotoXY(06,Z_Base+11); write('Last-Evnt[Hex]:');

   Set_Text_Win;
   TextColor(Brown);
   GotoXY(03,18); write  ('Belegung der Funktions-Tasten:');

   Set_TastEvt_Win;
   TextColor(Yellow);
   GotoXY(01, 01); Write('F1: En  Evt-Mask     F10: En  ext. Event');
   GotoXY(01, 02); Write(' ', (chr($7C)),'    [1..12]        F11: Dis ext. Event');
   GotoXY(01, 03); Write('F3: Dis Evt-Mask     F12: Reset Evt-Pigy');
   TextColor(Black);

   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Set_Text_win;
       Show_Stat_Reg;
       Mil.Timer2_Wait(1000);
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Set_Text_win;
       Show_Stat_Reg;
       Mil.Timer2_Wait(1000);
      end;

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : Evt_Mask_Toggle (Enable);
        Taste_F3 : Evt_Mask_Toggle (Disable);

        Taste_F10: begin
                     ModAdr.AdrIfc  := Ifc_Test_Nr;
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrSub  := SubAdr_12Evt_EnExtEvt;
                     ModAdr.AdrMode := AdrNew;
                     WrData := 0;
                     Mil.Wr_ModBus (WrData, ModAdr, MilErr);
                     Ini_Err_Win;
                     Write ('ENABLE Ext. Event !!!');
                     Mil.Timer2_Wait(200000);
                     Std_Msg;
                     Ch := ' ';
                   end; {Taste_F10}

        Taste_F11: begin
                     ModAdr.AdrIfc  := Ifc_Test_Nr;
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrSub  := SubAdr_12Evt_DisExtEvt;
                     ModAdr.AdrMode := AdrNew;
                     WrData := 0;
                     Mil.Wr_ModBus (WrData, ModAdr, MilErr);
                     Ini_Err_Win;
                     Write ('DISABLE Ext. Event !!!');
                     Mil.Timer2_Wait(200000);
                     Std_Msg;
                     Ch := ' ';
                   end; {Taste_F11}
        Taste_F12: begin
                     ModAdr.AdrIfc  := Ifc_Test_Nr;
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrSub  := SubAdr_12Evt_Reset;
                     ModAdr.AdrMode := AdrNew;
                     WrData := 0;
                     Mil.Wr_ModBus (WrData, ModAdr, MilErr);
                     Ini_Err_Win;
                     Write ('Reset 12Evt-Modul !!!');
                     Mil.Timer2_Wait(200000);
                     Std_Msg;
                     Ch := ' ';
                   end; {Taste_F12}
       end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
 end; {Evt_Status}




BEGIN   { Hauptprogramm }
  Ifc_Test_Nr := 0;
  Mod_Test_Nr := 0;

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
    User_Input := ReadKey;
    loop := TRUE;
    IF User_Input IN ['0'..'9'] THEN loop := FALSE;
    CASE User_Input OF
     '0'      : Mil_Detect_Ifc;
     '1'      : Mil_Detect_Ifc_Compare;

     '2'      : begin
                  if Check_Ifc_Adr (Ifc_Test_Nr) then Mil_Rd_HS_Ctrl (Ifc_Test_Nr);
                end;
     '3'      : begin
                  if Check_Ifc_Adr (Ifc_Test_Nr) then Mil_Rd_HS_Status (Ifc_Test_Nr);
                end;
     '4'      : begin
                  if Check_Ifc_Adr (Ifc_Test_Nr) then Mil_Stat_All (Ifc_Test_Nr);
                end;
     '5'      : begin
                  Convert_Hex_Volt;
                end;
     '6'      : begin
                  Int_Mask;
                end;
     '7'      : begin
                  if Check_Ifc_Adr (Ifc_Test_Nr) then Mil_HS_Stat_Cmd (Ifc_Test_Nr);
                end;
     '9'      : begin
		  if Check_Ifc_Adr (Ifc_Test_Nr) then Mil_Echo (Ifc_Test_Nr);
                end;
     'a', 'A' :   Mil_Ask_Ifc;
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
                  if Check_Ifc_Adr (Ifc_Test_Nr) then Mil_Rd_Data;
		end;
     'f', 'F' : begin
                  Functioncode_Table;
                end;
     'g', 'G' : begin
                  Mil_Data := Ask_Data;
		  Mil_WrData (Mil_Data);
                end;
     'h', 'H' : begin
		  Mil_Wr_Fctcode;
                end;
     'i', 'I' : begin
                  if Check_Ifc_Adr (Ifc_Test_Nr) THEN
                   begin
		     Mil_Wr (Mil_Data);
                   end;
                end;
     'j', 'J' : begin
		  if Check_Ifc_Adr (Ifc_Test_Nr) then
		    begin
		     Mil_Data := Ask_Data;
		     Mil_Wr_Rd (Mil_Data);
 		    end;
                end;
     'k', 'K' : begin
		  if Check_Ifc_Adr (Ifc_Test_Nr) then Mil_Loop;
                end;

     'l', 'L' : begin
                  Mil_Dual_Mode;
                end;
     'z', 'Z' : begin
                  Telefon;
                end;
     {Ab hier User-Erweiterungen!!}
     'm', 'M' : begin
                 if (Ifc_Test_Nr = 0) or (Mod_Test_Nr = 0) then Ask_Ifc_Mod_Adr;
                 Evt_Status;
                end;
     'n', 'N' : begin
                end;
     'o', 'O' : begin

                end;
     'p', 'P' : begin
                 if Check_Ifc_Adr (Ifc_Test_Nr) THEN
                  begin
                    if Ask_IO_Adr (Mil_Data) then Mil_Wr_11 (Mil_Data);
                  end;
                end;
     'q', 'Q' : begin
                 if Check_Ifc_Adr (Ifc_Test_Nr) THEN
                  begin
                    if Ask_IO_Adr (Mil_Data) then Mil_Wr_11 (Mil_Data);
                  end;
                 end;
     'r', 'R' : begin
                 if Check_Ifc_Adr (Ifc_Test_Nr) THEN
                  begin
		    Mil_DAC_ADC;
                  end;
                end;
     's', 'S' : begin
                 if Check_Ifc_Adr  (Ifc_Test_Nr) THEN
                  begin
                   Mil_IO_Status
                  end;
                end;
     't', 'T' : begin
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



 Function Mil_Ask_ModAdr: Byte;
  VAR answer : CHAR;
      Status : Boolean;
      Mod_Adr: Byte;

  Begin
    Status := FALSE;
    WHILE NOT Status DO
     Begin
      Ini_Text_Win;
      GotoXY(5, 22);
      write ('Welche Modul-Adr. testen?');
      Mod_Adr := ask_hex_byte;
      IF Mod_Adr IN [0..255] THEN status := TRUE;
     End;
    Mil_Ask_ModAdr:= Mod_Adr;
  End; {Mil_Ask_ModAdr}
