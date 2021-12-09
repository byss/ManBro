//
//  KBSection.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/30/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBSection.h"

#import "KBPrefix.h"
#import "KBDocument.h"
#import "CoreData+logging.h"
#import "NSManagedObject+convenience.h"

@implementation KBSection

@dynamic name, documents, prefix;

+ (NSFetchRequest <KBSection *> *) fetchRequestWithSectionName: (NSString *) name prefix: (KBPrefix *) prefix {
	return [self fetchRequestFromTemplateWithName:@"FetchSectionByName" substitutionVariables:KBVariables (prefix, name)];
}

+ (KBSection *) fetchSectionNamed: (NSString *) sectionName prefix: (KBPrefix *) prefix createIfNeeded: (BOOL) createIfNeeded {
	KBSection *result = [prefix.managedObjectContext executeFetchRequest:[self fetchRequestWithSectionName:sectionName prefix:prefix]].firstObject;
	if (!result && createIfNeeded) {
		result = [[KBSection alloc] initWithContext:prefix.managedObjectContext];
		result.name = sectionName;
		result.prefix = prefix;
	}
	return result;
}

- (NSURL *) URL {
	NSURL *const prefixURL = self.prefix.URL;
	return prefixURL ? [[NSURL alloc] initFileURLWithPath:[@"man" stringByAppendingString:self.name] isDirectory:YES relativeToURL:prefixURL] : nil;
}

- (KBDocument *) documentNamed: (NSString *) documentTitle createIfNeeded: (BOOL) createIfNeeded {
	return [KBDocument fetchDocumentNamed:documentTitle section:self createIfNeeded:createIfNeeded];
}

@end
