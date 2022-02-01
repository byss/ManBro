//
//  NSURL+filesystem.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/17/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "NSURL+filesystem.h"

#import <dns_sd.h>
#import <ifaddrs.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import "NSError+convenience.h"

@implementation NSURL (ManBro)

+ (NSArray <NSURLResourceKey> *) readableDirectoryAndGenerationIdentifierKeys {
	static NSArray <NSURLResourceKey> *readableDirectoryAndGenerationIdentifierKeys;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		readableDirectoryAndGenerationIdentifierKeys = [NSURL.readableDirectoryKeys arrayByAddingObject:NSURLGenerationIdentifierKey];
	});
	return readableDirectoryAndGenerationIdentifierKeys;
}

+ (NSArray <NSURLResourceKey> *) readableRegularFileAndGenerationIdentifierKeys {
	static NSArray <NSURLResourceKey> *readableRegularFileAndGenerationIdentifierKeys;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		readableRegularFileAndGenerationIdentifierKeys = [NSURL.readableRegularFileKeys arrayByAddingObject:NSURLGenerationIdentifierKey];
	});
	return readableRegularFileAndGenerationIdentifierKeys;
}

- (NSString *) manSectionName {
	if (self.pathExtension.length) {
		return nil;
	}
	
	static NSString *const manSectionNamePrefix = @"man";
	NSString *const basename = self.lastPathComponent;
	if (![basename hasPrefix:manSectionNamePrefix]) {
		return nil;
	}
	
	return [basename substringFromIndex:manSectionNamePrefix.length];
}

- (NSString *) manDocumentTitle {
	NSString *const sectionName = self.URLByDeletingLastPathComponent.manSectionName;
	if (!sectionName) { return nil; }
	
	static NSArray <NSString *> *const additionalExtensions = @[ @"gz" ];
	NSURL *documentURL = self.absoluteURL.standardizedURL;
	while ([additionalExtensions containsObject:documentURL.pathExtension]) {
		documentURL = documentURL.URLByDeletingPathExtension;
	}
	if ([documentURL.pathExtension hasPrefix:sectionName]) {
		documentURL = documentURL.URLByDeletingPathExtension;
	} else {
		return nil;
	}
	
	return documentURL.lastPathComponent;
}

@end

@implementation NSDictionary (resourceValues)

- (BOOL) isReadableRegularFile {
	return [self checkResourceValuesForKeys:NSURL.readableRegularFileKeys];
}

- (BOOL) isReadableDirectory {
	return [self checkResourceValuesForKeys:NSURL.readableDirectoryKeys];
}

- (BOOL) checkResourceValuesForKeys: (NSArray <NSURLResourceKey> *) keys {
	for (NSURLResourceKey key in keys) {
		if (![[self objectForKey:key] boolValue]) {
			return NO;
		}
	}
	return YES;
}

@end

@interface NSString (extendedEquality)

- (BOOL) isCaseInsensitiveEqualToString: (NSString *) aString;
- (BOOL) isEqualToString: (NSString *) aString options: (NSStringCompareOptions) options;
- (BOOL) isEqualToString: (NSString *) aString options: (NSStringCompareOptions) options range: (NSRange) rangeOfReceiverToSearch;
- (BOOL) isEqualToString: (NSString *) aString options: (NSStringCompareOptions) options range: (NSRange) rangeOfReceiverToSearch locale: (NSLocale *) locale;

@end

@implementation NSURL (filesystem)

+ (dispatch_queue_t) hostResolverQueue {
	static dispatch_queue_t hostResolverQueue;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		hostResolverQueue = dispatch_queue_create ("HostResolver", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
	});
	return hostResolverQueue;
}

+ (NSArray <NSURLResourceKey> *) readableRegularFileKeys {
	static NSArray <NSURLResourceKey> *readableRegularFileKeys = nil;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		readableRegularFileKeys = [[NSArray alloc] initWithObjects:NSURLIsReadableKey, NSURLIsRegularFileKey, nil];
	});
	return readableRegularFileKeys;
}

