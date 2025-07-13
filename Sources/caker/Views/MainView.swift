import SwiftUI

struct MainView: View {
	var title = "Hello, world!"

	var body: some View {
		VStack {
			Image(systemName: "globe")
				.imageScale(.large)
				.foregroundStyle(.tint)
			Text(title)
		}
		.padding()
	}
}

#Preview {
	MainView()
}
