CERT_DIR:=mosquitto/config/certs

CERTS:=\
	$(CERT_DIR)/ca/ca.crt \
	$(CERT_DIR)/broker/broker.key \
	$(CERT_DIR)/broker/broker.crt

CLIENT_CERTS:=\
	$(CERT_DIR)/clients/ruuvigw

include $(PWD)/.env

.PHONY: certs
certs: $(CERTS) $(CLIENT_CERTS)

# This cleans everything, use with caution. Ensure that CERT_DIR is set.
.PHONY: distclean 
distclean:
	rm -f *~
	rm -f $(CERT_DIR)/ca/*.crt $(CERT_DIR)/ca/*.key $(CERT_DIR)/ca/*.srl
	rm -f $(CERT_DIR)/broker/*.crt $(CERT_DIR)/broker/*.key $(CERT_DIR)/broker/*.csr
	rm -f $(CERT_DIR)/clients/*.crt $(CERT_DIR)/clients/*.key $(CERT_DIR)/clients/*.csr

# For creating Mosquitto users we need to access the mosquitto_passwd tool which is only inside the container.
.PHONY: users
users:
	touch mosquitto/config/passwd
	chmod 0700 mosquitto/config/passwd
	docker run -it --rm -v $(shell pwd)/mosquitto/config:/mosquitto/config eclipse-mosquitto mosquitto_passwd -b /mosquitto/config/passwd $(MOSQUITTO_GATEWAY_USER) $(MOSQUITTO_GATEWAY_PASSWORD)
	docker run -it --rm -v $(shell pwd)/mosquitto/config:/mosquitto/config eclipse-mosquitto mosquitto_passwd -b /mosquitto/config/passwd $(MOSQUITTO_RUUVIBRIDGE_USER) $(MOSQUITTO_RUUVIBRIDGE_PASSWORD)

# TODO: check if this file exists and do not overwrite it.
.PHONY: ruuvibridge
ruuvibridge:
	cat examples/ruuvibridge.config.yml|sed "s/MOSQUITTO_RUUVIBRIDGE_PASSWORD/${MOSQUITTO_RUUVIBRIDGE_PASSWORD}/" > ruuvibridge/config.yml
	chmod 0600 ruuvibridge/config.yml

.PHONY: influx-config
influx-config:
	install -m 0700 -d ~/.influxdbv2/
	cat examples/influxdbv2-config|sed "s/INFLUXDB2_TOKEN/${INFLUXDB_ADMIN_TOKEN}/" > ~/.influxdbv2/configs
	chmod 0600 ~/.influxdbv2/configs

# ROOT CA KEY
# To remove password protetction, remove '-des3'
mosquitto/config/certs/ca/ca.key:
	openssl genrsa -des3 -out $@ 4096

# ROOT CA CERTIFICATE AND SELF SIGN
mosquitto/config/certs/ca/ca.crt: mosquitto/config/certs/ca/ca.key
	openssl req -x509 -new -nodes -key $< -sha256 -days 1850 -out $@ -subj "$(MOSQUITTO_ROOT_CA_SUBJECT)"

# BROKER KEY
mosquitto/config/certs/broker/broker.key:
	openssl genrsa -out $@ 2048

# CERTIFICATE SIGNING REQUEST (CSR) FOR BROKER
mosquitto/config/certs/broker/broker.csr: mosquitto/config/certs/broker/broker.key
	openssl req -new -key $< -out $@ -subj "$(MOSQUITTO_BROKER_SUBJECT)" || openssl req -in $@ -noout -text

# BROKER CERTIFICATE
# Created using CSR and CA Root key
mosquitto/config/certs/broker/broker.crt: mosquitto/config/certs/broker/broker.csr mosquitto/config/certs/ca/ca.crt mosquitto/config/certs/ca/ca.key 
	openssl x509 -req -in mosquitto/config/certs/broker/broker.csr -CA mosquitto/config/certs/ca/ca.crt -CAkey mosquitto/config/certs/ca/ca.key -CAcreateserial -out $@ -days 1850 -sha256 || openssl x509 -in $@ -text -noout

# CLIENT CERTIFICATE
mosquitto/config/certs/clients/ruuvigw:
	echo "Creating Client: $@" ; \
	openssl genrsa -out $@.key ; \
	openssl req -new -key $@.key -out $@.csr -subj "$(MOSQUITTO_CLIENT_SUBJECT)" || openssl req -in $@.csr -noout -text ; \
	openssl x509 -req -CA mosquitto/config/certs/ca/ca.crt -CAkey mosquitto/config/certs/ca/ca.key -CAcreateserial -in $@.csr -out $@.crt || openssl x509 -in $@.crt -text -noout