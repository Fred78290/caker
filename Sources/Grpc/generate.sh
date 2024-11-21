#!/bin/bash
## Copyright 2024, gRPC Authors All rights reserved.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

set -eu

here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
root="$here/.."
protoc=$(which protoc)
protoc_gen_swift="" # $(command -v protoc-gen-swift-v1) || :
protoc_gen_grpc_swift="" # $(command -v protoc-gen-grpc-swift-v1) || :

# Checkout and build the plugins.
if [ -z "${protoc_gen_swift:=}" ] || [ -z "${protoc_gen_swift:=}" ]; then
  build_dir=$(mktemp -d)
  git clone https://github.com/grpc/grpc-swift -b "release/1.x" --depth 1 "$build_dir"
  swift build --package-path "$build_dir" --product protoc-gen-swift
  swift build --package-path "$build_dir" --product protoc-gen-grpc-swift

  # Grab the plugin paths.
  bin_path=$(swift build --package-path "$build_dir" --show-bin-path)
  protoc_gen_swift="$bin_path/protoc-gen-swift"
  protoc_gen_grpc_swift="$bin_path/protoc-gen-grpc-swift"

#  sudo mv ${protoc_gen_swift} /usr/local/bin/protoc-gen-swift-v1
#  sudo mv ${protoc_gen_grpc_swift} /usr/local/bin/protoc-gen-grpc-swift-v1
#  protoc_gen_swift="/usr/local/bin/protoc-gen-swift-v1"
#  protoc_gen_grpc_swift="/usr/local/bin/protoc-gen-grpc-swift-v1"
fi

# Generates gRPC by invoking protoc with the gRPC Swift plugin.
# Parameters:
# - $1: .proto file
# - $2: proto path
# - $3: output path
# - $4 onwards: options to forward to the plugin
function generate_grpc {
  local proto=$1
  local args=("--plugin=$protoc_gen_grpc_swift" "--proto_path=${2}" "--grpc-swift_out=${3}")

  for option in "${@:4}"; do
    args+=("--grpc-swift_opt=$option")
  done

  invoke_protoc "${args[@]}" "$proto"
}

# Generates messages by invoking protoc with the Swift plugin.
# Parameters:
# - $1: .proto file
# - $2: proto path
# - $3: output path
# - $4 onwards: options to forward to the plugin
function generate_message {
  local proto=$1
  local args=("--plugin=$protoc_gen_swift" "--proto_path=$2" "--swift_out=$3")

  for option in "${@:4}"; do
    args+=("--swift_opt=$option")
  done

  invoke_protoc "${args[@]}" "$proto"
}

function invoke_protoc {
  # Setting -x when running the script produces a lot of output, instead boil
  # just echo out the protoc invocations.
  echo "$protoc" "$@"
  "$protoc" "$@"
}

#- EXAMPLES -------------------------------------------------------------------

function generate_service {
  local proto="$here/service.proto"
  local output="$root/Grpc"

  generate_message "$proto" "$(dirname "$proto")" "$output" "Visibility=Public"
  generate_grpc "$proto" "$(dirname "$proto")" "$output" "Visibility=Public"
}

#------------------------------------------------------------------------------
generate_service
