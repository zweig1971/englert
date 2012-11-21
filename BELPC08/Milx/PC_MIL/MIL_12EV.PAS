PROGRAM Mil_12EV;
{ Autor des Basis-Programmes Mil_Base.PAS: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS

  Autor der Erweiterungen   :
  énderungen:
  14.05.97      ursprÅnglich MIL_EVNT.PAS auf Modulbus Umstellung!!

Frage: Timeout Zeit rÅcklesbar ??? Punkt M
       Reset, En-, Disable ext. Event nur mit Subadr!!! schlecht

}
{$S-}
uses Crt, WinDos, Dos, Datech, Datech_0, Datech_1;    {spez. MIL-Routinen in Units Datech..}

const
 Head_Line =
      'BELAB                               MIL_12EV    ' +
      '                    [24.11.1997]' +
      '                     12-fach Event-Generator FG 450.350     (Turbo Pascal V7.0)';

 procedure menue_win;
  var answer: CHAR;
 begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;            {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}
  TextColor(Blue);

  {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}
  GotoXY(5, 14);
  Writeln('       [M]<-- Status/Command 12-Ext-Event-I/O-Modul           ');
  GotoXY(5, 15);
  Writeln('       [N]<-- Lese letzten Event                              ');
  GotoXY(5, 16);
  Writeln('       [O]<-- Sende Event (RÅcklesen aus  Event-Reg)          ');
  GotoXY(5, 17);
  Write  ('       [P]<-- Sende Event (RÅcklesen Åber Event-Bus: ');
                         TextColor(Red); Write('spez. Kabel!!'); TextColor(Blue); Write(')   ');
  GotoXY(5, 18);
  Writeln('       [Q]<-- Schreibe ext. Event-Daten [1..12] ins RAM + RÅcklesen');
  GotoXY(5, 19);
  Writeln('       [R]<-- PolaritÑt fÅr ext. Trigger-EingÑnge            ');
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
  Ext_Evt_Max = 12;
  SubAdr_12Evt_Stat     = $0E; {Subadr f. Modul 12Evt Status       }
  SubAdr_12Evt_Evt      = $02; {Subadr f. Modul 12Evt Wr/Rd letzter Event}
  SubAdr_12Evt_Mask     = $04; {Subadr f. Modul 12Evt MaskReg f. ext. Events}
  SubAdr_12Evt_Polari   = $06; {Subadr f. Modul 12Evt PolaritÑts-Reg f. ext. Events}

  SubAdr_12Evt_EnExtEvt = $08; {Subadr f. Modul 12Evt Enable  ext. Events}
  SubAdr_12Evt_DisExtEvt= $0A; {Subadr f. Modul 12Evt Disable ext. Events}
  SubAdr_12Evt_Reset    = $0C; {Subadr f. Modul 12Evt Reset Karte}
  SubAdr_12Evt_RamBase  = $40; {Subadr f. Modul 12Evt RAM Basisadresse}
  SubAdr_12Evt_RamTimEvt= SubAdr_12Evt_RamBase + $1A; {RAM Timeout-Event}
  SubAdr_12Evt_RamTimMs = $10; {RAM Timeout-Zeit}
{
 procedure Ask_Ifc_Mod_Adr;
  begin
   Ini_Text_Win;
   Mil_Ask_Ifc;
   Mil_Ask_Mod;
  end;
}

 type
  TID_Mode = (Modul, Slot);
  TID_Type = record
               Soll: Byte;
               Ist : Byte;
               Mode: TID_Mode;
             end;

  function ID_Check (Mod_Adr: TModAdr; var Ident: TID_Type): Boolean;
   var Id_Word : Word;
       MilErr  : TMilErr;
   begin
     ID_Check := False;                            {Default}
     Mil.Rd_ModBus (Id_Word, Mod_Adr, MilErr);     {Lese Modul-Id}
     if MilErr = No_Err then
      begin
       case Ident.Mode of
        Modul: begin                               {Richtiges Modul?}
                 Ident.Ist     := Hi(Id_Word);     {Hi-Byte=Kartenident}
                 if  Ident.Soll = Ident.Ist then  ID_Check := True;
               end;
        Slot : begin                               {Richtiger Slot?}
                 Ident.Ist     := Lo(Id_Word);     {Lo-Byte=VG-Leiste=Slot-ID}
                 if  Ident.Soll = Ident.Ist then  ID_Check := True; {Richtiger Slot?}
               end;
         end;
      end;
   end; {ID_Check}

{xxxx}
 procedure Evt_Status;
  Label 99;
  const
   Z_Base    = 4;
   S_MaskCnt = 33;

 type
  TMask_Mode = (Enable, Disable);

  VAR read_data,fct_code : WORD;
      MilErr     : TMilErr;
      Fct        : TFct;
      Transf_Cnt : LongInt;
      Timout_Cnt : LongInt;
      WrMask_Cnt : LongInt;
      Rd_Stat_Cnt: LongInt;
      WrData     : Word;
      Adress     : Word;
      ModAdr     : TModAdr;
      ModIdent   : TID_Type;
      IdRet_Code : TIfk_IdErr;
      Adr_Error  : Boolean;
      Timeout_Evt: Word;
      Timeout_Ms : Word;
      IoRes      : Integer;
      User_Int   : LongInt;
      User_Input : Word;

  procedure Set_TastEvt_Win;
  begin
   Window(03, 20, 55, 23);
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

 procedure Displ_Mod_Stat;
  begin
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
   end; {displ_ifc_stat}

{ Falls Timeout-Zeit rÅcklesbar:
  ModAdr.AdrSub  := SubAdr_12Evt_RamTimMs;
}
  procedure Displ_Timeout_Event;
   var Ram_Timeout_Evt : Word;
   begin
     Set_Text_Win;
     GotoXY(23,Z_Base+1);
     Write ('            ');
     ModAdr.AdrIfc  := Ifc_Test_Nr;
     ModAdr.AdrCard := Mod_Test_Nr;
     ModAdr.AdrSub  := SubAdr_12Evt_RamTimEvt;
     ModAdr.AdrMode := AdrNew;
     Mil.Rd_ModBus (Ram_Timeout_Evt, ModAdr, MilErr);
     GotoXY(23,Z_Base+1);
     if (MilErr = No_Err) then
      Write (Hex_Word(Ram_Timeout_Evt))
     else
      begin
       TextColor (Red);
       Write ('Read Error!!');
      end;

    {Timeout Zeit anzeigen: klÑren ob rÅcklesbar}

     GotoXY(22,Z_Base+2);
     Write (Timeout_Ms:5);
   end; {Displ_Timeout_Event}


  PROCEDURE show_stat_reg;
   var Bit16_Strg: Str19;
       Read_Data : Word;
    begin
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

     ModAdr.AdrSub  := SubAdr_12Evt_Evt;  {nur die Subadr Ñndert sich}
     ModAdr.AdrMode := AdrNew;
     Mil.Rd_ModBus (Read_Data, ModAdr, MilErr);
     if MilErr = No_Err then
      begin
        GotoXY(28, Z_Base+11);  write(hex_word(read_data));
      end
     else
      begin
        GotoXY(28, Z_Base+11);  write('    ');
     end;

     ModAdr.AdrSub  := SubAdr_12Evt_Mask; {Subadr f. Modul 12Evt MaskReg f. ext. Events}
     ModAdr.AdrMode := AdrNew;
     Mil.Rd_ModBus (Read_Data, ModAdr, MilErr);
     if MilErr = No_Err then
      begin
        Hex_Bin_Str (Read_Data, bit16_strg);
        GotoXY(22, Z_Base+9);  write(bit16_strg);
      end
     else
      begin
        GotoXY(22, Z_Base+9);  write('   Read Error!!    ');
      end;
     GotoXY(S_MaskCnt,Z_Base+4);  Write (WrMask_Cnt:8);
     Displ_Timeout_Event;
    End; {show_stat_reg; }


 procedure Evt_Mask_Toggle (Mask_Mode: TMask_Mode);
  label 1;
   var Wr_Data : Word;
       Rd_Data : Word;
       Mod_Adr : TModAdr;
       Mask_BitNr: Integer;
       ModIdent  : Byte;

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
                  WrMask_Cnt := WrMask_Cnt +1;
                  Show_Stat_Reg;
                  Ini_Err_Win;
                  Write ('Enable ext. Event-Nr: ', Mask_BitNr);
                  Mil.Timer2_Wait(200000);
                end;

       Disable: begin
                  Wr_Data := Rd_Data;             {Maskbits: D0..D11}
                  Wr_Data := BitClr (Wr_Data, Mask_BitNr-1);  {1= en ext. Evt}
                  Mil.Wr_ModBus (Wr_Data, Mod_Adr, MilErr);
                  WrMask_Cnt := WrMask_Cnt +1;
                  Show_Stat_Reg;
                  Ini_Err_Win;
                  Write ('Disable ext. Event-Nr: ', Mask_BitNr);
                  Mil.Timer2_Wait(200000);
                end;
    end; {case}
