//
//  LMLogCleaner.h
//  LemonLogCleaner
//
//  Created by Trae AI on 2024/10/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LMLogItem : NSObject

@property (nonatomic, copy) NSString *logPath;
@property (nonatomic, assign) unsigned long long logSize;
@property (nonatomic, copy) NSString *logType;
@property (nonatomic, strong) NSDate *modificationDate;

- (instancetype)initWithPath:(NSString *)path size:(unsigned long long)size type:(NSString *)type;
- (NSString *)formattedLogSize;

@end

@interface LMLogCleaner : NSObject

@property (nonatomic, strong, nullable) NSMutableArray<NSString *> *includedLogPaths;
@property (nonatomic, strong, nullable) NSMutableArray<NSString *> *excludedLogPaths;
@property (nonatomic, assign, getter=isScanning) BOOL scanning;

+ (instancetype)sharedInstance;

/**
 * Start scanning for log files
 * @param progressBlock Progress callback
 * @param completionBlock Completion callback with found log items
 */
- (void)startScanningLogsWithProgress:(void (^)(double progress))progressBlock 
                           completion:(void (^)(NSArray<LMLogItem *> *logItems, NSError * _Nullable error))completionBlock;

/**
 * Stop current scanning process
 */
- (void)stopScanning;

/**
 * Clean selected log items
 * @param items Array of LMLogItem to clean
 * @param completionBlock Completion callback with cleaning result
 */
- (void)cleanLogItems:(NSArray<LMLogItem *> *)items 
           completion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock;

/**
 * Clean all log files
 * @param completionBlock Completion callback with cleaning result
 */
- (void)cleanAllLogsWithCompletion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock;

/**
 * Get total log size
 * @param completionBlock Completion callback with total log size
 */
- (void)getTotalLogSizeWithCompletion:(void (^)(unsigned long long totalSize, NSError * _Nullable error))completionBlock;

@end

NS_ASSUME_NONNULL_END
