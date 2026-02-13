//
//  LMLoginItemOptimizer.m
//  LemonLoginItemOptimizer
//
//  Created by Tencent on 2026/02/13.
//  Copyright © 2026 Tencent. All rights reserved.
//

#import "LMLoginItemOptimizer.h"
#import <QMAppLoginItemManage/QMAppLoginItemManage.h>
#import <QMAppLoginItemManage/QMLocalAppHelper.h>

@interface LMLoginItemOptimizer ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, LMLoginItemInfo *> *loginItemMap;
@property (nonatomic, strong) dispatch_queue_t loginItemQueue;
@property (nonatomic, assign) NSTimeInterval startupStartTime;
@property (nonatomic, assign) NSTimeInterval startupEndTime;

@end

@implementation LMLoginItemOptimizer

+ (instancetype)sharedInstance {
    static LMLoginItemOptimizer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{        instance = [[self alloc] init];    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        [self initialize];    }
    return self;
}

- (void)initialize {
    self.loginItemMap = [NSMutableDictionary dictionary];
    self.loginItemQueue = dispatch_queue_create("com.tencent.lemon.login.item.optimizer", DISPATCH_QUEUE_SERIAL);
    [self loadLoginItemData];
}

- (void)loadLoginItemData {
    dispatch_async(self.loginItemQueue, ^{        QMLocalAppHelper *appHelper = [[QMLocalAppHelper alloc] init];
        NSArray *appLoginItems = [appHelper getAllLoginItems];
        
        for (QMBaseLoginItem *loginItem in appLoginItems) {
            LMLoginItemInfo *info = [[LMLoginItemInfo alloc] init];
            info.appName = loginItem.appName;
            info.appPath = loginItem.appPath;
            info.isEnabled = loginItem.isEnabled;
            info.launchTime = [self estimateLaunchTimeForApp:loginItem.appPath];
            info.lastUsedTime = [self getLastUsedTimeForApp:loginItem.appPath];
            info.usageFrequency = [self getUsageFrequencyForApp:loginItem.appPath];
            info.isEssential = [self isEssentialApp:loginItem.appName];
            
            [self.loginItemMap setObject:info forKey:loginItem.appName];
        }
    });
}

- (NSArray<LMLoginItemInfo *> *)getAllLoginItems {
    __block NSArray<LMLoginItemInfo *> *result;
    dispatch_sync(self.loginItemQueue, ^{        result = [self.loginItemMap allValues];    });
    return result;
}

- (void)optimizeLoginItemOrder {
    dispatch_async(self.loginItemQueue, ^{        // 获取所有启动项
        NSArray<LMLoginItemInfo *> *loginItems = [self getAllLoginItems];
        
        // 按优先级排序
        NSArray<LMLoginItemInfo *> *sortedItems = [loginItems sortedArrayUsingComparator:^NSComparisonResult(LMLoginItemInfo *obj1, LMLoginItemInfo *obj2) {
            // 1. 必要启动项优先
            if (obj1.isEssential && !obj2.isEssential) return NSOrderedAscending;
            if (!obj1.isEssential && obj2.isEssential) return NSOrderedDescending;
            
            // 2. 使用频率高的优先
            if (obj1.usageFrequency != obj2.usageFrequency) {
                return [@(obj2.usageFrequency) compare:@(obj1.usageFrequency)];
            }
            
            // 3. 最后使用时间近的优先
            if (obj1.lastUsedTime != obj2.lastUsedTime) {
                return [@(obj2.lastUsedTime) compare:@(obj1.lastUsedTime)];
            }
            
            // 4. 启动耗时短的优先
            return [@(obj1.launchTime) compare:@(obj2.launchTime)];
        }];
        
        // 应用优化后的顺序
        [self applyLoginItemOrder:sortedItems];
    });
}

