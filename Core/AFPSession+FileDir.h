/*
 *  AFPSession+FileDir.h
 *  MRFS
 *
 *  Created by han9kin on 2011-05-02.
 *
 */

#import <Foundation/Foundation.h>
#import "AFPSession.h"


@class AFPDirectory;
@class AFPFile;


@interface AFPSession (FileDir)


- (int16_t)allCommonBits;
- (int16_t)allFileBits;
- (int16_t)allDirectoryBits;


- (void)fillParameters:(int16_t)aBitmap on:(NSMutableData *)aReplyBlock withFile:(AFPFile *)aFile;
- (void)fillParameters:(int16_t)aBitmap on:(NSMutableData *)aReplyBlock withDirectory:(AFPDirectory *)aDirectory;


@end
