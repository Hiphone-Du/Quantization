//
//  BinanceModels.swift
//  Quantization
//
//  Created by Claude on 2025/4/13.
//

import Foundation

// 合约行情数据模型
struct FuturesMarketPrice: Codable {
    let symbol: String
    let price: String
    
    var priceDouble: Double {
        return Double(price) ?? 0.0
    }
}

// 合约账户余额
struct FuturesAccountBalance: Codable {
    let asset: String
    let balance: String
    let crossWalletBalance: String
    let availableBalance: String
    
    var balanceDouble: Double {
        return Double(balance) ?? 0.0
    }
    
    var availableBalanceDouble: Double {
        return Double(availableBalance) ?? 0.0
    }
}

// 合约账户信息
struct FuturesAccountInfo: Codable {
    let assets: [FuturesAccountBalance]
    let positions: [FuturesPosition]
    let totalInitialMargin: String
    let totalMaintMargin: String
    let totalWalletBalance: String
    let totalUnrealizedProfit: String
    let totalMarginBalance: String
    let totalPositionInitialMargin: String
    let totalOpenOrderInitialMargin: String
    let totalCrossWalletBalance: String
    let availableBalance: String
    let maxWithdrawAmount: String
    
    // 添加可选初始化方法，便于从各种格式创建对象
    init(assets: [FuturesAccountBalance] = [],
         positions: [FuturesPosition] = [],
         totalInitialMargin: String = "0",
         totalMaintMargin: String = "0",
         totalWalletBalance: String = "0",
         totalUnrealizedProfit: String = "0",
         totalMarginBalance: String = "0",
         totalPositionInitialMargin: String = "0",
         totalOpenOrderInitialMargin: String = "0",
         totalCrossWalletBalance: String = "0",
         availableBalance: String = "0",
         maxWithdrawAmount: String = "0") {
        self.assets = assets
        self.positions = positions
        self.totalInitialMargin = totalInitialMargin
        self.totalMaintMargin = totalMaintMargin
        self.totalWalletBalance = totalWalletBalance
        self.totalUnrealizedProfit = totalUnrealizedProfit
        self.totalMarginBalance = totalMarginBalance
        self.totalPositionInitialMargin = totalPositionInitialMargin
        self.totalOpenOrderInitialMargin = totalOpenOrderInitialMargin
        self.totalCrossWalletBalance = totalCrossWalletBalance
        self.availableBalance = availableBalance
        self.maxWithdrawAmount = maxWithdrawAmount
    }
    
    // 从原始JSON字典创建账户信息对象
    static func fromJSON(_ json: [String: Any]) -> FuturesAccountInfo? {
        // 尝试解析assets数组
        var assets: [FuturesAccountBalance] = []
        if let assetsArray = json["assets"] as? [[String: Any]] {
            assets = assetsArray.compactMap { assetDict -> FuturesAccountBalance? in
                guard let asset = assetDict["asset"] as? String,
                      let balance = assetDict["balance"] as? String,
                      let crossWalletBalance = assetDict["crossWalletBalance"] as? String,
                      let availableBalance = assetDict["availableBalance"] as? String else {
                    return nil
                }
                
                return FuturesAccountBalance(
                    asset: asset,
                    balance: balance,
                    crossWalletBalance: crossWalletBalance,
                    availableBalance: availableBalance
                )
            }
        }
        
        // 尝试解析positions数组
        var positions: [FuturesPosition] = []
        if let positionsArray = json["positions"] as? [[String: Any]] {
            positions = positionsArray.compactMap { posDict -> FuturesPosition? in
                guard let symbol = posDict["symbol"] as? String,
                      let positionAmt = posDict["positionAmt"] as? String,
                      let entryPrice = posDict["entryPrice"] as? String,
                      let markPrice = posDict["markPrice"] as? String,
                      let unRealizedProfit = posDict["unRealizedProfit"] as? String,
                      let liquidationPrice = posDict["liquidationPrice"] as? String,
                      let leverage = posDict["leverage"] as? String,
                      let marginType = posDict["marginType"] as? String,
                      let positionSide = posDict["positionSide"] as? String,
                      let notional = posDict["notional"] as? String,
                      let updateTime = posDict["updateTime"] as? Int64 else {
                    return nil
                }
                
                return FuturesPosition(
                    symbol: symbol,
                    positionAmt: positionAmt,
                    entryPrice: entryPrice,
                    markPrice: markPrice,
                    unRealizedProfit: unRealizedProfit,
                    liquidationPrice: liquidationPrice,
                    leverage: leverage,
                    marginType: marginType,
                    isolatedMargin: posDict["isolatedMargin"] as? String,
                    positionSide: positionSide,
                    notional: notional,
                    isolatedWallet: posDict["isolatedWallet"] as? String,
                    updateTime: updateTime
                )
            }
        }
        
        // 创建对象，提取各种余额信息
        return FuturesAccountInfo(
            assets: assets,
            positions: positions,
            totalInitialMargin: json["totalInitialMargin"] as? String ?? "0",
            totalMaintMargin: json["totalMaintMargin"] as? String ?? "0",
            totalWalletBalance: json["totalWalletBalance"] as? String ?? "0",
            totalUnrealizedProfit: json["totalUnrealizedProfit"] as? String ?? "0",
            totalMarginBalance: json["totalMarginBalance"] as? String ?? "0",
            totalPositionInitialMargin: json["totalPositionInitialMargin"] as? String ?? "0",
            totalOpenOrderInitialMargin: json["totalOpenOrderInitialMargin"] as? String ?? "0",
            totalCrossWalletBalance: json["totalCrossWalletBalance"] as? String ?? "0",
            availableBalance: json["availableBalance"] as? String ?? "0",
            maxWithdrawAmount: json["maxWithdrawAmount"] as? String ?? "0"
        )
    }
}

