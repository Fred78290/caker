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
					$0.reason = error.reason
				}
			}

		case .delete:
			reply = Caked_TemplateReply.with {
				$0.delete = .with {
					$0.deleted = false
					$0.reason = error.reason
				}
			}

		case .duplicate:
			reply = Caked_TemplateReply.with {
				$0.duplicate = .with {
					$0.name = request.duplicateRequest.templateName
					$0.duplicated = false
					$0.reason = error.reason
				}
			}

		case .infos:
			reply = Caked_TemplateReply.with {
				$0.infos = .with {
					$0.success = false
					$0.reason = error.reason
				}
			}

		case .list:
			reply = .with {
				$0.list = .with {
					$0.success = false
					$0.reason = error.reason
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
				$0.create = CakedLib.TemplateHandler.createTemplate(sourceName: request.createRequest.sourceName, templateName: request.createRequest.templateName, runMode: runMode).caked
			}

		case .delete:
			reply = Caked_TemplateReply.with {
				$0.delete = CakedLib.TemplateHandler.deleteTemplate(templateName: request.deleteRequest, runMode: runMode).caked
			}

		case .duplicate:
			reply = Caked_TemplateReply.with {
				$0.duplicate = CakedLib.TemplateHandler.duplicateTemplate(sourceName: request.duplicateRequest.sourceName, templateName: request.duplicateRequest.templateName, runMode: runMode).caked
			}

		case .infos:
			reply = Caked_TemplateReply.with {
				$0.infos = CakedLib.TemplateHandler.infos(templateName: request.infoRequest, runMode: runMode).caked
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
