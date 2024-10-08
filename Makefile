NAME = agent

PACKAGE_NAME ?= linux-amd64-v3

PACKAGE_VERSION ?= 0.0.0

build:
	go build -v -trimpath -ldflags "-X main.version=$(PACKAGE_VERSION) -s -w -buildid=" -o nezha-agent ./cmd/agent/

default:
	GOOS=linux GOARCH=amd64 GOAMD64=v3 CGO_ENABLED=1 go build -v -trimpath -ldflags "-X main.version=$(PACKAGE_VERSION) -s -w -buildid=" -o nezha-agent ./cmd/agent/

pack:
	tar czvf nezha-agent-$(PACKAGE_NAME).tar.gz nezha-agent

clean:
	rm -rf nezha-agent-$(PACKAGE_NAME).tar.gz nezha-agent