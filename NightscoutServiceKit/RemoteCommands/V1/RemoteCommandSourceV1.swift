//
//  RemoteCommandSourceV1.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import OSLog

class RemoteCommandSourceV1: RemoteCommandSource {
    
    weak var delegate: RemoteCommandSourceV1Delegate?
    private let otpManager: OTPManager
    private let log = OSLog(category: "Remote Command Source V1")
    private var commandValidator: RemoteCommandValidator
    private var recentNotifications = RecentNotifications()
    
    init(otpManager: OTPManager) {
        self.otpManager = otpManager
        self.commandValidator = RemoteCommandValidator(otpManager: otpManager)
    }
    
    //MARK: RemoteCommandSource
    
    func remoteNotificationWasReceived(_ notification: [String: AnyObject], serviceDelegate: ServiceDelegate) async {
        
        guard let remoteNotification = try? notification.toRemoteNotification() else {
            log.error("Remote Notification: Malformed notification payload")
            return
        }
        
        guard await !recentNotifications.contains(pushIdentifier: remoteNotification.id) else {
            // Duplicate notifications are expected after app is force killed
            // https://github.com/LoopKit/Loop/issues/2174
            return
        }

        do {
            try await recentNotifications.trackReceivedRemoteNotification(remoteNotification, rawNotification: notification)
            try commandValidator.validate(remoteNotification: remoteNotification)
            
            switch remoteNotification.toRemoteAction() {
            case .bolusEntry(let bolusCommand):
                let doseEntry = try await serviceDelegate.deliverRemoteBolus(
                    amountInUnits: bolusCommand.amountInUnits,
                    userCreatedDate: bolusCommand.userCreatedDate
                )
                var adjustmentMessage: String? = nil
                if bolusCommand.amountInUnits > doseEntry.programmedUnits {
                    let quantityFormatter = QuantityFormatter(for: .internationalUnit())
                    if let bolusAmountDescription = quantityFormatter.numberFormatter.string(from: bolusCommand.amountInUnits as NSNumber),
                       let doseAmountDescription = quantityFormatter.numberFormatter.string(from: doseEntry.programmedUnits as NSNumber){
                        adjustmentMessage = "Bolus amount was reduced from \(bolusAmountDescription) U to \(doseAmountDescription) U due to other recent treatments."
                    }
                }
                await handleEnactmentCompletion(
                    remoteNotification: remoteNotification,
                    status: .success(date: Date(), syncIdentifier: doseEntry.syncIdentifier ?? "", completionMessage: adjustmentMessage),
                    notificationJSON: notification
                )
            case .cancelTemporaryOverride:
                let cancelledOverride = try await serviceDelegate.cancelRemoteOverride()
                await handleEnactmentCompletion(
                    remoteNotification: remoteNotification,
                    status: .success(date: Date(), syncIdentifier: cancelledOverride.syncIdentifier.uuidString, completionMessage: nil),
                    notificationJSON: notification
                )
            case .carbsEntry(let carbCommand):
                let carbEntry = try await serviceDelegate.deliverRemoteCarbs(
                    amountInGrams: carbCommand.amountInGrams,
                    absorptionTime: carbCommand.absorptionTime,
                    foodType: carbCommand.foodType,
                    startDate: carbCommand.startDate,
                    userCreatedDate: carbCommand.userCreatedDate
                )
                await handleEnactmentCompletion(
                    remoteNotification: remoteNotification,
                    status: .success(date: Date(), syncIdentifier: carbEntry.syncIdentifier ?? "", completionMessage: nil),
                    notificationJSON: notification
                )
            case .temporaryScheduleOverride(let overrideCommand):
                let override = try await serviceDelegate.enactRemoteOverride(
                    name: overrideCommand.name,
                    durationTime: overrideCommand.durationTime,
                    remoteAddress: overrideCommand.remoteAddress
                )
                await handleEnactmentCompletion(
                    remoteNotification: remoteNotification,
                    status: .success(date: Date(), syncIdentifier: override.syncIdentifier.uuidString, completionMessage: nil),
                    notificationJSON: notification
                )
            }
        } catch {
            log.error("Remote Notification: %{public}@. Error: %{public}@", String(describing: notification), String(describing: error))
            await handleEnactmentCompletion(
                remoteNotification: remoteNotification,
                status: .failure(date: Date(), errorMessage: error.localizedDescription),
                notificationJSON: notification
            )
        }
    }
    
