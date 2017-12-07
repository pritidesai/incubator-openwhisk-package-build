# Package and Deploy Third Party Modules - NodeJS 

OpenWhisk has a limitation in creating actions which are dependent on third party modules. Users have to install such modules locally before creating a new action and package them as part of action source. In addition, those packages are not available to any other action in the same runtime container. For example:

```
ls actions/my-action/
index.js
package.json
cd actions/my-action
npm install --production
zip -rq action.zip *
wsk action create my-action --kind nodejs:6 action.zip
```

This automation is created to address this limitation.

## Deploy this Automation - nodejs-build

### Build docker image using nodejs6

For this automation, we need a docker image using [nodejs6](https://github.com/apache/incubator-openwhisk/blob/dad7243269ba2554a81fcdd9dabfba4201eb7f7f/core/nodejs6Action/Dockerfile) and adding `zip`.

To create a new docker image:

```
git clone <incubator-package-build>
cd incubator-package-build
docker build . -t <user>/nodejs6action-build
docker login # Provide your username and password
docker push <user>/nodejs6action-build
```

Replace `<user>` with your docker hub username.

You can skip this step to **experiment** by using a prebuilt image [pritidesai8/nodejs6action-build](https://hub.docker.com/r/pritidesai8/nodejs6action-build/), but for production use you must create your own docker image.

### Create an action nodejs-build

Run `./deploy.sh` to create `action.zip` with [`index.js`](src/index.js) and deploy a new action `nodejs-build` to OpenWhisk with your docker image.

```
./deloy.sh
```

## Create Your Own Action - my-action

Invoke this new action using the `wsk` CLI:

```
ls actions/my-action/
index.js
package.json
cd actions/my-action
zip -rq action.zip *
wsk action invoke nodejs-build --blocking --param action_name my-action --param action_data `cat action.zip | base64`
```

`my-action` is using node module [string-format](https://www.npmjs.com/package/string-format) which is not available in OpenWhisk Node.js runtime container and was installed by `nodejs-build`. Test `my-action` with:

```
wsk action invoke my-action -r --blocking --param name Amy
{
    "message": "Hello, Amy!"
}
```

## Customize Deployment of nodejs-build

You can override some settings in [`deploy.sh`](./deploy,sh) using following enviornment variables:

```
OPENWHISK_ACTION_NAME
OPENWHISK_ACTION_DOCKER_IMAGE
OPENWHISK_HOST
OPENWHISK_AUTH
```

For example to deploy using your own image

```
OPENWHISK_ACTION_DOCKER_IMAGE="<user>/nodejs6action-build" \
./deploy.sh
```

You can also provide name of the action, an existing zip archive, and the name of the image on command line:

```
./deloy.sh buildaction build-action.zip pritidesai8/nodejs6action-build
```

Adjust the [`./deloy.sh`](./deploy.sh) as necessary for more customizations.

## Improvements

### Improve Usage

This automation has a limitation as well where users have to create a zip file and provide base64 encoded zip content as a parameter to nodejs-build. We would ideally like to have an automation such that users can provide path to action files and those action files are uploaded to docker runtime container, with the following workflow:

```
ls actions/my-action/
index.js
package.json
wsk action invoke nodejs-build --blocking --param action_name my-action --param action_data actions/my-action
```

### Add More Runtimes

This automation should be extended to include other runtimes such as Swift, Java, and Python.
