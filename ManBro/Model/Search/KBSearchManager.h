//
//  KBSearchManager.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/8/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class KBPrefix, KBSection;
@interface KBSearchQuery: NSObject

@property (nonatomic, readonly) NSString *text;
@property (nonatomic, readonly, nullable) NSSet <KBPrefix *> *prefixes;
@property (nonatomic, readonly, nullable) NSSet <KBSection *> *sections;

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype) init NS_UNAVAILABLE;

- (instancetype) initWithText: (NSString *) text NS_DESIGNATED_INITIALIZER;

- (BOOL) isEqualToSearchQuery: (KBSearchQuery *) searchQuery;

@end

@interface KBSearchQuery (NSCopying) <NSCopying, NSMutableCopying>
@end

@interface KBMutableSearchQuery: KBSearchQuery

@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy, nullable) NSSet <KBPrefix *> *prefixes;
@property (nonatomic, copy, nullable) NSSet <KBSection *> *sections;

+ (instancetype) new;
- (instancetype) init;

@end

@protocol NSFetchedResultsSectionInfo;
@class NSManagedObjectContext, KBDocument;
@interface KBSearchManager: NSObject

@property (nonatomic, readonly) NSManagedObjectContext *context;

- (instancetype) initWithContext: (NSManagedObjectContext *) context NS_DESIGNATED_INITIALIZER;

- (void) fetchDocumentsMatchingQuery: (KBSearchQuery *__nullable) searchQuery completion: (void (^) (NSArray <id <NSFetchedResultsSectionInfo>> *)) completion;

@end

NS_ASSUME_NONNULL_END
