//
//  KBDocumentContentController.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 1/5/22.
//  Copyright © 2022 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentController_Private.h"

#import <WebKit/WebKit.h>

#import "KBDocumentMeta.h"
#import "KBDocumentTOCItem.h"
#import "KBDocumentLoading.h"
#import "NSObject+blockKVO.h"
#import "NSPersistentContainer+sharedContainer.h"

@interface KBDocumentContentController (NSUserInterfaceValidations) <NSUserInterfaceValidations>
@end
@interface KBDocumentContentController (NSTextFinderBarContainer) <NSTextFinderBarContainer>
@end
@interface KBDocumentContentController (WKNavigationDelegate) <WKNavigationDelegate>
@end

@interface KBDocumentContentController () {
	IBOutlet NSTextFinder *_textFinder;
	id _textFinderObserver;
}

@property (nonatomic, strong) NSStackView *view;

@property (nonatomic, unsafe_unretained, readonly) WKWebView *webView;
@property (nonatomic, readonly) NSTextFinder *textFinder;
@property (nonatomic, strong) NSView *findBarView;

@end

@implementation KBDocumentContentController

@dynamic view, currentDocument;

+ (BOOL) canOpenURL: (NSURL *) url {
	NSString *const scheme = url.scheme;
	return [scheme isEqualToString:KBDocumentBodyLoader.scheme] || [scheme isEqualToString:KBManScheme];
}

+ (BOOL) openURL: (NSURL *) url {
	NSString *const scheme = url.scheme;
	if ([scheme isEqualToString:KBDocumentBodyLoader.scheme]) {
		KBDocumentController *const target = [KBDocumentController documentControllerWithIdentifier:url.targetIdentifier] ?: [KBDocumentController new];
		[target showWindow:nil];
		[target.contentViewController.contentController loadDocumentAtURL:url];
		return YES;
	} else if ([scheme isEqualToString:KBManScheme]) {
		KBDocumentController *const source = [KBDocumentController documentControllerWithIdentifier:url.sourceIdentifier];
		[[KBManSchemeURLResolver sharedResolver] resolveManURL:url relativeToDocumentURL:source.contentViewController.contentController.webView.URL completion:^(NSURL *resolvedURL, NSError *error) {
			dispatch_async (dispatch_get_main_queue (), ^{
				if (resolvedURL) {
					[self openURL:[[NSURL alloc] initWithTargetURL:resolvedURL sourceURL:url]];
				} else {
					[source ?: NSApp presentError:error];
				}
			});
		}];
		return YES;
	} else {
		return NO;
	}
}

- (void) viewDidLoad {
	[super viewDidLoad];
	
	WKWebViewConfiguration *const config = [WKWebViewConfiguration new];
	[config setURLSchemeHandler:[KBDocumentBodyLoader new] forURLScheme:KBDocumentBodyLoader.scheme];
	[config setURLSchemeHandler:[KBDocumentBundledResourceLoader new] forURLScheme:KBDocumentBundledResourceLoader.scheme];
	
	WKWebView *const webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
	webView.translatesAutoresizingMaskIntoConstraints = NO;
	webView.navigationDelegate = self;
	[self.view addArrangedSubview:webView];
	_webView = webView;
	
	self.textFinder.client = webView;
}

- (KBDocumentMeta *) currentDocument {
	return self.representedObject;
}

- (void) setCurrentDocument: (KBDocumentMeta *) currentDocument {
	[self setCurrentDocument:currentDocument loadImmediately:YES];
}

- (void) setCurrentDocument: (KBDocumentMeta *) currentDocument loadImmediately: (BOOL) shouldLoad {
	[self willChangeValueForKey:@"currentDocument"];
	self.representedObject = currentDocument;
	[self didChangeValueForKey:@"currentDocument"];
	
	if (shouldLoad) {
		[self loadDocumentAtURL:currentDocument.loaderURI];
	}
}

- (void) loadDocumentAtURL: (NSURL *) documentURL {
	[self.webView loadRequest:[[NSURLRequest alloc] initWithURL:documentURL]];
}

- (void) loadTOCDataWithCompletion: (void (^)(id, NSError *)) completion {
	[self.webView callAsyncJavaScript:@"return getHeadings (document);" arguments:nil inFrame:nil inContentWorld:[WKContentWorld pageWorld] completionHandler:completion];
}

- (void) openTOCItem: (KBDocumentTOCItem *) tocItem {
	if (![tocItem.document isEqual:self.currentDocument]) { return; }
	[self.webView callAsyncJavaScript:@"goToAnchor (anchor);" arguments:@{@"anchor": tocItem.anchor} inFrame:nil inContentWorld:[WKContentWorld pageWorld] completionHandler:NULL];
}

@end

@implementation KBDocumentContentController (NSUserInterfaceValidations)