// 合约持仓信息
struct FuturesPosition: Codable {
    let symbol: String
    let positionAmt: String
    let entryPrice: String
    let markPrice: String
    let unRealizedProfit: String
    let liquidationPrice: String
    let leverage: String
    let marginType: String
    let isolatedMargin: String?
    let positionSide: String
    let notional: String
    let isolatedWallet: String?
    let updateTime: Int64
    
    var positionAmount: Double {
        return Double(positionAmt) ?? 0.0
    }
    
    var entryPriceDouble: Double {
        return Double(entryPrice) ?? 0.0
    }
    
    var markPriceDouble: Double {
        return Double(markPrice) ?? 0.0
    }
    
    var unrealizedProfitDouble: Double {
        return Double(unRealizedProfit) ?? 0.0
    }
    
    var leverageInt: Int {
        return Int(leverage) ?? 1
    }
}

// 订单方向
enum OrderSide: String, Codable {
    case buy = "BUY"
    case sell = "SELL"
}

// 增强订单类型枚举，支持更多订单类型
enum OrderType: String, Codable, CaseIterable {
    case limit = "LIMIT"           // 限价单
    case market = "MARKET"         // 市价单
    case stop = "STOP"             // 止损单
    case stopMarket = "STOP_MARKET" // 止损市价单
    case takeProfit = "TAKE_PROFIT" // 止盈单
    case takeProfitMarket = "TAKE_PROFIT_MARKET" // 止盈市价单
    case trailingStopMarket = "TRAILING_STOP_MARKET" // 跟踪止损市价单
    case limit_maker = "LIMIT_MAKER" // 限价只挂单，如果会立即成交则订单会被拒绝
    
    var description: String {
        switch self {
        case .limit: return "限价单"
        case .market: return "市价单"
        case .stop: return "止损限价单"
        case .stopMarket: return "止损市价单"
        case .takeProfit: return "止盈限价单"
        case .takeProfitMarket: return "止盈市价单"
        case .trailingStopMarket: return "跟踪止损单"
        case .limit_maker: return "只挂单"
        }
    }
}

// 持仓方向
enum PositionSide: String, Codable {
    case both = "BOTH"
    case long = "LONG"
    case short = "SHORT"
}

// 时间有效性
enum TimeInForce: String, Codable {
    case gtc = "GTC" // Good Till Cancel
    case ioc = "IOC" // Immediate or Cancel
    case fok = "FOK" // Fill or Kill
}

// 下单参数
struct FuturesOrderParams {
    let symbol: String
    let side: OrderSide
    let positionSide: PositionSide?
    let type: OrderType
    let timeInForce: TimeInForce?
    let quantity: Double?
    let price: Double?
    let reduceOnly: Bool?
    let newClientOrderId: String?
    let stopPrice: Double?
    let closePosition: Bool?
    let activationPrice: Double?
    let callbackRate: Double?
    let workingType: String?
    let newOrderRespType: String?
    
