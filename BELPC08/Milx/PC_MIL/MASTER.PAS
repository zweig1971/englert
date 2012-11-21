
 procedure Modul_WrRd;
   LABEL 99, Loop;
{Procedure  Mil_Wr_Rd_11 (Wr_Data: Word);  WR_Data in diesem Falle = IO-Adr}
{Wichtig: Die Reihenfolge write IO-Adr mit Fct-11, write IO-Data mit Fct-10
}
   const  Z_Start = 18;
{         Fct_Rd_Dta = $90;
          Fct_Wr_Adr = $11;
          Fct_Wr_Dta = $10;    }
 IOsub_Adr_Skal   = $FC;  {gerade   Adr: hibyte}
 IOsub_Adr_ModAdr = $FD;  {ungerade Adr: lobyte}

 IOsub_Adr_Epld   = $FA;  {gerade   Adr: hibyte}
 IOsub_Adr_Frei   = $FB;  {ungerade Adr: lobyte}



 Fct_Rd_Iob_Dta = $90;   {Lesen Daten von APL-IO-Bus bzw. Modulbus}
 Fct_Wr_Iob_Dta = $10;   {Setze Daten fÅr APL-IO-Bus bzw. Modulbus}
 Fct_Wr_Iob_Adr = $11;   {Setze Adr   fÅr APL-IO-Bus bzw. Modulbus}


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
 Fct_11_Dta: Word;
  IO_ModAdr : Byte;

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
    Fct_11_Dta := 0;             {an sich IO-Adresse}
    Fct.B.Fct  := Fct_Wr_Iob_Dta;  { Fct_Wr_Dta; }
{    Sub_Adr    := Wr_Data and $00FF;  }         {Low-Byte der Daten ist Sub_Adr}
{    Mod_Adr    := (Wr_Data and $FF00) shr 8;}   {Hi-Byte ist Mod-Adr}
    Sub_Adr    := 0;
    Mod_Adr    := 0;

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

{ procedure T_Mil.Mod_Online (Ifc_Adr: Byte; Mod_Adr: Byte; var Mod_RetAdr: Byte; var OnlineErr: TOnlineErr);}
 { TOnlineErr= (NoErr, WrTo, RdTo, AdrErr, ModAdrErr)}

{
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
}
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


  end; {Modul_WrRd}
