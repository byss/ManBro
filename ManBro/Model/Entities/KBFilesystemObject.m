//
//  KBFilesystemObject.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/30/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBFilesystemObject.h"

#import "NSManagedObject+convenience.h"

@implementation KBFilesystemObject

@dynamic URL;

static char const NSBinaryPropertyListMagic [] = { 'b', 'p', 'l', 'i', 's', 't', '0', '0' };

- (NSURLGenerationIdentifier) generationIdentifier {
	return [self valueForKey:@"generationIdentifier" notifyObservers:YES transform:^id (NSData *rawValue) {
		if (![rawValue isKindOfClass:[NSData class]]) { return nil; }
		if ((rawValue.length < sizeof (NSBinaryPropertyListMagic)) || memcmp (NSBinaryPropertyListMagic, rawValue.bytes, sizeof (NSBinaryPropertyListMagic))) {
			return rawValue;
		}
		NSKeyedUnarchiver *const coder = [[NSKeyedUnarchiver alloc] initForReadingFromData:rawValue error:NULL];
		coder.requiresSecureCoding = NO;
		coder.decodingFailurePolicy = NSDecodingFailurePolicySetErrorAndReturn;
		return [coder decodeTopLevelObjectAndReturnError:NULL];
	}];
}

- (void) setGenerationIdentifier: (NSURLGenerationIdentifier) generationIdentifier {
	NSData *rawValue = nil;
	if ([generationIdentifier isKindOfClass:[NSData class]]) {
		rawValue = (NSData *) generationIdentifier;
	} else if (generationIdentifier) {
		NSKeyedArchiver *const coder = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
		coder.outputFormat = NSPropertyListBinaryFormat_v1_0;
		[coder encodeRootObject:generationIdentifier];
		[coder finishEncoding];
		rawValue = coder.encodedData;
	}
	[self setValue:rawValue forKey:@"generationIdentifier" notifyObservers:YES];
}

@end
