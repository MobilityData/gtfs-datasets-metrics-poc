#!/bin/bash

# Copyright MobilityData 2023
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

##############################################################################################################
# This scripts invokes gtfs-validator-reporter.sh script with two release versions againts a feed.
# See also: gtfs-validator-reporter.sh
##############################################################################################################


cloud_storage=""
report_dir="reports"
validator_args=()
release_target_tag=""
release_reference_tag=""
working_dir="output"

# Function to display script usage
usage() {
  printf "\nScript Usage:\n"
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -cs, --cloud_storage <path>    Specify the cloud storage path"
  echo "  -h, --help                     Display this help message"
#  printf "\nGTFS Validator Usage:\n"
#  echo "$(java -jar gtfs-validator-cli-help.jar -h)"
  exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -wd|--working_dir)
      working_dir="$2"
      shift # past argument
      shift # past value
      ;;      
    -rr|--release_reference)
      release_reference_tag="$2"
      shift # past argument
      shift # past value
      ;;
    -rt|--release-target)
      release_target_tag="$2"
      shift # past argument
      shift # past value
      ;;        
    -h|--help)
      usage
      ;;
    *) # unknown option
      validator_args+=("$1") # store in array
      shift # past argument
      ;;
  esac
done

# Check if release tag is provided
if [[ -z $release_target_tag || -z $release_reference_tag ]]; then
  echo "Release tag and release reference are required"
  usage
fi

printf "Processing the file with arguments: ${validator_args[@]}"

# Generates the validation reports
./gtfs-validator-reporter.sh "${validator_args[@]}" -r "${release_reference_tag}"  | tee output.log

./gtfs-validator-reporter.sh "${validator_args[@]}" -r "${release_target_tag}"  | tee output.log


