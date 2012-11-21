program IOB_TEST;                  {Programm IOB_TEST.PAS mit Unit DATECH.PAS}
{ Autor: Gerhard Englert                              Turbo-Pascal Version 7.0
  ***************** Testprogramm fÅr APL-MIL IO-Bus *************************
  09.02.94       Erstellung
  19.04.94       Anzeige de Fct-Codes bei IOB-Tests
  17.08.94       Test 6: Out->IN: eine Subadr schreiben, alle lesen und
                 ÅberprÅfen : Iob_Dual_Wr_Rd
  23.02.00       wegen MIL-Timeout neu compiliert
}
{$S-}
uses Crt, WinDos, Datech, Datech_0, Datech_1;

const
 Head_Line =
      'Datentechnik                        MIL_IOB  ' +
      '                       [23.02.2000]'+
      '                       APL I/O-BUS     [IFC-Karte FG 380.122]        ';

type
 Str4    = string[4];
 Str8    = string[8];
 Num_Str = string[10];


var
 Mil        : T_Mil;               {Type OBJECT: in Unit Datech.Pas definiert}
 ifb_online : ARRAY[1..255] OF BOOLEAN;

 Ifc_Test_Nr: Byte;
 Iob_Card_Nr: Byte;

 Iob_Card_Stat   : Byte;   {FÅr Automatischen Test mit FG 385.030}
 Iob_Card_Cmd    : Byte;   {FÅr Automatischen Test mit FG 385.030}

 Loop       : Boolean;
 User_Input : Char;
 Ch         : Char;
 I,N        : Byte;

 Transf_Cnt: LongInt;
 Error_Cnt : LongInt;
 Timout_Cnt: LongInt;
 Timout_Rd : LongInt;
 Timout_Wr : LongInt;

FUNCTION menue_win: CHAR;
VAR answer: CHAR;
begin
  Ini_Headl_Win;
  Write(head_line);
  Ini_Text_Win;
  GotoXY(12, 03);
  Writeln('**********************  TEST-MENUE  ************************ ');
  GotoXY(12, 05);
  Writeln('[0]<-- Welche IFC am MIL-Bus?      Welche IFC testen? -->[A]');
  GotoXY(12, 06);
  Writeln('[1]<--                             Welche IOBasis-Adr -->[B]');
  GotoXY(12, 07);
  Writeln('[2]<-- 1_SubAdr    Read Daten v.  I/O-Bus    8_SubAdr -->[C]');
  GotoXY(12, 08);
  Writeln('[3]<-- 1_SubAdr    Write Daten z. I/O-Bus    8_SubAdr -->[D]');
  GotoXY(12, 09);
  Writeln('[4]<-- 1_SubAdr      Wr/Rd (Daten=0..FF)     8_SubAdr -->[E]');
  GotoXY(12, 10);
  Writeln('[5]<-- 1_SubAdr     Wr/Rd (Daten=0..FFFF)    8_SubAdr -->[F]');
  GotoXY(12, 11);
  Writeln('[6]<-- 1_SubAdr Dual FG385.030 OUT->IN-Test  8_SubAdr -->[G]');
{
  GotoXY(12, 11);
  Writeln('[6]<--                                                -->[G]');
  GotoXY(12, 12);
  Writeln('[7]<--                                                -->[H]');
}
  GotoXY(12, 14);
  Writeln('         [K]<--  Anzeigen MIL- u. I/O-Bus-Adressen          ');
  GotoXY(12, 15);
  Writeln('         [L]<--  Reset MIL-IFC + I/O-Bus (Fctcode 01)       ');
{ GotoXY(12, 16);
  Writeln('         [M]<--                                             ');
}
  Ini_Msg_Win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
  Answer := Readkey;
  if answer in ['0'..'9','A'..'N','a'..'n','x','X'] then
   menue_win := answer;
 end; {menue_win}


procedure Mil_Ask_Ifc;
 var Status: Boolean;
 begin
   Status := False;
   while not Status do
    begin
     Ini_Text_Win;
     GotoXY(1, 22);
     Write ('Welche IFC-Karten-Adr (FG 380.122) testen? (01..FF) [Hex]: ');
     Ifc_Test_Nr := Ask_Hex_Byte;
     if Ifc_Test_Nr in [1..255] then Status := True;
    end; {while}
end; {Ask_Ifc}

