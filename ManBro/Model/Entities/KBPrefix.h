//
//  KBPrefix.h
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "KBFilesystemObject.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString *KBPrefixSource NS_TYPED_EXTENSIBLE_ENUM;

extern KBPrefixSource const KBPrefixSourceManConfig;
extern KBPrefixSource const KBPrefixSourceHeuristic;
extern KBPrefixSource const KBPrefixSourceUser;

@class KBSection;
@class KBDocumentMeta;
@interface KBPrefix: KBFilesystemObject

@property (nonatomic, assign) NSUInteger priority;
@property (nonatomic, copy) KBPrefixSource source;
@property (nonatomic, copy) NSURL *URL;
@property (nonatomic, strong) NSSet <KBSection *> *sections;
@property (nonatomic, readonly) NSSet <KBDocumentMeta *> *documents;

+ (void) fetchInContext: (NSManagedObjectContext *) context completion: (void (^) (NSArray <KBPrefix *> *)) completion;
+ (KBPrefix *) fetchPrefixWithURL: (NSURL *) url createIfNeeded: (BOOL) createIfNeeded context: (NSManagedObjectContext *) context;

- (KBSection *__nullable) sectionNamed: (NSString *) sectionName createIfNeeded: (BOOL) createIfNeeded;

@end

NS_ASSUME_NONNULL_END
