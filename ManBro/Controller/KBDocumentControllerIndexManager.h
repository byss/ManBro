//
//  KBDocumentControllerIndexManager.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 1/8/22.
//  Copyright © 2022 Kirill byss Bystrov. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const KBDocumentControllerIndexManagerDidStartIndexUpdate;
extern NSNotificationName const KBDocumentControllerIndexManagerDidFinishIndexUpdate;

@interface KBDocumentControllerIndexManager: NSObject

@property (nonatomic, readonly, getter = isUpdating) BOOL updating;
@property (nonatomic, readonly, nullable) NSNumber *progress;

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype) init NS_UNAVAILABLE;

+ (instancetype) sharedManager;

- (void) updateIndexIfNeeded;

@end

NS_ASSUME_NONNULL_END
