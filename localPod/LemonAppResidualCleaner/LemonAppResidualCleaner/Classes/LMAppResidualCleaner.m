//
//  LMAppResidualCleaner.m
//  LemonAppResidualCleaner
//
//  Created by Trae AI on 2024/10/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import "LMAppResidualCleaner.h"

@implementation LMAppResidualItem

- (instancetype)initWithPath:(NSString *)path size:(unsigned long long)size type:(NSString *)type app:(NSString *)app {
    if (self = [super init]) {
        _residualPath = path;
        _residualSize = size;
        _residualType = type;
        _relatedApp = app;
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:path error:&error];
        if (fileAttributes) {
            _modificationDate = fileAttributes[NSFileModificationDate];
        }
    }
    return self;
}

- (NSString *)formattedResidualSize {
    if (_residualSize < 1024) {
        return [NSString stringWithFormat:@"%.2f B", (double)_residualSize];
    } else if (_residualSize < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f KB", (double)_residualSize / 1024.0];
    } else if (_residualSize < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f MB", (double)_residualSize / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.2f GB", (double)_residualSize / (1024.0 * 1024.0 * 1024.0)];
    }
}

@end

@interface LMAppResidualCleaner ()

@property (nonatomic, strong) dispatch_queue_t scanningQueue;
@property (nonatomic, strong) dispatch_group_t scanningGroup;
@property (nonatomic, assign) BOOL shouldStopScanning;
@property (nonatomic, strong) NSMutableArray<LMAppResidualItem *> *foundResidualItems;
@property (nonatomic, assign) unsigned long long totalScannedItems;
@property (nonatomic, assign) unsigned long long totalItemsToScan;

@end

@implementation LMAppResidualCleaner

+ (instancetype)sharedInstance {
    static LMAppResidualCleaner *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{  
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _includedResidualPaths = [NSMutableArray array];
        _excludedResidualPaths = [NSMutableArray array];
        _scanningQueue = dispatch_queue_create("com.lemon.appresidual.scanning", DISPATCH_QUEUE_CONCURRENT);
        _scanningGroup = dispatch_group_create();
        _foundResidualItems = [NSMutableArray array];
        
        // Add default included residual file paths
        [self addDefaultIncludedResidualPaths];
        
        // Add default excluded residual file paths
        [self addDefaultExcludedResidualPaths];
    }
    return self;
}

