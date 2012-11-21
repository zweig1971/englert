UNIT mil_tmr1;             { TURBO PASCAL ab V 5.5 }

INTERFACE

CONST
 c_res = $0001;

 stat_intlock  = $0001;
 stat_dta_rdy  = $0002;
 stat_dta_req  = $0004;
 stat_wrt_rdy  = $0008;
 stat_val_wrd  = $0010;
 stat_ffo_ety  = $0020;
 stat_ffo_ful  = $0040;
 stat_cmd_mode = $0080;
 stat_cmd_rcv  = $0100;
 stat_timeout1 = $0200; { Bit 09 Hardware-Timer1: 0=laeuft, 1=abgelaufen  }
 stat_timeout2 = $0400; { Bit 10 Hardware-Timer2: 0=laeuft, 1=abgelaufen  }
 stat_timer2   = $0800; { Bit 11 Hardware-Timer2 Clock-Ticks: 0=10us 1=1ms}

 ifc_irmask_all  = $E000; {Interrupt Enable Maske auf der IFC-Karte}
 ifc_irmask_intl = $8000;
 ifc_irmask_drdy = $4000;
 ifc_irmask_dreq = $2000;

 ifc_stat_dreq   = $0400;
 ifc_stat_drdy   = $0800;
 ifc_stat_intl   = $1000;


 c_fc_sw1    = $06;
 c_fc_sw2    = $07;
 c_fc_sw3    = $08;
 c_fc_sw4    = $09;
 c_fc_reset  = $01;
 c_fc_wr_irm = $12;
 c_fc_iw1    = $81;
 c_fc_iw2    = $82;
 c_fc_stat   = $C9;

 p_stat      = $220;
 p_data      = $222;
 p_mode      = $224;
 p_rset      = $226;
 p_intr      = $228;   {wichtig fÅr GerÑte-Simulation: Interrupts setzen}
 p_tmr1      = $22A;   {set and start timer}
 p_tmr2      = $22C;   {set and start timer}
 p_tmr2_1ms  = $22E;   {Ansprechen der Adr. schaltet Timer2 auf 1 ms}

 dta_mode   = 0;
 cmd_mode   = 1;


 c_wr_rdy_time  = 3;
 c_val_wrd_time = 6;

TYPE

 t_fc = RECORD CASE BYTE OF
          1: (r : PACKED RECORD
                    adr : BYTE;
                    fc  : BYTE
                  END;
              );
           2: (w : WORD);
         END;

 t_mil_err = (no_err, fc_to, rd_to, wr_to);


 t_mil =
   OBJECT
     PROCEDURE timer1_set(time: WORD);  { Startet Timer1 time*10us    }
     FUNCTION  timeout1  : BOOLEAN;     { Testet Timer1 auf Timeout   }
     PROCEDURE timer1_wait(time: WORD); { Wartet mit Timer1 time*10us }

     PROCEDURE timer2_set(time: LONGINT);  { Startet Timer2:                }
                                           { time <= $FFFF dann time*10us   }
                                           { time >  $FFFF dann time/100*ms }
     FUNCTION  timeout2  : BOOLEAN;        { Testet Timer2 auf Timeout      }
     PROCEDURE timer2_wait(time: LONGINT); { Wartet mit Timer2:             }
                                           { time <= $FFFF dann time*10us   }
                                           { time >  $FFFF dann time/100*ms }

     PROCEDURE wr_fc (fct : t_fc; VAR mil_err: t_mil_err);
     PROCEDURE rd (VAR mil_data: WORD; fct : t_fc; VAR mil_err: t_mil_err);
     PROCEDURE wr (data: WORD; fct : t_fc; VAR mil_err: t_mil_err);
   END; { t_mil }

IMPLEMENTATION   { Teil der UNIT-Deklaration }

FUNCTION t_mil.timeout1 : BOOLEAN;
  Begin
  IF PORTW[p_stat] AND stat_timeout1 = stat_timeout1 THEN
    timeout1 := TRUE
  ELSE
    timeout1 := FALSE;
  End;

 PROCEDURE t_mil.timer1_set(time: WORD);  {setzt u. startet den Timer: 10 us Ticks}
  Begin
  PORTW[p_tmr1] := time;
  End;

PROCEDURE t_mil.timer1_wait(time : WORD);
  BEGIN
  PORTW[p_tmr1] := time;
  REPEAT UNTIL (PORTW[p_stat] AND stat_timeout1) = stat_timeout1;
  END;

FUNCTION t_mil.timeout2 : BOOLEAN;
  Begin
  IF PORTW[p_stat] AND stat_timeout2 = stat_timeout2 THEN
    timeout2 := TRUE
  ELSE
    timeout2 := FALSE;
  End;

