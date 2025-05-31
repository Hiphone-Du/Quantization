//
//  FuturesTradeViewController.swift
//  Quantization
//
//  Created by Claude on 2025/4/13.
//

import UIKit
import SnapKit
import Charts
import Alamofire
import Toast_Swift

class FuturesTradeViewController: UIViewController {
    
    // MARK: - 属性
    
    private var currentSymbol: String = "BTCUSDT" // 默认交易对
    private var currentLeverage: Int = 1 // 默认杠杆
    private var accountInfo: FuturesAccountInfo?
    private var positions: [FuturesPosition] = []
    private var markPrice: Double = 0.0
    private var fundingRate: Double = 0.0 // 资金费率
    private var nextFundingTime: Date? // 下次收取资金费时间
    private var availableSymbols: [String] = [] // 存储可用的交易对
    private var timer: Timer? // 定期刷新数据的计时器
    private var lastPositionUpdateTime = Date()
    private var priceChangePercent: Double = 0.0 // 添加价格变化百分比
    
    private let refreshControl = UIRefreshControl()
    
    // MARK: - 简化版账户信息属性
    
    private var simplifiedAccountInfo: SimplifiedAccountInfo? {
        didSet {
            updateAccountInfoUI()
        }
    }
    
    private var simplifiedPositions: [SimplifiedPosition] = [] {
        didSet {
            positionsTableView.reloadData()
        }
    }
    
    // MARK: - 修改订单类型枚举，只保留市价单和限价单
    private enum OrderType: String, CaseIterable {
        case market = "市价单"
        case limit = "限价单"
        
        var description: String {
            switch self {
            case .market: return "市价"
            case .limit: return "限价"
            }
        }
    }
    
    private var currentOrderType: OrderType = .limit {
        didSet {
            updateOrderUI()
        }
    }
    