1:    Std_Msg;
   end; {Ifc_Mask_Toggle}


  Begin
   Timeout_Ms  := 0;
   Adr_Error := False;
   Ini_Text_Win;
   {Zuerst prÅfen, ob Åberhaupt eine IFK fÅr den Modulbus vorhanden ist!!}
   Check_ModBus_Ifk (Ifc_Test_Nr, IdRet_Code);
   if IdRet_Code <> NoIdErr then
    begin
      Adr_Error := True;
      Ini_Err_Win;
      case IdRet_Code of
        MilRd : Write ('Vorsicht: MIL-Lesefehler. IFK vorhanden? Weiter mit <Space>');
        IfkAdr: Write ('Vorsicht: Falsche IFK-Adr im Identwort!  Weiter mit <Space>');
        IfkId : Write ('Vorsicht: Keine Modulbus-Ident von IFK!  Weiter mit <Space>');
      end;
      Ch := NewReadKey;
    end;

   ModAdr.AdrIfc  := Ifc_Test_Nr;    {Modul-Adr definieren}
   ModAdr.AdrCard := Mod_Test_Nr;
   ModAdr.AdrSub  := ModSub_Adr_ID;  {SubAdr um Ident zu lesen}
   ModAdr.AdrMode := AdrNew;

   ModIdent.Soll := ModID_12Event;
   ModIdent.Ist  := 0;
   ModIdent.Mode := Modul;       {nur Modul-Id prÅfen egal welcher Steckplatz}

   if not ID_Check (ModAdr, ModIdent ) then         {Ist richtiges Modul da?}
    begin
      Adr_Error := True;
      Ini_Err_Win;
      Write ('ERROR: I/O-Modul IDENT [Hex] Soll: ', Hex_Byte(ModIdent.Soll),'  Ist: ', Hex_Byte(ModIdent.Ist));
      Write ('    Weiter mit <Space> ');
      Ch := NewReadKey;
    end;

   if Adr_Error then         {bei Fehler: frage User wegen neuer Adr-Eingabe}
    begin
     Ini_Msg_Win;
     Write ('Sollen IFK- u. Modul-Adr neu definiert werden?  <J> oder weiter mit <CR>: ');
     Ch := NewReadKey;
     if Ch in ['j','J'] then
      begin
       Ask_Ifc_Mod_Adr;
       ModAdr.AdrIfc  := Ifc_Test_Nr;    {Modul-Adr definieren}
       ModAdr.AdrCard := Mod_Test_Nr;
       Ini_Text_Win;
      end;
    end;

   Set_Text_Win;
   Rd_Stat_Cnt:= 0;
   Transf_Cnt := 0;
   Timout_Cnt := 0;
   WrMask_Cnt := 0;

   GotoXY(16,01); write('------ Lese Status des Event-Piggy + letzter Event -----');
   TextColor(Yellow);
   GotoXY(19,02); write('Set/Clear Event-Maske[1..12]: mit F1 bzw. F2-Taste! ');
   TextColor(Brown);
   GotoXY(50,05); write  ('Bedeutung der Event Status-Bits');

   GotoXY(06,Z_Base-1);  write('Ifk-Adr  [Hex]:');
   GotoXY(06,Z_Base  );  write('Modul-Adr[Hex]:');

   GotoXY(06,Z_Base+1);  write('TimeoutEvt [H]:');
   GotoXY(06,Z_Base+2);  write('Timeout   [ms]:');

   GotoXY(06,Z_Base+4);  write('Wr_Mask_Count :');
   GotoXY(06,Z_Base+5);  write('Stat-Rd-Count :');
   GotoXY(35,Z_Base+6);  write('^  ^');
   GotoXY(06,Z_Base+7);  write('Stat-Data[Hex]:');
   GotoXY(06,Z_Base+8);  write('Stat-Data[Bin]:');
   GotoXY(06,Z_Base+9);  write('Mask-Data[Bin]:');
   GotoXY(22,Z_Base+10); write('MSB             LSB');
   GotoXY(06,Z_Base+11); write('Last-Evnt[Hex]:');

   Set_Text_Win;
   TextColor(Brown);
   GotoXY(03,17); write  ('Belegung der Funktions-Tasten:');
   TextColor(Black);

   GotoXY(22,Z_Base-1);  Write(Hex_Byte(ModAdr.AdrIfc));
   GotoXY(22,Z_Base  );  Write(Hex_Byte(ModAdr.AdrCard));

   Set_TastEvt_Win;
   TextColor(Yellow);              {(chr($7C))}
   GotoXY(01, 01); Write('F1:En  Evt-Mask 1..12    F9 :Reset Evt-Pigy ');
   GotoXY(01, 02); Write('F2:Dis Evt-Mask 1..12    F10:WrMask-Data [H]');
   GotoXY(01, 03); Write('F3:Defin. Timeout Evt    F11:En  ext. Event ');
   GotoXY(01, 04); Write('F4:Set Timeout ZÑhler    F12:Dis ext. Event ');
   TextColor(Black);
   Displ_Mod_Stat;
   Set_Text_Win;

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
       Mil.Timer2_Wait(10000);
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Set_Text_win;
       Show_Stat_Reg;
       Mil.Timer2_Wait(10000);
      end;

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : Evt_Mask_Toggle (Enable);
        Taste_F2 : Evt_Mask_Toggle (Disable);
        Taste_F3 : begin              {Timeout event}
                     if Ask_Hex_Break (User_Input, Wrd) then
                      begin
                        Timeout_Evt    := User_Input;
                        ModAdr.AdrIfc  := Ifc_Test_Nr;              {Modul-Adr definieren}
                        ModAdr.AdrCard := Mod_Test_Nr;
                        ModAdr.AdrSub  := SubAdr_12Evt_RamTimEvt;   {RAM Timeout-Event}
                        ModAdr.AdrMode := AdrNew;
                        Mil.Wr_ModBus (Timeout_Evt, ModAdr, MilErr);
                        Displ_Timeout_Event;
                      end;
                     Std_Msg;
                   end;
        Taste_F4 : begin
                     Ini_Msg_Win;
                     Write ('Bitte Timeout-Zeit (0..65535 [ms]) eingeben: ');
                     {$I-}                            {Compiler Check aus, Error selber abfangen}
                     Read (User_Int);
                     {$I+}
                     IoRes := IoResult;
                     if (IoRes = 0) then
                      begin
                        if (User_Int > $FFFF) then User_Int := $FFFF;
                        if (User_Int < 0)     then User_Int := 0;
                        Timeout_Ms := User_Int;
                        ModAdr.AdrIfc  := Ifc_Test_Nr;              {Modul-Adr definieren}
                        ModAdr.AdrCard := Mod_Test_Nr;
                        ModAdr.AdrSub  := SubAdr_12Evt_RamTimMs;   {RAM Timeout-Zeit}
                        ModAdr.AdrMode := AdrNew;
                        Mil.Wr_ModBus (Timeout_Ms, ModAdr, MilErr);
                        Displ_Timeout_Event;
                      end;
                    Std_Msg;
                   end;
        Taste_F9: begin
                     ModAdr.AdrIfc  := Ifc_Test_Nr;
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrSub  := SubAdr_12Evt_Reset  ;
                     ModAdr.AdrMode := AdrNew;
                     WrData := 0;
                     Mil.Wr_ModBus (WrData, ModAdr, MilErr);
                     Ini_Err_Win;
                     Write ('Reset 12Event-Karte !!!');
                     Mil.Timer2_Wait(200000);
                     Std_Msg;
                   end; {Taste_F9}
        Taste_F10: begin
                    if Ask_Hex_Break (User_Input, Wrd) then
                     begin
                      ModAdr.AdrIfc  := Ifc_Test_Nr;
                      ModAdr.AdrCard := Mod_Test_Nr;
                      ModAdr.AdrSub := SubAdr_12Evt_Mask;
                      ModAdr.AdrMode := AdrNew;
                      WrData := User_Input;
                      Mil.Wr_ModBus (WrData, ModAdr, MilErr);
                     end;
                     Std_Msg;
                   end; {Taste_F10}
        Taste_F11: begin
                     ModAdr.AdrIfc  := Ifc_Test_Nr;
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrSub  := SubAdr_12Evt_EnExtEvt;
                     ModAdr.AdrMode := AdrNew;
                     WrData := 0;
                     Mil.Wr_ModBus (WrData, ModAdr, MilErr);
                     Ini_Err_Win;
                     Write ('ENable Ext. Event !!!');
                     Mil.Timer2_Wait(200000);
                     Std_Msg;
                   end; {Taste_F11}
        Taste_F12: begin
                     ModAdr.AdrIfc  := Ifc_Test_Nr;
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrSub  := SubAdr_12Evt_DisExtEvt;
                     ModAdr.AdrMode := AdrNew;
                     WrData := 0;
                     Mil.Wr_ModBus (WrData, ModAdr, MilErr);
                     Ini_Err_Win;
                     Write ('DISable Ext. Event !!!');
                     Mil.Timer2_Wait(200000);
                     Std_Msg;
                   end; {Taste_F12}
       end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
 end; {Evt_Status}


 procedure Evt_Rd_Last;
  Label 99;

  var Read_Data  : WORD;
      MilErr     : TMilErr;
      Fct        : TFct;
      Transf_Cnt : LongInt;
      Timout_Cnt : LongInt;
      WrMask_Cnt : LongInt;
      Rd_Stat_Cnt:  LongInt;
      WrData     : Word;
      Adress     : Word;
      ModAdr     : TModAdr;
      ModIdent   : TID_Type;
      IdRet_Code : TIfk_IdErr;


   PROCEDURE get_data;
    var Rd_Dta : Word;
        Bit16_Strg : Str19;

    Begin
     ModAdr.AdrIfc  := Ifc_Test_Nr;          {Modul-Adr definieren}
     ModAdr.AdrCard := Mod_Test_Nr;
     ModAdr.AdrSub  := SubAdr_12Evt_Evt; {Subadr 12Evt letzter Event}
     ModAdr.AdrMode := AdrNew;
     Mil.Rd_ModBus (Rd_Dta, ModAdr, MilErr);   {Lese Maskenregister}
     IF MilErr  <> No_Err THEN
      Begin
        timout_cnt := timout_cnt + 1;
        rd_timeout := TRUE;
        GotoXY(22,12); write(timout_cnt:12);
        TextColor (Black);
        GotoXY(25, 17);  write('    ');
        GotoXY(17, 18);  write('                   ');
      End
     ELSE
      Begin  {kein Timeout}
       rd_timeout := FALSE;
       GotoXY(25, 17);  write(hex_word(Rd_Dta));
       Hex_Bin_Str (Rd_Dta,bit16_strg);
       GotoXY(17, 18);  write(bit16_strg);
      End;
    End; {get_data}

  Begin
    transf_cnt := 0;
    timout_cnt := 0;

    Ini_Text_Win;
    TextColor(Brown);
    GotoXY(27,05); write('----- Lese letzten EVENT -----');
    GotoXY(06,11); writeln('Rd_Data_Cnt  :');
    GotoXY(26,12); writeln('^  ^');
    GotoXY(06,12); writeln('Timeout_Count: ');
    GotoXY(22,12); writeln(timout_cnt:12);

    GotoXY(02,17); writeln('MIL-Data[H]:');
    GotoXY(08,18); writeln('[Bin]:');
    GotoXY(17,19); writeln('MSB             LSB');
    TextColor(Brown);

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
        GotoXY(22, 11); write(transf_cnt:12);
        Get_Data;
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
 end; {Evt_Rd_Last }


 Procedure Evt_WrRD_Last;
  LABEL 99;
  var Read_Data  : WORD;
      MilErr     : TMilErr;
      Fct        : TFct;
      Transf_Cnt : LongInt;
      Timout_Cnt : LongInt;
      WrMask_Cnt : LongInt;
      Rd_Stat_Cnt:  LongInt;
      WrData     : Word;
      Adress     : Word;
      ModAdr     : TModAdr;
      ModIdent   : TID_Type;
      IdRet_Code : TIfk_IdErr;
      User_Data  : Word;
      Wr_Data    : Word;
      Auto_Test  : Boolean;
      Bit16_Strg : Str19;
      Error_Cnt  : LONGINT;

  procedure  Set_TastWr_Win;
   begin
    Window(39, 21, 80, 23);
    TextBackground(Green);
    TextColor(Black);               {Setze Schriftfarbe}
   end;

   procedure Displ;
    begin
      Cursor(False);
      Set_Text_Win;
      GotoXY(18,10); write(transf_cnt:10);
      GotoXY(48,10); write(hex_word(Wr_Data));
      if not Auto_Test then
       begin
        Hex_Bin_Str (Wr_Data,bit16_strg);
        GotoXY(42, 11);  write(bit16_strg);
       end
      else
       begin
         GotoXY(42, 11);  write('                   ');
       end;
      TextColor (Red);
      GotoXY(18, 12);  write(Error_Cnt:10);
      TextColor (Black);
     end; {Wr-Data}

  procedure Wr_SW (Data: Word);
   begin
     Transf_Cnt := Transf_Cnt+ 1;
     ModAdr.AdrIfc  := Ifc_Test_Nr;          {Modul-Adr definieren}
     ModAdr.AdrCard := Mod_Test_Nr;
     ModAdr.AdrSub  := SubAdr_12Evt_Evt; {Subadr 12Evt Wr/Rd letzter Event}
     ModAdr.AdrMode := AdrNew;
     Mil.Wr_ModBus (Data, ModAdr, MilErr);
     Displ;
   end; {Wr-Data}

  PROCEDURE Get_Data (Snd_Dta: Word);
   var Rd_Data : Word;
       Bit16_Strg : Str19;
   Begin
    Set_Text_Win;
    ModAdr.AdrIfc  := Ifc_Test_Nr;          {Modul-Adr definieren}
    ModAdr.AdrCard := Mod_Test_Nr;
    ModAdr.AdrSub  := SubAdr_12Evt_Evt; {Subadr 12Evt letzter Event}
    ModAdr.AdrMode := AdrNew;
    Mil.Rd_ModBus (Rd_Data, ModAdr, MilErr);   {Lese Maskenregister}

    IF MilErr  <> No_Err THEN
     Begin
       rd_timeout := TRUE;
       GotoXY(48, 13);  write('    ');
       TextColor(Red);
       GotoXY(42, 14);  write('   Read Timeout    ');
       TextColor(Black);
     End
    ELSE
     Begin  {kein Timeout}
      rd_timeout := FALSE;
      if Rd_Data = Snd_Dta then
        begin
         TextColor (Black);
         GotoXY(48, 13);  write(hex_word(Rd_Data));
         if not Auto_Test then
          begin
           Hex_Bin_Str (Rd_Data,bit16_strg);
           GotoXY(42, 14);  write(bit16_strg);
          end
         else
          begin
            GotoXY(42, 14);  write('                   ');
          end;
        end
      else
        begin
         TextColor(Red);
         GotoXY(48, 13);  write(hex_word(Rd_Data));
         if not Auto_Test then
          begin
           Hex_Bin_Str (Rd_Data,bit16_strg);
           GotoXY(42, 14);  write(bit16_strg);
          end
         else
          begin
            GotoXY(48, 13);  write('    ');
            GotoXY(42, 14);  write('                   ');
          end;
         Error_Cnt := Error_Cnt +1;
         GotoXY(18, 12);  write(Error_Cnt:10);
        end;
       end;
    Displ;
    TextColor(Black);
   End; {get_data}

   Begin
    Wr_Data    := 0;
    transf_cnt := 0;
    error_cnt  := 0;
    timout_wr  := 0;
    Single_Step:= True;
    Auto_Test  := False;
    ModAdr.AdrIfc  := Ifc_Test_Nr;          {Modul-Adr definieren}
    ModAdr.AdrCard := Mod_Test_Nr;

    Ini_Text_Win;
    TextColor(Brown);
    GotoXY(15,03); write('----- Sende Event und lese als Letzten-Event zurÅck -----');
    GotoXY(15,04); write('         Vergleiche Sende-Event und Letzten-Event ');
    GotoXY(05,07); Write  ('Ifk-Adr [Hex]: '); TextColor(Black); Write (Hex_Byte (ModAdr.AdrIfc ));  TextColor(Brown);
    GotoXY(05,08); Write  ('Modul-Nr[Hex]: '); TextColor(Black); Write (Hex_Byte (ModAdr.AdrCard)); TextColor(Brown);

    TextColor(Brown);
    GotoXY(5, 10); write('Wr-Data-Cnt:                Write-Data[H]:                ');
    GotoXY(22,11); write('^  ^');
    GotoXY(5, 12); write('Error-Count: ');
    GotoXY(05,13); write('                            Rd-Data [Hex]:');
    GotoXY(42,15); write('MSB             LSB');

    GotoXY(39,18); write('Belegung Funktions- u. Sondertasten: ');
    GotoXY(5, 18); write('Autom. Incr-Test: ');
    TextColor(Black);
    GotoXY(23,18); if Auto_Test then Write ('EIN') else Write ('AUS');

    Set_TastWr_Win;
    TextColor(Yellow);
    GotoXY(01, 01); Write('F1: Event [Hex]     F11: EIN Incr-Test   ');
    GotoXY(01, 02); Write('F5: Event = 0       F12: AUS Incr-Test   ');
    GotoXY(01, 03); Write('F9: Clr Err-Counts  <- -> Bit schieben   ');
    Displ;

    Mil.Reset;    { clear fifo }
    Std_Msg;
    Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       if Auto_Test then Wr_Data := Wr_Data +1;
       Wr_SW    (Wr_Data);
       Get_Data (Wr_Data);
       Single_Step := True;
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       if Auto_Test then Wr_Data := Wr_Data +1;
       Wr_SW    (Wr_Data);
       Get_Data (Wr_Data);
       Displ;
      end;

    if KeyEPressed then Ch := NewReadkey;
     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
       Taste_F1 : begin
                   if Ask_Hex_Break (User_Data, Wrd) then
                    begin
                      Wr_Data := User_Data;
                      Displ;
                    end;
                   Std_Msg;
                  end;
       Taste_F2 : begin
                  end;
       Taste_F5 : begin
                   Wr_Data := 0;
                   Displ;
                  end;
       Taste_F9: begin
                   Error_Cnt := 0;
                   Displ;
                  end; {Taste_F12}
       Taste_F11: begin
                    Auto_Test:= True;
                    Set_Text_Win;
                    GotoXY(23,18); if Auto_Test then Write ('EIN') else Write ('AUS');
                 end; {Taste_F10}
       Taste_F12: begin
                    Auto_Test := False;
                    Set_Text_Win;
                    GotoXY(23,18); if Auto_Test then Write ('EIN') else Write ('AUS');
                  end; {Taste_F12}
       Taste_Pfeil_Links : begin
                             if Wr_Data = $0000 then Wr_Data := $1
                             else Wr_Data := Wr_Data shl 1;
                             Displ;
                            end;  {Taste_Pfeil_Links}
       Taste_Pfeil_Rechts: begin
                            if Wr_Data = $0000 then Wr_Data := $8000
                            else Wr_Data := Wr_Data shr 1;
                            Displ;
                           end;  {Taste_Pfeil_Rechts}
      end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
 99:
