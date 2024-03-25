#!/bin/zsh

# tempFile will be made of 2 columns, the feed is and the feature id present in the feed.
# That means there will be as many lines for given feed as the number of features in the feed.
tempFile="tempDtaDepth.csv"

# The sorting file is the same as tempFile, but before it is sorted. We sort so the list of feeds for a given feature
# in the final file is sorted.
sortingFile="sortingFile.csv"
echo "tempFile = $tempFile"
truncate -s 0 $tempFile
truncate -s 0 $sortingFile
truncate -s 0 dataDepth.csv

# First sort the files by feed_id so the list of feed per feature is sorted at the end
for fic in ../../dataFormatted/*.json
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
}' ~/IdeaProjects/gtfs-validator/docs/FEATURES.md > $tempFile

# Extract the list of features from the results json files.
echo "Features = $features"
while IFS= read -r line
do

  read -r feed_id fic <<< "$line"
  echo "feed_id = $feed_id, fic = $fic"
  jq '.summary.gtfsFeatures[]' $fic | grep -v '^$' | sed 's/"//g' | awk -v var="$feed_id" '{print var "," $0}' >> $tempFile

done < "$sortingFile"

# Now tempFile contains 2 columns, the feed id and the feature id. We will aggregate the data per feature.
# The output will be a csv file with 3 columns: feature id, number of feeds and the sorted list of feed ids.
# The beginning of tempFile is the list of features with a 0 as the feed id.
# That way we can "prime" the aggregation and know if a feature is used in 0 feed
echo "Features,Number of feeds,Feed ids" > dataDepth.csv
cat $tempFile | awk -v features="$features" -F',' '
{
  feed_id = $1
  feature = $2
  if (feed_id == 0) {
  print "Processing feature " feature " with feed_id " feed_id
    numFeeds[feature] = 0
    next
  }
  feeds[feature] = (feeds[feature] ? feeds[feature] " " : "") feed_id
  numFeeds[feature]++
}
END {
  for (feature in numFeeds) print feature "," numFeeds[feature] "," feeds[feature] >> "dataDepth.csv"
}'

ls -l $tempFile
exit 0
sed 's/"//g' dataDepth.csv | grep -v '^$' | sort | uniq -c | awk '{temp=$1; gsub(/^ *[0-9]+ */, ""); print $0 ", " temp}'
