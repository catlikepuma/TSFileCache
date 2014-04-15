//
//  TSFileCache.m
//  TSFileCache
//
//  Created by Tomasz Szulc Prywatny on 15/04/14.
//  Copyright (c) 2014 Tomasz Szulc. All rights reserved.
//

#import "TSFileCache.h"

@interface NSURL (TSFileCache)
- (NSURL *)_tsfc_appendURL:(NSURL *)url;
@end

static NSString * const TSFileCacheErrorDomain = @"TSFileCacheErrorDomain";
@interface NSError (TSFileCache)
+ (NSError *)_tsfc_errorWithDescription:(NSString *)description;
@end


@interface TSFileCache (Prepare)
- (void)_prepareWithDirectoryAtURL:(NSURL *)directoryURL error:(NSError *__autoreleasing *)error;
@end

@interface TSFileCache (StorageManager)
- (NSData *)_readFileAtURL:(NSURL *)fileURL;
- (void)_writeData:(NSData *)data atURL:(NSURL *)fileURL;
- (void)_clearDirectoryAtURL:(NSURL *)storageURL;
@end

@interface TSFileCache (Helpers)
+ (NSURL *)_temporaryDirectoryURL;
@end


@implementation TSFileCache {
    NSURL *_directoryURL;
    NSCache *_cache;
}

static TSFileCache *_sharedInstance = nil;
+ (void)setSharedInstance:(TSFileCache *)instance {
    _sharedInstance = instance;
}

+ (instancetype)sharedInstance {
    return _sharedInstance;
}

#pragma mark - Initializers
+ (instancetype)cacheForURL:(NSURL *)directoryURL {
    NSParameterAssert(directoryURL && [directoryURL isFileURL]);
    return [[[self class] alloc] _initWithDirectoryURL:directoryURL];
}

+ (instancetype)cacheInTemporaryDirectoryWithRelativeURL:(NSURL *)relativeURL {
    NSParameterAssert(relativeURL);
    /// Build url relative to temporary directory
    NSURL *directoryURL = [[self _temporaryDirectoryURL] _tsfc_appendURL:relativeURL];
    return [self cacheForURL:directoryURL];
}


#pragma mark - Initialization
- (instancetype)_initWithDirectoryURL:(NSURL *)directoryURL
{
    self = [super init];
    if (self) {
        _directoryURL = directoryURL;
        _cache = [[NSCache alloc] init];
    }
    return self;
}


#pragma mark - Externals
- (void)prepare:(NSError *__autoreleasing *)error {
    NSError *localError = nil;
    [self _prepareWithDirectoryAtURL:_directoryURL error:&localError];
    if (!localError) {
        
    } else if (localError && error) {
        *error = localError;
    }
}

- (void)clear {
    [_cache removeAllObjects];
    [self _clearDirectoryAtURL:_directoryURL];
}

- (NSData *)dataForKey:(NSString *)key {
    NSData *data = nil;
    if (key) {
        data = [_cache objectForKey:key];
        if (!data) {
            data = [self _readFileAtURL:[_directoryURL URLByAppendingPathComponent:key]];
            if (data)
                [_cache setObject:data forKey:key];
        }
    }
    return data;
}

- (void)storeData:(NSData *)data forKey:(NSString *)key {
    if (data && key) {
        [self _writeData:data atURL:[_directoryURL URLByAppendingPathComponent:key]];
    }
}

@end

@implementation TSFileCache (Prepare)
- (void)_prepareWithDirectoryAtURL:(NSURL *)directoryURL error:(NSError *__autoreleasing *)error {
    NSError *localError = nil;
    /// Check if file exists and create directory if necessary
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL fileExists = [fileManager fileExistsAtPath:[directoryURL path] isDirectory:&isDirectory];
    if (fileExists) {
        if (!isDirectory) {
            localError = [NSError _tsfc_errorWithDescription:[NSString stringWithFormat:@"File at path %@ exists and it is not directory. Cannot create directory here.", [directoryURL path]]];
        }
    } else {
        NSError *createDirectoryError = nil;
        [fileManager createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:&createDirectoryError];
        if (createDirectoryError) {
            localError = [NSError _tsfc_errorWithDescription:createDirectoryError.localizedDescription];
        }
    }
    
    /// Return error if occured
    if (localError && error) {
        *error = localError;
    }
}

@end

@implementation TSFileCache (StorageManager)

- (NSData *)_readFileAtURL:(NSURL *)fileURL {
    return [[NSData alloc] initWithContentsOfURL:fileURL options:NSDataReadingUncached error:nil];
}

- (void)_writeData:(NSData *)data atURL:(NSURL *)fileURL {
    [data writeToURL:fileURL atomically:YES];
}

- (void)_clearDirectoryAtURL:(NSURL *)directoryURL {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:[directoryURL path]];
    
    NSString *fileName = nil;
    while (fileName = [enumerator nextObject]) {
        [fileManager removeItemAtPath:[[directoryURL URLByAppendingPathComponent:fileName] path] error:nil];
    }
}

@end


@implementation TSFileCache (Helpers)

+ (NSURL *)_temporaryDirectoryURL {
    return [NSURL fileURLWithPath:NSTemporaryDirectory()];
}

@end


@implementation NSURL (TSFileCache)

- (NSURL *)_tsfc_appendURL:(NSURL *)url {
    NSString *absoluteString = [url absoluteString];
    if ([absoluteString rangeOfString:@"/"].location == 0) {
        absoluteString = [absoluteString substringFromIndex:1];
    }
    
    return [self URLByAppendingPathComponent:absoluteString];
}

@end

@implementation NSError (TSFileCache)

+ (NSError *)_tsfc_errorWithDescription:(NSString *)description {
    NSDictionary *info = @{NSLocalizedDescriptionKey : description};
    return [NSError errorWithDomain:TSFileCacheErrorDomain code:-1 userInfo:info];
}

@end