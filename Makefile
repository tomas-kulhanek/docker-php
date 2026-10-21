PHP_VERSIONS ?= 8.3 8.4 8.5
BUILDER      ?= docker-php-builder

export BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
export SHA    := $(shell git rev-parse HEAD)

BAKE := docker buildx bake --builder $(BUILDER)

.PHONY: all builder login build push print $(addprefix build-,$(PHP_VERSIONS)) $(addprefix push-,$(PHP_VERSIONS))

all: push

# Multi-platform builds need a docker-container builder (with QEMU for the foreign arch)
builder:
	@docker buildx inspect $(BUILDER) >/dev/null 2>&1 || \
		docker buildx create --name $(BUILDER) --driver docker-container
	docker buildx inspect $(BUILDER) --bootstrap >/dev/null

login:
	docker login ghcr.io

# Show resolved bake config (tags, labels, platforms)
print:
	$(BAKE) --print

# Build only (result stays in buildx cache; multi-platform images can't be --load-ed)
build: builder
	$(BAKE)
$(addprefix build-,$(PHP_VERSIONS)): build-%: builder
	$(BAKE) php-$(subst .,-,$*)

# Build and push to GHCR
push: builder
	$(BAKE) --push
$(addprefix push-,$(PHP_VERSIONS)): push-%: builder
	$(BAKE) --push php-$(subst .,-,$*)