End; {Evt_WrRD_Last}


 procedure Evt_WrRd_Fifo;   {Daten werden direkt aus dem RCV-Fifo gelesen!!}
  LABEL 99;                 {u. a. weil kein Functionscode nîtig ist. }
   VAR
     Bit16_Strg   : Str19;
     Error_Cnt    : LONGINT;
     Fifo_Err_Cnt : LONGINT;
     Auto_Test    : Boolean;
     ModAdr       : TModAdr;
     User_Data    : Word;
     MilErr : TMilErr;
     Fct    : TFct;
     Code   : Word;
     Adress : Word;
     Wr_Data: Word;

  procedure  Set_TastWr_Win;
   begin
    Window(39, 21, 80, 23);
    TextBackground(Green);
    TextColor(Black);               {Setze Schriftfarbe}
   end;

  procedure Std_Msg;
   begin
    Ini_Msg_Win;
    Write('Stop/Single Step mit <SPACE>, Loop mit <CR> ,  Ende mit [X]');
   end;

   procedure Displ;
    begin
      Set_Text_Win;
      GotoXY(18,10); write(transf_cnt:10);
      GotoXY(48,10); write(hex_word(Wr_Data));
      if not Auto_Test then
       begin
        Hex_Bin_Str (Wr_Data,bit16_strg);
        GotoXY(42, 11);  write(bit16_strg);
       end
      else
       begin
         GotoXY(42, 11);  write('                   ');
       end;
      TextColor (Red);
      GotoXY(18, 12);  write(Error_Cnt:10);
      GotoXY(18, 13);  write(Fifo_Err_Cnt:10);

      TextColor (Black);
     end; {Wr-Data}

  procedure Wr_SW (Data: Word);
   begin
     Transf_Cnt := Transf_Cnt+ 1;
     ModAdr.AdrIfc  := Ifc_Test_Nr;          {Modul-Adr definieren}
     ModAdr.AdrCard := Mod_Test_Nr;
     ModAdr.AdrSub  := SubAdr_12Evt_Evt; {Subadr 12Evt Wr/Rd letzter Event}
     ModAdr.AdrMode := AdrNew;
     Mil.Wr_ModBus (Data, ModAdr, MilErr);
     Displ;
   end; {Wr-Data}

  PROCEDURE Get_Data (Snd_Dta: Word);
   var Rd_Data : Word;
       Bit16_Strg : Str19;
       Pc_Stat    : TPcStat;
   Begin
    Set_Text_Win;
      {Ist Fifo vor der Wartezeit leer? (leider von CPU-Speed beeinflu·t)}
{    Pc_Stat.W := PortW [Port_Stat];
    if not (FfoEty in Pc_Stat.B) then
     begin
      Fifo_Err_Cnt := Fifo_Err_Cnt + 1;
      rd_timeout := TRUE;
      GotoXY(48, 13);  write('    ');
      TextColor(Red);
      GotoXY(42, 14);  write('Snd: not Fifo empty');
      TextColor(Black);
      Ini_Err_Win;
      Write('ERROR: Nach Evt_Send bereits Daten im FIFO!!     Stop mit <Space> ');
      Mil.Timer2_Wait(150000);
      Std_Msg;
      Exit;
     end;
  }
    Mil.Timer2_Wait(5);             {mindestens 50 us warten = 2xMiltransfer}
    Pc_Stat.W := PortW [Port_Stat]; {internen PC-Status lesen}
    if (FfoEty in Pc_Stat.B) then   {ist Fifo leer?}
      MilErr := Rd_To               {Ja!}
    else
     begin
      MilErr  := No_Err;
      Rd_Data := PORTW [Port_Data];   {nur fÅr hardwarenahe Testzwecke erlaubt}
     end;

    IF MilErr <> No_Err THEN
     Begin
       Fifo_Err_Cnt := Fifo_Err_Cnt + 1;
       rd_timeout := TRUE;
       GotoXY(48, 13);  write('    ');
       TextColor(Red);
       GotoXY(42, 14);  write(' Rcv: FiFo empty!! ');
       TextColor(Black);
       Ini_Err_Win;
       Write('ERROR: Nach Wartezeit keine Daten im RCV-FIFO!!      Stop mit <Space>');
       Mil.Timer2_Wait(150000);       {mindestens 50 us warten = 2xMiltransfer}
       Std_Msg;
     End
    ELSE
     Begin  {kein Timeout}
      rd_timeout := FALSE;
      if Rd_Data = Snd_Dta then
        begin
         TextColor (Black);
         GotoXY(48, 13);  write(hex_word(Rd_Data));
         if not Auto_Test then
          begin
           Hex_Bin_Str (Rd_Data,bit16_strg);
           GotoXY(42, 14);  write(bit16_strg);
          end
         else
          begin
            GotoXY(42, 14);  write('                   ');
          end;
        end
      else
        begin
         TextColor(Red);
         GotoXY(48, 13);  write(hex_word(Rd_Data));
         if not Auto_Test then
          begin
           Hex_Bin_Str (Rd_Data,bit16_strg);
           GotoXY(42, 14);  write(bit16_strg);
          end
         else
          begin
            GotoXY(48, 13);  write('    ');
            GotoXY(42, 14);  write('                   ');
          end;
         Error_Cnt := Error_Cnt +1;
         GotoXY(18, 12);  write(Error_Cnt:10);
        end;
       end;
    Displ;
    TextColor(Black);
   End; {get_data}

   Begin
    Wr_Data     := 0;
    transf_cnt  := 0;
    error_cnt   := 0;
    Fifo_Err_Cnt:= 0;
    timout_wr   := 0;
    Single_Step := True;
    Auto_Test   := False;

    Ini_Text_Win;
    Fct.B.Adr := Ifc_Test_Nr;

    Ini_Text_Win;
    GotoXY(10,02); write('----- Sende Event und lese verzîgert direkt aus RCV-FIFO zurÅck -----');
    GotoXY(10,03); write('              Vergleiche Sende-Event und FIFO-Daten ');
    TextColor (Yellow);
    GotoXY(15,04); Write ('Achtung: Device-Stecker mit Event-Stecker verbinden!!!! ');
    TextColor (Black);
    TextColor(Brown);
{    Fct.B.Fct  := Fct_Wr_Event;
    GotoXY(22,06); Write  ('Wr-Function-Word (Fct + Adr): ',hex_word(Fct.W),' [H]');
}   GotoXY(5, 10); write('Wr-Data-Cnt:                Write-Data[H]:                ');
    GotoXY(22,11); write('^  ^');
    GotoXY(5, 12); write('Dta-Err-Cnt: ');
    GotoXY(33,13);                             write('Rd-Fifo [Hex]:');
    GotoXY(5, 13); write('Ffo-Err-Cnt: ');
    GotoXY(42,15); write('MSB             LSB');

    GotoXY(39,18); write('Belegung Funktions- u. Sondertasten: ');
    GotoXY(5, 18); write('Autom. Incr-Test: ');
    TextColor(Black);
    GotoXY(23,18); if Auto_Test then Write ('EIN') else Write ('AUS');

    Set_TastWr_Win;
    TextColor(Yellow);
    GotoXY(01, 01); Write('F1: Event [Hex]     F11: EIN Incr-Test   ');
    GotoXY(01, 02); Write('F5: Event = 0       F12: AUS Incr-Test   ');
    GotoXY(01, 03); Write('F9: Clr Err-Counts  <- -> Bit schieben   ');
    Displ;

    Mil.Reset;
    Std_Msg;                            { clear fifo }
    Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       if Auto_Test then Wr_Data := Wr_Data +1;
       Wr_SW    (Wr_Data);
       Get_Data (Wr_Data);
       Single_Step := True;
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = Taste_Return then Single_Step := False;

     if not Single_Step then
      begin
       if Auto_Test then Wr_Data := Wr_Data + 1;
       Wr_SW    (Wr_Data);
       Get_Data (Wr_Data);
       Displ;
      end;

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
       Taste_F1 : begin
                   if Ask_Hex_Break (User_Data, Wrd) then Wr_Data := User_Data;
                   Displ;
                   Std_Msg;
                  end;
       Taste_F2 : begin
                  end;
       Taste_F5 : begin
                   Wr_Data := 0;
                   Displ;
                  end;
       Taste_F9: begin
                   Error_Cnt    := 0;
                   Fifo_Err_Cnt := 0;
                   Displ;
                  end; {Taste_F12}
       Taste_F11: begin
                    Auto_Test:= True;
                    Set_Text_Win;
                    GotoXY(23,18); if Auto_Test then Write ('EIN') else Write ('AUS');
                 end; {Taste_F10}
       Taste_F12: begin
                    Auto_Test := False;
                    Set_Text_Win;
                    GotoXY(23,18); if Auto_Test then Write ('EIN') else Write ('AUS');
                  end; {Taste_F12}

       Taste_Pfeil_Links : begin
                             if Wr_Data = $0000 then Wr_Data := $1
                             else Wr_Data := Wr_Data shl 1;
                             Displ;
                            end;  {Taste_Pfeil_Links}
       Taste_Pfeil_Rechts: begin
                            if Wr_Data = $0000 then Wr_Data := $8000
                            else Wr_Data := Wr_Data shr 1;
                            Displ;
                           end;  {Taste_Pfeil_Rechts}
      end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:
 end; {Evt_WrRd_Fifo}


 procedure Evt_WrRAM;
  Label 99;
  const
   Z_Base     = 10;
   Z_Base_Ram = 9;
   Z_Count    = Z_Base - 3;
   S_Base     = 40;
   S_RAM_Base = 6;
   S_CntOffSet= 18;