procedure Mil_Ask_IoAdr;
 var Status: Boolean;
 begin
   Status := False;
   while not Status do
    begin
     Ini_Text_Win;
     GotoXY(1, 22);
     Write ('Basis-Adr fÅr allgem. I/O-Bus Testkarte? (00, 08, 10H, 18H .. F8) [Hex]: ');
     Iob_Card_Nr := Ask_Hex_Byte;
     if (Iob_Card_Nr in [00..$F8]) and (Iob_Card_Nr mod 8 = 0) then
       Status := True
     else
      begin
       Ini_Err_Win;
       Write('Error: Diese I/O-Bus Karten-Adr ist nicht erlaubt! Weiter beliebige Taste.');
       repeat until KeyPressed;
      end;
    end; {while}
 end; {Ask_IoAdr}


function Iob_Ask_SubAdr(IobCard: Byte): Byte;
 var Status: Boolean;
     SubAdr: Byte;
 begin
   Status := False;
   while not Status do
    begin
     Ini_Msg_Win;
     Write ('Welche Subadresse von IOB-Karte [',Hex_Byte(IobCard),'H] testen? (0..7): ');
     {$I-}                            {Compiler Check aus, Error selber abfangen}
     readln(SubAdr);
     {$I+}
     if IoResult = 0 then                             {PrÅfe, ob Nr ok}
      begin
       Iob_Ask_SubAdr:= SubAdr;
       if (SubAdr in [0..7]) then Status := True
       else
        begin
         Ini_Err_Win;
         Write('Error: Diese Subadresse ist nicht erlaubt! Weiter beliebige Taste.');
         repeat until KeyPressed;
        end;
      end
     else
      begin
       Ini_Err_Win;
       Write('Error: Keine gÅltige Zahleneingabe! Weiter beliebige Taste.');
       repeat until KeyPressed;
      end;   {if IoResult}
    end; {while}
 end; {Iob_Ask_Subadr}

procedure Iob_Ask_Dual_Adr;
 var Status: Boolean;
 begin
   Status := False;
   while not Status do
    begin
     Ini_Text_Win;
     GotoXY(1, 22);
     Write ('Welche I/O-Bus Basis-Adr fÅr Write? (00, 08, 10H, 18H .. F8) [Hex]: ');
     Iob_Card_Cmd := Ask_Hex_Byte;
     if ((Iob_Card_Cmd in [00..$F8]) and (Iob_Card_Cmd mod 8 = 0)) and (Iob_Card_Cmd <> Iob_Card_Stat) then
       Status := True
     else
      begin
       Ini_Err_Win;
       if Iob_Card_Cmd = Iob_Card_Stat then
         Write('Error: Wr-Adr = Rd-Adr!   Nicht erlaubt! Weiter beliebige Taste.')
       else
         Write('Error: Diese I/O-Bus Karten-Adr ist nicht erlaubt! Weiter beliebige Taste.');
       repeat until KeyPressed;
      end;
    end; {while}

   Status := False;
   while not Status do
    begin
     Ini_Text_Win;
     GotoXY(1, 22);
     Write ('Welche I/O-Bus Basis-Adr fÅr Read? (00, 08, 10H, 18H .. F8) [Hex]: ');
     Iob_Card_Stat := Ask_Hex_Byte;
     if (Iob_Card_Stat in [00..$F8]) and (Iob_Card_Stat mod 8 = 0) then
       Status := True
     else
      begin
       Ini_Err_Win;
       Write('Error: Diese I/O-Bus Karten-Adr ist nicht erlaubt! Weiter beliebige Taste.');
       repeat until KeyPressed;
      end;
    end; {while}
 end; {Ask_Dual}

function Check_Ifc_Adr: Boolean;
 begin
   Check_Ifc_Adr := True;
   if not (Ifc_Test_Nr in [1..255]) then
    begin
     Check_Ifc_Adr := False;
     Ini_Err_Win;
     Write ('ABORT: IFC-Karten-Nr. undefiniert!!  Weiter mit beliebiger Taste.');
     Ch := ReadKey;
    end;
 end; {check_ifc_adr}

