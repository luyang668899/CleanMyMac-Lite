//
//  LMDuplicateFileCleaner.m
//  LemonDuplicateFileCleaner
//
//  Created by Trae AI on 2024/10/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import "LMDuplicateFileCleaner.h"
#import <CommonCrypto/CommonCrypto.h>

@implementation LMDuplicateFileItem

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

- (BOOL)calculateFileHashWithError:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:self.filePath]) {
        if (error) {
            *error = [NSError errorWithDomain:@"LMDuplicateFileCleaner" code:200 userInfo:@{NSLocalizedDescriptionKey: @"File does not exist"}];
        }
        return NO;
    }
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:self.filePath];
    if (!fileHandle) {
        if (error) {
            *error = [NSError errorWithDomain:@"LMDuplicateFileCleaner" code:201 userInfo:@{NSLocalizedDescriptionKey: @"Failed to open file"}];
        }
        return NO;
    }
    
    CC_SHA256_CTX sha256Context;
    CC_SHA256_Init(&sha256Context);
    
    const NSUInteger bufferSize = 1024 * 1024; // 1MB buffer
    void *buffer = malloc(bufferSize);
    if (!buffer) {
        [fileHandle closeFile];
        if (error) {
            *error = [NSError errorWithDomain:@"LMDuplicateFileCleaner" code:202 userInfo:@{NSLocalizedDescriptionKey: @"Failed to allocate memory"}];
        }
        return NO;
    }
    
    @try {
        while (YES) {
            NSData *data = [fileHandle readDataOfLength:bufferSize];
            if (data.length == 0) {
                break;
            }
            CC_SHA256_Update(&sha256Context, data.bytes, (CC_LONG)data.length);
        }
        
        unsigned char hash[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256_Final(hash, &sha256Context);
        
        NSMutableString *hashString = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
        for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
            [hashString appendFormat:@"%02x", hash[i]];
        }
        
        self.fileHash = hashString;
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"LMDuplicateFileCleaner" code:203 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Exception during hash calculation: %@", exception.reason]}];
        }
        return NO;
    } @finally {
        [fileHandle closeFile];
        free(buffer);
    }
}

@end

@implementation LMDuplicateFileGroup

- (instancetype)init {
    if (self = [super init]) {
        _files = [NSMutableArray array];
        _totalSize = 0;
    }
    return self;
}

- (void)addFile:(LMDuplicateFileItem *)file {
    [_files addObject:file];
    _totalSize += file.fileSize;
    
    // Set file extension if not set
    if (!_fileExtension && file.fileName) {
        NSString *extension = [file.fileName pathExtension];
        if (extension.length > 0) {
            _fileExtension = extension;
        }
    }
}

- (NSString *)formattedTotalSize {
    if (_totalSize < 1024) {
        return [NSString stringWithFormat:@"%.2f B", (double)_totalSize];
    } else if (_totalSize < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f KB", (double)_totalSize / 1024.0];
    } else if (_totalSize < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f MB", (double)_totalSize / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.2f GB", (double)_totalSize / (1024.0 * 1024.0 * 1024.0)];
    }
}

- (NSUInteger)fileCount {
    return _files.count;
}

@end

@interface LMDuplicateFileCleaner ()

@property (nonatomic, strong) dispatch_queue_t scanningQueue;
@property (nonatomic, strong) dispatch_group_t scanningGroup;
@property (nonatomic, assign) BOOL shouldStopScanning;
@property (nonatomic, strong) NSMutableArray<LMDuplicateFileItem *> *foundFiles;
@property (nonatomic, assign) unsigned long long totalScannedFiles;
@property (nonatomic, assign) unsigned long long totalFilesToScan;

@end

@implementation LMDuplicateFileCleaner

