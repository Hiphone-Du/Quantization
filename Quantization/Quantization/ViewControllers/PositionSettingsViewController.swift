//
//  PositionSettingsViewController.swift
//  Quantization
//
//  Created by Claude on 2025/4/20.
//

import UIKit
import SnapKit

class PositionSettingsViewController: UIViewController {
    
    // MARK: - 属性
    
    private var positions: [SimplifiedPosition] = []
    private var savedSettings: [String: PositionSetting] = [:]
    
    // MARK: - UI组件
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.register(PositionSettingCell.self, forCellReuseIdentifier: "PositionSettingCell")
        tableView.backgroundColor = .systemBackground
        return tableView
    }()
    
    private let noPositionsLabel: UILabel = {
        let label = UILabel()
        label.text = "当前没有持仓，请先在合约交易页面开仓"
        label.textAlignment = .center
        label.textColor = .systemGray
        label.font = UIFont.systemFont(ofSize: 16)
        label.isHidden = true
        return label
    }()
    
    // MARK: - 生命周期方法
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "持仓设置"
        view.backgroundColor = .systemBackground
        
        setupUI()
        setupTableView()
        loadSavedSettings()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadPositions()
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        view.addSubview(tableView)
        view.addSubview(noPositionsLabel)
        
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        noPositionsLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(20)
        }
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
    }
    
    // MARK: - 数据加载
    
    private func loadPositions() {
        // 获取当前持仓信息
        BinanceAPIService.shared.getFuturesPositions { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let positions):
                    // 过滤有持仓的记录
                    let activePositions = positions.filter { Double($0.positionAmt) != 0 }
                    
                    // 转换为简化版持仓信息
                    self.positions = activePositions.map { SimplifiedPosition.fromFuturesPosition($0) }
                    
                    // 更新UI
                    self.updateUI()
                    
                case .failure(let error):
                    print("获取持仓信息失败: \(error.localizedDescription)")
                    self.showAlert(title: "错误", message: "获取持仓信息失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadSavedSettings() {
        // 从UserDefaults加载保存的持仓设置
        if let data = UserDefaults.standard.data(forKey: "positionSettings"),
           let settings = try? JSONDecoder().decode([String: PositionSetting].self, from: data) {
            self.savedSettings = settings
        }
    }
    
    private func saveSettings() {
        // 将持仓设置保存到UserDefaults
        if let data = try? JSONEncoder().encode(savedSettings) {
            UserDefaults.standard.set(data, forKey: "positionSettings")
        }
    }
    
    // MARK: - UI更新
    
    private func updateUI() {
        tableView.reloadData()
        noPositionsLabel.isHidden = !positions.isEmpty
        tableView.isHidden = positions.isEmpty
    }
    
    // MARK: - 辅助方法
    
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    // 获取特定持仓的设置，如果没有则创建默认设置
    private func getSettingsForPosition(_ position: SimplifiedPosition) -> PositionSetting {
        let key = "\(position.symbol)_\(position.isLong ? "LONG" : "SHORT")"
        
        if let existingSettings = savedSettings[key] {
            return existingSettings
        } else {
            // 创建默认设置
            let defaultSetting = PositionSetting(
                symbol: position.symbol,
                isLong: position.isLong,
                takeProfitPercentage: 5.0, // 默认5%止盈
                stopLossPercentage: 5.0,   // 默认5%止损
                trailingStopEnabled: false,
                trailingStopActivationPercentage: 1.0,
                trailingStopCallbackPercentage: 0.5
            )
            
            savedSettings[key] = defaultSetting
            return defaultSetting
        }
    }
    
    // 更新持仓设置
    private func updateSettings(for position: SimplifiedPosition, setting: PositionSetting) {
        let key = "\(position.symbol)_\(position.isLong ? "LONG" : "SHORT")"
        savedSettings[key] = setting
        saveSettings()
    }
}

