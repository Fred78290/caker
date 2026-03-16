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

struct ExternalVirtualMachineView: NSViewRepresentable {
	typealias NSViewType = VirtualMachineTerminalView
	
	private var fontPickerDelegate: FontPickerDelegate!
	private let fontManager = NSFontManager.shared
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
	
	init(interactiveShell: InteractiveShell, size: CGSize) {
		self.terminalView = interactiveShell.buildTerminalView(frame: CGRect(origin: .zero, size: size))
		self.fontPickerDelegate = FontPickerDelegate(terminalView: self.terminalView)
	}
	
	func makeNSView(context: Context) -> NSViewType {
		return terminalView
	}
	
	func updateNSView(_ nsView: NSViewType, context: Context) {
		self.fontPickerDelegate.terminalView = nsView
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
	
	func startShell() {
		self.terminalView.startShell()
	}
	
	func closeShell() {
		self.terminalView.closeShell()
	}
}

struct InteractiveShellModifier: ViewModifier {	
	let target: ExternalVirtualMachineView

	init<Content, Modifier>(modifier: ModifiedContent<Content, Modifier>) where Content: View, Modifier: ViewModifier {
		self.init(modifier.content as! ExternalVirtualMachineView)
	}

	init(_ target: ExternalVirtualMachineView) {
		self.target = target
	}
	
	func body(content: Content) -> some View {
		content.onAppear {
			target.startShell()
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
	func addModifiers(placement: ToolbarItemPlacement) -> some View {
		self.modifier(InteractiveShellModifier(self).concat(ColorWellModifier(placement: placement, self)).concat(FontPickerModifier(placement: placement, self)))
	}

	func interactiveShell() -> ModifiedContent<ExternalVirtualMachineView, InteractiveShellModifier> {
		self.modifier(InteractiveShellModifier(self))
	}

	func colorPicker(placement: ToolbarItemPlacement) -> ModifiedContent<ExternalVirtualMachineView, ColorWellModifier> {
		self.modifier(ColorWellModifier(placement: placement, self))
	}

	func fontPicker(placement: ToolbarItemPlacement) -> ModifiedContent<ExternalVirtualMachineView, FontPickerModifier> {
		modifier(FontPickerModifier(placement: placement, self))
	}
}

extension ModifiedContent where Content: View, Modifier: ViewModifier {
	func interactiveShell() -> some View {
		self.modifier(InteractiveShellModifier(modifier: self))
	}

	func colorPicker(placement: ToolbarItemPlacement) -> some View {
		self.modifier(ColorWellModifier(placement: placement, modifier: self))
	}

	func fontPicker(placement: ToolbarItemPlacement) -> some View {
		modifier(FontPickerModifier(placement: placement, modifier: self))
	}
}
