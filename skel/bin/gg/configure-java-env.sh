#!/bin/bash
##
## This script tries to set the library load path (LD_LIBRARY_PATH
## or LIBPATH) as necessary for a Java/JNI application.
##
## The library load path requires the correct jvm library to be found;
## the location of this library (libjvm.so or jvm.dll) depends on the
## host architecture and version of Java being used.
##
## The environmental variable JAVA_HOME is used to find a specific version
## of Java, and JVM and JVM_LIB may be used to find a specific JVM.
##
##   ************  NOTE! *********************************************
##   ** This script can only make a 'best guess', and may not find  **
##   ** the JVM you actually want to use.                           **
##   *****************************************************************
##
## If setting these environmental variables manually:
##  For Solaris / Linux:
##   export JAVA_HOME=/path/to/java             # (this is optional)
##   export PATH="${JAVA_HOME}"/bin:"${PATH}"
##   export LD_LIBRARY_PATH=${JAVA_HOME}/path/to/jvm_dir/:"${LD_LIBRARY_PATH}"
##
##  For AIX:
##   export JAVA_HOME=/path/to/java
##   export PATH="${JAVA_HOME}"/bin:"${PATH}"
##   export LIBPATH=${JAVA_HOME}/path/to/jvm_dir/classic:"${LIBPATH}"
##   export LIBPATH=${JAVA_HOME}/path/to/jvm_dir/:"${LIBPATH}"
##
## Usage:
##   To just PRINT the current environmental variables for the Java
##   environment, execute the script (all changes are lost in the subshell):
##     shell>  ./configure-java-env.sh
##  
##   To actually SET the env variables in the current shell, source 
##   this file (in ksh/bash):
##     shell>  .  ./configure-java-env.sh
##
##   To completely reset the script to do a new search,
##     shell> unset JVM  JVM_PATH
##     shell>  .  ./configure-java-env.sh
##
##  The following values are used for this script:
##   * JAVA_HOME - (required) location of the JDK or JRE
##   * Optionally, if set, the following are used (in order):
##      JVM - the path to (and including) the file, libjvm.so
##          By default, searches in JAVA_HOME using "find" for the JVM.
##      JVM_PATH - the full path to the directory containing libjvm.so
##          By default: dirname $JVM
##


libjvm=${libjvm:-libjvm.so}

if [ -z "$JAVA_HOME" ]; then
  echo "## Please set JAVA_HOME to the Java installation (JDK or JRE)."
else
  if [ -n "$JVM" ]; then
    # if given full path to JVM library
    echo "## using preset JVM=$JVM"
    export JVM_PATH=$(dirname ${JVM})
  elif [ -n "$JVM_PATH" ]; then
    echo "## using preset JVM_PATH=$JVM_PATH"
    export JVM=$JVM_PATH/$libjvm
  else
    # search for JVM, print out all matches, take first one found
    echo ""
    echo "## ========================================"
    echo "##  *** JVM unset ***"
    echo "##  ...searching for $libjvm in JAVA_HOME=$JAVA_HOME ......."
    libs=($(find ${JAVA_HOME}/  -name $libjvm -print ))
    export JVM=${libs[0]}
    #echo "## found: \"${#JVM[@]}\", strlen=${#JVM} : \"${JVM[@]}\""
    if [ ${#JVM} -ge 3 ]; then
      echo "##     JVMs found: ${libs[*]}"
      export JVM="$( ls -1 ${libs[*]} | sort -r | head -1 )"
      export JVM_PATH=$(dirname ${JVM})
    else
      echo "##     No JVMs found."
    fi
    echo "##  ========================================="
    echo
  fi

  # only change path & libpath if JVM_PATH was set
  if [ -n $JVM_PATH ]; then
    arch=$(uname)
    case "`uname`" in
     "AIX*" ) 
        export LIBPATH="${JVM_PATH}":"${LIBPATH}"
        export PATH="${JAVA_HOME}"/bin:"${PATH}"
        echo "  export LIBPATH=$LIBPATH"
        ;;
     "CYGWIN*" ) 
        export PATH="${JVM_PATH}":"${PATH}"
        echo "  export PATH=$PATH"
        ;;
      * ) 
        export LD_LIBRARY_PATH="${JVM_PATH}":"${LD_LIBRARY_PATH}"
        export PATH="${JAVA_HOME}"/bin:"${PATH}"
        echo "  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
        ;;
    esac
  else
    echo "## JVM not found, environment variables will not be set."
  fi
  
  echo "  JAVA_HOME=$JAVA_HOME"
  echo "  JVM_PATH=$JVM_PATH"
  echo 
  echo "##   Java version: $( java -version 2>&1 | head -1 )"
  echo "##   JVM version:  $(file $JVM_PATH/$libjvm)"
fi

echo "$0" | grep "java-env" > /dev/null && \
     printf "\n##  PLEASE NOTE! You must \"source\" this script to set these values, eg:\n##    . $0 \n\n"


