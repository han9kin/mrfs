/*
 *  AFPConnection+Login.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-19.
 *
 */

#import "NSMutableData+Additions.h"
#import "NSString+Additions.h"
#import "AFPMessage.h"
#import "AFPConnection.h"
#import "AFPListener.h"
#import "AFPServer.h"
#import "AFPVolume.h"
#import "AFPDHXContext.h"


#ifndef LOG_OFF
#define LOG_PARAMETERS 1
#endif


@implementation AFPConnection (Login)


#pragma mark -
#pragma mark AFP DHCAST128 UAM


- (void)loginDHXWithMessage:(AFPMessage *)aMessage payload:(const uint8_t *)aPayload
{
    [mLoginContext prepareV1];

    if ((aPayload + [mLoginContext keySize]) != ([aMessage payloadLength] + [aMessage payload]))
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
    }
    else
    {
        NSData *sPublicKey = [NSData dataWithBytesNoCopy:(void *)aPayload length:[mLoginContext keySize] freeWhenDone:NO];

        [mLoginContext generateKey];
        [mLoginContext computeKeyWithCounterpartPublicKey:sPublicKey];
        [mLoginContext generateNonce];

        NSMutableData *sToken = [NSMutableData data];

        [sToken appendData:[mLoginContext nonce]];
        [sToken setLength:([mLoginContext nonceSize] * 2)];

        NSMutableData *sReplyBlock = [NSMutableData data];

        [sReplyBlock appendUInt16:[mLoginContext contextID]];
        [sReplyBlock appendData:[mLoginContext publicKey]];
        [sReplyBlock appendData:[mLoginContext encrypt:sToken]];

        [aMessage setReplyResult:kFPAuthContinue withBlock:sReplyBlock];
    }
}


- (void)loginContDHXWithMessage:(AFPMessage *)aMessage payload:(const uint8_t *)aPayload
{
    if ((aPayload + [mLoginContext nonceSize] + [mLoginContext passwordSize]) != ([aMessage payloadLength] + [aMessage payload]))
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
    }
    else
    {
        NSData *sCipher = [NSData dataWithBytesNoCopy:(void *)aPayload length:([mLoginContext nonceSize] + [mLoginContext passwordSize]) freeWhenDone:NO];
        NSData *sPlain  = [mLoginContext decrypt:sCipher];
        NSData *sNonce  = [sPlain subdataWithRange:NSMakeRange(0, [mLoginContext nonceSize])];

        if ([sNonce isEqualToData:[[mLoginContext nonce] dataByAdding:1]])
        {
            NSData   *sData     = [sPlain subdataWithRange:NSMakeRange([mLoginContext nonceSize], [mLoginContext passwordSize])];
            NSString *sPassword = [[[[NSString alloc] initWithData:sData encoding:NSASCIIStringEncoding] autorelease] stringByTrimmingCharactersInSet:[NSCharacterSet controlCharacterSet]];

            if ([sPassword isEqualToString:[[self listener] password]])
            {
                [mLoginContext release];
                mLoginContext = nil;

                [aMessage setReplyResult:kFPNoErr withBlock:nil];
            }
            else
            {
                [mLoginContext cleanup];

                [aMessage setReplyResult:kFPUserNotAuth withBlock:nil];
            }
        }
        else
        {
            [mLoginContext cleanup];

            [aMessage setReplyResult:kFPParamErr withBlock:nil];
        }
    }
}


#pragma mark -
#pragma mark AFP Diffie-Hellman Key Exchange 2 User Authentication Method Implementation


- (void)loginDHX2WithMessage:(AFPMessage *)aMessage payload:(const uint8_t *)aPayload
{
    [mLoginContext prepareV2];
    [mLoginContext generateKey];

    NSMutableData *sReplyBlock = [NSMutableData data];

    [sReplyBlock appendUInt16:[mLoginContext contextID]];
    [sReplyBlock appendData:[mLoginContext generator]];
    [sReplyBlock appendUInt16:[mLoginContext keySize]];
    [sReplyBlock appendData:[mLoginContext primeNumber]];
    [sReplyBlock appendData:[mLoginContext publicKey]];

    [aMessage setReplyResult:kFPAuthContinue withBlock:sReplyBlock];
}


- (void)loginContDHX2WithMessage:(AFPMessage *)aMessage payload:(const uint8_t *)aPayload
{
    if ([mLoginContext step] == 0)
    {
        if ((aPayload + [mLoginContext keySize] + [mLoginContext nonceSize]) != ([aMessage payloadLength] + [aMessage payload]))
        {
            [aMessage setReplyResult:kFPParamErr withBlock:nil];
        }
        else
        {
            NSData *sPublicKey = [NSData dataWithBytesNoCopy:(void *)aPayload length:[mLoginContext keySize] freeWhenDone:NO];

            [mLoginContext computeKeyWithCounterpartPublicKey:sPublicKey];
            [mLoginContext generateNonce];
            [mLoginContext nextStep];

            NSData *sClientNonce = [mLoginContext decrypt:[NSData dataWithBytesNoCopy:(void *)(aPayload + [mLoginContext keySize]) length:[mLoginContext nonceSize] freeWhenDone:NO]];

            NSMutableData *sText = [NSMutableData data];

            [sText appendData:[sClientNonce dataByAdding:1]];
            [sText appendData:[mLoginContext nonce]];

            NSMutableData *sReplyBlock = [NSMutableData data];

            [sReplyBlock appendUInt16:[mLoginContext contextID]];
            [sReplyBlock appendData:[mLoginContext encrypt:sText]];

            [aMessage setReplyResult:kFPAuthContinue withBlock:sReplyBlock];
        }
    }
    else
    {
        [self loginContDHXWithMessage:aMessage payload:aPayload];
    }
}


