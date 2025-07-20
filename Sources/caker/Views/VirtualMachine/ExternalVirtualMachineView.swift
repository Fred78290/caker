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
import GRPCLib
import CakeAgentLib
import NIO
import CakedLib
import AppKit

typealias CakeAgentExecuteStream = BidirectionalStreamingCall<CakeAgent.ExecuteRequest, CakeAgent.ExecuteResponse>

struct ExternalVirtualMachineView: NSViewRepresentable {
	
	typealias NSViewType = TerminalView
	
	@StateObject var document: VirtualMachineDocument
	@State var fontPickerDelegate:FontPickerDelegate? = nil
	
	private let dismiss: DismissAction
	private var callback: VMView.CallbackWindow? = nil
	private let fontManager = NSFontManager.shared
	private let fontPanel = NSFontPanel.shared
	private let terminalView: TerminalView
	
	class FontPickerDelegate: NSObject, NSWindowDelegate {
		@Binding var visible: Bool

		var terminalView: TerminalView
		
		init(visible: Binding<Bool>, terminalView: TerminalView) {
			self.terminalView = terminalView
			self._visible = visible
		}
		
		@objc
		func changeFont(_ sender: Any ) {
			// the sender is a font manager
			guard let fontManager = sender as? NSFontManager else {
				return
			}

			self.terminalView.font = fontManager.convert(self.terminalView.font)
			self.visible = false
			
			Defaults.saveCurrentFont(self.terminalView.font)
		}
		
		func windowWillClose(_ notification: Notification) {
			self.visible = false
		}
	}
	
	init(document: StateObject<VirtualMachineDocument>, size: CGSize, dismiss: DismissAction, callback: VMView.CallbackWindow? = nil) throws {
		self._document = document
		self.callback = callback
		self.dismiss = dismiss
		self.terminalView = NSViewType(frame: CGRect(origin: .zero, size: size), font: Defaults.currentFont())
	}
	
	func makeNSView(context: Context) -> NSViewType {
		if let callback = self.callback {
			DispatchQueue.main.async {
				callback(self.terminalView.window)
			}
		}
		
		return terminalView
	}

	func sizeThatFits(_ proposal: ProposedViewSize, nsView: TerminalView, context: Context) -> CGSize? {
		if let width = proposal.width, let height = proposal.height {
			let newSize = CGSize(width: width, height: height)

			print("\(newSize)")

			document.changingSize = true
			nsView.frame = CGRect(origin: .zero, size: newSize)
			nsView.needsLayout = true
			document.changingSize = false

			return newSize
		}

		return nil
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.getTerminal().options.convertEol = true
		
		try? self.document.startShell(terminalView: nsView, dismiss: dismiss)
	}
	
	func displayFontPanel(_ visible: Binding<Bool>) {
		if visible.wrappedValue {
			self.fontPickerDelegate = FontPickerDelegate(visible: visible, terminalView: self.terminalView)
			
			NSFontManager.shared.target = self.fontPickerDelegate
			NSFontManager.shared.action = #selector(FontPickerDelegate.changeFont(_:))

			NSFontPanel.shared.setPanelFont(self.terminalView.font, isMultiple: false)
			NSFontPanel.shared.orderBack(nil)
			NSFontPanel.shared.delegate = self.fontPickerDelegate
			NSFontPanel.shared.worksWhenModal = true
		} else {
			NSFontPanel.shared.orderOut(nil)
		}
	}
}

extension View where Self == ExternalVirtualMachineView {
	func fontPanel(isPresented: Binding<Bool>) -> some View {
		self.displayFontPanel(isPresented)

		return self
	}
}
