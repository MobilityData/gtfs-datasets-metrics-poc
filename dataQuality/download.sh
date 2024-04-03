#!/bin/bash
validator_version=$1
if [ -z "$validator_version" ]; then
  echo "Please provide the validator version as an argument"
  exit 1
fi

cat allFiles.txt | awk -v validator_version=$validator_version -F '/' '
BEGIN {
    print "#!/bin/bash" > "commands.txt"
}
/report-summary.json/{
    # Process only the lines with 9 fields
    if (NF != 9) {
        next
    }

    # Extract the agency name
    agency = $7

    # If its a new agency and "5.0.0" was not found in the previous agency, print it
    if (prev_agency != "" && prev_agency != agency) {

      if (found_data_for_version == 0) {
        print "No data for version " version " for agency " prev_agency
      }
      found_data_for_version = 0
    }
    # Check if the line contains "5.0.0"
    if ($0 ~ /5.0.0/) {
        found_data_for_version = 1
        line_number++
        command = sprintf("gsutil cp %s reports/%s.json\n", $0, agency)
        print line_number ": " agency
        print "echo \"Processing #" line_number "\"" >> "commands.txt"
        print command >> "commands.txt"
    }

    # Update the previous agency
    prev_agency = agency
}

# At the end, print the last agency if "5.0.0" was not found
END {
    if (found_500 == 0) {
        print "No data for version " version " for agency " prev_agency
    }
}'
