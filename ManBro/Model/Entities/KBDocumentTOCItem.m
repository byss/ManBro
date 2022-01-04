//
//  KBDocumentTOCItem.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/26/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentTOCItem.h"

#import "KBDocumentMeta.h"
#import "KBDocumentContent.h"
#import "NSPersistentContainer+sharedContainer.h"

@interface KBDocumentTOCItem (CoreDataGeneratedAccesssors)

- (void) addChildrenObject: (KBDocumentTOCItem *) child;
- (void) removeChildrenObject: (KBDocumentTOCItem *) child;

@end

@implementation KBDocumentTOCItem

@dynamic anchor, title, content, children, parent;

+ (NSPredicate *) staleObjectsPredicate {
	return [NSPredicate predicateWithFormat:@"content == nil AND parent == nil"];
}

- (instancetype) initRootItemWithContent: (KBDocumentContent *) content {
	if (self = [self initWithContext:content.managedObjectContext]) {
		self.anchor = @"#";
		self.title = content.meta.title;
		self.content = content;
	}
	return self;
}

- (instancetype) initWithParent: (KBDocumentTOCItem *) parent anchor: (NSString *) anchor title: (NSString *) title {
	if (self = [self initWithContext:parent.managedObjectContext]) {
		self.anchor = anchor;
		self.title = title;
		self.parent = parent;
	}
	return self;
}

- (BOOL) hasChildren {
	return !!self.children.count;
}

- (NSUInteger) level {
	if (self.content) {
		return 0;
	} else if (self.parent) {
		return self.parent.level + 1;
	} else {
		NSAssert (NO, @"TOC item must have either content or parent set");
		__builtin_unreachable ();
	}
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
		[self addChildrenObject:item];
	}
}

@end
