//
//  MultiplatfromTabBar.swift
//  Stuff To Buy
//
//  Created by Kevin Mullins on 4/30/21.
//

import Foundation
import SwiftUI
import SwiftletUtilities

/// Extends color to support the `MultiplatformTabBar`.
fileprivate extension Color {
	static var toolbarForegroundColor: Color {
		switch colorScheme {
		case .dark:
			return Color(fromHex: "9d9b9aFF")!
		default:
			return Color.primary
		}
	}

	static var toolbarPressedColor: Color {
		switch colorScheme {
		case .dark:
			return Color(fromHex: "eeeeeeff")!
		default:
			return Color(fromHex: "202020ff")!
		}
	}

	static var toolbarFillColor: Color {
		switch colorScheme {
		case .dark:
			return Color(fromHex: "494543FF")!
		default:
			return Color(fromHex: "e6e4e1ff")!
		}
	}

	#if os(macOS)
		/// Holds the standard window background color.
		static let backgroundColor = Color(NSColor.windowBackgroundColor)

		/// Holds the standard control background color.
		static let secondaryBackgroundColor = Color(NSColor.controlBackgroundColor)
	#else
		/// Holds the standard window background color.
		static let backgroundColor = Color(UIColor.systemBackground)

		/// Holds the standard control background color.
		static let secondaryBackgroundColor = Color(UIColor.secondarySystemBackground)
	#endif
}

/// Creates a common Tab Bar control that runs and looks the same across multiple devices and OS (iOS, iPadOS, macOS & tvOS).
///
/// ## Example:
/// ```swift
/// MultiplatformTabBar(tabPosition: .top, barHorizontalAlignment: .center)
/// .tab(title: "Tab 1", icon: Image(systemName: "tray.fill")) {
///  VStack {
/// 	Text("Body of Tab 1")
///  }
/// }
/// .tab(title: "Tab 2", icon: Image(systemName: "tray.fill")) {
///  VStack {
/// 	Text("Body of Tab 1")
///  }
/// }
/// .tab(title: "Tab 3", icon: Image(systemName: "tray.fill")) {
///  VStack {
/// 	Text("Body of Tab 1")
///  }
/// }
/// ```
///
/// - Remark: This tool works great for creating a **Settings** page for the macOS build of a multiplatform SwiftUI project.
public struct MultiplatformTabBar: View {
	// MARK: - Properties

	/// Defines the location of the Tab Bar.
	public var tabPosition: MultiplatformTabViewPosition = .top

	/// Defines the vertical alignment of the Tab Bar.
	public var barVerticalAlignment: MultiplatformTabBarVerticalAlignment = .center

	/// Defines the horizontal alignment of the Tab Bar.
	public var barHorizontalAlignment: MultiplatformTabBarHorizontalAlignment = .center

	/// Holds the currently selected tab bar.
	@Binding public var selection: Int

	/// Holds the collection of tabs being presented.
	@ObservedObject public var tabSet: MultiplatformTabCollection = MultiplatformTabCollection()

	// MARK: - Initializers

	@State var hoverItem: Int? = nil
	@State var pressedItem: Int? = nil

	/// Creates a new instance of the object.
	public init(selection: Binding<Int>) {
		self._selection = selection
	}

	/// Creates a new instance of the object with the given properties
	/// - Parameters:
	///   - tabPosition: The Tab Bar position.
	///   - barVerticalAlignment: The Tab Bar's vertical alignment.
	///   - barHorizontalAlignment: The Tab Bar's horizontal alignment.
	public init(selection: Binding<Int>, tabPosition: MultiplatformTabViewPosition = .top, barVerticalAlignment: MultiplatformTabBarVerticalAlignment = .center, barHorizontalAlignment: MultiplatformTabBarHorizontalAlignment = .center) {
		// Initialize
		self.tabPosition = tabPosition
		self.barVerticalAlignment = barVerticalAlignment
		self.barHorizontalAlignment = barHorizontalAlignment
		self._selection = selection
	}

	private func fillToolbarColor(_ item: Int) -> Color {
		if item == self.selection || item == self.hoverItem {
			return Color.toolbarFillColor
		}

		return Color.red.opacity(0.0)
	}

	private func foregroundToolbarColor(_ item: Int) -> Color {
		if item == self.pressedItem && item == self.selection {
			return Color.accentColor.withBrightnessValue(20)
		}

		if item == self.pressedItem {
			return Color.toolbarPressedColor
		}
		
		if item == self.selection {
			return Color.accentColor
		}

		return Color.toolbarForegroundColor
	}

	private func gesture(_ index: Int) -> some Gesture {
		DragGesture(minimumDistance: 0)
			.onChanged({ _ in
				if tabSet.tabs[index].disabled == false {
					self.pressedItem = index
				}
			})
			.onEnded({ _ in
				self.pressedItem = nil
				if tabSet.tabs[index].disabled == false {
					self.selection = index
				}
			})
	}

