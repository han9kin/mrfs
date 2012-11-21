/*
 *  AFPProtocol.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-12.
 *
 */

#import <Foundation/Foundation.h>



/*
 * DSI: Data Stream Interface (Transport Layer of AFP over TCP)
 */

#pragma mark -
#pragma mark DSI Commands


#define kDSIAttention    8
#define kDSICloseSession 1
#define kDSICommand      2
#define kDSIGetStatus    3
#define kDSIOpenSession  4
#define kDSITickle       5
#define kDSIWrite        6


NSString *DSICommandNameFromCode(uint8_t aCommandCode);


#pragma mark DSI Header


typedef struct DSIHeader
{
    uint8_t      flags;
    uint8_t      command;
    uint16_t     requestID;
    union
    {
        uint32_t errorCode;
        uint32_t writeOffset;
    };
    uint32_t     totalDataLength;
    uint32_t     reserved;
} DSIHeader;


static inline void DSIHeaderConvertToHostByteOrder(DSIHeader *aHeader)
{
    aHeader->requestID       = ntohs(aHeader->requestID);
    aHeader->writeOffset     = ntohl(aHeader->writeOffset);
    aHeader->totalDataLength = ntohl(aHeader->totalDataLength);
    aHeader->reserved        = ntohl(aHeader->reserved);
}


static inline void DSIHeaderMakeRequest(DSIHeader *aRequestHeader, DSIHeader *aHeader)
{
    aRequestHeader->flags           = 0x00;
    aRequestHeader->command         = aHeader->command;
    aRequestHeader->requestID       = htons(aHeader->requestID);
    aRequestHeader->writeOffset     = htonl(aHeader->writeOffset);
    aRequestHeader->totalDataLength = htonl(aHeader->totalDataLength);
    aRequestHeader->reserved        = 0;
}


static inline void DSIHeaderMakeReply(DSIHeader *aReplyHeader, DSIHeader *aHeader, uint32_t aErrorCode, uint32_t aDataLength)
{
    aReplyHeader->flags           = 0x01;
    aReplyHeader->command         = aHeader->command;
    aReplyHeader->requestID       = htons(aHeader->requestID);
    aReplyHeader->errorCode       = htonl(aErrorCode);
    aReplyHeader->totalDataLength = htonl(aDataLength);
    aReplyHeader->reserved        = 0;
}


#pragma mark AFPUserBytes Definitions

enum
{
    kShutDownNotifyMask   = 0x8000,
    kAllowReconnectMask   = 0x4000,
    kMsgNotifyMask        = 0x2000,
    kDisconnectNotifyMask = 0x1000,
};


#define kMsgNotifyVolumeChanged (kMsgNotifyMask | kDisconnectNotifyMask | 0x5)


#pragma mark DSIOpenSession Option Types


enum
{
    kRequestQuanta         = 0x00,
    kAttentionQuanta       = 0x01,
    kServerReplayCacheSize = 0x02,
};


/*
 * AFP: Apple Filing Protocol
 */

#pragma mark -
#pragma mark AFP Commands


