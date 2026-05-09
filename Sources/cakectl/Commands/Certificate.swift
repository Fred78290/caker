//
//  Certificate.swift
//  Caker
//
//  Created by Frederic BOLTZ on 08/05/2026.
//

import ArgumentParser
import Foundation
import GRPCLib
import Security

// MARK: - Certificate command group

struct Certificate: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "certificate",
		abstract: String(localized: "Manage TLS client certificates for REST API authentication"),
		subcommands: [AddCertificate.self, ListCertificates.self, DeleteCertificate.self]
	)

	// MARK: add

	struct AddCertificate: AsyncParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "add",
			abstract: String(localized: "Register a PEM client certificate in caked")
		)

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Option(
			name: [.customLong("rest-url")],
			help: ArgumentHelp(String(localized: "caked REST API base URL"), valueName: "url")
		)
		var restURL: String = "http://localhost:8080"

		@Option(
			name: .shortAndLong,
			help: ArgumentHelp(String(localized: "Friendly name for the certificate"))
		)
		var name: String

		@Argument(help: ArgumentHelp(String(localized: "Path to PEM certificate file")))
		var pemFile: String

		mutating func run() async throws {
			let pem = try String(contentsOfFile: pemFile, encoding: .utf8)

			guard !pem.isEmpty else {
				throw GrpcError(code: 1, reason: "Certificate file is empty: \(pemFile)")
			}

			let body: [String: Any] = [
				"name": name,
				"type": "client",
				"restricted": false,
				"projects": [String](),
				"certificate": pem,
			]

			let (_, http) = try await restRequest(
				method: "POST",
				path: "/1.0/certificates",
				body: body
			)

			switch http.statusCode {
			case 201:
				print(options.format.render("Certificate '\(name)' added successfully."))
			case 409:
				throw GrpcError(code: 1, reason: "Certificate already exists.")
			default:
				throw GrpcError(code: 1, reason: "HTTP \(http.statusCode) from caked REST API.")
			}
		}
	}

	// MARK: list

	struct ListCertificates: AsyncParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "list",
			abstract: String(localized: "List registered TLS client certificates")
		)

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Option(
			name: [.customLong("rest-url")],
			help: ArgumentHelp(String(localized: "caked REST API base URL"), valueName: "url")
		)
		var restURL: String = "http://localhost:8080"

		mutating func run() async throws {
			let (data, http) = try await restRequest(method: "GET", path: "/1.0/certificates?recursion=1")

			guard http.statusCode == 200 else {
				throw GrpcError(code: 1, reason: "HTTP \(http.statusCode) from caked REST API.")
			}

			// Parse the LXD-style response {"metadata": [...]}
			guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
			      let metadata = json["metadata"] as? [[String: Any]]
			else {
				throw GrpcError(code: 1, reason: "Unexpected response from caked REST API.")
			}

			if metadata.isEmpty {
				print(options.format.render("No certificates registered."))
				return
			}

			var lines: [String] = []
			for cert in metadata {
				let fp   = cert["fingerprint"] as? String ?? "-"
				let nm   = cert["name"] as? String ?? "-"
				let tp   = cert["type"] as? String ?? "-"
				lines.append("\(fp)  \(nm)  \(tp)")
			}
			print(options.format.render(lines.joined(separator: "\n")))
		}
	}

	// MARK: delete

	struct DeleteCertificate: AsyncParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "delete",
			abstract: String(localized: "Remove a registered TLS client certificate")
		)

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Option(
			name: [.customLong("rest-url")],
			help: ArgumentHelp(String(localized: "caked REST API base URL"), valueName: "url")
		)
		var restURL: String = "http://localhost:8080"

		@Argument(help: ArgumentHelp(String(localized: "Certificate fingerprint or name")))
		var fingerprint: String

		mutating func run() async throws {
			let (_, http) = try await restRequest(
				method: "DELETE",
				path: "/1.0/certificates/\(fingerprint)"
			)

			switch http.statusCode {
			case 200:
				print(options.format.render("Certificate '\(fingerprint)' deleted."))
			case 404:
				throw GrpcError(code: 1, reason: "Certificate '\(fingerprint)' not found.")
			default:
				throw GrpcError(code: 1, reason: "HTTP \(http.statusCode) from caked REST API.")
			}
		}
	}
}

