//
//  KBAppDelegate.m
//  ManBro
//
//  Created by Kirill Bystrov on 12/1/20.
//

#import "KBAppDelegate.h"

#import "KBIndexManager.h"
#import "CoreData+logging.h"
#import "KBDocumentLoading.h"
#import "KBDocumentController.h"
#import "NSPersistentContainer+sharedContainer.h"

#define LOG_PROGRESS_TREE 0

@interface KBAppDelegate () {
	KBIndexManager *_indexManager;
	NSTimeInterval _prefixesScanTimestamp;
#if DEBUG
	dispatch_queue_t _logQueue;
	long _lastProgressPromille;
#endif
}

@end

#if DEBUG && LOG_PROGRESS_TREE
@interface NSProgress (safeRecursiveDescription)

@property (nonatomic, readonly) NSString *safeRecursiveDescription;

@end
#endif

static NSString *const KBPrefixUpdateLastTimestampKey = @"lastPrefixesScanTimestamp";

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
	KBManSchemeURLResolver *const resolver = [KBManSchemeURLResolver sharedResolver];
	for (NSURL *url in urls) {
		if (![url.scheme isEqualToString:KBManScheme]) { continue; }
		[resolver resolveManURL:url relativeToDocumentURL:nil completion:^(NSURL *resolvedURL, NSError *error) {
			dispatch_async (dispatch_get_main_queue (), ^{
				if (error) { return (void) [NSApp presentError:error]; }
				KBDocumentController *const controller = [KBDocumentController new];
				[controller.window makeKeyAndOrderFront:nil];
				[controller loadDocumentAtURL:resolvedURL];
			});
		}];
	}
}

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
#if DEBUG
		_logQueue = dispatch_queue_create ("IndexUpdateLogging", dispatch_queue_attr_make_with_qos_class (DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, QOS_CLASS_USER_INITIATED, 0));
		_lastProgressPromille = -1;
		[_indexManager.progress addObserver:self forKeyPath:@"fractionCompleted" options:0 context:NULL];
#endif
		[_indexManager runWithCompletion:^{
			dispatch_async (dispatch_get_main_queue (), ^{
				NSTimeInterval const timestamp = [NSDate timeIntervalSinceReferenceDate];
				NSUserDefaults *const defaults = [NSUserDefaults standardUserDefaults];
				[defaults setDouble:timestamp forKey:KBPrefixUpdateLastTimestampKey];
				[defaults synchronize];
				self->_prefixesScanTimestamp = timestamp;
#if DEBUG
				[self->_indexManager.progress removeObserver:self forKeyPath:@"fractionCompleted" context:NULL];
				self->_logQueue = NULL;
#endif
				self->_indexManager = nil;
			});
		}];
	}
}

- (BOOL) shouldScanPrefixesNow {
	return !_indexManager && (!_prefixesScanTimestamp || (([NSDate timeIntervalSinceReferenceDate] - _prefixesScanTimestamp) > 3600.0));
}

#if DEBUG
- (void) observeValueForKeyPath: (NSString *) keyPath ofObject: (id) object change: (NSDictionary <NSKeyValueChangeKey, id> *) change context: (void *) context {
	if ((object == _indexManager.progress) && [keyPath isEqualToString:@"fractionCompleted"]) {
		double const progress = _indexManager.progress.fractionCompleted;
		long const progressPromille = lrint (progress * 1000.0);
		if (progressPromille != _lastProgressPromille) {
			_lastProgressPromille = progressPromille;
#	if LOG_PROGRESS_TREE
			NSString *const description = _indexManager.progress.safeRecursiveDescription;
#	endif
			dispatch_async (_logQueue, ^{
				NSLog (@"Progress: %.1f%%", progress * 100.0);
#	if LOG_PROGRESS_TREE
				NSLog (@"%@", description);
#	endif
			});
		}
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}
#endif

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

#if DEBUG && LOG_PROGRESS_TREE

#import <objc/runtime.h>

@implementation NSProgress (safeRecursiveDescription)

- (NSSet <NSProgress *> *) safeChildren {
	static Ivar childrenIvar;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{ childrenIvar = class_getInstanceVariable ([NSProgress class], "_children"); });
	return [object_getIvar (self, childrenIvar) copy];
}

- (NSString *)  safeRecursiveDescription {
	return [self safeRecursiveDescriptionWithLevel:0];
}

- (NSString *)  safeRecursiveDescriptionWithLevel: (int) level {
	NSMutableString *result = [[NSMutableString alloc] initWithFormat:@"%*s<%@: %p>: Fraction completed: %.4f / Completed: %ld of %ld", level * 2, "", self.class, self, self.fractionCompleted, (long) self.completedUnitCount, (long) self.totalUnitCount];
	NSSet <NSProgress *> *const children = self.safeChildren;
	for (NSProgress *child in children) {
		[result appendFormat:@"\n%@", [child safeRecursiveDescriptionWithLevel:level + 1]];
	}
	return result;
}

@end
#endif
