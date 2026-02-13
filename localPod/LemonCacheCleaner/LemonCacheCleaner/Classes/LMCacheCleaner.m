//
//  LMCacheCleaner.m
//  LemonCacheCleaner
//
//  Created by Trae AI on 2024/10/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import "LMCacheCleaner.h"

@implementation LMCacheItem

- (instancetype)initWithPath:(NSString *)path size:(unsigned long long)size type:(NSString *)type {
    if (self = [super init]) {
        _cachePath = path;
        _cacheSize = size;
        _cacheType = type;
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:path error:&error];
        if (fileAttributes) {
            _modificationDate = fileAttributes[NSFileModificationDate];
        }
    }
    return self;
}

- (NSString *)formattedCacheSize {
    if (_cacheSize < 1024) {
        return [NSString stringWithFormat:@"%.2f B", (double)_cacheSize];
    } else if (_cacheSize < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f KB", (double)_cacheSize / 1024.0];
    } else if (_cacheSize < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f MB", (double)_cacheSize / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.2f GB", (double)_cacheSize / (1024.0 * 1024.0 * 1024.0)];
    }
}

@end

@interface LMCacheCleaner ()

@property (nonatomic, strong) dispatch_queue_t scanningQueue;
@property (nonatomic, strong) dispatch_group_t scanningGroup;
@property (nonatomic, assign) BOOL shouldStopScanning;
@property (nonatomic, strong) NSMutableArray<LMCacheItem *> *foundCacheItems;
@property (nonatomic, assign) unsigned long long totalScannedItems;
@property (nonatomic, assign) unsigned long long totalItemsToScan;

@end

@implementation LMCacheCleaner

+ (instancetype)sharedInstance {
    static LMCacheCleaner *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{  
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _includedCachePaths = [NSMutableArray array];
        _excludedCachePaths = [NSMutableArray array];
        _scanningQueue = dispatch_queue_create("com.lemon.cache.scanning", DISPATCH_QUEUE_CONCURRENT);
        _scanningGroup = dispatch_group_create();
        _foundCacheItems = [NSMutableArray array];
        
        // Add default included cache paths
        [self addDefaultIncludedCachePaths];
        
        // Add default excluded cache paths
        [self addDefaultExcludedCachePaths];
    }
    return self;
}

