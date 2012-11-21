PROGRAM Mil_PZIU;
{ Autor des Basis-Programmes Mil_Base.PAS: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS
  Wegen Jahr 2000: File-Datum unter DOS ist ab 1.1.2000 -> 01.01.80

  Mil_PZIU: Spezial-Test-Programm, um Pulszentralen-Einschub mit Daten-Austausch
  zwischen Interlock und Unilac zu testen. 2 x 3 Modulbus 32-Bit-IO sind paarweise
  verschaltet:   (Achtung RÅcklesen: KanÑle Åberkreuz!!)
  Nur die IFK-Adr kînnen geÑndert werden; die Modul-Adr sind fixiert

      IFK-Adr 1                      IFK-Adr 2
      Mod-Adr 1    Kanal 0 <---      Kanal 1
                         1 <---      Kanal 0

      Mod-Adr 2    Kanal 0 <---      Kanal 1
                         1 <---      Kanal 0

      Mod-Adr 3    Kanal 0 --->      Kanal 1
                         1 --->      Kanal 0
   Beachten: 32-Bit-IO Daten-RÅcklesen fixiert auf Kabelverbindung:
             kein RÅcklesen Åber  SubAdr4u6 Outregister im 32-Bit-IO!!

         nicht mîglich '1' : Compare32 := Long32;
             "         '2' : Compare32 := Wr16Hi_Rd16Hi;
             "         '3' : Compare32 := Wr16Lo_Rd16Lo;

                       '4' : Compare32 := Wr16Hi_Rd16Lo;
                       '5' : Compare32 := Wr16Lo_Rd16Hi;

  énderungs-Protokoll:
  19.12.2000 Et


}
{$S-}
uses Crt, WinDos, Dos, Datech, Datech_0, Datech_1;    {spez. MIL-Routinen in Units Datech..}

