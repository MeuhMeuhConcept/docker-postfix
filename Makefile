.PHONY: help install start stop
.DEFAULT_GOAL := help

build:
	docker build -t meuhmeuhconcept/postfix .

install: docker-compose.yml ## Install

docker-compose.yml:
	cp docker-compose.yml.dist $@

start: install ## Run with docker stack
	docker stack deploy --compose-file docker-compose.yml postfix

stop: install ## Stop service
	docker stack rm postfix

help:
	@grep -E '^[a-zA-Z_-.]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
