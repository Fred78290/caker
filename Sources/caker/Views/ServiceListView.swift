//
//  ServiceListView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 21/04/2026.
//

import Foundation
import SwiftUI

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
	private var serviceType: String = "_caked._tcp."
	private var domain: String = "local."

	var body: some View {
		VStack {
			// Services list
			GroupBox(
				content: {
					if viewModel.isScanning {
						HStack {
							ProgressView()
								.scaleEffect(0.8)
							Text("Lookup...")
								.foregroundColor(.secondary)
						}
						.padding()
					}

					if viewModel.services.isEmpty && !viewModel.isScanning {
						Text("Any service found")
							.foregroundColor(.secondary)
							.padding()
					} else {
						List(viewModel.services, id: \.name) { service in
							ServiceRowView(service: service)
						}
						.frame(minHeight: 200)
					}
				},
				label: {
					HStack {
						Text("Services découverts (\(viewModel.services.count))")
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

			HStack {
				Text("Type: \(service.type)")
					.font(.caption)
					.foregroundColor(.secondary)

				Spacer()

				if service.port > 0 {
					Text("Port: \(service.port)")
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}

			if service.domain.isEmpty == false {
				Text("Domaine: \(service.domain)")
					.font(.caption)
					.foregroundColor(.secondary)
			}

			// TXT records if available
			if let txtRecordData = service.txtRecordData() {
				let txtRecord = NetService.dictionary(fromTXTRecord: txtRecordData)

				if !txtRecord.isEmpty == false {
					DisclosureGroup("Informations TXT") {
						VStack(alignment: .leading, spacing: 2) {
							ForEach(txtRecord.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
								HStack {
									Text("\(key):")
										.fontWeight(.semibold)
										.font(.caption)

									if let stringValue = String(data: value, encoding: .utf8) {
										Text(stringValue)
											.font(.caption)
											.foregroundColor(.secondary)
									} else {
										Text("<binaries data>")
											.font(.caption)
											.italic()
											.foregroundColor(.secondary)
									}
								}
							}
						}
					}
					.font(.caption)
				}
			}
		}
		.padding(.vertical, 4)
	}
}

#Preview {
	ServiceListView()
}
