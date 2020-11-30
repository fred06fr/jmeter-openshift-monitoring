#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
set -e

: ${GRAFANA_ROUTE?need GRAFANA_ROUTE set with the route to the Grafana instance that you got when installing the monitoring stack}

if ! oc projects 1>/dev/null; then
    echo "please login in the target cluster as admin before running this script"
    echo "this is the target cluster that you will want to monitor in grafana"
    exit -1
fi

PROMETHEUS_SERVER=$(oc cluster-info | sed -n 's@.*https://api\.\([^:]*\).*@\1@p')
PROMETHEUS_SERVER_SIMPLE_NAME=${PROMETHEUS_SERVER/.*/}
echo "Create Server datasource for the current server '$PROMETHEUS_SERVER' in grafana instance running in '$GRAFANA_ROUTE'"
PROMETHEUS_SERVER_URL="https://prometheus-k8s-openshift-monitoring.apps.$PROMETHEUS_SERVER"
PROMETHEUS_SERVER_TOKEN=$(oc sa get-token prometheus-k8s -n openshift-monitoring)
sed -e "s@\${PROMETHEUS_SERVER_SIMPLE_NAME}@${PROMETHEUS_SERVER_SIMPLE_NAME}@" \
    -e "s@\${PROMETHEUS_SERVER_URL}@${PROMETHEUS_SERVER_URL}@" \
    -e "s@\${PROMETHEUS_SERVER_TOKEN}@${PROMETHEUS_SERVER_TOKEN}@" \
    $SCRIPT_DIR/datasource_server_prometheus.json | curl "http://admin:password@$GRAFANA_ROUTE/api/datasources" -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary @-
echo


