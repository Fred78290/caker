import ArgumentParser
import CakedLib
import Cocoa
import Foundation
import GRPCLib
import NIO
import Shout

struct TemplateHandler: CakedCommand {
	let request: Caked_TemplateRequest

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		switch request.command {
		case .add:
			return Caked_Reply.with {
				$0.templates = Caked_Caked.Reply.TemplateReply.with {
					$0.create = .with {
						$0.created = false
						$0.reason = "\(error)"
					}
				}
			}

		case .delete:
			return Caked_Reply.with {
				$0.templates = Caked_TemplateReply.with {
					$0.delete = .with {
						$0.deleted = false
						$0.reason = "\(error)"
					}
				}
			}

		case .list:
			return Caked_Reply.with {
				$0.templates = .with {
					$0.list = .with {
						$0.success = false
						$0.reason = "\(error)"
					}
				}
			}

		default:
			fatalError("Unknown command \(request.command)")
		}
	}
	
	private func listTemplate(runMode: Utils.RunMode) -> Caked_TemplateReply {
		do {
			let result = try CakedLib.TemplateHandler.listTemplate(runMode: runMode)

			return Caked_TemplateReply.with {
				$0.list = Caked_ListTemplatesReply.with {
					$0.success = true
					$0.reason = "Success"
					$0.templates = result.map {
						$0.caked
					}
				}
			}
		} catch {
			return Caked_TemplateReply.with {
				$0.list = Caked_ListTemplatesReply.with {
					$0.success = false
					$0.reason = "\(error)"
				}
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		switch request.command {
		case .add:
			let result = CakedLib.TemplateHandler.createTemplate(on: on, sourceName: request.createRequest.sourceName, templateName: request.createRequest.templateName, runMode: runMode)

			return Caked_Reply.with {
				$0.templates = Caked_Caked.Reply.TemplateReply.with {
					$0.create = result.caked
				}
			}

		case .delete:
			return Caked_Reply.with {
				$0.templates = Caked_TemplateReply.with {
					$0.delete = CakedLib.TemplateHandler.deleteTemplate(templateName: request.deleteRequest, runMode: runMode).caked
				}
			}

		case .list:
			return Caked_Reply.with {
				$0.templates = self.listTemplate(runMode: runMode)
			}

		default:
			throw ServiceError("Unknown command \(request.command)")
		}
	}
}
