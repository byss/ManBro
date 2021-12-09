//
//  KBDocumentLoading.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/8/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentLoading.h"

#import <AppKit/NSDataAsset.h>
#import <WebKit/WKURLSchemeTask.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "KBManPageTasks.h"
#import "NSPersistentContainer+sharedContainer.h"

@interface NSString (pathComponents)

- (NSString *) stringByAppendingPathComponents: (NSArray <NSString *> *) pathComponents;

@end

@implementation KBDocument (KBDocumentLoader)

- (NSURL *) loaderURI {
	NSManagedObjectID *const objectID = self.objectID;
	if (!objectID || objectID.temporaryID) { return nil; }
	NSURL *const objectURI = objectID.URIRepresentation;
	NSURLComponents *const result = [NSURLComponents new];
	result.scheme = KBDocumentBodyLoader.scheme;
	result.host = objectURI.scheme;
	NSMutableArray *const pathComponents = [objectURI.pathComponents mutableCopy];
	if ([pathComponents.firstObject isEqualToString:@"/"]) {
		[pathComponents removeObjectAtIndex:0];
	}
	[pathComponents insertObject:objectURI.host atIndex:0];
	result.path = [@"/" stringByAppendingPathComponents:pathComponents];
	return result.URL;
}

@end

@interface KBBundledData: NSObject

@property (nonatomic, readonly) NSArray <NSData *> *chunks;
@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) NSError *error;
@property (nonatomic, readonly) UTType *typeIdentifier;

- (instancetype) initWithType: (UTType *) typeIdentifier error: (NSError *) error NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithType: (UTType *) typeIdentifier chunks: (NSData *) firstChunk, ... NS_DESIGNATED_INITIALIZER NS_REQUIRES_NIL_TERMINATION;
- (instancetype) initWithError: (NSError *) error;
- (instancetype) initWithType: (UTType *) typeIdentifier data: (NSData *) data;
- (instancetype) initWithAssetName: (NSDataAssetName) name;

@end

@interface KBDocumentLoader (loading)

@property (nonatomic, readonly, class) UTType *defaultTypeIdentifier;

- (void) loadDataForURL: (NSURL *) url completion: (void (^) (KBBundledData *result)) completion;
- (void) loadDataForURL: (NSURL *) url isCancelled: (BOOL (^) (void)) isCancelledBlock completion: (void (^) (KBBundledData *result)) completion;

@end

@implementation KBDocumentBodyLoader: KBDocumentLoader

+ (NSString *) scheme { return @"manbro-doc"; }
+ (UTType *) defaultTypeIdentifier { return UTTypeHTML; }

- (void) loadDataForURL: (NSURL *) url isCancelled: (BOOL (^)()) isCancelledBlock completion: (void (^) (KBBundledData *)) completion {
	static KBBundledData *const preHTML = [[KBBundledData alloc] initWithAssetName:@"doc-html-pre"];
	if (preHTML.error) { return completion (preHTML); }
	static KBBundledData *const postHTML = [[KBBundledData alloc] initWithAssetName:@"doc-html-post"];
	if (postHTML.error) { return completion (postHTML); }
	
	NSError *error = nil;
	NSManagedObjectID *const objectID = [self objectIDForURL:url error:&error];
	if (!objectID) {
		return completion ([[KBBundledData alloc] initWithError:error]);
	}
	
	NSPersistentContainer *const container = [NSPersistentContainer sharedContainer];
	[container performBackgroundTask:^(NSManagedObjectContext *ctx) {
		if (isCancelledBlock ()) { return; }
		KBDocument *const document = [ctx objectWithID:objectID];
		if (document.html) {
			return completion ([[KBBundledData alloc] initWithType:UTTypeHTML chunks:preHTML.data, document.html, postHTML.data, nil]);
		}
		
		KBGenerateHTMLTask *const task = [[KBGenerateHTMLTask alloc] initWithInputFileURL:document.URL];
		[task startWithCompletion:^(NSData *result, NSError *error) {
			if (isCancelledBlock ()) { return; }
			if (error) {
				return completion ([[KBBundledData alloc] initWithError:error]);
			}
			[container performBackgroundTask:^(NSManagedObjectContext *ctx) {
				KBDocument *const document = [ctx objectWithID:objectID];
				document.html = result;
				NSError *error = nil;
				[ctx save:&error];

				if (isCancelledBlock ()) { return; }
				if (error) {
					return completion ([[KBBundledData alloc] initWithError:error]);
				}
				
				completion ([[KBBundledData alloc] initWithType:UTTypeHTML chunks:preHTML.data, result, postHTML.data, nil]);
			}];
		}];
	}];
}

