#!/bin/bash

clear

cd $MAILPILE_HOME/sshd

# Stop the regular daemon.
if [ -f sshd_pid ]; then
    kill `cat sshd_pid`
fi

# Start the daemon with password authentication enabled.
# UsePAM=yes allows an unprivileged user to do password authentication.
/usr/sbin/sshd -f $MAILPILE_HOME/sshd/sshd_config -o PasswordAuthentication=yes -o UsePAM=yes

# Get port number and address internally in the Mailpile machine.
HTTP_HOST=`sed -n 's/http_host = \([^\n ]*\)[^\n]*/\1/p' $MAILPILE_HOME/mailpile.rc`
HTTP_PORT=`sed -n 's/http_port = \([^\n ]*\)[^\n]*/\1/p' $MAILPILE_HOME/mailpile.rc`

# Get port number and address exposed by sshd to the Internet
EXT_HOST=192.168.1.50
EXT_PORT=`cat port_external`

# Get port number and address used internally in the device.
DEV_HOST=127.0.0.1
DEV_PORT=33333

echo $HTTP_HOST $HTTP_PORT $EXT_HOST $EXT_PORT $DEV_HOST $DEV_PORT
echo
echo This procedure sets up a remote Android device so that it can
echo securely access email on your Mailpile machine via the Internet.
echo
echo At the start of the procedure you will be asked to check that the
echo \"key fingerprint\" displayed by the device is one of these:
echo
ssh-keygen -l -f ssh_host_rsa_key.pub
echo
ssh-keygen -l -f ssh_host_ed25519_key.pub
echo
echo To do the setup, using the remote device:
echo
echo 1. Run Terminal Emulator.  Key this command into the terminal window:
echo
echo    "  " ssh -f -N -R $HTTP_PORT:$DEV_HOST:$DEV_PORT -p $EXT_PORT $USER@$EXT_HOST
echo
echo 2. At \"Are you sure you want to continue connecting \(yes/no\)?\"
echo    "  " respond \"yes\" if and only if the key fingerprint matches one listed above.
echo    "  " \(The message \"Failed to add the host ... \" is normal - ignore it.\)
echo
echo 3. At \"$USER@$EXT_HOST\'s password:\"
echo    "  " enter your password for the Mailpile machine.
echo
echo 4. Key this command into the terminal window:
echo
echo    "  " telnetd -l "/system/xbin/ash" -b $DEV_HOST:$DEV_PORT
echo
echo On the Mailpile machine:
echo   
read -rsp $'When this is done, press <enter> on the Mailpile machine to continue...\n'      
echo

#
# Get the version of OpenSSH that is running on the device.
#
SSH_VERSION=`nc -v -i  2 $HTTP_HOST $HTTP_PORT <<< "ssh -V ; exit"`

#
# Set up contents of files to be created on device.
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
     LocalForward 33333 $HTTP_HOST:$HTTP_PORT

     # Mitigate known vulnerabilities in OpenSSH back to version 6.4.
     # See http://www.openssh.com/security.html
     ForwardX11 no
     ForwardX11Trusted no
     UseRoaming no

     # Shell does not have permissions for global known_hosts
     # so use local directory.
     UserKnownHostsFile  ssh-tunnel/known_hosts$EXT_PORT

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
     IdentityFile ssh-tunnel/id_rsa

     # Symmetric ciphers.
     # chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com not supported in 6.4
     Ciphers aes256-ctr,aes192-ctr,aes128-ctr

     # Message authentication codes
     MACs hmac-sha2-512,hmac-sha2-256,hmac-ripemd160,umac-128@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-ripemd160-etm@openssh.com,umac-128-etm@openssh.com
"

echo -----------------------------
echo "$SSH_VERSION"
echo -----------------------------
echo "$CONFIG"
echo -----------------------------
echo "$HOSTS"
echo -----------------------------


read -rsp $'When this is done, press <enter> on the Mailpile machine to continue...\n'      
echo


#
# Do the file transfers.
#

nc -v -i  2 $HTTP_HOST $HTTP_PORT <<< "cd ~ ; mkdir ssh-tunnel ; cd ssh-tunnel ; echo $? ; exit"
echo ... Configuration directory created on remote device
nc -v -i  2 $HTTP_HOST $HTTP_PORT <<< "cd ~/ssh-tunnel ; echo '$CONFIG' > config$EXT_PORT ; echo $? ; exit"
echo ... Configuration file transferred to remote device
nc -v -i  2 $HTTP_HOST $HTTP_PORT <<< "cd ~/ssh-tunnel ; echo '$HOSTS' > known_hosts$EXT_PORT ; echo $? ; exit"
echo ... Host id keys transferred to remote device
nc -v -i 10 $HTTP_HOST $HTTP_PORT <<< "cd ~/ssh-tunnel ; rm id_rsa*;     ssh-keygen -q -t rsa -b 2048 -a 100 -P '' -f id_rsa     < /dev/null ; echo $? ; exit"
# nc -v -i 10 $HTTP_HOST $HTTP_PORT <<< "cd ~/ssh-tunnel ; rm id_ed25519*; ssh-keygen -q -t ed25519     -a 100 -P '' -f id_ed25519 < /dev/null ; echo $? ; exit"
echo ... Remote device id keys generated
nc -v -i 10 $HTTP_HOST $HTTP_PORT <<< "cd ~/ssh-tunnel ; cat id*.pub ; exit" | sed -n 's/rsa/rsa/p' > $MAILPILE_HOME/sshd/keys$EXT_PORT
echo ... Remote device id keys transferred to host
cat $MAILPILE_HOME/sshd/keys* > $MAILPILE_HOME/sshd/authorized_keys
echo ... Remote device id keys added to authorized_keys

START="#!/system/xbin/ash
cd ~
~/ssh-tunnel/run$EXT_PORT &
exit
"
nc -v -i  2 $HTTP_HOST $HTTP_PORT <<< "cd ~/ssh-tunnel ; echo '$START' > start$EXT_PORT ; chmod 700 start$EXT_PORT ; exit"

RUN="#!/system/xbin/ash
cd ~
echo \$\$ > ~/ssh-tunnel/pid$EXT_PORT
while [ 1 ]; do
    ssh -N -F ~/ssh-tunnel/config$EXT_PORT $USER@$EXT_HOST
    busybox sleep 60
done
exit
"
nc -v -i  2 $HTTP_HOST $HTTP_PORT <<< "cd ~/ssh-tunnel ; echo '$RUN' > run$EXT_PORT ; chmod 700 run$EXT_PORT ; exit"

STOP="#!/system/xbin/ash
cd ~
RUN_PID=\`busybox cat ~/ssh-tunnel/pid$EXT_PORT\`
ALL_PIDS=\`busybox ps -o pid,ppid | busybox grep \$RUN_PID\$`
busybox kill \$ALL_PIDS
busybox rm ~/ssh-tunnel/pid$EXT_PORT
busybox sleep 10
exit
"
nc -v -i  2 $HTTP_HOST $HTTP_PORT <<< "cd ~/ssh-tunnel ; echo '$STOP' > stop$EXT_PORT ; chmod 700 stop$EXT_PORT ; exit"

echo ... Start and stop scripts transferred to remote device.

exit


