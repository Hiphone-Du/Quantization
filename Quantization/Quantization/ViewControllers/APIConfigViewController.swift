//
//  APIConfigViewController.swift
//  Quantization
//
//  Created by Claude on 2025/4/13.
//

import UIKit
import SnapKit

class APIConfigViewController: UIViewController {
    
    // API配置类型
    enum APIType: String, CaseIterable {
        case readOnly = "只读API"
        case fullAccess = "交易API"
        
        var description: String {
            switch self {
            case .readOnly:
                return "只读权限，无法交易"
            case .fullAccess:
                return "完整权限，可以交易"
            }
        }
    }
    
    // MARK: - 属性
    
    private var currentType: APIType = .fullAccess
    
    // MARK: - UI组件
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "API配置"
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textAlignment = .center
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "请输入您的币安API密钥"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let apiKeyLabel: UILabel = {
        let label = UILabel()
        label.text = "API Key:"
        label.font = UIFont.boldSystemFont(ofSize: 16)
        return label
    }()
    
    private let apiKeyTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "输入API Key"
        textField.borderStyle = .roundedRect
        textField.clearButtonMode = .whileEditing
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        return textField
    }()
    
    private let secretKeyLabel: UILabel = {
        let label = UILabel()
        label.text = "Secret Key:"
        label.font = UIFont.boldSystemFont(ofSize: 16)
        return label
    }()
    
    private let secretKeyTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "输入Secret Key"
        textField.borderStyle = .roundedRect
        textField.clearButtonMode = .whileEditing
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.isSecureTextEntry = true
        return textField
    }()
    
    private let toggleSecretButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "eye.slash"), for: .normal)
        return button
    }()
    
    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("保存", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()
    
    private let switchLabel: UILabel = {
        let label = UILabel()
        label.text = "API类型:"
        label.font = UIFont.boldSystemFont(ofSize: 16)
        return label
    }()
    
    private let typeSegmentedControl: UISegmentedControl = {
        let items = APIType.allCases.map { $0.rawValue }
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 1 // 默认选中交易API
        return control
    }()
    
    private let typeDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "完整权限，可以交易"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .systemGray
        return label
    }()
    
    private let publicIPLabel: UILabel = {
        let label = UILabel()
        label.text = "正在获取公网IP..."
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.backgroundColor = UIColor.systemGray6
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.isUserInteractionEnabled = true
        return label
    }()
    
    private let copyIPButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("复制IP", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 6
        return button
    }()
    
    // MARK: - 生命周期方法
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        title = "API配置"
        
        setupUI()
        setupActions()
        loadCurrentAPIKeys()
        getPublicIP()
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(publicIPLabel)
        view.addSubview(copyIPButton)
        view.addSubview(switchLabel)
        view.addSubview(typeSegmentedControl)
        view.addSubview(typeDescriptionLabel)
        view.addSubview(apiKeyLabel)
        view.addSubview(apiKeyTextField)
        view.addSubview(secretKeyLabel)
        view.addSubview(secretKeyTextField)
        view.addSubview(toggleSecretButton)
        view.addSubview(saveButton)
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.centerX.equalToSuperview()
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        publicIPLabel.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalTo(copyIPButton.snp.leading).offset(-10)
            make.height.equalTo(40)
        }
        
        copyIPButton.snp.makeConstraints { make in
            make.centerY.equalTo(publicIPLabel)
            make.trailing.equalToSuperview().offset(-20)
            make.width.equalTo(70)
            make.height.equalTo(36)
        }
        
        switchLabel.snp.makeConstraints { make in
            make.top.equalTo(publicIPLabel.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(20)
        }
        
        typeSegmentedControl.snp.makeConstraints { make in
            make.top.equalTo(switchLabel.snp.bottom).offset(10)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        typeDescriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(typeSegmentedControl.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        apiKeyLabel.snp.makeConstraints { make in
            make.top.equalTo(typeDescriptionLabel.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(20)
        }
        
        apiKeyTextField.snp.makeConstraints { make in
            make.top.equalTo(apiKeyLabel.snp.bottom).offset(10)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(44)
        }
        
        secretKeyLabel.snp.makeConstraints { make in
            make.top.equalTo(apiKeyTextField.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(20)
        }
        
        secretKeyTextField.snp.makeConstraints { make in
            make.top.equalTo(secretKeyLabel.snp.bottom).offset(10)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-50)
            make.height.equalTo(44)
        }
        
        toggleSecretButton.snp.makeConstraints { make in
            make.centerY.equalTo(secretKeyTextField)
            make.trailing.equalToSuperview().offset(-20)
            make.width.height.equalTo(44)
        }
        
        saveButton.snp.makeConstraints { make in
            make.top.equalTo(secretKeyTextField.snp.bottom).offset(40)
            make.centerX.equalToSuperview()
            make.width.equalTo(200)
            make.height.equalTo(50)
        }
    }
    
    private func setupActions() {
        toggleSecretButton.addTarget(self, action: #selector(toggleSecretVisibility), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        copyIPButton.addTarget(self, action: #selector(copyIPButtonTapped), for: .touchUpInside)
        typeSegmentedControl.addTarget(self, action: #selector(apiTypeChanged), for: .valueChanged)
    }
    
    // MARK: - 数据方法
    
    private func loadCurrentAPIKeys() {
        // 根据当前选择的API类型加载对应的密钥
        currentType = typeSegmentedControl.selectedSegmentIndex == 0 ? .readOnly : .fullAccess
        
        let keyPrefix = currentType == .readOnly ? "ReadOnly_" : ""
        
        if let apiKey = UserDefaults.standard.string(forKey: "\(keyPrefix)BinanceAPIKey") {
            apiKeyTextField.text = apiKey
        }
        
        if let secretKey = UserDefaults.standard.string(forKey: "\(keyPrefix)BinanceSecretKey") {
            secretKeyTextField.text = secretKey
        }
        
        updateTypeDescription()
    }
    
    private func saveAPIKeys() {
        guard let apiKey = apiKeyTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let secretKey = secretKeyTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            showAlert(title: "错误", message: "API Key和Secret Key不能为空")
            return
        }
        
        // 根据当前选择的API类型保存对应的密钥
        let keyPrefix = currentType == .readOnly ? "ReadOnly_" : ""
        
        UserDefaults.standard.set(apiKey, forKey: "\(keyPrefix)BinanceAPIKey")
        UserDefaults.standard.set(secretKey, forKey: "\(keyPrefix)BinanceSecretKey")
        
        // 如果是交易API，同时更新Constants中的值供当前使用
        if currentType == .fullAccess {
            Constants.Binance.apiKey = apiKey
            Constants.Binance.secretKey = secretKey
        }
        
        showAlert(title: "保存成功", message: "已保存\(currentType.rawValue)配置")
    }
    
    private func getPublicIP() {
        NetworkUtils.getPublicIPAddress { [weak self] publicIP in
            DispatchQueue.main.async {
                self?.publicIPLabel.text = "公网IP: " + publicIP
            }
        }
    }
    
    private func updateTypeDescription() {
        typeDescriptionLabel.text = currentType.description
    }
    
    // MARK: - 事件处理
    
    @objc private func toggleSecretVisibility() {
        secretKeyTextField.isSecureTextEntry.toggle()
        let imageName = secretKeyTextField.isSecureTextEntry ? "eye.slash" : "eye"
        toggleSecretButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
    
    @objc private func saveButtonTapped() {
        saveAPIKeys()
    }
    
    @objc private func copyIPButtonTapped() {
        if let text = publicIPLabel.text,
           let ipAddress = text.components(separatedBy: "公网IP: ").last {
            UIPasteboard.general.string = ipAddress
            
            // 显示复制成功的反馈
            let originalText = copyIPButton.titleLabel?.text
            copyIPButton.setTitle("已复制!", for: .normal)
            
            // 震动反馈
            let feedbackGenerator = UINotificationFeedbackGenerator()
            feedbackGenerator.notificationOccurred(.success)
            
            // 短暂延迟后恢复原文本
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.copyIPButton.setTitle(originalText, for: .normal)
            }
        }
    }
    
    @objc private func apiTypeChanged() {
        // 保存当前输入的内容
        let previousType = currentType
        let previousAPIKey = apiKeyTextField.text
        let previousSecretKey = secretKeyTextField.text
        
        let keyPrefix = previousType == .readOnly ? "ReadOnly_" : ""
        
        if let apiKey = previousAPIKey, !apiKey.isEmpty,
           let secretKey = previousSecretKey, !secretKey.isEmpty {
            UserDefaults.standard.set(apiKey, forKey: "\(keyPrefix)BinanceAPIKey")
            UserDefaults.standard.set(secretKey, forKey: "\(keyPrefix)BinanceSecretKey")
        }
        
        // 加载新选择的类型
        currentType = typeSegmentedControl.selectedSegmentIndex == 0 ? .readOnly : .fullAccess
        loadCurrentAPIKeys()
    }
    
    // MARK: - 辅助方法
    
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
} 

