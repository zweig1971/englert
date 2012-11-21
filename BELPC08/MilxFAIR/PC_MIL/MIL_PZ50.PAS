PROGRAM Mil_PZ50;
{ Autor des Basis-Programmes Mil_Base.PAS: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS

  Voraussetzung: Modul-Adr im Unilac- und SIS-Teil jeweils von 1..x verdrahtet
                 und in einem Array definiert!!
                 IFK-Adr fÅr Unilac und SIS unterschiedlich, aber fest verdrahtet
                 damit an einem MIL-Bus gestestet werden kann!!

  énderungs-Protokoll:
  22.05.97   Et Erstellt fÅr neue Pulszentrale mit 50 Hz Synchronisierung
                und Event-Versendung mit 12-fach Event-Generator


}
{$S-}
uses Crt, WinDos, Dos, Datech, Datech_0, Datech_1;    {spez. MIL-Routinen in Units Datech..}

const
 Head_Line =
      'BELAB                              MIL_PZ50     ' +
      '                    [28.05.1997]' +
      '                 Unilac-Pulszentrale PZ50SYNC auf Modulbus-Basis               ';

 procedure menue_win;
 var answer: CHAR;
 begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;            {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}
  TextColor(Blue);
                  {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}
  GotoXY(5, 14);
  Writeln('       [M]<-- Belegung der Modulbus-SteckplÑtze (IST-SOLL)      ');
  GotoXY(5, 15);
  Writeln('       [N]<-- Event-Generator FG450.350 (12 ext. Events)         ');
  GotoXY(5, 16);
  Writeln('       [O]<-- Datentransfer zwischen Unilac <--> SIS Teil       ');
  GotoXY(5, 17);
  Writeln('       [P]<-- öberprÅfe Funkuhr                                 ');

