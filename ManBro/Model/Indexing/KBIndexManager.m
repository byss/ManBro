//
//  KBIndexManager.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/10/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBIndexManager.h"

#import "KBManPageTasks.h"
#import "NSURL+filesystem.h"
#import "CoreData+logging.h"
#import "NSObject+abstract.h"
#import "NSPersistentContainer+sharedContainer.h"
#import "KBPrefix.h"
#import "KBSection.h"
#import "KBDocumentMeta.h"
#import "KBIndexUpdateTasks.h"

@protocol KBPrefixUpdateHeuristic <NSObject>

@required
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly, nullable) NSSet <NSURL *> *requestedURLs;

@end

@interface KBPrefixUpdateHeuristic: NSObject <KBPrefixUpdateHeuristic>

@property (nonatomic, readonly, class) NSSet <id <KBPrefixUpdateHeuristic>> *allHeuristics;

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype) init NS_UNAVAILABLE;

@end

@interface KBIndexManager () {
	BOOL _started;
}

@property (nonatomic, readonly) dispatch_queue_t queue;
@property (nonatomic, readonly) NSManagedObjectContext *context;

@property (nonatomic, copy) NSDictionary <NSURL *, KBPrefix *> *prefixes;

@end

@implementation KBIndexManager

@synthesize progress = _progress;

- (instancetype) init {
	NSManagedObjectContext *const context = [[NSPersistentContainer sharedContainer] newBackgroundContext];
#if DEBUG
	context.name = @"KBIndexManager: ROOT";
#endif
	return [self initWithContext:context];
}

- (instancetype) initWithContext: (NSManagedObjectContext *) context {
	if (!context) {
		return nil;
	}
	if (self = [super init]) {
		_queue = dispatch_queue_create ("KBIndexManager", dispatch_queue_attr_make_with_qos_class (DISPATCH_QUEUE_CONCURRENT_WITH_AUTORELEASE_POOL, QOS_CLASS_USER_INITIATED, 0));
		_context = context;
		_progress = [NSProgress new];
		_progress.totalUnitCount = -1;
	}
	return self;
}

- (void) runWithCompletion: (void (^)(void)) completion {
	NSAssert (!_started, @"KBIndexManager has already started an indexing task");
	_started = YES;
	
	[self prepareTasksWithCompletion:^(NSSet <KBPrefixUpdateTask *> *tasks) {
		self.progress.totalUnitCount = tasks.count + 2;
		for (KBPrefixUpdateTask *task in tasks) {
			[self.progress addChild:task.progress withPendingUnitCount:1];
		}

		dispatch_group_t const group = dispatch_group_create ();
		for (KBPrefixUpdateTask *task in tasks) {
			dispatch_group_enter (group);
			[task runWithCompletion:^{ dispatch_group_leave (group); }];
		}
		
		dispatch_group_notify (group, self.queue, ^{
			[KBPrefix fetchInContext:self.context completion:^(NSArray <KBPrefix *> *prefixes) {
				for (KBPrefix *prefix in prefixes) {
					if (prefix.sections.count) { continue; }
					if ([prefix.source isEqualToString:KBPrefixSourceUser]) {
						for (KBSection *section in prefix.sections) {
							[self.context deleteObject:section];
						}
					} else {
						[self.context deleteObject:prefix];
					}
				}
				dispatch_async (self.queue, ^{
					self.progress.completedUnitCount++;
					[self.context performBlock:^{
						[self.context save];
						dispatch_async (self.queue, ^{
							self.progress.completedUnitCount++;
							completion ();
						});
					}];
				});
			}];
		});
	}];
}