- (void)applyLoginItemOrder:(NSArray<LMLoginItemInfo *> *)sortedItems {
    // 这里实现应用启动项顺序的逻辑
    // 由于macOS的启动项顺序管理比较复杂，这里主要是记录优化建议
    NSLog(@"Optimized login item order:");
    for (int i = 0; i < sortedItems.count; i++) {
        LMLoginItemInfo *item = sortedItems[i];
        NSLog(@"%d. %@ (Enabled: %@, Frequency: %ld, Last Used: %.0f days ago)", 
              i+1, item.appName, item.isEnabled ? @"YES" : @"NO", 
              (long)item.usageFrequency, 
              [[NSDate date] timeIntervalSince1970] - item.lastUsedTime > 86400 ? 
              ([[NSDate date] timeIntervalSince1970] - item.lastUsedTime) / 86400 : 0);
    }
}

- (NSArray<NSString *> *)getLoginItemSuggestions {
    __block NSMutableArray<NSString *> *suggestions;
    dispatch_sync(self.loginItemQueue, ^{        suggestions = [NSMutableArray array];
        
        NSArray<LMLoginItemInfo *> *loginItems = [self getAllLoginItems];
        
        // 分析启动项
        NSInteger enabledCount = 0;
        NSTimeInterval totalLaunchTime = 0;
        NSMutableArray<LMLoginItemInfo *> *rarelyUsedItems = [NSMutableArray array];
        NSMutableArray<LMLoginItemInfo *> *slowLaunchItems = [NSMutableArray array];
        
        for (LMLoginItemInfo *item in loginItems) {
            if (item.isEnabled) {
                enabledCount++;
                totalLaunchTime += item.launchTime;
                
                // 识别很少使用的启动项
                if (item.usageFrequency < 3) {
                    [rarelyUsedItems addObject:item];
                }
                
                // 识别启动慢的应用
                if (item.launchTime > 3.0) {
                    [slowLaunchItems addObject:item];
                }
            }
        }
        
        // 生成建议
        if (enabledCount > 10) {
            [suggestions addObject:[NSString stringWithFormat:@"您当前启用了 %ld 个启动项，建议减少到 8 个以下以提高开机速度", (long)enabledCount]];
        }
        
        if (totalLaunchTime > 20.0) {
            [suggestions addObject:[NSString stringWithFormat:@"启动项总耗时约 %.1f 秒，建议优化以减少开机时间", totalLaunchTime]];
        }
        
        if (rarelyUsedItems.count > 0) {
            NSMutableString *rarelyUsedStr = [NSMutableString stringWithString:@"以下应用很少使用，建议禁用其启动项："];
            for (LMLoginItemInfo *item in rarelyUsedItems) {
                [rarelyUsedStr appendFormat:@" %@", item.appName];
            }
            [suggestions addObject:rarelyUsedStr];
        }
        
        if (slowLaunchItems.count > 0) {
            NSMutableString *slowLaunchStr = [NSMutableString stringWithString:@"以下应用启动较慢，建议延迟启动："];
            for (LMLoginItemInfo *item in slowLaunchItems) {
                [slowLaunchStr appendFormat:@" %@ (%.1f秒)", item.appName, item.launchTime];
            }
            [suggestions addObject:slowLaunchStr];
        }
        
        if (suggestions.count == 0) {
            [suggestions addObject:@"您的启动项配置合理，无需优化"];
        }
    });
    return suggestions;
}

- (NSDictionary *)analyzeStartupProcess {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    // 模拟启动过程分析
    result[@"startupTime"] = @(self.startupEndTime - self.startupStartTime);
    result[@"loginItemCount"] = @([self getAllLoginItems].count);
    result[@"enabledLoginItemCount"] = @([self getEnabledLoginItemCount]);
    result[@"bottlenecks"] = [self identifyStartupBottlenecks];
    
    return result;
}

- (void)delayLaunchForApp:(NSString *)appName delaySeconds:(NSTimeInterval)seconds {
    dispatch_async(self.loginItemQueue, ^{        // 这里实现延迟启动的逻辑
        // 由于macOS的启动项管理限制，这里主要是记录延迟启动的建议
        NSLog(@"Delay launch for app %@ by %.1f seconds", appName, seconds);
        
        // 实际实现可能需要创建一个launchd配置来延迟启动
    });
}

