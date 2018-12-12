
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
CURL := $(shell command -v curl 2> /dev/null)

index: ## Uploads to elasticsearch, using Bulk API (expects ndjson file)
index: all_builds.ndjson curl
	echo "Indexing to: $$ES_PROTOCOL://$$ES_HOST:$$ES_PORT/$$ES_INDEX/$$ES_DOC_TYPE/_bulk/" ; \
	curl -H 'Content-Type: application/json' -XPUT -d' { "settings" : { "mapping" : { "total_fields" : { "limit" : "100000" } } } }' $$ES_PROTOCOL://$$ES_HOST:$$ES_PORT/$$ES_INDEX/
	curl -v -H "Content-Type: application/x-ndjson" -X POST --data-binary @all_builds.ndjson $$ES_PROTOCOL://$$ES_HOST:$$ES_PORT/$$ES_INDEX/_bulk/
	cp data/latest_build_number_available data/previous_update_build_number

all_builds.ndjson: # Converts json to ndjson AND THEN adds the extra line Elasticsearch Bulk API expects.
all_builds.ndjson: all_builds.json json-to-ndjson
	json-to-ndjson all_builds.json -o all_builds.ndjson
	perl -i -pe 's/{"compare"/{ "index" : { "_index" : "$$ENV{'ES_INDEX'}" , "_type" : "build" } } \n {"compare"/g' all_builds.ndjson

all_builds.json: # Aggregates all batches into one
all_builds.json:
	cat builds/*.json > all_builds.json

json-to-ndjson: # Ensures json-to-ndjson package is installed
ifndef JSON_2_NDJSON
    $(error 'json-to-ndjson is not available and is required to proceed. Consider installing with: `npm install -g json-to-ndjson`')
endif

jq: # Ensures jq package is installed
ifndef JQ
    $(error 'JQ is not available and is required to proceed! Please install to continue.')
endif

curl: # Ensures curl package is installed
ifndef CURL
    $(error 'curl is not available and is required to proceed! Please install to continue.')
endif

download: builds/*.json

builds/*.json: # Fetches all builds information from circleci, in batches.
builds/*.json: jq builds data/latest_build_number_available data/previous_update_build_number curl
	export LATEST_BUILD=$$(cat data/latest_build_number_available) ; \
	export PREVIOUS_RUN=$$(cat data/previous_update_build_number) ; \
	((number = $$PREVIOUS_RUN + 1)) ; \
	while [[ $$number -lt $$LATEST_BUILD ]] ; do \
		inc=100; \
		if [ $$(($$number + $$inc)) -gt $$LATEST_BUILD ]; then \
			((inc = $$LATEST_BUILD - $$number )); \
		fi; \
		echo "Fetching $$inc builds from offset $$number" ; \
		curl -L "https://circleci.com/api/v1.1/project/github/$$GITHUB_USERNAME/$$GITHUB_REPONAME/?limit=$$inc&filter=completed&offset=$$number" | jq -f credits.jq > builds/$$number.json ; \
		((number = number + inc)) ; \
		echo $$number; \
	done

data/latest_build_number_available: curl
	curl -L "https://circleci.com/api/v1.1/project/github/$$GITHUB_USERNAME/$$GITHUB_REPONAME/?limit=1&filter=completed&offset=0" | jq '.[].build_num' > data/latest_build_number_available

builds:
	mkdir -p builds

clean:
	rm -rf builds/
	rm data/latest_build_number_available