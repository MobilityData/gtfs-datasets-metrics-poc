#!/bin/bash

outputFolder="./results"
mkdir -p $outputFolder

# tempFile will be made of 2 columns, the feed is and the feature id present in the feed.
# That means there will be as many lines for given feed as the number of features in the feed.
tempFile="tempDtaDepth.csv"

# The sorting file is the same as tempFile, but before it is sorted. We sort so the list of feeds for a given feature
# in the final file is sorted.
sortingFile="sortingFile.csv"

rawDataDepthFile="$outputFolder/rawDataDepth.csv"
dataDepthFile="$outputFolder/dataDepth.csv"
# Where the json files were uploaded
inputFolder="./reports"

truncate -s 0 $tempFile
truncate -s 0 $sortingFile
truncate -s 0 $dataDepthFile
truncate -s 0 $rawDataDepthFile

# First sort the files by feed_id so the list of feed per feature is sorted at the end
for fic in $inputFolder/*.json
do
  echo "Processing $fic"
  feed_id=`echo "$fic" | sed 's/.*-\([0-9]\{1,\}\)\.json$/\1/'`
  echo "$feed_id $fic" >> $sortingFile
done

sort -n $sortingFile -o $sortingFile

# Obtain the list of all features
# Write them in the temp file with a 0 as the feed id. This will be processed when we aggregate the data per feature.
awk -F '|' '
/^ *$/ {
  next
}
/\|----------/ {flag=1; next} flag {

  # Remove leading and trailing spaces
  gsub(/^[ \t]+|[ \t]+$/, "", $3)
  # Some features have a star at the end in the features file (e.g. "Pathways (extra)*"). Remove it.
  gsub(/\*$/, "", $3)
  print "0," $3
}' ../gtfs-validator/docs/FEATURES.md > $tempFile

# Extract the list of features from the results json files.
while IFS= read -r line
do

  read -r feed_id fic <<< "$line"
  feed_name=$(basename "$fic" | sed 's/\.json$//')
  echo "feed_id = $feed_id, fic = $fic"
  jq '.summary.gtfsFeatures[]' $fic | grep -v '^$' | sed 's/"//g' |
    awk -v feed_id="$feed_id" -v feed_name="$feed_name" '{print feed_id "," $0 "," feed_name}' >> $tempFile


done < "$sortingFile"

# Now tempFile contains 2 columns, the feed id and the feature id. We will aggregate the data per feature.
# The output will be a csv file with 3 columns: feature id, number of feeds and the sorted list of feed ids.
# The beginning of tempFile is the list of features with a 0 as the feed id.
# That way we can "prime" the aggregation and know if a feature is used in 0 feed
echo "Features,Number of feeds,Feed ids" > $dataDepthFile
cat $tempFile | awk -v features="$features" -v rawDataDepthFile="$rawDataDepthFile" -v dataDepthFile="$dataDepthFile" -F',' '
BEGIN {
  print "Feed Id,Feed Name,Component" > rawDataDepthFile
}
{
  feed_id = $1
  feature = $2
  feed_name = $3
  print "Processing feature " feature " with feed_id " feed_id
  if (feed_id == 0) {
    numFeeds[feature] = 0
    next
  }
  feeds[feature] = (feeds[feature] ? feeds[feature] " " : "") feed_id
  print feed_id "," feed_name "," feature >> rawDataDepthFile
  numFeeds[feature]++
}
END {
  for (feature in numFeeds) print feature "," numFeeds[feature] "," feeds[feature] >> dataDepthFile
}'
