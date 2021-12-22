//
//  NSObject+abstract.h
//  ManBro
//
//  Created by Kirill byss Bystrov on 12/21/21.
//  Copyright © 2021 Kirill byss Bystrov. All rights reserved.
//

#import <objc/NSObject.h>

#define KB_ABSTRACT { \
	[self doesNotRecognizeSelector:_cmd]; \
	__builtin_unreachable (); \
}
