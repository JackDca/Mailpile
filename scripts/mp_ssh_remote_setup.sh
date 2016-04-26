#!/bin/bash

# Sets up a remote device so that it can access Mailpile
# through a secure SSH tunnel without using password authentication.
# - Start it in the Mailpile home directory or set the directory with
#     export MAILPILE_HOME=[ ... ]
#     The Mailpile home directory path must not contain spaces.

# Copyright 2016 Jack Dodds

# This file is part of Mailpile.

#    Mailpile is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as published
#    by the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.

#    Mailpile is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.

#    You should have received a copy of the GNU Affero General Public License
#    along with Mailpile.  If not, see <http://www.gnu.org/licenses/>.
    
#    Contact information, source code, and licencing information is available
#    at https://github.com/mailpile and https://github.com/JackDca/Mailpile

clear

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

if [ "$1" == "" ]; then
    echo
    echo Usage:    mp_ssh_remote_setup.sh  internet_address
    echo
    exit
fi

echo
echo This procedure sets up a remote Android device so that it can
echo securely access email on a Mailpile server via the Internet.
echo Copyright 2016 Jack Dodds - read source for details.
echo

# Extract the Mailpile home directory, host and port from mailpile.rc
HOMEDIR=`sed -n 's/\;\?homedir = \([^\n ]*\)[^\n]*/\1/p' mailpile.rc`
HTTP_HOST=`sed -n 's/\;\?http_host = \([^\n ]*\)[^\n]*/\1/p' mailpile.rc`
HTTP_PORT=`sed -n 's/\;\?http_port = \([^\n ]*\)[^\n]*/\1/p' mailpile.rc`

cd $HOMEDIR/sshd

# Get port number and address exposed by sshd to the Internet
EXT_HOST=$1
EXT_PORT=`cat port_external`

# Get port number and address used internally in the remote.
# Set here to same as local port on server - but this could be changed.
RMT_HOST=127.0.0.1
RMT_PORT=$HTTP_PORT

# Define port numbers for use during the setup only.
# This prevents problems with leftover TCP connections when a link to 
# Mailpile from the remote is established immediately after setup or
# if Mailpile is running during the setup.
# Of course we hope that these port numbers are not in use!
HTTP_SETUP_PORT=$(($HTTP_PORT+1))
RMT_SETUP_PORT=$(($HTTP_PORT+2))

# Stop the regular daemon (that does not allow password authentication).
if [ -f sshd_pid ]; then
    kill `cat sshd_pid`
fi

# Start the daemon with password authentication enabled.
# UsePAM=yes allows an unprivileged user to do password authentication.
/usr/sbin/sshd -f $HOMEDIR/sshd/sshd_config -o PermitOpen=$HTTP_HOST:$HTTP_SETUP_PORT -o PasswordAuthentication=yes -o UsePAM=yes
 
echo To do the setup:
echo
echo 1. Run Terminal Emulator on the remote.
read -rsp $'        Press <enter> on the server to continue...\n'
echo
echo 2. Key this command into the terminal window:
echo
echo    "  " ssh -f -N -R $HTTP_SETUP_PORT:$RMT_HOST:$RMT_SETUP_PORT -p $EXT_PORT $USER@$EXT_HOST \<enter\>
read -rsp $'        Press <enter> on the server to continue...\n'
echo
echo 3. At \"Are you sure you want to continue connecting \(yes/no\)?\"
echo    "  " respond \"yes\<enter\>\" if and only if the key fingerprint matches one listed below.
for HOST_KEY in ssh_host_*.pub ; do
    echo
    ssh-keygen -l -f $HOST_KEY | sed -n 's/[0123456789]* \([0123456789ABCDEabcedf:]*\) .*/   \1/p'
