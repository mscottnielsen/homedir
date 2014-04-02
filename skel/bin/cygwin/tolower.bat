:: Convert given argument to lowercase.
:: Relies on GNU/cygwin 'tr' being found in the PATH.
::
:: Usage: tolower.bat %USERNAME%
::
:: Example: 
::  c:> echo %USERNAME%
::   MNIELSEN
::  c:> tolower.bat %USERNAME%
::   mnielsen
::   
:: Example in 'bat' file (so that result can be used in the script):
::   for /f "delims=" %%h in ('c:\cygwin\tolower.bat %USERNAME%') do @set HOME=/home/%%h


echo %1|tr 'A-Z' 'a-z'

