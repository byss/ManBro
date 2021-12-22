//
//  KBDocumentController.m
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentController_Private.h"

#import <WebKit/WKWebView.h>
#import <WebKit/WKNavigationDelegate.h>
#import <WebKit/WKWebViewConfiguration.h>

#import "KBTask.h"
#import "KBSection.h"
#import "KBPrefix.h"
#import "NSObject+abstract.h"
#import "KBDocumentLoading.h"
#import "NSPersistentContainer+sharedContainer.h"

@interface KBDocumentController (NSWindowDelegate) <NSWindowDelegate>
@end
@interface KBDocumentController (NSSearchFieldDelegate) <NSSearchFieldDelegate>
@end
@interface KBDocumentController (KBDocumentControllerSearchPanelDelegate) <KBDocumentControllerSearchPanelDelegate>
@end
@interface KBDocumentController (WKNavigationDelegate) <WKNavigationDelegate>
@end

@interface KBDocumentController (suggestionsPanelManagement)

- (void) setSearchSheetHidden: (BOOL) searchSheetHidden;
- (void) setSearchSheetQueryText: (NSString *) queryText;
- (void) updateDocumentsSuggestionsPanelPosition;

@end

@interface KBDocumentController (documentLoading)

- (void) loadDocument: (KBDocumentMeta *) document;

@end

@interface KBDocumentController ()

@property (nonatomic, unsafe_unretained) IBOutlet NSSearchToolbarItem *searchItem;
@property (nonatomic, unsafe_unretained) KBDocumentControllerSuggestionsPanel *documentSuggestionsPanel;
@property (nonatomic, readonly) WKWebView *webView;

- (instancetype) init NS_DESIGNATED_INITIALIZER;

@end

static NSString *const KBDocumentControllerClassName = @"KBDocumentController";
static NSMutableSet <KBDocumentController *> *KBDocumentControllerInstances = nil;

@implementation KBDocumentController

+ (BOOL) accessInstanceVariablesDirectly {
	return YES;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype) init {
	return [super initWithWindowNibName:KBDocumentControllerClassName];
}

- (instancetype) initWithWindowNibName: (NSNibName) windowNibName owner: (id) owner {
	return [super initWithWindowNibName:KBDocumentControllerClassName owner:owner];
}
#pragma clang diagnostic pop

- (instancetype) initWithWindow: (NSWindow *) window {
	return [super initWithWindow:window];
}

- (instancetype) initWithCoder: (NSCoder *) coder {
	return [super initWithCoder:coder];
}

- (instancetype) initWithWindowNibName: (NSNibName) windowNibName KB_ABSTRACT;
- (instancetype) initWithWindowNibPath: (NSString *) windowNibPath owner: (id) owner KB_ABSTRACT;

- (WKWebView *) webView { return self.window.contentView; }

@end

@implementation KBDocumentController (suggestionsPanelManagement)

- (void) setSearchSheetHidden: (BOOL) searchSheetHidden {
	if (!searchSheetHidden != !self.documentSuggestionsPanel) { return; }

	if (searchSheetHidden) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:self.documentSuggestionsPanel];
		[self.window removeChildWindow:self.documentSuggestionsPanel];
		[self.documentSuggestionsPanel close];
		self.documentSuggestionsPanel = nil;
	} else {
		KBDocumentControllerSuggestionsPanel *const panel = [KBDocumentControllerSuggestionsPanel new];
		panel.navigationDelegate = self;
		self.documentSuggestionsPanel = panel;
		[self.window addChildWindow:panel ordered:NSWindowAbove];
		[self updateDocumentsSuggestionsPanelPosition];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector (updateDocumentsSuggestionsPanelPosition) name:NSWindowDidResizeNotification object:self.documentSuggestionsPanel];
	}
}

- (void) setSearchSheetQueryText: (NSString *) queryText {
	[self.documentSuggestionsPanel setQueryText:queryText];
}

- (void) updateDocumentsSuggestionsPanelPosition {
	NSWindow *const panel = self.documentSuggestionsPanel;
	if (!panel) { return; }
	CGRect const searchFieldFrame = [self.window convertRectToScreen:[self.searchItem.searchField convertRect:self.searchItem.searchField.bounds toView:nil]];
	CGRect const contentViewFrame = [self.window convertRectToScreen:[self.window.contentView convertRect:self.window.contentView.bounds toView:nil]];
	[panel setFrameTopLeftPoint:NSMakePoint (CGRectGetMidX (searchFieldFrame) - CGRectGetWidth (panel.frame) / 2, CGRectGetMinY (searchFieldFrame) - 2.0)];
	panel.maxSize = CGSizeMake (CGRectGetWidth (contentViewFrame) - 32.0, CGRectGetHeight (contentViewFrame) - 16.0);
}

