#!/bin/bash

export CGO_ENABLED=1
export CGO_CFLAGS="-fembed-bitcode"
export GOOS=darwin
export SDK=macosx
export SDK_PATH=`xcrun --sdk $SDK --show-sdk-path`
export CLANG=`xcrun --sdk $SDK --find clang`
#exec $CLANG -arch $CARCH -isysroot $SDK_PATH -mios-version-min=10.0 "$@"

mkdir -p release/arm64
export CARCH="arm64"  # if compiling for iPhone
export GOARCH=arm64
go build -buildmode c-archive -trimpath -o release/arm64/qcow2convert.a main.go

export CARCH="x86_64"
export GOARCH=amd64
mkdir -p release/x86_64
go build -buildmode c-archive -trimpath -o release/x86_64/qcow2convert.a main.go

mkdir -p release/universal
lipo release/arm64/qcow2convert.a release/x86_64/qcow2convert.a -create -output release/universal/qcow2convert.a

xcodebuild -create-xcframework \
    -output qcow2convert.xcframework \
    -library release/universal/qcow2convert.a \
    -headers release/x86_64/qcow2convert.h