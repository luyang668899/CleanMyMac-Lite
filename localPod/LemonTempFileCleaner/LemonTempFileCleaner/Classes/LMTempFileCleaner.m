//
//  LMTempFileCleaner.m
//  LemonTempFileCleaner
//
//  Created by Trae AI on 2024/10/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import "LMTempFileCleaner.h"

@implementation LMTempFileItem

- (instancetype)initWithPath:(NSString *)path size:(unsigned long long)size type:(NSString *)type {
    if (self = [super init]) {
        _tempFilePath = path;
        _tempFileSize = size;
        _tempFileType = type;
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:path error:&error];
        if (fileAttributes) {
            _modificationDate = fileAttributes[NSFileModificationDate];
        }
    }
    return self;
}

- (NSString *)formattedTempFileSize {
    if (_tempFileSize < 1024) {
        return [NSString stringWithFormat:@"%.2f B", (double)_tempFileSize];
    } else if (_tempFileSize < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f KB", (double)_tempFileSize / 1024.0];
    } else if (_tempFileSize < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f MB", (double)_tempFileSize / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.2f GB", (double)_tempFileSize / (1024.0 * 1024.0 * 1024.0)];
    }
}

@end

@interface LMTempFileCleaner ()

@property (nonatomic, strong) dispatch_queue_t scanningQueue;
@property (nonatomic, strong) dispatch_group_t scanningGroup;
@property (nonatomic, assign) BOOL shouldStopScanning;
@property (nonatomic, strong) NSMutableArray<LMTempFileItem *> *foundTempItems;
@property (nonatomic, assign) unsigned long long totalScannedItems;
@property (nonatomic, assign) unsigned long long totalItemsToScan;

@end

@implementation LMTempFileCleaner

+ (instancetype)sharedInstance {
    static LMTempFileCleaner *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{  
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _includedTempPaths = [NSMutableArray array];
        _excludedTempPaths = [NSMutableArray array];
        _scanningQueue = dispatch_queue_create("com.lemon.temp.scanning", DISPATCH_QUEUE_CONCURRENT);
        _scanningGroup = dispatch_group_create();
        _foundTempItems = [NSMutableArray array];
        
        // Add default included temporary file paths
        [self addDefaultIncludedTempPaths];
        
        // Add default excluded temporary file paths
        [self addDefaultExcludedTempPaths];
    }
    return self;
}

