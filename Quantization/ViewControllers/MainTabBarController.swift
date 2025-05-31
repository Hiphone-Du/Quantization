//
//  MainTabBarController.swift
//  Quantization
//
//  Created by Claude on 2025/4/13.
//

import UIKit

class MainTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViewControllers()
    }
    
    private func setupViewControllers() {
        // 合约交易控制器
        let futuresVC = FuturesTradeViewController()
        let futuresNav = UINavigationController(rootViewController: futuresVC)
        futuresNav.tabBarItem = UITabBarItem(title: "合约交易", image: UIImage(systemName: "chart.line.uptrend.xyaxis"), tag: 0)
        
        // 持仓设置控制器
        let positionSettingsVC = PositionSettingsViewController()
        let positionSettingsNav = UINavigationController(rootViewController: positionSettingsVC)
        positionSettingsVC.title = "持仓设置"
        positionSettingsNav.tabBarItem = UITabBarItem(title: "持仓设置", image: UIImage(systemName: "square.stack.3d.up"), tag: 1)
        
        // API设置控制器
        let apiConfigVC = APIConfigViewController()
        let apiConfigNav = UINavigationController(rootViewController: apiConfigVC)
        apiConfigVC.title = "API设置"
        apiConfigNav.tabBarItem = UITabBarItem(title: "API设置", image: UIImage(systemName: "gear"), tag: 2)
        
        // 设置标签栏控制器
        viewControllers = [futuresNav, positionSettingsNav, apiConfigNav]
    }
} 