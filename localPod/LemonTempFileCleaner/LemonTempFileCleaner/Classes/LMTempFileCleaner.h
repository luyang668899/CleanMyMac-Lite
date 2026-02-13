//
//  LMTempFileCleaner.h
//  LemonTempFileCleaner
//
//  Created by Trae AI on 2024/10/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LMTempFileItem : NSObject

@property (nonatomic, copy) NSString *tempFilePath;
@property (nonatomic, assign) unsigned long long tempFileSize;
@property (nonatomic, copy) NSString *tempFileType;
@property (nonatomic, strong) NSDate *modificationDate;

- (instancetype)initWithPath:(NSString *)path size:(unsigned long long)size type:(NSString *)type;
- (NSString *)formattedTempFileSize;

@end

@interface LMTempFileCleaner : NSObject

@property (nonatomic, strong, nullable) NSMutableArray<NSString *> *includedTempPaths;
@property (nonatomic, strong, nullable) NSMutableArray<NSString *> *excludedTempPaths;
@property (nonatomic, assign, getter=isScanning) BOOL scanning;

+ (instancetype)sharedInstance;

/**
 * Start scanning for temporary files
 * @param progressBlock Progress callback
 * @param completionBlock Completion callback with found temporary file items
 */
- (void)startScanningTempFilesWithProgress:(void (^)(double progress))progressBlock 
                                completion:(void (^)(NSArray<LMTempFileItem *> *tempItems, NSError * _Nullable error))completionBlock;

/**
 * Stop current scanning process
 */
- (void)stopScanning;

/**
 * Clean selected temporary file items
 * @param items Array of LMTempFileItem to clean
 * @param completionBlock Completion callback with cleaning result
 */
- (void)cleanTempFileItems:(NSArray<LMTempFileItem *> *)items 
                completion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock;

/**
 * Clean all temporary files
 * @param completionBlock Completion callback with cleaning result
 */
- (void)cleanAllTempFilesWithCompletion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock;

/**
 * Get total temporary file size
 * @param completionBlock Completion callback with total temporary file size
 */
- (void)getTotalTempFileSizeWithCompletion:(void (^)(unsigned long long totalSize, NSError * _Nullable error))completionBlock;

@end

NS_ASSUME_NONNULL_END