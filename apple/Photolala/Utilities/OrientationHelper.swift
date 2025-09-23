//
//  OrientationHelper.swift
//  Photolala
//
//  Utility for managing screen orientation on iOS
//

#if os(iOS)
import SwiftUI
import UIKit

struct OrientationHelper {

	static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
		// Set the static property on AppDelegate
		AppDelegate.orientationLock = orientation

		// Force the orientation update
		UIViewController.attemptRotationToDeviceOrientation()
	}

	static func lockOrientation(_ orientation: UIInterfaceOrientationMask, andRotateTo rotateOrientation: UIInterfaceOrientation) {
		self.lockOrientation(orientation)

		if #available(iOS 16.0, *) {
			guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
			windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
			windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
		} else {
			UIDevice.current.setValue(rotateOrientation.rawValue, forKey: "orientation")
			UINavigationController.attemptRotationToDeviceOrientation()
		}
	}
}

struct DeviceRotationViewModifier: ViewModifier {
	let orientation: UIInterfaceOrientationMask

	func body(content: Content) -> some View {
		content
			.onAppear {
				OrientationHelper.lockOrientation(orientation)
			}
			.onDisappear {
				OrientationHelper.lockOrientation(.all)
			}
	}
}

// Portrait-only modifier specifically for iPhone
struct PortraitOnlyForiPhone: ViewModifier {
	func body(content: Content) -> some View {
		content
			.onAppear {
				// Only lock orientation on iPhone, not iPad
				if UIDevice.current.userInterfaceIdiom == .phone {
					OrientationHelper.lockOrientation(.portrait, andRotateTo: .portrait)
				}
			}
			.onDisappear {
				// Reset to all orientations when view disappears
				if UIDevice.current.userInterfaceIdiom == .phone {
					OrientationHelper.lockOrientation(.all)
				}
			}
	}
}

extension View {
	func portraitOnlyForiPhone() -> some View {
		modifier(PortraitOnlyForiPhone())
	}

	func onRotate(perform action: @escaping (UIInterfaceOrientationMask) -> Void) -> some View {
		modifier(DeviceRotationViewModifier(orientation: .all))
	}
}
#else
// macOS implementation - just return the view unchanged
import SwiftUI

extension View {
	func portraitOnlyForiPhone() -> some View {
		self
	}
}
#endif