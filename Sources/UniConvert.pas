unit UniConvert; // Convert from a codepage to the current one using unicode!
interface
uses Unicode;

Procedure Init_Convert(SourceCP:longint);
Procedure Uninit_Convert;
Function Convert(s:AnsiString):AnsiString;

implementation
const Convert_Initialized:boolean=false;
var ToUc,FromUc:UConvObject;

procedure Init_Convert(SourceCP:longint);
var UniCPName:pUniString;
    rc:longint;
begin
  Convert_Initialized:=false;
  getmem(UniCPName,1024);
  if UniCPName=Nil then exit; // *** Not enough memory to create Unicode CP Name string!
  rc:=UniMapCpToUcsCp(SourceCP,UniCPName,1024);
  if rc<>0 then               // *** Error mapping codepage to Unicode codepage
  begin
    freemem(UniCPName);
    exit;
  end;
  rc:=UniCreateUconvObject(UniCPName, ToUC);
  if rc<>0 then
  begin
    freemem(UniCPName);
    exit;         // *** Error creating Unicode convertation object
  end;

  // Ok, we have the unicode object that converts from pchar to unicode. Now the backwards direction.

  UniCPName^[0]:=0; // Empty string: convert to actual codepage!
  rc:=UniCreateUconvObject(UniCPName, FromUC);
  if rc<>0 then
  begin
    UniFreeUconvObject(ToUC);
    freemem(UniCPName);
    exit;         // *** Error creating Unicode convertation object
  end;
  Convert_Initialized:=true;
  freemem(UniCPName);
end;

procedure Uninit_Convert;
begin
  if Convert_Initialized then
  begin
    Convert_Initialized:=false;
    UniFreeUconvObject(FromUC);
    UniFreeUconvObject(ToUC);
  end;
end;

Function Convert(s:AnsiString):AnsiString;
var UniName:pUniString;
    UniCharsLeft,inBytesLeft,NonIdentical:size_t;
    outbytesleft:size_t;
    rc:longint;
    ps:pointer;
    pus:pUniString;
begin
  result:=s;

  if not Convert_Initialized then exit;

  getmem(UniName,sizeof(UniChar)*(length(s)+1));
  if UniName=Nil then exit; // *** Not enough memory to create temporary Unicode string!

  inbytesleft:=length(s)+1;
  UniCharsLeft:=inBytesLeft;
  Nonidentical:=0;
  ps:=@s[1];       // The function will change the addresses, so use a local variable!
  pus:=UniName;
  rc:=UniUconvToUcs(ToUC,ps,inBytesLeft,pus,UniCharsLeft,nonidentical);
  if rc=0 then
  begin
    // now back from unicode to actual codepage
    outbytesleft:=length(s);
    UniCharsLeft:=UniStringLength(UniName);
    Nonidentical:=0;
    ps:=@s[1];
    pus:=UniName;
    rc:=UniUconvFromUcs(FromUC,pus,UniCharsLeft,ps,OutBytesLeft,nonidentical);
    if rc=0 then result:=s;
  end;
  freemem(UniName);
end;

end.
