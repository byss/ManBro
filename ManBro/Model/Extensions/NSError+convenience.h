//
//  NSError+convenience.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/23/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import <Foundation/NSURL.h>
#import <Foundation/NSError.h>
#import <Foundation/NSString.h>

NS_ASSUME_NONNULL_BEGIN

#define NSOutErr(_errorPtr, ...) ((_errorPtr) ? (void) (*(_errorPtr) = __VA_ARGS__) : (void) 0)

@protocol NSURLErrorUserInfoValue <NSObject>

@required
@property (nonatomic, readonly) NSErrorUserInfoKey URLErrorUserInfoKey;

@end

@interface NSString (NSURLErrorUserInfoValue) <NSURLErrorUserInfoValue>
@end
@interface NSURL (NSURLErrorUserInfoValue) <NSURLErrorUserInfoValue>
@end

@interface NSError (convenience)

#pragma mark - Cocoa errors

@property (nonatomic, readonly, class) NSError *userCancelledError;
@property (nonatomic, readonly, class) NSError *fileReadCorruptFileError;

@property (nonatomic, readonly, getter = isUserCancelledError) BOOL userCancelledError;

- (instancetype) initPOSIXErrorWithCurrentErrno;
- (instancetype) initPOSIXErrorWithCode: (NSInteger) code;
- (instancetype) initPOSIXErrorWithCode: (NSInteger) code userInfo: (NSDictionary <NSErrorUserInfoKey, id> *__nullable) userInfo;

- (instancetype) initCocoaErrorWithCode: (NSInteger) code;
- (instancetype) initCocoaErrorWithCode: (NSInteger) code userInfo: (NSDictionary <NSErrorUserInfoKey, id> *__nullable) userInfo;

- (instancetype) initFileReadNoSuchFileErrorWithPath: (NSString *) path;

#pragma mark - URL errors

@property (nonatomic, readonly, getter = isBadURLError) BOOL badURLError;

- (instancetype) initURLErrorWithCode: (NSInteger) code;
- (instancetype) initURLErrorWithCode: (NSInteger) code userInfo: (NSDictionary <NSErrorUserInfoKey, id> *__nullable) userInfo;

- (instancetype) initBadURLErrorWithFailingURL: (id <NSURLErrorUserInfoValue>) failingURL;
- (instancetype) initUnsupportedURLErrorWithFailingURL: (id <NSURLErrorUserInfoValue>) failingURL;
- (instancetype) initResourceUnavailableErrorWithFailingURL: (id <NSURLErrorUserInfoValue>) failingURL;

@end

NS_ASSUME_NONNULL_END
