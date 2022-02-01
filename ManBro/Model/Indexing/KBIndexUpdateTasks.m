//
//  KBIndexUpdateTasks.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/17/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBIndexUpdateTasks.h"

#import "KBPrefix.h"
#import "KBSection.h"
#import "KBDocumentMeta.h"
#import "CoreData+logging.h"
#import "NSURL+filesystem.h"

NS_ASSUME_NONNULL_BEGIN

@interface KBIndexUpdateTask <__covariant ObjectType: KBFilesystemObject *> ()

@property (nonatomic, readonly, class) Class objectClass;
@property (nonatomic, readonly, class) BOOL needsSeparateContext;
@property (nonatomic, readonly) NSManagedObjectContext *context;
@property (nonatomic, readonly) ObjectType object;
@property (nonatomic, readonly) NSURL *objectURL;
@property (nonatomic, readonly) BOOL shouldDeleteObject;

@property (nonatomic, copy, nullable) NSURLGenerationIdentifier objectGenerationIdentifier;

- (instancetype) initWithUpdatedObject: (ObjectType) object NS_DESIGNATED_INITIALIZER;
- (instancetype) initCreatingObjectWithProperties: (NSDictionary <NSString *, id> *) objectProperties parentContext: (NSManagedObjectContext *) parentContext NS_DESIGNATED_INITIALIZER;

- (void) prepareForRunning;
- (void) addChildTask: (KBIndexUpdateTask *) childTask;
- (void) addAction: (dispatch_block_t) finalAction performInContext: (BOOL) performInContext;
- (void) addFinalAction: (dispatch_block_t) finalAction performInContext: (BOOL) performInContext;

@end

NS_ASSUME_NONNULL_END

@interface KBPrefixUpdateTask ()

- (instancetype) initWithUpdatedObject: (KBPrefix *) object NS_UNAVAILABLE;
- (instancetype) initCreatingObjectWithProperties: (NSDictionary <NSString *, id> *) objectProperties parentContext: (NSManagedObjectContext *) parentContext NS_UNAVAILABLE;

@end

@interface KBSectionUpdateTask ()

- (instancetype) initWithUpdatedObject: (KBPrefix *) object NS_UNAVAILABLE;
- (instancetype) initCreatingObjectWithProperties: (NSDictionary <NSString *, id> *) objectProperties parentContext: (NSManagedObjectContext *) parentContext NS_UNAVAILABLE;

@end

@interface KBDocumentUpdateTask ()

- (instancetype) initWithUpdatedObject: (KBPrefix *) object NS_UNAVAILABLE;
- (instancetype) initCreatingObjectWithProperties: (NSDictionary <NSString *, id> *) objectProperties parentContext: (NSManagedObjectContext *) parentContext NS_UNAVAILABLE;

@end

@implementation KBPrefixUpdateTask

+ (Class) objectClass { return [KBPrefix class]; }

- (instancetype) initWithPrefix: (KBPrefix *) prefix {
	return [super initWithUpdatedObject:prefix];
}

- (instancetype) initWithURL: (NSURL *) prefixURL source: (KBPrefixSource) source priority: (NSUInteger) priority context: (NSManagedObjectContext *) context {
	if (!(prefixURL.absoluteString.length && source && context)) { return nil; }
	return [super initCreatingObjectWithProperties:@{@"url": prefixURL, @"source": source, @"priority": @(priority)} parentContext:context];
}

