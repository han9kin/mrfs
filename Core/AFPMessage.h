/*
 *  AFPMessage.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-14.
 *
 */

#import <Foundation/Foundation.h>
#import "AFPProtocol.h"


@interface AFPMessage : NSObject
{
    DSIHeader      mHeader;
    const uint8_t *mPayload;  /* received payload */

    BOOL           mHasReply;
    uint32_t       mResult;
    NSData        *mBlock;    /* sending payload */
}


- (id)initWithHeader:(DSIHeader *)aHeader payload:(const uint8_t *)aPayload;


- (BOOL)isRequest;
- (uint8_t)dsiCommand;
- (uint8_t)afpCommand;

- (uint32_t)payloadLength;
- (const uint8_t *)payload;


- (void)setRequestBlock:(NSData *)aData;
- (void)setReplyResult:(uint32_t)aResult withBlock:(NSData *)aData;

- (BOOL)writeOnStream:(NSOutputStream *)aOutputStream;


@end