    init(symbol: String,
         side: OrderSide,
         positionSide: PositionSide? = nil,
         type: OrderType,
         timeInForce: TimeInForce? = nil,
         quantity: Double? = nil,
         price: Double? = nil,
         reduceOnly: Bool? = nil,
         newClientOrderId: String? = nil,
         stopPrice: Double? = nil,
         closePosition: Bool? = nil,
         activationPrice: Double? = nil,
         callbackRate: Double? = nil,
         workingType: String? = nil,
         newOrderRespType: String? = nil) {
        self.symbol = symbol
        self.side = side
        self.positionSide = positionSide
        self.type = type
        self.timeInForce = timeInForce
        self.quantity = quantity
        self.price = price
        self.reduceOnly = reduceOnly
        self.newClientOrderId = newClientOrderId
        self.stopPrice = stopPrice
        self.closePosition = closePosition
        self.activationPrice = activationPrice
        self.callbackRate = callbackRate
        self.workingType = workingType
        self.newOrderRespType = newOrderRespType
    }
}

// 订单响应
struct FuturesOrderResponse: Codable {
    let orderId: Int64
    let symbol: String
    let status: String
    let clientOrderId: String
    let price: String
    let avgPrice: String
    let origQty: String
    let executedQty: String
    let cumQuote: String
    let timeInForce: String
    let type: String
    let reduceOnly: Bool
    let closePosition: Bool
    let side: String
    let positionSide: String
    let stopPrice: String
    let workingType: String
    let priceProtect: Bool
    let origType: String
    let priceMatch: String
    let selfTradePreventionMode: String
    let goodTillDate: Int64
    let time: Int64?
    let updateTime: Int64
    
    // 可选字段
    let leverage: String?
    let realizedPnl: String?
    
    // 计算属性
    var priceDouble: Double { Double(price) ?? 0 }
    var avgPriceDouble: Double { Double(avgPrice) ?? 0 }
    var origQtyDouble: Double { Double(origQty) ?? 0 }
    var executedQtyDouble: Double { Double(executedQty) ?? 0 }
    var stopPriceDouble: Double { Double(stopPrice) ?? 0 }
    var realizedPnlDouble: Double { Double(realizedPnl ?? "0") ?? 0 }
    var leverageDouble: Double { Double(leverage ?? "1") ?? 1 }
}

// API响应错误
struct BinanceAPIError: Codable {
    let code: Int
    let msg: String
}

// 添加精简版账户信息模型
struct SimplifiedAccountInfo {
    let totalBalance: Double
    let availableBalance: Double
    let unrealizedProfit: Double
    let marginBalance: Double
    let positions: [SimplifiedPosition]
    
    // 从完整账户信息创建简化版账户信息
    static func fromFuturesAccountInfo(_ accountInfo: FuturesAccountInfo) -> SimplifiedAccountInfo {
        // 提取活跃持仓
        let activePositions = accountInfo.positions.filter { Double($0.positionAmt) != 0 }
        let simplifiedPositions = activePositions.map { SimplifiedPosition.fromFuturesPosition($0) }
        
        return SimplifiedAccountInfo(
            totalBalance: Double(accountInfo.totalWalletBalance) ?? 0,
            availableBalance: Double(accountInfo.availableBalance) ?? 0,
            unrealizedProfit: Double(accountInfo.totalUnrealizedProfit) ?? 0,
            marginBalance: Double(accountInfo.totalMarginBalance) ?? 0,
            positions: simplifiedPositions
        )
    }
}

// 精简版持仓信息
struct SimplifiedPosition {
    let symbol: String
    let positionAmount: Double
    let entryPrice: Double
    let markPrice: Double
    let unrealizedProfit: Double
    let leverage: Int
    let positionSide: String
    let isLong: Bool
    
    // 构造函数，确保包含所有参数
    init(symbol: String, 
         positionAmount: Double, 
         entryPrice: Double, 
         markPrice: Double, 
         unrealizedProfit: Double, 
         leverage: Int, 
         positionSide: String, 
         isLong: Bool) {
        self.symbol = symbol
        self.positionAmount = positionAmount
        self.entryPrice = entryPrice
        self.markPrice = markPrice
        self.unrealizedProfit = unrealizedProfit
        self.leverage = leverage
        self.positionSide = positionSide
        self.isLong = isLong
    }
    
    // 计算持仓价值
    var positionValue: Double {
        return abs(positionAmount) * markPrice
    }
    
