#!/bin/bash
# Starts an sshd daemon with ordinary user privileges for Mailpile access.

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

# Stop a daemon that is already running.
if [ -f sshd_pid ]; then
    kill `cat sshd_pid`
fi

/usr/sbin/sshd -f sshd_config