procedure Mil_Ifc_Reset;
 var IobErr : TMilErr;
      Fct    : TFct;
 begin
   Fct.B.Adr := Ifc_Test_Nr;
   Fct.B.Fct := Fct_Reset ;
   Ini_Err_Win;
   Write('Achtung: Wirklich alles rÅcksetzen? [J/N]: ');
   Ch := ReadKey;
   if Ch in ['J','j'] then
    begin
     Mil.WrFct (Fct, IobErr);
     if IobErr = No_Err then
      begin
       Ini_Msg_Win;
       Write('Reset IFC ausgefÅhrt. Weiter mit irgendeiner Taste!');
      end
     else
      begin
       Ini_Err_Win;
       Write('Error! Reset nicht ausgefÅhrt!. Weiter mit irgendeiner Taste!');
      end;
     repeat until KeyPressed;
    end;
 end;

procedure Show_IOB_Fct;
 begin
   GotoXY(6, 04);
   Write('Fct-Code Wr-IO-Adressbus[Hex]: '); Write(Hex_Byte(Fct_Wr_Iob_Adr));
   GotoXY(6, 05);
   Write('Fct-Code Wr-IO-Datenbus [Hex]: '); Write(Hex_Byte(Fct_Wr_Iob_Dta));
   GotoXY(6, 06);
   Write('Fct-Code Rd-IO-Datenbus [Hex]: '); Write(Hex_Byte(Fct_Rd_Iob_Dta));
 end;


procedure Iob_Wr_Multi_Data_8;
 var A,I     : Word;
     Adr     : TIoAdr;
     IobErr  : TMilErr;
     RdData  : Word;
     Mil_Timout : Boolean;
  begin
   Ini_Text_Win;
   Transf_Cnt := 0;
   Error_Cnt  := 0;
   Timout_Wr  := 0;
   Timout_Rd  := 0;

   Show_IOB_Fct;
   GotoXY(6, 11);
   writeln('Transfr_Cnt:              Write-Data[H]:                ');
   GotoXY(6, 14);
   writeln('Error_Count:              Read-Data [H]:                ');
   GotoXY(18,14); write(error_cnt:10);
   GotoXY(22,12);  writeln('^  ^');
   GotoXY(22,15);  writeln('^  ^');
   GotoXY(53,11);  write('Timeout:');
   GotoXY(53,14);  write('Timeout:');
   GotoXY(61,14);  write(timout_rd:10);
   GotoXY(61,11);  write(timout_wr:10);

   Ch := ' ';
   Adr.IfcAdr := Ifc_Test_Nr;
   Adr.IoCard := Iob_Card_Nr;

   if not loop then Adr.IoSub := Iob_Ask_SubAdr(Iob_Card_Nr);
   Ini_Msg_Win;
   Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');

   I := 0;  {Daten-ZÑhler}
   A := 0;  {Subadr. ZÑhler}
   if Loop then                                     {Alle Subadresssen}
    begin
      repeat
       repeat
         Set_Text_win;
         Mil_Timout := False;
         Transf_Cnt := Transf_Cnt+ 1;
         GotoXY(18,11);  Write(Transf_Cnt:10);
         GotoXY(47,11);  Write(Hex_Word(I));

         Adr.IoSub := A;
         GotoXY(06,09);  Writeln('Sub-Adr    :', Adr.IoSub:10);
         Mil.Wr_IoBus (I, Adr, IobErr);
         if IobErr <> No_err then
           begin
            Mil_Timout := True;
            Timout_Wr:= Timout_Wr +1;
            GotoXY(61,11);  write(timout_wr:10);
           end;

         Mil.Rd_IoBus (RdData, Adr, IobErr);
         if IobErr <> No_err then
           begin
            Mil_Timout := True;
            Timout_Wr:= Timout_Wr +1;
            GotoXY(61,11);  write(timout_wr:10);
           end
         else
          begin
            GotoXY(47,14);  Write(Hex_Word(RdData));
            if RdData <> I then
             begin
               Error_Cnt := Error_Cnt +1;
               GotoXY(18,14); write(error_cnt:10);
             end;
          end;

          A := A + 1;
          if A > 7 then
           begin
             A := 0;
             I := I + 1;
             if I > $FF then I := 0;
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
  end {if loop= yes}
 else
  begin                                      {nur eine Subadresse}
   repeat
    repeat
      Set_Text_win;
      Mil_Timout := False;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(06,09);  Writeln('Sub-Adr    :', Adr.IoSub:10);
      GotoXY(18,11);  Write(Transf_Cnt:10);
      GotoXY(47,11);  Write(Hex_Word(I));

      Mil.Wr_IoBus (I, Adr, IobErr);
      if IobErr <> No_err then
       begin
        Mil_Timout := True;
        Timout_Wr:= Timout_Wr +1;
        GotoXY(61,11);  write(timout_wr:10);
       end
      else
       begin
        Mil.Rd_IoBus (RdData, Adr, IobErr);
        if IobErr <> No_err then
          begin
           Mil_Timout := True;
           Timout_Wr:= Timout_Wr +1;
           GotoXY(61,11);  write(timout_wr:10);
          end
        else
         begin
           GotoXY(47,14);  Write(Hex_Word(RdData));
           if RdData <> I then
            begin
              Error_Cnt := Error_Cnt +1;
              GotoXY(18,14); write(error_cnt:10);
            end;
         end;
       end; {if no write-Error}
      GotoXY(61,11);  write(timout_wr:10);
      I := I + 1;
      if I = $FF then I := 0;
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
 end; {mil_wr_multi_8}

