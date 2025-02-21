#!/bin/bash
pushd /tmp
git clone https://github.com/Fred78290/gomobile.git
cd gomobile
go mod tidy
go install ./cmd/gomobile
go install ./cmd/gobind
popd

export PATH=$PATH:~/go/bin

rm -rf Qcow2convert.xcframework

gomobile bind -target macos -macosversion "13.0" -o Qcow2convert.xcframework
