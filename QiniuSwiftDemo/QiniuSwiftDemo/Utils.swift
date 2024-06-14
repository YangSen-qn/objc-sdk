//
//  Utils.swift
//  QiniuSwiftDemo
//
//  Created by yangsen on 2024/6/13.
//

import Foundation
import UIKit
import SwiftUI

let kMainColor = Color(red: 24/256.0, green: 175/256.0, blue: 255/256.0)
let kBgColor = Color(white: 0.9)

let kScreenW = UIScreen.main.bounds.width
let kScreenH = UIScreen.main.bounds.height

let kNavBarH = safeAreaTop()
let kTabBarH = safeAreaBottom()

private func safeAreaTop() -> CGFloat {
	let scene = UIApplication.shared.connectedScenes.first
	guard let windowScene = scene as? UIWindowScene else { return 0 }
	guard let window = windowScene.windows.first else { return 0 }
	return window.safeAreaInsets.top
}

private func safeAreaBottom() -> CGFloat {
	let scene = UIApplication.shared.connectedScenes.first
	guard let windowScene = scene as? UIWindowScene else { return 0 }
	guard let window = windowScene.windows.first else { return 0 }
	return window.safeAreaInsets.bottom
}

func rootViewController() -> UIViewController? {
	return UIApplication.shared.windows.first?.rootViewController
}

func presentViewController(vc: UIViewController, animated: Bool) {
	guard let rootVC = rootViewController() else {
		return
	}

	rootVC.present(vc, animated: animated)
}
