/*
 *  AFPDHXContext.h
 *  MRFS
 *
 *  Created by han9kin on 2011-05-02.
 *
 */

#import <Foundation/Foundation.h>


#ifndef AFPDHX_ENGINE
#define AFPDHX_ENGINE void
#endif

#ifndef AFPDHX_NONCE
#define AFPDHX_NONCE void
#endif


@interface AFPDHXContext : NSObject
{
    AFPDHX_ENGINE *mDH;
    AFPDHX_NONCE  *mNonce;
    unsigned char *mKey;

    int            mKeySize;
    int            mPasswordSize;

    uint16_t       mID;
    uint8_t        mStep;
    uint8_t        mVersion;
}


- (uint16_t)contextID;
- (uint8_t)step;
- (uint8_t)version;


- (int)keySize;
- (int)nonceSize;
- (int)passwordSize;

- (NSData *)primeNumber;
- (NSData *)generator;
- (NSData *)publicKey;
- (NSData *)nonce;


- (void)prepareV1;
- (void)prepareV2;
- (void)cleanup;

- (void)generateKey;
- (void)generateNonce;
- (void)computeKeyWithCounterpartPublicKey:(NSData *)aPublicKey;
- (void)nextStep;


- (NSData *)decrypt:(NSData *)aData;
- (NSData *)encrypt:(NSData *)aData;


@end


@interface NSData (BigNum)


- (NSData *)dataByAdding:(unsigned long)aValue;
- (NSData *)dataBySubtracting:(unsigned long)aValue;


@end
