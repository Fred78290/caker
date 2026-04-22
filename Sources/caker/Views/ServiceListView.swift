//
//  ServiceListView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 21/04/2026.
//

import Foundation
import SwiftUI
import CakedLib
import CakeAgentLib

class ServiceListViewModel: ObservableObject {
	@Published var services: [NetService] = []
	@Published var isScanning: Bool = false

	private var serviceLister: BonjourServiceLister?

	func startScanning(serviceType: String = "_caked._tcp.", domain: String = "local.") {
		guard !isScanning else { return }

		serviceLister = BonjourServiceLister(
			serviceType: serviceType,
			domain: domain
		) { [weak self] services in
			DispatchQueue.main.async {
				self?.services = services
			}
		}

		serviceLister?.start()
		isScanning = true
	}

	func stopScanning() {
		serviceLister?.stop()
		serviceLister = nil
		isScanning = false
		services = []
	}

	deinit {
		stopScanning()
	}
}

struct ServiceListView: View {
	@StateObject private var viewModel = ServiceListViewModel()
	@State private var selectedService: NetService? = nil
    @State private var isPresentingPasswordPrompt: Bool = false
    @State private var enteredPassword: String = ""
	@State private var displayAlert: Bool = false
	@State private var errorMessage: String? = nil
	private var serviceType: String = "_caked._tcp."
	private var domain: String = "local."

	private func checkIfPasswordIsRequired(service: NetService) -> Bool {
		guard let txtRecordData = service.txtRecordData() else {
			return false
		}
		
		let txtRecord = NetService.dictionary(fromTXTRecord: txtRecordData)

		guard let value = txtRecord["secure"], let stringValue = String(data: value, encoding: .utf8) else {
			return false
		}

		return stringValue.lowercased() == "true"
	}

	private func checkIfTlsIsRequired(service: NetService) -> Bool {
		guard let txtRecordData = service.txtRecordData() else {
			return false
		}
		
		let txtRecord = NetService.dictionary(fromTXTRecord: txtRecordData)

		guard let value = txtRecord["tls"], let stringValue = String(data: value, encoding: .utf8) else {
			return false
		}

		return stringValue.lowercased() == "true"
	}

	private func connect(service: NetService) {
		let listenAddress = "tcp://\(service.hostName!):\(service.port)"

		self.selectedService = service
        self.enteredPassword = ""

		if checkIfPasswordIsRequired(service: service) {
			self.isPresentingPasswordPrompt = true
		} else {
			let tlsIsRequired = checkIfTlsIsRequired(service: service)

			self.errorMessage = nil
			self.displayAlert = false

			if checkIfServiceIsReachable(listenAddress: listenAddress, password: nil, tlsIsRequired: tlsIsRequired) {
				AppState.shared.connectToRemote(listenAddress: listenAddress, password: nil, tls: tlsIsRequired)
			} else {
				if let errorMessage {
					self.errorMessage = String(localized: "Failed to connect to the service \(service).\nPlease check the address and try again.\n\n\(errorMessage)")
				} else {
					self.errorMessage = String(localized: "The service \(service) is unreachable.")
				}

				self.displayAlert = true
			}
		}
	}

	private func connectWithPassword(service: NetService, password: String? = nil) {
		let listenAddress = "tcp://\(service.hostName!):\(service.port)"
		let tlsIsRequired = checkIfTlsIsRequired(service: service)

		self.errorMessage = nil
		self.displayAlert = false

		if checkIfServiceIsReachable(listenAddress: listenAddress, password: password, tlsIsRequired: tlsIsRequired) {
			AppState.shared.connectToRemote(listenAddress: listenAddress, password: password, tls: tlsIsRequired)
		} else {
			if let errorMessage {
				self.errorMessage = String(localized: "Failed to connect to the service \(service).\nPlease check the address and try again.\n\n\(errorMessage)")
			} else {
				self.errorMessage = String(localized: "The service \(service) is unreachable.")
			}

			self.displayAlert = true
		}
	}

	private func checkIfServiceIsReachable(listenAddress: String, password: String? = nil, tlsIsRequired: Bool) -> Bool {
		guard let client = try? ServiceHandler.createCakedServiceClient(listenAddress: listenAddress, password: password, tls: tlsIsRequired, runMode: .user) else {
			return false
		}

		do {
			_ = try client.checkReliability(.init()).response.wait()

			return true
		} catch {
			self.errorMessage = error.reason
		}

		return false
	}

