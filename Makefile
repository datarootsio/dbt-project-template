ORG ?= datarootsio
DBT_VERSION ?= 1.8.0
ADAPTER ?= snowflake
IMAGE ?= ghcr.io/$(ORG)/dbt-runtime-$(ADAPTER):$(DBT_VERSION)

TARGET ?= dev
SELECTOR ?= staging

SNOWFLAKE_ACCOUNT ?= dummy
SNOWFLAKE_USER ?= dummy
SNOWFLAKE_PASSWORD ?= dummy
SNOWFLAKE_ROLE ?= dummy
SNOWFLAKE_DATABASE ?= dummy
SNOWFLAKE_WAREHOUSE ?= dummy
SNOWFLAKE_SCHEMA ?= dummy

define DBT_DOCKER_ENV
  -e DBT_ADAPTER=$(ADAPTER)   -e DBT_TARGET=$(TARGET)   -e DBT_PROFILES_DIR=/profiles   -e DBT_RENDER_PROFILES=1   -e SNOWFLAKE_ACCOUNT=$(SNOWFLAKE_ACCOUNT)   -e SNOWFLAKE_USER=$(SNOWFLAKE_USER)   -e SNOWFLAKE_PASSWORD=$(SNOWFLAKE_PASSWORD)   -e SNOWFLAKE_ROLE=$(SNOWFLAKE_ROLE)   -e SNOWFLAKE_DATABASE=$(SNOWFLAKE_DATABASE)   -e SNOWFLAKE_WAREHOUSE=$(SNOWFLAKE_WAREHOUSE)   -e SNOWFLAKE_SCHEMA=$(SNOWFLAKE_SCHEMA)
endef

.PHONY: deps parse build test clean

deps:
	docker run --rm -v "$$PWD:/app" $(DBT_DOCKER_ENV) $(IMAGE) deps

parse:
	docker run --rm -v "$$PWD:/app" $(DBT_DOCKER_ENV) $(IMAGE) parse

build:
	docker run --rm -v "$$PWD:/app" $(DBT_DOCKER_ENV) $(IMAGE) build --selector $(SELECTOR) --target $(TARGET)

test:
	docker run --rm -v "$$PWD:/app" $(DBT_DOCKER_ENV) $(IMAGE) test --target $(TARGET)

clean:
	rm -rf target dbt_packages logs
