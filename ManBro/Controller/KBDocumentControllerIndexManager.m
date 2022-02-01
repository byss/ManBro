//
//  KBDocumentControllerIndexManager.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 1/8/22.
//  Copyright © 2022 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentController_Private.h"

#import "KBIndexManager.h"
#import "NSObject+blockKVO.h"

#define LOG_PROGRESS_TREE 0
#define DISABLE_INDEX_UPDATES 0

#if DEBUG && LOG_PROGRESS_TREE
@interface NSProgress (safeRecursiveDescription)

@property (nonatomic, readonly) NSString *safeRecursiveDescription;

@end
#endif

NSNotificationName const KBDocumentControllerIndexManagerDidStartIndexUpdate = @"ru.byss.ManBro.DocumentController.IndexManager.didStartIndexUpdate";
NSNotificationName const KBDocumentControllerIndexManagerDidFinishIndexUpdate = @"ru.byss.ManBro.DocumentController.IndexManager.didFinishIndexUpdate";

static NSString *const KBPrefixUpdateLastTimestampKey = @"lastPrefixesScanTimestamp";

@interface KBDocumentControllerIndexManager () {
	KBIndexManager *_indexManager;
	NSTimeInterval _prefixesScanTimestamp;
	id <NSObject> _progressObserver;
	long _lastProgressPromille;
#if DEBUG
	dispatch_queue_t _logQueue;
#endif
}

@end

@implementation KBDocumentControllerIndexManager

+ (instancetype) sharedManager {
	static KBDocumentControllerIndexManager *sharedManager;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		sharedManager = [[self alloc] initPrivate];
	});
	return sharedManager;
}

- (instancetype) init { return nil; }
- (instancetype) initPrivate { return [super init]; }

- (BOOL) shouldScanPrefixesNow {
#if DEBUG && DISABLE_INDEX_UPDATES
	return NO;
#else
	return !_indexManager && (!_prefixesScanTimestamp || (([NSDate timeIntervalSinceReferenceDate] - _prefixesScanTimestamp) > 3600.0));
#endif
}

- (BOOL) isUpdating {
	return !!_indexManager;
}

- (NSNumber *) progress {
	return (_lastProgressPromille < 0) ? nil : @(_lastProgressPromille / 1000.0);
}

- (void) updateIndexIfNeeded {
	if ([self shouldScanPrefixesNow]) {
		_indexManager = [KBIndexManager new];
		[self willChangeValueForKey:@"progress"];
		_lastProgressPromille = -1;
		[self didChangeValueForKey:@"progress"];
#if DEBUG
		_logQueue = dispatch_queue_create ("IndexUpdateLogging", dispatch_queue_attr_make_with_qos_class (DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, QOS_CLASS_USER_INITIATED, 0));
#endif
		__unsafe_unretained typeof (self) unsafeSelf = self;
		_progressObserver = [_indexManager.progress observeValueForKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionAutoremove usingBlock:^(NSDictionary <NSKeyValueChangeKey, id> *change) { [unsafeSelf indexManagerDidUpdateWithProgress:[change [NSKeyValueChangeNewKey] doubleValue]]; }];
		[[NSNotificationCenter defaultCenter] postNotificationName:KBDocumentControllerIndexManagerDidStartIndexUpdate object:self];
		[_indexManager runWithCompletion:^{
			dispatch_async (dispatch_get_main_queue (), ^{
				NSTimeInterval const timestamp = [NSDate timeIntervalSinceReferenceDate];
				NSUserDefaults *const defaults = [NSUserDefaults standardUserDefaults];
				[defaults setDouble:timestamp forKey:KBPrefixUpdateLastTimestampKey];
				[defaults synchronize];
				self->_prefixesScanTimestamp = timestamp;
				self->_progressObserver = nil;
#if DEBUG
				self->_logQueue = NULL;
#endif
				self->_indexManager = nil;
				[[NSNotificationCenter defaultCenter] postNotificationName:KBDocumentControllerIndexManagerDidFinishIndexUpdate object:self];
			});
		}];
	}
}

- (void) indexManagerDidUpdateWithProgress: (double) progress {
	long const progressPromille = lrint (progress * 1000.0);
	if (progressPromille != _lastProgressPromille) {
		[self willChangeValueForKey:@"progress"];
		_lastProgressPromille = progressPromille;
		[self didChangeValueForKey:@"progress"];
#if LOG_PROGRESS_TREE
		NSString *const description = _indexManager.progress.safeRecursiveDescription;
#endif
#if DEBUG
		dispatch_async (_logQueue, ^{
			NSLog (@"Progress: %.1f%%", progress * 100.0);
#	if LOG_PROGRESS_TREE
			NSLog (@"%@", description);
#	endif
		});
#endif
	}
}

@end

#if DEBUG && LOG_PROGRESS_TREE

#import <objc/runtime.h>

@implementation NSProgress (safeRecursiveDescription)

- (NSSet <NSProgress *> *) safeChildren {
	static Ivar childrenIvar;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{ childrenIvar = class_getInstanceVariable ([NSProgress class], "_children"); });
	return [object_getIvar (self, childrenIvar) copy];
}

- (NSString *)  safeRecursiveDescription {
	return [self safeRecursiveDescriptionWithLevel:0];
}

- (NSString *)  safeRecursiveDescriptionWithLevel: (int) level {
	NSMutableString *result = [[NSMutableString alloc] initWithFormat:@"%*s<%@: %p>: Fraction completed: %.4f / Completed: %ld of %ld", level * 2, "", self.class, self, self.fractionCompleted, (long) self.completedUnitCount, (long) self.totalUnitCount];
	NSSet <NSProgress *> *const children = self.safeChildren;
	for (NSProgress *child in children) {
		[result appendFormat:@"\n%@", [child safeRecursiveDescriptionWithLevel:level + 1]];
	}
	return result;
}

@end

#endif
