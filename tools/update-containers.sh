#!/bin/sh

set -e

docker-compose pull
docker-compose up --force-recreate --build -d
docker image prune -f 

df -h

echo "All OK"
exit 0
