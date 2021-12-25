//
//  NSURL+filesystem.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/17/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "NSURL+filesystem.h"

@implementation NSURL (ManBro)

+ (NSArray <NSURLResourceKey> *) readableDirectoryAndGenerationIdentifierKeys {
	static NSArray <NSURLResourceKey> *readableDirectoryAndGenerationIdentifierKeys;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		readableDirectoryAndGenerationIdentifierKeys = [NSURL.readableDirectoryKeys arrayByAddingObject:NSURLGenerationIdentifierKey];
	});
	return readableDirectoryAndGenerationIdentifierKeys;
}

+ (NSArray <NSURLResourceKey> *) readableRegularFileAndGenerationIdentifierKeys {
	static NSArray <NSURLResourceKey> *readableRegularFileAndGenerationIdentifierKeys;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		readableRegularFileAndGenerationIdentifierKeys = [NSURL.readableRegularFileKeys arrayByAddingObject:NSURLGenerationIdentifierKey];
	});
	return readableRegularFileAndGenerationIdentifierKeys;
}

- (NSString *) manSectionName {
	if (self.pathExtension.length) {
		return nil;
	}
	
	static NSString *const manSectionNamePrefix = @"man";
	NSString *const basename = self.lastPathComponent;
	if (![basename hasPrefix:manSectionNamePrefix]) {
		return nil;
	}
	
	return [basename substringFromIndex:manSectionNamePrefix.length];
}

- (NSString *) manDocumentTitle {
	NSString *const sectionName = self.URLByDeletingLastPathComponent.manSectionName;
	if (!sectionName) { return nil; }
	
	static NSArray <NSString *> *const additionalExtensions = @[ @"gz" ];
	NSURL *documentURL = self.absoluteURL.standardizedURL;
	while ([additionalExtensions containsObject:documentURL.pathExtension]) {
		documentURL = documentURL.URLByDeletingPathExtension;
	}
	if ([documentURL.pathExtension hasPrefix:sectionName]) {
		documentURL = documentURL.URLByDeletingPathExtension;
	} else {
		return nil;
	}
	
	return documentURL.lastPathComponent;
}

@end

@implementation NSDictionary (resourceValues)

- (BOOL) isReadableRegularFile {
	return [self checkResourceValuesForKeys:NSURL.readableRegularFileKeys];
}

- (BOOL) isReadableDirectory {
	return [self checkResourceValuesForKeys:NSURL.readableDirectoryKeys];
}

- (BOOL) checkResourceValuesForKeys: (NSArray <NSURLResourceKey> *) keys {
	for (NSURLResourceKey key in keys) {
		if (![[self objectForKey:key] boolValue]) {
			return NO;
		}
	}
	return YES;
}

@end

@implementation NSURL (filesystem)

+ (NSArray <NSURLResourceKey> *) readableRegularFileKeys {
	static NSArray <NSURLResourceKey> *readableRegularFileKeys = nil;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		readableRegularFileKeys = [[NSArray alloc] initWithObjects:NSURLIsReadableKey, NSURLIsRegularFileKey, nil];
	});
	return readableRegularFileKeys;
}

+ (NSArray <NSURLResourceKey> *) readableDirectoryKeys {
	static NSArray <NSURLResourceKey> *readableDirectoryKeys = nil;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		readableDirectoryKeys = [[NSArray alloc] initWithObjects:NSURLIsReadableKey, NSURLIsDirectoryKey, NSURLIsExecutableKey, nil];
	});
	return readableDirectoryKeys;
}

- (BOOL) isReadableRegularFile {
	return [self isReadableRegularFile:NULL];
}

- (BOOL) isReadableDirectory {
	return [self isReadableDirectory:NULL];
}

- (BOOL) isReadableRegularFile: (NSError *__autoreleasing *) error {
	return [self checkResourceValuesForKeys:self.class.readableRegularFileKeys error:error];
}

- (BOOL) isReadableDirectory: (NSError *__autoreleasing *) error {
	return [self checkResourceValuesForKeys:self.class.readableDirectoryKeys error:error];
}

- (BOOL) checkResourceValuesForKeys: (NSArray <NSURLResourceKey> *) keys error: (NSError *__autoreleasing *) error {
	return [[self.URLByResolvingSymlinksInPath resourceValuesForKeys:keys error:error] checkResourceValuesForKeys:keys];
}

@end