    func handleEnactmentCompletion(
        remoteNotification: RemoteNotification,
        status: RemoteNotificationStatus,
        notificationJSON: [String: AnyObject]
    ) async {
        do {
            let storedNotification = try await recentNotifications.updateStatus(status, for: remoteNotification.id)
            await uploadStoredNotification(storedNotification)
        } catch {
            log.error("Remote Notification: %{public}@. Error: %{public}@", String(describing: notificationJSON), String(describing: error))
        }
    }
    
    func uploadStoredNotification(_ storedNotification: StoredRemoteNotification) async {
        do {
            switch storedNotification.status {
            case .success(_, _, let completionMessage):
                if let completionMessage {
                    // Store adjustments as an error note to Nightscout
                    // try await self.delegate?.commandSourceV1(self, uploadError: completionMessage, receivedDate: storedNotification.receivedDate, notification: storedNotification.notificationJSON())
                }
            case .failure(_, let errorMessage):
                try await self.delegate?.commandSourceV1(self, uploadError: errorMessage, receivedDate: storedNotification.receivedDate, notification: storedNotification.notificationJSON())
            case .none:
                return
            }
            try await recentNotifications.updateUploadStatus(true, for: storedNotification.pushIdentifier)
        } catch {
            log.error("Remote Notification: %{public}@. Error: %{public}@", String(describing: storedNotification), String(describing: error))
        }
    }
    
    func notificationHistory() async -> [StoredRemoteNotification] {
        return await recentNotifications.notifications
    }
    
    /// Uploads pending notifications. Limited to a few at a time to avoid long background delays.
    func uploadPendingNotifications() async {
        guard let mostRecentPendingNotification = await notificationHistory().filter({$0.isPendingUpload}).sorted(by: {$0.receivedDate > $1.receivedDate}).last else {
            return
        }
        await uploadStoredNotification(mostRecentPendingNotification)
    }
    
    func notificationPublisher() async -> AsyncStream<[StoredRemoteNotification]> {
        return await recentNotifications.notificationPublisher()
    }
    
    func deleteNotificationHistory() {
        Task {
            await recentNotifications.deleteNotificationHistory()
        }
    }
}

protocol RemoteCommandSourceV1Delegate: AnyObject {
    func commandSourceV1(_: RemoteCommandSourceV1, uploadError errorMessage: String, receivedDate: Date, notification: [String: AnyObject]) async throws
}

// MARK: Notification history

public class StoredRemoteNotification: NSObject, Codable {
    public let remoteNotificationType: RemoteNotificationType
    public let notificationJSONData: Data
    public var status: RemoteNotificationStatus? = nil
    public var receivedDate: Date
    public var uploaded: Bool = false
    
    init(notificationType: RemoteNotificationType, notificationJSONData: Data) {
        self.remoteNotificationType = notificationType
        self.notificationJSONData = notificationJSONData
        self.receivedDate = Date()
        self.uploaded = false
    }
    
    convenience init(bolusNotification: BolusRemoteNotification, notificationJSONData: Data) {
        self.init(notificationType: .bolus(bolusNotification), notificationJSONData: notificationJSONData)
    }
    
    convenience init(carbNotification: CarbRemoteNotification, notificationJSONData: Data) {
        self.init(notificationType: .carbs(carbNotification), notificationJSONData: notificationJSONData)
    }
    
    convenience init(overrideNotification: OverrideRemoteNotification, notificationJSONData: Data) {
        self.init(notificationType: .override(overrideNotification), notificationJSONData: notificationJSONData)
    }
    
    convenience init(overrideCancelNotification: OverrideCancelRemoteNotification, notificationJSONData: Data) {
        self.init(notificationType: .overrideCancel(overrideCancelNotification), notificationJSONData: notificationJSONData)
    }
    
    public var pushIdentifier: String {
        return remoteNotification().id
    }
    
