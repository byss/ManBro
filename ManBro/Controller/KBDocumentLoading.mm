//
//  KBDocumentLoading.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/8/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentLoading.h"

#import <AppKit/NSDataAsset.h>
#import <AppKit/NSWorkspace.h>
#import <WebKit/WKURLSchemeTask.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "KBPrefix.h"
#import "KBSection.h"
#import "KBManPageTasks.h"
#import "KBSearchManager.h"
#import "NSError+convenience.h"
#import "NSPersistentContainer+sharedContainer.h"

@interface NSString (pathComponents)

- (NSString *) stringByAppendingPathComponents: (NSArray <NSString *> *) pathComponents;

@end

@interface KBBundledData: NSObject

@property (nonatomic, readonly) NSArray <NSData *> *chunks;
@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) NSError *error;
@property (nonatomic, readonly) UTType *typeIdentifier;

- (instancetype) initWithType: (UTType *) typeIdentifier error: (NSError *) error NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithType: (UTType *) typeIdentifier arguments: (va_list) arguments NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithType: (UTType *) typeIdentifier, ...  NS_REQUIRES_NIL_TERMINATION;
- (instancetype) initWithError: (NSError *) error;
- (instancetype) initWithType: (UTType *) typeIdentifier data: (NSData *) data;
- (instancetype) initWithAssetName: (NSDataAssetName) name;

@end

@interface KBDocumentLoader (loading)

@property (nonatomic, readonly, class) UTType *defaultTypeIdentifier;

- (void) loadDataForURL: (NSURL *) url completion: (void (^) (KBBundledData *result)) completion;
- (void) loadDataForURL: (NSURL *) url isCancelled: (BOOL (^) (void)) isCancelledBlock completion: (void (^) (KBBundledData *result)) completion;
- (void) loadDataForURL: (NSURL *) url isCancelled: (BOOL (^) (void)) isCancelledBlock completionWithResponse: (void (^) (NSURLResponse *response, KBBundledData *result)) completion;

@end

@implementation KBManSchemeURLResolver

+ (instancetype) sharedResolver {
	static KBManSchemeURLResolver *sharedResolver;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{ sharedResolver = [[self alloc] initPrivate]; });
	return sharedResolver;
}

- (instancetype) init { return nil; }

- (instancetype) initPrivate { return [super init]; }

