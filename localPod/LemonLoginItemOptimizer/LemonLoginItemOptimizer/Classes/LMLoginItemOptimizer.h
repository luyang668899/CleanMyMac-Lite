//
//  LMLoginItemOptimizer.h
//  LemonLoginItemOptimizer
//
//  Created by Tencent on 2026/02/13.
//  Copyright © 2026 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LMLoginItemInfo : NSObject

@property (nonatomic, strong) NSString *appName;
@property (nonatomic, strong) NSString *appPath;
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) NSTimeInterval launchTime; // 启动耗时
@property (nonatomic, assign) NSTimeInterval lastUsedTime; // 最后使用时间
@property (nonatomic, assign) NSInteger usageFrequency; // 使用频率
@property (nonatomic, assign) BOOL isEssential; // 是否为必要启动项

@end

@interface LMLoginItemOptimizer : NSObject

+ (instancetype)sharedInstance;

// 获取所有启动项
- (NSArray<LMLoginItemInfo *> *)getAllLoginItems;

// 优化启动项顺序
- (void)optimizeLoginItemOrder;

// 获取启动项建议
- (NSArray<NSString *> *)getLoginItemSuggestions;

// 分析启动过程
- (NSDictionary *)analyzeStartupProcess;

// 延迟启动指定应用
- (void)delayLaunchForApp:(NSString *)appName delaySeconds:(NSTimeInterval)seconds;

// 禁用指定应用的启动项
- (BOOL)disableLoginItemForApp:(NSString *)appName;

// 启用指定应用的启动项
- (BOOL)enableLoginItemForApp:(NSString *)appName;

@end

NS_ASSUME_NONNULL_END
