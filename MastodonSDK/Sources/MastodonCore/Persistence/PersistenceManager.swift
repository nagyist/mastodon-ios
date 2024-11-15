//
//  PersistenceManager.swift
//  MastodonSDK
//
//  Created by Shannon Hughes on 11/15/24.
//
import Combine
import CoreData
import CoreDataStack

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