- (void) prepareForRunning {
	__block NSSet <NSString *> *existingSectionNames;
	[self.context performBlockAndWait:^{
		existingSectionNames = [self.object.sections valueForKey:@"name"];
		for (KBSection *section in self.object.sections) {
			[self addChildTask:[[KBSectionUpdateTask alloc] initWithSection:section]];
		}
	}];
	NSURL *const url = self.objectURL;
	NSDictionary <NSURLResourceKey, id> *const prefixProps = [url resourceValuesForKeys:NSURL.readableDirectoryAndGenerationIdentifierKeys error:NULL];
	if (!prefixProps.readableDirectory) { return; }

	NSURLGenerationIdentifier const generationID = prefixProps [NSURLGenerationIdentifierKey];
	if (![self.objectGenerationIdentifier isEqual:generationID]) {
		self.objectGenerationIdentifier = generationID;

		NSFileManager *const mgr = [NSFileManager defaultManager];
		NSDirectoryEnumerator *const enumerator = [mgr enumeratorAtURL:url includingPropertiesForKeys:NSURL.readableDirectoryAndGenerationIdentifierKeys options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:NULL];
		for (NSURL *subURL in enumerator) {
			NSString *const sectionName = subURL.manSectionName;
			if (sectionName && ![existingSectionNames containsObject:sectionName]) {
				[self addChildTask:[[KBSectionUpdateTask alloc] initWithPrefix:self.object sectionName:sectionName]];
			}
		}
	}
}

@end

@implementation KBSectionUpdateTask

+ (Class) objectClass { return [KBSection class]; }

- (instancetype) initWithSection: (KBSection *) section {
	return [super initWithUpdatedObject:section];
}

- (instancetype) initWithPrefix: (KBPrefix *) prefix sectionName: (NSString *) sectionName {
	return (prefix && sectionName.length) ? [super initCreatingObjectWithProperties:@{@"prefix": prefix, @"name": sectionName} parentContext:prefix.managedObjectContext] : nil;
}

- (void) prepareForRunning {
	__block NSString *sectionName;
	__block NSSet <NSString *> *existingDocumentFilenames;
	[self.context performBlockAndWait:^{
		sectionName = self.object.name;
		existingDocumentFilenames = [self.object.documents valueForKey:@"filename"];
		for (KBDocumentMeta *document in self.object.documents) {
			[self addChildTask:[[KBDocumentUpdateTask alloc] initWithDocument:document]];
		}
	}];
	
	NSURL *const url = self.objectURL;
	NSURLGenerationIdentifier generationID;
	[url getResourceValue:&generationID forKey:NSURLGenerationIdentifierKey error:NULL];
	if (![generationID isEqual:self.objectGenerationIdentifier]) {
		self.objectGenerationIdentifier = generationID;

		NSFileManager *const mgr = [NSFileManager defaultManager];
		NSDirectoryEnumerator *const enumerator = [mgr enumeratorAtURL:url includingPropertiesForKeys:NSURL.readableRegularFileAndGenerationIdentifierKeys options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:NULL];
		for (NSURL *subURL in enumerator) {
			NSString *const filename = subURL.lastPathComponent;
			if (![existingDocumentFilenames containsObject:filename]) {
				[self addChildTask:[[KBDocumentUpdateTask alloc] initWithSection:self.object documentFilename:filename]];
			}
		}
	}
}

- (BOOL) shouldDeleteObject { return !self.object.documents.count; }

@end

@implementation KBDocumentUpdateTask {
	BOOL _success;
}

+ (Class) objectClass { return [KBDocumentMeta class]; }
+ (BOOL) needsSeparateContext { return NO; }

- (instancetype) initWithDocument: (KBDocumentMeta *) document {
	return [super initWithUpdatedObject:document];
}

- (instancetype) initWithSection: (KBSection *) section documentFilename: (NSString *) documentFilename {
	return [super initCreatingObjectWithProperties:@{@"section": section, @"filename": documentFilename} parentContext:section.managedObjectContext];
}

- (void) prepareForRunning {
	typeof (self) strongSelf = self;
	[strongSelf addAction:^{
		NSURL *const url = self.objectURL;
		NSDictionary <NSURLResourceKey, id> *const urlProps = [url.URLByResolvingSymlinksInPath resourceValuesForKeys:NSURL.readableRegularFileAndGenerationIdentifierKeys error:NULL];
		if (!urlProps.readableRegularFile) { return; }
		NSString *const documentTitle = url.manDocumentTitle;
		if ((self->_success = !!documentTitle)) {
			NSURLGenerationIdentifier const generationID = urlProps [NSURLGenerationIdentifierKey];
			[self.context performBlockAndWait:^{
				self.object.title = documentTitle;
				self.objectGenerationIdentifier = generationID;
			}];
		}
	} performInContext:NO];
}

