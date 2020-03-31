#!/bin/bash

readonly SCRIPT_HOME=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
readonly SCRIPT_PARENT_DIR=$( cd ${SCRIPT_HOME} && cd .. && pwd )

set -ex
helm lint ${SCRIPT_PARENT_DIR}
helm template ${SCRIPT_PARENT_DIR} --set route.create=true
helm template ${SCRIPT_PARENT_DIR} --set ingress.create=true
helm template ${SCRIPT_PARENT_DIR} --set scc.create=true
helm template ${SCRIPT_PARENT_DIR} --set horizontalPodAutoscaler.create=true
set +ex