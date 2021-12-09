//
//  KBIndexManager.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/10/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBIndexManager.h"

#import "KBManPageTasks.h"
#import "CoreData+logging.h"
#import "NSPersistentContainer+sharedContainer.h"
#import "KBPrefix.h"
#import "KBSection.h"
#import "KBDocument.h"

@interface KBPrefixUpdateTask: NSObject <NSProgressReporting>

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype) init NS_UNAVAILABLE;

- (instancetype) initWithURL: (NSURL *) url source: (KBPrefixSource) source priority: (NSUInteger) priority manager: (KBIndexManager *) manager NS_DESIGNATED_INITIALIZER;
- (void) runWithCompletion: (void (^) (void)) completion;

@end

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

@interface KBIndexManager ()

@property (nonatomic, readonly) dispatch_queue_t queue;
@property (nonatomic, readonly) NSManagedObjectContext *context;

@property (nonatomic, copy) NSDictionary <NSURL *, KBPrefix *> *prefixes;
@property (nonatomic, readonly) NSMutableSet <KBPrefix *> *invalidPrefixes;

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
		_queue = dispatch_queue_create ("KBIndexManager", DISPATCH_QUEUE_CONCURRENT_WITH_AUTORELEASE_POOL);
		_context = context;
		_progress = [NSProgress new];
		_progress.totalUnitCount = -1;
	}
	return self;
}

- (void) runWithCompletion: (void (^)(void)) completion {
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
			[self.context performBlock:^{
				for (KBPrefix *prefix in self.invalidPrefixes) {
					if ([prefix.source isEqualToString:KBPrefixSourceUser]) {
						for (KBSection *section in prefix.sections) {
							[self.context deleteObject:section];
						}
					} else {
						[self.context deleteObject:prefix];
					}
				}
				self.progress.completedUnitCount++;
				[self.context save];
				self.progress.completedUnitCount++;
				dispatch_async (dispatch_get_main_queue (), completion);
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
				[result addObject:requestedURL];
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
		NSArray <NSURL *> *urls = [fetched valueForKeyPath:@"URL"];
		existingPrefixURLs = [[NSSet alloc] initWithArray:urls];
		self.prefixes = [[NSDictionary alloc] initWithObjects:fetched forKeys:urls];
		self->_invalidPrefixes = [[NSMutableSet alloc] initWithArray:fetched];
		dispatch_group_leave (group);
	}];
	
	dispatch_group_notify (group, self.queue, ^{
		__block NSUInteger minPriority = 0;
		NSMutableDictionary <NSURL *, KBPrefixUpdateTask *> *tasks = [NSMutableDictionary new];
		[self.context performBlockAndWait:^{
			for (NSURL *url in self.prefixes) {
				KBPrefix *const prefix = self.prefixes [url];
				tasks [url] = [[KBPrefixUpdateTask alloc] initWithURL:url source:prefix.source priority:prefix.priority manager:self];
				minPriority = MAX (minPriority, prefix.priority);
			}
		}];
		for (NSURL *url in manConfigURLs) {
			if (!tasks [url]) {
				tasks [url] = [[KBPrefixUpdateTask alloc] initWithURL:url source:KBPrefixSourceManConfig priority:minPriority++ manager:self];
			}
		}
		for (NSURL *url in heuristicURLs) {
			if (!tasks [url]) {
				tasks [url] = [[KBPrefixUpdateTask alloc] initWithURL:url source:KBPrefixSourceHeuristic priority:minPriority++ manager:self];
			}
		}
		completion ([[NSSet alloc] initWithArray:tasks.allValues]);
	});
}

@end

@interface KBPrefixUpdateTask () {
	void (^_isValidBlock) (void (^) (void));
	dispatch_queue_t _targetQueue;
}

@property (nonatomic, readonly) NSURL *url;
@property (nonatomic, readonly) dispatch_queue_t queue;
@property (nonatomic, readonly) NSManagedObjectContext *context;
@property (nonatomic, readonly) KBPrefix *prefix;

@end

@interface NSURL (convenience)

@property (nonatomic, readonly, class) NSArray <NSURLResourceKey> *readableRegularFileKeys;
@property (nonatomic, readonly, class) NSArray <NSURLResourceKey> *readableDirectoryKeys;

@property (nonatomic, readonly, getter = isReadableRegularFile) BOOL readableRegularFile;
@property (nonatomic, readonly, getter = isReadableDirectory) BOOL readableDirectory;

- (BOOL) isReadableRegularFile: (NSError *__autoreleasing *) error;
- (BOOL) isReadableDirectory: (NSError *__autoreleasing *) error;

@end

@interface NSDictionary (resourceValues)