// MARK: - REST helper

/// Shared URLSession delegate that handles custom CA verification and Basic auth.
private final class RESTDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
	let caCertPath: String?

	init(caCertPath: String?) {
		self.caCertPath = caCertPath
	}

	func urlSession(
		_ session: URLSession,
		didReceive challenge: URLAuthenticationChallenge,
		completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
	) {
		guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
		      let trust = challenge.protectionSpace.serverTrust
		else {
			completionHandler(.performDefaultHandling, nil)
			return
		}

		if let path = caCertPath,
		   let caDer = pemFileToDer(path: path),
		   let caCert = SecCertificateCreateWithData(nil, caDer as CFData)
		{
			SecTrustSetAnchorCertificates(trust, [caCert] as CFArray)
			SecTrustSetAnchorCertificatesOnly(trust, true)
		}

		completionHandler(.useCredential, URLCredential(trust: trust))
	}

	/// Converts the first PEM block in a file to DER Data.
	private func pemFileToDer(path: String) -> Data? {
		guard let pem = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
		let lines = pem.components(separatedBy: "\n")
			.filter { !$0.hasPrefix("-----") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
		let base64 = lines.joined()
		return Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
	}
}

// MARK: - restRequest helper (available to all three subcommands)

private extension Certificate.AddCertificate {
	func restRequest(
		method: String,
		path: String,
		body: [String: Any]? = nil
	) async throws -> (Data, HTTPURLResponse) {
		try await performRESTRequest(
			method: method, path: path, body: body,
			restURL: restURL, options: options
		)
	}
}

private extension Certificate.ListCertificates {
	func restRequest(
		method: String,
		path: String,
		body: [String: Any]? = nil
	) async throws -> (Data, HTTPURLResponse) {
		try await performRESTRequest(
			method: method, path: path, body: body,
			restURL: restURL, options: options
		)
	}
}

private extension Certificate.DeleteCertificate {
	func restRequest(
		method: String,
		path: String,
		body: [String: Any]? = nil
	) async throws -> (Data, HTTPURLResponse) {
		try await performRESTRequest(
			method: method, path: path, body: body,
			restURL: restURL, options: options
		)
	}
}

private func performRESTRequest(
	method: String,
	path: String,
	body: [String: Any]?,
	restURL: String,
	options: Client.Options
) async throws -> (Data, HTTPURLResponse) {
	guard let url = URL(string: restURL + path) else {
		throw GrpcError(code: 1, reason: "Invalid REST URL: \(restURL + path)")
	}

	let isHTTPS = url.scheme?.lowercased() == "https"
	let delegate: RESTDelegate? = isHTTPS ? RESTDelegate(caCertPath: options.caCert) : nil
	let session = URLSession(
		configuration: .ephemeral,
		delegate: delegate,
		delegateQueue: nil
	)

	var request = URLRequest(url: url)
	request.httpMethod = method
	request.setValue("application/json", forHTTPHeaderField: "Content-Type")

	// Basic auth when a password is provided (username ignored by caked, but required by RFC 7617)
	if let password = options.password {
		let token = Data("cakectl:\(password)".utf8).base64EncodedString()
		request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
	}

	if let body {
		request.httpBody = try JSONSerialization.data(withJSONObject: body)
	}

	let (data, response) = try await session.data(for: request)

	guard let http = response as? HTTPURLResponse else {
		throw GrpcError(code: 1, reason: "Invalid HTTP response")
	}

	return (data, http)
}
