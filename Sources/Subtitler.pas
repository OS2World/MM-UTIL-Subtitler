Program Subtitler;
{$X+}{$H+}{$R-}
{&USE32+}

{$PMTYPE PM}        // We are about to create a PM application...

{$R Subtitler.res}  // The resources will be compiled into this file
                    // by the compiler

Uses
  vpSysLow, VPUtils, Os2Def, Os2Base, Os2PmApi, UniConvert;

const {$I Subtitler.inc}     // Include the resource IDs
      TIMERID = 1;           // We'll have one timer, with this ID

      FPS:Real=25;           // Default FramePerSec  (e.g. 23.978)

      pszAppName='Subtitler';            // Save the settings into this appname/appkey in os2.ini
      pszAppKey='MainWindowProperties';

const ProgramTitle='Subtitler v1.0';     // Program title

type pSubtitleElement=^SubtitleElement;  // After processing the subtitle file, a linked list of
     SubtitleElement=record              // this kind of records will be created.
       TimeFrom:longint;                 // Show the subtitle from this time (in msec)
       TimeTo:longint;                   // ... until this time (in msec)
       TextToShow:String;                // Show this text (might be multiple lines)
       Next:pSubtitleElement;            // Next linked list element
     end;

var Ab:HAB;                 // Anchor block
    Mq:HMQ;                 // Message Queue
    MainWindow:HWND;        // Handle of main window

// Global variables used for parsing the subtitle file:

    t:text;                 // Text file handle, while loading the subtitles. Used by some procedures.
    TimeFrom:Longint;       // Parsed subtitles gets into this three variables
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

    CPFrom:ushort;                   // Codepage to convert the subtitles from. (codepage of subtitles)

    ShuttingDown:boolean;            // Used to indicate to the communicator thread to shut down
    CommunicatorThreadID:TID;        // Thread ID of communicator thread, which gets info from pipe



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
// Also converts the frame information to msec according to the FPS variable.
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
         TimeFrom:=round((TimeFrom*1000)/FPS);
         TimeTo:=round((TimeTo*1000)/FPS);
       end;
  end;
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
// GetSubtitle
//
// Returns the element of list (or NIL) that contains the subtitle that
// should be shown at a given time.
//

function GetSubtitle(time:longint):pSubtitleElement;
var temp:pSubtitleElement;
begin
  result:=nil;
  temp:=SubtHead;
  while (temp<>Nil) and (not ((temp^.TimeFrom<=time) and (temp^.TimeTo>=time))) do temp:=temp^.Next;
  result:=temp;
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
          Sub:=GetSubtitle(ActualTime);
          if Sub<>ActSubt then          // New subtitle?
          begin                         // Yes, so change text on screen:
            if Sub=Nil then
              MySetDlgItemText(MainWindow, DID_TEXTFIELD, '') else
              MySetDlgItemText(MainWindow, DID_TEXTFIELD, Sub^.TextToShow);
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

    WM_ADJUSTFRAMEPOS:  // Resizing the window?
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

        XPos:= 5;
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
// Returns true if it could load every subtitle, and build the list.
// Also converts the text from its codepage to the current codepage, using
// the unicode API.
//
// Also processes parameters.
//
function Load_Subtitles:boolean;
var s:string;
    i:integer;
begin
  result:=false;

  if ParamCount>=2 then val(paramstr(2),FPS,i);     // Set frame/sec
  if FPS<1 then FPS:=30;

  cpfrom:=0;
  // Load translation data
  Assign(t,'Translat.ini');                         // Codepage should be
                                                    // stored in this file
  filemode:=Open_Access_ReadOnly or Open_Share_DenyNone;
  {$I-}
  reset(t);
  {$I+}
  if ioresult=0 then
  begin
    {$I-}
    readln(t,s);
    {$I+}
    if ioresult=0 then
    begin
      val(s,cpfrom,i);
    end;
    close(t);
  end;

  //    Load and process subtitles

  assign(t,paramstr(1));
  filemode:=Open_Access_ReadOnly or Open_Share_DenyNone;
  {$I-}
  reset(t);
  {$I+}
  if ioresult<>0 then exit;

  if not eof(t) then
  repeat
    readln(t,s); // Get the first non blank line! Try to get subtitle file format!
  until (s<>'') or (eof(t));

  if eof(t) then  // Could not figure out file format.
  begin
    close(t); exit;
  end;

  close(t);
  reset(t);

  SubStyle:=0; // Unknown;
  SubTitleNumber:=1;

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
  Init_Convert(CPFrom);
  repeat
    TextToShow:=Convert(TextToShow); // Convert it!
    AddNewSubtitle;
    ParseOneLine;
  until eof(t);
  Uninit_Convert;
  close(t);
  result:=true;
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
    i:integer;
begin
  if msg=nil then exit;
  if length(msg)<19 then exit;
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
  if s[1]+s[2]='A:' then               // Message from WarpVision
  begin
    s:=s[3]+s[4]+s[5]+s[6]+s[7]+s[8];
    val(s,rsec,i);

    BaseTime:=GetTime;
    Time:=round(rsec*1000);
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
        if rc=0 then ProcessPipeMessage(StrPas(@inMsg));
      until (ShuttingDown) or (rc<>0);

      DosClose(f);
    end;
    DosSleep(128); // Sleep some...
  until ShuttingDown;
end;

// ---------------------- M A I N --------------------------------------------
begin
  // Setup variables:
  ShuttingDown:=false;
  Time:=0;BaseTime:=GetTime;LastInfoShowTime:=BaseTime;
  SubtHead:=Nil;ActSubt:=SubtHead;

  // Start new thread to read pipe:
  CommunicatorThreadID:=VPBeginThread(CommunicatorThreadFunc, 16384, Nil);
  if CommunicatorThreadID=0 then
  begin
    SysMessageBox('Could not create communicator thread! Falling back to own synchronization.',
                  'Error creating thread!',true);
  end;

  InitPM;
  if ParamCount<1 then
  begin
    SysMessageBox('You must start the program with a parameter, containing the subtitle file name!',
                  'Error with parameters!', false);

  end else
  if Load_Subtitles then
  begin
    MainProc;
  end;
  UninitPM;

  Free_SubtitleList;

  ShuttingDown:=True;
  if CommunicatorThreadID<>0 then
    DosWaitThread(CommunicatorThreadID,dcww_Wait);
end.
