/*
 *  AFPConnection+Session.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-29.
 *
 */

#import "NSMutableData+Additions.h"
#import "AFPMessage.h"
#import "AFPSession.h"
#import "AFPConnection.h"
#import "AFPListener.h"
#import "AFPServer.h"


@implementation AFPConnection (Session)


- (void)doOpenSession:(AFPMessage *)aMessage
{
    NSMutableData *sReplyBlock = [NSMutableData data];

    [sReplyBlock appendUInt8:kRequestQuanta];
    [sReplyBlock appendUInt8:4];
    [sReplyBlock appendUInt32:[[mListener server] maxReqSize]];
    [sReplyBlock appendUInt8:kServerReplayCacheSize];
    [sReplyBlock appendUInt8:4];
    [sReplyBlock appendUInt32:0];

    [aMessage setReplyResult:kFPNoErr withBlock:sReplyBlock];

    [self replyMessage:aMessage];
}


- (void)doCloseSession:(AFPMessage *)aMessage
{
    [mSession stop];
    mSession = nil;

    [self stop];
}


- (void)doGetSessionToken:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    int16_t        sType;
    int32_t        sIDLength;
    int32_t        sTimestamp;
    NSData        *sClientID;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sType = ntohs(*(int16_t *)sPayload);
    sPayload += 2;
    sIDLength = ntohl(*(int32_t *)sPayload);
    sPayload += 4;

    if ((sType == kLoginWithTimeAndID) || (sType == kReconnWithTimeAndID))
    {
        sTimestamp = ntohl(*(int32_t *)sPayload);
        sPayload += 4;

        if (sIDLength)
        {
            sClientID = [NSData dataWithBytes:sPayload length:sIDLength];
        }
        else
        {
            sClientID = nil;
        }
    }
    else
    {
        [aMessage setReplyResult:kFPCallNotSupported withBlock:nil];
        [self replyMessage:aMessage];
        return;
    }

#if LOG_PARAMETERS
    NSLog(@"  Type: %d", sType);
    NSLog(@"  IDLength: %d", sIDLength);
    NSLog(@"  Timestamp: %d", sTimestamp);
#endif

    if (sClientID)
    {
        NSString      *sSessionToken = [[NSProcessInfo processInfo] globallyUniqueString];
        NSData        *sTokenData    = [sSessionToken dataUsingEncoding:NSUTF8StringEncoding];
        NSMutableData *sReplyBlock   = [NSMutableData data];

        if (sType == kLoginWithTimeAndID)
        {
            [mSession setClientID:sClientID];
            [mSession setTimestamp:sTimestamp];
        }
        else if (sType == kReconnWithTimeAndID)
        {
            NSAssert([[mSession clientID] isEqual:sClientID], @"Reconnected session's client ID mismatch");
            NSAssert(([mSession timestamp] == sTimestamp), @"Reconnected session's timestamp mismatch");
        }

        [mSession setSessionToken:sSessionToken];

        [sReplyBlock appendUInt32:[sTokenData length]];
        [sReplyBlock appendData:sTokenData];

        [aMessage setReplyResult:kFPNoErr withBlock:sReplyBlock];
    }
    else
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
    }

    [self replyMessage:aMessage];
}


- (void)doDisconnectOldSession:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    int32_t        sTokenLength;
    NSString      *sSessionToken;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sPayload += 2; /* Type */
    sTokenLength = ntohl(*(int32_t *)sPayload);
    sPayload += 4;
    sSessionToken = [[[NSString alloc] initWithData:[NSData dataWithBytes:sPayload length:sTokenLength] encoding:NSUTF8StringEncoding] autorelease];

    NSAssert(!mSession, @"Session already exists");
    [mSession stop];
    mSession = [mListener popIdleSessionWithToken:sSessionToken];
    [mSession setConnection:self];

    [aMessage setReplyResult:kFPNoErr withBlock:nil];
    [self replyMessage:aMessage];
}


@end