- (BOOL) appIsDefaultManURLHandler {
	NSURLComponents *const comps = [NSURLComponents new];
	comps.scheme = KBManScheme;
	comps.host = @"";
	comps.path = @"/";
	return [[[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:comps.URL] isEqual:[NSBundle mainBundle].bundleURL];
}

- (void) setDefaultManURLHandlerWithCompletion: (void (^)(NSError *)) completion {
	if (@available (macOS 12.0, *)) {
		[[NSWorkspace sharedWorkspace] setDefaultApplicationAtURL:[NSBundle mainBundle].bundleURL toOpenURLsWithScheme:KBManScheme completionHandler:completion];
	} else {
		OSStatus const result = LSSetDefaultHandlerForURLScheme ((__bridge CFStringRef) KBManScheme, (__bridge CFStringRef) [NSBundle mainBundle].bundleIdentifier);
		completion (result ? [[NSError alloc] initWithDomain:NSOSStatusErrorDomain code:result userInfo:nil] : nil);
	}
}

- (void) resolveManURL: (NSURL *) url relativeToDocumentURL: (NSURL *) documentURL completion: (void (^)(NSURL *, NSError *)) completion {
	if (![url.scheme isEqualToString:KBManScheme]) { return completion (nil, [[NSError alloc] initUnsupportedURLErrorWithFailingURL:url]); }

	NSArray <NSString *> *const pathComponents = url.pathComponents;
	NSString *documentTitle, *sectionName;
	if (pathComponents.count > 1) {
		sectionName = url.host;
		documentTitle = [[pathComponents subarrayWithRange:NSMakeRange (1, pathComponents.count - 1)] componentsJoinedByString:@"/"];
	} else {
		documentTitle = url.host;
	}
	if (!documentTitle.length) { return completion (nil, [[NSError alloc] initBadURLErrorWithFailingURL:url]); }
	
	NSPersistentContainer *const container = [NSPersistentContainer sharedContainer];
	NSManagedObjectID *documentID = nil;
	if (documentURL) {
		NSError *documentError;
		documentID = [KBDocumentMeta objectIDWithLoaderURI:documentURL error:&documentError];
		if (!documentID) { return completion (nil, documentError); }
	}

	[container performBackgroundTask:^(NSManagedObjectContext *context) {
		KBSearchManager *const searchMgr = [[KBSearchManager alloc] initWithContext:context];
		NSURL *redirectURL = [self fetchDocumentTitled:documentTitle inSectionNamed:sectionName forRefererID:documentID searchManager:searchMgr];
		if (!redirectURL) { redirectURL = [self fetchDocumentTitled:documentTitle inSectionNamed:sectionName searchManager:searchMgr]; }
		if (redirectURL) {
			return completion (redirectURL, nil);
		} else {
			return completion (nil, [[NSError alloc] initResourceUnavailableErrorWithFailingURL:url]);
		}
	}];
}

- (NSURL *) fetchDocumentTitled: (NSString *) documentTitle inSectionNamed: (NSString *) sectionName forRefererID: (NSManagedObjectID *) refererID searchManager: (KBSearchManager *) searchManager {
	if (!refererID) { return nil; }
	KBDocumentMeta *const referer = [searchManager.context existingObjectWithID:refererID error:NULL];
	if (!referer) { return nil; }
	
	KBMutableSearchQuery *const query = [[KBMutableSearchQuery alloc] initWithText:documentTitle];
	KBPrefix *const prefix = referer.prefix;
	if (sectionName.length) {
		KBSection *const section = [prefix sectionNamed:sectionName createIfNeeded:NO];
		if (!section) { return nil; }
		query.sections = [[NSSet alloc] initWithObjects:section, nil];
	} else {
		query.prefixes = [[NSSet alloc] initWithObjects:prefix, nil];
	}
	return [self searchManager:searchManager loaderURLForDocumentBestMatchingQuery:query];
}

- (NSURL *) fetchDocumentTitled: (NSString *) documentTitle inSectionNamed: (NSString *) sectionName searchManager: (KBSearchManager *) searchManager {
	KBMutableSearchQuery *const query = [[KBMutableSearchQuery alloc] initWithText:documentTitle];
	if (sectionName.length) {
		NSArray <KBSection *> *const sections = [KBSection fetchSectionsNamed:sectionName inContext:searchManager.context];
		if (!sections.count) { return nil; }
		query.sections = [[NSSet alloc] initWithArray:sections];
	}
	return [self searchManager:searchManager loaderURLForDocumentBestMatchingQuery:query];
}

- (NSURL *) searchManager: (KBSearchManager *) searchManager loaderURLForDocumentBestMatchingQuery: (KBMutableSearchQuery *) query {
	query.partialMatchingAllowed = NO;
	KBDocumentMeta *const bestMatch = [searchManager fetchDocumentsMatchingQuery:query].firstObject.objects.firstObject;
	return bestMatch.loaderURI;
}

@end

@implementation KBDocumentBodyLoader

+ (NSString *) scheme { return @"manbro-doc"; }
+ (UTType *) defaultTypeIdentifier { return UTTypeHTML; }

- (void) loadDataForURL: (NSURL *) url isCancelled: (BOOL (^)()) isCancelledBlock completion: (void (^) (KBBundledData *)) completion {
	static KBBundledData *const preHTML = [[KBBundledData alloc] initWithAssetName:@"doc-html-pre"];
	if (preHTML.error) { return completion (preHTML); }
	static KBBundledData *const postHTML = [[KBBundledData alloc] initWithAssetName:@"doc-html-post"];
	if (postHTML.error) { return completion (postHTML); }
	
	NSError *error = nil;
	NSManagedObjectID *const objectID = [KBDocumentMeta objectIDWithLoaderURI:url error:&error];
	if (!objectID) { return completion ([[KBBundledData alloc] initWithError:error]); }
	
	NSPersistentContainer *const container = [NSPersistentContainer sharedContainer];
	[container performBackgroundTask:^(NSManagedObjectContext *ctx) {
		if (isCancelledBlock ()) { return; }
		KBDocumentMeta *const document = [ctx objectWithID:objectID];
		if (document.html) { return completion ([[KBBundledData alloc] initWithType:UTTypeHTML, preHTML.data, document.html, postHTML.data, nil]); }
		
		KBGenerateHTMLTask *const task = [[KBGenerateHTMLTask alloc] initWithInputFileURL:document.URL];
		[task startWithCompletion:^(NSData *bodyData, NSError *error) {
			if (isCancelledBlock ()) { return; }
			if (error) { return completion ([[KBBundledData alloc] initWithError:error]); }
			[ctx performBlock:^{
				[document setContentHTML:bodyData];
				NSError *error = nil;
				[ctx save:&error];

				if (isCancelledBlock ()) { return; }
				KBBundledData *const result = [KBBundledData alloc];
				completion (error ? [result initWithError:error] : [result initWithType:UTTypeHTML, preHTML.data, bodyData, postHTML.data, nil]);
			}];
		}];
	}];
}

@end

@implementation KBDocumentBundledResourceLoader

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
	[self loadDataForURL:urlSchemeTask.request.URL isCancelled:^{ return [self isTaskCancelled:urlSchemeTask]; } completionWithResponse:^(NSURLResponse *response, KBBundledData *result) {
		if ([self isTaskCancelled:urlSchemeTask]) { return; }
		if (result.error) { return [urlSchemeTask didFailWithError:result.error]; }
		[urlSchemeTask didReceiveResponse:response];
		if (result) {
			for (NSData *chunk in result.chunks) {
				[urlSchemeTask didReceiveData:chunk];
			}
			[urlSchemeTask didFinish];
		}
	}];
}

