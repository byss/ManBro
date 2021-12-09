//
//  KBAppDelegate.m
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//

#import "KBAppDelegate.h"

#import "CoreData+logging.h"
#import "KBIndexManager.h"
#import "KBDocumentController.h"
#import "NSPersistentContainer+sharedContainer.h"

@interface KBAppDelegate () {
	KBIndexManager *_indexManager;
	NSTimeInterval _prefixesScanTimestamp;
}

@end


static NSString *const KBPrefixUpdateLastTimestampKey = @"lastPrefixesScanTimestamp";

@implementation KBAppDelegate

- (BOOL) applicationOpenUntitledFile: (NSApplication *) sender {
	[[KBDocumentController new].window makeKeyAndOrderFront:sender];
	return YES;
}

- (IBAction) newDocument: (id) sender {
	[self applicationOpenUntitledFile:NSApp];
}

- (void) applicationDidBecomeActive: (NSNotification *) notification {
	if ([self shouldScanPrefixesNow]) {
		_indexManager = [KBIndexManager new];
		[_indexManager.progress addObserver:self forKeyPath:@"fractionCompleted" options:0 context:NULL];
		[_indexManager runWithCompletion:^{
			NSTimeInterval const timestamp = [NSDate timeIntervalSinceReferenceDate];
			NSUserDefaults *const defaults = [NSUserDefaults standardUserDefaults];
			[defaults setDouble:timestamp forKey:KBPrefixUpdateLastTimestampKey];
			[defaults synchronize];
			self->_prefixesScanTimestamp = timestamp;
			[self->_indexManager.progress removeObserver:self forKeyPath:@"fractionCompleted" context:NULL];
			self->_indexManager = nil;
		}];
	}
}

- (BOOL) shouldScanPrefixesNow {
	return !_indexManager && (!_prefixesScanTimestamp || (([NSDate timeIntervalSinceReferenceDate] - _prefixesScanTimestamp) > 3600.0));
}

- (void) observeValueForKeyPath: (NSString *) keyPath ofObject: (id) object change: (NSDictionary <NSKeyValueChangeKey, id> *) change context: (void *) context {
	if ((object == _indexManager.progress) && [keyPath isEqualToString:@"fractionCompleted"]) {
		NSLog (@"Progress: %.1f%%", _indexManager.progress.fractionCompleted * 100.0);
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

#if 0

#pragma mark - Core Data Saving and Undo support

- (IBAction)saveAction:(id)sender {
    // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
    NSManagedObjectContext *context = self.persistentContainer.viewContext;

    if (![context commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }
    
    NSError *error = nil;
    if (context.hasChanges && ![context save:&error]) {
        // Customize this code block to include application-specific recovery steps.
        [[NSApplication sharedApplication] presentError:error];
    }
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
    return self.persistentContainer.viewContext.undoManager;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    // Save changes in the application's managed object context before the application terminates.
    NSManagedObjectContext *context = self.persistentContainer.viewContext;

    if (![context commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }
    
    if (!context.hasChanges) {
        return NSTerminateNow;
    }
    
    NSError *error = nil;
    if (![context save:&error]) {

        // Customize this code block to include application-specific recovery steps.
        BOOL result = [sender presentError:error];
        if (result) {
            return NSTerminateCancel;
        }

        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];

        NSInteger answer = [alert runModal];
        
        if (answer == NSAlertSecondButtonReturn) {
            return NSTerminateCancel;
        }
    }

    return NSTerminateNow;
}
#endif

@end
