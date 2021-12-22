//
//  NSLayoutConstraint+convenience.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/22/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

static const NSLayoutPriority NSLayoutPriorityAlmostIgnored = 1.0f;
static const NSLayoutPriority NSLayoutPriorityAlmostRequired = 999.0f;

@interface NSLayoutConstraint (convenience)

+ (void) activateAllConstraintsFrom: (id) firstObject, ... NS_REQUIRES_NIL_TERMINATION;

@end

@interface NSView (convenience)

- (NSArray <NSLayoutConstraint *> *) constrainCenterToSuperviewCenter;
- (NSArray <NSLayoutConstraint *> *) constrainCenterToSuperviewCenterWithOffset: (CGSize) offset;

- (NSArray <NSLayoutConstraint *> *) constrainCenterToViewCenter: (NSView *) otherView;
- (NSArray <NSLayoutConstraint *> *) constrainCenterToViewCenter: (NSView *) otherView offset: (CGSize) offset;

- (NSArray <NSLayoutConstraint *> *) constrainBoundsToSuperviewBounds;
- (NSArray <NSLayoutConstraint *> *) constrainBoundsToSuperviewBoundsWithInsets: (NSEdgeInsets) insets;
- (NSArray <NSLayoutConstraint *> *) constrainBoundsToSuperviewBoundsWithDirectionalInsets: (NSDirectionalEdgeInsets) insets;

- (NSArray <NSLayoutConstraint *> *) constrainBoundsToViewBounds: (NSView *) otherView;
- (NSArray <NSLayoutConstraint *> *) constrainBoundsToViewBounds: (NSView *) otherView withInsets: (NSEdgeInsets) insets;
- (NSArray <NSLayoutConstraint *> *) constrainBoundsToViewBounds: (NSView *) otherView withDirectionalInsets: (NSDirectionalEdgeInsets) insets;

@end

@interface NSLayoutAnchor <AnchorType> (convenience)

- (NSLayoutConstraint *) constraintEqualToAnchor:(NSLayoutAnchor <AnchorType> *) anchor priority: (NSLayoutPriority) priority NS_WARN_UNUSED_RESULT;
- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor:(NSLayoutAnchor <AnchorType> *) anchor priority: (NSLayoutPriority) priority NS_WARN_UNUSED_RESULT;
- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor:(NSLayoutAnchor <AnchorType> *) anchor priority: (NSLayoutPriority) priority NS_WARN_UNUSED_RESULT;

- (NSLayoutConstraint *) constraintEqualToAnchor:(NSLayoutAnchor <AnchorType> *) anchor constant: (CGFloat) c priority: (NSLayoutPriority) priority NS_WARN_UNUSED_RESULT;
- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor:(NSLayoutAnchor <AnchorType> *) anchor constant: (CGFloat) c priority: (NSLayoutPriority) priority NS_WARN_UNUSED_RESULT;
- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor:(NSLayoutAnchor <AnchorType> *) anchor constant: (CGFloat) c priority: (NSLayoutPriority) priority NS_WARN_UNUSED_RESULT;

@end

@interface NSLayoutDimension (convenience)

- (NSLayoutConstraint *) constraintEqualToConstant: (CGFloat) c priority: (NSLayoutPriority) priority NS_WARN_UNUSED_RESULT;
- (NSLayoutConstraint *) constraintGreaterThanOrEqualToConstant: (CGFloat) c priority: (NSLayoutPriority) priority NS_WARN_UNUSED_RESULT;
- (NSLayoutConstraint *) constraintLessThanOrEqualToConstant: (CGFloat) c priority: (NSLayoutPriority) priority NS_WARN_UNUSED_RESULT;

- (NSLayoutConstraint *) constraintEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m priority: (NSLayoutPriority) priority NS_WARN_UNUSED_RESULT;
- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor: (NSLayoutDimension  *) anchor multiplier: (CGFloat) m priority: (NSLayoutPriority) priority NS_WARN_UNUSED_RESULT;
- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor: (NSLayoutDimension  *) anchor multiplier: (CGFloat) m priority: (NSLayoutPriority) priority NS_WARN_UNUSED_RESULT;

- (NSLayoutConstraint *) constraintEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m constant: (CGFloat) c priority: (NSLayoutPriority) priority NS_WARN_UNUSED_RESULT;
- (NSLayoutConstraint *) constraintGreaterThanOrEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m constant: (CGFloat) c priority: (NSLayoutPriority) priority NS_WARN_UNUSED_RESULT;
- (NSLayoutConstraint *) constraintLessThanOrEqualToAnchor: (NSLayoutDimension *) anchor multiplier: (CGFloat) m constant: (CGFloat) c priority: (NSLayoutPriority) priority NS_WARN_UNUSED_RESULT;

@end

@interface NSWindow (rounding)

- (CGFloat) ceilValue: (CGFloat) value;
- (CGFloat) floorValue: (CGFloat) value;
- (CGFloat) truncValue: (CGFloat) value;
- (CGFloat) roundValue: (CGFloat) value;
- (CGFloat) roundValue: (CGFloat) value mode: (int) roundingMode;

@end

NS_ASSUME_NONNULL_END
