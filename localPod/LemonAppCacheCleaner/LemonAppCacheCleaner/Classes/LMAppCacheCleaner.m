//
//  LMAppCacheCleaner.m
//  LemonAppCacheCleaner
//
//  Created by Tencent on 2026/02/13.
//  Copyright © 2026 Tencent. All rights reserved.
//

#import "LMAppCacheCleaner.h"

@interface LMAppCacheCleaner ()

@property (nonatomic, strong) dispatch_queue_t scanQueue;
@property (nonatomic, strong) NSArray *defaultCacheRules;
@property (nonatomic, strong) NSMutableArray *customCacheRules;
@property (nonatomic, strong) NSMutableDictionary *appCacheInfoMap;

@end

@implementation LMAppCacheCleaner

+ (instancetype)sharedInstance {
    static LMAppCacheCleaner *instance = nil;
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
    self.scanQueue = dispatch_queue_create("com.tencent.lemon.app.cache.cleaner", DISPATCH_QUEUE_SERIAL);
    self.customCacheRules = [NSMutableArray array];
    self.appCacheInfoMap = [NSMutableDictionary dictionary];
    [self setupDefaultCacheRules];
}

- (void)setupDefaultCacheRules {
    // 默认的应用缓存清理规则
    NSMutableArray *rules = [NSMutableArray array];
    
    // Safari
    LMAppCacheRule *safariRule = [[LMAppCacheRule alloc] init];
    safariRule.bundleId = @"com.apple.Safari";
    safariRule.appName = @"Safari";
    safariRule.cachePaths = @[
        @"~/Library/Caches/com.apple.Safari",
        @"~/Library/Safari"
    ];
    safariRule.excludePaths = @[
        @"~/Library/Safari/Bookmarks.plist",
        @"~/Library/Safari/History.db"
    ];
    safariRule.isEnabled = YES;
    [rules addObject:safariRule];
    
    // Chrome
    LMAppCacheRule *chromeRule = [[LMAppCacheRule alloc] init];
    chromeRule.bundleId = @"com.google.Chrome";
    chromeRule.appName = @"Google Chrome";
    chromeRule.cachePaths = @[
        @"~/Library/Caches/Google/Chrome",
        @"~/Library/Application Support/Google/Chrome"
    ];
    chromeRule.excludePaths = @[
        @"~/Library/Application Support/Google/Chrome/Default/Bookmarks",
        @"~/Library/Application Support/Google/Chrome/Default/History"
    ];
    chromeRule.isEnabled = YES;
    [rules addObject:chromeRule];
    
    // Firefox
    LMAppCacheRule *firefoxRule = [[LMAppCacheRule alloc] init];
    firefoxRule.bundleId = @"org.mozilla.firefox";
    firefoxRule.appName = @"Firefox";
    firefoxRule.cachePaths = @[
        @"~/Library/Caches/Firefox",
        @"~/Library/Application Support/Firefox"
    ];
    firefoxRule.excludePaths = @[
        @"~/Library/Application Support/Firefox/Profiles/*/bookmarks.sqlite",
        @"~/Library/Application Support/Firefox/Profiles/*/places.sqlite"
    ];
    firefoxRule.isEnabled = YES;
    [rules addObject:firefoxRule];
    
    // Finder
    LMAppCacheRule *finderRule = [[LMAppCacheRule alloc] init];
    finderRule.bundleId = @"com.apple.finder";
    finderRule.appName = @"Finder";
    finderRule.cachePaths = @[
        @"~/Library/Caches/com.apple.finder"
    ];
    finderRule.excludePaths = @[];
    finderRule.isEnabled = YES;
    [rules addObject:finderRule];
    
    // Mail
    LMAppCacheRule *mailRule = [[LMAppCacheRule alloc] init];
    mailRule.bundleId = @"com.apple.mail";
    mailRule.appName = @"Mail";
    mailRule.cachePaths = @[
        @"~/Library/Caches/com.apple.mail"
    ];
    mailRule.excludePaths = @[];
    mailRule.isEnabled = YES;
    [rules addObject:mailRule];
    
    // Photos
    LMAppCacheRule *photosRule = [[LMAppCacheRule alloc] init];
    photosRule.bundleId = @"com.apple.Photos";
    photosRule.appName = @"Photos";
    photosRule.cachePaths = @[
        @"~/Library/Caches/com.apple.Photos"
    ];
    photosRule.excludePaths = @[];
    photosRule.isEnabled = YES;
    [rules addObject:photosRule];
    
    // Music
    LMAppCacheRule *musicRule = [[LMAppCacheRule alloc] init];
    musicRule.bundleId = @"com.apple.Music";
    musicRule.appName = @"Music";
    musicRule.cachePaths = @[
        @"~/Library/Caches/com.apple.Music"
    ];
    musicRule.excludePaths = @[];
    musicRule.isEnabled = YES;
    [rules addObject:musicRule];
    
    // 微信
    LMAppCacheRule *wechatRule = [[LMAppCacheRule alloc] init];
    wechatRule.bundleId = @"com.tencent.xinWeChat";
    wechatRule.appName = @"微信";
    wechatRule.cachePaths = @[
        @"~/Library/Caches/com.tencent.xinWeChat",
        @"~/Library/Application Support/com.tencent.xinWeChat"
    ];
    wechatRule.excludePaths = @[
        @"~/Library/Application Support/com.tencent.xinWeChat/*/Message"
    ];
    wechatRule.isEnabled = YES;
    [rules addObject:wechatRule];
    
    // QQ
    LMAppCacheRule *qqRule = [[LMAppCacheRule alloc] init];
    qqRule.bundleId = @"com.tencent.qq";
    qqRule.appName = @"QQ";
    qqRule.cachePaths = @[
        @"~/Library/Caches/com.tencent.qq",
        @"~/Library/Application Support/com.tencent.qq"
    ];
    qqRule.excludePaths = @[];
    qqRule.isEnabled = YES;
    [rules addObject:qqRule];
    
    self.defaultCacheRules = rules;
}

