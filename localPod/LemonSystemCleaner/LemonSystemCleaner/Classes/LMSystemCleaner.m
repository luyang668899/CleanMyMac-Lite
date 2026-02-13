//
//  LMSystemCleaner.m
//  LemonSystemCleaner
//
//  Created by Tencent on 2026/02/13.
//  Copyright © 2026 Tencent. All rights reserved.
//

#import "LMSystemCleaner.h"

@interface LMSystemCleaner ()

@property (nonatomic, strong) dispatch_queue_t scanQueue;
@property (nonatomic, strong) NSArray *safeCleanPaths;
@property (nonatomic, strong) NSArray *dangerousPaths;

@end

@implementation LMSystemCleaner

+ (instancetype)sharedInstance {
    static LMSystemCleaner *instance = nil;
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
    self.scanQueue = dispatch_queue_create("com.tencent.lemon.system.cleaner", DISPATCH_QUEUE_SERIAL);
    [self setupSafeCleanPaths];
    [self setupDangerousPaths];
}

- (void)setupSafeCleanPaths {
    // 安全的系统清理路径
    self.safeCleanPaths = @[
        // 系统缓存
        @{@"path": @"/Library/Caches", @"name": @"系统缓存", @"description": @"系统应用产生的缓存文件"},
        // 系统日志
        @{@"path": @"/Library/Logs", @"name": @"系统日志", @"description": @"系统运行时产生的日志文件"},
        // 诊断报告
        @{@"path": @"/Library/Logs/DiagnosticReports", @"name": @"诊断报告", @"description": @"系统诊断产生的报告文件"},
        // ASL日志
        @{@"path": @"/private/var/log/asl", @"name": @"ASL日志", @"description": @"Apple System Logs"},
        // 诊断消息
        @{@"path": @"/private/var/log/DiagnosticMessages", @"name": @"诊断消息", @"description": @"系统诊断消息日志"},
        // CUPS打印日志
        @{@"path": @"/private/var/log/cups", @"name": @"打印日志", @"description": @"CUPS打印系统日志"},
        // 系统更新缓存
        @{@"path": @"/Library/Updates", @"name": @"系统更新缓存", @"description": @"系统更新产生的缓存文件"},
        // 字体缓存
        @{@"path": @"/Library/Caches/com.apple.FontRegistry", @"name": @"字体缓存", @"description": @"系统字体缓存文件"},
        // Spotlight索引缓存
        @{@"path": @"/private/var/db/Spotlight", @"name": @"Spotlight缓存", @"description": @"Spotlight搜索索引缓存"},
        // 临时文件
        @{@"path": @"/private/var/tmp", @"name": @"临时文件", @"description": @"系统临时文件"},
        // 回收站
        @{@"path": @"~/.Trash", @"name": @"回收站", @"description": @"已删除的文件"}
    ];
}

- (void)setupDangerousPaths {
    // 危险的路径，需要避免清理
    self.dangerousPaths = @[
        "/System",
        "/Library/Preferences",
        "/Library/Application Support",
        "/private/var/root",
        "/private/etc",
        "/private/var/db/systemstats",
        "/private/var/folders",
        "/Users",
        "/Applications"
    ];
}

- (void)startScanningWithCompletion:(void (^)(NSArray<LMSystemCleanItem *> *items, uint64_t totalSize))completion {
    dispatch_async(self.scanQueue, ^{        NSMutableArray<LMSystemCleanItem *> *items = [NSMutableArray array];
        uint64_t totalSize = 0;
        
        for (NSDictionary *pathInfo in self.safeCleanPaths) {
            NSString *path = pathInfo[@"path"];
            // 处理波浪号路径
            if ([path hasPrefix:@"~"]) {
                path = [path stringByExpandingTildeInPath];
            }
            
            // 验证路径安全性
            if ([self validatePathSafety:path]) {
                // 计算路径大小
                uint64_t size = [self calculateDirectorySize:path];
                if (size > 0) {
                    LMSystemCleanItem *item = [[LMSystemCleanItem alloc] init];
                    item.itemName = pathInfo[@"name"];
                    item.itemDescription = pathInfo[@"description"];
                    item.path = path;
                    item.size = size;
                    item.isSafeToClean = YES;
                    item.isSelected = YES;
                    
                    [items addObject:item];
                    totalSize += size;
                }
            }
        }
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{                completion(items, totalSize);            });
        }
    });
}

