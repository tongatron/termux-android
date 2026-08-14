SHELL := /bin/bash

CONFIG ?= config.env

.PHONY: help check deploy status logs restart

help:
	@printf '%s\n' \
	  'make check   - controlla la sintassi degli script' \
	  'make deploy  - copia il sito sul telefono' \
	  'make status  - verifica i servizi remoti' \
	  'make logs    - mostra il log di cloudflared' \
	  'make restart - rilancia lo stack Termux'

check:
	@bash -n boot-start-services.sh scripts/*.sh
	@printf '%s\n' 'Sintassi OK'

deploy:
	@CONFIG_FILE=$(CONFIG) bash scripts/deploy.sh

status:
	@CONFIG_FILE=$(CONFIG) bash scripts/status.sh

logs:
	@CONFIG_FILE=$(CONFIG) bash scripts/logs.sh

restart:
	@CONFIG_FILE=$(CONFIG) bash scripts/restart-services.sh
