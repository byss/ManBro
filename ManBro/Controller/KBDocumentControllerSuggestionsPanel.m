//
//  KBDocumentControllerSuggestionsPanel.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 11/8/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentController_Private.h"

#import "KBTask.h"
#import "KBDocument.h"
#import "NSPersistentContainer+sharedContainer.h"

@interface KBDocumentControllerSuggestionsPanel () <NSTableViewDataSource, NSTableViewDelegate> {
	__weak KBManQueryTask *_currentTask;
	NSInteger _clickedRow;
}

@property (nonatomic, readonly, unsafe_unretained) NSTableView *tableView;
@property (nonatomic, readonly, unsafe_unretained) NSLayoutConstraint *tableHeightConstraint;
@property (nonatomic, readonly, unsafe_unretained) NSView *noDocumentsView;
@property (nonatomic, copy) NSArray <KBDocument *> *documents;

@end

@implementation KBDocumentControllerSuggestionsPanel

- (instancetype) initWithContentRect: (NSRect) contentRect styleMask: (NSWindowStyleMask) style backing: (NSBackingStoreType) backingStoreType defer: (BOOL) flag {
	style = NSWindowStyleMaskBorderless | NSWindowStyleMaskTitled | NSWindowStyleMaskDocModalWindow | NSWindowStyleMaskNonactivatingPanel | NSWindowStyleMaskFullSizeContentView;
	if (self = [super initWithContentRect:contentRect styleMask:style backing:backingStoreType defer:flag]) {
		self.titleVisibility = NSWindowTitleHidden;
		self.titlebarAppearsTransparent = YES;
		self.floatingPanel = YES;
		self.becomesKeyOnlyIfNeeded = YES;
		self.level = NSModalPanelWindowLevel;
		self.movable = NO;
		self.releasedWhenClosed = NO;
		self.worksWhenModal = YES;
		
		NSTableView *tableView = [NSTableView new];
		tableView.translatesAutoresizingMaskIntoConstraints = NO;
		NSTableColumn *const column = [NSTableColumn new];
		column.editable = NO;
		column.resizingMask = NSTableColumnAutoresizingMask;
		[tableView addTableColumn:column];
		tableView.dataSource = self;
		tableView.delegate = self;
		_tableView = tableView;
		_clickedRow = -1;
		
		NSLayoutConstraint *tableHeightConstraint = [tableView.heightAnchor constraintEqualToConstant:0.0];
		tableHeightConstraint.priority = NSLayoutPriorityDefaultLow;
		tableHeightConstraint.active = YES;
		_tableHeightConstraint = tableHeightConstraint;
		
		NSView *noDocumentsView = [NSView new];
		noDocumentsView.translatesAutoresizingMaskIntoConstraints = NO;
		NSTextField *noDocumentsLabel = [NSTextField new];
		noDocumentsLabel.translatesAutoresizingMaskIntoConstraints = NO;
		noDocumentsLabel.stringValue = @"Nothing found";
		noDocumentsLabel.editable = NO;
		noDocumentsLabel.backgroundColor = [NSColor windowBackgroundColor];
		noDocumentsLabel.bordered = NO;
		[noDocumentsLabel sizeToFit];
		[noDocumentsView addSubview:noDocumentsLabel];
		_noDocumentsView = noDocumentsView;
		
		[NSLayoutConstraint activateConstraints:@[
			[noDocumentsLabel.centerXAnchor constraintEqualToAnchor:noDocumentsView.centerXAnchor],
			[noDocumentsLabel.centerYAnchor constraintEqualToAnchor:noDocumentsView.centerYAnchor],
			[noDocumentsLabel.leadingAnchor constraintGreaterThanOrEqualToSystemSpacingAfterAnchor:noDocumentsView.leadingAnchor multiplier:1.0],
			[noDocumentsLabel.topAnchor constraintGreaterThanOrEqualToSystemSpacingBelowAnchor:noDocumentsView.topAnchor multiplier:1.0],
		]];
		
		NSStackView *contentView = [NSStackView new];
		contentView.orientation = NSUserInterfaceLayoutOrientationVertical;
		[contentView addArrangedSubview:tableView];
		[contentView addArrangedSubview:noDocumentsView];
		self.contentView = contentView;
	}
	return self;
}

- (BOOL) isResizable {
	return YES;
}

