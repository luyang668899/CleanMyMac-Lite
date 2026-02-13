//
//  LMAppCacheCleaner.h
//  LemonAppCacheCleaner
//
//  Created by Tencent on 2026/02/13.
//  Copyright © 2026 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LMAppCacheItem : NSObject

@property (nonatomic, strong) NSString *appName;
@property (nonatomic, strong) NSString *appBundleId;
@property (nonatomic, strong) NSString *appPath;
@property (nonatomic, strong) NSImage *appIcon;
@property (nonatomic, strong) NSArray *cachePaths;
@property (nonatomic, assign) uint64_t totalCacheSize;
@property (nonatomic, assign) BOOL isSelected;
@property (nonatomic, strong) NSString *appVersion;

@end

@interface LMAppCacheRule : NSObject

@property (nonatomic, strong) NSString *bundleId;
@property (nonatomic, strong) NSString *appName;
@property (nonatomic, strong) NSArray *cachePaths;
@property (nonatomic, strong) NSArray *excludePaths;
@property (nonatomic, assign) BOOL isEnabled;

@end

@interface LMAppCacheCleaner : NSObject

+ (instancetype)sharedInstance;

// 开始扫描应用缓存
- (void)startScanningWithCompletion:(void (^)(NSArray<LMAppCacheItem *> *items, uint64_t totalSize))completion;

// 清理选中的应用缓存
- (void)cleanSelectedItems:(NSArray<LMAppCacheItem *> *)items completion:(void (^)(BOOL success, uint64_t cleanedSize, NSError * _Nullable error))completion;

// 获取应用缓存清理规则
- (NSArray<LMAppCacheRule *> *)getAppCacheRules;

// 添加自定义应用缓存规则
- (void)addCustomCacheRule:(LMAppCacheRule *)rule;

// 获取应用缓存清理建议
- (NSArray<NSString *> *)getAppCacheSuggestions;

@end

NS_ASSUME_NONNULL_END
