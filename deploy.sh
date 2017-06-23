#!/bin/bash
set -e

# Setup environment
OPENWHISK_ACTION_NAME=${OPENWHISK_ACTION_NAME:=$1}
OPENWHISK_ZIP=${2:-action.zip}
OPENWHISK_ACTION_DOCKER_IMAGE=${OPENWHISK_ACTION_DOCKER_IMAGE:=$3}
OPENWHISK_ACTION_DOCKER_IMAGE=${OPENWHISK_ACTION_DOCKER_IMAGE:="pritidesai8/nodejs6action-build"}
OPENWHISK_ACTION_NAME=${OPENWHISK_ACTION_NAME:="nodejs-build"}
OPENWHISK_HOST=${OPENWHISK_HOST:=`wsk property get --apihost | awk '{printf $4}'`}
OPENWHISK_AUTH=${OPENWHISK_AUTH:=`wsk property get --auth | awk '{printf $3}'`}

# Create action zip with source code
if [ ${OPENWHISK_ZIP} = "action.zip" ]; then
echo Creating ${OPENWHISK_ZIP} using src/*
pushd src > /dev/null
zip -r ../action.zip *
popd > /dev/null
fi

OPENWHISK_ACTION_SOURCE=`cat ${OPENWHISK_ZIP} | base64`

# Create action, binary=true using a zip
echo Deploying OpenWhisk action $OPENWHISK_ACTION_NAME with content of ${OPENWHISK_ZIP} using image $OPENWHISK_ACTION_DOCKER_IMAGE to host $OPENWHISK_HOST
curl -u $OPENWHISK_AUTH -d '{"namespace":"_","name":"'"$OPENWHISK_ACTION_NAME"'","exec":{"kind":"blackbox","code":"'"$OPENWHISK_ACTION_SOURCE"'","image":"'"$OPENWHISK_ACTION_DOCKER_IMAGE"'"}}' -X PUT -H "Content-Type: application/json" https://$OPENWHISK_HOST/api/v1/namespaces/_/actions/$OPENWHISK_ACTION_NAME?overwrite=true 1>/dev/null
#wsk action update ${OPENWHISK_ACTION_NAME} ${OPENWHISK_ZIP} --docker ${OPENWHISK_ACTION_DOCKER_IMAGE}
echo Action successfully deploy
echo Invoke action using:
echo "wsk action invoke $OPENWHISK_ACTION_NAME -r --param action_name <action name> --param action_data <action data>"
