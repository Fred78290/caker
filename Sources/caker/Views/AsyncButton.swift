//
//  AsyncButton.swift
//  Caker
//
//  Created by Frederic BOLTZ on 08/07/2025.
//
import SwiftUI

struct AsyncButton<Label: View>: View {
	enum ActionOption: CaseIterable {
		case disableButton
		case showProgressView
	}

	var action: () async throws -> Void
	var actionOptions: Set<ActionOption>

	@ViewBuilder var label: () -> Label

	@State private var isDisabled = false
	@State private var showProgressView = false

	init(options: Set<ActionOption> = Set(ActionOption.allCases), action: @escaping () async throws -> Void, @ViewBuilder label: @escaping () -> Label) {
		self.action = action
		self.label = label
		self.actionOptions = options
	}

	var body: some View {
		Button(
			action: {
				var progressViewTask: Task<Void, Error>?
				
				if actionOptions.contains(.disableButton) {
					isDisabled = true
				}

				if actionOptions.contains(.showProgressView) {
					progressViewTask = Task {
						try await Task.sleep(nanoseconds: 150_000_000)
						showProgressView = true
					}
				}

				Task {
					defer {
						isDisabled = false
						showProgressView = false
						progressViewTask?.cancel()
					}

					return try await action()
				}
			},
			label: {
				ZStack {
					// We hide the label by setting its opacity
					// to zero, since we don't want the button's
					// size to change while its task is performed:
					label().opacity(showProgressView ? 0 : 1)
					if showProgressView {
						ProgressView().frame(width: 18, height: 18)
					}
				}
			}
		)
		.disabled(isDisabled)
	}
}

extension AsyncButton where Label == Text {
	init(_ label: String, options: Set<ActionOption> = Set(ActionOption.allCases), action: @escaping () async -> Void) {
		self.init(options: options, action: action) {
			Text(label)
		}
	}
}

extension AsyncButton where Label == Image {
	init(systemImageName: String, options: Set<ActionOption> = Set(ActionOption.allCases), action: @escaping () async -> Void) {
		self.init( options: options, action: action) {
			Image(systemName: systemImageName)
		}
	}
}
