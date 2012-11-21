/*
 *  AFPProtocol.m
 *  MRFS
 *
 *  Created by han9kin on 2011-04-12.
 *
 */

#import "AFPProtocol.h"


NSString *DSICommandNameFromCode(uint8_t aCommandCode)
{
    NSString *sName;

    switch (aCommandCode)
    {
        case kDSIAttention:
            sName = @"DSIAttention";
            break;
        case kDSICloseSession:
            sName = @"DSICloseSession";
            break;
        case kDSICommand:
            sName = @"DSICommand";
            break;
        case kDSIGetStatus:
            sName = @"DSIGetStatus";
            break;
        case kDSIOpenSession:
            sName = @"DSIOpenSession";
            break;
        case kDSITickle:
            sName = @"DSITickle";
            break;
        case kDSIWrite:
            sName = @"DSIWrite";
            break;
        default:
            sName = @"UNKNOWN";
            break;
    }

    return sName;
}


NSString *AFPCommandNameFromCode(uint8_t aCommandCode)
{
    NSString *sName;

    switch (aCommandCode)
    {
        case kFPAccess:
            sName = @"FPAccess";
            break;
        case kFPAddAPPL:
            sName = @"FPAddAPPL";
            break;
        case kFPAddComment:
            sName = @"FPAddComment";
            break;
        case kFPAddIcon:
            sName = @"FPAddIcon";
            break;
        case kFPByteRangeLock:
            sName = @"FPByteRangeLock";
            break;
        case kFPByteRangeLockExt:
            sName = @"FPByteRangeLockExt";
            break;
        case kFPCatSearch:
            sName = @"FPCatSearch";
            break;
        case kFPCatSearchExt:
            sName = @"FPCatSearchExt";
            break;
        case kFPChangePassword:
            sName = @"FPChangePassword";
            break;
        case kFPCloseDir:
            sName = @"FPCloseDir";
            break;
        case kFPCloseDT:
            sName = @"FPCloseDT";
            break;
        case kFPCloseFork:
            sName = @"FPCloseFork";
            break;
        case kFPCloseVol:
            sName = @"FPCloseVol";
            break;
        case kFPCopyFile:
            sName = @"FPCopyFile";
            break;
        case kFPCreateDir:
            sName = @"FPCreateDir";
            break;
        case kFPCreateFile:
            sName = @"FPCreateFile";
            break;
        case kFPCreateID:
            sName = @"FPCreateID";
            break;
        case kFPDelete:
            sName = @"FPDelete";
            break;
        case kFPDeleteID:
            sName = @"FPDeleteID";
            break;
        case kFPDisconnectOldSession:
            sName = @"FPDisconnectOldSession";
            break;
        case kFPEnumerate:
            sName = @"FPEnumerate";
            break;
        case kFPEnumerateExt:
            sName = @"FPEnumerateExt";
            break;
        case kFPEnumerateExt2:
            sName = @"FPEnumerateExt2";
            break;
        case kFPExchangeFiles:
            sName = @"FPExchangeFiles";
            break;
        case kFPFlush:
            sName = @"FPFlush";
            break;
        case kFPFlushFork:
            sName = @"FPFlushFork";
            break;
        case kFPGetACL:
            sName = @"FPGetACL";
            break;
        case kFPGetAPPL:
            sName = @"FPGetAPPL";
            break;
        case kFPGetAuthMethods:
            sName = @"FPGetAuthMethods";
            break;
        case kFPGetComment:
            sName = @"FPGetComment";
            break;
        case kFPGetExtAttr:
            sName = @"FPGetExtAttr";
            break;
        case kFPGetFileDirParms:
            sName = @"FPGetFileDirParms";
            break;
        case kFPGetForkParms:
            sName = @"FPGetForkParms";
            break;
        case kFPGetIcon:
            sName = @"FPGetIcon";
            break;
        case kFPGetSessionToken:
            sName = @"FPGetSessionToken";
            break;
        case kFPGetSrvrInfo:
            sName = @"FPGetSrvrInfo";
            break;
        case kFPGetSrvrMsg:
            sName = @"FPGetSrvrMsg";
            break;
        case kFPGetSrvrParms:
            sName = @"FPGetSrvrParms";
            break;
        case kFPGetUserInfo:
            sName = @"FPGetUserInfo";
            break;
        case kFPGetVolParms:
            sName = @"FPGetVolParms";
            break;
        case kFPListExtAttrs:
            sName = @"FPListExtAttrs";
            break;
        case kFPLogin:
            sName = @"FPLogin";
            break;
        case kFPLoginCont:
            sName = @"FPLoginCont";
            break;
        case kFPLoginExt:
            sName = @"FPLoginExt";
            break;
        case kFPLogout:
            sName = @"FPLogout";
            break;
        case kFPMapID:
            sName = @"FPMapID";
            break;
        case kFPMapName:
            sName = @"FPMapName";
            break;
        case kFPMoveAndRename:
            sName = @"FPMoveAndRename";
            break;
        case kFPOpenDir:
            sName = @"FPOpenDir";
            break;
        case kFPOpenDT:
            sName = @"FPOpenDT";
            break;
        case kFPOpenFork:
            sName = @"FPOpenFork";
            break;
        case kFPOpenVol:
            sName = @"FPOpenVol";
            break;
        case kFPRead:
            sName = @"FPRead";
            break;
        case kFPReadExt:
            sName = @"FPReadExt";
            break;
        case kFPRemoveAPPL:
            sName = @"FPRemoveAPPL";
            break;
        case kFPRemoveComment:
            sName = @"FPRemoveComment";
            break;
        case kFPRemoveExtAttr:
            sName = @"FPRemoveExtAttr";
            break;
        case kFPRename:
            sName = @"FPRename";
            break;
        case kFPResolveID:
            sName = @"FPResolveID";
            break;
        case kFPSetACL:
            sName = @"FPSetACL";
            break;
        case kFPSetDirParms:
            sName = @"FPSetDirParms";
            break;
        case kFPSetExtAttr:
            sName = @"FPSetExtAttr";
            break;
        case kFPSetFileDirParms:
            sName = @"FPSetFileDirParms";
            break;
        case kFPSetFileParms:
            sName = @"FPSetFileParms";
            break;
        case kFPSetForkParms:
            sName = @"FPSetForkParms";
            break;
        case kFPSetVolParms:
            sName = @"FPSetVolParms";
            break;
        case kFPSpotlightRPC:
            sName = @"FPSpotlightRPC";
            break;
        case kFPSyncDir:
            sName = @"FPSyncDir";
            break;
        case kFPSyncFork:
            sName = @"FPSyncFork";
            break;
        case kFPWrite:
            sName = @"FPWrite";
            break;
        case kFPWriteExt:
            sName = @"FPWriteExt";
            break;
        case kFPZzzzz:
            sName = @"FPZzzzz";
            break;
        default:
            sName = @"UNKNOWN";
            break;
    }

    return sName;
}


