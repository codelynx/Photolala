//
//  ContentView.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/09/20.
//

import SwiftUI

struct ContentView: View {
	@State private var model = Model()

	var body: some View {
		VStack {
			Image(systemName: model.iconName)
				.imageScale(.large)
				.foregroundStyle(.tint)
			Text(model.greeting)
		}
		.padding()
	}
}

// MARK: - View Model
extension ContentView {
	@Observable
	final class Model {
		var greeting = "Hello, Photolala!"
		var iconName = "photo.stack"

		// Add view model logic here
	}
}

#Preview {
	ContentView()
}
