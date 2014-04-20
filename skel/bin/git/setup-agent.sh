#!/bin/bash
#
# Useful ssh-agent windows script, since ssh-agent probably isn't running.
#
#############################################################################
# Alternatively, add this to .bashrc, setting the env vars as appropriate:
#
#  conf=$HOME/.ssh-agent.conf
#  key=$HOME/.ssh/id_rsa.git.myhost.mydomain.com
#
#  test -e $conf && . $conf >/dev/null
#
#  ps -p ${SSH_AGENT_PID} >/dev/null || {
#    ssh-agent >| $conf && . $conf >/dev/null
#      ssh-add $key
#  }
#############################################################################


SSH_ENV="$HOME/.ssh/environment"

start_agent() {
    echo "Initializing new SSH agent..."
    ssh-agent | sed 's/^echo/#echo/' > "$SSH_ENV"
    echo succeeded
    chmod 600 "$SSH_ENV"
    . "$SSH_ENV" > /dev/null
    ssh-add
}

test_identities() {
    # test whether standard identities have been added to the agent already
    ssh-add -l | grep "The agent has no identities" > /dev/null
    if [ $? -eq 0 ]; then
      ssh-add
      # $SSH_AUTH_SOCK broken so we start a new proper agent
      if [ $? -eq 2 ];then
        start_agent
      fi
    fi
}

# check for running ssh-agent with proper $SSH_AGENT_PID
if [ ${#SSH_AGENT_PID} -gt 0 ]; then
    ps -ef | grep "$SSH_AGENT_PID" | grep ssh-agent > /dev/null
    if [ $? -eq 0 ]; then
      test_identities
    fi
else # if $SSH_AGENT_PID not set, maybe load from $SSH_ENV
    [ -f "$SSH_ENV" ] && . "$SSH_ENV" > /dev/null
    if ps -ef | grep "${SSH_AGENT_PID:-xxxx}" | grep ssh-agent > /dev/null
    then
      test_identities
    else
      start_agent
    fi
fi

