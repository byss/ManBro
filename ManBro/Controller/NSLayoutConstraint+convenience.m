//
//  NSLayoutConstraint+convenience.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/22/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "NSLayoutConstraint+convenience.h"

#import <objc/message.h>
#import <objc/runtime.h>

@implementation NSLayoutConstraint (convenience)

+ (void) activateAllConstraintsFrom: (id) firstObject, ... {
	if (!firstObject) { return; }
	NSMutableArray <NSLayoutConstraint *> *const constraints = [NSMutableArray new];
	[self _getAllConstraintsFromObject:firstObject intoArray:constraints];
	
	va_list args;
	va_start (args, firstObject);
	for (id object; (object = va_arg (args, id)); [self _getAllConstraintsFromObject:object intoArray:constraints]);
	va_end (args);
	
	[self activateConstraints:constraints];
}

+ (void) _getAllConstraintsFromObject: (id) object intoArray: (NSMutableArray <NSLayoutConstraint *> *) array {
	if ([object isKindOfClass:[NSLayoutConstraint class]]) {
		[array addObject:object];
	} else if ([object conformsToProtocol:@protocol (NSFastEnumeration)]) {
		for (id subobject in object) {
			[self _getAllConstraintsFromObject:subobject intoArray:array];
		}
	} else if ([object respondsToSelector:@selector (objectEnumerator)]) {
		[self _getAllConstraintsFromObject:[object objectEnumerator] intoArray:array];
	}
}

- (NSLayoutConstraint *) constraintBySettingPriority: (NSLayoutPriority) priority {
	self.priority = priority;
	return self;
}

@end

@implementation NSView (convenience)

static NSArray <NSLayoutConstraint *> *KBAnchorsSourceConstrainBoundsToItemBounds (id <KBAnchorsSource> self, SEL _cmd, id <KBAnchorsSource> otherItem) {
	return KBAnchorsSourceConstrainBoundsToItemBoundsWithDirectionalInsets (self, _cmd, otherItem, NSDirectionalEdgeInsetsZero);
}

static NSArray <NSLayoutConstraint *> *KBAnchorsSourceConstrainBoundsToItemBoundsWithInsets (id <KBAnchorsSource> self, SEL _cmd, id <KBAnchorsSource> otherItem, NSEdgeInsets insets) {
	return KBAnchorsSourceConstrainBoundsToItemBoundsImpl (self, _cmd, otherItem, insets.top, insets.bottom, insets.left, insets.right, @selector (leftAnchor), @selector (rightAnchor));
}

static NSArray <NSLayoutConstraint *> *KBAnchorsSourceConstrainBoundsToItemBoundsWithDirectionalInsets (id <KBAnchorsSource> self, SEL _cmd, id <KBAnchorsSource> otherItem, NSDirectionalEdgeInsets insets) {
	return KBAnchorsSourceConstrainBoundsToItemBoundsImpl (self, _cmd, otherItem, insets.top, insets.bottom, insets.leading, insets.trailing, @selector (leadingAnchor), @selector (trailingAnchor));
}

static NSArray <NSLayoutConstraint *> *KBAnchorsSourceConstrainBoundsToItemBoundsImpl (NSObject <KBAnchorsSource> *self, SEL _cmd, NSObject <KBAnchorsSource> *otherItem, CGFloat top, CGFloat bottom, CGFloat firstHoriz, CGFloat secondHoriz, SEL firstGetter, SEL secondGetter) {
	NSParameterAssert (otherItem);
	return @[
		[self.topAnchor constraintEqualToAnchor:otherItem.topAnchor constant:top],
		[otherItem.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:bottom],
		[[self valueForKey:NSStringFromSelector (firstGetter)] constraintEqualToAnchor:[otherItem valueForKey:NSStringFromSelector (firstGetter)] constant:firstHoriz],
		[[otherItem valueForKey:NSStringFromSelector (secondGetter)] constraintEqualToAnchor:[self valueForKey:NSStringFromSelector (secondGetter)] constant:secondHoriz],
	];
}

static NSArray <NSLayoutConstraint *> *KBAnchorsSourceConstrainCenterToItemCenter (id <KBAnchorsSource> self, SEL _cmd, id <KBAnchorsSource> otherItem) {
	return KBAnchorsSourceConstrainCenterToItemCenterWithOffset (self, _cmd, otherItem, NSZeroSize);
}

static NSArray <NSLayoutConstraint *> *KBAnchorsSourceConstrainCenterToItemCenterWithOffset (id <KBAnchorsSource> self, SEL _cmd, id <KBAnchorsSource> otherItem, NSSize offset) {
	NSParameterAssert (otherItem);
	return @[
		[self.centerXAnchor constraintEqualToAnchor:otherItem.centerXAnchor constant:offset.width],
		[self.centerYAnchor constraintEqualToAnchor:otherItem.centerYAnchor constant:offset.height],
	];
}

