import Foundation
import CakedLib
import GRPCLib

extension TemplateHandler {
	public static func exists(client: CakedServiceClient?, name: String, runMode: Utils.RunMode) async -> Bool {
		guard let client = client else {
			return self.exists(name: name, runMode: runMode)
		}

		do {
			return try await client.template(.with { $0.command = .list }).response.get().templates.list.templates.first(where: { $0.name == name }) != nil
		} catch {
			return false
		}
	}

	public static func createTemplate(client: CakedServiceClient?, vmURL: URL, templateName: String, runMode: Utils.RunMode) async throws -> CreateTemplateReply {
		guard let client, vmURL.isFileURL == false else {
			return self.createTemplate(vmURL: vmURL, templateName: templateName, runMode: runMode)
		}

		return try await CreateTemplateReply(client.template(.with {
			$0.command = .add
			$0.createRequest = .with {
				$0.templateName = templateName
				$0.sourceName = vmURL.vmName
			}
		}).response.get().templates.create)
	}

	public static func deleteTemplate(client: CakedServiceClient?, templateName: String, runMode: Utils.RunMode) async throws -> DeleteTemplateReply {
		guard let client else {
			return self.deleteTemplate(templateName: templateName, runMode: runMode)
		}

		return try await DeleteTemplateReply(client.template(.with {
			$0.command = .delete
			$0.deleteRequest = templateName
		}).response.get().templates.delete )
	}

	public static func duplicateTemplate(client: CakedServiceClient?, sourceName: String, templateName: String, runMode: Utils.RunMode) async throws -> DuplicateTemplateReply {
		guard let client else {
			return self.duplicateTemplate(sourceName: sourceName, templateName: templateName, runMode: runMode)
		}

		return try await DuplicateTemplateReply(client.template(.with {
			$0.command = .duplicate
			$0.duplicateRequest = .with {
				$0.sourceName = sourceName
				$0.templateName = templateName
			}
		}).response.get().templates.duplicate)
	}

	public static func infos(client: CakedServiceClient?, templateName: String, runMode: Utils.RunMode) async throws -> InfoTemplateReply {
		guard let client else {
			return self.infos(templateName: templateName, runMode: runMode)
		}

		return try await InfoTemplateReply(client.template(.with {
			$0.command = .infos
			$0.infoRequest = templateName
		}).response.get().templates.infos)
	}

	public static func listTemplate(client: CakedServiceClient?, runMode: Utils.RunMode) throws -> ListTemplateReply {
		guard let client = client else {
			return self.listTemplate(runMode: runMode)
		}

		return try ListTemplateReply(client.template(.with { $0.command = .list }).response.wait().templates.list)
	}
}
