ENV_NAME ?= dev

SSL_PROXY=true
DB_HOST="mysql-0.mysql"


ifeq ($(ENV_NAME), dev)
SITE_URL="https://moodle-950003-dev.apps.silver.devops.gov.bc.ca"
endif

ifeq ($(ENV_NAME), test)
SITE_URL="https://moodle-950003-test.apps.silver.devops.gov.bc.ca"
endif

ifeq ($(ENV_NAME), prod)
SITE_URL="https://moodle-950003-prod.apps.silver.devops.gov.bc.ca"
endif

define ENV_FILE_DATA
SSL_PROXY = "$(SSL_PROXY)"
DB_HOST = "$(DB_HOST)"
SITE_URL = "$(SITE_URL)"
endef
export ENV_FILE_DATA


print-env:
	@echo ENV_NAME=$(ENV_NAME)
	@echo
	@echo ./.env.${ENV_NAME}:
	@echo "$$ENV_FILE_DATA"
	@echo



write-config:
	@echo "$$ENV_FILE_DATA" > ./.env.$(ENV_NAME)

