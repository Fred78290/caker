//
//  Greeter.swift
//  tart
//
//  Created by Frederic BOLTZ on 19/11/2024.
//
import Foundation
import GRPC
import GRPCLib
import ArgumentParser

protocol TartdCommand {
  mutating func run() async throws -> String
}

protocol CreateTartdCommand {
  func createCommand() -> TartdCommand
}

private func saveToTempFile(_ data: Data) throws -> String {
  let url = FileManager.default.temporaryDirectory
	  .appendingPathComponent(UUID().uuidString)
	  .appendingPathExtension("txt")
  
  try data.write(to: url)

  return url.absoluteURL.path()
}

class Unimplemented : Error {
  let description: String

  init(_ what: String) {
    self.description = what
  }
}

extension Tartd_TartRequest : CreateTartdCommand {
  func createCommand() -> TartdCommand {
	  return TartHandler(command: self.command, arguments: self.arguments)
  }
}

extension Tartd_BuildRequest : CreateTartdCommand {
  func createCommand() -> TartdCommand {
	  var command = BuildHandler(name: self.name)
	
	if self.hasCpu {
	  command.cpu = UInt16(self.cpu)
	}
	
	if self.hasMemory {
	  command.memory = UInt64(self.memory)
	}

	if self.hasDiskSize {
	  command.diskSize = UInt16(self.diskSize)
	}

	if self.hasUser {
	  command.user = self.user
	}
	
	if self.hasInsecure {
	  command.insecure = self.insecure
	}
	
	if self.hasCloudImage {
	  command.cloudImage = self.cloudImage
	}
	
	if self.hasAliasImage {
	  command.aliasImage = self.aliasImage
	}
	
	if self.hasFromImage {
	  command.fromImage = self.fromImage
	}
	
	if self.hasOciImage {
	  command.ociImage = self.ociImage
	}

	if self.hasRemoteContainerServer {
	  command.remoteContainerServer = self.remoteContainerServer
	}
		  
	if self.hasSshAuthorizedKey {
	  command.sshAuthorizedKey = try? saveToTempFile(self.sshAuthorizedKey)
	}
	
	if self.hasUserData {
	  command.userData = try? saveToTempFile(self.userData)
	}

	if self.hasVendorData {
	  command.vendorData = try? saveToTempFile(self.vendorData)
	}

	if self.hasNetworkConfig {
	  command.networkConfig = try? saveToTempFile(self.networkConfig)
	}
	
	return command
  }
}

extension Tartd_CloneRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
	  var command = CloneHandler(sourceName: self.sourceName, newName: self.newName)
	
	if self.hasDeduplicate {
	   command.deduplicate = self.deduplicate
	}

	if self.hasInsecure {
	  command.insecure = self.insecure
	}
	
	if self.hasConcurrency {
	  command.concurrency = UInt(self.concurrency)
	}
	
	return command
  }
}

extension Tartd_CreateRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
	  var command = CreateHandler(name: self.name)
		
	if self.hasLinux {
	  command.linux = self.linux
	}
	
	if self.hasFromIpsw {
	  command.fromIPSW = self.fromIpsw
	}

	if self.hasDiskSize {
		command.diskSize = UInt16(self.diskSize)
	}

	return command
  }
}

extension Tartd_DeleteRequest : CreateTartdCommand {
  func createCommand() -> TartdCommand {
	return DeleteHandler(name: self.name)
  }
}

extension Tartd_FqnRequest : CreateTartdCommand {
	func createCommand() -> TartdCommand {
	return FQNHandler(name: self.name)
  }
}

extension Tartd_GetRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
    var command = GetHandler(name: self.name)
    
    if self.hasFormat {
      if self.format == .json {
        command.format = Format.json
      } else if self.format == .text {
        command.format = Format.text
      }
    }

    return command
  }
}

extension Tartd_ExportRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
    var command = ExportHandler(name: self.name)
	
    if self.hasPath {
      command.path = self.path
    }

    return command
  }
}

extension Tartd_ImportRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
	return ImportHandler(path: self.path, name: self.name)
  }
}

extension Tartd_IPRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
    var command = IPHandler(name: self.name)
        
    if self.hasResolver {
      if self.resolver == .dhcp {
        command.resolver = IPResolutionStrategy.dhcp
      } else if self.resolver == .arp {
        command.resolver = IPResolutionStrategy.arp
      }
    }

    if self.hasWait {
      command.wait = UInt16(self.wait)
    }

    return command
  }
}

extension Tartd_LaunchRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
    var command = LaunchHandler(name: self.name)

    command.dir = self.dir
    command.netBridged = self.netBridged
    command.netHost = self.netHost

    if self.hasNetSofnet {
      command.netSoftnet = self.netSofnet
    }

    if self.hasCpu {
      command.cpu = UInt16(self.cpu)
    }
    
    if self.hasMemory {
      command.memory = UInt64(self.memory)
    }

    if self.hasDiskSize {
      command.diskSize = UInt16(self.diskSize)
    }

    if self.hasUser {
      command.user = self.user
    }
    
    if self.hasInsecure {
      command.insecure = self.insecure
    }
    
    if self.hasCloudImage {
      command.cloudImage = self.cloudImage
    }
    
    if self.hasAliasImage {
      command.aliasImage = self.aliasImage
    }
    
    if self.hasFromImage {
      command.fromImage = self.fromImage
    }
    
    if self.hasOciImage {
      command.ociImage = self.ociImage
    }

    if self.hasRemoteContainerServer {
      command.remoteContainerServer = self.remoteContainerServer
    }
          
    if self.hasSshAuthorizedKey {
      command.sshAuthorizedKey = try? saveToTempFile(self.sshAuthorizedKey)
    }
    
    if self.hasUserData {
      command.userData = try? saveToTempFile(self.userData)
    }

    if self.hasVendorData {
      command.vendorData = try? saveToTempFile(self.vendorData)
    }

    if self.hasNetworkConfig {
      command.networkConfig = try? saveToTempFile(self.networkConfig)
    }
    
    return command
  }
}

