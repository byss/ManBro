//
//  KBDocumentContent.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/17/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentContent.h"

#import "NSComparisonPredicate+convenience.h"
#import "NSPersistentContainer+sharedContainer.h"

@implementation KBDocumentContent

@dynamic meta, html;

+ (NSPredicate *) staleObjectsPredicate { return [[NSComparisonPredicate alloc] initWithType:NSEqualToPredicateOperatorType forKeyPath:@"meta" value:[NSNull null]]; }

- (instancetype) initWithHTML: (NSData *) html meta: (KBDocumentMeta *) meta {
	if (self = [self initWithContext:meta.managedObjectContext]) {
		self.html = html;
		self.meta = meta;
	}
	return self;
}

- (void) willSave {
	if (!self.meta  && !self.deleted) { [self.managedObjectContext deleteObject:self]; }
	[super willSave];
}

@end
