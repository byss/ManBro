//
//  CoreData+logging.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/11/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "CoreData+logging.h"

#import <os/log.h>

@implementation NSManagedObjectContext (logging)

#define METHOD_LOGGING_ERRORS(_ret, _base) \
	- (_ret) _base { \
		NSError *error = nil; \
		_ret const result = [self _base error:&error]; \
		if (error) { \
			[self logError:error method:__PRETTY_FUNCTION__]; \
		} \
		return result; \
	}

METHOD_LOGGING_ERRORS (__kindof NSManagedObject *, existingObjectWithID: (NSManagedObjectID *) objectID)
METHOD_LOGGING_ERRORS (NSArray *__nullable, executeFetchRequest: (NSFetchRequest *) request)
METHOD_LOGGING_ERRORS (NSUInteger, countForFetchRequest: (NSFetchRequest *) request)
METHOD_LOGGING_ERRORS (__kindof NSPersistentStoreResult *__nullable, executeRequest: (NSPersistentStoreRequest *) request)
METHOD_LOGGING_ERRORS (BOOL, obtainPermanentIDsForObjects: (NSArray <NSManagedObject *> *) objects)

- (void) save {
	if (!self.hasChanges) { return; }
	NSError *error = nil;
	if (self.hasChanges && ![self save:&error]) {
		[self logError:error method:__PRETTY_FUNCTION__];
		abort ();
	}
}

- (void) logError: (NSError *) error method: (char const *) method {
	static os_log_t KBLog;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		KBLog = os_log_create ("CoreData", "NSManagedObjectContext");
	});
	os_log_fault (KBLog, "%{public}s failed: %{public}@", method, error);
}

@end

@implementation NSManagedObjectContext (asyncRequest)

#define ASYNC_METHOD(_base, _ret) \
	- (void) _base completion: (void (^) (_ret)) completion { \
		[self performBlock:^{ completion ([self _base]); }]; \
	}

ASYNC_METHOD (executeFetchRequest: (NSFetchRequest *) request, NSArray <__kindof NSManagedObject *> *__nullable)
ASYNC_METHOD (countForFetchRequest: (NSFetchRequest *) request, NSUInteger)
ASYNC_METHOD (executeRequest: (NSPersistentStoreRequest *) request, __kindof NSPersistentStoreResult *__nullable)

@end

@implementation NSAsynchronousFetchRequest (logging)

- (instancetype) initWithFetchRequest: (NSFetchRequest *) request successBlock: (void (^)(NSArray <id <NSFetchRequestResult>> *)) blk {
	return [self initWithFetchRequest:request completionBlock:^(NSAsynchronousFetchResult *result) {
		if (result.operationError) {
			[result.managedObjectContext logError:result.operationError method:__PRETTY_FUNCTION__];
		}
	}];
}

@end
