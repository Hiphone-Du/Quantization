//
//  NetworkUtils.swift
//  Quantization
//
//  Created by Claude on 2025/4/13.
//

import Foundation
import SystemConfiguration
import Network
import Alamofire

// 添加网络类型枚举
enum NetworkType {
    case wifi
    case cellular
    case none
}

class NetworkUtils {
    // 添加单例实例
    static let shared = NetworkUtils()
    
    // 私有初始化方法，确保单例模式
    private init() {}
    
    // 检查网络类型的方法
    func checkNetworkType(completion: @escaping (NetworkType) -> Void) {
        let reachability = SCNetworkReachabilityCreateWithName(nil, "8.8.8.8")
        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reachability!, &flags)
        
        if flags.contains(.isWWAN) {
            completion(.cellular)
        } else if flags.contains(.reachable) {
            completion(.wifi)
        } else {
            completion(.none)
        }
    }
    
    // 获取本地设备的局域网IP地址
    static func getLocalIPAddress() -> String {
        var address: String = "获取IP失败"
        
        // 获取所有网络接口
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return address }
        guard let firstAddr = ifaddr else { return address }
        
        // 遍历网络接口
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            
            // 检查是IPv4或IPv6地址
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                
                // 获取接口名称
                let name = String(cString: interface.ifa_name)
                
                // 检查是否是蜂窝网络或WiFi
                if name == "en0" || name == "en1" || name == "pdp_ip0" || name == "pdp_ip1" {
                    // 转换socket地址为字符串
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    
                    // 如果是IPv4地址，直接返回
                    if addrFamily == UInt8(AF_INET) {
                        return address
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address
    }
    
    // 获取网络类型
    static func getNetworkType() -> String {
        let reachability = SCNetworkReachabilityCreateWithName(nil, "8.8.8.8")
        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reachability!, &flags)
        
        if flags.contains(.isWWAN) {
            return "蜂窝网络"
        } else if flags.contains(.reachable) {
            return "WiFi"
        } else {
            return "无网络"
        }
    }
    
    // 获取公网IP地址（使用外部服务）
    static func getPublicIPAddress(completion: @escaping (String) -> Void) {
        // 使用多个IP查询服务以提高可靠性
        let ipServices = [
            "https://api.ipify.org",           // 返回纯文本IP
            "https://ipv4.icanhazip.com",      // IPv4专用
            "https://ifconfig.me/ip",          // 返回纯文本IP
            "https://api.ip.sb/ip",            // 返回纯文本IP
            "https://api4.ipify.org",          // IPv4专用
            "https://ipinfo.io/ip",            // 返回纯文本IP
            "https://checkip.amazonaws.com",   // AWS IP检查服务
            "https://wtfismyip.com/text"       // 返回纯文本IP
        ]
        
        print("开始尝试获取公网IP地址...")
        
        // 尝试第一个服务
        tryNextIPService(services: ipServices, index: 0, completion: completion)
    }
    
    // 递归尝试IP服务
    private static func tryNextIPService(services: [String], index: Int, completion: @escaping (String) -> Void) {
        // 如果已尝试所有服务，返回失败
        if index >= services.count {
            print("所有IP服务都失败了，无法获取公网IP")
            completion("获取公网IP失败")
            return
        }
        
        let service = services[index]
        print("尝试从 \(service) 获取IP...")
        
        AF.request(service).responseString { response in
            switch response.result {
            case .success(let ip):
                // 清理返回的IP地址（去除空格和换行符）
                let cleanIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 验证是否是有效的IP地址
                if isValidIP(cleanIP) {
                    print("成功获取公网IP: \(cleanIP) (来自 \(service))")
                    completion(cleanIP)
                } else {
                    print("从 \(service) 获取的IP格式无效: \(cleanIP)")
                    // 如果不是有效IP，尝试下一个服务
                    tryNextIPService(services: services, index: index + 1, completion: completion)
                }
            case .failure(let error):
                print("从 \(service) 获取IP失败: \(error.localizedDescription)")
                // 请求失败，尝试下一个服务
                tryNextIPService(services: services, index: index + 1, completion: completion)
            }
        }
    }
    
    // 验证是否是有效的IP地址
    private static func isValidIP(_ ip: String) -> Bool {
        // 简单的IPv4验证
        let pattern = "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        let regex = try? NSRegularExpression(pattern: pattern)
        return regex?.firstMatch(in: ip, range: NSRange(location: 0, length: ip.count)) != nil
    }
} 