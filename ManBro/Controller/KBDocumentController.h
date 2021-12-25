//
//  KBDocumentController.h
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//  Copyright © 2020 Kirill byss Bystrov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface KBDocumentController: NSWindowController

- (instancetype) init;

- (instancetype) initWithWindow: (nullable NSWindow *) window NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithCoder: (NSCoder *) coder NS_DESIGNATED_INITIALIZER;

- (instancetype) initWithWindowNibName: (NSNibName) windowNibName NS_UNAVAILABLE;
- (instancetype) initWithWindowNibName: (NSNibName) windowNibName owner: (id) owner NS_UNAVAILABLE;
- (instancetype) initWithWindowNibPath: (NSString *) windowNibPath owner: (id) owner NS_UNAVAILABLE;
 
@end

@class KBDocumentMeta;
@interface KBDocumentController (documentLoading)

- (void) loadDocument: (KBDocumentMeta *) document;
- (void) loadDocumentAtURL: (NSURL *) documentURL;

@end


NS_ASSUME_NONNULL_END