- (void) prepareTasksWithCompletion: (void (^) (NSSet <KBPrefixUpdateTask *> *)) completion {
	__block NSSet <NSURL *> *heuristicURLs, *manConfigURLs, *existingPrefixURLs;
	dispatch_group_t const group = dispatch_group_create ();
	
	dispatch_group_async (group, self.queue, ^{
		NSMutableSet <NSURL *> *result = [NSMutableSet new];
		for (id <KBPrefixUpdateHeuristic> heuristic in KBPrefixUpdateHeuristic.allHeuristics) {
			for (NSURL *requestedURL in heuristic.requestedURLs) {
				[result addObject:requestedURL.absoluteURL.standardizedURL];
			}
		}
		heuristicURLs = [[NSSet alloc] initWithSet:result];
	});

	dispatch_group_enter (group);
	[[KBManpathQueryTask new] startWithCompletion:^(NSArray <NSURL *> *prefixURLs, NSError *error) {
		manConfigURLs = [[NSSet alloc] initWithArray:prefixURLs];
		dispatch_group_leave (group);
	}];
	
	dispatch_group_enter (group);
	[KBPrefix fetchInContext:self.context completion:^(NSArray <KBPrefix *> *fetched) {
		NSArray <NSURL *> *const urls = [fetched valueForKeyPath:@"URL"];
		existingPrefixURLs = [[NSSet alloc] initWithArray:urls];
		self.prefixes = [[NSDictionary alloc] initWithObjects:fetched forKeys:urls];
		dispatch_group_leave (group);
	}];
	
	dispatch_group_notify (group, self.queue, ^{
		__block NSUInteger minPriority = 0;
		NSMutableDictionary <NSURL *, KBPrefixUpdateTask *> *tasks = [NSMutableDictionary new];
		[self.context performBlockAndWait:^{
			for (NSURL *url in self.prefixes) {
				KBPrefix *const prefix = self.prefixes [url];
				tasks [url] = [[KBPrefixUpdateTask alloc] initWithPrefix:prefix];
				minPriority = MAX (minPriority, prefix.priority);
			}
		}];
		for (NSURL *url in manConfigURLs) {
			if (!tasks [url]) {
				tasks [url] = [[KBPrefixUpdateTask alloc] initWithURL:url source:KBPrefixSourceManConfig priority:++minPriority context:self.context];
			}
		}
		for (NSURL *url in heuristicURLs) {
			if (!tasks [url]) {
				tasks [url] = [[KBPrefixUpdateTask alloc] initWithURL:url source:KBPrefixSourceHeuristic priority:++minPriority context:self.context];
			}
		}
		completion ([[NSSet alloc] initWithArray:tasks.allValues]);
	});
}

@end

typedef NS_ENUM (NSInteger, KBPrefixUpdateHeuristicPathCheckingResult) {
	KBPrefixUpdateHeuristicContinuePathEnumeraration = -1,
	KBPrefixUpdateHeuristicIgnorePathAndDescendants = 0,
	KBPrefixUpdateHeuristicPossiblePrefixPathRecognized = 1,
};

@interface KBDynamicPrefixUpdateHeuristic: KBPrefixUpdateHeuristic

@property (nonatomic, readonly) NSURL *rootURL;

- (instancetype) initWithName: (NSString *) name rootURL: (NSURL *) rootURL descendantsPredicate: (KBPrefixUpdateHeuristicPathCheckingResult (^) (NSArray <NSString *> *pathComponents)) descendantsPredicate NS_DESIGNATED_INITIALIZER;

@end

NS_INLINE KBPrefixUpdateHeuristicPathCheckingResult KBPrefixUpdateHeuristicHomebrewPredicate (NSArray <NSString *> *pathComponents);

#import <objc/runtime.h>

static __unsafe_unretained Class KBPrefixUpdateHeuristicClass;

static void KBPrefixUpdateHeuristicClassInit (void *context) { KBPrefixUpdateHeuristicClass = (__bridge Class) context; }

@implementation KBPrefixUpdateHeuristic

@synthesize name = _name;

+ (void) load {
	static dispatch_once_t onceToken;
	dispatch_once_f (&onceToken, (__bridge void *) self, KBPrefixUpdateHeuristicClassInit);
}

+ (NSSet <id <KBPrefixUpdateHeuristic>> *) allHeuristics {
	static NSSet <id <KBPrefixUpdateHeuristic>> *allHeuristics;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		id <KBPrefixUpdateHeuristic> const heuristics [] = {
			[[self alloc] initWithName:@"Xcode" requestedURLs:
			 [[NSURL alloc] initFileURLWithPath:@"/Applications/Xcode.app/Contents/Developer/usr/share/man" isDirectory:YES],
			 [[NSURL alloc] initFileURLWithPath:@"/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/share/man" isDirectory:YES],
			 nil],
			[[self alloc] initWithName:@"local" requestedURLs:[[NSURL alloc] initFileURLWithPath:@"/usr/local/share/man" isDirectory:YES], nil],
			[[KBDynamicPrefixUpdateHeuristic alloc] initWithName:@"Homebrew" rootURL:[[NSURL alloc] initFileURLWithPath:@"/usr/local/Cellar" isDirectory:YES] descendantsPredicate:^(NSArray <NSString *> *pathComponents) { return KBPrefixUpdateHeuristicHomebrewPredicate (pathComponents); }],
		};
		allHeuristics = [[NSSet alloc] initWithObjects:heuristics count:sizeof (heuristics) / sizeof (id)];
	});
	return allHeuristics;
}

+ (BOOL) isHeuristicSubclass { return self != KBPrefixUpdateHeuristicClass; }

+ (instancetype) allocWithZone: (NSZone *) zone {
	return self.isHeuristicSubclass ? [super allocWithZone:zone] : class_createInstance (self, sizeof (id));
}

- (BOOL) isHeuristicSubclass { return object_getClass (self) != KBPrefixUpdateHeuristicClass; }

- (instancetype) init {
	return [self initWithName:nil requestedURLs:nil];
}

