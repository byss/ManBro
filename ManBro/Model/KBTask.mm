//
//  KBTask.m
//  ManBro
//
//  Created by Kirill Bystrov on 12/3/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "KBTask.h"

#include <paths.h>
#include <type_traits>
#include <objc/runtime.h>

static NSErrorUserInfoKey const KBTaskErrorTaskKey = @"ru.byss.KBTask.Error.task";
static NSErrorUserInfoKey const KBTaskErrorTaskStdoutKey = @"ru.byss.KBTask.Error.stdout";
static NSErrorUserInfoKey const KBTaskErrorTaskStderrKey = @"ru.byss.KBTask.Error.stderr";

@interface KBTask <ResponseType> ()

@property (nonatomic, readonly, class) Class <KBTaskResponseType> responseType;

@property (nonatomic, copy) NSURL *executableURL;
@property (nonatomic, copy) NSString *executableName;
@property (nonatomic, copy) NSArray <NSString *> *arguments;
@property (nonatomic, copy) NSMutableDictionary <NSString *, NSString *> *environment;
@property (nonatomic, copy) NSURL *currentDirectoryURL;

- (BOOL) canHandleExitCode: (int) exitCode;
- (ResponseType) parseResponseData: (NSData *) responseData error: (NSError **) error;

@end

@interface KBManQueryTaskResponse: NSArray <KBTaskResponseType>
@end

@implementation KBManQueryTask

+ (Class <KBTaskResponseType>) responseType {
	return [KBManQueryTaskResponse class];
}

- (instancetype) init { return [self initWithQuery:(id __nonnull) nil]; }

- (instancetype) initWithQuery: (NSString *) query {
	if (!query.length) {
		return nil;
	}
	
	if (self = [super init]) {
		self.executableName = @"man";
		self.arguments = @[@"-aW", query];
	}
	return self;
}

- (BOOL) canHandleExitCode: (int) exitCode {
	return (exitCode == 1) || [super canHandleExitCode:exitCode];
}

@end

@implementation KBGenerateHTMLTask

- (instancetype) init { return [self initWithInputFileURL:(id __nonnull) nil]; }

- (instancetype) initWithInputFileURL: (NSURL *) inputFileURL {
	if (self = [super init]) {
		self.executableName = @"mandoc";
		self.arguments = @[@"-T", @"html", @"-O", @"man=x-man-page://%S/%N", @"-O", @"fragment", @(inputFileURL.fileSystemRepresentation)];
	}
	return self;
}

- (id) parseResponseData: (NSData *) responseData error: (NSError *__autoreleasing *) error {
	return responseData;
}

@end

@interface KBTask ()

@property (nonatomic, readonly, class) dispatch_queue_t queue;
@property (nonatomic, readonly, getter = isCancelled) BOOL cancelled;
@property (nonatomic, readonly) NSTask *task;
@property (nonatomic, readonly) dispatch_queue_t queue;
@property (nonatomic, readonly) NSData *outputData;

@end

static id KBTaskErrorInfoValueProvider (NSError *error, NSErrorUserInfoKey key);

@implementation KBTask

@dynamic responseType, arguments, currentDirectoryURL;

@synthesize queue = _queue;

+ (void) initialize {
	if (self == [KBTask class]) {
		[NSError setUserInfoValueProviderForDomain:KBTaskErrorDomain provider:^id (NSError *error, NSErrorUserInfoKey key) { return KBTaskErrorInfoValueProvider (error, key); }];
	}
}

+ (dispatch_queue_t) queue {
	static auto const queue = dispatch_queue_create ("KBTask-root", dispatch_queue_attr_make_with_qos_class (DISPATCH_QUEUE_CONCURRENT_WITH_AUTORELEASE_POOL, QOS_CLASS_USER_INITIATED, 0));
	return queue;
}

+ (NSURL *) searchExecutableNamed: (NSString *) name path: (NSString *) pathVarValue {
	NSArray <NSString *> *paths = [pathVarValue componentsSeparatedByString:@":"];
	for (NSString *path in paths) {
		NSURL *const url = [[[NSURL alloc] initFileURLWithPath:path isDirectory:YES] URLByAppendingPathComponent:name];
		NSDictionary <NSURLResourceKey, NSNumber *> *const values = [url resourceValuesForKeys:@[NSURLIsRegularFileKey, NSURLIsReadableKey, NSURLIsExecutableKey] error:NULL];
		if ([values.allValues isEqualToArray:@[@YES, @YES, @YES]]) {
			return url;
		}
	}
	return nil;
}

- (NSMutableDictionary <NSString *, NSString *> *) environment {
	if (!_environment) {
		_environment = [self.task.environment ?: [NSProcessInfo processInfo].environment mutableCopy];
	}
	return _environment;
}

