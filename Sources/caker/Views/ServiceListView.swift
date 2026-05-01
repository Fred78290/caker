//  ServiceListView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 21/04/2026.
//

import Foundation
import SwiftUI
import CakedLib
import CakeAgentLib
import GRPCLib
import Darwin

extension ConnectionManager {
	func isConnected(to service: NetService) -> Bool {
		guard connectionMode == .remote else { return false }
		guard let serviceURL = self.serviceURL, serviceURL.port == service.port else { return false }
		guard let connectedHost = normalizedHost(serviceURL.host) else { return false }

		if let serviceHost = normalizedHost(service.hostName), connectedHost == serviceHost {
			return true
		}

		return resolvedAddressHosts(for: service).contains(connectedHost)
	}

	private func normalizedHost(_ host: String?) -> String? {
		guard let host else { return nil }

		let normalizedHost = host
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.trimmingCharacters(in: CharacterSet(charactersIn: "."))
			.lowercased()

		return normalizedHost.isEmpty ? nil : normalizedHost
	}

	private func resolvedAddressHosts(for service: NetService) -> Set<String> {
		guard let addresses = service.addresses else { return [] }

		return Set(addresses.compactMap { addressData in
			guard !addressData.isEmpty else { return nil }

			var storage = sockaddr_storage()
			let storageSize = min(addressData.count, MemoryLayout<sockaddr_storage>.size)

			return addressData.withUnsafeBytes { rawBuffer in
				guard let baseAddress = rawBuffer.baseAddress else { return nil }

				memcpy(&storage, baseAddress, storageSize)

				var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
				let result = withUnsafePointer(to: &storage) {
					$0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
						getnameinfo(
							$0,
							socklen_t(addressData.count),
							&hostBuffer,
							socklen_t(hostBuffer.count),
							nil,
							0,
							NI_NUMERICHOST
						)
					}
				}

				guard result == 0 else { return nil }
				return normalizedHost(String(cString: hostBuffer))
			}
		})
	}
}

extension NetService {
	var tlsIsRequired: Bool {
		guard let txtRecordData = self.txtRecordData() else {
			return false
		}
		
		let txtRecord = NetService.dictionary(fromTXTRecord: txtRecordData)

		guard let value = txtRecord["tls"], let stringValue = String(data: value, encoding: .utf8) else {
			return false
		}

		return stringValue.lowercased() == "true"
	}

