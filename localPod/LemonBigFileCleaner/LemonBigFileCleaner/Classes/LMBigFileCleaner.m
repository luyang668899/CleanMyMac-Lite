//
//  LMBigFileCleaner.m
//  LemonBigFileCleaner
//
//  Created by Trae AI on 2024/10/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import "LMBigFileCleaner.h"

@implementation LMBigFileItem

- (instancetype)initWithPath:(NSString *)path size:(unsigned long long)size {
    if (self = [super init]) {
        _filePath = path;
        _fileSize = size;
        _fileName = [path lastPathComponent];
        
        NSError *error = nil;
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
        if (fileAttributes) {
            _modificationDate = fileAttributes[NSFileModificationDate];
        }
    }
    return self;
}

- (NSString *)formattedFileSize {
    if (_fileSize < 1024) {
        return [NSString stringWithFormat:@"%.2f B", (double)_fileSize];
    } else if (_fileSize < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f KB", (double)_fileSize / 1024.0];
    } else if (_fileSize < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f MB", (double)_fileSize / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.2f GB", (double)_fileSize / (1024.0 * 1024.0 * 1024.0)];
    }
}

@end

@interface LMBigFileCleaner ()

@property (nonatomic, strong) dispatch_queue_t scanningQueue;
@property (nonatomic, strong) dispatch_group_t scanningGroup;
@property (nonatomic, assign) BOOL shouldStopScanning;
@property (nonatomic, strong) NSMutableArray<LMBigFileItem *> *foundBigFiles;
@property (nonatomic, assign) unsigned long long totalScannedFiles;
@property (nonatomic, assign) unsigned long long totalFilesToScan;

@end

@implementation LMBigFileCleaner

+ (instancetype)sharedInstance {
    static LMBigFileCleaner *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{  
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _minimumFileSize = 100 * 1024 * 1024; // Default: 100MB
        _excludedPaths = [NSMutableArray array];
        _scanningQueue = dispatch_queue_create("com.lemon.bigfile.scanning", DISPATCH_QUEUE_CONCURRENT);
        _scanningGroup = dispatch_group_create();
        _foundBigFiles = [NSMutableArray array];
        
        // Add default excluded paths
        [self addDefaultExcludedPaths];
    }
    return self;
}

- (void)addDefaultExcludedPaths {
    // Exclude system directories
    [_excludedPaths addObject:@"/System"];
    [_excludedPaths addObject:@"/Library"];
    [_excludedPaths addObject:@"/Applications"];
    [_excludedPaths addObject:@"/usr"];
    [_excludedPaths addObject:@"/bin"];
    [_excludedPaths addObject:@"/sbin"];
    [_excludedPaths addObject:@"/private"];
    
    // Exclude user library directories that might contain important data
    NSString *userLibraryPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library"];
    [_excludedPaths addObject:userLibraryPath];
}

- (void)startScanningPaths:(NSArray<NSString *> *)paths 
                  progress:(void (^)(double))progressBlock 
                completion:(void (^)(NSArray<LMBigFileItem *> *bigFiles, NSError * _Nullable error))completionBlock {
    if (self.isScanning) {
        NSError *error = [NSError errorWithDomain:@"LMBigFileCleaner" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Scanning is already in progress"}];
        completionBlock(@[], error);
        return;
    }
    
    self.scanning = YES;
    self.shouldStopScanning = NO;
    [self.foundBigFiles removeAllObjects];
    self.totalScannedFiles = 0;
    self.totalFilesToScan = 0;
    
    // Calculate total files to scan for progress reporting
    dispatch_async(self.scanningQueue, ^{ 
        for (NSString *path in paths) {
            [self calculateTotalFilesAtPath:path];
        }
        
        // Start actual scanning
        for (NSString *path in paths) {
            dispatch_group_enter(self.scanningGroup);
            [self scanDirectoryAtPath:path progress:progressBlock];
        }
        
        // Wait for all scanning to complete
        dispatch_group_notify(self.scanningGroup, dispatch_get_main_queue(), ^{ 
            self.scanning = NO;
            
            if (self.shouldStopScanning) {
                completionBlock(@[], [NSError errorWithDomain:@"LMBigFileCleaner" code:101 userInfo:@{NSLocalizedDescriptionKey: @"Scanning was cancelled"}]);
            } else {
                // Sort big files by size (descending)
                NSArray<LMBigFileItem *> *sortedFiles = [self.foundBigFiles sortedArrayUsingComparator:^NSComparisonResult(LMBigFileItem *obj1, LMBigFileItem *obj2) {
                    return obj2.fileSize < obj1.fileSize;
                }];
                completionBlock(sortedFiles, nil);
            }
        });
    });
}

- (void)calculateTotalFilesAtPath:(NSString *)path {
    if (self.shouldStopScanning) return;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
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
                [self calculateTotalFilesAtPath:itemPath];
            } else {
                self.totalFilesToScan++;
            }
        }
    }
}

