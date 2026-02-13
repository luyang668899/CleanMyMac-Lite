//
//  LMCacheCleaner.h
//  LemonCacheCleaner
//
//  Created by Trae AI on 2024/10/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LMCacheItem : NSObject

@property (nonatomic, copy) NSString *cachePath;
@property (nonatomic, assign) unsigned long long cacheSize;
@property (nonatomic, copy) NSString *cacheType;
@property (nonatomic, strong) NSDate *modificationDate;

- (instancetype)initWithPath:(NSString *)path size:(unsigned long long)size type:(NSString *)type;
- (NSString *)formattedCacheSize;

@end

@interface LMCacheCleaner : NSObject

@property (nonatomic, strong, nullable) NSMutableArray<NSString *> *includedCachePaths;
@property (nonatomic, strong, nullable) NSMutableArray<NSString *> *excludedCachePaths;
@property (nonatomic, assign, getter=isScanning) BOOL scanning;

+ (instancetype)sharedInstance;

/**
 * Start scanning for cache files
 * @param progressBlock Progress callback
 * @param completionBlock Completion callback with found cache items
 */
- (void)startScanningCacheWithProgress:(void (^)(double progress))progressBlock 
                            completion:(void (^)(NSArray<LMCacheItem *> *cacheItems, NSError * _Nullable error))completionBlock;

/**
 * Stop current scanning process
 */
- (void)stopScanning;

/**
 * Clean selected cache items
 * @param items Array of LMCacheItem to clean
 * @param completionBlock Completion callback with cleaning result
 */
- (void)cleanCacheItems:(NSArray<LMCacheItem *> *)items 
             completion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock;

/**
 * Clean all cache files
 * @param completionBlock Completion callback with cleaning result
 */
- (void)cleanAllCacheWithCompletion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock;

/**
 * Get total cache size
 * @param completionBlock Completion callback with total cache size
 */
- (void)getTotalCacheSizeWithCompletion:(void (^)(unsigned long long totalSize, NSError * _Nullable error))completionBlock;

@end

NS_ASSUME_NONNULL_END
