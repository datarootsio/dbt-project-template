# dbt Project Template — container runtime execution
# ----------------------------------------------------
# How it works:
# - Choose an adapter (snowflake, fabric, …)
# - Provide adapter env vars via adapters/<adapter>/.env
# - Run dbt inside the matching runtime image:
#     ghcr.io/<ORG>/dbt-runtime-<adapter>:<DBT_VERSION>
#
# Common usage:
#   cp adapters/snowflake/env.example adapters/snowflake/.env
#   make pull ADAPTER=snowflake
#   make deps ADAPTER=snowflake
#   make parse ADAPTER=snowflake
#   make build ADAPTER=snowflake SELECTOR=daily TARGET=dev
#
# Power mode (any dbt cmd):
#   make dbt ADAPTER=snowflake CMD="run -s tag:daily --target prod"

ORG ?= datarootsio
DBT_VERSION ?= 1.8.0
ADAPTER ?= snowflake

IMAGE ?= ghcr.io/$(ORG)/dbt-runtime-$(ADAPTER):$(DBT_VERSION)

TARGET ?= dev
SELECTOR ?= staging

# Users create this from env.example and fill credentials/config
ENV_FILE ?= adapters/$(ADAPTER)/.env

# Extra arguments appended to dbt command (optional)
ARGS ?=

.PHONY: help envcheck pull deps parse build test clean dbt shell

help:
	@echo ""
	@echo "dbt template (containerized) commands:"
	@echo "  make pull  ADAPTER=snowflake"
	@echo "  make deps  ADAPTER=snowflake"
	@echo "  make parse ADAPTER=snowflake"
	@echo "  make build ADAPTER=snowflake SELECTOR=daily TARGET=dev"
	@echo "  make test  ADAPTER=snowflake TARGET=dev"
	@echo ""
	@echo "Power mode:"
	@echo "  make dbt ADAPTER=snowflake CMD=\"build --selector daily --target prod\""
	@echo ""
	@echo "Debug:"
	@echo "  make shell ADAPTER=snowflake"
	@echo ""

envcheck:
	@test -f $(ENV_FILE) || (echo "Missing $(ENV_FILE). Create it: cp adapters/$(ADAPTER)/env.example $(ENV_FILE)" && exit 1)

pull:
	docker pull $(IMAGE)

deps: envcheck
	docker run --rm \
	  -v "$$PWD:/app" \
	  --env-file $(ENV_FILE) \
	  -e DBT_TARGET=$(TARGET) \
	  -e DBT_PROFILES_DIR=/profiles \
	  -e DBT_RENDER_PROFILES=1 \
	  $(IMAGE) deps $(ARGS)

parse: envcheck
	docker run --rm \
	  -v "$$PWD:/app" \
	  --env-file $(ENV_FILE) \
	  -e DBT_TARGET=$(TARGET) \
	  -e DBT_PROFILES_DIR=/profiles \
	  -e DBT_RENDER_PROFILES=1 \
	  $(IMAGE) parse $(ARGS)

build: envcheck
	docker run --rm \
	  -v "$$PWD:/app" \
	  --env-file $(ENV_FILE) \
	  -e DBT_TARGET=$(TARGET) \
	  -e DBT_PROFILES_DIR=/profiles \
	  -e DBT_RENDER_PROFILES=1 \
	  $(IMAGE) build --selector $(SELECTOR) --target $(TARGET) $(ARGS)

test: envcheck
	docker run --rm \
	  -v "$$PWD:/app" \
	  --env-file $(ENV_FILE) \
	  -e DBT_TARGET=$(TARGET) \
	  -e DBT_PROFILES_DIR=/profiles \
	  -e DBT_RENDER_PROFILES=1 \
	  $(IMAGE) test --target $(TARGET) $(ARGS)

# Run any dbt command you want:
#   make dbt CMD="run -s tag:daily --target prod"
dbt: envcheck
	@test -n "$(CMD)" || (echo "Missing CMD. Example: make dbt CMD=\"run -s tag:daily\"" && exit 1)
	docker run --rm \
	  -v "$$PWD:/app" \
	  --env-file $(ENV_FILE) \
	  -e DBT_PROFILES_DIR=/profiles \
	  -e DBT_RENDER_PROFILES=1 \
	  $(IMAGE) $(CMD)

# Open a shell inside the runtime image with the project mounted
shell: envcheck
	docker run --rm -it \
	  -v "$$PWD:/app" \
	  --env-file $(ENV_FILE) \
	  -e DBT_PROFILES_DIR=/profiles \
	  -e DBT_RENDER_PROFILES=1 \
	  --entrypoint bash \
	  $(IMAGE)

clean:
	rm -rf target dbt_packages logs package-lock.yml
