#!/bin/sh

# All required packages in Debian 12.9:

apt-get install docker.io make git docker-compose apparmor influxdb-client

git clone git@github.com:laiti/ruuvistack.git /var/lib/ruuvistack