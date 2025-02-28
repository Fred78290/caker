# delete pem file
rm *.pem *.key *.srl *.csr *.conf

echo "subjectAltName=DNS:localhost,DNS:*,IP:127.0.0.1" > server.conf
echo "subjectAltName=DNS:localhost,IP:127.0.0.1" > client.conf

# Create CA private key and self-signed certificate
# adding -nodes to not encrypt the private key
openssl req -x509 -newkey rsa:4096 -nodes -days 365 \
	-keyout ca.key -out ca.pem \
	-subj "/C=FR/ST=EUROPA/L=PARIS/O=DEV/OU=TUTORIAL/CN=Caked Root CA/emailAddress=frederic.boltz@gmail.com"

echo "CA's self-signed certificate"
openssl x509 -in ca.pem -noout -text 

# Create Web Server private key and CSR
# adding -nodes to not encrypt the private key
openssl req -newkey rsa:4096 -nodes -keyout server.key \
	-out server.csr \
	-subj "/C=FR/ST=EUROPA/L=PARIS/O=DEV/OU=BLOG/CN=Cake Agent/emailAddress=frederic.boltz@gmail.com"

# Sign the Web Server Certificate Request (CSR)
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out server.pem -extfile server.conf

echo "Server's signed certificate"
openssl x509 -in server.pem -noout -text

# Verify certificate
echo "Verifying certificate"
openssl verify -CAfile ca.pem server.pem

# Generate client's private key and certificate signing request (CSR)
openssl req -newkey rsa:4096 -nodes -keyout client.key -out client.csr \
	-subj "/C=FR/ST=EUROPA/L=PARIS/O=DEV/OU=BLOG/CN=Caked client/emailAddress=frederic.boltz@gmail.com"

#  Sign the Client Certificate Request (CSR)
openssl x509 -req -in client.csr -days 365 -CA ca.pem -CAkey ca.key -CAcreateserial -out client.pem -extfile client.conf

echo "Client's signed certificate"
openssl x509 -in client.pem -noout -text