@echo off

set PROG_PATH=%~dp0
%PROG_PATH%\fix-mks.bat

if exist c:\cygwin\bin\mintty.exe (
  :: better terminal than cmd.exe
  C:\cygwin\bin\mintty.exe -
) else (
   :: simple bash in cmd
   bash --login -i
)

:: end of file