- (void)addDefaultIncludedTempPaths {
    // Add common temporary directories
    NSString *homeDirectory = NSHomeDirectory();
    
    // System temporary directories
    [_includedTempPaths addObject:NSTemporaryDirectory()];
    
    // User temporary directories
    [_includedTempPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Caches/TemporaryItems"]];
    [_includedTempPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Application Support/TemporaryItems"]];
    
    // System-wide temporary directories
    [_includedTempPaths addObject:@"/tmp"];
    [_includedTempPaths addObject:@"/private/tmp"];
    [_includedTempPaths addObject:@"/private/var/tmp"];
    
    // Browser temporary directories
    [_includedTempPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Caches/com.apple.Safari/TemporaryItems"]];
    [_includedTempPaths addObject:[homeDirectory stringByAppendingPathComponent:@"Library/Caches/Google/Chrome/Default/Temporary Files"]];
}

- (void)addDefaultExcludedTempPaths {
    // Exclude important system temporary directories
    NSString *homeDirectory = NSHomeDirectory();
    
    // Exclude some system directories that might contain important data
    [_excludedTempPaths addObject:@"/private/var/tmp/com.apple.launchd"];
    [_excludedTempPaths addObject:@"/private/var/tmp/launchd"];
}

- (void)startScanningTempFilesWithProgress:(void (^)(double))progressBlock 
                                completion:(void (^)(NSArray<LMTempFileItem *> *tempItems, NSError * _Nullable error))completionBlock {
    if (self.isScanning) {
        NSError *error = [NSError errorWithDomain:@"LMTempFileCleaner" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Scanning is already in progress"}];
        completionBlock(@[], error);
        return;
    }
    
    self.scanning = YES;
    self.shouldStopScanning = NO;
    [self.foundTempItems removeAllObjects];
    self.totalScannedItems = 0;
    self.totalItemsToScan = 0;
    
    // Calculate total items to scan for progress reporting
    dispatch_async(self.scanningQueue, ^{ 
        for (NSString *path in self.includedTempPaths) {
            [self calculateTotalItemsAtPath:path];
        }
        
        // Start actual scanning
        for (NSString *path in self.includedTempPaths) {
            dispatch_group_enter(self.scanningGroup);
            [self scanTempDirectoryAtPath:path progress:progressBlock];
        }
        
        // Wait for all scanning to complete
        dispatch_group_notify(self.scanningGroup, dispatch_get_main_queue(), ^{ 
            if (self.shouldStopScanning) {
                self.scanning = NO;
                completionBlock(@[], [NSError errorWithDomain:@"LMTempFileCleaner" code:501 userInfo:@{NSLocalizedDescriptionKey: @"Scanning was cancelled"}]);
                return;
            }
            
            self.scanning = NO;
            completionBlock(self.foundTempItems, nil);
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
                // Only count temporary files
                if ([self isTempFile:itemPath]) {
                    self.totalItemsToScan++;
                }
            }
        }
    }
}

- (void)scanTempDirectoryAtPath:(NSString *)path progress:(void (^)(double))progressBlock {
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
                [self scanSubTempDirectoryAtPath:itemPath progress:progressBlock];
            } else {
                // Check if it's a temporary file
                if ([self isTempFile:itemPath]) {
                    [self checkTempItemAtPath:itemPath];
                    
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

- (void)scanSubTempDirectoryAtPath:(NSString *)path progress:(void (^)(double))progressBlock {
    dispatch_group_enter(self.scanningGroup);
    [self scanTempDirectoryAtPath:path progress:progressBlock];
}

- (BOOL)isTempFile:(NSString *)path {
    // Check if file has temporary extensions
    NSString *extension = [path pathExtension];
    NSString *fileName = [path lastPathComponent];
    NSArray *tempExtensions = @[@"tmp", @"temp", @"swp", @"swo", @"~", @"bak", @"backup"];
    
    return [tempExtensions containsObject:extension.lowercaseString] || 
           [fileName hasPrefix:@"."] ||
           [fileName hasSuffix:@"~"] ||
           [fileName containsString:@"temp"] ||
           [fileName containsString:@"Temp"] ||
           [fileName containsString:@"TMP"];
}

- (void)checkTempItemAtPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:path error:&error];
    
    if (error) return;
    
    unsigned long long fileSize = [fileAttributes fileSize];
    if (fileSize > 0) {
        // Determine temporary file type based on path
        NSString *tempType = [self determineTempTypeForPath:path];
        LMTempFileItem *tempItem = [[LMTempFileItem alloc] initWithPath:path size:fileSize type:tempType];
        @synchronized(self.foundTempItems) {
            [self.foundTempItems addObject:tempItem];
        }
    }
}

- (NSString *)determineTempTypeForPath:(NSString *)path {
    if ([path containsString:@"Safari"]) {
        return @"Safari Temporary Files";
    } else if ([path containsString:@"Chrome"]) {
        return @"Chrome Temporary Files";
    } else if ([path hasPrefix:@"/tmp"] || [path hasPrefix:@"/private/tmp"]) {
        return @"System Temporary Files";
    } else if ([path containsString:@"TemporaryItems"]) {
        return @"Application Temporary Files";
    } else {
        return @"Other Temporary Files";
    }
}

- (BOOL)shouldExcludePath:(NSString *)path {
    for (NSString *excludedPath in self.excludedTempPaths) {
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

- (void)cleanTempFileItems:(NSArray<LMTempFileItem *> *)items 
                completion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ 
        NSFileManager *fileManager = [NSFileManager defaultManager];
        unsigned long long totalCleanedSize = 0;
        NSError *cleanError = nil;
        
        for (LMTempFileItem *item in items) {
            // Safety check: ensure item exists and is not in excluded path
            if ([fileManager fileExistsAtPath:item.tempFilePath] && ![self shouldExcludePath:item.tempFilePath]) {
                BOOL deleted = [fileManager removeItemAtPath:item.tempFilePath error:&cleanError];
                if (deleted) {
                    totalCleanedSize += item.tempFileSize;
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{ 
            completionBlock(totalCleanedSize > 0, totalCleanedSize, cleanError);
        });
    });
}

- (void)cleanAllTempFilesWithCompletion:(void (^)(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error))completionBlock {
    // First scan for all temporary file items
    [self startScanningTempFilesWithProgress:^(double progress) {
        // Progress is being reported
    } completion:^(NSArray<LMTempFileItem *> *tempItems, NSError * _Nullable error) {
        if (error) {
            completionBlock(NO, 0, error);
        } else {
            // Clean all found temporary file items
            [self cleanTempFileItems:tempItems completion:completionBlock];
        }
    }];
}

- (void)getTotalTempFileSizeWithCompletion:(void (^)(unsigned long long totalSize, NSError * _Nullable error))completionBlock {
    // First scan for all temporary file items
    [self startScanningTempFilesWithProgress:^(double progress) {
        // Progress is being reported
    } completion:^(NSArray<LMTempFileItem *> *tempItems, NSError * _Nullable error) {
        if (error) {
            completionBlock(0, error);
        } else {
            // Calculate total temporary file size
            unsigned long long totalSize = 0;
            for (LMTempFileItem *item in tempItems) {
                totalSize += item.tempFileSize;
            }
            completionBlock(totalSize, nil);
        }
    }];
}

@end