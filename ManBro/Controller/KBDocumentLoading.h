//
//  KBDocumentLoading.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/8/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import <WebKit/WKURLSchemeHandler.h>

#import "KBDocumentMeta.h"

NS_ASSUME_NONNULL_BEGIN

@interface KBDocumentLoader: NSObject <WKURLSchemeHandler>

@property (nonatomic, readonly, class) NSString *scheme;

@end

@interface KBDocumentMeta (KBDocumentLoader)

@property (nonatomic, readonly, nullable) NSURL *loaderURI;
@property (nonatomic, readonly) NSString *presentationTitle;

+ (NSManagedObjectID *__nullable) objectIDWithLoaderURI: (NSURL *) loaderURI error: (NSError *__autoreleasing *__nullable) error;

- (instancetype __nullable) initWithLoaderURI: (NSURL *) loaderURI context: (NSManagedObjectContext *) context;

@end

@interface KBDocumentBodyLoader: KBDocumentLoader
@end

@interface KBDocumentBundledResourceLoader: KBDocumentLoader
@end

extern NSString *const KBManScheme;

@interface KBManSchemeURLResolver: NSObject

@property (nonatomic, readonly) BOOL appIsDefaultManURLHandler;

+ (instancetype) sharedResolver;

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype) init NS_UNAVAILABLE;

- (void) setDefaultManURLHandlerWithCompletion: (void (^)(NSError *)) completion;
- (void) resolveManURL: (NSURL *) url relativeToDocumentURL: (NSURL *__nullable) documentURL completion: (void (^) (NSURL *__nullable, NSError *__nullable)) completion;

@end

NS_ASSUME_NONNULL_END
