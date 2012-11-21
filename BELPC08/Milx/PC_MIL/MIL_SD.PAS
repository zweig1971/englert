PROGRAM Mil_SD;
{ Autor des Basis-Programmes Mil_Base.PAS: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS
  Hinweise:
  SD-LED: CM = Command Mode, verlîscht nach der Endadr.
               Leuchtet z. B. wenn nur Anfangs-Adr und keine Endadr folgt!
               Reset mit Fct-Code 01 oder Abort
  Block Rd/Wr: Anfangs- einschl. Endadr.!!
  Reset auf IFK resettet auch die SD-Elektronik!!
  Vorsicht: Beim Blockmode schreiben mÅssen Daten mit Schreib-Fct-Code
            fÅr jedes Wort geschrieben werden!!


  Autor der Erweiterungen   :  Test fÅr Strahldiagnose Dual-Ported RAM
  énderungen:
  04.08.97   Blîcke kînnen jetzt mit 2 BitMuster getestet werden
  13.08.97   Timer Test
  23.02.00   wegen MIL-Timeout neu compiliert
}
{$S-}
uses Crt, WinDos, Dos, Datech, Datech_0,Datech_1,Datech_2;    {spez. MIL-Routinen in Units Datech..}

const
 Head_Line =
      'BELAB                                MIL_SD     ' +
      '                    [23.02.2000]' +
      '                Strahldiagnose Blockmode-DPR-Test (FG 380.711)                 ';

 procedure menue_win;
  var answer: CHAR;
 begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;              {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}
  TextColor(Blue);

                  {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}
  GotoXY(5, 14);
  Writeln('       [M]<-- Piggy Status lesen                                ');
  GotoXY(5, 15);
  Writeln('       [N]<-- Timer-Test                                        ');
  GotoXY(5, 16);
  Writeln('       [O]<-- Wr-Rd DPR: BlocklÑnge = Single Word (Data=Adr)    ');
  GotoXY(5, 17);
  Writeln('       [P]<-- Wr-Rd DPR: BlocklÑnge = variabel bis 1024 (max.FIFO)');
  GotoXY(5, 18);
  Writeln('       [Q]<--                                                   ');
  GotoXY(5, 19);
  Writeln('       [R]<--                                                   ');
  GotoXY(5, 20);
  Write  ('       [S]<--                                                   ');
  GotoXY(5, 21);
  Ini_Msg_Win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
 end; {Menue_Win}

var
 MilErr      : TMilErr;
 Fct         : TFct;
 {
  Bisherige Routinen f. alle Anwender gleich! Ab hier spezielle User-Routinen
 }

 const
  Fct_SD_Abort       = $14;
  Fct_WrStart_Adr    = $15;
  Fct_WrEnd_Adr      = $16;
  Fct_RdStart_Adr    = $17;
  Fct_RdEnd_Adr      = $18;
  Fct_RdStart_AdrRom = $19;
  Fct_RdEnd_AdrRom   = $1A;
  Fct_WrRAM          = $1C;
  Fct_RdRAM          = $8F;
  Fct_RdEpld_Version = $93;

  Fct_Pgy_WrTimer    = $1B;
  Fct_Pgy_RdTimer    = $92;
  Fct_Pgy_RdEpld     = $8D;
  Fct_Pgy_RdIdent    = $8E;
  Fct_Pgy_RdStat     = $91;

  Z_Tast     = 21;
  S_Tast_Min = 40;
  S_Tast_Max = 79;


  DPR_Max        = 16383; {3FFE [Hex]: geradzahlig wegen abwechselnd Muster1 u. 2 Vergleich}
  Ary_Max        =  8192; {16382=3FFE [Hex] }
  Bit_Muster_Def = $5AA5; {festes Testmuster}
  Bit_Muster1_Def= $5AA5;
  Bit_Muster2_Def= $A55A;


 procedure Ini_Pigy_Win;
  begin
   Window(50, 08, 79, 23);
   TextBackground(Cyan);
   TextColor(Black);               {Setze Schriftfarbe}
   ClrScr;
  end;

 procedure Displ_Pigy_Stat;
  begin
     {Info-Anzeige der Bit-Belegung IFC-Status}
      Ini_Pigy_Win;
      write('Bit 15: DPR-IM-BM             ');
      write('Bit 14: DPR-Mode (CM)         ');
      write('Bit 13: OBF                   ');
      write('Bit 12: SD-IBF                ');
      write('Bit 11: -                     ');
      write('Bit 10: -                     ');
      write('Bit 09: -                     ');
      write('Bit 08: -                     ');
      write('Bit 07: 0=En.Timeout [Jumper1]');
      write('Bit 06: BM-SM-Err             ');
      write('Bit 05: RD-SM-Err             ');
      write('Bit 04: RD-Err                ');
      write('Bit 03: SD-Err                ');
      write('Bit 02: SEQ-Err_Flag          ');
      write('Bit 01: Timeout Err           ');
      write('Bit 00: DPR-Res-Flag         ');
   end; {displ_ifc_stat}

 procedure Pigy_Status;
  Label 99;
  const
   Z_Base    = 4;
   S_MaskCnt = 33;


  VAR read_data,fct_code : WORD;
      MilErr     : TMilErr;
      Fct        : TFct;
      Transf_Cnt : LongInt;
      Timout_Cnt : LongInt;
      WrMask_Cnt : LongInt;
      Rd_Stat_Cnt: LongInt;
      WrData     : Word;
      Adress     : Word;
      IdRet_Code : TIfk_IdErr;
      Adr_Error  : Boolean;
      Timeout_Evt: Word;
      Timeout_Ms : Word;
      IoRes      : Integer;
      User_Int   : LongInt;
      User_Input : Word;

