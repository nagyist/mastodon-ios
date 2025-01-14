// Copyright © 2025 Mastodon gGmbH. All rights reserved.

import UIKit
import MastodonSDK

struct BetaTestSettingsViewModel {
    let useStagingForDonations: Bool
    let testGroupedNotifications: Bool
    
    init() {
        useStagingForDonations = UserDefaults.standard.useStagingForDonations
        testGroupedNotifications = UserDefaults.standard.useGroupedNotifications
    }
    
    func byToggling(_ setting: BetaTestSetting) -> BetaTestSettingsViewModel {
        switch setting {
        case .useStagingForDonations:
            UserDefaults.standard.toggleUseStagingForDonations()
        case .useGroupedNotifications:
            UserDefaults.standard.toggleUseGroupedNotifications()
        case .clearPreviousDonationCampaigns:
            assertionFailure("this is an action, not a setting")
            break
        }
        return BetaTestSettingsViewModel()
    }
}

enum BetaTestSettingsSectionType: Hashable {
    case donations
    case notifications
    
    var sectionTitle: String {
        switch self {
        case .donations:
            return "Donations"
        case .notifications:
            return "Notifications"
        }
    }
}

enum BetaTestSetting: Hashable {
    case useStagingForDonations
    case clearPreviousDonationCampaigns
    case useGroupedNotifications
    
    var labelText: String {
        switch self {
        case .useStagingForDonations:
            return "Donations use test endpoint"
        case .clearPreviousDonationCampaigns:
            return "Clear donation history"
        case .useGroupedNotifications:
            return "Test grouped notifications"
        }
    }
}

fileprivate typealias BasicCell = UITableViewCell
fileprivate let basicCellReuseIdentifier = "basic_cell"

class BetaTestSettingsViewController: UIViewController {
    
    let tableView: UITableView
    
    var tableViewDataSource: BetaTestSettingsDiffableTableViewDataSource?
    
    private var viewModel: BetaTestSettingsViewModel {
        didSet {
            loadFromViewModel(animated: true)
        }
    }
    
    init() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(BasicCell.self, forCellReuseIdentifier: basicCellReuseIdentifier)
        tableView.register(ToggleTableViewCell.self, forCellReuseIdentifier: ToggleTableViewCell.reuseIdentifier)
        
        viewModel = BetaTestSettingsViewModel()
        
        super.init(nibName: nil, bundle: nil)
        
        tableView.delegate = self
        
        let tableViewDataSource = BetaTestSettingsDiffableTableViewDataSource(tableView: tableView, cellProvider: { [weak self] tableView, indexPath, itemIdentifier in
            guard let self else { return nil }
            switch itemIdentifier {
            case .useStagingForDonations:
                guard let selectionCell = tableView.dequeueReusableCell(withIdentifier: ToggleTableViewCell.reuseIdentifier, for: indexPath) as? ToggleTableViewCell else { assertionFailure("unexpected cell type"); return nil }
                selectionCell.label.text = itemIdentifier.labelText
                selectionCell.toggle.isOn = self.viewModel.useStagingForDonations
                selectionCell.toggle.removeTarget(self, action: nil, for: .valueChanged)
                selectionCell.toggle.addTarget(self, action: #selector(didToggleDonationsStaging), for: .valueChanged)
                return selectionCell
            case .clearPreviousDonationCampaigns:
                let cell = tableView.dequeueReusableCell(withIdentifier: basicCellReuseIdentifier, for: indexPath)
                cell.textLabel?.text = itemIdentifier.labelText
                cell.textLabel?.textColor = .red
                return cell
            case .useGroupedNotifications:
                guard let selectionCell = tableView.dequeueReusableCell(withIdentifier: ToggleTableViewCell.reuseIdentifier, for: indexPath) as? ToggleTableViewCell else { assertionFailure("unexpected cell type"); return nil }
                selectionCell.label.text = itemIdentifier.labelText
                selectionCell.toggle.isOn = self.viewModel.testGroupedNotifications
                selectionCell.toggle.removeTarget(self, action: nil, for: .valueChanged)
                selectionCell.toggle.addTarget(self, action: #selector(didToggleGroupedNotifications), for: .valueChanged)
                return selectionCell
            }
        })
        
        tableView.dataSource = tableViewDataSource
        self.tableViewDataSource = tableViewDataSource
        
        view.backgroundColor = .systemGroupedBackground
        view.addSubview(tableView)
        tableView.pinTo(to: view)
        
        title = "Beta Test Settings"
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadFromViewModel(animated: false)
    }
    
    @objc func didToggleDonationsStaging(_ sender: UISwitch) {
        viewModel = viewModel.byToggling(.useStagingForDonations)
    }
    @objc func didToggleGroupedNotifications(_ sender: UISwitch) {
        viewModel = viewModel.byToggling(.useGroupedNotifications)
    }
    
    func loadFromViewModel(animated: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<BetaTestSettingsSectionType, BetaTestSetting>()
        snapshot.appendSections([.donations, .notifications])
        snapshot.appendItems([.useStagingForDonations], toSection: .donations)
        if viewModel.useStagingForDonations {
            snapshot.appendItems([.useStagingForDonations, .clearPreviousDonationCampaigns], toSection: .donations)
        }
        snapshot.appendItems([.useGroupedNotifications], toSection: .notifications)
        tableViewDataSource?.apply(snapshot, animatingDifferences: animated)
    }
}

extension BetaTestSettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let identifier = tableViewDataSource?.itemIdentifier(for: indexPath) else { return }
        switch identifier {
        case .useStagingForDonations, .useGroupedNotifications:
            break
        case .clearPreviousDonationCampaigns:
            Mastodon.Entity.DonationCampaign.forgetPreviousCampaigns()
            DispatchQueue.main.async {
                self.tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
}
