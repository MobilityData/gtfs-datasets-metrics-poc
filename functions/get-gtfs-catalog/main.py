# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import json
import pandas as pd

#####################################################################################
# This GCP function reads the latest dataset versions on the Mobility Database Catalogs.
# Made for Python 3.9. Requires the modules listed in requirements.txt.
#####################################################################################

CATALOGS_CSV = "https://storage.googleapis.com/storage/v1/b/mdb-csv/o/sources.csv?alt=media"
MDB_SOURCE_ID = "mdb_source_id"
COUNTRY = "location.country_code"
SUBDIVISION = "location.subdivision_name"
MUNICIPALITY = "location.municipality"
PROVIDER = "urls.latest"
LATEST_URL = "urls.latest"

DATA_TYPE = "data_type"
GTFS = "gtfs"
URL_PREFIX = "https://storage.googleapis.com/storage/v1/b/mdb-latest/o/"
URL_SUFFIX = ".zip?alt=media"

EXPORT_FIELDS = [MDB_SOURCE_ID, COUNTRY, SUBDIVISION, MUNICIPALITY, PROVIDER, LATEST_URL]


def get_gtfs_datasets():
    """Reads the GTFS datasets information from  the latest URLs from the Mobility Database catalogs.
    :return: An array containing a dictionary with the datasets information with the format
    {
        "mdb_source_id": 727,
        "location.country_code": "CA",
        "location.subdivision_name": "Ontario",
        "location.municipality": "Toronto",
        "urls.latest": "https://storage.googleapis.com/storage/v1/b/mdb-latest/o/ca-ontario-go-transit-gtfs-727.zip?alt=media"
        "source_key" : "ca-ontario-go-transit-gtfs-727"
    }
    """
    catalogs = pd.read_csv(CATALOGS_CSV)
    result = []
    catalogs_gtfs = catalogs[catalogs[DATA_TYPE] == GTFS]
    for index, dataset in catalogs_gtfs.iterrows():
        item = {
            "source_key": dataset[LATEST_URL].replace(URL_PREFIX, "").replace(URL_SUFFIX, "")
            if dataset[LATEST_URL] == dataset[LATEST_URL] else
            dataset[MDB_SOURCE_ID]
        }
        for field in EXPORT_FIELDS:
            item[field] = dataset[field] if dataset[field] == dataset[field] else ""
        result.append(item)
    return result


def get_request(request):
    """Cloud function to read the GTFS datasets information from  the latest URLs from the Mobility Database catalogs.
    Args:
        request (flask.Request): HTTP request object.
    Returns:
    {
        "mdb_source_id": 727,
        "location.country_code": "CA",
        "location.subdivision_name": "Ontario",
        "location.municipality": "Toronto",
        "urls.latest": "https://storage.googleapis.com/storage/v1/b/mdb-latest/o/ca-ontario-go-transit-gtfs-727.zip?alt=media"
    }
    """
    result = get_gtfs_datasets()
    print("Returning datasets count=" + str(len(result)))
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
    }
    return json.dumps(result), 200, headers
    # return json.dumps(result)


if __name__ == '__main__':
    print(get_request({}))
