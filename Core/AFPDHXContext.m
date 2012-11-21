/*
 *  AFPDHXContext.m
 *  MRFS
 *
 *  Created by han9kin on 2011-05-02.
 *
 */

#define AFPDHX_ENGINE DH
#define AFPDHX_NONCE  BIGNUM

#import <openssl/bn.h>
#import <openssl/dh.h>
#import <openssl/cast.h>
#import <openssl/rand.h>
#import <openssl/md5.h>
#import <sys/time.h>
#import "AFPDHXContext.h"


#define kDHX2KeySize 64
#define kNonceSize   16


static NSData *gPrime     = nil;
static int     gGenerator = 2;


static void RandAddEntropy()
{
    static BOOL sSeeded = NO;

    struct timeval sTime;

    gettimeofday(&sTime, NULL);
    RAND_add(&sTime, sizeof(sTime), (sSeeded ? (sizeof(sTime) / 2) : sizeof(sTime)));

    sSeeded = YES;
}


@interface NSData (BigNumConversion)

+ (NSData *)dataWithBignum:(BIGNUM *)aBignum length:(NSUInteger)aLength;
- (BIGNUM *)bignum;

@end


@implementation NSData (BigNumConversion)


+ (NSData *)dataWithBignum:(BIGNUM *)aBignum length:(NSUInteger)aLength
{
    unsigned char *sBuffer;

    if (aLength)
    {
        NSAssert(BN_num_bytes(aBignum) <= aLength, @"bignum overflow");
    }
    else
    {
        aLength = BN_num_bytes(aBignum);
    }

    sBuffer = calloc(1, aLength);
    BN_bn2bin(aBignum, sBuffer + aLength - BN_num_bytes(aBignum));

    return [self dataWithBytesNoCopy:sBuffer length:aLength freeWhenDone:YES];
}


- (BIGNUM *)bignum
{
    return BN_bin2bn([self bytes], [self length], NULL);
}


@end


@implementation AFPDHXContext


+ (void)initialize
{
    if (!gPrime)
    {
        DH *sDH;

        RandAddEntropy();

        sDH = DH_generate_parameters(kDHX2KeySize * 8, gGenerator, NULL, NULL);

        gPrime = [[NSData dataWithBignum:sDH->p length:kDHX2KeySize] retain];

        DH_free(sDH);
    }
}


- (void)dealloc
{
    [self cleanup];
    [super dealloc];
}


- (uint16_t)contextID
{
    return mID + mStep;
}


- (uint8_t)step
{
    return mStep;
}


- (uint8_t)version
{
    return mVersion;
}


- (NSData *)primeNumber
{
    return gPrime;
}


- (NSData *)generator
{
    unsigned char sGenerator[] = { 0, 0, 0, gGenerator };

    return [NSData dataWithBytes:sGenerator length:sizeof(sGenerator)];
}


- (int)keySize
{
    return mKeySize;
}


- (NSData *)publicKey
{
    return [NSData dataWithBignum:mDH->pub_key length:mKeySize];
}


- (int)nonceSize
{
    return kNonceSize;
}


- (NSData *)nonce
{
    return [NSData dataWithBignum:mNonce length:kNonceSize];
}


- (int)passwordSize
{
    return mPasswordSize;
}


- (void)prepareV1
{
    static const uint8_t sPrime[] = {
        0xBA, 0x28, 0x73, 0xDF, 0xB0, 0x60, 0x57, 0xD4,
        0x3F, 0x20, 0x24, 0x74, 0x4C, 0xEE, 0xE7, 0x5B
    };
    static const uint8_t sGenerator[] = { 0x07 };

    RandAddEntropy();

    RAND_pseudo_bytes((unsigned char *)&mID, sizeof(mID));

    if (mDH)
    {
        DH_free(mDH);
    }

    mDH = DH_new();

    mDH->p = BN_bin2bn(sPrime, sizeof(sPrime), NULL);
    mDH->g = BN_bin2bn(sGenerator, sizeof(sGenerator), NULL);

    mKeySize      = 16;
    mPasswordSize = 64;
    mStep         = 0;
    mVersion      = 1;
}


