SHELL := /bin/bash
ALL: build
.PHONY: build test push

PARENT_IMAGE := php
IMAGE := chialab/php
VERSION ?= latest
PHP_VERSION = $(firstword $(subst -, ,$(VERSION)))

# Extensions.
EXTENSIONS := \
	bcmath \
	bz2 \
	calendar \
	exif \
	iconv \
	intl \
	gd \
	ldap \
	mbstring \
	memcached \
	mysqli \
	OPcache \
	pdo_mysql \
	pdo_pgsql \
	pgsql \
	redis \
	soap \
	xsl \
	zip \
	sockets
ifeq (,$(findstring $(PHP_VERSION), 7.2 7.3 7.4 latest))
	# Add more extensions to PHP < 7.2.
	EXTENSIONS += mcrypt
endif
ifeq (,$(findstring $(PHP_VERSION), 7.0 7.1 7.2 7.3 7.4 latest))
	# Add more extensions to 5.x series images.
	EXTENSIONS += mysql
else
	EXTENSIONS += pdo_sqlsrv \
	   	sqlsrv
endif

build:
	@echo " =====> Building $(IMAGE):$(VERSION)..."
	@dir="$(subst -,/,$(VERSION))"; \
	if [[ "$(VERSION)" == 'latest' ]]; then \
		dir='.'; \
	fi; \
	docker image build --quiet -t $(IMAGE):$(VERSION) $${dir}

test:
	@echo -e "=====> Testing loaded extensions... \c"
	@if [[ -z `docker image ls $(IMAGE) | grep "\s$(VERSION)\s"` ]]; then \
		echo 'FAIL [Missing image!!!]'; \
		exit 1; \
	fi
	@modules=`docker container run --rm $(IMAGE):$(VERSION) php -m`; \
	for ext in $(EXTENSIONS); do \
		if [[ "$${modules}" != *"$${ext}"* ]]; then \
			echo "FAIL [$${ext}]"; \
			exit 1; \
		fi \
	done
	@if [[ "$(VERSION)" == *'-apache' ]]; then \
		apache=`docker container run --rm $(IMAGE):$(VERSION) apache2ctl -M 2> /dev/null`; \
		if [[ "$${apache}" != *'rewrite_module'* ]]; then \
			echo 'FAIL [mod_rewrite]'; \
			exit 1; \
		fi \
	fi
	@if [[ -z `docker container run --rm $(IMAGE):$(VERSION) composer --version 2> /dev/null | grep '^Composer version 2\.[0-9][0-9]*'` ]]; then \
		echo 'FAIL [Composer 2]'; \
		exit 1; \
	fi
	@if [[ -z `docker container run --rm $(IMAGE):$(VERSION) composer2 --version 2> /dev/null | grep '^Composer version 2\.[0-9][0-9]*'` ]]; then \
		echo 'FAIL [Composer 2]'; \
		exit 1; \
	fi
	@if [[ -z `docker container run --rm $(IMAGE):$(VERSION) composer1 --version 2> /dev/null | grep '^Composer version 1\.[0-9][0-9]*'` ]]; then \
		echo 'FAIL [Composer 1]'; \
		exit 1; \
	fi
	@if [[ -z `docker container run --rm $(IMAGE):$(VERSION) composer1 global show 2> /dev/null | grep '^hirak/prestissimo [0-9][0-9]*\.[0-9][0-9]*'` ]]; then \
		echo 'FAIL [Composer 1 plugin - prestissimo]'; \
		exit 1; \
	fi
	@echo 'OK'

push:
	docker image push $(IMAGE):$(VERSION)