    var isPendingUpload: Bool {
        guard !uploaded else {
            return false
        }
        switch status {
        case .success, .failure:
            return true
        case nil:
            return false
        }
    }
    
    func containsDose(_ dose: DoseEntry) -> Bool {
        guard case let .bolus(bolusNotification) = remoteNotificationType else {
            return false
        }
        
        if case let .success(_, syncIdentifier: syncIdentifier, _) = status {
            return dose.syncIdentifier == syncIdentifier
        }
        
        // If sync identifier not set yet, that could mean either a failure occurred
        // or we are in the middle of processing this notification.
        // Doses start uploading during remote bolus action,
        // before syncIdentifier is set to StoredRemoteAction.
        // Heuristics are used to match the dose.
        guard isDateWithinEnactmentPeriod(dose.startDate) else {
            return false
        }
        
        return dose.programmedUnits <= bolusNotification.amount
    }
    
    func isDateWithinEnactmentPeriod(_ date: Date) -> Bool {
        guard date.isAfterOrEqual(otherDate: receivedDate) else {
            return false
        }
        
        guard let completionDate else {
            // Either enactment is in progress or there was an app crash during enactment
            // For the corner case of an app crash, we want only want to match if the
            // received date is within a few minutes. It should be within seconds really
            // but minutes help when paused in the Xcode debugger.
            return date.timeIntervalSince(receivedDate) < 60 * 5
        }
        
        guard date.isBeforeOrEqual(otherDate: completionDate) else {
            return false
        }
        
        return true
    }
    
    var completionDate: Date? {
        guard let status else {
            return nil
        }
        switch status {
        case .success(let completionDate, _, _):
            return completionDate
        case .failure(let completionDate, _):
            return completionDate
        }
    }
    
    func remoteNotification() -> RemoteNotification {
        switch remoteNotificationType {
            case let .bolus(bolusNotification):
            return bolusNotification
        case let .carbs(carbNotification):
            return carbNotification
        case let .override(overrideNotification):
            return overrideNotification
        case let .overrideCancel(overrideCancelNotification):
            return overrideCancelNotification
        }
    }
    
    public func remoteAction() -> Action {
        return remoteNotification().toRemoteAction()
    }
    
    func notificationJSON() throws -> [String: AnyObject] {
        let jsonObject = try JSONSerialization.jsonObject(with: notificationJSONData, options: [])
        guard let notificationJSON = jsonObject as? [String: AnyObject] else {
            throw StoredRemoteNotificationError.notificationJSONTypeIncorrect
        }
        return notificationJSON
    }
    
    enum StoredRemoteNotificationError: Error {
        case notificationJSONTypeIncorrect
    }
    
    public enum RemoteNotificationType: Codable {
        case bolus(BolusRemoteNotification)
        case carbs(CarbRemoteNotification)
        case override(OverrideRemoteNotification)
        case overrideCancel(OverrideCancelRemoteNotification)
    }
}

public enum RemoteNotificationStatus: Codable, Equatable {
    case success(date: Date, syncIdentifier: String, completionMessage: String?)
    case failure(date: Date, errorMessage: String)
}