- (void)prepareV2
{
    RandAddEntropy();

    RAND_pseudo_bytes((unsigned char *)&mID, sizeof(mID));

    if (mDH)
    {
        DH_free(mDH);
    }

    mDH = DH_new();

    mDH->p = [gPrime bignum];
    mDH->g = BN_new();
    BN_set_word(mDH->g, gGenerator);

    mKeySize      = kDHX2KeySize;
    mPasswordSize = 256;
    mStep         = 0;
    mVersion      = 2;
}


- (void)cleanup
{
    if (mDH)
    {
        DH_free(mDH);
    }
    if (mNonce)
    {
        BN_free(mNonce);
    }
    if (mKey)
    {
        free(mKey);
    }

    mNonce = NULL;
    mDH    = NULL;
    mKey   = NULL;
}


- (void)generateKey
{
    DH_generate_key(mDH);
}


- (void)generateNonce
{
    if (mNonce)
    {
        BN_free(mNonce);
    }

    unsigned char sNonce[kNonceSize];

    RAND_bytes(sNonce, sizeof(sNonce));

    mNonce = BN_bin2bn(sNonce, sizeof(sNonce), NULL);
}


- (void)computeKeyWithCounterpartPublicKey:(NSData *)aPublicKey
{
    BIGNUM *sPubKey;

    if (mKey)
    {
        free(mKey);
    }

    sPubKey = [aPublicKey bignum];

    if (mVersion == 1)
    {
        mKey = malloc(DH_size(mDH));
        DH_compute_key(mKey, sPubKey, mDH);
    }
    else
    {
        unsigned char *sKey;
        int            sSize;

        sKey  = malloc(DH_size(mDH));
        sSize = DH_compute_key(sKey, sPubKey, mDH);

        mKey = malloc(MD5_DIGEST_LENGTH);
        MD5(sKey, sSize, mKey);

        free(sKey);
    }

    BN_free(sPubKey);
}


- (void)nextStep
{
    mStep++;
}


- (NSData *)decrypt:(NSData *)aData
{
    uint8_t        sC2SIV[] = { 0x4c, 0x57, 0x61, 0x6c, 0x6c, 0x61, 0x63, 0x65 };
    CAST_KEY       sCastKey;
    unsigned char *sResult;

    CAST_set_key(&sCastKey, DH_size(mDH), mKey);

    sResult = malloc([aData length]);

    CAST_cbc_encrypt([aData bytes], sResult, [aData length], &sCastKey, sC2SIV, CAST_DECRYPT);

    return [NSData dataWithBytesNoCopy:sResult length:[aData length] freeWhenDone:YES];
}


- (NSData *)encrypt:(NSData *)aData
{
    uint8_t        sS2CIV[] = { 0x43, 0x4a, 0x61, 0x6c, 0x62, 0x65, 0x72, 0x74 };
    CAST_KEY       sCastKey;
    unsigned char *sResult;

    CAST_set_key(&sCastKey, DH_size(mDH), mKey);

    sResult = malloc([aData length]);

    CAST_cbc_encrypt([aData bytes], sResult, [aData length], &sCastKey, sS2CIV, CAST_ENCRYPT);

    return [NSData dataWithBytesNoCopy:sResult length:[aData length] freeWhenDone:YES];
}


@end


@implementation NSData (BigNum)


- (NSData *)dataByAdding:(unsigned long)aValue
{
    BIGNUM *sBignum;
    NSData *sResult;

    sBignum = [self bignum];

    BN_add_word(sBignum, aValue);

    sResult = [NSData dataWithBignum:sBignum length:0];

    BN_free(sBignum);

    return sResult;
}


- (NSData *)dataBySubtracting:(unsigned long)aValue
{
    BIGNUM *sBignum;
    NSData *sResult;

    sBignum = [self bignum];

    BN_sub_word(sBignum, aValue);

    sResult = [NSData dataWithBignum:sBignum length:0];

    BN_free(sBignum);

    return sResult;
}


@end
