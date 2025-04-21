//
//  Constants.swift
//  Quantization
//
//  Created by Claude on 2025/4/13.
//

import Foundation

struct Constants {
    // 币安API配置
    struct Binance {
        static let baseURL = "https://api.binance.com"
        static let futuresURL = "https://fapi.binance.com"
        
        // 测试网URL
        static let testBaseURL = "https://testnet.binance.vision"
        static let testFuturesURL = "https://testnet.binancefuture.com"
        
        // API访问设置 (实际使用时替换为你的真实API Keys)
        static var apiKey = ""
        static var secretKey = "" 
        
        // 是否使用测试网 - 默认开启测试网
        static var useTestnet = true
        
        static var useReadOnlyAPI: Bool = false
    }
    
    // 网络请求相关
    struct Network {
        static let timeoutInterval: TimeInterval = 30.0
    }
    
    // 用户偏好设置Key
    struct UserDefaultsKeys {
        static let apiKey = "binance_api_key"
        static let secretKey = "binance_secret_key" 
        static let useTestnet = "use_testnet"
    }
} 