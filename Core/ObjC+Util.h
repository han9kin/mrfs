/*
 *  ObjC+Util.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-28.
 *
 */

#import <Foundation/Foundation.h>


#define SubclassResponsibility()                                        \
    do                                                                  \
    {                                                                   \
        NSLog(@"SubclassResponsibility %s[%@ %@] not implemented.",     \
              (((Class)self == [self class]) ? "+" : "-"),              \
              NSStringFromClass([self class]),                          \
              NSStringFromSelector(_cmd));                              \
        abort();                                                        \
    } while (0)