{ Falls Timeout-Zeit rÅcklesbar:
  ModAdr.AdrSub  := SubAdr_12Evt_RamTimMs;
}

  PROCEDURE show_stat_reg;
   var Bit16_Strg: Str19;
       Read_Data : Word;
    begin
     Set_Text_Win;
     Rd_Stat_Cnt:= Rd_Stat_Cnt + 1;
     GotoXY(31, Z_Base+5); Write (Rd_Stat_Cnt:10);
     Fct.B.Fct  := Fct_Pgy_RdStat;
     Mil.Rd (Read_Data, Fct, MilErr);
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
    end; {show_stat_reg; }


  Begin
   Ini_Text_Win;
   Fct.B.Adr  := Ifc_Test_Nr;    {Modul-Adr definieren}
   Rd_Stat_Cnt:= 0;
   Transf_Cnt := 0;
   Timout_Cnt := 0;
   WrMask_Cnt := 0;

   TextColor(Brown);
   GotoXY(16,01); write('------ Lese Status des SD-Blockmode-Piggy  -----');
   GotoXY(50,05); write  ('Bedeutung der Status-Bits');

   GotoXY(06,Z_Base-1);  write('Ifk-Adr  [Hex]:');
   GotoXY(06,Z_Base  );  write('Pigy-Id  [Hex]:');
   GotoXY(06,Z_Base+1);  write('EPLD-Vers[Hex]:');

   GotoXY(06,Z_Base+5);  write('Stat-Rd-Count :');
   GotoXY(35,Z_Base+6);  write('^  ^');
   GotoXY(06,Z_Base+7);  write('Stat-Data[Hex]:');
   GotoXY(06,Z_Base+8);  write('Stat-Data[Bin]:');
   GotoXY(22,Z_Base+9);  write('MSB             LSB');
   TextColor(Black);
   GotoXY(23,Z_Base-1);  Write (Hex_Byte(Ifc_Test_Nr));

   GotoXY(23,Z_Base  );
   Fct.B.Fct  := Fct_Pgy_RdIdent;
   Mil.Rd (Read_Data, Fct, MilErr);
   if MilErr = No_Err then  Write (Hex_Byte(Read_Data)) else Write ('ERROR');

   GotoXY(23,Z_Base+1  );
   Fct.B.Fct  := Fct_Pgy_RdEpld;
   Mil.Rd (Read_Data, Fct, MilErr);
   if MilErr = No_Err then  Write (Hex_Byte(Read_Data)) else Write ('ERROR');

   Displ_Pigy_Stat;
   Set_Text_Win;

   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Show_Stat_Reg;
       Mil.Timer2_Wait(10000);
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Show_Stat_Reg;
       Mil.Timer2_Wait(100);
      end;

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : ;
        Taste_F2 : ;
        Taste_F9: begin
                   end; {Taste_F10}
        Taste_F10: begin
                   end; {Taste_F10}
       end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
 end; {Evt_Status}


  procedure Ini_TastMag_Win;
   begin
    Window(S_Tast_Min, Z_Tast, S_Tast_Max, Z_Tast+2);
    TextBackground(Green);
    TextColor(Black);               {Setze Schriftfarbe}
    ClrScr;
   end;

  procedure Set_TastMag_Win;
   begin
    Window(S_Tast_Min, Z_Tast, S_Tast_Max, Z_Tast+2);
    TextBackground(Green);
    TextColor(Black);               {Setze Schriftfarbe}
   end;

  procedure Set_BitMuster_Win;
   begin
    Window(02, Z_Tast, 34, Z_Tast+2);
    TextBackground(Cyan);
    TextColor(Brown);               {Setze Schriftfarbe}
   end;

  procedure Clr_BitMuster_Win;
   begin
    Window(02, Z_Tast, 34, Z_Tast+2);
    TextBackground(White);
    ClrScr;
   end;

  const
   S_Null  = 2;
   S_Block_Hex = S_Null + 17;    {14}
   S_Block_Dez = S_Null + 28;    {25}
   S_Count = S_Null + 8;
   S_Err   = S_Null + 20;
   S_Hex   = S_Null + 40;
   S_Bin   = S_Null + 55;
   S_BlkCnt= S_Null + 23;

   Z_Basis     = 4;
   Z_Block     = Z_Basis+2;
   Z_Start     = Z_Basis+3;
   Z_End       = Z_Basis+4;
   Z_Muster    = Z_Basis+5;
   Z_BlkCnt    = Z_Basis+6;
   Z_BlkCntErr = Z_Basis+7;
   Z_Text      = Z_Basis+9;
   Z_RdCount   = Z_Basis+10;

 procedure SD_DPR_Drq;
{
 Endadresse = Start_Adr + (Blockssize - 1), da auch die Start_Adr Åbertragen wird!
 Verschiedene BitMuster werden verwendet
 DREQ wird 16-bitweise dyn. von dem Blockmode-Piggy FG380.711 generiert!
 Dieses Signal wird in der PC-Mil-Karte nicht gespeichert. Falls auf dieses
 Signal getestet wird, ist das Resultat nicht eindeutig!
}
  label 99;
  const
   Ary_Max        =  1024; {max. 8192 wegen TPascal; 1024 wegen Fifo-Grenze}

   Bit_Muster_Def = $5AA5; {festes Testmuster}
   Bit_Muster1_Def= $5AA5;
   Bit_Muster2_Def= $A55A;

  type
   TDta_Ary         = array [1..Ary_Max] of Word;
   TBit_Muster_Mode = (Fix, Vari, Cnt, Ary);

  var
   Life_Mode    : TLife_XY;
   Adr_Max      : LongInt;
   Rd_Block_Size: Integer;
   Wr_Block_Size: Integer;
   Rd_Start_Adr : Integer;
   Wr_Start_Adr : Integer;
   Wr_Ary       : TDta_Ary;
   Rd_Ary       : TDta_Ary;
   I            : Integer;
   Rcv_Count    : LongInt;
   Rcv_Err_Count: LongInt;
   Block_Count  : LongInt;
   Block_ErrCnt : LongInt;
   User_Int     : Integer;
   User_Hex     : Word;
   Bit_Muster   : Word;
   Bit_Muster1  : Word;
   Bit_Muster2  : Word;
{   Bit_Muster_Var: Boolean;  }
   Bit_Muster_Mode: TBit_Muster_Mode;

  procedure Ary_Init;
   var I : Integer;
   begin
    for I := 1 to Ary_Max  do Rd_Ary[I] := I;
    for I := 1 to Ary_Max  do Wr_Ary[I] := I;
   end;

  procedure Displ_Block_Param;
   begin
    Set_Text_Win;
    TextColor(Black);
    GotoXY(S_Block_Hex,Z_Block);   Write(Hex_Word (Wr_Block_Size));
    GotoXY(S_Block_Hex,Z_Start);   Write(Hex_Word (Wr_Start_Adr));
    GotoXY(S_Block_Hex,Z_End);     Write(Hex_Word (Wr_Start_Adr+(Wr_Block_Size-1)));

    case Bit_Muster_Mode of
     Vari : begin
              GotoXY(S_Block_Hex,Z_Muster);  Write('vari');
              Set_BitMuster_Win;
              Write ('Bit-Muster wortweise wechselnd:  ');
              GotoXY(01,02);
              Write ('Muster 1 [Hex]: '); TextColor(Black); Write (Hex_Word(Bit_Muster1)); ClrEol; Writeln; TextColor(Brown);
              Write ('Muster 2 [Hex]: '); TextColor(Black); Write(Hex_Word(Bit_Muster2));  ClrEol;
              Set_Text_Win;
            end;
     Fix :  begin
              Clr_BitMuster_Win;
              Set_Text_Win;
              GotoXY(S_Block_Hex,Z_Muster);  Write(Hex_Word (Bit_Muster));
            end;
     Cnt :  begin
             Clr_BitMuster_Win;
             Set_Text_Win;
             GotoXY(S_Block_Hex,Z_Muster);  Write('Data');
            end;
     Ary :  begin
             Clr_BitMuster_Win;
             Set_Text_Win;
             GotoXY(S_Block_Hex,Z_Muster);  Write('Aray');
            end;

    end; {case}

    GotoXY(S_Block_Dez,Z_Block);   Write(Wr_Block_Size:5);
    GotoXY(S_Block_Dez,Z_Start);   Write(Wr_Start_Adr:5);
    GotoXY(S_Block_Dez,Z_End);     Write(Wr_Start_Adr+(Wr_Block_Size-1):5);

    GotoXY(S_BlkCnt,Z_BlkCnt  );    Write(Block_Count:10);
    GotoXY(S_BlkCnt,Z_BlkCntErr);   Write(Block_ErrCnt:10);
    GotoXY(S_Count, Z_RdCount);     Write(Rcv_Count:5);
    GotoXY(S_BlkCnt,Z_RdCount);     Write(Rcv_Err_Count:10);
   end;


 function WrSD_Block_Ary (Start_Adr: Integer;
                          Blck_Size: Integer): Boolean;
   var I : LongInt;
       SD_WrData : Word;
   begin
     WrSD_Block_Ary := True;
     Fct.B.Adr := Ifc_Test_Nr;
     Fct.B.Fct := Fct_WrStart_Adr;
     Mil.Wr (Start_Adr, Fct, MilErr);
     Fct.B.Fct := Fct_WrEnd_Adr;
     Mil.Wr (Start_Adr+(Blck_Size-1), Fct, MilErr);

     Fct.B.Fct := Fct_WrRAM;         {Daten mit Block-Write-Fct!!}
     for I := 1 to Blck_Size  do     {=0 weil Daten ab Start-Adr lesen}
      begin
       SD_WrData := Wr_Ary[I];
       Mil.Wr (SD_WrData, Fct, MilErr);
       if MilErr <> No_Err then
       begin
         Ini_Err_Win;
         Write ('ERROR: Wr-Blockmode-Data !!');
         repeat until Keypressed;
         Std_Msg;
         Exit;
         Set_text_Win;
       end;
      end;
   end; {WrSD_Block_Ary}


 function RdSD_Block_Ary (Start_Adr  : LongInt;
                          Blck_Size  : LongInt;
                      var Rcv_Cnt    : LongInt;
                      var Rcv_Err_Cnt: LongInt): Boolean;
  const Wait_Rd_Block = 20;   {x 10 us}
  var I : Integer;                   {Anzahl der gelesenen Daten zurÅck}
      Rd_Data   : Word;
      Wr_Data   : Word;
      SD_RdData : Word;
      Timeout   : Boolean;

   begin
     RdSD_Block_Ary := True;
     Rcv_Cnt        := 0;
     Fct.B.Adr      := Ifc_Test_Nr;
     Fct.B.Fct      := Fct_Rd_Status;    {Lese IRQ-Status der IFK}
     Mil.Rd (Rd_Data, Fct, MilErr);

     if MilErr = No_Err then
      begin
       Fct.B.Fct := Fct_Set_IntMask;
       Wr_Data   := Rd_Data or Ifc_Irmask_Dreq;  {Enable DREQ-Bit setzen}
       Mil.Wr (Wr_Data, Fct, MilErr);
     end;
     Mil.Timer2_Wait(20);      {Warte evtl. laufenden MIL-Transfer ab}
               {Teste, ob bereits vorzeitig DREQ vorliegt}
    if ((Portw[Port_Stat] and Stat_Dta_Req) = Stat_Dta_Req) then
     begin
      RdSD_Block_Ary := False;
      Ini_Err_Win;
      Write('DREQ vorzeitig da!');
      Mil.Timer2_Wait(200000);
      Std_Msg;
      Exit;
     end;

     Mil.Reset;                         {Clear FIFO}
     Fct.B.Fct  := Fct_RdStart_Adr;
     Mil.Wr (Start_Adr, Fct, MilErr);

     Fct.B.Fct  := Fct_RdEnd_Adr;
     Mil.Wr (Start_Adr+(Blck_Size-1), Fct, MilErr);

     Fct.B.Fct := Fct_RdRAM;         {IFK in READ_Blockmode schalten}
     Mil.WrFct (Fct, MilErr);        {Blockweiser Datentransfer lÑuft automat}
     Mil.Timer2_Wait(10);

     {DREQ ist dyn. und kann nicht sicher auf Vorhandensein geprÅft werden!}
{    if not ((Portw[Port_Stat] and Stat_Dta_Req) = Stat_Dta_Req) then
     begin
      Ini_Err_Win;
      Write('DREQ nach Start Blockmode nicht da!');
      Mil.Timer2_Wait(200000);
      Std_Msg;
      Exit;
     end;
}
{
     Mil.Timer2_Set(100000);
     repeat
     until  Mil.Timeout2 or
       not ((Portw[Port_Stat] and Stat_Dta_Req) = Stat_Dta_Req);
     if Mil.Timeout2 then Exit;
}

     {PrÅfe, ob im Rcv_Fifo Daten sind bzw. ob IFK antwortet}
     if ((Portw[Port_Stat] and stat_ffo_ety) = stat_ffo_ety) then
      begin
       RdSD_Block_Ary:= False;
       Ini_Err_Win;
       Write ('ERROR: Nach Start Blockmode keine Daten im Rcv-FIFO!  Weiter <CR> oder E<X>it');
       repeat until Keypressed;
       Std_Msg;
       Set_Text_Win;
       Exit;
      end;

     Mil.Timer2_Wait(100000);  {Warte bis alle Daten im FIFO}
     I := 0;
     while not ((Portw[Port_Stat] and stat_ffo_ety) = stat_ffo_ety)  do
      begin
          I := I + 1;
          Rd_Ary[I] := Portw[Port_Data];
      end;

    Rcv_Cnt   := I;
    if Rcv_Cnt <> Blck_Size then RDSD_Block_Ary:= False;
    for I := 1 to Rcv_Cnt do
     begin
      if Wr_Ary[I] <> Rd_Ary[I] then
       begin
         Set_Text_Win;
         GotoXY(45, Z_RdCount); Write (Hex_Word(Rd_Ary[I]));
         GotoXY(60, Z_RdCount); Write (Hex_Word(Wr_Ary[I]));
         Displ_Block_Param;
         Ini_Msg_Win;
         Write ('NÑchste Daten <Space>    oder <Q>uit');
         Ch := NewReadKey;
         if Ch in ['q','Q'] then
          begin
           Std_Msg;
           Exit;
          end;
       end;  {If Daten <>}
     end;    {for}
    {Zeige den ersten Datenfehler}
  end; {RdSD_Block_Ary }


  procedure Transfer_Block_Ary;
   begin
    Fct.B.Fct := Fct_Reset;         {IFK + SD reset}
    Mil.WrFct (Fct, MilErr);
    Mil.Timer2_Wait (10);           {Warte Ende des MIL-Transfers ab}
    Mil.Reset;                      {Clear Rcv-FIFO}
    Rcv_Count := 0;
    GotoXY(S_Count, Z_RdCount);   Write('     ');
    if WrSD_Block_Ary (Wr_Start_Adr, Wr_Block_Size) then
      Block_Count  := Block_Count + 1;
    if not RdSD_Block_Ary (Rd_Start_Adr,Rd_Block_Size,Rcv_Count,Rcv_Err_Count) then
      Block_ErrCnt := Block_ErrCnt + 1;
    Displ_Block_Param;
   end; {Transfer_Block_Ary}


 procedure Displ_FTasten;
  begin
   Set_TastMag_Win;
   TextColor(Yellow);
   GotoXY(01, 01); Write('F1:BlcklÑnge ', 'F5:            ', 'F10:      ');
   GotoXY(01, 02); Write('F2:Start-Adr ', 'F6:            ', 'F11:      ');
   GotoXY(01, 03); Write('F3:          ', 'F7:            ', 'F12: Reset');
   TextColor(Black);
   Set_Text_Win;
  end;

  begin
   Life_Mode.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
   Life_Mode.PosX    := S_Null;        {02;}
   Life_Mode.PosY    := Z_RdCount-1;;        {}
   Life_Mode.Time    := Life_Time_Fast;
   Life_Mode.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}

   Ary_Init;
   Wr_Block_Size  := Ary_Max;
   Rd_Block_Size  := Ary_Max;
   Wr_Start_Adr   := 1;
   Rd_Start_Adr   := Wr_Start_Adr;

   Block_Count    := 0;
   Block_ErrCnt   := 0;
   Rcv_Count      := 0;
   Rcv_Err_Count  := 0;
   Bit_Muster_Mode:= Ary;

