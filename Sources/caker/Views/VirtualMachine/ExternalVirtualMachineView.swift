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

typealias CakeAgentExecuteStream = BidirectionalStreamingCall<CakeAgent.ExecuteRequest, CakeAgent.ExecuteResponse>

struct ExternalVirtualMachineView: NSViewRepresentable {

	typealias NSViewType = TerminalView

	private class ExternalVirtualMachineViewDelegate: NSObject, TerminalViewDelegate {
		private let dismiss: DismissAction
		private var document: VirtualMachineDocument
		private var client: CakeAgentClient
		private var stream: CakeAgentExecuteStream?
		private var terminalView: NSViewType?

		init(document: VirtualMachineDocument, dismiss: DismissAction) throws {
			self.document = document
			self.dismiss = dismiss
			self.client = try Utilities.createCakeAgentClient(on: Utilities.group.next(), runMode: .app, name: document.name)
		}

		func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
			if let stream = self.stream {
				stream.sendTerminalSize(rows: Int32(newRows), cols: Int32(newCols))
			}
		}
		
		func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {
		}
		
		func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
		}
		
		func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
			if let stream = self.stream {
				data.withUnsafeBytes { ptr in
					let message = CakeAgent.ExecuteRequest.with {
						$0.input = Data(bytes: ptr.baseAddress!, count: ptr.count)
					}

					try? stream.sendMessage(message).wait()
				}
			}
		}
		
		func scrolled(source: SwiftTerm.TerminalView, position: Double) {
		}
		
		func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {
			if let str = String (bytes: content, encoding: .utf8) {
				let pasteBoard = NSPasteboard.general
				pasteBoard.clearContents()
				pasteBoard.writeObjects([str as NSString])
			}
		}
		
		func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {
		}
		
		func terminalViewDidChangeSize(_ terminalView: TerminalView) {
		}
		
		func display(_ datas: Data) {
			if let terminalView = self.terminalView {
				let input = [UInt8](datas)
				terminalView.feed(byteArray: input[...])
			}
		}

		func startShell(terminalView: NSViewType) {
			self.terminalView = terminalView

			let stream = client.execute(callOptions: CallOptions(timeLimit: .none)) { response in
				if case let .exitCode(code) = response.response {
					Logger(self).debug("Shell exited with code \(code) for \(self.document.name)")

					self.client.close().whenComplete { _ in
						DispatchQueue.main.async {
							self.dismiss()
						}
					}
				} else if case let .stdout(datas) = response.response {
					self.display(datas)
				} else if case let .stderr(datas) = response.response {
					self.display(datas)
				} else if case .established = response.response {
					terminalView.terminalDelegate = self
				}
			}

			self.stream = stream
			
			stream.sendTerminalSize(rows: Int32(terminalView.getTerminal().rows), cols: Int32(terminalView.getTerminal().cols))
			stream.sendShell()
		}
	}

	@StateObject var document: VirtualMachineDocument
	var automaticallyReconfiguresDisplay: Bool = false
	var callback: VMView.CallbackWindow? = nil

	private var terminalDelegate: ExternalVirtualMachineViewDelegate

	init(document: StateObject<VirtualMachineDocument>, automaticallyReconfiguresDisplay: Bool, dismiss: DismissAction, callback: VMView.CallbackWindow? = nil) throws {
		self._document = document
		self.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
		self.callback = callback
		self.terminalDelegate = try ExternalVirtualMachineViewDelegate(document: document.wrappedValue, dismiss: dismiss)
	}

	func makeNSView(context: Context) -> NSViewType {
		let view = NSViewType(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100)))

		if let callback = self.callback {
			DispatchQueue.main.async { [weak view] in
				callback(view?.window)
			}
		}

		return view
	}
	
	func updateNSView(_ nsView: NSViewType, context: Context) {
		terminalDelegate.startShell(terminalView: nsView)
	}
}
