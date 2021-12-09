//
//  NSString+searchPredicateValue.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/8/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (searchPredicateValue)

- (NSString *__nullable) stringByPreparingForCaseInsensitiveComparisonPredicates;

@end

NS_ASSUME_NONNULL_END
