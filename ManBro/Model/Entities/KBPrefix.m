//
//  KBPrefix.m
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "KBPrefix.h"

#import "KBSection.h"
#import "CoreData+logging.h"
#import "NSManagedObject+convenience.h"

@implementation KBPrefix

@dynamic generationIdentifier, source, URL, sections, documents;

+ (NSFetchRequest *) fetchRequest {
	static NSArray <NSSortDescriptor *> *sortDescriptors;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		sortDescriptors = [[NSArray alloc] initWithObjects:[[NSSortDescriptor alloc] initWithKey:@"priority" ascending:YES], nil];
	});
	
	NSFetchRequest *const result = [super fetchRequest];
	result.sortDescriptors = sortDescriptors;
	return result;
}

+ (NSFetchRequest *) fetchRequestWithURL: (NSURL *) url {
	return [self fetchRequestFromTemplateWithName:@"FetchPrefixWithURL" substitutionVariables:KBVariables (url)];
}

+ (NSArray <KBPrefix *> *) fetchInContext: (NSManagedObjectContext *) context {
	return [context executeFetchRequest:[self fetchRequest]];
}

+ (void) fetchInContext: (NSManagedObjectContext *) context completion: (void (^)(NSArray <KBPrefix *> *)) completion {
	[context executeFetchRequest:[self fetchRequest] completion:completion];
}

+ (instancetype) fetchPrefixWithURL: (NSURL *) URL createIfNeeded: (BOOL) createIfNeeded context: (NSManagedObjectContext *) context {
	URL = URL.absoluteURL.standardizedURL;
	KBPrefix *result = [context executeFetchRequest:[self fetchRequestWithURL:URL]].firstObject;
	if (!result && createIfNeeded) {
		result = [[KBPrefix alloc] initWithContext:context];
		result.URL = URL;
	}
	return result;
}

- (NSUInteger) priority {
	return [[self valueForKey:@"priority" notifyObservers:YES] unsignedIntegerValue];
}

- (void) setPriority: (NSUInteger) priority {
	[self setValue:@(priority) forKey:@"priority" notifyObservers:YES];
}

- (NSURL *) URL {
	return [self valueForKey:@"url" notifyObservers:YES];
}

- (void) setURL: (NSURL *) URL {
	[self setValue:URL.absoluteURL.standardizedURL forKey:@"url" notifyObservers:YES];
}

- (KBSection *) sectionNamed: (NSString *)  sectionName createIfNeeded: (BOOL) createIfNeeded {
	return [KBSection fetchSectionNamed:sectionName prefix:self createIfNeeded:createIfNeeded];
}

@end

KBPrefixSource const KBPrefixSourceManConfig = @"man.conf";
KBPrefixSource const KBPrefixSourceHeuristic = @"heuristic";
KBPrefixSource const KBPrefixSourceUser = @"user";
