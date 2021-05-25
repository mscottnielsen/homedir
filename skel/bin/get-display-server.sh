#!/bin/bash

## Test to see if running wayland vs x11 (systemd).
## (Gets first session if more than one running.)

# return 'wayland' or 'x11'
if ! type loginctl 2>/dev/null 1>&2; then
    echo 'loginctl not found: unable to query systemd to check display server' 1>&2
    exit 2
fi

loginctl show-session  $(loginctl list-sessions  --no-legend | grep $USER | head -1 | cut -f1 -d' ') --property=Type --value
