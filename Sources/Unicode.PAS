Unit Unicode;
Interface

{&CDECL+}{&USE32+}

Type ApiRet=longint;
     ULONG=Word;
     USHORT=SmallWord;
     size_t=WORD;
     UniChar=SmallWord;
     pUniChar=^UniChar;
     UniString=Array[0..0] of UniChar;
     pUniString=^UniString;
     UConvObject=Pointer;

type conv_endian_t=record
       source:ushort;
       target:ushort;
     end;

type udcrange_t=record
       first:ushort;
       last:ushort;
     end;

type uconv_attribute_t=record
       version:ulong;
       mb_min_len:byte;
       mb_max_len:byte;
       usc_min_len:byte;
       usc_max_len:byte;
       esid:ushort;
       Options:byte;
       State:Byte;
       endian:conv_endian_t;
       displaymask:ulong;
       converttype:ulong;
       subchar_len:ushort;
       subuni_len:ushort;
       subchar:array[0..15] of byte;
       subuni:array[0..7] of UniChar;
     end;

type a256byte=array[0..255] of byte;
     a32udcrange_t=array[0..31] of udcrange_t;

Function UniCreateUconvObject(cpname:pUniString;var uconv_object:UconvObject):ApiRet;
Function UniFreeUconvObject(uconv_object:UconvObject):ApiRet;
Function UniMapCpToUcsCp(ulCodepage:ULONG; ucsCodepage:pUniString; n:size_t):ApiRet;
Function UniQueryUconvObject(uobj:UconvObject; var attr:uconv_attribute_t; size:size_t;
                             first:a256byte; other:a256byte;
                             udcrange:a32udcrange_t):ApiRet;

Function UniSetUconvObject(uconv_object:UconvObject; var attr_t:uconv_attribute_t):ApiRet;

Function UniUconvFromUcs(uconv_object:UconvObject; var ucsbuf:pUniString; var UniCharsleft:size_t;
                     var outbuf:pointer; var outbytesleft:size_t; var nonidentical:size_t):ApiRet;
Function UniUconvToUcs(uconv_object:UconvObject; var inbuf:pointer; var inBytesLeft:size_t;
                     var ucsbuf:pUniString; var uniCharsLeft:size_t; var nonidentical:size_t):ApiRet;

Function UniStringLength(UniCharArray:pointer):longint;

implementation

Function UniStringLength(UniCharArray:pointer):longint;
begin
  result:=0;
  while (memw[ofs(UniCharArray^)+result*2]<>0) do inc(result);
end;

function UniCreateUconvObject; external 'uconv.dll' name 'UniCreateUconvObject';
function UniFreeUconvObject; external 'uconv.dll' name 'UniFreeUconvObject';
function UniMapCpToUcsCp; external 'uconv.dll' name 'UniMapCpToUcsCp';
function UniQueryUconvObject; external 'uconv.dll' name 'UniQueryUconvObject';
function UniSetUconvObject; external 'uconv.dll' name 'UniSetUconvObject';
function UniUconvFromUcs; external 'uconv.dll' name 'UniUconvFromUcs';
function UniUconvToUcs; external 'uconv.dll' name 'UniUconvToUcs';

end.