procedure Iob_Wr_Multi_Data_16;
 var A,I     : Word;
     Adr     : TIoAdr;
     IobErr  : TMilErr;
     RdData  : Word;
     Mil_Timout : Boolean;
  begin
   Ini_Text_Win;
   Transf_Cnt := 0;
   Error_Cnt  := 0;
   Timout_Wr  := 0;
   Timout_Rd  := 0;

   Show_IOB_Fct;
   GotoXY(6, 11);
   writeln('Transfr_Cnt:              Write-Data[H]:                ');
   GotoXY(6, 14);
   writeln('Error_Count:              Read-Data [H]:                ');
   GotoXY(18,14); write(error_cnt:10);
   GotoXY(22,12);  writeln('^  ^');
   GotoXY(22,15);  writeln('^  ^');
   GotoXY(53,11);  write('Timeout:');
   GotoXY(53,14);  write('Timeout:');
   GotoXY(61,14);  write(timout_rd:10);
   GotoXY(61,11);  write(timout_wr:10);

   Ch := ' ';
   Adr.IfcAdr := Ifc_Test_Nr;
   Adr.IoCard := Iob_Card_Nr;

   if not loop then Adr.IoSub := Iob_Ask_SubAdr(Iob_Card_Nr);
   Ini_Msg_Win;
   Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');

   I := 0;  {Daten-ZÑhler}
   A := 0;  {Subadr. ZÑhler}
   if Loop then                                     {Alle Subadresssen}
    begin
      repeat
       repeat
         Set_Text_win;
         Mil_Timout := False;
         Transf_Cnt := Transf_Cnt+ 1;
         GotoXY(18,11);  Write(Transf_Cnt:10);
         GotoXY(47,11);  Write(Hex_Word(I));

         Adr.IoSub := A;
         GotoXY(06,09);  Writeln('Sub-Adr    :', Adr.IoSub:10);
         Mil.Wr_IoBus (I, Adr, IobErr);
         if IobErr <> No_err then
           begin
            Mil_Timout := True;
            Timout_Wr:= Timout_Wr +1;
            GotoXY(61,11);  write(timout_wr:10);
           end;

         Mil.Rd_IoBus (RdData, Adr, IobErr);
         if IobErr <> No_err then
           begin
            Mil_Timout := True;
            Timout_Wr:= Timout_Wr +1;
            GotoXY(61,11);  write(timout_wr:10);
           end
         else
          begin
            GotoXY(47,14);  Write(Hex_Word(RdData));
            if RdData <> I then
             begin
               Error_Cnt := Error_Cnt +1;
               GotoXY(18,14); write(error_cnt:10);
             end;
          end;

          A := A + 1;
          if A > 7 then
           begin
             A := 0;
             I := I + 1;
             if I > $FFFF then I := 0;
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
  end {if loop= yes}
 else
  begin                                      {nur eine Subadresse}
   repeat
    repeat
      Set_Text_win;
      Mil_Timout := False;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(06,09);  Writeln('Sub-Adr    :', Adr.IoSub:10);
      GotoXY(18,11);  Write(Transf_Cnt:10);
      GotoXY(47,11);  Write(Hex_Word(I));

      Mil.Wr_IoBus (I, Adr, IobErr);
      if IobErr <> No_err then
       begin
        Mil_Timout := True;
        Timout_Wr:= Timout_Wr +1;
        GotoXY(61,11);  write(timout_wr:10);
       end
      else
       begin
        Mil.Rd_IoBus (RdData, Adr, IobErr);
        if IobErr <> No_err then
          begin
           Mil_Timout := True;
           Timout_Wr:= Timout_Wr +1;
           GotoXY(61,11);  write(timout_wr:10);
          end
        else
         begin
           GotoXY(47,14);  Write(Hex_Word(RdData));
           if RdData <> I then
            begin
              Error_Cnt := Error_Cnt +1;
              GotoXY(18,14); write(error_cnt:10);
            end;
         end;
       end; {if no write-Error}
      GotoXY(61,11);  write(timout_wr:10);
      I := I + 1;
      if I = $FFFF then I := 0;
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
 end; {mil_wr_multi_8}