- (instancetype) init {
	if (self = [super init]) {
		_task = [NSTask new];
		_task.standardInput = [NSFileHandle fileHandleWithNullDevice];
		_task.standardOutput = [NSPipe new];
		_task.standardError = [NSPipe new];
	}
	return self;
}

- (id) forwardingTargetForSelector: (SEL) aSelector {
	static SEL const taskSelectors [] = {
		@selector (arguments), @selector (setArguments:),
		@selector (currentDirectoryURL), @selector (setCurrentDirectoryURL:),
	};
	for (SEL const *ptr = taskSelectors; ptr < taskSelectors + std::extent_v <decltype (taskSelectors)>; ptr++) {
		if (*ptr == aSelector) {
			return self.task;
		}
	}
	return [super forwardingTargetForSelector:aSelector];
}

- (dispatch_queue_t) queue {
	if (!_queue) {
		_queue = dispatch_queue_create_with_target ("KBTask", DISPATCH_QUEUE_SERIAL, self.class.queue);
	}
	return _queue;
}

- (void) setExecutableURL: (NSURL *) executableURL {
	_executableURL = [executableURL copy];
	_executableName = [_executableURL lastPathComponent];
}

- (void) setExecutableName: (NSString *) executableName {
	_executableURL = nil;
	_executableName = [executableName copy];
}

- (void) cancel {
	_cancelled = YES;
	if (self.task.running) {
		[self.task terminate];
	}
}

- (void) startWithCompletion: (void (^) (id, NSError *)) completion {
	if (self.cancelled) {
		return;
	}
	
	dispatch_async (self.queue, ^{
		if (self.environment) {
			self.task.environment = self.environment;
		}
		if (self.executableURL) {
			self.task.executableURL = self.executableURL;
		} else if (self.executableName) {
			NSString *const path = self.environment [@"PATH"] ?: [NSProcessInfo processInfo].environment [@"PATH"] ?: @_PATH_DEFPATH;
			self.task.executableURL = [self.class searchExecutableNamed:self.executableName path:path];
		}
		
		typeof (self) strongSelf = self;
		self.task.terminationHandler = ^(NSTask *task) {
			dispatch_sync (strongSelf.queue, ^{
				[strongSelf terminationHandlerForTask:task completion:completion];
			});
		};
		
		NSError *error = nil;
		[self.task launchAndReturnError:&error];
		if (error) {
			return completion (nil, error);
		}
		strongSelf->_outputData = [[self.task.standardOutput fileHandleForReading] readDataToEndOfFileAndReturnError:&error];
		if (error) {
			completion (nil, error);
			self.task.terminationHandler = NULL;
			[self.task terminate];
		}
	});
}

- (void) terminationHandlerForTask: (NSTask *) task completion: (void (^) (id, NSError *)) completion {
	dispatch_assert_queue_debug (self.queue);
	
	id result = nil;
	KBTaskErrorCode code;
	NSError *stdoutError = nil;

	if (self.cancelled) {
		code = KBTaskCancelledError;
	} else {
		if (task.terminationReason == NSTaskTerminationReasonExit) {
			if ([self canHandleExitCode:task.terminationStatus]) {
				if (self.outputData && (result = [self parseResponseData:self.outputData error:&stdoutError])) {
					return completion (result, nil);
				} else {
					code = KBTaskInvalidOutputError;
				}
			} else {
				code = KBTaskNonzeroExitCodeError;
			}
		} else {
			code = KBTaskUncaughtSignalError;
		}
	}
	
	NSMutableDictionary <NSErrorUserInfoKey, id> *const userInfo = [[NSMutableDictionary alloc] initWithCapacity:4];
	NSError *stderrError = nil;
	NSData *const stderrData = [[task.standardError fileHandleForReading] readDataToEndOfFileAndReturnError:&stderrError];
	userInfo [KBTaskErrorTaskKey] = task;
	self.outputData ? userInfo [KBTaskErrorTaskStdoutKey] = self.outputData : nil;
	stderrData ? userInfo [KBTaskErrorTaskStderrKey] = stderrData : nil;
	if (stdoutError) {
		if (stderrError) {
			userInfo [NSMultipleUnderlyingErrorsKey] = @[stdoutError, stderrError];
		} else {
			userInfo [NSUnderlyingErrorKey] = stdoutError;
		}
	} else if (stderrError) {
		userInfo [NSUnderlyingErrorKey] = stderrError;
	}
	completion (nil, [[NSError alloc] initWithDomain:KBTaskErrorDomain code:code userInfo:userInfo]);
}