- (instancetype) initWithName: (NSString *) name requestedURLs: (NSURL *) url, ... NS_REQUIRES_NIL_TERMINATION {
	if (!name.length) { return nil; }
	if (self.isHeuristicSubclass) {
		NSAssert (!url, @"%@ subclasses must provide their own URL storage", [KBPrefixUpdateHeuristic class]);
	} else if (!url) {
		return nil;
	}
	
	if (self = [super init]) {
		_name = [name copy];
		
		if (url) {
			id __unsafe_unretained stackURLs [256] = { url }, *urls = stackURLs, *urlsEnd = urls + 1;
			size_t urlsAllocated = sizeof (stackURLs) / sizeof (*stackURLs);
			
			va_list args;
			va_start (args, url);
			for (id __unsafe_unretained url; (url = va_arg (args, NSURL *)); *urlsEnd++ = url) {
				size_t const count = urlsEnd - urls;
				if (count >= urlsAllocated) {
					urlsAllocated += count / 2;
					size_t const newSize = urlsAllocated * sizeof (id);
					if (urls == stackURLs) {
						urls = (id __unsafe_unretained *) malloc (newSize);
						memcpy (urls, stackURLs, sizeof (stackURLs));
					} else {
						urls = (id __unsafe_unretained *) realloc (urls, newSize);
					}
					urlsEnd = urls + count;
				}
			}
			va_end (args);
			
			*(id __strong *) object_getIndexedIvars (self) = [[NSSet alloc] initWithObjects:urls count:urlsEnd - urls];
			if (urls != stackURLs) {
				free (urls);
			}
		}
	}
	return self;
}

- (void) dealloc {
	if (!self.isHeuristicSubclass) { *(id __strong *) object_getIndexedIvars (self) = nil; }
}

- (NSArray <NSURL *> *) requestedURLs {
	if (self.isHeuristicSubclass) KB_ABSTRACT;
	return *(id __strong *) object_getIndexedIvars (self);
}

@end

@implementation KBDynamicPrefixUpdateHeuristic {
	NSURL *_rootURL;
	KBPrefixUpdateHeuristicPathCheckingResult (^_descendantsPredicate) (NSArray <NSString *> *pathComponents);
}

- (instancetype) initWithName: (NSString *) name rootURL: (NSURL *) rootURL descendantsPredicate: (KBPrefixUpdateHeuristicPathCheckingResult (^) (NSArray <NSString *> *pathComponents)) descendantsPredicate {
	if (self = [super initWithName:name requestedURLs:nil]) {
		_rootURL = rootURL;
		_descendantsPredicate = [descendantsPredicate copy];
	}
	return self;
}

- (NSSet <NSURL *> *) requestedURLs {
	NSInteger const rootPathComponentsCount = _rootURL.pathComponents.count;
	NSMutableArray <NSURL *> *const result = [NSMutableArray new];
	NSDirectoryEnumerator *const enumerator = [[NSFileManager defaultManager] enumeratorAtURL:_rootURL includingPropertiesForKeys:NSURL.readableDirectoryKeys options:NSDirectoryEnumerationProducesRelativePathURLs errorHandler:NULL];
	for (NSURL *subURL in enumerator) {
		NSArray <NSString *> *const pathComponents = subURL.pathComponents;
		NSInteger const relativePathComponentsCount = (NSInteger) pathComponents.count - rootPathComponentsCount;
		if (!subURL.isReadableDirectory || (relativePathComponentsCount <= 0)) { continue; }
		switch (_descendantsPredicate ([pathComponents subarrayWithRange:NSMakeRange (rootPathComponentsCount, relativePathComponentsCount)])) {
		case KBPrefixUpdateHeuristicContinuePathEnumeraration: continue;
		case KBPrefixUpdateHeuristicPossiblePrefixPathRecognized: [result addObject:subURL];
		case KBPrefixUpdateHeuristicIgnorePathAndDescendants: break;
		}
		[enumerator skipDescendants];
	}
	return [[NSSet alloc] initWithArray:result];
}

@end

NS_INLINE KBPrefixUpdateHeuristicPathCheckingResult KBPrefixUpdateHeuristicHomebrewPredicate (NSArray <NSString *> *pathComponents) {
	switch (pathComponents.count) {
	case 1: case 2: return KBPrefixUpdateHeuristicContinuePathEnumeraration;
	case 3: if ([pathComponents.lastObject isEqualToString:@"libexec"]) { return KBPrefixUpdateHeuristicContinuePathEnumeraration; }; break;
	case 4: if ([pathComponents.lastObject isEqualToString:@"gnuman"]) { return KBPrefixUpdateHeuristicPossiblePrefixPathRecognized; }; break;
	}
	return KBPrefixUpdateHeuristicIgnorePathAndDescendants;
}