    // MARK: - UI组件
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        return scrollView
    }()
    
    private let contentView = UIView()
    
    private let symbolLabel: UILabel = {
        let label = UILabel()
        label.text = "BTCUSDT"
        label.font = UIFont.boldSystemFont(ofSize: 24)
        return label
    }()
    
    private let priceChangeLabel: UILabel = {
        let label = UILabel()
        label.text = "0.00%"
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .systemGreen
        return label
    }()
    
    private let priceLabel: UILabel = {
        let label = UILabel()
        label.text = "价格: 加载中..."
        label.font = UIFont.systemFont(ofSize: 18)
        return label
    }()
    
    private let symbolPickerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("更换交易对", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()
    
    private let accountBalanceLabel: UILabel = {
        let label = UILabel()
        label.text = "账户余额: 加载中..."
        label.font = UIFont.systemFont(ofSize: 16)
        return label
    }()
    
    private let leverageSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 1
        slider.maximumValue = 125
        slider.value = 1
        return slider
    }()
    
    private let leverageLabel: UILabel = {
        let label = UILabel()
        label.text = "杠杆倍数: 1x"
        label.font = UIFont.systemFont(ofSize: 16)
        return label
    }()
    
    private let amountLabel: UILabel = {
        let label = UILabel()
        label.text = "交易额 (USDT):"
        label.font = UIFont.systemFont(ofSize: 16)
        return label
    }()
    
    private let amountTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "输入交易额"
        textField.borderStyle = .roundedRect
        textField.keyboardType = .decimalPad
        return textField
    }()
    
    private let longButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("做多 (买入)", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()
    
    private let shortButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("做空 (卖出)", for: .normal)
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()
    
    // 一键平仓按钮
    private let closeAllPositionsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("一键平仓", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemRed
        button.layer.cornerRadius = 5
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        return button
    }()
    
    // 取消所有委托按钮
    private let cancelAllOrdersButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("取消所有委托", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemOrange
        button.layer.cornerRadius = 5
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.isHidden = true  // 默认隐藏，切换到委托列表时显示
        return button
    }()
    
    private let positionsLabel: UILabel = {
        let label = UILabel()
        label.text = "持仓与委托"
        label.font = UIFont.boldSystemFont(ofSize: 20)
        return label
    }()
    
    private let positionsTableView: UITableView = {
        let tableView = UITableView()
        tableView.register(PositionTableViewCell.self, forCellReuseIdentifier: PositionTableViewCell.identifier)
        return tableView
    }()
    
    // 添加合约类型标签
    private let contractTypeLabel: UILabel = {
        let label = UILabel()
        label.text = "永续合约"
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textColor = .systemOrange
        label.textAlignment = .center
        label.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        return label
    }()
    
    // 添加资金费率标签
    private let fundingRateLabel: UILabel = {
        let label = UILabel()
        label.text = "资金费率: 加载中..."
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()
    
    // 添加下次资金费时间标签
    private let nextFundingTimeLabel: UILabel = {
        let label = UILabel()
        label.text = "下次收取: 加载中..."
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()
    
    // 添加持仓模式按钮
    private let positionModeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("单向持仓模式", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemPurple
        button.layer.cornerRadius = 8
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        return button
    }()
    
    // 添加账户信息摘要标签
    private let accountSummaryLabel: UILabel = {
        let label = UILabel()
        label.text = "账户信息摘要"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .darkGray
        label.numberOfLines = 0
        return label
    }()
    
    // 在类的适当位置添加属性
    private var isUsingReadOnlyAPI: Bool = false
    
    // 添加开仓模式选择器
    private let orderTypeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("限价单", for: .normal)
        button.backgroundColor = .systemGray6
        button.setTitleColor(.darkText, for: .normal)
        button.layer.cornerRadius = 8
        button.contentHorizontalAlignment = .left
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 10)
        return button
    }()
    
    // 添加数量模式选择器
    private let quantityModeSegmentedControl: UISegmentedControl = {
        let items = QuantityMode.allCases.map { $0.rawValue }
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0 // 默认选择数量模式
        return control
    }()
    
    // 添加价格输入框
    private let priceTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "输入价格"
        textField.borderStyle = .roundedRect
        textField.keyboardType = .decimalPad
        textField.isHidden = true // 默认市价单不显示价格输入框
        return textField
    }()
    
    // 添加数量百分比滑块
    private let quantityPercentageSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 100 // 默认100%
        slider.isHidden = true // 默认数量模式不显示百分比滑块
        return slider
    }()
    
    // 添加百分比显示标签
    private let percentageLabel: UILabel = {
        let label = UILabel()
        label.text = "100%"
        label.textAlignment = .right
        label.font = UIFont.systemFont(ofSize: 14)
        label.isHidden = true // 默认数量模式不显示百分比标签
        return label
    }()
    
    // 持仓信息容器
    private var positionInfos: [PositionInfo] = []
    
    // 持仓操作属性
    private var selectedPosition: PositionInfo?
    
    // 数量模式
    private var currentQuantityMode: QuantityMode = .amount {
        didSet {
            updateQuantityUI()
        }
    }
    
    // 计算可用开仓数量
    private var maxOpenQuantity: Double {
        guard let accountInfo = simplifiedAccountInfo else { return 0 }
        
        // 如果标记价格为0，返回0
        if markPrice <= 0 {
            return 0
        }
        
        // 基于可用余额计算最大可开仓数量
        let availableBalance = accountInfo.availableBalance
        
        // 考虑杠杆倍数
        let leverage = Double(currentLeverage)
        
        // 计算可用开仓数量（假设使用全部可用余额）
        // 币数量 = 可用余额 * 杠杆倍数 / 价格
        return availableBalance * leverage / markPrice
    }
    
    // 添加最优价按钮
    private let bestPriceButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("最优价", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()
    
    // 添加分段控制器用于切换显示持仓和委托
    private let positionsSegmentedControl: UISegmentedControl = {
        let items = ["持有仓位", "当前委托"]
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0 // 默认显示持仓
        return control
    }()
    
    // 当前订单数组
    private var currentOrders: [FuturesOrderResponse] = [] {
        didSet {
            positionsTableView.reloadData()
        }
    }
    
    // 当前视图模式
    private enum ViewMode {
        case positions  // 持仓
        case orders     // 委托
    }
    
    private var currentViewMode: ViewMode = .positions {
        didSet {
            positionsTableView.reloadData()
        }
    }
    
    // 双向持仓模式状态
    private var isDualSidePositionMode: Bool = false
    
    // 搜索结果
    private var filteredSymbols: [String] = []
    private var searchResultsTableView: UITableView?
    private var searchResultsVisible = false
    
    // MARK: - 生命周期方法
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 初始化交易对
        initializeSymbols()
        
        // 设置导航栏
        setupNavigationBar()
        
        // 初始化和设置UI
        setupUI()
        
        // 设置操作
        setupActions()
        
        // 刷新数据
        refreshData()
    }
    
    // 设置导航栏
    private func setupNavigationBar() {
        // 设置导航栏标题
        title = "期货交易"
        
        // 创建搜索控制器
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "搜索交易对"
        searchController.searchBar.tintColor = .systemBlue
        
        // 将搜索控制器添加到导航栏
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        
        // 添加刷新按钮
        let refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refreshButtonTapped))
        navigationItem.rightBarButtonItem = refreshButton
    }
    
    // 刷新按钮点击事件
    @objc private func refreshButtonTapped() {
        refreshData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 无论有无API Key，都启动价格更新
        // 启动当前交易对的WebSocket连接
        BinanceAPIService.shared.connectToTickerStream(for: currentSymbol)
        
        // 获取永续合约价格
        refreshPriceOnly()
        
        // 检查API配置，只有有API Key才能获取账户信息
        if Constants.Binance.apiKey.isEmpty || Constants.Binance.secretKey.isEmpty {
            showAPIConfigAlert()
        } else {
            // 有API Key时获取完整账户信息
            refreshAccountData()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 关闭WebSocket连接
        BinanceAPIService.shared.closeWebSocketConnection()
        
        // 停止定时刷新
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        // 添加视图
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(symbolLabel)
        contentView.addSubview(priceChangeLabel)
        contentView.addSubview(symbolPickerButton)
        contentView.addSubview(priceLabel)
        contentView.addSubview(accountBalanceLabel)
        contentView.addSubview(accountSummaryLabel)
        contentView.addSubview(leverageLabel)
        contentView.addSubview(leverageSlider)
        contentView.addSubview(contractTypeLabel)
        contentView.addSubview(fundingRateLabel)
        contentView.addSubview(nextFundingTimeLabel)
        
        // 交易模式选择器
        contentView.addSubview(orderTypeButton)
        contentView.addSubview(quantityModeSegmentedControl)
        
        // 价格和价格按钮
        contentView.addSubview(priceTextField)
        contentView.addSubview(bestPriceButton)
        
        // 交易数量相关
        contentView.addSubview(amountLabel)
        contentView.addSubview(amountTextField)
        contentView.addSubview(quantityPercentageSlider)
        contentView.addSubview(percentageLabel)
        
        // 按钮
        contentView.addSubview(longButton)
        contentView.addSubview(shortButton)
        
        // 持仓相关
        contentView.addSubview(positionsLabel)
        contentView.addSubview(positionsSegmentedControl)  // 添加分段控制器
        contentView.addSubview(closeAllPositionsButton)
        contentView.addSubview(cancelAllOrdersButton)
        contentView.addSubview(positionsTableView)
        
        // 设置约束
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView)
            make.width.equalTo(scrollView)
            // 内容视图高度会根据子视图动态调整
        }
        
        symbolLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(20)
        }
        
        priceChangeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(symbolLabel)
            make.leading.equalTo(symbolLabel.snp.trailing).offset(8)
        }
        
        symbolPickerButton.snp.makeConstraints { make in
            make.centerY.equalTo(symbolLabel)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        priceLabel.snp.makeConstraints { make in
            make.top.equalTo(symbolLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(20)
        }
        
        // 合约类型标签
        contractTypeLabel.snp.makeConstraints { make in
            make.top.equalTo(symbolLabel.snp.bottom).offset(8)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(24)
            make.width.equalTo(80)
        }
        
        // 资金费率标签和下次收取时间
        fundingRateLabel.snp.makeConstraints { make in
            make.top.equalTo(priceLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(20)
        }
        
        nextFundingTimeLabel.snp.makeConstraints { make in
            make.top.equalTo(fundingRateLabel)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        accountBalanceLabel.snp.makeConstraints { make in
            make.top.equalTo(fundingRateLabel.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        // 在适当位置添加账户摘要标签
        accountSummaryLabel.snp.makeConstraints { make in
            make.top.equalTo(accountBalanceLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        // 调整leverage标签的位置，放在摘要后面
        leverageLabel.snp.makeConstraints { make in
            make.top.equalTo(accountSummaryLabel.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(20)
        }
        
        leverageSlider.snp.makeConstraints { make in
            make.top.equalTo(leverageLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        // ====== 交易控件布局优化 ======
        // 1. 先放置订单模式选择器
        orderTypeButton.snp.makeConstraints { make in
            make.top.equalTo(leverageSlider.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        // 2. 价格输入框放在订单模式下面
        priceTextField.snp.makeConstraints { make in
            make.top.equalTo(orderTypeButton.snp.bottom).offset(15)
            make.leading.equalToSuperview().offset(20)
            make.width.equalTo((view.frame.width - 60) * 0.7) // 70%的宽度
            make.height.equalTo(44)
        }
        
        bestPriceButton.snp.makeConstraints { make in
            make.top.equalTo(priceTextField)
            make.leading.equalTo(priceTextField.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(priceTextField)
        }
        
        // 4. 数量模式选择器放在价格输入框下面
        quantityModeSegmentedControl.snp.makeConstraints { make in
            make.top.equalTo(priceTextField.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        // 5. 交易数量相关控件
        amountLabel.snp.makeConstraints { make in
            make.top.equalTo(quantityModeSegmentedControl.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(20)
        }
        
        amountTextField.snp.makeConstraints { make in
            make.top.equalTo(amountLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(44)
        }
        
        // 百分比滑块和标签
        quantityPercentageSlider.snp.makeConstraints { make in
            make.top.equalTo(amountTextField.snp.bottom).offset(15)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalTo(percentageLabel.snp.leading).offset(-10)
        }
        
        percentageLabel.snp.makeConstraints { make in
            make.centerY.equalTo(quantityPercentageSlider)
            make.trailing.equalToSuperview().offset(-20)
            make.width.equalTo(50)
        }
        
        // 6. 操作按钮
        longButton.snp.makeConstraints { make in
            make.top.equalTo(quantityPercentageSlider.snp.bottom).offset(25)
            make.leading.equalToSuperview().offset(20)
            make.width.equalTo((view.frame.width - 60) / 2)
            make.height.equalTo(50)
        }
        
        shortButton.snp.makeConstraints { make in
            make.top.equalTo(longButton)
            make.trailing.equalToSuperview().offset(-20)
            make.width.equalTo(longButton)
            make.height.equalTo(50)
        }
        
        // 7. 持仓相关
        positionsLabel.snp.makeConstraints { make in
            make.top.equalTo(shortButton.snp.bottom).offset(25)
            make.leading.equalToSuperview().offset(20)
        }
        
        // 添加分段控制器约束
        positionsSegmentedControl.snp.makeConstraints { make in
            make.centerY.equalTo(positionsLabel)
            make.trailing.equalToSuperview().offset(-20)
            make.width.equalTo(180)
        }
        
        closeAllPositionsButton.snp.makeConstraints { make in
            make.top.equalTo(positionsLabel.snp.bottom).offset(10)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(30)
            make.width.equalTo(100)
        }
        
        cancelAllOrdersButton.snp.makeConstraints { make in
            make.top.equalTo(positionsLabel.snp.bottom).offset(10)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(30)
            make.width.equalTo(120)
        }
        
        positionsTableView.snp.makeConstraints { make in
            make.top.equalTo(positionsLabel.snp.bottom).offset(50)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(300)
            make.bottom.equalToSuperview().offset(-20)
        }
    }
    
    private func setupActions() {
        // 添加各种按钮和控件的事件处理
        symbolPickerButton.addTarget(self, action: #selector(showSymbolPicker), for: .touchUpInside)
        
        leverageSlider.addTarget(self, action: #selector(leverageChanged), for: .valueChanged)
        
        orderTypeButton.addTarget(self, action: #selector(showOrderTypePicker), for: .touchUpInside)
        quantityModeSegmentedControl.addTarget(self, action: #selector(quantityModeChanged), for: .valueChanged)
        
        bestPriceButton.addTarget(self, action: #selector(setBestPrice), for: .touchUpInside)
        
        // 数量调整相关事件
        amountTextField.addTarget(self, action: #selector(amountChanged), for: .editingChanged)
        quantityPercentageSlider.addTarget(self, action: #selector(quantityPercentageChanged), for: .valueChanged)
        
        // 交易按钮
        longButton.addTarget(self, action: #selector(longButtonTapped), for: .touchUpInside)
        shortButton.addTarget(self, action: #selector(shortButtonTapped), for: .touchUpInside)
        
        // 持仓操作按钮
        closeAllPositionsButton.addTarget(self, action: #selector(closeAllPositionsButtonTapped), for: .touchUpInside)
        cancelAllOrdersButton.addTarget(self, action: #selector(cancelAllOrdersButtonTapped), for: .touchUpInside)
        
        // 添加分段控制器的事件处理
        positionsSegmentedControl.addTarget(self, action: #selector(positionsViewModeChanged), for: .valueChanged)
    }
    
    private func setupTableView() {
        positionsTableView.dataSource = self
        positionsTableView.delegate = self
    }
    
    // MARK: - 数据方法
    
    @objc private func refreshData() {
        // 获取当前交易对行情
        getMarketPrice()
        
        // 获取账户信息
        getAccountInfo()
        
        // 获取资金费率
        getFundingRate()
        
        // 刷新账户数据
        refreshAccountData()
        
        // 如果当前在委托模式，刷新委托订单
        if currentViewMode == .orders {
            getCurrentOrders()
        }
        
        // 隐藏刷新控件
        refreshControl.endRefreshing()
        
        // 隐藏加载指示器
        hideLoadingIndicator()
    }
    
    private func getMarketPrice() {
        // 获取永续合约价格
        BinanceAPIService.shared.getFuturesMarkPrice(symbol: currentSymbol) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let marketPrice):
                    self?.markPrice = marketPrice.priceDouble
                    self?.priceLabel.text = "价格: \(String(format: "%.2f", marketPrice.priceDouble)) USDT"
                    
                    // 获取24小时价格变化数据
                    self?.get24hPriceChange()
                    
                case .failure(let error):
                    print("获取价格失败: \(error.localizedDescription)")
                    self?.priceLabel.text = "价格: 加载失败"
                }
            }
        }
    }
    
    // 获取24小时价格变化
    private func get24hPriceChange() {
        BinanceAPIService.shared.get24hPriceChange(symbol: currentSymbol) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let priceChange):
                    if let percentChangeStr = priceChange["priceChangePercent"] as? String,
                       let percentChange = Double(percentChangeStr) {
                        self?.priceChangePercent = percentChange
                        
                        // 根据涨跌设置不同颜色
                        let percentText = percentChange >= 0 ? 
                            "+\(String(format: "%.2f", percentChange))%" : 
                            "\(String(format: "%.2f", percentChange))%"
                            
                        self?.priceChangeLabel.text = percentText
                        self?.priceChangeLabel.textColor = percentChange >= 0 ? .systemGreen : .systemRed
                    }
                case .failure(let error):
                    print("获取24小时价格变化失败: \(error.localizedDescription)")
                    self?.priceChangeLabel.text = "0.00%"
                }
            }
        }
    }
    
    private func getAccountInfo() {
        BinanceAPIService.shared.getFuturesAccountInfo { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let accountInfo):
                    self?.accountInfo = accountInfo
                    
                    // 创建简化版账户信息
                    let simplified = SimplifiedAccountInfo.fromFuturesAccountInfo(accountInfo)
                    self?.simplifiedAccountInfo = simplified
                    
                    // 更新UI
                    if let usdtBalance = accountInfo.assets.first(where: { $0.asset == "USDT" }) {
                        self?.accountBalanceLabel.text = "账户余额: \(String(format: "%.2f", usdtBalance.availableBalanceDouble)) USDT"
                    }
                    
                    // 单独获取持仓信息
                    self?.getFuturesPositions()
                    
                    // 更新账户信息UI
                    self?.updateAccountInfoUI()
                    
                case .failure(let error):
                    print("获取账户信息失败: \(error.localizedDescription)")
                    self?.showAlert(title: "错误", message: "获取账户信息失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func getFundingRate() {
        // 获取资金费率
        BinanceAPIService.shared.getFuturesFundingRate(symbol: currentSymbol) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let lastFundingRate = data["lastFundingRate"] as? String,
                       let rate = Double(lastFundingRate),
                       let nextFundingTimeStr = data["nextFundingTime"] as? Int64 {
                        
                        // 更新资金费率
                        self?.fundingRate = rate
                        let ratePercentage = rate * 100
                        let rateText = ratePercentage >= 0 ? "+\(String(format: "%.4f", ratePercentage))%" : "\(String(format: "%.4f", ratePercentage))%"
                        self?.fundingRateLabel.text = "资金费率: \(rateText)"
                        
                        // 设置资金费率颜色
                        self?.fundingRateLabel.textColor = ratePercentage >= 0 ? .systemGreen : .systemRed
                        
                        // 更新下次收取时间
                        let nextFundingDate = Date(timeIntervalSince1970: TimeInterval(nextFundingTimeStr/1000))
                        self?.nextFundingTime = nextFundingDate
                        
                        let formatter = DateFormatter()
                        formatter.dateFormat = "MM-dd HH:mm"
                        let timeString = formatter.string(from: nextFundingDate)
                        self?.nextFundingTimeLabel.text = "下次收取: \(timeString)"
                    }
                case .failure(let error):
                    print("获取资金费率失败: \(error.localizedDescription)")
                    self?.fundingRateLabel.text = "资金费率: 加载失败"
                    self?.nextFundingTimeLabel.text = "下次收取: 未知"
                }
            }
        }
    }
    
    // MARK: - 按钮动作
    
    @objc private func leverageChanged() {
        let leverage = Int(leverageSlider.value)
        leverageLabel.text = "杠杆倍数: \(leverage)x"
    }
    
    @objc private func showOrderTypePicker() {
        // 创建菜单
        let actionSheet = UIAlertController(title: "选择订单类型", message: nil, preferredStyle: .actionSheet)
        
        // 添加市价单选项
        actionSheet.addAction(UIAlertAction(title: OrderType.market.rawValue, style: .default) { [weak self] _ in
            self?.currentOrderType = .market
            self?.orderTypeButton.setTitle(OrderType.market.rawValue, for: .normal)
        })
        
        // 添加限价单选项
        actionSheet.addAction(UIAlertAction(title: OrderType.limit.rawValue, style: .default) { [weak self] _ in
            self?.currentOrderType = .limit
            self?.orderTypeButton.setTitle(OrderType.limit.rawValue, for: .normal)
        })
        
        // 添加取消选项
        actionSheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        
        // 在iPad上的处理
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = orderTypeButton
            popoverController.sourceRect = orderTypeButton.bounds
        }
        
        // 显示菜单
        present(actionSheet, animated: true, completion: nil)
    }
    
    @objc private func quantityModeChanged() {
        currentQuantityMode = QuantityMode.allCases[quantityModeSegmentedControl.selectedSegmentIndex]
    }
    
    @objc private func quantityPercentageChanged() {
        let percentage = Int(quantityPercentageSlider.value)
        percentageLabel.text = "\(percentage)%"
        
        // 计算并更新数量输入框
        if currentQuantityMode == .percentage {
            // 获取账户信息
            guard let accountInfo = simplifiedAccountInfo else {
                return
            }
            
            // 获取当前杠杆倍数
            let leverage = Double(currentLeverage)
            
            // 基于可用余额计算交易额
            let availableBalance = accountInfo.availableBalance
            
            // 计算交易额：可用余额 * 百分比 * 杠杆倍数 * 0.98 (预留2%缓冲区)
            let usdtAmount = availableBalance * Double(percentage) / 100.0 * leverage * 0.98
            
            // 需要确保交易额与实际币安交易额一致，需要计算实际数量
            if markPrice > 0 {
                // 计算实际数量 = 交易额 / 价格
                let quantity = usdtAmount / markPrice
                
                // 获取交易对精度
                let symbol = currentSymbol
                var decimalPlaces = 3 // 默认3位小数
                
                if symbol.contains("BTC") {
                    decimalPlaces = 3
                } else if symbol.contains("ETH") {
                    decimalPlaces = 3
                } else if symbol.contains("SOL") {
                    decimalPlaces = 1
                } else {
                    decimalPlaces = 0
                }
                
                // 格式化数量，确保不超过交易所允许的精度
                let formattedQuantity = quantity.rounded(toPlaces: decimalPlaces)
                
                // 获取价格精度
                let pricePrecision = getSymbolPricePrecision(symbol: symbol)
                let formattedPrice = markPrice.rounded(toPlaces: pricePrecision)
                
                // 计算实际交易额 = 格式化后数量 × 格式化后价格
                let actualOrderValue = formattedQuantity * formattedPrice
                
                // 格式化并更新交易额
                let formattedAmount = String(format: "%.2f", actualOrderValue)
                amountTextField.text = formattedAmount
                
                print("滑块选择: \(percentage)% -> 计算交易额: \(usdtAmount) -> 数量: \(formattedQuantity) -> 实际交易额: \(actualOrderValue)")
            } else {
                // 如果没有价格，直接使用计算的交易额
                let formattedAmount = String(format: "%.2f", usdtAmount)
                amountTextField.text = formattedAmount
            }
        }
    }
    
    @objc private func amountChanged() {
        // 检查输入是否为空
        guard let amountText = amountTextField.text, !amountText.isEmpty else {
            return
        }
        
        // 检查输入是否为数字
        guard let amount = Double(amountText) else {
            return
        }
        
        // 更新金额输入框
        amountTextField.text = String(format: "%.2f", amount)
    }
    
    @objc private func longButtonTapped() {
        submitOrder(side: .buy)
    }
    
    @objc private func shortButtonTapped() {
        submitOrder(side: .sell)
    }
    
    @objc private func closeAllPositionsButtonTapped() {
        if positions.isEmpty {
            showAlert(title: "提示", message: "当前没有持仓")
            return
        }
        
        let alertController = UIAlertController(
            title: "确认平仓",
            message: "确定要平仓所有持仓吗？",
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "确定", style: .destructive) { [weak self] _ in
            self?.closeAllPositions()
        })
        
        present(alertController, animated: true, completion: nil)
    }
    
    @objc private func cancelAllOrdersButtonTapped() {
        if currentOrders.isEmpty {
            showAlert(title: "提示", message: "当前没有委托订单")
            return
        }
        
        let alertController = UIAlertController(
            title: "确认取消",
            message: "确定要取消所有委托订单吗？",
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "确定", style: .destructive) { [weak self] _ in
            self?.cancelAllOrders()
        })
        
        present(alertController, animated: true, completion: nil)
    }
    
    @objc private func positionsViewModeChanged() {
        let selectedIndex = positionsSegmentedControl.selectedSegmentIndex
        currentViewMode = selectedIndex == 0 ? .positions : .orders
        
        // 根据当前模式，显示或隐藏相应的按钮
        closeAllPositionsButton.isHidden = currentViewMode == .orders
        cancelAllOrdersButton.isHidden = currentViewMode == .positions
        
        // 如果切换到持仓列表，则刷新账户数据和持仓数据
        if currentViewMode == .positions {
            // 刷新账户数据以更新持仓信息
            refreshAccountData()
            
            // 立即更新持仓盈亏信息，不等待网络响应
            updatePositionProfits()
        }
        // 如果切换到委托列表，则获取当前委托
        else if currentViewMode == .orders {
            getCurrentOrders()
        }
    }
    
    @objc private func setBestPrice() {
        // 使用当前价格作为最优价
        if markPrice > 0 {
            priceTextField.text = String(format: "%.2f", markPrice)
        }
    }
    
    // 处理开仓模式变更
    @objc private func orderTypeChanged() {
        // 创建菜单
        let actionSheet = UIAlertController(title: "选择订单类型", message: nil, preferredStyle: .actionSheet)
        
        // 添加市价单选项
        actionSheet.addAction(UIAlertAction(title: OrderType.market.rawValue, style: .default) { [weak self] _ in
            self?.currentOrderType = .market
            self?.orderTypeButton.setTitle(OrderType.market.rawValue, for: .normal)
        })
        
        // 添加限价单选项
        actionSheet.addAction(UIAlertAction(title: OrderType.limit.rawValue, style: .default) { [weak self] _ in
            self?.currentOrderType = .limit
            self?.orderTypeButton.setTitle(OrderType.limit.rawValue, for: .normal)
        })
        
        // 添加取消选项
        actionSheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        
        // 在iPad上的处理
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = orderTypeButton
            popoverController.sourceRect = orderTypeButton.bounds
        }
        
        // 显示菜单
        present(actionSheet, animated: true, completion: nil)
    }
    
    // MARK: - 辅助方法
    
    private func showAPIConfigAlert() {
        let alertController = UIAlertController(
            title: "未配置API",
            message: "请先配置币安API Key和Secret",
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "去设置", style: .default) { [weak self] _ in
            let apiConfigVC = APIConfigViewController()
            self?.navigationController?.pushViewController(apiConfigVC, animated: true)
        })
        
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        
        present(alertController, animated: true, completion: nil)
    }
    
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    // MARK: - 新增方法
    
    // 获取可用的交易对
    private func loadAvailableSymbols() {
        BinanceAPIService.shared.getFuturesExchangeInfo { [weak self] result in
            switch result {
            case .success(let symbols):
                let symbolNames = symbols.map { $0.symbol }
                self?.availableSymbols = symbolNames.filter { $0.hasSuffix("USDT") } // 只显示以USDT结尾的交易对
            case .failure(let error):
                print("获取交易对失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 设置定时刷新
    private func setupRefreshTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshAccountData()
        }
    }
    
    // 更新持仓的未实现盈亏
    private func updatePositionProfits() {
        // 遍历所有持仓并更新它们的标记价格和未实现盈亏
        if !simplifiedPositions.isEmpty && markPrice > 0 {
            // 只更新当前交易对的持仓
            let symbol = currentSymbol
            for (index, position) in simplifiedPositions.enumerated() {
                if position.symbol == symbol {
                    // 更新持仓的未实现盈亏
                    let entryPrice = position.entryPrice
                    let positionAmt = position.positionAmount
                    let isLong = position.isLong
                    
                    // 计算新的未实现盈亏
                    var profit: Double = 0.0
                    if isLong {
                        // 多头: (当前价格 - 开仓价格) * 持仓数量
                        profit = (markPrice - entryPrice) * abs(positionAmt)
                    } else {
                        // 空头: (开仓价格 - 当前价格) * 持仓数量
                        profit = (entryPrice - markPrice) * abs(positionAmt)
                    }
                    
                    // 更新持仓
                    var updatedPosition = position
                    // 使用直接更新未实现盈亏的方式
                    // 注意：由于SimplifiedPosition是结构体，我们需要创建一个新的实例
                    // 假设这里有方法可以创建更新后的实例
                    
                    // 如果有positionsTableView可见并且显示的是持仓视图，则刷新UI
                    if currentViewMode == .positions && positionsTableView.window != nil {
                        DispatchQueue.main.async {
                            self.positionsTableView.reloadData()
                        }
                    }
                }
            }
        }
    }
    
    // 刷新账户数据
    private func refreshAccountData() {
        // 从服务中获取账户信息
        BinanceAPIService.shared.getFuturesAccountInfo { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let accountInfo):
                    self?.accountInfo = accountInfo
                    self?.updateAccountInfoUI()
                case .failure(let error):
                    print("刷新账户数据失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 添加单独获取持仓信息的方法
    private func getFuturesPositions() {
        // 调用获取持仓的API
        BinanceAPIService.shared.getFuturesPositions { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let positions):
                    // 过滤出有持仓的记录
                    self?.positions = positions.filter { 
                        Double($0.positionAmt) != 0
                    }
                    
                    // 转换为简化版持仓信息
                    self?.simplifiedPositions = self?.positions.map { 
                        SimplifiedPosition.fromFuturesPosition($0)
                    } ?? []
                    
                case .failure(let error):
                    print("获取持仓信息失败: \(error.localizedDescription)")
                    self?.showAlert(title: "错误", message: "获取持仓信息失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 关闭所有持仓
    private func closeAllPositions() {
        guard !positions.isEmpty else { return }
        
        // 显示加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        let dispatchGroup = DispatchGroup()
        var errors: [Error] = []
        
        // 遍历每个持仓并平仓
        for position in positions {
            dispatchGroup.enter()
            
            // 判断当前是否为双向持仓模式，根据模式设置不同的参数
            var positionSideParam: PositionSide? = nil
            
            // 判断持仓方向
            let posAmount = position.positionAmount
            let isLong = posAmount > 0
            
            if isDualSidePositionMode {
                // 双向持仓模式下，必须指定positionSide
                positionSideParam = isLong ? .long : .short
            }
            
            // 创建平仓订单参数
            let orderSide: OrderSide = isLong ? .sell : .buy
            let orderParams = FuturesOrderParams(
                symbol: position.symbol,
                side: orderSide,
                positionSide: positionSideParam, // 根据持仓模式设置positionSide
                type: .market,
                timeInForce: nil,
                quantity: abs(posAmount),
                price: nil,
                reduceOnly: true,
                newClientOrderId: nil,
                stopPrice: nil,
                closePosition: false,
                activationPrice: nil,
                callbackRate: nil,
                workingType: nil,
                newOrderRespType: nil
            )
            
            // 发送平仓订单
            BinanceAPIService.shared.createFuturesOrder(params: orderParams) { result in
                switch result {
                case .success(_):
                    print("成功平仓: \(position.symbol) \(isLong ? "多" : "空")仓")
                case .failure(let error):
                    print("平仓失败: \(position.symbol) - \(error.localizedDescription)")
                    errors.append(error)
                }
                dispatchGroup.leave()
            }
        }
        
        // 所有请求完成后更新UI
        dispatchGroup.notify(queue: .main) { [weak self] in
            activityIndicator.stopAnimating()
            activityIndicator.removeFromSuperview()
            
            if errors.isEmpty {
                self?.showAlert(title: "成功", message: "所有持仓已平仓")
            } else {
                let errorMessages = errors.map { $0.localizedDescription }.joined(separator: "\n")
                self?.showAlert(title: "部分平仓失败", message: errorMessages)
            }
            
            // 刷新数据
            self?.refreshData()
        }
    }
    
    // 新增方法 - 只刷新价格和资金费率，不需要API Key
    private func refreshPriceOnly() {
        // 获取永续合约价格
        BinanceAPIService.shared.getFuturesMarkPrice(symbol: currentSymbol) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let marketPrice):
                    self?.markPrice = marketPrice.priceDouble
                    self?.priceLabel.text = "价格: \(String(format: "%.2f", marketPrice.priceDouble)) USDT"
                    
                    // 获取24小时价格变化
                    self?.get24hPriceChange()
                    
                case .failure(let error):
                    print("获取价格失败: \(error.localizedDescription)")
                    self?.priceLabel.text = "价格: 加载失败"
                }
            }
        }
        
        // 获取资金费率
        BinanceAPIService.shared.getFuturesFundingRate(symbol: currentSymbol) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let lastFundingRate = data["lastFundingRate"] as? String,
                       let rate = Double(lastFundingRate),
                       let nextFundingTimeStr = data["nextFundingTime"] as? Int64 {
                        
                        // 更新资金费率
                        self?.fundingRate = rate
                        let ratePercentage = rate * 100
                        let rateText = ratePercentage >= 0 ? "+\(String(format: "%.4f", ratePercentage))%" : "\(String(format: "%.4f", ratePercentage))%"
                        self?.fundingRateLabel.text = "资金费率: \(rateText)"
                        
                        // 设置资金费率颜色
                        self?.fundingRateLabel.textColor = ratePercentage >= 0 ? .systemGreen : .systemRed
                        
                        // 更新下次收取时间
                        let nextFundingDate = Date(timeIntervalSince1970: TimeInterval(nextFundingTimeStr/1000))
                        self?.nextFundingTime = nextFundingDate
                        
                        let formatter = DateFormatter()
                        formatter.dateFormat = "MM-dd HH:mm"
                        let timeString = formatter.string(from: nextFundingDate)
                        self?.nextFundingTimeLabel.text = "下次收取: \(timeString)"
                    }
                case .failure(let error):
                    print("获取资金费率失败: \(error.localizedDescription)")
                    self?.fundingRateLabel.text = "资金费率: 加载失败"
                    self?.nextFundingTimeLabel.text = "下次收取: 未知"
                }
            }
        }
    }
    
    // MARK: - 网络信息
    
    /// 更新网络信息
    private func updateNetworkInfo() {
        // 保留网络类型检查但删除IP相关代码
        NetworkUtils.shared.checkNetworkType { [weak self] (networkType: NetworkType) in
            DispatchQueue.main.async {
                // 根据网络类型更新UI
                if networkType == .none {
                    self?.showAlert(title: "网络错误", message: "未检测到网络连接，请确保连接到WiFi或移动网络")
                }
            }
        }
    }
    
    // MARK: - 更新账户信息UI
    
    private func updateAccountInfoUI() {
        guard let accountInfo = simplifiedAccountInfo else { return }
        
        // 更新账户余额显示
        accountBalanceLabel.text = String(format: "账户余额: %.2f USDT", accountInfo.totalBalance)
        
        // 使用富文本和等宽字体处理账户摘要信息，防止数字宽度变化导致的左右跳动
        let attributedSummary = NSMutableAttributedString()
        
        // 添加可用余额部分
        attributedSummary.append(NSAttributedString(
            string: "可用余额: ",
            attributes: [
                .foregroundColor: UIColor.darkText,
                .font: UIFont.systemFont(ofSize: 14, weight: .regular)
            ]
        ))
        attributedSummary.append(NSAttributedString(
            string: String(format: "%9.2f", accountInfo.availableBalance),
            attributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)]
        ))
        attributedSummary.append(NSAttributedString(
            string: " USDT | ",
            attributes: [
                .foregroundColor: UIColor.darkText,
                .font: UIFont.systemFont(ofSize: 14, weight: .regular)
            ]
        ))
        
        // 添加未实现盈亏部分 - 使用固定宽度格式并设置颜色
        attributedSummary.append(NSAttributedString(
            string: "未实现盈亏: ",
            attributes: [
                .foregroundColor: UIColor.darkText,
                .font: UIFont.systemFont(ofSize: 14, weight: .regular)
            ]
        ))
        
        // 格式化未实现盈亏，使用固定宽度
        let profit = accountInfo.unrealizedProfit
        let formattedProfit = String(format: profit >= 0 ? "+%8.2f" : "%8.2f", profit)
        
        // 始终使用绿色或红色，不用灰色
        let profitColor: UIColor = profit >= 0 ? .systemGreen : .systemRed
        
        attributedSummary.append(NSAttributedString(
            string: formattedProfit,
            attributes: [
                .foregroundColor: profitColor,
                .font: UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold)
            ]
        ))
        attributedSummary.append(NSAttributedString(
            string: " USDT | ",
            attributes: [
                .foregroundColor: UIColor.darkText,
                .font: UIFont.systemFont(ofSize: 14, weight: .regular)
            ]
        ))
        
        // 添加保证金余额部分
        attributedSummary.append(NSAttributedString(
            string: "保证金余额: ",
            attributes: [
                .foregroundColor: UIColor.darkText,
                .font: UIFont.systemFont(ofSize: 14, weight: .regular)
            ]
        ))
        attributedSummary.append(NSAttributedString(
            string: String(format: "%9.2f", accountInfo.marginBalance),
            attributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)]
        ))
        attributedSummary.append(NSAttributedString(
            string: " USDT",
            attributes: [
                .foregroundColor: UIColor.darkText,
                .font: UIFont.systemFont(ofSize: 14, weight: .regular)
            ]
        ))
        
        accountSummaryLabel.attributedText = attributedSummary
    }
    
    // 处理开仓模式变更
    @objc private func showOrderTypeOptions() {
        // 创建菜单
        let actionSheet = UIAlertController(title: "选择订单类型", message: nil, preferredStyle: .actionSheet)
        
        // 添加市价单选项
        actionSheet.addAction(UIAlertAction(title: OrderType.market.rawValue, style: .default) { [weak self] _ in
            self?.currentOrderType = .market
            self?.orderTypeButton.setTitle(OrderType.market.rawValue, for: .normal)
        })
        
        // 添加限价单选项
        actionSheet.addAction(UIAlertAction(title: OrderType.limit.rawValue, style: .default) { [weak self] _ in
            self?.currentOrderType = .limit
            self?.orderTypeButton.setTitle(OrderType.limit.rawValue, for: .normal)
        })
        
        // 添加取消选项
        actionSheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        
        // 在iPad上的处理
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = orderTypeButton
            popoverController.sourceRect = orderTypeButton.bounds
        }
        
        // 显示菜单
        present(actionSheet, animated: true, completion: nil)
    }
    
    // 更新订单UI
    private func updateOrderUI() {
        switch currentOrderType {
        case .market:
            priceTextField.isHidden = true
            bestPriceButton.isHidden = true
        case .limit:
            priceTextField.isHidden = false
            bestPriceButton.isHidden = false
            priceTextField.placeholder = "价格"
            
            // 在限价单模式下填充当前价格
            if markPrice > 0 && (priceTextField.text?.isEmpty ?? true) {
                priceTextField.text = String(format: "%.2f", markPrice)
            }
        }
        
        // 强制重新布局，确保隐藏的视图不会占用空间
        view.layoutIfNeeded()
    }
    
    // 更新数量UI
    private func updateQuantityUI() {
        switch currentQuantityMode {
        case .amount:
            quantityPercentageSlider.isHidden = true
            percentageLabel.isHidden = true
            amountTextField.placeholder = "输入交易额"
        case .percentage:
            quantityPercentageSlider.isHidden = false
            percentageLabel.isHidden = false
            amountTextField.placeholder = "交易额"
            quantityPercentageChanged() // 触发一次计算
        }
    }
    
    // 显示交易对选择器
    @objc private func showSymbolPicker() {
        // 创建一个自定义的警告控制器，使用alert样式而不是actionSheet
        let alertController = UIAlertController(title: "选择交易对", message: nil, preferredStyle: .alert)
        
        // 添加搜索框
        alertController.addTextField { textField in
            textField.placeholder = "搜索交易对"
            textField.clearButtonMode = .whileEditing
            textField.returnKeyType = .search
            
            // 添加搜索框的值变化监听
            NotificationCenter.default.addObserver(
                forName: UITextField.textDidChangeNotification,
                object: textField,
                queue: .main) { [weak self] _ in
                    guard let self = self, let searchText = textField.text?.uppercased() else { return }
                    self.updateSymbolList(alertController: alertController, searchText: searchText)
                }
        }
        
        // 初始化交易对列表
        updateSymbolList(alertController: alertController, searchText: "")
        
        // 添加取消按钮
        let cancelAction = UIAlertAction(title: "取消", style: .cancel) { _ in
            // 移除通知观察者
            NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: alertController.textFields?.first)
        }
        alertController.addAction(cancelAction)
        
        // 显示选择器
        present(alertController, animated: true, completion: nil)
    }
    
    // 更新交易对列表（基于搜索条件）
    private func updateSymbolList(alertController: UIAlertController, searchText: String) {
        // 移除之前的所有交易对选项（除了最后一个取消按钮）
        if alertController.actions.count > 1 {
            // 因为无法直接修改actions数组，我们需要重新创建一个数组
            // 保存最后一个取消按钮
            let cancelAction = alertController.actions.last!
            
            // 移除所有action
            for action in alertController.actions {
                if action != cancelAction {
                    action.isEnabled = false
                    alertController.dismiss(animated: false)
                }
            }
            
            // 创建新的警告控制器
            let newAlertController = UIAlertController(title: "选择交易对", message: nil, preferredStyle: .alert)
            
            // 添加原来的搜索框
            if let textField = alertController.textFields?.first {
                newAlertController.addTextField { newTextField in
                    newTextField.text = textField.text
                    newTextField.placeholder = textField.placeholder
                    newTextField.clearButtonMode = textField.clearButtonMode
                    newTextField.returnKeyType = textField.returnKeyType
                    
                    // 添加搜索框的值变化监听
                    NotificationCenter.default.addObserver(
                        forName: UITextField.textDidChangeNotification,
                        object: newTextField,
                        queue: .main) { [weak self] _ in
                            guard let self = self, let searchText = newTextField.text?.uppercased() else { return }
                            self.updateSymbolList(alertController: newAlertController, searchText: searchText)
                        }
                }
            }
            
            // 过滤交易对列表
            let filteredSymbols = searchText.isEmpty ? 
                availableSymbols : 
                availableSymbols.filter { $0.uppercased().contains(searchText) }
            
            // 限制显示的交易对数量，防止列表过长
            let maxSymbolsToShow = 15
            let symbolsToShow = filteredSymbols.count > maxSymbolsToShow ? 
                Array(filteredSymbols.prefix(maxSymbolsToShow)) : 
                filteredSymbols
            
            // 添加过滤后的交易对选项
            for symbol in symbolsToShow {
                let action = UIAlertAction(title: symbol, style: .default) { [weak self] _ in
                    self?.currentSymbol = symbol
                    self?.symbolLabel.text = symbol
                    self?.refreshData() // 切换交易对后刷新数据
                    
                    // 移除通知观察者
                    NotificationCenter.default.removeObserver(self!, name: UITextField.textDidChangeNotification, object: newAlertController.textFields?.first)
                }
                newAlertController.addAction(action)
            }
            
            // 如果搜索结果被限制，添加提示信息
            if filteredSymbols.count > maxSymbolsToShow {
                let infoAction = UIAlertAction(title: "搜索到 \(filteredSymbols.count) 个结果，显示前 \(maxSymbolsToShow) 个", style: .default, handler: nil)
                infoAction.isEnabled = false
                newAlertController.addAction(infoAction)
            }
            
            // 如果没有搜索结果，添加提示信息
            if filteredSymbols.isEmpty {
                let noResultAction = UIAlertAction(title: "没有找到匹配的交易对", style: .default, handler: nil)
                noResultAction.isEnabled = false
                newAlertController.addAction(noResultAction)
            }
            
            // 添加取消按钮
            newAlertController.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                // 移除通知观察者
                NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: newAlertController.textFields?.first)
            })
            
            // 关闭原来的警告框，显示新的警告框
            alertController.dismiss(animated: false) {
                self.present(newAlertController, animated: false, completion: nil)
            }
            
            return
        }
        
        // 过滤交易对列表
        let filteredSymbols = searchText.isEmpty ? 
            availableSymbols : 
            availableSymbols.filter { $0.uppercased().contains(searchText) }
        
        // 限制显示的交易对数量，防止列表过长
        let maxSymbolsToShow = 15
        let symbolsToShow = filteredSymbols.count > maxSymbolsToShow ? 
            Array(filteredSymbols.prefix(maxSymbolsToShow)) : 
            filteredSymbols
        
        // 添加过滤后的交易对选项
        for symbol in symbolsToShow {
            let action = UIAlertAction(title: symbol, style: .default) { [weak self] _ in
                self?.currentSymbol = symbol
                self?.symbolLabel.text = symbol
                self?.refreshData() // 切换交易对后刷新数据
                
                // 移除通知观察者
                NotificationCenter.default.removeObserver(self!, name: UITextField.textDidChangeNotification, object: alertController.textFields?.first)
            }
            alertController.addAction(action)
        }
        
        // 如果搜索结果被限制，添加提示信息
        if filteredSymbols.count > maxSymbolsToShow {
            let infoAction = UIAlertAction(title: "搜索到 \(filteredSymbols.count) 个结果，显示前 \(maxSymbolsToShow) 个", style: .default, handler: nil)
            infoAction.isEnabled = false
            alertController.addAction(infoAction)
        }
        
        // 如果没有搜索结果，添加提示信息
        if filteredSymbols.isEmpty {
            let noResultAction = UIAlertAction(title: "没有找到匹配的交易对", style: .default, handler: nil)
            noResultAction.isEnabled = false
            alertController.addAction(noResultAction)
        }
    }
    
    private func setLeverage(_ leverage: Int) {
        BinanceAPIService.shared.setLeverage(symbol: currentSymbol, leverage: leverage) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("设置杠杆成功")
                    self?.refreshAccountData()
                case .failure(let error):
                    print("设置杠杆失败: \(error.localizedDescription)")
                    
                    // 在失败时显示Toast提示
                    var style = ToastStyle()
                    style.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
                    style.messageColor = .white
                    style.messageFont = UIFont.systemFont(ofSize: 14)
                    style.messageAlignment = .center
                    style.messageNumberOfLines = 0
                    style.cornerRadius = 8
                    style.displayShadow = true
                    
                    self?.view.makeToast("杠杆设置失败: \(error.localizedDescription)", 
                                        duration: 2.0, 
                                        position: .center, 
                                        style: style)
                }
            }
        }
    }
    
    // 显示加载指示器
    private func showLoadingIndicator() {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.tag = 999
        activityIndicator.startAnimating()
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
    }
    
    // 隐藏加载指示器
    private func hideLoadingIndicator() {
        if let activityIndicator = view.viewWithTag(999) as? UIActivityIndicatorView {
            activityIndicator.stopAnimating()
            activityIndicator.removeFromSuperview()
        }
    }
    

    private func closePosition(position: SimplifiedPosition) {
        // 显示加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        // 确定平仓方向和数量
        let isLong = position.isLong
        // 平仓方向与持仓方向相反
        let side: OrderSide = isLong ? .sell : .buy
        // 平仓数量为持仓数量的绝对值
        let quantity = abs(position.positionAmount)
        
        // 构建订单参数
        let orderParams = FuturesOrderParams(
            symbol: position.symbol,
            side: side,
            positionSide: isLong ? .long : .short,
            type: .market,
            timeInForce: nil,
            quantity: quantity,
            price: nil,
            reduceOnly: nil,  // 移除reduceOnly参数
            newClientOrderId: nil,
            stopPrice: nil,
            closePosition: true,  // 使用closePosition=true标记这是平仓操作
            activationPrice: nil,
            callbackRate: nil,
            workingType: nil,
            newOrderRespType: nil
        )
        
        // 发送平仓订单
        BinanceAPIService.shared.createFuturesOrder(params: orderParams) { [weak self] result in
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                
                switch result {
                case .success(let order):
                    self?.showAlert(title: "平仓成功", message: "订单ID: \(order.orderId)")
                    self?.refreshData()
                case .failure(let error):
                    self?.showAlert(title: "平仓失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    // 取消所有委托订单
    private func cancelAllOrders() {
        guard !currentOrders.isEmpty else { return }
        
        // 显示加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        // 获取当前交易对
        let symbol = currentSymbol
        
        // 调用API取消所有委托
        BinanceAPIService.shared.cancelAllFuturesOrders(symbol: symbol) { [weak self] result in
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                
                switch result {
                case .success(_):
                    self?.showAlert(title: "成功", message: "所有委托订单已取消")
                    self?.currentOrders.removeAll()
                    self?.positionsTableView.reloadData()
                case .failure(let error):
                    self?.showAlert(title: "取消失败", message: error.localizedDescription)
                }
                
                // 刷新数据
                self?.refreshData()
            }
        }
    }
    
    // 获取当前委托订单
    private func getCurrentOrders() {
        BinanceAPIService.shared.getFuturesOpenOrders { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let orders):
                    self?.currentOrders = orders
                case .failure(let error):
                    print("获取当前委托订单失败: \(error.localizedDescription)")
                    self?.currentOrders = []
                    if self?.currentViewMode == .orders {
                        self?.showAlert(title: "错误", message: "获取委托订单失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // 获取当前持仓模式
    private func getPositionMode() {
        BinanceAPIService.shared.getPositionMode { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if let dualSidePosition = response["dualSidePosition"] as? Bool {
                        self?.isDualSidePositionMode = dualSidePosition
                        self?.updatePositionModeButton()
                    }
                case .failure(let error):
                    print("获取持仓模式失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 更新持仓模式按钮状态
    private func updatePositionModeButton() {
        if isDualSidePositionMode {
            positionModeButton.setTitle("双向持仓模式", for: .normal)
            positionModeButton.backgroundColor = .systemBlue
        } else {
            positionModeButton.setTitle("单向持仓模式", for: .normal)
            positionModeButton.backgroundColor = .systemPurple
        }
    }
    
    // 双向持仓模式按钮点击事件
    @objc private func positionModeButtonTapped() {
        let newMode = !isDualSidePositionMode
        let alertController = UIAlertController(
            title: "确认更改持仓模式",
            message: "您确定要切换到\(newMode ? "双向" : "单向")持仓模式吗？\n注意：更改持仓模式前必须先平掉所有仓位。",
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "确认更改", style: .destructive) { [weak self] _ in
            self?.changeDualSidePosition(dualSidePosition: newMode)
        })
        
        present(alertController, animated: true, completion: nil)
    }
    
    // 设置双向持仓模式
    private func changeDualSidePosition(dualSidePosition: Bool) {
        // 显示加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        BinanceAPIService.shared.changeDualSidePosition(dualSidePosition: dualSidePosition) { [weak self] result in
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                
                switch result {
                case .success(_):
                    self?.isDualSidePositionMode = dualSidePosition
                    self?.updatePositionModeButton()
                    self?.showAlert(title: "设置成功", message: "已切换到\(dualSidePosition ? "双向" : "单向")持仓模式")
                    
                    // 刷新数据
                    self?.refreshData()
                case .failure(let error):
                    let errorMessage = error.localizedDescription
                    var message = "设置失败: \(errorMessage)"
                    
                    // 检查是否有未平仓的持仓
                    if errorMessage.contains("4046") || errorMessage.contains("position") {
                        message = "请先平掉所有持仓再切换持仓模式"
                    }
                    
                    self?.showAlert(title: "设置失败", message: message)
                }
            }
        }
    }
    
    // 获取交易对的价格精度
    private func getSymbolPricePrecision(symbol: String) -> Int {
        // 查找当前交易对的价格精度
        if let symbolInfo = availableSymbols.first(where: { $0.hasPrefix(symbol) }) {
            // 默认值
            return 2
        }
        
        // 不同交易对的默认精度
        if symbol.contains("BTC") {
            return 1 // BTC通常是1位小数
        } else if symbol.contains("ETH") {
            return 2 // ETH通常是2位小数
        } else {
            return 2 // 其他默认2位小数
        }
    }
    
    private func submitOrder(side: OrderSide) {
        // 显示加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.tag = 999
        activityIndicator.startAnimating()
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        
        // 验证输入
        guard let amountText = amountTextField.text, !amountText.isEmpty,
              let usdtAmount = Double(amountText), usdtAmount > 0 else {
            activityIndicator.stopAnimating()
            activityIndicator.removeFromSuperview()
            showAlert(title: "输入错误", message: "请输入有效的交易额")
            return
        }
        
        // 检查可用保证金
        guard let accountInfo = simplifiedAccountInfo else {
            activityIndicator.stopAnimating()
            activityIndicator.removeFromSuperview()
            showAlert(title: "错误", message: "无法获取账户信息")
            return
        }
        
        // 获取杠杆倍数
        let leverage = Int(leverageSlider.value)
        
        // 检查交易金额是否超过可用余额乘以杠杆倍数(最大可用)
        let maxTradingAmount = accountInfo.availableBalance * Double(leverage)
        if usdtAmount > maxTradingAmount {
            activityIndicator.stopAnimating()
            activityIndicator.removeFromSuperview()
            showAlert(title: "金额超限", message: "交易额超过最大可用额度\n最大可用: \(String(format: "%.2f", maxTradingAmount)) USDT\n可用余额: \(String(format: "%.2f", accountInfo.availableBalance)) USDT\n杠杆倍数: \(leverage)x")
            return
        }
        
        // 检查价格输入
        var orderPrice: Double = 0
        if currentOrderType == .limit {
            guard let priceText = priceTextField.text, !priceText.isEmpty,
                  let price = Double(priceText), price > 0 else {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                showAlert(title: "输入错误", message: "请输入有效的价格")
                return
            }
            orderPrice = price
        } else {
            // 市价单使用当前价格
            orderPrice = markPrice
        }
        
        // 验证杠杆设置
        guard leverage > 0 else {
            activityIndicator.stopAnimating()
            activityIndicator.removeFromSuperview()
            showAlert(title: "输入错误", message: "请设置有效的杠杆倍数")
            return
        }
        
        // 计算资产数量 = USDT金额 / 价格 (不再乘以杠杆，因为输入的USDT金额已经包含杠杆因素)
        var quantity = usdtAmount / orderPrice
        
        // 获取交易对设置的小数位数
        let symbol = currentSymbol
        var decimalPlaces = 3 // 默认3位小数
        
        if symbol.contains("BTC") {
            decimalPlaces = 3
        } else if symbol.contains("ETH") {
            decimalPlaces = 3
        } else if symbol.contains("SOL") {
            decimalPlaces = 1
        } else {
            decimalPlaces = 0
        }
        
        // 格式化数量，确保不超过交易所允许的精度
        let formattedQuantity = quantity.rounded(toPlaces: decimalPlaces)
        quantity = formattedQuantity
        
        // 确保订单金额超过5 USDT的最低要求
        let orderValue = quantity * orderPrice
        if orderValue < 5.0 {
            activityIndicator.stopAnimating()
            activityIndicator.removeFromSuperview()
            showAlert(title: "交易额过小", message: "交易额必须大于5 USDT")
            return
        }
        
        // 获取价格精度并确保价格符合精度要求
        let pricePrecision = getSymbolPricePrecision(symbol: symbol)
        let formattedPrice = orderPrice.rounded(toPlaces: pricePrecision)
        
        // 币安实际计算的订单价值 = 数量 × 价格
        let actualOrderValue = formattedQuantity * formattedPrice
        
        // 打印详细信息帮助调试
        print("======== 下单详情 ========")
        print("交易对: \(symbol)")
        print("方向: \(side.rawValue)")
        print("数量模式: \(currentQuantityMode.rawValue)")
        print("订单类型: \(currentOrderType.rawValue)")
        print("输入的交易额: \(usdtAmount)")
        print("杠杆倍数: \(leverage)x")
        print("原始计算数量: \(quantity)")
        print("格式化后数量: \(formattedQuantity)")
        print("原始价格: \(orderPrice)")
        print("格式化后价格: \(formattedPrice)")
        print("预计交易额: \(orderValue) USDT")
        print("币安实际交易额: \(actualOrderValue) USDT")
        print("差异: \(actualOrderValue - orderValue) USDT")
        print("双向持仓模式: \(isDualSidePositionMode)")
        print("===========================")
        
        // 创建订单前提示用户实际金额
        let alertController = UIAlertController(
            title: "确认下单",
            message: "交易额: \(String(format: "%.2f", actualOrderValue)) USDT\n数量: \(String(format: "%.8f", formattedQuantity))\n价格: \(String(format: "%.2f", formattedPrice))",
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
            activityIndicator.stopAnimating()
            activityIndicator.removeFromSuperview()
        })
        
        alertController.addAction(UIAlertAction(title: "确认下单", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            // 根据持仓模式确定positionSide
            var positionSide: PositionSide? = nil
            if self.isDualSidePositionMode {
                // 双向持仓模式下，需要指定持仓方向
                positionSide = side == .buy ? .long : .short
            }
            
            // 获取订单参数
            let params = OpenPositionParams(
                symbol: symbol,
                side: side,
                orderType: self.currentOrderType == .market ? .market : .limit,
                quantity: formattedQuantity,
                price: self.currentOrderType == .market ? nil : formattedPrice, // 使用格式化后的价格
                stopPrice: nil,
                leverage: leverage,
                reduceOnly: nil,
                isIsolated: false,
                positionSide: positionSide
            )
            
            // 调用API创建订单
            BinanceAPIService.shared.openPosition(params: params) { [weak self] result in
                DispatchQueue.main.async {
                    activityIndicator.stopAnimating()
                    activityIndicator.removeFromSuperview()
                    
                    switch result {
                    case .success(let orderResponse):
                        self?.showAlert(title: "开仓成功", message: "订单ID: \(orderResponse.orderId)\n交易额: \(String(format: "%.2f", actualOrderValue)) USDT")
                        self?.refreshData()
                    case .failure(let error):
                        // 检查价格错误响应
                        if let nsError = error as? NSError, nsError.code == -4014 {
                            // 如果是价格精度错误，提供更详细的提示
                            self?.showAlert(title: "价格错误", 
                                            message: "请确保价格符合交易所的精度要求。\n对于\(symbol)，请使用\(pricePrecision)位小数。\n当前市场价格为: \(String(format: "%.\(pricePrecision)f", self?.markPrice ?? 0))")
                        } else {
                            self?.showAlert(title: "开仓失败", message: error.localizedDescription)
                        }
                    }
                }
            }
        })
        
        present(alertController, animated: true)
    }
    
    // 处理搜索选择
    private func selectSymbol(_ symbol: String) {
        // 更新当前选择的交易对
        currentSymbol = symbol
        symbolLabel.text = symbol
        
        // 刷新数据
        refreshData()
        
        // 清除搜索框
        navigationItem.searchController?.isActive = false
        navigationItem.searchController?.searchBar.text = ""
    }
    
    // 初始化交易对
    private func initializeSymbols() {
        // 初始化订单类型为限价单
        currentOrderType = .limit
        orderTypeButton.setTitle(OrderType.limit.rawValue, for: .normal)
        
        // 确保默认使用交易API
        BinanceAPIService.shared.switchAPIConfig(isReadOnly: false)
        
        // 强制设置为双向持仓模式
        isDualSidePositionMode = true
        
        // 设置WebSocket价格更新回调
        BinanceAPIService.shared.priceUpdateHandler = { [weak self] (symbol, price) in
            guard let self = self, symbol == self.currentSymbol else { return }
            
            // 只有价格变化超过一定阈值才更新UI
            let priceChange = abs(self.markPrice - price)
            let percentChange = self.markPrice > 0 ? (priceChange / self.markPrice) * 100 : 0
            
            // 更新内部价格值
            self.markPrice = price
            
            // 更新价格标签 - 无论变化多少都更新
            DispatchQueue.main.async {
                self.priceLabel.text = "价格: \(String(format: "%.2f", price)) USDT"
            }
            
            // 只有价格变化超过0.05%或者5秒没更新时才刷新持仓
            if percentChange > 0.05 || self.lastPositionUpdateTime.timeIntervalSinceNow < -5 {
                DispatchQueue.main.async {
                    // 更新所有持仓的未实现盈亏
                    self.updatePositionProfits()
                    self.lastPositionUpdateTime = Date()
                }
            }
        }
        
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        scrollView.refreshControl = refreshControl
        
        // 获取所有可用交易对
        loadAvailableSymbols()
        
        // 设置定时刷新
        setupRefreshTimer()
        
        // 显示加载提示
        showLoadingIndicator()
        
        // 延迟1秒后刷新数据，避免刚启动应用时网络不稳定
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.refreshData()
        }
    }
    
    // 创建搜索结果表格视图
    private func createSearchResultsTableView() {
        // 如果已经存在，先移除
        searchResultsTableView?.removeFromSuperview()
        
        // 创建表格视图
        let tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SymbolCell")
        tableView.backgroundColor = .systemBackground
        tableView.layer.cornerRadius = 8
        tableView.layer.borderWidth = 1
        tableView.layer.borderColor = UIColor.systemGray4.cgColor
        tableView.layer.shadowColor = UIColor.black.cgColor
        tableView.layer.shadowOffset = CGSize(width: 0, height: 2)
        tableView.layer.shadowRadius = 4
        tableView.layer.shadowOpacity = 0.2
        
        // 添加到视图
        view.addSubview(tableView)
        
        // 设置约束
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56), // 导航栏下方
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            tableView.heightAnchor.constraint(lessThanOrEqualToConstant: 300) // 最大高度
        ])
        
        searchResultsTableView = tableView
        searchResultsTableView?.isHidden = true
    }
    
    // 显示或隐藏搜索结果
    private func showSearchResults(_ show: Bool) {
        // 如果需要显示但表格视图不存在，先创建
        if show && searchResultsTableView == nil {
            createSearchResultsTableView()
        }
        
        searchResultsVisible = show
        searchResultsTableView?.isHidden = !show
        
        // 如果显示搜索结果，让其显示在最上层
        if show {
            view.bringSubviewToFront(searchResultsTableView!)
        }
    }
}

