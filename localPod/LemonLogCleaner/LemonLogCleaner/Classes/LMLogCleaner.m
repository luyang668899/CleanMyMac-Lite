//
//  LMLogCleaner.m
//  LemonLogCleaner
//
//  Created by Trae AI on 2024/10/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import "LMLogCleaner.h"

@implementation LMLogItem

- (instancetype)initWithPath:(NSString *)path size:(unsigned long long)size type:(NSString *)type {
    if (self = [super init]) {
        _logPath = path;
        _logSize = size;
        _logType = type;
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:path error:&error];
        if (fileAttributes) {
            _modificationDate = fileAttributes[NSFileModificationDate];
        }
    }
    return self;
}

- (NSString *)formattedLogSize {
    if (_logSize < 1024) {
        return [NSString stringWithFormat:@"%.2f B", (double)_logSize];
    } else if (_logSize < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f KB", (double)_logSize / 1024.0];
    } else if (_logSize < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f MB", (double)_logSize / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.2f GB", (double)_logSize / (1024.0 * 1024.0 * 1024.0)];
    }
}

@end

@interface LMLogCleaner ()

@property (nonatomic, strong) dispatch_queue_t scanningQueue;
@property (nonatomic, strong) dispatch_group_t scanningGroup;
@property (nonatomic, assign) BOOL shouldStopScanning;
@property (nonatomic, strong) NSMutableArray<LMLogItem *> *foundLogItems;
@property (nonatomic, assign) unsigned long long totalScannedItems;
@property (nonatomic, assign) unsigned long long totalItemsToScan;

@end

@implementation LMLogCleaner

+ (instancetype)sharedInstance {
    static LMLogCleaner *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{  
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _includedLogPaths = [NSMutableArray array];
        _excludedLogPaths = [NSMutableArray array];
        _scanningQueue = dispatch_queue_create("com.lemon.log.scanning", DISPATCH_QUEUE_CONCURRENT);
        _scanningGroup = dispatch_group_create();
        _foundLogItems = [NSMutableArray array];
        
        // Add default included log paths
        [self addDefaultIncludedLogPaths];
        
        // Add default excluded log paths
        [self addDefaultExcludedLogPaths];
    }
    return self;
}

