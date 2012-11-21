PROGRAM Mil_Dtak;
{$S-}
uses Crt, WinDos, Dos, Datech, Datech_0, Datech_1;    {spez. MIL-Routinen in Units Datech..}

const
 Head_Line =
      'BELAB                                MIL_Dtack   ' +
      '                    [15.08.2000]' +
      '                       Universal-Einschub 128Bit FE 675.010                    ';
 procedure menue_win;
  var answer: CHAR;
 begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;            {Festliegender Teil des MenÅs: s. a. DATECH_0.PAS}
  TextColor(Blue);
   {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}
  GotoXY(5, 14);
  Writeln('       [Q]<-- Dtack-test   ');
  GotoXY(5, 15);
  Writeln('                               ');
  GotoXY(5, 16);
  Writeln('                                ');
  GotoXY(5, 17);
  Writeln('                          ');
  GotoXY(5, 18);
  Writeln('        ');
  Ini_Msg_Win;
  Write('Bitte Auswahl eingeben:                                          EXIT: X-Taste ');
 end; {menue_win}
{
Bisherige Routinen f. alle Anwender gleich! Ab hier spezielle User-Routinen
}
const
 Stecker_Max = 16;
 S_Base      = 03;
 S_Base8     = S_Base+10;
 S_OffSet    = 04;
 S_IfkNr     = 15;
 S_RdErr_Id  = 32;
 S_RdErr_Data= 55;
 Z_BaseLo    = 08;
 Z_FTastWin  = 22;

 Z_ID32      = 09;
 Z_Err       = 15;

 S_APK       = 30;
 S_Dtack     = 45;
 S_Out       = 60;

{Gilt nur fÅr OUTREL-Karten: weil nur dann SubAdr 4 und 6 aktiv}
procedure Rd_ID_OUT_Test;   {lese Daten von Hardware}
const MaxCard = 4;
type
 TCardErr  = record
              ApkID : LongInt;
              Dtack : LongInt;
              OutReg: LongInt;
              Err_FcTo     : LongInt;
              Err_RdTo     : LongInt;
              Err_WrTo     : LongInt;
              Err_IoAdr    : LongInt;
              Err_IoAdrMode: LongInt;
             end;

{ TMilErr       = (No_Err, Fc_To, Rd_To, Wr_To, Io_Adr, Io_AdrMode);}

 TRdErrAry = array [1..MaxCard] of TCardErr;
