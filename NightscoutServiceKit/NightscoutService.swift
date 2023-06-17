//
//  NightscoutService.swift
//  NightscoutServiceKit
//
//  Created by Darin Krauss on 6/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import os.log
import HealthKit
import LoopKit
import NightscoutKit

public enum NightscoutServiceError: Error {
    case incompatibleTherapySettings
    case missingCredentials
    case missingCommandSource
}


public final class NightscoutService: Service {

    public static let serviceIdentifier = "NightscoutService"

    public static let localizedTitle = LocalizedString("Nightscout", comment: "The title of the Nightscout service")
    
    public let objectIdCacheKeepTime = TimeInterval(24 * 60 * 60)

    public weak var serviceDelegate: ServiceDelegate?

    public var siteURL: URL?

    public var apiSecret: String?
    
    public var isOnboarded: Bool

    public let otpManager: OTPManager
    
    /// Maps loop syncIdentifiers to Nightscout objectIds
    var objectIdCache: ObjectIdCache {
        get {
            return lockedObjectIdCache.value
        }
        set {
            lockedObjectIdCache.value = newValue
        }
    }
    private let lockedObjectIdCache: Locked<ObjectIdCache>

    private var _uploader: NightscoutClient?

    private var uploader: NightscoutClient? {
        if _uploader == nil {
            guard let siteURL = siteURL, let apiSecret = apiSecret else {
                return nil
            }
            _uploader = NightscoutClient(siteURL: siteURL, apiSecret: apiSecret)
        }
        return _uploader
    }
    
    private let commandSourceV1: RemoteCommandSourceV1
    private var commandSourceV2: RemoteCommandSourceV2

    private let log = OSLog(category: "NightscoutService")

    public init() {
        self.isOnboarded = false
        self.lockedObjectIdCache = Locked(ObjectIdCache())
        self.otpManager = OTPManager(secretStore: KeychainManager())
        self.commandSourceV1 = RemoteCommandSourceV1(otpManager: otpManager)
        self.commandSourceV2 = RemoteCommandSourceV2(otpManager: otpManager)
        self.commandSourceV1.delegate = self
        Task {
            await self.commandSourceV2.setDelegate(self)
        }
    }

    public required init?(rawState: RawStateValue) {
        self.isOnboarded = rawState["isOnboarded"] as? Bool ?? true   // Backwards compatibility

        if let objectIdCacheRaw = rawState["objectIdCache"] as? ObjectIdCache.RawValue,
            let objectIdCache = ObjectIdCache(rawValue: objectIdCacheRaw)
        {
            self.lockedObjectIdCache = Locked(objectIdCache)
        } else {
            self.lockedObjectIdCache = Locked(ObjectIdCache())
        }
        
        self.otpManager = OTPManager(secretStore: KeychainManager())
        self.commandSourceV1 = RemoteCommandSourceV1(otpManager: otpManager)
        self.commandSourceV2 = RemoteCommandSourceV2(otpManager: otpManager)
        self.commandSourceV1.delegate = self
        Task {
            await commandSourceV2.setDelegate(self)
        }
        
        restoreCredentials()
    }

    public var rawState: RawStateValue {
        return [
            "isOnboarded": isOnboarded,
            "objectIdCache": objectIdCache.rawValue
        ]
    }

    public var lastDosingDecisionForAutomaticDose: StoredDosingDecision?

    public var hasConfiguration: Bool { return siteURL != nil && apiSecret?.isEmpty == false }

    public func verifyConfiguration(completion: @escaping (Error?) -> Void) {
        guard hasConfiguration, let siteURL = siteURL, let apiSecret = apiSecret else {
            completion(NightscoutServiceError.missingCredentials)
            return
        }

        let uploader = NightscoutClient(siteURL: siteURL, apiSecret: apiSecret)
        uploader.checkAuth(completion)
    }

    public func completeCreate() {
        saveCredentials()
    }

    public func completeOnboard() {
        isOnboarded = true

        saveCredentials()
        serviceDelegate?.serviceDidUpdateState(self)
    }

    public func completeUpdate() {
        saveCredentials()
        serviceDelegate?.serviceDidUpdateState(self)
    }

    public func completeDelete() {
        clearCredentials()
        serviceDelegate?.serviceWantsDeletion(self)
    }

    private func saveCredentials() {
        try? KeychainManager().setNightscoutCredentials(siteURL: siteURL, apiSecret: apiSecret)
    }

    public func restoreCredentials() {
        if let credentials = try? KeychainManager().getNightscoutCredentials() {
            self.siteURL = credentials.siteURL
            self.apiSecret = credentials.apiSecret
        }
    }

