PROGRAM Mil_Gpge;
{ Autor des Basis-Programmes Mil_Base.PAS: G. Englert;      Erstellt 12.04.95
  Basis-Programm als Grundlage fÅr anwender-spezifische Erweiterungen
  Achtung: Bei Erweiterungen den Namen des Programmes Ñndern in MIL_xxxx.PAS

  Autor der Erweiterungen   :
  énderungen:
  14.05.97      ursprÅnglich MIL_EVNT.PAS auf Modulbus Umstellung!!
  12.11.98      Brown als Farbe vermeiden, da ATI-Karten Farbe falsch darstellen!!
  21.12.98      énderung der Bitbelegung u. a. im Hardware-Status usw.
                Das Modiregister ist jetzt rÅcklesbar;
}
{$S-}
uses Crt, WinDos, Dos, Datech, Datech_0, Datech_1;    {spez. MIL-Routinen in Units Datech..}

const
 Head_Line =
      'BELAB                               MIL_GPGE    ' +
      '                    [26.04.2001]' +
      '                           GatePuls-Generator FG450.380                        ';

 procedure menue_win;
  var answer: CHAR;
 begin
  Ini_Headl_Win;
  Write(Head_Line);
  Menue_Base;            {Festliegender Teil des MenÅs: s. a. DATECH_1.PAS}
  TextColor(Blue);

  {Ab hier kann der Anwender seine MenÅ-Punkte eintragen}
  GotoXY(5, 14);
  Writeln('       [M]<-- Software Triggerung                                ');
  GotoXY(5, 15);
  Writeln('       [N]<-- Event    Triggerung                                ');
  GotoXY(5, 16);
  Writeln('       [O]<-- Externe  Triggerung                                ');
  GotoXY(5, 17);
  Writeln('       [P]<-- TIF-1 u. TIF-2 Test                                ');
  GotoXY(5, 18);
  Writeln('       [Q]<-- Set INTR-Maske                                    ');
  GotoXY(5, 19);
  Writeln('       [R]<-- Puls-Mode: Events triggern TIF1- u. TIF2-OUTs als Pulse    ');
{  GotoXY(5, 20);
  Write  ('       [S]<--                                                            ');
  GotoXY(5, 21);
  Write  ('       [T]<--                                                            ');
  GotoXY(5, 22);
  Write  ('       [U]<--                                                            ');
}
  Ini_Msg_Win;
  Write('Bitte Auswahl eingeben:                                           EXIT: X-Taste');
 end; {menue_win}

