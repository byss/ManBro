//
//  KBManPageTasks.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/10/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBManPageTasks.h"
#import "KBTask_Protected.h"

#import <stdatomic.h>

#import "NSError+convenience.h"

@interface KBFileURLArrayTaskResponse: NSObject <KBTaskResponseType>
@end
@interface KBManpathQueryTaskResponse: KBFileURLArrayTaskResponse
@end

@implementation KBManpathQueryTask

+ (Class <KBTaskResponseType>) responseType {
	return [KBManpathQueryTaskResponse class];
}

- (instancetype) init {
	if (self = [super init]) {
		self.executableName = @"manpath";
	}
	return self;
}

@end

@interface KBGenerateHTMLTask ()

@property (nonatomic, readonly) NSURL *inputFileURL;

@end

@implementation KBGenerateHTMLTask

- (instancetype) init { return [self initWithInputFileURL:(id __nonnull) nil]; }

- (instancetype) initWithInputFileURL: (NSURL *) inputFileURL {
	if (!inputFileURL.absoluteString.length) {
		return nil;
	}
	
	if (self = [super init]) {
		_inputFileURL = inputFileURL;
		self.executableName = @"mandoc";
		self.arguments = @[@"-T", @"html", @"-O", @"man=x-man-page://%S/%N,fragment"];
	}
	return self;
}

- (void) startWithCompletion: (void (^)(id _Nullable, NSError * _Nullable)) completion {
	NSError *error = nil;
	self.standardInput = [NSFileHandle fileHandleForReadingFromURL:self.inputFileURL error:&error];
	if (error) {
		return completion (nil, error);
	}
	[super startWithCompletion:completion];
}

- (id) parseResponseData: (NSData *) responseData error: (NSError *__autoreleasing *) error {
	return responseData;
}

@end

@interface KBFileURLArrayTaskResponse (subclassing)

+ (NSUInteger) estimateCountForResponseString: (NSString *) responseString;
+ (NSUInteger) getNextURLString: (NSString *__strong *) result fromString: (NSString *) responseString error: (NSError *__autoreleasing *) error;

@end

@interface NSString (countCharacters)

- (NSUInteger) countOfCharactersInSet: (NSCharacterSet *) searchSet options: (NSStringCompareOptions) options;

@end

@interface NSCharacterSet (colonCharacterSet)

+ (NSCharacterSet *) colonCharacterSet;

@end

@implementation KBManpathQueryTaskResponse

+ (NSUInteger) estimateCountForResponseString: (NSString *) responseString {
	return [responseString countOfCharactersInSet:[NSCharacterSet colonCharacterSet] options:0] + 1;
}

+ (NSUInteger) getNextURLString: (NSString *__strong *) result fromString: (NSString *) responseString error: (NSError *__autoreleasing *) error {
	NSUInteger const colonLocation = [responseString rangeOfCharacterFromSet:[NSCharacterSet colonCharacterSet]].location;
	if (colonLocation == NSNotFound) {
		if ([responseString hasSuffix:@"\n"]) {
			*result = [responseString substringWithRange:NSMakeRange (0, responseString.length - 1)];
		} else {
			*result = responseString;
		}
		return responseString.length;
	} else {
		*result = [responseString substringToIndex:colonLocation];
		return colonLocation + 1;
	}
}

@end

@implementation KBFileURLArrayTaskResponse

+ (id) createWithTaskResponse: (NSData *) responseData error: (NSError *__autoreleasing *) error {
	NSMutableString *const responseString = [[NSMutableString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
	if (!responseString) {
		NSOutErr (error, [NSError fileReadCorruptFileError]);
		return nil;
	}
	
	NSUInteger const stackObjectsCount = MIN ([self estimateCountForResponseString:responseString], 256);
	NSURL *stackObjects [stackObjectsCount], *__strong *stackObjectsEnd = stackObjects;
	bzero (stackObjects, sizeof (stackObjects));
	NSMutableArray *heapObjects = nil;
	while (responseString.length) {
		NSString *urlString = nil;
		NSUInteger const consumedLength = [self getNextURLString:&urlString fromString:responseString error:error];
		if (!urlString) {
			return nil;
		}
		[responseString deleteCharactersInRange:NSMakeRange (0, consumedLength)];
		NSURL *url = [[NSURL alloc] initFileURLWithPath:urlString];
		if (!url) {
			NSOutErr (error, [NSError fileReadCorruptFileError]);
			return nil;
		}
		if (stackObjectsEnd < stackObjects + stackObjectsCount) {
			*stackObjectsEnd++ = url;
		} else {
			if (!heapObjects) {
				heapObjects = [[NSMutableArray alloc] initWithObjects:stackObjects count:stackObjectsCount];
			}
			[heapObjects addObject:url];
		}
	}
	
	NSArray *const result = heapObjects ? [[NSArray alloc] initWithArray:heapObjects] : [[NSArray alloc] initWithObjects:stackObjects count:stackObjectsEnd - stackObjects];
	for (; stackObjectsEnd > stackObjects; *--stackObjectsEnd = nil);
	return result;
}

@end

@implementation NSString (countCharacters)

- (NSUInteger) countOfCharactersInSet: (NSCharacterSet *) searchSet options: (NSStringCompareOptions) options {
	options = options & ~NSBackwardsSearch;
	NSUInteger result = 0;
	for (NSUInteger location = 0; (location = [self rangeOfCharacterFromSet:searchSet options:options range:NSMakeRange (location, self.length - location)].location) != NSNotFound; result++, location++);
	return result;
}

@end

@implementation NSCharacterSet (colonCharacterSet)

+ (NSCharacterSet *) colonCharacterSet {
	static NSCharacterSet *colonCharacterSet;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		colonCharacterSet = [NSCharacterSet characterSetWithRange:NSMakeRange (':', 1)];
	});
	return colonCharacterSet;
}

@end
