#!/bin/bash
# https://medium.com/nerd-for-tech/creating-a-grpc-server-and-client-with-node-js-and-typescript-bb804829fada
#https://github.com/jsbroks/grpc-typescript/blob/master/proto/build.sh
PROTO_DIR=lib/grpc
mkdir -p ${PROTO_DIR}
# Generate the gRPC code from the proto files
# Generate JavaScript code
yarn run grpc_tools_node_protoc \
    --js_out=import_style=commonjs,binary:${PROTO_DIR} \
    --grpc_out=${PROTO_DIR} \
    --plugin=protoc-gen-grpc=./node_modules/.bin/grpc_tools_node_protoc_plugin \
	-I ../grpc \
	../grpc/service.proto

# Generate TypeScript code (d.ts)
yarn run grpc_tools_node_protoc \
    --plugin=protoc-gen-ts=./node_modules/.bin/protoc-gen-ts \
    --ts_out=${PROTO_DIR} \
	-I ../grpc \
	../grpc/service.proto
