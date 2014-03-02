
                               S u b t i t l e r
                               -----------------


Description:

  This is an application that shows subtitles for AVI files (usually SUB files)
  while they are being played with WarpMedia or WarpVision. It currently knows
  three kind of subtitle files, if you are lucky, yours is also supported.:)


Usage:

  SUBTITLER <SubFileName> [FramePerSec]

  Parameter one has to be the name (and path) of the file containing the 
  subtitles. Parameter two is optional, it is 25 by default. If the subtitle
  file contains Frame numbers instead of time information (numbers in curved
  brackets), you have the use this to provide the FPS of the AVI file. It is
  a real number, it's not a must to be an integer.

  If your subtitle file contains national characters, make sure that you set
  the codepage of the subtitle file in the translat.ini file (it's a plain
  text file).

  If you plan to use it with WarpMedia, you don't have to do anything else.

  If you plan to use it with WarpVision, you will have to use another program
  too, called PipeExec. It sends every output of WarpVision into a Pipe, making
  it possible for Subtitler to track the position of the movie. You should
  start WarpVision like this:
  
  PipeExec WarpVision.EXE D:\Path\Movie.AVI


Sources/Compilation:

  All the sources are included. To compile it, you will need the followings:
   - IBM OS/2 DEVELOPER'S TOOLKIT (Included with eComStation)
   - Virtual Pascal v2.1 (can be freely downloaded from www.vpascal.com)

  To create an EXE, you will have to take care of the followings:

   - Execute R.CMD, which will create the pascal-style resource file and
     include file from the dialog.dlg and dialog.h files.

   - Make sure that the INCLUDE environment variable contains the path to
     the header files of the toolkit. (In my case, SET INCLUDE=F:\os2tk45\h) 
     They are needed to compile the resources.

   - Start Virtual Pascal, change its directory to the directory of 
     Subtitler.pas/PipeExec.pas
     (File->Change Dir...)

   - Open the Subtitler.pas/PipeExec.pas file

   - Build it! (Compile->Build)


Changing the sources:

  You are allowed to do changes, and do everything you want with the program
  and/or the sources.

  To change the window of the program use the DLGEDIT.EXE from the toolkit to 
  edit the dialog.res file. It will also modify the dialog.dlg and dialog.h
  files. Run R.CMD to reflect the changes to pascal.

Contact information:

  I don't plan to do changes to this program, anyway, the sourcecode is open,
  so anybody can change it. :) The purpose of the release is to help others
  with creating OS/2 applications.

  If you still want to contact me, send an e-mail to 
  Doodle <kocsisp@dragon.klte.hu>


