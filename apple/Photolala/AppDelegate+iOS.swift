//
//  AppDelegate+iOS.swift
//  Photolala
//
//  Created for iOS-specific orientation management
//

#if os(iOS)
import UIKit

class AppDelegateiOS: NSObject, UIApplicationDelegate {
	
	static var orientationLock = UIInterfaceOrientationMask.all {
		didSet {
			// Trigger orientation update when lock changes
			if #available(iOS 16.0, *) {
				UIApplication.shared.connectedScenes.forEach { scene in
					if let windowScene = scene as? UIWindowScene {
						windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientationLock))
					}
				}
			} else {
				// Fallback for older iOS versions
				if orientationLock == .portrait {
					UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
				} else {
					UIDevice.current.setValue(UIInterfaceOrientation.unknown.rawValue, forKey: "orientation")
				}
				UINavigationController.attemptRotationToDeviceOrientation()
			}
		}
	}
	
	func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
		return AppDelegateiOS.orientationLock
	}
}
#endif