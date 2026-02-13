//
//  LMMemoryOptimizer.h
//  LemonMemoryOptimize
//
//  Created by Tencent on 2026/02/13.
//  Copyright © 2026 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LMMemoryAppInfo : NSObject

@property (nonatomic, strong) NSString *appName;
@property (nonatomic, strong) NSImage *appIcon;
@property (nonatomic, assign) pid_t pid;
@property (nonatomic, assign) uint64_t memoryUsage;
@property (nonatomic, assign) NSTimeInterval lastActiveTime;
@property (nonatomic, assign) BOOL isActive;

@end

@interface LMMemoryOptimizer : NSObject

@property (nonatomic, assign, readonly) uint64_t totalMemory;
@property (nonatomic, assign, readonly) uint64_t usedMemory;
@property (nonatomic, assign, readonly) double memoryUsageRate;

+ (instancetype)sharedInstance;

// 开始内存监控
- (void)startMonitoring;

// 停止内存监控
- (void)stopMonitoring;

// 手动触发内存优化
- (uint64_t)optimizeMemory;

// 获取内存使用详情
- (NSArray<LMMemoryAppInfo *> *)getMemoryUsageDetails;

// 设置内存紧张阈值（默认80%）
- (void)setMemoryThreshold:(double)threshold;

// 获取内存使用建议
- (NSString *)getMemoryUsageSuggestion;

@end

NS_ASSUME_NONNULL_END
