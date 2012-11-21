/*
 *  AFPFile.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-22.
 *
 */

#import <Foundation/Foundation.h>
#import "AFPNode.h"


@interface AFPFile : AFPNode
{

}


- (uint32_t)dataForkLen;
- (uint32_t)rsrcForkLen;
- (uint64_t)dataForkLenExt;
- (uint64_t)rsrcForkLenExt;


@end
