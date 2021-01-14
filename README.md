# Performance tests: simultaneous "live" reporting of client response time and server load with JMeter and Openshift

This project setups a monitoring stack in Openshift, that will allow to monitor simultaneously in real time:
- JMeter test results: this is the performance as seen from client side
- Your server workload running on Openshift: this is the load as seen from server side

The stack installs Influxdb + Grafana + datasources and dashboards.

You can find a more complete description in the associated article:
https://medium.com/@fpesquet/performance-tests-simultaneous-live-reporting-of-client-response-time-and-server-load-with-84add0ab0bb9

## Architecture

Our architecture is quite simple:
- JMeter exercise the server application, and reports performance results (response times, errors, etc.) in an InfluxDB database
- RedHat Openshift reports performance measurements of your server workload (cpu, memory, network usage) in its Prometheus instance
- Grafana displays a live report with both client-side measurements and related server-side measurements

Notice that you can install this stack on an Openshift cluster and monitor another Openshift cluster, or they can be the same.

## Create monitoring stack in Openshift

- Login as admin in the openshift cluster in which you want to host the monitoring stack:

`oc login ....`
- (optional) Customize the namespace (project) in which to install. Default is `jmeter-monitoring`

`export NAMESPACE=jmeter-monitoring`
- (optional) Customize the storage class to use for InfluxDB and Graphana data. Persistent Volume Claims will be created using this storage class. Default is `nfs-client`

`export K8S_STORAGE_CLASS=my-storage-class`
- Run the installation script: 

`create_monitoring_stack.sh`

_Background articles and documents for reference:_
- https://grafana.com/grafana/dashboards/5496 
  (original JMeter dashboard I derived mine from)

## (Optional) add other servers to monitor

- Set the GRAFANA_ROUTE to the monitoring stack grafana server that you got in the output log of 'Create monitoring stack in Openshift'

`export GRAFANA_ROUTE=grafana-jmeter-monitoring.apps.my-server.com`
- Login in the openshift cluster you want to monitor in the monitoring stack. Notice that the cluster of the monitoring stack is already added by default, so use this step if you want to monitor another one in addition.

`oc login ....`
- Run the add datasource script: 

`add_server_datasource.sh`

_Background articles and documents for reference:_
- https://medium.com/faun/openshift-leveraging-prometheus-cluster-metrics-in-your-own-grafana-7077fb0725ab
  (describe a cleaner way to handle openshift prometheus access, our script is more brutal...)
  
## Setup JMeter to send data in monitoring stack

- Add a BackendListener using the InfluxDBBackendListenerClient in Jmeter script
- For InfluxDB url, use the monitoring stack InfluxDB server that you got in the output log of 'Create monitoring stack in Openshift'. Be sure to remove the 8086 port, as the Openshift route is on port 80
- Add a parameter 'TAG_testid' with an id for your test as value: this is needed in the dashboard to differentiate between several tests that you might run in parallel
- Same for parameter 'application', use whatever name you want for your application under test.
- Check all is right: 
  - run a JMeter test to fill some data in InfluxDB
  - check from monitoring stack that the data is there:

    `oc rsh deployment/influxdb influx -database 'jmeter' -execute 'select * from jmeter'`

_Background articles and documents for reference:_
- https://jmeter.apache.org/usermanual/realtime-results.html

## Login in Grafana and see results

- connect to grafana with a browser using the monitoring stack grafana server that you got in the output log of 'Create monitoring stack in Openshift', for example: `http://grafana-jmeter-monitoring.apps.my-server.com`
- login with 'admin/password' to be admin
- Open dashboard 'JMeter+Openshift Dashboard'
- Enjoy :-)