- (void)addDefaultIncludedResidualPaths {
    // Add common application residual directories
    NSString *homeDirectory = NSHomeDirectory();
    
    // Application support directories
    [_includedResidualPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Application Support"]];
    
    // Preferences directories
    [_includedResidualPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Preferences"]];
    
    // Caches directories
    [_includedResidualPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Caches"]];
    
    // Containers directories
    [_includedResidualPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Containers"]];
    
    // Saved Application State
    [_includedResidualPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Saved Application State"]];
    
    // Logs directories
    [_includedResidualPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Logs"]];
}

- (void)addDefaultExcludedResidualPaths {
    // Exclude important system and application directories
    NSString *homeDirectory = NSHomeDirectory();
    
    // Exclude some system directories that might contain important data
    [_excludedResidualPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Application Support/iCloud"]];
    [_excludedResidualPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Application Support/Shared Files"]];
    [_excludedResidualPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Preferences/com.apple"]];
    [_excludedResidualPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Caches/com.apple"]];
}

- (void)startScanningAppResidualsWithProgress:(void (^)(double))progressBlock 
                                  completion:(void (^)(NSArray<LMAppResidualItem *> *residualItems, NSError * _Nullable error))completionBlock {
    if (self.isScanning) {
        NSError *error = [NSError errorWithDomain:@"LMAppResidualCleaner" code:600 userInfo:@{NSLocalizedDescriptionKey: @"Scanning is already in progress"}];
        completionBlock(@[], error);
        return;
    }
    
    self.scanning = YES;
    self.shouldStopScanning = NO;
    [self.foundResidualItems removeAllObjects];
    self.totalScannedItems = 0;
    self.totalItemsToScan = 0;
    
    // Calculate total items to scan for progress reporting
    dispatch_async(self.scanningQueue, ^{ 
        for (NSString *path in self.includedResidualPaths) {
            [self calculateTotalItemsAtPath:path];
        }
        
        // Start actual scanning
        for (NSString *path in self.includedResidualPaths) {
            dispatch_group_enter(self.scanningGroup);
            [self scanResidualDirectoryAtPath:path progress:progressBlock];
        }
        
        // Wait for all scanning to complete
        dispatch_group_notify(self.scanningGroup, dispatch_get_main_queue(), ^{ 
            if (self.shouldStopScanning) {
                self.scanning = NO;
                completionBlock(@[], [NSError errorWithDomain:@"LMAppResidualCleaner" code:601 userInfo:@{NSLocalizedDescriptionKey: @"Scanning was cancelled"}]);
                return;
            }
            
            self.scanning = NO;
            completionBlock(self.foundResidualItems, nil);
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
                // Only count potential residual files
                if ([self isPotentialResidualFile:itemPath]) {
                    self.totalItemsToScan++;
                }
            }
        }
    }
}

- (void)scanResidualDirectoryAtPath:(NSString *)path progress:(void (^)(double))progressBlock {
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
                [self scanSubResidualDirectoryAtPath:itemPath progress:progressBlock];
            } else {
                // Check if it's a potential residual file
                if ([self isPotentialResidualFile:itemPath]) {
                    [self checkResidualItemAtPath:itemPath];
                    
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
    }
    
    dispatch_group_leave(self.scanningGroup);
}

- (void)scanSubResidualDirectoryAtPath:(NSString *)path progress:(void (^)(double))progressBlock {
    dispatch_group_enter(self.scanningGroup);
    [self scanResidualDirectoryAtPath:path progress:progressBlock];
}

- (BOOL)isPotentialResidualFile:(NSString *)path {
    // Check if file is likely a residual file from uninstalled app
    NSString *fileName = [path lastPathComponent];
    NSString *directoryName = [[path stringByDeletingLastPathComponent] lastPathComponent];
    
    // Check for common application residual patterns
    BOOL isAppResidual = NO;
    
    // Check if directory name looks like an app bundle identifier
    if ([directoryName containsString:@"."]) {
        NSArray *parts = [directoryName componentsSeparatedByString:@"."];
        if (parts.count >= 2) {
            isAppResidual = YES;
        }
    }
    
    // Check for preference files
    if ([fileName hasSuffix:@".plist"] && [fileName containsString:@"."]) {
        isAppResidual = YES;
    }
    
    // Check for cache files in application-specific directories
    if ([path containsString:@"Caches"] && [directoryName containsString:@"."]) {
        isAppResidual = YES;
    }
    
    // Check for saved application state files
    if ([path containsString:@"Saved Application State"] && [fileName hasSuffix:@".savedState"]) {
        isAppResidual = YES;
    }
    
    return isAppResidual;
}

- (void)checkResidualItemAtPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:path error:&error];
    
    if (error) return;
    
    unsigned long long fileSize = [fileAttributes fileSize];
    if (fileSize > 0) {
        // Determine residual type and related app based on path
        NSString *residualType = [self determineResidualTypeForPath:path];
        NSString *relatedApp = [self determineRelatedAppForPath:path];
        LMAppResidualItem *residualItem = [[LMAppResidualItem alloc] initWithPath:path size:fileSize type:residualType app:relatedApp];
        @synchronized(self.foundResidualItems) {
            [self.foundResidualItems addObject:residualItem];
        }
    }
}

- (NSString *)determineResidualTypeForPath:(NSString *)path {
    if ([path containsString:@"Application Support"]) {
        return @"Application Support Files";
    } else if ([path containsString:@"Preferences"]) {
        return @"Preference Files";
    } else if ([path containsString:@"Caches"]) {
        return @"Cache Files";
    } else if ([path containsString:@"Containers"]) {
        return @"Container Files";
    } else if ([path containsString:@"Saved Application State"]) {
        return @"Saved State Files";
    } else if ([path containsString:@"Logs"]) {
        return @"Log Files";
    } else {
        return @"Other Residual Files";
    }
}

- (NSString *)determineRelatedAppForPath:(NSString *)path {
    // Extract app name from path
    NSString *appName = @"Unknown App";
    
    // Try to extract from directory name
    NSString *directoryName = [[path stringByDeletingLastPathComponent] lastPathComponent];
    if ([directoryName containsString:@"."]) {
        // For bundle identifiers, take the last part
        NSArray *parts = [directoryName componentsSeparatedByString:@"."];
        if (parts.count > 0) {
            appName = [parts lastObject];
        }
    } else {
        appName = directoryName;
    }
    
    // Clean up app name
    appName = [appName stringByReplacingOccurrencesOfString:@"com." withString:@""];
    appName = [appName stringByReplacingOccurrencesOfString:@"apple." withString:@""];
    
    return appName;
}

- (BOOL)shouldExcludePath:(NSString *)path {
    for (NSString *excludedPath in self.excludedResidualPaths) {
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

- (void)cleanResidualItems:(NSArray<LMAppResidualItem *> *)items 
                completion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ 
        NSFileManager *fileManager = [NSFileManager defaultManager];
        unsigned long long totalCleanedSize = 0;
        NSError *cleanError = nil;
        
        for (LMAppResidualItem *item in items) {
            // Safety check: ensure item exists and is not in excluded path
            if ([fileManager fileExistsAtPath:item.residualPath] && ![self shouldExcludePath:item.residualPath]) {
                BOOL deleted = [fileManager removeItemAtPath:item.residualPath error:&cleanError];
                if (deleted) {
                    totalCleanedSize += item.residualSize;
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{ 
            completionBlock(totalCleanedSize > 0, totalCleanedSize, cleanError);
        });
    });
}

- (void)cleanAllAppResidualsWithCompletion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock {
    // First scan for all residual items
    [self startScanningAppResidualsWithProgress:^(double progress) {
        // Progress is being reported
    } completion:^(NSArray<LMAppResidualItem *> *residualItems, NSError * _Nullable error) {
        if (error) {
            completionBlock(NO, 0, error);
        } else {
            // Clean all found residual items
            [self cleanResidualItems:residualItems completion:completionBlock];
        }
    }];
}

- (void)getTotalAppResidualSizeWithCompletion:(void (^)(unsigned long long totalSize, NSError * _Nullable error))completionBlock {
    // First scan for all residual items
    [self startScanningAppResidualsWithProgress:^(double progress) {
        // Progress is being reported
    } completion:^(NSArray<LMAppResidualItem *> *residualItems, NSError * _Nullable error) {
        if (error) {
            completionBlock(0, error);
        } else {
            // Calculate total residual size
            unsigned long long totalSize = 0;
            for (LMAppResidualItem *item in residualItems) {
                totalSize += item.residualSize;
            }
            completionBlock(totalSize, nil);
        }
    }];
}

@end