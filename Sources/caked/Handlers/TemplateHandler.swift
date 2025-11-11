import ArgumentParser
import CakedLib
import Cocoa
import Foundation
import GRPCLib
import NIO
import Shout

struct TemplateHandler: CakedCommand {
	let request: Caked_TemplateRequest

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		switch request.command {
		case .add:
			let result = CakedLib.TemplateHandler.createTemplate(on: on, sourceName: request.createRequest.sourceName, templateName: request.createRequest.templateName, runMode: runMode)

			return Caked_Reply.with {
				$0.templates = Caked_Caked.Reply.TemplateReply.with {
					$0.create = result.toCaked_CreateTemplateReply()
				}
			}

		case .delete:
			let result = CakedLib.TemplateHandler.deleteTemplate(templateName: request.deleteRequest, runMode: runMode)

			return Caked_Reply.with {
				$0.templates = Caked_TemplateReply.with {
					$0.delete = Caked_DeleteTemplateReply.with {
						$0.name = result.name
						$0.deleted = result.deleted
					}
				}
			}

		case .list:
			let result = try CakedLib.TemplateHandler.listTemplate(runMode: runMode)

			return Caked_Reply.with {
				$0.templates = Caked_Caked.Reply.TemplateReply.with {
					$0.list = Caked_ListTemplatesReply.with {
						$0.templates = result.map {
							$0.toCaked_TemplateEntry()
						}
					}
				}
			}

		default:
			throw ServiceError("Unknown command \(request.command)")
		}
	}
}
