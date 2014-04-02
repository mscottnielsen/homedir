
Copy these '.bat' files to c:/cygwin (or c:/cygwin64 for x64).

They unset MKS environment variables so that cygwin can run.

Run cygwin by either double-clicking the start-*.bat icon(s), or
by running in "cmd.exe" (from any directory): \cygwin\start-cygwin.bat
and then Cygwin bash will start (and it will not cd to $HOME).

Notes:
* The Windows %USERNAME% is typically uppercase, and Cygwin $HOME is
  typically lowercase "/home/{username}", so "tolower.bat" is used
  to convert the username to lowercase before cygwin is launched.
* cygwin64 typically doesn't have rxvt, mintty, etc., so those
  launchers may not work with 64-bit cygwin

