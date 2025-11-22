SHELL = /bin/bash

CONTAINER_RUNTIME := $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null)
IMAGE_NAME := starvz-shell
CONTAINER_NAME := starvz-shell

.DEFAULT_GOAL := help
.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build:  ## build the starvz helper contianer
	@$(CONTAINER_RUNTIME) build -f Containerfile -t $(IMAGE_NAME) .

shell: build  ## shell into the starvz helper container
	@$(CONTAINER_RUNTIME) run --rm -it \
		-v $(CURDIR):/workspace:Z \
		--name $(CONTAINER_NAME) \
		$(IMAGE_NAME)
