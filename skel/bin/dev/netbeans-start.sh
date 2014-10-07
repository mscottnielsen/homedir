#!/bin/bash

# Use java7/java8+ to run the IDE. Projects can use other platforms.
export JAVA_HOME=/opt/jdk8
#export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64
export PATH=$JAVA_HOME/bin

# optionally use bundled netbeans maven; just make sure no other maven home is set
unset M2_HOME MAVEN_HOME
export PATH=/opt/maven3/bin:$PATH

# fix java timezone issue. On Linux, if TZ is set, Sun Java always uses it
export TZ=$(cat /etc/timezone | sed 's/ /_/g')

# fix tar using either gnu-tar options, or custom tar wrapper script
export TAR_OPTIONS=--delay-directory-restore
#export TAR=$HOME/bin/slowtar.sh

# fix for undersized tmp dir
TMPDIR=$HOME/temp/tmpdir/netbeans
[ ! -d $TMPDIR ] && mkdir -p $TMPDIR

############################################################################
# let proxy be set via netbeans options
unset http_proxy
unset https_proxy
unset ftp_proxy

############################################################################
# Look-and-Feel examples
#   LAF=' --laf javax.swing.plaf.metal.MetalLookAndFeel'
#   LAF=' --laf com.sun.java.swing.plaf.gtk.GTKLookAndFeel'
# Napkin:
#   option: -Dswing.defaultlaf=net.sourceforge.napkinlaf.NapkinLookAndFeel
#   LAF='--laf net.sourceforge.napkinlaf.NapkinLookAndFeel'
#   LAF_JARS='$HOME/opt/lib/napkinlaf/napkinlaf-1.2.jar:$HOME/opt/lib/jgoodies/looks/looks.jar'
# JGoodies:
#   LAF=" --laf com.sun.java.swing.plaf.gtk.GTKLookAndFeel"
#   LAF=" --laf com.jgoodies.looks.plastic.PlasticLookAndFeel"

# JGoodies
LOOKS_HOME=$HOME/opt/lib/jgoodies
LAF_JARS=$LOOKS_HOME/common/jgoodies-common.jar:$LOOKS_HOME/looks/jgoodies-looks.jar

CP="-cp:p $LAF_JARS"
LAF=" --laf com.jgoodies.looks.plastic.Plastic3DLookAndFeel"

OPTS="$LAF $CP"

# set classpath and other JVM options, LAF, etc
#OPTS=" -J-Dswing.aatext=TRUE -J-Dawt.useSystemAAFontSettings=on $OPTS "
OPTS=" -J-Dorg.netbeans.editor.linewrap=false $OPTS "
OPTS=" -J-Djsch.connection.timeout=30000 -J-Dsocket.connection.timeout=300000 $OPTS "
OPTS=" -J-Djava.io.tmpdir=$TMPDIR $OPTS "

# fix console output truncating junit results
OPTS=" -J-Dtestrunner.max.msg.line.length=2000 $OPTS "

# for scala
OPTS=" -J-Ddefault.javac.target=1.6 $OPTS "
OPTS=" -J-Ddefault.javac.source=1.6 $OPTS "
# set SCALA_HOME, append "-J-Dscala.home={scala_home_path}" to netbeans options;
# can set "netbeans_default_options" property in {NETBEANS_HOME}/etc/netbeans.conf
OPTS=" -J-Dscala.home=$SCALA_HOME $OPTS "


############################################################################
# work-around for menus not working; need correct DESKTOP_SESSION
# for {gnome, mate, etc...} this script guesses at desktop session
SET_SESSION_SCRIPT=$HOME/bin/desktop_session.sh
if [ -f $SET_SESSION_SCRIPT ]; then
  eval $( $SET_SESSION_SCRIPT -v -p -u gnome )
else
  echo "*** warning: script to fix desktop session not found: $SET_SESSION_SCRIPT" 1>&2
  echo "*** warning: setting desktop session:  DESKTOP_SESSION=gnome (was: $DESKTOP_SESSION)" 1>&2
  export DESKTOP_SESSION=gnome  # using script instead by default
fi

# work-around for older gnome desktop (ubuntu) and remote dev host
# http://wiki.netbeans.org/FaqCplusPlusRemoteSocketException
# (my desktop-session script above now does this)
#unset GNOME_DESKTOP_SESSION_ID
#unset MATE_DESKTOP_SESSION_ID

NETBEANS_HOME=/opt/netbeans-dev

echo "## $(readlink -e $NETBEANS_HOME/bin/netbeans)"
echo "## OPTS=$OPTS"
echo "## CP=$CP"
echo "## DESKTOP_SESSION=$DESKTOP_SESSION"

echo ## starting gradle..."
type gradle && gradle --daemon --quiet
sleep 3

echo ## starting netbeans..."
set -x
$NETBEANS_HOME/bin/netbeans $CP $OPTS --jdkhome $JAVA_HOME
set +x

