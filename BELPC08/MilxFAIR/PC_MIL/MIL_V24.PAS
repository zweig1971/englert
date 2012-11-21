PROGRAM Mil_V24;
{ Autor des Basis-Programmes Mil_Base.PAS: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS

  énderungs-Protokoll:
  10.07.97  Et        V24-Piggy FG402.000

}
{$S-}
uses Crt, WinDos, Dos, Datech, Datech_1;    {spez. MIL-Routinen in Units Datech..}

const
 Head_Line =
      'BELAB                                MIL_V24    ' +
      '                    [15.07.1997]' +
      '                             Test V24-Piggy FG402.000                          ';

 procedure menue_win;
  var answer: CHAR;
 begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;            {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}
  TextColor(Blue);

   {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}
  GotoXY(5, 14);
  Writeln('       [M]<-- Terminal-Funktion Åber V24-Piggy                ');
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

{
Bisherige Routinen f. alle Anwender gleich! Ab hier spezielle User-Routinen
}

procedure V24_Terminal;
 label 99;
 const Rcv_Fifo_Empty_Bitnr = 11;
 var
  MilErr : TMilErr;
  Fct    : TFct;
  Wr_Data: Word;
  Rd_Data: Word;
  Rd_Zeichen : Char;


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
    Ini_Text_Win;
    Fct.B.Adr := Ifc_Test_Nr;
    Cursor(False);
    Ini_Msg_Win;
    Write ('Keyboard-Eingabe ('); TextColor(Black); Write('sw'); TextColor(Yellow);
    Write(')'); Write(' -> V24;  V24-Input -> Display ('); TextColor (Red);
    Write ('rot'); TextColor(Yellow); Write (')      Abort Esc-Taste!');
    Set_Text_Win;

    repeat
     if KeyEPressed then
      begin
       Ch := NewReadKey;
       if Ch = #0 then                        {Sonder-Tasten Abfrage}
        begin
         Ch := NewReadKey;
        end;

       Write (Ch);                            {Zeichen zum PC-Display}
       Wr_Data := ord (Ch);
       Fct.B.Fct := Fct_Wr_Sw1;
       Mil.Wr (Wr_Data, Fct, MilErr);         {Zeichen zum Milbus}
       if Ch = #13 then
        begin
         Writeln;                             {neue Zeile auf PC-Display}
         Wr_Data := 10;                       {Linefeed zum Milbus}
         Mil.Wr (Wr_Data, Fct, MilErr);
        end;
      end; {if keypressed}

     while Mil_RcvChar (Rd_Zeichen) do                     {Lese Daten aus Fifo bis empty}
      begin
        TextColor(Red);
        Write (Rd_Zeichen);                      {Read-Zeichen auf Bildschirm}
        TextColor(Black);
        if Rd_Zeichen = #13 then Writeln;
      end;
    until Ch = #27;
    Ch := '?';       {Wichtig: ESC-Zeichen lîschen!}
 99:  Cursor(True);
 end; {V24-Echo }


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
                       if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
                       V24_Terminal;
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


  Dual[1].Adr := 0;        {Init Dual-Mode Array}
  Dual[1].Fct := 0;
  Dual[1].Dta_ok := False;
  Dual[1].Dta := 0;
  Dual[2].Adr := 0;
  Dual[2].Fct := 0;
  Dual[2].Dta_ok := False;
  Dual[2].Dta := 0;