procedure Iob_Wr_Single_Data;
 var A       : Word;
     Adr     : TIoAdr;
     IobErr  : TMilErr;
     RdData  : Word;
     WrData  : Word;
     Mil_Timout : Boolean;

  begin
   Ini_Text_Win;
   Ch := ' ';
   Transf_Cnt := 0;
   Error_Cnt  := 0;
   Timout_Wr  := 0;
   Timout_Rd  := 0;

   Adr.IfcAdr := Ifc_Test_Nr;
   Adr.IoCard := Iob_Card_Nr;
   if not loop then Adr.IoSub := Iob_Ask_SubAdr(Iob_Card_Nr);

   Ini_Text_Win;
   GotoXY(1, 22);
   Write ('Welche Daten zur IO-Bus-Karte schreiben? ');
   WrData := Ask_Hex_Byte;

   Ini_Text_Win;
   Show_IOB_Fct;
   GotoXY(6, 11);
   writeln('Transfr_Cnt:              Write-Data[H]:                ');
   GotoXY(22,12);  writeln('^  ^');

   GotoXY(53,11);  write('Timeout:');
   GotoXY(61,11);  write(timout_wr:10);
   GotoXY(47,11);  Write(Hex_Byte(WrData));
   Ini_Msg_Win;
   Write('Stop/Single Step mit <SPACE>, Neue Daten <D>, Loop mit <CR> ,  Ende mit [X]');

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
         GotoXY(06,09);  Writeln('Sub-Adr    :', Adr.IoSub:10);
         GotoXY(47,11);  Write(Hex_Byte(WrData));

         Mil.Wr_IoBus (WrData, Adr, IobErr);
         if IobErr <> No_err then
           begin
            Mil_Timout := True;
            Timout_Wr:= Timout_Wr +1;
            GotoXY(61,11);  write(timout_wr:10);
           end;
          A := A + 1;
          if A > 7 then A := 0;
          GotoXY(61,11);  write(timout_wr:10);
       until KeyPressed or (Ch = ' ');
       if Ch = ' ' then
         begin
          Ini_Msg_Win;
          Write('Stop/Single Step mit <SPACE>, Neue Daten <D>, Loop mit <CR> ,  Ende mit [X]');
          repeat until KeyPressed;
         end;
       Ch := ReadKey;
       if Ch in ['d','D'] then
         begin
          Set_Text_Win;
          GotoXY(01,22);  Write('Bitte neue Write-Daten eingeben!');
          WrData := Ask_Hex_Byte;
          Set_Text_Win;
          GotoXY(01,22);  ClrEol;
          Ini_Msg_Win;
          Write('Stop/Single Step mit <SPACE>, Neue Daten <D>, Loop mit <CR> ,  Ende mit [X]');
          Set_Text_Win;
          Ch := ' ';
         end;
         until Ch in ['x','X'];
   end {if loop= yes}
 else
  begin                                      {nur eine Subadresse}
   repeat
    repeat
      Set_Text_win;
      Mil_Timout := False;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(06,09);  Writeln('Sub-Adr    :', Adr.IoSub:10);
      GotoXY(18,11);  Write(Transf_Cnt:10);
      GotoXY(47,11);  Write(Hex_Byte(WrData));

      Mil.Wr_IoBus (WrData, Adr, IobErr);
      if IobErr <> No_err then
       begin
        Mil_Timout := True;
        Timout_Wr:= Timout_Wr +1;
        GotoXY(61,11);  write(timout_wr:10);
       end;
      GotoXY(61,11);  write(timout_wr:10);
    until KeyPressed or (Ch = ' ');
    if Ch = ' ' then
      begin
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Neue Daten <D>, Loop mit <CR> ,  Ende mit [X]');
       repeat until KeyPressed;
      end;
    Ch := ReadKey;
    if Ch in ['d','D'] then
      begin
       Set_Text_Win;
       GotoXY(01,22);  Write('Bitte neue Write-Daten eingeben!');
       WrData := Ask_Hex_Byte;
       Set_Text_Win;
       GotoXY(01,22);  ClrEol;
       Ini_Msg_Win;
       Write('Stop/Single Step mit <SPACE>, Neue Daten <D>, Loop mit <CR> ,  Ende mit [X]');
       Set_Text_Win;
       Ch := ' ';
      end;
   until Ch in ['x','X'];
  end; {if loop = no}
 end; {mil_wr_single Data}

