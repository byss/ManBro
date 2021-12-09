//
//  KBDocument.h
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "KBFilesystemObject.h"

NS_ASSUME_NONNULL_BEGIN

@class KBSection;
@class KBPrefix;
@interface KBDocument: KBFilesystemObject

@property (nullable, nonatomic, retain) NSData *html;
@property (nonatomic, copy) NSString *title;

@property (nonatomic, retain) KBSection *section;
@property (nonatomic, readonly) KBPrefix *prefix;

+ (KBDocument *__nullable) fetchDocumentNamed: (NSString *) documentTitle section: (KBSection *) section createIfNeeded: (BOOL) createIfNeeded;

@end

NS_ASSUME_NONNULL_END
