/*
 *  LoopbackFileSystem.h
 *  MRFS
 *
 *  Created by han9kin on 2011-04-27.
 *
 */

#import <Foundation/Foundation.h>
#import <MRFS/MRFS.h>


@interface LoopbackFileSystem : NSObject <MRFSOperations>
{
    NSString   *mName;
    NSString   *mPath;
    MRFSVolume *mVolume;
}


- (id)initWithName:(NSString *)aName path:(NSString *)aPath server:(MRFSServer *)aServer;


- (NSString *)name;
- (NSString *)path;
- (MRFSVolume *)volume;


- (BOOL)isMounted;
- (void)setMounted:(BOOL)aMounted;


@end
