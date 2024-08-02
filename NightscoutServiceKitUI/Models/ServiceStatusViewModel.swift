//
//  ServiceStatusViewModel.swift
//  NightscoutServiceKitUI
//
//  Created by Pete Schwamb on 10/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

import NightscoutServiceKit
import LoopKit

protocol ServiceStatusViewModelDelegate {
    func verifyConfiguration(completion: @escaping (Error?) -> Void)
    func notificationHistory() async -> [StoredRemoteNotification]
    func notificationPublisher() async -> AsyncStream<[StoredRemoteNotification]>
    func deleteNotificationHistory()
    var siteURL: URL? { get }
}

enum ServiceStatus {
    case checking
    case normalOperation
    case error(Error)
}

extension ServiceStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .checking:
            return LocalizedString("Checking...", comment: "Description of ServiceStatus of checking")
        case .normalOperation:
            return LocalizedString("OK", comment: "Description of ServiceStatus of checking")
        case .error(let error):
            return error.localizedDescription
        }
    }
}

class ServiceStatusViewModel: ObservableObject {
    @Published var status: ServiceStatus = .checking
    @Published var notificationHistory = [StoredRemoteNotification]()
    @Published var remoteCommands = [RemoteCommand]()
    let delegate: ServiceStatusViewModelDelegate
    var didLogout: (() -> Void)?
    
    var urlString: String {
        return delegate.siteURL?.absoluteString ?? LocalizedString("Not Available", comment: "Error when nightscout service url is not set")
    }

    init(delegate: ServiceStatusViewModelDelegate) {
        self.delegate = delegate
        listenForNotifications(from: delegate)
        
        Task {
            do {
                let notifications = await delegate.notificationHistory()
                await updateNotifications(with: notifications)
            }
        }
        
        delegate.verifyConfiguration { (error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.status = .error(error)
                } else {
                    self.status = .normalOperation
                }
            }
        }
    }
    
    func deleteNotificationHistory() {
        delegate.deleteNotificationHistory()
    }
    
    func listenForNotifications(from delegate: ServiceStatusViewModelDelegate) {
        Task {
            let notificationsStream = await delegate.notificationPublisher()
            for await notifications in notificationsStream {
                await updateNotifications(with: notifications)
            }
        }
    }
    
    @MainActor
    func updateNotifications(with notifications: [StoredRemoteNotification]) {
        remoteCommands = notifications.map({.init(notification: $0)})
            .sorted { (lhs: RemoteCommand, rhs: RemoteCommand) in
                return lhs.receivedDate > rhs.receivedDate
            }
    }
}

struct RemoteCommand: Equatable, Hashable {
    let id: String
    let receivedDate: Date
    let actionName: String
    let createdDateDescription: String
    let details: String
    let statusMessage: String
    let isError: Bool
    
    init(notification: StoredRemoteNotification) {
        self.id = notification.pushIdentifier
        self.receivedDate = notification.receivedDate
        self.actionName = notification.actionName
        self.createdDateDescription = notification.createdDateDescription
        self.details = notification.details
        self.statusMessage = notification.statusMessage
        self.isError = notification.isError
    }
}

extension StoredRemoteNotification {
    
    var actionName: String {
        switch remoteAction() {
        case .bolusEntry:
            return "Bolus"
        case .carbsEntry:
            return "Carbs"
        case .cancelTemporaryOverride:
            return "Cancel Override"
        case .temporaryScheduleOverride:
            return "Override"
        }
    }
    
    var createdDateDescription: String {
        return receivedDate.formatted(.dateTime)
    }
    
    var details: String {
        switch remoteAction() {
        case .bolusEntry(let bolusEntry):
            return "\(bolusEntry.amountInUnits.formatted()) U"
        case .carbsEntry(let carbAction):
            return "\(carbAction.amountInGrams.formatted()) G"
        case .cancelTemporaryOverride:
            return ""
        case .temporaryScheduleOverride(let override):
            return override.name
        }
    }
    
    var statusMessage: String {
        guard let status else {
            return ""
        }
        switch status {
        case .success(_, _, let completionMessage):
            return completionMessage ?? ""
        case .failure(_, let errorMessage):
            return errorMessage
        }
    }
    
    var isError: Bool {
        guard let status else {
            return false
        }
        switch status {
        case .success:
            return false
        case .failure:
            return true
        }
    }
}
