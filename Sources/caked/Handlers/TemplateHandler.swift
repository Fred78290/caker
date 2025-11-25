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
		let reply: Caked_TemplateReply

		switch request.command {
		case .add:
			reply = Caked_TemplateReply.with {
				$0.create = .with {
					$0.created = false
					$0.reason = "\(error)"
				}
			}

		case .delete:
			reply = Caked_TemplateReply.with {
				$0.delete = .with {
					$0.deleted = false
					$0.reason = "\(error)"
				}
			}

		case .list:
			reply = .with {
				$0.list = .with {
					$0.success = false
					$0.reason = "\(error)"
				}
			}

		default:
			fatalError("Unknown command \(request.command)")
		}

		return Caked_Reply.with {
			$0.templates = reply
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		let reply: Caked_TemplateReply

		switch request.command {
		case .add:
			reply = Caked_TemplateReply.with {
				$0.create = CakedLib.TemplateHandler.createTemplate(on: on, sourceName: request.createRequest.sourceName, templateName: request.createRequest.templateName, runMode: runMode).caked
			}

		case .delete:
			reply = Caked_TemplateReply.with {
				$0.delete = CakedLib.TemplateHandler.deleteTemplate(templateName: request.deleteRequest, runMode: runMode).caked
			}

		case .list:
			reply = Caked_TemplateReply.with {
				$0.list = CakedLib.TemplateHandler.listTemplate(runMode: runMode).caked
			}

		default:
			fatalError("Unknown command \(request.command)")
		}

		return Caked_Reply.with {
			$0.templates = reply
		}
	}
}
