#!/bin/bash

grep "\<debug\>" --color=always -rn lib \
\
    | grep -v MessageSystem \
    | grep -Ev '^[^ ]*:(\[[0-9;]*[mK])*[ ]*#' \
    | grep -v CLISH_DEBUG \
    | grep -v "[^;]$" \
    | less -eS +G
