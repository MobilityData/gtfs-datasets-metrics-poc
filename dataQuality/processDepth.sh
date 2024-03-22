#!/bin/zsh

truncate -s 0 dataDepth.csv
for fic in ../../data/*.json
do
    jq '.summary.gtfsFeatures[]' $fic | grep -v '^$' | sed 's/"//g' >> dataDepth.csv
done

sed 's/"//g' dataDepth.csv | grep -v '^$' | sort | uniq -c | awk '{temp=$1; gsub(/^ *[0-9]+ */, ""); print $0 ", " temp}'