{   Mil_Ask_Ifc;   }
   Fct.B.Adr := Ifc_Test_Nr;

   Ini_Text_Win;
   TextColor(Brown);
   GotoXY(20,Z_Basis-2);       Write('Blockmode-Bitmuster-Test fÅr Strahldiagnose-Hardware');
   GotoXY(10,Z_Basis-1);
   TextColor(Blue);            Write('Write zur SD-Hardware wortweise, Read von SD-HW:  ');
   TextColor(White); Write('blockweise'); TextColor(Brown);

   GotoXY(S_Block_Hex,Z_Block-1);   Write('[Hex]');
   GotoXY(S_Block_Dez,Z_Block-1);   Write('[Dez]');

   GotoXY(S_Null,Z_Block);      Write('Block-LÑnge  : ');
   GotoXY(S_Null,Z_Start);      Write('Start-Adr DPR: ');
   GotoXY(S_Null,Z_End);        Write('End-Adresse  : ');
   GotoXY(S_Null, Z_Muster);    Write('BitMuster    : ');

   GotoXY(S_Null, Z_BlkCnt);    Write('WrBlock-Count: ');
   GotoXY(S_Null, Z_BlkCntErr); Write('RdBlockErrCnt: ');

   GotoXY(S_Null+4, Z_Text-1);  Write('Block-');
   GotoXY(S_Null+4, Z_Text);    Write('Rcv-Data-Cnt');

   GotoXY(S_Null+20, Z_Text-1); Write('Total-');
   GotoXY(S_Null+20, Z_Text);   Write('Rcv-Err-Count');

   GotoXY(S_Hex,  Z_Text-1);    Write('Ist-');
   GotoXY(S_Hex,  Z_Text);      Write('Data [Hex]');
   GotoXY(S_Bin,  Z_Text-1);    Write('Soll]');
   GotoXY(S_Bin,  Z_Text);      Write('Data [Hex]');

   Displ_Block_Param;
   Set_Text_Win; TextColor(Brown);
   GotoXY(S_Tast_Min, Z_Tast-3); Write('Belegung Funktions-Tasten:');
   Ini_TastMag_Win;
   Displ_FTasten;
   Set_Text_Win;

                     {Software-Gerippe fÅr Single-Step und Loop}
   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Life_Sign_XY (Life_Mode);
       case Bit_Muster_Mode of
        Ary : Transfer_Block_Ary;
       end;

       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Life_Sign_XY (Life_Mode);
       case Bit_Muster_Mode of
        Ary : Transfer_Block_Ary;
       end;
      end;

     if Ch = #0 then                  {Sonder-Tasten Abfrage}
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    if Read_Int (1,Ary_Max, User_Int) then
                     begin
                       Adr_Max  := User_Int + Wr_Start_Adr;
                       if Adr_Max > Ary_Max then
                        begin
                          Ini_Err_Win;
                          Write('ERROR: BlocklÑnge + Start-Adr unzulÑssig gro· [>',Ary_Max,']');
                          Mil.Timer2_Wait (200000);
                        end
                       else
                        begin
                         Wr_Block_Size := User_Int;
                         Rd_Block_Size := Wr_Block_Size;
                         Displ_Block_Param;
                       end;
                     end;
                     Std_Msg;
                   end;
        Taste_F2 : begin
                    if Read_Int (1, DPR_Max, User_Int) then
                      begin
                        Adr_Max  := User_Int + Wr_Block_Size;
                        if Adr_Max > DPR_Max then
                         begin
                           Ini_Err_Win;
                           Write('ERROR: Start-Adr + BlocklÑnge unzulÑssig gro· [>',DPR_Max,']');
                           Mil.Timer2_Wait (200000);
                         end
                        else
                          Wr_Start_Adr := User_Int;
                        Displ_Block_Param;
                      end;
                     Std_Msg;
                   end;
        Taste_F3 : begin           {2x Bitmuster fix}
                     Bit_Muster_Mode:= Ary;
                     for I := 1 to Ary_Max do Wr_Ary[I] := I;
                     Block_Count   := 0;
                     Block_ErrCnt  := 0;
                     Rcv_Count     := 0;
                     Rcv_Err_Count := 0;
                     Displ_Block_Param;
                   end;
        Taste_F5 : begin
{                    if Ask_Hex_Break (User_Hex, Wrd) then
                      begin
                       Bit_Muster_Mode := Fix;
                       Bit_Muster := User_Hex;
                       Displ_Block_Param;
                       Std_Msg;
                      end;
}                   end;
        Taste_F6 : begin
{                    Ini_Msg_Win;
                    Write ('Es werden nachfolgend 2 Bitmuster in Hex angefordert!  Weiter mit <Space>:');
                    repeat
                     Ch := NewReadKey;
                    until Ch = ' ';

                    if Ask_Hex_Break (User_Hex, Wrd) then
                      begin
                       Bit_Muster1 := User_Hex;
                       if Ask_Hex_Break (User_Hex, Wrd) then
                        begin
                         Bit_Muster2 := User_Hex;
                         Bit_Muster_Mode:= Vari;
                         Displ_Block_Param;
                        end;
                      end;
                    Std_Msg;
}                   end;
        Taste_F7 : begin           {2x Bitmuster fix}
{                     Bit_Muster_Mode:= Vari;
                     Bit_Muster1    := Bit_Muster1_Def;
                     Bit_Muster2    := Bit_Muster2_Def;
                     Displ_Block_Param;
}                   end;

        Taste_F12: begin
                     Fct.B.Adr := Ifc_Test_Nr;
                     Fct.B.Fct := Fct_Reset;         {IFK + SD reset}
                     Mil.WrFct (Fct, MilErr);
                     Mil.Timer2_Wait (20);
                     Mil.Reset;                {Clear Rcv-FIFO}

                     Block_Count   := 0;
                     Block_ErrCnt  := 0;
                     Rcv_Count     := 0;
                     Rcv_Err_Count := 0;

                     Displ_Block_Param;
                     Ini_Err_Win;
                     Write('Reset IFK');
                     Mil.Timer2_Wait (200000);
                     Std_Msg;
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
 end; {SD_DPR_Drq}


 procedure Pigy_Timer;
  Label 99;
  const
   Z_Base      = 2;
   Z_Stat      = Z_Base +6;
   Z_Time      = Z_Base +10;
   Z_Seq       = Z_Base +14;

   S_MaskCnt   = 33;
   Z_FTast_Min = 20;
   Z_FTast_Max = Z_FTast_Min + 3;
   S_FTast_Min = 02;
   S_FTast_Max = S_FTast_Min + 39;

  var
   read_data,fct_code : WORD;
   MilErr     : TMilErr;
   Fct        : TFct;
   Transf_Cnt : LongInt;
   Timout_Cnt : LongInt;
   SeqErr_Cnt : LongInt;
   WrMask_Cnt : LongInt;
   Rd_Stat_Cnt: LongInt;
   WrData     : Word;
   Adress     : Word;
   IdRet_Code : TIfk_IdErr;
   Adr_Error  : Boolean;
   Timeout_Evt: Word;
   Timeout_Ms : Word;
   IoRes      : Integer;
   User_Int   : LongInt;
   User_Input : Word;
   Start_Adr  : Word;
   End_Adr    : Word;
   I          : Integer;

 procedure Ini_FTast_Win;
  begin
   Window(S_FTast_Min, Z_FTast_Min, S_FTast_Max, Z_FTast_Max);
   TextBackground(Green);
   TextColor(Yellow);               {Setze Schriftfarbe}
   ClrScr;
  end;

