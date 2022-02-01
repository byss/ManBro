//
//  NSObject+blockKVO.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 1/5/22.
//  Copyright © 2022 Kirill byss Bystrov. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSKeyValueObservingOptions const NSKeyValueObservingOptionAutoremove = 0x8000;

@interface NSObject (blockKVO)

- (id <NSObject>) observeValueForKeyPath: (NSString *) keyPath usingBlock: (void (^) (void)) observerBlock NS_WARN_UNUSED_RESULT;
- (id <NSObject>) observeValueForKeyPath: (NSString *) keyPath options: (NSKeyValueObservingOptions) options usingBlock: (void (^) (NSDictionary <NSKeyValueChangeKey, id> *)) observerBlock NS_WARN_UNUSED_RESULT;
- (void) removeBlockObserver: (id <NSObject>) observer;

@end

@interface NSObject (blockKVOConvenience)

- (id <NSObject>) observeObject: (id) object keyPath: (NSString *) keyPath usingBlock: (void (^) (void)) observerBlock;
- (id <NSObject>) observeObject: (id) object keyPath: (NSString *) keyPath options: (NSKeyValueObservingOptions) options usingBlock: (void (^) (NSDictionary <NSKeyValueChangeKey, id> *)) observerBlock;

@end

NS_ASSUME_NONNULL_END