#define kFPAccess               75  /* introduced in AFP 3.2 */
#define kFPAddAPPL              53  /* deprecated in Mac OS X 10.6 */
#define kFPAddComment           56  /* deprecated in Mac OS X 10.6 */
#define kFPAddIcon              192 /* deprecated in Mac OS X 10.6 */
#define kFPByteRangeLock        1   /* deprecated in AFP 3.x -> FPByteRangeLockExt */
#define kFPByteRangeLockExt     59
#define kFPCatSearch            43  /* deprecated in APF 3.x -> FPCatSearchExt */
#define kFPCatSearchExt         67
#define kFPChangePassword       36
#define kFPCloseDir             3   /* deprecated in Mac OS X */
#define kFPCloseDT              49  /* deprecated in Mac OS X 10.6 */
#define kFPCloseFork            4
#define kFPCloseVol             2
#define kFPCopyFile             5
#define kFPCreateDir            6
#define kFPCreateFile           7
#define kFPCreateID             39  /* deprecated in Mac OS X */
#define kFPDelete               8
#define kFPDeleteID             40  /* deprecated in Mac OS X */
#define kFPDisconnectOldSession 65
#define kFPEnumerate            9   /* deprecated -> FPEnumerateExt2 */
#define kFPEnumerateExt         66  /* deprecated -> FPEnumerateExt2 */
#define kFPEnumerateExt2        68
#define kFPExchangeFiles        42
#define kFPFlush                10
#define kFPFlushFork            11
#define kFPGetACL               73  /* introduced in AFP 3.2 */
#define kFPGetAPPL              55  /* deprecated in Mac OS X 10.6 */
#define kFPGetAuthMethods       62  /* deprecated */
#define kFPGetComment           58  /* deprecated in Mac OS X 10.6 */
#define kFPGetExtAttr           69  /* introduced in AFP 3.2 */
#define kFPGetFileDirParms      34
#define kFPGetForkParms         14
#define kFPGetIcon              51  /* deprecated in Mac OS X 10.6 */
#define kFPGetIconInfo          51  /* deprecated in Mac OS X 10.6 */
#define kFPGetSessionToken      64
#define kFPGetSrvrInfo          15
#define kFPGetSrvrMsg           38
#define kFPGetSrvrParms         16
#define kFPGetUserInfo          37
#define kFPGetVolParms          17
#define kFPListExtAttrs         72  /* introduced in AFP 3.2 */
#define kFPLogin                18  /* deprecated in APF 3.x -> FPLoginExt */
#define kFPLoginCont            19
#define kFPLoginExt             63
#define kFPLogout               20
#define kFPMapID                21
#define kFPMapName              22
#define kFPMoveAndRename        23
#define kFPOpenDir              25  /* deprecated in Mac OS X */
#define kFPOpenDT               48  /* deprecated in Mac OS X 10.6 */
#define kFPOpenFork             26
#define kFPOpenVol              24
#define kFPRead                 27  /* deprecated -> FPReadExt */
#define kFPReadExt              60
#define kFPRemoveAPPL           54  /* deprecated in Mac OS X 10.6 */
#define kFPRemoveComment        57  /* deprecated in Mac OS X 10.6 */
#define kFPRemoveExtAttr        71  /* introduced in AFP 3.2 */
#define kFPRename               28
#define kFPResolveID            41
#define kFPSetACL               74  /* introduced in AFP 3.2 */
#define kFPSetDirParms          29
#define kFPSetExtAttr           70  /* introduced in AFP 3.2 */
#define kFPSetFileDirParms      35
#define kFPSetFileParms         30
#define kFPSetForkParms         31
#define kFPSetVolParms          32
#define kFPSpotlightRPC         76  /* private, not documented */
#define kFPSyncDir              78
#define kFPSyncFork             79
#define kFPWrite                33  /* deprecated -> FPWriteExt */
#define kFPWriteExt             61
#define kFPZzzzz                122 /* introduced in AFP 2.3 */


NSString *AFPCommandNameFromCode(uint8_t aCommandCode);


#pragma mark AFP Error Codes


#define kFPNoErr                 0
#define kFPNoMoreSessions    -1068
#define kASPSessClosed       -1072
#define kFPAccessDenied      -5000
#define kFPAuthContinue      -5001
#define kFPBadUAM            -5002
#define kFPBadVersNum        -5003
#define kFPBitmapErr         -5004
#define kFPCantMove          -5005
#define kFPDenyConflict      -5006
#define kFPDirNotEmpty       -5007
#define kFPDiskFull          -5008
#define kFPEOFErr            -5009
#define kFPFileBusy          -5010
#define kFPFlatVol           -5011
#define kFPItemNotFound      -5012
#define kFPLockErr           -5013
#define kFPMiscErr           -5014
#define kFPNoMoreLocks       -5015
#define kFPNoServer          -5016
#define kFPObjectExists      -5017
#define kFPObjectNotFound    -5018
#define kFPParamErr          -5019
#define kFPRangeNotLocked    -5020
#define kFPRangeOverlap      -5021
#define kFPSessClosed        -5022
#define kFPUserNotAuth       -5023
#define kFPCallNotSupported  -5024
#define kFPObjectTypeErr     -5025
#define kFPTooManyFilesOpen  -5026
#define kFPServerGoingDown   -5027
#define kFPCantRename        -5028
#define kFPDirNotFound       -5029
#define kFPIconTypeError     -5030
#define kFPVolLocked         -5031
#define kFPObjectLocked      -5032
#define kFPContainsSharedErr -5033
#define kFPIDNotFound        -5034
#define kFPIDExists          -5035
#define kFPDiffVolErr        -5036
#define kFPCatalogChanged    -5037
#define kFPSameObjectErr     -5038
#define kFPBadIDErr          -5039
#define kFPPwdSameErr        -5040
#define kFPPwdTooShortErr    -5041
#define kFPPwdExpiredErr     -5042
#define kFPInsideSharedErr   -5043
#define kFPInsideTrashErr    -5044
#define kFPPwdNeedsChangeErr -5045
#define kFPPwdPolicyErr      -5046
#define kFPDiskQuotaExceeded -5047