- (NSManagedObjectID *) objectIDForURL: (NSURL *) url error: (NSError *__strong *) error {
	NSURLComponents *const result = [NSURLComponents new];
	result.scheme = url.host;
	NSMutableArray <NSString *> *const pathComponents = [url.pathComponents mutableCopy];
	if ([pathComponents.firstObject isEqualToString:@"/"]) {
		[pathComponents removeObjectAtIndex:0];
	}
	result.host = pathComponents.firstObject ?: @"";
	if (pathComponents.count) {
		[pathComponents removeObjectAtIndex:0];
	}
	result.path = [@"/" stringByAppendingPathComponents:pathComponents];
	NSURL *const objectURI = [result URL];
	if (!objectURI) {
		NSMutableString *failedString = [url.absoluteString mutableCopy];
		if ([failedString hasPrefix:self.class.scheme]) {
			[failedString deleteCharactersInRange:NSMakeRange (0, self.class.scheme.length)];
		}
		if ([failedString hasPrefix:@"://"]) {
			[failedString deleteCharactersInRange:NSMakeRange (0, 3)];
		}
		NSUInteger const firstSlashIdx = [failedString rangeOfString:@"/"].location;
		if (firstSlashIdx != NSNotFound) {
			[failedString replaceCharactersInRange:NSMakeRange (firstSlashIdx, 1) withString:@"://"];
		}
		*error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:@{NSURLErrorFailingURLStringErrorKey: failedString}];
		return nil;
	}
	NSPersistentContainer *const container = [NSPersistentContainer sharedContainer];
	NSManagedObjectID *const objectID = [container.persistentStoreCoordinator managedObjectIDForURIRepresentation:objectURI];
	if (!objectID) {
		*error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:@{NSURLErrorFailingURLErrorKey: objectURI}];
	}
	return objectID;
}

@end

@implementation KBDocumentBundledResourceLoader: KBDocumentLoader

+ (NSString *) scheme { return @"manbro-res"; }

- (void) loadDataForURL: (NSURL *) url completion: (void (^)(KBBundledData *)) completion {
	completion ([[KBBundledData alloc] initWithAssetName:url.host]);
}

@end

@interface KBDocumentLoader () {
	NSMutableSet <id <WKURLSchemeTask>> *_currentTasks;
}

@property (nonatomic, readonly) NSSet <id <WKURLSchemeTask>> *currentTasks;

- (BOOL) isTaskCancelled: (id <WKURLSchemeTask>) task;

@end

@implementation KBDocumentLoader

@dynamic scheme;

@synthesize currentTasks = _currentTasks;

+ (UTType *) defaultTypeIdentifier { return UTTypeData; }


- (instancetype) init {
	if (self = [super init]) {
		_currentTasks = [NSMutableSet new];
	}
	return self;
}

- (void) webView: (nonnull WKWebView *) webView startURLSchemeTask: (nonnull id <WKURLSchemeTask>) urlSchemeTask {
	@synchronized (_currentTasks) {
		[_currentTasks addObject:urlSchemeTask];
	}
	[self loadDataForURL:urlSchemeTask.request.URL isCancelled:^{ return [self isTaskCancelled:urlSchemeTask]; } completion:^(KBBundledData *result) {
		if (![self isTaskCancelled:urlSchemeTask]) {
			if (result.error) {
				[urlSchemeTask didFailWithError:result.error];
			} else {
				UTType *const typeID = result.typeIdentifier ?: self.class.defaultTypeIdentifier;
				NSInteger const length = [[result.chunks valueForKeyPath:@"@sum.length"] integerValue];
				NSURLResponse *const response = [[NSURLResponse alloc] initWithURL:urlSchemeTask.request.URL MIMEType:typeID.preferredMIMEType expectedContentLength:length textEncodingName:[typeID conformsToType:UTTypeText] ? @"utf-8" : nil];
				[urlSchemeTask didReceiveResponse:response];
				for (NSData *chunk in result.chunks) {
					[urlSchemeTask didReceiveData:chunk];
				}
				[urlSchemeTask didFinish];
			}
		}
	}];
}

