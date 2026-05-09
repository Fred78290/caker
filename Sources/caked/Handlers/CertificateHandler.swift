import CakedLib
//
//  CertificateHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 08/05/2026.
//
import Foundation
import GRPCLib
import NIO

extension LXDCertificate {
	var toCaked: Caked_Certificate {
		.with {
			$0.name = self.name
			$0.type = self.type
			$0.restricted = self.restricted
			$0.projects = self.projects
			$0.certificate = self.certificate
			$0.fingerprint = self.fingerprint
		}
	}
}

struct CertificateHandler: CakedCommand {
	var request: Caked_CertificateRequest

	func run(on: any EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		let request = self.request

		// Execute async work on the provided event loop and wait for the result
		do {
			return try on.makeFutureWithTask {
				switch request.command {
				case .add:
					// certAsPem is Data; convert to String expected by add(name:pem:)
					guard let pemString = String(data: request.addRequest.certAsPem, encoding: .utf8) else {
						return self.replyError(error: String(localized: "Certificate PEM is not valid UTF-8"))
					}
					
					guard let certificate = await LXDCertificateStore.shared.createFromPem(name: request.addRequest.name, pem: pemString)  else {
						return self.replyError(error: String(localized: "Failed to create certificate from PEM"))
					}
					
					return .with {
						$0.certificates = .with {
							$0.success = true
							$0.reason = ""
							$0.added = certificate.toCaked
						}
					}
					
				case .delete:
					let success = await LXDCertificateStore.shared.delete(name: request.deleteRequest.name)
					
					return .with {
						$0.certificates = .with {
							$0.success = success
							$0.reason = success ? "" : String(localized: "Failed to delete certificate")
						}
					}
				case .list:
					let certificates = await LXDCertificateStore.shared.list()
					
					return .with {
						$0.certificates = .with {
							$0.success = true
							$0.reason = ""
							$0.list = .with {
								$0.certificates = certificates.map(\.toCaked)
							}
						}
					}
				
				case .get:
					guard let certificate = await LXDCertificateStore.shared.get(name: self.request.getRequest.name) else {
						return self.replyError(error: String(localized: "Certificate not found"))
					}

					let lines = certificate.certificate.components(separatedBy: "\n")
						.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

					return .with {
						$0.certificates = .with {
							$0.success = true
							$0.reason = ""
							$0.get = .with {
								$0.pem = lines
							}
						}
					}
				default:
					return self.replyError(error: String(localized: "Unknown certificate command"))
				}
			}.wait()
		} catch {
			return self.replyError(error: error)
		}
	}

	func replyError(error: String) -> Caked_Reply {
		.with {
			$0.certificates = .with {
				$0.success = false
				$0.reason = error
			}
		}
	}

	func replyError(error: any Error) -> Caked_Reply {
		.with {
			$0.certificates = .with {
				$0.success = false
				$0.reason = (error as? ServiceError)?.reason ?? String(describing: error)
			}
		}
	}

	func createCommand(request: Caked_CertificateRequest, provider: CakedProvider) throws -> any CakedCommand {
		CertificateHandler(request: request)
	}
}
