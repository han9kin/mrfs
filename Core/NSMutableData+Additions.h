/*
 *  NSMutableData+Additions.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-18.
 *
 */

#import <Foundation/Foundation.h>


@interface NSMutableData (Additions)


- (NSUInteger)appendUInt8:(uint8_t)aValue;
- (NSUInteger)appendUInt16:(uint16_t)aValue;
- (NSUInteger)appendUInt32:(uint32_t)aValue;
- (NSUInteger)appendUInt64:(uint64_t)aValue;

- (NSUInteger)appendPascalString:(NSString *)aString maxLength:(NSUInteger)aMaxLength;
- (NSUInteger)appendPSUTF8String:(NSString *)aString maxLength:(NSUInteger)aMaxLength;
- (NSUInteger)appendHintedString:(NSString *)aString;


@end
