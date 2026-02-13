//
//  LMDisk3DAnalyzer.h
//  LemonDisk3DAnalyzer
//
//  Created by Tencent on 2026/02/13.
//  Copyright © 2026 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LMDiskItemInfo : NSObject

@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) uint64_t size;
@property (nonatomic, assign) BOOL isDirectory;
@property (nonatomic, strong) NSArray<LMDiskItemInfo *> *children;
@property (nonatomic, assign) CGFloat normalizedSize;

@end

@interface LMDisk3DAnalyzer : NSObject

@property (nonatomic, strong, readonly) SCNView *sceneView;

+ (instancetype)sharedInstance;

// 开始分析磁盘空间
- (void)startAnalyzingDisk:(NSString *)diskPath completion:(void (^)(BOOL success))completion;

// 生成3D可视化
- (void)generate3DVisualization;

// 放大到指定项目
- (void)zoomToItem:(LMDiskItemInfo *)item;

// 重置视图
- (void)resetView;

// 获取磁盘使用统计
- (NSDictionary *)getDiskUsageStatistics;

// 导出3D可视化结果
- (NSImage *)exportVisualizationAsImage;

@end

NS_ASSUME_NONNULL_END