+ (void) load {
	static struct {
		char const *viewSelector;
		char const *anchorsSourceSelector;
		IMP implementation;
		char const *typeEncoding;
	} const selectors [] = {
		{ "constrainCenterToViewCenter:", "constrainCenterToItemCenter:", (IMP) KBAnchorsSourceConstrainCenterToItemCenter, "@@:@" },
		{ "constrainCenterToViewCenter:offset:", "constrainCenterToItemCenter:offset:", (IMP) KBAnchorsSourceConstrainCenterToItemCenterWithOffset, "@@:@{CGSize=dd}" },
		{ "constrainBoundsToViewBounds:", "constrainBoundsToItemBounds:", (IMP) KBAnchorsSourceConstrainBoundsToItemBounds, "@@:@" },
		{ "constrainBoundsToViewBounds:withInsets:;", "constrainBoundsToItemBounds:withInsets:", (IMP) KBAnchorsSourceConstrainBoundsToItemBoundsWithInsets, "@@:@{NSEdgeInsets=dddd}" },
		{ "constrainBoundsToViewBounds:withDirectionalInsets:", "constrainBoundsToItemBounds:withDirectionalInsets:", (IMP) KBAnchorsSourceConstrainBoundsToItemBoundsWithDirectionalInsets, "@@:@{NSDirectionalEdgeInsets=dddd}" },
		{ NULL, NULL },
	};
	Class const viewClass = [NSView class], layoutGuideClass = [NSLayoutGuide class];
	for (typeof (*selectors) *i = selectors; i->viewSelector; i++) {
		class_addMethod (viewClass, sel_getUid (i->viewSelector), i->implementation, i->typeEncoding);
		class_addMethod (viewClass, sel_getUid (i->anchorsSourceSelector), i->implementation, i->typeEncoding);
		class_addMethod (layoutGuideClass, sel_getUid (i->anchorsSourceSelector), i->implementation, i->typeEncoding);
	}
}

- (NSArray <NSLayoutConstraint *> *) constrainCenterToSuperviewCenter {
	return [self constrainCenterToViewCenter:self.superview];
}

- (NSArray <NSLayoutConstraint *> *) constrainCenterToSuperviewCenterWithOffset: (NSSize) offset {
	return [self constrainCenterToViewCenter:self.superview offset:offset];
}

- (NSArray <NSLayoutConstraint *> *) constrainBoundsToSuperviewBounds {
	return [self constrainBoundsToViewBounds:self.superview];
}

- (NSArray <NSLayoutConstraint *> *) constrainBoundsToSuperviewBoundsWithInsets: (NSEdgeInsets) insets {
	return [self constrainBoundsToViewBounds:self.superview withInsets:insets];
}

- (NSArray <NSLayoutConstraint *> *) constrainBoundsToSuperviewBoundsWithDirectionalInsets: (NSDirectionalEdgeInsets) insets {
	return [self constrainBoundsToViewBounds:self.superview withDirectionalInsets:insets];
}

@end

@implementation NSLayoutAnchor (convenience)

- (NSLayoutConstraint *) constraintEqualToAnchor:(NSLayoutAnchor *) anchor priority: (NSLayoutPriority) priority {
	return [self constraintEqualToAnchor:anchor constant:0.0 priority:priority];
}

- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor:(NSLayoutAnchor *) anchor priority: (NSLayoutPriority) priority {
	return [self constraintGreaterThanOrEqualToAnchor:anchor constant:0.0 priority:priority];
}

- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor:(NSLayoutAnchor *) anchor priority: (NSLayoutPriority) priority {
	return [self constraintLessThanOrEqualToAnchor:anchor constant:0.0 priority:priority];
}

- (NSLayoutConstraint *) constraintEqualToAnchor:(NSLayoutAnchor *) anchor constant: (CGFloat) c priority: (NSLayoutPriority) priority {
	return [[self constraintEqualToAnchor:anchor constant:c] constraintBySettingPriority:priority];
}

- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor:(NSLayoutAnchor *) anchor constant: (CGFloat) c priority: (NSLayoutPriority) priority {
	return [[self constraintGreaterThanOrEqualToAnchor:anchor constant:c] constraintBySettingPriority:priority];
}

- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor:(NSLayoutAnchor *) anchor constant: (CGFloat) c priority: (NSLayoutPriority) priority {
	return [[self constraintLessThanOrEqualToAnchor:anchor constant:c] constraintBySettingPriority:priority];
}

@end

@implementation NSLayoutDimension (convenience)