+ (instancetype)sharedInstance {
    static LMDuplicateFileCleaner *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{  
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _minimumFileSize = 1 * 1024 * 1024; // Default: 1MB
        _excludedPaths = [NSMutableArray array];
        _scanningQueue = dispatch_queue_create("com.lemon.duplicate.scanning", DISPATCH_QUEUE_CONCURRENT);
        _scanningGroup = dispatch_group_create();
        _foundFiles = [NSMutableArray array];
        
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
                completion:(void (^)(NSArray<LMDuplicateFileGroup *> *duplicateGroups, NSError * _Nullable error))completionBlock {
    if (self.isScanning) {
        NSError *error = [NSError errorWithDomain:@"LMDuplicateFileCleaner" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Scanning is already in progress"}];
        completionBlock(@[], error);
        return;
    }
    
    self.scanning = YES;
    self.shouldStopScanning = NO;
    [self.foundFiles removeAllObjects];
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
            if (self.shouldStopScanning) {
                self.scanning = NO;
                completionBlock(@[], [NSError errorWithDomain:@"LMDuplicateFileCleaner" code:101 userInfo:@{NSLocalizedDescriptionKey: @"Scanning was cancelled"}]);
                return;
            }
            
            // Calculate file hashes for found files
            NSLog(@"Calculating hashes for %lu files...", (unsigned long)self.foundFiles.count);
            
            dispatch_async(self.scanningQueue, ^{ 
                // Process files in batches to avoid memory issues
                NSUInteger batchSize = 100;
                NSUInteger totalFiles = self.foundFiles.count;
                
                for (NSUInteger i = 0; i < totalFiles; i += batchSize) {
                    if (self.shouldStopScanning) break;
                    
                    NSUInteger endIndex = MIN(i + batchSize, totalFiles);
                    NSArray<LMDuplicateFileItem *> *batchFiles = [self.foundFiles subarrayWithRange:NSMakeRange(i, endIndex - i)];
                    
                    for (LMDuplicateFileItem *fileItem in batchFiles) {
                        if (self.shouldStopScanning) break;
                        NSError *error = nil;
                        [fileItem calculateFileHashWithError:&error];
                        if (error) {
                            NSLog(@"Error calculating hash for %@: %@", fileItem.filePath, error.localizedDescription);
                        }
                    }
                }
                
                if (self.shouldStopScanning) {
                    dispatch_async(dispatch_get_main_queue(), ^{ 
                        self.scanning = NO;
                        completionBlock(@[], [NSError errorWithDomain:@"LMDuplicateFileCleaner" code:101 userInfo:@{NSLocalizedDescriptionKey: @"Scanning was cancelled"}]);
                    });
                    return;
                }
                
                // Group duplicate files
                NSArray<LMDuplicateFileGroup *> *duplicateGroups = [self groupFilesByHash:self.foundFiles];
                
                // Sort groups by size
                NSArray<LMDuplicateFileGroup *> *sortedGroups = [self sortGroupsBySize:duplicateGroups];
                
                dispatch_async(dispatch_get_main_queue(), ^{ 
                    self.scanning = NO;
                    completionBlock(sortedGroups, nil);
                });
            });
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
        LMDuplicateFileItem *fileItem = [[LMDuplicateFileItem alloc] initWithPath:path size:fileSize];
        @synchronized(self.foundFiles) {
            [self.foundFiles addObject:fileItem];
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

- (void)deleteFiles:(NSArray<LMDuplicateFileItem *> *)files 
         completion:(void (^)(BOOL success, NSArray<NSString *> *deletedFiles, NSError * _Nullable error))completionBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ 
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSMutableArray<NSString *> *deletedFiles = [NSMutableArray array];
        NSError *deleteError = nil;
        
        for (LMDuplicateFileItem *fileItem in files) {
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

- (NSDictionary *)getFileInfoForPreview:(LMDuplicateFileItem *)fileItem {
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
        fileInfo[@"fileHash"] = fileItem.fileHash ?: @"N/A";
        
        // Get file extension
        NSString *extension = [fileItem.fileName pathExtension];
        if (extension.length > 0) {
            fileInfo[@"extension"] = extension;
        }
        
        fileInfo[@"mimeType"] = @"N/A";
    }
    
    return fileInfo;
}

- (NSArray<LMDuplicateFileGroup *> *)groupFilesByHash:(NSArray<LMDuplicateFileItem *> *)files {
    NSMutableDictionary<NSString *, LMDuplicateFileGroup *> *hashToGroupMap = [NSMutableDictionary dictionary];
    
    for (LMDuplicateFileItem *fileItem in files) {
        if (fileItem.fileHash) {
            LMDuplicateFileGroup *group = hashToGroupMap[fileItem.fileHash];
            if (!group) {
                group = [[LMDuplicateFileGroup alloc] init];
                hashToGroupMap[fileItem.fileHash] = group;
            }
            [group addFile:fileItem];
        }
    }
    
    // Filter groups with only one file (not duplicates)
    NSMutableArray<LMDuplicateFileGroup *> *duplicateGroups = [NSMutableArray array];
    for (LMDuplicateFileGroup *group in hashToGroupMap.allValues) {
        if (group.fileCount > 1) {
            [duplicateGroups addObject:group];
        }
    }
    
    return duplicateGroups;
}

- (NSArray<LMDuplicateFileGroup *> *)sortGroupsBySize:(NSArray<LMDuplicateFileGroup *> *)groups {
    return [groups sortedArrayUsingComparator:^NSComparisonResult(LMDuplicateFileGroup *obj1, LMDuplicateFileGroup *obj2) {
        return obj2.totalSize < obj1.totalSize;
    }];
}

@end
