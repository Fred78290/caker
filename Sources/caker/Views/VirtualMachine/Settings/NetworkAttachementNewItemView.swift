//
//  NetworkAttachementNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//
import ArgumentParser
import SwiftUI
import GRPCLib
import CakedLib
import Virtualization

let macAddressRegex = /^(?:[0-9A-Fa-f]{2}[:-]){5}(?:[0-9A-Fa-f]{2})$/

struct RegexParseableFormatStyle: ParseableFormatStyle {
	struct RegexStategy: ParseStrategy {
		let regex: String

		init(regex: String) {
			self.regex = regex
		}

		func parse(_ value: String) throws -> String {
			guard let regex = try Regex<Substring>(self.regex).wholeMatch(in: value) else {
				return ""
			}

			return value
		}
	}
	
	var parseStrategy: RegexStategy

	init(regex: String) {
		self.parseStrategy = .init(regex: regex)
	}

	func format(_ value: String) -> String {
		return ""
	}
}

extension FormatStyle where Self == RegexParseableFormatStyle {
	static func regex(_ pattern: String) -> RegexParseableFormatStyle {
		.init(regex: pattern)
	}
}

struct VZMacAddressStrategy: ParseStrategy {
	func parse(_ input: String) throws -> VZMACAddress? {
		guard let macAddr = VZMACAddress(string: input) else {
			return nil
		}
		
		return macAddr
	}
}

struct VZMacAddressParseableFormatStyle : ParseableFormatStyle {
	var parseStrategy = VZMacAddressStrategy()
	
	func format(_ value: VZMACAddress?) -> String {
		guard let value = value else {
			return ""
		}
		
		return value.string
	}
}

extension FormatStyle where Self == VZMacAddressParseableFormatStyle {
	static var macAddress: VZMacAddressParseableFormatStyle {
		VZMacAddressParseableFormatStyle()
	}
}


struct NetworkAttachementNewItemView: View {
	@Binding var networks: [BridgeAttachement]
	@State var newItem: BridgeAttachement = .init(network: "nat")
	@State var selectedNetwork: String = "nat"
	@State var selectedMode: NetworkMode = .auto
	@State var macAddress: VZMACAddress? = nil

	let names: [String] = try! NetworksHandler.networks(runMode: .app).map { $0.name }

	var body: some View {
		EditableListNewItem(newItem: $newItem, $networks) {
			Section("New network attachment") {
				Picker("Network name", selection: $selectedNetwork) {
					ForEach(names, id: \.self) { name in
						Text(name).tag(name)
					}
				}
				.onChange(of: selectedNetwork) {
					newItem.network = selectedNetwork
				}
				
				Picker("Mode", selection: $selectedMode) {
					ForEach([NetworkMode.auto, NetworkMode.manual], id: \.self) { mode in
						Text(mode.description).tag(mode).frame(width: 80)
					}
				}
				.onChange(of: selectedMode) {
					newItem.mode = selectedMode
				}

				HStack {
					Text("Mac address")
					Spacer()
					HStack {
						Spacer()
						Button(action: {
							macAddress = VZMACAddress.randomLocallyAdministered()
						}) {
							Image(systemName: "arrow.trianglehead.clockwise")
						}.buttonStyle(.borderless)
						TextField("", value: $macAddress, format: .macAddress)
							.multilineTextAlignment(.center)
							.textFieldStyle(SquareBorderTextFieldStyle())
							.labelsHidden()
							.frame(width: 150)
					}
				}
				.onChange(of: macAddress) {
					newItem.macAddress = macAddress?.string
				}
			}
		}
    }
}

#Preview {
    NetworkAttachementNewItemView(networks: .constant([]))
}
