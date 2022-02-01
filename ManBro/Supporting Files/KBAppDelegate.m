//
//  KBAppDelegate.m
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//

#import "KBAppDelegate.h"

#import "KBDocumentLoading.h"
#import "KBDocumentController.h"

@interface KBAppDelegate ()
@end

@implementation KBAppDelegate

- (void) applicationDidFinishLaunching: (NSNotification *) notification {
	KBManSchemeURLResolver *const resolver = [KBManSchemeURLResolver sharedResolver];
	if (!resolver.appIsDefaultManURLHandler) {
		[resolver setDefaultManURLHandlerWithCompletion:^(NSError *error) {
			if (error) {
				NSLog (@"Error: %@", error);
			}
		}];
	}
}

- (void) application: (NSApplication *) application openURLs: (NSArray <NSURL *> *) urls {
	for (NSURL *url in urls) {
		[KBDocumentController openURL:url];
	}
}

- (BOOL) applicationSupportsSecureRestorableState: (NSApplication *) app {
	return YES;
}

- (BOOL) applicationOpenUntitledFile: (NSApplication *) sender {
	[[KBDocumentController new] showWindow:sender];
	return YES;
}

- (IBAction) newDocument: (id) sender {
	[self applicationOpenUntitledFile:NSApp];
}

@end
