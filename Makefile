SHELL := /bin/bash

CONFIG ?= config.env

.PHONY: help check deploy status logs restart

help:
	@printf '%s\n' \
	  'make check   - validate script syntax' \
	  'make deploy  - copy the site to the phone' \
	  'make status  - check remote services' \
	  'make logs    - show the cloudflared log' \
	  'make restart - restart the Termux stack'

check:
	@bash -n boot-start-services.sh scripts/*.sh
	@printf '%s\n' 'Syntax OK'

deploy:
	@CONFIG_FILE=$(CONFIG) bash scripts/deploy.sh

status:
	@CONFIG_FILE=$(CONFIG) bash scripts/status.sh

logs:
	@CONFIG_FILE=$(CONFIG) bash scripts/logs.sh

restart:
	@CONFIG_FILE=$(CONFIG) bash scripts/restart-services.sh
