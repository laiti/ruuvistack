CERT_DIR:=mosquitto/config/certs
CERTS:=\
	$(MOUNTED_VOLUMES_TOP)/config/certs/ca/ca.crt \
	$(MOUNTED_VOLUMES_TOP)/config/certs/broker/broker.key \
	$(MOUNTED_VOLUMES_TOP)/config/certs/broker/broker.crt
CLIENT_CERTS:=\
	$(MOUNTED_VOLUMES_TOP)/config/certs/clients/ruuvigw

include $(PWD)/.env

.PHONY: certs
certs: $(CERTS) $(CLIENT_CERTS)

.PHONY: distclean # This cleans everything
distclean:
	rm -f *~
	rm -f mosquitto/config/certs/ca/*.crt mosquitto/config/certs/ca/*.key mosquitto/config/certs/ca/*.srl
	rm -f mosquitto/config/certs/broker/*.crt mosquitto/config/certs/broker/*.key mosquitto/config/certs/broker/*.csr
	rm -f mosquitto/config/certs/clients/*.crt mosquitto/config/certs/clients/*.key mosquitto/config/certs/clients/*.csr

# ==================================================================
# CERTIFICATES:

# This section creates three groups of ceritficates: one for the
# certificate authority (CA), one for the MQTT broker, and then one
# for each MQTT client.  The subjects for the CA and broker are
# defined in this makefile and may be overriden on the command line.
# See mqtt/certs/clients/README.txt for instructions for creating new
# clients.

# =========================
# variables

# Materials that go in the subject
IP:=$(MOSQUITTO_HOSTNAME)
ORGANIZATION_NAME:=Laiti Inc.
# NOTE: the Common Name (CN) for the CA must be different than that of the broker and the client
SUBJECT_ROOT_CA:=$(MOSQUITTO_ROOT_CA_SUBJECT)
SUBJECT_SERVER:=$(MOSQUITTO_SERVER_SUBJECT)
SUBJECT_CLIENT:=/C=FI/ST=Pirkanmaa/L=Tampere/O=$(ORGANIZATION_NAME)/OU=Client/CN=$(IP)

# =========================
# CERTIFICATE AUTHROITY

# KEY

# Note: if you want a password protected key, then add the '-des3'
# command line option to the 'openssl genrsa' command below.
mosquitto/config/certs/ca/ca.key: ## Create Root Key
	openssl genrsa -des3 -out $@ 4096

# CERTIFICATE

# Here we used our root key to create the root certificate that needs
# to be distributed in all the computers that have to trust us.
mosquitto/config/certs/ca/ca.crt: mosquitto/config/certs/ca/ca.key ## Create and self sign the Root Certificate
	openssl req -x509 -new -nodes -key $< -sha256 -days 1850 -out $@ -subj "$(MOSQUITTO_ROOT_CA_SUBJECT)"

# =========================
# MQTT BROKER

# KEY
mosquitto/config/certs/broker/broker.key: ## Create the server certificate key
	openssl genrsa -out $@ 2048

# CERTIFICATE SIGNING REQUEST (CSR)

# The certificate signing request is where you specify the details for
# the certificate you want to generate. This request will be
# processed by the owner of the Root key (you in this case since you
# created it earlier) to generate the certificate.
mosquitto/config/certs/broker/broker.csr: mosquitto/config/certs/broker/broker.key ## Create the server certificate signing request (csr)
	openssl req -new -key $< -out $@ -subj "$(MOSQUITTO_SERVER_SUBJECT)" || openssl req -in $@ -noout -text

# CERTIFICATE
mosquitto/config/certs/broker/broker.crt: mosquitto/config/certs/broker/broker.csr mosquitto/config/certs/ca/ca.crt mosquitto/config/certs/ca/ca.key ## Generate the certificate using the `server` csr and key along with the CA Root key
	openssl x509 -req -in mosquitto/config/certs/broker/broker.csr -CA mosquitto/config/certs/ca/ca.crt -CAkey mosquitto/config/certs/ca/ca.key -CAcreateserial -out $@ -days 1850 -sha256 || openssl x509 -in $@ -text -noout

# =========================
# MQTT CLIENTS

# generic rule to generate the client certificate from a text file.
mosquitto/config/certs/clients/ruuvigw:
	echo "Creating Client: $@" ; \
	openssl genrsa -out $@.key ; \
	openssl req -new -key $@.key -out $@.csr -subj "$(MOSQUITTO_CLIENT_SUBJECT)" || openssl req -in $@.csr -noout -text ; \
	openssl x509 -req -CA mosquitto/config/certs/ca/ca.crt -CAkey mosquitto/config/certs/ca/ca.key -CAcreateserial -in $@.csr -out $@.crt || openssl x509 -in $@.crt -text -noout