@property (nonatomic, readonly, getter = isReadableRegularFile) BOOL readableRegularFile;
@property (nonatomic, readonly, getter = isReadableDirectory) BOOL readableDirectory;

@end

@interface KBSectionUpdateTask: NSObject <NSProgressReporting>

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype) init NS_UNAVAILABLE;

- (instancetype) initWithPrefix: (KBPrefix *) prefix sectionName: (NSString *) sectionName targetQueue: (dispatch_queue_t) targetQueue;
- (void) runWithCompletion: (void (^) (void)) completion;

@end

@implementation KBPrefixUpdateTask

@synthesize progress = _progress, context = _context;

- (instancetype) init {
	return [self initWithURL:nil source:nil priority:NSUIntegerMax manager:nil];
}

- (instancetype) initWithURL: (NSURL *) url source: (KBPrefixSource) source priority: (NSUInteger) priority manager: (KBIndexManager *) manager {
	if (!(url && source && manager)) {
		return nil;
	}
	if (self = [super init]) {
		_url = url;
		_progress = [NSProgress new];
		_progress.totalUnitCount = -1;

		_targetQueue = manager.queue;
		_queue = dispatch_queue_create_with_target (NULL, dispatch_queue_attr_make_with_qos_class (DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, 0), _targetQueue);
		__block NSManagedObjectID *existingID;
		[manager.context performBlockAndWait:^{
			existingID = manager.prefixes [url].objectID;
		}];
		
		_context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
#if DEBUG
		self.context.name = [[NSString alloc] initWithFormat:@"KBIndexManager: %s", url.absoluteURL.fileSystemRepresentation];
#endif
		self.context.parentContext = manager.context;
		[self.context performBlockAndWait:^{
			if (existingID) {
				_prefix = [self.context objectWithID:existingID];
			} else {
				_prefix = [[KBPrefix alloc] initWithContext:self.context];
				self.prefix.source = source;
				self.prefix.priority = priority;
				self.prefix.URL = url;
			}
		}];

		__unsafe_unretained typeof (self) unsafeSelf = self;
		_isValidBlock = ^(void (^completion) (void)) {
			[manager.context performBlock:^{
				existingID ? [manager.invalidPrefixes removeObject:[manager.context objectWithID:existingID]] : (void) 0;
				[unsafeSelf.context performBlock:completion];
			}];
		};
	}
	return self;
}

- (void) runWithCompletion: (void (^)(void)) completion {
	void (^completionBlock) (void) = ^{
		[self.context save];
		completion ();
	};
	
	dispatch_async (self.queue, ^{
		[self updatePrefixWithURL:self.url completion:^(BOOL result) {
			if (result) {
				self->_isValidBlock (completionBlock);
			} else {
				[self.context performBlock:^{
					if (self.prefix.inserted) {
						[self.context deleteObject:self.prefix];
					}
					completionBlock ();
				}];
			}
		}];
	});
}

- (void) updatePrefixWithURL: (NSURL *) url completion: (void (^) (BOOL)) completion {
	NSArray <NSURLResourceKey> *const keys = [NSURL.readableDirectoryKeys arrayByAddingObject:NSURLGenerationIdentifierKey];
	NSDictionary <NSURLResourceKey, id> *const prefixProps = [url resourceValuesForKeys:keys error:NULL];
	if (!prefixProps.readableDirectory) {
		return completion (NO);
	}

	NSURLGenerationIdentifier const currentGenerationID = prefixProps [NSURLGenerationIdentifierKey];
	__block NSURLGenerationIdentifier knownGenerationID;
	[self.context performBlockAndWait:^{
		knownGenerationID = self.prefix.generationIdentifier;
	}];

	__block NSMutableSet <NSString *> *sectionNames;
	[self.context performBlockAndWait:^{
		sectionNames = self.prefix.sections.count ? [[NSMutableSet alloc] initWithSet:[self.prefix.sections valueForKey:@"name"]] : [NSMutableSet new];
	}];
	if (![currentGenerationID isEqual:knownGenerationID]) {
		NSFileManager *const mgr = [NSFileManager defaultManager];
		NSDirectoryEnumerator *const enumerator = [mgr enumeratorAtURL:url includingPropertiesForKeys:keys options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:NULL];
		for (NSURL *subURL in enumerator) {
			if (subURL.isReadableDirectory && [subURL.lastPathComponent hasPrefix:@"man"] && !subURL.pathExtension.length) {
				[sectionNames addObject:[subURL.lastPathComponent substringFromIndex:3]];
			}
		}
	}
	if (!sectionNames.count) {
		return completion (NO);
	}
	
	dispatch_group_t const group = dispatch_group_create ();
	self.progress.totalUnitCount = sectionNames.count;
	for (NSString *sectionName in sectionNames) {
		KBSectionUpdateTask *const task = [[KBSectionUpdateTask alloc] initWithPrefix:self.prefix sectionName:sectionName targetQueue:_targetQueue];
		[self.progress addChild:task.progress withPendingUnitCount:1];
		dispatch_group_enter (group);
		[task runWithCompletion:^{ dispatch_group_leave (group); }];
	}
	
	dispatch_group_notify (group, self.queue, ^{
		[self.context performBlock:^{
			BOOL const result = !!self.prefix.documents.count;
			self.prefix.generationIdentifier = currentGenerationID;
			completion (result);
		}];
	});
}

