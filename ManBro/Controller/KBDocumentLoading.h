//
//  KBDocumentLoading.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/8/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import <WebKit/WKURLSchemeHandler.h>

#import "KBDocument.h"

NS_ASSUME_NONNULL_BEGIN

@interface KBDocumentLoader: NSObject <WKURLSchemeHandler>

@property (nonatomic, readonly, class) NSString *scheme;

@end

@interface KBDocument (KBDocumentLoader)

@property (nonatomic, readonly, nullable) NSURL *loaderURI;

@end

@interface KBDocumentBodyLoader: KBDocumentLoader
@end

@interface KBDocumentBundledResourceLoader: KBDocumentLoader
@end

NS_ASSUME_NONNULL_END
