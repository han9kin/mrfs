/*
 *  AFPNode.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-22.
 *
 */

#import <Foundation/Foundation.h>
#import "MRFSOperations.h"


@class AFPVolume;
@class AFPDirectory;


@interface AFPNode : NSObject
{
    AFPDirectory   *mParent;

    int32_t         mNodeID;
    NSString       *mNodeName;

    MRFSFileStat    mFileStat;
    NSTimeInterval  mFileStatTime;
}


- (id)initWithNodeID:(int32_t)aNodeID volume:(AFPVolume *)aVolume stat:(const MRFSFileStat *)aFileStat;


- (AFPVolume *)volume;
- (NSString *)path;
- (id<MRFSOperations>)operationHandler;
- (BOOL)isDirectory;


- (NSString *)nodeName;
- (void)setNodeName:(NSString *)aNodeName;


- (AFPDirectory *)parent;
- (void)setParent:(AFPDirectory *)aParent;


- (AFPNode *)validateNode;


- (int)getFileStat:(MRFSFileStat **)aFileStat;
- (void)setFileStat:(const MRFSFileStat *)aFileStat;
- (void)invalidateFileStat;

- (uint32_t)accessRightsFromMode:(uint32_t)aMode userID:(uint32_t)aUserID;
- (uint32_t)modeFromAccessRights:(uint32_t)aAccessRights;


- (uint16_t)attribute;
- (uint32_t)parentID;
- (uint32_t)creationDate;
- (uint32_t)modificationDate;
- (uint32_t)backupDate;
- (NSData *)finderInfo;
- (NSString *)longName;
- (NSString *)shortName;
- (int32_t)nodeID;
- (void)getUnixPrivileges:(struct FPUnixPrivs *)aUnixPrivs;


- (uint32_t)setParameters:(const uint8_t *)aParameters bitmap:(int16_t)aBitmap;

- (uint32_t)deleteNode;
- (uint32_t)moveNodeToDirectory:(AFPDirectory *)aDirectory withNewName:(NSString *)aNodeName;


- (uint32_t)listExtendedAttributes:(void *)aBuffer size:(int64_t)aSize returnedSize:(int64_t *)aReturendSize bitmap:(uint16_t)aBitmap;
- (uint32_t)getExtendedAttribute:(const char *)aName buffer:(void *)aBuffer size:(int64_t)aSize offset:(int64_t)aOffset returnedSize:(int64_t *)aReturnedSize bitmap:(uint16_t)aBitmap;
- (uint32_t)setExtendedAttribute:(const char *)aName buffer:(const void *)aBuffer size:(int64_t)aSize offset:(int64_t)aOffset writtenSize:(int64_t *)aWrittenSize bitmap:(uint16_t)aBitmap;
- (uint32_t)removeExtendedAttribute:(const char *)aName bitmap:(uint16_t)aBitmap;


@end