procedure Iob_Rd_Single_Data;
 var A       : Word;
     Adr     : TIoAdr;
     IobErr  : TMilErr;
     RdData  : Word;
     WrData  : Word;
     RdByte  : Byte;
     Mil_Timout : Boolean;

  begin
   Ini_Text_Win;
   Ch := ' ';
   Transf_Cnt := 0;
   Error_Cnt  := 0;
   Timout_Wr  := 0;
   Timout_Rd  := 0;

   Adr.IfcAdr := Ifc_Test_Nr;
   Adr.IoCard := Iob_Card_Nr;
   if not loop then Adr.IoSub := Iob_Ask_SubAdr(Iob_Card_Nr);

   Ini_Text_Win;
   Show_IOB_Fct;
   GotoXY(6, 11);
   writeln('Transfr_Cnt:              Read-Data [H]:                ');
   GotoXY(22,12);  writeln('^  ^');

   GotoXY(53,11);  write('Timeout:');
   GotoXY(61,11);  write(timout_wr:10);
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
         GotoXY(06,09);  Writeln('Sub-Adr    :', Adr.IoSub:10);

         Mil.Rd_IoBus (RdData, Adr, IobErr);
         if IobErr <> No_err then
           begin
            Mil_Timout := True;
            Timout_Wr:= Timout_Wr +1;
            GotoXY(61,11);  write(timout_wr:10);
           end
         else
          begin
            RdByte := RdData and $00FF;                    {Nur Low-Byte}
            GotoXY(47,11);  Write(Hex_Byte(RdByte));
          end;

          A := A + 1;
          if A > 7 then A := 0;
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
  end {if loop= yes}
 else
  begin                                      {nur eine Subadresse}
   repeat
    repeat
      Set_Text_win;
      Mil_Timout := False;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(06,09);  Writeln('Sub-Adr    :', Adr.IoSub:10);
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
         RdByte := RdData and $00FF;                    {Nur Low-Byte}
         GotoXY(47,11);  Write(Hex_Byte(RdByte));
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
 end; {mil_rd_single Data}

