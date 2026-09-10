# Copyright © 2024 Intel Corporation. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

.PHONY: build-benchmark-docker docs docs-builder-image build-docs serve-docs clean \
        install-native start-native stop-native run-api-native

MKDOCS_IMAGE ?= asc-mkdocs
RESULTS_DIR ?= /tmp/results

build-benchmark-docker:
	cd docker && $(MAKE) build-all

install-native:
	bash live-metrics/native/install_deps.sh

start-native: install-native
	RESULTS_DIR=$(RESULTS_DIR) bash live-metrics/native/start_collectors.sh

stop-native:
	RESULTS_DIR=$(RESULTS_DIR) bash live-metrics/native/stop_collectors.sh

run-api-native:
	RESULTS_DIR=$(RESULTS_DIR) python3 live-metrics/metrics_api.py

docs: clean-docs
	mkdocs build
	mkdocs serve -a localhost:8008

docs-builder-image:
	docker build \
		-f Dockerfile.docs \
		-t $(MKDOCS_IMAGE) \
		.

build-docs: docs-builder-image
	docker run --rm \
		-v $(PWD):/docs \
		-w /docs \
		$(MKDOCS_IMAGE) \
		build

serve-docs: docs-builder-image
	docker run --rm \
		-it \
		-p 8008:8000 \
		-v $(PWD):/docs \
		-w /docs \
		$(MKDOCS_IMAGE)

clean:
	docker rm -f $(docker ps -aq)