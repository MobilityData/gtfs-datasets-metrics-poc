# gtfs-datasets-metrics-poc
## Process to generate analytics:
- See this repo: [feat/gcp-release-workflows-poc](https://github.com/MobilityData/gtfs-datasets-metrics-poc/tree/feat/gcp-release-workflows-poc)
- It contains a proof of concept that is not quite ready for prime time, but it's useful to understand the gist of it.
- The code for 4.0.0 -> 4.1.0 analytics is in branch feat/gcp-release-workflows-poc
- The code for 4.1.0 -> 4.2.0 analytics is in branch gcp-release-workflows-poc-4.2.0

Principle:
- Terraform is used to generate all resources in GCP, via the main.tf configuration.
- Then a series of manual steps are necessary to generate the analytics spreadsheet

## Resources created by main.tf:
- Buckets:
    - `md-poc-playground2-function `
        - bucket used by the functions.
        - Functions are defined in `main.py`, kept in the `md-poc-playground2-function` bucket as a zip file
    - `mobilitydata-gtfs-validation-results2`
        - Bucket to contain the results of the validation with 4.1.0 and 4.2.0
        - In reports/_date_/_md5_/_feedname_/report-output-4.X.0
        - One folder per feed, containing reports for 4.1.0 and 4.2.0
- Functions:
    - See https://console.cloud.google.com/functions/list?project=md-poc-playground2
    - `getGtfsCatalogFunction`
        - A function used to run functions in main.py.
        - Right now only 1 entrypoint: get_request - See `getGtfsCatalogFunction.entry_point`
        - This function essentially reads the csv file.

- Artifact Registry - Docker
    - See https://console.cloud.google.com/artifacts?project=md-poc-playground2
    - Create the `gtfs-validator-registry` docker registry that will contain the docker image that is used to extract data from the csv file

- Workflows:
    - See https://console.cloud.google.com/workflows?project=md-poc-playground2
    - `workflow-gtfs-catalog-validator2`
        - runs `workflow-gtfs-catalog-validator.yaml`
        - Calls the function to read the .csv
        - Repetitively call workflow `workflow-gtfs-validator2`
    - `workflow-gtfs-validator2`
        - runs `workflow-gtfs-validator.yaml`
        - Repetitively called by `workflow-gtfs-catalog-validator.yaml`
        - Starts a docker container that runs `gtfs-validator-reporter-entry.sh`


- Security
    - A service account is created: `containers-sa@md-poc-playground2.iam.gserviceaccount.com`
    - See https://console.cloud.google.com/iam-admin/serviceaccounts/details/112148817719881968910?project=md-poc-playground2
    - See resource `google_service_account` in main.tf
    - Apparently this also created an email address that used to refer to the service account.
    - The service account container-sa is given log permissions.
    - And run.admin role (which seems to broad, run.developer might be more appropriate)
        - This will let the function run the main.py script.
    - And the roles/iam.serviceAccountUser role.
        - This will let me the user act as a service account. E.g. if I run a workflow as myself, I might impersonate the service account for some operations
        - And access to the mobilitydata-gtfs-validation-results2 bucket

- Bigquery
    - Create a bigquery dataset (`gtfs-results-dataset`) and table (`validation_results_table`) that will be used to read all the `report-summary-nd.json` and put in a DB.
    - Then a specifiy query will be used to create the data to show in the spreadsheet

## Running the analytics
- Once `main.tf` has created everything, the processing is triggered by running the `workflow-gtfs-catalog-validator2` workflow.
    - Input:
```
{
  "concurrency_limits": 20,
  "results_bucket_path": "gs://mobilitydata-gtfs-validation-results2/reports"
}
```
- See [this](https://console.cloud.google.com/workflows/workflow/us-central1/workflow-gtfs-catalog-validator2/execution/d881ebd2-a17d-48f8-879d-1594b249e987?project=md-poc-playground2) as an example.
- If it works properly, this should create all the folders in the [mobilitydata-gtfs-validation-results2 bucket](https://console.cloud.google.com/storage/browser/mobilitydata-gtfs-validation-results2;tab=objects?forceOnBucketsSortingFiltering=true&project=md-poc-playground2&prefix=&forceOnObjectsSortingFiltering=false) with the validation results for 4.1.0 and 4.2.0
- Then convert the `reports-summary.json` file to a form that can be ingested by bigquery (`report-summary-nd.json`)
    - This is done by running the `convert-to-ndjson.sh` on your mac terminal.
    - `./convert-to-ndjson.sh -bp mobilitydata-gtfs-validation-results2/reports/ -f report-summary.json`
    - If this works properly there should be a `report-summary-nd.json` file for every `report-summary.json` that was present in the bucket.
- Transfer all the summary data to the big query.
    - Crete a new data transfer.  See [this](https://console.cloud.google.com/bigquery/transfers/locations/us/configs/65a3ad7f-0000-223d-bf0f-582429d034a0/edit?project=md-poc-playground2)
    - Cloud storage URI must be: `gs://mobilitydata-gtfs-validation-results2/reports/2023-11-17T17:07/5a286419-c6b9-403a-9d4e-47322ea48b7a/*/*/report-summary-nd.json`
    - This reads all the `report-summary-nd.json` files.
    - It's important to select `Ignore unknown values`
    - Run the transfer. This should populate the Bigquery. Verify by going to gtfs-results and select [preview](https://console.cloud.google.com/bigquery?project=md-poc-playground2&ws=!1m5!1m4!4m3!1smd-poc-playground2!2sgtfs_results_dataset!3sgtfs_results)
- Query the bigquery to create a spreadsheet with the proper columns.
- Here is the contents of the query:
```
WITH 
-- Notices that are present in the new validator by datasetId and code
new_validator AS (
  SELECT
    validator.datasetId AS datasetId,
    new_notices.code AS code,
    SUM(new_notices.totalNotices) AS counter,
    new_notices.severity
  FROM
    `md-poc-playground2.gtfs_results_dataset.gtfs_results`,
    UNNEST(notices) AS new_notices
  WHERE
    validator.version = '4.2.0'
  GROUP BY
    datasetId, code, severity
  order by datasetId
),

-- Notices that are present in the previous validator by datasetId and code
old_validator AS (
  SELECT
    validator.datasetId AS datasetId,
    new_notices.code AS code,
    SUM(new_notices.totalNotices) AS counter,
    new_notices.severity
  FROM
    `md-poc-playground2.gtfs_results_dataset.gtfs_results`,
    UNNEST(notices) AS new_notices
  WHERE
    validator.version = '4.1.0'
  GROUP BY
    datasetId, code, severity
  order by datasetId
),

notice_difference AS (
  SELECT
    datasetId,
    code,
    new_validator.counter new_validator_counter,
    old_validator.counter old_validator_counter,
    new_validator.counter - old_validator.counter AS difference,
    new_validator.severity
  FROM
    new_validator
  JOIN
    old_validator
  USING (datasetId, code)
),

only_on_new_release as (
    SELECT
    validator.datasetId AS datasetId,
    new_notices.code AS code,
    SUM(new_notices.totalNotices) AS counter,
    new_notices.severity
  FROM
    `md-poc-playground2.gtfs_results_dataset.gtfs_results`,
    UNNEST(notices) AS new_notices
  WHERE
    validator.version = '4.2.0'
  AND NOT EXISTS (
      SELECT 1
      FROM
        `md-poc-playground2.gtfs_results_dataset.gtfs_results` as subquery,
        UNNEST(subquery.notices) AS old_notices
      WHERE
        subquery.validator.version = '4.1.0'
        AND subquery.validator.datasetId = validator.datasetId
        AND old_notices.code = new_notices.code)    
  GROUP BY
    datasetId, code, severity
  order by datasetId
),

only_on_previous_release as (
    SELECT
    validator.datasetId AS datasetId,
    new_notices.code AS code,
    SUM(new_notices.totalNotices) AS counter,
    new_notices.severity
  FROM
    `md-poc-playground2.gtfs_results_dataset.gtfs_results`,
    UNNEST(notices) AS new_notices
  WHERE
    validator.version = '4.1.0'
  AND NOT EXISTS (
      SELECT 1
      FROM
        `md-poc-playground2.gtfs_results_dataset.gtfs_results` as subquery,
        UNNEST(subquery.notices) AS old_notices
      WHERE
        subquery.validator.version = '4.2.0'
        AND subquery.validator.datasetId = validator.datasetId
        AND old_notices.code = new_notices.code)    
  GROUP BY
    datasetId, code, severity
  order by datasetId
)

SELECT
  datasetId,
  code,
  severity,
  CASE
    WHEN notice_difference.difference > 0
      THEN notice_difference.difference
      ELSE 0
      END
      AS `New notices`,  
  CASE
    WHEN notice_difference.difference < 0
      THEN notice_difference.difference
      ELSE 0
      END
      AS `Dropped notices`,
  notice_difference.new_validator_counter AS `Total 4_2_0`,
  notice_difference.old_validator_counter AS `Total 4_1_0`,
FROM
  notice_difference
WHERE notice_difference.difference != 0

UNION ALL
SELECT 
  only_on_new_release.datasetId AS datasetId,
  only_on_new_release.code AS code,
  only_on_new_release.severity,
  only_on_new_release.counter AS `New notices`,
  0 AS `Dropped notices`,
  only_on_new_release.counter AS `Total 4_2_0`,
  0 AS `Total 4_1_0`
FROM only_on_new_release

UNION ALL
SELECT 
  only_on_previous_release.datasetId AS datasetId,
  only_on_previous_release.code AS code,
  only_on_previous_release.severity,
  0 AS `New notices`,
  only_on_previous_release.counter AS `Dropped notices`,
  0 AS `Total 4_2_0`,
  only_on_previous_release.counter AS `Total 4_1_0`
FROM only_on_previous_release

ORDER BY datasetId
````
- Execute the query.
- In Query results, select `Explore Data` -> `Explore with sheets`
- This shold open a google sheet with the analytics data.