PROCEDURE t_mil.timer2_set(time: LONGINT); { setzt u. startet den Timer:    }
                                           { time <= $FFFF dann time*10us   }
                                           { time >  $FFFF dann time/100*ms }
  Begin
  IF time <= $FFFF THEN
    BEGIN
{    PORTW[p_tmr2_1ms] := 0;}  { spaeter aendern !!! }
    PORTW[p_tmr2] := WORD(time);
    END
  ELSE
    BEGIN
    PORTW[p_tmr2_1ms] := 1;
    PORTW[p_tmr2] := WORD(time DIV 100);
    END;
  End;

PROCEDURE t_mil.timer2_wait(time : LONGINT);
  BEGIN
  IF time <= $FFFF THEN
    BEGIN
{    PORTW[p_tmr2_1ms] := 0;}  { spaeter aendern !!! }
    PORTW[p_tmr2] := WORD(time);
    END
  ELSE
    BEGIN
    PORTW[p_tmr2_1ms] := 1;
    PORTW[p_tmr2] := WORD(time DIV 100);
    END;
  REPEAT UNTIL (PORTW[p_stat] AND stat_timeout2) = stat_timeout2;
  END;

PROCEDURE t_mil.wr_fc(fct : t_fc; VAR mil_err: t_mil_err);
  VAR
    time_out : BOOLEAN;
  BEGIN
  PORTW[p_tmr1] := c_wr_rdy_time;
  REPEAT
    time_out := t_mil.timeout1;
  UNTIL((PORTW[p_stat] AND stat_wrt_rdy) = stat_wrt_rdy) OR time_out;
  IF ((PORTW[p_stat] AND stat_wrt_rdy) = stat_wrt_rdy) THEN
    BEGIN
    PORTW[p_mode] := cmd_mode;
    mil_err := no_err;
    PORTW[p_data] := fct.w; { Funktioncode schreiben }
    END
  ELSE
    mil_err := fc_to;
  END; { wr_fc }

PROCEDURE t_mil.rd(VAR mil_data: WORD; fct : t_fc; VAR mil_err: t_mil_err);
  VAR
    time_out : BOOLEAN;
  BEGIN
  {--------------------------------------------------}
  { Zuerst muss der Funktionscode geschrieben werden }
  {--------------------------------------------------}
  PORTW[p_tmr1] := c_wr_rdy_time;
  REPEAT
    time_out := timeout1;
  UNTIL((PORTW[p_stat] AND stat_wrt_rdy) = stat_wrt_rdy) OR time_out;
  IF ((PORTW[p_stat] AND stat_wrt_rdy) = stat_wrt_rdy) THEN
    BEGIN
    PORTW[p_mode] := cmd_mode;
    PORTW[p_data] := fct.w; { Funktionscode schreiben }
    {-------------------------------}
    { Dann werden die Daten gelesen }
    {-------------------------------}
    PORTW[p_tmr1] := c_val_wrd_time;
    REPEAT
      time_out := timeout1;
    UNTIL ((PORTW[p_stat] AND stat_val_wrd) = stat_val_wrd)  OR time_out;
    IF ((PORTW[p_stat] AND stat_val_wrd) = stat_val_wrd) THEN
      BEGIN
      mil_err := no_err;
      mil_data := PORTW[p_data]; { Mil-Daten lesen }
      END
    ELSE
      mil_err := rd_to;
    END
  ELSE
    mil_err := fc_to;
  END; { rd }


PROCEDURE t_mil.wr(data: WORD; fct : t_fc; VAR mil_err: t_mil_err);
  VAR
    time_out : BOOLEAN;
  BEGIN
  PORTW[p_tmr1] := c_wr_rdy_time;
  REPEAT
    time_out := timeout1;
  UNTIL ((PORTW[p_stat] AND stat_wrt_rdy) = stat_wrt_rdy)  OR time_out;
  IF ((PORTW[p_stat] AND stat_wrt_rdy) = stat_wrt_rdy) THEN
    BEGIN
    PORTW[p_mode] := dta_mode;
    PORTW[p_data] := data; { Mil-Daten schreiben }
    {--------------------------------------}
    { Dann wird der Funktionscode gesendet }
    {--------------------------------------}
    PORTW[p_tmr1] := c_wr_rdy_time;
    REPEAT
      time_out := timeout1;
    UNTIL((PORTW[p_stat] AND stat_wrt_rdy) = stat_wrt_rdy) OR time_out;
    IF ((PORTW[p_stat] AND stat_wrt_rdy) = stat_wrt_rdy) THEN
      BEGIN
      PORTW[p_mode] := cmd_mode;
      mil_err := no_err;
      PORTW[p_data] := fct.w; { Mil-Funktioncode schreiben }
      END
    ELSE
      mil_err := fc_to;
    END
  ELSE
    mil_err := wr_to;
  END; { wr }

END. { unit }