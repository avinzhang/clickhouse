#!/bin/bash

#set -o nounset \
#    -o errexit \
#    -o verbose \
#    -o xtrace

# Cleanup files
rm -f *.crt *.csr *_creds *.jks *.srl *.key *.pem *.der *.p12

# Generate CA key
openssl req -new -x509 -keyout ca.key -out ca.crt -days 365 -subj '/CN=ca.example.com/O=EXAMPLE/L=MountainView/ST=Ca/C=US' -passin pass:clickhouse -passout pass:clickhouse

for i in keeper01 keeper02 keeper03 clickhouse01 clickhouse02 clickhouse03 clickhouse04 client
do
	echo "------------------------------- $i -------------------------------"
  
  # Create CSR for notes
  openssl req -newkey rsa:2048 -nodes -subj "/CN=$i.example.com/O=EXAMPLE/L=MountainView/ST=Ca/C=US" -keyout $i.key -out $i.csr

  #Sign CSR to create cert
  openssl x509 -req -CA ca.crt -CAkey ca.key -in $i.csr -out $i.crt -days 9999 -CAcreateserial -passin pass:clickhouse -extensions v3_req -extfile <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = $i
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = $i
DNS.2 = localhost
DNS.3 = default
DNS.4 = admin
EOF
)

done
