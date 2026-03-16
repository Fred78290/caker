//
//  VirtualMachineTerminalView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 15/03/2026.
//

import AppKit
import CakeAgentLib
import CakedLib
import GRPC
import GRPCLib
import NIO
import SwiftTerm
import SwiftUI

extension SwiftTerm.Color {
	static var black: SwiftTerm.Color {
		.init(red: 0, green: 0, blue: 0)
	}

	convenience init(_ color: SwiftUI.Color) {
		let (red, green, blue, _) = color.baseComponents

		self.init(red: UInt16(red * 65535), green: UInt16(green * 65535), blue: UInt16(blue * 65535))
	}

	convenience init(_ color: NSColor) {
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		var alpha: CGFloat = 1.0

		if let rgbColor = color.usingColorSpace(.deviceRGB) {
			rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
		}

		self.init(red: UInt16(red * 65535), green: UInt16(green * 65535), blue: UInt16(blue * 65535))
	}

	var uiColor: SwiftUI.Color {
		.init(red: CGFloat(red) / 65535, green: CGFloat(green) / 65535, blue: CGFloat(blue) / 65535)
	}

	var nsColor: NSColor {
		NSColor(red: CGFloat(red) / 65535, green: CGFloat(green) / 65535, blue: CGFloat(blue) / 65535, alpha: 1)
	}
}

class VirtualMachineTerminalView: TerminalView, TerminalViewDelegate {
	private weak var interactiveShell: InteractiveShell!
	private var startShellOnWindow = false

	var fontColor: SwiftTerm.Color {
		get {
			self.terminal.foregroundColor
		}
		set {
			self.terminal.foregroundColor = newValue
		}
	}

	deinit {
		self.closeShell()
	}

	init(interactiveShell: InteractiveShell, frame: CGRect, font: NSFont, color: SwiftTerm.Color) {
		self.interactiveShell = interactiveShell

		super.init(frame: frame, font: font)

		self.terminal.foregroundColor = color
		self.terminalDelegate = self
	}

	public required init?(coder: NSCoder) {
		fatalError("Unimplemented")
	}

	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()

		if startShellOnWindow {
			startShellOnWindow = false
			startShell()
		}
	}

	func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
		self.interactiveShell.sendTerminalSize(rows: newRows, cols: newCols)
	}

	func setTerminalTitle(source: TerminalView, title: String) {
	}

	func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
	}

	func send(source: TerminalView, data: ArraySlice<UInt8>) {
		self.interactiveShell.sendDatas(data: data)
	}

	func scrolled(source: TerminalView, position: Double) {
	}

	func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {
		if let str = String(bytes: content, encoding: .utf8) {
			let pasteBoard = NSPasteboard.general
			pasteBoard.clearContents()
			pasteBoard.writeObjects([str as NSString])
		}
	}

	func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {
	}

	func terminalViewDidChangeSize(_ terminalView: TerminalView) {
	}

	func closeShell() {
		self.interactiveShell.closeShell {
			Logger(self).debug("Shell closed")
		}
	}

	private func displayDatas(_ datas: Data) -> Void {
		var converted: [UInt8] = []

		datas.forEach {
			if $0 == 0x0a {
				converted.append(0x0d)
			}

			converted.append($0)
		}

		self.feed(byteArray: converted[...])
	}

	func startShell() {
		guard self.window != nil else {
			self.startShellOnWindow = true
			return
		}

		let logger = Logger(self)
		let terminal = self.getTerminal()

		self.interactiveShell.startShell(rows: terminal.rows, cols: terminal.cols) { response in
			if case .established(let established, let reason) = response {
				if established == false {
					if reason != "Connection refused" {
						alertError(ServiceError(reason))
					}

					self.closeShell()
				} else {
					logger.debug("Shell established for \(self.interactiveShell.name)")
				}
			} else if case .exitCode(let code) = response {
				#if DEBUG
				logger.debug("Shell exited with code \(code) for \(self.interactiveShell.name)")
				#endif

				self.closeShell()
			} else if case .stdout(let datas) = response {
				self.displayDatas(datas)
			} else if case .stderr(let datas) = response {
				self.displayDatas(datas)
			}
		}
	}
}

