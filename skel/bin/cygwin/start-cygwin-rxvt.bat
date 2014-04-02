@echo off

set PROG_PATH=%~dp0
%PROG_PATH%\fix-mks.bat

if exist %PROG_PATH%\bin\rxvt.exe (
  :: better terminal (native rxvt, no x11)
  %PROG_PATH%\bin\rxvt.exe -display :0 -fn "Lucida Console-14" -tn rxvt-cygwin-native -e /bin/bash --login
) else (
   :: simple bash in cmd
   bash --login -i
)

:: end of file

