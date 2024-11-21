//
//  Greeter.swift
//  tart
//
//  Created by Frederic BOLTZ on 19/11/2024.
//
import Foundation
import GRPC
import TartLib
import GRPCLib

public protocol TartdCommand {
  mutating func run() async throws
}

class Unimplemented : Error {
  let description: String

  init(_ what: String) {
    self.description = what
  }
}

class StandardOutput {
  let standardOutput: DataWriteStream
  let savedStdout: Int32
  let savedStderr: Int32
  let savedOutPipe: Pipe
  let savedErrPipe: Pipe
  let outSemaphore: DispatchSemaphore
  let errSemaphore: DispatchSemaphore
  
  init() throws {
    Service.SyncSemaphore.wait()

    self.savedOutPipe = Pipe()
    self.savedErrPipe = Pipe()
    self.outSemaphore = DispatchSemaphore(value: 0)
    self.errSemaphore = DispatchSemaphore(value: 0)
    self.standardOutput = DataWriteStream()
    self.savedStdout = try StandardOutput.captureStandartOutput(fd: STDOUT_FILENO, output: self.standardOutput, outPipe: self.savedOutPipe, sema: self.outSemaphore)
    self.savedStderr = try StandardOutput.captureStandartOutput(fd: STDERR_FILENO, output: self.standardOutput, outPipe: self.savedErrPipe, sema: self.errSemaphore)
  }
  
  private static func captureStandartOutput(fd: Int32, output: DataWriteStream, outPipe: Pipe, sema: DispatchSemaphore) throws -> Int32 {
    outPipe.fileHandleForReading.readabilityHandler = { fileHandle in
      let data = fileHandle.availableData
      
      if data.isEmpty  { // end-of-file condition
        fileHandle.readabilityHandler = nil
        sema.signal()
      } else {
        try! output.write(data)
      }
    }
    
    // Redirect
    setvbuf(fd == STDOUT_FILENO ? stdout : stderr, nil, _IONBF, 0)
    
    let savedOutput = dup(fd)
    
    dup2(outPipe.fileHandleForWriting.fileDescriptor, fd)
    
    return savedOutput
  }
  
  func closeOutput() {
    dup2(savedStdout, STDOUT_FILENO)
    try! savedOutPipe.fileHandleForWriting.close()
    close(savedStdout)
    outSemaphore.wait() // Wait until read handler is done
    
    dup2(savedStderr, STDOUT_FILENO)
    try! savedErrPipe.fileHandleForWriting.close()
    close(savedStderr)
    errSemaphore.wait() // Wait until read handler is done
    
    Service.SyncSemaphore.signal()
  }
}

extension Tartd_GetRequest : TartdCommand {
  func createCommand() -> AsyncParsableCommand {
    var command = Get()
    
    command.name = self.name

    if self.hasFormat {
      if self.format == .json {
        command.format = .json
      } else if self.format == .text {
        command.format = .text
      }
    }

    return command
  }
}

extension Tartd_ExportRequest : TartdCommand {
  func createCommand() -> AsyncParsableCommand {
    var command = Export()
    
    command.name = self.name
    
    if self.hasPath {
      command.path = self.path
    }

    return command
  }
}

extension Tartd_ImportRequest : TartdCommand {
  func createCommand() -> AsyncParsableCommand {
    var command = Import()
    
    command.name = self.name
    command.path = self.path

    return command
  }
}

extension Tartd_IPRequest : TartdCommand {
  func createCommand() -> AsyncParsableCommand {
    var command = IP()
    
    command.name = self.name
    
    if self.hasResolver {
      if self.resolver == .dhcp {
        command.resolver = .dhcp
      } else if self.resolver == .arp {
        command.resolver = .arp
      }
    }

    if self.hasWait {
      command.wait = UInt16(self.wait)
    }

    return command
  }
}

extension Tartd_LaunchRequest : TartdCommand {
  func createCommand() -> AsyncParsableCommand {
    var command = Launch()

    command.name = self.name
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

extension Tartd_ListRequest : TartdCommand {
  func createCommand() -> AsyncParsableCommand {
    var command = List()
    
    command.quiet = self.quiet
    
    if self.hasFormat {
      if self.format == .json {
        command.format = .json
      }
    }

    return command
  }
}

extension Tartd_LoginRequest : TartdCommand {
  func createCommand() -> AsyncParsableCommand {
    var command = Login()
    
    command.host = self.host
    command.username = self.username
    command.insecure = self.insecure
    command.noValidate = self.noValidate

    return command
  }
}

extension Tartd_LogoutRequest : TartdCommand {
  func createCommand() -> AsyncParsableCommand {
    var command = Logout()
    
    command.host = self.host

    return command
  }
}

extension Tartd_PruneRequest : TartdCommand {
  func createCommand() -> AsyncParsableCommand {
    var command = Prune()
    
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

extension Tartd_PullRequest : TartdCommand {
  func createCommand() -> AsyncParsableCommand {
    var command = Pull()
    
    command.remoteName = self.remoteName
    command.deduplicate = self.deduplicate
    command.insecure = self.insecure
    
    if self.hasConcurrency {
      command.concurrency = UInt(self.concurrency)
    }

    return command
  }
}

extension Tartd_PushRequest : TartdCommand{
  func createCommand() -> AsyncParsableCommand {
    var command = Push()
    
    command.localName = self.localName
    command.remoteNames = self.remoteNames
    command.insecure = self.insecure
    command.populateCache = self.populateCache

    if self.hasConcurrency {
      command.concurrency = UInt(self.concurrency)
    }

    return command
  }
}

extension Tartd_RenameRequest : TartdCommand{
  func createCommand() -> AsyncParsableCommand {
    var command = Rename()
    
    command.name = self.newName
    command.newName = self.newName

    return command
  }
}

extension Tartd_SetRequest : TartdCommand {
  func createCommand() -> AsyncParsableCommand {
    var command = Set()
    
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

extension Tartd_StartRequest : TartdCommand {
  func createCommand() -> AsyncParsableCommand {
    var command = Start()
    
    command.name = self.name
    
    return command
  }
}

extension Tartd_StopRequest : TartdCommand {
  func createCommand() -> AsyncParsableCommand {
    var command = Stop()
    
    command.name = self.name
    
    if self.hasTimeout {
      command.timeout = UInt64(self.timeout)
    }

    return command
  }
}

extension Tartd_SuspendRequest : TartdCommand {
  func createCommand() -> AsyncParsableCommand {
    var command = Suspend()
    
    command.name = self.name
    
    return command
  }
}

class TartDaemonProvider: Tartd_ServiceAsyncProvider {
  var interceptors: Tartd_ServiceServerInterceptorFactoryProtocol? = nil

  func execute(command: TartdCommand) async throws -> Tartd_TartReply {
    let output = try StandardOutput()

    var command = command.createCommand()

    defer {
      output.closeOutput()
    }

    try await command.run()

    var reply: Tartd_TartReply = Tartd_TartReply()
    reply.output = String(data: output.standardOutput.data!,  encoding: .utf8)!

    return reply
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

