//
//  ExternalVirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 17/07/2025.
//

import AppKit
import CakeAgentLib
import CakedLib
import GRPC
import GRPCLib
import NIO
import SwiftTerm
import SwiftUI

typealias CakeAgentExecuteStream = BidirectionalStreamingCall<CakeAgent.ExecuteRequest, CakeAgent.ExecuteResponse>

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

		if let components = color.cgColor.components {
			red = components[0]
			green = components[1]
			blue = components[2]
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
	var document: VirtualMachineDocument!
	var fontColor: SwiftTerm.Color {
		get {
			self.terminal.foregroundColor
		}
		set {
			self.terminal.foregroundColor = newValue
		}
	}

	init(document: VirtualMachineDocument, frame: CGRect, font: NSFont, color: SwiftTerm.Color) {
		self.document = document

		super.init(frame: frame, font: font)

		self.terminal.foregroundColor = color
		self.terminalDelegate = self
	}

	public required init?(coder: NSCoder) {
		super.init(coder: coder)
		self.terminalDelegate = self
	}

	func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
		self.document.sendTerminalSize(rows: newRows, cols: newCols)
	}

	func setTerminalTitle(source: TerminalView, title: String) {
	}

	func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
	}

	func send(source: TerminalView, data: ArraySlice<UInt8>) {
		self.document.sendDatas(data: data)
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
		print("terminalViewDidChangeSize")
	}

}

struct ColorWell: NSViewRepresentable {
	typealias NSViewType = NSColorWell

	@Binding var selection: SwiftUI.Color

	private let colorWellDelegate: ColorWellDelegate

	private class ColorWellDelegate: NSObject {
		@Binding var selection: SwiftUI.Color

		init(selection: Binding<SwiftUI.Color>) {
			self._selection = selection
		}

		@objc func colorChanged(_ colorWell: NSColorWell) {
			self.selection = SwiftUI.Color(colorWell.color)
		}
	}

	init(selection: Binding<SwiftUI.Color>) {
		self._selection = selection
		self.colorWellDelegate = ColorWellDelegate(selection: selection)
	}

	func makeNSView(context: Context) -> NSColorWell {
		NSViewType()
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		if #available(macOS 14.0, *) {
			nsView.supportsAlpha = false
		}
		nsView.colorWellStyle = .minimal
		nsView.color = NSColor(self.selection)
		nsView.target = colorWellDelegate
		nsView.action = #selector(ColorWellDelegate.colorChanged(_:))
	}
}

struct ExternalVirtualMachineView: NSViewRepresentable {
	typealias NSViewType = VirtualMachineTerminalView

	@StateObject var document: VirtualMachineDocument

	private var fontPickerDelegate: FontPickerDelegate!
	private let dismiss: DismissAction
	private var callback: VMView.CallbackWindow? = nil
	private let fontManager = NSFontManager.shared
	private let fontPanel = NSFontPanel.shared
	private let terminalView: NSViewType

	var terminalColor: SwiftUI.Color {
		self.fontPickerDelegate.terminalView.fontColor.uiColor
	}

	var terminalFont: NSFont {
		self.fontPickerDelegate.terminalView.font
	}

	class FontPickerDelegate: NSObject, NSWindowDelegate, NSFontChanging {
		@Binding var presented: Bool
		@State var fontColor: SwiftUI.Color

		var terminalView: NSViewType

		var visible: Binding<Bool> {
			get {
				return self._presented
			}
			set {
				self._presented = newValue
			}

		}

		init(terminalView: NSViewType) {
			self._presented = .constant(false)
			self.terminalView = terminalView
			self.fontColor = terminalView.fontColor.uiColor
		}

		@objc func selectFont(_ sender: AnyObject) {
			let fontManager = NSFontManager.shared

			guard var newFont = fontManager.selectedFont else {
				return
			}

			newFont = fontManager.convert(newFont)
			self.terminalView.font = newFont
			self.presented = false

			Defaults.saveTerminalFont(newFont)
		}

		func windowWillClose(_ notification: Notification) {
			self.presented = false
		}
	}

	init(document: StateObject<VirtualMachineDocument>, size: CGSize, dismiss: DismissAction, callback: VMView.CallbackWindow? = nil) {
		self._document = document
		self.callback = callback
		self.dismiss = dismiss
		self.terminalView = NSViewType(document: document.wrappedValue, frame: CGRect(origin: .zero, size: size), font: Defaults.currentTerminalFont(), color: Defaults.currentTerminalFontColor())
		self.fontPickerDelegate = FontPickerDelegate(terminalView: self.terminalView)
	}

	func makeNSView(context: Context) -> NSViewType {
		if let callback = self.callback {
			DispatchQueue.main.async {
				callback(terminalView.window)
			}
		}

		return terminalView
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		let display: (Data) -> Void = { datas in
			var converted: [UInt8] = []

			datas.forEach {
				if $0 == 0x0a {
					converted.append(0x0d)
				}

				converted.append($0)
			}

			DispatchQueue.main.async {
				nsView.feed(byteArray: converted[...])
			}
		}

		self.fontPickerDelegate.terminalView = nsView

		try? self.document.startShell(rows: nsView.getTerminal().rows, cols: nsView.getTerminal().cols) { response in
			if case let .exitCode(code) = response.response {
				Logger(self).debug("Shell exited with code \(code) for \(self.document.name)")

				self.document.closeShell {
					DispatchQueue.main.async {
						dismiss()
					}
				}
			} else if case let .stdout(datas) = response.response {
				display(datas)
			} else if case let .stderr(datas) = response.response {
				display(datas)
			}
		}
	}

