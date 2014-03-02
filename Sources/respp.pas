program Resource_Preprocessor;
var f,t:text;
    s:string;

function param(s:String;ik:byte):string;
var b,c:byte;
    e:string;
begin
  b:=0;
  c:=1;
  repeat
    e:='';
    while (s[c]=' ') and (c<=length(s)) do inc(c);
    while (s[c]<>' ') and (c<=length(s)) do
    begin
      e:=e+s[c];
      inc(c);
    end;
    inc(b);
  until (b=ik) or (c>length(s));
  param:=e;
end;

procedure process(var s:String);
var n,e:string;
begin
  if param(s,1)<>'#define' then exit;
  n:=param(s,2); e:=param(s,3);
  s:='  '+n;
  while length(s)<40 do s:=s+' ';
  s:=s+'= '+e+';';
end;

procedure process2(var s:String);
var e,n:string;
    w:word;
begin
  if param(s,1)<>'DLGINCLUDE' then exit;
  if length(s)<11 then exit;
  w:=11;
  while ((w<=length(s)) and (s[w]=' ')) do inc(w); // find the number after the DLGINCLUDE tag
  while ((w<=length(s)) and (s[w]<>' ')) do inc(w); // find the space after the number
  while ((w<=length(s)) and (s[w]=' ')) do inc(w); // find the first character of filename

  e:='#include ';
  while w<=length(s) do
  begin
    e:=e+s[w]; inc(w);
  end;
  s:=e;
end;


begin
  if paramcount=0 then
  begin
    writeln('Resource file preprocessor v1.0');
    writeln('Usage: respp <filename (no extension!)>');
    writeln;
    writeln('Description:');
    writeln(' Respp will create a pascal style INC file');
    writeln(' from the C style filename.h file, and it');
    writeln(' will create a filename.plg file from the');
    writeln(' filename.dlg file, that can be processed');
    writeln(' by the standard RC.EXE/RCPP.EXE.');
    halt(1);
  end;

  Writeln('Creating .INC file...');
  assign(f,paramstr(1)+'.h');
  assign(t,paramstr(1)+'.inc');
  {$I-}
  reset(f);
  {$I+}
  if ioresult<>0 then
  begin
    writeln('Could not open ',paramstr(1),'.h!');
  end else
  begin
    {$I-}
    rewrite(t);
    {$I+}
    if ioresult<>0 then
    begin
      writeln('Could not create ',paramstr(1),'.inc!');
    end else
    begin // Files opened, process the .h file to .inc file!
      while not eof(f) do
      begin
        readln(f,s); process(s); writeln(t,s);
      end;
      close(t);
    end;
    close(f);
  end;

  Writeln('Creating .PLG file...');
  assign(f,paramstr(1)+'.dlg');
  assign(t,paramstr(1)+'.plg');
  {$I-}
  reset(f);
  {$I+}
  if ioresult<>0 then
  begin
    writeln('Could not open ',paramstr(1),'.dlg!');
  end else
  begin
    {$I-}
    rewrite(t);
    {$I+}
    if ioresult<>0 then
    begin
      writeln('Could not create ',paramstr(1),'.plg!');
    end else
    begin // Files opened, process the .h file to .inc file!
      while not eof(f) do
      begin
        readln(f,s); process2(s); writeln(t,s);
      end;
      close(t);
    end;
    close(f);
  end;
end.
