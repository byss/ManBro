//
//  NSURL+documentController.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 1/8/22.
//  Copyright © 2022 Kirill byss Bystrov. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURL (documentController)

@property (nonatomic, readonly) NSUInteger sourceIdentifier;
@property (nonatomic, readonly) NSUInteger targetIdentifier;

- (instancetype) initWithTargetURL: (NSURL *) url sourceURL: (NSURL *) sourceURL;
- (instancetype) initWithTargetURL: (NSURL *) url sourceIdentifier: (NSUInteger) sourceIdentifier;
- (instancetype) initWithTargetURL: (NSURL *) url sourceIdentifier: (NSUInteger) sourceIdentifier targetIdentifier: (NSUInteger) targetIdentifier;

@end

NS_ASSUME_NONNULL_END