done
# ssh-keygen -l -f ssh_host_ed25519_key.pub | sed 
echo
echo    "  " \(The message \"Failed to add the host ... \" is normal - ignore it.\)
read -rsp $'        Press <enter> on the server to continue...\n'
echo
echo 4. At \"$USER@$EXT_HOST\'s password:\"
echo    "  " key in $USER\'s password for the server, then \<enter\>.
read -rsp $'        Press <enter> on the server to continue...\n'
echo
echo 5. Key this command into the terminal window:
echo
echo    "  " busybox nc -ll -p $RMT_SETUP_PORT -e "/system/xbin/ash" \<enter\>
read -rsp $'        Press <> on the server to continue...\n'
echo

echo
echo Setting up remote to access Mailpile server on port $HTTP_HOST:$HTTP_PORT
echo " "    via an SSH tunnel to Mailpile server port $EXT_HOST:`cat port_external`.
echo

#
# Get the version of OpenSSH that is running on the remote.
#
SSH_VERSION=`nc -v -i  2 $HTTP_HOST $HTTP_SETUP_PORT <<< "ssh -V 2>&1; exit"`
echo OpenSSH version on remote: $SSH_VERSION

# Get the PIDs of the processes started on the remote by the user above.
# Use netstat and grep to get the PIDs associated with the TCP ports we're using.
# Then use sed to pick the port numbers out of the netstat output.
# It would be much less painful to code this in Python.
nc -v -i  2 $HTTP_HOST $HTTP_SETUP_PORT <<< "
    busybox netstat -antp |grep $EXT_PORT;
    busybox netstat -antp |grep $RMT_SETUP_PORT;
    exit" > $HOMEDIR/sshd/netstat$EXT_PORT
export PIDS=`sed ' \
    s/ \([0123456789]*\)\/.*/>\1 /g ; \
    s/^[^$]*[>-]//g' \
    < $HOMEDIR/sshd/netstat$EXT_PORT`
    
echo Setup process numbers on remote: $PIDS

#
# Set up contents of files to be created on remote.
#
HOSTS="`cat remote_known_hosts`"
     
CONFIG="
# OpenSSH client configuration for Android 4.4.4
#
# The selection of most secure crypto methods is based on
# https://stribika.github.io/2015/01/04/secure-secure-shell.html

Host *
     # Specify external port and port forwarding
     Port $EXT_PORT
     LocalForward $RMT_PORT $HTTP_HOST:$HTTP_PORT

     # Mitigate known vulnerabilities in OpenSSH back to version 6.4.
     # See http://www.openssh.com/security.html
     ForwardX11 no
     ForwardX11Trusted no
     UseRoaming no

     # Shell does not have permissions for global known_hosts
     # so use local directory.
     UserKnownHostsFile  ssh-tunnel/known_hosts$EXT_PORT
     
     # Other settings
     CheckHostIP no
     EscapeChar none
     Protocol 2

     # Key exchange
     # KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
     # curve25519-sha256@libssh.org not supported in 6.4
     KexAlgorithms diffie-hellman-group-exchange-sha256

     # Client authentication
     # HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ssh-ed25519,ssh-rsa
     # ssh-ed25519 not supported in 6.4
     HostKeyAlgorithms ssh-rsa-cert-v01@openssh.com,ssh-rsa     
     PasswordAuthentication no
     ChallengeResponseAuthentication no
     PubkeyAuthentication yes
     IdentitiesOnly yes
     IdentityFile ssh-tunnel/id_rsa

     # Symmetric ciphers.
     # chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com not supported in 6.4
     Ciphers aes256-ctr,aes192-ctr,aes128-ctr

     # Message authentication codes
     MACs hmac-sha2-512,hmac-sha2-256,hmac-ripemd160,umac-128@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-ripemd160-etm@openssh.com,umac-128-etm@openssh.com
"

#
# Do the file transfers from remote to server.
#

nc -v -i  2 $HTTP_HOST $HTTP_SETUP_PORT <<< "cd ~ ; mkdir ssh-tunnel ; cd ssh-tunnel ; echo $? ; exit"
echo ... Configuration directory created on remote

nc -v -i  2 $HTTP_HOST $HTTP_SETUP_PORT <<< "cd ~/ssh-tunnel ; echo '$CONFIG' > config$EXT_PORT ; echo $? ; exit"
echo ... Configuration file transferred to remote

nc -v -i  2 $HTTP_HOST $HTTP_SETUP_PORT <<< "cd ~/ssh-tunnel ; echo '$HOSTS' > known_hosts$EXT_PORT ; echo $? ; exit"
echo ... Server id keys transferred to remote

#
# Generate id key(s) on the remote if they don't already exist, copy public
# keys to server, give them unique names, add to authorized_keys. This creates
# an rsa 4096 bit key.  Preferably it should also generate an ed25519 key i.e.
# ssh-keygen -q -t ed25519 -a 100 -P '' -f id_ed25519 < /dev/null
#

echo ... Generating remote id keys may take 1 - 2 minutes ......
nc -v -i 10 $HTTP_HOST $HTTP_SETUP_PORT <<< "
    cd ~/ssh-tunnel ;\
    if [ ! -f id_rsa ]; then\
        ssh-keygen -q -t rsa -b 4096 -a 100 -P '' -C $USER-\$HOSTNAME-\`busybox date -u +%Y-%m-%d-%H-%M \` -f id_rsa\
            < /dev/null ;\
    fi; echo \$? ; exit"
echo ... Remote id keys generated on remote

nc -v -i 10 $HTTP_HOST $HTTP_SETUP_PORT <<< "cd ~/ssh-tunnel ; cat id_rsa.pub ; exit" | sed -n 's/rsa/rsa/p' > $HOMEDIR/sshd/id_rsa.pub

KEY_NAME=`sed 's/ [^\n ]* /-/' < id_rsa.pub`
echo $KEY_NAME
mv id_rsa.pub id_rsa-$KEY_NAME.pub
echo ... Remote id keys transferred to server

cat $HOMEDIR/sshd/id_*.pub > $HOMEDIR/sshd/authorized_keys
echo ... Remote id keys added to authorized_keys

#
# On remote, create a background run script, and scripts to start and stop it.
#

START="#!/system/xbin/ash
cd ~
~/ssh-tunnel/run$EXT_PORT &
exit
"
nc -v -i  2 $HTTP_HOST $HTTP_SETUP_PORT <<< "cd ~/ssh-tunnel ; echo '$START' > start$EXT_PORT ; chmod 700 start$EXT_PORT ; exit"

RUN="#!/system/xbin/ash
cd ~
echo \$\$ > ~/ssh-tunnel/pid$EXT_PORT
while [ 1 ]; do
    ssh -N -F ~/ssh-tunnel/config$EXT_PORT $USER@$EXT_HOST
    busybox sleep 60
done
exit
"
nc -v -i  2 $HTTP_HOST $HTTP_SETUP_PORT <<< "cd ~/ssh-tunnel ; echo '$RUN' > run$EXT_PORT ; chmod 700 run$EXT_PORT ; exit"

STOP="#!/system/xbin/ash
cd ~
RUN_PID=\`busybox cat ~/ssh-tunnel/pid$EXT_PORT\`
ALL_PIDS=\`busybox ps -o pid,ppid | busybox grep \$RUN_PID\$\`
busybox kill \$ALL_PIDS
busybox sleep 10
busybox kill -9 \$ALL_PIDS
busybox rm ~/ssh-tunnel/pid$EXT_PORT
busybox sleep 10
exit
"
nc -v -i  2 $HTTP_HOST $HTTP_SETUP_PORT <<< "cd ~/ssh-tunnel ; echo '$STOP' > stop$EXT_PORT ; chmod 700 stop$EXT_PORT ; exit"

echo ... Start and stop scripts transferred to remote.

#
# Stop the setup processes on the remote.
#

nc -v -i 2 $HTTP_HOST $HTTP_SETUP_PORT <<< "busybox kill $PIDS \&; busybox sleep 10; busybox kill -9 $PIDS \&; exit"

#
# Stop daemon on server.
#
if [ -f sshd_pid ]; then
    kill `cat sshd_pid`
    sleep 10
    kill -9 `cat sshd_pid &`
fi

echo Done

exit