const
 Head_Line =
      'BELAB                                MIL_PZIU   ' +
      '                    [19.12.2000]' +
      '      PrÅft Datenaustausch Interlock <--> Unilac PZ  IUUPZ1 (F700.610)         ';
{     '                  PrÅft Datenaustausch Interlock <--> Unilac PZ                ';
      '                        Allgemeines Devicebus Testprogramm                     ';
}
 procedure menue_win;
  var answer: CHAR;
 begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;            {Festliegender Teil des MenÅs: s. a. DATECH_0.PAS}
  TextColor(Blue);

   {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}


  GotoXY(5, 14);
  Writeln('       [M]<-- Datentransfer Interlock- <--> Unilac-Seite                 ');
{  GotoXY(5, 15);
  Writeln('       [N]<--                                                            ');
  GotoXY(5, 16);
  Writeln('       [O]<--                                                            ');
  GotoXY(5, 17);
  Writeln('       [P]<--                                                            ');
  GotoXY(5, 18);
  Writeln('       [Q]<--                                                            ');
  GotoXY(5, 19);
  Writeln('       [R]<--                                                            ');
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

 type
  TModeSubAdr = record
                 WrMode : Boolean;  {Anzeigen und Schreiben: Ja/Nein}
                 WrSub0 : Boolean;
                 WrSub2 : Boolean;
                 RdSub0 : Boolean;
                 RdSub2 : Boolean;
               end;

  TCardAdr    = record
                 IfkNr  : Byte;
                 ModAdr : Byte;
                end;

  TCardSubAdr = record
                 IfkNr  : Byte;
                 ModAdr : Byte;
                 SubAdr : Byte;
                end;

  TBackColor = (Gruen, Rot, Weiss, Magent, Blau, Gelb, Blank, BlankLoop, OnlinErr);

 procedure Ask_Ifc_Mod_Adr;
  begin
   Ini_Text_Win;
   Mil_Ask_Ifc;      {globale IFK:         Ifc_Test_Nr}
   Mil_Ask_Mod;      {globale Modul-Karte: Mod_Test_Nr}
  end; {Test_Adr}

  procedure Ini_Online_Win;
   begin
    Window(73, 10, 79, 23);
    TextBackground(Cyan);
    TextColor(yellow);               {Setze Schriftfarbe}
    ClrScr;
   end;

  procedure Clr_Online_Win;
   begin
    Window(73, 10, 79, 23);
    TextBackground(White);
    TextColor(Black);               {Setze Schriftfarbe}
    ClrScr;
   end;

 procedure Show_Ifk_Online;
  var I        : Word;
      RetAdr   : Byte;
      OnlineErr: TOnlineErr;
  begin
    Ini_Online_Win;
    Write ('- IFK -'); Write ('online:'); TextColor(Black);

    for I := 1 to 255 do
     begin
       Mil.Ifc_Online (I, RetAdr, OnlineErr);
       if OnlineErr = NoErr then Writeln ('  ',(Hex_Byte (RetAdr)));
     end; {for}
  end; {Show_Ifk_Online}

 procedure Show_Mod_Online;
  var I         : Word;
      Mod_RetAdr: Byte;
      OnlineErr : TOnlineErr;
  begin
    Ini_Online_Win;
    Write ('IFK: '); TextColor(Blue); Write(Hex_Byte(Ifc_Test_Nr)); TextColor(yellow);
    Write ('Module '); Write ('online:');
    TextColor(Black);
    if Ifc_Test_Nr = 0 then
     begin
       Writeln;
       Write (' ??? ');
     end
    else
     begin
       for I := 0 to $1F do
        begin
          Mil.Mod_Online (Ifc_Test_Nr, I, Mod_RetAdr, OnlineErr);
          if OnlineErr = NoErr then Writeln ('  ',(Hex_Byte (Mod_RetAdr)));
        end; {for}
     end; {if Test=0}
  end; {Show_Mod_Online}

 procedure Ini_WrRd32_Win;
  begin
   Window(65, 14, 79, 23);   { maximal 10 Zeilen }
   TextBackground(Cyan);
   TextColor(yellow);               {Setze Schriftfarbe}
   ClrScr; TextColor(magenta);
   {1} Write (' WR/RD 32bit-IO'); TextColor(yellow);
   {2} Write ('Mod-Adr1:      ');
   {3} Write ('   K0 <---- K1 '); TextColor(yellow);
   {4} Write ('   K1 <---- K0 ');
   {5} Write ('Mod-Adr2:      ');
   {6} Write ('   K0 <---- K1 ');
   {7} Write ('   K1 <---- K0 ');
   {8} Write ('Mod-Adr3:      ');
   {9} Write ('   K0 ----> K1 ');
   {10}Write ('   K1 ----> K0');
  end;

 procedure Clr_WrRd32_Win;
  begin
   Window(65, 14, 79, 23);
   TextBackground(White);
   ClrScr;
  end;

 procedure Modul_PzWrRd32; {Test fÅr 32-Bit-I/O mit Datenvergleich fÅr 32-
           oder 16 Bit. Beachten: DatenrÅcklesen von dem selben 32-BitIO
           ist default mÑssig auf Subadr 4 u. 6 (Outreg) eingestellt
           = internes Reg! Falls Åber externes Kabel Daten rÅckgelesen werden,
           muss auf Subadr 0 u. 2 umgestellt werden (F3) }
  const
   Z_Info     = 01;
   S_Info     = 15;

   Z_Data     = 10;
   S_Data     = 04;
   Z_Sub0_Hex = Z_Data+2;
   Z_Sub2_Hex = Z_Sub0_Hex+1;
   Z_Sub0_Bin = Z_Sub2_Hex+2;
   Z_Sub2_Bin = Z_Sub0_Bin+1;
   Z_Sub0_Life= Z_Sub0_Hex;
   Z_Sub2_Life= Z_Sub2_Hex;
   Z_WrData   = Z_Data+2;
   Z_RdData   = Z_Data+5;

   Z_Ifk_Adr   = Z_Data -3;
   Z_Mod_Adr   = Z_Data -2;
   S_Ifk_WrAdr = 40;
   S_Mod_WrAdr = S_Ifk_WrAdr;
   S_Ifk_RdAdr = S_Ifk_WrAdr+18;
   S_Mod_RdAdr = S_Ifk_RdAdr;

   S_WrData_Hex= S_Ifk_WrAdr-6;
   S_RdData_Hex= S_Ifk_RdAdr-7;
   S_WrData_Bin= S_Ifk_WrAdr-17;
   S_RdData_Bin= S_Ifk_RdAdr-12;

   Z_RdLife    = Z_Data;
   S_RdLife    = S_Mod_RdAdr-12;
   Z_WrLife    = Z_Data;
   S_WrLife    = S_Mod_WrAdr-12;

  type
       TCompare= (Long32, Wr16Hi_Rd16Hi, Wr16Lo_Rd16Lo, Wr16Hi_Rd16Lo, Wr16Lo_Rd16Hi, Wr32_Rd16HiLo);
       TWrRd   = (Wr, Rd);
       TData32 = record case Byte of
                  1: (li: LongInt);
                  2: (wrd: packed record
                           l : Word;
                           h : Word;
                           end)
                 end;

  var User_In     : Word;
      User_LongIn : LongInt;
      Mod_Adr     : Byte;
      Sub_Adr     : Byte;
      Rd_Sub0_Err : LONGINT;
      Rd_Sub2_Err : LONGINT;
      Ifk_AdrWr   : Byte;
      Ifk_AdrRd   : Byte;
      Mod_AdrWr   : Byte;
      Mod_AdrRd   : Byte;
      Mode_SubAdr : TModeSubAdr;
      RModCrd     : TCardAdr;
      WModCrd     : TCardAdr;
      Wr_Data_Sub0: Word;
      Wr_Data_Sub2: Word;
      Shift_Mode_Sub0 : Boolean;
      FixDataMode: Boolean;
      Start_Loop : Boolean;
      Transf_Cnt : LongInt;
      Error_Cnt  : LongInt;
      Color      : TBackColor;
      Compare32  : TCompare;
      I_32       : TData32;
      SubAdr4u6  : Boolean;

  procedure  Ini_TastMod32_Win;
   begin
    Window(02, 20, 70, 24); TextBackground(Green); TextColor(Yellow);
    Writeln ('v----------- WRITE -------------v v------ READ ------v');
    Writeln ('F1: Ifk-Adr    F5: Wr-Data fix/var F9 : Ifk-Adr       ');
    Writeln ('               F6: Wr-Data [Hex]                      ');
    Writeln ('               F7: Clr Data+Count                     ');
   end;

  procedure Win32_Hex4_Xy (X: Byte; Y: Byte; WData: Word;
                         BackColor: TBackColor; RdError: Boolean);
   begin
    if BackColor = Gruen     then TextBackground(Green);
    if BackColor = Rot       then TextBackground(Red);
    if BackColor = Weiss     then TextBackground(White);
    if BackColor = Magent    then TextBackground(Magenta);
    if BackColor = Blau      then TextBackground(Blue);
    if BackColor = Blank     then TextBackground(White);
    if BackColor = BlankLoop then TextBackground(White);

    GotoXY (X,Y);
    if (BackColor = Blank) or (BackColor = BlankLoop) then
      begin
       Write ('    ');
      end
    else
      begin
       if BackColor = Rot then TextColor(Yellow);
       if RdError then Write ('MIL?') else Write (Hex_Word(WData));
      end;

    if (BackColor = BlankLoop) then
     begin
       GotoXY(S_Data+12,Z_Data); TextColor(Red+128);
       Write ('    Loop! ');
     end;
    TextColor(Black);
   end; {Win32_Hex4_XY}

   procedure Display_Adr;
    begin
     Set_Text_Win;
     TextColor(Black);
     GotoXY(S_Ifk_WrAdr,Z_Ifk_Adr);   write(Hex_Byte(WModCrd.IfkNr));
     GotoXY(S_Mod_WrAdr,Z_Mod_Adr);   write(Hex_Byte(WModCrd.ModAdr));
     GotoXY(S_Ifk_RdAdr,Z_Ifk_Adr);   write(Hex_Byte(RModCrd.IfkNr));
     GotoXY(S_Mod_RdAdr,Z_Mod_Adr);   write(Hex_Byte(RModCrd.ModAdr));
    end;

   procedure Display_SubAdr;
    begin
     Set_Text_Win;        TextColor(Yellow);
     if SubAdr4u6 then begin
     GotoXY(17,Z_Info+2); write('     v--Sub-Adr['); TextColor(red);
                          write('4'); TextColor(yellow); write('] =K0--v   v--Sub-Adr['); TextColor(red);
                          write('6'); TextColor(yellow); write('] =K1--v    ');
       end
     else begin
     GotoXY(17,Z_Info+2); write('     v--Sub-Adr['); TextColor(red);
                          write('0'); TextColor(yellow); write('] =K0--v   v--Sub-Adr['); TextColor(red);
                          write('2'); TextColor(yellow); write('] =K1--v    ');
       end;
    end;

   procedure Display_Ini;
   begin
    Ini_Text_Win;        TextColor(Yellow);
    GotoXY(16,Z_Info+0); write('---- Modul-Bus Daten schreiben/lesen/prÅfen ----');
    TextColor(Blue);
    GotoXY(08,Z_Info+1); write('Setze Modul-Adr mit Fct-Code 11 [H], Wr/Rd mit Fct-Code 10/90 [H]');
    Display_SubAdr;
{
    if SubAdr4u6 then begin
    GotoXY(17,Z_Info+2); write('     v--Sub-Adr[4] =K0--v   v--Sub-Adr[6] =K1--v    ');
      end
    else begin
    GotoXY(17,Z_Info+2); write('     v--Sub-Adr[0] =K0--v   v--Sub-Adr[2] =K1--v    ');
      end;
}
    GotoXY(17,Z_Info+3); write('[Bit 31................16   15................00 Bit]');
    GotoXY(17,Z_Info+4); write('     ^-Byte3-^  ^-Byte2-^   ^-Byte1-^  ^-Byte0-^     ');

    TextColor(Blue);
    GotoXY(S_Ifk_WrAdr-12,Z_Ifk_Adr);   write('IFK-Adr[H]: ');
    GotoXY(S_Mod_WrAdr-12,Z_Mod_Adr);   write('Mod-Adr[H]: ');


    GotoXY(S_Ifk_RdAdr-12,Z_Ifk_Adr);   write('IFK-Adr[H]: ');
    GotoXY(S_Mod_RdAdr-12,Z_Mod_Adr);   write('Mod-Adr[H]: ');
    TextColor(yellow);
    GotoXY(S_Mod_WrAdr-12,Z_Mod_Adr+1); write('^-- WrAdr --^ ');
    GotoXY(S_Mod_RdAdr-12,Z_Mod_Adr+1); write('^-- RdAdr --^ ');
    Display_Adr;
    TextColor(Blue);
    GotoXY(S_Data,Z_Data  );    writeln('Wr-Data-Cnt: ');
    GotoXY(S_Data,Z_Data+1);    writeln('                ^  ^  ');
    GotoXY(S_Data,Z_WrData);    writeln('Write-Data[H]: ');
    GotoXY(S_Data,Z_WrData+1);  writeln('Error-Data[H]: ');

    GotoXY(S_WrData_Hex+2,Z_WrData+2);  writeln('----');
    GotoXY(S_WrData_Hex-3,Z_WrData+2);  writeln('----');

    GotoXY(S_Data,Z_RdData);    writeln('Read-Data [H]: ');
    GotoXY(S_Data,Z_RdData+1);  writeln('Error-Data[H]: ');
    GotoXY(S_Data,Z_RdData+2);  writeln('Error-Count: ');
   end;

 procedure Transf_And_Displ_ModbusData  (Loop_Start: Boolean;
                                         StepSingle: Boolean;
                                         RdCard    : TCardAdr;
                                         WrCard    : TCardAdr);
  var ModRdDta: Word;      {fÅr PZ-Test sind hier Adr bereits vertauscht}
      WrAdr   : TModAdr;
      RdAdr   : TModAdr;
      MilErr  : TMilErr;
      RdErr   : Boolean;
      RdDta32 : TData32;
      WrDta32 : TData32;

  begin                                             {DataTo_ModBus_And_Displ}
     WrDta32.li := I_32.li;
     Transf_Cnt := Transf_Cnt + 1;
     RdErr      := False;

     case Compare32 of
       Long32 : begin
                  {Subadr 2 = Low-Word schreiben}
                  WrAdr.AdrIfc  := WrCard.IfkNr;
                  WrAdr.AdrCard := WrCard.ModAdr;
                  WrAdr.AdrSub  := 2;
                  WrAdr.AdrMode := AdrNew;
                  Mil.Wr_ModBus (WrDta32.wrd.l, WrAdr, MilErr);

                  {Subadr 0 = Hi-Word schreiben}
                  WrAdr.AdrIfc  := WrCard.IfkNr;
                  WrAdr.AdrCard := WrCard.ModAdr;
                  WrAdr.AdrSub  := 0;
                  WrAdr.AdrMode := AdrNew;
                  Mil.Wr_ModBus (WrDta32.wrd.h, WrAdr, MilErr);

                  {Subadr 2/6 = Low-Word Daten lesen}
                  RdAdr.AdrIfc  := RdCard.IfkNr;
                  RdAdr.AdrCard := RdCard.ModAdr;
                  if SubAdr4u6 then RdAdr.AdrSub := 6 else RdAdr.AdrSub := 2;
                  RdAdr.AdrMode := AdrNew;
                  Mil.Rd_ModBus (RdDta32.wrd.l,RdAdr,MilErr);
                  if MilErr <> No_Err then RdErr := True;

                  {Subadr 0/4 = Hi-Word Daten lesen}
                  RdAdr.AdrIfc  := RdCard.IfkNr;
                  RdAdr.AdrCard := RdCard.ModAdr;
                  if SubAdr4u6 then RdAdr.AdrSub := 4 else RdAdr.AdrSub := 0;
                  RdAdr.AdrMode := AdrNew;
                  Mil.Rd_ModBus (RdDta32.wrd.h,RdAdr,MilErr);
                  if MilErr <> No_Err then RdErr := True;

                  Set_Text_Win;
                  if Loop_Start then
                   begin
                    Color := BlankLoop;
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData, WrDta32.wrd.h, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData, WrDta32.wrd.h, Color, False);
                  end
                  else
                   begin
                    if StepSingle then
                     begin
                      Set_Text_Win;
                      GotoXY(S_Data+12,Z_Data); Writeln (Transf_Cnt:10);
                      Color := Gruen;  TextColor(Black);
                      Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData, WrDta32.wrd.l, Color, False);
                      Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData, WrDta32.wrd.h, Color, False);

                      Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData, RdDta32.wrd.l, Color, RdErr);
                      Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData, RdDta32.wrd.h, Color, RdErr);
                     end
                    else
                      Color := Blank;
                   end;

                  if (RdErr or (RdDta32.li <> WrDta32.li)) then
                   begin
                    Error_Cnt := Error_Cnt +1;
                    TextBackground(White); TextColor(Black);
                    GotoXY(S_Data+12,Z_RdData+2); Writeln (Error_Cnt:10);
                    Color := Rot;
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData+1, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData+1, WrDta32.wrd.h, Color, False);

                    Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData+1, RdDta32.wrd.l, Color, RdErr);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData+1, RdDta32.wrd.h, Color, RdErr);
                   end;
                end; {Long32}

       Wr16Hi_Rd16Hi:
               begin
                   {Subadr 0 = Hi-Word schreiben}
                  WrAdr.AdrIfc  := WrCard.IfkNr;
                  WrAdr.AdrCard := WrCard.ModAdr;
                  WrAdr.AdrSub  := 0;
                  WrAdr.AdrMode := AdrNew;
                  Mil.Wr_ModBus (WrDta32.wrd.h, WrAdr, MilErr);

                  {Subadr 0 = Hi-Word Daten lesen}
                  RdAdr.AdrIfc  := RdCard.IfkNr;
                  RdAdr.AdrCard := RdCard.ModAdr;
                  if SubAdr4u6 then RdAdr.AdrSub := 4 else RdAdr.AdrSub := 0;
                  RdAdr.AdrMode := AdrNew;
                  Mil.Rd_ModBus (RdDta32.wrd.h,RdAdr,MilErr);
                  if MilErr <> No_Err then RdErr := True;

                  Set_Text_Win;
                  if Loop_Start then
                   begin
                    Color := BlankLoop;
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData, WrDta32.wrd.h, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData, WrDta32.wrd.h, Color, False);
                   end
                  else
                   begin
                    if StepSingle then
                     begin
                      Set_Text_Win;
                      TextBackground(White);
                      GotoXY(S_Data+12,Z_Data); Writeln (Transf_Cnt:10);
                      Color := Gruen;  TextColor(Black);
                      Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData, WrDta32.wrd.l, Blank, False);
                      Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData, WrDta32.wrd.h, Color, False);

                      Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData, RdDta32.wrd.l, Blank, RdErr);
                      Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData, RdDta32.wrd.h, Color, RdErr);
                     end
                    else
                      Color := Blank;
                   end;

                  if (RdErr or (RdDta32.wrd.h <> WrDta32.wrd.h)) then
                   begin
                    Error_Cnt := Error_Cnt +1;
                    TextBackground(White); TextColor(Black);
                    GotoXY(S_Data+12,Z_RdData+2); Writeln (Error_Cnt:10);
                    Color := Rot;
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData+1, WrDta32.wrd.l, Blank, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData+1, WrDta32.wrd.h, Color, False);

                    Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData+1, RdDta32.wrd.l, Blank, RdErr);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData+1, RdDta32.wrd.h, Color, RdErr);
                   end;
                end;  {Hi16}

       Wr16Lo_Rd16Lo:
                begin
                  {Subadr 2 = Low-Word schreiben}
                  WrAdr.AdrIfc  := WrCard.IfkNr;
                  WrAdr.AdrCard := WrCard.ModAdr;
                  WrAdr.AdrSub  := 2;
                  WrAdr.AdrMode := AdrNew;
                  Mil.Wr_ModBus (WrDta32.wrd.l, WrAdr, MilErr);

                  {Subadr 2 = Low-Word Daten lesen}
                  RdAdr.AdrIfc  := RdCard.IfkNr;
                  RdAdr.AdrCard := RdCard.ModAdr;
                  if SubAdr4u6 then RdAdr.AdrSub := 6 else RdAdr.AdrSub := 2;
                  RdAdr.AdrMode := AdrNew;
                  Mil.Rd_ModBus (RdDta32.wrd.l,RdAdr,MilErr);
                  if MilErr <> No_Err then RdErr := True;

                  Set_Text_Win;
                  if Loop_Start then
                   begin
                    Color := BlankLoop;
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData, WrDta32.wrd.h, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData, WrDta32.wrd.h, Color, False);
                   end
                  else
                   begin
                    if StepSingle then
                     begin
                      Set_Text_Win;
                      TextBackground(White);
                      GotoXY(S_Data+12,Z_Data); Writeln (Transf_Cnt:10);
                      Color := Gruen;  TextColor(Black);
                      Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData, WrDta32.wrd.l, Color, False);
                      Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData, WrDta32.wrd.h, Blank, False);

                      Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData, RdDta32.wrd.l, Color, RdErr);
                      Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData, RdDta32.wrd.h, Blank, RdErr);
                     end
                    else
                      Color := Blank;
                   end;

                  if (RdErr or (RdDta32.wrd.l <> WrDta32.wrd.l)) then
                   begin
                    Error_Cnt := Error_Cnt +1;
                    TextBackground(White); TextColor(Black);
                    GotoXY(S_Data+12,Z_RdData+2); Writeln (Error_Cnt:10);
                    Color := Rot;
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData+1, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData+1, WrDta32.wrd.h, Blank, False);

                    Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData+1, RdDta32.wrd.l, Color, RdErr);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData+1, RdDta32.wrd.h, Blank, RdErr);
                   end;
                 end;

       Wr16Hi_Rd16Lo:
                begin
                   {Subadr 0 = Hi-Word schreiben}
                  WrAdr.AdrIfc  := WrCard.IfkNr;
                  WrAdr.AdrCard := WrCard.ModAdr;
                  WrAdr.AdrSub  := 0;
                  WrAdr.AdrMode := AdrNew;
                  Mil.Wr_ModBus (WrDta32.wrd.h, WrAdr, MilErr);

                  {Subadr 2 = Low-Word Daten lesen}
                  RdAdr.AdrIfc  := RdCard.IfkNr;
                  RdAdr.AdrCard := RdCard.ModAdr;
                  if SubAdr4u6 then RdAdr.AdrSub := 6 else RdAdr.AdrSub := 2;
                  RdAdr.AdrMode := AdrNew;
                  Mil.Rd_ModBus (RdDta32.wrd.l,RdAdr,MilErr);
                  if MilErr <> No_Err then RdErr := True;

                  Set_Text_Win;
                  if Loop_Start then
                   begin
                    Color := BlankLoop;
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData, WrDta32.wrd.h, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData, WrDta32.wrd.h, Color, False);
                   end
                  else
                   begin
                    if StepSingle then
                     begin
                      Set_Text_Win;
                      TextBackground(White);
                      GotoXY(S_Data+12,Z_Data); Writeln (Transf_Cnt:10);
                      Color := Gruen;  TextColor(Black);
                      Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData, WrDta32.wrd.l, Blank, False);
                      Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData, WrDta32.wrd.h, Color, False);

                      Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData, RdDta32.wrd.l, Color, RdErr);
                      Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData, RdDta32.wrd.h, Blank, RdErr);
                     end
                    else
                      Color := Blank;
                   end;

                  if (RdErr or (WrDta32.wrd.h <> RdDta32.wrd.l)) then
                   begin
                    Error_Cnt := Error_Cnt +1;
                    TextBackground(White); TextColor(Black);
                    GotoXY(S_Data+12,Z_RdData+2); Writeln (Error_Cnt:10);
                    Color := Rot;
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData+1, WrDta32.wrd.l, Blank, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData+1, WrDta32.wrd.h, Color, False);

                    Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData+1, RdDta32.wrd.l, Color, RdErr);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData+1, RdDta32.wrd.h, Blank, RdErr);
                   end;
                end;

       Wr16Lo_Rd16Hi:
                begin
                  {Subadr 2 = Low-Word schreiben}
                  WrAdr.AdrIfc  := WrCard.IfkNr;
                  WrAdr.AdrCard := WrCard.ModAdr;
                  WrAdr.AdrSub  := 2;
                  WrAdr.AdrMode := AdrNew;
                  Mil.Wr_ModBus (WrDta32.wrd.l, WrAdr, MilErr);

                  {Subadr 0 = Hi-Word Daten lesen}
                  RdAdr.AdrIfc  := RdCard.IfkNr;
                  RdAdr.AdrCard := RdCard.ModAdr;
                  if SubAdr4u6 then RdAdr.AdrSub := 4 else RdAdr.AdrSub := 0;
                  RdAdr.AdrMode := AdrNew;
                  Mil.Rd_ModBus (RdDta32.wrd.h,RdAdr,MilErr);
                  if MilErr <> No_Err then RdErr := True;

                  Set_Text_Win;
                  if Loop_Start then
                   begin
                    Color := BlankLoop;
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData, WrDta32.wrd.h, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData, WrDta32.wrd.h, Color, False);
                   end
                  else
                   begin
                    if StepSingle then
                     begin
                      Set_Text_Win;
                      TextBackground(White);
                      GotoXY(S_Data+12,Z_Data); Writeln (Transf_Cnt:10);
                      Color := Gruen;  TextColor(Black);
                      Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData, WrDta32.wrd.l, Color, False);
                      Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData, WrDta32.wrd.h, Blank, False);

                      Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData, RdDta32.wrd.l, Blank, RdErr);
                      Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData, RdDta32.wrd.h, Color, RdErr);
                     end
                    else
                      Color := Blank;
                   end;

                  if (RdErr or (WrDta32.wrd.l <> RdDta32.wrd.h)) then
                   begin
                    Error_Cnt := Error_Cnt +1;
                    TextBackground(White); TextColor(Black);
                    GotoXY(S_Data+12,Z_RdData+2); Writeln (Error_Cnt:10);
                    Color := Rot;
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData+1, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData+1, WrDta32.wrd.h, Blank, False);

                    Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData+1, RdDta32.wrd.l, Blank, RdErr);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData+1, RdDta32.wrd.h, Color, RdErr);
                   end;
                end;

         Wr32_Rd16HiLo:  {spezial: Test fÅr Datenaustausch PZ FG 700.610}
                 begin    {Wr32_Rd16HiLo }
                  {Subadr 2 = Low-Word schreiben}
                  WrAdr.AdrIfc  := WrCard.IfkNr;
                  WrAdr.AdrCard := WrCard.ModAdr;
                  WrAdr.AdrSub  := 2;
                  WrAdr.AdrMode := AdrNew;
                  Mil.Wr_ModBus (WrDta32.wrd.l, WrAdr, MilErr);

                  {Subadr 0 = Hi-Word schreiben}
                  WrAdr.AdrIfc  := WrCard.IfkNr;
                  WrAdr.AdrCard := WrCard.ModAdr;
                  WrAdr.AdrSub  := 0;
                  WrAdr.AdrMode := AdrNew;
                  Mil.Wr_ModBus (WrDta32.wrd.h, WrAdr, MilErr);

    {Subadr 2/6 = Low-Word Daten lesen: bei PZ wird hier Hi-Word gelesen}
                  RdAdr.AdrIfc  := RdCard.IfkNr;
                  RdAdr.AdrCard := RdCard.ModAdr;
                  if SubAdr4u6 then RdAdr.AdrSub := 6 else RdAdr.AdrSub := 2;
                  RdAdr.AdrMode := AdrNew;
                  Mil.Rd_ModBus (RdDta32.wrd.h,RdAdr,MilErr);
                  if MilErr <> No_Err then RdErr := True;

    {Subadr 0/4 = Hi-Word Daten lesen: bei PZ wird hier Lo-Word gelesen}
                  RdAdr.AdrIfc  := RdCard.IfkNr;
                  RdAdr.AdrCard := RdCard.ModAdr;
                  if SubAdr4u6 then RdAdr.AdrSub := 4 else RdAdr.AdrSub := 0;
                  RdAdr.AdrMode := AdrNew;
                  Mil.Rd_ModBus (RdDta32.wrd.l,RdAdr,MilErr);
                  if MilErr <> No_Err then RdErr := True;

                  Set_Text_Win;
               Set_Text_Win;   {im PZ Mode: stÑndige Anzeige}
               GotoXY(S_Data+12,Z_Data); Writeln (Transf_Cnt:10);
               Color := Gruen;  TextColor(Black);
               Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData, WrDta32.wrd.l, Color, False);
               Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData, WrDta32.wrd.h, Color, False);

               Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData, RdDta32.wrd.l, Color, RdErr);
               Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData, RdDta32.wrd.h, Color, RdErr);