@end

@interface KBSectionUpdateTask ()

@property (nonatomic, readonly) dispatch_queue_t queue;
@property (nonatomic, readonly) NSManagedObjectContext *context;
@property (nonatomic, readonly) KBSection *section;

@end

@implementation KBSectionUpdateTask

@synthesize progress = _progress, context = _context;

- (instancetype) init {
	return [self initWithPrefix:nil sectionName:nil targetQueue:NULL];
}

- (instancetype) initWithPrefix: (KBPrefix *) prefix sectionName: (NSString *) sectionName targetQueue: (dispatch_queue_t) targetQueue {
	if (!(prefix && sectionName.length && targetQueue)) {
		return nil;
	}
	
	if (self = [super init]) {
		_progress = [NSProgress new];
		_progress.totalUnitCount = -1;
		_queue = dispatch_queue_create_with_target (NULL, dispatch_queue_attr_make_with_qos_class (DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, 0), targetQueue);
		_context = prefix.managedObjectContext;

		[self.context performBlockAndWait:^{
			_section = [prefix sectionNamed:sectionName createIfNeeded:YES];
		}];
	}
	
	return self;
}

- (void) runWithCompletion: (void (^)(void)) completion {
	dispatch_async (self.queue, ^{
		__block NSURL *sectionURL;
		__block NSURLGenerationIdentifier generationID;
		__block NSString *sectionName;
		[self.context performBlockAndWait:^{
			sectionURL = self.section.URL;
			generationID = self.section.generationIdentifier;
			sectionName = self.section.name;
		}];
		[self updateSectionWithURL:sectionURL name:sectionName generationID:generationID completion:^(BOOL result) {
			result ? (void) 0 : [self.context performBlockAndWait:^{ [self.context deleteObject:self.section]; }];
			completion ();
		}];
	});
}

- (void) updateSectionWithURL: (NSURL *) url name: (NSString *) sectionName generationID: (NSURLGenerationIdentifier) knownGenerationID completion: (void (^) (BOOL)) completion {
	NSArray <NSURLResourceKey> *const keys = [NSURL.readableDirectoryKeys arrayByAddingObject:NSURLGenerationIdentifierKey];
	NSDictionary <NSURLResourceKey, id> *const sectionProps = [url resourceValuesForKeys:keys error:NULL];
	if (!sectionProps.readableDirectory) {
		return completion (NO);
	}
	
	NSURLGenerationIdentifier const currentGenerationID = sectionProps [NSURLGenerationIdentifierKey];
	BOOL const sectionGenerationUpdated = ![currentGenerationID isEqual:knownGenerationID];
	[self.context performBlock:^{
		NSUInteger const documentsCount = self.section.documents.count;
		NSMutableSet <NSString *> *addedDocumentTitles, *removedDocumentTitles;
		NSMutableDictionary <NSString *, KBDocument *> *documentsByTitle;
		if (sectionGenerationUpdated) {
			NSArray <KBDocument *> *const documents = self.section.documents.allObjects;
			NSArray <NSString *> *const titles = [documents valueForKey:@"title"];
			addedDocumentTitles = [NSMutableSet new];
			removedDocumentTitles = titles.count ? [[NSMutableSet alloc] initWithArray:titles] : [NSMutableSet new];
			documentsByTitle = documents.count ? [[NSMutableDictionary alloc] initWithObjects:documents forKeys:titles] : [NSMutableDictionary new];
		}
		
		dispatch_async (self.queue, ^{
			if (sectionGenerationUpdated) {
				NSFileManager *const mgr = [NSFileManager defaultManager];
				NSArray <NSURLResourceKey> *const keys = [NSURL.readableRegularFileKeys arrayByAddingObject:NSURLGenerationIdentifierKey];
				NSDirectoryEnumerator *const enumerator = [mgr enumeratorAtURL:url includingPropertiesForKeys:keys options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:NULL];
				for (NSURL *subURL in enumerator) {
					if (![subURL.pathExtension isEqualToString:sectionName]) { continue; }
					NSString *const title = [subURL URLByDeletingPathExtension].lastPathComponent;
					if ([removedDocumentTitles containsObject:title]) {
						[removedDocumentTitles removeObject:title];
					} else {
						[addedDocumentTitles addObject:title];
					}
				}
			}
			
			NSUInteger const totalCount = self.progress.totalUnitCount = documentsCount + removedDocumentTitles.count + 2 * addedDocumentTitles.count;
			if (!totalCount) { return completion (NO); }
			NSUInteger const batchSize = MAX (25, totalCount / 25);
			[self.context performBlock:^{
				__block NSUInteger currentBatchSize = 0;
				void (^updateProgressIfNeeded) (void) = ^{
					if (++currentBatchSize >= batchSize) {
						NSUInteger const completedUnitIncrement = currentBatchSize;
						dispatch_async (self.queue, ^{ self.progress.completedUnitCount += completedUnitIncrement; });
						currentBatchSize = 0;
					}
				};
				
				for (NSString *removedTitle in removedDocumentTitles) {
					[self.context deleteObject:documentsByTitle [removedTitle]];
					updateProgressIfNeeded ();
				}
				for (NSString *addedTitle in addedDocumentTitles) {
					KBDocument *const document = [[KBDocument alloc] initWithContext:self.context];
					document.section = self.section;
					document.title = addedTitle;
					updateProgressIfNeeded ();
				}
				for (KBDocument *document in self.section.documents) {
					NSURLGenerationIdentifier currentGenerationID;
					[document.URL getResourceValue:&currentGenerationID forKey:NSURLGenerationIdentifierKey error:NULL];
					document.generationIdentifier = currentGenerationID;
					updateProgressIfNeeded ();
				}
				self.section.generationIdentifier = currentGenerationID;
				dispatch_async (self.queue, ^{
					self.progress.completedUnitCount = self.progress.totalUnitCount;
					completion (YES);
				});
			}];
		});
	}];
}

