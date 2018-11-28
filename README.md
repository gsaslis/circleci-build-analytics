# CircleCI Build Analytics

A solution for better analytics for CircleCI builds, powered by Elasticsearch + Kibana. 

# Requirements 

* [JQ](https://stedolan.github.io/jq/) - the awesome command-line tool for manipulating JSON. (Needed for credit calculations in CircleCI exported data)
* [json-to-ndjson](https://www.npmjs.com/package/json-to-ndjson) - for converting the data to be indexed into Elasticsearch
* `curl` - for invoking CircleCI and Elasticsearch APIs
* `perl` - for some "a la `sed`" string manipulation, when preparing data for indexing into Elasticsearch.

# How it works

This project basically consists of a `Makefile` that orchestrates:

1. downloading data from the CircleCI API and storing it locally -- with `make download`
2. calculating credits for each of the builds, based on resource class 
3. converting data for indexing and uploading into Elasticsearch (through their 
[Bulk API](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html) ) -- with `make index`

# Usage 

```
make download
# this should take a while, as CircleCI imposes a limit of only fetching 100 records per batch
# ... 
# your builds folder should now have a bunch of files with all the info circleci makes available
make index
```

If something went wrong and you want to start over, `make clean` will probably help. 

# Contributing 

Please feel free to raise Issues and Pull Requests if you feel this can be improved in any way. 
