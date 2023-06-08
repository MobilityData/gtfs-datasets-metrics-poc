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


######################################################################################################
# This scripts executes the GTFS validator against a feed.
# It uses a release tag parameter to download a GTFS validator version.
# If the cloud_storage parameter is passed, it will upload the report to the GCP cloud_storage address.
#
# Usage: 
# ./gtfs-validator-reporter.sh --url "https://url/gtfs.zip" -cs gs://gtfs-validator-your-storage/ -r 4.1.0

#######################################################################################################


cloud_storage=""
working_dir="output"
report_dir="report-output"
validator_args=()
java_maximum_memory=-Xmx10G
dataset_id="n/a"

# Function to display script usage
usage() {
  printf "\nScript Usage:\n"
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -cs, --cloud_storage <path>    Specify the cloud storage path"
  echo "  -h, --help                     Display this help message"
  printf "\nGTFS Validator Usage:\n"
  echo "$(java -jar gtfs-validator-cli-help.jar -h)"
  exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -cs|--cloud_storage)
      cloud_storage="$2"
      shift # past argument
      shift # past value
      ;;
    -did|--dataset_id)
      dataset_id="$2"
      shift # past argument
      shift # past value
      ;;      
    -r|--release)
      release_tag="$2"
      shift # past argument
      shift # past value
      ;;
    -wd|--working_dir)
      working_dir="$2"
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
if [[ -z $release_tag ]]; then
  echo "Release tag is required"
  usage
fi

# Download the Java program from GitHub release
gtfs_validator=gtfs-validator-$release_tag-cli.jar
if test -f "$gtfs_validator"; then
    printf "\n*** $gtfs_validator exists.\n"
else
    printf "*** Downloading $gtfs_validator\n"
    wget --no-check-certificate "https://github.com/MobilityData/gtfs-validator/releases/download/v$release_tag/gtfs-validator-$release_tag-cli.jar" -O "$gtfs_validator"
fi


printf "Processing the file with arguments: $validator_args[*] \n"
printf "\n"

# clean previous reports
rm -rf $working_dir/$report_dir-*

# Execute the Java jar file
java "${java_maximum_memory}" -jar $gtfs_validator "${validator_args[@]}" -o "$working_dir/$report_dir-$release_tag" | tee output.log

# Create summary.json
# validator_info="{ validator: { "version": "$release_tag", "dataset": "value5"  } }"
cat "$working_dir/$report_dir-$release_tag/report.json" | jq -c --arg release_tag "$release_tag" --arg dataset_id "$dataset_id" '. + { validator: { "version": $release_tag, "datasetId": $dataset_id } }' > "$working_dir/$report_dir-$release_tag/report-summary.json"

if [[ -n $cloud_storage ]]; then
  echo "copying to: $cloud_storage/$report_dir-$release_tag"
  echo "gsutil command: gsutil -m cp -r $working_dir/$report_dir-$release_tag $cloud_storage/$report_dir-$release_tag"
  # Upload the folder to Google Cloud Storage
  gsutil -m cp -r "$working_dir/$report_dir-$release_tag" "$cloud_storage/$report_dir-$release_tag"
else
  echo "cloud_storage is not set"
fi

