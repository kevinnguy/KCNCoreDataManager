//
//  KCNCoreDataManager.m
//  KCNCoreDataManager
//
//  Created by Kevin Nguy on 8/20/15.
//  Copyright (c) 2015 kevinnguy. All rights reserved.
//

#import "KCNCoreDataManager.h"

@import CoreData;
@import UIKit.UIApplication;

@interface KCNCoreDataManager ()

@property (nonatomic, strong) NSManagedObjectContext *masterContext;

@end

@implementation KCNCoreDataManager

+ (instancetype)sharedManager {
    static KCNCoreDataManager *manager;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    
    return manager;
}

#pragma mark - Setup
- (void)setupCoreDataStackWithName:(NSString *)name {
    // Core data stack inspired by Tumblr https://github.com/tumblr/CoreDataExample
    
    NSManagedObjectModel *managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:
                                                [[NSBundle mainBundle] URLForResource:name
                                                                        withExtension:@"momd"]];
    NSPersistentStoreCoordinator *persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];
    
    _masterContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    _masterContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
    _masterContext.persistentStoreCoordinator = persistentStoreCoordinator;
    
    _mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    _mainContext.parentContext = _masterContext;
    
    NSURL *persistentStoreURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject
                                 URLByAppendingPathComponent:[name stringByAppendingPathExtension:@"sqlite"]];
    
    /**
     *  Add a persistent store to a coordinator. If a store already exists on disk, reuse it if it is compatible with the
     *  provided managed object model. Otherwise, delete the store on disk and create a new one.
     */
    if ([[NSFileManager defaultManager] fileExistsAtPath:[persistentStoreURL path]]) {
        NSError *storeMetadataError = nil;
        NSDictionary *storeMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
                                                                                                 URL:persistentStoreURL
                                                                                               error:&storeMetadataError];
        
        // If store is incompatible with the managed object model, remove the store file
        if (storeMetadataError || ![managedObjectModel isConfiguration:nil compatibleWithStoreMetadata:storeMetadata]) {
            NSError *removeStoreError = nil;
            if (![[NSFileManager defaultManager] removeItemAtURL:persistentStoreURL error:&removeStoreError]) {
                NSLog(@"KCNCoreDataManager: Error removing store file at URL '%@': %@, %@", persistentStoreURL, removeStoreError, [removeStoreError userInfo]);
            }
        }
    }
    
    NSError *addStoreError = nil;
    [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                             configuration:nil
                                                       URL:persistentStoreURL
                                                   options:nil
                                                     error:&addStoreError];
    if (!addStoreError) {
        NSLog(@"KCNCoreDataManager: persistentStoreCoordinator was unable to add store: %@, %@", addStoreError, [addStoreError userInfo]);
    }
    
    // Tell app delegate to save context when app is in background or terminated
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(kcn_saveMainContext)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(kcn_saveMainContext)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
}

#pragma mark - Save methods
- (void)saveInBackgroundBlockAndWait:(void (^)(NSManagedObjectContext *context))block {
    /**
     *  Provides a block with a private queue context and performs the block on the aforementioned queue, synchronously.
     *  Saves the context (and any ancestor contexts, recursively) afterwards.
     *
     *  @param block Block provided with a private queue context and performed on the aforementioned queue.
     */
    if (!block) {
        return;
    }
    
    NSManagedObjectContext *backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    backgroundContext.parentContext = self.mainContext;
    [backgroundContext performBlockAndWait:^{
        block(backgroundContext);
        [self kcn_saveContext:backgroundContext];
    }];
}

- (void)saveInMainContextBlock:(void (^)(NSManagedObjectContext *mainContext))block {
    /**
     *  Provides a block with the main queue context and performs the block on the main queue, synchronously.
     *  Saves the context (and any ancestor contexts, recursively) afterwards.
     *
     *  @param block Block provided with the main queue context and performed on the main queue.
     */
    if (!block) {
        return;
    }
    
    block(self.mainContext);
    [self kcn_saveMainContext];
}

#pragma mark - Delete methods
- (void)deleteEntity:(NSManagedObject *)entity {
    [self saveInBackgroundBlockAndWait:^(NSManagedObjectContext *context) {
        [context deleteObject:entity];
    }];
}

- (void)deleteAllEntityClass:(Class)entityClass {
    [self saveInBackgroundBlockAndWait:^(NSManagedObjectContext *context) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:NSStringFromClass(entityClass)];
        NSArray *fetchedArray = [context executeFetchRequest:fetchRequest error:nil];
        
        [fetchedArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [context deleteObject:obj];
        }];
    }];
}

- (void)deleteInMainContextWithEntity:(NSManagedObject *)entity {
    [self saveInMainContextBlock:^(NSManagedObjectContext *mainContext) {
        [mainContext deleteObject:entity];
    }];
}

#pragma mark - Query methods
- (NSFetchRequest *)fetchRequestWithEntityClass:(Class)entityClass predicate:(NSPredicate *)predicate batchSize:(NSInteger)batchSize {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:NSStringFromClass(entityClass)];
    fetchRequest.predicate = predicate;
    fetchRequest.fetchBatchSize = batchSize;
    fetchRequest.sortDescriptors = @[];
    return fetchRequest;
}

- (NSArray *)findFetchRequestWithEntityClass:(Class)entityClass predicate:(NSPredicate *)predicate batchSize:(NSInteger)batchSize {
    NSFetchRequest *fetchRequest = [self fetchRequestWithEntityClass:entityClass predicate:predicate batchSize:batchSize];
    return [self.mainContext executeFetchRequest:fetchRequest error:nil];
}

#pragma mark - Private methods
- (void)kcn_saveMainContext {
    /**
     *  Save the main queue's context as well as its parent context(s) (recursively)
     */
    [self kcn_saveContext:self.mainContext];
}

- (void)kcn_saveContext:(NSManagedObjectContext *)context {
    /**
     *  Save the provided managed object context as well as its parent context(s) (recursively)
     */
    if ([context hasChanges]) {
        NSError *error;
        if (![context save:&error]) {
            NSLog(@"DMCoreDataManager: Error saving context: %@ %@ %@", self, error, [error userInfo]);
        }
        
        [self kcn_saveContext:context.parentContext];
    }
}

@end