var
    ModAdr: TModAdr;
    MilErr: TMilErr;
    ModData: Word;
    Fct       : TFct;
    RdErrAry  : TRdErrAry;

 procedure Ini_Err_Disp;
  var N : Byte;
  begin
   Ini_Text_Win; TextColor(Blue);
   GotoXY(25,Z_ID32-5);    Write ('  Lese-Test fÅr 128-Bit-IO');
   GotoXY(25,Z_ID32-4);    Write ('4x32-Bit + OUTREL FG 423.260');
   GotoXY(S_APK-3,  Z_ID32-2); Write ('APK-ID');
   GotoXY(S_Dtack-3,Z_ID32-2); Write ('DTACK');
   GotoXY(S_Out-3,  Z_ID32-2); Write ('OUT-REG');

   GotoXY(S_APK-6,  Z_ID32-1); Write ('SubAdr 16+18H');
   GotoXY(S_Dtack-6,Z_ID32-1); Write ('  Fct: CAH');
   GotoXY(S_Out-6,  Z_ID32-1); Write ('SubAdr 04+06');

   GotoXY(S_APK-25, Z_ID32+0);  Write ('32Bit-IO [1]: ');
   GotoXY(S_APK-25, Z_ID32+1);  Write ('32Bit-IO [2]: ');
   GotoXY(S_APK-25, Z_ID32+2);  Write ('32Bit-IO [3]: ');
   GotoXY(S_APK-25, Z_ID32+3);  Write ('32Bit-IO [4]: ');
  end; {Ini_Err_disp}


 procedure Ini_RdErrAry;
  var N : Byte;
  begin
    for N:= 1 to MaxCard do
     begin
        RdErrAry[N].ApkID := 0;
        RdErrAry[N].Dtack := 0;
        RdErrAry[N].OutReg:= 0;
        RdErrAry[N].Err_FcTo     := 0;
        RdErrAry[N].Err_RdTo     := 0;
        RdErrAry[N].Err_WrTo     := 0;
        RdErrAry[N].Err_IoAdr    := 0;
        RdErrAry[N].Err_IoAdrMode:= 0;
     end; {for}
  end;

 procedure Disp_RdErr_Ary;
  var N: Byte;
  begin
   Set_Text_Win;
   TextColor(Red);
   for N := 0 to MaxCard-1 do
    begin  GotoXY(S_APK,   Z_ID32+N);  Write (RdErrAry[N+1].ApkID:8); end;
   for N := 0 to MaxCard-1 do
    begin  GotoXY(S_Dtack, Z_ID32+N);  Write (RdErrAry[N+1].Dtack:8); end;
   for N := 0 to MaxCard-1 do
    begin  GotoXY(S_OUT,   Z_ID32+N);  Write (RdErrAry[N+1].OutReg:8); end;

    N := 1;   {Karte 1}
    GotoXY(S_OUT,   Z_Err+1);   Write (RdErrAry[N].Err_FcTo:8);
    GotoXY(S_OUT,   Z_Err+2);   Write (RdErrAry[N].Err_RdTo:8);
    GotoXY(S_OUT,   Z_Err+3);   Write (RdErrAry[N].Err_WrTo:8);
    GotoXY(S_OUT,   Z_Err+4);   Write (RdErrAry[N].Err_IoAdr:8);
    GotoXY(S_OUT,   Z_Err+5);   Write (RdErrAry[N].Err_IoAdrMode:8);
  end;

 function Check_Dtack_Err: Boolean;
   var  IfkCA_Stat: TIfkCAStat;
        Stat_Data : Word;
   begin
    Check_Dtack_Err:= False;  {Default}
    Fct.B.Adr := Ifc_Test_Nr;
    Fct.B.Fct := Fct_Rd_GlobalStat;   {CA[H]: globaler Status IFK};
    Mil.Rd (Stat_Data, Fct, MilErr);
    IfkCA_Stat.W := Stat_Data;
    if not (Pigy_Dtack_Err in IfkCA_Stat.B)  then   {Dtack-Err ist 0-aktiv}
     begin
       Check_Dtack_Err:= True;
       Fct.B.Fct:= Fct_Clr_DtackErr;       {Bit zurÅcksetzen}
       Mil.WrFct (Fct, MilErr);
     end;
   end;  {Check_Dtack_Err}

 procedure RdIO_Cards;      {wegen Timeout-Fehler geschrieben}
  var I : Byte;
  begin
    for I := 1 to 1 do        {alle vier 32Bit-IO-Karten prÅfen}
     begin
       ModAdr.AdrCard:= I;
       {1.OutRegister rÅcklesen}
       ModAdr.AdrSub := 4;      {RÅcklesreg}
       Mil.Wr_ModBus (ModData, ModAdr, MilErr);
       if Check_Dtack_Err then  RdErrAry[I].Dtack := RdErrAry[I].Dtack + 1;
     end;  {for}
   end; {RdIO_Cards}

 begin
    Ini_RdErrAry;
    ModAdr.AdrIfc := Ifc_Test_Nr;
    ModAdr.AdrMode:= AdrNew;
    Mil.Reset;  {PC-Karte auf definierte Werte}
    Ini_Text_Win;
    Ini_Err_Disp;

    Cursor(False);
    Std_Msg;
    Ch := NewReadKey;
    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       RdIO_Cards;
       Disp_RdErr_Ary;
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;
     if Ch = #13 then Single_Step := False;
     if not Single_Step then
      begin
       RdIO_Cards;
       Disp_RdErr_Ary;
      end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
 { 99:  Cursor(True); }
 end; {Rd_ID_OUT_Test}

begin                      { Hauptprogramm }
  Ifc_Test_Nr := 0;
  Mod_Test_Nr := 0;
  repeat
    Menue_Win;
    User_Input  := NewReadKey;
    Single_Step := True;
    case User_Input of
     {Ab hier User-Erweiterungen!!}
          'm', 'M' : begin
                     end;
          'n', 'N' : begin
                     end;
          'o', 'O' : begin
                       ;
                     end;
          'p', 'P' : begin

                     end;
          'q', 'Q' : begin              {geht nur mit 4 OUTREL-Karten}
                       Mil_Ask_Ifc;
                       Rd_ID_OUT_Test;
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
end. {mil_U128}

