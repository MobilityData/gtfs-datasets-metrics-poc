#!/bin/zsh

counter=1
rawDataQualityFile="rawDataQuality.csv"
dataQualityFile="dataQuality.csv"
tmpFile="tmpDataQuality.csv"
inputFolder="../../dataFormatted"

truncate -s 0 $rawDataQualityFile
truncate -s 0 $dataQualityFile
truncate -s 0 $tmpFile
for fic in $inputFolder/*.json
do
    feed_name=$(basename "$fic" | sed 's/\.json$//')
    feed_id=$(echo "$feed_name" | sed 's/.*-\([0-9]\{1,\}\)$/\1/')
    echo "$counter: Processing $fic"
    ((counter++))
    jq -r '.notices[] | "\(.code) '$feed_id' \(.totalNotices) \(.severity) '$feed_name'"' $fic >> $tmpFile
done


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

