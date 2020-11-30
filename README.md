# jmeter-openshift-monitoring
Simultaneous monitoring of client and server side performance with JMeter and Openshift

This project setups a monitoring stack in Openshift, that will allow to monitor simultaneously in real time:
- JMeter test results: this is the performance as seen from client side
- Your server workload running on Openshift: this is the performance as seen from server side

The stack installs Influxdb + Grafana + datasources and dashboards.

It receives:
- JMeter data through the default JMeter InfluxDB backend listener
- Server data through the prometheus stack of the monitored server(s)

Notice that you can install this stack on an Openshift cluster and monitor **another** Openshift cluster.

## Create monitoring stack in Openshift

- Login in the openshift cluster in which you want to host the monitoring stack:
`oc login ....`
- (optional) Customize the namespace (project) in which to install. Default is `jmeter-monitoring`
`export NAMESPACE=my-monitoring`
- (optional) Customize the storage class to use for InfluxDB and Graphana data. Persistent Volume Claims will be created using this storage class. Default is `nfs-client`
`export K8S_STORAGE_CLASS=my-storage-class`
- Run the installation script: 
`create_monitoring_stack.sh`

Reference articles and documents: 
- https://grafana.com/grafana/dashboards/5496 
  (original JMeter dashboard I derived mine from)
- https://medium.com/faun/openshift-leveraging-prometheus-cluster-metrics-in-your-own-grafana-7077fb0725ab
  (describe a cleaner way to handle openshift prometheus access, our script is more brutal...)

## Setup JMeter to send data in monitoring stack

- add a BackendListener using the InfluxDBBackendListenerClient in Jmeter script
- For InfluxDB url, use the monitoring stack InfluxDB server that you got in the output log of 'Create monitoring stack in Openshift'. Be sure to remove the 8086 port, as the Openshift route is on port 80
- Check all is right: 
  - run a JMeter test to fill some data in InfluxDB
  - check from monitoring stack that the data is there:
    `oc rsh deployment/influxdb influx -database 'jmeter' -execute 'select * from jmeter'`

Reference articles and documents: 
- https://jmeter.apache.org/usermanual/realtime-results.html

## (Optional) add other servers to monitor

- Set the GRAFANA_ROUTE to the monitoring stack grafana server that you got in the output log of 'Create monitoring stack in Openshift'
`export GRAFANA_ROUTE=grafana-jmeter-monitoring.apps.my-server.com`
- Login in the openshift cluster you want to monitor in the monitoring stack. Notice that the cluster of the monitoring stack is already added by default, so use this step if you want to monitor another one in addition.
`oc login ....`
- Run the add datasource script: 
`add_server_datasource.sh`

## Login in Grafana and see results

- connect to grafana with a browser using the monitoring stack grafana server that you got in the output log of 'Create monitoring stack in Openshift', for example: `http://grafana-jmeter-monitoring.apps.my-server.com`
- login with 'admin/password' to be admin
- Open dashboard 'JMeter+Openshift Dashboard'
- Enjoy :-)