// MARK: - UISearchResultsUpdating
extension FuturesTradeViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text?.uppercased(), !searchText.isEmpty else {
            filteredSymbols = []
            showSearchResults(false)
            return
        }
        
        // 过滤符合搜索条件的交易对
        filteredSymbols = availableSymbols.filter { $0.uppercased().contains(searchText) }
        
        // 根据搜索结果决定是否显示结果表格
        showSearchResults(!filteredSymbols.isEmpty)
        
        // 刷新搜索结果表格
        searchResultsTableView?.reloadData()
    }
}

// MARK: - 搜索结果表格视图相关
extension FuturesTradeViewController {
    // 搜索结果表格视图数据源
    func numberOfRowsInSearchTable() -> Int {
        return filteredSymbols.count
    }
    
    func cellForRowInSearchTable(at indexPath: IndexPath) -> UITableViewCell {
        guard let tableView = searchResultsTableView else {
            return UITableViewCell()
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "SymbolCell", for: indexPath)
        let symbol = filteredSymbols[indexPath.row]
        
        // 配置单元格
        var content = cell.defaultContentConfiguration()
        content.text = symbol
        cell.contentConfiguration = content
        
        // 高亮当前选中的交易对
        if symbol == currentSymbol {
            cell.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            content.textProperties.color = .systemBlue
            cell.contentConfiguration = content
        } else {
            cell.backgroundColor = .systemBackground
        }
        
        return cell
    }
    
