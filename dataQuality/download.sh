#!/bin/zsh

cat allFiles.txt | awk -F '/' '
BEGIN {
    print "" > "commands.txt"
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

      if (found_500 == 0) {
        print "No 5.0.0 data" prev_agency
      }
      found_500 = 0
    }
    # Check if the line contains "5.0.0"
    if ($0 ~ /5.0.0/) {
        found_500 = 1
        line_number++
        command = sprintf("gsutil cp %s data/%s.json\n", $0, agency)
        print line_number ": " agency
        print "echo \"Processing #" line_number "\"" >> "commands.txt"
        print command >> "commands.txt"
#        system( command )
    }

    # Update the previous agency
    prev_agency = agency
}

# At the end, print the last agency if "5.0.0" was not found
END {
    if (found_500 == 0) {
        print "No 5.0.0 data " prev_agency
    }
}'
