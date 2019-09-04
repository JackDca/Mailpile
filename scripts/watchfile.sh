#!/bin/bash
# Watch a file's directory entry, log any changes.

FILEPATH=$1
LOGFILEPATH=$1.log
PREVIOUS=""

while :
do
    TIME="`date --iso-8601=seconds`"
    ENTRY="`ls -l --time-style=full-iso $FILEPATH 2>&1`"
    if [ "$ENTRY" != "$PREVIOUS" ]; then   
        echo "$TIME $ENTRY"
        echo "$TIME $ENTRY" &>> $LOGFILEPATH
    fi
    PREVIOUS=$ENTRY
    sleep 1
done