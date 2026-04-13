.PHONY : log protos plugins generate clean help

SWIFT_PROTOBUF_VERSION = 1.28.2
GRPC_SWIFT_PROTOBUF_VERSION = 2.2.1

PLUGIN_BUILD_DIR = .build/plugins
PROTOC_GEN_SWIFT = $(PLUGIN_BUILD_DIR)/protoc-gen-swift
PROTOC_GEN_GRPC_SWIFT = $(PLUGIN_BUILD_DIR)/protoc-gen-grpc-swift-2

log:help

## protos              : Pull protos from Google Repository
protos:
	curl -L -O https://github.com/googleapis/googleapis/archive/master.zip
	unzip master.zip
	rm -f master.zip
	rm -rf googleapis
	mv googleapis-master googleapis

## plugins             : Build protoc-gen-swift and protoc-gen-grpc-swift v2 plugins
plugins:
	mkdir -p $(PLUGIN_BUILD_DIR)
	@echo "Building protoc-gen-swift from swift-protobuf $(SWIFT_PROTOBUF_VERSION)..."
	rm -rf /tmp/swift-protobuf-build
	git clone --depth 1 --branch $(SWIFT_PROTOBUF_VERSION) https://github.com/apple/swift-protobuf.git /tmp/swift-protobuf-build
	swift build -c release --product protoc-gen-swift --package-path /tmp/swift-protobuf-build
	cp /tmp/swift-protobuf-build/.build/release/protoc-gen-swift $(PROTOC_GEN_SWIFT)
	rm -rf /tmp/swift-protobuf-build
	@echo "Building protoc-gen-grpc-swift-2 from grpc-swift-protobuf $(GRPC_SWIFT_PROTOBUF_VERSION)..."
	rm -rf /tmp/grpc-swift-protobuf-build
	git clone --depth 1 --branch $(GRPC_SWIFT_PROTOBUF_VERSION) https://github.com/grpc/grpc-swift-protobuf.git /tmp/grpc-swift-protobuf-build
	swift build -c release --product protoc-gen-grpc-swift-2 --package-path /tmp/grpc-swift-protobuf-build
	cp /tmp/grpc-swift-protobuf-build/.build/release/protoc-gen-grpc-swift-2 $(PROTOC_GEN_GRPC_SWIFT)
	rm -rf /tmp/grpc-swift-protobuf-build
	@echo "Plugins built successfully."

## generate            : Generate Swift from .proto files using v2 plugins
generate: $(PROTOC_GEN_SWIFT) $(PROTOC_GEN_GRPC_SWIFT)
	protoc \
	googleapis/google/cloud/speech/v1/cloud_speech.proto \
	googleapis/google/cloud/speech/v1/resource.proto \
	googleapis/google/rpc/status.proto \
	googleapis/google/api/client.proto \
	googleapis/google/api/annotations.proto \
	googleapis/google/api/http.proto \
	googleapis/google/api/field_behavior.proto \
	googleapis/google/api/launch_stage.proto \
	googleapis/google/longrunning/operations.proto \
	-Igoogleapis \
	--plugin=protoc-gen-swift=$(PROTOC_GEN_SWIFT) \
	--plugin=protoc-gen-grpc-swift-2=$(PROTOC_GEN_GRPC_SWIFT) \
	--swift_out=Visibility=Public:. \
	--grpc-swift-2_out=Visibility=Public,Client=true,Server=false:.

	mkdir -p Sources/Generated
	find google/ -name \*.swift -exec cp {} Sources/Generated/ \;

$(PROTOC_GEN_SWIFT) $(PROTOC_GEN_GRPC_SWIFT):
	$(MAKE) plugins

## clean               : Clean workspace and start from scratch
clean:
	rm -rf googleapis/
	rm -rf google/
	rm -rf Sources/Generated/*
	rm -rf $(PLUGIN_BUILD_DIR)

help: Makefile
	sed -n "s/^##//p" $<
