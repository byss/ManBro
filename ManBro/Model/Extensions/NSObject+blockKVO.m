//
//  NSObject+blockKVO.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 1/5/22.
//  Copyright © 2022 Kirill byss Bystrov. All rights reserved.
//

#import "NSObject+blockKVO.h"

#import <os/log.h>
#import <objc/runtime.h>

@interface KBKVOBlockObserver: NSObject

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype) init NS_UNAVAILABLE;

- (instancetype) initWithObject: (id) object keyPath: (NSString *) keyPath options: (NSKeyValueObservingOptions) options actionBlock: (void (^) (NSDictionary <NSKeyValueChangeKey, id> *)) actionBlock;
- (instancetype) initWithObject: (id) object keyPath: (NSString *) keyPath options: (NSKeyValueObservingOptions) options actionBlock: (void (^) (NSDictionary <NSKeyValueChangeKey, id> *)) actionBlock invalidationBlock: (void (^) (KBKVOBlockObserver *)) invalidationBlock NS_DESIGNATED_INITIALIZER;

- (void) invalidate;

@end

@implementation NSObject (blockKVOConvenience)

- (id <NSObject>) observeObject: (id) object keyPath: (NSString *) keyPath usingBlock: (void (^) (void)) observerBlock {
	return [self observeObject:object keyPath:keyPath options:NSKeyValueObservingOptionAutoremove usingBlock:^(id change) { observerBlock (); }];
}

- (id <NSObject>) observeObject: (id) object keyPath: (NSString *) keyPath options: (NSKeyValueObservingOptions) options usingBlock: (void (^) (NSDictionary <NSKeyValueChangeKey, id> *)) observerBlock {
	id <NSObject> const observer = [[KBKVOBlockObserver alloc] initWithObject:object keyPath:keyPath options:options actionBlock:observerBlock invalidationBlock:^(id observer) {
		objc_setAssociatedObject (self, (__bridge void const *) observer, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}];
	objc_setAssociatedObject (self, (__bridge void const *) observer, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	return observer;
}

@end

@implementation NSObject (blockKVO)

- (id <NSObject>) observeValueForKeyPath: (NSString *) keyPath usingBlock: (void (^) (void)) observerBlock {
	return [self observeValueForKeyPath:keyPath options:NSKeyValueObservingOptionAutoremove usingBlock:^(id change) { observerBlock (); }];
}

- (id <NSObject>) observeValueForKeyPath: (NSString *) keyPath options: (NSKeyValueObservingOptions) options usingBlock: (void (^) (NSDictionary <NSKeyValueChangeKey, id> *)) observerBlock {
	return [[KBKVOBlockObserver alloc] initWithObject:self keyPath:keyPath options:options actionBlock:observerBlock];
}

- (void) removeBlockObserver: (id <NSObject>) observer {
	[observer isKindOfClass:[KBKVOBlockObserver class]] ? [(KBKVOBlockObserver *) observer invalidate] : (void) 0;
}

@end

@interface KBKVOBlockObserver () {
	dispatch_block_t _invalidationBlock;
#if DEBUG
	NSString *_debugDescription;
#endif
}

@property (nonatomic, readonly, getter = isInvalid) BOOL invalid;
@property (nonatomic, readonly) BOOL shouldAutoremove;
@property (nonatomic, readonly) void (^actionBlock) (NSDictionary <NSKeyValueChangeKey, id> *);

@end

@implementation KBKVOBlockObserver

- (instancetype) init { return [self initWithObject:nil keyPath:nil options:0 actionBlock:NULL]; }

- (instancetype) initWithObject: (id) object keyPath: (NSString *) keyPath options: (NSKeyValueObservingOptions) options actionBlock: (void (^) (NSDictionary <NSKeyValueChangeKey, id> *)) actionBlock {
	return [self initWithObject:object keyPath:keyPath options:options actionBlock:actionBlock invalidationBlock:NULL];
}

- (instancetype) initWithObject: (id) object keyPath: (NSString *) keyPath options: (NSKeyValueObservingOptions) options actionBlock: (void (^) (NSDictionary <NSKeyValueChangeKey, id> *)) actionBlock invalidationBlock: (void (^) (KBKVOBlockObserver *)) invalidationBlock {
	if (!(object && keyPath.length && actionBlock)) { return nil; }
	if (self = [super init]) {
		_shouldAutoremove = !!(options & NSKeyValueObservingOptionAutoremove);
		_actionBlock = [actionBlock copy];
		
		[object addObserver:self forKeyPath:keyPath options:options & ~NSKeyValueObservingOptionAutoremove context:NULL];
		__unsafe_unretained typeof (self) unsafeSelf = self;
		_invalidationBlock = ^{
			typeof (self) self = unsafeSelf;
			invalidationBlock ? invalidationBlock (self) : (void) 0;
			[object removeObserver:self forKeyPath:keyPath context:NULL];
			self->_invalidationBlock = NULL;
		};
		
#if DEBUG
		_debugDescription = [[NSString alloc] initWithFormat:@"keyPath: %@; object: %@", [object debugDescription], keyPath];
#endif
	}
	return self;
}

- (void) dealloc {
	if (self.shouldAutoremove) {
		[self invalidate];
#if DEBUG
	} else if (!self.invalid) {
			os_log_t const log = os_log_create ("NSObject", "BlockKVO");
			os_log_error (log, "%@ is being deallocated while observing; trouble ahead", self);
#endif
	}
}

#if DEBUG
- (NSString *) debugDescription {
	return [[NSString alloc] initWithFormat:@"<%@: %p; %@; %@; %@>", self.class, self, self.invalid ? @"invalidated" : @"observing", self.shouldAutoremove ? @"autoremoves" : @"default", _debugDescription];
}
#endif

- (void) observeValueForKeyPath: (NSString *) keyPath ofObject: (id) object change: (NSDictionary <NSKeyValueChangeKey, id> *) change context: (void *) context {
	self.actionBlock (change);
}

- (BOOL) isInvalid {
	return !_invalidationBlock;
}

- (void) invalidate {
	_invalidationBlock ? _invalidationBlock () : (void) 0;
}

@end