- (NSLayoutConstraint *) constraintEqualToConstant: (CGFloat) c priority: (NSLayoutPriority) priority {
	return [[self constraintEqualToConstant:c] constraintBySettingPriority:priority];
}

- (NSLayoutConstraint *) constraintGreaterThanOrEqualToConstant: (CGFloat) c priority: (NSLayoutPriority) priority {
	return [[self constraintGreaterThanOrEqualToConstant:c] constraintBySettingPriority:priority];
}

- (NSLayoutConstraint *) constraintLessThanOrEqualToConstant: (CGFloat) c priority: (NSLayoutPriority) priority {
	return [[self constraintLessThanOrEqualToConstant:c] constraintBySettingPriority:priority];
}

- (NSLayoutConstraint *) constraintEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m priority: (NSLayoutPriority) priority {
	return [self constraintEqualToAnchor:anchor multiplier:m constant:0.0 priority:priority];
}

- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor: (NSLayoutDimension  *) anchor multiplier: (CGFloat) m priority: (NSLayoutPriority) priority {
	return [self constraintGreaterThanOrEqualToAnchor:anchor multiplier:m constant:0.0 priority:priority];
}

- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor: (NSLayoutDimension  *) anchor multiplier: (CGFloat) m priority: (NSLayoutPriority) priority {
	return [self constraintLessThanOrEqualToAnchor:anchor multiplier:m constant:0.0 priority:priority];
}

- (NSLayoutConstraint *) constraintEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m constant: (CGFloat) c priority: (NSLayoutPriority) priority {
	return [[self constraintEqualToAnchor:anchor multiplier:m constant:c] constraintBySettingPriority:priority];
}

- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m constant: (CGFloat) c priority: (NSLayoutPriority) priority {
	return [[self constraintGreaterThanOrEqualToAnchor:anchor multiplier:m constant:c] constraintBySettingPriority:priority];
}

- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m constant: (CGFloat) c priority: (NSLayoutPriority) priority {
	return [[self constraintLessThanOrEqualToAnchor:anchor multiplier:m constant:c] constraintBySettingPriority:priority];
}

@end

static void KBPixelRoundingSetup (Class self, SEL implGetter) {
	static unsigned methodCount;
	static struct objc_method_description *methods;
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		methods = protocol_copyMethodDescriptionList (@protocol (KBPixelRounding), YES, YES, &methodCount);
	});
	id <KBPixelRounding> (*implGetterIMP) (id, SEL) = (typeof (implGetterIMP)) class_getMethodImplementation (self, implGetter);
	for (unsigned i = 0; i < methodCount; i++) {
		struct objc_method_description const *const method = methods + i;
		IMP impl;
		if (method->name == @selector (roundValue:mode:)) {
			impl = imp_implementationWithBlock (^(id self, CGFloat value, int roundingMode) {
				return [implGetterIMP (self, implGetter) roundValue:value mode:roundingMode];
			});
		} else {
			impl = imp_implementationWithBlock (^(id self, CGFloat value) {
				return ((CGFloat (*) (id, SEL, CGFloat)) objc_msgSend) (implGetterIMP (self, implGetter), method->name, value);
			});
		}
		class_addMethod (self, method->name, impl, method->types);
	}
}

@implementation NSWindow (KBPixelRounding)

+ (void) load {
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken, ^{
		KBPixelRoundingSetup ([NSView class], @selector (window));
		KBPixelRoundingSetup ([NSWindowController class], @selector (window));
		KBPixelRoundingSetup ([NSViewController class], @selector (view));
	});
}

- (CGFloat) ceilValue: (CGFloat) value {
	return [self roundValue:value mode:FE_UPWARD];
}

- (CGFloat) floorValue: (CGFloat) value {
	return [self roundValue:value mode:FE_DOWNWARD];
}

- (CGFloat) truncValue: (CGFloat) value {
	return [self roundValue:value mode:FE_TOWARDZERO];
}

- (CGFloat) roundValue: (CGFloat) value {
	return [self roundValue:value mode:FE_TONEAREST];
}

- (CGFloat) roundValue: (CGFloat) value mode: (int) roundingMode {
	CGFloat const scale = self.backingScaleFactor, scaledValue = value * scale;
	CGFloat roundedScaledValue;
	switch (roundingMode) {
	case FE_UPWARD: roundedScaledValue = ceil (scaledValue); break;
	case FE_DOWNWARD: roundedScaledValue = floor (scaledValue); break;
	case FE_TOWARDZERO: roundedScaledValue = trunc (scaledValue); break;
	case FE_TONEAREST: roundedScaledValue = round (scaledValue); break;
	default: NSAssert (NO, @"Unknown rounding mode %d", roundingMode); __builtin_unreachable ();
	}
	return roundedScaledValue / scale;
}

@end