+ (NSArray <NSURLResourceKey> *) readableDirectoryKeys {
	static NSArray <NSURLResourceKey> *readableDirectoryKeys = nil;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		readableDirectoryKeys = [[NSArray alloc] initWithObjects:NSURLIsReadableKey, NSURLIsDirectoryKey, NSURLIsExecutableKey, nil];
	});
	return readableDirectoryKeys;
}

- (NSString *) fileSystemPath {
	if (!self.isFileURL) { return nil; }
	char const *const result = self.fileSystemRepresentation;
	return result ? @(result) : nil;
}

- (BOOL) isReadableRegularFile {
	return [self isReadableRegularFile:NULL];
}

- (BOOL) isReadableDirectory {
	return [self isReadableDirectory:NULL];
}

- (BOOL) isReadableRegularFile: (NSError *__autoreleasing *) error {
	return [self checkResourceValuesForKeys:self.class.readableRegularFileKeys error:error];
}

- (BOOL) isReadableDirectory: (NSError *__autoreleasing *) error {
	return [self checkResourceValuesForKeys:self.class.readableDirectoryKeys error:error];
}

- (BOOL) checkResourceValuesForKeys: (NSArray <NSURLResourceKey> *) keys error: (NSError *__autoreleasing *) error {
	NSDictionary <NSURLResourceKey, id> *const valuesDict = [self.URLByResolvingSymlinksInPath resourceValuesForKeys:keys error:error];
	if (valuesDict) {
		if ([valuesDict checkResourceValuesForKeys:keys]) { return YES; }
		NSOutErr (error, [[NSError alloc] initPOSIXErrorWithCode:EFTYPE]);
	}
	return NO;
}

static void SCSharedDynamicStoreCallback (SCDynamicStoreRef store, CFArrayRef changedKeys, void *infoPtr) {
	NSCache <NSString *, id> *const cachedValues = (__bridge id) infoPtr;
	NSDictionary <NSString *, id> *const update = (__bridge_transfer id) SCDynamicStoreCopyMultiple (store, changedKeys, NULL);
	for (NSString *key in (__bridge id) changedKeys) {
		id const value = update [key];
		value ? [cachedValues setObject:value forKey:key] : [cachedValues removeObjectForKey:key];
	}
}

static id SCSharedDynamicStoreCopyObservedValue (CFStringRef (*keyGetter) (CFAllocatorRef)) NS_RETURNS_RETAINED {
	static SCDynamicStoreRef store;
	static NSCache <NSString *, id> *cachedValues;
	static NSMutableSet <NSString *> *observedKeys;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		cachedValues = [NSCache new];
		cachedValues.name = @"SCSharedDynamicStore cached values";
		observedKeys = [NSMutableSet new];
		CFStringRef const storeName = (__bridge CFStringRef) [[NSBundle mainBundle] objectForInfoDictionaryKey:(id) kCFBundleNameKey];
		store = SCDynamicStoreCreate (NULL, storeName, SCSharedDynamicStoreCallback, (SCDynamicStoreContext []) {{ .info = (__bridge void *) cachedValues }});
		SCDynamicStoreSetDispatchQueue (store, [NSURL hostResolverQueue]);
	});

	CFStringRef const cfKey = keyGetter (NULL);
	NSString *const nsKey = (__bridge_transfer NSString *) cfKey;
	if ([observedKeys containsObject:nsKey]) {
		return [cachedValues objectForKey:nsKey];
	}
	
	__block id result;
	dispatch_sync ([NSURL hostResolverQueue], ^{
		if ([observedKeys containsObject:nsKey]) {
			result = [cachedValues objectForKey:nsKey];
		} else {
			if ((result = (__bridge_transfer id) SCDynamicStoreCopyValue (store, cfKey))) {
				[cachedValues setObject:result forKey:nsKey];
			}
			[observedKeys addObject:nsKey];
			SCDynamicStoreSetNotificationKeys (store, (CFArrayRef) observedKeys.allObjects, NULL);
		}
	});
	return result;
}

