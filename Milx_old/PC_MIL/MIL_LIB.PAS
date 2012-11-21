UNIT mil_lib;             {TURBO PASCAL  V 7.0}
{
  Mil-Objects in einer eigenen Unit konzentriert:  MIL_LIB.PAS
  Software Interface fÅr die PC-MIL-Karte. Zwei 16-Bit Hardware-Timer vorhanden
  Timer1-Ticks = 10 us, Timer2-Ticks 10 us oder 1 ms
   Changes:
  23.06.93 Et  Hardware Timer hinzugefÅgt
  08.07.93 Et  Timeouts Åberarbeitet
  30.07.93 Et  2. Hardware Timer eingebaut
  09.08.93 Et  hw_timer1 u. 2 aufrufbar
  21.08.93 Et  hw_timer2 umschaltbar auf 1ms, rÅcksetzen auf 10 us: mit Reset
  01.12.93 Et  Timeout-Constante time_max auf $F00 erhîht
  11.01.94 Et  Mil-Read: statt timeout, valid-word testen
}

INTERFACE                               { Teil der UNIT-Deklaration }
CONST
 stat_port   = $220;
 data_port   = $222;
 mode_port   = $224;
 rset_port   = $226;
 intr_port   = $228;   {wichtig fÅr GerÑte-Simulation: Interrupts setzen}
 timer1_port = $22A;   {set and start timer}
 timer2_port = $22C;   {set and start timer}
 tmr2_1ms_port  = $22E;   {Ansprechen der Adr. schaltet Timer2 auf 1 ms}

 dta_mode   = 0;
 cmd_mode   = 1;
 reset_mil  = 1;

 stat_timer2   = $800; {Bit 11 Hardware-Timer2 Clock-Ticks: 0=10us 1=1ms}
 stat_timeout2 = $400; {Bit 10 Hardware-Timer2 abgelaufen: 0=no 1=:yes  }
 stat_timeout1 = $200; {Bit 09 Hardware-Timer1 abgelaufen: 0=no 1=:yes  }
 stat_cmd_rcv  = $100; {Bit 08 Bit erst gÅltig nach dem Lesen der FiFo-Daten!!}
 stat_cmd_mode = $80;  {Bit 07 }
 stat_ffo_ful  = $40;  {Bit 06 }
 stat_ffo_ety  = $20;  {Bit 05 }
 stat_val_wrd  = $10;  {Bit 04 }
 stat_wrt_rdy  = $08;  {Bit 03 }
 stat_dta_req  = $04;  {Bit 02 }
 stat_dta_rdy  = $02;  {Bit 01 }
 stat_intlock  = $01;  {Bit 00 }

 fct_read_status = $C9; {siehe auch: Allgemeine IFC-Karte}
 time_max        = $F00; {Software Timeout: Vorsicht > CPU-Speed abhÑngig!!}
                        {getestet fÅr CPU 486 mit 33 MHz}
TYPE
 Tmil = OBJECT
         wr_timout  : BOOLEAN;          { Daten bzw. Variablen des Objectes }
         rd_timout  : BOOLEAN;
         PROCEDURE reset;                          { Statische Methoden }
         FUNCTION  rd_status   : WORD;
         PROCEDURE wr_fct_code (cmd_word:WORD); {Hibyte: fct_code, Lob:Adr}
         PROCEDURE write_data (data: WORD);
         FUNCTION  read_data   : WORD;
         FUNCTION  wr_timeout  : BOOLEAN;    {Software. CPU-Speed beachten}
         FUNCTION  rd_timeout  : BOOLEAN;    {Software. CPU-Speed beachten}
         FUNCTION  ifc_online (ifc_adr: WORD): BOOLEAN;
         FUNCTION  set_mil_intr (intr_pattern: WORD): BOOLEAN;
         PROCEDURE hw_timer1_set (hw_time: WORD); {startet Timer1! 10us-Ticks}
         FUNCTION  hw_timeout1 : BOOLEAN;
         PROCEDURE hw_timer2_set (hw_time: WORD); {startet Timer2! 10us/1ms-Ticks}
         FUNCTION  hw_timeout2  : BOOLEAN;
         PROCEDURE hw_timer2_1ms; {1ms-Ticks, zurÅck auf 10 us nur mit reset}
        End; {Tmil}

