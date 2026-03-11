//
//  CakedServiceClient.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/03/2026.
//
import Foundation
import GRPC

extension CakedServiceClient {
	public func info(name: String, timeout: Int64 = 10) throws -> Caked_Reply {
		return try self.info(.with {
			$0.name = name
		}, callOptions: CallOptions(timeLimit: .timeout(.seconds(timeout)))).response.wait()
	}

	public func shell(name: String, rows: Int32, cols: Int32, handler: @escaping (Caked_ExecuteResponse) -> Void) throws -> BidirectionalStreamingCall<Caked_ExecuteRequest, Caked_ExecuteResponse> {
		let stream = self.execute(callOptions: CallOptions(customMetadata: .init([("CAKEAGENT_VMNAME", name)]), timeLimit: .none), handler: handler)

		try stream.sendTerminalSize(rows: rows, cols: cols).wait()
		try stream.sendShell().wait()

		return stream
	}

	internal func exec(
		name: String,
		command: CakedChannelStreamer.ExecuteCommand,
		inputHandle: FileHandle = FileHandle.standardInput,
		outputHandle: FileHandle = FileHandle.standardOutput,
		errorHandle: FileHandle = FileHandle.standardError,
		callOptions: CallOptions? = nil
	) async throws -> Int32 {
		let handler = CakedChannelStreamer(inputHandle: inputHandle, outputHandle: outputHandle, errorHandle: errorHandle)
		var callOptions = callOptions ?? CallOptions()

		callOptions.timeLimit = .none
		callOptions.customMetadata.add(name: "CAKEAGENT_VMNAME", value: name)

		return try await handler.stream(command: command) {
			return self.execute(callOptions: callOptions, handler: handler.handleResponse)
		}
	}

	public func exec(
		name: String,
		command: String,
		arguments: [String],
		inputHandle: FileHandle = FileHandle.standardInput,
		outputHandle: FileHandle = FileHandle.standardOutput,
		errorHandle: FileHandle = FileHandle.standardError,
		callOptions: CallOptions? = nil
	) async throws -> Int32 {
		return try await self.exec(name: name, command: .execute(command, arguments), inputHandle: inputHandle, outputHandle: outputHandle, errorHandle: errorHandle, callOptions: callOptions)
	}

	public func shell(
		name: String,
		inputHandle: FileHandle = FileHandle.standardInput,
		outputHandle: FileHandle = FileHandle.standardOutput,
		errorHandle: FileHandle = FileHandle.standardError,
		callOptions: CallOptions? = nil
	) async throws -> Int32 {
		return try await self.exec(name: name, command: .shell(), inputHandle: inputHandle, outputHandle: outputHandle, errorHandle: errorHandle, callOptions: callOptions)
	}
}