// MARK: - UITableViewDataSource
extension PositionSettingsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return positions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PositionSettingCell", for: indexPath) as? PositionSettingCell else {
            return UITableViewCell()
        }
        
        let position = positions[indexPath.row]
        let settings = getSettingsForPosition(position)
        
        cell.configure(with: position, settings: settings)
        cell.delegate = self
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension PositionSettingsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let position = positions[indexPath.row]
        let settings = getSettingsForPosition(position)
        
        // 显示设置编辑对话框
        showSettingsDialog(for: position, currentSettings: settings)
    }
    
    private func showSettingsDialog(for position: SimplifiedPosition, currentSettings: PositionSetting) {
        let alertController = UIAlertController(
            title: "设置 \(position.symbol) (\(position.isLong ? "多" : "空")仓)",
            message: "设置止盈止损参数",
            preferredStyle: .alert
        )
        
        // 添加止盈百分比输入框
        alertController.addTextField { textField in
            textField.placeholder = "止盈百分比 (例如: 5.0)"
            textField.keyboardType = .decimalPad
            textField.text = "\(currentSettings.takeProfitPercentage)"
            textField.tag = 1
        }
        
        // 添加止损百分比输入框
        alertController.addTextField { textField in
            textField.placeholder = "止损百分比 (例如: 5.0)"
            textField.keyboardType = .decimalPad
            textField.text = "\(currentSettings.stopLossPercentage)"
            textField.tag = 2
        }
        
        // 确认按钮
        alertController.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let self = self,
                  let tpTextField = alertController.textFields?.first(where: { $0.tag == 1 }),
                  let slTextField = alertController.textFields?.first(where: { $0.tag == 2 }),
                  let tpPercentage = Double(tpTextField.text ?? ""),
                  let slPercentage = Double(slTextField.text ?? "") else {
                return
            }
            
            // 创建新的设置
            var updatedSettings = currentSettings
            updatedSettings.takeProfitPercentage = tpPercentage
            updatedSettings.stopLossPercentage = slPercentage
            
            // 保存设置
            self.updateSettings(for: position, setting: updatedSettings)
            
            // 刷新UI
            self.tableView.reloadData()
            
            // 应用设置到Binance
            self.applySettings(position: position, settings: updatedSettings)
        })
        
        // 取消按钮
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        
        present(alertController, animated: true, completion: nil)
    }
    
    private func applySettings(position: SimplifiedPosition, settings: PositionSetting) {
        // 计算止盈止损价格
        let entryPrice = position.entryPrice
        let takeProfitPrice: Double
        let stopLossPrice: Double
        
        if position.isLong {
            // 多仓: 止盈价格 = 入场价 * (1 + 止盈百分比/100)
            takeProfitPrice = entryPrice * (1 + settings.takeProfitPercentage / 100)
            // 多仓: 止损价格 = 入场价 * (1 - 止损百分比/100)
            stopLossPrice = entryPrice * (1 - settings.stopLossPercentage / 100)
        } else {
            // 空仓: 止盈价格 = 入场价 * (1 - 止盈百分比/100)
            takeProfitPrice = entryPrice * (1 - settings.takeProfitPercentage / 100)
            // 空仓: 止损价格 = 入场价 * (1 + 止损百分比/100)
            stopLossPrice = entryPrice * (1 + settings.stopLossPercentage / 100)
        }
        
        // 创建TPSL参数
        let params = TPSLParams(
            symbol: position.symbol,
            positionSide: position.isLong ? .long : .short,
            takeProfitPrice: takeProfitPrice,
            stopLossPrice: stopLossPrice,
            quantity: abs(position.positionAmount)
        )
        
        // 调用API设置止盈止损
        BinanceAPIService.shared.setTPSL(params: params) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    self?.showAlert(title: "设置成功", message: "止盈止损订单已创建")
                case .failure(let error):
                    self?.showAlert(title: "设置失败", message: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - PositionSettingCellDelegate
extension PositionSettingsViewController: PositionSettingCellDelegate {
    func didTapApplyButton(for position: SimplifiedPosition, settings: PositionSetting) {
        applySettings(position: position, settings: settings)
    }
    
    func didUpdateSettings(for position: SimplifiedPosition, settings: PositionSetting) {
        updateSettings(for: position, setting: settings)
    }
}

// MARK: - 持仓设置模型
struct PositionSetting: Codable {
    let symbol: String
    let isLong: Bool
    var takeProfitPercentage: Double
    var stopLossPercentage: Double
    var trailingStopEnabled: Bool
    var trailingStopActivationPercentage: Double
    var trailingStopCallbackPercentage: Double
}

// MARK: - 持仓设置单元格
protocol PositionSettingCellDelegate: AnyObject {
    func didTapApplyButton(for position: SimplifiedPosition, settings: PositionSetting)
    func didUpdateSettings(for position: SimplifiedPosition, settings: PositionSetting)
}

class PositionSettingCell: UITableViewCell {
    
    weak var delegate: PositionSettingCellDelegate?
    private var position: SimplifiedPosition?
    private var settings: PositionSetting?
    
    // UI组件
    private let symbolLabel = UILabel()
    private let directionLabel = UILabel()
    private let entryPriceLabel = UILabel()
    private let markPriceLabel = UILabel()
    private let profitLabel = UILabel()
    
    private let takeProfitLabel = UILabel()
    private let takeProfitSlider = UISlider()
    private let takeProfitValueLabel = UILabel()
    
    private let stopLossLabel = UILabel()
    private let stopLossSlider = UISlider()
    private let stopLossValueLabel = UILabel()
    
    private let applyButton = UIButton(type: .system)
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        
        // 设置标签样式
        symbolLabel.font = UIFont.boldSystemFont(ofSize: 16)
        directionLabel.font = UIFont.systemFont(ofSize: 14)
        directionLabel.textAlignment = .center
        directionLabel.layer.cornerRadius = 4
        directionLabel.layer.masksToBounds = true
        
        entryPriceLabel.font = UIFont.systemFont(ofSize: 14)
        markPriceLabel.font = UIFont.systemFont(ofSize: 14)
        profitLabel.font = UIFont.systemFont(ofSize: 14)
        
        takeProfitLabel.text = "止盈设置"
        takeProfitLabel.font = UIFont.systemFont(ofSize: 14)
        takeProfitValueLabel.font = UIFont.systemFont(ofSize: 14)
        takeProfitValueLabel.textAlignment = .right
        
        stopLossLabel.text = "止损设置"
        stopLossLabel.font = UIFont.systemFont(ofSize: 14)
        stopLossValueLabel.font = UIFont.systemFont(ofSize: 14)
        stopLossValueLabel.textAlignment = .right
        
        // 配置滑块
        takeProfitSlider.minimumValue = 0.1
        takeProfitSlider.maximumValue = 50
        takeProfitSlider.addTarget(self, action: #selector(takeProfitSliderChanged), for: .valueChanged)
        
        stopLossSlider.minimumValue = 0.1
        stopLossSlider.maximumValue = 50
        stopLossSlider.addTarget(self, action: #selector(stopLossSliderChanged), for: .valueChanged)
        
        // 配置应用按钮
        applyButton.setTitle("应用设置", for: .normal)
        applyButton.backgroundColor = .systemBlue
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.layer.cornerRadius = 5
        applyButton.addTarget(self, action: #selector(applyButtonTapped), for: .touchUpInside)
        
        // 添加组件到视图层次
        contentView.addSubview(symbolLabel)
        contentView.addSubview(directionLabel)
        contentView.addSubview(entryPriceLabel)
        contentView.addSubview(markPriceLabel)
        contentView.addSubview(profitLabel)
        
        contentView.addSubview(takeProfitLabel)
        contentView.addSubview(takeProfitSlider)
        contentView.addSubview(takeProfitValueLabel)
        
        contentView.addSubview(stopLossLabel)
        contentView.addSubview(stopLossSlider)
        contentView.addSubview(stopLossValueLabel)
        
        contentView.addSubview(applyButton)
        
        // 设置约束
        symbolLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(16)
        }
        
        directionLabel.snp.makeConstraints { make in
            make.centerY.equalTo(symbolLabel)
            make.leading.equalTo(symbolLabel.snp.trailing).offset(8)
            make.width.equalTo(40)
            make.height.equalTo(24)
        }
        
        entryPriceLabel.snp.makeConstraints { make in
            make.top.equalTo(symbolLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(16)
        }
        
        markPriceLabel.snp.makeConstraints { make in
            make.top.equalTo(entryPriceLabel)
            make.leading.equalTo(entryPriceLabel.snp.trailing).offset(16)
        }
        
        profitLabel.snp.makeConstraints { make in
            make.top.equalTo(entryPriceLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        takeProfitLabel.snp.makeConstraints { make in
            make.top.equalTo(profitLabel.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(16)
        }
        
        takeProfitValueLabel.snp.makeConstraints { make in
            make.centerY.equalTo(takeProfitLabel)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        takeProfitSlider.snp.makeConstraints { make in
            make.top.equalTo(takeProfitLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        stopLossLabel.snp.makeConstraints { make in
            make.top.equalTo(takeProfitSlider.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(16)
        }
        
        stopLossValueLabel.snp.makeConstraints { make in
            make.centerY.equalTo(stopLossLabel)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        stopLossSlider.snp.makeConstraints { make in
            make.top.equalTo(stopLossLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        applyButton.snp.makeConstraints { make in
            make.top.equalTo(stopLossSlider.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.width.equalTo(120)
            make.height.equalTo(36)
            make.bottom.equalToSuperview().offset(-12)
        }
    }
    
    func configure(with position: SimplifiedPosition, settings: PositionSetting) {
        self.position = position
        self.settings = settings
        
        // 设置基本信息
        symbolLabel.text = position.symbol
        
        if position.isLong {
            directionLabel.text = "多"
            directionLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.2)
            directionLabel.textColor = .systemGreen
        } else {
            directionLabel.text = "空"
            directionLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.2)
            directionLabel.textColor = .systemRed
        }
        
        entryPriceLabel.text = "开仓价: \(String(format: "%.2f", position.entryPrice))"
        markPriceLabel.text = "现价: \(String(format: "%.2f", position.markPrice))"
        
        // 设置盈亏信息
        let profit = position.unrealizedProfit
        let profitPercentage = position.profitPercentage
        let profitColor: UIColor = profit >= 0 ? .systemGreen : .systemRed
        profitLabel.text = "盈亏: \(String(format: profit >= 0 ? "+%.2f" : "%.2f", profit)) USDT (\(String(format: profitPercentage >= 0 ? "+%.2f%%" : "%.2f%%", profitPercentage)))"
        profitLabel.textColor = profitColor
        
        // 设置止盈止损滑块
        takeProfitSlider.value = Float(settings.takeProfitPercentage)
        stopLossSlider.value = Float(settings.stopLossPercentage)
        
        updateTakeProfitValueLabel()
        updateStopLossValueLabel()
    }
    
    @objc private func takeProfitSliderChanged() {
        if var settings = settings {
            settings.takeProfitPercentage = Double(takeProfitSlider.value)
            self.settings = settings
            updateTakeProfitValueLabel()
            
            // 通知代理更新设置
            if let position = position {
                delegate?.didUpdateSettings(for: position, settings: settings)
            }
        }
    }
    
    @objc private func stopLossSliderChanged() {
        if var settings = settings {
            settings.stopLossPercentage = Double(stopLossSlider.value)
            self.settings = settings
            updateStopLossValueLabel()
            
            // 通知代理更新设置
            if let position = position {
                delegate?.didUpdateSettings(for: position, settings: settings)
            }
        }
    }
    
    @objc private func applyButtonTapped() {
        if let position = position, let settings = settings {
            delegate?.didTapApplyButton(for: position, settings: settings)
        }
    }
    
    private func updateTakeProfitValueLabel() {
        if let settings = settings {
            takeProfitValueLabel.text = "\(String(format: "%.1f", settings.takeProfitPercentage))%"
        }
    }
    
    private func updateStopLossValueLabel() {
        if let settings = settings {
            stopLossValueLabel.text = "\(String(format: "%.1f", settings.stopLossPercentage))%"
        }
    }
} 