actor RecentNotifications {
    var notifications: [StoredRemoteNotification] = []
    private var continuation: AsyncStream<[StoredRemoteNotification]>.Continuation?
    
    init() {
        Task {
            await loadNotifications()
        }
    }
    
    // Publish
    
    func notificationPublisher() -> AsyncStream<[StoredRemoteNotification]> {
        return AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(notifications)
        }
    }
    
    private func publish(notifications: [StoredRemoteNotification]) {
        self.notifications = notifications
        continuation?.yield(notifications)
    }
    
    // Misc
    
    func contains(pushIdentifier: String) -> Bool {
        return storedNotification(for: pushIdentifier) != nil
    }
    
    func storedNotification(for id: String) -> StoredRemoteNotification? {
        return notifications.first(where: {$0.pushIdentifier == id})
    }
    
    func trackReceivedRemoteNotification(_ remoteNotification: RemoteNotification, rawNotification: [String : AnyObject]) throws {
        let data = try JSONSerialization.data(withJSONObject: rawNotification, options: [])
        if let bolusNotification = remoteNotification as? BolusRemoteNotification {
            let storedNotification = StoredRemoteNotification(bolusNotification: bolusNotification, notificationJSONData: data)
            try storeNotification(storedNotification)
        } else if let carbNotification = remoteNotification as? CarbRemoteNotification {
            let storedNotification = StoredRemoteNotification(carbNotification: carbNotification, notificationJSONData: data)
            try storeNotification(storedNotification)
        } else if let overrideNotification = remoteNotification as? OverrideRemoteNotification {
            let storedNotification = StoredRemoteNotification(overrideNotification: overrideNotification, notificationJSONData: data)
            try storeNotification(storedNotification)
        } else if let overrideCancelNotification = remoteNotification as? OverrideCancelRemoteNotification {
            let storedNotification = StoredRemoteNotification(overrideCancelNotification: overrideCancelNotification, notificationJSONData: data)
            try storeNotification(storedNotification)
        } else {
            fatalError()
        }
    }
    
    func updateStatus(_ status: RemoteNotificationStatus, for pushIdentifier: String) throws -> StoredRemoteNotification {
        guard let storedNotification = storedNotification(for: pushIdentifier) else {
            throw RemoteNotificationError.notificationNotFound(pushIdentifier)
        }
        storedNotification.status = status
        try storeNotification(storedNotification)
        return storedNotification
    }
    
    func updateUploadStatus(_ uploaded: Bool, for pushIdentifier: String) throws {
        guard let storedNotification = storedNotification(for: pushIdentifier) else {
            throw RemoteNotificationError.notificationNotFound(pushIdentifier)
        }
        
        storedNotification.uploaded = uploaded
        try storeNotification(storedNotification)
    }
    
    func storeNotification(_ storedNotification: StoredRemoteNotification) throws {
        var updatedNotifications = notifications
        if let index = updatedNotifications.firstIndex(where: {$0.pushIdentifier == storedNotification.pushIdentifier}) {
            updatedNotifications.remove(at: index)
            updatedNotifications.insert(storedNotification, at: index)
        } else {
            updatedNotifications.append(storedNotification)
        }
        
        let maxCountToStore = 50
        if updatedNotifications.count > maxCountToStore {
            updatedNotifications = Array(updatedNotifications.dropFirst(updatedNotifications.count - maxCountToStore))
        }
        
        try storeNotifications(updatedNotifications)
    }
    
    func deleteNotificationHistory() {
        do {
            try storeNotifications([])
        } catch {
            print(error)
        }
    }
    
    // Disk Operations
    
    private func loadNotifications() {
        do {
            let notifications = try notificationsFromDisk()
            publish(notifications: notifications)
        } catch {
            print("Error decoding JSON - will delete history: \(error)")
            // Error in history - deleting
            deleteNotificationHistory()
        }
    }
    
    private func notificationsFromDisk() throws -> [StoredRemoteNotification] {
        let data = try Data(contentsOf: remoteHistoryJSONURL)
        return try JSONDecoder().decode([StoredRemoteNotification].self, from: data)
    }
    
    private func storeNotifications(_ notifications: [StoredRemoteNotification]) throws {
        let notificationJSON = try JSONEncoder().encode(notifications)
        try notificationJSON.write(to: remoteHistoryJSONURL)
        publish(notifications: notifications)
    }
    
    private var remoteHistoryJSONURL: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!.appendingPathComponent("remote_notifications.json")
    }
}

enum RemoteNotificationError: LocalizedError {
    case unhandledNotification([String: AnyObject])
    case notificationNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .unhandledNotification(let notification):
            return String(format: NSLocalizedString("Unhandled Notification: %1$@", comment: "The prefix for the remote unhandled notification error. (1: notification payload)"), notification)
        case .notificationNotFound(let notificationID):
            return String(format: NSLocalizedString("Notification Not Found: %1$@", comment: "The remote notification not found error. (1: notification ID)"), notificationID)
        }
    }
}

extension Date {
    func isBeforeOrEqual(otherDate: Date) -> Bool {
        return timeIntervalSince(otherDate) <= 0
    }
    
    func isAfterOrEqual(otherDate: Date) -> Bool {
        return timeIntervalSince(otherDate) >= 0
    }
}