	func setTerminalColor(_ color: SwiftUI.Color) {
		let color = SwiftTerm.Color(color)

		Defaults.saveTerminalFontColor(color: color)
		self.fontPickerDelegate.terminalView.fontColor = color
	}

	func setTerminalFont(_ font: NSFont) {
		self.fontPickerDelegate.terminalView.font = font

		Defaults.saveTerminalFont(font)
	}
}

struct ColorPickerModifier: ViewModifier {
	@State var color: SwiftUI.Color
	var placement: ToolbarItemPlacement
	var target: ExternalVirtualMachineView?

	init<Content, Modifier>(placement: ToolbarItemPlacement, modifier: ModifiedContent<Content, Modifier>) where Content: View, Modifier: ViewModifier {
		self.init(placement: placement, modifier.content)
	}

	init(placement: ToolbarItemPlacement, _ view: any View) {
		self.placement = placement

		if let target = view as? ExternalVirtualMachineView {
			self.target = target
			self.color = target.terminalColor
		} else {
			self.color = .black
		}
	}

	func body(content: Content) -> some View {
		return content.onChange(of: self.color) { newValue in
			target?.setTerminalColor(newValue)
		}.toolbar {
			ToolbarItem(placement: placement) {
				ColorPicker("Color", selection: self.$color, supportsOpacity: false)
					.frame(maxWidth: 40, maxHeight: 30)
			}
		}
	}
}

struct ColorWellModifier: ViewModifier {
	@State var color: SwiftUI.Color
	var placement: ToolbarItemPlacement
	var target: ExternalVirtualMachineView?

	init<Content, Modifier>(placement: ToolbarItemPlacement, modifier: ModifiedContent<Content, Modifier>) where Content: View, Modifier: ViewModifier {
		self.init(placement: placement, modifier.content)
	}

	init(placement: ToolbarItemPlacement, _ view: any View) {
		self.placement = placement

		if let target = view as? ExternalVirtualMachineView {
			self.target = target
			self.color = target.terminalColor
		} else {
			self.color = .black
		}
	}

	func body(content: Content) -> some View {
		return content.onChange(of: self.color) { newValue in
			target?.setTerminalColor(newValue)
		}.toolbar {
			ToolbarItem(placement: placement) {
				ColorWell(selection: self.$color)
			}
		}
	}
}

struct FontPickerModifier: ViewModifier {
	var font: NSFont
	var placement: ToolbarItemPlacement
	var target: ExternalVirtualMachineView?

	private let delegate: FontPanelDelegate

	init<Content, Modifier>(placement: ToolbarItemPlacement, modifier: ModifiedContent<Content, Modifier>) where Content: View, Modifier: ViewModifier {
		self.init(placement: placement, modifier.content)
	}

	init(placement: ToolbarItemPlacement, _ view: any View) {
		self.placement = placement

		if let target = view as? ExternalVirtualMachineView {
			self.target = target
			self.font = target.terminalFont
		} else {
			self.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
			self.target = nil
		}

		self.delegate = FontPanelDelegate(self.target)
	}

	private class FontPanelDelegate: NSObject {
		var target: ExternalVirtualMachineView?

		init(_ target: ExternalVirtualMachineView?) {
			self.target = target
		}

		@objc func selectFont(_ sender: AnyObject) {
			let fontManager = NSFontManager.shared

			guard let newFont = fontManager.selectedFont else {
				return
			}

			self.target?.setTerminalFont(fontManager.convert(newFont))

			NSFontPanel.shared.orderOut(nil)
		}

		func displayFontPanel(_ font: NSFont) {
			let fontManager = NSFontManager.shared

			fontManager.target = self
			fontManager.action = #selector(selectFont(_:))
			fontManager.setSelectedFont(font, isMultiple: false)
			fontManager.orderFrontFontPanel(self)
		}
	}

	func body(content: Content) -> some View {
		content.toolbar {
			ToolbarItem(placement: placement) {
				Button("Font", systemImage: "character.circle") {
					self.delegate.displayFontPanel(self.font)
				}
				.help("Change font terminal")
			}
		}
	}
}

extension View where Self == ExternalVirtualMachineView {
	func colorPicker(placement: ToolbarItemPlacement) -> ModifiedContent<ExternalVirtualMachineView, ColorWellModifier> {
		self.modifier(ColorWellModifier(placement: placement, self))
	}

	func fontPicker(placement: ToolbarItemPlacement) -> ModifiedContent<ExternalVirtualMachineView, FontPickerModifier> {
		modifier(FontPickerModifier(placement: placement, self))
	}
}

extension ModifiedContent where Content: View, Modifier: ViewModifier {
	func colorPicker(placement: ToolbarItemPlacement) -> some View {
		self.modifier(ColorWellModifier(placement: placement, modifier: self))
	}

	func fontPicker(placement: ToolbarItemPlacement) -> some View {
		modifier(FontPickerModifier(placement: placement, modifier: self))
	}
}
