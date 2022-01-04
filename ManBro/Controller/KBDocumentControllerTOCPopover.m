//
//  KBDocumentControllerTOCPopover.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/26/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentController_Private.h"

#import "NSObject+abstract.h"
#import "KBDocumentTOCItem.h"
#import "NSLayoutConstraint+convenience.h"

@interface KBDocumentTOCViewController: NSViewController

- (instancetype) initWithCoder: (NSCoder *) coder NS_UNAVAILABLE;
- (instancetype) initWithNibName: (NSNibName) nibNameOrNil bundle: (NSBundle *) nibBundleOrNil NS_UNAVAILABLE;

- (instancetype) initWithTOC: (KBDocumentTOCItem *) toc parent: (KBDocumentControllerTOCPopover *) parent NS_DESIGNATED_INITIALIZER;

@end

@implementation KBDocumentControllerTOCPopover

@dynamic delegate;

- (instancetype) init KB_ABSTRACT;
- (instancetype) initWithCoder: (NSCoder *) coder KB_ABSTRACT;

- (instancetype) initWithTOC: (KBDocumentTOCItem *) toc {
	if (self = [super init]) {
		self.behavior = NSPopoverBehaviorSemitransient;
		self.contentViewController = [[KBDocumentTOCViewController alloc] initWithTOC:toc parent:self];
	}
	return self;
}

- (void) tocItemSelected: (KBDocumentTOCItem *) item {
	[self.delegate tocPopover:self didSelectTOCItem:item];
	[self close];
}

@end

@interface KBDocumentTOCViewController () <NSOutlineViewDataSource, NSOutlineViewDelegate>

@property (nonatomic, unsafe_unretained, readonly) KBDocumentControllerTOCPopover *parent;
@property (nonatomic, unsafe_unretained, readonly) NSOutlineView *outlineView;
@property (nonatomic, readonly) KBDocumentTOCItem *toc;

@property (nonatomic, assign) IBInspectable NSSize contentMinSize;
@property (nonatomic, assign) IBInspectable NSSize contentMaxSize;
@property (nonatomic, assign) IBInspectable CGFloat contentWidth;

@end

@implementation KBDocumentTOCViewController {
	__unsafe_unretained IBOutlet NSOutlineView *_outlineView;
	__unsafe_unretained IBOutlet NSLayoutConstraint *_contentMinWidthConstraint;
	__unsafe_unretained IBOutlet NSLayoutConstraint *_contentMinHeightConstraint;
	__unsafe_unretained IBOutlet NSLayoutConstraint *_contentMaxWidthConstraint;
	__unsafe_unretained IBOutlet NSLayoutConstraint *_contentMaxHeightConstraint;
	__unsafe_unretained IBOutlet NSLayoutConstraint *_contentWidthConstraint;
}

+ (BOOL) accessInstanceVariablesDirectly { return YES; }

- (instancetype) initWithCoder: (NSCoder *) coder KB_ABSTRACT;
- (instancetype) initWithNibName: (NSNibName) nibNameOrNil bundle: (NSBundle *) nibBundleOrNil KB_ABSTRACT;

- (instancetype) initWithTOC: (KBDocumentTOCItem *) toc parent: (KBDocumentControllerTOCPopover *) parent {
	if (self = [super initWithNibName:nil bundle:nil]) {
		self.representedObject = toc;
		_parent = parent;
	}
	return self;
}

- (KBDocumentTOCItem *) toc {
	return self.representedObject;
}

- (id) forwardingTargetForSelector: (SEL) aSelector {
	if ((aSelector == @selector (contentMinSize)) || (aSelector == @selector (setContentMinSize:)) ||
			(aSelector == @selector (contentMaxSize)) || (aSelector == @selector (setContentMaxSize:))) {
		return self.view.window;
	} else {
		return [super forwardingTargetForSelector:aSelector];
	}
}

- (NSSize) contentMinSize {
	return NSMakeSize (_contentMinWidthConstraint.constant, _contentMinHeightConstraint.constant);
}

- (void) setContentMinSize: (NSSize) contentMinSize {
	_contentMinWidthConstraint.constant = contentMinSize.width;
	_contentMinHeightConstraint.constant = contentMinSize.height;
}

- (NSSize) contentMaxSize {
	return NSMakeSize (_contentMaxWidthConstraint.constant, _contentMaxHeightConstraint.constant);
}

- (void) setContentMaxSize: (NSSize) contentMaxSize {
	_contentMaxWidthConstraint.constant = contentMaxSize.width;
	_contentMaxHeightConstraint.constant = contentMaxSize.height;
}

- (CGFloat) contentWidth {
	return _contentWidthConstraint.constant;
}

- (void) setContentWidth: (CGFloat) contentWidth {
	if (fabs ((contentWidth = MAX (MIN (contentWidth, self.contentMaxSize.width), self.contentMinSize.width)) - self.contentWidth) < 1e-3) { return; }
	self.view.needsLayout = YES;
	_contentWidthConstraint.constant = contentWidth;
}

- (void) viewDidLoad {
	[super viewDidLoad];
	
	self.contentMinSize = NSMakeSize (100.0, 50.0);
}

- (void) viewWillAppear {
	[super viewWillAppear];

	NSWindow *const parentWindow = self.view.window.parentWindow;
	self.contentMaxSize = NSMakeSize (NSWidth (parentWindow.contentLayoutRect) /  2, NSHeight (parentWindow.contentLayoutRect));
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
- (void) outlineViewItemDidExpand: (NSNotification *) notification {
	[notification.object invalidateIntrinsicContentSize];
}

- (void) outlineViewItemDidCollapse: (NSNotification *) notification {
	[notification.object invalidateIntrinsicContentSize];
}

- (void) outlineView: (NSOutlineView *) outlineView willDisplayCell: (NSCell *) cell forTableColumn: (NSTableColumn *) tableColumn item: (id) item {
	NSInteger const row = [outlineView rowForItem:item], column = [outlineView.tableColumns indexOfObject:tableColumn];
	if ((row < 0) || (column < 0)) { return; }
	NSRect const columnRect = [outlineView rectOfColumn:column], cellRect = [outlineView frameOfCellAtColumn:column row:row];
	if (NSEqualRects (columnRect, NSZeroRect) || NSEqualRects (cellRect, NSZeroRect)) { return; }
	CGFloat const cellTrailing = [outlineView.window ceilValue:NSMinX (cellRect) + cell.cellSize.width];
	NSLog (@"%@: %.1f + %.1f  = %.1f", cell.stringValue, NSMinX (cellRect), cell.cellSize.width, cellTrailing);
	
	if (cellTrailing > self.contentWidth) {
		self.contentWidth = cellTrailing;
	}
}

- (id) outlineView: (NSOutlineView *) outlineView persistentObjectForItem: (id) item {
	return [item objectID];
}

- (id) outlineView: (NSOutlineView *) outlineView itemForPersistentObject: (id) object {
	return [self.toc.managedObjectContext objectWithID:object];
}

- (void) outlineViewSelectionDidChange: (NSNotification *) notification {
	NSOutlineView *const outlineView = notification.object;
	NSInteger const selectedRow = outlineView.selectedRow;
	if (selectedRow < 0) { return; }
	[self.parent tocItemSelected:[outlineView itemAtRow:selectedRow]];
}

@end
