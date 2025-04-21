//
//  BinanceAPIService.swift
//  Quantization
//
//  Created by Claude on 2025/4/13.
//

import Foundation
import Alamofire
import SwiftyJSON
import CryptoSwift
import CryptoKit

// 添加交易对信息模型
struct FuturesSymbolInfo: Codable {
    let symbol: String
    let pair: String
    let contractType: String
    let deliveryDate: Int64
    let onboardDate: Int64
    let status: String
    let maintMarginPercent: String
    let requiredMarginPercent: String
    let baseAsset: String
    let quoteAsset: String
    let marginAsset: String
    let pricePrecision: Int
    let quantityPrecision: Int
    let baseAssetPrecision: Int
    let quotePrecision: Int
    let underlyingType: String?
    let settlePlan: Int?
    let triggerProtect: String?
    let liquidationFee: String?
    let marketTakeBound: String?
    let filters: [JSON]?
    let orderTypes: [String]?
    let timeInForce: [String]?
}

// 添加交易对列表响应模型
struct FuturesExchangeInfo: Codable {
    let symbols: [FuturesSymbolInfo]
}

class BinanceAPIService {
    
    static let shared = BinanceAPIService()
    
    // 添加价格更新回调
    var priceUpdateHandler: ((String, Double) -> Void)?
    
    // 保存当前所有的交易对
    private var availableSymbols: [FuturesSymbolInfo] = []
    
    // 当前正在监听的交易对价格WebSocket任务
    private var priceWebSocketTask: URLSessionWebSocketTask?
    
    private init() {
        // 从UserDefaults加载API配置
        loadAPIConfiguration()
    }
    
    // 从UserDefaults加载API配置
    private func loadAPIConfiguration() {
        if let apiKey = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.apiKey) {
            Constants.Binance.apiKey = apiKey
        }
        
