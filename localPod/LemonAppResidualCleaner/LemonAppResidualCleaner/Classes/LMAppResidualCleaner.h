//
//  LMAppResidualCleaner.h
//  LemonAppResidualCleaner
//
//  Created by Trae AI on 2024/10/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LMAppResidualItem : NSObject

@property (nonatomic, copy) NSString *residualPath;
@property (nonatomic, assign) unsigned long long residualSize;
@property (nonatomic, copy) NSString *residualType;
@property (nonatomic, copy) NSString *relatedApp;
@property (nonatomic, strong) NSDate *modificationDate;

- (instancetype)initWithPath:(NSString *)path size:(unsigned long long)size type:(NSString *)type app:(NSString *)app;
- (NSString *)formattedResidualSize;

@end

@interface LMAppResidualCleaner : NSObject

@property (nonatomic, strong, nullable) NSMutableArray<NSString *> *includedResidualPaths;
@property (nonatomic, strong, nullable) NSMutableArray<NSString *> *excludedResidualPaths;
@property (nonatomic, assign, getter=isScanning) BOOL scanning;

+ (instancetype)sharedInstance;

/**
 * Start scanning for application residual files
 * @param progressBlock Progress callback
 * @param completionBlock Completion callback with found residual items
 */
- (void)startScanningAppResidualsWithProgress:(void (^)(double progress))progressBlock 
                                  completion:(void (^)(NSArray<LMAppResidualItem *> *residualItems, NSError * _Nullable error))completionBlock;

/**
 * Stop current scanning process
 */
- (void)stopScanning;

/**
 * Clean selected residual items
 * @param items Array of LMAppResidualItem to clean
 * @param completionBlock Completion callback with cleaning result
 */
- (void)cleanResidualItems:(NSArray<LMAppResidualItem *> *)items 
                completion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock;

/**
 * Clean all application residual files
 * @param completionBlock Completion callback with cleaning result
 */
- (void)cleanAllAppResidualsWithCompletion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock;

/**
 * Get total application residual size
 * @param completionBlock Completion callback with total residual size
 */
- (void)getTotalAppResidualSizeWithCompletion:(void (^)(unsigned long long totalSize, NSError * _Nullable error))completionBlock;

@end

NS_ASSUME_NONNULL_END