    // 计算盈亏百分比
    var profitPercentage: Double {
        if entryPrice == 0 || positionAmount == 0 {
            return 0
        }
        return (unrealizedProfit / (entryPrice * abs(positionAmount))) * 100
    }
    
    // 格式化盈亏文本，附带颜色标识
    func formattedProfitText() -> (text: String, isProfit: Bool) {
        let profitText = String(format: "%.2f USDT (%.2f%%)", unrealizedProfit, profitPercentage)
        return (profitText, unrealizedProfit >= 0)
    }
    
    // 从完整持仓信息创建简化版持仓信息
    static func fromFuturesPosition(_ position: FuturesPosition) -> SimplifiedPosition {
        let posAmount = Double(position.positionAmt) ?? 0
        
        return SimplifiedPosition(
            symbol: position.symbol,
            positionAmount: posAmount,
            entryPrice: Double(position.entryPrice) ?? 0,
            markPrice: Double(position.markPrice) ?? 0,
            unrealizedProfit: Double(position.unRealizedProfit) ?? 0,
            leverage: Int(position.leverage) ?? 1,
            positionSide: position.positionSide,
            isLong: posAmount > 0
        )
    }
}

// 开仓模式枚举
enum OpenPositionMode: String, CaseIterable {
    case market = "市价单"
    case limit = "限价单"
    
    var orderType: OrderType {
        switch self {
        case .market: return .market
        case .limit: return .limit
        }
    }
}

// 数量模式枚举
enum QuantityMode: String, CaseIterable {
    case amount = "数量"
    case percentage = "百分比"
}

// 增强持仓模型，添加止盈止损信息
struct PositionInfo {
    let position: SimplifiedPosition
    var takeProfitPrice: Double?
    var stopLossPrice: Double?
    var currentLeverage: Int
    
    init(position: SimplifiedPosition, 
         takeProfitPrice: Double? = nil, 
         stopLossPrice: Double? = nil) {
        self.position = position
        self.takeProfitPrice = takeProfitPrice
        self.stopLossPrice = stopLossPrice
        self.currentLeverage = position.leverage
    }
}

// 开仓参数模型
struct OpenPositionParams {
    let symbol: String
    let side: OrderSide
    let orderType: OrderType
    let quantity: Double
    let price: Double?
    let stopPrice: Double?
    let leverage: Int
    let reduceOnly: Bool?
    let isIsolated: Bool
    let positionSide: PositionSide?
    
    init(symbol: String, 
         side: OrderSide, 
         orderType: OrderType, 
         quantity: Double, 
         price: Double? = nil, 
         stopPrice: Double? = nil, 
         leverage: Int = 1, 
         reduceOnly: Bool? = nil,
         isIsolated: Bool = false,
         positionSide: PositionSide? = nil) {
        self.symbol = symbol
        self.side = side
        self.orderType = orderType
        self.quantity = quantity
        self.price = price
        self.stopPrice = stopPrice
        self.leverage = leverage
        self.reduceOnly = reduceOnly
        self.isIsolated = isIsolated
        self.positionSide = positionSide
    }
    
    // 转换为API请求参数
    func toFuturesOrderParams() -> FuturesOrderParams {
        return FuturesOrderParams(
            symbol: symbol,
            side: side,
            positionSide: positionSide,
            type: orderType,
            timeInForce: orderType == .market ? nil : .gtc,
            quantity: quantity,
            price: price,
            reduceOnly: reduceOnly,
            newClientOrderId: nil,
            stopPrice: stopPrice,
            closePosition: false,
            activationPrice: nil,
            callbackRate: nil,
            workingType: nil,
            newOrderRespType: nil
        )
    }
}

// 止盈止损参数模型
struct TPSLParams {
    let symbol: String
    let positionSide: PositionSide
    let takeProfitPrice: Double?
    let stopLossPrice: Double?
    let takeProfitQuantity: Double?
    let stopLossQuantity: Double?
    
    init(symbol: String, 
         positionSide: PositionSide, 
         takeProfitPrice: Double? = nil, 
         stopLossPrice: Double? = nil, 
         quantity: Double? = nil) {
        self.symbol = symbol
        self.positionSide = positionSide
        self.takeProfitPrice = takeProfitPrice
        self.stopLossPrice = stopLossPrice
        self.takeProfitQuantity = quantity
        self.stopLossQuantity = quantity
    }
} 