extension Tartd_ListRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
    var command = ListHandler()
    
    command.quiet = self.quiet
    
    if self.hasFormat {
      if self.format == .json {
        command.format = .json
      }
    }

    return command
  }
}

extension Tartd_LoginRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
	  var command = LoginHandler(host: self.host)
    
    command.username = self.username
    command.insecure = self.insecure
    command.noValidate = self.noValidate

    return command
  }
}

extension Tartd_LogoutRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
	return LogoutHandler(host: self.host)
  }
}

extension Tartd_PruneRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
    var command = PruneHandler()
    
    if self.hasEntries {
      command.entries = self.entries
    }

    if self.hasOlderThan {
      command.olderThan = UInt(self.olderThan)
    }

    if self.hasCacheBudget {
      command.cacheBudget = UInt(self.cacheBudget)
    }

    if self.hasSpaceBudget {
      command.spaceBudget = UInt(self.spaceBudget)
    }

    return command
  }
}

extension Tartd_PullRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
	  var command = PullHandler(remoteName: self.remoteName)
    
    command.deduplicate = self.deduplicate
    command.insecure = self.insecure
    
    if self.hasConcurrency {
      command.concurrency = UInt(self.concurrency)
    }

    return command
  }
}

extension Tartd_PushRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
	  var command = PushHandler(localName: self.localName, remoteNames: self.remoteNames)
    
    command.insecure = self.insecure
    command.populateCache = self.populateCache

    if self.hasConcurrency {
      command.concurrency = UInt(self.concurrency)
    }

    return command
  }
}

extension Tartd_RenameRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
	return RenameHandler(name: self.newName, newName: self.newName)
  }
}

extension Tartd_SetRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
    var command = SetHandler(name: self.name)
    
    command.name = self.name
    command.randomMAC = self.randomMac
    command.randomSerial = self.randomSerial

    if self.hasCpu {
      command.cpu = UInt16(self.cpu)
    }
    
    if self.hasMemory {
      command.memory = UInt64(self.memory)
    }
    
    if self.hasDisk {
      command.disk = self.disk
    }
    
    if self.hasDisplay {
      command.display = VMDisplayConfig(
        width: Int(self.display.width),
        height: Int(self.display.height)
      )
    }

    return command
  }
}

extension Tartd_StartRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
	return StartHandler(name: self.name)
  }
}

extension Tartd_StopRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
    var command = StopHandler(name: self.name)
        
    if self.hasTimeout {
      command.timeout = UInt64(self.timeout)
    }

    return command
  }
}

extension Tartd_SuspendRequest: CreateTartdCommand {
  func createCommand() -> TartdCommand {
	return SuspendHandler(name: self.name)
  }
}

extension Tartd_Error {
  init(code: Int32, reason: String) {
    self.init()

    self.code = code
    self.reason = reason
  }
}
class TartDaemonProvider: @unchecked Sendable, Tartd_ServiceAsyncProvider {
  var interceptors: Tartd_ServiceServerInterceptorFactoryProtocol? = nil
  
  func execute(command: CreateTartdCommand) async throws -> Tartd_TartReply {
    var command = command.createCommand()
    var reply: Tartd_TartReply = Tartd_TartReply()

    do {
      reply.output = try await command.run()
    } catch {
      reply.error = Tartd_Error(code: -1, reason: error.localizedDescription)
    }

    return reply
  }

	func tart(request: Tartd_TartRequest, context: GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
	  return try await self.execute(command: request)
	}

  func build(request: Tartd_BuildRequest, context: GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func clone(request: Tartd_CloneRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func create(request: Tartd_CreateRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func delete(request: Tartd_DeleteRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func fQN(request: Tartd_FqnRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func get(request: Tartd_GetRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func exportVM(request: Tartd_ExportRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func importVM(request: Tartd_ImportRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func iP(request: Tartd_IPRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func launch(request: Tartd_LaunchRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func list(request: Tartd_ListRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func login(request: Tartd_LoginRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func logout(request: Tartd_LogoutRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func prune(request: Tartd_PruneRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func pull(request: Tartd_PullRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func push(request: Tartd_PushRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func rename(request: Tartd_RenameRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func runVM(request: Tartd_RunRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    throw Unimplemented("run is not implemented")
  }
  
  func set(request: Tartd_SetRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func start(request: Tartd_StartRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func stop(request: Tartd_StopRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
  
  func suspend(request: Tartd_SuspendRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Tartd_TartReply {
    return try await self.execute(command: request)
  }
}

