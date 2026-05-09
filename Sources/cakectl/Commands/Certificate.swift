//
//  Certificate.swift
//  Caker
//
//  Created by Frederic BOLTZ on 08/05/2026.
//

import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import Security

// MARK: - Certificate command group

struct Certificate: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "certificate",
		abstract: String(localized: "Manage TLS client certificates for REST API authentication"),
		subcommands: [AddCertificate.self, GetCertificate.self, ListCertificates.self, DeleteCertificate.self]
	)
	
	// MARK: add
	struct AddCertificate: GrpcParsableCommand {
		static let configuration = CommandConfiguration(commandName: "add", abstract: String(localized: "Register a PEM client certificate in caked"))
		
		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options
		
		@Option(name: .shortAndLong, help: ArgumentHelp(String(localized: "Friendly name for the certificate")))
		var name: String
		
		@Argument(help: ArgumentHelp(String(localized: "Path to PEM certificate file or undefined for stdin")))
		var pemFile: String? = nil
		
		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			// Read PEM either from file path or stdin
			let pem: String
			
			if let pemPath = pemFile {
				pem = try String(contentsOfFile: pemPath, encoding: .utf8)
			} else {
				let data = try FileHandle.standardInput.readToEnd() ?? Data()
				pem = String(data: data, encoding: .utf8) ?? ""
			}
			
			// Trim and validate
			let trimmed = pem.trimmingCharacters(in: .whitespacesAndNewlines)
			
			guard trimmed.isEmpty == false else {
				throw GrpcError(code: 1, reason: String(localized: "Certificate input is empty"))
			}
			
			let reply = try client.certificate(.with {
				$0.command = .add
				$0.addRequest = .with {
					$0.name = name
					$0.certAsPem = Data(pem.utf8)
				}
			}).response.wait().certificates
			
			if reply.success {
				return self.options.format.render(reply.added)
			} else {
				return self.options.format.render(reply.reason)
			}
		}
	}
	
	// MARK: list
	struct ListCertificates: GrpcParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "list",
			abstract: String(localized: "List registered TLS client certificates")
		)
		
		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options
		
		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let reply = try client.certificate(.with {	$0.command = .list }).response.wait().certificates
			
			if reply.success {
				return self.options.format.render(reply.list.certificates)
			} else {
				return self.options.format.render(reply.reason)
			}
		}
	}
	
	// MARK: delete
	struct DeleteCertificate: GrpcParsableCommand {
		static let configuration = CommandConfiguration(commandName: "delete", abstract: String(localized: "Remove a registered TLS client certificate"))
		
		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options
		
		@Argument(help: ArgumentHelp(String(localized: "Certificate fingerprint or name")))
		var fingerprint: String
		
		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let reply = try client.certificate(.with {
				$0.command = .delete
				$0.deleteRequest = .with {
					$0.name = fingerprint
				}}
			).response.wait().certificates
			
			if reply.success {
				return self.options.format.render("Certificate '\(fingerprint)' deleted.")
			} else {
				return self.options.format.render(reply.reason)
			}
		}
	}
	
	// MARK: get
	struct GetCertificate: GrpcParsableCommand {
		static let configuration = CommandConfiguration(commandName: "get", abstract: String(localized: "Return a registered TLS client certificate"))

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Argument(help: ArgumentHelp(String(localized: "Certificate fingerprint or name")))
		var fingerprint: String

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let reply = try client.certificate(.with {
				$0.command = .get
				$0.getRequest = .with {
					$0.name = fingerprint
				}}
			).response.wait().certificates

			if reply.success {
				return reply.get.pem.joined(separator: "\n")
			} else {
				return self.options.format.render(reply.reason)
			}
		}
	}
}

