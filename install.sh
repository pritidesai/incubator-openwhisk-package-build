#!/bin/bash
#
# use the command line interface to install standard actions deployed
# automatically
#
# To run this command
# ./install.sh <authkey> <edgehost> <apihost> <workers>

set -e
set -x

: ${OPENWHISK_HOME:?"OPENWHISK_HOME must be set and non-empty"}
WSK_CLI="$OPENWHISK_HOME/bin/wsk"

if [ $# -eq 0 ]
then
echo "Usage: ./install.sh <authkey> <edgehost> <apihost>"
fi

AUTH="$1"
EDGEHOST="$2"
APIHOST="$3"

# If the auth key file exists, read the key in the file. Otherwise, take the
# first argument as the key itself.
if [ -f "$AUTH" ]; then
    AUTH=`cat $AUTH`
fi

# Make sure that the EDGEHOST is not empty.
: ${EDGEHOST:?"EDGEHOST must be set and non-empty"}

# Make sure that the APIHOST is not empty.
: ${APIHOST:?"APIHOST must be set and non-empty"}

export PACKAGE_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export WSK_CONFIG_FILE= # override local property file to avoid namespace clashes

export NAMESPACE="whisk.system"

echo Installing build package ...

# Creating build package using wsk CLI
# $WSK_CLI -i --apihost "$EDGEHOST" package update --auth "$AUTH" --shared yes build \
#     -a description 'Utility to package and deploy third party modules' \

curl -sD - -o /dev/null -k -u $AUTH -X PUT https://$APIHOST/api/v1/namespaces/$NAMESPACE/packages/build?overwrite=true \
     -H "Content-Type: application/json" \
     -d @- << 'EOF'
{
   "namespace":"$NAMESPACE",
   "name":"build",
   "publish":true,
   "annotations":[{
       "key":"description","value":"Utility to package and deploy third party modules"
   }]
}
EOF

# create action zip with source code - action.zip
echo Creating action.zip using actions/nodejs
pushd $PACKAGE_HOME/actions/nodejs > /dev/null
zip -r action.zip *
popd > /dev/null

NODEJS_ACTION_SOURCE=`cat $PACKAGE_HOME/actions/nodejs/action.zip | base64`

echo Deploying build/nodejs action ...

nodejs_request_body=$(cat <<EOF
{
    "namespace":"$NAMESPACE",
    "name":"build/nodejs",
    "exec":{
        "kind":"blackbox",
        "code":"$NODEJS_ACTION_SOURCE",
        "image":"pritidesai8/nodejs6action-build"
    },
    "annotations":[
        {
            "key":"description",
            "value":"Creates an action that allows you to package and deploy third party modules on OpenWhisk"
        },
        {
            "key":"parameters",
            "value":[
                {
                    "name":"action_name",
                    "required":true,
                    "bindTime":true,
                    "description":"Name of the action to be created"
                },
                {
                    "name":"action_data",
                    "required":true,
                    "bindTime":true,
                    "description":"Base64 encoded compressed data containing action files and packaging file, must have index.js and can have pacakge.json, for example, run zip -rq action.zip action_files/ and run this action with cat action.zip | base64"
                }
            ]
        },
        {
            "key":"sampleInput",
            "value":{
                "action_name":"my-action",
                "action_data":"cat action.zip | base64"
            }
        }
    ]
}
EOF
)

# Create nodejs action using wsk CLI
#$WSK_CLI -i --apihost "$EDGEHOST" --auth "$AUTH" action update build/nodejs "$NODEJS_ACTION_SOURCE" \
#     --docker "pritidesai8/nodejs6action-build"
curl -sD - -o /dev/null -k -u $AUTH -X PUT https://$APIHOST/api/v1/namespaces/$NAMESPACE/actions/build/nodejs?overwrite=true \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -d "$nodejs_request_body" 1>/dev/null 

# create action zip with source code - action.zip
echo Creating action.zip using actions/nodejs
if [ -f $PACKAGE_HOME/actions/python/action.zip ] ; then
    rm $PACKAGE_HOME/actions/python/action.zip
fi 
pushd $PACKAGE_HOME/actions/python > /dev/null
zip -r action.zip *
popd > /dev/null

PYTHON_ACTION_SOURCE=`cat $PACKAGE_HOME/actions/python/action.zip | base64`

echo Deploying build/python2 action ...

python_request_body=$(cat <<EOF
{
    "namespace":"$NAMESPACE",
    "name":"build/python2",
    "exec":{
        "kind":"python:2",
        "code":"$PYTHON_ACTION_SOURCE",
        "image":"openwhisk/python2action"
    },
    "annotations":[
        {
            "key":"description",
            "value":"Creates an action that allows you to package and deploy third party modules on OpenWhisk"
        },
        {
            "key":"parameters",
            "value":[
                {
                    "name":"action_name",
                    "required":true,
                    "bindTime":true,
                    "description":"Name of the action to be created"
                },
                {
                    "name":"action_data",
                    "required":true,
                    "bindTime":true,
                    "description":"Base64 encoded compressed data containing action files and requirements file, must have requirements.txt and can have __main__.py or any other action file with action_main parameter set to action entry point, for example, run zip -rq action.zip action_files/ and run this action with cat action.zip | base64"
                },
                {
                    "name":"action_main",
                    "required":false,
                    "bindTime":true,
                    "description":"Name of the function which is entry point in the action python file"
                },
                {
                    "name":"action_namespace",
                    "required":false,
                    "bindTime":true,
                    "description":"namespace where the action needs to be created"
                }
            ]
        },
        {
            "key":"sampleInput",
            "value":{
                "action_name":"my-action",
                "action_data":"cat action.zip | base64",
                "action_main":"jokes",
                "action_namespace":"dev"
            }
        }
    ]
}
EOF
)

# Create python action using wsk CLI
#$WSK_CLI -i --apihost "$EDGEHOST" --auth "$AUTH" action update build/python2 "$PYTHON_ACTION_SOURCE" \
#     --docker "openwhisk/python2action"
curl -sD - -o /dev/null -k -u $AUTH -X PUT https://$APIHOST/api/v1/namespaces/$NAMESPACE/actions/build/python2?overwrite=true \
     -H "Content-Type: application/json" \
     -d "$python_request_body" 1>/dev/null 

# create action zip with source code - action.zip
echo Creating action.zip using actions/nodejs
if [ -f $PACKAGE_HOME/actions/python/action.zip ] ; then
    rm $PACKAGE_HOME/actions/python/action.zip
fi 
pushd $PACKAGE_HOME/actions/python > /dev/null
zip -r action.zip *
popd > /dev/null

PYTHON_ACTION_SOURCE=`cat $PACKAGE_HOME/actions/python/action.zip | base64`

echo Deploying build/python3 action ...

python_request_body=$(cat <<EOF
{
    "namespace":"$NAMESPACE",
    "name":"build/python3",
    "exec":{
        "kind":"python:3",
        "code":"$PYTHON_ACTION_SOURCE",
        "image":"openwhisk/python3action"
    },
    "annotations":[
        {
            "key":"description",
            "value":"Creates an action that allows you to package and deploy third party modules on OpenWhisk"
        },
        {
            "key":"parameters",
            "value":[
                {
                    "name":"action_name",
                    "required":true,
                    "bindTime":true,
                    "description":"Name of the action to be created"
                },
                {
                    "name":"action_data",
                    "required":true,
                    "bindTime":true,
                    "description":"Base64 encoded compressed data containing action files and requirements file, must have requirements.txt and can have __main__.py or any other action file with action_main parameter set to action entry point, for example, run zip -rq action.zip action_files/ and run this action with cat action.zip | base64"
                },
                {
                    "name":"action_main",
                    "required":false,
                    "bindTime":true,
                    "description":"Name of the function which is entry point in the action python file"
                },
                {
                    "name":"action_namespace",
                    "required":false,
                    "bindTime":true,
                    "description":"namespace where the action needs to be created"
                }
            ]
        },
        {
            "key":"sampleInput",
            "value":{
                "action_name":"my-action",
                "action_data":"cat action.zip | base64",
                "action_main":"jokes",
                "action_namespace":"dev"
            }
        }
    ]
}
EOF
)

# Create python action using wsk CLI
#$WSK_CLI -i --apihost "$EDGEHOST" --auth "$AUTH" action update build/python3 "$PYTHON_ACTION_SOURCE" \
#     --docker "openwhisk/python3action"
curl -sD - -o /dev/null -k -u $AUTH -X PUT https://$APIHOST/api/v1/namespaces/$NAMESPACE/actions/build/python3?overwrite=true \
     -H "Content-Type: application/json" \
     -d "$python_request_body" 1>/dev/null 
 
