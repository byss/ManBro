//
//  KBIndexManager.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/10/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSManagedObjectContext;
@interface KBIndexManager: NSObject <NSProgressReporting>

- (instancetype) initWithContext: (NSManagedObjectContext *) context NS_DESIGNATED_INITIALIZER;

- (void) runWithCompletion: (void (^) (void)) completion;

@end

NS_ASSUME_NONNULL_END