NSString *AFPErrorNameFromCode(uint32_t aErrorCode);


#pragma mark AFP Versions


#define kAFPVersion_2_1 "AFPVersion 2.1"
#define kAFPVersion_2_2 "AFP2.2"
#define kAFPVersion_2_3 "AFP2.3"
#define kAFPVersion_3_0 "AFPX03"
#define kAFPVersion_3_1 "AFP3.1"
#define kAFPVersion_3_2 "AFP3.2"
#define kAFPVersion_3_3 "AFP3.3"


#pragma mark AFP UAMs


#define kNoUserAuthStr       "No User Authent"  /* for Guest login */
#define kClearTextUAMStr     "Cleartxt Passwrd" /* Disabled by default in Mac OS X */
#define kRandNumUAMStr       "Randnum Exchange" /* Deprecated */
#define kTwoWayRandNumUAMStr "2-Way Randnum"    /* Deprecated */
#define kDHCAST128UAMStr     "DHCAST128"        /* Deprecated */
#define kDHX2UAMStr          "DHX2"
#define kKerberosUAMStr      "Client Krb v2"
#define kReconnectUAMStr     "Recon1"


#pragma mark AFP Status Flags


enum
{
    kSupportsCopyfile     = 0x01,
    kSupportsChgPwd       = 0x02,
    kDontAllowSavePwd     = 0x04,
    kSupportsSrvrMsg      = 0x08,
    kSrvrSig              = 0x10,
    kSupportsTCP          = 0x20,
    kSupportsSrvrNotify   = 0x40,
    kSupportsReconnect    = 0x80,
    kSupportsDirServices  = 0x100,
    kSupportsUTF8SrvrName = 0x200,
    kSupportsUUIDs        = 0x400,
    kSupportsExtSleep     = 0x800,
    kSupportsSuperClient  = 0x8000,
};


#pragma mark FPGetSrvrMsg Bitmap


enum
{
    kSrvrMsg     = 0x1,
    kUTF8SrvrMsg = 0x2,
};


#pragma mark FPGetSessionToken Types


enum
{
    kLoginWithoutID        = 0,
    kLoginWithID           = 1,
    kReconnWithID          = 2,
    kLoginWithTimeAndID    = 3,
    kReconnWithTimeAndID   = 4,
    kRecon1Login           = 5,
    kRecon1ReconnectLogin  = 6,
    kRecon1RefreshToken    = 7,
    kGetKerberosSessionKey = 8,
};


#pragma mark AFP Path Type Constants


enum
{
    kFPShortName = 1,
    kFPLongName  = 2,
    kFPUTF8Name  = 3,
};


#pragma mark Volume Bitmap


enum
{
    kFPVolAttributeBit     = 0x1,
    kFPVolSignatureBit     = 0x2,
    kFPVolCreateDateBit    = 0x4,
    kFPVolModDateBit       = 0x8,
    kFPVolBackupDateBit    = 0x10,
    kFPVolIDBit            = 0x20,
    kFPVolBytesFreeBit     = 0x40,
    kFPVolBytesTotalBit    = 0x80,
    kFPVolNameBit          = 0x100,
    kFPVolExtBytesFreeBit  = 0x200,
    kFPVolExtBytesTotalBit = 0x400,
    kFPVolBlockSizeBit     = 0x800,
};