- (void) setQueryText: (NSString *) queryText {
	[_currentTask cancel];
	if (!queryText.length) {
		self.documents = nil;
		return;
	}
	
	KBManQueryTask *task = [[KBManQueryTask alloc] initWithQuery:queryText];
	_currentTask = task;
	[task startWithCompletion:^(NSArray <NSURL *> *result, NSError *error) {
		if (error) {
			if ([error.domain isEqualToString:KBTaskErrorDomain] && (error.code == KBTaskCancelledError)) {
				return;
			}
			return dispatch_async (dispatch_get_main_queue (), ^{ [self presentError:error]; });
		}
		
		NSPersistentContainer *const container = [NSPersistentContainer sharedContainer];
		[container performBackgroundTask:^(NSManagedObjectContext *ctx) {
			NSMutableArray <KBDocument *> *const docs = [[NSMutableArray alloc] initWithCapacity:result.count];
			for (NSURL *docURL in result) {
				KBDocument *const doc = [KBDocument fetchOrCreateDocumentWithURL:docURL context:ctx];
				doc ? [docs addObject:doc] : (void) 0;
			}
			NSError *saveError = nil;
			[ctx save:&saveError];
			NSArray <NSManagedObjectID *> *const objectIDs = saveError ? nil : [docs valueForKey:NSStringFromSelector (@selector (objectID))];
			dispatch_async (dispatch_get_main_queue (), ^{
				if (saveError) {
					return (void) [self presentError:saveError];
				}
				NSMutableArray <KBDocument *> *const documents = [[NSMutableArray alloc] initWithCapacity:objectIDs.count];
				for (NSManagedObjectID *objectID in objectIDs) {
					[documents addObject:[container.viewContext objectWithID:objectID]];
				}
				self.documents = documents;
			});
		}];
	}];
}

- (BOOL) selectNextSuggestion {
	[self selectSuggestionWithOffset:1];
	return YES;
}

- (BOOL) selectPrevSuggestion {
	[self selectSuggestionWithOffset:-1];
	return YES;
}

- (void) selectSuggestionWithOffset: (NSInteger) offset {
	if (!self.documents.count) {
		return;
	}
	NSInteger rowToSelect;
	if (self.tableView.selectedRow < 0) {
		rowToSelect = (offset > 0) ? 0 : self.documents.count - 1;
	} else {
		rowToSelect = (self.tableView.selectedRow + offset) % self.documents.count;
	}
	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:rowToSelect] byExtendingSelection:NO];
}

- (BOOL) confirmSuggestionSelection {
	if (!self.documents.count) {
		return NO;
	}
	KBDocument *doc = self.documents [MAX (self.tableView.selectedRow, 0)];
	[self.navigationDelegate searchPanel:self didRequestDocument:doc options:KBReplaceCurrentContext];
	return YES;
}

- (void) setDocuments: (NSArray <KBDocument *> *) documents {
	NSManagedObjectID *selectedID = (self.tableView.selectedRow < 0) ? nil : self.documents [self.tableView.selectedRow].objectID;
	_documents = [documents copy];
	[self.tableView reloadData];
	[self.documents enumerateObjectsUsingBlock:^(KBDocument *obj, NSUInteger idx, BOOL *stop) {
		if ([selectedID isEqual:obj.objectID]) {
			*stop = YES;
			[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:idx] byExtendingSelection:NO];
		}
	}];
	self.noDocumentsView.hidden = !(self.tableView.hidden = !_documents.count);
	if (documents.count) {
		self.tableHeightConstraint.constant = CGRectGetMaxY ([self.tableView rectOfRow:documents.count - 1]);
	} else {
		self.tableHeightConstraint.constant = 0.0;
	}
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) tableView {
	return self.documents.count;
}

- (id) tableView: (NSTableView *) tableView objectValueForTableColumn: (NSTableColumn *) tableColumn row: (NSInteger) row {
	KBDocument *const doc = self.documents [row];
	return [[NSString alloc] initWithFormat:@"%@ (%@) – %@", doc.name, doc.section, doc.url];
}

- (void) tableViewSelectionIsChanging: (NSNotification *) notification {
	if (self.currentEvent.type == NSEventTypeLeftMouseDown) {
		_clickedRow = [self.tableView rowAtPoint:[self.tableView convertPoint:self.currentEvent.locationInWindow fromView:nil]];
	} else {
		_clickedRow = -1;
	}
}

- (void) tableViewSelectionDidChange: (NSNotification *) notification {
	if (_clickedRow == self.tableView.selectedRow) {
		[self confirmSuggestionSelection];
		_clickedRow = -1;
	}
}

@end