procedure Iob_Dual_Wr_Rd;
 label 1;
 const sub_adr_max = 4;
 var A,I,S    : Word;
     IobErr  : TMilErr;
     RdData  : Word;
     RdByte  : Byte;
     Mil_Timout : Boolean;

     Adr_Stat,Adr_Cmd: TIoAdr;
     Adr_Tst         : TIoAdr;
     Iob_Card_Sub    : Byte;

  begin
   Ini_Text_Win;
   Transf_Cnt := 0;
   Error_Cnt  := 0;
   Timout_Wr  := 0;
   Timout_Rd  := 0;

   if (Iob_Card_Stat=0)  or (Iob_Card_Cmd=0) then
      Iob_Ask_Dual_Adr                        {Bei Null auf jeden Fall fragen}
   else
     begin
       Ini_Text_Win;
       GotoXY(06,07);  Writeln('Wr-Basis-Adr [Hex]: ', Hex_Byte(Iob_Card_Cmd));
       GotoXY(06,08);  Writeln('Rd-Basis-Adr [Hex]: ', Hex_Byte(Iob_Card_Stat));
       Ini_Msg_Win;
       Write('Sollen die IOB-Basis-Adresssen geÑndert werden? [J/N]:  ');
       Ch := ReadKey;
       if Ch in ['J','j'] then Iob_Ask_Dual_Adr;
     end;

   Ini_Text_Win;
   GotoXY(06,07);  Writeln('Wr-Basis-Adr [Hex]: ', Hex_Byte(Iob_Card_Cmd));
   GotoXY(06,08);  Writeln('Rd-Basis-Adr [Hex]: ', Hex_Byte(Iob_Card_Stat));

   GotoXY(6, 11);
   writeln('Transfr_Cnt:              Write-Data[H]:                ');
   GotoXY(6, 14);
   writeln('Error_Count:              Read-Data [H]:                ');
   GotoXY(18,14); write(error_cnt:10);
   GotoXY(22,12);  writeln('^  ^');
   GotoXY(22,15);  writeln('^  ^');
   GotoXY(53,11);  write('Timeout:');
   GotoXY(53,14);  write('Timeout:');
   GotoXY(61,14);  write(timout_rd:10);
   GotoXY(61,11);  write(timout_wr:10);

   Ch := ' ';
   Adr_Stat.IfcAdr := Ifc_Test_Nr;
   Adr_Stat.IoCard := Iob_Card_Stat;
   Adr_Cmd.IfcAdr  := Ifc_Test_Nr;
   Adr_Cmd.IoCard  := Iob_Card_Cmd;

   Adr_Tst.IfcAdr  := Ifc_Test_Nr;
   Adr_Tst.IoCard  := Iob_Card_Cmd;

   if not loop then
    begin
     Iob_Card_Sub := Iob_Ask_SubAdr(Iob_Card_Cmd);
     Adr_Stat.IoSub := Iob_Card_Sub;
     Adr_Cmd.IoSub  := Iob_Card_Sub;
    end;

   Ini_Msg_Win;
   Write('Single Step mit <SPACE>, Loop mit <CR> , Ende mit [X]');
{xxx}
   I := 0;  {Daten-ZÑhler}
   A := 0;  {Subadr. ZÑhler}
   if Loop then                                     {Alle Subadresssen}
    begin
      repeat
       repeat
         Set_Text_win;
         Mil_Timout := False;
         Transf_Cnt := Transf_Cnt+ 1;
         GotoXY(18,11);  Write(Transf_Cnt:10);
         GotoXY(47,11);  Write(Hex_Byte(I));
         Adr_Stat.IoSub := A;
         Adr_Cmd.IoSub  := A;
         GotoXY(06,09);  Writeln('Sub-Adr           : ', Adr_Cmd.IoSub:2);

         Mil.Wr_IoBus (I, Adr_Cmd, IobErr);
         if IobErr <> No_err then
           begin
            Mil_Timout := True;
            Timout_Wr  := Timout_Wr +1;
            GotoXY(61,11);  write(timout_wr:10);
           end
         else
           begin
             Mil.Rd_IoBus (RdData, Adr_Stat, IobErr);
             if IobErr <> No_err then
              begin
               Mil_Timout := True;
               Timout_Rd  := Timout_Rd +1;
               GotoXY(61,11);  write(timout_rd:10);
              end
             else
              begin
               RdByte := RdData and $00FF;                    {Nur Low-Byte}
               RdByte := not (RdByte);
               GotoXY(47,14);  Write(Hex_Byte(RdByte));
               if RdByte <> I then
                 begin
                   Error_Cnt := Error_Cnt +1;
                   GotoXY(18,14); write(error_cnt:10);
                 end;
              end;
               end; {if no wr err}

          A := A + 1;
          if A > sub_adr_max then
           begin
             A := 0;
             I := I + 1;
             if I > $FF then I := 0;
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
  end {if loop= yes}
 else
  begin                                      {nur eine Subadresse}
   repeat
    repeat
      Set_Text_win;
      Mil_Timout := False;
      Transf_Cnt := Transf_Cnt+ 1;
      GotoXY(06,09);  Writeln('Sub-Adr           : ', Adr_Cmd.IoSub:2);
      GotoXY(18,11);  Write(Transf_Cnt:10);
      GotoXY(47,11);  Write(Hex_Byte(I));

             {Null auf alle Subadr schreiben}
      for S := 0 to Sub_Adr_Max do
       begin
        Adr_Tst.IoSub  := S;
        Mil.Wr_IoBus (0, Adr_Tst, IobErr);
       end;

      Mil.Wr_IoBus (I, Adr_Cmd, IobErr);
      if IobErr <> No_err then
       begin
        Mil_Timout := True;
        Timout_Wr:= Timout_Wr +1;
        GotoXY(61,11);  write(timout_wr:10);
       end
      else
       begin
        Mil.Rd_IoBus (RdData, Adr_Stat, IobErr);
        if IobErr <> No_err then
          begin
           Mil_Timout := True;
           Timout_Rd:= Timout_Rd +1;
           GotoXY(61,14);  write(timout_rd:10);
          end
        else
         begin
           RdByte := RdData and $00FF;                    {Nur Low-Byte}
           RdByte := not (RdByte);
           GotoXY(47,14);  Write(Hex_Byte(RdByte));
           if RdByte <> I then
            begin
              Error_Cnt := Error_Cnt +1;
              GotoXY(18,14); write(error_cnt:10);
            end;
         end;

       {öberprÅfe, ob Daten alle anderen CMD-Subadresssen noch NUll sind!!}
        for S := 0 to Sub_Adr_Max do
         begin
          if Adr_Cmd.IoSub  <> S then
           begin
            Adr_Tst.IoSub  := S;
            Mil.Rd_IoBus (RdData, Adr_Tst, IobErr);
            if RdData <> 0 then
             begin
              Error_Cnt := Error_Cnt +1;
              GotoXY(18,14); write(error_cnt:10);

              Ini_Err_Win;
              Write('ERROR: OUT-Subadr. ',S:2,' wird Åberschrieben! Ende mit beliebiger Taste');
              repeat until KeyPressed;
              goto 1;
             end;
           end;
         end;

       end; {if no write-Error}
      I := I + 1;
      if I = $FF then I := 0;
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
1:
 end; {mil_dual_wr_rd}

