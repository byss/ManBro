//
//  KBSection.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/30/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBSection.h"

#import "KBPrefix.h"
#import "KBDocumentMeta.h"
#import "CoreData+logging.h"
#import "NSManagedObject+convenience.h"

@implementation KBSection

@dynamic name, documents, prefix;

+ (KBSection *) fetchSectionNamed: (NSString *) sectionName prefix: (KBPrefix *) prefix createIfNeeded: (BOOL) createIfNeeded {
	if (!(prefix && sectionName.length)) { return nil; }
	
	static NSArray <NSString *> *properties = nil;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		properties = [self validatedArrayOfPropertyNames:@[@"prefix", @"name"]];
	});

	KBSection *result = [self fetchUniqueObjectWithValues:@[prefix, sectionName ?: [NSNull null]] forPropertiesNamed:properties inContext:prefix.managedObjectContext];
	if (!result && createIfNeeded) {
		result = [[self alloc] initWithContext:prefix.managedObjectContext];
		result.name = sectionName;
		result.prefix = prefix;
	}
	return result;
}

- (NSURL *) URL {
	NSURL *const prefixURL = self.prefix.URL;
	return prefixURL ? [[NSURL alloc] initFileURLWithPath:[@"man" stringByAppendingString:self.name] isDirectory:YES relativeToURL:prefixURL] : nil;
}

@end
