# Ruuvi-docker
Docker-compose setup to set up a complete Ruuvitag monitoring setup with grafana. Consists of:

- [Eclipse Mosquitto™](https://mosquitto.org/) - An open source MQTT broker

- [Caddy](https://caddyserver.com/) - The Ultimate Server with Automatic HTTPS

- [Grafana](https://grafana.com) - The open and composable observability platform

- [InfluxDB](https://www.influxdata.com/) - Platform for time series data

- [RuuviBridge](https://github.com/Scrin/RuuviBridge) - As data bridge between Mosquitto and InfluxDB

...and of course Docker and Docker-compose.

## Setup guide

To bring the Docker containers up, simply populate .env file (example available at `examples/` dir) `docker-compose up` in the root directory.

- `.env`
- `ruuvibridge/config.yml`

Besides that, there's some manual work to do.

### Mosquitto

#### Encryption
If you wish to encrypt your traffic (highly recommended in public internet), you need to generate certificates. And deliver the client certificate to Ruuvi Gateway. In short the command is `make certs` but you might want to check the Makefile for details.

We could use Caddy as well to encrypt the traffic but I am not sure how well that works with WebSockets.

#### Users
Mosquitto users and passwords are defined in `mosquitto/config/passwd`. Passwords are hashed. To create the file with required gateway and ruuvibridge users, simply command `make users`.

### InfluxDB
To use InfluxDB in this setup, you need to create couple of things manually.

#### Create bucket and config

The `-r 1825d` sets the retention period for the data. Adjust this according to your free disk space and how frequently Ruuvitags send the data. I use the longlife firmware version in my tags to extend battery life and save disk space.

TODO: does docker-compose network rules need altering in order to connect to InfluxDB?

```
. ./.env
influx config create --config-name ruuvi --host-url http://localhost:8086 --token ${INFLUXDB_ADMIN_TOKEN} --active

influx bucket create -n ruuvi --org-id ${INFLUXDB_ORG} -r 1825d -t <token>
```


#### Create grafana and ruuvibridge users:
```
. ./.env
influx user create -n ruuvibridge -o ruuvi
influx user password -n ruuvibridge

influx user create -n grafana -o ruuvi
influx user password -n grafana
influx auth create --org ${INFLUXDB_ORG} --user grafana --read-authorizations --read-buckets
```

Configure ruuvibridge token to `ruuvibridge/config.yml` under the `influxdb_publisher`.


### Ruuvi Gateway

TODO

### Ruuvibridge

Ruuvibridge is configured with just `ruuvibridge/config.yml`, example config is in `examples/ruuvibridge.config.yml. This setup uses the recommended **MQTT listener** mode. As the traffic between Mosquitto, Ruuvibridge and InfluxDB happens between Docker containers, no SSL is required.

Change the `username` and `password` under `mqtt_listener` to the ones you created in Mosquitto. And configure your Ruuvitag BT addressess under `tag_names` and you should be good to go.

### Grafana queries

Once you've set up grafana, you can start querying Ruuvitag data if all works. Example query for single tag:

```
from(bucket: "ruuvi")
    |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
    |> filter(fn: (r) => r._measurement == "ruuvi_measurements" and r._field == "temperature" and r.name == "Sauna")
    |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: true)
    |> yield(name: "_time")
```

## Sources

- https://github.com/mchestr/Secure-MQTT-Docker
- https://cedalo.com/blog/mqtt-tls-configuration-guide/
- https://docs.influxdata.com/influxdb/v2/install/use-docker-compose/
- https://medium.com/@tomer.klein/docker-compose-and-mosquitto-mqtt-simplifying-broker-deployment-7aaf469c07ee
- https://github.com/sukesh-ak/setup-mosquitto-with-docker/tree/main
- https://github.com/Scrin/RuuviBridge