- (void)startScanningWithCompletion:(void (^)(NSArray<LMAppCacheItem *> *items, uint64_t totalSize))completion {
    dispatch_async(self.scanQueue, ^{        NSMutableArray<LMAppCacheItem *> *items = [NSMutableArray array];
        uint64_t totalSize = 0;
        
        // 获取所有应用
        NSArray *applications = [self getAllApplications];
        
        for (NSDictionary *appInfo in applications) {
            NSString *bundleId = appInfo[@"bundleId"];
            NSString *appName = appInfo[@"appName"];
            NSString *appPath = appInfo[@"appPath"];
            NSImage *appIcon = appInfo[@"appIcon"];
            NSString *appVersion = appInfo[@"appVersion"];
            
            // 查找匹配的缓存规则
            LMAppCacheRule *rule = [self findCacheRuleForBundleId:bundleId];
            if (rule && rule.isEnabled) {
                // 计算缓存大小
                uint64_t cacheSize = 0;
                NSMutableArray *cachePaths = [NSMutableArray array];
                
                for (NSString *pathPattern in rule.cachePaths) {
                    NSString *path = [pathPattern stringByExpandingTildeInPath];
                    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                        uint64_t pathSize = [self calculateDirectorySize:path excludePaths:rule.excludePaths];
                        if (pathSize > 0) {
                            cacheSize += pathSize;
                            [cachePaths addObject:path];
                        }
                    }
                }
                
                if (cacheSize > 0) {
                    LMAppCacheItem *item = [[LMAppCacheItem alloc] init];
                    item.appName = appName;
                    item.appBundleId = bundleId;
                    item.appPath = appPath;
                    item.appIcon = appIcon;
                    item.cachePaths = cachePaths;
                    item.totalCacheSize = cacheSize;
                    item.isSelected = YES;
                    item.appVersion = appVersion;
                    
                    [items addObject:item];
                    totalSize += cacheSize;
                }
            }
        }
        
        // 按缓存大小排序
        [items sortUsingComparator:^NSComparisonResult(LMAppCacheItem *obj1, LMAppCacheItem *obj2) {
            return [@(obj2.totalCacheSize) compare:@(obj1.totalCacheSize)];
        }];
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{                completion(items, totalSize);            });
        }
    });
}

- (void)cleanSelectedItems:(NSArray<LMAppCacheItem *> *)items completion:(void (^)(BOOL success, uint64_t cleanedSize, NSError * _Nullable error))completion {
    dispatch_async(self.scanQueue, ^{        uint64_t cleanedSize = 0;
        NSError *cleanError = nil;
        
        for (LMAppCacheItem *item in items) {
            if (item.isSelected) {
                // 查找匹配的缓存规则
                LMAppCacheRule *rule = [self findCacheRuleForBundleId:item.appBundleId];
                if (rule && rule.isEnabled) {
                    // 清理缓存路径
                    for (NSString *cachePath in item.cachePaths) {
                        uint64_t pathSize = [self cleanPath:cachePath excludePaths:rule.excludePaths error:&cleanError];
                        if (cleanError) {
                            break;
                        }
                        cleanedSize += pathSize;
                    }
                }
            }
            if (cleanError) {
                break;
            }
        }
        
        BOOL success = (cleanError == nil);
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{                completion(success, cleanedSize, cleanError);            });
        }
    });
}