- (BOOL)disableLoginItemForApp:(NSString *)appName {
    __block BOOL result = NO;
    dispatch_sync(self.loginItemQueue, ^{        QMLocalAppHelper *appHelper = [[QMLocalAppHelper alloc] init];
        NSArray *appLoginItems = [appHelper getAllLoginItems];
        
        for (QMBaseLoginItem *loginItem in appLoginItems) {
            if ([loginItem.appName isEqualToString:appName]) {
                result = [appHelper disableLoginItem:loginItem];
                if (result) {
                    LMLoginItemInfo *info = [self.loginItemMap objectForKey:appName];
                    if (info) {
                        info.isEnabled = NO;
                    }
                }
                break;
            }
        }
    });
    return result;
}

- (BOOL)enableLoginItemForApp:(NSString *)appName {
    __block BOOL result = NO;
    dispatch_sync(self.loginItemQueue, ^{        QMLocalAppHelper *appHelper = [[QMLocalAppHelper alloc] init];
        NSArray *appLoginItems = [appHelper getAllLoginItems];
        
        for (QMBaseLoginItem *loginItem in appLoginItems) {
            if ([loginItem.appName isEqualToString:appName]) {
                result = [appHelper enableLoginItem:loginItem];
                if (result) {
                    LMLoginItemInfo *info = [self.loginItemMap objectForKey:appName];
                    if (info) {
                        info.isEnabled = YES;
                    }
                }
                break;
            }
        }
    });
    return result;
}

#pragma mark - Helper Methods

- (NSTimeInterval)estimateLaunchTimeForApp:(NSString *)appPath {
    // 估算应用启动耗时
    // 这里可以根据应用大小、类型等因素进行估算
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *fileAttrs = [fileManager attributesOfItemAtPath:appPath error:nil];
    unsigned long long fileSize = [fileAttrs fileSize];
    
    // 简单估算：应用越大，启动时间越长
    NSTimeInterval estimatedTime = (double)fileSize / (1024.0 * 1024.0 * 5.0); // 每5MB约1秒
    return MAX(0.5, MIN(10.0, estimatedTime));
}

- (NSTimeInterval)getLastUsedTimeForApp:(NSString *)appPath {
    // 获取应用最后使用时间
    // 这里可以从应用的使用记录中获取
    // 暂时返回当前时间作为模拟数据
    return [[NSDate date] timeIntervalSince1970];
}

- (NSInteger)getUsageFrequencyForApp:(NSString *)appPath {
    // 获取应用使用频率
    // 这里可以从应用的使用记录中获取
    // 暂时返回随机值作为模拟数据
    return arc4random_uniform(10) + 1;
}

- (BOOL)isEssentialApp:(NSString *)appName {
    // 判断是否为必要应用
    NSArray *essentialApps = @[@"Finder", @"SystemUIServer", @"Dock", @"CoreServicesUIAgent"];
    return [essentialApps containsObject:appName];
}

- (NSInteger)getEnabledLoginItemCount {
    __block NSInteger count = 0;
    dispatch_sync(self.loginItemQueue, ^{        for (LMLoginItemInfo *info in [self.loginItemMap allValues]) {
            if (info.isEnabled) {
                count++;
            }
        }    });
    return count;
}

- (NSArray *)identifyStartupBottlenecks {
    // 识别启动瓶颈
    NSMutableArray *bottlenecks = [NSMutableArray array];
    
    for (LMLoginItemInfo *info in [self getAllLoginItems]) {
        if (info.isEnabled && info.launchTime > 5.0) {
            [bottlenecks addObject:[NSString stringWithFormat:@"%@ (启动耗时: %.1f秒)", info.appName, info.launchTime]];
        }
    }
    
    return bottlenecks;
}

@end

@implementation LMLoginItemInfo

@end
