BIN := bin/kdrill

.PHONY: build install test clean

build:
	go build -ldflags "-X main.defaultHome=$(CURDIR)" -o $(BIN) ./cmd/kdrill

install: build
	cp $(BIN) $(shell go env GOPATH)/bin/kdrill

test:
	go test ./...

clean:
	rm -rf bin
