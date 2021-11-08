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

@protocol KBTaskResponseType <NSObject>

+ (instancetype) createWithTaskResponse: (NSData *) responseData error: (NSError *__autoreleasing *__nullable) error;

@end

@interface KBTask <__covariant ResponseType>: NSObject

- (void) startWithCompletion: (void (^)(ResponseType __nullable, NSError *__nullable)) completion;
- (void) cancel;

@end

@interface KBManQueryTask: KBTask <NSArray <NSURL *> *>

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype) init NS_UNAVAILABLE;

- (instancetype) initWithQuery: (NSString *) query;

@end

@interface KBGenerateHTMLTask: KBTask <NSData *>

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype) init NS_UNAVAILABLE;

- (instancetype) initWithInputFileURL: (NSURL *) inputFileURL;

@end

NS_ASSUME_NONNULL_END
