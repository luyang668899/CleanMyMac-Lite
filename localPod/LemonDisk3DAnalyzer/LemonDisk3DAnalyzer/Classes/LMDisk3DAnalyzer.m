//
//  LMDisk3DAnalyzer.m
//  LemonDisk3DAnalyzer
//
//  Created by Tencent on 2026/02/13.
//  Copyright © 2026 Tencent. All rights reserved.
//

#import "LMDisk3DAnalyzer.h"

@interface LMDisk3DAnalyzer ()

@property (nonatomic, strong) SCNView *sceneView;
@property (nonatomic, strong) SCNScene *scene;
@property (nonatomic, strong) SCNCamera *camera;
@property (nonatomic, strong) SCNNode *cameraNode;
@property (nonatomic, strong) SCNNode *rootNode;
@property (nonatomic, strong) LMDiskItemInfo *diskRoot;
@property (nonatomic, assign) uint64_t totalDiskSize;
@property (nonatomic, strong) dispatch_queue_t analysisQueue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, LMDiskItemInfo *> *itemCache;

@end

@implementation LMDisk3DAnalyzer

+ (instancetype)sharedInstance {
    static LMDisk3DAnalyzer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{        instance = [[self alloc] init];    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        [self initialize];    }
    return self;
}

- (void)initialize {
    self.analysisQueue = dispatch_queue_create("com.tencent.lemon.disk.analyzer", DISPATCH_QUEUE_SERIAL);
    self.itemCache = [NSMutableDictionary dictionary];
    [self setupScene];
}

- (void)setupScene {
    // 创建场景
    self.scene = [SCNScene scene];
    
    // 创建视图
    self.sceneView = [[SCNView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    self.sceneView.scene = self.scene;
    self.sceneView.backgroundColor = [NSColor colorWithCalibratedRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    self.sceneView.allowsCameraControl = YES;
    self.sceneView.autoenablesDefaultLighting = YES;
    
    // 创建相机
    self.camera = [SCNCamera camera];
    self.cameraNode = [SCNNode node];
    self.cameraNode.camera = self.camera;
    self.cameraNode.position = SCNVector3Make(0, 0, 10);
    [self.scene.rootNode addChildNode:self.cameraNode];
    
    // 创建根节点
    self.rootNode = [SCNNode node];
    [self.scene.rootNode addChildNode:self.rootNode];
    
    // 添加环境光
    SCNLight *ambientLight = [SCNLight light];
    ambientLight.type = SCNLightTypeAmbient;
    ambientLight.color = [NSColor whiteColor];
    ambientLight.intensity = 0.5;
    SCNNode *ambientLightNode = [SCNNode node];
    ambientLightNode.light = ambientLight;
    [self.scene.rootNode addChildNode:ambientLightNode];
    
    // 添加平行光
    SCNLight *directionalLight = [SCNLight light];
    directionalLight.type = SCNLightTypeDirectional;
    directionalLight.color = [NSColor whiteColor];
    directionalLight.intensity = 1.0;
    SCNNode *directionalLightNode = [SCNNode node];
    directionalLightNode.light = directionalLight;
    directionalLightNode.position = SCNVector3Make(1, 1, 1);
    [self.scene.rootNode addChildNode:directionalLightNode];
}

- (void)startAnalyzingDisk:(NSString *)diskPath completion:(void (^)(BOOL success))completion {
    dispatch_async(self.analysisQueue, ^{        NSError *error = nil;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        // 检查路径是否存在
        if (![fileManager fileExistsAtPath:diskPath isDirectory:nil]) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{                    completion(NO);                });
            }
            return;
        }
        
        // 分析磁盘根目录
        self.diskRoot = [self analyzeDirectory:diskPath error:&error];
        if (error) {
            NSLog(@"Error analyzing disk: %@", error.localizedDescription);
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{                    completion(NO);                });
            }
            return;
        }
        
        // 计算总大小
        self.totalDiskSize = [self calculateTotalSize:self.diskRoot];
        
        // 归一化大小
        [self normalizeSizes:self.diskRoot totalSize:self.totalDiskSize];
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{                completion(YES);            });
        }
    });
}

- (LMDiskItemInfo *)analyzeDirectory:(NSString *)path error:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    LMDiskItemInfo *item = [[LMDiskItemInfo alloc] init];
    item.path = path;
    item.name = [path lastPathComponent];
    item.isDirectory = YES;
    item.children = [NSMutableArray array];
    
    // 获取目录内容
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:error];
    if (*error) {
        return nil;
    }
    
    uint64_t totalSize = 0;
    
    for (NSString *subPath in contents) {
        NSString *fullPath = [path stringByAppendingPathComponent:subPath];
        
        // 跳过隐藏文件
        if ([subPath hasPrefix:@"."]) {
            continue;
        }
        
        // 检查文件类型
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                // 递归分析子目录
                LMDiskItemInfo *childItem = [self analyzeDirectory:fullPath error:error];
                if (childItem) {
                    [item.children addObject:childItem];
                    totalSize += childItem.size;
                }
            } else {
                // 分析文件
                LMDiskItemInfo *childItem = [[LMDiskItemInfo alloc] init];
                childItem.path = fullPath;
                childItem.name = subPath;
                childItem.isDirectory = NO;
                
                // 获取文件大小
                NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:fullPath error:error];
                if (fileAttributes) {
                    childItem.size = [[fileAttributes objectForKey:NSFileSize] unsignedLongLongValue];
                    totalSize += childItem.size;
                    [item.children addObject:childItem];
                }
            }
        }
    }
    
    item.size = totalSize;
    [self.itemCache setObject:item forKey:item.path];
    
    return item;
}

