//
//  test_cache_cleaner.m
//  Test script for LemonCacheCleaner
//
//  Created by Trae AI on 2024/10/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "localPod/LemonCacheCleaner/LemonCacheCleaner/Classes/LMCacheCleaner.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"=== Testing LemonCacheCleaner ===");
        
        // Get shared instance
        LMCacheCleaner *cleaner = [LMCacheCleaner sharedInstance];
        NSLog(@"✓ Initialized LMCacheCleaner shared instance");
        
        // Test get total cache size
        NSLog(@"\n=== Testing get total cache size ===");
        [cleaner getTotalCacheSizeWithCompletion:^(unsigned long long totalSize, NSError * _Nullable error) {
            if (error) {
                NSLog(@"✗ Failed to get total cache size: %@", error.localizedDescription);
            } else {
                NSLog(@"✓ Total cache size: %.2f MB", totalSize / (1024.0 * 1024.0));
                
                // Test start scanning cache
                NSLog(@"\n=== Testing start scanning cache ===");
                [cleaner startScanningCacheWithProgress:^(double progress) {
                    NSLog(@"Scan progress: %.2f%%", progress * 100);
                } completion:^(NSArray<LMCacheItem *> *cacheItems, NSError * _Nullable error) {
                    if (error) {
                        NSLog(@"✗ Scan failed with error: %@", error.localizedDescription);
                    } else {
                        NSLog(@"✓ Scan completed successfully");
                        NSLog(@"Found %lu cache items:", (unsigned long)cacheItems.count);
                        
                        // Print first few cache items
                        NSUInteger printCount = MIN(5, cacheItems.count);
                        for (int i = 0; i < printCount; i++) {
                            LMCacheItem *item = cacheItems[i];
                            NSLog(@"%d. %@ (%@) - %@", i+1, [item.cachePath lastPathComponent], item.formattedCacheSize, item.cacheType);
                        }
                        
                        if (cacheItems.count > 5) {
                            NSLog(@"... and %lu more cache items", (unsigned long)cacheItems.count - 5);
                        }
                        
                        // Test clean cache items (commented out for safety)
                        /*
                        if (cacheItems.count > 0) {
                            NSLog(@"\n=== Testing clean cache items ===");
                            NSArray *itemsToClean = [cacheItems subarrayWithRange:NSMakeRange(0, MIN(2, cacheItems.count))];
                            [cleaner cleanCacheItems:itemsToClean completion:^(BOOL success, unsigned long long cleanedSize, NSError * _Nullable error) {
                                if (error) {
                                    NSLog(@"✗ Clean failed with error: %@", error.localizedDescription);
                                } else {
                                    NSLog(@"✓ Clean completed successfully");
                                    NSLog(@"Cleaned %.2f MB of cache", cleanedSize / (1024.0 * 1024.0));
                                }
                            }];
                        }
                        */
                        
                        NSLog(@"\n=== Test completed successfully ===");
                    }
                }];
            }
        }];
        
        // Keep the script running to see the results
        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}
