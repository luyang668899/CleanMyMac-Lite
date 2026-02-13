//
//  LMSystemCleaner.h
//  LemonSystemCleaner
//
//  Created by Tencent on 2026/02/13.
//  Copyright © 2026 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LMSystemCleanItem : NSObject

@property (nonatomic, strong) NSString *itemName;
@property (nonatomic, strong) NSString *itemDescription;
@property (nonatomic, strong) NSString *path;
@property (nonatomic, assign) uint64_t size;
@property (nonatomic, assign) BOOL isSafeToClean;
@property (nonatomic, assign) BOOL isSelected;

@end

@interface LMSystemCleaner : NSObject

+ (instancetype)sharedInstance;

// 开始扫描系统数据
- (void)startScanningWithCompletion:(void (^)(NSArray<LMSystemCleanItem *> *items, uint64_t totalSize))completion;

// 清理选中的系统数据
- (void)cleanSelectedItems:(NSArray<LMSystemCleanItem *> *)items completion:(void (^)(BOOL success, uint64_t cleanedSize, NSError * _Nullable error))completion;

// 获取系统数据清理建议
- (NSArray<NSString *> *)getSystemCleanSuggestions;

// 验证清理路径的安全性
- (BOOL)validatePathSafety:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
