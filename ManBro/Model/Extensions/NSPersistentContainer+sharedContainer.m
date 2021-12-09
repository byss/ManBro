//
//  NSPersistentContainer+sharedContainer.m
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "NSPersistentContainer+sharedContainer.h"

#import <os/log.h>

NS_INLINE void NSPersistentContainerCreateSharedInstance (void *instance);

@implementation NSPersistentContainer (sharedContainer)

+ (instancetype) sharedContainer {
	static NSPersistentContainer *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once_f (&onceToken, &instance, NSPersistentContainerCreateSharedInstance);
	return instance;
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

NS_INLINE void NSPersistentContainerCreateSharedInstance (void *instance) {
	NSPersistentContainer *const result = [[NSPersistentContainer alloc] initWithName:[[NSBundle mainBundle] objectForInfoDictionaryKey:(id) kCFBundleNameKey]];
	NSPersistentStoreDescription *const sqliteStore = [result defaultStoreOfType:NSSQLiteStoreType];
	result.persistentStoreDescriptions = @[sqliteStore];
	[result loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *store, NSError *error) {
		if (error) {
			os_log_t const log = os_log_create ("CoreData", "NSPersistentContainer");
			os_log_fault (log, "Error opening persistent store at %{public}@: %{public}@", sqliteStore.URL, error);
			result.persistentStoreDescriptions = @[[result defaultStoreOfType:NSInMemoryStoreType]];
			[result loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *store, NSError *error) {
				if (error) {
					os_log_fault (log, "Failed to initialize in-memory store: %{public}@", error);
					abort ();
				} else {
					os_log (log, "Using in-memory temporary store instead");
				}
			}];
		}
	}];
	
	result.viewContext.automaticallyMergesChangesFromParent = YES;
	*((NSPersistentContainer *__strong *) instance) = result;
}
