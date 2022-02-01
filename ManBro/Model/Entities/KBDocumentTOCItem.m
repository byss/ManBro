//
//  KBDocumentTOCItem.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/26/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentTOCItem.h"

#import "KBDocumentContent.h"
#import "NSManagedObject+convenience.h"
#import "NSPersistentContainer+sharedContainer.h"

@implementation KBDocumentTOCItem

@dynamic anchor, title, content, children, parent;

+ (NSPredicate *) staleObjectsPredicate {
	return [self predicateMatchingObjectsWithValues:@[[NSNull null], [NSNull null]] forPropertiesNamed:@[@"content", @"parent"]];
}

- (instancetype) initRootItemWithContent: (KBDocumentContent *) content {
	if (!content) { return nil; }
	if (self = [self initWithContext:content.managedObjectContext]) {
		self.anchor = @"#";
		self.content = content;
		self.title = content.meta.title;
	}
	return self;
}

- (instancetype) initWithParent: (KBDocumentTOCItem *) parent anchor: (NSString *) anchor title: (NSString *) title {
	if (!(parent && anchor.length && title.length)) { return nil; }
	if (self = [self initWithContext:parent.managedObjectContext]) {
		self.anchor = anchor;
		self.parent = parent;
		self.title = title;
	}
	return self;
}

- (KBDocumentMeta *) document {
	return self.parent ? self.parent.document : self.content.meta;
}

- (BOOL) hasChildren {
	return !!self.children.count;
}

- (NSUInteger) level {
	return self.parent ? (self.parent.level + 1) : 0;
}

- (void) willSave {
	if (!(self.content || self.parent) && !self.deleted) {
		[self.managedObjectContext deleteObject:self];
	}
	[super willSave];
}

- (void) populateChildrenUsingData: (id) tocData {
	if (![tocData isKindOfClass:[NSArray class]]) { return; }
	for (NSDictionary <NSString *, id> *childInfo in tocData) {
		if (![childInfo isKindOfClass:[NSDictionary class]]) { continue; }
		NSString *const anchor = childInfo [@"href"], *const title = childInfo [@"name"];
		if (!([anchor isKindOfClass:[NSString class]] && [anchor hasPrefix:@"#"] && [title isKindOfClass:[NSString class]] && title.length)) { continue; }
		KBDocumentTOCItem *const item = [[KBDocumentTOCItem alloc] initWithParent:self anchor:anchor title:title];
		[item populateChildrenUsingData:childInfo [@"children"]];
	}
}

@end
