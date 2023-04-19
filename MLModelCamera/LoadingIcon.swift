//
//  LoadingIcon.swift
//  MLModelCamera
//
//  Created by Shin Toyo on 2023/04/19.
//  Copyright © 2023 Shuichi Tsutsumi. All rights reserved.
//

import UIKit

class LoadingIcon {
    // インディケーターアニメーション開始メソッド
    func startIndicatorAnimation(viewController: UIViewController, activityIndicatorView: UIActivityIndicatorView) {
        // 画面タップ無効化
        viewController.view.isUserInteractionEnabled = false
        // インディケーター表示
        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.center = viewController.view.center
        activityIndicatorView.style = .large
        activityIndicatorView.color = .black
        
        viewController.view.addSubview(activityIndicatorView)
        // アニメーション開始
        activityIndicatorView.startAnimating()
    }
    // インディケーターアニメーション停止メソッド
    func stopIndicatorAnimation(viewController: UIViewController, activityIndicatorView: UIActivityIndicatorView) {
        // 画面操作有効化
        viewController.view.isUserInteractionEnabled = true
        // インディケーターアニメーションストップ
        activityIndicatorView.stopAnimating()
    }

}
