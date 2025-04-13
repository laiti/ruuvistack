CERT_DIR:=mosquitto/config/certs

CERTS:=\
	$(CERT_DIR)/ca/ca.crt \
	$(CERT_DIR)/broker/broker.key \
	$(CERT_DIR)/broker/broker.crt

CLIENT_CERTS:=\
	$(CERT_DIR)/clients/ruuvigw

include $(PWD)/.env

### GENERAL COMMANDS
.PHONY: all # Default rule
all: certs config docker

.PHONY: certs
certs: $(CERTS) $(CLIENT_CERTS)

# This cleans everything, use with caution. Ensure that CERT_DIR is set.
.PHONY: clean
distclean:
	rm -f *~
	rm -f $(CERT_DIR)/ca/*.crt $(CERT_DIR)/ca/*.key $(CERT_DIR)/ca/*.srl
	rm -f $(CERT_DIR)/broker/*.crt $(CERT_DIR)/broker/*.key $(CERT_DIR)/broker/*.csr
	rm -f $(CERT_DIR)/clients/*.crt $(CERT_DIR)/clients/*.key $(CERT_DIR)/clients/*.csr
	rm -f mosquitto/config/passwd ruuvibridge/config.yml ~/.influxdbv2/configs

.PHONY: config
config: mosquitto/config/passwd ruuvibridge/config.yml ~/.influxdbv2/configs grafana/provisioning/datasources/influxdbv2.yml

.PHONY: docker
docker:
	docker-compose up -d

.PHONY: docker-update
docker-update:
	docker-compose pull
	docker-compose up --force-recreate --build -d
	docker image prune -f
	df -h

### CONFIGURATIONS

# For creating Mosquitto users we need to access the mosquitto_passwd tool which is only inside the container.
mosquitto/config/passwd:
	touch $@
	chmod 0600 $@
	docker run -it --rm -v $(shell pwd)/mosquitto/config:/mosquitto/config eclipse-mosquitto mosquitto_passwd -b $@ $(MOSQUITTO_GATEWAY_USER) $(MOSQUITTO_GATEWAY_PASSWORD)
	docker run -it --rm -v $(shell pwd)/mosquitto/config:/mosquitto/config eclipse-mosquitto mosquitto_passwd -b $@ $(MOSQUITTO_RUUVIBRIDGE_USER) $(MOSQUITTO_RUUVIBRIDGE_PASSWORD)

ruuvibridge/config.yml:
	cat examples/ruuvibridge.config.yml|sed "s/MOSQUITTO_RUUVIBRIDGE_PASSWORD/${MOSQUITTO_RUUVIBRIDGE_PASSWORD}/;s/MOSQUITTO_RUUVIBRIDGE_USER/${MOSQUITTO_RUUVIBRIDGE_USER}/;s/INFLUXDB_ORGANIZATION/${INFLUXDB_ORGANIZATION}/" > $@
	chown root:1337 $@
	chmod 0640 $@

~/.influxdbv2/configs:
	install -m 0700 -d ~/.influxdbv2/
	cat examples/influxdbv2-config|sed "s/INFLUXDB_TOKEN/${INFLUXDB_ADMIN_TOKEN}/" > $@
	chmod 0600 $@

grafana/provisioning/datasources/influxdbv2.yml:
	install -m 0644 -d grafana/provisioning/datasources/
	cat examples/influxdbv2.yml|sed "s/INFLUXDB_ORGANIZATION/${INFLUXDB_ORGANIZATION}/;s/INFLUXDB_BUCKET/${INFLUXDB_BUCKET}/;s/INFLUXDB_GRAFANA_USER_TOKEN/${INFLUXDB_GRAFANA_USER_TOKEN}/" > $@
	chown root:472 grafana/provisioning/datasources/influxdbv2.yml
	chmod 0640 grafana/provisioning/datasources/influxdbv2.yml

### CERTIFICATES

# ROOT CA KEY
# To remove password protetction, remove '-des3'
mosquitto/config/certs/ca/ca.key:
	openssl genrsa $(MOSQUITTO_ROOT_CA_KEY_OPTIONS) -out $@ 4096

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