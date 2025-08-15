//
//  OrientationHelper.swift
//  Photolala
//
//  Utility for managing screen orientation on iOS
//

#if os(iOS)
import SwiftUI

struct OrientationHelper {
	
	static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
		AppDelegateiOS.orientationLock = orientation
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
				// Restore all orientations when leaving
				if UIDevice.current.userInterfaceIdiom == .phone {
					OrientationHelper.lockOrientation(.all)
				}
			}
	}
}

extension View {
	func forceRotation(orientation: UIInterfaceOrientationMask) -> some View {
		self.modifier(DeviceRotationViewModifier(orientation: orientation))
	}
	
	func portraitOnlyForiPhone() -> some View {
		self.modifier(PortraitOnlyForiPhone())
	}
}

#else

import SwiftUI

// Provide no-op implementations for non-iOS platforms
extension View {
	func forceRotation(orientation: Any) -> some View {
		self
	}
	
	func portraitOnlyForiPhone() -> some View {
		self
	}
}

#endif