- (IBAction) goBack: (id) sender {
	[self.webView goBack];
}

- (IBAction) goForward: (id) sender {
	[self.webView goForward];
}

- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>) item {
	if (item.action == @selector (goBack:)) {
		return self.webView.URL && self.webView.canGoBack;
	} else if (item.action == @selector (goForward:)) {
		return self.webView.URL && self.webView.canGoForward;
	} else if (item.action == @selector (performTextFinderAction:)) {
		return self.webView.URL && [self.textFinder validateAction:item.tag];
	} else {
		return YES;
	}
}

@end

@implementation KBDocumentContentController (NSTextFinderBarContainer)

- (NSView *) contentView {
	return self.webView;
}

- (BOOL) isFindBarVisible {
	return self.contentView.subviews.count > 1;
}

- (void) setFindBarVisible: (BOOL) findBarVisible {
	if (findBarVisible == self.findBarVisible) { return; }
	
	if (findBarVisible) {
		self.findBarView.translatesAutoresizingMaskIntoConstraints = NO;
		if (self.findBarView) {
			[self.view addArrangedSubview:self.findBarView];
		}
	} else {
		[self.view removeArrangedSubview:self.findBarView];
		self.findBarView.translatesAutoresizingMaskIntoConstraints = YES;
		[self.findBarView removeFromSuperview];
	}
}

- (void) findBarViewDidChangeHeight {
}

- (IBAction) performTextFinderAction: (id <NSValidatedUserInterfaceItem>) sender {
	[self.textFinder performAction:sender.tag];
}

@end

@implementation KBDocumentContentController (WKNavigationDelegate)

- (void) webView: (WKWebView *) webView decidePolicyForNavigationAction: (WKNavigationAction *) navigationAction preferences: (WKWebpagePreferences *) preferences decisionHandler: (void (^)(WKNavigationActionPolicy, WKWebpagePreferences *)) decisionHandler {
	if (!navigationAction.sourceFrame) { return decisionHandler (WKNavigationActionPolicyAllow, preferences); }
	NSURL *const targetURL = navigationAction.request.URL;
	BOOL const isCommandKeyPressed = !!(navigationAction.modifierFlags & NSEventModifierFlagCommand);
	if ([KBDocumentContentController canOpenURL:targetURL]) {
		NSUInteger const targetIdentifier = isCommandKeyPressed ? 0 : self.documentController.identifier;
		[KBDocumentContentController openURL:[[NSURL alloc] initWithTargetURL:targetURL sourceIdentifier:self.documentController.identifier targetIdentifier:targetIdentifier]];
	} else {
		NSWorkspaceOpenConfiguration *const configuration = [NSWorkspaceOpenConfiguration new];
		configuration.activates = !isCommandKeyPressed;
		[[NSWorkspace sharedWorkspace] openURL:targetURL configuration:configuration completionHandler:NULL];
	}
	decisionHandler (WKNavigationActionPolicyCancel, nil);
}

- (void) webView: (WKWebView *) webView didStartProvisionalNavigation: (WKNavigation *) navigation {
	NSManagedObjectID *const documentID = [KBDocumentMeta objectIDWithLoaderURI:webView.URL error:NULL];
	if (![documentID isEqual:self.currentDocument.objectID]) {
		dispatch_async (dispatch_get_main_queue (), ^{
			[self setCurrentDocument:nil loadImmediately:NO];
		});
	}
}

- (void) webView: (WKWebView *) webView didFinishNavigation: (WKNavigation *) navigation {
	NSManagedObjectID *const documentID = [KBDocumentMeta objectIDWithLoaderURI:webView.URL error:NULL];
	if (![documentID isEqual:self.currentDocument.objectID]) {
		dispatch_async (dispatch_get_main_queue (), ^{
			[self setCurrentDocument:[[NSPersistentContainer sharedContainer].viewContext objectWithID:documentID] loadImmediately:NO];
		});
	}
}

- (void) webView: (WKWebView *) webView didFailProvisionalNavigation: (WKNavigation *) navigation withError: (NSError *) error {
	[self webView:webView didFailNavigation:navigation withError:error];
}

- (void) webView: (WKWebView *) webView didFailNavigation: (WKNavigation *) navigation withError: (NSError *) error {
	if ([error.domain isEqualToString:WKErrorDomain]) { return; }
	dispatch_async (dispatch_get_main_queue (), ^{ [self presentError:error]; });
}

@end

#import <objc/runtime.h>

@interface WKWebView (notEditable)
@end

@implementation WKWebView (notEditable)

+ (void) load {
	class_addMethod (self, @selector (isEditable), imp_implementationWithBlock (^(id self) { return NO; }), (char const []) { _C_BOOL, _C_ID, _C_SEL, '\0' });
}

@end
