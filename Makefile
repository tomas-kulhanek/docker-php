# Misc
IMAGE_PATH = ghcr.io/tomas-kulhanek/docker-php

.DEFAULT_GOAL = help
.PHONY        : help build push

## —— 🎵 🐳 The Symfony Docker Makefile 🐳 🎵 ——————————————————————————————————
help: ## Outputs this help screen
	@grep -E '(^[a-zA-Z0-9\./_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

## —— Docker 🐳 ————————————————————————————————————————————————————————————————
build: ## Builds the Docker images
	docker buildx create --name multi --use >/dev/null 2>&1 || docker buildx use multi
	docker buildx inspect --bootstrap


push: ## Push the Docker images to Github Container Registry
push: build
push:
	docker buildx build --platform linux/amd64,linux/arm64 --build-arg PHP_VERSION=8.4 -t "$(IMAGE_PATH):8.4" -t "$(IMAGE_PATH):8.4-latest" --push .
	docker buildx build --platform linux/amd64,linux/arm64 --build-arg PHP_VERSION=8.3 -t "$(IMAGE_PATH):8.3" -t "$(IMAGE_PATH):8.3-latest" --push .