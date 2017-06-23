/*
 * Copyright 2015-2016 IBM Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
  * This is the action to compile nodejs action files.
  *
  * main() will be invoked when you run this action.
  *
  * @param whisk actions accept a single parameter,
  *        which must be a JSON object with following keys.
  *
  * @param {string} action_name - Name of the action to be created
  * @param {string} action_data - Base64 encoded compressed data containing
  *     action files and packaging file. Must have index.js and can have
  *     package.json. For example, run:
  *         zip -rq action.zip action_files/
  *         cat action.zip | base64
  * 
  *
  * In this case, the params variable looks like:
  *     {
  *         "action_name": "xxxx",
  *         "action_data": "xxxx",
  *     }
  *
  * @return which must be a JSON object. It will be the output of this action.
  *
  */


function main(params) {
    // validate parameters
    var errorMsg = validateParams(params);

    if (errorMsg) {
        return { error: errorMsg };
    }

    var actionName = params.action_name;
    var actionData = params.action_data;

    var fs = require('fs');
    var exec = require('child_process').exec;

    console.log("Action Data", actionData);

    // create temporary directory under /tmp/<actionName>-<timestamp>/
    // create new directory for each invocation otherwise with subsequent
    // execution, directory creation fails
    var zipFileDir = "/tmp/" + actionName + '-' + new Date().getTime() + '/';
    var zipFileName = actionName + ".zip";
    var zipFile = zipFileDir + zipFileName;

    // require the OpenWhisk npm package
    var openwhisk = require("openwhisk");
    // instantiate the openwhisk instance before you can use it
    var wsk = openwhisk();

    actionData += actionData.replace('+', ' ');
    binaryActionData = new Buffer(actionData, 'base64').toString('binary');

    return new Promise(function (resolve, reject) {
        // create a temporary directory
        cmd = 'mkdir ' + zipFileDir;
        exec(cmd, function (err, data) {
            // rejects the promise with `err` as the reason
            if (err) {
                console.error('Failed to create temporary directory to hold action data: ', zipFileDir);
                console.error(err);
                reject(err);
            } else {
                // fulfills the promise with `data` as the value
                console.log('Successfully created temporary directory to hold action data: ', zipFileDir);
                console.log(data);
                resolve(data);
            }
        })
    })     
    .then(function () {
        return new Promise(function (resolve, reject) {
            // write a zip file with base64 encoded action data
            fs.writeFile(zipFile, binaryActionData, "binary", function (err, data) {
                if (err) {
                    console.error('Failed to create zip file with action_data: ', zipFile);
                    console.error(err);
                    reject(err);
                } else {
                    // fulfills the promise with `data` as the value
                    console.log('Successfully created zip file: ', zipFile);
                    resolve(data);
                }
            })
        })
    })
    .then (function () {
        // extract all the files/data from action data with
        // unzip -o -d /tmp/ /tmp/action.zip && rm /tmp/action.zip
        cmd = 'unzip -o ' + zipFile + ' && rm ' + zipFile;
        return new Promise(function (resolve, reject) {
            exec(cmd, {cwd: zipFileDir}, function (err, data) {
                if (err) {
                    console.error('Failed to extract action files from action data: ', zipFile);
                    console.error(err);
                    reject(err);
                } else {
                    // fulfills the promise with `data` as the value
                    console.log('Successfully extracted action files from action data: ', zipFile);
                    console.log(data);
                    resolve(data);
                }
            })
        })
    })
    .then(function () {
        /**
         * Run: cd zipFileDir && npm install --production
         * run npm install only if package.json file exists at zipFileDir
         * package.json file contains list of npm packages which are needed for
         * the new action getting created.
         * npm install reads the list of dependencies from package.json file and
         * installs required packages.
         * Running npm install wihtout package.json fails with "enoent" - 
         * ENOENT: no such file or directory, open <zipFileDir>/package.json
         */
        return new Promise(function (resolve, reject) {
            fs.exists(zipFileDir + 'package.json', exists => {
                if (exists) {
                    cmd = 'npm install --production';
                    exec(cmd, {cwd: zipFileDir}, function (err, data) {
                        if (err) {
                            console.log('Failed to install npm packages ', err);
                            reject(err);
                        } else {
                            console.log('successfully installed npm packages', data);
                            resolve(data);
                        }
                    })
                } else {
                    resolve();
                }
            })
        })
    })
    .then (function () {
        /**
         * Prune package directories under node_modules to delete test/ and tests/ directories
         */
        return new Promise(function (resolve, reject) {
            fs.exists(zipFileDir + 'node_modules', exists => {
                if (exists) {
                    cmd = 'find . -type d -name "test*" -exec rm -r {} +'
                    exec(cmd, {cwd: zipFileDir + 'node_modules'}, function (err, data) {
                        if (err) {
                            console.log('Failed to prune node_modules to remove tests directory', err);
                            reject(err);
                        } else {
                            console.log('Successfully pruned node_modules to remove tests directory', data);
                            resolve(data);
                        }
                    })
                } else {
                    resolve();
                }
            })
        })
    })
    .then (function () {
        /**
         * Zip the whole directory including package.json, index.js, and node_modules.
         * Maintain the same directory structure while zipping so that index.js
         * and/or package.json are still at the root which is must for zipped actions.
         */
        cmd = 'zip -rq ' + zipFileName + ' *';
        return new Promise(function (resolve, reject) {
            exec(cmd, {cwd: zipFileDir}, function (err, data) {
                if (err) {
                    console.log('Failed to create zip file from action files and dependent npm packages', err);
                    reject(err);
                } else {
                    console.log('successfully created zip file from action files and dependent npm packages', data);
                    resolve(data);
                }
            })
        })
    })
    .then (function () {
        actionData = fs.readFileSync(zipFile)
        // using "update" action instead of "create" action
        // Update action creates a new action if it doesn't exist
        // we decided to use update action mode here as create action fails if you
        // try to create an action which already exists so you have to first delete
        // it and than recreate it.
        return wsk.actions.update({actionName: actionName, action: actionData})
        .then (result => {
            console.log('Successfully created/updated action: ', actionName, result);
            return {
                message: result
            };
        })
        .catch (err => {
            console.error('Failed to create/update action: ', actionName, err);
            return {
                error: err
            };
        })
    })
    // catch handler
    .catch(function (err) {
        console.error('Error: ', err);
        return {error: err};
    });

}

/**
 *  Checks if all required params are set.
 *  Required parameters are:
 *      action_name
 *      action_location
 */
function validateParams(params) {
    if (params.action_name === undefined) {
        return ('No action name provided, please specify action_name.');
    }
    else if (params.action_data === undefined) {
        return ('No action data provided, please specify action_data.');
    }
    else {
        return undefined;
    }
}

exports.main = main;
