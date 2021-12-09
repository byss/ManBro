//
//  KBTask.h
//  ManBro
//
//  Created by Kirill Bystrov on 12/3/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const KBTaskErrorDomain;

typedef NS_ERROR_ENUM (KBTaskErrorDomain, KBTaskErrorCode) {
	KBTaskCancelledError = -1,
	KBTaskNonzeroExitCodeError = 1,
	KBTaskUncaughtSignalError = 2,
	KBTaskInvalidOutputError = 3,
};

@interface KBTask <__covariant ResponseType>: NSObject

- (void) startWithCompletion: (void (^)(ResponseType __nullable, NSError *__nullable)) completion;
- (void) cancel;

@end

NS_ASSUME_NONNULL_END
