//
//  KCNCoreDataManager.h
//  KCNCoreDataManager
//
//  Created by Kevin Nguy on 8/20/15.
//  Copyright (c) 2015 kevinnguy. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NSFetchRequest;
@class NSManagedObject;
@class NSManagedObjectContext;

@interface KCNCoreDataManager : NSObject

/**
 *  Context associated with the main queue. Can be passed directly to read-only methods that require a context but don't
 *  require the context to be saved afterwards (in which case `performMainContextBlock:` would be a better option).
 */
@property (nonatomic, strong, readonly) NSManagedObjectContext *mainContext;

+ (instancetype)sharedManager;

// Call setup in app delegate
#pragma mark - Setup
- (void)setupCoreDataStackWithName:(NSString *)name;

#pragma mark - Save methods
- (void)saveInBackgroundBlockAndWait:(void (^)(NSManagedObjectContext *context))block;
- (void)saveInMainContextBlock:(void (^)(NSManagedObjectContext *mainContext))block;

#pragma mark - Delete methods
- (void)deleteEntity:(NSManagedObject *)entity;
- (void)deleteAllEntityClass:(Class)entityClass;
- (void)deleteInMainContextWithEntity:(NSManagedObject *)entity;

#pragma mark - Query methods
- (NSFetchRequest *)fetchRequestWithEntityClass:(Class)entityClass predicate:(NSPredicate *)predicate batchSize:(NSInteger)batchSize;
- (NSArray *)findFetchRequestWithEntityClass:(Class)entityClass predicate:(NSPredicate *)predicate batchSize:(NSInteger)batchSize;

@end
