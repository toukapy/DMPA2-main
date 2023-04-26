#!/bin/bash
##########################################################
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# This script handles bootstrapping python for
# the Apache Kudu base docker images.
#
##########################################################

set -xe
set -o pipefail

function install_python_packages() {
  PYTHON_VERSION=$(python --version 2>&1 | cut -d' ' -f2)
  PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
  PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)

  # We use get-pip.py to bootstrap pip outside of system packages.
  # This prevents issues with the platform package manager knowing
  # about only some of the python packages.
  if [[ "$PYTHON_MAJOR" == "2" && "$PYTHON_MINOR" == "7" ]]; then
    # The standard get-pip.py URL no longer supports Python 2.7,
    # so we need to use the version specific one.
    curl https://bootstrap.pypa.io/pip/2.7/get-pip.py | python
  else
    # Use a stable version of pip that works with Python 2 and 3.
    curl https://bootstrap.pypa.io/get-pip.py | python - "pip < 20.3.4"
  fi
  pip install --upgrade \
    cython \
    setuptools \
    setuptools_scm
}

# Install the prerequisite libraries, if they are not installed.
# CentOS/RHEL
if [[ -f "/usr/bin/yum" ]]; then
  # Update the repo.
  yum update -y

  # Install curl, used when installing pip.
  yum install -y ca-certificates \
    curl \
    redhat-lsb-core

  # Get the major version for version specific package logic below.
  OS_MAJOR_VERSION=$(lsb_release -rs | cut -f1 -d.)

  # Install python development packages.
  yum install -y epel-release
  # g++ is required to check for int128 support in setup.py.
  yum install -y gcc gcc-c++
  if [[ "$OS_MAJOR_VERSION" -lt "8" ]]; then
    yum install -y python-devel
  else
    yum install -y python3-devel
    alternatives --set python /usr/bin/python3
  fi

  install_python_packages

  # Reduce the image size by cleaning up after the install.
  yum clean all
  rm -rf /var/cache/yum /tmp/* /var/tmp/*
# Ubuntu/Debian
elif [[ -f "/usr/bin/apt-get" ]]; then
  # Ensure the Debian frontend is noninteractive.
  export DEBIAN_FRONTEND=noninteractive

  # Update the repo.
  apt-get update -y

  # Install curl, used when installing pip.
  apt-get install -y --no-install-recommends ca-certificates curl

  # Install python development packages.
  # g++ is required to check for int128 support in setup.py.
  apt-get install -y --no-install-recommends g++ python-dev
  install_python_packages

  # Reduce the image size by cleaning up after the install.
  apt-get clean
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

  unset DEBIAN_FRONTEND
# OpenSUSE/SLES
elif [[ -f "/usr/bin/zypper" ]]; then
  # Update the repo.
  zypper update -y

  # Install curl, used when installing pip.
  zypper install -y ca-certificates curl

  # Install python development packages.
  # g++ is required to check for int128 support in setup.py.
  zypper install -y gcc gcc-c++ python-devel python-xml
  install_python_packages

  # Reduce the image size by cleaning up after the install.
  zypper clean --all
  rm -rf /var/lib/zypp/* /tmp/* /var/tmp/*
else
  echo "Unsupported OS"
  exit 1
fi