- (BOOL) shouldDeleteObject { return !_success; }

@end

@implementation KBIndexUpdateTask {
	NSMutableArray <KBIndexUpdateTask *> *_childTasks;
	NSMutableArray <dispatch_block_t> *_actions;
	NSMutableArray <dispatch_block_t> *_finalActions;
	BOOL _running;
}

@dynamic objectClass;

@synthesize progress = _progress;

NS_INLINE void KBIndexUpdateTaskCommonInit (KBIndexUpdateTask *self, NSManagedObjectContext *parentContext, KBFilesystemObject *(^NS_NOESCAPE objectInitializer) (NSManagedObjectContext *)) {
	NSProgress *const progress = [NSProgress new];
	progress.totalUnitCount = -1;
	
	NSManagedObjectContext *const context = ({
		NSManagedObjectContext *result;
		if ([self.class needsSeparateContext]) {
			result = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
			result.parentContext = parentContext;
		} else {
			result = parentContext;
		}
		result;
	});
	
	__block NSURL *objectURL;
	__block KBFilesystemObject *object;
	__block NSURLGenerationIdentifier generationID;
	[context performBlockAndWait:^{
		object = objectInitializer (context);
		objectURL = object.URL;
		generationID = object.generationIdentifier;
#if DEBUG
		context.name = [[NSString alloc] initWithFormat:@"KBIndexManager: %@ %@", object.entity.name, object.URL.absoluteURL.fileSystemPath];
#endif
	}];
	
	self->_progress = progress;
	self->_context = context;
	self->_object = object;
	self->_objectURL = objectURL;
	self->_objectGenerationIdentifier = generationID;
}

+ (BOOL) needsSeparateContext { return YES; }

+ (dispatch_semaphore_t) runningTasksSemaphore {
	static dispatch_semaphore_t runningTasksSemaphore;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{ runningTasksSemaphore = dispatch_semaphore_create ([NSProcessInfo processInfo].processorCount * 2); });
	return runningTasksSemaphore;
}

+ (KBFilesystemObject *) createObjectWithProperties: (NSDictionary <NSString *, id> *) objectProperties inContext: (NSManagedObjectContext *) context {
	Class const objectClass = self.objectClass;
	NSEntityDescription *const entity = [objectClass entity];
	KBFilesystemObject *const result = [[objectClass alloc] initWithEntity:entity insertIntoManagedObjectContext:context];
	for (NSString *propertyName in objectProperties) {
		id const propertyValue = objectProperties [propertyName];
		if ([propertyValue isKindOfClass:[NSNull class]]) {
			[result setNilValueForKey:propertyName];
			continue;
		}
		
		NSRelationshipDescription *const relationship = entity.relationshipsByName [propertyName];
		if (relationship.toMany) {
			NSMutableArray *const objects = [[NSMutableArray alloc] initWithCapacity:[propertyValue count]];
			for (NSManagedObject *object in propertyValue) {
				[objects addObject:[context objectWithID:object.objectID]];
			}
			Class const collectionClass = relationship.isOrdered ? [NSOrderedSet class] : [NSSet class];
			[result setValue:[[collectionClass alloc] initWithArray:objects] forKey:propertyName];
		} else if (relationship) {
			[result setValue:[context objectWithID:[propertyValue objectID]] forKey:propertyName];
		} else {
			[result setValue:propertyValue forKey:propertyName];
		}
	}
	return result;
}

- (instancetype) init {
	return [self initWithUpdatedObject:(id __nonnull) nil];
}

- (instancetype) initWithUpdatedObject: (KBFilesystemObject *) object {
	if (!object) { return nil; }
	if (self = [super init]) {
		KBIndexUpdateTaskCommonInit (self, object.managedObjectContext, ^(NSManagedObjectContext *context) { return [context objectWithID:object.objectID]; });
	}
	return self;
}

- (instancetype) initCreatingObjectWithProperties: (NSDictionary <NSString *, id> *) objectProperties parentContext: (NSManagedObjectContext *) parentContext {
	if (!parentContext) { return nil; }
	if (self = [super init]) {
		KBIndexUpdateTaskCommonInit (self, parentContext, ^(NSManagedObjectContext *context) { return [self.class createObjectWithProperties:objectProperties inContext:context]; });
	}
	return self;
}

