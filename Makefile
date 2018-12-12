
default: update

.PHONY: index json-to-ndjson jq curl

export GITHUB_USERNAME := 3scale
export GITHUB_REPONAME := porta

export ES_PROTOCOL := http
export ES_HOST := localhost
export ES_PORT := 9200
export ES_PATH := _bulk
export ES_INDEX := circleci_builds
export ES_DOC_TYPE := build

JSON_2_NDJSON := $(shell command -v json-to-ndjson 2> /dev/null)
JQ := $(shell command -v jq 2> /dev/null)
CURL := $(shell command -v curl 2> /dev/null)

index: ## Uploads to elasticsearch, using Bulk API (expects ndjson file)
index: curl
	echo "Will be indexing to: $$ES_PROTOCOL://$$ES_HOST:$$ES_PORT/$$ES_INDEX/$$ES_DOC_TYPE/$$ES_PATH" ; \
	curl -H 'Content-Type: application/json' -XPUT -d' { "settings" : { "mapping" : { "total_fields" : { "limit" : "100000" } } } }' $$ES_PROTOCOL://$$ES_HOST:$$ES_PORT/$$ES_INDEX/

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

update: curl data/latest_build_number_available data/previous_update_build_number index
	export LATEST_BUILD=$$(cat data/latest_build_number_available) ; \
	export PREVIOUS_RUN=$$(cat data/previous_update_build_number) ; \
	((number = $$PREVIOUS_RUN + 1)) ; \
	while [[ $$number -lt $$LATEST_BUILD ]] ; do \
		inc=100; \
		if [ $$(($$number + $$inc)) -gt $$LATEST_BUILD ]; then \
			((inc = $$LATEST_BUILD - $$number )); \
		fi; \
		echo "Fetching $$inc builds from offset $$number" ; \
		export LIMIT=$$inc; \
		export OFFSET=$$number; \
		$(MAKE) builds/$$number.ndjson ; \
		curl -v -H "Content-Type: application/x-ndjson" -X POST --data-binary @builds/$$number.ndjson $$ES_PROTOCOL://$$ES_HOST:$$ES_PORT/$$ES_INDEX/$$ES_PATH ; \
		((number = number + inc)) ; \
		echo $$number > data/previous_update_build_number ; \
	done

builds/%.json: # Fetches all builds information from circleci, in batches.
builds/%.json: curl jq builds
	curl -L "https://circleci.com/api/v1.1/project/github/$$GITHUB_USERNAME/$$GITHUB_REPONAME/?limit=$$LIMIT&filter=completed&offset=$$OFFSET" | jq -f credits.jq > builds/$$OFFSET.json ; \

builds/%.ndjson: builds/%.json json-to-ndjson
	json-to-ndjson $< -o $@; \
	perl -i -pe 's/{"compare"/{ "index" : { "_index" : "$$ENV{'ES_INDEX'}" , "_type" : "build" } } \n {"compare"/g' $@; \


data/latest_build_number_available: curl
	curl -L "https://circleci.com/api/v1.1/project/github/$$GITHUB_USERNAME/$$GITHUB_REPONAME/?limit=1&filter=completed&offset=0" | jq '.[].build_num' > data/latest_build_number_available

builds:
	mkdir -p builds

clean:
	rm -rf builds/
	rm data/latest_build_number_available