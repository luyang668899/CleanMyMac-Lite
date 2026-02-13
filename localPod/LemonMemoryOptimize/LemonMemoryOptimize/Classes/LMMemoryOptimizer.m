//
//  LMMemoryOptimizer.m
//  LemonMemoryOptimize
//
//  Created by Tencent on 2026/02/13.
//  Copyright © 2026 Tencent. All rights reserved.
//

#import "LMMemoryOptimizer.h"
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <AppKit/AppKit.h>
#import "QMPurgeRAM.h"
#import "McProcessInfo.h"

@interface LMMemoryOptimizer ()

@property (nonatomic, assign) uint64_t totalMemory;
@property (nonatomic, assign) uint64_t usedMemory;
@property (nonatomic, assign) double memoryUsageRate;
@property (nonatomic, assign) double memoryThreshold;
@property (nonatomic, strong) NSTimer *monitorTimer;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, LMMemoryAppInfo *> *appMemoryInfoMap;
@property (nonatomic, strong) dispatch_queue_t memoryQueue;

@end

@implementation LMMemoryOptimizer

+ (instancetype)sharedInstance {
    static LMMemoryOptimizer *instance = nil;
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
    self.memoryThreshold = 0.8; // 默认80%阈值
    self.appMemoryInfoMap = [NSMutableDictionary dictionary];
    self.memoryQueue = dispatch_queue_create("com.tencent.lemon.memory.optimizer", DISPATCH_QUEUE_SERIAL);
    [self calculateTotalMemory];
}

- (void)calculateTotalMemory {
    uint64_t totalmem = 0;
    size_t size = sizeof(totalmem);
    int mib[] = {CTL_HW, HW_MEMSIZE};
    if (sysctl(mib, 2, &totalmem, &size, NULL, 0) == 0) {
        self.totalMemory = totalmem;
    }
}

- (void)updateMemoryStatus {
    dispatch_async(self.memoryQueue, ^{        kern_return_t kr;
        vm_size_t pagesize;
        vm_statistics64_data_t vm_stat;
        mach_msg_type_number_t count = sizeof(vm_stat) / sizeof(natural_t);

        // 获取页大小
        kr = host_page_size(mach_host_self(), &pagesize);
        if (kr != KERN_SUCCESS) {
            return;
        }

        // 获取内存状态
        kr = host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info_t)&vm_stat, &count);
        if (kr != KERN_SUCCESS) {
            return;
        }

        uint64_t freeMemory = vm_stat.free_count * pagesize;
        uint64_t inactiveMemory = vm_stat.inactive_count * pagesize;
        uint64_t activeMemory = vm_stat.active_count * pagesize;
        uint64_t wiredMemory = vm_stat.wire_count * pagesize;

        self.usedMemory = activeMemory + wiredMemory;
        self.memoryUsageRate = (double)self.usedMemory / self.totalMemory;

        // 更新应用内存信息
        [self updateAppMemoryInfo];

        // 当内存使用率超过阈值时，自动优化
        if (self.memoryUsageRate > self.memoryThreshold) {
            [self optimizeMemory];
        }
    });
}

- (void)updateAppMemoryInfo {
    // 获取所有进程信息
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t len = 0;

    if (sysctl(mib, 4, NULL, &len, NULL, 0) != 0) {
        return;
    }

    struct kinfo_proc *procs = malloc(len);
    if (!procs) {
        return;
    }

    if (sysctl(mib, 4, procs, &len, NULL, 0) != 0) {
        free(procs);
        return;
    }

    int count = len / sizeof(struct kinfo_proc);
    NSMutableDictionary<NSNumber *, LMMemoryAppInfo *> *newAppInfoMap = [NSMutableDictionary dictionary];

    for (int i = 0; i < count; i++) {
        struct kinfo_proc proc = procs[i];
        pid_t pid = proc.kp_proc.p_pid;
        if (pid <= 0) continue;

        // 获取应用信息
        NSRunningApplication *runningApp = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
        if (runningApp && runningApp.activationPolicy == NSApplicationActivationPolicyRegular) {
            // 获取内存使用情况
            struct task_basic_info info;
            mach_msg_type_number_t infoCount = TASK_BASIC_INFO_COUNT;
            kern_return_t kr = task_info(proc.kp_proc.p_pid, TASK_BASIC_INFO, (task_info_t)&info, &infoCount);
            if (kr == KERN_SUCCESS) {
                LMMemoryAppInfo *appInfo = [[LMMemoryAppInfo alloc] init];
                appInfo.appName = runningApp.localizedName ?: @"Unknown";
                appInfo.appIcon = runningApp.icon;
                appInfo.pid = pid;
                appInfo.memoryUsage = info.resident_size;
                appInfo.isActive = (runningApp.isActive != NO);
                appInfo.lastActiveTime = runningApp.isActive ? [NSDate timeIntervalSinceReferenceDate] : [[self.appMemoryInfoMap objectForKey:@(pid)] lastActiveTime];

                [newAppInfoMap setObject:appInfo forKey:@(pid)];
            }
        }
    }

    free(procs);
    self.appMemoryInfoMap = newAppInfoMap;
}