- (BOOL) shouldDeleteObject { return NO; }

- (void) addObject: (id) object toArray: (NSMutableArray *__strong *) array {
	NSAssert (!_running, @"%@ is already running", self);
	*array ? [*array addObject:object] : (*array = [[NSMutableArray alloc] initWithObjects:object, nil]);
}

- (void) addBlock: (dispatch_block_t) block toArray: (NSMutableArray <dispatch_block_t> *__strong *) array performInContext: (BOOL) performInContext {
	typeof (self) strongSelf = self;
	performInContext ? [strongSelf addBlock:^{ [self.context performBlockAndWait:block]; } toArray:array performInContext:NO] : [self addObject:block toArray:array];
}

- (void) addChildTask: (KBIndexUpdateTask *) childTask { [self addObject:childTask toArray:&_childTasks]; }
- (void) addAction: (dispatch_block_t) action performInContext: (BOOL) performInContext { [self addBlock:action toArray:&_actions performInContext:performInContext]; }
- (void) addFinalAction: (dispatch_block_t) action performInContext: (BOOL) performInContext { [self addBlock:action toArray:&_finalActions performInContext:performInContext]; }

- (void) runWithCompletion: (void (^)(void)) completion {
	if (self.class.needsSeparateContext) {
		__block NSString *name;
#if DEBUG
		[self.context performBlockAndWait:^{ name = self.context.name; }];
#endif
		dispatch_queue_t const queue = dispatch_queue_create (name.UTF8String, dispatch_queue_attr_make_with_qos_class (DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, QOS_CLASS_USER_INITIATED, 0));
		dispatch_async (queue, ^{ [self run]; });
		dispatch_async (queue, completion);
	} else {
		[self run];
		completion ();
	}
}

- (void) beginExecution {
	if (self.class.needsSeparateContext) {
		dispatch_semaphore_wait (self.class.runningTasksSemaphore, DISPATCH_TIME_FOREVER);
	}
}

- (void) endExecution {
	if (self.class.needsSeparateContext) {
		dispatch_semaphore_signal (self.class.runningTasksSemaphore);
	}
}

- (void) run {
	[self beginExecution];
	[self prepareForRunning];
	_running = YES;
	
	NSUInteger const childTasksCount = _childTasks.count, actionsCount = _actions.count + _finalActions.count, totalCount = childTasksCount + actionsCount;
	self.progress.totalUnitCount = totalCount ? (totalCount + 1) : 0;
	if (!totalCount) { return [self endExecution]; }

	for (KBIndexUpdateTask *task in _childTasks) {
		[self.progress addChild:task.progress withPendingUnitCount:1];
	}
	NSProgress *const actionsProgress = [NSProgress new];
	actionsProgress.totalUnitCount = actionsCount + 1;
	[self.progress addChild:actionsProgress withPendingUnitCount:actionsProgress.totalUnitCount];
		
	dispatch_group_t const group = dispatch_group_create ();
	for (KBIndexUpdateTask *task in _childTasks) {
		dispatch_group_enter (group);
		[task runWithCompletion:^{ dispatch_group_leave (group); }];
	}
	_childTasks = nil;
	
	for (dispatch_block_t action in _actions) {
		action ();
		actionsProgress.completedUnitCount++;
	}
	_actions = nil;
	[self endExecution];
	
	dispatch_group_wait (group, DISPATCH_TIME_FOREVER);
	
	[self beginExecution];
	for (dispatch_block_t finalAction in _finalActions) {
		finalAction ();
		actionsProgress.completedUnitCount++;
	}
	_finalActions = nil;
	
	[self.context performBlockAndWait:^{
		self.object.generationIdentifier = self.objectGenerationIdentifier;
		if (self.shouldDeleteObject) {
			[self.context deleteObject:self.object];
		}
		if (self.class.needsSeparateContext) {
			[self.context save];
		}
	}];
	actionsProgress.completedUnitCount++;
	[self endExecution];
}

- (void) prepareForRunning {}

@end
