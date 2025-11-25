//
//  RoundedTextField.swift
//  Caker
//
//  Created by Frederic BOLTZ on 22/10/2025.
//

import SwiftUI

extension View {
	public func rounded(_ alignment: TextAlignment) -> some View {
		multilineTextAlignment(alignment)
			.textFieldStyle(.roundedBorder)
			.backgroundStyle(.windowBackground)
			.labelsHidden()
		//.clipShape(RoundedRectangle(cornerRadius: 4))
	}
}