- (void)startMonitoring {
    [self stopMonitoring]; // 先停止之前的监控
    
    self.monitorTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                         target:self
                                                       selector:@selector(updateMemoryStatus)
                                                       userInfo:nil
                                                        repeats:YES];
    
    // 立即更新一次内存状态
    [self updateMemoryStatus];
}

- (void)stopMonitoring {
    if (self.monitorTimer) {
        [self.monitorTimer invalidate];
        self.monitorTimer = nil;
    }
}

- (uint64_t)optimizeMemory {
    // 记录优化前的内存使用情况
    uint64_t beforeUsedMemory = self.usedMemory;

    // 1. 先使用系统自带的内存释放
    [QMPurgeRAM purge];

    // 2. 智能释放策略：针对非活跃应用
    [self releaseInactiveAppMemory];

    // 3. 再次更新内存状态
    [self updateMemoryStatus];

    // 返回释放的内存大小
    return beforeUsedMemory > self.usedMemory ? (beforeUsedMemory - self.usedMemory) : 0;
}

- (void)releaseInactiveAppMemory {
    // 按最后活跃时间排序，优先释放长时间不活跃的应用内存
    NSArray<LMMemoryAppInfo *> *sortedApps = [[self.appMemoryInfoMap allValues] sortedArrayUsingComparator:^NSComparisonResult(LMMemoryAppInfo *obj1, LMMemoryAppInfo *obj2) {
        return [@(obj1.lastActiveTime) compare:@(obj2.lastActiveTime)];
    }];

    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval inactiveThreshold = 300; // 5分钟不活跃阈值

    for (LMMemoryAppInfo *appInfo in sortedApps) {
        if (!appInfo.isActive && (currentTime - appInfo.lastActiveTime) > inactiveThreshold) {
            // 对于长时间不活跃的应用，可以尝试通过发送低内存通知来让它们释放内存
            [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidReceiveMemoryWarningNotification object:nil];
            // 注意：这里只是发送通知，具体应用是否响应取决于应用本身
        }
    }
}

- (NSArray<LMMemoryAppInfo *> *)getMemoryUsageDetails {
    NSArray<LMMemoryAppInfo *> *allApps = [self.appMemoryInfoMap allValues];
    // 按内存使用量排序
    return [allApps sortedArrayUsingComparator:^NSComparisonResult(LMMemoryAppInfo *obj1, LMMemoryAppInfo *obj2) {
        return [@(obj2.memoryUsage) compare:@(obj1.memoryUsage)];
    }];
}

- (void)setMemoryThreshold:(double)threshold {
    if (threshold > 0 && threshold < 1) {
        self.memoryThreshold = threshold;
    }
}

- (NSString *)getMemoryUsageSuggestion {
    if (self.memoryUsageRate < 0.5) {
        return @"内存使用正常，无需优化";
    } else if (self.memoryUsageRate < 0.8) {
        return @"内存使用适中，可以考虑优化以获得更好性能";
    } else if (self.memoryUsageRate < 0.9) {
        return @"内存使用较高，建议进行内存优化";
    } else {
        return @"内存使用紧张，急需进行内存优化";
    }
}

@end

@implementation LMMemoryAppInfo

@end
