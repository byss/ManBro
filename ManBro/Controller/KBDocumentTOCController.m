//
//  KBDocumentTOCController.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 1/5/22.
//  Copyright © 2022 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentController_Private.h"

#import "KBDocumentMeta.h"
#import "CoreData+logging.h"
#import "KBDocumentTOCItem.h"
#import "NSPersistentContainer+sharedContainer.h"

@interface KBDocumentTOCController () <NSOutlineViewDataSource, NSOutlineViewDelegate> {
	__unsafe_unretained IBOutlet NSOutlineView *_outlineView;
	__unsafe_unretained IBOutlet NSTextField *_emptyTOCField;
}

@property (nonatomic, unsafe_unretained, readonly) NSOutlineView *outlineView;
@property (nonatomic, unsafe_unretained, readonly) NSTextField *emptyTOCField;
@property (nonatomic, readonly) KBDocumentTOCItem *toc;

@end

@implementation KBDocumentTOCController

- (KBDocumentTOCItem *) toc {
	return self.currentDocument.toc;
}

- (KBDocumentMeta *) currentDocument {
	return self.representedObject;
}

- (void) setCurrentDocument: (KBDocumentMeta *) currentDocument {
	self.representedObject = currentDocument;
	[self reloadData];
}

- (void) reloadData {
	[self.outlineView reloadData];
	self.emptyTOCField.stringValue = self.toc ? NSLocalizedString (@"Cannot load TOC.", nil) : NSLocalizedString (@"Loading…", nil);
	self.emptyTOCField.hidden = self.toc.hasChildren;
	[self populateCurrentDocumentTOCIfNeeded];
}

- (void) populateCurrentDocumentTOCIfNeeded {
	if (!self.currentDocument || self.toc) { return; }
	NSManagedObjectID *const currentDocumentID = self.currentDocument.objectID;
	[self.documentController.contentController loadTOCDataWithCompletion:^(id tocData, NSError *error) {
		if (error) { return; }
		[[NSPersistentContainer sharedContainer] performBackgroundTask:^(NSManagedObjectContext *context) {
			KBDocumentMeta *const document = [context objectWithID:currentDocumentID];
			[document populateTOCUsingData:tocData];
			[context save];
			
			dispatch_async (dispatch_get_main_queue (), ^{
				if ([self.currentDocument.objectID isEqual:currentDocumentID]) {
					[self reloadData];
				}
			});
		}];
	}];
}


- (NSInteger) outlineView: (NSOutlineView *) outlineView numberOfChildrenOfItem: (KBDocumentTOCItem *) item {
	return (item ?: self.toc).children.count;
}

- (id) outlineView: (NSOutlineView *) outlineView child: (NSInteger) index ofItem: (KBDocumentTOCItem *) item {
	return (item ?: self.toc).children [index];
}

- (BOOL) outlineView: (NSOutlineView *) outlineView isItemExpandable: (KBDocumentTOCItem *) item {
	return !!item.children.count;
}

- (id) outlineView: (NSOutlineView *) outlineView objectValueForTableColumn: (NSTableColumn *) tableColumn byItem: (KBDocumentTOCItem *) item {
	return item.title;
}

- (id) outlineView: (NSOutlineView *) outlineView persistentObjectForItem: (id) item {
	return [item objectID];
}

- (id) outlineView: (NSOutlineView *) outlineView itemForPersistentObject: (id) object {
	return [self.toc.managedObjectContext objectWithID:object];
}

- (IBAction) tocCellClicked: (NSOutlineView *) sender {
	if (sender.clickedRow < 0) { return; }
	KBDocumentTOCItem *const tocItem = [sender itemAtRow:sender.clickedRow];
	[self.documentController.contentController openTOCItem:tocItem];
}

@end
