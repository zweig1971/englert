program Test10;   {Grafik-Test 07.08.96 Et}

uses  Crt, Dos, Graph;
(* {$DEFINE Use8514}  *)
{$DEFINE MIL_PC}

const
  CharSize1 = 1;
  CharSize2 = 2;

  VESA16Modes: array[0..2] of Word =
    ($0102, $0104, $0106);

  { The ten fonts available }
  Fonts : array[0..10] of string[17] =
  ('DefaultFont', 'TriplexFont', 'SmallFont', 'SansSerifFont', 'GothicFont',
   'ScriptFont', 'SimplexFont', 'TriplexScriptFont', 'ComplexFont',
   'EuropeanFont', 'BoldFont');

  { The five predefined line styles supported }
  LineStyles : array[0..4] of string[9] =
  ('SolidLn', 'DottedLn', 'CenterLn', 'DashedLn', 'UserBitLn');

  { The twelve predefined fill styles supported }
  FillStyles : array[0..11] of string[14] =
  ('EmptyFill', 'SolidFill', 'LineFill', 'LtSlashFill', 'SlashFill',
   'BkSlashFill', 'LtBkSlashFill', 'HatchFill', 'XHatchFill',
   'InterleaveFill', 'WideDotFill', 'CloseDotFill');

  { The two text directions available }
  TextDirect : array[0..1] of string[8] = ('HorizDir', 'VertDir');

  { The Horizontal text justifications available }
  HorizJust  : array[0..2] of string[10] = ('LeftText', 'CenterText', 'RightText');

  { The vertical text justifications available }
  VertJust   : array[0..2] of string[10] = ('BottomText', 'CenterText', 'TopText');


type
  VgaInfoBlock = record
    VESASignature: array[0..3] of Byte;
    VESAVersion: Word;
    OEMStringPtr: Pointer;
    Capabilities: array[0..3] of Byte;
    VideoModePtr: Pointer;
  end;

var
  GraphDriver : integer;  { The Graphics device driver }
  GraphMode   : integer;  { The Graphics mode value }
  MaxX, MaxY  : word;     { The maximum resolution of the screen }
  ErrorCode   : integer;  { Reports any graphics errors }
  MaxColor    : word;     { The maximum color value available }
  OldExitProc : Pointer;  { Saves exit procedure address }
  VESA16      : Integer;  { Driver number of 16 color driver }

 procedure DefaultColors;
 { Select the maximum color in the Palette for the drawing color }
 begin
   SetColor(MaxColor);
 end; { DefaultColors }

procedure FullPort; { Set the view port to the entire screen }
begin
  SetViewPort(0, 0, MaxX, MaxY, ClipOn);
end; { FullPort }

procedure StatusLine(Msg : string); { Display a status line at the bottom of the screen }
begin
  FullPort;
{  DefaultColors;   }
  SetColor(15);             {15 = Weiá}
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(CenterText, TopText);
  SetLineStyle(SolidLn, 0, NormWidth);
  SetFillStyle(EmptyFill, 0);
  Bar(0, MaxY-(TextHeight('M')+4), MaxX, MaxY);      { Erase old status line }
  Rectangle(0, MaxY-(TextHeight('M')+4), MaxX, MaxY);
  OutTextXY(MaxX div 2, MaxY-(TextHeight('M')+2), Msg);
  { Go back to the main window }
  SetViewPort(1, TextHeight('M')+5, MaxX-1, MaxY-(TextHeight('M')+5), ClipOn);