{
                  if Loop_Start then
                   begin
                    Color := BlankLoop;
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData, WrDta32.wrd.h, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData, WrDta32.wrd.h, Color, False);
                  end
                  else
                   begin
                    if StepSingle then
                     begin
                      Set_Text_Win;
                      GotoXY(S_Data+12,Z_Data); Writeln (Transf_Cnt:10);
                      Color := Gruen;  TextColor(Black);
                      Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData, WrDta32.wrd.l, Color, False);
                      Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData, WrDta32.wrd.h, Color, False);

                      Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData, RdDta32.wrd.l, Color, RdErr);
                      Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData, RdDta32.wrd.h, Color, RdErr);
                     end
                    else
                      Color := Blank;
                   end;
}
                  if (RdErr or (RdDta32.li <> WrDta32.li)) then
                   begin
                    Error_Cnt := Error_Cnt +1;
                    TextBackground(White); TextColor(Black);
                    GotoXY(S_Data+12,Z_RdData+2); Writeln (Error_Cnt:10);
                    Color := Rot;
                    Win32_Hex4_XY (S_WrData_Hex+2, Z_WrData+1, WrDta32.wrd.l, Color, False);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_WrData+1, WrDta32.wrd.h, Color, False);

                    Win32_Hex4_XY (S_WrData_Hex+2, Z_RdData+1, RdDta32.wrd.l, Color, RdErr);
                    Win32_Hex4_XY (S_WrData_Hex-3, Z_RdData+1, RdDta32.wrd.h, Color, RdErr);
                   end;
                end; {Wr32_Rd16HiLo}
          end; {case Compare32}
  end;   {DataTo_ModBus_And_Displ}

  procedure Disp_FV_Mode;
   begin
     Set_Text_Win;
     TextBackground(Magenta); TextColor(Yellow);
     GotoXY(02,Z_WrData);
     if FixDataMode then
       begin
         Writeln ('f');
       end
      else
       begin
         Writeln ('v');
       end;
   end;

 procedure Reset_Counters;
  begin
   I_32.li    := 0;
   Transf_Cnt := 0;
   Error_Cnt  := 0;
   Set_Text_Win;
   GotoXY(S_Data+12,Z_Data);     Writeln (Transf_Cnt:10);
   GotoXY(S_Data+12,Z_RdData+2); Writeln (Error_Cnt:10);
   {Write Daten anzeigen}
   GotoXY (S_WrData_Hex+2, Z_WrData);    Write ('0000');
   GotoXY (S_WrData_Hex-3, Z_WrData);    Write ('0000');
   {Read Daten blank}
   GotoXY (S_WrData_Hex+2, Z_RdData);    Write ('    ');
   GotoXY (S_WrData_Hex-3, Z_RdData);    Write ('    ');
   {Error-Daten blank}
   GotoXY (S_WrData_Hex+2, Z_WrData+1);  Write ('    ');
   GotoXY (S_WrData_Hex-3, Z_WrData+1);  Write ('    ');
   GotoXY (S_WrData_Hex+2, Z_RdData+1);  Write ('    ');
   GotoXY (S_WrData_Hex-3, Z_RdData+1);  Write ('    ');
  end;

 procedure Incr_Data;
  begin
    case Compare32 of
     Long32, Wr32_Rd16HiLo:
                    begin
                      if I_32.li = $FFFFFFFF then
                        I_32.li:= 0
                      else
                        I_32.li:= I_32.li + 1;
                    end; {Long32}
     Wr16Hi_Rd16Hi, Wr16Hi_Rd16Lo:
                     begin
                      if I_32.wrd.h = $FFFF then
                        I_32.li:= 0
                      else
                        I_32.wrd.h:= I_32.wrd.h + 1;
                    end;

     Wr16Lo_Rd16Lo, Wr16Lo_Rd16Hi:
                    begin
                      if I_32.wrd.l = $FFFF then
                        I_32.li:= 0
                      else
                        I_32.wrd.l:= I_32.wrd.l + 1;
                    end;
    end; {case}
  end;

 procedure PZ_Transfer_Single;
  var Old_WrIFK, Old_RdIFK: Byte;
  begin
    WModCrd.ModAdr:= 1;
    RModCrd.ModAdr:= 1;
    Display_Adr;
    Transf_And_Displ_ModbusData (Start_Loop, Single_Step, RModCrd, WModCrd{, FixDataMode});
    Ch := NewReadKey;

    WModCrd.ModAdr:= 2;
    RModCrd.ModAdr:= 2;
    Display_Adr;
    Transf_And_Displ_ModbusData (Start_Loop, Single_Step, RModCrd, WModCrd{, FixDataMode});
    Ch := NewReadKey;

    {Bei Modul-Adr 3 mÅssen Wr-IFK-Adr und Rd-IFK-Adr vertauscht werden!!}
    Old_WrIFK := WModCrd.IfkNr;  {rette alte IFK-Nummern}
    Old_RdIFK := RModCrd.IfkNr;
    WModCrd.IfkNr := Old_RdIFK; {fÅr die 3. Modulbus-Karte werden die R/W-Adr vertauscht}
    RModCrd.IfkNr := Old_WrIFK;
    WModCrd.ModAdr:= 3;
    RModCrd.ModAdr:= 3;
    Display_Adr;
    Transf_And_Displ_ModbusData (Start_Loop, Single_Step, RModCrd, WModCrd{, FixDataMode});
    Ch := NewReadKey;

    WModCrd.IfkNr := Old_WrIFK; {alten Adressen wieder herstellen}
    RModCrd.IfkNr := Old_RdIFK;
    if not FixDataMode then Incr_Data; {feste oder variable Daten schreiben}
  end; {PZ_Transfer_Single}

 procedure PZ_Transfer_Loop;
  var Old_WrIFK, Old_RdIFK: Byte;
  begin
    WModCrd.ModAdr:= 1;
    RModCrd.ModAdr:= 1;
    Display_Adr;
    Transf_And_Displ_ModbusData (Start_Loop, Single_Step, RModCrd, WModCrd{, FixDataMode});

    WModCrd.ModAdr:= 2;
    RModCrd.ModAdr:= 2;
    Display_Adr;
    Transf_And_Displ_ModbusData (Start_Loop, Single_Step, RModCrd, WModCrd{, FixDataMode});
{    Ch := NewReadKey; }

    {Bei Modul-Adr 3 mÅssen Wr-IFK-Adr und Rd-IFK-Adr vertauscht werden!!}
    Old_WrIFK := WModCrd.IfkNr;  {rette alte IFK-Nummern}
    Old_RdIFK := RModCrd.IfkNr;
    WModCrd.IfkNr := Old_RdIFK; {fÅr die 3. Modulbus-Karte werden die R/W-Adr vertauscht}
    RModCrd.IfkNr := Old_WrIFK;
    WModCrd.ModAdr:= 3;
    RModCrd.ModAdr:= 3;
    Display_Adr;
    Transf_And_Displ_ModbusData (Start_Loop, Single_Step, RModCrd, WModCrd{, FixDataMode});
{    Ch := NewReadKey;}

    WModCrd.IfkNr := Old_WrIFK; {alten Adressen wieder herstellen}
    RModCrd.IfkNr := Old_RdIFK;
    if not FixDataMode then Incr_Data; {feste oder variable Daten schreiben}
  end; {PZ_Transfer_Loop}


  begin    {Modbus_WrRd32}
    WModCrd.IfkNr  := 0;  {Ifk_AdrWr}
    WModCrd.ModAdr := 0;  {Mod_AdrWr}
    RModCrd.IfkNr  := 0;  {Ifk_AdrRd}
    RModCrd.ModAdr := 0;  {Mod_AdrRd}

    Wr_Data_Sub0    := 0;
    Wr_Data_Sub2    := 0;
    Shift_Mode_Sub0 := False;
    FixDataMode     := False;
    SubAdr4u6       := False;{DatenrÅcklesung 32-Bit -> fixiert Åber externe}
    Transf_Cnt      := 0;                                      {KabelbrÅcken}
    Error_Cnt       := 0;
    Compare32       := Wr32_Rd16HiLo;  {32-Bit-Vergleich}

    Ini_Text_Win;
    Display_Ini;
    Disp_FV_Mode;
    Ini_TastMod32_Win;
    Ini_WrRd32_Win;
    Cursor(False);       {Software-Gerippe fÅr Single-Step und Loop}
    Std_Msg;
    Ch := NewReadKey;
    I_32.li := 0;           {Datencounter bei variablen Daten}
    Mode_SubAdr.WrMode := True;   {falls enabled: auch Daten schreiben}

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Start_Loop  := False;
       PZ_Transfer_Single;
      end;

     if Ch = #13 then
      begin
        Single_Step := False;
        Start_Loop  := True;   {Loop-Anzeige aktivieren!}
        PZ_Transfer_Loop;
      end;

     if not Single_Step then
      begin
       if not FixDataMode then Incr_Data; {feste oder variable Daten schreiben}
       Mode_SubAdr.WrMode := True; {falls enabled: auch Daten schreiben}
       Start_Loop  := False;
       PZ_Transfer_Loop;
      end;

     if Ch = #0 then                  {Sonder-Tasten Abfrage}
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    Clr_WrRd32_Win;
                    Show_Ifk_Online;
                    if Ask_Hex_Break (User_In, Byt) then
                      begin
                        WModCrd.IfkNr := User_In;
                        Display_Adr;
                      end;
                    Clr_Online_Win;
                    Ini_WrRd32_Win;
                    Std_Msg;
                   end;

        Taste_F5: begin
                    if FixDataMode then FixDataMode:=False else FixDataMode:=True;
                    Disp_FV_Mode;
                    Std_Msg;
                  end;

         Taste_F6: begin
                   if Ask_Hex_LongInteger_Break (User_LongIn) then
                     begin
                      I_32.li := User_LongIn;
                     end;
                    Std_Msg;
                    Ch := '?';
                  end;

        Taste_F7: begin
                   Reset_Counters;
                   Single_Step := True;
                   Ch := '?';
                  end;

        Taste_F9: begin
                    Clr_WrRd32_Win;
                    Show_Ifk_Online;
                    if Ask_Hex_Break (User_In, Byt) then
                      begin
                        RModCrd.IfkNr := User_In;
                        Display_Adr;
                      end;
                    Clr_Online_Win;
                    Ini_WrRd32_Win;
                    Std_Msg;
                   end;
      end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
   Cursor(True);
  end; {Modul_WrRd32}



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
		  Mil_Ask_Ifc;
                  Mil_Rd_HS_Ctrl (Ifc_Test_Nr);
                end;
     '3'      : begin
		{  Mil_Ask_Ifc;                    }
                {  Mil_Rd_HS_Status (Ifc_Test_Nr); }
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
     '8'      : begin
		  Mil_Ask_Ifc ;
                  Mil_Echo (Ifc_Test_Nr);
                end;
     '9'      : begin
		  Mil_Ask_Ifc ;
                  Mil_IfkMode;
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
          'm', 'M' : begin
                       Modul_PzWrRd32
                     end;
          'n', 'N' : begin
                     end;
          'o', 'O' : begin
                     end;
          'p', 'P' : begin
                     end;
          'q', 'Q' : begin
                     end;
          'r', 'R' : begin
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
end. {mil_base}


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


