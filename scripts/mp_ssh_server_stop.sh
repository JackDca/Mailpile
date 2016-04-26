#!/bin/bash
# Stops a Mailpile sshd daemon
# sshd deletes the sshd_pid file hen it stops.

if [ ! $MAILPILE_HOME == "" ]; then
    cd $MAILPILE_HOME
fi

if [ ! -f mailpile.rc ]; then
    echo
    echo Location of valid Mailpile data not specified.
    echo Use:    export MAILPILE_HOME=[ ... ]
    echo
    exit
fi

cd sshd

if [ -f sshd_pid ]; then
    export SSHD_PID=`cat sshd_pid`
    export PIDS=`ps --no-headers -e -o pid,ppid | grep $SSHD_PID`
    echo $PIDS
    kill $PIDS
    sleep 10
    kill -9 $PIDS
fi
