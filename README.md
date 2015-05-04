homedir
=======

A generic home directory for dot-files (eg., .bashrc), scripts, application set-up and configuration. Portable across all unix-like OS's (including cygwin), and works or mutliple users across multiple hosts (without branching or patching).

Features:
* a home directory configuration (scripts & dot-files) completely under version control. No need for a separate project for every user and/or host or OS.
* per-host and per-user configuration may also be versioned, but is separate. Each user & host is a separate file. Groups of users may share common configuration env files (eg, dev org, sys-ops org, "xyz" org, ...)
* useful for training environments with "student" accounts that are basically the same and need to be reset after class; but also allows per-student or per-course customization.
* easy to set up virtual environments (VM/containers for demos, POCs), so they all have the same functionality you've come to expect from your $HOME.
* personal info (passwords, personal files, env vars, private aliases/functions) can be in an unversioned, local file.

All $HOME configuration is refactored into separate files:
* generic configuration that applies to every user, every host, every OS (common files; most configuration goes here)
* per-OS configuration (a lot of things go here: e.g., one file each for Linux, SunOS, HP-UX, AIX, Cygwin, MacOSX, etc)
* per-application configuration (these are very small per-application configuration settings; a few env vars, functions)
* per-host configuration (only few env vars set here, for example properly setting the PATH for a given host)
* per-user configuration (ideally, hardly anything goes here, but it may be useful for "generic" user accounts)
* unversioned, local, current user-configuration (optional: maybe env vars storing passwords, usernames, etc)

To install & use this $HOME dir configration, get the 'git' project (either via 'git clone', or download the zip); and place it anywhere in your home directory. Symbolic links will then be created during the "install" script, pointing from your $HOME into this project:

    ## get the project (for example):
    $ mkdir ~/git-wk && cd ~/git-wk
    $ git clone https://github.com/mscottnielsen/homedir.git
    ...
    $ cd homedir

    ## this creates symlinks from ~/.bashrc, ~/.profile, etc to
    ## existing files will be moved out of the way (renamed)
    ./setup-links.sh

For example, your $HOME will look like this after running the script (and, again, old files are not deleted, they are just moved out of the way):

    .aliases      -> ~/git-wk/homedir/skel/.aliases
    .bashrc       -> ~/git-wk/homedir/skel/.bashrc
    .cshrc        -> ~/git-wk/homedir/skel/.cshrc
    .screenrc     -> ~/git-wk/homedir/skel/.screenrc
    .vim          -> ~/git-wk/homedir/skel/.vim/
    .vimrc        -> ~/git-wk/homedir/skel/.vimrc
    env           -> ~/git-wk/homedir/skel/env/
    host_env      -> ~/git-wk/homedir/skel/host_env/
    user_env      -> ~/git-wk/homedir/skel/user_env/
     ....etc...

Add your personal config (what normally would go in your .bashrc) into ~/local.env (unversioned). For user-specific and host-specific configuration, add files to ~/user_env/user-${USER}.env and ~/host_env/host-$(hostname).env, respectively. These files will be ignored by git by default (see .gitignore).

Here's what the full directory tree looks like (there are many more files than this, though):

    $HOME
    |-- bin
    |   |-- common
    |   |   |-- log.sh
    |   |   |-- hashtab.sh
    |   |-- completion
    |   |   |-- bash_completion_cdw
    |   |   |-- bash_completion_psx
    |   |   `-- bash_completion_ssh
    |   |-- cygwin
    |   |   |-- ReadMe.txt
    |   |   |-- check-win32-64.bat
    |   |   |-- start-cygwin.bat
    |   |   |-- start-cygwin-rxvt.bat
    |   |   `-- tolower.bat
    |   |-- ext2dir.sh
    |   |-- gg
    |   |   |-- bash_completion_gg
    |   |   |-- print-trail-rec-summary.sh
    |   |   |-- print-trail.sh
    |   |-- logger.sh
    |   |-- ora
    |   |   `-- test_ora.sh
    |   |-- set_proxy.sh
    |   |-- unset_proxy.sh
    |   `-- update-public-key.sh
    |
    |-- env
    |   |-- app-bash-completion.env
    |   |-- ...
    |   |-- app-goldengate.env
    |   |-- app-java.env
    |   |-- app-rlwrap.env
    |   |-- local.env.sample
    |   |-- os-aix.env
    |   |-- os-cygwin.env
    |   |-- os-hp-ux.env
    |   |-- os-linux.env
    |   |-- os-os_390.env
    |   |-- os-sunos.env
    |   `-- os-unix.env
    |
    |-- user_env
    |   |-- org-default.env
    |   |-- org-{my-dev-org}.env    # for example, org-some-cool-acryonym.env, or org-devops.env
    |   |-- ...
    |   `-- user-{my-username}.env  # your login ($LOGNAME / $USER), will be source automatically.
    |                               # to automatically source the org-*env files, set (in order):
    |                               #   $ export USER_ORG=$USER_ORG,devops,some-cool-acryonym
    |
    |
    `-- host_env
        |-- host-{hostname1}.env     # when you login to {hostname1}, this will automatically be sourced
        |-- host-{hostname2}.env
        `-- ...

The "host_env" directory can be used to configure per-host env settings (PATH, JAVA_HOME, etc); I keep this as a separate git repo that is a git submodule for the homedir git project, but it could just as easily be unversioned files, or generated from a puppet/pallet host list.