{
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

{var Ifc_Test_Nr;  Mod_Test_Nr; sind global}

{
Bisherige Routinen f. alle Anwender gleich! Ab hier spezielle User-Routinen
}

 const
  Ifk_PZ_Uni = $B0;  {Adr der IFK ist auf Backplane festverdrahtet!!}
  Ifk_PZ_Sis = $B0;


  Slot_Max     = 10; {grî·tes denkbares Array fÅr allgemeinen Gebrauch}
  Slot_Max_Uni = 5;  {Anzahl Modulbus-SteckplÑtze im UNILAC-Teil}
  Slot_Max_Sis = 3;  {Anzahl Modulbus-SteckplÑtze im SIS-Teil   }



 type
  TSlot = record
           Belegt : Boolean;    {Slot belegt oder frei}
           VGAdr  : Byte;       {Modul-Adr Åber VG-Leiste festgelegt}
           CardID : Byte;       {Karten Identifizierung}
           Text   : string [32]; {Bezeichnung der Karte}
          end;

  TSlots_Uni = array [1..Slot_Max_Uni] of TSlot;
  TSlots_Sis = array [1..Slot_Max_Sis] of TSlot;
  TSlots     = array [1..Slot_Max]     of TSlot; {allgemeines Array}

  TSlotDisp = record                    {Paramter fÅr Bildschirmdarstellung}
               IfkNr     : Byte;
               IfkText   : string[12];  {Bezeichnung z. B. IFK-Uni [H]: }
               Z_Basis   : Byte;        {Zeile fÅr Bildschirm Darstellung}
               SlotAry   : TSlots;     {Zeiger auf SlotBelegungs Array}
               SlotMax   : Byte;        {Max. Anzahl SteckplÑtze}
              end;

 const                     {Soll-BestÅckung der Hardware-SteckplÑtze Modulbus}
  Slot_Uni : TSlots_Uni =
             (
             (Belegt: True;   VGAdr: 01; CardID: $21;
                              Text: 'Unilac-Karte 1'),
             (Belegt: True;   VGAdr: 02; CardID: $22;
                              Text: 'Unilac-Karte 2'),
             (Belegt: False;  VGAdr: 03; CardID: $00;
                              Text: 'frei fÅr Unilac-Karte 03'),
             (Belegt: False;  VGAdr: 04; CardID: $00;
                              Text: 'frei fÅr Unilac-Karte 04'),
             (Belegt: True;   VGAdr: 05; CardID: $25;
                              Text: 'Unilac-Karte 5'));

  Slot_Sis : TSlots_Sis =
             (
             (Belegt: True;  VGAdr: 01; CardID: $21;
                              Text: 'SIS-Karte 1'),
             (Belegt: True;  VGAdr: 02; CardID: $22;
                              Text: 'SIS-Karte 2'),
             (Belegt: False; VGAdr: 03; CardID: $23;
                              Text: 'frei'));

  Slot_HeadLine =
      '                 v--- IST ---v   v----SOLL-----------v                          '  +
      ' [Hex] ->        VG---ID--Card   Card-ID  Beschreibung                  ';

  S_ISTVgID      = 20;               {Spalten Positionen}
  S_ISTCrdID     = S_ISTVgID   + 7;
  S_SOLLCrdId    = S_ISTCrdID  + 8;
  S_Beschreib    = S_SOLLCrdId + 8;

 var
  MilErr     : TMilErr;


 procedure Displ_Slot (SDisp: TSlotDisp); {Soll-Ist Anzeige}
  var
   I         : Byte;
   IfkAdresse: Word;
   IfkRetAdr : Byte;
   SL        : TSlots;
   Slot_Data : Word;
   Mod_Adr   : TModAdr;
   OnlineErr : TOnlineErr;

  begin
   SL := SDisp.SlotAry;          {Slot-Array zuordnen}
   TextColor(Blue);
   GotoXY(02, SDisp.Z_Basis);
   Write(SDisp.IfkText);

   IfkAdresse := SDisp.IfkNr;
   Mil.Ifc_Online (IfkAdresse, IfkRetAdr,  OnlineErr);
   GotoXY(S_ISTCrdID-4, SDisp.Z_Basis);
   if OnlineErr = NoErr then
     Write (Hex_Byte(IfkAdresse))
   else
     Write ('Offline!');

   GotoXY(S_SOLLCrdId , SDisp.Z_Basis);
   Write (Hex_Byte(SDisp.IfkNr)); TextColor(Brown);

   TextColor(Black);
   for I:= 1 to SDisp.SlotMax do
    begin
      TextColor(Brown);
      GotoXY(02,          SDisp.Z_Basis+I);  Write('Platz ',I:2); TextColor(Black);
      GotoXY(S_ISTVgID ,  SDisp.Z_Basis+I);  Write('            ');

      Mod_Adr.AdrIfc := SDisp.IfkNr;
      Mod_Adr.AdrCard:= I;
      Mod_Adr.AdrSub := ModSub_Adr_ID; {Hi: Card-ID(LP), Lo: VG-ID =SlotID (VG)}
      Mod_Adr.AdrMode:= AdrNew;
      Mil.Rd_ModBus (Slot_Data, Mod_Adr, MilErr);   {Lese Maskenregister}
      if MilErr = No_Err then
       begin
        GotoXY(S_ISTVgID , SDisp.Z_Basis+I);  Write(Hex_Byte(Lo(Slot_Data)));
        GotoXY(S_ISTCrdID, SDisp.Z_Basis+I);  Write(Hex_Byte(Hi(Slot_Data)));
       end
      else
       begin
        TextColor(Red);
        GotoXY(S_ISTVgID , SDisp.Z_Basis+I);  Write('Read Error!');
        TextColor(Black);
       end;

      if SL[I].Belegt then
       begin
        GotoXY(S_SOLLCrdId, SDisp.Z_Basis+I);
        Write(Hex_Byte(SL[I].CardID));
        GotoXY(S_Beschreib, SDisp.Z_Basis+I);  Write(SL[I].Text);
       end
      else
       begin
        GotoXY(S_Beschreib, SDisp.Z_Basis+I); Write ('frei');
       end;
    end;
 end; {Displ_Slot_Belegung}


 procedure Show_Slot_Hardware;
  const Z_Uni = 4;
        Z_Sis = Z_Uni + Slot_Max_Uni + 2;
  var
   S    : TSlotDisp;
   X    : Byte;
   Slot : TSlots;

  begin
   Ini_Text_Win;
   TextColor(Brown);
   Write (Slot_HeadLine);

   for X := 1 to Slot_Max_Uni do   {Unilac Array kopieren}
    begin
     Slot[X].Belegt := Slot_Uni[X].Belegt;
     Slot[X].VGAdr  := Slot_Uni[X].VGAdr;
     Slot[X].CardID := Slot_Uni[X].CardID;
     Slot[X].Text   := Slot_Uni[X].Text;
    end;

   S.IfkNr    := Ifk_PZ_Uni;        {Unilac-Teil der PZ anzeigen}
   S.IfkText  := 'IFK-UNI [H]-> ';
   S.Z_Basis  := Z_Uni;
   S.SlotAry  := Slot;              {Array mit Soll-Belegung}
   S.SlotMax  := Slot_Max_Uni;
   Displ_Slot (S);                  {Allgemeine Anzeige aufrufen}

   for X := 1 to Slot_Max_Sis do
    begin
     Slot[X].Belegt := Slot_Sis[X].Belegt; {SIS Array kopieren}
     Slot[X].VGAdr  := Slot_Sis[X].VGAdr;
     Slot[X].CardID := Slot_Sis[X].CardID;
     Slot[X].Text   := Slot_Sis[X].Text;
    end;

   S.IfkNr      := Ifk_PZ_Sis;  {SIS-Teil der PZ anzeigen}
   S.IfkText    := 'IFK-SIS [H]-> ';
   S.Z_Basis    := Z_Sis;
   S.SlotAry    := Slot;        {Array mit Soll-Belegung}
   S.SlotMax    := Slot_Max_Sis;
   Displ_Slot (S);
   repeat until Keypressed;
 end; {Show_Slot_Hardware}

 procedure Event12_Gen;
  begin

  end; {Event12_Gen}

 procedure Uni_Sis_Trans;
  begin

  end; {Uni_Sis_Trans}


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
                       Show_Slot_Hardware;
                     end;
          'n', 'N' : begin
                       Event12_Gen;
                     end;
          'o', 'O' : begin
                       Uni_Sis_Trans;
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

