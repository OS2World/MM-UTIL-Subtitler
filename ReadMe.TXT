
                            S u b t i t l e r  v1.2
                            -----------------------


Description:

  This is an application that shows subtitles for AVI files (usually SUB files)
  while they are being played with WarpMedia or WarpVision CLI/GUI. It knows
  three kind of subtitle files currently, if you are lucky, yours is also 
  supported.:)


Usage (short):

  The easiest way of using the application is to start it, and set the SUB file
  and the FPS in the Settings window, available by pressing the Setup button.

  You can also provide these by command line parameters:

  SUBTITLER [SubFileName [FramePerSec]]

  In this case, the first parameter has to be the name (and path) of the file 
  containing the subtitles. If a second parameter is given, it will be treated
  as the FPS of the film. It is 25 by default.

  When Subtitler is started, you can start your favourite media player appli-
  cation to see films with subtitles.


Getting started (long usage):

  - 1st step: Configuring Subtitler for general usage

    After starting Subtitler, you should set its position and size to what you
    would like for it. Then you can open the Font Palette and the Color Palette
    (they are in the System Setup folder), and drag-and-drop your preferred
    font (a big enough font size is recommended, like 20 or bigger) from the
    Font Palette, and your preferred background and font color from the Color
    Palette (use simple drag and drop for background color, and Ctrl+Drag and
    drop for fint color changing).
    Subtitler will remember these settings next time you start it.

  - 2nd step: Loading subtitle file

    Press the Setup button, so the Settings window will appear. You can load
    files containing subtitles in this window, by pressing the Load button.

    For subtitles with national characters, Subtitler has to know the codepage
    in which the subtitle-file has been saved. If it was saved in a Windoze
    environment, it might be necessary to set a Windoze codepage, like 1250 or
    1252 (for Eastern European countries). 
    It has to be set in the 'Codepage of subtitles' entry.

    Another thing you might need to set is the Frame/Sec (FPS) of the film.
    There is one kind of subtitle-file format, which contains frame information,
    and not time information for subtitles. In other words, it contains that
    for example a specified text should be shown between the 3150. and the 3310.
    frame (picture/image) of the film. For this kind of subtitle files, 
    Subtitler has to convert frame number to time, and for this, it has to know
    the FPS of the film.

    Subtitler will show if it needs the FPS for this subtitle file in the
    'In use now' entry. If 'Yes' is written there, you have to provide the FPS.
    (WarpVision CLI writes the FPS constant to the screen when started. For
    WarpVision GUI and WarpMedia, you might check the Playlist for this infor-
    mation. In the last case, you can guess it. ;) It is usually 23.98. )

    When all is done, you can save your FPS and Codepage settings by pressing
    the Save settings button. It will create a Stitler.ini file next to the
    Subtitler executable. It is a editable text file.

    Press the Done button to go back to the main window.

    You can change these settings anytime, even while playing a subtitle. The
    changes will take effect when you press the Done button.

  - 3rd step: Starting a media-player application

    Subtitler can co-operate with the following media-player applications:
     - WarpMedia
     - WarpVision CLI (Text-mode version, v0.0.13 is tested to work)
     - WarpVision GUI (Graphical version, builds after 2002.05.28.)

    Subtitler has to get film-position information from these applications.
    There is no problem with WarpMedia and WarpVision GUI, they automatically
    send these informations, when the film is started. So, there is nothing
    special to do with them, use them as you use them regulary.

    With WarpVision CLI, you have to use an additional program, called PipeExec
    (available in this package). It sends the output of WarpVision CLI to
    Subtitler, so the actual position can be got. So, in this case, you have
    to start WarpVision CLI in this way:

    PipeExec wvision.exe <parameters>


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


Thankyous:

  Thanks to Vlad Stelmahovsky (author of WarpVision GUI) for implementing the
  named pipe position-output, so Subtitler can be used with WVGUI until they
  implement native subtitle support!


History:

  v1.0: Initial release
  v1.2: Support for changing codepage, FPS and SUB-file on the fly
        Added support for Stitler.ini file, so settings can be saved,
          translat.ini is not used anymore
        Minor Unicode conversion fix
        WarpVision GUI support


<End of ReadMe.TXT>