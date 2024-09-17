NAME = agent

build:
	go build -v -trimpath -ldflags "-s -w -buildid=" -o agent ./cmd/agent/

pack:
	tar czvf agent.tar.gz agent

clean:
	rm -rf agent.tar.gz agent