- (NSArray<LMAppCacheRule *> *)getAppCacheRules {
    NSMutableArray<LMAppCacheRule *> *allRules = [NSMutableArray arrayWithArray:self.defaultCacheRules];
    [allRules addObjectsFromArray:self.customCacheRules];
    return allRules;
}

- (void)addCustomCacheRule:(LMAppCacheRule *)rule {
    if (rule && rule.bundleId) {
        [self.customCacheRules addObject:rule];
    }
}

- (NSArray<NSString *> *)getAppCacheSuggestions {
    NSMutableArray<NSString *> *suggestions = [NSMutableArray array];
    
    // 扫描应用缓存获取建议
    __block uint64_t totalCacheSize = 0;
    __block NSMutableDictionary *appCacheSizes = [NSMutableDictionary dictionary];
    
    dispatch_sync(self.scanQueue, ^{        // 获取所有应用
        NSArray *applications = [self getAllApplications];
        
        for (NSDictionary *appInfo in applications) {
            NSString *bundleId = appInfo[@"bundleId"];
            NSString *appName = appInfo[@"appName"];
            
            // 查找匹配的缓存规则
            LMAppCacheRule *rule = [self findCacheRuleForBundleId:bundleId];
            if (rule && rule.isEnabled) {
                // 计算缓存大小
                uint64_t cacheSize = 0;
                
                for (NSString *pathPattern in rule.cachePaths) {
                    NSString *path = [pathPattern stringByExpandingTildeInPath];
                    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                        cacheSize += [self calculateDirectorySize:path excludePaths:rule.excludePaths];
                    }
                }
                
                if (cacheSize > 0) {
                    totalCacheSize += cacheSize;
                    [appCacheSizes setObject:@(cacheSize) forKey:appName];
                }
            }
        }
    });
    
    // 生成建议
    if (totalCacheSize > 1024 * 1024 * 100) { // 超过100MB
        [suggestions addObject:[NSString stringWithFormat:@"应用缓存总占用较大 (%.2fGB)，建议清理", (double)totalCacheSize / (1024 * 1024 * 1024)]];
    }
    
    // 找出缓存占用最大的应用
    NSArray *sortedApps = [[appCacheSizes allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        return [appCacheSizes[obj2] compare:appCacheSizes[obj1]];
    }];
    
    if (sortedApps.count > 0) {
        NSString *topApp = sortedApps[0];
        uint64_t topAppSize = [appCacheSizes[topApp] unsignedLongLongValue];
        if (topAppSize > 1024 * 1024 * 50) { // 超过50MB
            [suggestions addObject:[NSString stringWithFormat:@"%@ 缓存占用较大 (%.2fGB)，建议优先清理", topApp, (double)topAppSize / (1024 * 1024 * 1024)]];
        }
    }
    
    if (suggestions.count == 0) {
        [suggestions addObject:@"应用缓存占用合理，无需清理"];
    }
    
    return suggestions;
}

#pragma mark - Helper Methods

- (LMAppCacheRule *)findCacheRuleForBundleId:(NSString *)bundleId {
    // 先查找默认规则
    for (LMAppCacheRule *rule in self.defaultCacheRules) {
        if ([rule.bundleId isEqualToString:bundleId]) {
            return rule;
        }
    }
    
    // 再查找自定义规则
    for (LMAppCacheRule *rule in self.customCacheRules) {
        if ([rule.bundleId isEqualToString:bundleId]) {
            return rule;
        }
    }
    
    return nil;
}

- (NSArray *)getAllApplications {
    NSMutableArray *applications = [NSMutableArray array];
    
    // 扫描应用程序目录
    NSArray *appDirectories = @[
        @"/Applications",
        @"~/Applications",
        @"/System/Applications",
        @"/System/Library/CoreServices"
    ];
    
    for (NSString *directoryPath in appDirectories) {
        NSString *expandedPath = [directoryPath stringByExpandingTildeInPath];
        [self scanApplicationsInDirectory:expandedPath intoArray:applications];
    }
    
    return applications;
}

