NAME = agent

PACKAGE_NAME ?= linux-amd64-v3

build:
	go build -v -trimpath -ldflags "-s -w -buildid=" -o agent ./cmd/agent/

default:
	GOOS=linux GOARCH=amd64 GOAMD64=v3 CGO_ENABLED=1 go build -v -trimpath -ldflags "-s -w -buildid=" -o agent ./cmd/agent/

pack:
	tar czvf agent-$(PACKAGE_NAME).tar.gz agent

clean:
	rm -rf agent-$(PACKAGE_NAME).tar.gz agent