{ Falls Timeout-Zeit rÅcklesbar:
  ModAdr.AdrSub  := SubAdr_12Evt_RamTimMs;
}

 PROCEDURE Show_Stat_Reg_Tmr;
  var Bit16_Strg: Str19;
      Stat_Data : Word;
      Timr_Data : Word;
      Timer_Int : LongInt;
      Timer_Real: Real;

    begin
     Set_Text_Win;
     Stat_Data := 0;
     Timr_Data := 0;

     Rd_Stat_Cnt:= Rd_Stat_Cnt + 1;
     GotoXY(31, Z_Base+04); Write (Rd_Stat_Cnt:10);
     GotoXY(23, Z_Time+2); Write (Timout_Cnt:6);

     Mil.Timer2_Wait(10);    {Warte bis laufender Mil-Transfer beendet}
     Mil.Reset;              {ohne Fifo Clear gibt es Fehler!}
     Fct.B.Fct  := Fct_Pgy_RdStat;
     Mil.Rd (Stat_Data, Fct, MilErr);
     if MilErr = No_Err then
      begin
        GotoXY(28, Z_Stat);   write(hex_word(Stat_data));
        Hex_Bin_Str (Stat_Data, bit16_strg);
        GotoXY(22, Z_Stat+1);   write(bit16_strg);

        if BitTst(Stat_Data, 1) then Timout_Cnt := Timout_Cnt +1;
        GotoXY(23, Z_Time+2);  Write(Timout_Cnt:6);

        if BitTst(Stat_Data, 2) then SeqErr_Cnt := SeqErr_Cnt +1;
        GotoXY(23, Z_Seq);     Write (SeqErr_Cnt:6);
     end
     else
      begin
        GotoXY(28, Z_Stat);  write('    ');
        TextColor (Red);
        GotoXY(22, Z_Stat+1);  write('   Read Error!!    ');
        TextColor (Black);
      end;

    {Timer Daten}
     Fct.B.Fct  := Fct_Pgy_RdTimer;
     Mil.Rd (Timr_Data, Fct, MilErr);
     if MilErr = No_Err then
      begin
        GotoXY(25, Z_Time);  Write(hex_word(Timr_Data));
        Timer_Real := Timr_Data;
        Timer_Real := (Timer_Real * 42.66)/1000.0;
        GotoXY(24, Z_Time+1);  write(Timer_Real:5:0);
     end
     else
      begin
        GotoXY(28, Z_Time);  write('    ');
        GotoXY(25, Z_Time+1);  write('          ');
      end;
   end; {show_stat_reg-tmr; }


 procedure Create_Seq_Error (S_Adr: Word); {nur Start-Adr schicken}
  begin
     Fct.B.Fct  := Fct_RdStart_Adr;   {Wr Startadr ohne Endadr}
     Mil.Wr (S_Adr, Fct, MilErr);

     Fct.B.Fct := Fct_RdRAM;         {IFK in READ_Blockmode schalten}
     Mil.WrFct (Fct, MilErr);        {Blockweiser Datentransfer lÑuft automat}
  end; {Rd_DPR_Single}

 procedure Create_Timeout_Error (S_Adr: Word); {nur Start-Adr schicken}
  begin
     Fct.B.Fct  := Fct_RdStart_Adr;   {Wr nur Start-Adr}
     Mil.Wr (S_Adr, Fct, MilErr);
  end; {Rd_DPR_Single}

 procedure Read_Block (Start_Adr  : LongInt;
                       Blck_Size  : LongInt);
 const Wait_Rd_Block = 20;   {x 10 us}
  var I : Integer;                   {Anzahl der gelesenen Daten zurÅck}
      Rd_Data   : Word;
      Wr_Data   : Word;
      SD_RdData : Word;
      Timeout   : Boolean;

   begin
     Mil.Reset;                         {Clear FIFO}
     Fct.B.Adr      := Ifc_Test_Nr;
     Fct.B.Fct      := Fct_RdStart_Adr;
     Mil.Wr (Start_Adr, Fct, MilErr);

     Fct.B.Fct  := Fct_RdEnd_Adr;
     Mil.Wr (Start_Adr+(Blck_Size-1), Fct, MilErr);

     Fct.B.Fct := Fct_RdRAM;         {IFK in READ_Blockmode schalten}
     Mil.WrFct (Fct, MilErr);        {Blockweiser Datentransfer lÑuft automat}
  end; {Create_Timeout_Err}


  Begin          {Pigy_Timer}
   Ini_Text_Win;
   Fct.B.Adr  := Ifc_Test_Nr;    {Modul-Adr definieren}
   Rd_Stat_Cnt:= 0;
   Transf_Cnt := 0;
   Timout_Cnt := 0;
   SeqErr_Cnt := 0;
   WrMask_Cnt := 0;

   TextColor(Brown);
   GotoXY(16,01); write('------ Timer-Test + Status lesen des SD-Blockmode-Piggy  -----');
   GotoXY(50,05); write  ('Bedeutung der Status-Bits');

   GotoXY(06,Z_Base  );  write('Ifk-Adr  [Hex]:');
   GotoXY(06,Z_Base+1);  write('Pigy-Id  [Hex]:');
   GotoXY(06,Z_Base+2);  write('EPLD-Vers[Hex]:');

   GotoXY(06,Z_Base+4);  write('Rd-Count      :');
   GotoXY(35,Z_Base+5);  write('^  ^');
   GotoXY(06,Z_Stat);    write('Stat-Data[Hex]:');
   GotoXY(06,Z_Stat+1);  write('Stat-Data[Bin]:');
   GotoXY(22,Z_Stat+2);  write('MSB             LSB');
   GotoXY(06,Z_Time);    write('Timer Rd [Hex]:');
   GotoXY(06,Z_Time+1);  write('  "       [ms]:');
   GotoXY(06,Z_Time+2);  write('  " ErrorCount:');

   GotoXY(06,Z_Seq);     write('Seq-ErrorCount:');
   TextColor(Black);
   GotoXY(23,Z_Base);  Write (Hex_Byte(Ifc_Test_Nr));

   GotoXY(23,Z_Base+1);
   Fct.B.Fct  := Fct_Pgy_RdIdent;
   Mil.Rd (Read_Data, Fct, MilErr);
   if MilErr = No_Err then  Write (Hex_Byte(Read_Data)) else Write ('ERROR');

   GotoXY(23,Z_Base+2);
   Fct.B.Fct  := Fct_Pgy_RdEpld;
   Mil.Rd (Read_Data, Fct, MilErr);
   if MilErr = No_Err then  Write (Hex_Byte(Read_Data)) else Write ('ERROR');

   Displ_Pigy_Stat;
   Ini_FTast_Win;
   Writeln ('F1: Set Timer manuell  F9 : Read Block ');
   Writeln ('F2: Set Timer max.     F10:            ');
   Writeln ('F3: Create Timeout-Err F11: Abort DPR  ');
   Write   ('F4: Create Seq-Error   F12: Reset all ');

   Set_Text_Win;
   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Single_Step := True;
       Show_Stat_Reg_Tmr;
       repeat until KeyEPressed;
         Ch := NewReadKey;
      end;

    if Ch = #13 then Single_Step := False;
    if not Single_Step then
      begin
       Show_Stat_Reg_Tmr;
      end;

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                     Ini_Msg_Win;
                     Write ('Bitte Timeout-Zeit (20..xxxxx [ms]) eingeben: ');
                     {$I-}                            {Compiler Check aus, Error selber abfangen}
                     Read (User_Int);
                     {$I+}
                     IoRes := IoResult;
                     if (IoRes = 0) then
                      begin
                        if (User_Int > $FFFF) then User_Int := $FFFF;
                        if (User_Int < 20)    then User_Int := 20;
                        Fct.B.Fct := Fct_Pgy_WrTimer;
                        WrData    := User_Int;
                        Mil.Wr (WrData, Fct, MilErr);
                      end;
                    Std_Msg;
                   end; {Taste_F1}
        Taste_F2: begin
                    Fct.B.Fct := Fct_Pgy_WrTimer;
                    WrData    := $FFFF;
                    Mil.Wr (WrData, Fct, MilErr);
                  end; {Taste_F2}
        Taste_F3: begin
                    Start_Adr := $10;
                    Fct.B.Fct := Fct_WrStart_Adr;
                    Create_Timeout_Error (Start_Adr);
                    Ini_Err_Win;
                    Write('Bitte Piggy-Timeout abwarten!!');
                    Mil.Timer2_Wait(200000);
                    Std_Msg;
                  end; {Taste_F2}
        Taste_F4: begin
                    Start_Adr := $10;
                    Fct.B.Fct := Fct_WrStart_Adr;
                    Create_Seq_Error (Start_Adr);
                  end; {Taste_F4}
        Taste_F9: begin
                    Read_Block (1, 1024);
                  end; {Taste_F9}
        Taste_F10: begin
                   end; {Taste_F10}

        Taste_F11: begin
                     Fct.B.Fct := Fct_SD_Abort;         {SD Abort}
                     Mil.WrFct (Fct, MilErr);
                     Mil.Timer2_Wait (20);
                   end; {Taste_F12}
        Taste_F12: begin
                     Fct.B.Fct := Fct_Reset;
                     Mil.WrFct (Fct, MilErr);
                     Mil.Timer2_Wait (200);
                     Rd_Stat_Cnt:= 0;
                     Timout_Cnt := 0;
                     SeqErr_Cnt := 0;
                     Ini_Err_Win;
                     Write ('Reset IFC + SD');
                     Mil.Timer2_Wait(200000);
                     Std_Msg;
                     Set_Text_Win;
                     GotoXY(31, Z_Base+04); Write (Rd_Stat_Cnt:10);
                     GotoXY(23, Z_Time+2); Write (Timout_Cnt:6);
                     GotoXY(23, Z_Seq);     Write(SeqErr_Cnt:6);
                   end; {Taste_F12}
       end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
 end; {Pigy_Timer}