{
Bisherige Routinen f. alle Anwender gleich! Ab hier spezielle User-Routinen
}

 const
  SubAdr_GpStartCnt_Low = $02;  {Subadr fÅr Gatepuls-Generator}
  SubAdr_GpStartCnt_Hi  = $04;
  SubAdr_GpStopCnt_Low  = $06;
  SubAdr_GpStopCnt_Hi   = $08;
  SubAdr_GpInOut        = $0A;
  SubAdr_GpIntr_Mask    = $0C;

  SubAdr_GpModi         = $0E;
  SubAdr_GpEnable       = $10;
  SubAdr_GpMask_StartEvt= $12;
  SubAdr_GpMask_StopEvt = $14;
  SubAdr_GpMask_Evt1    = $16;
  SubAdr_GpMask_Evt2    = $18;

  SubAdr_GpPuls1_EinEvt = $12;    {speziell fÅr Doppelpuls-Mode; ab EPLD Version 4}
  SubAdr_GpPuls1_AusEvt = $14;
  SubAdr_GpPuls2_EinEvt = $16;
  SubAdr_GpPuls2_AusEvt = $18;

  SubAdr_GpSoftTrig     = $1A;
  SubAdr_GpSoftReset    = $1C;
  SubAdr_GpHw_Stat      = $20;
  SubAdr_GpDyn_Stat     = $22;

 type
  TCounter   = record case Byte of
                 1: (W: packed record
                          lwr: Word;
                          upr: Word
                         end; );

                 2: (L: LongInt);
               end;


  TGpDynStat = record case Byte of
                1: (Bit: set of
                       (GpAktiv,       {Bit 0}
                        Err2Trig,
                        ErrStartLate,
                        GpPwrup,
                        Frei_4,
                        Frei_5,
                        ExtStat6,
                        ExtStat7,      {Bit 7}
                        GpEnable,      {Bit 8}
                        WaitTrig,
                        WaitGp,
                        EnInt,         {Bit 11}
                        EnStartEvt,
                        EnStopEvt,
                        EnTif1Evt,
                        EnTif2Evt);    {Bit 15}
                    );
                2: (Wrd: WORD;);
             end;
{
}
  TGpStatReg = record case Byte of
              1: (Bit: set of
                     (ExtStat12,   {Bit 0}
                      ExtStat13,
                      ExtStat14,
                      ExtStat15,
                      SpezOszi,    {Bit 04}
                      Frei_05,
                      Frei_06,
                      Frei_07,
                      Frei_08,
                      Frei_09,
                      Frei_10,
                      Frei_11,
                      Frei_12,
                      Frei_13,
                      Frei_14,
                      Frei_15)
                  );
              2: (Wrd: WORD;);
           end;

  TGpModi = record case Byte of
              1: (Bit: set of
                     (TrigSrc0,          {Bit 0}
                      TrigSrc1,
                      TransMode,
                      RepMode,
                      ExTrig,
                      ExOut,
                      EntPrell,
                      PulsMode,        {Bit 7}
                      EvtMask_GpStart0,  {Bit 08}  {8-, 12-, 16-Bit aktiv}
                      EvtMask_GpStart1,
                      EvtMask_GpStop0,   {Bit 10}
                      EvtMask_GpStop1,
                      EvtMask_Tif1_0,    {Bit 12}
                      EvtMask_Tif1_1,
                      EvtMask_Tif2_0,    {Bit 14}
                      EvtMask_Tif2_1)
                  );
              2: (Wrd: WORD;);
           end;
  TGpEnable = record case Byte of
              1: (Bit: set of
                     (Gp_En,        {Bit 0}
                      Frei1_En,
                      Intr_En,
                      Frei3_En,
                      StartEvt_En,
                      StopEvt_En,
                      Tif1Evt_En,
                      Tif2Evt_En,   {Bit 7}

                      Frei8_En,     {Bit 8}
                      Frei9_En,
                      Frei10_En,
                      Frei11_En,    {Bit 11}
                      Frei12_En,
                      Frei13_En,
                      Frei14_En,
                      Frei15_En);   {Bit 15}
                  );
              2: (Wrd: WORD;);
           end;

 const
  S_Begin_EvtWin = 50;
  Z_Begin_EvtWin = 8;
  S_Ende_EvtWin  = 80;
  Z_Ende_EvtWin  = 24;

  Gp_Quarz_Faktor = 50;  {Start- u. Stop-Counter werden mit 50 Mhz betrieben}
                         {da die Eingabe in us ist, mu· entsprechend korrigiert werden}
  Count_Max     = $7FFFFFFF;
  Z_Base        = 3;
  S_Base        = 3;
  Z_ModAdr      = Z_Base;

  Z_Mask_Text   = Z_Base+3;
  Z_Evt_Start   = Z_Mask_Text+1;
  Z_Evt_Stop    = Z_Mask_Text+2;
  S_Trigger     = S_Base+17;
  S_Mask        = S_Base+27;

  Z_HwStat_Hex  = Z_Base+10;
  Z_HwStat_Bin  = Z_HwStat_Hex+1;
  Z_DynStat_Bin = Z_HwStat_Bin+1;
  Z_ModReg_Bin  = Z_DynStat_Bin+1;
  Z_Input       = Z_Base+3;
  Z_Output      = Z_Input+1;
  Z_StartCount  = Z_Base+7;
  Z_StopCount   = Z_StartCount+1;

  Z_Out         = Z_Base+1;
{  Z_In          = Z_Base-0; }
  Z_In          = Z_Base+1;
  Z_Single      = Z_Base-1;
  Z_Intr        = Z_Base;
  Z_Out_Text    = Z_Base+1;

  S_MaskCnt     = 33;
  S_ModAdr      = S_Base+14;
  S_Count_Int   = S_Base+16;
  S_Single_Rep  = S_Base+25;
  S_Output      = S_Single_Rep+3;
  S_Intr        = S_Base+25;

 type
  TDia_Mode = (PulsMod,IndepSw,IndepExt,IndepEvt,TranspExt,TranspEvt,NoTrigSrc,Error);
  TPuls_Mode= (EnAll, DisAll, EnPuls1, EnPuls2, DisPuls1, DisPuls2);

 var                       {Globale Variablen}
  Life_Mode  : TLife_XY;
  ModAdr     : TModAdr;
  MilErr     : TMilErr;
  GpStatReg  : TGpStatReg;
  GpDynStat  : TGpDynStat;
  GpModi     : TGpModi;
  TIF_Test   : Boolean;
  Intr_Test  : Boolean;
  Puls_Mode  : Boolean;

  procedure Change_Mode_2Puls (Puls_Mode: TPuls_Mode);
   var
    GpMod_Modi:  TGpModi;
    GpMod_En  :  TGpEnable;
   begin
     ModAdr.AdrIfc  := Ifc_Test_Nr;    {Modi-Status rÅcklesen}
     ModAdr.AdrCard := Mod_Test_Nr;
     ModAdr.AdrMode := AdrNew;
     ModAdr.AdrSub  := SubAdr_GpModi;  {SubAdr_GpHw_Stat}
     Mil.Rd_ModBus (GpMod_Modi.Wrd, ModAdr, MilErr);     {Modi-Status lesen}
     if MilErr = No_Err then
      begin     {statt clear: den alten Zustand erhalten}
        GpMod_En.Bit  := [];  {Clear}
        GpMod_Modi.Bit:= [];  {Clear; Evt-Masken auf 16-Bit Vergleich}
        GpMod_Modi.Bit:= GpMod_Modi.Bit + [PulsMode]; {Double Mode}
        GpMod_Modi.Bit:= GpMod_Modi.Bit + [TrigSrc0];   {Evt-Triggerung}
        GpMod_Modi.Bit:= GpMod_Modi.Bit + [TrigSrc1];   {   2Bit Code  }
        ModAdr.AdrSub := SubAdr_GpModi;       {neuen Mode zur Hardware}
        Mil.Wr_ModBus (GpMod_Modi.Wrd, ModAdr, MilErr);

        case Puls_Mode of
         EnAll : begin
                  GpMod_En.Bit  := GpMod_En.Bit  + [Tif2Evt_En];
                  GpMod_En.Bit  := GpMod_En.Bit  + [Tif1Evt_En];
                  GpMod_En.Bit  := GpMod_En.Bit  + [StopEvt_En];
                  GpMod_En.Bit  := GpMod_En.Bit  + [StartEvt_En];
                 end;
          DisAll: begin
                  GpMod_En.Bit  := GpMod_En.Bit  - [StartEvt_En];
                  GpMod_En.Bit  := GpMod_En.Bit  - [StopEvt_En];
                  GpMod_En.Bit  := GpMod_En.Bit  - [Tif1Evt_En];
                  GpMod_En.Bit  := GpMod_En.Bit  - [Tif2Evt_En];
                 end;
         EnPuls1: begin
                  GpMod_En.Bit  := GpMod_En.Bit  + [StartEvt_En];
                  GpMod_En.Bit  := GpMod_En.Bit  + [StopEvt_En];
                 end;
         EnPuls2: begin
                  GpMod_En.Bit  := GpMod_En.Bit  + [Tif1Evt_En];
                  GpMod_En.Bit  := GpMod_En.Bit  + [Tif2Evt_En];
                 end;
        end; {case}

       ModAdr.AdrSub := SubAdr_GpEnable; {EnableReg ist ein Write-Only Register!!}
       Mil.Wr_ModBus (GpMod_En .Wrd, ModAdr, MilErr);
      end; {if}
   end; {Change_Mode_2Puls}

  procedure Change_Mode (Mode_Letter: Char);
   var
    GpMod_Modi:  TGpModi;
    GpMod_En  :  TGpEnable;
   begin                 {bisherige Modi erhalten, Ñndere nur die gewÅnschten}
     ModAdr.AdrIfc  := Ifc_Test_Nr;    {Modi-Status rÅcklesen}
     ModAdr.AdrCard := Mod_Test_Nr;
     ModAdr.AdrMode := AdrNew;
     ModAdr.AdrSub  := SubAdr_GpModi;  {SubAdr_GpHw_Stat}
     Mil.Rd_ModBus (GpMod_Modi.Wrd, ModAdr, MilErr);     {Modi-Status lesen}
     if MilErr = No_Err then
      begin
        if Mode_Letter in ['A'..'D','G'] then              {neuen Mode einstellen}
          begin
            case Mode_Letter of
             'A': GpMod_Modi.Bit:= GpMod_Modi.Bit - [TransMode];  {Indep  Mode}
             'B': GpMod_Modi.Bit:= GpMod_Modi.Bit + [TransMode];  {Transp Mode}
             'C': GpMod_Modi.Bit:= GpMod_Modi.Bit - [RepMode];    {Single Mode}
             'D': GpMod_Modi.Bit:= GpMod_Modi.Bit + [RepMode];    {Repeat Mode}
             'G': GpMod_Modi.Bit:= GpMod_Modi.Bit + [PulsMode]; {Double Mode}
            end; {case}
           ModAdr.AdrSub := SubAdr_GpModi;           {neuen Mode zur Hardware}
           Mil.Wr_ModBus (GpMod_Modi.Wrd, ModAdr, MilErr);
           Exit;                                    {Diese Aktion ist beendet}
          end; {if Mode_Letter A--D}

        if Mode_Letter in ['E'..'Z'] then
          begin                          {Beachten->Modi-Status schon gelesen}
            ModAdr.AdrSub  := SubAdr_GpDyn_Stat;
            Mil.Rd_ModBus (GpDynStat.Wrd, ModAdr, MilErr);      {Dynam. Status lesen}
            if MilErr = No_Err then
             begin
               GpMod_En.Bit := [];  {Clear}
               case Mode_Letter of
                {G wurde oben schon vergeben!!}
                'E': begin      {autom. Triggerquelle auf Event-Triggerung !!}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit + [TrigSrc0]; {Evt-Triggerung}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit + [TrigSrc1];

                      GpMod_En.Bit  := GpMod_En.Bit  + [Gp_En];     {Enable Gp}
                      GpMod_En.Bit  := GpMod_En.Bit  + [StartEvt_En];
                      if TransMode in GpMod_Modi.Bit then GpMod_En.Bit:= GpMod_En.Bit+[StopEvt_En];
                     end; {case E}
                'F': begin    {autom. Trig.quelle auf: Kein Triggerung}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [TrigSrc0]; {keine Triggerung}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [TrigSrc1];

                      GpMod_En.Bit  := GpMod_En.Bit  - [Gp_En];     {Enable Gp}
                      GpMod_En.Bit  := GpMod_En.Bit  - [StartEvt_En];
                      if TransMode in GpMod_Modi.Bit then GpMod_En.Bit:= GpMod_En.Bit+[StopEvt_En];
                     end; {case F}
               'I': begin {Interrupt Toggle: alten Enable Status erhalten}
                      if GpEnable    in GpDynStat.Bit then GpMod_En.Bit := GpMod_En.Bit+[Gp_En];
                      if EnStartEvt  in GpDynStat.Bit then GpMod_En.Bit := GpMod_En.Bit+[StartEvt_En];
                      if EnStopEvt   in GpDynStat.Bit then GpMod_En.Bit := GpMod_En.Bit+[StopEvt_En];
                      if EnTif1Evt   in GpDynStat.Bit then GpMod_En.Bit := GpMod_En.Bit+[Tif1Evt_En];
                      if EnTif2Evt   in GpDynStat.Bit then GpMod_En.Bit := GpMod_En.Bit+[Tif2Evt_En];
                                     {Toggle}
                      if EnInt       in GpDynStat.Bit then GpMod_En.Bit := GpMod_En.Bit - [Intr_En]
                      else GpMod_En.Bit := GpMod_En.Bit + [Intr_En]
                     end; {case I}

                'K': begin    {Alten Status von TIF2 erhalten!!}
                      if EnTif2Evt in GpDynStat.Bit then GpMod_En.Bit:= GpMod_En.Bit+[Tif2Evt_En];
                      GpMod_En.Bit  := GpMod_En.Bit + [Tif1Evt_En];
                     end; {case K}
                'L': begin
                      if EnTif2Evt in GpDynStat.Bit then GpMod_En.Bit:= GpMod_En.Bit+[Tif2Evt_En];
                      GpMod_En.Bit  := GpMod_En.Bit - [Tif1Evt_En];
                     end; {case L}
                'M': begin
                      if EnTif1Evt in GpDynStat.Bit then GpMod_En.Bit:= GpMod_En.Bit+[Tif1Evt_En];
                      GpMod_En.Bit  := GpMod_En.Bit + [Tif2Evt_En];
                     end; {case M}
                'N': begin
                      if EnTif1Evt in GpDynStat.Bit then GpMod_En.Bit:= GpMod_En.Bit+[Tif1Evt_En];
                      GpMod_En.Bit  := GpMod_En.Bit - [Tif2Evt_En];
                     end; {case N}

                'O': begin                      {08-Bit aktiv fÅr GP-Start-Event}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_GpStart0];
                      GpMod_Modi.Bit:= GpMod_Modi.Bit + [EvtMask_GpStart1];
                     end; {case O}
                'P': begin                      {12-Bit aktiv fÅr GP-Start-Event}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit + [EvtMask_GpStart0];
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_GpStart1];
                     end; {case P}
                'Q': begin                      {16-Bit aktiv fÅr GP-Start-Event}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_GpStart0];
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_GpStart1];
                     end; {case Q}

                'R': begin                      {08-Bit aktiv fÅr GP-Stop-Event}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_GpStop0];
                      GpMod_Modi.Bit:= GpMod_Modi.Bit + [EvtMask_GpStop1];
                     end; {case R}
                'S': begin                      {12-Bit aktiv fÅr GP-Stop-Event}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit + [EvtMask_GpStop0];
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_GpStop1];
                     end; {case S}
                'T': begin                      {16-Bit aktiv fÅr GP-Stop-Event}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_GpStop0];
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_GpStop1];
                     end; {case T}

                'U': begin                       {08-Bit aktiv fÅr TIF1-Event}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_TIF1_0];
                      GpMod_Modi.Bit:= GpMod_Modi.Bit + [EvtMask_TIF1_1];
                     end; {case R}
                'V': begin                      {12-Bit aktiv fÅr TIF1-Event}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit + [EvtMask_TIF1_0];
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_TIF1_1];
                     end; {case P}
                'W': begin                      {16-Bit aktiv fÅr TIF1-Event}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_TIF1_0];
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_TIF1_1];
                     end; {case Q}

                'X': begin                       {08-Bit aktiv fÅr TIF2-Event}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_TIF2_0];
                      GpMod_Modi.Bit:= GpMod_Modi.Bit + [EvtMask_TIF2_1];
                     end; {case X}
                'Y': begin                      {12-Bit aktiv fÅr TIF2-Event}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit + [EvtMask_TIF2_0];
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_TIF2_1];
                     end; {case Y}
                'Z': begin                      {16-Bit aktiv fÅr TIF2-Event}
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_TIF2_0];
                      GpMod_Modi.Bit:= GpMod_Modi.Bit - [EvtMask_TIF2_1];
                     end; {case Z}
               end; {case}
              ModAdr.AdrSub := SubAdr_GpModi;        {neuen Mode zur Hardware}
              Mil.Wr_ModBus (GpMod_Modi.Wrd, ModAdr, MilErr);
              ModAdr.AdrSub := SubAdr_GpEnable;     {neues Enable zur Hardware}
              Mil.Wr_ModBus (GpMod_En .Wrd, ModAdr, MilErr);
            end; {if MilErr Dyn. Status}
          end; {if Mode_Letter E..I}
      end; {if MilErr Status Read}
   end; {Change_Mode}

 procedure WriteEvt_To_Milbus (Evt_Data: Word);
  var Fct: TFct;
  begin
   Fct.W   := Evt_Data;
   Mil.WrFct (Fct, MilErr); {Daten werden im Command-Mode gesendet}
  end;

 procedure Displ_Puls_Diagramm (Dia_Mode: TDia_Mode);
  const Z_Dia_Start = Z_Base-1;
        Z_Dia_Stop  = Z_Dia_Start +1;
        S_Dia       = 50;
        S_Dia_Mode  = S_Dia+16;
  begin
    Set_Text_Win;
    GotoXY(S_Dia,Z_Dia_Start-1); TextColor(Red);

    if TIF_Test then
     begin
      GotoXY(S_Dia,Z_Dia_Start-1);  ClrEol;
      GotoXY(S_Dia,Z_Dia_Start);    ClrEol;
      GotoXY(S_Dia,Z_Dia_Stop);     ClrEol;
      GotoXY(S_Dia,Z_Dia_Stop+1);   ClrEol;
      Exit;
     end;

    case Dia_Mode of
     PulsMod:
        begin
         Write('Puls-Mode ');      TextColor(Yellow);
         Write (' ',chr($19),'EinEvt','   ', chr($19), 'AusEvt');
         GotoXY(S_Dia,Z_Dia_Start);    Write ('Puls1 -> ');  TextColor(Yellow);
         Write(' _',chr($A9),'---------', chr($AA),'_'); ClrEol;
         GotoXY(S_Dia,Z_Dia_Stop);  TextColor(Blue);
         Write('         ');
         Write (' ',chr($19),'EinEvt','      ', chr($19), 'AusEvt');
         GotoXY(S_Dia,Z_Dia_Stop+1);   Write ('Puls2 -> ');
         Write('_',chr($A9),'------------', chr($AA),'_'); ClrEol;   TextColor(Blue);
        end;

     IndepSw:
        begin
          Write('Indep-Mode ');                                TextColor(Yellow);
          Write('   ', chr($19),'SoftTrig');  ClrEol;          TextcOlor(Blue);
          GotoXY(S_Dia,Z_Dia_Start);  Write ('Start_Cnt -> '); TextColor(Yellow);
          Write('_',chr($A9),'----',chr($AA),'_');  ClrEol;    TextColor(Blue);
          GotoXY(S_Dia,Z_Dia_Stop);   Write ('Stop_Cnt  -> '); TextColor(Yellow);
          Write('_',chr($A9),'-------',chr($AA),'_');  ClrEol; TextColor(Blue);
          GotoXY(S_Dia,Z_Dia_Stop+1); Write ('GatePuls  -> '); TextColor(Yellow);
          Write('_______',chr($A9),'-',chr($AA),'_');  ClrEol;
        end;
     IndepExt:
        begin
         Write('Indep-Mode   ');                              TextColor(Yellow);
         Write('_',chr($A9),'',chr($AA),'_','    ', chr($1B),'ext.Trig'); ClrEol;    TextColor(Blue);
         GotoXY(S_Dia,Z_Dia_Start);  Write ('Start_Cnt -> '); TextColor(Yellow);
         Write('_',chr($A9),'---',chr($AA),'_'); ClrEol;      TextColor(Blue);
         GotoXY(S_Dia,Z_Dia_Stop);   Write ('Stop_Cnt  -> '); TextColor(Yellow);
         Write('_',chr($A9),'--------',chr($AA),'_'); ClrEol; TextColor(Blue);
         GotoXY(S_Dia,Z_Dia_Stop+1); Write ('GatePuls  -> '); TextColor(Yellow);
         Write('______',chr($A9),'---',chr($AA),'_'); ClrEol;
        end;
     IndepEvt:
        begin
         Write('Indep Mode ');                                TextColor(Yellow);
         Write ('   ',chr($19),'StartEvt');  ClrEol;          TextcOlor(Blue);
         GotoXY(S_Dia,Z_Dia_Start);  Write ('Start_Cnt -> '); TextColor(Yellow);
         Write('_',chr($A9),'--',chr($AA),'_'); ClrEol;       TextColor(Blue);
         GotoXY(S_Dia,Z_Dia_Stop);   Write ('Stop_Cnt  -> '); TextColor(Yellow);
         Write('_',chr($A9),'------',chr($AA),'_');  ClrEol;  TextColor(Blue);
         GotoXY(S_Dia,Z_Dia_Stop+1); Write ('GatePuls  -> '); TextColor(Yellow);
         Write('_____',chr($A9),'--',chr($AA),'_');  ClrEol;
        end;
     TranspExt:
        begin
         Write('Transp-Mode  ');   TextColor(Yellow);
         Write('_',chr($A9),'--',chr($AA),'_');
         Write('  ', chr($1B),'ext.Trig'); ClrEol;            TextcOlor(Blue);
         GotoXY(S_Dia,Z_Dia_Start);  Write ('Start_Cnt -> '); TextColor(Yellow);
         Write('_',chr($A9),'-----',chr($AA),'_'); ClrEol;    TextColor(Blue);
         GotoXY(S_Dia,Z_Dia_Stop);   Write ('Stop_Cnt  -> '); TextColor(Yellow);
         Write('_____',chr($A9),'------',chr($AA),'_');ClrEol;TextColor(Blue);
         GotoXY(S_Dia,Z_Dia_Stop+1); Write ('GatePuls  -> '); TextColor(Yellow);
         Write('_______',chr($A9),'----',chr($AA),'_'); ClrEol;
        end;
     TranspEvt:
        begin
         Write('Transp-Mode');      TextColor(Yellow);
         Write ('  ',chr($19),'StaEvt','   ', chr($19), 'StopEvt');  TextcOlor(Blue);
         GotoXY(S_Dia,Z_Dia_Start);  Write ('Start_Cnt ->');         TextColor(Yellow);
         Write('_',chr($A9),'----',chr($AA),'__________'); ClrEol;   TextColor(Blue);
         GotoXY(S_Dia,Z_Dia_Stop);   Write ('Stop_Cnt  ->');         TextColor(Yellow);
         Write('___________',chr($A9),'---',chr($AA),'_'); ClrEol;   TextColor(Blue);
         GotoXY(S_Dia,Z_Dia_Stop+1); Write ('GatePuls  ->');         TextColor(Yellow);
         Write('_______',chr($A9),'-------',chr($AA),'_'); ClrEol;
        end;
     Error:
        begin
         Write('Transp-Mode');  ClrEol;  TextColor(Yellow);
         GotoXY(S_Dia,Z_Dia_Start);
         Write('In diesem Mode keine Software'); ClrEol;
         GotoXY(S_Dia,Z_Dia_Stop);
         Write('Triggerung mîglich oder ');      ClrEol;
         GotoXY(S_Dia,Z_Dia_Stop+1);
         Write('MIL-Lesefehler!!');              ClrEol;
        end;
     NoTrigSrc:
        begin
         GotoXY(S_Dia,Z_Dia_Start-1);  ClrEol;
         Write('Achtung:  '); TextColor(Yellow);
         GotoXY(S_Dia,Z_Dia_Start);        ClrEol;
         Write('Keine Triggerquelle definiert!!');
         GotoXY(S_Dia,Z_Dia_Stop);         ClrEol;
         GotoXY(S_Dia,Z_Dia_Stop+1);       ClrEol;
        end;
    end; {case}
  end; {Displ_Puls_Diagramm}


  procedure Show_HwStat_Reg;  {Show_Stat_Reg}
   var Bit16_Strg : Str19;
       Read_Data  : Word;
       GpModi     : TGpModi;
       Trig_Mode  : Word;
       MilErr      : TMilErr;
       Fct         : TFct;
    begin
     Trig_Mode         := 0;
     Life_Mode.PosX    := S_Base-1;
     Life_Mode.PosY    := Z_HwStat_Hex;
     Life_Mode.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
     Life_Mode.Time    := Life_Time_Super;
     Life_Mode.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}
     Life_Sign_XY (Life_Mode);

     Set_Text_Win;
     ModAdr.AdrIfc  := Ifc_Test_Nr;
     ModAdr.AdrCard := Mod_Test_Nr;
     ModAdr.AdrSub  := SubAdr_GpHw_Stat;
     ModAdr.AdrMode := AdrNew;
     Mil.Rd_ModBus (Read_Data, ModAdr, MilErr);
     if MilErr = No_Err then
      begin
        GotoXY(28, Z_HwStat_Hex);  write(hex_word(read_data));
        Hex_Bin_Str (read_data, bit16_strg);
        GotoXY(S_ModAdr+5, Z_HwStat_Bin);  write(bit16_strg);
        {Modi-Reg neuerdings rÅcklesbar!!}
        ModAdr.AdrSub  := SubAdr_GpModi;
        ModAdr.AdrMode := AdrNew;
        Mil.Rd_ModBus (Read_Data, ModAdr, MilErr);
        GpModi.Wrd := Read_Data;

        if TrigSrc0  in GpModi.Bit then Trig_Mode:= 01;
        if TrigSrc1  in GpModi.Bit then Trig_Mode:=BitSet(Trig_Mode,01);
        if TransMode in GpModi.Bit then
         begin                                {TranspMode}
          case Trig_Mode of
            00: Displ_Puls_Diagramm (NoTrigSrc);
            01: Displ_Puls_Diagramm (TranspExt);
            02: Displ_Puls_Diagramm (Error);
            03: Displ_Puls_Diagramm (TranspEvt);
          end; {case}
        end
        else
         begin                                {IndepMode}
          case Trig_Mode of
            00: Displ_Puls_Diagramm (NoTrigSrc);
            01: Displ_Puls_Diagramm (IndepExt);
            02: Displ_Puls_Diagramm (IndepSw);
            03: Displ_Puls_Diagramm (IndepEvt);
          end; {case}
         end; {if Transp}

        if not Puls_Mode then
         begin
           GotoXY(S_Single_Rep, Z_Single);  TextColor(Black);
           if RepMode in GpModi.Bit then
             Write ('R')
            else
             Write ('S');
         end;

        if Intr_Test then
         begin
          GotoXY(S_Intr, Z_Intr);  TextColor(Black);
          {lese C9-Status, Bit 11: Drdy, 0-Aktiv}
          Fct.B.Adr := Ifc_Test_Nr;
          Fct.B.Fct := Fct_Rd_Status;   {Wegen Update FG380.203: jetzt erst Statuslesen}
          Mil.Rd (Read_Data, Fct, MilErr);
          if BitTst (Read_Data,11) then
           Write ('inaktiv')
          else
           Write ('aktiv  ');
        end;
      end
     else
      begin
        GotoXY(28, Z_HwStat_Hex);         write('    ');
        GotoXY(S_Intr, Z_Intr);           write('?      ');  TextColor (Red);
        GotoXY(S_ModAdr+5, Z_HwStat_Bin); write('   Read Error!!    ');
        Displ_Puls_Diagramm (Error);
      end;
     if Puls_Mode then Displ_Puls_Diagramm (PulsMod); {Zeige Diagramm, egal was vorher war}
    end; {Show_Stat_Reg}

  procedure Show_DynStat_Reg;
   var Bit16_Strg: Str19;
       Read_Data : Word;
    begin
     Life_Mode.Mode    := Norm;      {Parameter fÅr Lebenszeichen definieren}
     Life_Mode.PosX    := S_Base-1;
     Life_Mode.PosY    := Z_DynStat_Bin;
     Life_Mode.Time    := Life_Time_Super;
     Life_Mode.Disp_Win:= Set_Text_Win; {Darstellungs-Fenster}
     Life_Sign_XY (Life_Mode);

     Set_Text_Win;
     ModAdr.AdrIfc  := Ifc_Test_Nr;
     ModAdr.AdrCard := Mod_Test_Nr;
     ModAdr.AdrSub  := SubAdr_GpDyn_Stat;
     ModAdr.AdrMode := AdrNew;

     Mil.Rd_ModBus (Read_Data, ModAdr, MilErr);
     if MilErr = No_Err then
      begin
        Hex_Bin_Str (read_data, bit16_strg);
        GotoXY(S_ModAdr+5, Z_DynStat_Bin);  write(bit16_strg);
      end
     else
      begin
        TextColor (Red);
        GotoXY(S_ModAdr+5, Z_DynStat_Bin);  write('   Read Error!!    ');
        TextColor (Black);
      end;
    end; {show_dyn_reg; }


 procedure Ini_Event_Win;
  begin
   Window(S_Begin_EvtWin, Z_Begin_EvtWin, S_Ende_EvtWin, Z_Ende_EvtWin);
   TextBackground(Cyan);
   TextColor(Blue);               {Setze Schriftfarbe}
   ClrScr;
  end;

 procedure Displ_Modul_Stat;
  begin
     {Info-Anzeige der Bit-Belegung IFC-Status}
      Set_Text_Win;
      GotoXY(S_Begin_EvtWin,Z_Begin_EvtWin-3); TextColor(Yellow); Write (chr($19)); TextColor(Red);
      Write ('Hardw.Status   '); TextColor(Yellow); Write (chr($19)); {Pfeil nach unten} TextColor(Red);
      Write ('Dyn.Status');
      Ini_Event_Win;           {v- Dyn. Status}
      writeln('15: Frei      | TIF2  Evt En  ');
      writeln('14: Frei      | TIF1  Evt En  ');
      writeln('13: Frei      | Stop  Evt En  ');
      writeln('12: Frei      | Start Evt En  ');
      writeln('11: Frei      | Intr En (DRDY)');
      writeln('10: Frei      | Wait for GPuls');
      writeln('09: Frei      | Wait for Trig ');
      writeln('08: Frei      | Enabl Gatepuls'); TextColor(Yellow);
      writeln(' >Alle 16Bit: "1" Darstellung<'); TextColor(Blue);
      writeln('07:           | Ext In 7 (Dyn)');
      writeln('06: Frei      | Ext In 6 (Dyn)');
      writeln('05: Frei      | Frei          ');
      writeln('04: Spez-Oszi | Frei          ');
      writeln('03: ExtStat15 | Err Mask Pwrup');
      writeln('02: ExtStat14 | Err Start>Stop');
      writeln('01| ExtStat13 | Err 2. Trigger');
      write  ('00| ExtStat12 | Gatepuls aktiv');
   end; {Displ_Mod_Stat}

 procedure Displ_Modi_Win;
  begin
     {Info-Anzeige der Bit-Belegung IFC-Status}
      Set_Text_Win;
      GotoXY(S_Begin_EvtWin,Z_Begin_EvtWin-3); TextColor(Yellow); Write (chr($19)); {Pfeil nach unten} TextColor(blue);
      Write ('Belegung Modi-Register:     ');
      Ini_Event_Win;
      writeln('15: TIF2-Event  Bits     00=16');
      writeln('14:   |aktiv       01=12 10= 8');
      writeln('13: TIF1-Event  Bits     00=16');
      writeln('12:   |aktiv       01=12 10= 8');
      writeln('11: Gp Stop-Evt Bits     00=16');
      writeln('10:   |aktiv       01=12 10= 8');
      writeln('09: Gp Start-Evt Bits    00=16');
      writeln('08:   |aktiv       01=12 10= 8');
      writeln('                              ');
      writeln('07: 1= zweifach Pulsmode      ');
      writeln('06: Frei                      ');
      writeln('05: 0=Ext. Output  pos. Logik ');
      writeln('04: 0=Ext. IN-Trig pos. Logik ');
      writeln('03: 0=Single  1=Repeat Mode   ');
      writeln('02: 0=IndpMod 1=TransparentMod');
      writeln('01: |00=kein  10=Soft  Trigger');
      write  ('00: |01=ext.  11=Event Trigger');
   end; {Displ_Mod_Stat}

 procedure Displ_ModiSelect_Win;
  begin
      Set_Text_Win;
      GotoXY(S_Begin_EvtWin,Z_Begin_EvtWin-3); TextColor(Yellow); Write (chr($19)); {Pfeil nach unten} TextColor(Red);
      Write ('Wahl der GP-Generator Modi: ');
      Ini_Event_Win; TextColor(Red);
      Write  ('A');  TextColor(Blue); writeln(': Independent-Mode          '); TextColor(Red);
      Write  ('B');  TextColor(Blue); writeln(': Transparent-Mode          '); TextColor(Red);
      Write  ('C');  TextColor(Blue); writeln(': Single Gatepuls           '); TextColor(Red);
      Write  ('D');  TextColor(Blue); writeln(': Repeat    "               '); TextColor(Red);
      Write  ('G');  TextColor(Blue); writeln(': 2-fach-Puls Mode          '); TextColor(Red);

      Write  ('E');  TextColor(Blue); write  (': Evt En [EvTrig,Gp,Strt,Stop]'); TextColor(Red);
      Write  ('F');  TextColor(Blue); writeln(':  "  Disable                '); TextColor(Red);
      Write  ('K');  TextColor(Blue); writeln(': TIF-1 Enable               '); TextColor(Red);
      Write  ('L');  TextColor(Blue); writeln(':  "    Disable              '); TextColor(Red);
      Write  ('M');  TextColor(Blue); writeln(': TIF-2 Enable               '); TextColor(Red);
      Write  ('N');  TextColor(Blue); writeln(':  "    Disable              '); TextColor(Red);
      writeln('                              '); TextColor(Yellow);
      write  ('-- Anzahl aktiver Event-Bits --'); TextColor(Blue);
      write  ('GpStartEvt ');  TextColor(Red); Write('O'); TextColor(Blue);
               Write(':8  ');  TextColor(Red); write('P'); TextColor(Blue);
               Write(':12  '); TextColor(Red); write('Q'); TextColor(Blue);  Writeln(':16 Bit'); TextColor(Blue);

      write  ('GpStopEvt  ');  TextColor(Red); Write('R'); TextColor(Blue);
               Write(':8  ');  TextColor(Red); write('S'); TextColor(Blue);
               Write(':12  '); TextColor(Red); write('T'); TextColor(Blue);  Writeln(':16 Bit'); TextColor(Blue);

      write  ('TIF-1 Evt  ');  TextColor(Red); Write('U'); TextColor(Blue);
               Write(':8  ');  TextColor(Red); write('V'); TextColor(Blue);
               Write(':12  '); TextColor(Red); write('W'); TextColor(Blue);  Writeln(':16 Bit'); TextColor(Blue);

      write  ('TIF-2 Evt  ');  TextColor(Red); Write('X'); TextColor(Blue);
               Write(':8  ');  TextColor(Red); write('Y'); TextColor(Blue);
               Write(':12  '); TextColor(Red); write('Z'); TextColor(Blue);  Write  (':16 Bit'); TextColor(Blue);
   end; {Displ_ModiSelect_Win}


 procedure Displ_Event_Win;
  begin
      Set_Text_Win;
      GotoXY(S_Begin_EvtWin,Z_Begin_EvtWin-3); TextColor(Yellow); Write (chr($19)); {Pfeil nach unten} TextColor(Red);
      Write ('Hinweis zur Event-Eingabe:  ');
      Ini_Event_Win;
      writeln('Die Eingabe fÅr Start- u. Stop');
      write  ('Event-Maske [=auf welche Events');
      write  ('getriggert werden soll] erfolgt');
      writeln('als 16-Bit Wort. Wirksam sind ');
      writeln('je nach gewÑhltem Mode jedoch ');
      writeln('nur 8-, 12- oder 16 Bit.      ');
      writeln('Test-Events kann man erzeugen ');
      writeln('mit 2. PC + Softw MIL_TIF.    ');
      writeln('Dazu braucht man Karte DTUB   ');
      writeln('(FX195060). Alternativ: DTUB  ');
      writeln('am gleichen MIL-Bus wie IFK ->');
      writeln('die F-Tasten F3/F4 erzeugen   ');
      write  ('dann Trig-Events Start u. Stop.');
      writeln('Achtung: Die Events erscheinen');
      writeln('als Command-Wort auf MILBus.  ');
      writeln('Ist L-Byte=IFK-Adr ->Vorsicht!');
      write  ('HiByte wirkt dann wie Fct-Code');
   end; {Displ_Event_Win}

 procedure Displ_PulsEvt_Win;
  begin
      Set_Text_Win;
      GotoXY(S_Begin_EvtWin,Z_Begin_EvtWin-3); TextColor(Yellow); Write (chr($19)); {Pfeil nach unten} TextColor(Red);
      Write ('Hinweis zu Puls-Events:     ');
     Ini_Event_Win;
      writeln('Die Eingabe fÅr Puls 1 u. 2   ');
      write  ('Events erfolgt als 16-Bit Wort.');
      writeln('Ein-Evt startet den Puls und  ');
      writeln('Aus-Evt beendet ihn.          ');
      writeln('Die erzeugten Pulse sind an   ');
      writeln('Buchsen TIF1-OUT bzw. TIF2-OUT');
      writeln('verfÅgbar.                    ');
      writeln('Test-Events kann man mit einem');
      write  ('2. PC + Softw MIL_TIF erzeugen.');
      write  ('Dazu braucht man die Karte DTUB');
      writeln('(FX195060) als Umsetzer von   ');
      writeln('Device-Bus auf 2-polig Lemo.  ');
      write  ('                              ');
      writeln('                              ');
      writeln('                              ');
      writeln('                              ');
      write  ('                              ');
   end; {Displ_PulsEvt_Win}

 procedure Displ_Intr_Win;
  begin
      Set_Text_Win;
      GotoXY(S_Begin_EvtWin,Z_Begin_EvtWin-3); TextColor(Yellow); Write (chr($19)); {Pfeil nach unten} TextColor(Red);
      Write ('En/Dis Interrupt-Quellen: ');
      Ini_Event_Win;
      writeln('Die Maskierung der Interrupts ');
      writeln('ist nicht rÅcklesbar. Deshalb ');
      writeln('Åberschreibt jede énderung die');
      writeln('die alten Werte! Taste F6 gibt');
      writeln('  Modul-Intr an IFK weiter!   ');
      writeln('                              ');
      writeln('Im Maskenbyte bedeutet eine   ');
      writeln('"0" Disable         "1" Enable');
      writeln('                              ');
      writeln('Bit 7: Ext Stat Eingang DST7  ');
      writeln('Bit 6: Ext Stat Eingang DST6  ');
      writeln('Bit 5: frei                   ');
      writeln('Bit 4: frei                   ');
      writeln('Bit 3: frei                   ');
      writeln('Bit 2: Err: Stop vor Start    ');
      writeln('Bit 1: Err: 2.Trig wÑhrend GP ');
      write  ('Bit 0: Gatepuls               ');
   end; {Displ_Intr_Win}

 procedure Gpgen_Softw_Trigger;
  label 99;
  var
   ModIdent   : TID_Type;
   IdRet_Code : TIfk_IdErr;
   Adr_Error  : Boolean;
   Start_Cnt  : TCounter;
   Stop_Cnt   : TCounter;
   WrData     : Word;
   Adress     : Word;
   User_Int   : LongInt;
   User_Input : Word;
   Mod_Dmy_Adr: Byte;
   User_In      : Word;
   Data_InOutput: Word;
   Data_Byte  : Byte;
   Bit16_Strg : Str19;
   Bit8_Strg  : Str10;

  procedure Set_TastSoft_Win;
  begin
   Window(02, 20, 49, 23);
   TextBackground(Green);
   TextColor(Black);
  end;

  Begin                {Gpgen_Softw_Trigger}
   Ini_Text_Win;
   Data_InOutput  := 0;   {Ext. TriggerEingÑnge und Ext. AusgÑnge}

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

   ModIdent.Soll := ModID_GPGen;
   ModIdent.Ist  := 0;
   ModIdent.Mode := Modul;       {nur Modul-Id prÅfen egal welcher Steckplatz}

   if not ID_Check (ModAdr, ModIdent) then         {Ist richtiges Modul da?}
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

   Set_Text_Win; TextColor(Yellow);
   GotoXY(03,01); write('Softw. Triggerung -> nur Independent-Mode!');
   TextColor(Blue);
   GotoXY(S_Base,Z_Base-1);   write('Ifk-Adr  [H]:');
   GotoXY(S_Base,Z_Base  );   write('Modul-Adr[H]:');
   GotoXY(S_Base,Z_Base+1);   write('Modul-ID [H]:');

   GotoXY(S_Single_Rep-7,Z_Single); write('SiRep: ');
   GotoXY(S_Single_Rep-7,Z_Intr);   write('DRDY : ');
   GotoXY(S_Single_Rep-7,Z_Out);    write('Input: ');
   GotoXY(S_Output,Z_Out);          write('Output: ');

   GotoXY(S_ModAdr,Z_Base+1);
   if ModIdent.Soll = ModIdent.Ist then
     TextColor(Black)
   else
     TextColor(Red+128);
   write (Hex_Byte(ModIdent.Ist));

   TextColor(blue);
   GotoXY(S_Base,   Z_StartCount); write('StartCount[us]:');
   GotoXY(S_Base,   Z_StopCount);  write('Stop Count[us]:');

   GotoXY(37,Z_HwStat_Hex); write('LSB'); TextColor(Yellow); Write (chr($19)); {Pfeil nach unten}  TextColor(blue);
   GotoXY(S_Base,Z_HwStat_Hex);    write('HardwStatus[H]:');

   GotoXY(S_Base,Z_HwStat_Bin);    write('  "      [Bin]:');
   GotoXY(S_Base,Z_DynStat_Bin);   write('Dyn.Stat [Bin]:');
{
   GotoXY(S_Base,Z_ModReg_Bin);    write('Mode Reg [Bin]:');
}
   Set_Text_Win;
   TextColor(Black);
   GotoXY(S_ModAdr,Z_Base-1);  Write(Hex_Byte(ModAdr.AdrIfc));
   GotoXY(S_ModAdr,Z_ModAdr);  Write(Hex_Byte(ModAdr.AdrCard));

   TextColor(blue);
   GotoXY(02,17); write  ('Belegung der Funktions-Tasten:');
   Set_TastSoft_Win;
   TextColor(Yellow);
   GotoXY(01, 01); Write('F1:SofTrigAktiv  F5:Ld-StartCnt F9 :Modul Adr ');
   GotoXY(01, 02); Write('F2:Singl/Repeat  F6:Ld-Stop-Cnt F10:Ifk   Adr ');
   GotoXY(01, 03); Write('F3:Gatepuls En   F7:Sel Output  F11:LoadCntDef');
   GotoXY(01, 04); Write('F4:Trigger       F8:Rd-DynStat  F12:Soft Reset');
   TextColor(Black);
   Displ_Modul_Stat;
   Set_Text_Win;

   GotoXY(S_Single_Rep, Z_Out); Write('0');   {Bei Softw-Trigger: kein ext. Inp}

   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Set_Text_win;
       Show_HwStat_Reg;
       Mil.Timer2_Wait(10000);
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Set_Text_win;
       Show_HwStat_Reg;
       Mil.Timer2_Wait(10000);
      end;

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin       {Toggle Trigger aktiv setzen}
                    GpModi.Bit     := []; {Clear}
                    ModAdr.AdrIfc  := Ifc_Test_Nr;    {Hw-Status lesen}
                    ModAdr.AdrCard := Mod_Test_Nr;
                    ModAdr.AdrSub  := SubAdr_GpModi ;
                    ModAdr.AdrMode := AdrNew;
                    Mil.Rd_ModBus (GpModi.Wrd, ModAdr, MilErr);
                    if MilErr = No_Err then
                     begin
                      if TrigSrc1 in GpModi.Bit then
                       begin
                         GpModi.Bit := GpModi.Bit - [TrigSrc0];
                         GpModi.Bit := GpModi.Bit - [TrigSrc1];   {0}
                       end
                      else
                       begin
                         GpModi.Bit := GpModi.Bit - [TrigSrc0];
                         GpModi.Bit := GpModi.Bit + [TrigSrc1];   {1}
                       end;
                      Mil.Wr_ModBus (GpModi.Wrd, ModAdr, MilErr);
                      Ini_Err_Win;
                      Write ('Trigger aktiv/passiv!');
                      Mil.Timer2_Wait(100000);
                     end; {if MilErr}
                    Std_Msg;
                   end;

        Taste_F2 : begin    {Toggle Single/Repeat}
                    ModAdr.AdrIfc  := Ifc_Test_Nr;    {Hw-Status lesen}
                    ModAdr.AdrCard := Mod_Test_Nr;
                    ModAdr.AdrSub  := SubAdr_GpModi;
                    ModAdr.AdrMode := AdrNew;
                    Mil.Rd_ModBus (GpModi.Wrd, ModAdr, MilErr);
                    if MilErr = No_Err then
                     begin
                      if RepMode in GpModi.Bit then
                       GpModi.Bit := GpModi.Bit - [RepMode]     {0}
                      else
                       GpModi.Bit := GpModi.Bit + [RepMode];   {1}
                      Mil.Wr_ModBus (GpModi.Wrd, ModAdr, MilErr);
                      Ini_Err_Win;
                      Write ('Single/Repeat!');
                      Mil.Timer2_Wait(100000);
                     end; {if MilErr}
                    Std_Msg;
                   end; {F-Taste}

        Taste_F3 : begin   {Enable Gatepuls}
                     ModAdr.AdrIfc  := Ifc_Test_Nr;     {Modul-Adr definieren}
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrSub  := SubAdr_GpEnable ;
                     ModAdr.AdrMode := AdrNew;
                     Mil.Wr_ModBus (1, ModAdr, MilErr);
                     Ini_Err_Win;
                     Write ('Gatepuls enable!');
                     Mil.Timer2_Wait(100000);
                     Std_Msg;
                   end;
        Taste_F4 : begin           {Software Trigger}
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrSub := SubAdr_GpSoftTrig;
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (0, ModAdr, MilErr);
                    Std_Msg;
                   end;
        Taste_F5 : begin
                    {Eingabe in [us]: also umrechnen!!}
                    if Read_LongInt (0,(Count_Max Div Gp_Quarz_Faktor), Start_Cnt.L) then
                      begin
                       Set_Text_Win;
                       GotoXY(S_Count_Int, Z_StartCount); WriteLn('          ');
                       GotoXY(S_Count_Int, Z_StartCount); Write (Start_Cnt.L:10);
                       Start_Cnt.L   := Start_Cnt.L * (Gp_Quarz_Faktor);
                       ModAdr.AdrIfc := Ifc_Test_Nr;
                       ModAdr.AdrCard:= Mod_Test_Nr;
                       ModAdr.AdrSub := SubAdr_GpStartCnt_Low; {LowWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Start_Cnt.W.Lwr, ModAdr, MilErr);

                       ModAdr.AdrSub := SubAdr_GpStartCnt_Hi;  {HiWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Start_Cnt.W.Upr, ModAdr, MilErr);
                     end;
                     Std_Msg;
                   end; {F-Taste}
        Taste_F6 : begin
                    {Eingabe in [us]: also umrechnen!!}
                    if Read_LongInt (0,(Count_Max Div Gp_Quarz_Faktor), Stop_Cnt.L) then
                      begin
                       Set_Text_Win;
                       GotoXY(S_Count_Int, Z_StopCount); WriteLn('          ');
                       GotoXY(S_Count_Int, Z_StopCount); Write(Stop_Cnt.L:10);
                       Stop_Cnt.L   := Stop_Cnt.L * (Gp_Quarz_Faktor);
                       ModAdr.AdrIfc := Ifc_Test_Nr;
                       ModAdr.AdrCard:= Mod_Test_Nr;
                       ModAdr.AdrSub := SubAdr_GpStopCnt_Low; {LowWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Stop_Cnt.W.Lwr, ModAdr, MilErr);

                       ModAdr.AdrSub := SubAdr_GpStopCnt_Hi;  {HiWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Stop_Cnt.W.Upr, ModAdr, MilErr);
                      end;
                     Std_Msg;
                   end; {F-Taste}
        Taste_F7 : begin           {Output wÑhlen}
                     if Ask_Hex_Break (User_In, Byt) then
                      begin
                       Data_InOutput  := swap(User_In); {Bytes vertauschen}
                       ModAdr.AdrIfc  := Ifc_Test_Nr;
                       ModAdr.AdrCard := Mod_Test_Nr;
                       ModAdr.AdrSub  := SubAdr_GpInOut;
                       ModAdr.AdrMode := AdrNew;
                       Write_Data     := Data_InOutput;
                       Mil.Wr_ModBus (Write_Data, ModAdr, MilErr);
                       Set_Text_WIn;
                       Hex_Bin8_Str (Hi(Write_Data), Bit8_Strg);
                       GotoXY(S_Output+8, Z_Out);  write(Bit8_Strg);
                      end;
                     Std_Msg;
                  end; {Taste}

        Taste_F8 : Show_DynStat_Reg;
        Taste_F9: begin                            {neue Mod-Adr erfragen}
                   if Ask_Hex_Break (Adress, Byt) then
                    begin
                     ModAdr.AdrCard:= Adress;           {neu}
                     Set_Text_Win;
                     GotoXY(S_ModAdr,Z_ModAdr);  Write(Hex_Byte(ModAdr.AdrCard));
                    end;
                    Std_Msg;
                   end; {Taste_F9}
        Taste_F10: begin                             {neue IFK-Adr erfragen}
                    if Ask_Hex_Break (Adress, Byt) then
                     begin
                      Ifc_Test_Nr := Adress;           {neu}
                      ModAdr.AdrIfc  := Ifc_Test_Nr;
                      Set_Text_Win;
                      GotoXY(S_ModAdr,Z_Base-1);  Write(Hex_Byte(ModAdr.AdrIfc));
                     end;
                    Std_Msg;
                   end; {Taste_F10}
        Taste_F11: begin
                    Start_Cnt.L:= 500; {Default Wert}
                    Stop_Cnt.L := 1000;
                    Set_Text_Win;
                    GotoXY(S_Count_Int, Z_StartCount); Write ('          ');
                    GotoXY(S_Count_Int, Z_StopCount);  Write ('          ');
                    GotoXY(S_Count_Int, Z_StartCount); Write (Start_Cnt.L);
                    GotoXY(S_Count_Int, Z_StopCount);  Write (Stop_Cnt.L);

                    Start_Cnt.L   := Start_Cnt.L * (Gp_Quarz_Faktor);
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrSub := SubAdr_GpStartCnt_Low; {LowWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Start_Cnt.W.Lwr, ModAdr, MilErr);
                    ModAdr.AdrSub := SubAdr_GpStartCnt_Hi;  {HiWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Start_Cnt.W.Upr, ModAdr, MilErr);

                    Stop_Cnt.L   := Stop_Cnt.L * (Gp_Quarz_Faktor);
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrSub := SubAdr_GpStopCnt_Low; {LowWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Stop_Cnt.W.Lwr, ModAdr, MilErr);

                    ModAdr.AdrSub := SubAdr_GpStopCnt_Hi;  {HiWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Stop_Cnt.W.Upr, ModAdr, MilErr);
                    Std_Msg;
                    end; {Taste_F11}
        Taste_F12 : begin
                     ModAdr.AdrIfc  := Ifc_Test_Nr;     {Modul-Adr definieren}
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrSub  := SubAdr_GpSoftReset;
                     ModAdr.AdrMode := AdrNew;
                     Mil.Wr_ModBus (0, ModAdr, MilErr);
                     Ini_Err_Win;
                     Write ('Modul Software Reset');
                     Mil.Timer2_Wait(200000);
                     Std_Msg;
                   end;  {F-Taste}
       end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
 end; {Gpgen_Softw_Trigger}


 procedure Gpgen_Evt_Trigger;  {9.3.01: Trigger nur mit 2. Pc}
  label 99;
  const
   Cmd_Letter_UpMax = 'Z';
   Cmd_Letter_LoMax = 'z';
  var
   ModIdent   : TID_Type;
   IdRet_Code : TIfk_IdErr;
   Adr_Error  : Boolean;
   Start_Cnt  : TCounter;
   Stop_Cnt   : TCounter;
   WrData     : Word;
   Adress     : Word;
   User_LInt   : LongInt;
   User_Input : Word;
   Mod_Dmy_Adr: Byte;
   User_In      : Word;
   Data_InOutput: Word;
   Data_Byte  : Byte;
   Bit16_Strg : Str19;
   Bit8_Strg  : Str10;
   Trig_EvtStart: Word;
   Trig_EvtStop : Word;
   Zeichen      : Char;

  procedure Set_TastEvt_Win;
  begin
   Window(02, 20, 49, 23);
   TextBackground(Green);
   TextColor(Black);
  end;


  Begin                     {Gpgen_Evt_Trigger}
   Ask_Ifc_Mod_Adr;
   Ini_Text_Win;
   Data_InOutput := 0;   {Ext. Trigger EingÑnge und Ext. AusgÑnge}
   Trig_EvtStart := 0;
   Trig_EvtStop  := 0;
 {  Intr_Test     := True;}  {wegen DRDY-Anzeige}

   Life_Mode.Mode    := Norm;         {Parameter fÅr Lebenszeichen definieren}
   Life_Mode.Time    := Life_Time_Super;  {Life_Time_Fast; }
   Life_Mode.Disp_Win:= Set_Text_Win;     {Darstellungs-Fenster}

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

   ModIdent.Soll := ModID_GPGen;
   ModIdent.Ist  := 0;
   ModIdent.Mode := Modul;       {nur Modul-Id prÅfen egal welcher Steckplatz}

   if not ID_Check (ModAdr, ModIdent) then         {Ist richtiges Modul da?}
    begin
      Adr_Error := True;
      Ini_Err_Win;
      Write ('ERROR: I/O-Modul IDENT [Hex] Soll: ', Hex_Byte(ModIdent.Soll),'  Ist: ', Hex_Byte(ModIdent.Ist));
      Write ('    Weiter mit <Space> ');
      Ch := NewReadKey;
    end;

   Set_Text_Win; TextColor(Yellow);
   GotoXY(03,01); write('Event Triggerung [Indep + Transp-Mode]');
   TextColor(Blue);
   GotoXY(S_Base,Z_Base-1);   write('Ifk-Adr  [H]:');
   GotoXY(S_Base,Z_Base  );   write('Modul-Adr[H]:');
   GotoXY(S_Base,Z_Base+1);   write('Modul-ID [H]:');

   GotoXY(S_Single_Rep-7,Z_Single); write('SiRep: ');
   GotoXY(S_Single_Rep-7,Z_Intr);   write('DRDY : ');
   GotoXY(S_Single_Rep-7,Z_Out);    write('Input: ');
   GotoXY(S_Output,Z_Out);          write('Output: ');

   GotoXY(S_ModAdr,Z_Base+1);
   if ModIdent.Soll = ModIdent.Ist then
     TextColor(Black)
   else
     TextColor(Red+128);
   write (Hex_Byte(ModIdent.Ist));

   TextColor(Yellow);
{   GotoXY(S_Trigger,Z_Mask_Text);    Write (chr($19));
   TextColor(Red); write('Trigger'); TextColor(Yellow);
}
   GotoXY(S_Mask,Z_Mask_Text);       Write (chr($19)); {Pfeil nach unten}
   TextColor(Red); write('StartonEvt');   TextColor(Blue);
   GotoXY(S_Base,   Z_Evt_Start);  write('Start Event[H]:');
   GotoXY(S_Base,   Z_Evt_Stop);   write('Stop  Event[H]:');

   GotoXY(S_Base,   Z_StartCount); write('StartCount[us]:');
   GotoXY(S_Base,   Z_StopCount);  write('Stop Count[us]:');
   GotoXY(37,Z_HwStat_Hex); write('LSB'); TextColor(Yellow); Write (chr($19)); {Pfeil nach unten}  TextColor(blue);
   GotoXY(S_Base,Z_HwStat_Hex);    write('HardwStatus[H]:');
   GotoXY(S_Base,Z_HwStat_Bin);    write('  "      [Bin]:');
   GotoXY(S_Base,Z_DynStat_Bin);   write('Dyn.Stat [Bin]:');

   Set_Text_Win;
   TextColor(Black);
   GotoXY(S_ModAdr,Z_Base-1);  Write(Hex_Byte(ModAdr.AdrIfc));
   GotoXY(S_ModAdr,Z_ModAdr);  Write(Hex_Byte(ModAdr.AdrCard));

   TextColor(blue);
   GotoXY(02,17); write  ('Belegung der Funktions-Tasten:');
   Set_TastEvt_Win;
   TextColor(Yellow);
   GotoXY(01, 01); Write('F1:Set Modi      F5:Ld-StartCnt F9 :Modul Adr ');
   GotoXY(01, 02); Write('F2:Set Events    F6:Ld-Stop-Cnt F10:Ifk   Adr ');
   GotoXY(01, 03); Write('F3:              F7:Sel Output  F11:LoadCntDef');
   GotoXY(01, 04); Write('F4:              F8:Rd-DynStat  F12:Soft Reset');
   TextColor(Black);
   Displ_Modul_Stat;
   Set_Text_Win;
   GotoXY(S_Single_Rep, Z_Out); Write(Lo(Data_InOutput));
   Hex_Bin8_Str (Hi(Data_InOutput), Bit8_Strg);
   GotoXY(S_Output+8, Z_Out);  write(Bit8_Strg);
{
   GotoXY(S_Trigger, Z_Evt_Start);  write(Hex_Word(Trig_EvtStart));
   GotoXY(S_Trigger, Z_Evt_Stop);   write(Hex_Word(Trig_EvtStop));
}
   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Set_Text_win;
       Show_HwStat_Reg;
       Mil.Timer2_Wait(10000);
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Set_Text_win;
       Show_HwStat_Reg;
       Mil.Timer2_Wait(10000);
      end;

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    Displ_ModiSelect_Win;
                    repeat
                     Ini_Msg_Win;
                     Cursor (True);
                     Write('Mit Buchstabe Mode-Auswahl, <F8> Dyn-Status, <Space> Hw-Status oder <Esc>: ');
                     Zeichen := NewReadKey; TextColor(Red);
                     if Zeichen in ['a'..'z'] then Ch := UpCase(Zeichen) else Ch := Zeichen;
                     if Ch      in ['A'..'Z'] then
                       begin
                        Write (Ch);
                        Mil.Timer2_Wait(50000);
                        Change_Mode (Ch);
                       end;
                     if Ch = Taste_Space then Show_HwStat_Reg;
                     if Ch = #0 then
                       begin
                         Ch := NewReadKey;
                         case ord (Ch) of Taste_F8 : Show_DynStat_Reg; end;
                       end; {Ch=0}
                    until Ch = chr(Taste_Esc);
                    Cursor (False);
                    Ch:= '?';    {Dummy}
                    Std_Msg;
                    Displ_Modul_Stat;
                  end; {F-Taste}
        Taste_F2: begin           {Lade Start + StopEvent und Sende Trigger-Start-, Trig-Stop}
                    Displ_Event_Win;
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrMode:= AdrNew;
                    repeat
                    Ini_Msg_Win;
                    Cursor (True);
                    Write('Eingeben: [');     TextColor(Red); Write('1'); TextColor(Yellow);
                    Write(']Start-Evt, [');   TextColor(Red); Write('2'); TextColor(Yellow);
                    Write(']Stop-Evt  '); {   TextColor(Red); Write('3'); TextColor(Yellow);
                    Write(']TrigEvtStart ['); TextColor(Red); Write('4'); TextColor(Yellow);
                    Write(']TrigEvtStop, [Esc]:');} Write ('[Esc]');
                    Ch:= NewReadKey;
                    case Ch of
                     '1'    : begin
                               if Ask_Hex_Break (User_In, Wrd) then
                                begin
                                 Set_Text_Win;
                                 GotoXY(S_Mask, Z_Evt_Start);
                                 Write (Hex_Word(User_In));
                                 ModAdr.AdrSub := SubAdr_GpMask_StartEvt;
                                 Mil.Wr_ModBus (User_In, ModAdr, MilErr);
                                end;
                              end;
                     '2'    : begin
                               if Ask_Hex_Break (User_In, Wrd) then
                                begin
                                 Set_Text_Win;
                                 GotoXY(S_Mask, Z_Evt_Stop);
                                 Write (Hex_Word(User_In));
                                 ModAdr.AdrSub := SubAdr_GpMask_StopEvt;
                                 Mil.Wr_ModBus (User_In, ModAdr, MilErr);
                                end;
                              end;
{                     '3'    : begin
                               if Ask_Hex_Break (User_In, Wrd) then
                                begin
                                 if Lo(User_In) = Ifc_Test_Nr then
                                  begin
                                   Ini_Err_Win;
                                   Write ('Error: Lo-Byte Event=IFK-Adr!! Hi-Byte wirkt als Fct-Code! Abort mit <Space> : ');
                                   Ch := NewReadKey;  Ch := '?';
                                  end
                                 else
                                  begin
                                   Set_Text_Win;
                                   Trig_EvtStart := User_In;
                                   GotoXY(S_Trigger, Z_Evt_Start);   write(Hex_Word(Trig_EvtStart));
                                  end;
                                end;
                               Std_Msg;
                              end;
                     '4'    : begin
                               if Ask_Hex_Break (User_In, Wrd) then
                                begin
                                 if Lo(User_In) = Ifc_Test_Nr then
                                  begin
                                   Ini_Err_Win;
                                   Write ('Error: Lo-Byte Event=IFK-Adr!! Hi-Byte wirkt als Fct-Code! Abort mit <Space> : ');
                                   Ch := NewReadKey;  Ch := '?';
                                  end
                                 else
                                  begin
                                   Set_Text_Win;
                                   Trig_EvtStop := User_In;
                                   GotoXY(S_Trigger, Z_Evt_Stop);   write(Hex_Word(Trig_EvtStop));
                                  end;
                                end;
                                Std_Msg;
                              end;
}                     end; {case}
                    until Ch = chr(Taste_Esc);  { until Ch in ['q','Q'];}
                    Std_Msg;
                    Displ_Modul_Stat;
                   end; {F-Taste}
        Taste_F3 : begin   {Sende Start-Event Åber sep- Einschub DTUB}
{                     WriteEvt_To_Milbus (Trig_EvtStart);
                     Life_Mode.PosX    := S_Base-1;
                     Life_Mode.PosY    := Z_Evt_Start;
                     Life_Sign_XY (Life_Mode);
}                   end;
        Taste_F4 : begin   {Sende Stop-Event Åber sep- Einschub DTUB}
{                     WriteEvt_To_Milbus (Trig_EvtStop);
                     Life_Mode.PosX    := S_Base-1;
                     Life_Mode.PosY    := Z_Evt_Stop;
                     Life_Sign_XY (Life_Mode);
}                   end;
        Taste_F5 : begin
                    {Eingabe in [us]: also umrechnen!!}
                    if Read_LongInt (0,(Count_Max Div Gp_Quarz_Faktor), Start_Cnt.L) then
                      begin
                       Set_Text_Win;
                       GotoXY(S_Count_Int, Z_StartCount); WriteLn ('          ');
                       GotoXY(S_Count_Int, Z_StartCount); Write (Start_Cnt.L:10);
                       Start_Cnt.L   := Start_Cnt.L * (Gp_Quarz_Faktor);
                       ModAdr.AdrIfc := Ifc_Test_Nr;
                       ModAdr.AdrCard:= Mod_Test_Nr;
                       ModAdr.AdrSub := SubAdr_GpStartCnt_Low; {LowWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Start_Cnt.W.Lwr, ModAdr, MilErr);

                       ModAdr.AdrSub := SubAdr_GpStartCnt_Hi;  {HiWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Start_Cnt.W.Upr, ModAdr, MilErr);
                     end;
                     Std_Msg;
                   end; {F-Taste}
        Taste_F6 : begin
                    {Eingabe in [us]: also umrechnen!!}
                    if Read_LongInt (0,(Count_Max Div Gp_Quarz_Faktor), Stop_Cnt.L) then
                      begin
                       Set_Text_Win;
                       GotoXY(S_Count_Int, Z_StopCount); Write ('          ');
                       GotoXY(S_Count_Int, Z_StopCount); Write(Stop_Cnt.L:10);
                       Stop_Cnt.L   := Stop_Cnt.L * (Gp_Quarz_Faktor);
                       ModAdr.AdrIfc := Ifc_Test_Nr;
                       ModAdr.AdrCard:= Mod_Test_Nr;
                       ModAdr.AdrSub := SubAdr_GpStopCnt_Low; {LowWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Stop_Cnt.W.Lwr, ModAdr, MilErr);

                       ModAdr.AdrSub := SubAdr_GpStopCnt_Hi;  {HiWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Stop_Cnt.W.Upr, ModAdr, MilErr);
                      end;
                     Std_Msg;
                   end; {F-Taste}
        Taste_F7 : begin           {Output wÑhlen}
                     if Ask_Hex_Break (User_In, Byt) then
                      begin
                       Data_InOutput     := swap(User_In); {Bytes vertauschen}
                       ModAdr.AdrIfc     := Ifc_Test_Nr;
                       ModAdr.AdrCard    := Mod_Test_Nr;
                       ModAdr.AdrSub     := SubAdr_GpInOut;
                       ModAdr.AdrMode    := AdrNew;
                       Write_Data        := Data_InOutput;
                       Mil.Wr_ModBus (Write_Data, ModAdr, MilErr);
                       Set_Text_Win;
                       Hex_Bin8_Str (Hi(Write_Data), Bit8_Strg);
                       GotoXY(S_Output+8, Z_Out);  write(Bit8_Strg);
                      end;
                     Std_Msg;
                  end; {Taste}

        Taste_F8 : Show_DynStat_Reg;
        Taste_F9: begin                            {neue Mod-Adr erfragen}
                   if Ask_Hex_Break (Adress, Byt) then
                    begin
                     ModAdr.AdrCard:= Adress;           {neu}
                     Set_Text_Win;
                     GotoXY(S_ModAdr,Z_ModAdr);  Write(Hex_Byte(ModAdr.AdrCard));
                    end;
                    Std_Msg;
                   end; {Taste_F9}
        Taste_F10: begin                             {neue IFK-Adr erfragen}
                    if Ask_Hex_Break (Adress, Byt) then
                     begin
                      Ifc_Test_Nr := Adress;           {neu}
                      ModAdr.AdrIfc  := Ifc_Test_Nr;
                      Set_Text_Win;
                      GotoXY(S_ModAdr,Z_Base-1);  Write(Hex_Byte(ModAdr.AdrIfc));
                     end;
                    Std_Msg;
                   end; {Taste_F10}
        Taste_F11: begin
                    Start_Cnt.L:= 500; {Default Wert}
                    Stop_Cnt.L := 1000;
                    Set_Text_Win;
                    GotoXY(S_Count_Int, Z_StartCount);  Write ('          ');
                    GotoXY(S_Count_Int, Z_StopCount);   Write ('          ');
                    GotoXY(S_Count_Int, Z_StartCount);  Write (Start_Cnt.L);
                    GotoXY(S_Count_Int, Z_StopCount);   Write (Stop_Cnt.L);

                    Start_Cnt.L   := Start_Cnt.L * (Gp_Quarz_Faktor);
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrSub := SubAdr_GpStartCnt_Low; {LowWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Start_Cnt.W.Lwr, ModAdr, MilErr);
                    ModAdr.AdrSub := SubAdr_GpStartCnt_Hi;  {HiWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Start_Cnt.W.Upr, ModAdr, MilErr);

                    Stop_Cnt.L   := Stop_Cnt.L * (Gp_Quarz_Faktor);
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrSub := SubAdr_GpStopCnt_Low; {LowWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Stop_Cnt.W.Lwr, ModAdr, MilErr);

                    ModAdr.AdrSub := SubAdr_GpStopCnt_Hi;  {HiWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Stop_Cnt.W.Upr, ModAdr, MilErr);
                    Std_Msg;
                    end; {Taste_F11}
        Taste_F12 : begin
                     ModAdr.AdrIfc  := Ifc_Test_Nr;     {Modul-Adr definieren}
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrSub  := SubAdr_GpSoftReset;
                     ModAdr.AdrMode := AdrNew;
                     Mil.Wr_ModBus (0, ModAdr, MilErr);
                     Ini_Err_Win;
                     Write ('Modul Software Reset');
                     Mil.Timer2_Wait(200000);
                     Std_Msg;
                   end;  {F-Taste}
       end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
  Intr_Test:= False; {wegen DRDY-Anzeige}
 end; {Gpgen_Evt_Trigger}


 procedure Gpgen_Ext_Trigger;
  label 99, F7End;
  var
   ModIdent   : TID_Type;
   IdRet_Code : TIfk_IdErr;
   Adr_Error  : Boolean;
   Start_Cnt  : TCounter;
   Stop_Cnt   : TCounter;
   WrData     : Word;
   Adress     : Word;
   User_Lint  : LongInt;
   User_Int   : Integer;
   User_Wrd   : Word;

   Mod_Dmy_Adr: Byte;
   Data_InOutput: Word;
   Data_Byte  : Byte;
   Bit16_Strg : Str19;
   Bit8_Strg  : Str10;

  procedure Set_TastSoft_Win;
  begin
   Window(02, 20, 49, 23);
   TextBackground(Green);
   TextColor(Black);
  end;

  Begin                {Gpgen_Ext_Trigger}
   Ask_Ifc_Mod_Adr;
   Ini_Text_Win;
   Data_InOutput  := 0;   {Ext. TriggerEingÑnge und Ext. AusgÑnge}
{   Intr_Test:= True; }  {wegen DRDY-Anzeige}


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

   ModIdent.Soll := ModID_GPGen;
   ModIdent.Ist  := 0;
   ModIdent.Mode := Modul;       {nur Modul-Id prÅfen egal welcher Steckplatz}

   if not ID_Check (ModAdr, ModIdent) then         {Ist richtiges Modul da?}
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

   Life_Mode.Mode    := Norm;         {Parameter fÅr Lebenszeichen definieren}
   Life_Mode.Time    := Life_Time_Super;  {Life_Time_Fast; }
   Life_Mode.Disp_Win:= Set_Text_Win;     {Darstellungs-Fenster}


   Set_Text_Win; TextColor(Yellow);
   GotoXY(03,01); write('Test der externen Triggerung!');
   TextColor(Blue);
   GotoXY(S_Base,Z_Base-1);   write('Ifk-Adr  [H]:');
   GotoXY(S_Base,Z_Base  );   write('Modul-Adr[H]:');
   GotoXY(S_Base,Z_Base+1);   write('Modul-ID [H]:');

   GotoXY(S_Single_Rep-7,Z_Single); write('SiRep: ');
   GotoXY(S_Single_Rep-7,Z_Intr);   write('DRDY : ');
   GotoXY(S_Single_Rep-7,Z_Out);    write('Input: ');
   GotoXY(S_Output,Z_Out);          write('Output: ');

   GotoXY(S_ModAdr,Z_Base+1);
   if ModIdent.Soll = ModIdent.Ist then
     TextColor(Black)
   else
     TextColor(Red+128);
   write (Hex_Byte(ModIdent.Ist));

   TextColor(blue);

   GotoXY(S_Base,   Z_StartCount); write('StartCount[us]:');
   GotoXY(S_Base,   Z_StopCount);  write('Stop Count[us]:');

   GotoXY(37,Z_HwStat_Hex); write('LSB'); TextColor(Yellow); Write (chr($19)); {Pfeil nach unten}  TextColor(blue);
   GotoXY(S_Base,Z_HwStat_Hex);    write('HardwStatus[H]:');

   GotoXY(S_Base,Z_HwStat_Bin);    write('  "      [Bin]:');
   GotoXY(S_Base,Z_DynStat_Bin);   write('Dyn.Stat [Bin]:');

   Set_Text_Win;
   TextColor(Black);
   GotoXY(S_ModAdr,Z_Base-1);  Write(Hex_Byte(ModAdr.AdrIfc));
   GotoXY(S_ModAdr,Z_ModAdr);  Write(Hex_Byte(ModAdr.AdrCard));

   TextColor(blue);
   GotoXY(02,17); write  ('Belegung der Funktions-Tasten:');
   Set_TastSoft_Win;
   TextColor(Yellow);
   GotoXY(01, 01); Write('F1:ExtTrig En/Dis F5:Ld-StartCnt F9 :Modul Adr ');
   GotoXY(01, 02); Write('F2:Indep/Transp   F6:Ld-Stop-Cnt F10:Ifk   Adr ');
   GotoXY(01, 03); Write('F3:Singl/Repeat   F7:Sel In/Out  F11:LoadCntDef');
   GotoXY(01, 04); Write('F4:Gatepuls En    F8:Rd-DynStat  F12:Soft Reset');
   TextColor(Black);
   Displ_Modul_Stat;
   Set_Text_Win;

   GotoXY(S_Single_Rep, Z_Out); Write('?');
   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Set_Text_win;
       Show_HwStat_Reg;
       Mil.Timer2_Wait(10000);
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Set_Text_win;
       Show_HwStat_Reg;
       Mil.Timer2_Wait(10000);
      end;

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin       {Toggle Trigger aktiv setzen}
                    GpModi.Bit     := []; {Clear}
                    ModAdr.AdrIfc  := Ifc_Test_Nr;    {Hw-Status lesen}
                    ModAdr.AdrCard := Mod_Test_Nr;
                    ModAdr.AdrSub  := SubAdr_GpModi;
                    ModAdr.AdrMode := AdrNew;
                    Mil.Rd_ModBus (GpModi.Wrd, ModAdr, MilErr);
                    if MilErr = No_Err then
                     begin
                      if TrigSrc0 in GpModi.Bit then
                       begin
                         GpModi.Bit := GpModi.Bit - [TrigSrc0];
                         GpModi.Bit := GpModi.Bit - [TrigSrc1];   {0}
                       end
                      else                       {ext. Triggersource toggeln}
                       begin
                         GpModi.Bit := GpModi.Bit + [TrigSrc0];
                         GpModi.Bit := GpModi.Bit - [TrigSrc1];   {1}
                       end;

                      ModAdr.AdrSub := SubAdr_GpModi;
                      Mil.Wr_ModBus (GpModi.Wrd, ModAdr, MilErr);
                      Ini_Err_Win;
                      Write ('Ext. Trigger En/Dis');
                      Mil.Timer2_Wait(100000);
                     end; {if MilErr}
                    Std_Msg;
                   end;

        Taste_F2 : begin    {Toggle Indep/Transp}
                    ModAdr.AdrIfc  := Ifc_Test_Nr;    {Hw-Status lesen}
                    ModAdr.AdrCard := Mod_Test_Nr;
                    ModAdr.AdrSub  := SubAdr_GpModi;
                    ModAdr.AdrMode := AdrNew;
                    Mil.Rd_ModBus (GpModi.Wrd, ModAdr, MilErr);
                    if MilErr = No_Err then
                     begin
                      if TransMode in GpModi.Bit then
                       GpModi.Bit := GpModi.Bit - [TransMode]    {0}
                      else
                       GpModi.Bit := GpModi.Bit + [TransMode];   {1}

                      ModAdr.AdrSub := SubAdr_GpModi;
                      Mil.Wr_ModBus (GpModi.Wrd, ModAdr, MilErr);
                      Ini_Err_Win;
                      Write ('Indep/Transp!');
                      Mil.Timer2_Wait(100000);
                     end; {if MilErr}
                    Std_Msg;
                   end; {F-Taste}
        Taste_F3 : begin    {Toggle Single/Repeat}
                    ModAdr.AdrIfc  := Ifc_Test_Nr;    {Hw-Status lesen}
                    ModAdr.AdrCard := Mod_Test_Nr;
                    ModAdr.AdrSub  := SubAdr_GpModi;
                    ModAdr.AdrMode := AdrNew;
                    Mil.Rd_ModBus (GpModi.Wrd, ModAdr, MilErr);
                    if MilErr = No_Err then
                     begin
                      if RepMode in GpModi.Bit then
                       GpModi.Bit := GpModi.Bit - [RepMode]     {0}
                      else
                       GpModi.Bit := GpModi.Bit + [RepMode];;   {1}

                      ModAdr.AdrSub := SubAdr_GpModi;
                      Mil.Wr_ModBus (GpModi.Wrd, ModAdr, MilErr);
                      Ini_Err_Win;
                      Write ('Single/Repeat!');
                      Mil.Timer2_Wait(100000);
                     end; {if MilErr}
                    Std_Msg;
                   end; {F-Taste}

        Taste_F4 : begin   {Enable Gatepuls}
                     ModAdr.AdrIfc  := Ifc_Test_Nr;     {Modul-Adr definieren}
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrSub  := SubAdr_GpEnable ;
                     ModAdr.AdrMode := AdrNew;
                     Mil.Wr_ModBus (1, ModAdr, MilErr);
                     Ini_Err_Win;
                     Write ('Gatepuls enable!');
                     Mil.Timer2_Wait(100000);
                     Std_Msg;
                   end;
        Taste_F5 : begin
                    {Eingabe in [us]: also umrechnen!!}
                    if Read_LongInt (0,(Count_Max Div Gp_Quarz_Faktor), Start_Cnt.L) then
                      begin
                       Set_Text_Win;
                       GotoXY(S_Count_Int, Z_StartCount); WriteLn ('          ');
                       GotoXY(S_Count_Int, Z_StartCount); Write (Start_Cnt.L:10);
                       Start_Cnt.L   := Start_Cnt.L * (Gp_Quarz_Faktor);
                       ModAdr.AdrIfc := Ifc_Test_Nr;
                       ModAdr.AdrCard:= Mod_Test_Nr;
                       ModAdr.AdrSub := SubAdr_GpStartCnt_Low; {LowWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Start_Cnt.W.Lwr, ModAdr, MilErr);

                       ModAdr.AdrSub := SubAdr_GpStartCnt_Hi;  {HiWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Start_Cnt.W.Upr, ModAdr, MilErr);
                     end;
                     Std_Msg;
                   end; {F-Taste}
        Taste_F6 : begin
                    {Eingabe in [us]: also umrechnen!!}
                    if Read_LongInt (0,(Count_Max Div Gp_Quarz_Faktor), Stop_Cnt.L) then
                      begin
                       Set_Text_Win;
                       GotoXY(S_Count_Int, Z_StopCount); Write ('          ');
                       GotoXY(S_Count_Int, Z_StopCount); Write(Stop_Cnt.L:10);
                       Stop_Cnt.L   := Stop_Cnt.L * (Gp_Quarz_Faktor);
                       ModAdr.AdrIfc := Ifc_Test_Nr;
                       ModAdr.AdrCard:= Mod_Test_Nr;
                       ModAdr.AdrSub := SubAdr_GpStopCnt_Low; {LowWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Stop_Cnt.W.Lwr, ModAdr, MilErr);

                       ModAdr.AdrSub := SubAdr_GpStopCnt_Hi;  {HiWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Stop_Cnt.W.Upr, ModAdr, MilErr);
                      end;
                     Std_Msg;
                   end; {F-Taste}
        Taste_F7 : begin           {In- u. Output wÑhlen}
                     ModAdr.AdrIfc  := Ifc_Test_Nr;
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrMode := AdrNew;
                     Data_InOutput  := 0;
                     Ini_Msg_Win;
                     Write ('Bitte mit <CR> zur Auswahl des Eingangs dezimal [1 aus 8]  ->');
                     TextColor(Yellow+128); Write('Jetzt <Return>');
                     Ch := NewReadKey;
                     if Read_Int (1,8, User_Int) then Data_InOutput := (Lo(User_Int) - 1) {wegen Hardw. 0..7}
                     else
                      begin
                        Ini_Err_WIn;
                        Write('ERROR: Falsche Eingabe!!  Abort mit <Space> ');
                        Ch := NewReadKey;
                        goto F7End;
                      end;

                     Ini_Msg_Win;
                     Write ('Max. 8 AusgÑnge [8..1] auswÑhlen in Hex [jedes Bit 1 Ausgang]  ->');
                     TextColor(Yellow+128); Write('Jetzt <Return>');
                     Ch := NewReadKey;
                     if Ask_Hex_Break (User_Wrd, Byt) then
                      begin
                       User_Wrd      := User_Wrd shl 8;
                       Data_InOutput := Data_InOutput or User_Wrd;
                       ModAdr.AdrSub := SubAdr_GpInOut;
                       Mil.Wr_ModBus (Data_InOutput, ModAdr, MilErr);
                       Set_Text_Win;
                       GotoXY(S_Single_Rep, Z_Out); Write(Lo(Data_InOutput)+1);
                       Hex_Bin8_Str (Hi(Data_InOutput), Bit8_Strg);
                       GotoXY(S_Output+8, Z_Out);  write(Bit8_Strg);
                      end
                     else
                      begin
                        Ini_Err_WIn;
                        Write('ERROR: Das war keine 2-stellige Hex-Eingabe!!  Abort mit <Space> ');
                        Ch := NewReadKey;
                      end;
              F7End: Ch := '?';
                     Std_Msg;
                     Set_Text_WIn;
                  end; {Taste}

        Taste_F8 : Show_DynStat_Reg;
        Taste_F9: begin                            {neue Mod-Adr erfragen}
                   if Ask_Hex_Break (Adress, Byt) then
                    begin
                     ModAdr.AdrCard:= Adress;           {neu}
                     Set_Text_Win;
                     GotoXY(S_ModAdr,Z_ModAdr);  Write(Hex_Byte(ModAdr.AdrCard));
                    end;
                    Std_Msg;
                   end; {Taste_F9}
        Taste_F10: begin                             {neue IFK-Adr erfragen}
                    if Ask_Hex_Break (Adress, Byt) then
                     begin
                      Ifc_Test_Nr := Adress;           {neu}
                      ModAdr.AdrIfc  := Ifc_Test_Nr;
                      Set_Text_Win;
                      GotoXY(S_ModAdr,Z_Base-1);  Write(Hex_Byte(ModAdr.AdrIfc));
                     end;
                    Std_Msg;
                   end; {Taste_F10}
        Taste_F11: begin
                    Start_Cnt.L:= 500; {Default Wert}
                    Stop_Cnt.L := 1000;
                    Set_Text_Win;
                    GotoXY(S_Count_Int, Z_StartCount); Write ('          ');
                    GotoXY(S_Count_Int, Z_StopCount);  Write ('          ');
                    GotoXY(S_Count_Int, Z_StartCount); Write (Start_Cnt.L:10);
                    GotoXY(S_Count_Int, Z_StopCount);  Write (Stop_Cnt.L:10);

                    Start_Cnt.L   := Start_Cnt.L * (Gp_Quarz_Faktor);
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrSub := SubAdr_GpStartCnt_Low; {LowWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Start_Cnt.W.Lwr, ModAdr, MilErr);
                    ModAdr.AdrSub := SubAdr_GpStartCnt_Hi;  {HiWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Start_Cnt.W.Upr, ModAdr, MilErr);

                    Stop_Cnt.L   := Stop_Cnt.L * (Gp_Quarz_Faktor);
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrSub := SubAdr_GpStopCnt_Low; {LowWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Stop_Cnt.W.Lwr, ModAdr, MilErr);

                    ModAdr.AdrSub := SubAdr_GpStopCnt_Hi;  {HiWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Stop_Cnt.W.Upr, ModAdr, MilErr);
                    Std_Msg;
                    end; {Taste_F11}
        Taste_F12 : begin
                     ModAdr.AdrIfc  := Ifc_Test_Nr;     {Modul-Adr definieren}
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrSub  := SubAdr_GpSoftReset;
                     ModAdr.AdrMode := AdrNew;
                     Mil.Wr_ModBus (0, ModAdr, MilErr);
                     Ini_Err_Win;
                     Write ('Modul Software Reset');
                     Mil.Timer2_Wait(200000);
                     Std_Msg;
                   end;  {F-Taste}
       end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
  Intr_Test:= False; {wegen DRDY-Anzeige}
 end; {Gpgen_Ext_Trigger}


 procedure Gpgen_Tif;
  label 99;
  var
   ModIdent     : TID_Type;
   IdRet_Code   : TIfk_IdErr;
   Adr_Error    : Boolean;
   Start_Cnt    : TCounter;
   Stop_Cnt     : TCounter;
   WrData       : Word;
   Adress       : Word;
   User_LInt    : LongInt;
   User_Input   : Word;
   Mod_Dmy_Adr  : Byte;
   User_In      : Word;
   Data_InOutput: Word;
   Data_Byte    : Byte;
   Bit16_Strg   : Str19;
   Bit8_Strg    : Str10;
   Trig_Tif1Evt : Word;
   Trig_Tif2Evt : Word;
   Zeichen      : Char;

  procedure Set_TastEvt_Win;
  begin
   Window(02, 20, 49, 23);
   TextBackground(Green);
   TextColor(Black);
  end;

  Begin                     {Gpgen_Tif}
   Ask_Ifc_Mod_Adr;
   Ini_Text_Win;
   Data_InOutput     := 0;   {Ext. Trigger EingÑnge und Ext. AusgÑnge}
   Trig_Tif1Evt      := 0;
   Trig_Tif2Evt      := 0;
   Life_Mode.Mode    := Norm;         {Parameter fÅr Lebenszeichen definieren}
   Life_Mode.Time    := Life_Time_Super;  {Life_Time_Fast; }
   Life_Mode.Disp_Win:= Set_Text_Win;     {Darstellungs-Fenster}

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

   ModIdent.Soll := ModID_GPGen;
   ModIdent.Ist  := 0;
   ModIdent.Mode := Modul;       {nur Modul-Id prÅfen egal welcher Steckplatz}

   if not ID_Check (ModAdr, ModIdent) then         {Ist richtiges Modul da?}
    begin
      Adr_Error := True;
      Ini_Err_Win;
      Write ('ERROR: I/O-Modul IDENT [Hex] Soll: ', Hex_Byte(ModIdent.Soll),'  Ist: ', Hex_Byte(ModIdent.Ist));
      Write ('    Weiter mit <Space> ');
      Ch := NewReadKey;
    end;

   Set_Text_Win;   TextColor(Yellow);
   GotoXY(03,01);  Write('TIF-1 und TIF-2 testen!');
   TextColor(Blue);
   GotoXY(S_Base,Z_Base-1);         write('Ifk-Adr  [H]:');
   GotoXY(S_Base,Z_Base  );         write('Modul-Adr[H]:');
   GotoXY(S_Base,Z_Base+1);         write('Modul-ID [H]:');

   GotoXY(S_Single_Rep-7,Z_Single); write('SiRep: ');
{  GotoXY(S_Single_Rep-7,Z_Intr);   write('DRDY : '); }
   GotoXY(S_Single_Rep-7,Z_Out);    write('Input: ');
   GotoXY(S_Output,Z_Out);          write('Output: ');

   GotoXY(S_ModAdr,Z_Base+1);
   if ModIdent.Soll = ModIdent.Ist then
     TextColor(Black)
   else
     TextColor(Red+128);
   write (Hex_Byte(ModIdent.Ist));

   TextColor(Yellow);
{   GotoXY(S_Trigger,Z_Mask_Text);    Write (chr($19));
   TextColor(Red); write('Trigger'); TextColor(Yellow);
}
   GotoXY(S_Mask,Z_Mask_Text);       Write (chr($19)); {Pfeil nach unten}
   TextColor(Red); write('Maske');   TextColor(Blue);

   GotoXY(S_Base,   Z_Evt_Start);  write('TIF-1 Event[H]:');
   GotoXY(S_Base,   Z_Evt_Stop);   write('TIF-2 Event[H]:');

   GotoXY(S_Base,   Z_StartCount); write('StartCount[us]:');
   GotoXY(S_Base,   Z_StopCount);  write('Stop Count[us]:');
   GotoXY(37,Z_HwStat_Hex); write('LSB'); TextColor(Yellow); Write (chr($19)); {Pfeil nach unten}  TextColor(blue);
   GotoXY(S_Base,Z_HwStat_Hex);    write('HardwStatus[H]:');
   GotoXY(S_Base,Z_HwStat_Bin);    write('  "      [Bin]:');
   GotoXY(S_Base,Z_DynStat_Bin);   write('Dyn.Stat [Bin]:');

   Set_Text_Win;
   TextColor(Black);
   GotoXY(S_ModAdr,Z_Base-1);  Write(Hex_Byte(ModAdr.AdrIfc));
   GotoXY(S_ModAdr,Z_ModAdr);  Write(Hex_Byte(ModAdr.AdrCard));

   TextColor(blue);
   GotoXY(02,17); write  ('Belegung der Funktions-Tasten:');
   Set_TastEvt_Win;
   TextColor(Yellow);
   GotoXY(01, 01); Write('F1:Set Modi     F5:             F9 :Modul Adr ');
   GotoXY(01, 02); Write('F2:Set Events   F6:             F10:Ifk   Adr ');
   GotoXY(01, 03); Write('F3:             F7:             F11:          ');
   GotoXY(01, 04); Write('F4:             F8:Rd-DynStat   F12:Soft Reset');

   TextColor(Black);
   Displ_Modul_Stat;
   Set_Text_Win;

   GotoXY(S_Single_Rep, Z_Out); Write(Lo(Data_InOutput));
   GotoXY(S_Single_Rep, Z_In);  Write(Hi(Data_InOutput and $0F00));
   GotoXY(S_Single_Rep, Z_Single);
{
   GotoXY(S_Trigger, Z_Evt_Start);  write(Hex_Word(Trig_Tif1Evt));
   GotoXY(S_Trigger, Z_Evt_Stop);   write(Hex_Word(Trig_Tif2Evt));
}
   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;
   TIF_Test := True;   {nur wegen Diagramm-Anzeige}

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Set_Text_win;
       Show_HwStat_Reg;
       Mil.Timer2_Wait(10000);
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Set_Text_win;
       Show_HwStat_Reg;
       Mil.Timer2_Wait(10000);
      end;

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    Displ_ModiSelect_Win;
                    repeat
                     Ini_Msg_Win;
                     Cursor (True);
                     Write('Mit Buchstabe Mode-Auswahl, <F8> Dyn-Status, <Space> Hw-Status oder <Esc>: ');
                     Zeichen := NewReadKey; TextColor(Red);
                     if Zeichen in ['a'..'z'] then Ch := UpCase(Zeichen) else Ch := Zeichen;
                     if Ch      in ['A'..'Z'] then
                       begin
                        Write (Ch);
                        Mil.Timer2_Wait(50000);
                        Change_Mode (Ch);
                       end;
                     if Ch = Taste_Space then Show_HwStat_Reg;
                     if Ch = #0 then
                       begin
                         Ch := NewReadKey;
                         case ord (Ch) of Taste_F8 : Show_DynStat_Reg; end;
                       end; {Ch=0}
                    until Ch = chr(Taste_Esc);
                    Cursor (False);
                    Ch:= '?';    {Dummy}
                    Std_Msg;
                    Displ_Modul_Stat;
                  end; {F-Taste}
        Taste_F2: begin           {Lade Start + StopEvent und Sende Trigger-Start-, Trig-Stop}
                    Displ_Event_Win;
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrMode:= AdrNew;
                    repeat
                    Ini_Msg_Win;
                    Cursor (True);
                    Write('Eingeben: [');     TextColor(Red); Write('1'); TextColor(Yellow);
                    Write(']TIF1 Mask, [');   TextColor(Red); Write('2'); TextColor(Yellow);
                    Write(']TIF2 Mask, '); {  TextColor(Red); Write('3'); TextColor(Yellow);
                    Write(']Trig Event1  ['); TextColor(Red); Write('4'); TextColor(Yellow);
                    Write(']Trig Event2, [Esc]:'); } Write ('[Esc]');
                    Ch:= NewReadKey;
                    case Ch of
                     '1'    : begin
                               if Ask_Hex_Break (User_In, Wrd) then
                                begin
                                 Set_Text_Win;

                                 GotoXY(S_Mask, Z_Evt_Start);
                                 Write (Hex_Word(User_In));
                                 ModAdr.AdrSub := SubAdr_GpMask_Evt1 ;
                                 Mil.Wr_ModBus (User_In, ModAdr, MilErr);
                                end;
                              end;
                     '2'    : begin
                               if Ask_Hex_Break (User_In, Wrd) then
                                begin
                                 Set_Text_Win;
                                 GotoXY(S_Mask, Z_Evt_Stop);
                                 Write (Hex_Word(User_In));
                                 ModAdr.AdrSub := SubAdr_GpMask_Evt2 ;
                                 Mil.Wr_ModBus (User_In, ModAdr, MilErr);
                                end;
                              end;
{                     '3'    : begin
                               if Ask_Hex_Break (User_In, Wrd) then
                                begin
                                 if Lo(User_In) = Ifc_Test_Nr then
                                  begin
                                   Ini_Err_Win;
                                   Write ('Error: Lo-Byte Event=IFK-Adr!! Hi-Byte wirkt als Fct-Code! Abort mit <Space> : ');
                                   Ch := NewReadKey;  Ch := '?';
                                  end
                                 else
                                  begin
                                   Set_Text_Win;
                                   Trig_Tif1Evt := User_In;
                                   GotoXY(S_Trigger, Z_Evt_Start);   write(Hex_Word(Trig_Tif1Evt));
                                  end;
                                end;
                               Std_Msg;
                              end;
                     '4'    : begin
                               if Ask_Hex_Break (User_In, Wrd) then
                                begin
                                 if Lo(User_In) = Ifc_Test_Nr then
                                  begin
                                   Ini_Err_Win;
                                   Write ('Error: Lo-Byte Event=IFK-Adr!! Hi-Byte wirkt als Fct-Code! Abort mit <Space> : ');
                                   Ch := NewReadKey;  Ch := '?';
                                  end
                                 else
                                  begin
                                   Set_Text_Win;
                                   Trig_Tif2Evt := User_In;
                                   GotoXY(S_Trigger, Z_Evt_Stop);   write(Hex_Word(Trig_Tif2Evt));
                                  end;
                                end;
                                Std_Msg;
                              end;
}                     end; {case}
                    until Ch = chr(Taste_Esc); {until Ch in ['q','Q'];}
                    Std_Msg;
                    Displ_Modul_Stat;
                   end; {F-Taste}
        Taste_F3 : begin   {Sende Start-Event Åber sep- Einschub DTUB}
{                     WriteEvt_To_Milbus (Trig_Tif1Evt);
                     Life_Mode.PosX    := S_Base-1;
                     Life_Mode.PosY    := Z_Evt_Start;
                     Life_Sign_XY (Life_Mode);
}                   end;
        Taste_F4 : begin   {Sende Stop-Event Åber sep- Einschub DTUB}
{                     WriteEvt_To_Milbus (Trig_Tif2Evt);
                     Life_Mode.PosX    := S_Base-1;
                     Life_Mode.PosY    := Z_Evt_Stop;
                     Life_Sign_XY (Life_Mode);
}                   end;
        Taste_F5 : begin
                    {Eingabe in [us]: also umrechnen!!}
                    if Read_LongInt (0,(Count_Max Div Gp_Quarz_Faktor), Start_Cnt.L) then
                      begin
                       Set_Text_Win;
                       GotoXY(S_Count_Int, Z_StartCount); WriteLn ('          ');
                       GotoXY(S_Count_Int, Z_StartCount); Write (Start_Cnt.L:10);
                       Start_Cnt.L   := Start_Cnt.L * (Gp_Quarz_Faktor);
                       ModAdr.AdrIfc := Ifc_Test_Nr;
                       ModAdr.AdrCard:= Mod_Test_Nr;
                       ModAdr.AdrSub := SubAdr_GpStartCnt_Low; {LowWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Start_Cnt.W.Lwr, ModAdr, MilErr);

                       ModAdr.AdrSub := SubAdr_GpStartCnt_Hi;  {HiWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Start_Cnt.W.Upr, ModAdr, MilErr);
                     end;
                     Std_Msg;
                   end; {F-Taste}
        Taste_F6 : begin
                    {Eingabe in [us]: also umrechnen!!}
                    if Read_LongInt (0,(Count_Max Div Gp_Quarz_Faktor), Stop_Cnt.L) then
                      begin
                       Set_Text_Win;
                       GotoXY(S_Count_Int, Z_StopCount); Write ('          ');
                       GotoXY(S_Count_Int, Z_StopCount); Write(Stop_Cnt.L:10);
                       Stop_Cnt.L   := Stop_Cnt.L * (Gp_Quarz_Faktor);
                       ModAdr.AdrIfc := Ifc_Test_Nr;
                       ModAdr.AdrCard:= Mod_Test_Nr;
                       ModAdr.AdrSub := SubAdr_GpStopCnt_Low; {LowWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Stop_Cnt.W.Lwr, ModAdr, MilErr);

                       ModAdr.AdrSub := SubAdr_GpStopCnt_Hi;  {HiWord laden}
                       ModAdr.AdrMode:= AdrNew;
                       Mil.Wr_ModBus (Stop_Cnt.W.Upr, ModAdr, MilErr);
                      end;
                     Std_Msg;
                   end; {F-Taste}
        Taste_F7 : begin           {Output wÑhlen}
                     if Ask_Hex_Break (User_In, Byt) then
                      begin
                       Data_InOutput     := swap(User_In); {Bytes vertauschen}
                       ModAdr.AdrIfc     := Ifc_Test_Nr;
                       ModAdr.AdrCard    := Mod_Test_Nr;
                       ModAdr.AdrSub     := SubAdr_GpInOut;
                       ModAdr.AdrMode    := AdrNew;
                       Write_Data        := Data_InOutput;
                       Mil.Wr_ModBus (Write_Data, ModAdr, MilErr);
                       Set_Text_WIn;
                       Hex_Bin8_Str (Hi(Write_Data), Bit8_Strg);
                       GotoXY(S_Single_Rep, Z_Out);  write(Bit8_Strg);
                      end;
                     Std_Msg;
                  end; {Taste}

        Taste_F8 : Show_DynStat_Reg;
        Taste_F9: begin                            {neue Mod-Adr erfragen}
                   if Ask_Hex_Break (Adress, Byt) then
                    begin
                     ModAdr.AdrCard:= Adress;           {neu}
                     Set_Text_Win;
                     GotoXY(S_ModAdr,Z_ModAdr);  Write(Hex_Byte(ModAdr.AdrCard));
                    end;
                    Std_Msg;
                   end; {Taste_F9}
        Taste_F10: begin                             {neue IFK-Adr erfragen}
                    if Ask_Hex_Break (Adress, Byt) then
                     begin
                      Ifc_Test_Nr := Adress;           {neu}
                      ModAdr.AdrIfc  := Ifc_Test_Nr;
                      Set_Text_Win;
                      GotoXY(S_ModAdr,Z_Base-1);  Write(Hex_Byte(ModAdr.AdrIfc));
                     end;
                    Std_Msg;
                   end; {Taste_F10}
        Taste_F11: begin
                    Start_Cnt.L:= 500; {Default Wert}
                    Stop_Cnt.L := 1000;
                    Set_Text_Win;
                    GotoXY(S_Count_Int, Z_StartCount);  Write ('          ');
                    GotoXY(S_Count_Int, Z_StopCount);   Write ('          ');
                    GotoXY(S_Count_Int, Z_StartCount);  Write (Start_Cnt.L:10);
                    GotoXY(S_Count_Int, Z_StopCount);   Write (Stop_Cnt.L:10);

                    Start_Cnt.L   := Start_Cnt.L * (Gp_Quarz_Faktor);
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrSub := SubAdr_GpStartCnt_Low; {LowWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Start_Cnt.W.Lwr, ModAdr, MilErr);
                    ModAdr.AdrSub := SubAdr_GpStartCnt_Hi;  {HiWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Start_Cnt.W.Upr, ModAdr, MilErr);

                    Stop_Cnt.L   := Stop_Cnt.L * (Gp_Quarz_Faktor);
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrSub := SubAdr_GpStopCnt_Low; {LowWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Stop_Cnt.W.Lwr, ModAdr, MilErr);

                    ModAdr.AdrSub := SubAdr_GpStopCnt_Hi;  {HiWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Stop_Cnt.W.Upr, ModAdr, MilErr);
                    Std_Msg;
                    end; {Taste_F11}
        Taste_F12 : begin
                     ModAdr.AdrIfc  := Ifc_Test_Nr;     {Modul-Adr definieren}
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrSub  := SubAdr_GpSoftReset;
                     ModAdr.AdrMode := AdrNew;
                     Mil.Wr_ModBus (0, ModAdr, MilErr);
                     Ini_Err_Win;
                     Write ('Modul Software Reset');
                     Mil.Timer2_Wait(200000);
                     Std_Msg;
                   end;  {F-Taste}
       end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
  TIF_Test  := False;
 end; {Gpgen_Tif}


 procedure Gpgen_Intr;
  label 99, F7End;
  var
   ModIdent   : TID_Type;
   IdRet_Code : TIfk_IdErr;
   Adr_Error  : Boolean;
   Start_Cnt  : TCounter;
   Stop_Cnt   : TCounter;
   WrData     : Word;
   Adress     : Word;
   User_Lint  : LongInt;
   User_Int   : Integer;
   User_Wrd   : Word;

   Mod_Dmy_Adr: Byte;
   Data_InOutput: Word;
   Data_Byte  : Byte;
   Bit16_Strg : Str19;
   Bit8_Strg  : Str10;

  procedure Set_TastSoft_Win;
  begin
   Window(02, 20, 49, 23);
   TextBackground(Green);
   TextColor(Black);
  end;

  Begin                {Gpgen_Interupts}
   Ini_Text_Win;
   Data_InOutput  := 0;   {Ext. TriggerEingÑnge und Ext. AusgÑnge}
   Intr_Test      := True;

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

   ModIdent.Soll := ModID_GPGen;
   ModIdent.Ist  := 0;
   ModIdent.Mode := Modul;       {nur Modul-Id prÅfen egal welcher Steckplatz}

   if not ID_Check (ModAdr, ModIdent) then         {Ist richtiges Modul da?}
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

   Life_Mode.Mode    := Norm;         {Parameter fÅr Lebenszeichen definieren}
   Life_Mode.Time    := Life_Time_Super;  {Life_Time_Fast; }
   Life_Mode.Disp_Win:= Set_Text_Win;     {Darstellungs-Fenster}


   Set_Text_Win; TextColor(Yellow);
   GotoXY(03,01); write('Setze Intr-Maske u. teste Interrupts!');
   TextColor(Blue);
   GotoXY(S_Base,Z_Base-1);   write('Ifk-Adr  [H]:');
   GotoXY(S_Base,Z_Base  );   write('Modul-Adr[H]:');
   GotoXY(S_Base,Z_Base+1);   write('Modul-ID [H]:');

   GotoXY(S_Single_Rep-7,Z_Single); write('SiRep: ');
   GotoXY(S_Single_Rep-7,Z_Intr);   write('DRDY : ');
   GotoXY(S_Single_Rep-7,Z_Out);    write('Input: ');
   GotoXY(S_Output,Z_Out);          write('Output: ');

   GotoXY(S_ModAdr,Z_Base+1);
   if ModIdent.Soll = ModIdent.Ist then
     TextColor(Black)
   else
     TextColor(Red+128);
   write (Hex_Byte(ModIdent.Ist));

   TextColor(blue);
   GotoXY(S_Base,   Z_Evt_Start);  write('Intr-Maske [H]:');
   GotoXY(S_Base,   Z_Evt_Stop);   write('   "     [Bin]:');
   GotoXY(S_Base,   Z_StartCount); write('StartCount[us]:');
   GotoXY(S_Base,   Z_StopCount);  write('Stop Count[us]:');

   GotoXY(37,Z_HwStat_Hex); write('LSB'); TextColor(Yellow); Write (chr($19)); {Pfeil nach unten}  TextColor(blue);
   GotoXY(S_Base,Z_HwStat_Hex);    write('HardwStatus[H]:');
   GotoXY(S_Base,Z_HwStat_Bin);    write('  "      [Bin]:');
   GotoXY(S_Base,Z_DynStat_Bin);   write('Dyn.Stat [Bin]:');

   Set_Text_Win;
   TextColor(Black);
   GotoXY(S_ModAdr,Z_Base-1);  Write(Hex_Byte(ModAdr.AdrIfc));
   GotoXY(S_ModAdr,Z_ModAdr);  Write(Hex_Byte(ModAdr.AdrCard));


   TextColor(blue);
   GotoXY(02,17); write  ('Belegung der Funktions-Tasten:');
   Set_TastSoft_Win;
   TextColor(Yellow);
   GotoXY(01, 01); Write('F1:ExtTrig En/Dis F5:Intr Mask   F9 :Modul Adr ');
   GotoXY(01, 02); Write('F2:Indep/Transp   F6:Intr En/Dis F10:Ifk   Adr ');
   GotoXY(01, 03); Write('F3:Singl/Repeat   F7:Sel In/Out  F11:LoadCntDef');
   GotoXY(01, 04); Write('F4:Gatepuls En    F8:Rd-DynStat  F12:Soft Reset');
   TextColor(Black);
   Displ_Modul_Stat;
   Set_Text_Win;

   GotoXY(S_Single_Rep, Z_Out); Write('?');
   Cursor(False);
   Std_Msg;
   Ch := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Set_Text_win;
       Show_HwStat_Reg;
       Mil.Timer2_Wait(10000);
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Set_Text_win;
       Show_HwStat_Reg;
       Mil.Timer2_Wait(10000);
      end;

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin       {Toggle Trigger aktiv setzen}
                    GpModi.Bit     := []; {Clear}
                    ModAdr.AdrIfc  := Ifc_Test_Nr;    {Hw-Status lesen}
                    ModAdr.AdrCard := Mod_Test_Nr;
                    ModAdr.AdrSub  := SubAdr_GpModi;
                    ModAdr.AdrMode := AdrNew;
                    Mil.Rd_ModBus (GpModi.Wrd, ModAdr, MilErr);
                    if MilErr = No_Err then
                     begin
                      if TrigSrc0 in GpModi.Bit then
                       begin
                         GpModi.Bit := GpModi.Bit - [TrigSrc0];
                         GpModi.Bit := GpModi.Bit - [TrigSrc1];   {0}
                       end
                      else                       {ext. Triggersource toggeln}
                       begin
                         GpModi.Bit := GpModi.Bit + [TrigSrc0];
                         GpModi.Bit := GpModi.Bit - [TrigSrc1];   {1}
                       end;

                      ModAdr.AdrSub := SubAdr_GpModi;
                      Mil.Wr_ModBus (GpModi.Wrd, ModAdr, MilErr);
                      Ini_Err_Win;
                      Write ('Trigger aktiv/passiv');
                      Mil.Timer2_Wait(100000);
                     end; {if MilErr}
                    Std_Msg;
                   end;

        Taste_F2 : begin    {Toggle Indep/Transp}
                    ModAdr.AdrIfc  := Ifc_Test_Nr;    {Hw-Status lesen}
                    ModAdr.AdrCard := Mod_Test_Nr;
                    ModAdr.AdrSub  := SubAdr_GpModi;
                    ModAdr.AdrMode := AdrNew;
                    Mil.Rd_ModBus (GpModi.Wrd, ModAdr, MilErr);
                    if MilErr = No_Err then
                     begin
                      if TransMode in GpModi.Bit then
                       GpModi.Bit := GpModi.Bit - [TransMode]    {0}
                      else
                       GpModi.Bit := GpModi.Bit + [TransMode];   {1}

                      ModAdr.AdrSub := SubAdr_GpModi;
                      Mil.Wr_ModBus (GpModi.Wrd, ModAdr, MilErr);
                      Ini_Err_Win;
                      Write ('Indep/Transp!');
                      Mil.Timer2_Wait(100000);
                     end; {if MilErr}
                    Std_Msg;
                   end; {F-Taste}
        Taste_F3 : begin    {Toggle Single/Repeat}
                    ModAdr.AdrIfc  := Ifc_Test_Nr;    {Hw-Status lesen}
                    ModAdr.AdrCard := Mod_Test_Nr;
                    ModAdr.AdrSub  := SubAdr_GpModi;
                    ModAdr.AdrMode := AdrNew;
                    Mil.Rd_ModBus (GpModi.Wrd, ModAdr, MilErr);
                    if MilErr = No_Err then
                     begin
                      if RepMode in GpModi.Bit then
                       GpModi.Bit := GpModi.Bit - [RepMode]     {0}
                      else
                       GpModi.Bit := GpModi.Bit + [RepMode];;   {1}

                      ModAdr.AdrSub := SubAdr_GpModi;
                      Mil.Wr_ModBus (GpModi.Wrd, ModAdr, MilErr);
                      Ini_Err_Win;
                      Write ('Single/Repeat!');
                      Mil.Timer2_Wait(100000);
                     end; {if MilErr}
                    Std_Msg;
                   end; {F-Taste}

        Taste_F4 : begin   {Enable Gatepuls}
                     ModAdr.AdrIfc  := Ifc_Test_Nr;     {Modul-Adr definieren}
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrSub  := SubAdr_GpEnable;
                     ModAdr.AdrMode := AdrNew;
                     Mil.Wr_ModBus (1, ModAdr, MilErr);
                     Ini_Err_Win;
                     Write ('Enable Gatepuls!');
                     Mil.Timer2_Wait(100000);
                     Std_Msg;
                   end;
        Taste_F5 : begin
                     Displ_Intr_Win;
                     if Ask_Hex_Break (User_Wrd, Byt) then
                      begin
                       Write_Data    := Lo(User_Wrd);
                       ModAdr.AdrSub := SubAdr_GpIntr_Mask;
                       Mil.Wr_ModBus (Write_Data, ModAdr, MilErr);
                       Set_Text_Win;
                       GotoXY(S_Mask+1, Z_Evt_Start); Write (Hex_Byte(Write_Data));
                       Hex_Bin8_Str (Write_Data, Bit8_Strg);
                       GotoXY(S_Mask+1, Z_Evt_Stop);  Write(Bit8_Strg);
                      end;
                     Displ_Modul_Stat;
                     Std_Msg;
                   end; {F-Taste}
        Taste_F6 : begin    {Toggle Interrrupt enable/disable}
                    Ch := 'I';
                    Change_Mode (Ch);
                    Ini_Err_Win;
                    Write ('Toggle Interrupt En/Dis');
                    Mil.Timer2_Wait(100000);
                    Std_Msg;
                   end; {F-Taste}
        Taste_F7 : begin           {In- u. Output wÑhlen}
                     ModAdr.AdrIfc  := Ifc_Test_Nr;
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrMode := AdrNew;
                     Data_InOutput  := 0;
                     Ini_Msg_Win;
                     Write ('Bitte mit <CR> zur Auswahl des Eingangs dezimal [1 aus 8]  ->');
                     TextColor(Yellow+128); Write('Jetzt <Return>');
                     Ch := NewReadKey;
                     if Read_Int (1,8, User_Int) then Data_InOutput := (Lo(User_Int) - 1) {wegen Hardw. 0..7}
                     else
                      begin
                        Ini_Err_WIn;
                        Write('ERROR: Falsche Eingabe!!  Abort mit <Space> ');
                        Ch := NewReadKey;
                        goto F7End;
                      end;

                     Ini_Msg_Win;
                     Write ('Max. 8 AusgÑnge [8..1] auswÑhlen in Hex [jedes Bit 1 Ausgang]  ->');
                     TextColor(Yellow+128); Write('Jetzt <Return>');
                     Ch := NewReadKey;
                     if Ask_Hex_Break (User_Wrd, Byt) then
                      begin
                       User_Wrd      := User_Wrd shl 8;
                       Data_InOutput := Data_InOutput or User_Wrd;
                       ModAdr.AdrSub := SubAdr_GpInOut;
                       Mil.Wr_ModBus (Data_InOutput, ModAdr, MilErr);
                       Set_Text_Win;
                       GotoXY(S_Single_Rep, Z_Out); Write(Lo(Data_InOutput)+1);
                       Hex_Bin8_Str (Hi(Data_InOutput), Bit8_Strg);
                       GotoXY(S_Output+8, Z_Out);  write(Bit8_Strg);
                      end
                     else
                      begin
                        Ini_Err_WIn;
                        Write('ERROR: Das war keine 2-stellige Hex-Eingabe!!  Abort mit <Space> ');
                        Ch := NewReadKey;
                      end;
              F7End: Ch := '?';
                     Std_Msg;
                     Set_Text_WIn;
                  end; {Taste}

        Taste_F8 : Show_DynStat_Reg;
        Taste_F9: begin                            {neue Mod-Adr erfragen}
                   if Ask_Hex_Break (Adress, Byt) then
                    begin
                     ModAdr.AdrCard:= Adress;           {neu}
                     Set_Text_Win;
                     GotoXY(S_ModAdr,Z_ModAdr);  Write(Hex_Byte(ModAdr.AdrCard));
                    end;
                    Std_Msg;
                   end; {Taste_F9}
        Taste_F10: begin                             {neue IFK-Adr erfragen}
                    if Ask_Hex_Break (Adress, Byt) then
                     begin
                      Ifc_Test_Nr := Adress;           {neu}
                      ModAdr.AdrIfc  := Ifc_Test_Nr;
                      Set_Text_Win;
                      GotoXY(S_ModAdr,Z_Base-1);  Write(Hex_Byte(ModAdr.AdrIfc));
                     end;
                    Std_Msg;
                   end; {Taste_F10}
        Taste_F11: begin
                    Start_Cnt.L:= 500; {Default Wert}
                    Stop_Cnt.L := 1000;
                    Set_Text_Win;
                    GotoXY(S_Count_Int, Z_StartCount); Write ('          ');
                    GotoXY(S_Count_Int, Z_StopCount);  Write ('          ');
                    GotoXY(S_Count_Int, Z_StartCount); Write (Start_Cnt.L:10);
                    GotoXY(S_Count_Int, Z_StopCount);  Write (Stop_Cnt.L:10);

                    Start_Cnt.L   := Start_Cnt.L * (Gp_Quarz_Faktor);
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrSub := SubAdr_GpStartCnt_Low; {LowWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Start_Cnt.W.Lwr, ModAdr, MilErr);
                    ModAdr.AdrSub := SubAdr_GpStartCnt_Hi;  {HiWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Start_Cnt.W.Upr, ModAdr, MilErr);

                    Stop_Cnt.L   := Stop_Cnt.L * (Gp_Quarz_Faktor);
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrSub := SubAdr_GpStopCnt_Low; {LowWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Stop_Cnt.W.Lwr, ModAdr, MilErr);

                    ModAdr.AdrSub := SubAdr_GpStopCnt_Hi;  {HiWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Stop_Cnt.W.Upr, ModAdr, MilErr);
                    Std_Msg;
                    end; {Taste_F11}
        Taste_F12 : begin
                     ModAdr.AdrIfc  := Ifc_Test_Nr;     {Modul-Adr definieren}
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrSub  := SubAdr_GpSoftReset;
                     ModAdr.AdrMode := AdrNew;
                     Mil.Wr_ModBus (0, ModAdr, MilErr);
                     Ini_Err_Win;
                     Write ('Modul Software Reset');
                     Mil.Timer2_Wait(200000);
                     Std_Msg;
                   end;  {F-Taste}
       end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
       Intr_Test := False;
 end; {Gpgen_Intr}


 procedure Gpgen_Evt_Trigger_2Puls;
  label 99;
  const
   Z_Evt_Puls1   = Z_Base+4;
   Z_Evt_Puls2   = Z_Evt_Puls1+1;
   S_Evt_Puls_E  = S_Base+17;
   S_Evt_Puls_A  = S_Base+27;
  var
   ModIdent     : TID_Type;
   IdRet_Code   : TIfk_IdErr;
   Adr_Error    : Boolean;
   Start_Cnt    : TCounter;
   Stop_Cnt     : TCounter;
   WrData,RdData: Word;
   Adress       : Word;
   User_LInt    : LongInt;
   User_Input   : Word;
   Mod_Dmy_Adr  : Byte;
   User_In      : Word;
   Data_InOutput: Word;
   Data_Byte    : Byte;
   Bit16_Strg   : Str19;
   Bit8_Strg    : Str10;
   Trig_Tif1Evt : Word;
   Trig_Tif2Evt : Word;
   Zeichen      : Char;

  procedure Set_TastEvt_Win;
  begin
   Window(02, 20, 49, 23);
   TextBackground(Green);
   TextColor(Black);
  end;

  procedure Clr_Evt_Display;
   begin
     Set_Text_Win;
     GotoXY(S_Evt_Puls_E, Z_Evt_Puls1); Write ('    ');
     GotoXY(S_Evt_Puls_A, Z_Evt_Puls1); Write ('    ');
     GotoXY(S_Evt_Puls_E, Z_Evt_Puls2); Write ('    ');
     GotoXY(S_Evt_Puls_A, Z_Evt_Puls2); Write ('    ');
   end;

  procedure Check_Modul;
   begin
    Ask_Ifc_Mod_Adr;
    ModAdr.AdrIfc  := Ifc_Test_Nr;    {Modul-Adr definieren}
    ModAdr.AdrCard := Mod_Test_Nr;
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

   ModIdent.Soll := ModID_GPGen;
   ModIdent.Ist  := 0;
   ModIdent.Mode := Modul;       {nur Modul-Id prÅfen egal welcher Steckplatz}

   if not ID_Check (ModAdr, ModIdent) then         {Ist richtiges Modul da?}
    begin
      Adr_Error := True;
      Ini_Err_Win;
      Write ('ERROR: I/O-Modul IDENT [Hex] Soll: ', Hex_Byte(ModIdent.Soll),'  Ist: ', Hex_Byte(ModIdent.Ist));
      Write ('    Weiter mit <Space> ');
      Ch := NewReadKey;
    end;
   end; {Check_Modul}

  Begin                     {Gpgen_Tif}
   Ini_Text_Win;
   Data_InOutput     := 0;   {Ext. Trigger EingÑnge und Ext. AusgÑnge}
   Life_Mode.Mode    := Norm;         {Parameter fÅr Lebenszeichen definieren}
   Life_Mode.Time    := Life_Time_Super;  {Life_Time_Fast; }
   Life_Mode.Disp_Win:= Set_Text_Win;     {Darstellungs-Fenster}

   Check_Modul;

   Set_Text_Win;   TextColor(Yellow);
   GotoXY(03,01);  Write('Puls-Funktion TIF1-OUT u. TIF2-OUT testen!');
   TextColor(Blue);
   GotoXY(S_Base,Z_Base-1);         write('Ifk-Adr  [H]:');
   GotoXY(S_Base,Z_Base  );         write('Modul-Adr[H]:');
   GotoXY(S_Base,Z_Base+1);         write('Modul-ID [H]:');
   GotoXY(S_Single_Rep-7,Z_Out);    write('EPLD : ');

   {EPLD-Version anzeigen, ob Modul Åberhaupt fÅr Pulsmode geeignet}
   ModAdr.AdrIfc  := Ifc_Test_Nr;    {Modul-Adr definieren}
   ModAdr.AdrCard := Mod_Test_Nr;
   ModAdr.AdrSub  := ModSub_Adr_EPLD;;
   ModAdr.AdrMode := AdrNew;
   Mil.Rd_ModBus (RdData, ModAdr, MilErr);
   if MilErr = No_Err then
    begin
      RdData := RdData AND $0F00;  {Maske fÅr EPLD-Version}
      RDData := RdData shr 8;
      if (RdData >= 04) then TextColor (Black) else TextColor (Red+128);
      Write (RdData:2);
    end
   else
    Write ('??');

   GotoXY(S_ModAdr,Z_Base+1);
   if ModIdent.Soll = ModIdent.Ist then TextColor(Black) else TextColor(Red+128);
   write (Hex_Byte(ModIdent.Ist));

   TextColor(Yellow);
   GotoXY(S_Trigger,Z_Mask_Text);    Write (chr($19)); {Pfeil nach unten}
   TextColor(Red); write('Ein-Evt'); TextColor(Yellow);
   GotoXY(S_Mask,Z_Mask_Text);       Write (chr($19)); {Pfeil nach unten}
   TextColor(Red); write('Aus-Evt');   TextColor(Blue);
   GotoXY(S_Base,   Z_Evt_Puls1);  write('Puls1 (TIF1->):');
   GotoXY(S_Base,   Z_Evt_Puls2);  write('Puls2 (TIF2->):');

   GotoXY(37,Z_HwStat_Hex); write('LSB'); TextColor(Yellow); Write (chr($19));  TextColor(blue);
   GotoXY(S_Base,Z_HwStat_Hex);    write('HardwStatus[H]:');
   GotoXY(S_Base,Z_HwStat_Bin);    write('  "      [Bin]:');
   GotoXY(S_Base,Z_DynStat_Bin);   write('Dyn.Stat [Bin]:');

   Set_Text_Win;
   TextColor(Black);
   GotoXY(S_ModAdr,Z_Base-1);  Write(Hex_Byte(ModAdr.AdrIfc));
   GotoXY(S_ModAdr,Z_ModAdr);  Write(Hex_Byte(ModAdr.AdrCard));

   TextColor(blue);
   GotoXY(02,17); write  ('Belegung der Funktions-Tasten:');
   Set_TastEvt_Win;
   TextColor(Yellow);
   GotoXY(01, 01); Write('F1:Show Modi    F5:En Puls1     F9 :Modul Adr ');
   GotoXY(01, 02); Write('F2:Set Events   F6:En Puls2     F10:Ifk   Adr ');
   GotoXY(01, 03); Write('F3:En  Pu1+2    F7:             F11:          ');
   GotoXY(01, 04); Write('F4:Dis Pu1+2    F8:Rd-DynStat   F12:Soft Reset');

   TextColor(Black);
   Displ_Modul_Stat;
   Set_Text_Win;

   {Karte in definierten Zustand}
   ModAdr.AdrIfc  := Ifc_Test_Nr;    {Modul-Adr definieren}
   ModAdr.AdrCard := Mod_Test_Nr;
   ModAdr.AdrSub  := SubAdr_GpSoftReset;
   Mil.Wr_ModBus (0, ModAdr, MilErr);
   Show_DynStat_Reg;                  {Disable sichtbar machen}

   Cursor(False);
   Std_Msg;
   Puls_Mode:= True;
   TIF_Test := False;   {nur wegen Diagramm-Anzeige}
   Displ_Puls_Diagramm (PulsMod);
   Ch       := NewReadKey;

    repeat
     if Ch = ' ' then
      begin
       Std_Msg;
       Single_Step := True;
       Set_Text_win;
       Show_HwStat_Reg;
       Mil.Timer2_Wait(10000);
       repeat until KeyEPressed;
       Ch := NewReadKey;
      end;

     if Ch = #13 then Single_Step := False;

     if not Single_Step then
      begin
       Set_Text_win;
       Show_HwStat_Reg;
       Mil.Timer2_Wait(10000);
      end;

     if Ch = #0 then
      begin
       Ch := NewReadKey;
       case ord (Ch) of
        Taste_F1 : begin
                    Displ_ModiSelect_Win;
                    Ini_Msg_Win;
                    Write('Weiter mit <Space> ');
                    repeat until KeyEPressed;
                    Ch := NewReadKey;
                    Displ_Modul_Stat;
                    Std_Msg;
                  end; {F-Taste}
        Taste_F2: begin           {Lade Start + StopEvent und Sende Trigger-Start-, Trig-Stop}
                    Displ_PulsEvt_Win;
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrMode:= AdrNew;
                    repeat
                    Ini_Msg_Win;
                    Cursor (True);
                    Write('Eingeben: [');    TextColor(Red); Write('1'); TextColor(Yellow);
                    Write(']Puls1 Ein, [');  TextColor(Red); Write('2'); TextColor(Yellow);
                    Write(']Puls1 Aus, [');  TextColor(Red); Write('3'); TextColor(Yellow);
                    Write(']Puls2 Ein, [');  TextColor(Red); Write('4'); TextColor(Yellow);
                    Write(']Puls2 Aus, [Esc]:');
                    Ch:= NewReadKey;
                    case Ch of
                     '1'    : begin
                               if Ask_Hex_Break (User_In, Wrd) then
                                begin
                                 Set_Text_Win;
                                 GotoXY(S_Evt_Puls_E, Z_Evt_Puls1);
                                 Write (Hex_Word(User_In));
                                 ModAdr.AdrSub := SubAdr_GpPuls1_EinEvt;
                                 Mil.Wr_ModBus (User_In, ModAdr, MilErr);
                                end;
                              end;
                     '2'    : begin
                               if Ask_Hex_Break (User_In, Wrd) then
                                begin
                                 Set_Text_Win;
                                 GotoXY(S_Evt_Puls_A, Z_Evt_Puls1);
                                 Write (Hex_Word(User_In));
                                 ModAdr.AdrSub := SubAdr_GpPuls1_AusEvt;
                                 Mil.Wr_ModBus (User_In, ModAdr, MilErr);
                                end;
                              end;
                     '3'    : begin
                               if Ask_Hex_Break (User_In, Wrd) then
                                begin
                                 Set_Text_Win;
                                 GotoXY(S_Evt_Puls_E, Z_Evt_Puls2);
                                 Write (Hex_Word(User_In));
                                 ModAdr.AdrSub := SubAdr_GpPuls2_EinEvt;
                                 Mil.Wr_ModBus (User_In, ModAdr, MilErr);
                                end;
                              end;
                     '4'    : begin
                               if Ask_Hex_Break (User_In, Wrd) then
                                begin
                                 Set_Text_Win;
                                 GotoXY(S_Evt_Puls_A, Z_Evt_Puls2);
                                 Write (Hex_Word(User_In));
                                 ModAdr.AdrSub := SubAdr_GpPuls2_AusEvt;
                                 Mil.Wr_ModBus (User_In, ModAdr, MilErr);
                                end;
                              end;
                     end; {case}
                    until Ch = chr(Taste_Esc); {until Ch in ['q','Q']; }
                    Std_Msg;
                    Displ_Modul_Stat;
                   end; {F-Taste}
        Taste_F3 : begin
                    Change_Mode_2Puls (EnAll);
                    Ini_Err_Win;
                    Cursor (True);
                    Write('Enable Puls1 + Puls2 !');
                    Mil.Timer2_Wait(50000);
                    Show_DynStat_Reg;         {Zeige Enable-Bits}
                    Std_Msg;
                  end; {Taste}
        Taste_F4 : begin
                    Change_Mode_2Puls (DisAll);
                    Ini_Err_Win;
                    Cursor (True);
                    Write('Disable Puls1 + Puls2 !');
                    Mil.Timer2_Wait(50000);
                    Show_DynStat_Reg;         {Zeige Enable-Bits}
                    Std_Msg;
                   end; {F-Taste}

        Taste_F5 : begin
                    Change_Mode_2Puls (EnPuls1);
                    Ini_Err_Win;
                    Cursor (True);
                    Write('Enable Puls1 !');
                    Mil.Timer2_Wait(50000);
                    Show_DynStat_Reg;         {Zeige Enable-Bits}
                    Std_Msg;
                   end; {F-Taste}
        Taste_F6 : begin
                    Change_Mode_2Puls (EnPuls2);
                    Ini_Err_Win;
                    Cursor (True);
                    Write('Enable Puls2 !');
                    Mil.Timer2_Wait(50000);
                    Show_DynStat_Reg;         {Zeige Enable-Bits}
                    Std_Msg;
                   end; {F-Taste}

        Taste_F8 : Show_DynStat_Reg;
        Taste_F9: begin                            {neue Mod-Adr erfragen}
                   if Ask_Hex_Break (Adress, Byt) then
                    begin
                     Mod_Test_Nr   := Adress;
                     ModAdr.AdrCard:= Mod_Test_Nr;           {neu}
                     Set_Text_Win;
                     GotoXY(S_ModAdr,Z_ModAdr);  Write(Hex_Byte(ModAdr.AdrCard));
                    end;
                    Std_Msg;
                   end; {Taste_F9}
        Taste_F10: begin                             {neue IFK-Adr erfragen}
                    if Ask_Hex_Break (Adress, Byt) then
                     begin
                      Ifc_Test_Nr := Adress;           {neu}
                      ModAdr.AdrIfc  := Ifc_Test_Nr;
                      Set_Text_Win;
                      GotoXY(S_ModAdr,Z_Base-1);  Write(Hex_Byte(ModAdr.AdrIfc));
                     end;
                    Std_Msg;
                   end; {Taste_F10}
        Taste_F11: begin
                    Start_Cnt.L:= 500; {Default Wert}
                    Stop_Cnt.L := 1000;
                    Set_Text_Win;
                    GotoXY(S_Count_Int, Z_StartCount);  Write ('          ');
                    GotoXY(S_Count_Int, Z_StopCount);   Write ('          ');
                    GotoXY(S_Count_Int, Z_StartCount);  Write (Start_Cnt.L:10);
                    GotoXY(S_Count_Int, Z_StopCount);   Write (Stop_Cnt.L:10);

                    Start_Cnt.L   := Start_Cnt.L * (Gp_Quarz_Faktor);
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrSub := SubAdr_GpStartCnt_Low; {LowWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Start_Cnt.W.Lwr, ModAdr, MilErr);
                    ModAdr.AdrSub := SubAdr_GpStartCnt_Hi;  {HiWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Start_Cnt.W.Upr, ModAdr, MilErr);

                    Stop_Cnt.L   := Stop_Cnt.L * (Gp_Quarz_Faktor);
                    ModAdr.AdrIfc := Ifc_Test_Nr;
                    ModAdr.AdrCard:= Mod_Test_Nr;
                    ModAdr.AdrSub := SubAdr_GpStopCnt_Low; {LowWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Stop_Cnt.W.Lwr, ModAdr, MilErr);

                    ModAdr.AdrSub := SubAdr_GpStopCnt_Hi;  {HiWord laden}
                    ModAdr.AdrMode:= AdrNew;
                    Mil.Wr_ModBus (Stop_Cnt.W.Upr, ModAdr, MilErr);
                    Std_Msg;
                    end; {Taste_F11}
        Taste_F12 : begin
                     ModAdr.AdrIfc  := Ifc_Test_Nr;     {Modul-Adr definieren}
                     ModAdr.AdrCard := Mod_Test_Nr;
                     ModAdr.AdrSub  := SubAdr_GpSoftReset;
                     ModAdr.AdrMode := AdrNew;
                     Mil.Wr_ModBus (0, ModAdr, MilErr);
                     Clr_Evt_Display;  {Anzeigen, dass Events gelîscht sind}
                     Show_DynStat_Reg; {Disable sichtbar machen}
                     Ini_Err_Win;
                     Write ('Modul Software Reset');
                     Mil.Timer2_Wait(200000);
                     Std_Msg;
                   end;  {F-Taste}
       end;  {Case}
     end;
    if KeyEPressed then Ch := NewReadKey;
   until Ch in ['x','X'];
  99:  Cursor(True);
  TIF_Test  := False;
  Puls_Mode := False;
 end; {Gpgen_Evt_Trigger_2Puls}

