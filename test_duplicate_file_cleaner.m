//
//  test_duplicate_file_cleaner.m
//  Lemon Cleaner Test
//
//  Created by Trae AI on 2024/10/15.
//

#import <Foundation/Foundation.h>
#import "LMDuplicateFileCleaner.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"=== Testing Lemon Duplicate File Cleaner ===");
        
        // Get shared instance
        LMDuplicateFileCleaner *cleaner = [LMDuplicateFileCleaner sharedInstance];
        
        // Set minimum file size to 1KB for testing
        cleaner.minimumFileSize = 1024;
        
        // Add some test paths (use user's Desktop for testing)
        NSString *desktopPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
        NSArray *testPaths = @[desktopPath];
        
        NSLog(@"Scanning for duplicate files in: %@", desktopPath);
        NSLog(@"Minimum file size: %llu bytes", cleaner.minimumFileSize);
        
        // Start scanning
        [cleaner startScanningPaths:testPaths progress:^(double progress) {
            NSLog(@"Scanning progress: %.2f%%", progress * 100);
        } completion:^(NSArray<LMDuplicateFileGroup *> *duplicateGroups, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error scanning for duplicates: %@", error.localizedDescription);
            } else {
                NSLog(@"Scanning completed successfully!");
                NSLog(@"Found %lu duplicate groups", (unsigned long)duplicateGroups.count);
                
                // Print duplicate groups
                for (int i = 0; i < duplicateGroups.count; i++) {
                    LMDuplicateFileGroup *group = duplicateGroups[i];
                    NSLog(@"\nGroup %d:", i + 1);
                    NSLog(@"Total size: %@", [group formattedTotalSize]);
                    NSLog(@"File count: %lu", (unsigned long)group.fileCount);
                    NSLog(@"File extension: %@", group.fileExtension ?: @"N/A");
                    
                    // Print files in group
                    for (LMDuplicateFileItem *file in group.files) {
                        NSLog(@"  - %@ (%@)", file.fileName, [file formattedFileSize]);
                        NSLog(@"    Path: %@", file.filePath);
                    }
                }
                
                // Test getTotalSize method (if available)
                NSLog(@"\n=== Test completed ===");
            }
        }];
        
        // Wait for scanning to complete
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:30.0]];
        
        NSLog(@"Test finished");
    }
    return 0;
}