- (uint64_t)calculateTotalSize:(LMDiskItemInfo *)item {
    if (!item.isDirectory) {
        return item.size;
    }
    
    uint64_t totalSize = 0;
    for (LMDiskItemInfo *child in item.children) {
        totalSize += [self calculateTotalSize:child];
    }
    return totalSize;
}

- (void)normalizeSizes:(LMDiskItemInfo *)item totalSize:(uint64_t)totalSize {
    if (totalSize > 0) {
        item.normalizedSize = (CGFloat)item.size / (CGFloat)totalSize;
    }
    
    for (LMDiskItemInfo *child in item.children) {
        [self normalizeSizes:child totalSize:totalSize];
    }
}

- (void)generate3DVisualization {
    dispatch_async(dispatch_get_main_queue(), ^{        // 清除现有内容
        [self.rootNode removeAllChildren];
        
        if (!self.diskRoot) {
            return;
        }
        
        // 生成3D模型
        [self generate3DForItem:self.diskRoot atPosition:SCNVector3Make(0, 0, 0) scale:SCNVector3Make(1, 1, 1)];
        
        // 添加标签
        [self addLabelsForItem:self.diskRoot];
    });
}

- (void)generate3DForItem:(LMDiskItemInfo *)item atPosition:(SCNVector3)position scale:(SCNVector3)scale {
    if (!item.isDirectory || item.children.count == 0) {
        return;
    }
    
    // 按大小排序
    NSArray *sortedChildren = [item.children sortedArrayUsingComparator:^NSComparisonResult(LMDiskItemInfo *obj1, LMDiskItemInfo *obj2) {
        return [@(obj2.size) compare:@(obj1.size)];
    }];
    
    // 限制显示数量
    NSInteger maxItems = MIN(20, sortedChildren.count);
    sortedChildren = [sortedChildren subarrayWithRange:NSMakeRange(0, maxItems)];
    
    // 计算布局
    CGFloat radius = 2.0 * scale.x;
    NSInteger itemCount = sortedChildren.count;
    CGFloat angleStep = 2.0 * M_PI / itemCount;
    
    for (int i = 0; i < itemCount; i++) {
        LMDiskItemInfo *child = sortedChildren[i];
        
        // 计算位置
        CGFloat angle = i * angleStep;
        CGFloat x = position.x + radius * cos(angle);
        CGFloat y = position.y + radius * sin(angle);
        CGFloat z = position.z;
        
        // 计算大小
        CGFloat sizeScale = sqrt(child.normalizedSize) * 2.0;
        SCNVector3 childScale = SCNVector3Make(sizeScale * scale.x, sizeScale * scale.y, sizeScale * scale.z);
        
        // 创建几何体
        SCNGeometry *geometry;
        if (child.isDirectory) {
            // 目录使用立方体
            geometry = [SCNBox boxWithWidth:1 height:1 length:1 chamferRadius:0.1];
        } else {
            // 文件使用球体
            geometry = [SCNSphere sphereWithRadius:0.5];
        }
        
        // 随机颜色
        CGFloat hue = fmod((CGFloat)i / itemCount, 1.0);
        NSColor *color = [NSColor colorWithHue:hue saturation:0.8 brightness:0.8 alpha:0.8];
        SCNMaterial *material = [SCNMaterial material];
        material.diffuse.contents = color;
        material.specular.contents = [NSColor whiteColor];
        geometry.materials = @[material];
        
        // 创建节点
        SCNNode *node = [SCNNode nodeWithGeometry:geometry];
        node.position = SCNVector3Make(x, y, z);
        node.scale = childScale;
        
        // 添加到父节点
        [self.rootNode addChildNode:node];
        
        // 递归生成子项目
        if (child.isDirectory && child.normalizedSize > 0.05) {
            [self generate3DForItem:child atPosition:node.position scale:childScale];
        }
    }
}

