#!/bin/bash

# Sets up an SSH daemon configuration to tunnel from a
# remote device to a specific Mailpile instance on a server
# using public key authentication.
# - Start it in the Mailpile home directory or set the directory with
#     export MAILPILE_HOME=[ ... ]
#     The Mailpile home directory path must not contain spaces.
# - The port number will be randomly selected in the range 20000-30000
#     or it may be specified on the command line.
# - If the setup script is run again in the same home directory it will
#     leave keys and port number unchanged unless their files are deleted.

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

if [ ! $MAILPILE_HOME == "" ]; then
    cd $MAILPILE_HOME
fi

if [ ! -f mailpile.rc ]; then
    echo
    echo Location of valid Mailpile data not specified.
    echo Use  export MAILPILE_HOME=[ ... ]
    echo
    exit
fi

# Extract the Mailpile home directory, host and port from mailpile.rc
HOMEDIR=`sed -n 's/\;\?homedir = \([^\n ]*\)[^\n]*/\1/p' mailpile.rc`
HTTP_HOST=`sed -n 's/\;\?http_host = \([^\n ]*\)[^\n]*/\1/p' $HOMEDIR/mailpile.rc`
HTTP_PORT=`sed -n 's/\;\?http_port = \([^\n ]*\)[^\n]*/\1/p' $HOMEDIR/mailpile.rc`

# Create a folder to be used by this SSH daemon instance only.
if [ ! -d $HOMEDIR/sshd ]; then
    mkdir $HOMEDIR/sshd
fi
cd $HOMEDIR/sshd

# If file port_external does not already exist, write to it an 
# external port number on which the SSH server will listen.
# If the user did not provide it, use a random port, 20001<port<29973.

if [ ! -f port_external ]; then
    if [ "$1" == "" ]; then
        echo $(( `od -vAn -N2 -tu < /dev/urandom` %9973+20001)) > port_external
    else      
        echo $1 > port_external
    fi
fi

echo
echo Setting up to accept SSH tunnels on port `cat port_external`
echo " "   to access Mailpile on port $HTTP_HOST:$HTTP_PORT.
echo

# Create host key files if they do not already exist -
# ssh_host_ed25519_key and ssh_host_rsa_key
if [ ! -f ssh_host_ed25519_key ]; then
    ssh-keygen -q -P "" -t ed25519 -f ssh_host_ed25519_key < /dev/null
fi
if [ ! -f ssh_host_rsa_key ]; then
    ssh-keygen -q -P "" -t rsa -b 4096 -f ssh_host_rsa_key < /dev/null
fi

# Create a file that a remote device can upload and use as "known_hosts".
echo "*,*.*.*.* `cat ssh_host_rsa_key.pub`" > remote_known_hosts

# Create empty file authorized_keys to hold the id keys of client devices
if [ ! -f authorized_keys ]; then
    touch authorized_keys
fi


# Create an sshd_config file in the data folder.
echo "
# Mailpile OpenSSH client configuration for Debian Jessie
# With this configuration file the command
# /usr/sbin/sshd -f $HOMEDIR/sshd/sshd_config
# starts an sshd daemon
#     - with ordinary user privileges,
#     - listening on a high port number specified in file port_external,
#     - only the current user is allowed to sign on,
#     - the config file requires public key client authentication.
# This is intended for Mailpile remote access, but could be used for other purposes.
# It should not interfere with a privileged sshd daemon listenting on port 22.

#
# The selection of most secure crypto methods is based on
# https://stribika.github.io/2015/01/04/secure-secure-shell.html

# Listen on this port.
Port `cat port_external`

# Restrict access to the user who set up this configuration.
AllowUsers $USER

# Restrict access to just one port on one local address
PermitOpen $HTTP_HOST:$HTTP_PORT

# Prevent shell login, agent forwarding, Protocol 1, DNS checking.
ForceCommand /bin/false
AllowAgentForwarding no
Protocol 2
UseDNS no

# Key exchange
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

# Host authentication
# The global host keys in /etc/ssh are not readable by an ordinary user.
HostKey $HOMEDIR/sshd/ssh_host_ed25519_key
HostKey $HOMEDIR/sshd/ssh_host_rsa_key

# Client authentication
PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
AllowAgentForwarding no
AuthorizedKeysFile $HOMEDIR/sshd/authorized_keys

# Symmetric ciphers
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# Message authentication codes
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-ripemd160-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,hmac-ripemd160,umac-128@openssh.com

# Save the PID to allow the server to be stopped.
PIDFile $HOMEDIR/sshd/sshd_pid

" > sshd_config
# End of sshd_config file.


