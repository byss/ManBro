//
//  CoreData+logging.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/11/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSManagedObjectContext (logging)

- (__kindof NSManagedObject *) existingObjectWithID: (NSManagedObjectID *) objectID;
- (NSArray *__nullable) executeFetchRequest: (NSFetchRequest *) request;
- (NSUInteger) countForFetchRequest: (NSFetchRequest *) request;
- (__kindof NSPersistentStoreResult *__nullable) executeRequest: (NSPersistentStoreRequest *) request;
- (BOOL) obtainPermanentIDsForObjects: (NSArray <NSManagedObject *> *) objects;
- (void) save;

@end

@interface NSManagedObjectContext (asyncRequest)

- (void) executeFetchRequest: (NSFetchRequest *) request completion: (void (^) (NSArray <__kindof NSManagedObject *> *__nullable)) completion;
- (void) countForFetchRequest: (NSFetchRequest *) request completion: (void (^) (NSUInteger)) completion;
- (void) executeRequest: (NSPersistentStoreRequest *) request completion: (void (^) (__kindof NSPersistentStoreResult *__nullable)) completion;

@end

@interface NSAsynchronousFetchRequest <ResultType: id <NSFetchRequestResult>> (logging)

- (instancetype) initWithFetchRequest: (NSFetchRequest *) request successBlock: (void (^)(NSArray <ResultType> *)) blk;

@end

NS_ASSUME_NONNULL_END
