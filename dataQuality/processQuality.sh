#!/bin/zsh

counter=1
# The raw data quality file
rawDataQualityFile="rawDataQuality.csv"
# The final data quality file
dataQualityFile="dataQuality.csv"
tmpFile="tmpDataQuality.csv"
# Where the json files were uploaded
inputFolder="../../dataFormatted"

truncate -s 0 $rawDataQualityFile
truncate -s 0 $dataQualityFile
truncate -s 0 $tmpFile
for fic in $inputFolder/*.json
do
    feed_name=$(basename "$fic" | sed 's/\.json$//')
    # Just keep the number at the end of the feed name
    feed_id=$(echo "$feed_name" | sed 's/.*-\([0-9]\{1,\}\)$/\1/')
    echo "$counter: Processing $fic"
    ((counter++))
    jq -r '.notices[] | "\(.code) '$feed_id' \(.totalNotices) \(.severity) '$feed_name'"' $fic >> $tmpFile
done

# A typical line of the tmp file looks like this:
# missing_recommended_file 2023 1 WARNING it-brindisi-stp-brindisi-gtfs-2023
# Sort by the second one, the feed id, so the list of feeds will be sorted by feed id in the final file
sort -k2,2n $tmpFile -o $tmpFile


cat $tmpFile | awk -v rawDataQualityFile="$rawDataQualityFile" -F' ' '
BEGIN {
  OFS = ","
  print "datasetId,code,counter,severity" > rawDataQualityFile
}
{
  notice_code = $1
  feed_id = $2
  total_notices = $3
  severity = $4
  feed_name = $5
  # Having the raw data has been requested
  # A typical line in that file looks like this:
  # it-brindisi-stp-brindisi-gtfs-2020,fast_travel_between_consecutive_stops,220,WARNING
  print feed_name "," notice_code"," total_notices "," severity >> rawDataQualityFile
  if (severity == "ERROR") {
    errors[notice_code]++
    b = errors_list_feeds[notice_code]
    errors_list_feeds[notice_code] = (b ? b " " : "") feed_id
  } else if (severity == "WARNING") {
    warnings[notice_code]++
    b = warnings_list_feeds[notice_code]
    warnings_list_feeds[notice_code] = (b ? b " " : "") feed_id
  } else if (severity == "INFO") {
    infos[notice_code]++
    b = infos_list_feeds[notice_code]
    infos_list_feeds[notice_code] = (b ? b " " : "") feed_id
  }
}

function print_notices(notices, notices_list_feeds) {
  print "#,Notice name,# of datasets,List of feed ids"
  counter = 1
  for (notice_code in notices) {
    print counter++, notice_code, notices[notice_code], notices_list_feeds[notice_code]
  }
}
END {

  print "ERRORS"
  print_notices(errors, errors_list_feeds)
  print "WARNINGS"
  print_notices(warnings, warnings_list_feeds)
  print "INFOS"
  print_notices(infos, infos_list_feeds)

}' > $dataQualityFile

