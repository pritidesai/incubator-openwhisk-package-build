# Using the Build Package

The `/whisk.system/build` package offers a convenient way for us to specify list of dependencies, install them on OpenWhisk runtime container, package them with the intended action and deploy that action on OpenWhisk. For example, for NodeJS runtime, receive `package.json` with action source, run `npm install --production` on OpenWhisk container, zip up the list of dependencies from the `package.json` along with action source code, and create an action with this zip file. 

This package includes following actions:

| Entity | Type | Parameters | Description |
| --- | --- | --- | --- |
| `/whisk.system/build` | package | - | Utility to package and deploy third party modules |
| `/whisk.system/build/nodejs` | action | action_name, action_data | Runs `npm install --production` and creates a zip file with dependencies on OpenWhisk server |
| `/whisk.system/build/python` | action | action_name, action_data, action_kind | Runs `virtualenv` and `pip install` on OpenWhisk server |

## Package and Deploy Third Party Modules - NodeJS

#### Problem Statement (Without `/whisk.system/build/nodejs`):

OpenWhisk has a limitation in creating actions which are dependent on third party modules. We have to install such modules locally before creating a new action and package them as part of action source. In addition, those packages are not available to any other action in the same runtime container. For example:

```
$ cd incubator-openwhisk-package-build/nodejs/actions/helloworld
$ ls -1
index.js
package.json
$ npm install --production
$ zip -rq helloworld.zip *
$ wsk action create helloworld --kind nodejs:6 helloworld.zip
$ wsk action invoke helloworld -r --blocking --param name Amy
{
    "message": "Hello, Amy!"
}
```

### `nodejs` Parameters

The `/whisk.system/build/nodejs` action installs and packages dependent `npm` modules while creating an OpenWhisk action. The parameters are as follows:

* `action_name`: A string specifying name of an intended action. For example: `my-action`

* `action_data`: Base64 encoded compressed data containing action files and `package.json`. Must have index.js and can have package.json. For example: `zip -rq action.zip action_files/` followed by `cat action.zip | base64`.

#### Solution (With `/whisk.system/build/nodejs`):

The following in an example of creating an action `helloworld`:

```
$ cd incubator-openwhisk-package-build/nodejs/actions/helloworld
$ ls -1
index.js
package.json
$ zip -rq helloworld.zip *
$ wsk action invoke /whisk.system/build/nodejs --blocking --param action_name helloworld --param action_data `cat helloworld.zip | base64`
```

Here `helloworld` is using node module `string-format` which is not available in OpenWhisk Node.js runtime container and was installed by `build/nodejs`. Test `helloworld` with:

```
$ wsk action invoke helloworld -r --blocking --param name Amy
{
    "message": "Hello, Amy!"
}
```

## Install Python Packages

#### Problem Statement (Without `/whisk.system/build/python*`):

```
$ cd incubator-openwhisk-package-build/python/actions/jokes
$ ls -1 
__main__.py
requirements.txt
$ virtualenv virtualenv
$ source virtualenv/bin/activate
$ pip install -r requirements.txt
$ zip -rq jokes.zip virtualenv __main__.py
$ wsk action create jokes --kind python:2 --main joke jokes.zip
$ wsk action invoke jokes -r --blocking
{
    "joke": "Software developers like to solve problems. If there are no problems handily available, they will create their own problems."
}
```

### `python2/python3` Parameters:

The `/whisk.system/build/python2` and `/whisk.system/build/python3` action installs third-party Python packages on Python runtime container before creating an OpenWhisk action. The parameters are as follows:

* `action_name`: A string specifying name of an intended action. For example: my-python-action

* `action_data`: Base64 encoded compressed data containing action files and requirements.txt. Must have requirements.txt and can have action source files. If an entry function is outside of `__main__.py`, you must specify `action_main`. For example: `zip -rq action.zip my-python-action/` followed by `cat action.zip | base64`.

* `action_main`: Optional. A string specifying an entry function of the intended action.

#### Solution (With `/whisk.system/build/nodejs`):

The following in an example of creating an action `my-python-action`:

```
$ cd incubator-openwhisk-package-build/python/actions/jokes
$ ls -1
__main__.py
requirements.txt
$ zip -rq jokes.zip *
$ wsk action invoke /whisk.system/build/python2 --blocking --param action_name jokes --param action_data `cat jokes.zip | base64` --param action_main joke
```

Here `jokes` depends on the third party Python package `pyjokes` which is not available in OpenWhisk Python2 runtime container and was installed by `build/python2`. Test `jokes` with:

```
$ wsk action invoke jokes -r --blocking
{
    "joke": "There are 10 types of people: those who understand hexadecimal and 15 others"
}
```
