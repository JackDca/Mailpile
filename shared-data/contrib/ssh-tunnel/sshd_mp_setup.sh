#!/bin/bash
# Sets up an SSH daemon configuration to tunnel from a
# remote device to a specific Mailpile instance on a server.

# Create a folder to be used by this SSH daemon instance only.
if [ ! -d $MAILPILE_HOME/sshd ]; then
    mkdir $MAILPILE_HOME/sshd
fi
cd $MAILPILE_HOME/sshd

# If file port_external does not already exist, write to it an 
# external port number on which the SSH server will listen.
# If the user did not provide it, use a random port, 20001<port<29363.

if [ ! -f port_external ]; then
    if [ "$1" == "" ]; then
        echo $(( `od -vAn -N2 -tu < /dev/urandom` /7+20001)) > port_external
    else      
        echo $1 > port_external
    fi
fi

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

# Extract the Mailpile host and port from mailpile.rc
HTTP_HOST=`sed -n 's/http_host = \([^\n ]*\)[^\n]*/\1/p' $MAILPILE_HOME/mailpile.rc`
HTTP_PORT=`sed -n 's/http_port = \([^\n ]*\)[^\n]*/\1/p' $MAILPILE_HOME/mailpile.rc`



# Create an sshd_config file in the data folder.
echo "
# Mailpile OpenSSH client configuration for Debian Jessie
# With this configuration file the command
# /usr/sbin/sshd -f $MAILPILE_HOME/sshd/sshd_config
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

# Prevent shell login
ForceCommand /bin/false

# Key exchange
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

# Host authentication
# The global host keys in /etc/ssh are not readable by an ordinary user.
HostKey $MAILPILE_HOME/sshd/ssh_host_ed25519_key
HostKey $MAILPILE_HOME/sshd/ssh_host_rsa_key

# Client authentication
PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
AllowAgentForwarding no
AuthorizedKeysFile $MAILPILE_HOME/sshd/authorized_keys


# Symmetric ciphers
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# Message authentication codes
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-ripemd160-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,hmac-ripemd160,umac-128@openssh.com

# Save the PID to allow the server to be stopped.
PIDFile $MAILPILE_HOME/sshd/sshd_pid

" > sshd_config
# End of sshd_config file.


