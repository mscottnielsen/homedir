#!/bin/bash

# use Java7/Java8+ to run the IDE; projects can use other platforms
: ${JAVA_HOME:="${JAVA_HOME:-"/usr/lib/jvm/java-8-openjdk-amd64"}"}
PATH=$JAVA_HOME/bin:$PATH

# use bundled netbeans maven; make sure no other maven_home is set
unset M2_HOME MAVEN_HOME

# fix Java/Linux timezone issue; if TZ is set, Sun Java always uses it
[ -f /etc/timezone ] && export TZ=$(cat /etc/timezone | sed 's/ /_/g')

# fix tar using either gnu-tar options, or custom tar wrapper script
export TAR_OPTIONS=--delay-directory-restore
#export TAR=$HOME/bin/slowtar.sh

# fix for undersized tmp dir
TMPDIR=$HOME/temp/tmpdir/netbeans
[ ! -d $TMPDIR ] && mkdir -p $TMPDIR

# let proxy be set via netbeans options
unset http_proxy
unset https_proxy
unset ftp_proxy

# java classpath, options, properties
OPTS=

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

# JGoodies (disabled)
if [ "$JGOODIES" != "" ]; then
  #LAF=" --laf com.jgoodies.looks.plastic.Plastic3DLookAndFeel"
  LOOKS_HOME=$HOME/opt/lib/jgoodies
  LAF_JARS=$LOOKS_HOME/common/jgoodies-common.jar:$LOOKS_HOME/looks/jgoodies-looks.jar
fi

[ "$LAF_JARS" != "" ] && CP="-cp:p $LAF_JARS" && OPTS="$LAF $CP"

############################################################################
# set classpath and other JVM options, LAF, etc
#OPTS=" -J-Dswing.aatext=TRUE -J-Dawt.useSystemAAFontSettings=on $OPTS "
OPTS=" -J-Dorg.netbeans.editor.linewrap=false $OPTS "
OPTS=" -J-Djsch.connection.timeout=30000 -J-Dsocket.connection.timeout=300000 $OPTS "
OPTS=" -J-Djava.io.tmpdir=$TMPDIR $OPTS "

############################################################################
# fix console output truncating junit results
OPTS=" -J-Dtestrunner.max.msg.line.length=2000 $OPTS "

############################################################################
# scala
OPTS=" -J-Ddefault.javac.target=1.6 $OPTS "
OPTS=" -J-Ddefault.javac.source=1.6 $OPTS "
# set SCALA_HOME, append "-J-Dscala.home={scala_home_path}" to netbeans options;
# can set "netbeans_default_options" property in {NETBEANS_HOME}/etc/netbeans.conf
[ "$SCALA_HOME" != "" ] && OPTS=" -J-Dscala.home=$SCALA_HOME $OPTS "


############################################################################
# work-around for menus not working; need correct DESKTOP_SESSION
# for {gnome, mate, etc...} this script guesses at desktop session
: ${SET_SESSION_SCRIPT:="$HOME/bin/desktop_session.sh"}
if [ -f "$SET_SESSION_SCRIPT" ]; then
  echo "## script to fix desktop session: $SET_SESSION_SCRIPT" 1>&2
  eval $( $SET_SESSION_SCRIPT -v -p -u gnome )
fi

# work-around for older gnome desktop (ubuntu) and remote dev host
# http://wiki.netbeans.org/FaqCplusPlusRemoteSocketException
# (the desktop_session.sh script (above) now also fixes this)
#unset GNOME_DESKTOP_SESSION_ID
#unset MATE_DESKTOP_SESSION_ID

############################################################################
: ${NETBEANS_HOME:="/opt/netbeans"}

echo "## $(readlink -e $NETBEANS_HOME/bin/netbeans)"
echo "## OPTS=$OPTS"
echo "## CP=$CP"
echo "## DESKTOP_SESSION=$DESKTOP_SESSION"

#type gradle && echo ## starting gradle..." && gradle --daemon --quiet

echo ## starting netbeans..."
set -x
$NETBEANS_HOME/bin/netbeans $CP $OPTS --jdkhome $JAVA_HOME
set +x

