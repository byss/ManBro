//
//  KBDocumentController_Private.h
//  ManBro
//
//  Created by Kirill Bystrov on 11/8/21.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import "KBDocumentController.h"
#import "NSURL+documentController.h"
#import "KBDocumentControllerIndexManager.h"

NS_ASSUME_NONNULL_BEGIN

@protocol KBDocumentController <NSObject>

@property (nonatomic, strong, nullable) KBDocumentMeta *currentDocument;

@end

@class KBDocumentSplitController, KBDocumentTOCController, KBDocumentContentController;
@interface KBDocumentController () <KBDocumentController>

@property (nonatomic, readonly) NSUInteger identifier;
@property (nonatomic, readonly) KBDocumentSplitController *contentViewController;
@property (nonatomic, readonly) KBDocumentTOCController *tocController;
@property (nonatomic, readonly) KBDocumentContentController *contentController;

+ (KBDocumentController *__nullable) documentControllerWithIdentifier: (NSUInteger) identifier;

@end

@interface KBSearchSuggestionsPanelController: NSWindowController

@property (nonatomic, assign) NSSize maxSize;

- (void) setQueryText: (NSString *) queryText;

- (BOOL) selectNextSuggestion;
- (BOOL) selectPrevSuggestion;
- (BOOL) selectNextSuggestionsPage;
- (BOOL) selectPrevSuggestionsPage;
- (BOOL) selectFirstSuggestion;
- (BOOL) selectLastSuggestion;

- (BOOL) confirmSuggestionSelection;

@end

@interface KBDocumentSplitController: NSSplitViewController <KBDocumentController>

@property (nonatomic, readonly) NSSplitViewItem *tocItem;
@property (nonatomic, readonly) NSSplitViewItem *contentItem;
@property (nonatomic, readonly) KBDocumentTOCController *tocController;
@property (nonatomic, readonly) KBDocumentContentController *contentController;

@end

@class KBDocumentTOCItem;
@interface KBDocumentContentController: NSViewController <KBDocumentController>

+ (BOOL) canOpenURL: (NSURL *) url;
+ (BOOL) openURL: (NSURL *) url;

- (void) loadDocumentAtURL: (NSURL *) loaderURI;

- (void) loadTOCDataWithCompletion: (void (^) (id __nullable tocData, NSError *__nullable error)) completion;
- (void) openTOCItem: (KBDocumentTOCItem *) tocItem;

@end

@interface KBDocumentTOCController: NSViewController <KBDocumentController>

@end

@interface NSViewController (KBDocumentController)

@property (nonatomic, readonly, nullable) KBDocumentController *documentController;

@end

NS_ASSUME_NONNULL_END
