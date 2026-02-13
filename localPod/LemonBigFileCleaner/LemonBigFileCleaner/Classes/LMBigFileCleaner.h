//
//  LMBigFileCleaner.h
//  LemonBigFileCleaner
//
//  Created by Trae AI on 2024/10/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LMBigFileItem : NSObject

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, assign) unsigned long long fileSize;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, strong) NSDate *modificationDate;

- (instancetype)initWithPath:(NSString *)path size:(unsigned long long)size;
- (NSString *)formattedFileSize;

@end

@interface LMBigFileCleaner : NSObject

@property (nonatomic, assign) unsigned long long minimumFileSize; // Minimum file size in bytes (default: 100MB)
@property (nonatomic, strong, nullable) NSMutableArray<NSString *> *excludedPaths;
@property (nonatomic, assign, getter=isScanning) BOOL scanning;

+ (instancetype)sharedInstance;

/**
 * Start scanning for big files
 * @param paths Directories to scan
 * @param progressBlock Progress callback
 * @param completionBlock Completion callback with found big files
 */
- (void)startScanningPaths:(NSArray<NSString *> *)paths 
                  progress:(void (^)(double progress))progressBlock 
                completion:(void (^)(NSArray<LMBigFileItem *> *bigFiles, NSError * _Nullable error))completionBlock;

/**
 * Stop current scanning process
 */
- (void)stopScanning;

/**
 * Delete selected big files
 * @param files Array of LMBigFileItem to delete
 * @param completionBlock Completion callback with deletion result
 */
- (void)deleteFiles:(NSArray<LMBigFileItem *> *)files 
         completion:(void (^)(BOOL success, NSArray<NSString *> *deletedFiles, NSError * _Nullable error))completionBlock;

/**
 * Get file information for preview
 * @param fileItem LMBigFileItem to preview
 * @return Dictionary with file information
 */
- (NSDictionary *)getFileInfoForPreview:(LMBigFileItem *)fileItem;

@end

NS_ASSUME_NONNULL_END
