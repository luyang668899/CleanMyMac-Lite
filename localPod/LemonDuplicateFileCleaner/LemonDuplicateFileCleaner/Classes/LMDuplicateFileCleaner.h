//
//  LMDuplicateFileCleaner.h
//  LemonDuplicateFileCleaner
//
//  Created by Trae AI on 2024/10/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LMDuplicateFileItem : NSObject

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, assign) unsigned long long fileSize;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, strong) NSDate *modificationDate;
@property (nonatomic, copy, nullable) NSString *fileHash;

- (instancetype)initWithPath:(NSString *)path size:(unsigned long long)size;
- (NSString *)formattedFileSize;
- (BOOL)calculateFileHashWithError:(NSError **)error;

@end

@interface LMDuplicateFileGroup : NSObject

@property (nonatomic, strong) NSMutableArray<LMDuplicateFileItem *> *files;
@property (nonatomic, assign) unsigned long long totalSize;
@property (nonatomic, copy, nullable) NSString *fileExtension;

- (instancetype)init;
- (void)addFile:(LMDuplicateFileItem *)file;
- (NSString *)formattedTotalSize;
- (NSUInteger)fileCount;

@end

@interface LMDuplicateFileCleaner : NSObject

@property (nonatomic, assign) unsigned long long minimumFileSize; // Minimum file size in bytes (default: 1MB)
@property (nonatomic, strong, nullable) NSMutableArray<NSString *> *excludedPaths;
@property (nonatomic, assign, getter=isScanning) BOOL scanning;

+ (instancetype)sharedInstance;

/**
 * Start scanning for duplicate files
 * @param paths Directories to scan
 * @param progressBlock Progress callback
 * @param completionBlock Completion callback with found duplicate files grouped
 */
- (void)startScanningPaths:(NSArray<NSString *> *)paths 
                  progress:(void (^)(double progress))progressBlock 
                completion:(void (^)(NSArray<LMDuplicateFileGroup *> *duplicateGroups, NSError * _Nullable error))completionBlock;

/**
 * Stop current scanning process
 */
- (void)stopScanning;

/**
 * Delete selected duplicate files
 * @param files Array of LMDuplicateFileItem to delete
 * @param completionBlock Completion callback with deletion result
 */
- (void)deleteFiles:(NSArray<LMDuplicateFileItem *> *)files 
         completion:(void (^)(BOOL success, NSArray<NSString *> *deletedFiles, NSError * _Nullable error))completionBlock;

/**
 * Get file information for preview
 * @param fileItem LMDuplicateFileItem to preview
 * @return Dictionary with file information
 */
- (NSDictionary *)getFileInfoForPreview:(LMDuplicateFileItem *)fileItem;

/**
 * Group duplicate files by hash
 * @param files Array of LMDuplicateFileItem
 * @return Array of LMDuplicateFileGroup
 */
- (NSArray<LMDuplicateFileGroup *> *)groupFilesByHash:(NSArray<LMDuplicateFileItem *> *)files;

/**
 * Sort duplicate groups by size (descending)
 * @param groups Array of LMDuplicateFileGroup
 * @return Sorted array of LMDuplicateFileGroup
 */
- (NSArray<LMDuplicateFileGroup *> *)sortGroupsBySize:(NSArray<LMDuplicateFileGroup *> *)groups;

@end

NS_ASSUME_NONNULL_END