- (void)addLabelsForItem:(LMDiskItemInfo *)item {
    if (!item.isDirectory || item.children.count == 0) {
        return;
    }
    
    // 按大小排序
    NSArray *sortedChildren = [item.children sortedArrayUsingComparator:^NSComparisonResult(LMDiskItemInfo *obj1, LMDiskItemInfo *obj2) {
        return [@(obj2.size) compare:@(obj1.size)];
    }];
    
    // 限制显示数量
    NSInteger maxItems = MIN(10, sortedChildren.count);
    sortedChildren = [sortedChildren subarrayWithRange:NSMakeRange(0, maxItems)];
    
    for (LMDiskItemInfo *child in sortedChildren) {
        if (child.normalizedSize > 0.01) {
            // 创建标签
            SCNText *text = [SCNText textWithString:child.name extrusionDepth:0.1];
            text.font = [NSFont systemFontOfSize:12];
            text.flatness = 0.1;
            
            SCNMaterial *textMaterial = [SCNMaterial material];
            textMaterial.diffuse.contents = [NSColor whiteColor];
            text.materials = @[textMaterial];
            
            SCNNode *textNode = [SCNNode nodeWithGeometry:text];
            textNode.scale = SCNVector3Make(0.1, 0.1, 0.1);
            textNode.position = SCNVector3Make(0, -3, 0);
            
            // 添加到场景
            [self.rootNode addChildNode:textNode];
        }
    }
}

- (void)zoomToItem:(LMDiskItemInfo *)item {
    if (!item) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{        // 找到对应的节点
        // 这里简化处理，实际实现需要根据item找到对应的3D节点
        
        // 移动相机位置
        [SCNTransaction begin];
        [SCNTransaction setAnimationDuration:1.0];
        
        // 计算目标位置
        CGFloat distance = 5.0 / sqrt(item.normalizedSize);
        self.cameraNode.position = SCNVector3Make(0, 0, distance);
        
        [SCNTransaction commit];
    });
}

- (void)resetView {
    dispatch_async(dispatch_get_main_queue(), ^{        [SCNTransaction begin];
        [SCNTransaction setAnimationDuration:1.0];
        
        // 重置相机位置
        self.cameraNode.position = SCNVector3Make(0, 0, 10);
        self.cameraNode.rotation = SCNVector4Make(0, 0, 0, 0);
        
        [SCNTransaction commit];
    });
}

- (NSDictionary *)getDiskUsageStatistics {
    NSMutableDictionary *statistics = [NSMutableDictionary dictionary];
    
    if (!self.diskRoot) {
        return statistics;
    }
    
    statistics[@"totalSize"] = @(self.totalDiskSize);
    statistics[@"usedSize"] = @(self.diskRoot.size);
    statistics[@"itemCount"] = @([self countItems:self.diskRoot]);
    statistics[@"directoryCount"] = @([self countDirectories:self.diskRoot]);
    statistics[@"fileCount"] = @([self countFiles:self.diskRoot]);
    
    // 获取最大的文件/目录
    NSArray *sortedItems = [self getAllItemsSortedBySize:self.diskRoot];
    if (sortedItems.count > 0) {
        statistics[@"largestItems"] = [sortedItems subarrayWithRange:NSMakeRange(0, MIN(10, sortedItems.count))];
    }
    
    return statistics;
}

- (NSImage *)exportVisualizationAsImage {
    if (!self.sceneView) {
        return nil;
    }
    
    // 渲染视图到图像
    NSImage *image = [self.sceneView snapshot];
    return image;
}

#pragma mark - Helper Methods

- (NSInteger)countItems:(LMDiskItemInfo *)item {
    if (!item.isDirectory) {
        return 1;
    }
    
    NSInteger count = 0;
    for (LMDiskItemInfo *child in item.children) {
        count += [self countItems:child];
    }
    return count;
}

- (NSInteger)countDirectories:(LMDiskItemInfo *)item {
    if (!item.isDirectory) {
        return 0;
    }
    
    NSInteger count = 1;
    for (LMDiskItemInfo *child in item.children) {
        count += [self countDirectories:child];
    }
    return count;
}

- (NSInteger)countFiles:(LMDiskItemInfo *)item {
    if (!item.isDirectory) {
        return 1;
    }
    
    NSInteger count = 0;
    for (LMDiskItemInfo *child in item.children) {
        count += [self countFiles:child];
    }
    return count;
}

- (NSArray<LMDiskItemInfo *> *)getAllItemsSortedBySize:(LMDiskItemInfo *)item {
    NSMutableArray<LMDiskItemInfo *> *allItems = [NSMutableArray array];
    [self collectAllItems:item intoArray:allItems];
    
    // 按大小排序
    [allItems sortUsingComparator:^NSComparisonResult(LMDiskItemInfo *obj1, LMDiskItemInfo *obj2) {
        return [@(obj2.size) compare:@(obj1.size)];
    }];
    
    return allItems;
}

- (void)collectAllItems:(LMDiskItemInfo *)item intoArray:(NSMutableArray<LMDiskItemInfo *> *)array {
    [array addObject:item];
    
    if (item.isDirectory) {
        for (LMDiskItemInfo *child in item.children) {
            [self collectAllItems:child intoArray:array];
        }
    }
}

@end

@implementation LMDiskItemInfo

@end
