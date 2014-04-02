:: usage: 
::   tolower.bat %USERNAME%
::
:: I.e.: 
::  c:> echo %USERNAME%
::   MSNIELSE
::  c:> tolower.bat %USERNAME%
::   msnielse
::   
:: Internally relies on gnu/cygwin 'tr' being installed: echo %USERNAME% | tr 'A-Z'  'a-z'
:: 
:: Typically usage in 'bat' file:
::    for /f "delims=" %%h in ('c:\cygwin\tolower.bat %USERNAME%') do @set HOME=/home/%%h


echo %1|tr 'A-Z' 'a-z'

