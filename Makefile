NAME = agent

PACKAGE_NAME ?= linux-amd64

build:
	go build -v -trimpath -ldflags "-s -w -buildid=" -o agent ./cmd/agent/

pack:
	tar czvf agent-$(PACKAGE_NAME).tar.gz agent

clean:
	rm -rf agent-$(PACKAGE_NAME).tar.gz agent