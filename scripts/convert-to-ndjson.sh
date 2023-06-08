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

#!/bin/bash

######################################################################################################
# This scripts converts JSON all files with the specified name within a path of a GCP bucket to NDJSON (New Line delimiter JSON).
#
# Usage: 
# ./convert-to-ndjson.sh -bp my-bucket/reports -f report.json
#######################################################################################################

bucket_path=""
filename=""
concurrency_limit=10

# Function to display script usage
usage() {
  printf "\nScript Usage:\n"
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -bp, --bucket_path <path>    Specify the GCP cloud storage bucket. Example: my-bucket/reports"
  echo "  -f, --filename <path>    Specify the filename to match with the search and convert"
  echo "  -h, --help                     Display this help message"
  exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -bp|--bucket_path)
      bucket_path="$2"
      shift # past argument
      shift # past value
      ;;      
    -f|--filename)
      filename="$2"
      shift # past argument
      shift # past value
      ;;     
    -h|--help)
      usage
      ;;
    *) # unknown option
      shift # past argument
      ;;
  esac
done

temp_dir=$(mktemp -d)

echo "Listing files gs://$bucket_path/ "

# List all summary-report.json files in the bucket and their paths
files=$(gsutil ls -r gs://$bucket_path/ | grep "/$filename$")

file_count=$(echo "$files" | wc -l)
echo "Number of files found: $file_count"

if [[ -z "$files" ]]; then
  echo "No files found."
  exit 1
fi

while IFS= read -r file; do
  (
    original_filename=$(basename "$file")

  relative_path=${file#gs://$bucket_path/}
  relative_path=${relative_path%"$original_filename"}
  echo "Relative path $relative_path"

  local_directory="$temp_dir/$relative_path"
  mkdir -p "$local_directory"

  echo "Original filename $original_filename"
  output_filename="${original_filename%.json}-nd.json"
  
  # Convert the file to NDJSON using jq and save it to the output file
  echo "Converting $local_directory/$output_filename"
  gsutil cp "$file" "$local_directory/$original_filename"
  echo "Copied $local_directory/$original_filename"
  jq -c '.' "$local_directory/$original_filename" > "$local_directory/$output_filename.tmp"
  mv "$local_directory/$output_filename.tmp" "$local_directory/$output_filename"

  echo "Uploading $local_directory/$output_filename to gs://$bucket_path/$relative_path/"
  gsutil cp "$local_directory/$output_filename" "gs://$bucket_path/$relative_path/"
  ) &

  # allow to execute up to $N jobs in parallel
  if [[ $(jobs -r -p | wc -l) -ge $concurrency_limit ]]; then
      wait
  fi
done <<< "$files"

# no more jobs to be started but wait for pending jobs to complete
wait

rm -r "$temp_dir"
