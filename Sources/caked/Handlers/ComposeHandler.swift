//
//  ComposeHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 26/06/2026.
//
import Foundation
import GRPCLib
import NIO
import CakedLib
import Yams

struct ComposeHandler {
	struct Down: CakedCommand {
		let request: Caked_ComposeRequest.ComposeRequestDown

		init(request: Caked_ComposeRequest.ComposeRequestDown) {
			self.request = request
		}

		mutating func run(on: any EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
			do {
				let home = try Home(runMode: runMode).composeFileDatabase()
				guard let compose = home.get(request.name) else {
					return replyError(error: ServiceError(String(localized: "compose \(request.name) not found")))
				}

				return .with {
					$0.compose = .with {
						$0.down = CakedLib.ComposeHandler.down(compose: compose, services: [], force: false, runMode: runMode).caked
					}
				}
			} catch {
				return replyError(error: error)
			}
		}

		func replyError(error: any Error) -> Caked_Reply {
			.with {
				$0.compose = .with {
					$0.down = .with {
						$0.success = false
						$0.reason = error.reason
					}
				}
			}
		}
	}

	struct Up: CakedCommandAsync {
		let request: Caked_ComposeRequest.ComposeRequestUp

		init(request: Caked_ComposeRequest.ComposeRequestUp) {
			self.request = request
		}

		mutating func run(on: any EventLoop, runMode: Utils.RunMode) async -> Caked_Reply {
			do {
				let composeFileDatabase = try Home(runMode: runMode).composeFileDatabase()
				let compose = try YAMLDecoder().decode(ComposeFile.self, from: request.composeDatas)

				guard compose.name.isEmpty == false else {
					return replyError(error: ServiceError(String(localized: "compose name must not be empty")))
				}

				guard let compose = composeFileDatabase.get(compose.name) else {
					return replyError(error: ServiceError(String(localized: "compose \(compose.name) not found")))
				}

				composeFileDatabase.add(compose.name, compose)
				try composeFileDatabase.save()

				let reply = await CakedLib.ComposeHandler.up(compose: compose, services: [], waitIPTimeout: Int(request.waitIptimeout), runMode: runMode).caked

				return .with {
					$0.compose = .with {
						$0.up = reply
					}
				}
			} catch {
				return replyError(error: error)
			}
		}

		func replyError(error: any Error) -> GRPCLib.Caked_Reply {
			.with {
				$0.compose = .with {
					$0.up = .with {
						$0.success = false
						$0.reason = error.reason
					}
				}
			}
		}
	}

	struct Ps: CakedCommand {
		let request: Caked_ComposeRequest.ComposeRequestPs

		init(request: Caked_ComposeRequest.ComposeRequestPs) {
			self.request = request
		}

		mutating func run(on: any EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
			do {
				let composeFileDatabase = try Home(runMode: runMode).composeFileDatabase()

				guard request.name.isEmpty == false else {
					return replyError(error: ServiceError(String(localized: "compose name must not be empty")))
				}

				guard let compose = composeFileDatabase.get(request.name) else {
					return replyError(error: ServiceError(String(localized: "compose \(request.name) not found")))
				}
				
				return .with {
					$0.compose = .with {
						$0.ps = CakedLib.ComposeHandler.ps(compose: compose, services: [], runMode: runMode).caked
					}
				}
			} catch {
				return replyError(error: error)
			}
		}

		func replyError(error: any Error) -> GRPCLib.Caked_Reply {
			.with {
				$0.compose = .with {
					$0.ps = .with {
						$0.success = false
						$0.reason = error.reason
					}
				}
			}
		}

	}

	struct List: CakedCommand {
		let request: Caked_ComposeRequest.ComposeRequestList

		init(request: Caked_ComposeRequest.ComposeRequestList) {
			self.request = request
		}

		mutating func run(on: any EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
			do {
				let composeFileDatabase = try Home(runMode: runMode).composeFileDatabase()
				
				return .with {
					$0.compose = .with {
						$0.ls = CakedLib.ComposeHandler.list(database: composeFileDatabase, runMode: runMode).caked
					}
				}
			} catch {
				return replyError(error: error)
			}
		}

		func replyError(error: any Error) -> Caked_Reply {
			.with {
				$0.compose = .with {
					$0.ls = .with {
						$0.success = false
						$0.reason = error.reason
					}
				}
			}
		}
	}

	struct Delete: CakedCommand {
		let request: Caked_ComposeRequest.ComposeRequestDelete

		init(request: Caked_ComposeRequest.ComposeRequestDelete) {
			self.request = request
		}

		mutating func run(on: any EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
			do {
				let composeFileDatabase = try Home(runMode: runMode).composeFileDatabase()
				guard request.name.isEmpty == false else {
					return replyError(error: ServiceError(String(localized: "compose name must not be empty")))
				}

				guard let compose = composeFileDatabase.get(request.name) else {
					return replyError(error: ServiceError(String(localized: "compose \(request.name) not found")))
				}

				composeFileDatabase.remove(compose.name)
				try composeFileDatabase.save()

				return .with {
					$0.compose = .with {
						$0.delete = CakedLib.ComposeHandler.rm(compose: compose, services: [], stop: true, force: false, runMode: runMode).caked
					}
				}
			} catch {
				return replyError(error: error)
			}
		}

		func replyError(error: any Error) -> GRPCLib.Caked_Reply {
			.with {
				$0.compose = .with {
					$0.delete = .with {
						$0.success = false
						$0.reason = error.reason
					}
				}
			}
		}
	}
}
