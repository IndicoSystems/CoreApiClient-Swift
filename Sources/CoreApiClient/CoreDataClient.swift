//
//  File.swift
//  
//
//  Created by Константин Ланин on 21.06.2023.
//

import CoreData
import SwiftUI

let moc: NSManagedObjectContext = {
//    let container = NSPersistentContainer(name: "Evidence")
//    container.loadPersistentStores(completionHandler: { (storeDescription, error) in })
//    return container.viewContext
    
    let momdName = "Evidence"
    
    guard let modelURL = Bundle.module.url(forResource: momdName, withExtension: "momd") else {
        fatalError("Error loading model from bundle")
    }

    guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
        fatalError("Error initializing mom from: \(modelURL)")
    }

    let container = NSPersistentContainer(name: momdName, managedObjectModel: mom)
    container.loadPersistentStores(completionHandler: { (storeDescription, error) in
        if let error = error as NSError? {
            print("Unresolved error \(error), \(error.userInfo)")
        }
    })
    
    return container.viewContext
}()

@available(iOS 13.0, *)
public class CoreDataClient {
    
    public static let shared = CoreDataClient()
    
    @FetchRequest(sortDescriptors: []) var items: FetchedResults<CDTask>
    
    public var cdItems: [CDTask] = []
    let fetchRequest: NSFetchRequest<CDTask> = CDTask.fetchRequest()
    
    public func searchItems() {
        do {
            cdItems = try moc.fetch(fetchRequest)
            print("fetched")
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    public func create() throws {
        do {
            let moc = moc
            let task = TestEntity(context: moc)
            //task.name = "new task"
            
            try moc.save()
            
            searchItems()
        }
        catch {
            throw(error)
        }
    }

    public func delete(_ items: [NSManagedObject]) throws {
        do {
            for item in items {
                moc.delete(item)
            }
            
            if !items.isEmpty {
                try moc.save()
            }
        }
        catch {
            throw(error)
        }
    }
}
