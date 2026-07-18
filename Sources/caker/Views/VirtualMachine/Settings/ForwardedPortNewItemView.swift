//
//  ForwardedPortNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import CakeAgentLib
import GRPCLib
import NIOPortForwarding
import SwiftUI

extension [TunnelAttachement] {
	func editItem(_ editItem: TunnelAttachement.ID?) -> TunnelAttachement {
		if let editItem = editItem {
			return self.first(where: { $0.id == editItem }) ?? .init()
		} else {
			return TunnelAttachement(host: -1, guest: -1, proto: .both)
		}
	}
}

struct ForwardedPortNewItemView: View {
	@Binding private var forwardPorts: [TunnelAttachement]
	@State private var newItem: TunnelAttachement
	private let editItem: TunnelAttachement.ID?

	init(_ forwardPorts: Binding<[TunnelAttachement]>, editItem: TunnelAttachement.ID? = nil) {
		self._forwardPorts = forwardPorts
		self.editItem = editItem
		self.newItem = forwardPorts.wrappedValue.editItem(editItem)
	}

	var body: some View {
		EditableListNewItem($forwardPorts, currentItem: $newItem, editItem: editItem) {
			Section("New port forwarding") {
				ForwardedPortDetailView(currentItem: $newItem, readOnly: false)
			}
		} validateItem: { item in
			if Bundle.isApplicationSandboxed && AppState.shared.connectionMode != .remote {
				if let home = try? Utils.getHome(runMode: AppState.shared.connectionMode.runMode), let unixSocket = item.unixDomain, unixSocket.host.isEmpty == false {
					if (unixSocket.host as NSString).expandingTildeInPath.starts(with: home.path(percentEncoded: false)) == false {
						return (false, String(localized: "Host path is not in the sandbox"))
					}
				}
			}

			switch item.oneOf {
			case .none:
				return (false, String(localized: "Please select a type"))
			case .forward(let value):
				if value.proto == .none {
					return (false, String(localized: "Please select a type"))
				}
				
				if value.host < 0 || value.guest <= 0 {
					return (false, String(localized: "Port must be defined"))
				}
			case .unixDomain(let value):
				if value.proto == .none {
					return (false, String(localized: "Please select a type"))
				}

				if value.host.isEmpty || value.guest.isEmpty {
					return (false, String(localized: "Path must be defined"))
				}

				if value.host.utf8.count > URL.maxSocketPathLength {
					return (false, String(localized: "Host path is too long"))
				}

				if value.guest.utf8.count > URL.maxSocketPathLength {
					return (false, String(localized: "Guest path is too long"))
				}
			}

			return (true, nil)
		}
	}
}

#Preview {
	ForwardedPortNewItemView(.constant([]))
}
