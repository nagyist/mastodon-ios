//
//  AppContext.swift
//  
//
//  Created by MainasuK on 22/9/30.
//

import UIKit
import SwiftUI
import Combine
import CoreData
import CoreDataStack
import AlamofireImage

@MainActor
public class PersistenceManager {
    public static let shared = { PersistenceManager() }()
    private let coreDataStack: CoreDataStack
    public let mainActorManagedObjectContext: NSManagedObjectContext
    public let backgroundManagedObjectContext: NSManagedObjectContext
    
    private var disposeBag = Set<AnyCancellable>()
    
    private init() {
        let _coreDataStack = CoreDataStack()
        let _managedObjectContext = _coreDataStack.persistentContainer.viewContext
        let _backgroundManagedObjectContext = _coreDataStack.persistentContainer.newBackgroundContext()
        
        coreDataStack = _coreDataStack
        mainActorManagedObjectContext = _managedObjectContext
        backgroundManagedObjectContext = _backgroundManagedObjectContext
        
        backgroundManagedObjectContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: backgroundManagedObjectContext)
            .sink { [weak self] notification in
                guard let self = self else { return }
                self.mainActorManagedObjectContext.perform {
                    self.mainActorManagedObjectContext.mergeChanges(fromContextDidSave: notification)
                }
            }
            .store(in: &disposeBag)
    }
    
    func newTaskContext() -> NSManagedObjectContext {
        return coreDataStack.newTaskContext()
    }
}

@MainActor
public class AppContext: ObservableObject {
    public static let shared = { AppContext() }()
    
    public var disposeBag = Set<AnyCancellable>()

    public let placeholderImageCacheService = PlaceholderImageCacheService()
    public let blurhashImageCacheService = BlurhashImageCacheService.shared

    public let documentStore: DocumentStore
    private var documentStoreSubscription: AnyCancellable!
    
    let overrideTraitCollection = CurrentValueSubject<UITraitCollection?, Never>(nil)
    let timestampUpdatePublisher = Timer.publish(every: 1.0, on: .main, in: .common)
        .autoconnect()
        .share()
        .eraseToAnyPublisher()
    
    private init() {
        documentStore = DocumentStore()
        documentStoreSubscription = documentStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                self.objectWillChange.send()
            }
    }
}

extension AppContext {
    
    public typealias ByteCount = Int
    
    public static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        return formatter
    }()
    
    public func purgeCache() {
        ImageDownloader.defaultURLCache().removeAllCachedResponses()

        let fileManager = FileManager.default
        let temporaryDirectoryURL = fileManager.temporaryDirectory
        let fileKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]

        if let directoryEnumerator = fileManager.enumerator(
            at: temporaryDirectoryURL,
            includingPropertiesForKeys: fileKeys,
            options: .skipsHiddenFiles) {
            for case let fileURL as URL in directoryEnumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(fileKeys)),
                      resourceValues.isDirectory == false else {
                    continue
                }

                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    // In Bytes
    public func currentDiskUsage() -> Int {
        let alamoFireDiskBytes = ImageDownloader.defaultURLCache().currentDiskUsage

        var tempFilesDiskBytes = 0
        let fileManager = FileManager.default
        let temporaryDirectoryURL = fileManager.temporaryDirectory
        let fileKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]

        if let directoryEnumerator = fileManager.enumerator(
            at: temporaryDirectoryURL,
            includingPropertiesForKeys: fileKeys,
            options: .skipsHiddenFiles) {
            for case let fileURL as URL in directoryEnumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(fileKeys)),
                      resourceValues.isDirectory == false else {
                    continue
                }

                tempFilesDiskBytes += resourceValues.fileSize ?? 0
            }
        }

        return alamoFireDiskBytes + tempFilesDiskBytes
    }
}
