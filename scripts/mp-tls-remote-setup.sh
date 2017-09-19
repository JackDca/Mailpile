export PROFILE=dev
export ORGANIZATION=$HOSTNAME-$USER
export SERVERNAME=MP-$HOSTNAME-$USER-${PROFILE}
export REMOTENAME=$1
export LINKNAME=$SERVERNAME-$REMOTENAME
export FQDN=cyberspirit.dyndns.org

# The keys and certificates created here are intended to be used only to
# authenticate a specific remote to a specific user on a specific Mailpile host
# So the file names are based on both the remote and the host.
# Ideally the remote would generate its own private key which would never be
# communicated to any other device, by generating the private key on the
# host, communication during remote setup can be in one direction only which
# is more practical.

# The remote needs to have
#       the CA certificate tls/$SERVERNAME.pem  e.g. 821 char
#       the remote certificate tls/$LINKNAME.pem e.g. 1151 char
#       the remote private key tls/private/$LINKNAME.key e.g. 1704 char
#       total 3676 char.

# It would be better to create the private key and the CSR on the remote
# but typical remotes don't ahve that capability.

# Create a TLS client key in PEM format.

export OPENSSL_CONF=mp-tls-remote-setup.cfg

openssl genpkey -out tls/remotes-private/$LINKNAME.key \
        -algorithm RSA  -pkeyopt rsa_keygen_bits:2048

chmod 600 tls/remotes-private/$LINKNAME.key

# Create CSR in PEM format requesting the CA to sign the remote's certificate.

openssl req -new -key tls/remotes-private/$LINKNAME.key -out tls/$LINKNAME.csr

# Create a TLS client certificate signed by the CA in PEM format.
# The certificate is presented to the MP host by the remote.
openssl x509 -req -in tls/$LINKNAME.csr -out tls/remotes/$LINKNAME.pem \
        -CA tls/$SERVERNAME-CA.pem -CAkey tls/private/$SERVERNAME-CA.key \
        -extfile mp-tls-remote-setup.cfg -CAcreateserial -sha256 -days 365

openssl rehash tls/remotes 

# The remote needs the CA certificate, so pack it with its own certificate.
# Acer-S120 demands a password when importing a .p12 file
# even though -nodes -passout pass: is specified.

cat tls/$SERVERNAME-CA.pem tls/remotes/$LINKNAME.pem | \

    openssl pkcs12 -inkey tls/remotes-private/$LINKNAME.key \
                    -out tls/remotes-private/$LINKNAME.p12 \
                    -export -nodes -passout pass:$REMOTENAME \

rm tls/remotes-private/$LINKNAME.key
rm tls/$LINKNAME.csr

