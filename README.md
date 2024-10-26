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

