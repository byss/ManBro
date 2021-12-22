//
//  KBDocumentMeta.m
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentMeta.h"

#import <os/log.h>

#import "KBSection.h"
#import "KBPrefix.h"
#import "KBDocumentContent.h"
#import "CoreData+logging.h"
#import "NSURL+filesystem.h"
#import "NSManagedObject+convenience.h"
#import "NSString+searchPredicateValue.h"

@interface KBDocumentMeta ()

@property (nonatomic, copy) NSString *normalizedTitle;
@property (nonatomic, strong, nullable) KBDocumentContent *content;

@end

@implementation KBDocumentMeta

@dynamic filename, html, normalizedTitle, title, section;

+ (KBDocumentMeta *) fetchDocumentNamed: (NSString *) documentTitle section: (KBSection *) section {
	static NSArray <NSString *> *properties = nil;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		properties = [self validatedArrayOfPropertyNames:@[@"section", @"title"]];
	});
	return [self fetchUniqueObjectWithValues:@[section, documentTitle] forPropertiesNamed:properties inContext:section.managedObjectContext];
}

- (KBPrefix *) prefix { return self.section.prefix; }
- (NSData *) html { return self.content.html; }

- (void) setTitle: (NSString *) title {
	[self setValue:title forKey:@"title" notifyObservers:YES additionalActions:^{ self.normalizedTitle = [title stringByPreparingForCaseInsensitiveComparisonPredicates]; }];
}

- (BOOL) validateContentGenerationIdentifier: (KBDocumentContent *) content {
	NSURLGenerationIdentifier const contentGenerationID = content.generationIdentifier, generationID = self.generationIdentifier;
	return !contentGenerationID || !generationID || [generationID isEqual:contentGenerationID];
}

- (void) setGenerationIdentifier: (NSURLGenerationIdentifier) generationIdentifier {
	[super setGenerationIdentifier:generationIdentifier];

	KBDocumentContent *const content = [self valueForKey:@"content" notifyObservers:YES];
	if ([self validateContentGenerationIdentifier:content]) {
		content.generationIdentifier = generationIdentifier;
	} else if (content) {
		[self.managedObjectContext deleteObject:content];
		self.content = nil;
	}
}

- (KBDocumentContent *) content {
	KBDocumentContent *const result = [self valueForKey:@"content" notifyObservers:YES];
	if ([self validateContentGenerationIdentifier:result]) { return result; }
	
	os_log_t const logHandle = os_log_create ("CoreData", "KBDocumentMeta");
	os_log_error (logHandle, "<KBDocument %{public}@ (%{public}@): invalid/stale content detected, purging", self.objectID.URIRepresentation.absoluteString, self.URL.absoluteString);
	[self.managedObjectContext deleteObject:result];
	return nil;
}

- (void) setContent: (KBDocumentContent *) content {
	if (content.generationIdentifier) {
		NSParameterAssert ([self validateContentGenerationIdentifier:content]);
	} else {
		content.generationIdentifier = self.generationIdentifier;
	}
	[self setValue:content forKey:@"content" notifyObservers:YES];
}

- (NSURL *) URL {
	NSURL *const sectionURL = self.section.URL;
	return sectionURL ? [[NSURL alloc] initFileURLWithPath:self.filename isDirectory:NO relativeToURL:sectionURL] : nil;
}

- (KBDocumentContent *) setContentHTML: (NSData *) contentHTML {
	KBDocumentContent *const content = self.content;
	if (content) {
		content.html = contentHTML;
		return content;
	} else {
		return [[KBDocumentContent alloc] initWithHTML:contentHTML meta:self];
	}
}

@end
