//
//  NSLayoutConstraint+convenience.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/22/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "NSLayoutConstraint+convenience.h"

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

- (NSArray <NSLayoutConstraint *> *) constrainCenterToSuperviewCenter {
	return [self constrainCenterToViewCenter:self.superview];
}

- (NSArray <NSLayoutConstraint *> *) constrainCenterToSuperviewCenterWithOffset: (CGSize) offset {
	return [self constrainCenterToViewCenter:self.superview offset:offset];
}

- (NSArray <NSLayoutConstraint *> *) constrainCenterToViewCenter: (NSView *) otherView {
	return [self constrainCenterToViewCenter:otherView offset:CGSizeZero];
}

- (NSArray <NSLayoutConstraint *> *) constrainCenterToViewCenter: (NSView *) otherView offset: (CGSize) offset {
	NSParameterAssert (otherView);
	return @[
		[self.centerXAnchor constraintEqualToAnchor:otherView.centerXAnchor constant:offset.width],
		[self.centerYAnchor constraintEqualToAnchor:otherView.centerYAnchor constant:offset.height],
	];
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

- (NSArray <NSLayoutConstraint *> *) constrainBoundsToViewBounds: (NSView *) otherView {
	return [self constrainBoundsToViewBounds:otherView withDirectionalInsets:NSDirectionalEdgeInsetsZero];
}

- (NSArray <NSLayoutConstraint *> *) constrainBoundsToViewBounds: (NSView *) otherView withInsets: (NSEdgeInsets) insets {
	return [self constrainBoundsToViewBounds:otherView insetValues:insets.top :insets.bottom :insets.left :insets.right anchorsGetters:@selector (leftAnchor) :@selector (rightAnchor)];
}

- (NSArray <NSLayoutConstraint *> *) constrainBoundsToViewBounds: (NSView *) otherView withDirectionalInsets: (NSDirectionalEdgeInsets) insets {
	return [self constrainBoundsToViewBounds:otherView insetValues:insets.top :insets.bottom :insets.leading :insets.trailing anchorsGetters:@selector (leadingAnchor) :@selector (trailingAnchor)];
}

- (NSArray <NSLayoutConstraint *> *) constrainBoundsToViewBounds: (NSView *) otherView insetValues: (CGFloat) top : (CGFloat) bottom : (CGFloat) firstHoriz : (CGFloat) secondHoriz anchorsGetters: (SEL) firstGetter : (SEL) secondGetter {
	NSParameterAssert (otherView);
	return @[
		[self.topAnchor constraintEqualToAnchor:otherView.topAnchor constant:top],
		[otherView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:bottom],
		[[self valueForKey:NSStringFromSelector (firstGetter)] constraintEqualToAnchor:[otherView valueForKey:NSStringFromSelector (firstGetter)] constant:firstHoriz],
		[[otherView valueForKey:NSStringFromSelector (secondGetter)] constraintEqualToAnchor:[self valueForKey:NSStringFromSelector (secondGetter)] constant:secondHoriz],
	];
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

@implementation NSWindow (rounding)

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