#pragma mark -


- (void)loginWithMessage:(AFPMessage *)aMessage AFPVersion:(NSString *)aAFPVersion UAM:(NSString *)aUAM payload:(const uint8_t *)aPayload
{
    if ([[AFPConnection supportedAFPVersions] containsObject:aAFPVersion])
    {
        if ([aUAM isEqualToString:@kDHCAST128UAMStr])
        {
            [self loginDHXWithMessage:aMessage payload:aPayload];
        }
        else if ([aUAM isEqualToString:@kDHX2UAMStr])
        {
            [self loginDHX2WithMessage:aMessage payload:aPayload];
        }
        else
        {
            [aMessage setReplyResult:kFPBadUAM withBlock:nil];
        }
    }
    else
    {
        [aMessage setReplyResult:kFPBadVersNum withBlock:nil];
    }

    [self replyMessage:aMessage];
}


#pragma mark -
#pragma mark Handling AFP Request


- (void)doLogin:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSString      *sAFPVersion;
    NSString      *sUAM;
    NSString      *sUserName;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sAFPVersion = [NSString stringWithPascalString:sPayload advanced:&sPayload];
    sUAM        = [NSString stringWithPascalString:sPayload advanced:&sPayload];
    sUserName   = [NSString stringWithPascalString:sPayload advanced:&sPayload];

    if ((sPayload - [aMessage payload]) & 1)
    {
        sPayload += 1; /* 2byte-aligned */
    }

    [self loginWithMessage:aMessage AFPVersion:sAFPVersion UAM:sUAM payload:sPayload];
}


- (void)doLoginExt:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    NSString      *sAFPVersion;
    NSString      *sUAM;
    NSString      *sUserName;
    NSString      *sPathname;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sPayload += 2; /* Flags */
    sAFPVersion = [NSString stringWithPascalString:sPayload advanced:&sPayload];
    sUAM        = [NSString stringWithPascalString:sPayload advanced:&sPayload];
    sUserName   = [NSString stringWithTypedString:sPayload advanced:&sPayload];
    sPathname   = [NSString stringWithTypedString:sPayload advanced:&sPayload];

    if ((sPayload - [aMessage payload]) & 1)
    {
        sPayload += 1; /* 2byte-aligned */
    }

    [self loginWithMessage:aMessage AFPVersion:sAFPVersion UAM:sUAM payload:sPayload];
}


- (void)doLoginCont:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    uint16_t       sID;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sID = ntohs(*(uint16_t *)sPayload);
    sPayload += 2;

    if (sID == [mLoginContext contextID])
    {
        switch ([mLoginContext version])
        {
            case 1:
                [self loginContDHXWithMessage:aMessage payload:sPayload];
                break;
            case 2:
                [self loginContDHX2WithMessage:aMessage payload:sPayload];
                break;
        }
    }
    else
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
    }

    [self replyMessage:aMessage];
}


- (void)doLogout:(AFPMessage *)aMessage
{
    [mLoginContext release];
    mLoginContext = [[AFPDHXContext alloc] init];

    [aMessage setReplyResult:kFPNoErr withBlock:nil];
    [self replyMessage:aMessage];
}


- (void)doGetUserInfo:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    uint8_t        sFlags;
    int16_t        sBitmap;

    sPayload += 1; /* CommandCode */
    sFlags = *sPayload;
    sPayload += 1;
    sPayload += 4; /* UserID */
    sBitmap = ntohs(*(int16_t *)sPayload);

    if (sFlags & 0x1)
    {
        if (sBitmap & 0x4) /* UUID */
        {
            [aMessage setReplyResult:kFPBitmapErr withBlock:nil];
        }
        else
        {
            NSMutableData *sReplyBlock = [NSMutableData data];

            [sReplyBlock appendUInt16:sBitmap];

            if (sBitmap & 0x1) /* User ID */
            {
                [sReplyBlock appendUInt32:getuid()];
            }

            if (sBitmap & 0x2) /* Primary Group ID */
            {
                [sReplyBlock appendUInt32:getgid()];
            }

            [aMessage setReplyResult:kFPNoErr withBlock:sReplyBlock];
        }
    }
    else
    {
        [aMessage setReplyResult:kFPParamErr withBlock:nil];
    }

    [self replyMessage:aMessage];
}


@end