{xxx}
 procedure SD_DPR_Single;
  Label 99;
  const
   Wait_Rcv    = 10; {Rcv-Timeout Zeit}

   Z_Base      = 4;
   S_MaskCnt   = 33;
   Z_FTast_Min = 21;
   Z_FTast_Max = Z_FTast_Min + 2;
   S_FTast_Min = 41;
   S_FTast_Max = S_FTast_Min + 38;

   S_Ifk     = 30;
   S_HexData = 50;
   S_BinData = 60;

   Z_WrCount = Z_Base +5;
   Z_WrData  = Z_Base +7;
   Z_RdData  = Z_Base +8;
   Z_RcvErr  = Z_Base +10;
   Z_RcvTout = Z_Base +11;
   Z_RcvNum  = Z_Base +12;
   Z_WaitTout= Z_Base +13;



  var
   read_data,fct_code : WORD;
   Transf_Cnt  : LongInt;
   Timout_Cnt  : LongInt;
   Rcv_DtaErrCnt: LongInt;
   Rcv_NumCnt  : LongInt;
   Rcv_Count   : Integer;
   WrData      : Word;
   RdData      : Word;
   Start_Adr   : Word;
   End_Adr     : Word;
   I           : Integer;
   Disp_Single_Block_Data: Boolean;
   Disp_Single_Step_Data : Boolean;


 procedure Ini_FTast_Win;
  begin
   Window(S_FTast_Min, Z_FTast_Min, S_FTast_Max, Z_FTast_Max);
   TextBackground(Green);
   TextColor(Yellow);               {Setze Schriftfarbe}
   ClrScr;
  end;

 procedure Wr_DPR_Single (S_Adr: Word; E_Adr:Word; DPR_WrData: Word);
  begin
     Transf_Cnt := Transf_Cnt+1;
     Fct.B.Fct := Fct_WrStart_Adr;
     Mil.Wr (S_Adr, Fct, MilErr);
     Fct.B.Fct := Fct_WrEnd_Adr;
     Mil.Wr (E_Adr, Fct, MilErr);
     Fct.B.Fct := Fct_WrRAM;
     Mil.Wr (DPR_WrData, Fct, MilErr);
  end; {Wr_DPR_Single}

 procedure Rd_DPR_Single(S_Adr     : Word;
                         E_Adr     : Word;
                     var DPR_RdData: Word;
                     var Rcv_Cnt   : Integer);
  begin
     Mil.Timer2_Wait(10);            {Warte auf Ende aller MIl-Transfers}
     Rcv_Cnt := 0;
     Mil.Reset;                      {Clear FIFO}
     Fct.B.Fct  := Fct_RdStart_Adr;
     Mil.Wr (S_Adr, Fct, MilErr);
     Fct.B.Fct  := Fct_RdEnd_Adr;
     Mil.Wr (E_Adr, Fct, MilErr);
     Fct.B.Fct := Fct_RdRAM;         {IFK in READ_Blockmode schalten}
     Mil.WrFct (Fct, MilErr);        {Blockweiser Datentransfer lÑuft automat}
     Mil.Timer2_Set (Wait_Rcv);
     repeat
       if not ((Portw[Port_Stat] and stat_ffo_ety) = stat_ffo_ety) then
        begin
          DPR_RdData := Portw[Port_Data];
          Rcv_Cnt    := Rcv_Cnt+1;
        end;
     until Mil.Timeout2;
  end; {Rd_DPR_Single}

 type
  TDisp_Mode = (All, No_Rd, No_Adr, No_Data, Wr_Count_Only);

  procedure Displ_Param (Disp_Mode: TDisp_Mode);
   var Bit16_Strg: Str19;
   begin
     Set_Text_Win;
     GotoXY(20,Z_WrCount);       write(Transf_Cnt:10);
     if Disp_Mode = Wr_Count_Only then Exit;

     GotoXY(S_Ifk+17,Z_Base+4);
     if Disp_Single_Block_Data then write('Ja  ') else write('Nein');
     TextColor(Blue);
     if Disp_Single_Step_Data  then Write('  Single Data') else Write ('             ');
     TextColor(Black);
     if Disp_Mode = No_Adr then
      begin
       GotoXY(20+6,Z_WrData); write('    ');
       GotoXY(20,Z_RdData);   write('          ');
      end
     else
      begin
       GotoXY(20+6,Z_WrData); write(Hex_Word(Start_Adr));
       GotoXY(20,Z_RdData);   write(Start_Adr:10);
      end;

     GotoXY(S_HexData,Z_WrData); write(Hex_Word(WrData));
     Hex_Bin_Str (WrData, bit16_strg);
     GotoXY(S_HexData+10,Z_WrData);  write(bit16_strg);

     if Disp_Mode = No_Rd then
      begin
        GotoXY(S_HexData,Z_RdData); write('    ');
        GotoXY(S_HexData+10,Z_RdData);  write('                   ');
      end
     else
      begin
        GotoXY(S_HexData,Z_RdData); write(Hex_Word(RdData));
        Hex_Bin_Str (RdData, bit16_strg);
        GotoXY(S_HexData+10,Z_RdData);  write(bit16_strg);
      end;

     if Disp_Mode = No_Data then
      begin
        GotoXY(20+6,Z_WrData);      write('    ');
        GotoXY(20,Z_RdData);        write('          ');
        GotoXY(S_HexData,Z_WrData); write('    ');
        GotoXY(S_HexData,Z_RdData); write('    ');
        GotoXY(S_HexData+10,Z_WrData);  Write('                   ');
        GotoXY(S_HexData+10,Z_RdData);  Write('                   ');
      end;

     GotoXY(20  , Z_RcvErr );     Write(Rcv_DtaErrCnt:10);
     GotoXY(20  , Z_RcvNum);      Write(Rcv_NumCnt:10);
     GotoXY(20  , Z_RcvTout);     Write(Timout_Cnt:10);
     GotoXY(20+5, Z_WaitTout);    Write(Wait_Rcv * 10:5);
   end;

  procedure Displ_WrCursor (Cursor_Show: Boolean);
   begin
    Set_Text_Win;
    GotoXY(04,Z_WrCount);
    if Cursor_Show then
     begin
       TextColor(Yellow+128);
       Cursor(True);
       Write (chr(Cursor_Solid ));
     end
    else
     begin
       TextBackground(White);
       Write (' ');
     end;
    Cursor(False);
   end; {Displ_WrCursor}

  procedure Displ_RdCursor (Cursor_Show: Boolean);
   begin
    Set_Text_Win;
    GotoXY(04,Z_WrData-1);
    if Cursor_Show then
     begin
       TextColor(Blue+128);
       Cursor(True);
       Write (chr(Cursor_Solid ));
     end
    else
     begin
       TextBackground(White);
       Write (' ');
     end;
    Cursor(False);
   end; {Displ_WrCursor}

 procedure WrRd_Check_Single;
  var I : Integer;
      Rcv_Err : Boolean;
  begin
       Displ_WrCursor (True);
       for I := 1 to DPR_Max do
        begin
         Start_Adr   := I;
         End_Adr     := Start_Adr;
         WrData      := I;
         Wr_DPR_Single (Start_Adr, End_Adr, WrData);
        end;
       Displ_WrCursor (False);

       Displ_RdCursor (True);
       for I := 1 to DPR_Max do
        begin
          Rcv_Err := False;
          if KeyEPressed then
           begin
            Displ_Param (All);
            if Single_Step then Disp_Single_Step_Data := True;
            Ch    := NewReadKey;
            if Ch in ['x','X'] then Break;
           end;

          Start_Adr   := I;
          End_Adr     := Start_Adr;
          WrData      := I;
          Rd_DPR_Single (Start_Adr, End_Adr, RdData, Rcv_Count);
          if Rcv_Count = 0 then
           begin
             Timout_Cnt := Timout_Cnt+1;
             Displ_Param (No_Rd);
             Rcv_Err := True;
           end;

          if Rcv_Count > 1 then
           begin
             Rcv_NumCnt := Rcv_NumCnt+1;
             Displ_Param (All);
             Break;
           end;

          if Rcv_Count = 1 then
           begin
             if WrData <> RdData then
              begin
               Rcv_DtaErrCnt := Rcv_DtaErrCnt +1;
               Displ_Param (All);
               Rcv_Err := True;
               Break;
              end;
           end;
         if (Disp_Single_Block_Data and not Rcv_Err) then Displ_Param (All);

         if  Disp_Single_Step_Data  then
          begin
            Single_Step := True;
            Ini_Msg_Win;
            Write ('Single Step Data Display!   Next Single Read mit <Space> bzw. [Q]uit ');
            Ch := NewReadKey;
            if Ch in ['q','Q'] then Disp_Single_Step_Data := False;
            Std_Msg;
          end;  {Disp_Single_Step_Data}
        end;  {for}
     Displ_RdCursor (False);
  end; {WrRd_Check_Single}


  Begin
   Ini_Text_Win;
   Fct.B.Adr    := Ifc_Test_Nr;    {Modul-Adr definieren}
   Transf_Cnt   := 0;
   Rcv_DtaErrCnt:= 0;
   Timout_Cnt   := 0;
   Rcv_NumCnt   := 0;
   Disp_Single_Block_Data := True;
   Disp_Single_Step_Data  := False;
   Displ_Param (No_Data);

   TextColor(Brown);
   GotoXY(01,02); write('Write DPR-Adr[1..');   Write (DPR_Max);
   Write ('] mit Data[1..'); WRite (DPR_Max);  Write('], dann wortweise lesen mit Daten-Check');
   GotoXY(S_Ifk,Z_Base  );  write('Ifk-Adr  [Hex]:');
   GotoXY(S_Ifk,Z_Base+1);  write('Pigy-Id  [Hex]:');
   GotoXY(S_Ifk,Z_Base+2);  write('EPLD-Vers[Hex]:');

   GotoXY(S_Ifk+2,Z_Base+4); write('Datenanzeige: ');
   GotoXY(06,Z_WrCount-1); write('Wr-Block     :');
   GotoXY(06,Z_WrCount);   write('Wr-Counter   :');
   GotoXY(24,Z_Base+6);    write('^  ^');

   GotoXY(06,Z_WrData-1);write('READ-');
   GotoXY(06,Z_WrData);  write('DPR-Adr [Hex]:');
   GotoXY(06,Z_RdData);  write('   "    [Dez]:');

   GotoXY(S_HexData  ,  Z_Base+6);   write('[Hex]');
   GotoXY(S_BinData+6,  Z_Base+6);   write('[Bin]');

   GotoXY(S_HexData-11, Z_WrData);    write('Soll Data:');
   GotoXY(S_HexData-11, Z_RdData);    write('Read-Data:');
   GotoXY(S_BinData   , Z_RdData+1); write('MSB             LSB');

   GotoXY(06          , Z_RcvErr );  write('Rcv DataErr  :');
   GotoXY(06          , Z_RcvTout);  write('Rcv Timeout  :');
   GotoXY(06          , Z_RcvNum);   write('Rcv >Anzahl 1:');
   GotoXY(06          , Z_WaitTout); write('Rcv Tout [us]:');

   TextColor(Black);
   GotoXY(S_Ifk+17,Z_Base);  Write (Hex_Byte(Ifc_Test_Nr));

   GotoXY(S_Ifk+17,Z_Base+1);
   Fct.B.Fct  := Fct_Pgy_RdIdent;
   Mil.Rd (Read_Data, Fct, MilErr);
   if MilErr = No_Err then  Write (Hex_Byte(Read_Data)) else Write ('ERROR');

   GotoXY(S_Ifk+17,Z_Base+2  );
   Fct.B.Fct  := Fct_Pgy_RdEpld;
   Mil.Rd (Read_Data, Fct, MilErr);
   if MilErr = No_Err then  Write (Hex_Byte(Read_Data)) else Write ('ERROR');

   Ini_FTast_Win;
   Writeln ('F1: Datenanzeige J/N F9 : Init Counter');
   Writeln ('F2: " Single Data "  F11: Abort Piggy ');
   Write   ('F3:                  F12: Reset Ifk+SD');

   Set_Text_Win;
   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;
   Mil.Reset;      {IFK und SD-DPR definiert resetten}

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Set_Text_Win;
       Displ_Param (No_Data);
       GotoXY(06,Z_WrCount-1); TextColor (White); write('Single Wr-Block');
       WrRd_Check_Single;
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then
      begin
        Single_Step := False;
        Set_Text_Win;
        GotoXY(06,Z_WrCount-1); TextColor (White); write('Loop Wr-Block  ');
        Displ_Param (No_Data);
        TextColor (Black);
      end;

     if not Single_Step then
      begin
       WrRd_Check_Single;
       Set_Text_Win;
       GotoXY(20,Z_WrCount);       write(Transf_Cnt:10);
      end; {if not Single Step}

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    if Disp_Single_Block_Data then
                      begin
                        Disp_Single_Block_Data:=False;
                        Displ_Param (No_Data);
                      end
                    else
                      begin
                        Disp_Single_Block_Data:=True;
                        Displ_Param (No_Data);
                      end;
                  end;
        Taste_F2 : begin
                    if Disp_Single_Step_Data then
                      begin
                        Disp_Single_Step_Data := False;
                        Displ_Param (No_Data);
                      end
                    else
                      begin
                        Disp_Single_Step_Data := True;
                        Displ_Param (No_Data);
                      end;
                  end;
        Taste_F9: begin
                    Transf_Cnt   := 0;
                    Rcv_DtaErrCnt:= 0;
                    Timout_Cnt   := 0;
                    Rcv_NumCnt   := 0;
                    Displ_Param (No_Data);
                  end; {Taste_F12}

        Taste_F11: begin
                     Fct.B.Fct := Fct_SD_Abort;         {SD Abort}
                     Mil.WrFct (Fct, MilErr);
                     Mil.Timer2_Wait (20);
                     Transf_Cnt   := 0;
                     Rcv_DtaErrCnt:= 0;
                     Timout_Cnt   := 0;
                     Rcv_NumCnt   := 0;
                     Displ_Param (No_Data);
                   end; {Taste_F12}
        Taste_F12: begin
                     Fct.B.Fct := Fct_Reset;
                     Mil.WrFct (Fct, MilErr);
                     Mil.Timer2_Wait (20);
                     Transf_Cnt   := 0;
                     Rcv_DtaErrCnt:= 0;
                     Timout_Cnt   := 0;
                     Rcv_NumCnt   := 0;
                     Displ_Param (No_Data);
                   end; {Taste_F12}
       end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
 end; {SD_DPR_Single}



