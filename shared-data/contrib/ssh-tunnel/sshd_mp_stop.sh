#!/bin/bash
# Stops a Mailpile sshd daemon
# sshd deletes the sshd_pid file hen it stops.

cd $MAILPILE_HOME/sshd

if [ -f sshd_pid ]; then
    kill `cat sshd_pid`
fi
