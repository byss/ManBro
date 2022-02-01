//
//  KBDocumentSplitController.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 1/5/22.
//  Copyright © 2022 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentController_Private.h"

#import "NSObject+abstract.h"
#import "NSObject+blockKVO.h"

@interface KBDocumentSplitController () {
	__unsafe_unretained IBOutlet NSSplitViewItem *_tocItem;
	__unsafe_unretained IBOutlet NSSplitViewItem *_contentItem;
}

@end

@implementation KBDocumentSplitController

@dynamic currentDocument;

+ (NSSet <NSString *> *) keyPathsForValuesAffectingCurrentDocument {
	static NSSet *keyPathsForValuesAffectingCurrentDocument;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{ keyPathsForValuesAffectingCurrentDocument = [[NSSet alloc] initWithObjects:@"contentController.currentDocument", nil] ;});
	return keyPathsForValuesAffectingCurrentDocument;
}

- (id) forwardingTargetForSelector: (SEL) aSelector {
	if ((aSelector == @selector (currentDocument)) || (aSelector == @selector (setCurrentDocument:))) {
		return self.contentController;
	} else {
		return [super forwardingTargetForSelector:aSelector];
	}
}

- (KBDocumentTOCController *) tocController {
	return KB_DOWNCAST (KBDocumentTOCController, self.tocItem.viewController);
}

- (KBDocumentContentController *) contentController {
	return KB_DOWNCAST (KBDocumentContentController, self.contentItem.viewController);
}

- (void) viewDidLoad {
	[super viewDidLoad];
	__unsafe_unretained typeof (self) unsafeSelf = self;
	[self observeObject:self keyPath:@"currentDocument" usingBlock:^{ [unsafeSelf currentDocumentDidChange]; }];
}

- (void) currentDocumentDidChange {
	self.tocController.currentDocument = self.currentDocument;
	if (!self.tocItem.collapsed) {
		self.tocItem.collapsed = YES;
	}
}

- (BOOL) validateUserInterfaceItem: (id< NSValidatedUserInterfaceItem>) item {
	if ((item.action == @selector (toggleSidebar:)) && !self.currentDocument) { return NO; }
	return [super validateUserInterfaceItem:item];
}

@end
