# Ruuvi-docker
Docker-compose setup to set up a complete Ruuvitag monitoring setup with grafana. Consists of:

- [Eclipse Mosquitto™](https://mosquitto.org/) - An open source MQTT broker

- [Caddy](https://caddyserver.com/) - The Ultimate Server with Automatic HTTPS

- [Grafana](https://grafana.com) - The open and composable observability platform

- [InfluxDB](https://www.influxdata.com/) - Platform for time series data

- [RuuviBridge](https://github.com/Scrin/RuuviBridge) - As data bridge between Mosquitto and InfluxDB

...and of course Docker and Docker-compose.

## Architecture in Mermaid graph format

![Preview](https://raw.githubusercontent.com/laiti/ruuvitag-grafana/main/doc/architecture.png)

```
flowchart TD
    A[Ruuvitags] -->|Bluetooth broadcast| B(Ruuvi Gateway)
    B -->|MQTT over TLS| C(Mosquitto)
    D(Ruuvibridge) -->|Subscribe via MQTT| C
    D -->|Write measurement data| E(InfluxDB)
    F(Grafana) -->|Read measurement data| E
    F -->|Temperature alert via HTTPS API| G(Telegram bot)
```

## Setup guide

### In short
To bring the Docker containers up:
1) Populate `.env` file (example available at `examples/` dir)
2) Create Mosquitto certs with `make certs` and users with `make users`
3) Create Ruuvibridge config, InfluxDB2 client config and Mosquitto passwd file with `make config`
4) Run `docker-compose up` in the root directory.

NOTE: This launches Grafana in the public net with `admin/admin` default credentials to the hostname you set in `.env`. Be sure to change the password before anyone else does it. If they do not work, refer to the [grafana-oss docker image documentation](https://hub.docker.com/r/grafana/grafana-oss).

Besides that, there's some manual work to do.

### Mosquitto

#### Encryption
If you wish to encrypt your traffic (highly recommended in public internet), you need to generate certificates. And deliver the client certificate to Ruuvi Gateway. In short the command is `make config` but you might want to check the Makefile for details.

We could use Caddy as well to encrypt the traffic but I am not sure how well that works with WebSockets.

#### Users
Mosquitto users and passwords are defined in `mosquitto/config/passwd`. Passwords are hashed. To create the file with required gateway and ruuvibridge users, simply command `make users`.

### InfluxDB
To use InfluxDB in, you need to create couple of things manually. This setup uses InfluxDB 2.

#### Connecting to InfluxDB

By default the InfluxDB is accessible only from Grafana and Ruuvibridge containers. Should you wish to run the InfluxDB command, you need to open the port. One way is to enable the `port:` statement from `compose.yaml` and restart container. You can create InfluxDB client config to your home directory (`~/.influxdbv2/configs`) with `make config`.

#### Create ruuvi bucket and config

The `-r 1825d` sets the retention period in days for the data. Adjust this according to your free disk space and how frequently Ruuvitags send the data. I use the longlife firmware version in my tags to extend battery life and save disk space.

```
. ./.env
influx config create --config-name ${INFLUXDB_BUCKET} --host-url http://localhost:8086 --token ${INFLUXDB_ADMIN_TOKEN} --active

influx bucket create -n ${INFLUXDB_BUCKET} --org-id ${INFLUXDB_ORGANIZATION} -r 1825d -t <token>
```


#### Create grafana and ruuvibridge users:
```
. ./.env
influx user create -n ruuvibridge --org ${INFLUXDB_ORGANIZATION}
influx user password -n ruuvibridge

influx user create -n grafana --org ${INFLUXDB_ORGANIZATION}
influx user password -n grafana
influx auth create --org ${INFLUXDB_ORGANIZATION} --user grafana --read-authorizations --read-buckets
```

Configure ruuvibridge token to `ruuvibridge/config.yml` under the `influxdb_publisher`.

### Ruuvi Gateway

TODO

### Ruuvibridge

Ruuvibridge is configured with just `ruuvibridge/config.yml`, example config is in `examples/ruuvibridge.config.yml`. This setup uses the recommended **MQTT listener** mode. As the traffic between Mosquitto, Ruuvibridge and InfluxDB happens between Docker containers, no SSL is required. You can also create a template from variables in `.env` via `Makefile` with command `make config`

Change the `username` and `password` under `mqtt_listener` to the ones you created in Mosquitto. And configure your Ruuvitag BT addressess under `tag_names` and you should be good to go.

### Grafana

Once you've set up Grafana, you can log in and start querying Ruuvitag data if all works. As stated above, the default login is `admin/admin`. Example query for single tag with offset (usually handy with humidity measurements):

```
from(bucket: "ruuvi")
    |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
    |> filter(fn: (r) => r._measurement == "ruuvi_measurements" and r._field == "temperature" and r.name == "Sauna")
    |> map(fn: (r) => ({r with _value: float(v: r._value) - 5.75 }))
    |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: true)
    |> yield(name: "_time")
```

Using the `r.name` requires that you've set up the `tag_names` in `ruuvibridge/config.yml` properly.

### Telegram
Grafana supports alert messages via Telegram out of the box. You can find some alert templates in the `doc/` directory.

## Sources

- https://github.com/mchestr/Secure-MQTT-Docker
- https://cedalo.com/blog/mqtt-tls-configuration-guide/
- https://docs.influxdata.com/influxdb/v2/install/use-docker-compose/
- https://medium.com/@tomer.klein/docker-compose-and-mosquitto-mqtt-simplifying-broker-deployment-7aaf469c07ee
- https://github.com/sukesh-ak/setup-mosquitto-with-docker/tree/main
- https://github.com/Scrin/RuuviBridge