//
//  KBDocument.m
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocument.h"

#import "KBSection.h"
#import "KBPrefix.h"
#import "CoreData+logging.h"
#import "NSManagedObject+convenience.h"
#import "NSString+searchPredicateValue.h"

@interface KBDocument ()

@property (nonatomic, copy) NSString *normalizedTitle;

@end

@implementation KBDocument

@dynamic html, normalizedTitle, title, section;

+ (NSFetchRequest <KBDocument *> *) fetchRequestWithDocumentTitle: (NSString *) title section: (KBSection *) section {
	return [self fetchRequestFromTemplateWithName:@"FetchDocumentByTitle" substitutionVariables:KBVariables (section, title)];
}

+ (KBDocument *) fetchDocumentNamed: (NSString *) documentTitle section: (KBSection *) section createIfNeeded: (BOOL) createIfNeeded {
	KBDocument *result = [section.managedObjectContext executeFetchRequest:[self fetchRequestWithDocumentTitle:documentTitle section:section]].firstObject;
	if (!result && createIfNeeded) {
		result = [[KBDocument alloc] initWithContext:section.managedObjectContext];
		result.title = documentTitle;
		result.section = section;
	}
	return result;
}

- (KBPrefix *) prefix {
	return self.section.prefix;
}

- (void) setTitle: (NSString *) title {
	[self setValue:title forKey:@"title" notifyObservers:YES additionalActions:^{ self.normalizedTitle = [title stringByPreparingForCaseInsensitiveComparisonPredicates]; }];
}

- (void) setGenerationIdentifier: (NSURLGenerationIdentifier) generationIdentifier {
	if (![self.generationIdentifier isEqual:generationIdentifier]) { self.html = nil; }
	[super setGenerationIdentifier:generationIdentifier];
}

- (NSURL *) URL {
	NSURL *const sectionURL = self.section.URL;
	return sectionURL ? [[NSURL alloc] initFileURLWithPath:[self.title stringByAppendingPathExtension:self.section.name] isDirectory:NO relativeToURL:sectionURL] : nil;
}

@end
