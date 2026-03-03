import Foundation
import CakedLib
import GRPCLib

extension TemplateHandler {
	public static func exists(client: CakedServiceClient?, name: String, runMode: Utils.RunMode) -> Bool {
		guard let client = client else {
			return self.exists(name: name, runMode: runMode)
		}

		do {
			return try client.template(.with { $0.command = .list }).response.wait().templates.list.templates.first(where: { $0.name == name }) != nil
		} catch {
			return false
		}
	}

	public static func createTemplate(client: CakedServiceClient?, sourceName: String, templateName: String, runMode: Utils.RunMode) throws -> CreateTemplateReply {
		guard let client = client else {
			return self.createTemplate(on: Utilities.group.next(), sourceName: sourceName, templateName: templateName, runMode: runMode)
		}
		
		return try CreateTemplateReply(client.template(.with {
			$0.command = .add
			$0.createRequest = .with {
				$0.templateName = templateName
				$0.sourceName = sourceName
			}
		}).response.wait().templates.create)
	}

	public static func listTemplate(client: CakedServiceClient?, runMode: Utils.RunMode) throws -> ListTemplateReply {
		guard let client = client else {
			return self.listTemplate(runMode: runMode)
		}

		return try ListTemplateReply(client.template(.with { $0.command = .list }).response.wait().templates.list)
	}
}
