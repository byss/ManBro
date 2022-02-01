//
//  NSPersistentContainer+sharedContainer.m
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "NSPersistentContainer+sharedContainer.h"

#import <os/log.h>
#import <dlfcn.h>

#import "CoreData+logging.h"

@interface KBPersistentContainer: NSPersistentContainer
@end

@implementation NSPersistentContainer (sharedContainer)

+ (instancetype) sharedContainer {
	return [KBPersistentContainer sharedContainer];
}

- (NSString *) defaultURLExtensionForStoreType: (NSString *) storeType {
	if ([storeType isEqualToString:NSSQLiteStoreType]) {
		return @"sqlite";
	} else if ([storeType isEqualToString:NSBinaryStoreType]) {
		return @"bin";
	} else if ([storeType isEqualToString:NSXMLStoreType]) {
		return @"xml";
	} else if (UTTypeIsDeclared ((__bridge CFStringRef) storeType)) {
		return (__bridge_transfer NSString *) UTTypeCopyPreferredTagWithClass ((__bridge CFStringRef) storeType, kUTTagClassFilenameExtension);
	} else {
		return storeType;
	}
}

- (NSURL *) defaultURLForStoreType: (NSString *) storeType {
	if ([storeType isEqualToString:NSInMemoryStoreType]) {
		return nil;
	}
	return [[[self.class defaultDirectoryURL] URLByAppendingPathComponent:[NSBundle mainBundle].bundleIdentifier] URLByAppendingPathExtension:[self defaultURLExtensionForStoreType:storeType]];
}

- (NSPersistentStoreDescription *) defaultStoreOfType: (NSString *) storeType {
	NSPersistentStoreDescription *const result = [[NSPersistentStoreDescription alloc] initWithURL:[self defaultURLForStoreType:storeType]];
	result.type = storeType;
	result.shouldAddStoreAsynchronously = NO;
	result.shouldMigrateStoreAutomatically = YES;
	result.shouldInferMappingModelAutomatically = YES;
	return result;
}

@end

@interface NSManagedObjectContext (sharedContainer)

@property (nonatomic, readonly) os_log_t log;

- (instancetype) setupAsMainContext;
- (instancetype) setupAsBackgroundContext;
- (void) deleteStaleObjectsAndWait;

@end

@interface KBPersistentContainer ()

@property (nonatomic, readonly) os_log_t log;

@end

@implementation KBPersistentContainer

NS_INLINE void KBPersistentContainerCreateSharedInstance (void *instance) {
	*((NSPersistentContainer *__strong *) instance) = [KBPersistentContainer new];
}

+ (instancetype) sharedContainer {
	static KBPersistentContainer *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once_f (&onceToken, &instance, KBPersistentContainerCreateSharedInstance);
	return instance;
}

- (instancetype) init {
	if (self = [super initWithName:[[NSBundle mainBundle] objectForInfoDictionaryKey:(id) kCFBundleNameKey]]) {
		_log = os_log_create ("CoreData", "KBPersistentContainer");
		[self loadDefaultStores];
		[self.viewContext setupAsMainContext];
		if ([self.persistentStoreDescriptions.firstObject.type isEqualToString:NSSQLiteStoreType]) {
			[[self newBackgroundContext] deleteStaleObjectsAndWait];
		}
	}
	
	return self;
}

- (NSManagedObjectContext *) newBackgroundContext {
	return [[super newBackgroundContext] setupAsBackgroundContext];
}

- (void) performBackgroundTask: (void (^) (NSManagedObjectContext *ctx)) block {
	[super performBackgroundTask:^(NSManagedObjectContext *ctx) { block ([ctx setupAsBackgroundContext]); }];
}

- (void) loadDefaultStores {
	NSPersistentStoreDescription *const sqliteStore = [self defaultStoreOfType:NSSQLiteStoreType];
	[self loadPersistentStoresWithCompletion:^(NSError *error) {
		if (!error) { return; }
		os_log_fault (self.log, "Error opening persistent store at %{public}@: %{public}@", sqliteStore.URL, error);
		[self loadPersistentStoresWithCompletion:^(NSError *error) {
			if (!error) { return os_log (self.log, "Using in-memory temporary store instead"); }
			os_log_fault (self.log, "Failed to initialize in-memory store: %{public}@", error);
			abort ();
		}, [self defaultStoreOfType:NSInMemoryStoreType], nil];
	}, sqliteStore, nil];
}

- (void) loadPersistentStoresWithCompletion: (void (^) (NSError *)) completionBlock, ... NS_REQUIRES_NIL_TERMINATION {
	NSMutableArray <NSPersistentStoreDescription *> *persistentStoreDescriptions = [[NSMutableArray alloc] initWithCapacity:1];
	va_list args;
	va_start (args, completionBlock);
	for (NSPersistentStoreDescription *description; (description = va_arg (args, NSPersistentStoreDescription *)); [persistentStoreDescriptions addObject:description]);
	va_end (args);
	self.persistentStoreDescriptions = persistentStoreDescriptions;
	[self loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *description, NSError *error) { completionBlock (error); }];
}

@end

@implementation NSManagedObjectContext (sharedContainer)

- (os_log_t) log {
	static os_log_t log;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		log = os_log_create ("CoreData", "NSManagedObjectContext");
	});
	return log;
}

- (instancetype) setupAsMainContext {
	self.automaticallyMergesChangesFromParent = YES;
#if DEBUG
	self.name = @"MAIN CTX";
#endif
	return self;
}

- (instancetype) setupAsBackgroundContext {
#if DEBUG
	Dl_info info;
	dladdr ((void const *) NSThread.callStackReturnAddresses [2].unsignedIntegerValue, &info);
	self.name = [NSString stringWithFormat:@"BG CTX (%s)", info.dli_sname];
#endif
	return self;
}

- (void) deleteStaleObjectsAndWait {
	[self performBlockAndWait:^{
		for (NSEntityDescription *entity in self.persistentStoreCoordinator.managedObjectModel.entities) {
			Class const entityClass = NSClassFromString (entity.managedObjectClassName);
			NSPredicate *const staleObjectsPredicate = [entityClass staleObjectsPredicate];
			if (!staleObjectsPredicate) { continue; }
			
			os_log_info (self.log, "%{public}@: purging stale objects using predicate %{public}@", entityClass, staleObjectsPredicate);
			NSFetchRequest *const fetchReq = [[NSFetchRequest alloc] initWithEntityName:entity.name];
			fetchReq.predicate = staleObjectsPredicate;
			NSBatchDeleteRequest *const deleteReq = [[NSBatchDeleteRequest alloc] initWithFetchRequest:fetchReq];
			deleteReq.resultType = NSBatchDeleteResultTypeCount;
			NSUInteger const deletedCount = [[[self executeRequest:deleteReq] result] unsignedIntegerValue];
			if (deletedCount) { os_log_info (self.log, "%lu object(s) deleted", deletedCount); }
		}
		[self save];
	}];
}

@end

@implementation NSManagedObject (staleObjectsPredicate)

+ (NSPredicate *) staleObjectsPredicate { return nil; }

@end
