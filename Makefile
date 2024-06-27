ARCH ?=amd64
ALL_ARCH = amd64 arm64

IMAGE ?= rancher/hyperkube-base
TAG ?= v0.0.1

all: all-push

sub-build-%:
	$(MAKE) ARCH=$* build

all-build: $(addprefix sub-build-,$(ALL_ARCH))

sub-push-image-%:
	$(MAKE) ARCH=$* push

all-push-images: $(addprefix sub-push-image-,$(ALL_ARCH))

all-push: all-push-images push-manifest

build: 
	docker build --pull --build-arg ARCH=${ARCH} -t $(IMAGE):$(TAG)-linux-$(ARCH) .

push: build
	docker push $(IMAGE):$(TAG)-$(ARCH)

test:
	IMAGE=test-hyperkube-base DEBUG=true \
		./tests/run-test.sh bci

.PHONY: all build push all-build all-push-images all-push

.DEFAULT_GOAL := build