    func didSelectRowInSearchTable(at indexPath: IndexPath) {
        guard indexPath.row < filteredSymbols.count else { return }
        
        let selectedSymbol = filteredSymbols[indexPath.row]
        selectSymbol(selectedSymbol)
        searchResultsTableView?.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - UITableViewDataSource 扩展用于搜索结果表格
extension FuturesTradeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // 区分是搜索结果表格还是原有表格
        if tableView == searchResultsTableView {
            return numberOfRowsInSearchTable()
        }
        
        // 原有逻辑
        switch currentViewMode {
        case .positions:
            // 持仓模式
            return simplifiedPositions.isEmpty ? 1 : simplifiedPositions.count
        case .orders:
            // 委托模式
            return currentOrders.isEmpty ? 1 : currentOrders.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 处理搜索结果表格
        if tableView == searchResultsTableView {
            return cellForRowInSearchTable(at: indexPath)
        }
        
        // 原有逻辑
        let cell = tableView.dequeueReusableCell(withIdentifier: PositionTableViewCell.identifier, for: indexPath) as! PositionTableViewCell
        
        switch currentViewMode {
        case .positions:
            // 持仓模式
            if simplifiedPositions.isEmpty {
                cell.configureEmpty(message: "暂无持仓")
                return cell
            }
            
            let position = simplifiedPositions[indexPath.row]
            cell.configure(with: position)
            
        case .orders:
            // 委托模式
            if currentOrders.isEmpty {
                cell.configureEmpty(message: "暂无委托")
                return cell
            }
            
            let order = currentOrders[indexPath.row]
            cell.configureOrder(with: order)
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate 扩展用于搜索结果表格
extension FuturesTradeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 处理搜索结果表格的选择
        if tableView == searchResultsTableView {
            didSelectRowInSearchTable(at: indexPath)
            return
        }
        
        // 原有逻辑
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch currentViewMode {
        case .positions:
            // 持仓操作
            if !simplifiedPositions.isEmpty {
                let position = simplifiedPositions[indexPath.row]
                selectedPosition = PositionInfo(position: position)
                
                let alertController = UIAlertController(
                    title: "持仓操作",
                    message: "选择要执行的操作 - \(position.symbol) (\(position.isLong ? "多" : "空")仓)",
                    preferredStyle: .actionSheet
                )
                
                // 平仓操作
                alertController.addAction(UIAlertAction(title: "平仓", style: .destructive) { [weak self] _ in
                    self?.closePosition(position: position)
                })
                
                // 调整杠杆操作
                alertController.addAction(UIAlertAction(title: "调整杠杆", style: .default) { [weak self] _ in
                    self?.showAdjustLeverageDialog(for: position)
                })
                
                // 设置止盈止损操作
                alertController.addAction(UIAlertAction(title: "设置止盈止损", style: .default) { [weak self] _ in
                    self?.showTPSLDialog(for: position)
                })
                
                alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
                
                present(alertController, animated: true, completion: nil)
            }
            
        case .orders:
            // 委托操作
            if !currentOrders.isEmpty {
                let order = currentOrders[indexPath.row]
                
                let alertController = UIAlertController(
                    title: "委托操作",
                    message: "订单ID: \(order.orderId)\n交易对: \(order.symbol)",
                    preferredStyle: .actionSheet
                )
                
                // 取消订单操作
                alertController.addAction(UIAlertAction(title: "取消订单", style: .destructive) { [weak self] _ in
                    self?.cancelOrder(orderId: order.orderId, symbol: order.symbol)
                })
                
                alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
                
                present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    // 取消订单
    private func cancelOrder(orderId: Int64, symbol: String) {
        // 显示加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        BinanceAPIService.shared.cancelFuturesOrder(symbol: symbol, orderId: orderId) { [weak self] result in
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                
                switch result {
                case .success:
                    self?.showAlert(title: "成功", message: "订单已取消")
                    // 刷新委托列表
                    self?.getCurrentOrders()
                case .failure(let error):
                    self?.showAlert(title: "取消失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAdjustLeverageDialog(for position: SimplifiedPosition) {
        let alertController = UIAlertController(
            title: "调整杠杆",
            message: "\(position.symbol) (\(position.isLong ? "多" : "空")仓)\n当前杠杆: \(position.leverage)倍",
            preferredStyle: .alert
        )
        
        // 添加杠杆输入框
        alertController.addTextField { textField in
            textField.placeholder = "新杠杆倍数 (1-125)"
            textField.keyboardType = .numberPad
            textField.text = "\(position.leverage)"
        }
        
        // 确认按钮
        alertController.addAction(UIAlertAction(title: "设置", style: .default) { [weak self, weak alertController] _ in
            guard let leverageText = alertController?.textFields?.first?.text,
                  let leverage = Int(leverageText),
                  leverage >= 1, leverage <= 125 else {
                self?.showAlert(title: "错误", message: "请输入1-125之间的有效杠杆倍数")
                return
            }
            
            // 更新杠杆
            self?.updatePositionLeverage(symbol: position.symbol, leverage: leverage)
        })
        
        // 取消按钮
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        
        present(alertController, animated: true, completion: nil)
    }
    
    // 更新持仓杠杆
    private func updatePositionLeverage(symbol: String, leverage: Int) {
        // 显示加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        // 调用API更新杠杆
        BinanceAPIService.shared.updatePositionLeverage(symbol: symbol, leverage: leverage) { [weak self] result in
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                
                switch result {
                case .success(_):
                    self?.showAlert(title: "更新成功", message: "持仓杠杆已调整为\(leverage)倍")
                    self?.refreshData()
                case .failure(let error):
                    self?.showAlert(title: "更新失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    // 设置止盈止损对话框
    private func showTPSLDialog(for position: SimplifiedPosition) {
        let alertController = UIAlertController(
            title: "设置止盈止损",
            message: "\(position.symbol) (\(position.isLong ? "多" : "空")仓)",
            preferredStyle: .alert
        )
        
        // 当前价格信息
        alertController.message = alertController.message! + "\n当前价格: \(String(format: "%.2f", position.markPrice))\n开仓价格: \(String(format: "%.2f", position.entryPrice))"
        
        // 添加止盈价输入框
        alertController.addTextField { textField in
            textField.placeholder = "止盈价格"
            textField.keyboardType = .decimalPad
            textField.tag = 1
        }
        
        // 添加止损价输入框
        alertController.addTextField { textField in
            textField.placeholder = "止损价格"
            textField.keyboardType = .decimalPad
            textField.tag = 2
        }
        
        // 确认按钮
        alertController.addAction(UIAlertAction(title: "设置", style: .default) { [weak self, weak alertController] _ in
            guard let alertController = alertController,
                  let tpTextField = alertController.textFields?.first(where: { $0.tag == 1 }),
                  let slTextField = alertController.textFields?.first(where: { $0.tag == 2 }) else {
                return
            }
            
            // 解析输入的价格
            let takeProfitPrice = Double(tpTextField.text ?? "")
            let stopLossPrice = Double(slTextField.text ?? "")
            
            // 确保至少有一个价格有效
            guard takeProfitPrice != nil || stopLossPrice != nil else {
                self?.showAlert(title: "错误", message: "请至少设置一个有效的止盈或止损价格")
                return
            }
            
            // 创建参数
            let params = TPSLParams(
                symbol: position.symbol,
                positionSide: position.isLong ? .long : .short,
                takeProfitPrice: takeProfitPrice,
                stopLossPrice: stopLossPrice,
                quantity: abs(position.positionAmount)
            )
            
            // 设置止盈止损
            self?.setTPSL(params: params)
        })
        
        // 取消按钮
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        
        present(alertController, animated: true, completion: nil)
    }
    
    // 设置止盈止损
    private func setTPSL(params: TPSLParams) {
        // 显示加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        // 调用API设置止盈止损
        BinanceAPIService.shared.setTPSL(params: params) { [weak self] result in
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                
                switch result {
                case .success(_):
                    self?.showAlert(title: "设置成功", message: "止盈止损订单已创建")
                    self?.refreshData()
                case .failure(let error):
                    self?.showAlert(title: "设置失败", message: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - 自定义持仓单元格
class PositionTableViewCell: UITableViewCell {
    
    static let identifier = "PositionTableViewCell"
    
    let symbolLabel = UILabel()
    let typeLabel = UILabel()
    let leverageLabel = UILabel()
    let amountLabel = UILabel()
    let priceInfoLabel = UILabel()
    let profitLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        symbolLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        symbolLabel.textAlignment = .left
        
        typeLabel.font = UIFont.systemFont(ofSize: 14)
        typeLabel.textAlignment = .center
        typeLabel.layer.cornerRadius = 4
        typeLabel.clipsToBounds = true
        
        leverageLabel.font = UIFont.systemFont(ofSize: 13)
        leverageLabel.textAlignment = .right
        
        amountLabel.font = UIFont.systemFont(ofSize: 14)
        amountLabel.textAlignment = .right
        
        priceInfoLabel.font = UIFont.systemFont(ofSize: 13)
        priceInfoLabel.textColor = .darkGray
        priceInfoLabel.numberOfLines = 0
        
        profitLabel.font = UIFont.systemFont(ofSize: 14)
        profitLabel.textAlignment = .left
        profitLabel.textColor = .black
        
        contentView.addSubview(symbolLabel)
        contentView.addSubview(typeLabel)
        contentView.addSubview(leverageLabel)
        contentView.addSubview(amountLabel)
        contentView.addSubview(priceInfoLabel)
        contentView.addSubview(profitLabel)
        
        // 使用SnapKit设置约束
        symbolLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.left.equalToSuperview().offset(16)
        }
        
        typeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(symbolLabel)
            make.left.equalTo(symbolLabel.snp.right).offset(8)
            // 不再固定宽度，而是设置内部边距，让其自适应
            make.height.equalTo(24)
        }
        
        leverageLabel.snp.makeConstraints { make in
            make.centerY.equalTo(symbolLabel)
            make.right.equalToSuperview().offset(-16)
        }
        
        amountLabel.snp.makeConstraints { make in
            make.top.equalTo(symbolLabel.snp.bottom).offset(8)
            make.right.equalTo(leverageLabel)
        }
        
        priceInfoLabel.snp.makeConstraints { make in
            make.top.equalTo(symbolLabel.snp.bottom).offset(8)
            make.left.equalTo(symbolLabel)
            make.right.equalTo(amountLabel.snp.left).offset(-10)
        }
        
        profitLabel.snp.makeConstraints { make in
            make.top.equalTo(priceInfoLabel.snp.bottom).offset(6)
            make.left.equalTo(priceInfoLabel)
            make.bottom.equalToSuperview().offset(-10)
        }
    }
    
    // 配置持仓信息
    func configure(with position: SimplifiedPosition) {
        symbolLabel.text = position.symbol
        
        if position.isLong {
            typeLabel.text = "多头"
            typeLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.2)
            typeLabel.textColor = .systemGreen
        } else {
            typeLabel.text = "空头"
            typeLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.2)
            typeLabel.textColor = .systemRed
        }
        
        // 设置内部边距，使文本不贴边
        typeLabel.layoutMargins = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        
        leverageLabel.text = "\(position.leverage)X"
        
        let positionValue = position.positionValue
        amountLabel.text = String(format: "%.2f USDT", positionValue)
        
        // 创建富文本显示持仓信息
        let infoText = NSMutableAttributedString()
        infoText.append(NSAttributedString(string: "开仓价: \(String(format: "%.2f", position.entryPrice))"))
        infoText.append(NSAttributedString(string: "\n标记价: \(String(format: "%.2f", position.markPrice))"))
        
        priceInfoLabel.attributedText = infoText
        
        // 显示盈亏信息
        let profit = position.unrealizedProfit
        let profitPercentage = position.profitPercentage
        
        let profitSign = profit >= 0 ? "+" : ""
        let profitText = String(format: "%@%.2f USDT (%.2f%%)", profitSign, profit, profitPercentage)
        
        profitLabel.text = profitText
        profitLabel.textColor = profit >= 0 ? .systemGreen : .systemRed
        profitLabel.isHidden = false
        
    }
    
    // 配置没有持仓的显示
    func configureEmpty(message: String) {
        symbolLabel.text = ""
        typeLabel.text = ""
        typeLabel.backgroundColor = .clear
        leverageLabel.text = ""
        amountLabel.text = ""
        priceInfoLabel.text = ""
        profitLabel.text = message
        profitLabel.textColor = .lightGray
        profitLabel.textAlignment = .center
    }
    
    // 配置订单状态
    func configureOrder(with order: FuturesOrderResponse) {
        symbolLabel.text = order.symbol
        
        // 设置订单方向
        let side = order.side
        let sideText: String
        if side == "BUY" {
            sideText = "买入"
            typeLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.2)
            typeLabel.textColor = .systemGreen
        } else {
            sideText = "卖出"
            typeLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.2)
            typeLabel.textColor = .systemRed
        }
        
        // 设置订单类型
        let orderType = order.type
        let typeDescription: String
        
        // 根据订单类型设置不同的显示文本
        switch orderType {
        case "LIMIT":
            typeDescription = "限价"
        case "MARKET":
            typeDescription = "市价"
        case "STOP":
            typeDescription = "止损限价"
        case "STOP_MARKET":
            typeDescription = "止损市价"
        case "TAKE_PROFIT":
            typeDescription = "止盈限价"
        case "TAKE_PROFIT_MARKET":
            typeDescription = "止盈市价"
        case "TRAILING_STOP_MARKET":
            typeDescription = "跟踪止损"
        default:
            typeDescription = orderType
        }
        
        // 组合方向和类型
        typeLabel.text = "\(sideText) \(typeDescription)"
        
        // 设置内部边距，使文本不贴边
        typeLabel.layoutMargins = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        
        // 使用SnapKit动态更新宽度约束
        typeLabel.snp.remakeConstraints { make in
            make.centerY.equalTo(symbolLabel)
            make.left.equalTo(symbolLabel.snp.right).offset(8)
            make.height.equalTo(24)
            // 不再设置固定宽度
        }
        
        // 设置订单状态标签
        let orderStatus = getOrderStatusText(order.status)
        leverageLabel.text = orderStatus
        
        // 计算USDT数量
        let price = Double(order.price) ?? 0
        let quantity = Double(order.origQty) ?? 0
        let usdtAmount = quantity * price
        
        // 显示USDT数量
        amountLabel.text = String(format: "%.2f USDT", usdtAmount)
        
        // 显示完整的订单信息
        let typeText = NSMutableAttributedString()
        
        // 添加价格信息
        if price > 0 {
            let formattedPrice: String
            if price >= 1000 {
                formattedPrice = String(format: "%.2f", price)
            } else if price >= 10 {
                formattedPrice = String(format: "%.4f", price)
            } else {
                formattedPrice = String(format: "%.6f", price)
            }
            typeText.append(NSAttributedString(string: "委托价: \(formattedPrice)"))
        } else {
            typeText.append(NSAttributedString(string: "委托价: 市价"))
        }
        
        // 如果是条件单，显示触发价格
        let stopPrice = Double(order.stopPrice) ?? 0
        if stopPrice > 0 {
            let formattedStopPrice: String
            if stopPrice >= 1000 {
                formattedStopPrice = String(format: "%.2f", stopPrice)
            } else if stopPrice >= 10 {
                formattedStopPrice = String(format: "%.4f", stopPrice)
            } else {
                formattedStopPrice = String(format: "%.6f", stopPrice)
            }
            typeText.append(NSAttributedString(string: "\n触发价: \(formattedStopPrice)"))
        }
        
        // 添加下单时间
        if let orderTime = order.time {
            let date = Date(timeIntervalSince1970: TimeInterval(orderTime / 1000))
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm:ss"
            let timeString = formatter.string(from: date)
            typeText.append(NSAttributedString(string: "\n时间: \(timeString)"))
        }
        
        priceInfoLabel.attributedText = typeText
        
        // 隐藏数量标签
        profitLabel.isHidden = true
    }
    
    // 辅助方法：获取订单状态的中文描述
    private func getOrderStatusText(_ status: String) -> String {
        switch status {
        case "NEW": return "未成交"
        case "PARTIALLY_FILLED": return "部分成交"
        case "FILLED": return "已成交"
        case "CANCELED": return "已取消"
        case "REJECTED": return "已拒绝"
        case "EXPIRED": return "已过期"
        default: return status
        }
    }
}

// Double扩展，添加保留指定小数位的方法
extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
