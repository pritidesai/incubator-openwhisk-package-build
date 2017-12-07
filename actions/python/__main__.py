#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
#   * this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
#   * the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import os
import base64
import datetime
import glob
import zipfile
import site
import subprocess
import requests
import pip
import virtualenv

def main(params):
    # validate parameters
    error_msg = validate_params(params)

    if error_msg:
        return {"error": error_msg}

    action_name = params.get("action_name")
    action_data = params.get("action_data")
    action_namespace = params.get("action_namespace")
    action_main = params.get("action_main")
    action_kind = params.get("action_kind")

    print ("Info: Both mandatory parameters are specified")
    print ("Info: Creating a new action with action_name set to: ", action_name)
    print ("Info: Creating a new action with action_data set to: ", action_data)

    if action_namespace:
        print ("Info: Creating a new action under namespace: ", action_namespace)
    else:
        action_namespace = "_"
        print ("Info: Creating a new action under default namespace: ", action_namespace)

    if action_kind:
        print ("Info: Creating a new action with kind: ", action_kind)
    else:
        action_kind = "python:2"
        print ("Info: Creating a new action with default kind: ", action_kind)

    # create temporary directory under /tmp/<action_name>-<timestamp>/
    # create new directory for each invocation otherwise with subsequent
    # execution, direction creation fails.
    zip_file_dir = os.path.join("/", "tmp", action_name + "-" + datetime.datetime.now().strftime("%s"))
    zip_file_name = action_name + "-tmp.zip"
    zip_file = os.path.join(zip_file_dir,  zip_file_name)

    # create a temporary directory
    if not os.path.exists(zip_file_dir):
        os.makedirs(zip_file_dir)
        print ("Info: Creating a temporary directory to hold action data at ", zip_file_dir)
        print ("Info: Creating a temporary zip file: ", zip_file)

    # write a zip file with base64 encoded action data
    # (TODO) add error handling
    zip_file_handle = open(zip_file, "wb")
    zip_file_handle.write(base64.b64decode(action_data))
    zip_file_handle.close()

    # extract all the files/data from action data
    # re-open the newly created zip file with ZipFile()
    zip_file_instance = zipfile.ZipFile(zip_file)

    if not zip_file_instance:
        return {"error": "Failed to open a zip file: " + zip_file}

    # get the list of files inside the zip file
    zip_file_members = zip_file_instance.namelist()
    if not zip_file_members:
        return {"error": "action data zip content is empty, please specify a valid base64 encoded action data"}

    # make sure that the action data has requirements.txt
    if not "requirements.txt" in zip_file_members:
        return {"error": "Error: Requirements file does not exist in action data payload, please add requirements.txt file"}


    # extract its contents into /tmp/<action_name>-<timestamp>/
    zip_file_instance.extractall(path=zip_file_dir)
    print ("Done extracting zip file at ", zip_file_dir)

    # close the ZipFile instance
    zip_file_instance.close()

    # make sure requirements.txt file exists in zip_file_dir
    req_file = os.path.join(zip_file_dir, "requirements.txt")
    if not os.path.isfile(req_file):
        return {"error": "Error: Action data did not have requirements.txt file."}

    # after unzipping, delete the zip file
    if os.path.isfile(zip_file):
        os.remove(zip_file)
        print ("Deleted a temporary zip file at ", zip_file)
    else:
        return {'error': "Error: " + zip_file + " file not found"}

    print ("Temporary directory has the following list of files:")
    print (os.listdir(zip_file_dir))

    # create and activate the virtual environment
    virtualenv_dir = os.path.join(zip_file_dir, "virtualenv")
    print ("Info: Creating virtualenv in project dir ", virtualenv_dir)
    if not os.path.exists(virtualenv_dir):
        virtualenv.create_environment(virtualenv_dir)
    activate_script = os.path.join(virtualenv_dir, "bin", "activate_this.py")
    execfile(activate_script, dict(__file__=activate_script))

    print ("Info: Installing packages from the requirements file at ", virtualenv_dir)
    # pip install a package using the venv as a prefix
    pip.main(["install", "--prefix", virtualenv_dir, "-r", req_file])

    # create a zip file using virtualenv/bin/activate_this.py,
    # each pacakge dir listed in requirements.txt, __main__.py if it exists,
    # and all files with an .py extension
    action_zip_file = os.path.join(zip_file_dir, action_name +".zip")
    print ("Info: Creating a action zip file to create a new action ", action_name)
    print ("Info: Creating zip file at ", action_zip_file)

    action_zip_file_instance = zipfile.ZipFile(action_zip_file, 'w')

    # adding activate script from virtualenv/bin/activate_this.py
    relative_activate_script = os.path.relpath(activate_script, zip_file_dir)
    print ("Info: Adding activate_script ", relative_activate_script, " in zip file ", action_zip_file)
    action_zip_file_instance.write(activate_script, relative_activate_script, compress_type=zipfile.ZIP_DEFLATED)

    # walk through the members of zip file and add them to target action zip file
    for zip_member in zip_file_members:
        zip_member_with_path = os.path.join(zip_file_dir, zip_member)
        if os.path.isfile(zip_member_with_path):
            ext = os.path.splitext(zip_member)[-1].lower()
            if ext == ".py":
                with open(zip_member_with_path, "r") as f:
                    action_source = f.readlines()
                print ("Info: Python file content is ", action_source)
                print ("Info: Adding python file ", zip_member, " to zip file ", action_zip_file)
                action_zip_file_instance.write(zip_member_with_path, zip_member, compress_type=zipfile.ZIP_DEFLATED)

    # read requirements.txt file to get a list of packages
    with open(req_file, "r") as req_file_obj:
        list_of_packages = req_file_obj.readlines()

    site_packages_dir = os.path.join(zip_file_dir, "virtualenv", "lib", "python*", "site-packages") #site.getsitepackages()[0]
    site_packages_dir = glob.glob(site_packages_dir)[0]
    print ("site package dir ", site_packages_dir)

    # add package directory from site-packages for each package listed in requirements.txt
    for package in list_of_packages:
        package = package.strip()
        package_dir = os.path.join(site_packages_dir, package.split(" ")[0])
        relative_package_path = os.path.relpath(package_dir, zip_file_dir)
        if os.path.isdir(package_dir):
            print ("Info: Adding package dir ", relative_package_path)
            addPackageFolderToZip(action_zip_file_instance, package_dir, zip_file_dir)


    action_zip_file_instance.close()

    action_source_zip_file = open(action_zip_file, 'rb')
    action_source_zip_data = action_source_zip_file.read()
    action_source_zip_file.close()

    openwhisk_action_source_base64 = base64.b64encode(action_source_zip_data)

    auth_key = os.environ['__OW_API_KEY']
    user_pass = auth_key.split(':')

    exec_params = {'kind': action_kind, 'code': openwhisk_action_source_base64}
    if action_main:
        exec_params['main'] = action_main
    json_params = {'exec': exec_params}

    payload = {'blocking': 'true', 'result': 'true'}

    url = os.environ['__OW_API_HOST'] + '/api/v1/namespaces/' + action_namespace + '/actions/' + action_name + '?overwrite=true'
    response = requests.put(url, json=json_params, params=payload, auth=(user_pass[0], user_pass[1]), verify=False)

    print(response.text)

    return {"result": "successfully created a new action " + action_name}

def validate_params(params):
    if not params.get("action_name"):
        return "Warning: No action name provided, please specify action_name."
    elif not params.get("action_data"):
        return "Warning: No action data provided, please spcify action_data."
    elif params.get("action_kind") != "":
        if  (params.get("action_kind") == "python:2" or params.get("action_kind") == "python:3"):
            return "Warning: action_kind can only be set to either python:2 or python:3"
    return None

def addPackageFolderToZip(zip_file_instance, package_folder, zip_file_dir):
    for file in os.listdir(package_folder):
        full_path = os.path.join(package_folder, file)
        if os.path.isfile(full_path):
           print ("File added: " + str(full_path))
           zip_file_instance.write(full_path, os.path.relpath(full_path, zip_file_dir), compress_type=zipfile.ZIP_DEFLATED)
        elif os.path.isdir(full_path):
            print ("Entering folder: " + str(full_path))
            addPackageFolderToZip(zip_file, full_path, zip_file_dir)