- (void) webView: (nonnull WKWebView *) webView stopURLSchemeTask: (nonnull id <WKURLSchemeTask>) urlSchemeTask {
	@synchronized (_currentTasks) {
		[_currentTasks removeObject:urlSchemeTask];
	}
	[urlSchemeTask didFailWithError:NSError.userCancelledError];
}

- (BOOL) isTaskCancelled: (id <WKURLSchemeTask>) task {
	@synchronized (self.currentTasks) {
		return ![self.currentTasks containsObject:task];
	}
}

- (void) loadDataForURL: (NSURL *) url isCancelled: (BOOL (^) (void)) isCancelledBlock completion: (void (^) (KBBundledData *result)) completion {
	[self loadDataForURL:url completion:completion];
}

- (void) loadDataForURL: (NSURL *) url isCancelled: (BOOL (^)(void)) isCancelledBlock completionWithResponse: (void (^) (NSURLResponse *, KBBundledData *)) completion {
	[self loadDataForURL:url isCancelled:isCancelledBlock completion:^(KBBundledData *result) {
		if (result.error) { return completion (nil, result); }
		
		UTType *const typeID = result.typeIdentifier ?: self.class.defaultTypeIdentifier;
		NSInteger const length = [[result.chunks valueForKeyPath:@"@sum.length"] integerValue];
		NSString *const textEncodingName = [typeID conformsToType:UTTypeText] ? @"utf-8" : nil;
		completion ([[NSURLResponse alloc] initWithURL:url MIMEType:typeID.preferredMIMEType expectedContentLength:length textEncodingName:textEncodingName], result);
	}];
}

- (KBBundledData *) _newResultWithDummyArg: (nullptr_t) unused, ... {
	va_list args;
	va_start (args, unused);
	KBBundledData *const result = [[KBBundledData alloc] initWithType:self.class.defaultTypeIdentifier arguments:args];
	va_end (args);
	return result;
}

@end

@implementation KBDocumentMeta (KBDocumentLoader)

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

