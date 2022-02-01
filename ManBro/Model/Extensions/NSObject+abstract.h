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

#define KB_DOWNCAST(_type, ...) _KB_DOWNCAST (__COUNTER__, _type, __VA_ARGS__)
#define _KB_DOWNCAST(_ctr, _type, ...) ({ \
	typeof (__VA_ARGS__) const _downcast_value_ ## _ctr = (__VA_ARGS__); \
	NSAssert ([_downcast_value_ ## _ctr isKindOfClass:[_type class]], @"Invalid value %@ (instance of %@ expected)", _downcast_value_ ## _ctr, [_type class]); \
	(_type *) _downcast_value_ ## _ctr; \
})
