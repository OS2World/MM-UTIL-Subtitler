Program Subtitler;
{$X+}{$H-}{$R-}
{&USE32+}

{$PMTYPE PM}        // We are about to create a PM application...

{$R Subtitler.res}  // The resources will be compiled into this file
                    // by the compiler

Uses
  vpSysLow, VPUtils, Os2Def, Os2Base, Os2PmApi, UniConvert;

const {$I Subtitler.inc}     // Include the resource IDs
      TIMERID = 1;           // We'll have one timer, with this ID

      FPS:Real=25;           // Default FramePerSec
      CPFrom:UShort=0;       // Default codepage to convert the subtitles from. (codepage of subtitles)

      pszAppName='Subtitler';            // Save the settings into this appname/appkey in os2.ini
      pszAppKey='MainWindowProperties';  // under this name. Only the window size/position and colors
                                         // will be saved.

const ProgramTitle='Subtitler v1.2';     // Program title
      FirstSubLine='Subtitler v1.2 by Doodle';

type pSubtitleElement=^SubtitleElement;  // After processing the subtitle file, a linked list of
     SubtitleElement=record              // this kind of records will be created.
       TimeFrom:longint;                 // Show the subtitle from this time (in msec or frame)
       TimeTo:longint;                   // ... until this time (in msec or frame)
       TextToShow:String;                // Show this text (might be multiple lines)
       Next:pSubtitleElement;            // Next linked list element
     end;

var Ab:HAB;                 // Anchor block
    Mq:HMQ;                 // Message Queue
    MainWindow:HWND;        // Handle of main window

// Global variables used for parsing the subtitle file:

    t:text;                 // Text file handle, while loading the subtitles. Used by some procedures.
    TimeFrom:Longint;       // Parsed subtitles get into this three variables
    TimeTo:Longint;
    TextToShow:String;
    SubTitleNumber:longint; // Used by one kind of subtitle file, the number (order) of subtitle.

// Linked list, containing the subtiles:
    SubtHead,ActSubt:pSubtitleElement;

    SubStyle:byte;         // Detected subtitle style: 0 - Unknown
                           //                          1 - time based subtitles
                           //                          2 - frame based subtitles
    TimeFormat:byte;       // Detected time format (used if SubStyle = 1) :
                           //                          1 - eg.: 00:11:23.32,00:11:25.10
                           //                          2 - eg.: 00:11:23,324 --> 00:11:25,103

    Time,                      // Actual time while showing movie (running)
    BaseTime,                  // Base time, got from movie player (jumping, usually in every second)
    LastInfoShowTime:longint;  // Last time when the info has been shown (so time information will be
                               // updated only 10 times per second...)

    MoveMode:boolean;                // True if the user drags the window with mouse button 2
    baseMouseX, baseMouseY:longint;  // Start position of mouse while dragging
    BaseSWP:SWP;                     // SWP structure to store window position

    ShuttingDown:boolean;            // Used to indicate to the communicator thread to shut down
    CommunicatorThreadID:TID;        // Thread ID of communicator thread, which gets time info from pipe
    WVGUIThreadID:TID;               // Thread ID of thread that communicates with WarpVision GUI
    WVGUIPipeEvSem:HEV;              // Event Semaphore for communication with WVGui
    oldHour, oldMin, oldSec:word;    // Old time information from WVGui

    IniFile:string;                  // Path and name of IniFile (Stitler.ini), set by Load_Settings.
    SubFileName:string;              // Path and name of active subtitle file

    InSettings:boolean;              // True if the settings dialog is active



// --------------------------------------------------------------------------
// GetTime
//
// Returns actual time in msec.
// Note, that there can be problems at every 49 days when it overflows.:)
//
Function GetTime:longint;
begin
  result:=SysSysMsCount;
end;

// --------------------------------------------------------------------------
// StrPCopy and StrPas
//
// They are rewritten here, so we don't have to include all the SysUtils unit,
// which would increase the executable size.
//
procedure StrPCopy(dest:pchar; src:string);
var w:longint;
begin
  for w:=1 to length(src) do dest[w-1]:=src[w];
  dest[length(src)]:=#0;
end;