- (BOOL) canHandleExitCode: (int) exitCode {
	return !exitCode;
}

- (id) parseResponseData: (NSData *) responseData error: (NSError **) error {
	return [self.class.responseType createWithTaskResponse:responseData error:error];
}

@end

@interface KBManQueryTaskResponse () {
	NSArray *_backing;
}

@end

@implementation KBManQueryTaskResponse

+ (instancetype) createWithTaskResponse: (NSData *) responseData error: (NSError *__autoreleasing *) error {
	NSArray <NSString *> *const paths = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] componentsSeparatedByString:@"\n"];
	if (!paths) {
		if (error) {
			*error = [[NSError alloc] initWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
		}
		return nil;
	}
	NSURL *urls [paths.count], *__strong *lastURL = urls;
	bzero (urls, sizeof (NSURL *) * paths.count);
	for (NSString *path in paths) {
		if (!path.length) {
			continue;
		}
		NSURL *url = [[NSURL alloc] initFileURLWithPath:path isDirectory:NO];
		if (url) {
			*lastURL++ = url;
		}
	}
	KBManQueryTaskResponse *const response = paths ? [[self alloc] initWithObjects:urls count:lastURL - urls] : nil;
	for (NSURL *__strong *url = urls; url < lastURL; url++) {
		*url = nil;
	}
	return response;
}

- (instancetype) initWithObjects: (id const []) objects count: (NSUInteger) cnt {
	if (self = [super init]) {
		_backing = [[NSArray alloc] initWithObjects:objects count:cnt];
	}
	return self;
}

- (NSUInteger) count { return _backing.count; }
- (id) objectAtIndex: (NSUInteger) index { return [_backing objectAtIndex:index]; }

@end

static NSString *KBTaskErrorStderrMessage (NSError *error);
static NSString *KBTaskErrorDebugDescriptionForKey (NSError *error, NSErrorUserInfoKey key);

static id KBTaskErrorInfoValueProvider (NSError *error, NSErrorUserInfoKey key) {
	NSTask *const task = error.userInfo [KBTaskErrorTaskKey];
	if (!task) {
		return nil;
	}
	
	if ([key isEqualToString:NSLocalizedDescriptionKey]) {
		switch (error.code) {
			case KBTaskCancelledError: return @"Task was cancelled";
			case KBTaskUncaughtSignalError: return [[NSString alloc] initWithCString:strsignal (task.terminationStatus) encoding:NSUTF8StringEncoding];
			case KBTaskNonzeroExitCodeError: return KBTaskErrorStderrMessage (error) ?: [[NSString alloc] initWithFormat:@"Exit code %d", task.terminationStatus];
			case KBTaskInvalidOutputError:
			default: return nil;
		}
	} else if ([key isEqualToString:NSDebugDescriptionErrorKey]) {
		NSMutableString *result = [[NSMutableString alloc] initWithFormat:@"%@ %@\n", task.executableURL.path, [task.arguments componentsJoinedByString:@" "]];
		[result appendString:KBTaskErrorDebugDescriptionForKey (error, KBTaskErrorTaskStdoutKey)];
		[result appendString:KBTaskErrorDebugDescriptionForKey (error, KBTaskErrorTaskStderrKey)];
		if (task.terminationReason == NSTaskTerminationReasonExit) {
			[result appendFormat:@"Process exited with code %d\n", task.terminationStatus];
		} else {
			[result appendFormat:@"Uncaught signal: %d\n", task.terminationStatus];
		}
		return result;
	} else {
		return nil;
	}
}

static NSString *KBTaskErrorStderrMessage (NSError *error) {
	id const stderrObj = error.userInfo [KBTaskErrorTaskStderrKey];
	if ([stderrObj isKindOfClass:[NSData class]]) {
		NSString *const errorMessage = [[[NSString alloc] initWithData:stderrObj encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (errorMessage.length) {
			return errorMessage;
		}
	}
	return nil;
}

static NSString *KBTaskErrorDebugDescriptionForKey (NSError *error, NSErrorUserInfoKey key) {
	NSData *const data = error.userInfo [key];
	if ([data isKindOfClass:[NSData class]]) {
		NSString *const message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		if (message) {
			if (message.length) {
				if ([message characterAtIndex:message.length - 1] != '\n') {
					return [message stringByAppendingString:@"\n"];
				} else {
					return message;
				}
			} else {
				return @"";
			}
		} else {
			return [[NSString alloc] initWithFormat:@"<%@: binary data (%ld bytes)>\n", key.pathExtension, data.length];
		}
	} else {
		return @"";
	}
}

NSString *const KBTaskErrorDomain = @"ru.byss.KBTask.Error";
