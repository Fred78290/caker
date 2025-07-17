//
//  ExternalVirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 17/07/2025.
//

import SwiftUI
import CakedLib
import SwiftTerm

struct ExternalVirtualMachineView: NSViewRepresentable {
	typealias NSViewType = LocalProcessTerminalView

	@StateObject var document: VirtualMachineDocument
	var automaticallyReconfiguresDisplay: Bool = false
	var callback: VMView.CallbackWindow? = nil

	func makeNSView(context: Context) -> NSViewType {
		var view = NSViewType(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100)))

		if let callback = self.callback {
			DispatchQueue.main.async { [weak view] in
				callback(view?.window)
			}
		}

		return view
	}
	
	func updateNSView(_ nsView: NSViewType, context: Context) {
	}
}
