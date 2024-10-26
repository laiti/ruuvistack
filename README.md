### InfluxDB

How to create bucket and config:
```
influx config create --config-name ruuvi --host-url http://localhost:8086 --token <token> --active

influx bucket create -n ruuvi --org-id <organization-id> -r 1825d -t <token>
```


How to create grafana and ruuvibridge users:
```
influx user create -n ruuvibridge -o ruuvi
influx user password -n ruuvibridge

influx user create -n grafana -o ruuvi
influx user password -n grafana
influx auth create --org ruuvi --user grafana --read-authorizations --read-buckets
```

### Grafana

Example query for single tag:

```
from(bucket: "ruuvi")
    |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
    |> filter(fn: (r) => r._measurement == "ruuvi_measurements" and r._field == "temperature" and r.name == "Sauna")
    |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: true)
    |> yield(name: "_time")
```


### Sources

https://github.com/mchestr/Secure-MQTT-Docker
https://cedalo.com/blog/mqtt-tls-configuration-guide/
https://docs.influxdata.com/influxdb/v2/install/use-docker-compose/
https://medium.com/@tomer.klein/docker-compose-and-mosquitto-mqtt-simplifying-broker-deployment-7aaf469c07ee
https://github.com/sukesh-ak/setup-mosquitto-with-docker/tree/main
https://github.com/Scrin/RuuviBridge