{ G. Englert
  Include File MIL_FLSH.INC mit Constanten fÅr MIL_FLSH.PAS
  Last Update
  03.11.93   G. Englert Erstellung
}

CONST                   {Function-Codes fÅr IFC-FLASH-Piggy: F 468 000}
 fct_wr_adr_hi  = $0A;  {32-bit Flash-Adr Bit 16..31}
 fct_wr_adr_lo  = $08;  {32-bit Flash-Adr Bit 00..15}
 fct_wr_data    = $06;  {16-bit Flash-Daten, erst Adresse einstellen!}
 fct_rd_data    = $80;  {16-bit Flash-Daten}
 fct_rd_ist1    = $81;  {Lese ADC-Wert}
 fct_rd_ident   = $8E;  {16-bit: HiByte=not used, LoByte=Ident-code}
 fct_rd_status  = $C9;  {Status IFC-Karte}

 ident_piggy_flash = $20;
 msg_any_key =
      'Weiter mit beliebiger Taste!                                     ';
 msg_single_step =
      'Loop- u. Single-Test mit [Q] beenden!    Single-Step mit [SPACE] ';
 msg_ifc_equal =
      'IFC-Adr.  Ref,Mess,Flash mÅssen verschieden sein!  Weiter mit einer Taste: ';
msg_timer_auto =
      'Automat. Timertest mit [Q] beenden!';
                                    {Error-Codes}
 err_undefind    = 0;
 err_ok          = 1;
 err_ifc_adr     = 2;   {Adresse nicht im Bereich 1..255}
 err_adr_offline = 3;   {IFC-Adr meldet sich nicht mit FCT-Code C9 Hex}
 err_id_timeout  = 4;   {keine Antwort beim Lesen des Piggy-Ident}
 err_id_flash    = 5;   {Falscher Ident fÅr Flash-Piggy}
 err_rd_timeout  = 6;   {keine Antwort beim Lesen der Flash-Daten}
 err_wr_data     = 7;   {Daten werden nicht geschrieben}
 err_erase_chip  = 8;   {Erase-Chip Kommando nicht erfolgreich}

 err_msg_max     = 8;  {Max-Index fÅr Error-Message-Array}
 err_msg_00      = 'Fehler undefiniert!';
 err_msg_01      = 'Kein Fehler!';
 err_msg_02      = 'IFC-Adr nicht im Bereich 1..255!';
 err_msg_03      = 'IFC-Adr meldet sich nicht mit Fct-Code C9 [H]!';
 err_msg_04      = 'Keine Antwort beim Lesen des Flash-Piggy-Ident!';
 err_msg_05      = 'Falscher Ident fÅr Flash-Piggy!';
 err_msg_06      = 'Keine Antwort beim Lesen der Flash-Daten!';
 err_msg_07      = 'Daten werden nicht geschrieben!';
 err_msg_08      = 'Erase-Chip Kommando war nicht erfolgreich!';

 err_msg_ary :  array [0..err_msg_max] of string =
                 (
                  err_msg_00,err_msg_01,err_msg_02,err_msg_03,err_msg_04,
                  err_msg_05,err_msg_06,err_msg_07,err_msg_08
                 );
