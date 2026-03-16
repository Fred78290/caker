//
//  ColorWell.swift
//  Caker
//
//  Created by Frederic BOLTZ on 15/03/2026.
//
import SwiftUI

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
		return content.onChange(of: self.color) { _, newValue in
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
	let placement: ToolbarItemPlacement
	let target: ExternalVirtualMachineView?

	init<Content, Modifier>(placement: ToolbarItemPlacement, modifier: ModifiedContent<Content, Modifier>) where Content: View, Modifier: ViewModifier {
		self.init(placement: placement, modifier.content)
	}

	init(placement: ToolbarItemPlacement, _ view: any View) {
		self.placement = placement

		if let target = view as? ExternalVirtualMachineView {
			self.target = target
			self.color = target.terminalColor
		} else {
			self.target = nil
			self.color = .black
		}
	}

	func body(content: Content) -> some View {
		return content.onChange(of: self.color) { _, newValue in
			target?.setTerminalColor(newValue)
		}.toolbar {
			ToolbarItem(placement: placement) {
				ColorWell(selection: self.$color)
					.frame(size: .init(width: 10, height: 10))
			}
		}
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

	func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSColorWell, context: Context) -> CGSize? {
		CGSize(width: 20, height: 20)
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
