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
- `~/.config/influxdb2/username` 
- `~/.config/influxdb2/password`
- `~/.config/influxdb2/token`

TODO: could infludxb files be in directory structure?

Besides that, there's some manual work to do.

### Mosquitto

#### Encryption
If you wish to encrypt your traffic (highly recommended in public internet), you need to generate certificates. And deliver the client certificate to Ruuvi Gateway.

In short the command is `make certs` but you might want to check the Makefile for details.

#### Users
Mosquitto users and passwords are defined in `mosquitto/passwd`. Passwords are hashed.

TODO: how to create passwd file

### InfluxDB
To use InfluxDB in this setup, you need to create couple of things manually.

#### Create bucket and config

Replace <token> with your InfluxDB token. The `-r 1825d` sets the retention period for the data. Adjust this according to your free disk space.

TODO: what is token?
TODO: does docker-compose network rules need altering in order to connect to InfluxDB?

```
influx config create --config-name ruugvi --host-url http://localhost:8086 --token <token> --active

influx bucket create -n ruuvi --org-id <organization-id> -r 1825d -t <token>
```


#### Create grafana and ruuvibridge users:
```
influx user create -n ruuvibridge -o ruuvi
influx user password -n ruuvibridge

influx user create -n grafana -o ruuvi
influx user password -n grafana
influx auth create --org ruuvi --user grafana --read-authorizations --read-buckets
```


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