@end

@implementation NSDictionary (resourceValues)

- (BOOL) isReadableRegularFile {
	return [self checkResourceValuesForKeys:NSURL.readableRegularFileKeys];
}

- (BOOL) isReadableDirectory {
	return [self checkResourceValuesForKeys:NSURL.readableDirectoryKeys];
}

- (BOOL) checkResourceValuesForKeys: (NSArray <NSURLResourceKey> *) keys {
	for (NSURLResourceKey key in keys) {
		if (![[self objectForKey:key] boolValue]) {
			return NO;
		}
	}
	return YES;
}

@end

@implementation NSURL (convenience)

+ (NSArray <NSURLResourceKey> *) readableRegularFileKeys {
	static NSArray <NSURLResourceKey> *readableRegularFileKeys = nil;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		readableRegularFileKeys = [[NSArray alloc] initWithObjects:NSURLIsReadableKey, NSURLIsRegularFileKey, nil];
	});
	return readableRegularFileKeys;
}

+ (NSArray <NSURLResourceKey> *) readableDirectoryKeys {
	static NSArray <NSURLResourceKey> *readableDirectoryKeys = nil;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		readableDirectoryKeys = [[NSArray alloc] initWithObjects:NSURLIsReadableKey, NSURLIsDirectoryKey, NSURLIsExecutableKey, nil];
	});
	return readableDirectoryKeys;
}

- (BOOL) isReadableRegularFile {
	return [self isReadableRegularFile:NULL];
}

- (BOOL) isReadableDirectory {
	return [self isReadableDirectory:NULL];
}

- (BOOL) isReadableRegularFile: (NSError *__autoreleasing *) error {
	return [self checkResourceValuesForKeys:self.class.readableRegularFileKeys error:error];
}

- (BOOL) isReadableDirectory: (NSError *__autoreleasing *) error {
	return [self checkResourceValuesForKeys:self.class.readableDirectoryKeys error:error];
}

- (BOOL) checkResourceValuesForKeys: (NSArray <NSURLResourceKey> *) keys error: (NSError *__autoreleasing *) error {
	return [[self resourceValuesForKeys:keys error:error] checkResourceValuesForKeys:keys];
}

@end

@implementation KBPrefixUpdateHeuristic

@synthesize name = _name, requestedURLs = _requestedURLs;

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
		};
		allHeuristics = [[NSSet alloc] initWithObjects:heuristics count:sizeof (heuristics) / sizeof (id)];
	});
	return allHeuristics;
}

- (instancetype) init {
	return [self initWithName:nil requestedURLs:nil];
}

- (instancetype) initWithName: (NSString *) name requestedURLs: (NSURL *) url, ... NS_REQUIRES_NIL_TERMINATION {
	if (!(name && url)) {
		return nil;
	}
	if (self = [super init]) {
		_name = [name copy];
		
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
		
		_requestedURLs = [[NSSet alloc] initWithObjects:urls count:urlsEnd - urls];
		if (urls != stackURLs) {
			free (urls);
		}
	}
	return self;
}

@end
