PROGRAM Mil_Ifk;
{ Autor des Basis-Programmes Mil_Base.PAS: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS

  énderungs-Protokoll:
  15.04.99    Et      Auf der Basis MILxBase Testprogramm fÅr Interface-Karten


}
{$S-}
uses Crt, WinDos, Dos, Datech, Datech_0, Datech_1;    {spez. MIL-Routinen in Units Datech..}

const
 Head_Line =
      'BELAB                                MIL_IFK    ' +
      '                    [15.04.1999]' +
      '                        Testprogramm fÅr FG 380.21x                            ';

 procedure menue_win;
  var answer: CHAR;
 begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;            {Festliegender Teil des MenÅs: s. a. DATECH_0.PAS}
  TextColor(Blue);

   {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}

  GotoXY(5, 14);
  Writeln('       [M]<-- Fct-Decoder RAM [IFK vorher in Mode=Modbus schalten!!]     ');
{
  GotoXY(5, 15);
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


 PROCEDURE Mil_FctCode_RAM;
  Label 99;
  const
   Z_StatCount = 8;
   Z_StatHex   = Z_StatCount +3;
   Z_StatBin   = Z_StatHex   +1;


  VAR Read_Data,fct_code : WORD;
      MilErr : TMilErr;
      Fct    : TFct;
      transf_cnt : LongInt;
      timout_cnt : LongInt;
      Ch : Char;
      Adress    : Word;

   PROCEDURE Wr_FctCode_RAM;
    var Bit16_Strg: Str19;
    Begin
     Fct.B.Adr := Ifc_Test_Nr;
     Fct.B.Fct := $62;              {Wr RAM Adr}
     Mil.Wr ($00A0, Fct, MilErr);   {Adr A0 als Fct-Code}

     Fct.B.Fct := $63;              {Wr RAM Data: Hi Modul-Adr + Lo Subadr}
{     Mil.Wr ($1FFE, Fct, MilErr); }  {Modul-Adr 1F}
     Mil.Wr ($1FA5, Fct, MilErr);   {Modul-Adr 1F}

{     Fct.B.Fct := $A0;  }            {Rd Modul Subadr. mit Fct-Code A0}
     Fct.B.Fct  := $97;               {lese RAM zurÅck}
     Mil.Rd (Read_Data, Fct, MilErr);
     if MilErr  <> No_Err then
      begin
       GotoXY(28, Z_StatHex); write ('    ');
       GotoXY(22, Z_StatBin); Textcolor(Red);
       Write('   Read Error!!    ');
      end
     else
      begin
       GotoXY(28, Z_StatHex);  write(hex_word(read_data));
       Hex_Bin_Str (read_data,bit16_strg);
       GotoXY(22, Z_StatBin);  write(bit16_strg);
      end;
     TextColor(Black);
    End;

 procedure Broad_FTast_Win;
  begin
   Set_Text_Win; TextColor(Brown);
   GotoXY(02,17); Write ('Belegung F-Tasten: ');
   Window(02, 20, 70, 24);
   TextBackground(Green); TextColor(Yellow);
   Writeln ('F1: Set   Broadcast   F5 : Reset IFK   F9 : Reset IFK ');
   Writeln ('F2: Reset Broadcast   F6 : Reset IFK   F10: Ifk-Adr   ');
   Writeln ('F3: Reset Broadcast   F7 : Reset IFK   F11: Ifk-Adr   ');
   Write   ('F4: Reset Broadcast   F8 : Reset IFK   F12: Ifk-Adr   ');
  end;

  PROCEDURE Displ_FctRam_Text;
  Begin
     {Info-Anzeige der Bit-Belegung Hochstrom-Maske}
       Window(50, 11, 80, 18);
       TextBackground(Cyan);
       TextColor(Blue);               {Setze Schriftfarbe}
       ClrScr;

      TextColor(Blue);
      writeln('Bit 15: MIL-Spg. 15V  1-aktiv ');
      writeln('Bit 14: Select Error  0-aktiv ');
      writeln('Bit 13: IRQ VG-Leiste 1-aktiv ');
      writeln('Bit 12: frei                  ');
      writeln('Bit 11: JmpSw1-Str 0=gest aktv');
      writeln('Bit 10: JmpEn-IO   0=gest aktv');
      writeln('Bit 09: Broadcast     1-aktiv ');
      writeln('Bit 08: Receive Error 1-aktiv ');
      TextColor(Black);
  End; {displ_HS_Ctrl}



  Begin
    Ini_Text_Win;
    Displ_FctRam_Text;
    Set_Text_Win;
    GotoXY(50,8); TextColor(Brown);
    Write ('Bedeutung Status-Bits: ');

    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Fct_Rd_HS_Ctrl;
    transf_cnt := 0;
    timout_cnt := 0;
    TextColor(Blue);
    GotoXY(05,01); write(' Funktionstest des Fct-Code Umsetzer-RAM: mit selbstdef. Fct-Code kann');
    GotoXY(10,02); write(' Wr/Rd auf Modulbuskarte erfolgen -> Zugriff dadurch schneller.');
    TextColor(Yellow);
    GotoXY(08,04); write('[Beachten: selbstdef. Fct-Codes unterschiedlich zu IFK-eigenen Codes]');
    TextColor(Blue);
    GotoXY(10,03); write('     Achtung: Diese Funktion nur mit den IFK-Karten FG380.21x!');
    GotoXY(25,06); write  ('Function-Word (Fct + Adr): '); TextColor(Blue);
    Write(hex_word(Fct.W)); TextColor(Brown); Write(' [H]');

    GotoXY(06,Z_StatCount  );  write('Rd_Stat_Cnt:');
    GotoXY(26,Z_StatCount+1);  write('^  ^');
    GotoXY(06,Z_StatHex);      write('Stat-Data[Hex]');
    GotoXY(06,Z_StatBin);      write('Stat-Data[Bin]');
    GotoXY(22,Z_StatBin+1);    write('MSB             LSB');

    Broad_FTast_Win;
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
       Transf_Cnt := Transf_Cnt+ 1;
       GotoXY(20, Z_StatCount); Write(transf_cnt:12);

       Wr_FctCode_RAM;
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Set_Text_win;
       Transf_Cnt := Transf_Cnt+ 1;
       GotoXY(20, Z_StatCount); Write(transf_cnt:12);
       Wr_FctCode_RAM;
      end;

     if Ch = #0 then                  {Sonder-Tasten Abfrage}
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                     Fct.B.Adr := Ifc_Test_Nr;
                     Fct.B.Fct := Fct_En_Broad;
                     Mil.WrFct (Fct, MilErr);
                   end; {F1}
        Taste_F2 : begin
                     Fct.B.Adr := Ifc_Test_Nr;
                     Fct.B.Fct := Fct_Dis_Broad;
                     Mil.WrFct (Fct, MilErr);
                   end; {F2}
        Taste_F3 : begin
                     Fct.B.Adr := Ifc_Test_Nr;
                     Fct.B.Fct := Fct_Reset;
                     Mil.WrFct (Fct, MilErr);
                   end;
        Taste_F10: begin
                     if Ask_Hex_Break (Adress, Byt) then
                      begin
                       Ifc_Test_Nr := Adress;
                       Fct.B.Adr := Ifc_Test_Nr;
                       Fct.B.Fct := Fct_Rd_HS_Ctrl;
                       Set_Text_Win; TextColor(Brown);
                       GotoXY(25,06); write  ('Function-Word (Fct + Adr): '); TextColor(Blue);
                       Write(hex_word(Fct.W)); TextColor(Brown); Write(' [H]');
                       Std_Msg;
                      end;
                   end;
       end; {case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
 end;


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
		      Mil_Ask_Ifc;
                      Mil_FctCode_RAM;
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


