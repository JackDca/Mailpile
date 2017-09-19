export PROFILE=dev
export ORGANIZATION=$HOSTNAME-$USER
export SERVERNAME=MP-$HOSTNAME-$USER-$PROFILE
export FQDN=cyberspirit.dyndns.org
export HOSTNAMELAN=Lucy2
export HTTP_PORT=33411
export HTTPS_PORT=29937

# Is it OK that the "exponent" is always 65537?
# Can -days and -[digest] be put in .cfg files?
# Can .cfg files be combined?

mkdir tls
mkdir tls/private
mkdir tls/remotes
mkdir tls/remotes-private

# Create a CA private key and a CA certificate in PEM format for the MP host.
# All MP host and remote certificates will be signed by this CA key.
# The certificate must be installed as a CA on each remote.

export OPENSSL_CONF=mp-ca-setup.cfg

openssl genpkey -out tls/private/$SERVERNAME-CA.key \
        -algorithm RSA  -pkeyopt rsa_keygen_bits:2048

chmod 600 tls/private/$SERVERNAME-CA.key

openssl req -key tls/private/$SERVERNAME-CA.key -out tls/$SERVERNAME-CA.pem \
        -x509 -new -nodes -sha384 -days 3640

# Create a TLS server key in PEM format.

export OPENSSL_CONF=mp-tls-server-setup.cfg

openssl genpkey -out tls/private/$SERVERNAME.key \
        -algorithm RSA  -pkeyopt rsa_keygen_bits:2048

chmod 600 tls/private/$SERVERNAME.key

# Create a TLS server certificate signed by the CA in PEM format.
# The certificate is presented to the remote by the MP host.

openssl req -new -key tls/private/$SERVERNAME.key -out tls/$SERVERNAME.csr

openssl x509 -req -in tls/$SERVERNAME.csr -out tls/$SERVERNAME.pem \
        -CA tls/$SERVERNAME-CA.pem -CAkey tls/private/$SERVERNAME-CA.key \
        -extfile mp-tls-server-setup.cfg -CAcreateserial -sha256 -days 365

rm tls/$SERVERNAME.csr

# Create config file for stunnel.

echo "

foreground = yes
pid        = $PWD/tls/stunnel-pid

[Mailpile$HTTPS_PORT]
accept  = $HTTPS_PORT
connect = $HTTP_PORT
CAfile  = tls/$SERVERNAME-CA.pem
cert    = tls/$SERVERNAME.pem
key     = tls/private/$SERVERNAME.key

verifyPeer = yes
CApath  = tls/remotes

" > tls/stunnel_config

# End of sshd_config file.





     

