//
//  KBTask+Protected.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/10/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBTask.h"

NS_ASSUME_NONNULL_BEGIN

@protocol KBTaskResponseType <NSObject>

@required
+ (id) createWithTaskResponse: (NSData *) responseData error: (NSError *__autoreleasing *__nullable) error;

@end

@interface KBTask <ResponseType> (/* Protected */)

@property (nonatomic, readonly, class) Class <KBTaskResponseType> responseType;

@property (nonatomic, copy) NSURL *executableURL;
@property (nonatomic, copy) NSString *executableName;
@property (nonatomic, copy) NSArray <NSString *> *arguments;
@property (nonatomic, strong, null_resettable) id standardInput;
@property (nonatomic, copy) NSMutableDictionary <NSString *, NSString *> *environment;
@property (nonatomic, copy) NSURL *currentDirectoryURL;

- (BOOL) canHandleExitCode: (int) exitCode;
- (ResponseType) parseResponseData: (NSData *) responseData error: (NSError **) error;

@end

NS_ASSUME_NONNULL_END
