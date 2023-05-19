#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
set -e

: ${GRAFANA_ROUTE?need GRAFANA_ROUTE set with the route to the Grafana instance that you got when installing the monitoring stack, for example grafana-jmeter-monitoring.apps.yourserver.com}

if ! oc projects 1>/dev/null; then
    echo "please login in the target cluster as admin before running this script"
    echo "this is the target cluster that you will want to monitor in grafana"
    exit -1
fi

PROMETHEUS_SERVER=$(oc cluster-info | sed -n 's@.*https://\([^:]*\).*@\1@p')
PROMETHEUS_SERVER=${PROMETHEUS_SERVER/api./} # OC4
PROMETHEUS_SERVER_SIMPLE_NAME=${PROMETHEUS_SERVER/.*/}
echo "Create Server datasource for the current server '$PROMETHEUS_SERVER' in grafana instance running in '$GRAFANA_ROUTE'"
PROMETHEUS_SERVER_URL="https://prometheus-k8s-openshift-monitoring.apps.$PROMETHEUS_SERVER"
echo "Get token to access prometheus (may fail, expected)"
PROMETHEUS_SERVER_TOKEN=$(oc serviceaccounts get-token prometheus-k8s -n openshift-monitoring || true)
if [[ ("$PROMETHEUS_SERVER_TOKEN" == "") ]]; then
    echo "No token available, create token with label 'usage=jmeter-openshift-monitoring' for prometheus-sa service account"
    PROMETHEUS_SERVER_TOKEN=$(oc serviceaccounts new-token prometheus-k8s -n openshift-monitoring --labels usage=jmeter-openshift-monitoring)
fi
if [[ ("$PROMETHEUS_SERVER_TOKEN" == "") || ("$PROMETHEUS_SERVER" == "") ]]; then
    echo "Something is wrong, I have: PROMETHEUS_SERVER='$PROMETHEUS_SERVER' ; PROMETHEUS_SERVER_TOKEN='$PROMETHEUS_SERVER_TOKEN' which does not seem right. Sorry :-("
    exit -1
fi
sed -e "s@\${PROMETHEUS_SERVER_SIMPLE_NAME}@${PROMETHEUS_SERVER_SIMPLE_NAME}@" \
    -e "s@\${PROMETHEUS_SERVER_URL}@${PROMETHEUS_SERVER_URL}@" \
    -e "s@\${PROMETHEUS_SERVER_TOKEN}@${PROMETHEUS_SERVER_TOKEN}@" \
    $SCRIPT_DIR/datasource_server_prometheus.json | curl "http://admin:password@$GRAFANA_ROUTE/api/datasources" -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary @-
echo


