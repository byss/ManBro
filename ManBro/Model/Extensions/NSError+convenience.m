//
//  NSError+convenience.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/23/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "NSError+convenience.h"

#import <dispatch/once.h>
#import <Foundation/NSURLError.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/FoundationErrors.h>

@implementation NSError (convenience)

#define NSStaticErrorInstance(_prop, _domain, _code) \
	+ (NSError *) _prop { \
		static NSError *_prop; \
		static dispatch_once_t onceToken; \
		dispatch_once (&onceToken, ^{ _prop = [[NSError alloc] initWithDomain:(_domain) code:(_code) userInfo:nil]; }); \
		return _prop; \
	}

NSStaticErrorInstance (userCancelledError, NSCocoaErrorDomain, NSUserCancelledError);
NSStaticErrorInstance (fileReadCorruptFileError, NSCocoaErrorDomain, NSFileReadCorruptFileError);

- (BOOL) isUserCancelledError { return [self.domain isEqualToString:NSCocoaErrorDomain] && (self.code == NSUserCancelledError); }
- (BOOL) isBadURLError { return [self.domain isEqualToString:NSURLErrorDomain] && (self.code == NSURLErrorBadURL); }

- (instancetype) initPOSIXErrorWithCurrentErrno {
	return [self initPOSIXErrorWithCode:errno];
}

- (instancetype) initPOSIXErrorWithCode: (NSInteger) code {
	return [self initPOSIXErrorWithCode:code userInfo:nil];
}

- (instancetype) initPOSIXErrorWithCode: (NSInteger) code userInfo: (NSDictionary <NSErrorUserInfoKey, id> *) userInfo {
	return [self initWithDomain:NSPOSIXErrorDomain code:code userInfo:userInfo];
}

- (instancetype) initCocoaErrorWithCode: (NSInteger) code { return [self initCocoaErrorWithCode:code userInfo:nil]; }
- (instancetype) initCocoaErrorWithCode: (NSInteger) code userInfo: (NSDictionary <NSErrorUserInfoKey, id> *) userInfo {
	return [self initWithDomain:NSCocoaErrorDomain code:code userInfo:userInfo];
}

- (instancetype) initFileReadNoSuchFileErrorWithPath: (NSString *) path {
	return [self initCocoaErrorWithCode:NSFileReadNoSuchFileError userInfo:path ? @{NSFilePathErrorKey: path} : nil];
}

- (instancetype) initURLErrorWithCode: (NSInteger) code { return [self initURLErrorWithCode:code userInfo:nil]; }
- (instancetype) initURLErrorWithCode: (NSInteger) code failingURL: (id <NSURLErrorUserInfoValue>) failingURL {
	return [self initURLErrorWithCode:code userInfo:@{failingURL.URLErrorUserInfoKey: failingURL}];
}
- (instancetype) initURLErrorWithCode: (NSInteger) code userInfo: (NSDictionary <NSErrorUserInfoKey, id> *) userInfo {
	return [self initWithDomain:NSURLErrorDomain code:code userInfo:userInfo];
}

- (instancetype) initBadURLErrorWithFailingURL: (id <NSURLErrorUserInfoValue>) failingURL { return [self initURLErrorWithCode:NSURLErrorBadURL failingURL:failingURL]; }
- (instancetype) initUnsupportedURLErrorWithFailingURL: (id <NSURLErrorUserInfoValue>) failingURL { return [self initURLErrorWithCode:NSURLErrorUnsupportedURL failingURL:failingURL]; }
- (instancetype) initResourceUnavailableErrorWithFailingURL: (id <NSURLErrorUserInfoValue>) failingURL { return [self initURLErrorWithCode:NSURLErrorResourceUnavailable failingURL:failingURL]; }

@end

@implementation NSString (NSURLErrorUserInfoValue)

- (NSErrorUserInfoKey) URLErrorUserInfoKey { return NSURLErrorFailingURLStringErrorKey; }

@end

@implementation NSURL (NSURLErrorUserInfoValue)

- (NSErrorUserInfoKey) URLErrorUserInfoKey { return NSURLErrorFailingURLErrorKey; }

@end