+ (NSManagedObjectID *) objectIDWithLoaderURI: (NSURL *) loaderURI error: (NSError *__autoreleasing *) error {
	NSString *const loaderURIScheme = KBDocumentBodyLoader.scheme;
	if (![loaderURI.scheme isEqualToString:loaderURIScheme]) {
		NSOutErr (error, [[NSError alloc] initUnsupportedURLErrorWithFailingURL:loaderURI]);
		return nil;
	}
	NSURLComponents *const result = [NSURLComponents new];
	result.scheme = loaderURI.host;
	NSMutableArray <NSString *> *const pathComponents = [loaderURI.pathComponents mutableCopy];
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
		NSMutableString *failedString = [loaderURI.absoluteString mutableCopy];
		if ([failedString hasPrefix:loaderURIScheme]) {
			[failedString deleteCharactersInRange:NSMakeRange (0, loaderURIScheme.length)];
		}
		if ([failedString hasPrefix:@"://"]) {
			[failedString deleteCharactersInRange:NSMakeRange (0, 3)];
		}
		NSUInteger const firstSlashIdx = [failedString rangeOfString:@"/"].location;
		if (firstSlashIdx != NSNotFound) {
			[failedString replaceCharactersInRange:NSMakeRange (firstSlashIdx, 1) withString:@"://"];
		}
		NSOutErr (error, [[NSError alloc] initBadURLErrorWithFailingURL:failedString]);
		return nil;
	}
	NSPersistentContainer *const container = [NSPersistentContainer sharedContainer];
	NSManagedObjectID *const objectID = [container.persistentStoreCoordinator managedObjectIDForURIRepresentation:objectURI];
	if (![objectID.entity isKindOfEntity:self.entity]) { NSOutErr (error, [[NSError alloc] initBadURLErrorWithFailingURL:objectURI]); }
	return objectID;
}

- (instancetype) initWithLoaderURI: (NSURL *) loaderURI context: (NSManagedObjectContext *) context {
	NSManagedObjectID *const objectID = [self.class objectIDWithLoaderURI:loaderURI error:NULL];
	return objectID ? [context objectWithID:objectID] : nil;
}

@end

@implementation KBBundledData {
	id _result;
}

@dynamic chunks, error;

- (NSArray <NSData *> *) chunks { return [_result isKindOfClass:[NSArray class]] ? _result : (self.data ? @[self.data] : nil); }
- (NSData *) data { return [_result isKindOfClass:[NSData class]] ? _result : nil; }
- (NSError *) error { return [_result isKindOfClass:[NSError class]] ? _result : nil; }

- (instancetype) init { return [self initWithAssetName:(id __nonnull) nil]; }

- (instancetype) initWithType: (UTType *) typeIdentifier arguments: (va_list) arguments {
	if (id result = va_arg (arguments, NSData *); self = [super init]) {
		_typeIdentifier = typeIdentifier;

		if (NSData *const secondChunk = va_arg (arguments, NSData *)) {
			NSMutableArray <NSData *> *const chunks = [[NSMutableArray alloc] initWithObjects:result, secondChunk, nil];
			for (NSData *chunk; (chunk = va_arg (arguments, NSData *)); [chunks addObject:chunk]);
			_result = [[NSArray alloc] initWithArray:chunks copyItems:YES];
		} else {
			_result = [result copy];
		}
		
		return self;
	} else {
		return nil;
	}
}

- (instancetype) initWithType: (UTType *) typeIdentifier, ... {
	va_list args;
	va_start (args, typeIdentifier);
	self = [self initWithType:typeIdentifier arguments:args];
	va_end (args);
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
	return [self initWithType:typeIdentifier, data, nil];
}

- (instancetype) initWithAssetName: (NSDataAssetName) name {
	if (!name.length) { return nil; }
	
	NSDataAsset *const asset = [[NSDataAsset alloc] initWithName:name];
	if (asset) {
		return [self initWithType:[UTType typeWithIdentifier:asset.typeIdentifier] data:asset.data];
	} else {
		return [self initWithError:[[NSError alloc] initFileReadNoSuchFileErrorWithPath:[[NSString alloc] initWithFormat:@"<Assets>/%@", name]]];
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

NSString *const KBManScheme = @"x-man-page";
