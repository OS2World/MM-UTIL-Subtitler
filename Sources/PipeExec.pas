
// Program to redirect output of a program to \PIPE\WarpMedia
// Based on Virtual Pascal's example program.

Program PipeExec;

{&PMTYPE VIO}

{$Delphi+,T-,X+,Use32-,H+}

Uses
  MyOs2Exec, Os2Base, SysUtils, VPUtils;


function Parameters:string; // Returns every parameter of the program, starting from parameter number 2.
var w:word;
begin
  result:='';
  for w:=2 to paramcount do
  begin
    if w>2 then result:=result+' ';
    result:=result+'"'+paramstr(w)+'"';
  end;
end;

const Pipe_Ready:boolean=false;
      p:HPipe=0;

function CreatePipeFunc(parm:pointer):longint;
var rc:longint;
begin
  // Thread that tries to create the PIPE, and ends if it could.
  rc:=DosCreateNPipe('\PIPE\WarpMedia',p,
               np_Access_OutBound ,
               np_wmesg or np_rmesg or 1,
               256,         // Output buffer size
               256,         // Input buffer size
               0);          // Use default time-out
  if rc<>0 then writeln('Error creating pipe, rc=',rc)
  else
  begin
    rc:=DosConnectNPipe(p);
    if rc<>0 then writeln('Error connecting pipe, rc=',rc) else
    Pipe_Ready:=True;
  end;
end;

procedure ClosePipe;
var rc:longint;
begin
  if p<>0 then
  begin
    DosDisConnectNPipe(p);
    rc:=DosClose(p);
    if rc<>0 then writeln('Error closing pipe, rc=',rc);
  end;
  Pipe_Ready:=false;
end;


Procedure SendToPipe(s:string);
var rc,actual:longint;
begin
  if Pipe_Ready then
  begin
    rc:=DosWrite(p,s[1], length(s), Actual);
    if rc<>0 then
    begin
      // error writing to pipe, so close it and reopen!
      ClosePipe;
      VPBeginThread(CreatePipeFunc, 16384, nil);
    end;
  end;
end;

procedure ExecuteProgram;
Var
  tr  : TRedirExec;
  i   : Integer;
  x,y : Integer;
  s:String;

begin
  tr := TRedirExec.Create;                   // Create a TRedirExec instance
  if Assigned( tr ) then                     // If creation was ok...
    try                                      // Catch any errors
          { Execute the command to grab the output from }
          tr.Execute( paramstr(1), pchar(Parameters), nil );
          While not tr.Terminated do         // While command is executing
            If tr.MessageReady then          // Ask if a line is ready
            begin
              s:=tr.Message;
              Write( s );          // - Display it
              SendToPipe(s);       // - Send it
            end
            else
              DosSleep( 30 );                // - otherwise wait a little
    finally
      tr.Destroy;                            // Free the instance
    end
  else
    Writeln( 'Error creating TRedirExec class instance' );
end;

begin
  Writeln( '-= Output redirector active =-' );
  PopupErrors := False;                      // Tell SysUtils to display
                                             // exceptions on user screen
  VPBeginThread(CreatePipeFunc, 16384, nil);
  ExecuteProgram;
  Writeln;
  Writeln( '-= Program terminated =-' );
  ClosePipe;
end.