    public func clearCredentials() {
        siteURL = nil
        apiSecret = nil
        try? KeychainManager().setNightscoutCredentials()
    }
    
}

extension NightscoutService: RemoteDataService {

    public func uploadTemporaryOverrideData(updated: [LoopKit.TemporaryScheduleOverride], deleted: [LoopKit.TemporaryScheduleOverride], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let uploader = uploader else {
            completion(.success(true))
            return
        }

        let updates = updated.map { OverrideTreatment(override: $0) }

        let deletions = deleted.map { $0.syncIdentifier.uuidString }

        uploader.deleteTreatmentsById(deletions, completionHandler: { (error) in
            if let error = error {
                self.log.error("Overrides deletions failed to delete %{public}@: %{public}@", String(describing: deletions), String(describing: error))
            } else {
                if deletions.count > 0 {
                    self.log.debug("Deleted ids: %@", deletions)
                }
                uploader.upload(updates) { (result) in
                    switch result {
                    case .failure(let error):
                        self.log.error("Failed to upload overrides %{public}@: %{public}@", String(describing: updates.map {$0.dictionaryRepresentation}), String(describing: error))
                        completion(.failure(error))
                    case .success:
                        self.log.debug("Uploaded overrides %@", String(describing: updates.map {$0.dictionaryRepresentation}))
                        completion(.success(true))
                    }
                }
            }
        })
    }


    public var alertDataLimit: Int? { return 1000 }

