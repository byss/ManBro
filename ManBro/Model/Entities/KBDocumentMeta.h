//
//  KBDocumentMeta.h
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "KBFilesystemObject.h"

NS_ASSUME_NONNULL_BEGIN

@class KBSection;
@class KBPrefix;
@class KBDocumentContent;
@class KBDocumentTOCItem;
@interface KBDocumentMeta: KBFilesystemObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *filename;

@property (nonatomic, strong) KBSection *section;
@property (nonatomic, readonly) KBPrefix *prefix;

@property (nonatomic, readonly, nullable) NSData *html;
@property (nonatomic, readonly, nullable) KBDocumentTOCItem *toc;

+ (instancetype __nullable) fetchDocumentNamed: (NSString *) documentTitle section: (KBSection *) section;

- (KBDocumentContent *) setContentHTML: (NSData *) contentHTML;
- (KBDocumentTOCItem *) populateTOCUsingData: (id) tocData;

@end

NS_ASSUME_NONNULL_END