#pragma mark Volume Attributes Bitmap


enum
{
    kReadOnly                 = 0x01,
    kHasVolumePassword        = 0x02,
    kSupportsFileIDs          = 0x04,
    kSupportsCatSearch        = 0x08,
    kSupportsBlankAccessPrivs = 0x10,
    kSupportsUnixPrivs        = 0x20,
    kSupportsUTF8Names        = 0x40,
    kNoNetworkUserIDs         = 0x80,
    kDefaultPrivsFromParent   = 0x100,
    kNoExchangeFiles          = 0x200,
    kSupportsExtAttrs         = 0x400,
    kSupportsACLs             = 0x800,
    kCaseSensitive            = 0x1000,
    kSupportsTMLockSteal      = 0x2000,
};


#pragma mark Extended Attributes Bitmap


enum
{
    kXAttrNoFollow = 0x1,
    kXAttrCreate   = 0x2,
    kXAttrReplace  = 0x4,
};


#pragma mark File and Directory Bitmap


enum
{
    kFPAttributeBit      = 0x1,
    kFPParentDirIDBit    = 0x2,
    kFPCreateDateBit     = 0x4,
    kFPModDateBit        = 0x8,
    kFPBackupDateBit     = 0x10,
    kFPFinderInfoBit     = 0x20,
    kFPLongNameBit       = 0x40,
    kFPShortNameBit      = 0x80,
    kFPNodeIDBit         = 0x100,

    /* Bits that apply only to directories: */
    kFPOffspringCountBit = 0x0200,
    kFPOwnerIDBit        = 0x0400,
    kFPGroupIDBit        = 0x0800,
    kFPAccessRightsBit   = 0x1000,

    /* Bits that apply only to files (same bits as previous group): */
    kFPDataForkLenBit    = 0x0200,
    kFPRsrcForkLenBit    = 0x0400,
    kFPExtDataForkLenBit = 0x0800,  /* In AFP version 3.0 and later */
    kFPLaunchLimitBit    = 0x1000,

    /* Bits that apply to everything except where noted: */
    kFPUTF8NameBit       = 0x2000,  /* AFP version 3.0 and later */
    kFPExtRsrcForkLenBit = 0x4000,  /* Files only; AFP version 3.0 and later */
    kFPUnixPrivsBit      = 0x8000,  /* AFP version 3.0 and later */
    kFPUUID              = 0x10000, /* Directories only; AFP version 3.2 and later (with ACL support) */
};


#pragma mark File and Directory Attributes Bitmap


enum
{
    kFPInvisibleBit     = 0x01,

    kFPMultiUserBit     = 0x02,   /* for files */
    kAttrIsExpFolder    = 0x02,   /* for directories */

    kFPSystemBit        = 0x04,

    kFPDAlreadyOpenBit  = 0x08,   /* for files */
    kAttrMounted        = 0x08,   /* for directories */

    kFPRAlreadyOpenBit  = 0x10,   /* for files */
    kAttrInExpFolder    = 0x10,   /* for directories */

    kFPWriteInhibitBit  = 0x20,
    kFPBackUpNeededBit  = 0x40,
    kFPRenameInhibitBit = 0x80,
    kFPDeleteInhibitBit = 0x100,
    kFPCopyProtectBit   = 0x400,
    kFPSetClearBit      = 0x8000,
};


#pragma mark Access Rights Bitmap


enum
{
    kSPOwner     =        0x1,
    kRPOwner     =        0x2,
    kWROwner     =        0x4,

    kSPGroup     =      0x100,
    kRPGroup     =      0x200,
    kWRGroup     =      0x400,

    kSPOther     =    0x10000,
    kRPOther     =    0x20000,
    kWROther     =    0x40000,

    kSPUser      =  0x1000000,
    kRPUser      =  0x2000000,
    kWRUser      =  0x4000000,
    kBlankAcess  = 0x10000000,
    kUserIsOwner = 0x80000000,
};


#pragma mark AFP Protocol Data Types


struct FPUnixPrivs
{
    uint32_t uid;
    uint32_t gid;
    uint32_t permissions;
    uint32_t ua_permissions;
};
