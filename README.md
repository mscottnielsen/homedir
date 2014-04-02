homedir
=======

A generic home directory (bash), dot-files, scripts, etc, portable across OS's, suitable for mutliple users

To install & use, get the project (either git clone, or download the zip); and place it anywhere in your home directory. Symbolic links can then be created to point from your $HOME into the project:

    ## get the project
    $ mkdir ~/git-wk && cd ~/git-wk
    $ git clone https://github.com/mscottnielsen/homedir.git
    ...
    $ cd homedir

    ## creates symlinks from ~/.bashrc, ~/.profile, etc to here.
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
    |   |-- org-goldengate.env
    |   |-- ...
    |   `-- user-msnielse.env
    |
    `-- host_env
        |-- host-{hostname1}.env
        |-- host-{hostname2}.env
        `-- ...

The "host_env" directory can be used to configure per-host env settings (PATH, JAVA_HOME, etc); I keep this as a separate git repo that is a git submodule for the homedir git project, but it could just as easily be unversioned files, or generated from a puppet/pallet host list. 



