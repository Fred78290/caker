//
//  SplashScreenView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 17/08/2026.
//
import AppKit
import SwiftUI

public struct SplashScreenView: View {
	public let name: String
	
	public var body: some View {
		VStack(spacing: 12) {
			Image(nsImage: NSApp.applicationIconImage ?? NSImage(named: NSImage.applicationIconName)!)
				.resizable()
				.frame(width: 64, height: 64)
			
			Text(name)
				.font(.headline)
			
			ProgressView()
				.controlSize(.small)
		}
		.padding(24)
		.frame(width: 320, height: 180)
		.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
		.onAppear {
			// Fallback retry in case setDockIcon()'s activate() call at launch lost the race —
			// see the "Front-app activation workaround" note above AppDelegate.
			DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
				NSApp.activate()
			}
		}
	}
	
	public static func showSplashWindow(name: String) -> NSWindow {
		let size = NSSize(width: 320, height: 180)
		let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)

		window.isReleasedWhenClosed = false
		window.isOpaque = false
		window.backgroundColor = .clear
		window.hasShadow = true
		// .floating puts this above other apps' windows on the window server regardless of
		// whether this process is the active app yet — see the note above AppDelegate.
		window.level = .floating
		window.center()
		window.contentView = NSHostingView(rootView: SplashScreenView(name: name))
		window.makeKeyAndOrderFront(self)

		return window
	}
}
