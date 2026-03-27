---
layout: page
title: Architecture
nav_order: 3
---

# Architecture

## Components

- `caked`: core background daemon
- `cakectl`: command-line controller 
- `cakedlib`: shared library code
- `grpc`: communication contracts and streaming/client interfaces

## High-level Flow

1. `cakectl` sends commands to `caked`
2. `caked` executes lifecycle/resource operations 
3. responses and streams are transmitted through gRPC
4. logs/status are returned to clients

## Service Responsibilities

`caked` is responsible for:
- lifecycle management
- resource allocation
- health monitoring
- logging and diagnostics

## Communication

The system uses gRPC for communication between `cakectl` and `caked`, providing:
- Type-safe service contracts
- Streaming capabilities for real-time updates
- Cross-platform compatibility
- Efficient binary protocol

## Repository Structure

```
Sources/
├── caked/          # Daemon implementation
├── cakectl/        # CLI client
├── cakedlib/       # Shared libraries
└── grpc/           # gRPC definitions and generated code
```