//
//  ExternalVirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 17/07/2025.
//

import SwiftUI
import CakedLib
import SwiftTerm
import GRPC
import CakeAgentLib

struct ExternalVirtualMachineView: NSViewRepresentable {
	typealias NSViewType = TerminalView

	private class ExternalVirtualMachineViewDelegate: NSObject, TerminalViewDelegate {
		var terminalView: TerminalView?
		var document: VirtualMachineDocument

		init(document: VirtualMachineDocument) {
			self.document = document
		}

		func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
		}
		
		func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {
		}
		
		func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
		}
		
		func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
		}
		
		func scrolled(source: SwiftTerm.TerminalView, position: Double) {
		}
		
		func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {
		}
		
		func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {
		}
		
		func terminalViewDidChangeSize(_ terminalView: TerminalView) {
		}
		
		func startShell() {
			Task {
				_ = try await CakeAgentHelper(on: Utilities.group.next(), client: client).shell(callOptions: CallOptions(timeLimit: .none))
			}
		}
	}

	@StateObject var document: VirtualMachineDocument
	var automaticallyReconfiguresDisplay: Bool = false
	var callback: VMView.CallbackWindow? = nil

	private var terminalDelegate: ExternalVirtualMachineViewDelegate

	init(document: StateObject<VirtualMachineDocument>, automaticallyReconfiguresDisplay: Bool, callback: VMView.CallbackWindow? = nil) {
		self._document = document
		self.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
		self.callback = callback
		terminalDelegate = ExternalVirtualMachineViewDelegate(document: document.wrappedValue)
	}

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
		self.terminalDelegate.terminalView = nsView

		nsView.terminalDelegate = terminalDelegate
		
		terminalDelegate.startShell()
	}
}
