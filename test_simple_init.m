//
//  test_simple_init.m
//  Lemon Cleaner Test
//
//  Created by Trae AI on 2024/10/15.
//

#import <Foundation/Foundation.h>

// Test all cleaner modules
#import "LMDuplicateFileCleaner.h"
#import "LMCacheCleaner.h"
#import "LMLogCleaner.h"
#import "LMTempFileCleaner.h"
#import "LMAppResidualCleaner.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"=== Testing Lemon Cleaner Modules Initialization ===");
        
        // Test Duplicate File Cleaner
        NSLog(@"\n1. Testing LMDuplicateFileCleaner:");
        LMDuplicateFileCleaner *duplicateCleaner = [LMDuplicateFileCleaner sharedInstance];
        if (duplicateCleaner) {
            NSLog(@"✓ Successfully initialized");
            NSLog(@"  Minimum file size: %llu bytes", duplicateCleaner.minimumFileSize);
            NSLog(@"  Excluded paths count: %lu", (unsigned long)duplicateCleaner.excludedPaths.count);
        } else {
            NSLog(@"✗ Failed to initialize");
        }
        
        // Test Cache Cleaner
        NSLog(@"\n2. Testing LMCacheCleaner:");
        LMCacheCleaner *cacheCleaner = [LMCacheCleaner sharedInstance];
        if (cacheCleaner) {
            NSLog(@"✓ Successfully initialized");
            NSLog(@"  Included paths count: %lu", (unsigned long)cacheCleaner.includedCachePaths.count);
            NSLog(@"  Excluded paths count: %lu", (unsigned long)cacheCleaner.excludedCachePaths.count);
        } else {
            NSLog(@"✗ Failed to initialize");
        }
        
        // Test Log Cleaner
        NSLog(@"\n3. Testing LMLogCleaner:");
        LMLogCleaner *logCleaner = [LMLogCleaner sharedInstance];
        if (logCleaner) {
            NSLog(@"✓ Successfully initialized");
            NSLog(@"  Included paths count: %lu", (unsigned long)logCleaner.includedLogPaths.count);
            NSLog(@"  Excluded paths count: %lu", (unsigned long)logCleaner.excludedLogPaths.count);
        } else {
            NSLog(@"✗ Failed to initialize");
        }
        
        // Test Temp File Cleaner
        NSLog(@"\n4. Testing LMTempFileCleaner:");
        LMTempFileCleaner *tempCleaner = [LMTempFileCleaner sharedInstance];
        if (tempCleaner) {
            NSLog(@"✓ Successfully initialized");
            NSLog(@"  Included paths count: %lu", (unsigned long)tempCleaner.includedTempPaths.count);
            NSLog(@"  Excluded paths count: %lu", (unsigned long)tempCleaner.excludedTempPaths.count);
        } else {
            NSLog(@"✗ Failed to initialize");
        }
        
        // Test App Residual Cleaner
        NSLog(@"\n5. Testing LMAppResidualCleaner:");
        LMAppResidualCleaner *residualCleaner = [LMAppResidualCleaner sharedInstance];
        if (residualCleaner) {
            NSLog(@"✓ Successfully initialized");
            NSLog(@"  Included paths count: %lu", (unsigned long)residualCleaner.includedResidualPaths.count);
            NSLog(@"  Excluded paths count: %lu", (unsigned long)residualCleaner.excludedResidualPaths.count);
        } else {
            NSLog(@"✗ Failed to initialize");
        }
        
        NSLog(@"\n=== All tests completed ===");
    }
    return 0;
}