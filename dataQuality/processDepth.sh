#!/bin/zsh

tempFile="tempDtaDepth.csv"
sortingFile="sortingFile.csv"
echo "tempFile = $tempFile"
truncate -s 0 $tempFile
truncate -s 0 $sortingFile
truncate -s 0 dataDepth.csv

# Obtain the list of all features
features=`awk -F '|' '/\|----------/ {flag=1; next} flag {print $3}' ~/IdeaProjects/gtfs-validator/docs/FEATURES.md`

echo "Features = $features"
exit 0

# First sort the files by feed_id
for fic in ../../dataFormatted/*.json
do
  echo "Processing $fic"
  feed_id=`echo "$fic" | sed 's/.*-\([0-9]\{1,\}\)\.json$/\1/'`
  echo "$feed_id $fic" >> $sortingFile

done
sort -n $sortingFile -o $sortingFile

while IFS= read -r line
do

  read -r feed_id fic <<< "$line"
  echo "feed_id = $feed_id, fic = $fic"
  jq '.summary.gtfsFeatures[]' $fic | grep -v '^$' | sed 's/"//g' | awk -v var="$feed_id" '{print var "," $0}' >> $tempFile

done < "$sortingFile"

#exit
#for fic in ../../DataFormatted/*.json
#do
#  feed_id=`echo "$fic" | sed 's/.*-\([0-9]\{1,\}\)\.json$/\1/'`
#  echo "Processing $feed_id $fic"
#
#  jq '.summary.gtfsFeatures[]' $fic | grep -v '^$' | sed 's/"//g' | awk -v var="$feed_id" '{print var "," $0}' >> $tempFile
#
#done

echo "Features,Number of feeds,Feed ids" > dataDepth.csv
cat $tempFile | awk -F',' '
{
  feeds[$2] = (feeds[$2] ? feeds[$2] " " : "") $1
  numFeeds[$2]++
}
END {
  for (feature in feeds) print feature "," numFeeds[feature] "," feeds[feature]
}' >> dataDepth.csv

ls -l $tempFile
exit 0
sed 's/"//g' dataDepth.csv | grep -v '^$' | sort | uniq -c | awk '{temp=$1; gsub(/^ *[0-9]+ */, ""); print $0 ", " temp}'