- (void)scanApplicationsInDirectory:(NSString *)directoryPath intoArray:(NSMutableArray *)applications {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:directoryPath error:&error];
    if (error) {
        return;
    }
    
    for (NSString *item in contents) {
        NSString *itemPath = [directoryPath stringByAppendingPathComponent:item];
        
        // 跳过隐藏文件
        if ([item hasPrefix:@"."]) {
            continue;
        }
        
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:itemPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                if ([itemPath hasSuffix:@".app"]) {
                    // 是应用程序包
                    NSDictionary *appInfo = [self getApplicationInfo:itemPath];
                    if (appInfo) {
                        [applications addObject:appInfo];
                    }
                } else {
                    // 递归扫描子目录
                    [self scanApplicationsInDirectory:itemPath intoArray:applications];
                }
            }
        }
    }
}

- (NSDictionary *)getApplicationInfo:(NSString *)appPath {
    NSBundle *appBundle = [NSBundle bundleWithPath:appPath];
    if (!appBundle) {
        return nil;
    }
    
    NSString *bundleId = [appBundle bundleIdentifier];
    NSString *appName = [appBundle objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
    if (!appName) {
        appName = [appBundle objectForInfoDictionaryKey:(NSString *)kCFBundleIdentifierKey];
    }
    NSString *appVersion = [appBundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    NSImage *appIcon = [[NSWorkspace sharedWorkspace] iconForFile:appPath];
    
    return @{
        @"bundleId": bundleId ? bundleId : @"",
        @"appName": appName ? appName : @"",
        @"appPath": appPath,
        @"appIcon": appIcon,
        @"appVersion": appVersion ? appVersion : @"
    };
}

- (uint64_t)calculateDirectorySize:(NSString *)directoryPath excludePaths:(NSArray *)excludePaths {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    uint64_t totalSize = 0;
    
    NSError *error = nil;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:directoryPath error:&error];
    if (error) {
        return 0;
    }
    
    for (NSString *item in contents) {
        NSString *itemPath = [directoryPath stringByAppendingPathComponent:item];
        
        // 检查是否在排除路径中
        if ([self isPathInExcludeList:itemPath excludePaths:excludePaths]) {
            continue;
        }
        
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:itemPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                // 递归计算子目录大小
                totalSize += [self calculateDirectorySize:itemPath excludePaths:excludePaths];
            } else {
                // 计算文件大小
                NSDictionary *attributes = [fileManager attributesOfItemAtPath:itemPath error:nil];
                if (attributes) {
                    totalSize += [[attributes objectForKey:NSFileSize] unsignedLongLongValue];
                }
            }
        }
    }
    
    return totalSize;
}

- (uint64_t)cleanPath:(NSString *)path excludePaths:(NSArray *)excludePaths error:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    uint64_t cleanedSize = 0;
    
    NSError *cleanError = nil;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:&cleanError];
    if (cleanError) {
        if (error) {
            *error = cleanError;
        }
        return 0;
    }
    
    for (NSString *item in contents) {
        NSString *itemPath = [path stringByAppendingPathComponent:item];
        
        // 检查是否在排除路径中
        if ([self isPathInExcludeList:itemPath excludePaths:excludePaths]) {
            continue;
        }
        
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:itemPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                // 递归清理子目录
                cleanedSize += [self cleanPath:itemPath excludePaths:excludePaths error:&cleanError];
                if (cleanError) {
                    continue; // 继续清理其他项目
                }
                
                // 删除空目录
                [fileManager removeItemAtPath:itemPath error:nil];
            } else {
                // 计算文件大小
                NSDictionary *attributes = [fileManager attributesOfItemAtPath:itemPath error:nil];
                if (attributes) {
                    cleanedSize += [[attributes objectForKey:NSFileSize] unsignedLongLongValue];
                }
                
                // 删除文件
                [fileManager removeItemAtPath:itemPath error:nil];
            }
        }
    }
    
    return cleanedSize;
}

- (BOOL)isPathInExcludeList:(NSString *)path excludePaths:(NSArray *)excludePaths {
    for (NSString *excludePath in excludePaths) {
        // 处理通配符路径
        if ([excludePath containsString:@"*"]) {
            // 简化的通配符匹配
            NSString *pattern = [excludePath stringByReplacingOccurrencesOfString:@"*" withString:@".*"];
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
            if (regex) {
                NSTextCheckingResult *match = [regex firstMatchInString:path options:0 range:NSMakeRange(0, path.length)];
                if (match) {
                    return YES;
                }
            }
        } else {
            // 精确匹配
            NSString *expandedExcludePath = [excludePath stringByExpandingTildeInPath];
            if ([path isEqualToString:expandedExcludePath]) {
                return YES;
            }
        }
    }
    return NO;
}

@end

@implementation LMAppCacheItem

@end

@implementation LMAppCacheRule

@end
