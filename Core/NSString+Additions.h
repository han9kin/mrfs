/*
 *  NSString+Additions.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-19.
 *
 */

#import <Foundation/Foundation.h>


@interface NSString (Additions)


+ (NSString *)stringWithPascalString:(const uint8_t *)aPascalString advanced:(const uint8_t **)aPointer;
+ (NSString *)stringWithPSUTF8String:(const uint8_t *)aPSUTF8String advanced:(const uint8_t **)aPointer;
+ (NSString *)stringWithTypedString:(const uint8_t *)aPathnameString advanced:(const uint8_t **)aPointer;
+ (NSString *)stringWithHintedString:(const uint8_t *)aHintedString advanced:(const uint8_t **)aPointer;
+ (NSString *)stringWithPathnameString:(const uint8_t *)aPathnameString advanced:(const uint8_t **)aPointer;


- (BOOL)demangleFilenamePrefix:(NSString **)aPrefix suffix:(NSString **)aSuffix nodeID:(uint32_t *)aNodeID;


@end