IMPLEMENTATION                          { Teil der UNIT-Deklaration }
 FUNCTION Tmil.ifc_online;
  VAR cmd_word   : WORD;
      mil_status : WORD;
      rd_data    : WORD;
      time       : LONGINT;

  FUNCTION timeout: BOOLEAN;
    Begin
      timeout := FALSE;
      IF time = 0 THEN timeout := TRUE  ELSE  time := time - 1;
    End; {Timeout}

 Begin
   ifc_online := FALSE;
   cmd_word   := fct_read_status * 256;  {fct-code ins Hibyte}
   cmd_word   := cmd_word + ifc_adr;   {ifc-adr  ins Lobyte}
   PORTW [rset_port] := reset_mil;  {Schafft klare VerhÑltnisse!!}
   Tmil.wr_fct_code (cmd_word);        {schreibe FCT: lese status von IFC}
   time := time_max;
   REPEAT
     mil_status := PORTW [stat_port];
   UNTIL ((mil_status AND stat_val_wrd) = stat_val_wrd)  OR timeout;
   IF NOT timeout THEN
    Begin                {PrÅfe, ob Adresse im Datenwort stimmt}
     rd_data := PORTW [data_port];          {Mil-Daten aus FIFO}
     IF rd_data AND ifc_adr = ifc_adr THEN
       ifc_online := TRUE;
    End;
   PORTW [rset_port] := reset_mil;  {Auf jeden Fall alles lîschen!!}
 End;

 PROCEDURE Tmil.reset;
  Begin
    PORTW [rset_port] := reset_mil;
  End;

 PROCEDURE Tmil.hw_timer2_1ms;
  Begin
    PORTW [tmr2_1ms_port] := 0; {Dummy-Write genÅgt, um auf 1ms zu schalten}
  End;

 FUNCTION Tmil.rd_status;
  Begin
    rd_status := PORTW [stat_port];
  End;

 FUNCTION Tmil.wr_timeout;
  Begin
    wr_timeout := wr_timout;
  End;

 FUNCTION Tmil.rd_timeout;
  Begin
    rd_timeout := rd_timout;
  End;

 FUNCTION Tmil.read_data;
  VAR mil_status: WORD;
      time      : LONGINT;
  FUNCTION timeout: BOOLEAN;
    Begin
      timeout := FALSE;
      IF time = 0 THEN timeout := TRUE  ELSE  time := time - 1;
    End; {Timeout}
  Begin
     time      := time_max;
     rd_timout := TRUE;
     REPEAT
      mil_status := PORTW [stat_port];
     UNTIL ((mil_status AND stat_val_wrd) = stat_val_wrd)  OR timeout;
     IF ((mil_status AND stat_val_wrd) = stat_val_wrd) THEN
      Begin
       read_data := PORTW [data_port];           {Mil-Daten schreiben}
       rd_timout := FALSE;
      End;
  End; {Tmil_read_data}

 PROCEDURE Tmil.write_data (data: WORD);   {Procedure local im Object}
  VAR mil_status: WORD;
      time      : LONGINT;
  FUNCTION timeout: BOOLEAN;
    Begin
      timeout := FALSE;
      IF time = 0 THEN timeout := TRUE  ELSE  time := time - 1;
    End; {Timeout}

  Begin
    wr_timout := TRUE;
    time      := time_max;
    PORTW [mode_port] := dta_mode;
    REPEAT
     mil_status := PORTW [stat_port];
    UNTIL ((mil_status AND stat_wrt_rdy) = stat_wrt_rdy)  OR timeout;
    IF NOT timeout THEN
     Begin
      PORTW [data_port] := data;              {Mil-Daten schreiben}
      wr_timout := FALSE;
     End;
  End; {write_data}

 PROCEDURE Tmil.wr_fct_code;
  VAR dummy_data : WORD;
      mil_status : WORD;
      time       : LONGINT;
  FUNCTION timeout: BOOLEAN;
    Begin
      timeout := FALSE;
      IF time = 0 THEN timeout := TRUE  ELSE  time := time - 1;
    End; {Timeout}

  Begin
    wr_timout := TRUE;
    time      := time_max;
    PORTW [mode_port] := cmd_mode;
    REPEAT
     mil_status := PORTW [stat_port];
    UNTIL ((mil_status AND stat_wrt_rdy) = stat_wrt_rdy)  OR timeout;
    IF NOT timeout THEN
     Begin
      PORTW [data_port] := cmd_word;              {Mil-Daten schreiben}
      wr_timout := FALSE;
     End;
  End;  {wr_fct_code}

  PROCEDURE Tmil.hw_timer1_set;   {setzt u. startet den Timer: 10 us Ticks}
  Begin
   PORTW [timer1_port] := hw_time;
  End;

 FUNCTION Tmil.hw_timeout1;
  VAR status : WORD;
  Begin
    hw_timeout1 := FALSE;
    status := PORTW [stat_port];
    IF status AND stat_timeout1 = stat_timeout1 THEN hw_timeout1 := TRUE;
  End;

 PROCEDURE Tmil.hw_timer2_set;   {setzt u. startet den Timer: 10 us Ticks}
  Begin
   PORTW [timer2_port] := hw_time;
  End;

 FUNCTION Tmil.hw_timeout2;
  VAR status : WORD;
  Begin
    hw_timeout2 := FALSE;
    status := PORTW [stat_port];
    IF status AND stat_timeout2 = stat_timeout2 THEN hw_timeout2 := TRUE;
  End;

 FUNCTION Tmil.set_mil_intr (intr_pattern: WORD): BOOLEAN;
  VAR status : WORD;
  Begin
    set_mil_intr := FALSE;
    IF intr_pattern IN [0..7] THEN   {nur interlock, drdy, dreq erlaubt}
     Begin
      PORTW [intr_port] := intr_pattern;
      status := PORTW [stat_port];         {PrÅfe, ob Bits gesetzt sind}
      IF status AND intr_pattern = intr_pattern THEN set_mil_intr := TRUE;
     End;
  End;
END.  { UNIT }
