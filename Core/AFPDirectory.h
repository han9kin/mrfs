/*
 *  AFPDirectory.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-21.
 *
 */

#import <Foundation/Foundation.h>
#import "AFPNode.h"


typedef enum AFPEnumerateOption
{
    AFPEnumerateAll = 0,
    AFPEnumerateDirectories,
    AFPEnumerateFiles,
} AFPEnumerateOption;


@class AFPVolume;


@interface AFPDirectory : AFPNode
{
    AFPVolume           *mVolume;

    NSMutableArray      *mOffspringNames;
    NSMutableDictionary *mOffspringNodes;
    NSTimeInterval       mOffspringTime;
}


- (void)setupRoot:(AFPDirectory *)aDirectory;


- (uint32_t)ownerID;
- (uint32_t)groupID;
- (uint32_t)accessRights;


- (uint32_t)offspringCount;
- (AFPNode *)offspringNodeForName:(NSString *)aNodeName;
- (NSArray *)offspringNodesWithRange:(NSRange)aRange option:(AFPEnumerateOption)aOption;

- (AFPNode *)nodeForRelativePath:(NSString *)aPath;


- (uint32_t)createDirectory:(AFPNode **)aNode withName:(NSString *)aNodeName;
- (uint32_t)createFile:(AFPNode **)aNode recreateIfExists:(BOOL)aRecreate withName:(NSString *)aNodeName;


- (AFPNode *)addOffspringNodeWithName:(NSString *)aNodeName isDirectory:(BOOL)aIsDirectory stat:(const MRFSFileStat *)aStat;
- (void)removeOffspringNode:(AFPNode *)aNode;
- (void)moveOffspringNode:(AFPNode *)aNode toDirectory:(AFPDirectory *)aDirectory withNewName:(NSString *)aNodeName;


- (BOOL)refreshOffspringNodes;


@end