begin                      { Hauptprogramm MIL-BASE }
  Ifc_Test_Nr := 0;
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
		  if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
                  Mil_Rd_HS_Ctrl (Ifc_Test_Nr);
                end;
     '3'      : begin
		  if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
                  Mil_Rd_HS_Status (Ifc_Test_Nr);
                end;
     '4'      : begin
		  if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
                  Mil_Stat_All (Ifc_Test_Nr);
                end;
     '5'      : begin
                  Convert_Hex_Volt;
                end;
     '6'      : begin
                  Int_Mask;
                end;
     '7'      : begin
		  if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
                  Mil_HS_Stat_Cmd (Ifc_Test_Nr);
                end;
     '9'      : begin
		  if Ifc_Test_Nr = 0 then Mil_Ask_Ifc ;
                  Mil_Echo (Ifc_Test_Nr);
                end;
     'a', 'A' :  Mil_Ask_Ifc;
     'b', 'B' : begin
		 if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
                 Mil_Rd_Ifc_Stat (Ifc_Test_Nr);
                end;
     'c', 'C' : begin
                  Mil_Rd_Status;
                end;
     'd', 'D' : begin
                  Mil_Rd_Fifo;
                end;
     'e', 'E' : begin
		  if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
                  Mil_Rd_Data;
		end;
     'f', 'F' : begin
                  Functioncode_Table;
                end;
     'g', 'G' : begin
		  if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
                  Mil_Data := Ask_Data;
		  Mil_WrData (Mil_Data);
                end;
     'h', 'H' : begin
		  if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
		  Mil_Wr_Fctcode;
                end;
     'i', 'I' : begin
		  if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
                  Mil_Wr (Mil_Data);
                end;
     'j', 'J' : begin
		  if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
		  Mil_Data := Ask_Data;
		  Mil_Wr_Rd (Mil_Data);
                end;
     'k', 'K' : begin
		  if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
		  Mil_Loop;
                end;

     'l', 'L' : begin
                  Mil_Dual_Mode;
                end;
     'z', 'Z' : begin
                  Telefon;
                end;
     {Ab hier User-Erweiterungen!!}
          'm', 'M' : begin
    		      if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
                      Pigy_Status;
                     end;
          'n', 'N' : begin
    		      if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
                      Pigy_Timer;
                     end;
          'o', 'O' : begin
    		      if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
                      SD_DPR_Single;
                     end;
          'p', 'P' : begin
    		      if Ifc_Test_Nr = 0 then Mil_Ask_Ifc;
                      SD_DPR_Drq;
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

       Start_Adr   := Start_Adr +1;
       if Start_Adr>DPR_Max+1 then Start_Adr:= 1; {+1 wegen geradzahliger Angabe}
       End_Adr     := Start_Adr;
       WrData      := $A55A;

       Wr_DPR_Single (Start_Adr, End_Adr, WrData);
       Rd_DPR_Single (Start_Adr, End_Adr, RdData, Rcv_Count);
       if Rcv_Count = 0 then Timout_Cnt := Timout_Cnt+1;
       if Rcv_Count > 1 then Rcv_NumCnt := Rcv_NumCnt+1;
       if Rcv_Count = 1 then
        begin
          if WrData <> RdData then Rcv_DtaErrCnt := Rcv_DtaErrCnt +1;
        end;

       Displ_Param;


 procedure SD_DPR_Pattern;
{Endadresse = Start_Adr + (Blockssize - 1), da auch die Start_Adr Åbertragen wird!
 Verschiedene BitMuster werden verwendet
}
  label 99;

  type
   TDta_Ary         = array [1..Ary_Max] of Word;
   TBit_Muster_Mode = (Fix, Vari, Cnt, Ary);

  var
   Life_Mode    : TLife_XY;
   Adr_Max      : LongInt;
   Rd_Block_Size: Integer;
   Wr_Block_Size: Integer;
   Rd_Start_Adr : Integer;
   Wr_Start_Adr : Integer;
   Wr_Ary       : TDta_Ary;
   Rd_Ary       : TDta_Ary;
   I            : Integer;
   Rcv_Count    : LongInt;
   Rcv_Err_Count: LongInt;
   Block_Count  : LongInt;
   Block_ErrCnt : LongInt;
   User_Int     : Integer;
   User_Hex     : Word;
   Bit_Muster   : Word;
   Bit_Muster1  : Word;
   Bit_Muster2  : Word;
{   Bit_Muster_Var: Boolean;  }
   Bit_Muster_Mode: TBit_Muster_Mode;

  procedure Ary_Init;
   var I : Integer;
   begin
    for I := 1 to Ary_Max  do Rd_Ary[I] := 0;
    for I := 1 to Ary_Max  do Wr_Ary[I] := 0;
   end;

  procedure Displ_Block_Param;
   begin
    Set_Text_Win;
    TextColor(Black);
    GotoXY(S_Block_Hex,Z_Block);   Write(Hex_Word (Wr_Block_Size));
    GotoXY(S_Block_Hex,Z_Start);   Write(Hex_Word (Wr_Start_Adr));
    GotoXY(S_Block_Hex,Z_End);     Write(Hex_Word (Wr_Start_Adr+(Wr_Block_Size-1)));

    case Bit_Muster_Mode of
     Vari : begin
              GotoXY(S_Block_Hex,Z_Muster);  Write('vari');
              Set_BitMuster_Win;
              Write ('Bit-Muster wortweise wechselnd:  ');
              GotoXY(01,02);
              Write ('Muster 1 [Hex]: '); TextColor(Black); Write (Hex_Word(Bit_Muster1)); ClrEol; Writeln; TextColor(Brown);
              Write ('Muster 2 [Hex]: '); TextColor(Black); Write(Hex_Word(Bit_Muster2));  ClrEol;
              Set_Text_Win;
            end;
     Fix :  begin
              Clr_BitMuster_Win;
              Set_Text_Win;
              GotoXY(S_Block_Hex,Z_Muster);  Write(Hex_Word (Bit_Muster));
            end;
     Cnt :  begin
             Clr_BitMuster_Win;
             Set_Text_Win;
             GotoXY(S_Block_Hex,Z_Muster);  Write('Data');
            end;
     Ary :  begin
             Clr_BitMuster_Win;
             Set_Text_Win;
             GotoXY(S_Block_Hex,Z_Muster);  Write('Aray');
            end;

    end; {case}

    GotoXY(S_Block_Dez,Z_Block);   Write(Wr_Block_Size:5);
    GotoXY(S_Block_Dez,Z_Start);   Write(Wr_Start_Adr:5);
    GotoXY(S_Block_Dez,Z_End);     Write(Wr_Start_Adr+(Wr_Block_Size-1):5);

    GotoXY(S_BlkCnt,Z_BlkCnt  );    Write(Block_Count:10);
    GotoXY(S_BlkCnt,Z_BlkCntErr);   Write(Block_ErrCnt:10);
    GotoXY(S_Count, Z_RdCount);     Write(Rcv_Count:5);
    GotoXY(S_BlkCnt,Z_RdCount);     Write(Rcv_Err_Count:10);
   end;


 function WrSD_Block_Ary (Start_Adr: Integer;
                          Blck_Size: Integer): Boolean;
   var I : LongInt;
       SD_WrData : Word;
   begin
     WrSD_Block_Ary := True;
     Fct.B.Adr := Ifc_Test_Nr;
     Fct.B.Fct := Fct_WrStart_Adr;
     Mil.Wr (Start_Adr, Fct, MilErr);

     Fct.B.Fct := Fct_WrEnd_Adr;
     Mil.Wr (Start_Adr+(Blck_Size-1), Fct, MilErr);

     Fct.B.Fct := Fct_WrRAM;         {Daten mit Block-Write-Fct!!}
     for I := 1 to Blck_Size  do     {=0 weil Daten ab Start-Adr lesen}
      begin
       SD_WrData := Wr_Ary[I];
       Mil.Wr (SD_WrData, Fct, MilErr);
       if MilErr <> No_Err then
       begin
         Ini_Err_Win;
         Write ('ERROR: Wr-Blockmode-Data !!');
         repeat until Keypressed;
         Std_Msg;
         Exit;
         Set_text_Win;
       end;
      end;
   end; {WrSD_Block_Ary}

 function RdSD_Block_Ary (Start_Adr  : LongInt;
                          Blck_Size  : LongInt;
                      var Rcv_Cnt    : LongInt;
                      var Rcv_Err_Cnt: LongInt): Boolean;
  const Wait_Rd_Block = 20;   {x 10 us}
  var I : Integer;                   {Anzahl der gelesenen Daten zurÅck}
      SD_RdData : Word;
      Timeout   : Boolean;
   begin
     RdSD_Block_Ary := True;
     Rcv_Cnt    := 0;
     Mil.Timer2_Wait(20);      {Warte evtl. laufenden MIL-Transfer ab}
     Mil.Reset;                {Clear FIFO}

     Fct.B.Adr  := Ifc_Test_Nr;
     Fct.B.Fct  := Fct_RdStart_Adr;
     Mil.Wr (Start_Adr, Fct, MilErr);

     Fct.B.Fct  := Fct_RdEnd_Adr;
     Mil.Wr (Start_Adr+(Blck_Size-1), Fct, MilErr);

     Fct.B.Fct := Fct_RdRAM;         {IFK in READ_Blockmode schalten}
     Mil.WrFct (Fct, MilErr);        {Blockweiser Datentransfer lÑuft automat}
     Mil.Timer2_Wait(10);

     {PrÅfe, ob im Rcv_Fifo Daten sind bzw. ob IFK antwortet}
     if ((Portw[Port_Stat] and stat_ffo_ety) = stat_ffo_ety) then
      begin
       RdSD_Block_Ary:= False;
       Ini_Err_Win;
       Write ('ERROR: Nach Start Blockmode keine Daten im Rcv-FIFO!  Weiter <CR> oder E<X>it');
       repeat until Keypressed;
       Std_Msg;
       Set_Text_Win;
       Exit;
      end;

     Timeout := False;
     I := 0;
     Mil.Timer2_Set(Wait_Rd_Block);
     while not Timeout do
      begin
       if not ((Portw[Port_Stat] and stat_ffo_ety) = stat_ffo_ety) then
        begin                                  {FIFO nicht leer}
          I := I + 1;
          Rd_Ary[I] := Portw[Port_Data];
          Mil.Timer2_Set(Wait_Rd_Block);        {Lade Timer}
        end
       else
        begin                                   {nichts im FIFO: warten}
          if Mil.Timeout2 then Timeout := True;
        end;
      end; {while}

    Rcv_Cnt   := I;
    if Rcv_Cnt <> Blck_Size then RDSD_Block_Ary:= False;
    for I := 1 to Rcv_Cnt do
     begin
      if Wr_Ary[I] <> Rd_Ary[I] then
       begin
         Set_Text_Win;
         GotoXY(45, Z_RdCount); Write (Hex_Word(Rd_Ary[I]));
         GotoXY(60, Z_RdCount); Write (Hex_Word(Wr_Ary[I]));
         Displ_Block_Param;
         Ini_Msg_Win;
         Write ('NÑchste Daten <Space>    oder <Q>uit');
         Ch := NewReadKey;
         if Ch in ['q','Q'] then
          begin
           Std_Msg;
           Exit;
          end;
       end;
     end;
    {Zeige den ersten Datenfehler}
  end; {RdSD_Block_Pattern}

  procedure Transfer_Block_Ary;
   begin
    Fct.B.Fct := Fct_Reset;         {IFK + SD reset}
    Mil.WrFct (Fct, MilErr);
    Mil.Timer2_Wait (100);           {Warte Ende des MIL-Transfers ab}
    Mil.Reset;                      {Clear Rcv-FIFO}
    Rcv_Count := 0;
    GotoXY(S_Count, Z_RdCount);   Write('     ');
    if WrSD_Block_Ary (Wr_Start_Adr, Wr_Block_Size) then
      Block_Count  := Block_Count + 1;
    if not RdSD_Block_Ary (Rd_Start_Adr,Rd_Block_Size,Rcv_Count,Rcv_Err_Count) then
      Block_ErrCnt := Block_ErrCnt + 1;
    Displ_Block_Param;
   end; {Transfer_Block_Ary}

 procedure Displ_FTasten;
  begin
   Set_TastMag_Win;
   TextColor(Yellow);
   GotoXY(01, 01); Write('F1:BlcklÑnge ', 'F5:            ', 'F10:      ');
   GotoXY(01, 02); Write('F2:Start-Adr ', 'F6:            ', 'F11:      ');
   GotoXY(01, 03); Write('F3:          ', 'F7:            ', 'F12: Reset');
   TextColor(Black);
   Set_Text_Win;
  end;

  begin
   Life_Mode.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
   Life_Mode.PosX    := S_Null;        {02;}
   Life_Mode.PosY    := Z_RdCount-1;;        {}
   Life_Mode.Time    := Life_Time_Fast;
   Life_Mode.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}

   Ary_Init;
   Wr_Block_Size := Ary_Max;
   Rd_Block_Size := Ary_Max;
   Wr_Start_Adr  := 1;
   Rd_Start_Adr  := Wr_Start_Adr;
   Block_Count   := 0;
   Block_ErrCnt  := 0;
   Rcv_Count     := 0;
   Rcv_Err_Count := 0;
   Bit_Muster    := Bit_Muster_Def;
   Bit_Muster1   := 0;
   Bit_Muster2   := 0;
   Bit_Muster_Mode := Ary;

   Mil_Ask_Ifc;
   Fct.B.Adr := Ifc_Test_Nr;

   Ini_Text_Win;
   TextColor(Brown);
   GotoXY(20,Z_Basis-2);       Write('Blockmode-Bitmuster-Test fÅr Strahldiagnose-Hardware');
   GotoXY(10,Z_Basis-1);
   TextColor(Blue);            Write('Write zur SD-Hardware wortweise, Read von SD-HW:  ');
   TextColor(White); Write('blockweise'); TextColor(Brown);

   GotoXY(S_Block_Hex,Z_Block-1);   Write('[Hex]');
   GotoXY(S_Block_Dez,Z_Block-1);   Write('[Dez]');

   GotoXY(S_Null,Z_Block);      Write('Block-LÑnge  : ');
   GotoXY(S_Null,Z_Start);      Write('Start-Adr DPR: ');
   GotoXY(S_Null,Z_End);        Write('End-Adresse  : ');
   GotoXY(S_Null, Z_Muster);    Write('BitMuster    : ');

   GotoXY(S_Null, Z_BlkCnt);    Write('WrBlock-Count: ');
   GotoXY(S_Null, Z_BlkCntErr); Write('RdBlockErrCnt: ');

   GotoXY(S_Null+4, Z_Text-1);  Write('Block-');
   GotoXY(S_Null+4, Z_Text);    Write('Rcv-Data-Cnt');

   GotoXY(S_Null+20, Z_Text-1); Write('Total-');
   GotoXY(S_Null+20, Z_Text);   Write('Rcv-Err-Count');

   GotoXY(S_Hex,  Z_Text-1);    Write('Ist-');
   GotoXY(S_Hex,  Z_Text);      Write('Data [Hex]');
   GotoXY(S_Bin,  Z_Text-1);    Write('Soll]');
   GotoXY(S_Bin,  Z_Text);      Write('Data [Hex]');

   Displ_Block_Param;
   Set_Text_Win; TextColor(Brown);
   GotoXY(S_Tast_Min, Z_Tast-3); Write('Belegung Funktions-Tasten:');
   Ini_TastMag_Win;
   Displ_FTasten;
   Set_Text_Win;

                     {Software-Gerippe fÅr Single-Step und Loop}
   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Life_Sign_XY (Life_Mode);
       case Bit_Muster_Mode of
        Ary : Transfer_Block_Ary;
       end;

       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Life_Sign_XY (Life_Mode);
       case Bit_Muster_Mode of
        Ary : Transfer_Block_Ary;
       end;
      end;

     if Ch = #0 then                  {Sonder-Tasten Abfrage}
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    if Read_Int (1,DPR_Max, User_Int) then
                     begin
                       Adr_Max  := User_Int + Wr_Start_Adr;
                       if Adr_Max > DPR_Max then
                        begin
                          Ini_Err_Win;
                          Write('ERROR: BlocklÑnge + Start-Adr unzulÑssig gro· [>',DPR_Max,']');
                          Mil.Timer2_Wait (200000);
                        end
                       else
                        begin
                         Wr_Block_Size := User_Int;
                         Rd_Block_Size := Wr_Block_Size;
                         Displ_Block_Param;
                       end;
                     end;
                     Std_Msg;
                   end;
        Taste_F2 : begin
                    if Read_Int (1, DPR_Max, User_Int) then
                      begin
                        Adr_Max  := User_Int + Wr_Block_Size;
                        if Adr_Max > DPR_Max then
                         begin
                           Ini_Err_Win;
                           Write('ERROR: Start-Adr + BlocklÑnge unzulÑssig gro· [>',DPR_Max,']');
                           Mil.Timer2_Wait (200000);
                         end
                        else
                          Wr_Start_Adr := User_Int;
                        Displ_Block_Param;
                      end;
                     Std_Msg;
                   end;
        Taste_F3 : begin           {2x Bitmuster fix}
                     Bit_Muster_Mode:= Ary;
                     for I := 1 to Ary_Max do Wr_Ary[I] := I;
                     Block_Count   := 0;
                     Block_ErrCnt  := 0;
                     Rcv_Count     := 0;
                     Rcv_Err_Count := 0;
                     Displ_Block_Param;
                   end;
        Taste_F5 : begin
{                    if Ask_Hex_Break (User_Hex, Wrd) then
                      begin
                       Bit_Muster_Mode := Fix;
                       Bit_Muster := User_Hex;
                       Displ_Block_Param;
                       Std_Msg;
                      end;
}                   end;
        Taste_F6 : begin
{                    Ini_Msg_Win;
                    Write ('Es werden nachfolgend 2 Bitmuster in Hex angefordert!  Weiter mit <Space>:');
                    repeat
                     Ch := NewReadKey;
                    until Ch = ' ';

                    if Ask_Hex_Break (User_Hex, Wrd) then
                      begin
                       Bit_Muster1 := User_Hex;
                       if Ask_Hex_Break (User_Hex, Wrd) then
                        begin
                         Bit_Muster2 := User_Hex;
                         Bit_Muster_Mode:= Vari;
                         Displ_Block_Param;
                        end;
                      end;
                    Std_Msg;
}                   end;
        Taste_F7 : begin           {2x Bitmuster fix}
{                     Bit_Muster_Mode:= Vari;
                     Bit_Muster1    := Bit_Muster1_Def;
                     Bit_Muster2    := Bit_Muster2_Def;
                     Displ_Block_Param;
}                   end;

        Taste_F12: begin
                     Mil.Reset;                {Clear Rcv-FIFO}
                     Fct.B.Adr := Ifc_Test_Nr;
                     Fct.B.Fct := Fct_Reset;         {IFK + SD reset}
                     Mil.WrFct (Fct, MilErr);
                     Block_Count   := 0;
                     Block_ErrCnt  := 0;
                     Rcv_Count     := 0;
                     Rcv_Err_Count := 0;

                     Displ_Block_Param;
                     Ini_Err_Win;
                     Write('Reset IFK');
                     Mil.Timer2_Wait (200000);
                     Std_Msg;
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
 end; {SD_DPR_Pattern}

