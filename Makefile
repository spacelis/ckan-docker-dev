SHELL := /bin/bash
VERSION := v0.1
IMAGENAME := spacelis/cdrc_repo
IMAGEID := $(shell docker images | awk '$$1 ~ "$(IMAGENAME)" { print $$3 }')
IMAGE := $(IMAGENAME):$(VERSION)
CONTAINERNAME := "ckan"
CONTAINERID := $(shell docker ps -a | awk '$$2 ~ "$(IMAGE)" { print $$1 }')

DBNAME := db
DBTEST := dbtest
DBIMAGE := spacelis/ckan_postgresql
SOLRNAME := solr
SOLRTEST := solrtest
SOLRIMAGE := spacelis/ckan_solr

ps:
	@echo $(CONTAINERID)

image:
	@if [ -z $(IMAGEID) ]; then docker build -t $(IMAGE) .; fi

run: image dbrun solrrun
	@if [ -z $(CONTAINERID) ]; then echo "Starting CKAN..."; docker run -d -p 80:80 --link db:db --link solr:solr --name $(CONTAINERNAME) $(IMAGE); fi

rm:
	@if [ $(CONTAINERID) ]; then echo "Removing CKAN..."; docker rm $(CONTAINERNAME); fi

stop:
	@if [ -z  `docker ps | awk '$$NF ~ "^$(CONTAINERID)$$" { print $$1 }'` ]; then echo "Stopping CKAN..."; docker stop $(CONTAINERNAME); fi

rmi: stop rm 
	@if [ $(IMAGEID) ]; then echo "Removing CKAN image..."; docker rmi $(IMAGEID); fi

dbrun:
	@if [ -z `docker ps -a | awk '$$NF ~ "^$(DBNAME)$$" { print $$1 }'` ]; then echo "Starting DB..."; docker run -d --name $(DBNAME) -p 5432:5432 $(DBIMAGE); fi
	@sleep 3

dbstop:
	@if [ `docker ps | awk '$$NF ~ "^$(DBNAME)$$" { print $$1 }'` ]; then echo "Stopping DB..."; docker stop db; fi

dbrm: dbstop
	@if [ `docker ps -a | awk '$$NF ~ "^$(DBNAME)$$" { print $$1 }'` ]; then echo "Removing DB..."; docker rm db; fi
	@sudo ./clear_docker_volumes

solrrun:
	@if [ -z `docker ps -a | awk '$$NF ~ "^$(SOLRNAME)$$" { print $$1 }'` ]; then echo "Starting SOLR..."; docker run -d --name $(SOLRNAME) $(SOLRIMAGE); fi
	@sleep 3

dbtest:
	@if [ -z `docker ps -a | awk '$$NF ~ "^$(DBTEST)$$" { print $$1 }'` ]; then echo "Starting DB (test)..."; docker run -d --name $(DBTEST) -p 5432:5432 $(DBIMAGE); fi
	@sleep 3

solrtest:
	@if [ -z `docker ps -a | awk '$$NF ~ "^$(SOLRTEST)$$" { print $$1 }'` ]; then echo "Starting SOLR (test)..."; docker run -d --name $(SOLRTEST) -p 8983:8983 $(SOLRIMAGE); fi
	@sleep 3

tests: solrtest dbtest
	@if [ `python -c "import sys; print sys.prefix.split('/')[-1].startswith('.')"` == "False" ]; then source ckan/.py27/bin/activate; fi && cd ckan && nosetests --ckan --reset-db --with-pylons=test-core.ini ckan/new_tests

figclean:
	@yes | fig rm
	sudo ./clear_docker_volumes
	docker rmi cdrcrepo_ckan:latest

.PHONY: image run rm stop rmi dbrun solrrun dummy tests
