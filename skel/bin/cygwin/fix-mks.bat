@echo off
REM   Removes mks residue so that cygwin can run.

:: unset mks vars
set NUTCROOT=
set ROOTDIR=
set MAN_TXT_INDEX=
set MAN_CHM_INDEX=
set TERM=cygwin
set TERMINFO=
set TERMCAP=/etc/termcap

:: remove mks directories from path (s/mksnt/no-mksnt/g), and
:: add in cygwin/bin to allow calling cygwin utils from cmd.exe
set PATH=%PATH:mksnt=no-mksnt;%
set PATH=C:\cygwin\bin;%PATH%


:: Reset MKS settings to cygwin values. Setting $HOME can be problematic, since it varies
:: from system to system. Assume either c:/Users/{user}, or /home/{user}. (Multiple options
:: shown; just un/comment preference. Example converts {user} to lowercase, just in case.)
set SHELL=/bin/bash
set HOME_BASE=/home
set HOME_BASE=/cygdrive/c/Users
set HOME=%HOME_BASE%/%USERNAME%

:: assign HOME to result of script tolower.bat (uses cygwin 'tr', found in PATH)
set PROG_PATH=%~dp0
for /f "delims=" %%h in ('%PROG_PATH%\tolower.bat %USERNAME%') do @set HOME=%HOME_BASE%/%%h


:: if running cygwin-x (xterm)
:: TERM=xterm
:: XTERM_SHELL=/usr/bin/bash

:: after starting cygwin, don't cd to $HOME
set CHERE_INVOKING=1

:: at this point, just launch bash to run mks-free cygwin
:: bash --login -i

exit /b 0

