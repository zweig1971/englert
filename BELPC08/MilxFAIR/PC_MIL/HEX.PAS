   Num_Str     = string[10];

  function hex_byte(b: BYTE): Num_Str;
  const hex_num : STRING[16] = '0123456789ABCDEF';
  begin
   hex_byte := hex_num[(b shr 4) + 1] + hex_num[(b AND $0F) + 1];
  end;

 function hex_word (w: Word): Num_Str;
  begin
   hex_word := hex_byte(HI (w)) + hex_byte(LO (w));
  end; {hex_word}

 procedure Convert_To_Hex (in_string  : str4;
                           var hex_out: Word;
                           var status : boolean);
  var
   offset,i : INTEGER;
   dummy    : Word;
  begin
   offset := ORD('A') - ORD('a');
   status := TRUE;
   hex_out:= 0;
{   for i :=  1 TO 4 do  }
    for i :=  1 TO ord(In_String[0]) do    {In_String[0] = Anzahl Zeichen}
    begin
     if in_string[i] <> ' ' then
       begin
         if in_string[i] in ['a'..'f'] then
            in_string[i] := CHR(offset + ORD(in_string[i]));
         if in_string[i] in ['0'..'9'] then
          hex_out := hex_out * 16 + (ORD(in_string[i]) - ORD('0'))
         else
          begin
            if in_string[i] in ['A' ..'F'] then
              hex_out := hex_out * 16 + (ORD(in_string[i]) - ORD('A') + 10)
            else
             status := FALSE;
          end; {if in 0..9}
       end; {if<>blank}
    end; {for i}
  end;
