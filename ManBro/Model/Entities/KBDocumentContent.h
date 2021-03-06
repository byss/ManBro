//
//  KBDocumentContent.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/17/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentMeta.h"

NS_ASSUME_NONNULL_BEGIN

@class KBDocumentTOCItem;
@interface KBDocumentContent: KBFilesystemObject

@property (nullable, nonatomic, copy) NSData *html;
@property (nullable, nonatomic, strong) KBDocumentTOCItem *toc;
@property (nonatomic, strong) KBDocumentMeta *meta;

- (instancetype) initWithHTML: (NSData *) html meta: (KBDocumentMeta *) meta;

- (KBDocumentTOCItem *) populateTOCUsingData: (id) tocData;

@end

NS_ASSUME_NONNULL_END
