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

+ (instancetype) fetchSectionNamed: (NSString *) sectionName prefix: (KBPrefix *) prefix createIfNeeded: (BOOL) createIfNeeded {
	if (!(prefix && sectionName.length)) { return nil; }
	
	static NSArray <NSString *> *properties = nil;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		properties = [self validatedArrayOfPropertyNames:@[@"prefix", @"name"]];
	});

	KBSection *result = [self fetchUniqueObjectWithValues:@[prefix, sectionName] forPropertiesNamed:properties inContext:prefix.managedObjectContext];
	if (!result && createIfNeeded) {
		result = [[self alloc] initWithContext:prefix.managedObjectContext];
		result.name = sectionName;
		result.prefix = prefix;
	}
	return result;
}

+ (NSArray <__kindof KBSection *> *) fetchSectionsNamed: (NSString *) sectionName inContext: (NSManagedObjectContext *) context {
	if (!sectionName.length) { return nil; }
	
	static NSArray <NSString *> *properties = nil;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		properties = [self validatedArrayOfPropertyNames:@[@"name"]];
	});
	
	NSArray <KBSection *> *const result = [self fetchObjectsWithValues:@[sectionName] forPropertiesNamed:properties inContext:context];
	return [result sortedArrayUsingComparator:^NSComparisonResult (KBSection *lhs, KBSection *rhs) {
		NSUInteger const lhsPrefixPrio = lhs.prefix.priority, rhsPrefixPrio = rhs.prefix.priority;
		if (lhsPrefixPrio < rhsPrefixPrio) { return NSOrderedAscending; }
		if (lhsPrefixPrio > rhsPrefixPrio) { return NSOrderedDescending; }
		return [lhs.name localizedStandardCompare:rhs.name];
	}];
}

- (NSURL *) URL {
	NSURL *const prefixURL = self.prefix.URL;
	return prefixURL ? [[NSURL alloc] initFileURLWithPath:[@"man" stringByAppendingString:self.name] isDirectory:YES relativeToURL:prefixURL] : nil;
}

@end
