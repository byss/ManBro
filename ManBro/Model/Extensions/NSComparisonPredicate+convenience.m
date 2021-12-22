//
//  NSComparisonPredicate+convenience.m
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/16/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import "NSComparisonPredicate+convenience.h"

@implementation NSComparisonPredicate (convenience)

- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type forKeyPath: (NSString *) keyPath {
	return [self initTemplateWithType:type forKeyPath:keyPath variableName:keyPath];
}

- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath {
	return [self initTemplateWithType:type options:options forKeyPath:keyPath variableName:keyPath];
}

- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type modifier: (NSComparisonPredicateModifier) modifier options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath {
	return [self initTemplateWithType:type modifier:modifier options:options forKeyPath:keyPath variableName:keyPath];
}

- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type forKeyPath: (NSString *) keyPath variableName: (NSString *) variableName {
	return [self initWithType:type forKeyPath:keyPath rightExpression:[NSExpression expressionForVariable:variableName]];
}

- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath variableName: (NSString *) variableName {
	return [self initWithType:type options:options forKeyPath:keyPath rightExpression:[NSExpression expressionForVariable:variableName]];
}

- (instancetype) initTemplateWithType: (NSPredicateOperatorType) type modifier: (NSComparisonPredicateModifier) modifier options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath variableName: (NSString *) variableName {
	return [self initWithType:type modifier:modifier options:options forKeyPath:keyPath rightExpression:[NSExpression expressionForVariable:variableName]];
}

- (instancetype) initWithType: (NSPredicateOperatorType) type forKeyPath: (NSString *) keyPath value: (id) value {
	return [self initWithType:type forKeyPath:keyPath rightExpression:[NSExpression expressionForConstantValue:value]];
}

- (instancetype) initWithType: (NSPredicateOperatorType) type options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath value: (id) value {
	return [self initWithType:type options:options forKeyPath:keyPath rightExpression:[NSExpression expressionForConstantValue:value]];
}

- (instancetype) initWithType: (NSPredicateOperatorType) type modifier: (NSComparisonPredicateModifier) modifier options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath value: (id) value {
	return [self initWithType:type modifier:modifier options:options forKeyPath:keyPath rightExpression:[NSExpression expressionForConstantValue:value]];
}

- (instancetype) initWithType: (NSPredicateOperatorType) type forKeyPath: (NSString *) keyPath rightExpression: (NSExpression *) rightExpression {
	return [self initWithType:type options:0 forKeyPath:keyPath rightExpression:rightExpression];
}

- (instancetype) initWithType: (NSPredicateOperatorType) type options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath rightExpression: (NSExpression *) rightExpression {
	return [self initWithType:type modifier:NSDirectPredicateModifier options:options forKeyPath:keyPath rightExpression:rightExpression];
}

- (instancetype) initWithType: (NSPredicateOperatorType) type modifier: (NSComparisonPredicateModifier) modifier options: (NSComparisonPredicateOptions) options forKeyPath: (NSString *) keyPath rightExpression: (NSExpression *) rightExpression {
	return [self initWithLeftExpression:[NSExpression expressionForKeyPath:keyPath] rightExpression:rightExpression modifier:modifier type:type options:options];
}

@end
