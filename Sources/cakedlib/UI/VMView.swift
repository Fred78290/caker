//
//  VMView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 31/05/2025.
//
import QuartzCore
import SwiftUI
import Virtualization
import CakeAgentLib

@objc protocol _VZFramebufferObserver {
	@objc func framebuffer(_ framebuffer: Any, didUpdateCursor cursor: UnsafeMutableRawPointer?)
	@objc func framebuffer(_ framebuffer: Any, didUpdateFrame frame: UnsafeMutableRawPointer?)
	@objc func framebuffer(_ framebuffer: Any, didUpdateGraphicsOrientation orientation: Int64)
	@objc func framebufferDidUpdateColorSpace(_ framebuffer: Any)
}

extension VZVirtualMachineView {
	public var framebufferView: NSView? {
		guard let field = class_getInstanceVariable(VZVirtualMachineView.self, "_framebufferView") else {
			return nil
		}

		guard let value = object_getIvar(self, field) as? NSView else {
			return nil
		}

		return value
	}

	public var guestIsUsingHostCursor: Bool {
		get {
			guard let field = class_getInstanceVariable(VZVirtualMachineView.self, "_guestIsUsingHostCursor") else {
				return false
			}

			guard let value = object_getIvar(self, field) as? Bool else {
				return false
			}

			return value
		}
		set {
			guard let field = class_getInstanceVariable(VZVirtualMachineView.self, "_guestIsUsingHostCursor") else {
				return
			}

			object_setIvar(self, field, newValue)
		}
	}

	public var showsHostCursor: Bool {
		get {
			guard let field = class_getInstanceVariable(VZVirtualMachineView.self, "_showsHostCursor") else {
				return false
			}

			guard let value = object_getIvar(self, field) as? Bool else {
				return false
			}

			return value
		}
		set {
			guard let field = class_getInstanceVariable(VZVirtualMachineView.self, "_showsHostCursor") else {
				return
			}

			object_setIvar(self, field, newValue)
		}
	}

	public var ivars: [Ivar] {
		var count: UInt32 = 0
		var ivars: [Ivar] = []
		let result = class_copyIvarList(VZVirtualMachineView.self, &count)

		for index in 0..<Int(count) {
			if let ivar = result?[index] {
				ivars.append(ivar)
			}
		}

		return ivars
	}
}

class ExVZVirtualMachineView: VZVirtualMachineView {
	var onDisconnect: (() -> Void)?

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)

		#if DEBUG
			if let framebufferView = self.framebufferView {
				let observer: _VZFramebufferObserver = unsafeBitCast(framebufferView, to: _VZFramebufferObserver.self)
			}
		#endif
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	#if DEBUG
		public override func keyDown(with event: NSEvent) {
			Logger(self).debug("keyDown: keyCode=\(event.keyCode), modifiers=\(String(event.modifierFlags.rawValue, radix: 16)), characters='\(event.characters ?? "none")' charactersIgnoringModifiers='\(event.charactersIgnoringModifiers ?? "none")'")

			super.keyDown(with: event)
		}

		public override func flagsChanged(with event: NSEvent) {
			Logger(self).debug("flagsChanged: keyCode=\(event.keyCode), modifiers=\(String(event.modifierFlags.rawValue, radix: 16))")

			super.flagsChanged(with: event)
		}

		public override func scrollWheel(with event: NSEvent) {
			Logger(self).debug("scrollWheel: deltaX=\(event.deltaX), deltaY=\(event.deltaY), deltaZ=\(event.deltaZ), modifiers=\(String(event.modifierFlags.rawValue, radix: 16))")

			super.scrollWheel(with: event)
		}
	#endif
}

public struct VMView: NSViewRepresentable {
	public typealias NSViewType = VZVirtualMachineView

	public var virtualMachine: VirtualMachine
	public var params: VMRunHandler

	public static func createView(vm: VirtualMachine, frame: NSRect) -> VZVirtualMachineView {
		#if DEBUG
			let vzMachineView = ExVZVirtualMachineView(frame: frame)
		#else
			let vzMachineView = VZVirtualMachineView(frame: frame)
		#endif

		vzMachineView.virtualMachine = vm.virtualMachine
		vzMachineView.autoresizingMask = [.width, .height]
		vzMachineView.automaticallyReconfiguresDisplay = true
		vzMachineView.capturesSystemKeys = true
		//vzMachineView.showsHostCursor = false

		return vzMachineView
	}

	public init(_ vm: VirtualMachine, params: VMRunHandler) {
		self.params = params
		self.virtualMachine = vm
	}

	public func makeNSView(context: Context) -> VZVirtualMachineView {
		guard let vmView = self.virtualMachine.env.vzMachineView else {
			return NSViewType()
		}

		return vmView
	}

	public func updateNSView(_ nsView: VZVirtualMachineView, context: Context) {
	}
}