- (void)cleanSelectedItems:(NSArray<LMSystemCleanItem *> *)items completion:(void (^)(BOOL success, uint64_t cleanedSize, NSError * _Nullable error))completion {
    dispatch_async(self.scanQueue, ^{        uint64_t cleanedSize = 0;
        NSError *cleanError = nil;
        
        for (LMSystemCleanItem *item in items) {
            if (item.isSelected && item.isSafeToClean) {
                // 验证路径安全性
                if ([self validatePathSafety:item.path]) {
                    // 清理路径
                    uint64_t itemSize = [self cleanPath:item.path error:&cleanError];
                    if (cleanError) {
                        break;
                    }
                    cleanedSize += itemSize;
                }
            }
        }
        
        BOOL success = (cleanError == nil);
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{                completion(success, cleanedSize, cleanError);            });
        }
    });
}

- (NSArray<NSString *> *)getSystemCleanSuggestions {
    NSMutableArray<NSString *> *suggestions = [NSMutableArray array];
    
    // 扫描系统数据获取建议
    __block uint64_t systemCacheSize = 0;
    __block uint64_t systemLogsSize = 0;
    __block uint64_t trashSize = 0;
    
    dispatch_sync(self.scanQueue, ^{        for (NSDictionary *pathInfo in self.safeCleanPaths) {
            NSString *path = pathInfo[@"path"];
            if ([path hasPrefix:@"~"]) {
                path = [path stringByExpandingTildeInPath];
            }
            
            if ([self validatePathSafety:path]) {
                uint64_t size = [self calculateDirectorySize:path];
                if (size > 0) {
                    NSString *name = pathInfo[@"name"];
                    if ([name isEqualToString:@"系统缓存"]) {
                        systemCacheSize = size;
                    } else if ([name isEqualToString:@"系统日志"]) {
                        systemLogsSize = size;
                    } else if ([name isEqualToString:@"回收站"]) {
                        trashSize = size;
                    }
                }
            }
        }
    });
    
    // 生成建议
    if (systemCacheSize > 1024 * 1024 * 100) { // 超过100MB
        [suggestions addObject:[NSString stringWithFormat:@"系统缓存占用较大 (%.2fGB)，建议清理", (double)systemCacheSize / (1024 * 1024 * 1024)]];
    }
    
    if (systemLogsSize > 1024 * 1024 * 50) { // 超过50MB
        [suggestions addObject:[NSString stringWithFormat:@"系统日志占用较大 (%.2fGB)，建议清理", (double)systemLogsSize / (1024 * 1024 * 1024)]];
    }
    
    if (trashSize > 1024 * 1024 * 100) { // 超过100MB
        [suggestions addObject:[NSString stringWithFormat:@"回收站占用较大 (%.2fGB)，建议清理", (double)trashSize / (1024 * 1024 * 1024)]];
    }
    
    if (suggestions.count == 0) {
        [suggestions addObject:@"系统数据占用合理，无需清理"];
    }
    
    return suggestions;
}

- (BOOL)validatePathSafety:(NSString *)path {
    // 检查路径是否在危险路径列表中
    for (NSString *dangerousPath in self.dangerousPaths) {
        if ([path hasPrefix:dangerousPath]) {
            // 特殊处理：某些子路径可能是安全的
            if ([dangerousPath isEqualToString:@"/private/var/log"]) {
                // /private/var/log 下的某些子目录是安全的
                return YES;
            } else if ([dangerousPath isEqualToString:@"/private/var/tmp"]) {
                // /private/var/tmp 是安全的
                return YES;
            }
            return NO;
        }
    }
    
    // 检查路径是否存在
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        return NO;
    }
    
    // 检查路径是否为目录
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory]) {
        return NO;
    }
    
    // 检查路径权限
    NSError *error = nil;
    NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:&error];
    if (error) {
        return NO;
    }
    
    // 检查是否为系统关键目录
    NSString *lastComponent = [path lastPathComponent];
    NSArray *criticalDirectories = @["kernel", "mach_kernel", "System", "Library", "Preferences"];
    if ([criticalDirectories containsObject:lastComponent]) {
        return NO;
    }
    
    return YES;
}

#pragma mark - Helper Methods

- (uint64_t)calculateDirectorySize:(NSString *)directoryPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    uint64_t totalSize = 0;
    
    NSError *error = nil;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:directoryPath error:&error];
    if (error) {
        return 0;
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
                // 递归计算子目录大小
                totalSize += [self calculateDirectorySize:itemPath];
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

- (uint64_t)cleanPath:(NSString *)path error:(NSError **)error {
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
        
        // 跳过隐藏文件
        if ([item hasPrefix:@"."]) {
            continue;
        }
        
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:itemPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                // 递归清理子目录
                cleanedSize += [self cleanPath:itemPath error:&cleanError];
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

@end

@implementation LMSystemCleanItem

@end
