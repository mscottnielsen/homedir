@echo off

set PROG_PATH=%~dp0
%PROG_PATH%\fix-mks.bat

if exist %PROG_PATH%\bin\mintty.exe (
  :: better terminal than cmd.exe
  %PROG_PATH%\bin\mintty.exe -
) else (
   :: simple bash in cmd
   bash --login -i
)

:: end of file