{   Rd_Fct_Base = $80;}  {Rd RAM1: Fct-Code 81H usw.}
{   Wr_Fct_Base = 8;  }   {Wr RAM1: Fct-Code  9  usw. }

  var
   fct_code : WORD;
   MilErr : TMilErr;
   Fct    : TFct;
   Transf_Cnt: LongInt;
   Timout_Cnt: LongInt;
   Adress    : Word;
   User_Data : Word;
   ModAdr    : TModAdr;
   RAM_Num   : Integer;
   X         : Byte;

  procedure  Set_TastEvt_Win;
   begin
    Window(S_Base, 21, S_Base+40, 23);
    TextBackground(Green);
    TextColor(Black);               {Setze Schriftfarbe}
   end;

 type TLife = (Norm, Blink);

 procedure Life_Sign (Mode: TLife);
  const S_Aktiv   = S_RAM_Base+22;
        Z_Aktiv   = Z_Base_Ram+0;
        Life_Time1 = 5000;
        Life_Time2 = 2000;
  var Life_Wait : LongInt;
  begin
    Cursor (False);
    Set_Text_Win;
    if Mode = Norm then
     begin
      Life_Wait := Life_Time2;
      Set_Text_Win;
      TextColor(Yellow);
      GotoXY(S_Aktiv, Z_Aktiv);  Write (chr($7C)); Mil.Timer2_Wait (Life_Wait);
      GotoXY(S_Aktiv, Z_Aktiv);  Write ('/');      Mil.Timer2_Wait (Life_Wait);
      GotoXY(S_Aktiv, Z_Aktiv);  Write (chr($2D)); Mil.Timer2_Wait (Life_Wait);
      GotoXY(S_Aktiv, Z_Aktiv);  Write ('\');      Mil.Timer2_Wait (Life_Wait);
     end
    else
     begin
       TextColor(Red+128);
       GotoXY(S_Aktiv, Z_Aktiv); Write (chr($B2));
     end;
    TextColor(Black);
    Cursor(True);
   end; {Life_Sign}

 procedure Ini_Event_Win;
  begin
   Window(50, 08, 80, 24);
   TextBackground(Cyan);
   TextColor(Black);               {Setze Schriftfarbe}
   ClrScr;
  end;

 procedure Disp_EvtRAM;
  var I : Byte;
  begin
    Cursor(False);
    Set_Text_Win;
    for I := 1 to Ext_Evt_Max+1 do
     begin
       ModAdr.AdrIfc  := Ifc_Test_Nr;              {Modul-Adr definieren}
       ModAdr.AdrCard := Mod_Test_Nr;
       ModAdr.AdrSub  := SubAdr_12Evt_RamBase+2*I; {Subadr 12Evt Wr/Rd letzter Event}
       ModAdr.AdrMode := AdrNew;
       Mil.Rd_ModBus (Read_Data, ModAdr, MilErr);
       GotoXY(S_RAM_Base+20,Z_Base_Ram+I);
       if MilErr = No_Err then
        begin
          Write (hex_word(Read_Data));
        end
       else
        begin
          Write ('    ');
        end;
     end; {for}
  end; {Disp-Ram}

 procedure Disp_WrData;
  var Bit16_Strg : Str19;
  begin
    TextColor(Black);
    Set_Text_Win;
    GotoXY(S_Base+20,Z_Base-1);
    Write (Hex_Word (Write_Data));
    Hex_Bin_Str (Write_Data,bit16_strg);
    GotoXY(S_Base+20,Z_Base);  Write(bit16_strg);
  end; {Disp_WrData}

 procedure Wr_Evt_RAM (RAM_Nr: Byte; Data: Word);
  var N: Byte;
  begin
    if RAM_Nr in [1..Ext_Evt_Max+1] then   {wegen Timeout Event}
     begin
      ModAdr.AdrIfc  := Ifc_Test_Nr;                  {Modul-Adr definieren}
      ModAdr.AdrCard := Mod_Test_Nr;
      ModAdr.AdrSub  := SubAdr_12Evt_RamBase+2*RAM_Nr; {Subadr 12Evt RAM Wr/Rd letzter Event}
      ModAdr.AdrMode := AdrNew;
      Mil.Wr_ModBus (Data, ModAdr, MilErr);

      Set_Text_Win;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(S_Base+S_CntOffSet  ,Z_Count); Write(transf_cnt:8);

      TextColor(Black);
      {Zeige auf RAM, in das geschrieben wurde}
      for N := 1 to Ext_Evt_Max+1 do
       begin
         GotoXY(S_RAM_Base-4,Z_Base_Ram+N);
         Write ('    ');
       end;
      GotoXY(S_RAM_Base-4,Z_Base_Ram+RAM_Nr);
      TextColor(Red);
      Write ('Wr->');
      TextColor(Black);
     end;
  end; {Wr_Evt_RAM}

  Begin             {Evt_WrRAM}
   Cursor(False);
   Ini_Text_Win;
   Write_Data := 0;
   Transf_Cnt := 0;
   timout_cnt := 0;

   GotoXY(22,01); write('----- Lesen/Schreiben Event-RAM -----');
{   GotoXY(16,02); write  ('Function-Word Read-Event-RAM (Fct + Adr): ',hex_word(Fct.W));
}  TextColor(Yellow);
   GotoXY(10,03); write('Mit F1-Taste RAM-Adr wÑhlen und Wr-Data ins Event-RAM schreiben');
   TextColor(Brown);
   GotoXY(05,05); Write  ('Ifk-Adr [Hex]: '); TextColor(Black); Write (Hex_Byte (Ifc_Test_Nr));  TextColor(Brown);
   GotoXY(05,06); Write  ('Modul-Nr[Hex]: '); TextColor(Black); Write (Hex_Byte (Mod_Test_Nr));

   TextColor(Brown);
   GotoXY(S_Base              ,Z_Count  ); Write('Wr_RAM_Count   :');
   GotoXY(S_Base+S_CntOffSet+2,Z_Count+1); Write('^  ^');
   GotoXY(S_Base   ,Z_Base-1);      Write('Wr-Data   [Hex]: ');
   GotoXY(S_Base+20,Z_Base-1);      Write (hex_word(Write_Data));
   GotoXY(S_Base   ,Z_Base+0);      Write('          [Bin]: ');
   GotoXY(S_Base+20,Z_Base+1);      Write('MSB             LSB');
   TextColor(Black);
   GotoXY(S_Base+S_CntOffSet  ,Z_Count); Write(transf_cnt:8);

   Disp_WrData;

   TextColor(Blue);
   GotoXY(S_RAM_Base,Z_Base_Ram+0);   write('Rd-RAM aktiv -->');
   TextColor(Brown);
   GotoXY(S_RAM_Base,Z_Base_Ram+1);   write('RAM 1-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base_Ram+2);   write('RAM 2-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base_Ram+3);   write('RAM 3-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base_Ram+4);   write('RAM 4-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base_Ram+5);   write('RAM 5-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base_Ram+6);   write('RAM 6-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base_Ram+7);   write('RAM 7-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base_Ram+8);   write('RAM 8-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base_Ram+9);   write('RAM 9-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base_Ram+10);  write('RAM10-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base_Ram+11);  write('RAM11-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base_Ram+12);  write('RAM12-Data [Hex]:');
   GotoXY(S_RAM_Base,Z_Base_Ram+13);  write('TimeoutEvt [Hex]:');
   TextColor(Black);

   Set_TastEvt_Win;
   TextColor(Yellow);
   GotoXY(01, 01); Write('F1: WrRAM einzel     F11: Wr-Data  = 0  ');
   GotoXY(01, 02); Write('F2: WrRAM alle       F12: Wr-Data [Hex] ');
   GotoXY(01, 03); Write('F3: WrRAM TimoutEvt  <- -> Bit schieben ');

   Set_Text_Win;
   TextColor(Brown);
   GotoXY(S_Base,18); write  ('Belegung der Funktions-Tasten:');
   TextColor(Black);

   Cursor(True);
   Std_Msg;
   Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Life_Sign (Norm);
       Disp_EvtRAM;
       Mil.Timer2_Wait(1000);
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Set_Text_win;
       Life_Sign (Norm);
       Disp_EvtRAM;
       Mil.Timer2_Wait(1000);
      end;

    if Ch = #0 then
     begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    if Read_Int (1, Ext_Evt_Max, RAM_Num) then
                     begin
                       Wr_Evt_RAM (RAM_Num, Write_Data);
                       Disp_EvtRAM;
                       Life_Sign (Norm);
                     end;
                    Std_Msg;
                   end;
        Taste_F2 : begin
                     for X := 1 to Ext_Evt_Max do  {Alle RAM's fÅllen}
                      begin
                       Wr_Evt_RAM (X, Write_Data);
                       Disp_EvtRAM;
                       Life_Sign (Norm);
                      end;
                   end;
        Taste_F3 : begin
                    if Ask_Hex_Break (User_Data, Wrd) then
                     begin
                      Wr_Evt_RAM (13, User_Data);
                      Disp_EvtRAM;
                      Life_Sign (Norm);
                     end;
                    Std_Msg;
                  end;
        Taste_F11: begin
                    Write_Data := 0;
                    Disp_WrData;
                    Std_Msg;
                   end; {Taste_F10}
        Taste_F12: begin
                    if Ask_Hex_Break (User_Data, Wrd) then
                     begin
                      Write_Data := User_Data;
                      Disp_WrData;
                     end;
                    Std_Msg;
                   end; {Taste_F11}
       Taste_Pfeil_Links : begin
                            if Write_Data = $0000 then Write_Data := $1
                            else Write_Data := Write_Data shl 1;
                            Disp_WrData;
                            Std_Msg;
                            end;  {Taste_Pfeil_Links}
       Taste_Pfeil_Rechts: begin
                            if Write_Data = $0000 then Write_Data := $8000
                            else Write_Data := Write_Data shr 1;
                            Disp_WrData;
                            Std_Msg;
                           end;  {Taste_Pfeil_Rechts}
       end; {case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:    Cursor(True);
  end; {Evt_WrRAM}

procedure Evt_Ext_Polari;
  LABEL 99;
  var Read_Data  : WORD;
      MilErr     : TMilErr;
      Fct        : TFct;
      Transf_Cnt : LongInt;
      Timout_Cnt : LongInt;
      WrMask_Cnt : LongInt;
      Rd_Stat_Cnt:  LongInt;
      WrData     : Word;
      Adress     : Word;
      ModAdr     : TModAdr;
      ModIdent   : TID_Type;
      IdRet_Code : TIfk_IdErr;
      User_Data  : Word;
      Wr_Data    : Word;
      Bit16_Strg : Str19;
      Error_Cnt  : LONGINT;
      Bit_Num    : Integer;
      Wr_Data_Valid : Boolean;
      Wr_Data_Loop  : Boolean;

  procedure  Set_TastWr_Win;
   begin
    Window(39, 21, 80, 23);
    TextBackground(Green);
    TextColor(Black);               {Setze Schriftfarbe}
   end;

  procedure Displ;
    begin
      Cursor(False);
      Set_Text_Win;
      GotoXY(18,10); write(transf_cnt:10);

      if Wr_Data_Valid  then
       begin
         GotoXY(48,10); write(hex_word(Wr_Data));
         Hex_Bin_Str (Wr_Data,bit16_strg);
         GotoXY(42, 11);  write(bit16_strg);
       end
      else
       begin
         GotoXY(48,10); write('    ');
         Hex_Bin_Str (Wr_Data,bit16_strg);
         GotoXY(42, 11);  write('                ');
       end;

      TextColor (Red);
      GotoXY(18, 12);  write(Error_Cnt:10);
      TextColor (Black);
    end; {Displ}


  PROCEDURE Get_Data (Snd_Dta: Word);
   var Rd_Data : Word;
       Bit16_Strg : Str19;
       Life_Mode  : TLife_XY;
   Begin
    Life_Mode.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
    Life_Mode.PosX    := 31;        {02;}
    Life_Mode.PosY    := 13;        {12;}
    Life_Mode.Time    := Life_Time_Fast;
    Life_Mode.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}
    Life_Sign_XY (Life_Mode);

    Set_Text_Win;
    ModAdr.AdrIfc  := Ifc_Test_Nr;          {Modul-Adr definieren}
    ModAdr.AdrCard := Mod_Test_Nr;
    ModAdr.AdrSub  := SubAdr_12Evt_Polari;  {Subadr 12Evt letzter Event}
    ModAdr.AdrMode := AdrNew;
    Mil.Rd_ModBus (Rd_Data, ModAdr, MilErr);   {Lese Maskenregister}

    IF MilErr  <> No_Err THEN
     Begin
       rd_timeout := TRUE;
       GotoXY(48, 13);  write('    ');
       TextColor(Red);
       GotoXY(42, 14);  write('   Read Timeout    ');
       TextColor(Black);
     End
    ELSE
     Begin  {kein Timeout}
      rd_timeout := FALSE;
      if Wr_Data_Valid then
       begin
         if Rd_Data = Snd_Dta then
           begin
            TextColor (Black);
            GotoXY(48, 13);  write(hex_word(Rd_Data));
            Hex_Bin_Str (Rd_Data,bit16_strg);
            GotoXY(42, 14);  write(bit16_strg);
           end
         else
           begin
            TextColor(Red);
            GotoXY(48, 13);  write(hex_word(Rd_Data));
            Hex_Bin_Str (Rd_Data,bit16_strg);
            GotoXY(42, 14);  write(bit16_strg);
            Error_Cnt := Error_Cnt +1;
            GotoXY(18, 12);  write(Error_Cnt:10);
           end;
        end     {Wr_Data_Valid}
      else
       begin    {kein Vergleich, nur Daten anzeigen}
          TextColor (Black);
          GotoXY(48, 13);  write(hex_word(Rd_Data));
          Hex_Bin_Str (Rd_Data,bit16_strg);
          GotoXY(42, 14);  write(bit16_strg);
       end;
     end;
    Displ;
    TextColor(Black);
   End; {get_data}

type
 TPolMode = (positiv, negativ, neutral);

 procedure Set_Polari (Bit_Num: Byte; PolMode : TPolMode);
  var Poli_Data : Word;
  begin
    ModAdr.AdrIfc  := Ifc_Test_Nr;             {Modul-Adr definieren}
    ModAdr.AdrCard := Mod_Test_Nr;
    ModAdr.AdrSub  := SubAdr_12Evt_Polari ;    {Subadr 12Evt PolaritÑt}
    ModAdr.AdrMode := AdrNew;
    Mil.Rd_ModBus (Poli_Data, ModAdr, MilErr);   {Lese Maskenregister}
    if MilErr = No_Err then
     begin
       case PolMode of
        positiv : begin
                    Wr_Data := BitSet (Poli_Data, Bit_Num);
                    Mil.Wr_ModBus (Wr_Data, ModAdr, MilErr);   {Lese Maskenregister}
                    Wr_Data_Valid := True;
                    Transf_cnt := transf_cnt +1;
                  end;

       negativ : begin
                    Wr_Data := BitClr (Poli_Data, Bit_Num);
                    Mil.Wr_ModBus (Wr_Data, ModAdr, MilErr);   {Lese Maskenregister}
                    Wr_Data_Valid := True;
                    Transf_cnt := transf_cnt +1;
                  end;
       neutral : begin
                    Mil.Wr_ModBus (Wr_Data, ModAdr, MilErr);   {Lese Maskenregister}
                    Wr_Data_Valid := True;
                    Transf_cnt := Transf_cnt +1;
                  end;
       end;
     end; {noErr}
  end; {Set_Polari}


   Begin
    Wr_Data_Loop  := False;
    Wr_Data_Valid := False;
    Wr_Data    := 0;
    transf_cnt := 0;
    error_cnt  := 0;
    timout_wr  := 0;
    Single_Step:= True;
    ModAdr.AdrIfc  := Ifc_Test_Nr;          {Modul-Adr definieren}
    ModAdr.AdrCard := Mod_Test_Nr;

    Ini_Text_Win;
    TextColor(Brown);
    GotoXY(15,03); write('----- Setzte/Lese Trigger-PolaritÑt fÅr externe Events  -----');
    GotoXY(05,07); Write  ('Ifk-Adr [Hex]: '); TextColor(Black); Write (Hex_Byte (ModAdr.AdrIfc ));  TextColor(Brown);
    GotoXY(05,08); Write  ('Modul-Nr[Hex]: '); TextColor(Black); Write (Hex_Byte (ModAdr.AdrCard)); TextColor(Brown);

    TextColor(Brown);
    GotoXY(5, 10); write('Wr-Data-Cnt:                Write-Data[H]:                ');
    GotoXY(22,11); write('^  ^');
    GotoXY(5, 12); write('Error-Count: ');
    GotoXY(05,13); write('                            Rd-Data [Hex]:');
    GotoXY(42,15); write('MSB             LSB');

    GotoXY(39,18); write('Belegung Funktions- u. Sondertasten: ');
    Set_TastWr_Win;
    TextColor(Yellow);
    GotoXY(01, 01); Write('F1: Pol pos  1..12   F10: Wr-Data = 0     ');
    GotoXY(01, 02); Write('F2: Pol neg  1..12   F11: Wr-Data [Hex]   ');
    GotoXY(01, 03); Write('F9: Clr Err-Counts   F12: Wr/Rd Toggle   ');
    Displ;

    Mil.Reset;    { clear fifo }
    Std_Msg;
    Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       if Wr_Data_Loop then Set_Polari (0, Neutral);   {Sende Wr_Data}
       Get_Data (Wr_Data);
       Single_Step := True;
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       if Wr_Data_Loop then Set_Polari (0, Neutral);   {Sende Wr_Data}
       Get_Data (Wr_Data);
       Displ;
      end;

    if KeyEPressed then Ch := NewReadkey;
     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
       Taste_F1 : begin
                    if Read_Int (1, Ext_Evt_Max, Bit_Num) then
                     begin
                       Set_Polari (Bit_Num-1, Positiv);
                     end;
                   Std_Msg;
                  end;
       Taste_F2 : begin
                    if Read_Int (1, Ext_Evt_Max, Bit_Num) then
                     begin
                       Set_Polari (Bit_Num-1, Negativ);
                     end;
                   Std_Msg;
                  end;
       Taste_F5 : begin
                   Wr_Data := 0;
                   Displ;
                  end;
       Taste_F9: begin
                   Error_Cnt := 0;
                   Transf_Cnt:= 0;
                   Displ;
                  end; {Taste_F9}
       Taste_F10: begin
                    Wr_Data := 0;
                    Set_Polari (0, Neutral);   {Sende Wr_Data}
                    Displ;
                    Std_Msg;
                  end; {Taste_F11}
       Taste_F11: begin
                    if Ask_Hex_Break (User_Data, Wrd) then
                     begin
                      Wr_Data := User_Data;
                      Set_Polari (0, Neutral);   {Sende Wr_Data}
                      Displ;
                     end;
                    Std_Msg;
                  end; {Taste_F12}
       Taste_F12: begin
                   if Wr_Data_Loop then Wr_Data_Loop := False
                   else Wr_Data_Loop := True;
                  end; {Taste_F12}
       Taste_Pfeil_Links : begin
                             if Wr_Data = $0000 then Wr_Data := $1
                             else Wr_Data := Wr_Data shl 1;
                             Displ;
                            end;  {Taste_Pfeil_Links}
       Taste_Pfeil_Rechts: begin
                            if Wr_Data = $0000 then Wr_Data := $8000
                            else Wr_Data := Wr_Data shr 1;
                            Displ;
                           end;  {Taste_Pfeil_Rechts}
      end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
 99:
 end; {Evt_Ext_Polari}


begin                      { Hauptprogramm }
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
     'y', 'Y' : begin
                  Modul_Bus;
                end;
     'z', 'Z' : begin
                  Telefon;
                end;
     {Ab hier User-Erweiterungen!!}
          'm', 'M' : begin
                      if (Ifc_Test_Nr=0) or (Mod_Test_Nr=0) then Ask_Ifc_Mod_Adr;
                      Evt_Status;
                     end;
          'n', 'N' : begin
	              if (Ifc_Test_Nr=0) or (Mod_Test_Nr=0) then Ask_Ifc_Mod_Adr;
	              Evt_Rd_Last;
                     end;
          'o', 'O' : begin
	              if (Ifc_Test_Nr=0) or (Mod_Test_Nr=0) then Ask_Ifc_Mod_Adr;
                      Evt_WrRd_Last;
                     end;
          'p', 'P' : begin
	              if (Ifc_Test_Nr=0) or (Mod_Test_Nr=0) then Ask_Ifc_Mod_Adr;
                      Evt_WrRd_Fifo;
                     end;
          'q', 'Q' : begin
	              if (Ifc_Test_Nr=0) or (Mod_Test_Nr=0) then Ask_Ifc_Mod_Adr;
                      Evt_WrRAM;
                     end;
          'r', 'R' : begin
	              if (Ifc_Test_Nr=0) or (Mod_Test_Nr=0) then Ask_Ifc_Mod_Adr;
                      Evt_Ext_Polari;
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


