# Copyright 2015 The Prometheus Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

GO           ?= go
GOFMT        ?= $(GO)fmt
FIRST_GOPATH := $(firstword $(subst :, ,$(shell $(GO) env GOPATH)))
PROMU        := $(FIRST_GOPATH)/bin/promu
STATICCHECK  := $(FIRST_GOPATH)/bin/staticcheck
pkgs          = $(shell $(GO) list ./... | grep -v /vendor/)

PREFIX                  ?= $(shell pwd)
BIN_DIR                 ?= $(shell pwd)
# Private repo.
DOCKER_IMAGE_NAME       ?= gcr.io/stackdriver-prometheus/stackdriver-prometheus-sidecar
DOCKER_IMAGE_TAG        ?= $(subst /,-,$(shell git rev-parse --abbrev-ref HEAD))

ifdef DEBUG
	bindata_flags = -debug
endif

all: format staticcheck build test

style:
	@echo ">> checking code style"
	@! $(GOFMT) -d $(shell find . -path ./vendor -prune -o -name '*.go' -print) | grep '^'

check_license:
	@echo ">> checking license header"
	@./scripts/check_license.sh

# TODO(fabxc): example tests temporarily removed.
test-short:
	@echo ">> running short tests"
	@$(GO) test -short $(shell $(GO) list ./... | grep -v /vendor/ | grep -v examples)

test:
	@echo ">> running all tests"
	@$(GO) test $(shell $(GO) list ./... | grep -v /vendor/ | grep -v examples)

cover:
	@echo ">> running all tests with coverage"
	@$(GO) test -coverprofile=coverage.out $(shell $(GO) list ./... | grep -v /vendor/ | grep -v examples)

format:
	@echo ">> formatting code"
	@$(GO) fmt $(pkgs)

vet:
	@echo ">> vetting code"
	@$(GO) vet $(pkgs)

staticcheck: $(STATICCHECK)
	@echo ">> running staticcheck"
	@$(STATICCHECK) $(pkgs)

build: promu
	@echo ">> building binaries"
	@$(PROMU) build --prefix $(PREFIX)

build-linux-amd64: promu
	@echo ">> building linux amd64 binaries"
	@GOOS=linux GOARCH=amd64 $(PROMU) build --prefix $(PREFIX)

tarball: promu
	@echo ">> building release tarball"
	@$(PROMU) tarball --prefix $(PREFIX) $(BIN_DIR)

docker: build-linux-amd64
	@echo ">> building docker image"
	@docker build -t "$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)" .

push: test docker
	@echo ">> pushing docker image"
	docker push "$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)"

assets:
	@echo ">> writing assets"
	@$(GO) get -u github.com/jteeuwen/go-bindata/...
	@go-bindata $(bindata_flags) -pkg ui -o web/ui/bindata.go -ignore '(.*\.map|bootstrap\.js|bootstrap-theme\.css|bootstrap\.css)'  web/ui/templates/... web/ui/static/...
	@$(GO) fmt ./web/ui

promu:
	@echo ">> fetching promu"
	@GOOS=$(shell uname -s | tr A-Z a-z) \
	GOARCH=$(subst x86_64,amd64,$(patsubst i%86,386,$(shell uname -m))) \
	GO="$(GO)" \
	$(GO) get -u github.com/prometheus/promu

$(FIRST_GOPATH)/bin/staticcheck:
	@GOOS= GOARCH= $(GO) get -u honnef.co/go/tools/cmd/staticcheck

.PHONY: all style check_license format build test vet assets tarball docker promu staticcheck $(FIRST_GOPATH)/bin/staticcheck