function StrPas(p:pchar):string;
begin
  result:='';
  while (p<>Nil) and (p^<>#0) do
  begin
    result:=result+p^;
    inc(ulong(p));
  end;
end;


// --------------------------------------------------------------------------
// UpStr
//
// Like UpCase, just for strings.
//
Function UpStr(s:string):string;
var l:longint;
begin
  for l:=1 to length(s) do s[l]:=upcase(s[l]);
  result:=s;
end;

// --------------------------------------------------------------------------
// toInteger
//
// Converts a string to integer, if possible.
//
function toInteger(s:String):Integer;
var w:Integer;
    i:longint;
begin
  val(s,w,i);
  Result:=w;
end;

// --------------------------------------------------------------------------
// toReal
//
// Converts a string to real, if possible.
//
function toReal(s:String):real;
var r:real;
    i:longint;
begin
  val(s,r,i);
  toreal:=r;
end;

// --------------------------------------------------------------------------
// toString
//
// Converts a longint to string.
//
function ToString(l:longint):string;
var s:string;
begin
  str(l,s);
  ToString:=s;
end;

// --------------------------------------------------------------------------
// FPSToStr
//
// Converts a real to string, without spaces.
//
Function FPSToStr(r:real):string;
begin
  str(r:8:2,result);
  while (length(result)>0) and (result[1]=' ') do delete(result,1,1);
end;

// --------------------------------------------------------------------------
// Load_Settings
//
// Reads the settings from STitler.INI file, if possible.
// Also sets the IniFile variable, so it can be used in Save_Settings.
//
procedure Load_Settings;
var f:text;
    l:longint;
    s:string;
begin
  // Get the directory of executable:
  s:=paramstr(0);
  for l:=length(s) downto 1 do if s[l]='\' then break;

  // Create ini file name
  if s[l]='\' then IniFile:=copy(s,1,l)+'Stitler.ini'
              else IniFile:='Stitler.ini';

  // Load settings
  assign(f,IniFile);
  filemode:=Open_Access_ReadOnly or Open_Share_DenyNone;
  {$i-}
  reset(f);
  {$I+}
  if ioresult=0 then
  begin // There is a subtitler ini file, so load settings!
    while not eof(f) do
    begin
      readln(f,s);
      if UpStr(Copy(s,1,9))='CODEPAGE=' then
      begin
        val(Copy(s,10,length(s)),cpfrom,l);
      end;
      if UpStr(Copy(s,1,4))='FPS=' then
      begin
        val(Copy(s,5,length(s)),FPS,l);
      end;
    end;
    close(f);
  end;
end;

// --------------------------------------------------------------------------
// Save_Settings
//
// Creates Stitler.ini file containing actual FPS and codepage settings.
//
procedure Save_Settings;
var f:text;
begin
  //If everything goes well, the name of ini file has been set by Load_Settings, so we can use that!
  assign(f,IniFile);
  {$I-}
  rewrite(f);
  {$I+}
  if ioresult=0 then
  begin
    Writeln(f,';-----------------------------------------');
    Writeln(f,'; INI file to store settings of Subtitler');
    Writeln(f,';-----------------------------------------');
    Writeln(f,';');
    Writeln(f,'; Codepage of subtitle files:');
    Writeln(f,'');
    Writeln(f,'Codepage=',CPFrom);
    Writeln(f,'');
    Writeln(f,'; Frame/Sec, used for subtitle files which contain frame information:');
    Writeln(f,'');
    Writeln(f,'FPS=',FPSToStr(FPS));
    Writeln(f,'');
    close(f);
  end;
end;

// --------------------------------------------------------------------------
// GetTimeInfo
//
// Tries to extract the time information from a string.
// Returns true if it can, and sets the TimeFormat variable.
//

function GetTimeInfo(l:String):boolean;
var h,m,s,ms:longint;
    i:integer;
begin
  result:=false;
  if length(l)<23 then exit;

  val(l[1]+l[2],h,i);
  if i<>0 then exit;
  val(l[4]+l[5],m,i);
  if i<>0 then exit;
  val(l[7]+l[8],s,i);
  if i<>0 then exit;
  val(l[10]+l[11],ms,i);
  if i<>0 then exit;

  TimeFrom:=ms+s*1000+m*60000+h*3600000;

  if l[12]=',' then
  begin // Time format 1: eg.: 00:11:23.32,00:11:25.10
    TimeFormat:=1;
    val(l[13]+l[14],h,i);
    if i<>0 then exit;
    val(l[16]+l[17],m,i);
    if i<>0 then exit;
    val(l[19]+l[20],s,i);
    if i<>0 then exit;
    val(l[22]+l[23],ms,i);
    if i<>0 then exit;

    TimeTo:=ms+s*1000+m*60000+h*3600000;
    Result:=true; exit;
  end else
    // Okay, not time format 1, maybe 2?
  if (l[13]+l[14]+l[15]+l[16]+l[17]=' --> ') and (length(l)>=28) then
  begin
    TimeFormat:=2;

    val(l[18]+l[19],h,i);
    if i<>0 then exit;
    val(l[21]+l[22],m,i);
    if i<>0 then exit;
    val(l[24]+l[25],s,i);
    if i<>0 then exit;
    val(l[27]+l[28],ms,i);
    if i<>0 then exit;

    TimeTo:=ms+s*1000+m*60000+h*3600000;
    Result:=true; exit;
  end;
  TimeFormat:=0;
end;

// --------------------------------------------------------------------------
// Process
//
// Used if the subtitle format contains frame information. (SubStyle=2)
// Extracts the TimeFrom (P1) TimeTo (P2) and Subtitle (T) from the input
// string (s).
//
procedure Process(s:String; var P1,P2:longint; var T:string);
var l:longint;
    State:byte;
    temp:string;
    i:integer;
begin
  p1:=0; p2:=0; t:='';
  State:=0;
  for l:=1 to length(s) do
  begin
    case State of
      0: if s[l]='{' then
         begin
           temp:='';
           State:=1;
         end;
      1: if s[l]<>'}' then
         begin
           temp:=temp+s[l];
         end else
         begin
           val(temp,p1,i);
           State:=2;
         end;
      2: if s[l]='{' then
         begin
           temp:='';
           State:=3;
         end;
      3: if s[l]<>'}' then
         begin
           temp:=temp+s[l];
         end else
         begin
           val(temp,p2,i);
           State:=4;
         end;
       4: if s[l]='|' then t:=t+#13+#10 else t:=t+s[l];
     end;
  end;
end;

// --------------------------------------------------------------------------
// RestoreEnter
//
// Replaces every | with an enter.
//
function RestoreEnter(s:String):string;
var w:word;
begin
 result:='';
 for w:=1 to length(s) do if s[w]='|' then result:=result+#13+#10 else result:=result+s[w];
end;

// --------------------------------------------------------------------------
// ParseOneLine
//
// Reads a line from t text file, and creates an element for the subtitle
// list from the line read.
//
Procedure ParseOneLine;
var s:string;
    sSubTitleNumber:string;
    sTemp:String;
begin
  if eof(t) then
  begin
    SubStyle:=0; // End of subtitling
    exit;
  end;
  case SubStyle of
    0: exit;
    1: begin  // time then text in next line(s)
         repeat
           readln(t,s);
         until (GetTimeInfo(s) or (eof(t)));    // First line time-info
         if eof(t) then
         begin
           SubStyle:=0;
           exit;
         end;
         if TimeFormat=1 then
         begin // Simple, only one line of text.
           readln(t,TextToShow);
           TextToShow:=RestoreEnter(TextToShow);
         end else
         if TimeFormat=2 then
         begin
           Inc(SubTitleNumber);
           Str(SubTitleNumber,sSubTitleNumber);
           TextToShow:='';
           repeat
             readln(t,sTemp);
             if sTemp<>sSubTitleNumber then
             begin
               if TextToShow='' then TextToShow:=sTemp else
                  TextToShow:=TextToShow+#13+#10+sTemp;
             end;
           until (sTemp=sSubTitleNumber) or (eof(t));
         end;
         if eof(t) then
         begin
           SubStyle:=0;
           exit;
         end;
       end;
    2: begin // {fromframe}{toframe}text
         if eof(t) then
         begin
           SubStyle:=0;
           exit;
         end;
         readln(t,s);
         Process(s,TimeFrom,TimeTo,TextToShow);
         // Note that the time information will be stored in Frames, in this case!
       end;
  end;
end;

// --------------------------------------------------------------------------
// Free_SubtitleList
//
// Free memory used by list of subtitles.
//
procedure Free_SubtitleList;
begin
  while SubtHead<>Nil do
  begin
    ActSubt:=SubtHead;
    SubtHead:=SubtHead^.Next;
    Dispose(ActSubt);
  end;
  // reinitialize variables:
  Time:=0;BaseTime:=GetTime;LastInfoShowTime:=BaseTime;
  SubtHead:=Nil;ActSubt:=SubtHead;
  SubFileName:='No subtitle loaded!';
end;

// --------------------------------------------------------------------------
// AddNewSubtitle
//
// Adds a new element to the list of subtitles.
//
procedure AddNewSubtitle;
var news:pSubtitleElement;
begin
  new(news);
  news^.next:=Nil;
  news^.TimeFrom:=TimeFrom;
  news^.TimeTo:=TimeTo;
  news^.TextToShow:=TextToShow;
  if SubtHead=Nil then
  begin
    SubtHead:=news;
    ActSubt:=news;
  end else
  begin
    ActSubt^.Next:=news;
    ActSubt:=news;
  end;
end;

// --------------------------------------------------------------------------
// Load_Subtitles
//
// Tries to load the subtitle file, and build the list.
//
procedure Load_Subtitles(filename:String);
var s:String;
begin
  if filename='' then exit;

  //    Load and process subtitles

  Free_SubtitleList;  // First free the old one.

  assign(t,filename); // Open file
  filemode:=Open_Access_ReadOnly or Open_Share_DenyNone;
  {$I-}
  reset(t);
  {$I+}
  if ioresult<>0 then exit;

  // Setup everything:
  SubFileName:=filename;
  Time:=0;BaseTime:=GetTime;LastInfoShowTime:=BaseTime;

  if not eof(t) then
  repeat
    readln(t,s); // Get the first non blank line in 's'! (To try to get subtitle file format)
  until (s<>'') or (eof(t));

  if eof(t) then  // Could not figure out file format.
  begin
    close(t); exit;
  end;

  close(t);
  reset(t);

  SubStyle:=0; // Unknown;
  SubTitleNumber:=1;

  // Check first non-blank line to see the file format!

  if s[1]='{' then
  begin
    SubStyle:=2;
    ParseOneLine;
  end else
  begin // Ok, format 1:  hh:mm:ss.ms,hh:mm:ss:ms   or   hh:mm:ss.ms_ --> hh:mm:ss.ms_
    SubStyle:=1;
    ParseOneLine;
  end;
  if (SubStyle=0) or ((SubStyle=1) and (TimeFormat=0)) then // Could not determine subtitle format.
  begin
    close(t); exit;
  end;

  // ParseOneLine has set TextToShow string to the string read.
  repeat
    AddNewSubtitle;
    ParseOneLine;
  until eof(t);

  close(t);
end;

// --------------------------------------------------------------------------
// MySetDlgItemText
//
// It's like WinSetDlgItemText, but uses a pascal style string.
//
procedure MySetDlgItemText(Wnd:HWND; ID:ULong; s:string);
begin
  s:=s+#0;
  WinSetDlgItemText(Wnd,ID,@s[1]);
end;

// --------------------------------------------------------------------------
// MyQueryDlgItemText
//
// It's like WinQueryDlgItemText, but uses a pascal style string.
//
function MyQueryDlgItemText(Wnd:HWND; ID:ULong):String;
var buffer:array[0..255] of char;
begin
  if (WinQueryDlgItemText(Wnd,ID,sizeof(Buffer),@Buffer)=0) then result:=''
  else
   result:=strpas(@Buffer);
end;

// --------------------------------------------------------------------------
// GetSubtitle
//
// Returns the element of list (or NIL) that contains the subtitle that
// should be shown at a given time (in msec).
//
function GetSubtitle(time:longint):pSubtitleElement;
var temp:pSubtitleElement;
begin
  result:=nil;
  temp:=SubtHead;
  while (temp<>Nil) and
        (
         ((SubStyle<>2) and          // Time is stored in msec:
          (not ((temp^.TimeFrom<=time) and (temp^.TimeTo>=time)))
         ) or
         ((SubStyle=2) and           // Time is stored in frames:
          (not ((temp^.TimeFrom*1000/FPS<=time) and (temp^.TimeTo*1000/FPS>=time)))
         )
        ) do temp:=temp^.Next;
  result:=temp;
end;

// --------------------------------------------------------------------------
// SetupDlgProc
//
// The procedure that processes messages for Setup dialog window.
//
function SetupDlgProc(Wnd: HWnd; Msg: ULong; Mp1, Mp2: MParam): MResult; cdecl;
var usID, usnotify:ushort;
    Fild:FileDlg;
    s:string;
begin
  result:=0; // Default: non-processed.

  case Msg of
    WM_INITDLG: // Initialization of dialog window
    begin
      // Setup the fields according to the actual settings:

      MySetDlgItemText(Wnd, DID_FILENAMEENTRY, SubFileName);
      S:=FPSToStr(FPS);
      MySetDlgItemText(Wnd, DID_FPSENTRY, s);
      if SubStyle=2 then s:='Yes' else
                         s:='No';
      MySetDlgItemText(Wnd, DID_FPSUSEDENTRY, s);
      Str(CPFrom,s);
      MySetDlgItemText(Wnd, DID_CODEPAGEENTRY, s);
    end;

    WM_COMMAND:
    begin
      usID:=ushort(mp1);
      if ushort(mp2)=CMDSRC_PUSHBUTTON then
      begin
        case usID of
// --------------------------------------------------- P U S H B U T T O N S ----------
          DID_DONEBUTTON:
           begin
             WinPostMsg(Wnd, WM_CLOSE, 0, 0);
             Result:=1;
           end;
          DID_LOADBUTTON:
           begin
             fillchar(fild,sizeof(fild),0);
             with fild do
             begin
               cbSize:=sizeof(filedlg);
               fl:=fds_Center or
                   fds_Open_Dialog;
               pszTitle:='Load Subtitle';
               pszOKButton:='Load';
               strpcopy(@szFullFile,'*.SUB;*.SRT');
             end;
             if (WinFileDlg(HWND_DESKTOP, Wnd, fild)<>0) and (fild.lReturn = DID_OK) then
             begin
               Load_Subtitles(strpas(@fild.szFullFile));
               WinPostMsg(Wnd, WM_INITDLG, 0, 0); // Reinitialize entries
             end;
             Result:=1;
           end;
          DID_SAVEBUTTON:
           begin
             Save_Settings;
             Result:=1;
           end;
        end;
      end;
    end;
    WM_CONTROL:
    begin
      usID:=ushort(mp1);
      usNotify:=ushort(mp1 shr 16);
      // --------------------------------------------- E N T R Y  F I E L D S -----
      case usID of
        DID_CODEPAGEENTRY:
          if usnotify=EN_KILLFOCUS then  // If leaving the entry field, check the value!
          begin
            CPFrom:=max(0,min(65535,
              ToInteger(MyQueryDlgItemText(Wnd, DID_CODEPAGEENTRY))));
            MySetDlgItemText(Wnd, DID_CODEPAGEENTRY,
              ToString(CPFrom));
            Uninit_Convert;
            Init_Convert(CPFrom);
            Result:=1;
          end;
        DID_FPSENTRY:
          if usnotify=EN_KILLFOCUS then
          begin
            FPS:=
              ToReal(MyQueryDlgItemText(Wnd, DID_FPSENTRY));
            MySetDlgItemText(Wnd, DID_FPSENTRY,
              FPSToStr(FPS));
            Result:=1;
          end;
      end;
    end;
  end;

  // Don't forget to call default dialog procedure if could not handle!
  if result=0 then result:=WinDefDlgProc(Wnd,Msg,Mp1,Mp2);
end;


// --------------------------------------------------------------------------
// MyDlgProc
//
// The main procedure that processes messages.
//
function MyDlgProc(Wnd: HWnd; Msg: ULong; Mp1, Mp2: MParam): MResult; cdecl;
var usID, usnotify:ushort;
    MainSWP,TempSWP:SWP;
    XPos,YPos, XSize,YSize: Longint;
    s,s2:string;
    ActualTime:longint;
    Sub:pSubtitleElement;
begin
  result:=0; // Default: non-processed.

  case Msg of
    WM_SAVEAPPLICATION:  // Called when the application closes.
    begin
      WinStoreWindowPos(pszAppName, pszAppKey, MainWindow); // Save window settings to os2.ini!
      Result:=1;
    end;
                        // Mouse to move the window:
    WM_BUTTON2DOWN:
    begin
      MoveMode:=true;
      WinSetCapture(HWND_Desktop, MainWindow);
      WinQueryWindowPos(MainWindow, BaseSWP);        // Save window base pos and
      BaseMouseX:=Short1FromMP(MP1);                 // mouse base pos.
      BaseMouseY:=Short2FromMP(MP1);
      result:=1;
    end;

    WM_MOUSEMOVE:
    begin
      if MoveMode=true then
      begin
        WinSetWindowPos(MainWindow, 0,                             // move the window to the new position.
                        BaseSWP.X-(BaseMouseX-Short1FromMP(MP1)),
                        BaseSWP.Y-(BaseMouseY-Short2FromMP(MP1)),
                        0,0,
                        SWP_MOVE);
        WinQueryWindowPos(MainWindow, BaseSWP);
        Result:=1;
      end;

    end;

    WM_BUTTON2UP:                                    // Release the mouse
    begin
      MoveMode:=false;
      WinSetCapture(HWND_Desktop, 0);
      result:=1;
    end;

    WM_TIMER:                                        // Timer event!
    begin
                                    // Is it our timer that generated the message?
      usID:=ushort(mp1);
      if usID=TIMERID then
      begin                         // Yes, so do what's needed:
        if CommunicatorThreadID<>0 then // If the thread runs, then limit our
        if (GetTime-BaseTime<2000) then // timer to correct max 2 secs!
        begin
          ActualTime:=Time+GetTime-BaseTime;

          // Use the subtitle-list *only if* the user is not tampering with it, so if the
          // user is not in settings:
          if InSettings then
          begin
            Sub:=Nil;
            ActSubt:=Nil;
          end else
          Sub:=GetSubtitle(ActualTime);

          if Sub<>ActSubt then          // New subtitle?
          begin                         // Yes, so change text on screen:
            if Sub=Nil then
              MySetDlgItemText(MainWindow, DID_TEXTFIELD, '') else
              MySetDlgItemText(MainWindow, DID_TEXTFIELD, Convert(Sub^.TextToShow)); // Convert CP
            ActSubt:=Sub;
          end;

          // Now show actual time in info field:
          if GetTime-LastInfoShowTime>100 then // 10 times per second
          begin
            LastInfoShowTime:=GetTime;
            str((ActualTime div 60000),s);
            while length(s)<2 do s:='0'+s;
            ActualTime:=ActualTime mod 60000;
            str(ActualTime div 1000,s2);
            while length(s2)<2 do s2:='0'+s2;
            s:=s+':'+s2;
            ActualTime:=ActualTime mod 1000;
            str(ActualTime,s2);
            while length(s2)<3 do s2:='0'+s2;
            s:='Time: '+s+'.'+s2;
            MySetDlgItemText(MainWindow, DID_INFOFIELD, s);
          end;

        end;
        Result:=1;
      end;
    end;

    WM_SIZE, WM_ADJUSTFRAMEPOS:  // Resizing the window?
    begin
      if WinQueryWindowPos(MainWindow,MainSWP) then
      begin
        // Reposition the buttons and text field according to the new size:

        XPos:=5; YPos:=5;
        if MainSWP.CY<70 then YPos:=MainSWP.CY-70;

        WinQueryWindowPos(WinWindowFromID(MainWindow, DID_EXITBUTTON), TempSWP);
        XPos:= MainSWP.CX-5-TempSWP.CX;
        WinSetWindowPos(WinWindowFromID(MainWindow, DID_EXITBUTTON), 0,
                        XPos,YPos,
                        0,0,
                        SWP_MOVE);

        WinQueryWindowPos(WinWindowFromID(MainWindow, DID_SETUPBUTTON), TempSWP);
        XPos:=TempSWP.X+TempSWP.CX+5;
        WinQueryWindowPos(WinWindowFromID(MainWindow, DID_EXITBUTTON), TempSWP);
        XSize:= (TempSWP.X-5)-XPos;
        WinQueryWindowPos(WinWindowFromID(MainWindow, DID_INFOFIELD), TempSWP);
        YSize:=TempSWP.CY;
        WinSetWindowPos(WinWindowFromID(MainWindow, DID_INFOFIELD), 0,
                        XPos,YPos,
                        XSize,YSize,
                        SWP_MOVE or SWP_SIZE);

        XSize:=MainSWP.CX-10;
        YSize:=MainSWP.CY-YPos-TempSWP.CY-10;
        if YSize>=MainSWP.CY-10 then YSize:=MainSWP.CY-10;
        XPos:=5; YPos:=MainSWP.CY-YSize-5;
        WinSetWindowPos(WinWindowFromID(MainWindow, DID_TEXTFIELD), 0,
                        XPos,YPos,
                        XSize,YSize,
                        SWP_MOVE or SWP_SIZE);

      end;

      Result:=0; // Let the default processing run too!
    end;

    WM_COMMAND:
    begin
      usID:=ushort(mp1);
      if ushort(mp2)=CMDSRC_PUSHBUTTON then
      begin
        case usID of
// --------------------------------------------------- P U S H B U T T O N S ----------
          DID_EXITBUTTON:
           begin
             WinPostMsg(MainWindow, WM_QUIT, 0, 0);
             Result:=1;
           end;
          DID_SETUPBUTTON:
           begin
             InSettings:=True;
             WinDlgBox(HWND_DESKTOP, Wnd,
                       SetupDlgProc,
                       0, DID_SETUPWINDOW, Nil);
             InSettings:=False;
             Result:=1;
           end;
        end;
      end;
    end;
  end;

  // Don't forget to call default dialog procedure if could not handle!
  if result=0 then result:=WinDefDlgProc(Wnd,Msg,Mp1,Mp2);
end;

// --------------------------------------------------------------------------
// AddToSwitchList
//
// Adds a new entry to the list of active windows/programs, so
// makes the program "visible" and switchable.
//
procedure AddToSwitchList;
var
  Swctl     : SwCntrl; // Switch control data
  Hsw       : hSwitch; // Switch handle
  ID        : Pid;     // Process id
  hwndFrame : HWnd;    // Frame handle

begin
  WinQueryWindowProcess(MainWindow, @ID, nil);

  with SwCtl do
  begin
    hwnd := MainWindow;          // Window handle
    hwndIcon := 0;                // Icon handle
    hprog := 0;                   // Program handle
    idProcess := ID;              // Process identIfier
    idSession := 0;               // Session identIfier
    uchVisibility := SWL_Visible; // Visibility
    fbJump := SWL_Jumpable;       // Jump indicator
    StrPCopy(@szSwtitle, ProgramTitle); // Title
    bProgType := Prog_Default;    // Program type
  end;
  Hsw := WinAddSwitchEntry(@Swctl);
end;

// --------------------------------------------------------------------------
// InitPM
//
// Initialize PM and create message queue. These are the basic things that
// have to be done in order to create windows.
//
procedure InitPM;
begin
  Ab:=WinInitialize(0);
  Mq:=WinCreateMsgQueue(Ab,0);
end;

// --------------------------------------------------------------------------
// MainProc
//
// Loads the resource of Dialog window from EXE, sets it up, adds a new
// entry to switchlist, starts a timer, and processes messages.
// At the end, stops timer, and destroys the window.
//
procedure MainProc;
begin
  MainWindow := WinLoadDlg(HWND_DESKTOP, HWND_DESKTOP,
                            MyDlgProc, 0,
                            DID_MainWindow, nil);

  if MainWindow<>0 then
  begin
    MySetDlgItemText(MainWindow, DID_TEXTFIELD, FirstSubLine); // Set initial message

    WinRestoreWindowPos(pszAppName, pszAppKey, MainWindow); // Try to restore the window position

    AddToSwitchList;

    WinShowWindow(MainWindow, true);

    WinStartTimer(Ab, MainWindow, TIMERID, 64); // around every 64 millisec

    WinProcessDlg(MainWindow);

    WinStopTimer(Ab, MainWindow, TIMERID);

    WinDestroyWindow(MainWindow);
  end else
    SysMessageBox('Could not load dialog window resource! The program will halt.',
                  'Error loading resoures', true);
end;

// --------------------------------------------------------------------------
// UninitPM
//
// Destroys message queue.
//
procedure UninitPM;
begin
  WinDestroyMsgQueue(Mq);
end;

// --------------------------------------------------------------------------
// ProcessPipeMessage
//
// Gets time information from message from pipe
//
procedure ProcessPipeMessage(msg:String);
var s:string;
    b:word;
    sec:word;
    rsec:real;
    h,m:word;
    i:integer;
begin
  if length(msg)=8 then
  begin                                  // Message from WarpVision GUI
    s:=msg[1]+msg[2];
    val(s,h,i);
    s:=msg[4]+msg[5];
    val(s,m,i);
    s:=msg[7]+msg[8];
    val(s,sec,i);
    if (h<>oldHour) or (m<>oldMin) or (sec<>oldSec) then // We're not interested in the same message again..
    begin
      BaseTime:=GetTime;
      Time:=round(sec*1000+m*60000+h*3600000);
    end;
    oldHour:=h; oldMin:=m; oldSec:=sec;  // Save this message
  end else
  if length(msg)>=19 then
  begin
    s:=msg;
    setlength(s,19);
    if s='SYNC TrackPosition ' then      // Message from WarpMedia
    begin
      s:='';
      for b:=20 to length(msg) do s:=s+Msg[b];
      val(s,sec,i);

      // Corrigate time according to this seconds:
      BaseTime:=GetTime;
      Time:=sec*1000;
    end else
    if s[1]+s[2]='A:' then               // Message from WarpVision CLI
    begin
      s:=s[3]+s[4]+s[5]+s[6]+s[7]+s[8];
      val(s,rsec,i);

      BaseTime:=GetTime;
      Time:=round(rsec*1000);
    end;
  end;
end;

// --------------------------------------------------------------------------
// CommunicatorTheadFunc
//
// Second thread, that communicates through pipe.
//
function CommunicatorThreadFunc(p:pointer):longint;
var f:HFile;
    action:longint;
    rc:apiret;
    inmsg      : array[0..511] of char;
    readed      : ULong;
begin
  repeat

    // Try to open pipe

    rc := DosOpen(
      '\PIPE\WarpMedia', f, Action,
      0,
      file_Normal,
      open_Action_Open_if_Exists,
      open_Access_ReadOnly Or
      open_Flags_NoInherit  Or
      open_share_DenyNone ,
      nil);
    if rc = No_Error then
    begin
      // If the pipe could be opened:
      repeat
        fillchar(inmsg,512,0);
        rc:=DosRead(f,inmsg, sizeof(inMsg), readed);
        if (rc=0) and (readed>0) then ProcessPipeMessage(StrPas(@inMsg));
      until (ShuttingDown) or (rc<>0);

      DosClose(f);
    end;
    DosSleep(128); // Sleep some...
  until ShuttingDown;
  CommunicatorThreadID:=0; // Indicate that it has been terminated.
end;

// --------------------------------------------------------------------------
// WVGUITheadFunc
//
// Third thread, that communicates with WarpVisionGUI
//
function WVGUIThreadFunc(param:pointer):longint;
var p:HPipe;
    rc:apiret;
    inmsg : array[0..511] of char;
    readed : ULong;
begin
  rc:=DosCreateNPipe('\PIPE\WVGUIPOS',
                     p,
                     np_Access_InBound,
                     np_noWait
                     or np_Unlimited_Instances,
                     0,
                     255,
                     0);
  if rc<>no_error then
  begin
    SysMessageBox('Could not create pipe to communicate with WarpVision GUI!'+#13+#10+
                  'WarpVision GUI support turned off.',
                  'Error creating pipe!',true);
    exit;
  end;

  rc:=DosCreateEventSem('\SEM32\PIPE\WVGUIPOS', WVGUIPipeEvSem, 0, False);
  if rc<>no_error then
  begin
    SysMessageBox('Could not create semaphore to communicate with WarpVision GUI!'+#13+#10+
                  'WarpVision GUI support turned off.',
                  'Error creating semaphore!',true);
    DosClose(p);
    exit;
  end;

  rc:=DosSetNPipeSem(p,                     // Handle for pipe
                     hSem(WVGUIPipeEvSem),  // Handle of semaphore
                     1);                    // Used to distinguish among events
  if rc<>No_Error then
  begin
    SysMessageBox('Could not set semaphore to pipe!'+#13+#10+
                  'WarpVision GUI support turned off.',
                  'Error setting semaphore!',true);
    DosCloseEventSem(WVGUIPipeEvSem);
    DosClose(p);
    exit;
  end;

  repeat
    rc:=DosConnectNPipe(p);                 // Check if somebody wants to connect
    if rc=No_Error then
    begin                                   // Yes, client connected
      DosSetNPHState(p, np_Wait);           // Set blocking mode, so DosRead will wait for messages!
      repeat
        fillchar(inmsg,512,0);
        rc:=DosRead(p,inmsg, sizeof(inMsg), readed);
        if (rc=0) and (readed>0) then ProcessPipeMessage(StrPas(@inMsg));
      until (ShuttingDown) or (rc<>0) or (readed=0);
      DosSetNPHState(p, np_noWait);         // Set non-blocking mode, so DosConnectNPipe will not wait for connection!
      DosDisConnectNPipe(p);                // Disconnect client
    end;
    DosSleep(128);
  until ShuttingDown;

  DosCloseEventSem(WVGUIPipeEvSem);
  DosClose(p);
  WVGUIThreadID:=0;        // Indicate that it has been terminated.
end;

// --------------------------------------------------------------------------
// Set_Commandline_FPS
//
// Sets FPS variable if it was given as a command line parameter
//
procedure Set_Commandline_FPS;
var i:longint;
    r:real;
begin
  // Set FPS if it was given as a command line parameter
  val(paramstr(2),r,i);
  if i=0 then FPS:=r;
end;

// --------------------------------------------------------------------------
// Wait_for_Threads_to_Shutdown
//
// Waits for the threads to shut down, but max. 1.5 second!
//
procedure Wait_for_Threads_to_Shutdown;
const MaxCounter=1500 div 32; // 1.5 seconds, by 32msec steps
var b1,b2:boolean;
    rc:apiret;
    counter:longint;
begin
  counter:=0;
  repeat
    b1:=true; b2:=true; // default: both are terminated
    if CommunicatorThreadID<>0 then
    begin
      rc:=DosWaitThread(CommunicatorThreadID,dcww_noWait);
      b1:=(rc=no_error) or (rc=error_invalid_ThreadID);        // check if thread1 is terminated!
    end;
    if WVGUIThreadID<>0 then
    begin
      rc:=DosWaitThread(WVGUIThreadID,dcww_noWait);
      b2:=(rc=no_error) or (rc=error_invalid_ThreadID);        // check if thread2 is terminated!
    end;
    DosSleep(32); inc(Counter);
  until (b1 and b2) or (Counter>MaxCounter);
  if not b1 then DosKillThread(CommunicatorThreadID);          // Kill them if they are still
  if not b2 then DosKillThread(WVGUIThreadID);                 // running (after 1.5 secs)
end;

// ---------------------- M A I N --------------------------------------------
begin
  // Setup variables:
  ShuttingDown:=false;
  Time:=0;BaseTime:=GetTime;LastInfoShowTime:=BaseTime;
  oldHour:=0; oldMin:=0; oldSec:=0;
  SubtHead:=Nil;ActSubt:=SubtHead;
  SubFileName:='No subtitle loaded!';

  // Start new thread to read pipe: (for supporting WarpMedia and WarpVision CLI)
  CommunicatorThreadID:=VPBeginThread(CommunicatorThreadFunc, 16384, Nil);
  if CommunicatorThreadID=0 then
  begin
    SysMessageBox('Could not create communicator thread! Falling back to own synchronization.',
                  'Error creating thread!',true);
  end;

  // Start new thread for communicating with WarpVision GUI:
  WVGUIThreadID:=VPBeginThread(WVGUIThreadFunc, 16384, Nil);
  if CommunicatorThreadID=0 then
  begin
    SysMessageBox('Could not create communicator thread! WarpVisionGUI support disabled.',
                  'Error creating thread!',true);
  end;

  InitPM;               // Initialize PM
  Load_Settings;        // Load settings from Stitler.ini file
  Set_Commandline_FPS;  // Set new FPS if it was given as a command line parameter.
  Init_Convert(CPFrom); // Initialize Unicode API to convert from this codepage

  Load_Subtitles(ParamStr(1));  // Load subtitles if it's given as a parameter
                                // (does nothing for bad filenames or empty strings...)

  MainProc;

  //                               Ok, shutting down:

  ShuttingDown:=True;           // Tell the threads to shut down!

  Uninit_Convert;
  UninitPM;
  Free_SubtitleList;

  Wait_for_Threads_to_Shutdown; // Wait some for the threads to shut down
end.