procedure  Disp_Adr;
 begin
  Ini_Text_Win;
  GotoXY(10,5);
  Writeln ('Aktuelle MIL- und I/O-Bus-Adressen : ');
  Writeln;
  Writeln (' MIL-IFC-Adr (FG 380.122) I/O-Bus-Drv [H]: ', Hex_Byte(Ifc_Test_Nr));
  Writeln (' I/O-Bus-Adr  Allgemeine Testadresse  [H]: ', Hex_Byte(Iob_Card_Nr));
  Write   (' I/O-Bus-Adr (FG 385.030) Read        [H]: ', Hex_Byte(Iob_Card_Stat)); Writeln (' [Gilt nur f. Wr -> Rd Test!]');
  Write   (' I/O-Bus-Adr (FG 385.030) Write       [H]: ', Hex_Byte(Iob_Card_Cmd));  Writeln (' [Gilt nur f. Wr -> Rd Test!]');

  Ini_Msg_Win;
  Write('Weiter mit beliebiger Taste! ');
  Ch := ReadKey;
 end;



BEGIN                        { Hauptprogramm }
  Ifc_Test_Nr  := 0;
  Iob_Card_Nr  := 0;
  Iob_Card_Stat:= 0;
  Iob_Card_Cmd := 0;

  REPEAT
    user_input := menue_win;
    loop := TRUE;
    IF user_input IN ['0'..'9'] THEN loop := FALSE;
    CASE user_input OF
     '0'      :      begin
                      Mil_Detect_Ifc;
                     end;
     'a', 'A' :      begin
                      Mil_Ask_Ifc;
                     end;
     '1'      :      Begin
                     End;
     'b', 'B' :      begin
                      Mil_Ask_IoAdr;
                     end;
     '2', 'c', 'C' : Begin
                      if Check_Ifc_Adr then Iob_Rd_Single_Data;
                     End;
     '3', 'd', 'D' : Begin
                      if Check_Ifc_Adr then Iob_Wr_Single_Data;
                     End;
     '4', 'e', 'E' : begin
                      if Check_Ifc_Adr then Iob_Wr_Multi_Data_8;
		     end;
     '5', 'f', 'F' : Begin
                      if Check_Ifc_Adr then Iob_Wr_Multi_Data_16;
 		     End;
     '6', 'g', 'G' : Begin
                      if Check_Ifc_Adr then Iob_Dual_Wr_Rd;
		     End;
    '7', 'h', 'H' : Begin
                      ;
		     End;
     '8', 'i', 'I' : begin
		     end;
          'k', 'K' : begin
                      Disp_Adr;
                     end;
          'l', 'L' : Begin
                      Ini_Text_Win;
                      if Check_Ifc_Adr then Mil_Ifc_Reset;;
                     End;
          'm', 'M' : begin
                     end;
          'n', 'N' : Begin
                     End;
    End; {CASE}
  UNTIL (user_input = 'x') OR (user_input = 'X');
END. {mil_ship}