- (void)addDefaultIncludedLogPaths {
    // Add common log directories
    NSString *homeDirectory = NSHomeDirectory();
    
    // System logs
    [_includedLogPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Logs"]];
    
    // Application logs
    [_includedLogPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Application Support/Logs"]];
    
    // System-wide logs
    [_includedLogPaths addObject:@"/Library/Logs"];
    
    // Console logs
    [_includedLogPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Logs/DiagnosticReports"]];
}

- (void)addDefaultExcludedLogPaths {
    // Exclude important system logs
    NSString *homeDirectory = NSHomeDirectory();
    
    // Exclude some system directories that might contain important data
    [_excludedLogPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Logs/CoreDuet"]];
    [_excludedLogPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Logs/DiagnosticMessages"]];
}

- (void)startScanningLogsWithProgress:(void (^)(double))progressBlock 
                           completion:(void (^)(NSArray<LMLogItem *> *logItems, NSError * _Nullable error))completionBlock {
    if (self.isScanning) {
        NSError *error = [NSError errorWithDomain:@"LMLogCleaner" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Scanning is already in progress"}];
        completionBlock(@[], error);
        return;
    }
    
    self.scanning = YES;
    self.shouldStopScanning = NO;
    [self.foundLogItems removeAllObjects];
    self.totalScannedItems = 0;
    self.totalItemsToScan = 0;
    
    // Calculate total items to scan for progress reporting
    dispatch_async(self.scanningQueue, ^{ 
        for (NSString *path in self.includedLogPaths) {
            [self calculateTotalItemsAtPath:path];
        }
        
        // Start actual scanning
        for (NSString *path in self.includedLogPaths) {
            dispatch_group_enter(self.scanningGroup);
            [self scanLogDirectoryAtPath:path progress:progressBlock];
        }
        
        // Wait for all scanning to complete
        dispatch_group_notify(self.scanningGroup, dispatch_get_main_queue(), ^{ 
            if (self.shouldStopScanning) {
                self.scanning = NO;
                completionBlock(@[], [NSError errorWithDomain:@"LMLogCleaner" code:401 userInfo:@{NSLocalizedDescriptionKey: @"Scanning was cancelled"}]);
                return;
            }
            
            self.scanning = NO;
            completionBlock(self.foundLogItems, nil);
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
                // Only count files with log extensions
                if ([self isLogFile:itemPath]) {
                    self.totalItemsToScan++;
                }
            }
        }
    }
}

- (void)scanLogDirectoryAtPath:(NSString *)path progress:(void (^)(double))progressBlock {
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
                [self scanSubLogDirectoryAtPath:itemPath progress:progressBlock];
            } else {
                // Check if it's a log file
                if ([self isLogFile:itemPath]) {
                    [self checkLogItemAtPath:itemPath];
                    
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

- (void)scanSubLogDirectoryAtPath:(NSString *)path progress:(void (^)(double))progressBlock {
    dispatch_group_enter(self.scanningGroup);
    [self scanLogDirectoryAtPath:path progress:progressBlock];
}

- (BOOL)isLogFile:(NSString *)path {
    // Check if file has log extension
    NSString *extension = [path pathExtension];
    NSArray *logExtensions = @[@"log", @"txt", @"log.gz", @"crash", @"diag", @"trace"];
    
    return [logExtensions containsObject:extension.lowercaseString] || 
           [path containsString:@"log"] || 
           [path containsString:@"Log"] ||
           [path containsString:@"Crash"] ||
           [path containsString:@"Diagnostic"];
}

- (void)checkLogItemAtPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:path error:&error];
    
    if (error) return;
    
    unsigned long long fileSize = [fileAttributes fileSize];
    if (fileSize > 0) {
        // Determine log type based on path
        NSString *logType = [self determineLogTypeForPath:path];
        LMLogItem *logItem = [[LMLogItem alloc] initWithPath:path size:fileSize type:logType];
        @synchronized(self.foundLogItems) {
            [self.foundLogItems addObject:logItem];
        }
    }
}

- (NSString *)determineLogTypeForPath:(NSString *)path {
    if ([path containsString:@"DiagnosticReports"]) {
        return @"Diagnostic Reports";
    } else if ([path containsString:@"Application Support/Logs"]) {
        return @"Application Logs";
    } else if ([path hasPrefix:@"/Library/Logs"]) {
        return @"System-wide Logs";
    } else if ([path containsString:@"Library/Logs"]) {
        return @"User Logs";
    } else {
        return @"Other Logs";
    }
}

- (BOOL)shouldExcludePath:(NSString *)path {
    for (NSString *excludedPath in self.excludedLogPaths) {
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

- (void)cleanLogItems:(NSArray<LMLogItem *> *)items 
           completion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ 
        NSFileManager *fileManager = [NSFileManager defaultManager];
        unsigned long long totalCleanedSize = 0;
        NSError *cleanError = nil;
        
        for (LMLogItem *item in items) {
            // Safety check: ensure item exists and is not in excluded path
            if ([fileManager fileExistsAtPath:item.logPath] && ![self shouldExcludePath:item.logPath]) {
                BOOL deleted = [fileManager removeItemAtPath:item.logPath error:&cleanError];
                if (deleted) {
                    totalCleanedSize += item.logSize;
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{ 
            completionBlock(totalCleanedSize > 0, totalCleanedSize, cleanError);
        });
    });
}

- (void)cleanAllLogsWithCompletion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock {
    // First scan for all log items
    [self startScanningLogsWithProgress:^(double progress) {
        // Progress is being reported
    } completion:^(NSArray<LMLogItem *> *logItems, NSError * _Nullable error) {
        if (error) {
            completionBlock(NO, 0, error);
        } else {
            // Clean all found log items
            [self cleanLogItems:logItems completion:completionBlock];
        }
    }];
}

- (void)getTotalLogSizeWithCompletion:(void (^)(unsigned long long totalSize, NSError * _Nullable error))completionBlock {
    // First scan for all log items
    [self startScanningLogsWithProgress:^(double progress) {
        // Progress is being reported
    } completion:^(NSArray<LMLogItem *> *logItems, NSError * _Nullable error) {
        if (error) {
            completionBlock(0, error);
        } else {
            // Calculate total log size
            unsigned long long totalSize = 0;
            for (LMLogItem *item in logItems) {
                totalSize += item.logSize;
            }
            completionBlock(totalSize, nil);
        }
    }];
}

@end