@end

@implementation KBDocumentController (documentLoading)

- (void) loadDocument: (KBDocumentMeta *) document {
	self.window.title = [[NSString alloc] initWithFormat:@"%@ (%@)", document.title, document.section.name];
	self.window.representedURL = document.URL;
	self.window.tab.toolTip = @(document.URL.fileSystemRepresentation);
	[self.webView loadRequest:[[NSURLRequest alloc] initWithURL:document.loaderURI]];
}

@end

@implementation KBDocumentController (NSWindowDelegate)

- (void) windowDidLoad {
	[super windowDidLoad];

	WKWebViewConfiguration *const config = [WKWebViewConfiguration new];
	[config setURLSchemeHandler:[KBDocumentBodyLoader new] forURLScheme:KBDocumentBodyLoader.scheme];
	[config setURLSchemeHandler:[KBDocumentBundledResourceLoader new] forURLScheme:KBDocumentBundledResourceLoader.scheme];
	
	self.window.contentView = [[WKWebView alloc] initWithFrame:self.window.contentLayoutRect configuration:config];
	
	if (KBDocumentControllerInstances) {
		[KBDocumentControllerInstances addObject:self];
	} else {
		KBDocumentControllerInstances = [[NSMutableSet alloc] initWithObjects:self, nil];
	}
}

- (void) windowWillClose: (NSNotification *) notification {
	[KBDocumentControllerInstances removeObject:self];
}

- (void) windowDidMove: (NSNotification *) notification {
	[self updateDocumentsSuggestionsPanelPosition];
}

- (void) windowDidResize: (NSNotification *) notification {
	[self updateDocumentsSuggestionsPanelPosition];
}

@end

@implementation KBDocumentController (NSSearchFieldDelegate)

- (void) controlTextDidBeginEditing: (NSNotification *) sender {
	[self setSearchSheetHidden:!self.searchItem.searchField.stringValue.length];
	[self setSearchSheetQueryText:self.searchItem.searchField.stringValue];
}

- (void) controlTextDidChange: (NSNotification *) obj {
	[self setSearchSheetHidden:!self.searchItem.searchField.stringValue.length];
	[self setSearchSheetQueryText:self.searchItem.searchField.stringValue];
}

- (void) controlTextDidEndEditing: (NSNotification *) sender {
	[self setSearchSheetHidden:YES];
}

- (BOOL) control: (NSControl *) control textView: (NSTextView *) textView doCommandBySelector: (SEL) commandSelector {
	if ((control != self.searchItem.searchField) || ![textView isDescendantOf:self.searchItem.searchField]) {
		return NO;
	}
	if (commandSelector == @selector (moveDown:)) {
		return [self.documentSuggestionsPanel selectNextSuggestion];
	} else if (commandSelector == @selector (moveUp:)) {
		return [self.documentSuggestionsPanel selectPrevSuggestion];
	} else if (commandSelector == @selector (insertNewline:)) {
		return [self.documentSuggestionsPanel confirmSuggestionSelection];
	}
	return NO;
}

@end

@implementation KBDocumentController (KBDocumentControllerSuggestionsPanelDelegate)

- (void) searchPanel: (KBDocumentControllerSuggestionsPanel *) panel didRequestDocument: (KBDocumentMeta *) document options: (KBDocumentRequestOptions) options {
	[self setSearchSheetHidden:YES];
	[self.searchItem.searchField endEditing:self.searchItem.searchField.currentEditor];
	
	KBDocumentController *controller;
	if (options & KBCreateDocumentWindow) {
		controller = [KBDocumentController new];
		controller.searchItem.searchField.stringValue = self.searchItem.searchField.stringValue;
	} else if (options & KBReplaceCurrentContext) {
		controller = self;
	} else {
		return;
	}
	[controller loadDocument:document];
	if (options & KBReplaceCurrentContext) {
		[controller.window makeKeyAndOrderFront:panel];
	}
}

@end

@implementation KBDocumentController (WKNavigationDelegate)

- (void) webView: (WKWebView *) webView didFailNavigation: (WKNavigation *) navigation withError: (NSError *) error {
	dispatch_async (dispatch_get_main_queue (), ^{
		[self.window presentError:error];
	});
}

@end