- (void) webView: (nonnull WKWebView *) webView stopURLSchemeTask: (nonnull id <WKURLSchemeTask>) urlSchemeTask {
	@synchronized (_currentTasks) {
		[_currentTasks removeObject:urlSchemeTask];
	}
	[urlSchemeTask didFailWithError:[[NSError alloc] initWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
}

- (BOOL) isTaskCancelled: (id <WKURLSchemeTask>) task {
	@synchronized (self.currentTasks) {
		return ![self.currentTasks containsObject:task];
	}
}

- (void) loadDataForURL: (NSURL *) url isCancelled: (BOOL (^) (void)) isCancelledBlock completion: (void (^) (KBBundledData *result)) completion {
	[self loadDataForURL:url completion:completion];
}

@end

@implementation KBBundledData {
	id _result;
}

@dynamic chunks, data, error;

- (NSArray <NSData *> *) chunks { return [_result isKindOfClass:[NSArray class]] ? _result : (self.data ? @[self.data] : nil); }
- (NSData *) data { return [_result isKindOfClass:[NSData class]] ? _result : nil; }
- (NSError *) error { return [_result isKindOfClass:[NSError class]] ? _result : nil; }

- (instancetype) init { return [self initWithAssetName:(id __nonnull) nil]; }

- (instancetype) initWithType: (UTType *) typeIdentifier chunks: (NSData *) firstChunk, ... {
	if (!firstChunk) { return nil; }
	
	id result;
	va_list args;
	va_start (args, firstChunk);
	if (NSData *const secondChunk = va_arg (args, NSData *)) {
		NSMutableArray <NSData *> *chunks = [[NSMutableArray alloc] initWithObjects:[firstChunk copy], [secondChunk copy], nil];
		for (NSData *chunk; (chunk = va_arg (args, NSData *)); [chunks addObject:[chunk copy]]);
		result = chunks;
	} else {
		result = firstChunk;
	}
	va_end (args);
	
	if (self = [super init]) {
		_typeIdentifier = typeIdentifier;
		_result = result;
	}
	
	return self;
}

- (instancetype) initWithType: (UTType *) typeIdentifier error: (NSError *) error {
	if (self = [super init]) {
		_typeIdentifier = typeIdentifier;
		_result = error;
	}
	return self;
}

- (instancetype) initWithError: (NSError *) error {
	return [self initWithType:nil error:error];
}

- (instancetype) initWithType: (UTType *) typeIdentifier data: (NSData *) data {
	return [self initWithType:typeIdentifier chunks:data, nil];
}

- (instancetype) initWithAssetName: (NSDataAssetName) name {
	if (!name.length) { return nil; }
	
	NSDataAsset *const asset = [[NSDataAsset alloc] initWithName:name];
	if (asset) {
		return [self initWithType:[UTType typeWithIdentifier:asset.typeIdentifier] data:asset.data];
	} else {
		NSString *const assetPath = [[NSString alloc] initWithFormat:@"<Assets>/%@", name];
		NSError *const error = [[NSError alloc] initWithDomain:NSCocoaErrorDomain code:NSFileReadNoSuchFileError userInfo:@{NSFilePathErrorKey: assetPath}];
		return [self initWithError:error];
	}
}

@end

@implementation NSString (pathComponents)

- (NSString *) stringByAppendingPathComponents: (NSArray<NSString *> *) pathComponents {
	NSString *result = self;
	for (NSString *component in pathComponents) {
		result = [result stringByAppendingPathComponent:component];
	}
	return result;
}

@end