- (void)scanDirectoryAtPath:(NSString *)path progress:(void (^)(double))progressBlock {
    if (self.shouldStopScanning) {
        dispatch_group_leave(self.scanningGroup);
        return;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
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
                [self scanSubDirectoryAtPath:itemPath progress:progressBlock];
            } else {
                // Check file size
                [self checkFileSizeAtPath:itemPath];
                
                // Update progress
                self.totalScannedFiles++;
                if (self.totalFilesToScan > 0) {
                    double progress = (double)self.totalScannedFiles / (double)self.totalFilesToScan;
                    dispatch_async(dispatch_get_main_queue(), ^{ 
                        progressBlock(progress);
                    });
                }
            }
        }
    }
    
    dispatch_group_leave(self.scanningGroup);
}

- (void)scanSubDirectoryAtPath:(NSString *)path progress:(void (^)(double))progressBlock {
    dispatch_group_enter(self.scanningGroup);
    [self scanDirectoryAtPath:path progress:progressBlock];
}

- (void)checkFileSizeAtPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:path error:&error];
    
    if (error) return;
    
    unsigned long long fileSize = [fileAttributes fileSize];
    if (fileSize >= self.minimumFileSize) {
        LMBigFileItem *bigFileItem = [[LMBigFileItem alloc] initWithPath:path size:fileSize];
        @synchronized(self.foundBigFiles) {
            [self.foundBigFiles addObject:bigFileItem];
        }
    }
}

- (BOOL)shouldExcludePath:(NSString *)path {
    for (NSString *excludedPath in self.excludedPaths) {
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

- (void)deleteFiles:(NSArray<LMBigFileItem *> *)files 
         completion:(void (^)(BOOL success, NSArray<NSString *> *deletedFiles, NSError * _Nullable error))completionBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ 
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSMutableArray<NSString *> *deletedFiles = [NSMutableArray array];
        NSError *deleteError = nil;
        
        for (LMBigFileItem *fileItem in files) {
            // Safety check: ensure file exists and is not in excluded path
            if ([fileManager fileExistsAtPath:fileItem.filePath] && ![self shouldExcludePath:fileItem.filePath]) {
                BOOL deleted = [fileManager removeItemAtPath:fileItem.filePath error:&deleteError];
                if (deleted) {
                    [deletedFiles addObject:fileItem.filePath];
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{ 
            completionBlock(deletedFiles.count > 0, deletedFiles, deleteError);
        });
    });
}

- (NSDictionary *)getFileInfoForPreview:(LMBigFileItem *)fileItem {
    NSMutableDictionary *fileInfo = [NSMutableDictionary dictionary];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:fileItem.filePath error:&error];
    
    if (fileAttributes) {
        fileInfo[@"name"] = fileItem.fileName;
        fileInfo[@"path"] = fileItem.filePath;
        fileInfo[@"size"] = @(fileItem.fileSize);
        fileInfo[@"formattedSize"] = [fileItem formattedFileSize];
        fileInfo[@"modificationDate"] = fileItem.modificationDate;
        fileInfo[@"creationDate"] = fileAttributes[NSFileCreationDate];
        fileInfo[@"fileType"] = fileAttributes[NSFileType];
        
        // Get file extension
        NSString *extension = [fileItem.fileName pathExtension];
        if (extension.length > 0) {
            fileInfo[@"extension"] = extension;
        }
        
        // MIME type detection removed due to framework dependency
        fileInfo[@"mimeType"] = @"N/A";
    }
    
    return fileInfo;
}

@end
