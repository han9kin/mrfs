/*
 *  AFPConnection+Info.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-29.
 *
 */

#import "NSMutableData+Additions.h"
#import "AFPMessage.h"
#import "AFPConnection.h"
#import "AFPListener.h"
#import "AFPServer.h"
#import "AFPVolume.h"


@implementation AFPConnection (Info)


- (void)doGetSrvrInfo:(AFPMessage *)aMessage
{
    NSArray *sSupportedAFPVersions = [AFPConnection supportedAFPVersions];
    NSArray *sSupportedUAMs        = [AFPConnection supportedUAMs];

    /*
     * 1st block
     *    uint16_t MachineTypeOffset;
     *    uint16_t AFPVersionCountOffset;
     *    uint16_t UAMCountOffset;
     *    uint16_t VolumeIconAndMaskOffset;
     *    uint16_t Flags;
     */
    NSMutableData *sBlock1 = [NSMutableData data];
    /*
     * 2nd block
     *    pascal_t ServerName; (max=32, aligned=2)
     *    uint16_t ServerSignatureOffset;
     *    uint16_t NetworkAddressesCountOffset;
     *    uint16_t DirectoryNamesCountOffset;
     *    uint16_t UTF8ServerNameOffset;
     */
    NSMutableData *sBlock2 = [NSMutableData data];
    /*
     * 3rd block
     *    pascal_t MachineType; (max=16)
     *    uint8_t  AFPVersionsCount;
     *    packed_t AFPVersions;
     *    uint8_t  UAMCount;
     *    packed_t UAMs;
     *    uint8_t  ServerSignature[16];
     *    uint8_t  NetworkAddressesCount;
     *    addrs_t  NetworkAddresses;
     *    uint8_t  DirectoryNamesCount;
     *    string_t DirectoryNames;
     *    utf8_t   UTF8ServerName;
     */
    NSMutableData *sBlock3 = [NSMutableData data];

    uint16_t       sOffset = 18; /* fixed length of block1, block2 */

    /*
     * ServerName (max 32 characters, 2byte-aligned)
     */
    sOffset += [sBlock2 appendPascalString:[[mListener server] serverName] maxLength:32];

    if ([sBlock2 length] & 1)
    {
        sOffset += [sBlock2 appendUInt8:0];
    }

    /*
     * MachineType (max 16 characters)
     */
    [sBlock1 appendUInt16:sOffset];
    sOffset += [sBlock3 appendPascalString:[[mListener server] machineType] maxLength:16];

    /*
     * AFPVersions
     */
    [sBlock1 appendUInt16:sOffset];
    sOffset += [sBlock3 appendUInt8:[sSupportedAFPVersions count]];
    for (NSString *sAFPVersion in sSupportedAFPVersions)
    {
        sOffset += [sBlock3 appendPascalString:sAFPVersion maxLength:0];
    }

    /*
     * UAMs
     */
    [sBlock1 appendUInt16:sOffset];
    sOffset += [sBlock3 appendUInt8:[sSupportedUAMs count]];
    for (NSString *sUAM in sSupportedUAMs)
    {
        sOffset += [sBlock3 appendPascalString:sUAM maxLength:0];
    }

    /*
     * ServerSignature
     */
    [sBlock2 appendUInt16:sOffset];
    [sBlock3 appendData:[[mListener server] serverSignature]];
    sOffset += 16;

    /*
     * NetworkAddresses
     */
    [sBlock2 appendUInt16:sOffset];
    sOffset += [sBlock3 appendUInt8:2];
    sOffset += [sBlock3 appendUInt8:0x08];
    sOffset += [sBlock3 appendUInt8:0x02];
    sOffset += [sBlock3 appendUInt32:[mListener address4]];
    sOffset += [sBlock3 appendUInt16:[mListener port]];
    sOffset += [sBlock3 appendUInt8:([[mListener host] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1)];
    sOffset += [sBlock3 appendUInt8:0x04];
    sOffset += [[mListener host] lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    [sBlock3 appendData:[[mListener host] dataUsingEncoding:NSUTF8StringEncoding]];

    /*
     * DirectoryNames
     */
    [sBlock2 appendUInt16:sOffset];
    sOffset += [sBlock3 appendUInt8:0];

    /*
     * UTF8ServerName
     */
    [sBlock2 appendUInt16:sOffset];
    sOffset += [sBlock3 appendPSUTF8String:[[mListener server] UTF8ServerName] maxLength:0];

    /*
     * VolumeIconAndMask
     */
    [sBlock1 appendUInt16:0];

    /*
     * Flags
     */
    uint16_t sFlags = 0;

    if ([[mListener server] supportsCopyFile])
    {
        sFlags |= kSupportsCopyfile;
    }

    sFlags |= kSupportsSrvrMsg;
    sFlags |= kSrvrSig;
    sFlags |= kSupportsTCP;
    sFlags |= kSupportsSrvrNotify;
    sFlags |= kSupportsReconnect;
    sFlags |= kSupportsDirServices;
    sFlags |= kSupportsUTF8SrvrName;

    [sBlock1 appendUInt16:sFlags];

    /*
     * Combine Reply Block
     */
    NSMutableData *sReplyBlock = [NSMutableData data];

    [sReplyBlock appendData:sBlock1];
    [sReplyBlock appendData:sBlock2];
    [sReplyBlock appendData:sBlock3];

    [aMessage setReplyResult:kFPNoErr withBlock:sReplyBlock];
    [self replyMessage:aMessage];
}


- (void)doGetSrvrParms:(AFPMessage *)aMessage
{
    NSArray       *sVolumes    = [[mListener server] volumes];
    NSMutableData *sReplyBlock = [NSMutableData data];

    if ([[mListener server] showsMountedVolumesOnly])
    {
        sVolumes = [sVolumes filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"volume.isMounted == TRUE"]];
    }

    [sReplyBlock appendUInt32:(int32_t)[NSDate timeIntervalSinceReferenceDate]];
    [sReplyBlock appendUInt8:[sVolumes count]];

    for (AFPVolume *sVolume in sVolumes)
    {
        [sReplyBlock appendUInt8:0];
        [sReplyBlock appendPascalString:[sVolume volumeName] maxLength:0];
    }

    [aMessage setReplyResult:kFPNoErr withBlock:sReplyBlock];
    [self replyMessage:aMessage];
}


- (void)doGetSrvrMsg:(AFPMessage *)aMessage
{
    const uint8_t *sPayload = [aMessage payload];
    int16_t        sMessageType;
    int16_t        sMessageBitmap;

    sPayload += 1; /* CommandCode */
    sPayload += 1; /* Pad */
    sMessageType = ntohs(*(int16_t *)sPayload);
    sPayload += 2;
    sMessageBitmap = ntohs(*(int16_t *)sPayload);

    NSMutableData *sReplyBlock = [NSMutableData data];

    [sReplyBlock appendUInt16:sMessageType];
    [sReplyBlock appendUInt16:sMessageBitmap];

    if (sMessageBitmap & kUTF8SrvrMsg)
    {
        [sReplyBlock appendPSUTF8String:@"" maxLength:0];
    }
    else
    {
        [sReplyBlock appendPascalString:@"" maxLength:0];
    }

    [aMessage setReplyResult:kFPNoErr withBlock:sReplyBlock];
    [self replyMessage:aMessage];
}


@end
