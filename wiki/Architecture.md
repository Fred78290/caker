# Architecture

## Components

- `caked`: core background daemon
- `cakectl`: command-line controller
- `cakedlib`: shared library code
- `grpc`: communication contracts and streaming/client interfaces

## High-level flow

1. `cakectl` sends commands to `caked`
2. `caked` executes lifecycle/resource operations
3. responses and streams are transmitted through gRPC
4. logs/status are returned to clients

## Service responsibilities

`caked` is responsible for:
- lifecycle management
- resource allocation
- health monitoring
- logging and diagnostics
