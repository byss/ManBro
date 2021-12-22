//
//  KBIndexUpdateTasks.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/17/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBPrefix.h"
#import "KBSection.h"
#import "KBDocumentMeta.h"

NS_ASSUME_NONNULL_BEGIN

@class NSManagedObject;
@interface KBIndexUpdateTask <__covariant ObjectType: KBFilesystemObject *>: NSObject <NSProgressReporting>

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype) init NS_UNAVAILABLE;

- (void) runWithCompletion: (void (^) (void)) completion;

@end

@class KBPrefix;
@interface KBPrefixUpdateTask: KBIndexUpdateTask <KBPrefix *>

- (instancetype) initWithPrefix: (KBPrefix *) prefix NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithURL: (NSURL *) prefixURL source: (KBPrefixSource) source priority: (NSUInteger) priority context: (NSManagedObjectContext *) context NS_DESIGNATED_INITIALIZER;

@end

@class KBSection;
@interface KBSectionUpdateTask: KBIndexUpdateTask <KBSection *>

- (instancetype) initWithSection: (KBSection *) section NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithPrefix: (KBPrefix *) prefix sectionName: (NSString *) sectionName NS_DESIGNATED_INITIALIZER;

@end

@class KBDocumentMeta;
@interface KBDocumentUpdateTask: KBIndexUpdateTask <KBDocumentMeta *>

- (instancetype) initWithDocument: (KBDocumentMeta *) document NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithSection: (KBSection *) section documentFilename: (NSString *) documentFilename NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