- (void)addDefaultIncludedCachePaths {
    // Add common cache directories
    NSString *homeDirectory = NSHomeDirectory();
    
    // Browser caches
    [_includedCachePaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Caches/com.apple.Safari"]];
    [_includedCachePaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Caches/Google/Chrome"]];
    [_includedCachePaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Caches/org.mozilla.firefox"]];
    
    // System caches
    [_includedCachePaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Caches"]];
    
    // Application caches
    [_includedCachePaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Application Support/Caches"]];
    
    // Temporary directories
    [_includedCachePaths addObject:NSTemporaryDirectory()];
}

- (void)addDefaultExcludedCachePaths {
    // Exclude important system caches
    NSString *homeDirectory = NSHomeDirectory();
    
    // Exclude some system directories that might contain important data
    [_excludedCachePaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Caches/com.apple.Safari/Favicon Cache"]];
    [_excludedCachePaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Caches/com.apple.iconservices"]];
    [_excludedCachePaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Caches/com.apple.IntelligentSuggestions"]];
}

- (void)startScanningCacheWithProgress:(void (^)(double))progressBlock 
                            completion:(void (^)(NSArray<LMCacheItem *> *cacheItems, NSError * _Nullable error))completionBlock {
    if (self.isScanning) {
        NSError *error = [NSError errorWithDomain:@"LMCacheCleaner" code:300 userInfo:@{NSLocalizedDescriptionKey: @"Scanning is already in progress"}];
        completionBlock(@[], error);
        return;
    }
    
    self.scanning = YES;
    self.shouldStopScanning = NO;
    [self.foundCacheItems removeAllObjects];
    self.totalScannedItems = 0;
    self.totalItemsToScan = 0;
    
    // Calculate total items to scan for progress reporting
    dispatch_async(self.scanningQueue, ^{ 
        for (NSString *path in self.includedCachePaths) {
            [self calculateTotalItemsAtPath:path];
        }
        
        // Start actual scanning
        for (NSString *path in self.includedCachePaths) {
            dispatch_group_enter(self.scanningGroup);
            [self scanCacheDirectoryAtPath:path progress:progressBlock];
        }
        
        // Wait for all scanning to complete
        dispatch_group_notify(self.scanningGroup, dispatch_get_main_queue(), ^{ 
            if (self.shouldStopScanning) {
                self.scanning = NO;
                completionBlock(@[], [NSError errorWithDomain:@"LMCacheCleaner" code:301 userInfo:@{NSLocalizedDescriptionKey: @"Scanning was cancelled"}]);
                return;
            }
            
            self.scanning = NO;
            completionBlock(self.foundCacheItems, nil);
        });
    });
}

- (void)calculateTotalItemsAtPath:(NSString *)path {
    if (self.shouldStopScanning) return;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Check if path exists
    if (![fileManager fileExistsAtPath:path]) return;
    
    // Check if path should be excluded
    if ([self shouldExcludePath:path]) return;
    
    NSError *error = nil;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:&error];
    
    if (error) return;
    
    for (NSString *item in contents) {
        NSString *itemPath = [path stringByAppendingPathComponent:item];
        
        // Check if path should be excluded
        if ([self shouldExcludePath:itemPath]) continue;
        
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:itemPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                [self calculateTotalItemsAtPath:itemPath];
            } else {
                self.totalItemsToScan++;
            }
        }
    }
}

- (void)scanCacheDirectoryAtPath:(NSString *)path progress:(void (^)(double))progressBlock {
    if (self.shouldStopScanning) {
        dispatch_group_leave(self.scanningGroup);
        return;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Check if path exists
    if (![fileManager fileExistsAtPath:path]) {
        dispatch_group_leave(self.scanningGroup);
        return;
    }
    
    // Check if path should be excluded
    if ([self shouldExcludePath:path]) {
        dispatch_group_leave(self.scanningGroup);
        return;
    }
    
    NSError *error = nil;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:&error];
    
    if (error) {
        dispatch_group_leave(self.scanningGroup);
        return;
    }
    
    for (NSString *item in contents) {
        if (self.shouldStopScanning) break;
        
        NSString *itemPath = [path stringByAppendingPathComponent:item];
        
        // Check if path should be excluded
        if ([self shouldExcludePath:itemPath]) continue;
        
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:itemPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                // Recursively scan subdirectory
                [self scanSubCacheDirectoryAtPath:itemPath progress:progressBlock];
            } else {
                // Check file size
                [self checkCacheItemAtPath:itemPath];
                
                // Update progress
                self.totalScannedItems++;
                if (self.totalItemsToScan > 0) {
                    double progress = (double)self.totalScannedItems / (double)self.totalItemsToScan;
                    dispatch_async(dispatch_get_main_queue(), ^{ 
                        progressBlock(progress);
                    });
                }
            }
        }
    }
    
    dispatch_group_leave(self.scanningGroup);
}

- (void)scanSubCacheDirectoryAtPath:(NSString *)path progress:(void (^)(double))progressBlock {
    dispatch_group_enter(self.scanningGroup);
    [self scanCacheDirectoryAtPath:path progress:progressBlock];
}

- (void)checkCacheItemAtPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:path error:&error];
    
    if (error) return;
    
    unsigned long long fileSize = [fileAttributes fileSize];
    if (fileSize > 0) {
        // Determine cache type based on path
        NSString *cacheType = [self determineCacheTypeForPath:path];
        LMCacheItem *cacheItem = [[LMCacheItem alloc] initWithPath:path size:fileSize type:cacheType];
        @synchronized(self.foundCacheItems) {
            [self.foundCacheItems addObject:cacheItem];
        }
    }
}

- (NSString *)determineCacheTypeForPath:(NSString *)path {
    if ([path containsString:@"Safari"]) {
        return @"Safari Cache";
    } else if ([path containsString:@"Chrome"]) {
        return @"Chrome Cache";
    } else if ([path containsString:@"firefox"]) {
        return @"Firefox Cache";
    } else if ([path containsString:@"Caches"]) {
        return @"System Cache";
    } else if ([path containsString:@"Temporary"]) {
        return @"Temporary Files";
    } else {
        return @"Other Cache";
    }
}

- (BOOL)shouldExcludePath:(NSString *)path {
    for (NSString *excludedPath in self.excludedCachePaths) {
        if ([path hasPrefix:excludedPath]) {
            return YES;
        }
    }
    return NO;
}

- (void)stopScanning {
    self.shouldStopScanning = YES;
    self.scanning = NO;
}

- (void)cleanCacheItems:(NSArray<LMCacheItem *> *)items 
             completion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ 
        NSFileManager *fileManager = [NSFileManager defaultManager];
        unsigned long long totalCleanedSize = 0;
        NSError *cleanError = nil;
        
        for (LMCacheItem *item in items) {
            // Safety check: ensure item exists and is not in excluded path
            if ([fileManager fileExistsAtPath:item.cachePath] && ![self shouldExcludePath:item.cachePath]) {
                BOOL deleted = [fileManager removeItemAtPath:item.cachePath error:&cleanError];
                if (deleted) {
                    totalCleanedSize += item.cacheSize;
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{ 
            completionBlock(totalCleanedSize > 0, totalCleanedSize, cleanError);
        });
    });
}

- (void)cleanAllCacheWithCompletion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock {
    // First scan for all cache items
    [self startScanningCacheWithProgress:^(double progress) {
        // Progress is being reported
    } completion:^(NSArray<LMCacheItem *> *cacheItems, NSError * _Nullable error) {
        if (error) {
            completionBlock(NO, 0, error);
        } else {
            // Clean all found cache items
            [self cleanCacheItems:cacheItems completion:completionBlock];
        }
    }];
}

- (void)getTotalCacheSizeWithCompletion:(void (^)(unsigned long long totalSize, NSError * _Nullable error))completionBlock {
    // First scan for all cache items
    [self startScanningCacheWithProgress:^(double progress) {
        // Progress is being reported
    } completion:^(NSArray<LMCacheItem *> *cacheItems, NSError * _Nullable error) {
        if (error) {
            completionBlock(0, error);
        } else {
            // Calculate total cache size
            unsigned long long totalSize = 0;
            for (LMCacheItem *item in cacheItems) {
                totalSize += item.cacheSize;
            }
            completionBlock(totalSize, nil);
        }
    }];
}

@end