    public func uploadAlertData(_ stored: [SyncAlertObject], completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    public var carbDataLimit: Int? { return 1000 }

    public func uploadCarbData(created: [SyncCarbObject], updated: [SyncCarbObject], deleted: [SyncCarbObject], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard hasConfiguration, let uploader = uploader else {
            completion(.success(true))
            return
        }
        
        uploader.createCarbData(created) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let createdObjectIds):
                let createdUploaded = !created.isEmpty
                let syncIdentifiers = created.map { $0.syncIdentifier }
                for (syncIdentifier, objectId) in zip(syncIdentifiers, createdObjectIds) {
                    if let syncIdentifier = syncIdentifier {
                        self.objectIdCache.add(syncIdentifier: syncIdentifier, objectId: objectId)
                    }
                }
                self.serviceDelegate?.serviceDidUpdateState(self)
                
                uploader.updateCarbData(updated, usingObjectIdCache: self.objectIdCache) { result in
                    switch result {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let updatedUploaded):
                        uploader.deleteCarbData(deleted, usingObjectIdCache: self.objectIdCache) { result in
                            switch result {
                            case .failure(let error):
                                completion(.failure(error))
                            case .success(let deletedUploaded):
                                self.objectIdCache.purge(before: Date().addingTimeInterval(-self.objectIdCacheKeepTime))
                                self.serviceDelegate?.serviceDidUpdateState(self)
                                completion(.success(createdUploaded || updatedUploaded || deletedUploaded))
                            }
                        }
                    }
                }
            }
        }
    }

    public var doseDataLimit: Int? { return 1000 }

    public func uploadDoseData(created: [DoseEntry], deleted: [DoseEntry], completion: @escaping (_ result: Result<Bool, Error>) -> Void) {
        guard hasConfiguration, let uploader = uploader else {
            completion(.success(true))
            return
        }

        uploader.createDoses(created, usingObjectIdCache: self.objectIdCache) { (result) in
            switch (result) {
            case .failure(let error):
                completion(.failure(error))
            case .success(let createdObjectIds):
                let createdUploaded = !created.isEmpty
                let syncIdentifiers = created.map { $0.syncIdentifier }
                for (syncIdentifier, objectId) in zip(syncIdentifiers, createdObjectIds) {
                    if let syncIdentifier = syncIdentifier {
                        self.objectIdCache.add(syncIdentifier: syncIdentifier, objectId: objectId)
                    }
                }
                self.serviceDelegate?.serviceDidUpdateState(self)

                uploader.deleteDoses(deleted.filter { !$0.isMutable }, usingObjectIdCache: self.objectIdCache) { result in
                    switch result {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let deletedUploaded):
                        self.objectIdCache.purge(before: Date().addingTimeInterval(-self.objectIdCacheKeepTime))
                        self.serviceDelegate?.serviceDidUpdateState(self)
                        completion(.success(createdUploaded || deletedUploaded))
                    }
                }
            }
        }
    }

    public var dosingDecisionDataLimit: Int? { return 50 }  // Each can be up to 20K bytes of serialized JSON, target ~1M or less

    public func uploadDosingDecisionData(_ stored: [StoredDosingDecision], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard hasConfiguration, let uploader = uploader else {
            completion(.success(true))
            return
        }

        var uploadPairs: [(StoredDosingDecision, StoredDosingDecision?)] = []

        for decision in stored {
            switch decision.reason {
            case "loop":
                lastDosingDecisionForAutomaticDose = decision
            case "updateRemoteRecommendation", "normalBolus", "simpleBolus", "watchBolus":
                uploadPairs.append((decision, lastDosingDecisionForAutomaticDose))
            default:
                break
            }
        }

        let statuses = uploadPairs.map { (decision, automaticDoseDecision) in
            return decision.deviceStatus(automaticDoseDecision: automaticDoseDecision)
        }

        guard statuses.count > 0 else {
            completion(.success(false))
            return
        }

        uploader.uploadDeviceStatuses(statuses) { result in
            switch result {
            case .success:
                self.lastDosingDecisionForAutomaticDose = nil
            default:
                break
            }
            completion(result)
        }
    }

    public var glucoseDataLimit: Int? { return 1000 }

    public func uploadGlucoseData(_ stored: [StoredGlucoseSample], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard hasConfiguration, let uploader = uploader else {
            completion(.success(true))
            return
        }

        uploader.uploadGlucoseSamples(stored, completion: completion)
    }

    public var pumpEventDataLimit: Int? { return 1000 }

    public func uploadPumpEventData(_ stored: [PersistedPumpEvent], completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    public var settingsDataLimit: Int? { return 400 }  // Each can be up to 2.5K bytes of serialized JSON, target ~1M or less

    public func uploadSettingsData(_ stored: [StoredSettings], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard hasConfiguration, let uploader = uploader else {
            completion(.success(true))
            return
        }

        uploader.uploadProfiles(stored.compactMap { $0.profileSet }, completion: completion)
    }
    
    public func fetchStoredTherapySettings(completion: @escaping (Result<(TherapySettings,Date), Error>) -> Void) {
        guard let uploader = uploader else {
            completion(.failure(NightscoutServiceError.missingCredentials))
            return
        }

        uploader.fetchCurrentProfile(completion: { result in
            switch result {
            case .success(let profileSet):
                if let therapySettings = profileSet.therapySettings {
                    completion(.success((therapySettings,profileSet.startDate)))
                } else {
                    completion(.failure(NightscoutServiceError.incompatibleTherapySettings))
                }
                break
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
    
    public func handleRemoteNotification(_ notification: [String: AnyObject]) async throws {
        let commandSource = try commandSource(notification: notification)
        await commandSource.handleRemoteNotification(notification)
    }
    
    public func processPendingRemoteCommands() async throws {
        try await commandSourceV2.processPendingRemoteCommands()
    }
    
    private func commandSource(notification: [String: AnyObject]) throws -> RemoteCommandSource {
        
        guard let versionString = notification["version"] as? String else {
            return commandSourceV1 //fallback before versions were introduced
        }
        
        guard let version = Double(versionString) else {
            throw NightscoutServiceError.missingCommandSource
        }
        
        switch version {
        case 1.0..<2.0:
            return commandSourceV1
        case 2.0..<3.0:
            return commandSourceV2
        default:
            throw NightscoutServiceError.missingCommandSource
        }
    }

}

extension NightscoutService: RemoteCommandSourceV1Delegate {
    
    func commandSourceV1(_: RemoteCommandSourceV1, handleAction action: Action) async throws {
        
        switch action {
        case .temporaryScheduleOverride(let overrideCommand):
            try await self.serviceDelegate?.handleRemoteOverride(
                name: overrideCommand.name,
                durationTime: overrideCommand.durationTime,
                remoteAddress: overrideCommand.remoteAddress
            )
        case .cancelTemporaryOverride:
            try await self.serviceDelegate?.handleRemoteOverrideCancel()
        case .bolusEntry(let bolusCommand):
            try await self.serviceDelegate?.handleRemoteBolus(amountInUnits: bolusCommand.amountInUnits)
        case .carbsEntry(let carbCommand):
            try await self.serviceDelegate?.handleRemoteCarb(
                amountInGrams: carbCommand.amountInGrams,
                absorptionTime: carbCommand.absorptionTime,
                foodType: carbCommand.foodType,
                startDate: carbCommand.startDate
            )
        case .autobolus(let autobolusCommand):
            try await self.serviceDelegate?.handleRemoteAutobolus(activate: autobolusCommand.active)
        case .closedLoop(let closedLoopComand):
            try await self.serviceDelegate?.handleRemoteClosedLoop(activate: closedLoopComand.active)
        }
    }
    
    func commandSourceV1(_: RemoteCommandSourceV1, uploadError error: Error, notification: [String: AnyObject]) async throws {
        
        guard let uploader = self.uploader else {throw NightscoutServiceError.missingCredentials}
        var commandDescription = "Loop Remote Action Error"
        if let remoteNotification = try? notification.toRemoteNotification() {
            commandDescription = remoteNotification.toRemoteAction().description
        }
        
        let notificationJSON = try JSONSerialization.data(withJSONObject: notification)
        let notificationJSONString = String(data: notificationJSON, encoding: .utf8) ?? ""
        
        let noteBody = """
        \(error.localizedDescription)
        \(notificationJSONString)
        """

        let treatment = NightscoutTreatment(
            timestamp: Date(),
            enteredBy: commandDescription,
            notes: noteBody,
            eventType: .note
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            uploader.upload([treatment], completionHandler: { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            })
        }
    }
}

extension NightscoutService: RemoteCommandSourceV2Delegate {
    
    func commandSourceV2(_: RemoteCommandSourceV2, fetchCommandsWithStartDate startDate: Date) async throws -> [NSRemoteCommandPayload] {
        
        guard let uploader = self.uploader else {throw NightscoutServiceError.missingCredentials}
        return try await uploader.fetchRemoteCommands(earliestDate: startDate)
    }
    
    func commandSourceV2(_: RemoteCommandSourceV2, fetchPendingCommandsWithStartDate startDate: Date) async throws -> [NSRemoteCommandPayload] {
        
        guard let uploader = self.uploader else {throw NightscoutServiceError.missingCredentials}
        return try await uploader.fetchPendingRemoteCommands(earliestDate: startDate)
    }
    
    func commandSourceV2(_: RemoteCommandSourceV2, updateCommand command: NSRemoteCommandPayload, status: NSRemoteCommandStatus) async throws {
        guard let uploader = self.uploader else {throw NightscoutServiceError.missingCredentials}
        guard let id = command._id else { throw RemoteCommandPayloadError.missingID }
        let commandUpdate = NSRemoteCommandPayloadUpdate(status: status)
        let _ = try await uploader.updateRemoteCommand(commandUpdate: commandUpdate, commandID: id)
    }
    
    func commandSourceV2(_: RemoteCommandSourceV2, handleAction action: Action) async throws {
        
        switch action {
        case .temporaryScheduleOverride(let overrideCommand):
            try await self.serviceDelegate?.handleRemoteOverride(
                name: overrideCommand.name,
                durationTime: overrideCommand.durationTime,
                remoteAddress: overrideCommand.remoteAddress
            )
        case .cancelTemporaryOverride:
            try await self.serviceDelegate?.handleRemoteOverrideCancel()
        case .bolusEntry(let bolusCommand):
            try await self.serviceDelegate?.handleRemoteBolus(amountInUnits: bolusCommand.amountInUnits)
        case .carbsEntry(let carbCommand):
            try await self.serviceDelegate?.handleRemoteCarb(
                amountInGrams: carbCommand.amountInGrams,
                absorptionTime: carbCommand.absorptionTime,
                foodType: carbCommand.foodType,
                startDate: carbCommand.startDate
            )
        case .autobolus(let autobolusCommand):
            try await self.serviceDelegate?.handleRemoteAutobolus(activate: autobolusCommand.active)
        case .closedLoop(let closedLoopComand):
            try await self.serviceDelegate?.handleRemoteClosedLoop(activate: closedLoopComand.active)
        }
    }
}

extension KeychainManager {

    func setNightscoutCredentials(siteURL: URL? = nil, apiSecret: String? = nil) throws {
        let credentials: InternetCredentials?

        if let siteURL = siteURL, let apiSecret = apiSecret {
            credentials = InternetCredentials(username: NightscoutAPIAccount, password: apiSecret, url: siteURL)
        } else {
            credentials = nil
        }

        try replaceInternetCredentials(credentials, forAccount: NightscoutAPIAccount)
    }

    func getNightscoutCredentials() throws -> (siteURL: URL, apiSecret: String) {
        let credentials = try getInternetCredentials(account: NightscoutAPIAccount)

        return (siteURL: credentials.url, apiSecret: credentials.password)
    }

}

fileprivate let NightscoutAPIAccount = "NightscoutAPI"