	private func handlePasswordSubmit() {
        guard let service = selectedService else {
            isPresentingPasswordPrompt = false
            return
        }
        let password = enteredPassword
        // TODO: Use `service` and `password` to perform the actual connection.
        // For now we just dismiss the sheet.
        isPresentingPasswordPrompt = false
        enteredPassword = ""

		// Example placeholder: print or log the attempt
		Logger(self).debug("Attempting to connect to \(service.name) with provided password (\(password.count) characters)")
		
		self.connectWithPassword(service: service, password: password)
    }

	var body: some View {
		VStack {
			// Services list
			GroupBox(
				content: {
					GeometryReader { geom in
						if viewModel.services.isEmpty {
							if #available(macOS 14, *) {
								VStack(alignment: .center) {
									ContentUnavailableView("Any service found", systemImage: "tray")
								}.frame(width: geom.size.width)
							} else {
								VStack(alignment: .center) {
									Image(systemName: "tray").resizable().scaledToFit().frame(width: 48, height: 48).foregroundStyle(.gray)
									Text("Any service found").font(.largeTitle).fontWeight(.bold).foregroundStyle(.gray).multilineTextAlignment(.center)
								}.frame(width: geom.size.width)
							}
						} else {
							List(selection: $selectedService) {
								ForEach(viewModel.services, id: \.name) { service in
									ServiceRowView(service: service)
										.tag(service)
										.contextMenu {
											Button("Connect") {
												self.connect(service: service)
											}
										}
								}
							}
							.frame(minHeight: geom.size.height)
							.alternatingRowBackgrounds()
							.clipShape(RoundedRectangle(cornerRadius: 6))
							.overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(CGColor.init(gray: 0.8, alpha: 0.4)), lineWidth: 1))
						}
					}
				},
				label: {
					HStack {
						Text("Discovered servers (\(viewModel.services.count))")
							.font(.headline)
						Spacer()
						if viewModel.isScanning {
							Image(systemName: "antenna.radiowaves.left.and.right")
								.foregroundColor(.blue)
								.symbolEffect(.pulse)
						}
					}
				}
			)
			.padding()

			Spacer()
		}
		.onAppear {
			viewModel.startScanning()
		}
		.onDisappear {
			viewModel.stopScanning()
		}
		.alert("Unable to connect", isPresented: $displayAlert) {
			VStack(alignment: .center, spacing: 5) {
				Label("Unable to connect to \(selectedService?.name ?? "the server")", systemImage: "exclamationmark.triangle.fill")
					.font(.headline)
					.foregroundColor(.red)

				if let errorMessage {
					Text(errorMessage)
						.font(.body)
						.foregroundColor(.secondary)
				}

				Button("OK", role: .cancel, action: {
					self.errorMessage = nil
					self.displayAlert = false
				})
			}
		}
        .sheet(isPresented: $isPresentingPasswordPrompt) {
            VStack(spacing: 16) {
                Text("Enter Password")
                    .font(.headline)
                if let service = selectedService {
                    Text("for \(service.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                SecureField("Password", text: $enteredPassword)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        handlePasswordSubmit()
                    }
                HStack {
                    Button("Cancel") {
                        isPresentingPasswordPrompt = false
                        enteredPassword = ""
                    }
                    Button("Connect") {
                        handlePasswordSubmit()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(enteredPassword.isEmpty)
                }
            }
            .padding(24)
            .frame(minWidth: 360)
        }
	}
}

struct ServiceRowView: View {
	let service: NetService

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Image(systemName: "network")
					.foregroundColor(.blue)

				Text(service.name)
					.font(.headline)

				Spacer()

				if let hostName = service.hostName {
					Text(hostName)
						.font(.caption)
						.foregroundColor(.secondary)
						.padding(.horizontal, 6)
						.padding(.vertical, 2)
						.background(Color.secondary.opacity(0.1))
						.cornerRadius(4)
				}
			}

			// TXT records if available
			HStack(alignment: .center, spacing: 2) {
				if let txtRecordData = service.txtRecordData() {
					let txtRecord = NetService.dictionary(fromTXTRecord: txtRecordData)

					if txtRecord.isEmpty == false {
						ForEach(txtRecord.filter({["tls", "secure"].contains($0.key.lowercased())}) .sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
							HStack {
								Text("\(key):")
									.fontWeight(.semibold)
									.font(.caption)

								if let stringValue = String(data: value, encoding: .utf8) {
									Text(stringValue)
										.font(.caption)
										.foregroundColor(.secondary)
										.padding(.horizontal, 6)
										.padding(.vertical, 2)
										.background(Color.secondary.opacity(0.1))
										.cornerRadius(4)
								}
							}
						}
					}
				}
				Spacer()
				if service.port > 0 {
					Text("Port: \(service.port)")
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
		}
		.padding(.vertical, 4)
	}
}

#Preview {
	ServiceListView()
}