	func serviceURL(_ password: String? = nil) -> URL {
		var serviceURL = URLComponents()

		serviceURL.host = self.hostName
		serviceURL.port = self.port
		serviceURL.scheme = self.tlsIsRequired ? "tcps" : "tcp"
		serviceURL.password = password

		return serviceURL.url!
	}
}

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
    @State private var isPresentingManualSheet: Bool = false

	@State private var manualAddress: String = ""
	@State private var manualPort: Int = Caked.defaultServicePort
    @State private var manualPassword: String = ""
    @State private var manualUseTLS: Bool = true
    @State private var manualError: String? = nil
	@ObservedObject private var appState: AppState = .shared

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

	private func connect(service: NetService) {
		self.selectedService = service
        self.enteredPassword = ""

		if checkIfPasswordIsRequired(service: service) {
			self.isPresentingPasswordPrompt = true
		} else {
			let serviceURL = service.serviceURL()

			self.errorMessage = nil
			self.displayAlert = false

			let ok = checkIfServiceIsReachable(serviceURL)

			if ok.reachable {
				AppState.shared.connectToRemote(serviceURL)
			} else {
				self.failedToConnect(service.description, errorMessage: ok.errorMessage)
			}
		}
	}

	private func failedToConnect(_ service: String, errorMessage: String?) {
		if let errorMessage = errorMessage {
			self.errorMessage = String(localized: "Failed to connect to the service \(service).\nPlease check the address and try again.\n\n\(errorMessage)")
		} else {
			self.errorMessage = String(localized: "The service \(service) is unreachable.")
		}

		self.displayAlert = true
	}

	private func connectWithPassword(service: NetService, password: String? = nil) {
		let serviceURL = service.serviceURL(password)

		self.errorMessage = nil
		self.displayAlert = false

		let ok = checkIfServiceIsReachable(serviceURL)

		if ok.reachable {
			AppState.shared.connectToRemote(serviceURL)
		} else {
			self.failedToConnect(service.description, errorMessage: ok.errorMessage)
		}
	}

	private func checkIfServiceIsReachable(_ serviceURL: URL) -> (reachable: Bool, errorMessage: String?) {
		do {
			_ = try ServiceHandler.createCakedServiceClient(serviceURL: serviceURL, runMode: .user).checkReliability(.init()).response.wait()
			return (true, nil)
		} catch {
			Logger(self).error("Failed to connect to service at \(serviceURL.hiddenPasswordURL): \(error)")
			return (false, error.reason)
		}
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

	private func manualConnect() {
		let address = manualAddress.trimmingCharacters(in: .whitespacesAndNewlines)

		guard address.isEmpty == false else {
			manualError = String(localized: "Please enter an address.")
			return
		}

		guard (1...65535).contains(manualPort) else {
			manualError = String(localized: "Please enter a valid port (1-65535).")
			return
		}

		var serviceURL = URLComponents()

		serviceURL.host = address
		serviceURL.port = manualPort
		serviceURL.scheme = manualUseTLS ? "tcps" : "tcp"
		serviceURL.password = manualPassword.isEmpty ? nil : manualPassword

		guard let url = serviceURL.url else {
			manualError = String(localized: "Please enter a valid hostname or IP address.")
			return
		}

		let result = checkIfServiceIsReachable(url)

		if result.reachable {
			isPresentingManualSheet = false

			AppState.shared.connectToRemote(url)
		} else {
			manualError = result.errorMessage
		}
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
									ServiceRowView(service: service,
												   selected: service == selectedService,
												   connected: self.appState.connectionManager.isConnected(to: service),
												   onConnect: { service in
										self.connect(service: service)
									})
									.tag(service)
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
			HStack {
				Spacer()
				Button("Connect to a server") {
                    isPresentingManualSheet = true
				}
			}.padding()
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
            .padding()
            .frame(width: 250)
        }
        .sheet(isPresented: $isPresentingManualSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Connect to Server")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
					LabeledContent("Address (host or ip)") {
						TextField("", text: $manualAddress)
							.textFieldStyle(.roundedBorder)
							.disableAutocorrection(true)
							.textCase(.lowercase)
					}

					LabeledContent("Port") {
						Spacer()
						TextField("", value: $manualPort, format: .number)
							.textFieldStyle(.roundedBorder)
							.frame(width: 50)
					}

					LabeledContent("Password (optional)") {
						SecureField("", text: $manualPassword)
							.textFieldStyle(.roundedBorder)
					}

                    Toggle("Use TLS", isOn: $manualUseTLS)
                }

                if let manualError {
                    Text(manualError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                HStack {
                    Spacer()
                    Button("Cancel") {
                        isPresentingManualSheet = false
                        manualError = nil
                    }
                    Button("Connect") {
						self.manualConnect()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(manualAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manualPort == 0)
                }
            }
            .padding()
            .frame(width: 450)
        }
	}
}

struct ServiceRowView: View {
	let service: NetService
	let selected: Bool
	let connected: Bool
	let onConnect: (NetService) -> Void

	var serviceInfos: some View {
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
	}

	var serviceDetails: some View {
		HStack(alignment: .center, spacing: 2) {
			if let txtRecordData = service.txtRecordData() {
				let txtRecord = NetService.dictionary(fromTXTRecord: txtRecordData)

				if txtRecord.isEmpty == false {
					ForEach(txtRecord.filter({["tls", "secure"].contains($0.key.lowercased())}) .sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
						HStack {
							let key = String(localized: .init(stringLiteral: key)) + ":"

							Text(key)
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
		}.contextMenu {
			if connected {
				Button("Disconnect") {
					AppState.shared.connectToLocal()
				}.log(text: "Disconnecting from service")
			} else {
				Button("Connect") {
					self.onConnect(service)
				}.log(text: "Connecting to service")
			}
		}
		.onTapGesture(count: 2) {
			if connected {
				AppState.shared.connectToLocal()
			} else {
				self.onConnect(service)
			}
		}
	}

	var body: some View {
		if selected {
			HStack(alignment: .center) {
				VStack(alignment: .leading, spacing: 4) {
					self.serviceInfos
					self.serviceDetails
				}
				.padding(.vertical, 4)

				if connected {
					if #available(macOS 26.0, *) {
						Button("Disconnect") {
							AppState.shared.connectToLocal()
						}.buttonStyle(.glass)
					} else {
						Button("Disconnect") {
							AppState.shared.connectToLocal()
						}.buttonStyle(.bordered)
					}
				} else {
					if #available(macOS 26.0, *) {
						Button("Connect") {
							self.onConnect(self.service)
						}.buttonStyle(.glass)
					} else {
						Button("Connect") {
							self.onConnect(self.service)
						}.buttonStyle(.bordered)
					}
				}
			}
		} else {
			VStack(alignment: .leading, spacing: 4) {
				self.serviceInfos
				self.serviceDetails
			}
			.padding(.vertical, 4)
		}
	}
}

#Preview {
	ServiceListView()
}