	@ViewBuilder
	private func tabContent(_ tab: MultiplatformTab, foregroundColor: Color) -> some View {
		VStack {
			tab.icon
				.resizable()
				.aspectRatio(contentMode: .fit)
				.foregroundStyle(tab.disabled ? .gray : foregroundColor)
				.frame(width: 24, height: 24, alignment: .center)

			Text(tab.title)
				.font(.footnote)
				.foregroundStyle(tab.disabled ? .gray : foregroundColor)
		}
		.background(Color.red.opacity(0.0))
	}

	// MARK: - Functions
	/// Generates a horizontal Tab Bar.
	private var barHorizontal: some View {
		VStack {
			HStack {
				if barHorizontalAlignment == .center || barHorizontalAlignment == .right {
					Spacer()
				}
				ForEach(0..<tabSet.tabs.count, id: \.self) { index in
					let foregroundColor = self.foregroundToolbarColor(index)

					RoundedRectangle(cornerRadius: 10)
						.fill(self.fillToolbarColor(index))
						.overlay(
							tabContent(tabSet.tabs[index], foregroundColor: foregroundColor)
						)
						.frame(width: 65, height: 65)
						.padding(0)
						.foregroundColor(foregroundColor)
						.onHover { hover in
							self.hoverItem = hover ? index : nil
						}
						.gesture(gesture(index))
				}
				if barHorizontalAlignment == .center || barHorizontalAlignment == .left {
					Spacer()
				}
			}

			Divider()
		}
		.padding(0)
	}

	/// Generates a vertical Tab Bar.
	private var barVertical: some View {
		HStack {
			VStack {
				Spacer()
				ForEach(0..<tabSet.tabs.count, id: \.self) { index in
					let foregroundColor = self.foregroundToolbarColor(index)

					RoundedRectangle(cornerRadius: 10)
						.fill(self.fillToolbarColor(index))
						.overlay(
							tabContent(tabSet.tabs[index], foregroundColor: foregroundColor)
						)
						.frame(width: 65, height: 65)
						.padding(0)
						.foregroundColor(foregroundColor)
						.onHover { hover in
							self.hoverItem = hover ? index : nil
						}
						.gesture(gesture(index))
				}
				Spacer()
			}
			Divider()
		}
		.padding(0)
	}

	/// Generates the body of the Tab Bar and the contents of the currently selected tab.
	public var body: some View {

		switch tabPosition {
		case .top:
			VStack(spacing: 0) {
				barHorizontal
					.padding(.top, 5)

				if tabSet.tabs.count > 0 {
					tabSet.tabs[selection].contents
						.padding(0)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				}
			}
			.padding(0)
		case .bottom:
			VStack(spacing: 0) {
				if tabSet.tabs.count > 0 {
					tabSet.tabs[selection].contents
						.padding(0)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				}

				barHorizontal
					.padding(.bottom, 5)
			}
			.padding(0)
		case .left:
			HStack(spacing: 0) {
				barVertical
					.padding(.leading, 5)

				if tabSet.tabs.count > 0 {
					tabSet.tabs[selection].contents
						.padding(0)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				}
			}
			.padding(0)
		case .right:
			HStack(spacing: 0) {
				if tabSet.tabs.count > 0 {
					tabSet.tabs[selection].contents
						.padding(0)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				}

				barVertical
					.padding(.trailing, 5)
			}
			.padding(0)
		}
	}

	/// Adds a new tab to the Tab Bar.
	/// - Parameter newTab: The new tab to add as a `MultiplatformTab`.
	/// - Returns: The parent `MultiplatformTabBar`.
	@discardableResult public func tab(_ newTab: MultiplatformTab) -> MultiplatformTabBar {

		// Add tab to collection
		tabSet.tabs.append(newTab)

		// Return self so the definitions can be chained.
		return self
	}

	/// Adds a new tab to the bar with the given properties.
	/// - Parameters:
	///   - title: The title of the tab.
	///   - icon: The icon for the tab.
	///   - tag: An optional tag for the tab.
	///   - content: The body of the page that will be displayed when the tab is selected in SwiftUI.
	/// - Returns: The parent `MultiplatformTabBar`.
	@discardableResult public func tab<Content: View>(title: String, icon: Image, tag: String = "", disabled: Bool = false, @ViewBuilder content: () -> Content) -> MultiplatformTabBar {

		// Add tab to collection
		tabSet.tabs.append(MultiplatformTab(title: title, icon: icon, tag: tag, disabled: disabled, contents: AnyView(content())))

		// Return self so the definitions can be chained.
		return self
	}

	/// Adds a new tab to the bar with the given properties.
	/// - Parameters:
	///   - title: The title of the tab.
	///   - icon: The icon for the tab.
	///   - tag: An optional tag for the tab.
	///   - content: The body of the page that will be displayed when the tab is selected in SwiftUI.
	/// - Returns: The parent `MultiplatformTabBar`.
	@discardableResult public func tab<Content: View>(title: String, systemName: String, tag: String = "", disabled: Bool = false, @ViewBuilder content: () -> Content) -> MultiplatformTabBar {

		// Add tab to collection
		tabSet.tabs.append(MultiplatformTab(title: title, icon: Image(systemName: systemName), tag: tag, disabled: disabled, contents: AnyView(content())))

		// Return self so the definitions can be chained.
		return self
	}
}
