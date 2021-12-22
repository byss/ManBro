//
//  NSComparisonPredicate+convenience.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/16/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSComparisonPredicate (convenience)

- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type forKeyPath: (NSString *) keyPath;
- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath;
- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type modifier: (NSComparisonPredicateModifier) modifier options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath;

- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type forKeyPath: (NSString *) keyPath variableName: (NSString *) variableName;
- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath variableName: (NSString *) variableName;
- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type modifier: (NSComparisonPredicateModifier) modifier options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath variableName: (NSString *) variableName;

- (instancetype) initWithType: (NSPredicateOperatorType) type forKeyPath: (NSString *) keyPath value: (id) value;
- (instancetype) initWithType: (NSPredicateOperatorType) type options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath value: (id) value;
- (instancetype) initWithType: (NSPredicateOperatorType) type modifier: (NSComparisonPredicateModifier) modifier options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath value: (id) value;

- (instancetype) initWithType: (NSPredicateOperatorType) type forKeyPath: (NSString *) keyPath rightExpression: (NSExpression *) rightExpression;
- (instancetype) initWithType: (NSPredicateOperatorType) type options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath rightExpression: (NSExpression *) rightExpression;
- (instancetype) initWithType: (NSPredicateOperatorType) type modifier: (NSComparisonPredicateModifier) modifier options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath rightExpression: (NSExpression *) rightExpression;

@end

NS_ASSUME_NONNULL_END