end; { StatusLine }

 procedure WaitToGo;  { Wait for the user to abort the program or continue }
 const
   Esc = #27;
 var
   Ch : char;
 begin
   StatusLine('Esc aborts or press a key...');
   repeat until KeyPressed;
   Ch := ReadKey;
   if ch = #0 then ch := readkey;      { trap function keys }
   if Ch = Esc then
     Halt(0)                           { terminate program }
   else
     ClearDevice;                      { clear screen, go on with demo }
 end; { WaitToGo }


 function Int2Str(L : LongInt) : string;
 { Converts an integer to a string for use with OutText, OutTextXY }
 var
   S : string;
 begin
   Str(L, S);
   Int2Str := S;
 end; { Int2Str }

 procedure DrawBorder;  { Draw a border around the current view port }
 var
   ViewPort : ViewPortType;
 begin
   DefaultColors;
   SetLineStyle(SolidLn, 0, NormWidth);
   GetViewSettings(ViewPort);
   with ViewPort do
     Rectangle(0, 0, x2-x1, y2-y1);
 end; { DrawBorder }

 { Scan the supported mode table for the highest mode this card
   will provide }
 function GetHighestCap(Table: Pointer; Modes: Word; Size: Integer): Integer;
   near; assembler;
 asm
         XOR     AX,AX
         LES     DI, Table
 @@1:
         MOV     SI, Modes
         ADD     SI, Size
         ADD     SI, Size
         MOV     BX, ES:[DI]
         CMP     BX, 0FFFFH
         JE      @@4
         INC     DI
         INC     DI
         MOV     CX,Size
 @@2:
         CMP     BX,[SI]
         JZ      @@3
         DEC     SI
         DEC     SI
         LOOP    @@2
 @@3:
         CMP     AX,CX
         JA      @@1
         MOV     AX,CX
         JMP     @@1
 @@4:
 end;

  {$F+}
  procedure MyExitProc;
  begin
    ExitProc := OldExitProc; { Restore exit procedure address }
    CloseGraph;              { Shut down the graphics system }
  end; { MyExitProc }
  {$F-}

 function DetectVesa16: Integer; far; assembler;
 var
   VesaInfo: array[0..255] of Byte;
 asm
         MOV     AX,SS
         MOV     ES,AX
         LEA     DI,VesaInfo
         MOV     AX,4F00H
         INT     10H
         CMP     AX,004FH
         MOV     AX,grError
         JNZ     @@Exit
         CMP     ES:[DI].VgaInfoBlock.VESASignature.Word[0], 'EV'
         JNZ     @@Exit
         CMP     ES:[DI].VgaInfoBlock.VESASignature.Word[2], 'AS'
         JNZ     @@Exit
         LES     DI,ES:[DI].VgaInfoBlock.VideoModePtr
         PUSH    ES
         PUSH    DI
         MOV     AX, OFFSET Vesa16Modes
         PUSH    AX
         MOV     AX,3
         PUSH    AX
         CALL    GetHighestCap
 @@Exit:
 end;

 procedure Initialize;
 { Initialize graphics and report any errors that may occur }
 var
   InGraphicsMode : boolean; { Flags initialization of graphics mode }
   PathToDriver   : string;  { Stores the DOS path to *.BGI & *.CHR }
 begin
   { when using Crt and graphics, turn off Crt's memory-mapped writes }
   DirectVideo := False;
   OldExitProc := ExitProc;                { save previous exit proc }
   ExitProc := @MyExitProc;                { insert our exit proc in chain }

   {$IFDEF MIL_PC}                          { check for Use8514 $DEFINE }
   PathToDriver := 'C:\PC_MIL';
   {$ELSE}
   PathToDriver := 'D:\TP\BGI';
   {$ENDIF}
   repeat
     VESA16 := InstallUserDriver('VESA16', @DetectVESA16);

 {$IFDEF Use8514}                          { check for Use8514 $DEFINE }
     GraphDriver := IBM8514;
     GraphMode   := IBM8514Hi;
 {$ELSE}
     GraphDriver := Detect;                { use autodetection }
 {$ENDIF}
     InitGraph(GraphDriver, GraphMode, PathToDriver);
     ErrorCode := GraphResult;             { preserve error return }
     if ErrorCode <> grOK then             { error? }
     begin
       Writeln('Graphics error: ', GraphErrorMsg(ErrorCode));
       if ErrorCode = grFileNotFound then  { Can't find driver file }
       begin
         Writeln('Enter full path to BGI driver or type <Ctrl-Break> to quit:');
         Readln(PathToDriver);
         Writeln;
       end
       else
         Halt(1);                          { Some other error: terminate }
     end;
   until ErrorCode = grOK;

   Randomize;                { init random number generator }
{   MaxColor := GetMaxColor;}  { Get the maximum allowable drawing color }
   MaxColor := 10;
   MaxX := GetMaxX;          { Get screen resolution values }
   MaxY := GetMaxY;
 end; { Initialize }

 procedure MainWindow(Header : string);
 { Make a default window and view port for demos }
 begin
   DefaultColors;                           { Reset the colors }
   ClearDevice;                             { Clear the screen }
   SetTextStyle(GothicFont, HorizDir, CharSize2);  { Default text font }
   SetTextJustify(CenterText, TopText);     { Left justify text }
   FullPort;                                { Full screen view port }
   OutTextXY(MaxX div 2, 2, Header);        { Draw the header }
   { Draw main window }
   SetViewPort(0, TextHeight('M')+4, MaxX, MaxY-(TextHeight('M')+4), ClipOn);
   DrawBorder;                              { Put a border around it }
   { Move the edges in 1 pixel on all sides so border isn't in the view port }
   SetViewPort(1, TextHeight('M')+5, MaxX-1, MaxY-(TextHeight('M')+5), ClipOn);
 end; { MainWindow }

 procedure GetDriverAndMode(var DriveStr, ModeStr : string);
 { Return strings describing the current device driver and graphics mode
   for display of status report }
 begin
   DriveStr := GetDriverName;
   ModeStr  := GetModeName(GetGraphMode);
 end; { GetDriverAndMode }


 procedure ReportStatus;
 { Display the status of all query functions after InitGraph }
 const
   X = 10;

 var
   ViewInfo   : ViewPortType;     { Parameters for inquiry procedures }
   LineInfo   : LineSettingsType;
   FillInfo   : FillSettingsType;
   TextInfo   : TextSettingsType;
   Palette    : PaletteType;
   DriverStr  : string;           { Driver and mode strings }
   ModeStr    : string;
   Y          : word;

  procedure WriteOut(S : string); {Write out a string + increment to next line}
   begin
    OutTextXY(X, Y, S);
    Inc(Y, TextHeight('M')+2);
   end; { WriteOut }

 begin { ReportStatus }
   GetDriverAndMode(DriverStr, ModeStr);
   GetViewSettings(ViewInfo);
   GetLineSettings(LineInfo);
   GetFillSettings(FillInfo);
   GetTextSettings(TextInfo);
   GetPalette(Palette);

   Y := 4;
   MainWindow('Status report after InitGraph lt. G. Englert   7.8.96');

   SetTextStyle(DefaultFont, HorizDir, CharSize1);  { Default text font }
   SetBkColor(Magenta);

   SetTextJustify(LeftText, TopText);
   WriteOut('Graphics device    : '+DriverStr);
   WriteOut('Graphics mode      : '+ModeStr);

   WriteOut('Screen resolution  : (0, 0, '+Int2Str(GetMaxX)+', '+Int2Str(GetMaxY)+')');
   with ViewInfo do
   begin
     WriteOut('Current view port  : ('+Int2Str(x1)+', '+Int2Str(y1)+', '+Int2Str(x2)+', '+Int2Str(y2)+')');
     if ClipOn then
       WriteOut('Clipping           : ON')
     else
       WriteOut('Clipping           : OFF');
   end;
   WriteOut('Current position   : ('+Int2Str(GetX)+', '+Int2Str(GetY)+')');
   WriteOut('Palette entries    : '+Int2Str(Palette.Size));
   WriteOut('GetMaxColor        : '+Int2Str(GetMaxColor));
   WriteOut('Current color      : '+Int2Str(GetColor));
   with LineInfo do
   begin
     WriteOut('Line style         : '+LineStyles[LineStyle]);
     WriteOut('Line thickness     : '+Int2Str(Thickness));
   end;
   with FillInfo do
   begin
     WriteOut('Current fill style : '+FillStyles[Pattern]);
     WriteOut('Current fill color : '+Int2Str(Color));
   end;
   with TextInfo do
   begin
     WriteOut('Current font       : '+Fonts[Font]);
     WriteOut('Text direction     : '+TextDirect[Direction]);
     WriteOut('Character size     : '+Int2Str(CharSize));
     WriteOut('Horizontal justify : '+HorizJust[Horiz]);
     WriteOut('Vertical justify   : '+VertJust[Vert]);
   end;
   WaitToGo;
 end; { ReportStatus }


begin           {Haupt-Programm}
  Initialize;
  ReportStatus;


end.
