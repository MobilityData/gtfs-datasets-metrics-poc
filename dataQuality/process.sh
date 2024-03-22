#!/bin/zsh

counter=1
truncate -s 0 dataQuality.csv
for fic in ../../data/*.json
do
    feed_id=$(echo "$fic" | sed 's/.*-\([0-9]\{1,\}\)\.json$/\1/')
    echo "$counter: Processing $fic"
    ((counter++))
    jq -r '.notices[] | "\(.code) '$feed_id' \(.totalNotices) \(.severity)"' $fic >> dataQuality.csv
done


exit 0
sort -k2,2n dataQuality.csv -o dataQuality.csv

cat dataQuality.csv | awk '
BEGIN {OFS = "," }
{
  notice_code = $1
  feed_id = $2
  total_notices = $3
  severity = $4
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

}'