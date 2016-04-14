#!/bin/bash
# Starts an sshd daemon with ordinary user privileges for Mailpile access.

cd $MAILPILE_HOME/sshd

# Stop a daemon that is already running.
if [ -f sshd_pid ]; then
    kill `cat sshd_pid`
fi

/usr/sbin/sshd -f $MAILPILE_HOME/sshd/sshd_config
