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

	public static func createTemplate(client: CakedServiceClient?, rootURL: URL, templateName: String, runMode: Utils.RunMode) throws -> CreateTemplateReply {
		guard let client else {
			return self.createTemplate(rootURL: rootURL, templateName: templateName, runMode: runMode)
		}
		
		if rootURL.isFileURL {
			return self.createTemplate(rootURL: rootURL, templateName: templateName, runMode: runMode)
		}

		guard let host = rootURL.host(percentEncoded: false) else {
			throw ServiceError("Internal error")
		}

		return try CreateTemplateReply(client.template(.with {
			$0.command = .add
			$0.createRequest = .with {
				$0.templateName = templateName
				$0.sourceName = host
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
