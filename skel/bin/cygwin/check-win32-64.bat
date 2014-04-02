@echo off
:: Test for 32/64-bit OS (ignores the bitness of the process).


IF [%PROCESSOR_ARCHITECTURE%] == [x86] (
 IF [%PROCESSOR_ARCHITEW6432%] == [] ( GOTO :Windows_x86 )
)

:Windows_x64
  echo 64-bit
  exit /b 0

:Windows_x86
  echo 32-bit
  exit /b 0

