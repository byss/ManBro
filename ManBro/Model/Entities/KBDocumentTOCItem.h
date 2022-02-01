//
//  KBDocumentTOCItem.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/26/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@class KBDocumentMeta, KBDocumentContent;
@interface KBDocumentTOCItem: NSManagedObject

@property (nonatomic, copy) NSString *anchor;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong, nullable) KBDocumentContent *content;
@property (nonatomic, strong, nullable) KBDocumentTOCItem *parent;
@property (nonatomic, strong) NSOrderedSet <KBDocumentTOCItem *> *children;

@property (nonatomic, readonly) KBDocumentMeta *document;
@property (nonatomic, readonly) BOOL hasChildren;
@property (nonatomic, readonly) NSUInteger level;

- (instancetype) initRootItemWithContent: (KBDocumentContent *) content;

- (void) populateChildrenUsingData: (id) tocData;

@end

NS_ASSUME_NONNULL_END
