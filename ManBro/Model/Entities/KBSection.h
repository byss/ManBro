//
//  KBSection.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/30/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBFilesystemObject.h"

NS_ASSUME_NONNULL_BEGIN

@class KBPrefix;
@class KBDocumentMeta;
@interface KBSection: KBFilesystemObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSSet <KBDocumentMeta *> *documents;
@property (nonatomic, strong) KBPrefix *prefix;

+ (KBSection *__nullable) fetchSectionNamed: (NSString *) sectionName prefix: (KBPrefix *) prefix createIfNeeded: (BOOL) createIfNeeded;

@end

NS_ASSUME_NONNULL_END