        if let secretKey = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.secretKey) {
            Constants.Binance.secretKey = secretKey
        }
        
        Constants.Binance.useTestnet = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.useTestnet)
    }
    
    // 保存API配置到UserDefaults
    func saveAPIConfiguration(apiKey: String, secretKey: String, useTestnet: Bool) {
        Constants.Binance.apiKey = apiKey
        Constants.Binance.secretKey = secretKey
        Constants.Binance.useTestnet = useTestnet
        
        UserDefaults.standard.set(apiKey, forKey: Constants.UserDefaultsKeys.apiKey)
        UserDefaults.standard.set(secretKey, forKey: Constants.UserDefaultsKeys.secretKey)
        UserDefaults.standard.set(useTestnet, forKey: Constants.UserDefaultsKeys.useTestnet)
    }
    
    // 获取当前使用的基础URL
    private var baseURL: String {
        return Constants.Binance.useTestnet ? Constants.Binance.testBaseURL : Constants.Binance.baseURL
    }
    
    // 获取当前使用的合约URL
    private var futuresURL: String {
        return Constants.Binance.useTestnet ? Constants.Binance.testFuturesURL : Constants.Binance.futuresURL
    }
    
    // MARK: - 通用请求方法
    
    // 发送私有API请求（需要签名）
    private func sendSignedRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any] = [:],
        isTestnet: Bool = Constants.Binance.useTestnet,
        isFutures: Bool = true,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        print("准备发送签名请求: \(endpoint)")
        print("API Key是否为空: \(Constants.Binance.apiKey.isEmpty), Secret Key是否为空: \(Constants.Binance.secretKey.isEmpty)")
        
        // 检查API密钥和Secret是否已设置
        guard !Constants.Binance.apiKey.isEmpty, !Constants.Binance.secretKey.isEmpty else {
            let error = NSError(domain: "BinanceAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "API密钥或Secret未设置"])
            print("API密钥未设置错误")
            completion(.failure(error))
            return
        }
        
        // 获取服务器时间戳
        getServerTimestamp { [weak self] result in
            guard let self = self else { return }
            
            var params = parameters
            
            switch result {
            case .success(let serverTime):
                // 使用服务器时间而不是本地时间 - 必须使用毫秒级时间戳
                params["timestamp"] = serverTime
                
                // 确保所有参数值都不为空字符串或nil
                for (key, value) in params {
                    if let stringValue = value as? String, stringValue.isEmpty {
                        print("警告: 参数 \(key) 的值为空字符串")
                        // 如果有空字符串参数，可能会导致签名验证失败
                        params[key] = "0" // 将空字符串替换为默认值
                    }
                }
                
                // 构建查询字符串 - 必须严格按照币安API要求处理
                let sortedParams = params.sorted(by: { $0.key < $1.key })
                let queryString = sortedParams.map { key, value in
                    let valueString = "\(value)"
                    // 使用标准URL编码（不编码特殊字符如:/?&=）
                    return "\(key)=\(valueString)"
                }.joined(separator: "&")
                
                print("签名前的原始查询字符串: \(queryString)")
                
                // HMAC-SHA256签名
                let key = Array(Constants.Binance.secretKey.utf8)
                let message = Array(queryString.utf8)
                let signature = try! HMAC(key: key, variant: .sha2(.sha256)).authenticate(message).toHexString()
                
                print("生成的签名: \(signature)")
                
                // 添加调试信息，输出关键信息，帮助排查问题
                print("使用的secretKey长度: \(Constants.Binance.secretKey.count)")
                print("使用的apiKey长度: \(Constants.Binance.apiKey.count)")
                // 输出secretKey的前两个字符和最后两个字符，避免泄露完整密钥
                if Constants.Binance.secretKey.count > 4 {
                    let prefix = Constants.Binance.secretKey.prefix(2)
                    let suffix = Constants.Binance.secretKey.suffix(2)
                    print("secretKey格式检查 - 前缀: \(prefix), 后缀: \(suffix)")
                }
                
                // 设置URL和请求头
                let baseURLString = (isFutures ? (isTestnet ? Constants.Binance.testFuturesURL : Constants.Binance.futuresURL) : (isTestnet ? Constants.Binance.testBaseURL : Constants.Binance.baseURL))
                let urlString = baseURLString + endpoint
                print("请求URL: \(urlString)")
                
                // 币安API要求signature参数必须作为最后一个参数
                let finalQueryString = queryString + "&signature=\(signature)"
                print("最终查询字符串: \(finalQueryString)")
                
                // 准备请求头
                let headers: HTTPHeaders = [
                    "X-MBX-APIKEY": Constants.Binance.apiKey
                ]
                
                // 根据HTTP方法处理参数
                var finalURLString = urlString
                var requestParameters: Parameters = [:]
                var encoding: ParameterEncoding = URLEncoding.default
                
                if method == .get {
                    // GET请求将参数附加到URL
                    finalURLString = urlString + "?" + finalQueryString
                    requestParameters = [:] // 空参数，因为已经添加到URL
                    encoding = URLEncoding.default
                } else {
                    // POST、DELETE等请求使用表单编码
                    var requestParamsDict: [String: Any] = [:]
                    
                    // 解析参数字符串回字典
                    finalQueryString.components(separatedBy: "&").forEach { pair in
                        let components = pair.components(separatedBy: "=")
                        if components.count == 2 {
                            requestParamsDict[components[0]] = components[1]
                        }
                    }
                    
                    requestParameters = requestParamsDict
                    encoding = URLEncoding.httpBody
                }
                
                print("发送最终请求: \(finalURLString)")
                print("请求方法: \(method.rawValue)")
                print("请求头: \(headers)")
                if method != .get {
                    print("请求体参数: \(requestParameters)")
                }
                
                // 发送请求
                AF.request(
                    finalURLString,
                    method: method,
                    parameters: method == .get ? [:] : requestParameters,
                    encoding: encoding,
                    headers: headers,
                    requestModifier: { $0.timeoutInterval = Constants.Network.timeoutInterval }
                )
                .validate()
                .responseData { response in
                    // 输出完整请求URL以进行调试
                    if let request = response.request {
                        print("完整请求URL: \(request.url?.absoluteString ?? "未知")")
                        print("请求方法: \(request.httpMethod ?? "未知")")
                        print("请求头: \(request.allHTTPHeaderFields ?? [:])")
                    }
                    
                    if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                        print("API响应内容: \(responseString)")
                    }
                    
                    switch response.result {
                    case .success(let data):
                        do {
                            // 输出类型信息以便调试
                            print("尝试解码为类型: \(String(describing: T.self))")
                            
                            // 先尝试作为字典读取，方便调试
                            if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
//                                print("API响应JSON结构: \(json)")
                                
                                // 特殊处理FuturesAccountInfo
                                if T.self == FuturesAccountInfo.self, let jsonDict = json as? [String: Any] {
                                    if let accountInfo = FuturesAccountInfo.fromJSON(jsonDict) {
                                        print("成功使用手动解析方式处理账户信息")
                                        // 创建一个Any类型并尝试转换为T
                                        if let typedAccountInfo = accountInfo as? T {
                                            completion(.success(typedAccountInfo))
                                            return
                                        }
                                    }
                                }
                            }
                            
                            // 尝试正常解码为请求的类型
                            let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                            completion(.success(decodedResponse))
                        } catch {
                            print("解码失败: \(error)")
                            print("解码错误详情: \(error.localizedDescription)")
                            
                            // 特别处理"The data couldn't be read because it is missing"错误
                            if error.localizedDescription.contains("missing") {
                                print("可能是响应格式与模型不匹配 - 尝试手动解析")
                                
                                // 尝试手动解析数据
                                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                    // 针对FuturesAccountInfo的特殊处理
                                    if T.self == FuturesAccountInfo.self {
                                        if let accountInfo = FuturesAccountInfo.fromJSON(json) {
                                            print("成功通过手动解析创建账户信息对象")
                                            if let typedAccountInfo = accountInfo as? T {
                                                completion(.success(typedAccountInfo))
                                                return
                                            }
                                        }
                                    }
                                    
                                    print("无法手动解析为所需类型")
                                }
                            }
                            
                            if let apiError = try? JSONDecoder().decode(BinanceAPIError.self, from: data) {
                                let nsError = NSError(domain: "BinanceAPI", code: apiError.code, userInfo: [NSLocalizedDescriptionKey: apiError.msg])
                                
                                // 特殊处理签名无效错误
                                if apiError.code == -1022 {
                                    print("签名无效错误 - 请检查：")
                                    print("1. API密钥和Secret是否正确配置")
                                    print("2. 当前IP地址是否已添加到API访问白名单中")
                                    print("3. 是否已启用'期货'交易权限")
                                }
                                
                                completion(.failure(nsError))
                            } else {
                                // 为错误添加更详细的描述
                                let detailedError = NSError(
                                    domain: "BinanceAPI", 
                                    code: -1, 
                                    userInfo: [
                                        NSLocalizedDescriptionKey: "API响应解码失败: \(error.localizedDescription)",
                                        NSUnderlyingErrorKey: error
                                    ]
                                )
                                completion(.failure(detailedError))
                            }
                        }
                    case .failure(let error):
                        if let data = response.data, let apiError = try? JSONDecoder().decode(BinanceAPIError.self, from: data) {
                            let nsError = NSError(domain: "BinanceAPI", code: apiError.code, userInfo: [NSLocalizedDescriptionKey: apiError.msg])
                            
                            // 特殊处理签名无效错误
                            if apiError.code == -1022 {
                                print("签名无效错误 - 请检查：")
                                print("1. API密钥和Secret是否正确配置")
                                print("2. 当前IP地址是否已添加到API访问白名单中")
                                print("3. 是否已启用'期货'交易权限")
                            }
                            
                            completion(.failure(nsError))
                        } else {
                            completion(.failure(error))
                        }
                    }
                }
                
            case .failure(let error):
                print("获取服务器时间失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // 获取服务器时间戳
    private func getServerTimestamp(completion: @escaping (Result<Int64, Error>) -> Void) {
        let endpoint = "/fapi/v1/time"
        let urlString = futuresURL + endpoint
        
        print("获取币安服务器时间: \(urlString)")
        
        AF.request(urlString)
            .validate()
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    if let json = value as? [String: Any], let serverTime = json["serverTime"] as? Int64 {
                        print("币安服务器时间: \(serverTime)")
                        completion(.success(serverTime))
                    } else {
                        print("无法解析服务器时间响应")
                        let error = NSError(domain: "BinanceAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析服务器时间响应"])
                        completion(.failure(error))
                    }
                case .failure(let error):
                    print("获取服务器时间失败: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
    }
    
    // 发送公共API请求（不需要签名）
    private func sendPublicRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any] = [:],
        isTestnet: Bool = Constants.Binance.useTestnet,
        isFutures: Bool = true,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let urlString = (isFutures ? futuresURL : baseURL) + endpoint
        
        AF.request(
            urlString,
            method: method,
            parameters: parameters,
            encoding: URLEncoding.queryString,
            requestModifier: { $0.timeoutInterval = Constants.Network.timeoutInterval }
        )
        .validate()
        .responseDecodable(of: T.self) { response in
            switch response.result {
            case .success(let value):
                completion(.success(value))
            case .failure(let error):
                if let data = response.data, let apiError = try? JSONDecoder().decode(BinanceAPIError.self, from: data) {
                    let nsError = NSError(domain: "BinanceAPI", code: apiError.code, userInfo: [NSLocalizedDescriptionKey: apiError.msg])
                    completion(.failure(nsError))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - 添加用于处理字典响应的请求方法
    
    // 发送需要签名的请求，返回字典类型
    private func sendSignedRequestWithDictResponse(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any] = [:],
        isTestnet: Bool = Constants.Binance.useTestnet,
        isFutures: Bool = true,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        print("准备发送签名请求: \(endpoint)")
        print("API Key是否为空: \(Constants.Binance.apiKey.isEmpty), Secret Key是否为空: \(Constants.Binance.secretKey.isEmpty)")
        
        // 检查API密钥和Secret是否已设置
        guard !Constants.Binance.apiKey.isEmpty, !Constants.Binance.secretKey.isEmpty else {
            let error = NSError(domain: "BinanceAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "API密钥或Secret未设置"])
            print("API密钥未设置错误")
            completion(.failure(error))
            return
        }
        
        // 获取服务器时间戳用于签名
        getServerTimestamp { [weak self] result in
            guard let self = self else { return }
            
            var params = parameters
            
            switch result {
            case .success(let serverTime):
                // 使用服务器时间戳 - 必须使用毫秒级时间戳
                params["timestamp"] = serverTime
                
                // 确保所有参数值都不为空字符串或nil
                for (key, value) in params {
                    if let stringValue = value as? String, stringValue.isEmpty {
                        print("警告: 参数 \(key) 的值为空字符串")
                        // 如果有空字符串参数，可能会导致签名验证失败
                        params[key] = "0" // 将空字符串替换为默认值
                    }
                }
                
                // 构建查询字符串 - 必须严格按照币安API要求处理
                let sortedParams = params.sorted(by: { $0.key < $1.key })
                let queryString = sortedParams.map { key, value in
                    let valueString = "\(value)"
                    // 使用标准URL编码（不编码特殊字符如:/?&=）
                    return "\(key)=\(valueString)"
                }.joined(separator: "&")
                
                print("签名前的原始查询字符串: \(queryString)")
                
                // 使用HMAC-SHA256算法生成签名
                guard let secretKey = Constants.Binance.secretKey.data(using: .utf8),
                      let queryData = queryString.data(using: .utf8) else {
                    let error = NSError(domain: "BinanceAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法对请求进行签名"])
                    completion(.failure(error))
                    return
                }
                
                let hmac = CryptoKit.HMAC<CryptoKit.SHA256>.authenticationCode(for: queryData, using: .init(data: secretKey))
                let signature = Data(hmac).map { String(format: "%02hhx", $0) }.joined()
                
                print("生成的签名: \(signature)")
                print("使用的secretKey长度: \(Constants.Binance.secretKey.count)")
                print("使用的apiKey长度: \(Constants.Binance.apiKey.count)")
                print("secretKey格式检查 - 前缀: \(Constants.Binance.secretKey.prefix(2)), 后缀: \(Constants.Binance.secretKey.suffix(2))")
                
                // 添加签名到查询字符串
                let signedQueryString = queryString + "&signature=" + signature
                
                // 准备API请求
                let baseUrlString = isFutures ? futuresURL : baseURL
                let requestURLString = baseUrlString + endpoint
                print("请求URL: \(requestURLString)")
                print("最终查询字符串: \(signedQueryString)")
                
                let finalURLString: String
                
                // 为DELETE请求特别处理，确保参数附加到URL上而不是请求体中
                if method == .delete || method == .get {
                    finalURLString = requestURLString + "?" + signedQueryString
                } else {
                    finalURLString = requestURLString
                }
                
                // 设置请求头
                let headers: HTTPHeaders = [
                    "X-MBX-APIKEY": Constants.Binance.apiKey
                ]
                
                // 确定参数编码
                let encoding: ParameterEncoding = method == .get || method == .delete ? URLEncoding.queryString : URLEncoding.httpBody
                
                // 设置请求参数
                var requestParameters: Parameters = [:]
                
                // 根据请求方法确定如何传递参数
                if method == .get || method == .delete {
                    // GET和DELETE请求已经将参数包含在URL中，不需要额外的参数
                    requestParameters = [:]
                } else {
                    // 将参数转换为字典
                    var requestParamsDict: [String: Any] = [:]
                    let queryItems = signedQueryString.components(separatedBy: "&")
                    
                    for item in queryItems {
                        let keyValue = item.components(separatedBy: "=")
                        if keyValue.count == 2 {
                            let key = keyValue[0]
                            let value = keyValue[1]
                            requestParamsDict[key] = value
                        }
                    }
                    
                    requestParameters = requestParamsDict
                }
                
                print("发送最终请求: \(finalURLString)")
                print("请求方法: \(method.rawValue)")
                print("请求头: \(headers)")
                if method != .get && method != .delete {
                    print("请求体参数: \(requestParameters)")
                }
                
                // 发送请求
                AF.request(
                    finalURLString,
                    method: method,
                    parameters: method == .get || method == .delete ? [:] : requestParameters,
                    encoding: encoding,
                    headers: headers,
                    requestModifier: { $0.timeoutInterval = Constants.Network.timeoutInterval }
                )
                .validate()
                .responseJSON { response in
                    print("API响应状态码: \(String(describing: response.response?.statusCode))")
                    
                    // 输出完整请求URL以进行调试
                    if let request = response.request {
                        print("完整请求URL: \(request.url?.absoluteString ?? "未知")")
                        print("请求方法: \(request.httpMethod ?? "未知")")
                        print("请求头: \(request.allHTTPHeaderFields ?? [:])")
                    }
                    
                    if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                        print("API响应内容: \(responseString)")
                    }
                    
                    switch response.result {
                    case .success(let value):
                        if let dict = value as? [String: Any] {
                            completion(.success(dict))
                        } else {
                            let error = NSError(domain: "BinanceAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法将响应解析为字典"])
                            completion(.failure(error))
                        }
                    case .failure(let error):
                        if let data = response.data, let apiError = try? JSONDecoder().decode(BinanceAPIError.self, from: data) {
                            print("币安API错误: 代码 \(apiError.code), 信息: \(apiError.msg)")
                            let nsError = NSError(domain: "BinanceAPI", code: apiError.code, userInfo: [NSLocalizedDescriptionKey: apiError.msg])
                            
                            // 特殊处理签名无效错误
                            if apiError.code == -1022 {
                                print("签名无效错误 - 请检查：")
                                print("1. API密钥和Secret是否正确配置")
                                print("2. 当前IP地址是否已添加到API访问白名单中")
                                print("3. 是否已启用'期货'交易权限")
                            }
                            
                            completion(.failure(nsError))
                        } else {
                            print("API请求失败: \(error.localizedDescription)")
                            completion(.failure(error))
                        }
                    }
                }
                
            case .failure(let error):
                print("获取服务器时间失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 合约市场数据API
    
    // 获取合约标记价格
    func getFuturesMarkPrice(symbol: String, completion: @escaping (Result<FuturesMarketPrice, Error>) -> Void) {
        // 使用正确的期货标记价格接口
        let endpoint = "/fapi/v1/premiumIndex"  // 使用premiumIndex而不是ticker/price获取标记价格
        let parameters: [String: Any] = ["symbol": symbol]
        
        // print("请求标记价格: \(futuresURL + endpoint)，参数: \(parameters)")
        
        AF.request(
            futuresURL + endpoint,
            method: .get,
            parameters: parameters,
            encoding: URLEncoding.queryString,
            requestModifier: { $0.timeoutInterval = Constants.Network.timeoutInterval }
        )
        .validate()
        .responseJSON { response in
            // print("价格API响应: \(response)")
            
            switch response.result {
            case .success(let value):
                // print("价格API成功: \(value)")
                if let json = value as? [String: Any],
                   let symbol = json["symbol"] as? String,
                   let markPrice = json["markPrice"] as? String {
                    
                    let marketPrice = FuturesMarketPrice(symbol: symbol, price: markPrice)
                    completion(.success(marketPrice))
                } else {
                    // print("价格数据格式不正确: \(value)")
                    let error = NSError(domain: "BinanceAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析标记价格数据"])
                    completion(.failure(error))
                }
            case .failure(let error):
                // print("价格API错误: \(error.localizedDescription)")
                if let data = response.data, let apiError = try? JSONDecoder().decode(BinanceAPIError.self, from: data) {
                    let nsError = NSError(domain: "BinanceAPI", code: apiError.code, userInfo: [NSLocalizedDescriptionKey: apiError.msg])
                    completion(.failure(nsError))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // 新增 - 获取永续合约资金费率
    func getFuturesFundingRate(symbol: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let endpoint = "/fapi/v1/premiumIndex"
        let parameters: [String: Any] = ["symbol": symbol]
        
        sendPublicRequestWithDictResponse(endpoint: endpoint, parameters: parameters, completion: completion)
    }
    
    // 新增 - 获取永续合约K线数据
    func getFuturesKlines(symbol: String, interval: String, limit: Int = 100, completion: @escaping (Result<[[Any]], Error>) -> Void) {
        let endpoint = "/fapi/v1/klines"
        let parameters: [String: Any] = [
            "symbol": symbol,
            "interval": interval,
            "limit": limit
        ]
        
        AF.request(
            futuresURL + endpoint,
            method: .get,
            parameters: parameters,
            encoding: URLEncoding.queryString,
            requestModifier: { $0.timeoutInterval = Constants.Network.timeoutInterval }
        )
        .validate()
        .responseJSON { response in
            switch response.result {
            case .success(let value):
                if let data = value as? [[Any]] {
                    completion(.success(data))
                } else {
                    let error = NSError(domain: "BinanceAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析K线数据"])
                    completion(.failure(error))
                }
            case .failure(let error):
                if let data = response.data, let apiError = try? JSONDecoder().decode(BinanceAPIError.self, from: data) {
                    let nsError = NSError(domain: "BinanceAPI", code: apiError.code, userInfo: [NSLocalizedDescriptionKey: apiError.msg])
                    completion(.failure(nsError))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - 合约账户和交易API
    
    // 获取合约账户信息
    func getFuturesAccountInfo(completion: @escaping (Result<FuturesAccountInfo, Error>) -> Void) {
        print("获取合约账户信息 - 尝试多个API版本")
        
        // 首先尝试V2版API
        tryFuturesAccountInfoWithEndpoint("/fapi/v2/account", apiVersion: "V2") { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let info):
                completion(.success(info))
            case .failure(let error):
                print("V2 API失败: \(error.localizedDescription), 尝试V1 API")
                
                // V2失败，尝试V1版API
                self.tryFuturesAccountInfoWithEndpoint("/fapi/v1/account", apiVersion: "V1") { result in
                    switch result {
                    case .success(let info):
                        completion(.success(info))
                    case .failure(let error):
                        print("V1 API也失败: \(error.localizedDescription), 尝试V3余额API")
                        
                        // V1也失败，尝试V3余额API
                        self.tryFuturesBalanceWithEndpoint("/fapi/v3/balance", apiVersion: "V3") { result in
                            switch result {
                            case .success(let info):
                                completion(.success(info))
                            case .failure(let error):
                                print("所有API尝试都失败了: \(error.localizedDescription)")
                                completion(.failure(error))
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 辅助方法：尝试使用指定端点获取账户信息
    private func tryFuturesAccountInfoWithEndpoint(_ endpoint: String, apiVersion: String, completion: @escaping (Result<FuturesAccountInfo, Error>) -> Void) {
        print("尝试\(apiVersion) API: \(endpoint)")
        
        let parameters: [String: Any] = [
            "recvWindow": 5000 // 添加recvWindow增加请求有效期
        ]
        
        // 输出完整请求信息
        print("请求URL: \(futuresURL + endpoint)")
        print("请求方法: GET")
        print("请求参数: \(parameters)")
        
        sendSignedRequest(endpoint: endpoint, parameters: parameters) { (result: Result<FuturesAccountInfo, Error>) in
            switch result {
            case .success(let accountInfo):
                print("\(apiVersion) API成功获取账户信息")
                completion(.success(accountInfo))
            case .failure(let error):
                print("\(apiVersion) API获取账户信息失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // 辅助方法：尝试获取V3账户余额并转换为账户信息
    private func tryFuturesBalanceWithEndpoint(_ endpoint: String, apiVersion: String, completion: @escaping (Result<FuturesAccountInfo, Error>) -> Void) {
        print("尝试\(apiVersion) API余额接口: \(endpoint)")
        
        // 获取服务器时间戳
        getServerTimestamp { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let serverTime):
                var parameters: [String: Any] = [
                    "timestamp": serverTime,
                    "recvWindow": 5000
                ]
                
                // 构建查询字符串并签名
                let sortedParams = parameters.sorted(by: { $0.key < $1.key })
                let queryString = sortedParams.map { key, value in
                    let valueString = "\(value)"
                    return "\(key)=\(valueString)"
                }.joined(separator: "&")
                
                print("签名前的原始查询字符串: \(queryString)")
                
                // HMAC-SHA256签名
                let key = Array(Constants.Binance.secretKey.utf8)
                let message = Array(queryString.utf8)
                let signature = try! HMAC(key: key, variant: .sha2(.sha256)).authenticate(message).toHexString()
                
                print("生成的签名: \(signature)")
                
                // 构建最终URL
                let urlString = futuresURL + endpoint
                let finalQueryString = queryString + "&signature=\(signature)"
                let finalURLString = urlString + "?" + finalQueryString
                
                print("请求URL: \(urlString)")
                print("请求方法: GET")
                print("请求参数: \(parameters)")
                print("最终请求URL: \(finalURLString)")
                
                // 发送请求
                AF.request(
                    finalURLString,
                    method: .get,
                    parameters: [:], // 参数已经在URL中
                    encoding: URLEncoding.default,
                    headers: ["X-MBX-APIKEY": Constants.Binance.apiKey],
                    requestModifier: { $0.timeoutInterval = Constants.Network.timeoutInterval }
                )
                .validate()
                .responseJSON { response in
                    if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                        print("API响应内容: \(responseString)")
                    }
                    
                    // 输出完整请求URL以进行调试
                    if let request = response.request {
                        print("完整请求URL: \(request.url?.absoluteString ?? "未知")")
                        print("请求方法: \(request.httpMethod ?? "未知")")
                        print("请求头: \(request.allHTTPHeaderFields ?? [:])")
                    }
                    
                    switch response.result {
                    case .success(let value):
                        if let balances = value as? [[String: Any]] {
                            // 将V3余额响应转换为FuturesAccountInfo
                            let assets = balances.compactMap { balance -> FuturesAccountBalance? in
                                guard let asset = balance["asset"] as? String,
                                      let balanceStr = balance["balance"] as? String,
                                      let crossWalletBalance = balance["crossWalletBalance"] as? String,
                                      let availableBalance = balance["availableBalance"] as? String else {
                                    return nil
                                }
                                
                                return FuturesAccountBalance(
                                    asset: asset,
                                    balance: balanceStr,
                                    crossWalletBalance: crossWalletBalance,
                                    availableBalance: availableBalance
                                )
                            }
                            
                            if assets.isEmpty {
                                let error = NSError(domain: "BinanceAPI", code: -1, 
                                                  userInfo: [NSLocalizedDescriptionKey: "获取到的资产列表为空"])
                                completion(.failure(error))
                                return
                            }
                            
                            // 创建一个简化的账户信息对象，只包含资产信息
                            let accountInfo = FuturesAccountInfo(
                                assets: assets,
                                positions: [],
                                totalWalletBalance: assets.first?.balance ?? "0",
                                availableBalance: assets.first?.availableBalance ?? "0"
                            )
                            
                            print("\(apiVersion) API成功获取账户余额")
                            completion(.success(accountInfo))
                        } else {
                            let error = NSError(domain: "BinanceAPI", code: -1, 
                                              userInfo: [NSLocalizedDescriptionKey: "API响应格式不正确"])
                            completion(.failure(error))
                        }
                    case .failure(let error):
                        if let data = response.data, let apiError = try? JSONDecoder().decode(BinanceAPIError.self, from: data) {
                            let nsError = NSError(domain: "BinanceAPI", code: apiError.code, 
                                                userInfo: [NSLocalizedDescriptionKey: apiError.msg])
                            
                            // 特殊处理签名无效错误
                            if apiError.code == -1022 {
                                print("签名无效错误 - 请检查：")
                                print("1. API密钥和Secret是否正确配置")
                                print("2. 当前IP地址是否已添加到API访问白名单中")
                                print("3. 是否已启用'期货'交易权限")
                            }
                            
                            completion(.failure(nsError))
                        } else {
                            completion(.failure(error))
                        }
                    }
                }
                
            case .failure(let error):
                print("获取服务器时间失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // 设置杠杆倍数
    func setLeverage(symbol: String, leverage: Int, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let endpoint = "/fapi/v1/leverage"
        let parameters: [String: Any] = [
            "symbol": symbol,
            "leverage": leverage
        ]
        
        sendSignedRequestWithDictResponse(endpoint: endpoint, method: .post, parameters: parameters, completion: completion)
    }
    
    // 创建合约订单
    func createFuturesOrder(params: FuturesOrderParams, completion: @escaping (Result<FuturesOrderResponse, Error>) -> Void) {
        let endpoint = "/fapi/v1/order"
        
        var parameters: [String: Any] = [
            "symbol": params.symbol,
            "side": params.side.rawValue,
            "type": params.type.rawValue
        ]
        
        if let positionSide = params.positionSide {
            parameters["positionSide"] = positionSide.rawValue
        }
        
        if let timeInForce = params.timeInForce {
            parameters["timeInForce"] = timeInForce.rawValue
        }
        
        if let quantity = params.quantity {
            parameters["quantity"] = String(format: "%.8f", quantity)
        }
        
        if let price = params.price {
            parameters["price"] = String(format: "%.8f", price)
        }
        
        if let reduceOnly = params.reduceOnly {
            parameters["reduceOnly"] = reduceOnly ? "true" : "false"
        }
        
        if let newClientOrderId = params.newClientOrderId {
            parameters["newClientOrderId"] = newClientOrderId
        }
        
        if let stopPrice = params.stopPrice {
            parameters["stopPrice"] = String(format: "%.8f", stopPrice)
        }
        
        if let closePosition = params.closePosition {
            parameters["closePosition"] = closePosition ? "true" : "false"
        }
        
        if let activationPrice = params.activationPrice {
            parameters["activationPrice"] = String(format: "%.8f", activationPrice)
        }
        
        if let callbackRate = params.callbackRate {
            parameters["callbackRate"] = String(format: "%.2f", callbackRate)
        }
        
        if let workingType = params.workingType {
            parameters["workingType"] = workingType
        }
        
        if let newOrderRespType = params.newOrderRespType {
            parameters["newOrderRespType"] = newOrderRespType
        }
        
        sendSignedRequest(endpoint: endpoint, method: .post, parameters: parameters, completion: completion)
    }
    
    // 取消合约订单
    func cancelFuturesOrder(symbol: String, orderId: Int64? = nil, origClientOrderId: String? = nil, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let endpoint = "/fapi/v1/order"
        
        var parameters: [String: Any] = ["symbol": symbol]
        
        if let orderId = orderId {
            parameters["orderId"] = orderId
        }
        
        if let origClientOrderId = origClientOrderId {
            parameters["origClientOrderId"] = origClientOrderId
        }
        
        sendSignedRequestWithDictResponse(endpoint: endpoint, method: .delete, parameters: parameters, completion: completion)
    }
    
    // 查询合约订单
    func getFuturesOrder(symbol: String, orderId: Int64? = nil, origClientOrderId: String? = nil, completion: @escaping (Result<FuturesOrderResponse, Error>) -> Void) {
        let endpoint = "/fapi/v1/order"
        
        var parameters: [String: Any] = ["symbol": symbol]
        
        if let orderId = orderId {
            parameters["orderId"] = orderId
        }
        
        if let origClientOrderId = origClientOrderId {
            parameters["origClientOrderId"] = origClientOrderId
        }
        
        sendSignedRequest(endpoint: endpoint, parameters: parameters, completion: completion)
    }
    
    // MARK: - 获取交易对列表
    
    // 获取所有合约交易对信息
    func getFuturesExchangeInfo(completion: @escaping (Result<[FuturesSymbolInfo], Error>) -> Void) {
        let endpoint = "/fapi/v1/exchangeInfo"
        
        sendPublicRequest(endpoint: endpoint) { (result: Result<FuturesExchangeInfo, Error>) in
            switch result {
            case .success(let exchangeInfo):
                self.availableSymbols = exchangeInfo.symbols.filter { $0.status == "TRADING" }
                completion(.success(self.availableSymbols))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 获取当前可用的交易对列表
    func getAvailableSymbols() -> [String] {
        return availableSymbols.map { $0.symbol }
    }
    
    // MARK: - WebSocket实时价格
    
    // 建立WebSocket连接获取实时价格
    func connectToTickerStream(for symbol: String) {
        // 关闭现有连接
        closeWebSocketConnection()
        
        print("正在连接WebSocket，Symbol: \(symbol)，测试网模式: \(Constants.Binance.useTestnet)")
        
        // 创建WebSocket连接 - 修正URL为正确的期货WebSocket地址
        // 币安期货WebSocket URL格式
        let urlString = Constants.Binance.useTestnet 
            ? "wss://dstream.binancefuture.com/ws/\(symbol.lowercased())@markPrice@1s" 
            : "wss://fstream.binance.com/ws/\(symbol.lowercased())@markPrice@1s"
        
        print("WebSocket URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("无效的WebSocket URL")
            return
        }
        
        let session = URLSession(configuration: .default)
        priceWebSocketTask = session.webSocketTask(with: url)
        priceWebSocketTask?.resume()
        
        print("WebSocket连接已启动")
        
        receiveMessage()
    }
    
    // 接收WebSocket消息
    private func receiveMessage() {
        priceWebSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
//                    print("收到WebSocket消息: \(text)")
                    self?.handleTickerMessage(text)
                    self?.receiveMessage() // 继续接收下一条消息
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        print("收到WebSocket数据消息: \(text)")
                        self?.handleTickerMessage(text)
                    }
                    self?.receiveMessage() // 继续接收下一条消息
                @unknown default:
                    break
                }
            case .failure(let error):
                print("WebSocket接收错误: \(error.localizedDescription)")
                
                // 添加自动重连逻辑
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self,
                          let symbol = self.getCurrentSymbolFromTask() else { return }
                    print("尝试重新连接WebSocket...")
                    self.connectToTickerStream(for: symbol)
                }
            }
        }
    }
    
    // 从当前WebSocket任务URL中提取交易对
    private func getCurrentSymbolFromTask() -> String? {
        guard let task = priceWebSocketTask,
              let url = task.currentRequest?.url?.absoluteString,
              let range = url.range(of: "ws/") else {
            return nil
        }
        
        let afterPrefix = url[range.upperBound...]
        if let endRange = afterPrefix.firstIndex(of: "@") {
            return String(afterPrefix[..<endRange]).uppercased()
        }
        return nil
    }
    
    // 处理Ticker消息
    private func handleTickerMessage(_ message: String) {
//        print("收到WebSocket消息: \(message)")
        
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        // 处理期货标记价格数据格式
        if let symbol = json["s"] as? String {
            var price: Double = 0
            
            // 尝试从不同格式中获取价格
            if let markPrice = json["p"] as? String {
                price = Double(markPrice) ?? 0
            } else if let markPrice = json["markPrice"] as? String {
                price = Double(markPrice) ?? 0
            } else if let markPrice = json["c"] as? String {
                price = Double(markPrice) ?? 0
            } else if let markPrice = json["p"] as? Double {
                price = markPrice
            } else if let markPrice = json["markPrice"] as? Double {
                price = markPrice
            }
            
            if price > 0 {
//                print("更新价格: \(symbol) - \(price)")
                // 触发价格更新回调
                DispatchQueue.main.async {
                    self.priceUpdateHandler?(symbol, price)
                }
            }
        }
    }
    
    // 关闭WebSocket连接
    func closeWebSocketConnection() {
        priceWebSocketTask?.cancel(with: .normalClosure, reason: nil)
        priceWebSocketTask = nil
    }
    
    // MARK: - 添加用于处理字典响应的公共请求方法
    
    // 发送公共API请求，返回字典类型
    private func sendPublicRequestWithDictResponse(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any] = [:],
        isTestnet: Bool = Constants.Binance.useTestnet,
        isFutures: Bool = true,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let urlString = (isFutures ? futuresURL : baseURL) + endpoint
        
        AF.request(
            urlString,
            method: method,
            parameters: parameters,
            encoding: URLEncoding.queryString,
            requestModifier: { $0.timeoutInterval = Constants.Network.timeoutInterval }
        )
        .validate()
        .responseJSON { response in
            switch response.result {
            case .success(let value):
                if let dict = value as? [String: Any] {
                    completion(.success(dict))
                } else {
                    let error = NSError(domain: "BinanceAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法将响应解析为字典"])
                    completion(.failure(error))
                }
            case .failure(let error):
                if let data = response.data, let apiError = try? JSONDecoder().decode(BinanceAPIError.self, from: data) {
                    let nsError = NSError(domain: "BinanceAPI", code: apiError.code, userInfo: [NSLocalizedDescriptionKey: apiError.msg])
                    completion(.failure(nsError))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // 获取合约持仓信息
    func getFuturesPositions(completion: @escaping (Result<[FuturesPosition], Error>) -> Void) {
        let endpoint = "/fapi/v2/positionRisk"
        
        sendSignedRequest(endpoint: endpoint, completion: completion)
    }
    
    // MARK: - 新增和修改的方法
    
    // 测试连接方法 - 供ViewController调用
    func testConnection(completion: @escaping (Bool, String) -> Void) {
        // 使用获取服务器时间这个简单接口来测试连接
        let endpoint = "/fapi/v1/time"
        let urlString = (Constants.Binance.useTestnet ? Constants.Binance.testFuturesURL : Constants.Binance.futuresURL) + endpoint
        
        print("测试连接请求: \(urlString)")
        
        AF.request(urlString)
            .validate()
            .responseJSON { [weak self] response in
                guard let self = self else { return }
                
                switch response.result {
                case .success:
                    print("连接测试成功，尝试获取账户信息...")
                    
                    // 如果连接成功，再测试带签名的API
                    self.getFuturesAccountInfo { result in
                        switch result {
                        case .success:
                            print("成功获取账户信息，API配置有效")
                            completion(true, "API连接配置有效")
                        case .failure(let error):
                            let errorMsg = error.localizedDescription
                            print("获取账户信息失败: \(errorMsg)")
                            
                            if errorMsg.contains("签名") || errorMsg.contains("-1022") {
                                completion(false, "API签名验证失败，请检查密钥和IP白名单")
                            } else {
                                completion(false, "API连接失败: \(errorMsg)")
                            }
                        }
                    }
                    
                case .failure(let error):
                    print("连接测试失败: \(error.localizedDescription)")
                    completion(false, "无法连接到币安服务器: \(error.localizedDescription)")
                }
            }
    }
    
    /// 切换到指定类型的API配置
    /// - Parameter isReadOnly: 是否使用只读API
    func switchAPIConfig(isReadOnly: Bool) {
        let keyPrefix = isReadOnly ? "ReadOnly_" : ""
        
        if let apiKey = UserDefaults.standard.string(forKey: "\(keyPrefix)BinanceAPIKey"),
           let secretKey = UserDefaults.standard.string(forKey: "\(keyPrefix)BinanceSecretKey") {
            
            Constants.Binance.apiKey = apiKey
            Constants.Binance.secretKey = secretKey
            
            print("已切换到\(isReadOnly ? "只读" : "交易")API配置")
        } else if isReadOnly {
            // 如果尝试切换到只读API但找不到，则使用交易API
            print("未找到只读API配置，尝试使用交易API配置")
            if let apiKey = UserDefaults.standard.string(forKey: "BinanceAPIKey"),
               let secretKey = UserDefaults.standard.string(forKey: "BinanceSecretKey") {
                Constants.Binance.apiKey = apiKey
                Constants.Binance.secretKey = secretKey
                print("已使用交易API配置")
            } else {
                print("未找到任何API配置")
            }
        } else {
            print("未找到交易API配置")
        }
    }
    
    // 设置止盈止损订单
    func setTPSL(params: TPSLParams, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        // 检查是否提供了止盈价或止损价
        guard params.takeProfitPrice != nil || params.stopLossPrice != nil else {
            let error = NSError(domain: "BinanceAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "必须设置止盈价或止损价"])
            completion(.failure(error))
            return
        }
        
        // 获取交易对的价格精度
        let precision = getSymbolPricePrecision(symbol: params.symbol)
        print("正在设置止盈止损 - 交易对: \(params.symbol), 价格精度: \(precision)")
        
        let dispatchGroup = DispatchGroup()
        var errors: [Error] = []
        var results: [[String: Any]] = []
        
        // 如果提供了止盈价，创建止盈单
        if let takeProfitPrice = params.takeProfitPrice, let quantity = params.takeProfitQuantity {
            dispatchGroup.enter()
            
            // 确定订单方向 - 平仓方向与持仓方向相反
            let orderSide: OrderSide = params.positionSide == .long ? .sell : .buy
            
            // 根据精度处理价格
            let formattedPrice = formatPrice(takeProfitPrice, precision: precision)
            
            let tpOrderParams = FuturesOrderParams(
                symbol: params.symbol,
                side: orderSide,
                positionSide: params.positionSide,
                type: .takeProfitMarket,
                timeInForce: nil,
                quantity: quantity,
                price: nil,
                reduceOnly: nil,  // 移除reduceOnly参数
                stopPrice: formattedPrice,
                closePosition: false,
                workingType: "MARK_PRICE"
            )
            
            print("创建止盈订单: \(params.symbol), 方向: \(orderSide), 价格: \(formattedPrice) (原始价格: \(takeProfitPrice))")
            createFuturesOrder(params: tpOrderParams) { result in
                switch result {
                case .success(let response):
                    if let dict = response as? [String: Any] {
                        results.append(dict)
                    }
                case .failure(let error):
                    print("创建止盈订单失败: \(error.localizedDescription)")
                    errors.append(error)
                }
                dispatchGroup.leave()
            }
        }
        
        // 如果提供了止损价，创建止损单
        if let stopLossPrice = params.stopLossPrice, let quantity = params.stopLossQuantity {
            dispatchGroup.enter()
            
            // 确定订单方向 - 平仓方向与持仓方向相反
            let orderSide: OrderSide = params.positionSide == .long ? .sell : .buy
            
            // 根据精度处理价格
            let formattedPrice = formatPrice(stopLossPrice, precision: precision)
            
            let slOrderParams = FuturesOrderParams(
                symbol: params.symbol,
                side: orderSide,
                positionSide: params.positionSide,
                type: .stopMarket,
                timeInForce: nil,
                quantity: quantity,
                price: nil,
                reduceOnly: nil,  // 移除reduceOnly参数
                stopPrice: formattedPrice,
                closePosition: false,
                workingType: "MARK_PRICE"
            )
            
            print("创建止损订单: \(params.symbol), 方向: \(orderSide), 价格: \(formattedPrice) (原始价格: \(stopLossPrice))")
            createFuturesOrder(params: slOrderParams) { result in
                switch result {
                case .success(let response):
                    if let dict = response as? [String: Any] {
                        results.append(dict)
                    }
                case .failure(let error):
                    print("创建止损订单失败: \(error.localizedDescription)")
                    errors.append(error)
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if errors.isEmpty {
                // 所有操作成功
                completion(.success(["orders": results]))
            } else {
                // 至少有一个操作失败
                let errorMessages = errors.map { $0.localizedDescription }.joined(separator: ", ")
                let error = NSError(domain: "BinanceAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "设置止盈止损失败: \(errorMessages)"])
                completion(.failure(error))
            }
        }
    }
    
    // 获取交易对的价格精度
    private func getSymbolPricePrecision(symbol: String) -> Int {
        // 默认精度为2，如果找不到交易对信息
        var precision = 2
        
        // 从已加载的交易对列表中查找
        if let symbolInfo = availableSymbols.first(where: { $0.symbol == symbol }) {
            precision = symbolInfo.pricePrecision
        } else {
            // 根据常见交易对的精度设置
            switch symbol {
            case "BTCUSDT":
                precision = 1  // BTC通常只需要1位小数
            case "ETHUSDT":
                precision = 2  // ETH通常只需要2位小数
            case _ where symbol.contains("USDT"):
                if symbol.contains("BTC") || symbol.contains("ETH") {
                    precision = 2
                } else {
                    precision = 4  // 其他USDT交易对通常需要4位小数
                }
            default:
                precision = 2  // 默认使用2位小数
            }
        }
        return precision
    }
    
    // 根据精度格式化价格
    private func formatPrice(_ price: Double, precision: Int) -> Double {
        let multiplier = pow(10.0, Double(precision))
        return round(price * multiplier) / multiplier
    }
    
    // 更新持仓杠杆
    func updatePositionLeverage(symbol: String, leverage: Int, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let endpoint = "/fapi/v1/leverage"
        let parameters: [String: Any] = [
            "symbol": symbol,
            "leverage": leverage
        ]
        
        sendSignedRequestWithDictResponse(endpoint: endpoint, method: .post, parameters: parameters, completion: completion)
    }
    
    // 更新保证金类型（全仓/逐仓）
    func updateMarginType(symbol: String, marginType: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let endpoint = "/fapi/v1/marginType"
        let parameters: [String: Any] = [
            "symbol": symbol,
            "marginType": marginType // "ISOLATED" 或 "CROSSED"
        ]
        
        sendSignedRequestWithDictResponse(endpoint: endpoint, method: .post, parameters: parameters, completion: completion)
    }
    
    // 执行完整的开仓操作
    func openPosition(params: OpenPositionParams, completion: @escaping (Result<FuturesOrderResponse, Error>) -> Void) {
        // 先设置杠杆
        setLeverage(symbol: params.symbol, leverage: params.leverage) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(_):
                print("杠杆设置成功: \(params.leverage)倍")
                
                // 可选：设置保证金类型
                if params.isIsolated {
                    self.updateMarginType(symbol: params.symbol, marginType: "ISOLATED") { marginResult in
                        switch marginResult {
                        case .success(_):
                            print("保证金类型设置为逐仓成功")
                            // 创建订单
                            self.createFuturesOrder(params: params.toFuturesOrderParams(), completion: completion)
                        case .failure(let error):
                            print("设置保证金类型失败: \(error.localizedDescription)")
                            completion(.failure(error))
                        }
                    }
                } else {
                    // 直接创建订单
                    self.createFuturesOrder(params: params.toFuturesOrderParams(), completion: completion)
                }
                
            case .failure(let error):
                print("设置杠杆失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // 获取24小时价格变化数据
    func get24hPriceChange(symbol: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let endpoint = Constants.Binance.useTestnet ? Constants.Binance.testFuturesURL : Constants.Binance.futuresURL
        let url = "\(endpoint)/fapi/v1/ticker/24hr"
        
        let parameters: [String: Any] = ["symbol": symbol]
        
        // 这是公共API，不需要签名
        AF.request(url, method: .get, parameters: parameters).responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        completion(.success(json))
                    } else {
                        let error = NSError(domain: "BinanceAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的响应格式"])
                        completion(.failure(error))
                    }
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 获取当前未完成的订单列表
    func getFuturesOpenOrders(completion: @escaping (Result<[FuturesOrderResponse], Error>) -> Void) {
        let endpoint = "/fapi/v1/openOrders"
        
        sendSignedRequest(endpoint: endpoint, parameters: [:], completion: completion)
    }
    
    // 取消指定交易对的所有未成交订单
    func cancelAllFuturesOrders(symbol: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let endpoint = "/fapi/v1/allOpenOrders"
        let parameters: [String: Any] = ["symbol": symbol]
        
        print("尝试取消所有订单 - 交易对: \(symbol)")
        
        // 确保使用DELETE方法并正确传递参数
        sendSignedRequestWithDictResponse(endpoint: endpoint, method: .delete, parameters: parameters) { result in
            switch result {
            case .success(let response):
                print("成功取消所有订单: \(response)")
                completion(.success(response))
            case .failure(let error):
                print("取消所有订单失败: \(error.localizedDescription)")
                
                // 处理签名错误
                if let nsError = error as? NSError, nsError.code == -1022 {
                    print("签名无效错误，尝试替代方法...")
                    
                    // 尝试使用替代API端点
                    let alternativeEndpoint = "/fapi/v1/cancelAllOpenOrders"
                    print("使用替代端点: \(alternativeEndpoint)")
                    
                    self.sendSignedRequestWithDictResponse(
                        endpoint: alternativeEndpoint, 
                        method: .delete, 
                        parameters: parameters
                    ) { retryResult in
                        completion(retryResult)
                    }
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // 设置双向持仓模式
    func changeDualSidePosition(dualSidePosition: Bool, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let endpoint = "/fapi/v1/positionSide/dual"
        let parameters: [String: Any] = [
            "dualSidePosition": dualSidePosition ? "true" : "false"
        ]
        
        sendSignedRequestWithDictResponse(endpoint: endpoint, method: .post, parameters: parameters, completion: completion)
    }
    
    // 获取当前持仓模式
    func getPositionMode(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let endpoint = "/fapi/v1/positionSide/dual"
        
        sendSignedRequestWithDictResponse(endpoint: endpoint, parameters: [:], completion: completion)
    }
} 