begin                      { Hauptprogramm }
  Ifc_Test_Nr := 0;
  Mod_Test_Nr := 0;
  TIF_Test    := False;
  Intr_Test   := False;
  Puls_Mode   := False;

  repeat
    Menue_Win;
    User_Input  := ReadKey;
    Single_Step := True;
    case User_Input of
     '0'      : Mil_Detect_Ifc;
     '1'      : Mil_Detect_Ifc_Compare;
     '2'      : begin
                  Mil_Ask_Ifc;
                  Mil_Rd_HS_Ctrl (Ifc_Test_Nr);
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
                       Gpgen_Softw_Trigger;
                     end;
          'n', 'N' : begin
{	              if (Ifc_Test_Nr=0) or (Mod_Test_Nr=0) then Ask_Ifc_Mod_Adr;
}                       Gpgen_Evt_Trigger;
                     end;
          'o', 'O' : begin
{	              if (Ifc_Test_Nr=0) or (Mod_Test_Nr=0) then Ask_Ifc_Mod_Adr;
}                       Gpgen_Ext_Trigger;
                     end;
          'p', 'P' : begin
{	              if (Ifc_Test_Nr=0) or (Mod_Test_Nr=0) then Ask_Ifc_Mod_Adr;
}                       Gpgen_Tif;
                     end;
          'q', 'Q' : begin
	              if (Ifc_Test_Nr=0) or (Mod_Test_Nr=0) then Ask_Ifc_Mod_Adr;
                       Gpgen_Intr;
                     end;
          'r', 'R' : begin
                       Gpgen_Evt_Trigger_2Puls;
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
end. {mil_GPGE}
