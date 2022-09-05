#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
set -e

: ${NAMESPACE:=jmeter-monitoring}
: ${INFLUXDB_IMAGE:=quay.io/influxdb/influxdb:1.6.4}
: ${GRAFANA_IMAGE:=grafana/grafana:7.3.3}
: ${K8S_STORAGE_CLASS:=nfs-client}

function createInfluxDB {
  echo "Create InfluxDB..."

  sed -e "s@\${K8S_STORAGE_CLASS}@${K8S_STORAGE_CLASS}@" $SCRIPT_DIR/influxdb_pvc.yaml | oc apply -f -
  sed -e "s@\${INFLUXDB_IMAGE}@${INFLUXDB_IMAGE}@" $SCRIPT_DIR/influxdb_deployment.yaml | oc apply -f -
  cat $SCRIPT_DIR/influxdb_service.yaml | oc apply -f -

  oc expose service influxdb || true
  INFLUXDB_ROUTE=$(oc get route influxdb -o jsonpath='{.spec.host}')
  echo "InfluxDB created at '${INFLUXDB_ROUTE}'"
}

function createGrafana {
  echo "Create Grafana..."

  sed -e "s@\${K8S_STORAGE_CLASS}@${K8S_STORAGE_CLASS}@" $SCRIPT_DIR/grafana_pvc.yaml | oc apply -f -
  sed -e "s@\${GRAFANA_IMAGE}@${GRAFANA_IMAGE}@" $SCRIPT_DIR/grafana_deployment.yaml | oc apply -f -
  cat $SCRIPT_DIR/grafana_config.yaml | oc apply -f -
  cat $SCRIPT_DIR/grafana_service.yaml | oc apply -f -

  oc expose service grafana || true
  GRAFANA_ROUTE=$(oc get route grafana -o jsonpath='{.spec.host}')
  echo "Grafana created at '${GRAFANA_ROUTE}'"
}

function createJMeterDatabaseInInfluxDB {
  echo "create JMeter database"
  oc rsh deployment/influxdb influx -execute 'CREATE DATABASE jmeter'
  oc rsh deployment/influxdb influx -execute 'show databases'
}

function createJMeterDatasourceInGrafana {
  echo "Create JMeter datasource"
  GRAFANA_ROUTE=$(oc get route grafana -o jsonpath='{.spec.host}')
  cat $SCRIPT_DIR/datasource_jmeter_influxdb.json | curl "http://admin:password@$GRAFANA_ROUTE/api/datasources" -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary @-
  echo
}

function createServerDatasourceInGrafana {
  export GRAFANA_ROUTE=$(oc get route grafana -o jsonpath='{.spec.host}')
  echo "Add a datasource for the cluster we are currently logged in (the one hosting the monitoring stack)"
  echo "you can add other servers using the add_server_datasource.sh script"
  bash $SCRIPT_DIR/add_server_datasource.sh
}

function createDashboardInGrafana {
  echo "Create/Update dashboard"
  GRAFANA_ROUTE=$(oc get route grafana -o jsonpath='{.spec.host}')
  cat "$SCRIPT_DIR/dashboard_client_and_server_jmeter.json" | jq '. * {overwrite: true, dashboard: {id: null}}' | curl "http://admin:password@$GRAFANA_ROUTE/api/dashboards/db" -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary @-
  cat "$SCRIPT_DIR/dashboard_comparison_jmeter.json" | jq '. * {overwrite: true, dashboard: {id: null}}' | curl "http://admin:password@$GRAFANA_ROUTE/api/dashboards/db" -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary @-
  echo
}

if ! oc projects 1>/dev/null; then
    echo "please login in cluster as admin before running this script"
    exit -1
fi

if [ "$1" == "clean" ]; then
    echo "Delete the monitoring stack in namespace '${NAMESPACE}'"
    oc delete project ${NAMESPACE}
    exit 0
fi

echo "Create/Update the monitoring stack in namespace '${NAMESPACE}'"
if ! oc project ${NAMESPACE} 2>/dev/null; then  
  oc new-project ${NAMESPACE} 
fi

createInfluxDB
createGrafana
createJMeterDatabaseInInfluxDB
createJMeterDatasourceInGrafana
createServerDatasourceInGrafana
createDashboardInGrafana