NSString *AFPErrorNameFromCode(uint32_t aErrorCode)
{
    NSString *sName;

    switch (aErrorCode)
    {
        case kFPNoErr:
            sName = @"kFPNoErr";
            break;
        case kFPNoMoreSessions:
            sName = @"kFPNoMoreSessions";
            break;
        case kASPSessClosed:
            sName = @"kASPSessClosed";
            break;
        case kFPAccessDenied:
            sName = @"kFPAccessDenied";
            break;
        case kFPAuthContinue:
            sName = @"kFPAuthContinue";
            break;
        case kFPBadUAM:
            sName = @"kFPBadUAM";
            break;
        case kFPBadVersNum:
            sName = @"kFPBadVersNum";
            break;
        case kFPBitmapErr:
            sName = @"kFPBitmapErr";
            break;
        case kFPCantMove:
            sName = @"kFPCantMove";
            break;
        case kFPDenyConflict:
            sName = @"kFPDenyConflict";
            break;
        case kFPDirNotEmpty:
            sName = @"kFPDirNotEmpty";
            break;
        case kFPDiskFull:
            sName = @"kFPDiskFull";
            break;
        case kFPEOFErr:
            sName = @"kFPEOFErr";
            break;
        case kFPFileBusy:
            sName = @"kFPFileBusy";
            break;
        case kFPFlatVol:
            sName = @"kFPFlatVol";
            break;
        case kFPItemNotFound:
            sName = @"kFPItemNotFound";
            break;
        case kFPLockErr:
            sName = @"kFPLockErr";
            break;
        case kFPMiscErr:
            sName = @"kFPMiscErr";
            break;
        case kFPNoMoreLocks:
            sName = @"kFPNoMoreLocks";
            break;
        case kFPNoServer:
            sName = @"kFPNoServer";
            break;
        case kFPObjectExists:
            sName = @"kFPObjectExists";
            break;
        case kFPObjectNotFound:
            sName = @"kFPObjectNotFound";
            break;
        case kFPParamErr:
            sName = @"kFPParamErr";
            break;
        case kFPRangeNotLocked:
            sName = @"kFPRangeNotLocked";
            break;
        case kFPRangeOverlap:
            sName = @"kFPRangeOverlap";
            break;
        case kFPSessClosed:
            sName = @"kFPSessClosed";
            break;
        case kFPUserNotAuth:
            sName = @"kFPUserNotAuth";
            break;
        case kFPCallNotSupported:
            sName = @"kFPCallNotSupported";
            break;
        case kFPObjectTypeErr:
            sName = @"kFPObjectTypeErr";
            break;
        case kFPTooManyFilesOpen:
            sName = @"kFPTooManyFilesOpen";
            break;
        case kFPServerGoingDown:
            sName = @"kFPServerGoingDown";
            break;
        case kFPCantRename:
            sName = @"kFPCantRename";
            break;
        case kFPDirNotFound:
            sName = @"kFPDirNotFound";
            break;
        case kFPIconTypeError:
            sName = @"kFPIconTypeError";
            break;
        case kFPVolLocked:
            sName = @"kFPVolLocked";
            break;
        case kFPObjectLocked:
            sName = @"kFPObjectLocked";
            break;
        case kFPContainsSharedErr:
            sName = @"kFPContainsSharedErr";
            break;
        case kFPIDNotFound:
            sName = @"kFPIDNotFound";
            break;
        case kFPIDExists:
            sName = @"kFPIDExists";
            break;
        case kFPDiffVolErr:
            sName = @"kFPDiffVolErr";
            break;
        case kFPCatalogChanged:
            sName = @"kFPCatalogChanged";
            break;
        case kFPSameObjectErr:
            sName = @"kFPSameObjectErr";
            break;
        case kFPBadIDErr:
            sName = @"kFPBadIDErr";
            break;
        case kFPPwdSameErr:
            sName = @"kFPPwdSameErr";
            break;
        case kFPPwdTooShortErr:
            sName = @"kFPPwdTooShortErr";
            break;
        case kFPPwdExpiredErr:
            sName = @"kFPPwdExpiredErr";
            break;
        case kFPInsideSharedErr:
            sName = @"kFPInsideSharedErr";
            break;
        case kFPInsideTrashErr:
            sName = @"kFPInsideTrashErr";
            break;
        case kFPPwdNeedsChangeErr:
            sName = @"kFPPwdNeedsChangeErr";
            break;
        case kFPPwdPolicyErr:
            sName = @"kFPPwdPolicyErr";
            break;
        case kFPDiskQuotaExceeded:
            sName = @"kFPDiskQuotaExceeded";
            break;
        default:
            sName = [NSString stringWithFormat:@"UnknownError[%d]", (int)aErrorCode];
            break;
    }

    return sName;
}
