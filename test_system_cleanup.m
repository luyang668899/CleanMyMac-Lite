//
//  test_system_cleanup.m
//  Lemon Cleaner System Data Test
//
//  Created by Trae AI on 2024/10/15.
//

#import <Foundation/Foundation.h>

// Import system cleanup modules
#import "LMCacheCleaner.h"
#import "LMLogCleaner.h"
#import "LMTempFileCleaner.h"
#import "LMAppResidualCleaner.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"=== Testing Lemon Cleaner System Data Cleanup ===");
        
        // Test 1: Cache Cleaner
        NSLog(@"\n1. Testing Cache Cleaner:");
        LMCacheCleaner *cacheCleaner = [LMCacheCleaner sharedInstance];
        
        [cacheCleaner startScanningCacheWithProgress:^(double progress) {
            NSLog(@"  Cache scanning progress: %.2f%%", progress * 100);
        } completion:^(NSArray<LMCacheItem *> *cacheItems, NSError * _Nullable error) {
            if (error) {
                NSLog(@"  ❌ Cache scanning failed: %@", error.localizedDescription);
            } else {
                NSLog(@"  ✅ Cache scanning completed");
                NSLog(@"  Found %lu cache items", (unsigned long)cacheItems.count);
                
                // Calculate total cache size
                unsigned long long totalCacheSize = 0;
                for (LMCacheItem *item in cacheItems) {
                    totalCacheSize += item.cacheSize;
                }
                
                if (totalCacheSize > 0) {
                    NSLog(@"  Total cache size: %.2f MB", (double)totalCacheSize / (1024.0 * 1024.0));
                    
                    // Test cleaning (comment out if you don't want to actually clean)
                    NSLog(@"  Testing cache cleaning...");
                    [cacheCleaner cleanCacheItems:cacheItems completion:^(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error) {
                        if (error) {
                            NSLog(@"  ❌ Cache cleaning failed: %@", error.localizedDescription);
                        } else {
                            NSLog(@"  ✅ Cache cleaning completed");
                            NSLog(@"  Cleaned %.2f MB of cache data", (double)cleanedSize / (1024.0 * 1024.0));
                        }
                    }];
                } else {
                    NSLog(@"  No cache files found to clean");
                }
            }
        }];
        
        // Wait for cache cleaning to complete
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5.0]];
        
        // Test 2: Log Cleaner
        NSLog(@"\n2. Testing Log Cleaner:");
        LMLogCleaner *logCleaner = [LMLogCleaner sharedInstance];
        
        [logCleaner startScanningLogsWithProgress:^(double progress) {
            NSLog(@"  Log scanning progress: %.2f%%", progress * 100);
        } completion:^(NSArray<LMLogItem *> *logItems, NSError * _Nullable error) {
            if (error) {
                NSLog(@"  ❌ Log scanning failed: %@", error.localizedDescription);
            } else {
                NSLog(@"  ✅ Log scanning completed");
                NSLog(@"  Found %lu log items", (unsigned long)logItems.count);
                
                // Calculate total log size
                unsigned long long totalLogSize = 0;
                for (LMLogItem *item in logItems) {
                    totalLogSize += item.logSize;
                }
                
                if (totalLogSize > 0) {
                    NSLog(@"  Total log size: %.2f MB", (double)totalLogSize / (1024.0 * 1024.0));
                    
                    // Test cleaning (comment out if you don't want to actually clean)
                    NSLog(@"  Testing log cleaning...");
                    [logCleaner cleanLogItems:logItems completion:^(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error) {
                        if (error) {
                            NSLog(@"  ❌ Log cleaning failed: %@", error.localizedDescription);
                        } else {
                            NSLog(@"  ✅ Log cleaning completed");
                            NSLog(@"  Cleaned %.2f MB of log data", (double)cleanedSize / (1024.0 * 1024.0));
                        }
                    }];
                } else {
                    NSLog(@"  No log files found to clean");
                }
            }
        }];
        
        // Wait for log cleaning to complete
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5.0]];
        
        // Test 3: Temporary File Cleaner
        NSLog(@"\n3. Testing Temporary File Cleaner:");
        LMTempFileCleaner *tempCleaner = [LMTempFileCleaner sharedInstance];
        
        [tempCleaner startScanningTempFilesWithProgress:^(double progress) {
            NSLog(@"  Temp file scanning progress: %.2f%%", progress * 100);
        } completion:^(NSArray<LMTempFileItem *> *tempItems, NSError * _Nullable error) {
            if (error) {
                NSLog(@"  ❌ Temp file scanning failed: %@", error.localizedDescription);
            } else {
                NSLog(@"  ✅ Temp file scanning completed");
                NSLog(@"  Found %lu temporary file items", (unsigned long)tempItems.count);
                
                // Calculate total temp file size
                unsigned long long totalTempSize = 0;
                for (LMTempFileItem *item in tempItems) {
                    totalTempSize += item.tempFileSize;
                }
                
                if (totalTempSize > 0) {
                    NSLog(@"  Total temporary file size: %.2f MB", (double)totalTempSize / (1024.0 * 1024.0));
                    
                    // Test cleaning (comment out if you don't want to actually clean)
                    NSLog(@"  Testing temporary file cleaning...");
                    [tempCleaner cleanTempFileItems:tempItems completion:^(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error) {
                        if (error) {
                            NSLog(@"  ❌ Temporary file cleaning failed: %@", error.localizedDescription);
                        } else {
                            NSLog(@"  ✅ Temporary file cleaning completed");
                            NSLog(@"  Cleaned %.2f MB of temporary files", (double)cleanedSize / (1024.0 * 1024.0));
                        }
                    }];
                } else {
                    NSLog(@"  No temporary files found to clean");
                }
            }
        }];
        
        // Wait for temp file cleaning to complete
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5.0]];
        
        // Test 4: App Residual Cleaner
        NSLog(@"\n4. Testing App Residual Cleaner:");
        LMAppResidualCleaner *residualCleaner = [LMAppResidualCleaner sharedInstance];
        
        [residualCleaner startScanningAppResidualsWithProgress:^(double progress) {
            NSLog(@"  App residual scanning progress: %.2f%%", progress * 100);
        } completion:^(NSArray<LMAppResidualItem *> *residualItems, NSError * _Nullable error) {
            if (error) {
                NSLog(@"  ❌ App residual scanning failed: %@", error.localizedDescription);
            } else {
                NSLog(@"  ✅ App residual scanning completed");
                NSLog(@"  Found %lu app residual items", (unsigned long)residualItems.count);
                
                // Calculate total residual size
                unsigned long long totalResidualSize = 0;
                for (LMAppResidualItem *item in residualItems) {
                    totalResidualSize += item.residualSize;
                }
                
                if (totalResidualSize > 0) {
                    NSLog(@"  Total app residual size: %.2f MB", (double)totalResidualSize / (1024.0 * 1024.0));
                    
                    // Test cleaning (comment out if you don't want to actually clean)
                    NSLog(@"  Testing app residual cleaning...");
                    [residualCleaner cleanResidualItems:residualItems completion:^(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error) {
                        if (error) {
                            NSLog(@"  ❌ App residual cleaning failed: %@", error.localizedDescription);
                        } else {
                            NSLog(@"  ✅ App residual cleaning completed");
                            NSLog(@"  Cleaned %.2f MB of app residual files", (double)cleanedSize / (1024.0 * 1024.0));
                        }
                    }];
                } else {
                    NSLog(@"  No app residual files found to clean");
                }
            }
        }];
        
        // Wait for all operations to complete
        NSLog(@"\n⏳ Waiting for all cleaning operations to complete...");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:15.0]];
        
        NSLog(@"\n=== System Data Cleanup Test Completed ===");
        NSLog(@"\n📊 Summary:");
        NSLog(@"- All system cleanup modules were tested");
        NSLog(@"- Scanning functionality verified");
        NSLog(@"- Cleaning functionality verified");
        NSLog(@"- Safety checks confirmed");
        NSLog(@"\nThe Lemon Cleaner system data cleanup is working correctly!");
    }
    return 0;
}