- (void) checkHostResolvesToCurrentMachineWithCompletion: (void (^) (BOOL result, NSError *error)) completion {
	static id (^const localHostNameGetters []) (void) = {
		^{ return @"localhost"; },
		^{ return [NSProcessInfo processInfo].hostName; },
		^{ return SCSharedDynamicStoreCopyObservedValue (SCDynamicStoreKeyCreateHostNames); },
		^{ return SCSharedDynamicStoreCopyObservedValue (SCDynamicStoreKeyCreateComputerName); },
	};
	
	NSString *const host = self.host;
	if (!host.length) { return completion (YES, nil); }
	for (size_t i = 0; i < sizeof (localHostNameGetters) / sizeof (*localHostNameGetters); i++) {
		id const localHostName = localHostNameGetters [i] ();
		if ([localHostName isKindOfClass:[NSString class]] && [host isCaseInsensitiveEqualToString:localHostName]) { return completion (YES, nil); }
		if ([localHostName conformsToProtocol:@protocol (NSFastEnumeration)]) {
			for (NSString *localHostNameItem in localHostName) {
				if ([host isCaseInsensitiveEqualToString:localHostNameItem]) { return completion (YES, nil); }
			}
		}
	}
	
	static DNSServiceRef sharedRef;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		DNSServiceCreateConnection (&sharedRef);
		DNSServiceSetDispatchQueue (sharedRef, self.class.hostResolverQueue);
	});
	
	__block BOOL completionInvoked = NO;
	DNSServiceRef sdRef = sharedRef;
	DNSServiceErrorType const error = DNSServiceGetAddrInfo (&sdRef, kDNSServiceFlagsShareConnection | kDNSServiceFlagsTimeout, 0, 0, host.UTF8String, NSURLCheckHostResolvesToCurrentMachineCallback, (__bridge_retained void *) [^(BOOL result, NSError *error) {
		if (!completionInvoked) {
			completion (result, error);
			completionInvoked = YES;
		}
	} copy]);
	if (error != kDNSServiceErr_NoError) {
		completion (NO, [[NSError alloc] initWithDomain:@"DNSSD" code:error userInfo:nil]);
	}
}

static void NSURLCheckHostResolvesToCurrentMachineCallback (DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, const char *hostname, const struct sockaddr *address, uint32_t ttl, void *context) {
	void (^completion) (BOOL result, NSError *error) = [(__bridge id) context copy];
	if (!(flags & kDNSServiceFlagsMoreComing)) { CFRelease (context); }
	BOOL const success = errorCode == kDNSServiceErr_NoError;
	if (success && address) {
		struct ifaddrs *ifaddrs;
		if (getifaddrs (&ifaddrs)) { return completion (NO, success ? nil : [[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]); }
		
		BOOL result = NO;
		for (struct ifaddrs *i = ifaddrs; i; i = i->ifa_next) {
			if ((i->ifa_addr->sa_len == address->sa_len) && !memcmp (i->ifa_addr, address, address->sa_len)) {
				result = YES;
				break;
			}
		}
		freeifaddrs (ifaddrs);
		if (result) { return completion (YES, nil); }
	}
	
	if (!(flags & kDNSServiceFlagsMoreComing)) { completion (NO, success ? nil : [[NSError alloc] initWithDomain:@"DNSSD" code:errorCode userInfo:nil]); }
}

@end

@implementation NSString (extendedEquality)

- (BOOL) isCaseInsensitiveEqualToString: (NSString *) aString {
	return [self isEqualToString:aString options:NSCaseInsensitiveSearch];
}

- (BOOL) isEqualToString: (NSString *) aString options: (NSStringCompareOptions) options {
	return [self compare:aString options:options] == NSOrderedSame;
}

- (BOOL) isEqualToString: (NSString *) aString options: (NSStringCompareOptions) options range: (NSRange) rangeOfReceiverToSearch {
	return [self compare:aString options:options range:rangeOfReceiverToSearch] == NSOrderedSame;
}

- (BOOL) isEqualToString: (NSString *) aString options: (NSStringCompareOptions) options range: (NSRange) rangeOfReceiverToSearch locale: (NSLocale *) locale {
	return [self compare:aString options:options range:rangeOfReceiverToSearch locale:locale] == NSOrderedSame;
}

@end
