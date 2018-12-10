
default: download index

.PHONY: index json-to-ndjson jq index download

export GITHUB_USERNAME := 3scale
export GITHUB_REPONAME := porta

export ES_PROTOCOL := http
export ES_HOST := localhost
export ES_PORT := 9200
export ES_INDEX := circleci_builds
export ES_DOC_TYPE := build

JSON_2_NDJSON := $(shell command -v json-to-ndjson 2> /dev/null)
JQ := $(shell command -v jq 2> /dev/null)

index: ## Uploads to elasticsearch, using Bulk API (expects ndjson file)
index: all_builds.ndjson
	echo "Indexing to: $$ES_PROTOCOL://$$ES_HOST:$$ES_PORT/$$ES_INDEX/$$ES_DOC_TYPE/_bulk/" ; \
	curl -H 'Content-Type: application/json' -XPUT -d' { "settings" : { "mapping" : { "total_fields" : { "limit" : "100000" } } } }' $$ES_PROTOCOL://$$ES_HOST:$$ES_PORT/$$ES_INDEX/
	curl -v -H "Content-Type: application/x-ndjson" -X POST --data-binary @all_builds.ndjson $$ES_PROTOCOL://$$ES_HOST:$$ES_PORT/$$ES_INDEX/_bulk/

all_builds.ndjson: # Converts json to ndjson AND THEN adds the extra line Elasticsearch Bulk API expects.
all_builds.ndjson: all_builds.json json-to-ndjson
	json-to-ndjson all_builds.json -o all_builds.ndjson
	perl -i -pe 's/{"compare"/{ "index" : { "_index" : "$$ENV{'ES_INDEX'}" , "_type" : "build" } } \n {"compare"/g' all_builds.ndjson

all_builds.json: # Aggregates all batches into one
all_builds.json:
	cat builds/*.json > all_builds.json

json-to-ndjson: # Ensures json-to-ndjson package is installed
ifndef JSON_2_NDJSON
    $(error 'json-to-ndjson is not available. Consider installing with: `npm install -g json-to-ndjson`')
endif

jq: # Ensures jq package is installed
ifndef JQ
    $(error 'JQ is not available and necessary! Please install to continue.')
endif

download: builds/*.json

builds/*.json: # Fetches all builds information from circleci, in batches.
builds/*.json: builds
	curl -L "https://circleci.com/api/v1.1/project/github/$$GITHUB_USERNAME/$$GITHUB_REPONAME/?limit=1&filter=completed&offset=0" | jq '.[].build_num' > last_build.json
	export LAST_BUILD=$$(cat last_build.json) ; \
	echo $$LAST_BUILD ; \
	number=0 ; while [[ $$number -le $$LAST_BUILD ]] ; do \
		echo "Fetching 100 builds from offset $$number" ; \
		curl -L "https://circleci.com/api/v1.1/project/github/$$GITHUB_USERNAME/$$GITHUB_REPONAME/?limit=100&filter=completed&offset=$$number" | jq -f credits.jq > builds/$$number.json ; \
		((number = number + 100)) ; \
	done

builds:
	mkdir builds

clean:
	rm -rf builds/