#!/bin/bash

rm -rf Qcow2convert.xcframework

gomobile bind -target macos -macosversion "13.0" -o Qcow2convert.xcframework
