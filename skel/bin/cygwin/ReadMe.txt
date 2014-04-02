
Copy these '.bat' files to c:/cygwin

They unset MKS environment variables so that cygwin can be run.

Run cygwin by either double-clicking the start-*.bat icon(s), or
by running (from any directory): \cygwin\start-cygwin.bat
Cygwin bash will be started (and it won't cd to $HOME).

The Windows %USERNAME% is typically uppercase, and Cygwin $HOME is typically
lowercase "/home/{username}", so the bat file "tolower.bat" helps convert
this before cygwin is launched.

