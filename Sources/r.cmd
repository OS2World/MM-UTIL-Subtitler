@echo off

rem This script creates the pascal-compatible RC file and INC file from
rem the dialog.dlg and dialog.h files, that are created by the dialog editor.
rem (dlgedit.exe)

respp dialog
del Subtitler.rc
del Subtitler.inc
rename dialog.plg Subtitler.rc
rename dialog.inc Subtitler.inc
