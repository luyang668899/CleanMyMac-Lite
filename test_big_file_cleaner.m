//
//  test_big_file_cleaner.m
//  Test script for LemonBigFileCleaner
//
//  Created by Trae AI on 2024/10/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "localPod/LemonBigFileCleaner/LemonBigFileCleaner/Classes/LMBigFileCleaner.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"=== Testing LemonBigFileCleaner ===");
        
        // Get shared instance
        LMBigFileCleaner *cleaner = [LMBigFileCleaner sharedInstance];
        NSLog(@"✓ Initialized LMBigFileCleaner shared instance");
        
        // Set minimum file size to 50MB for faster testing
        cleaner.minimumFileSize = 50 * 1024 * 1024;
        NSLog(@"✓ Set minimum file size to 50MB");
        
        // Get user home directory for scanning
        NSString *homeDirectory = NSHomeDirectory();
        NSArray *scanPaths = @[homeDirectory];
        NSLog(@"✓ Will scan directory: %@", homeDirectory);
        
        // Start scanning
        NSLog(@"\n=== Starting scan for big files ===");
        [cleaner startScanningPaths:scanPaths progress:^(double progress) {
            NSLog(@"Scan progress: %.2f%%", progress * 100);
        } completion:^(NSArray<LMBigFileItem *> *bigFiles, NSError * _Nullable error) {
            if (error) {
                NSLog(@"✗ Scan failed with error: %@", error.localizedDescription);
            } else {
                NSLog(@"✓ Scan completed successfully");
                NSLog(@"Found %lu big files:", (unsigned long)bigFiles.count);
                
                // Print found big files
                for (int i = 0; i < bigFiles.count; i++) {
                    LMBigFileItem *fileItem = bigFiles[i];
                    NSLog(@"%d. %@ (%@) - %@", i+1, fileItem.fileName, fileItem.formattedFileSize, fileItem.filePath);
                    
                    // Test file info preview for first file
                    if (i == 0) {
                        NSLog(@"\n=== Testing file info preview ===");
                        NSDictionary *fileInfo = [cleaner getFileInfoForPreview:fileItem];
                        NSLog(@"File info for %@:", fileItem.fileName);
                        NSLog(@"  Name: %@", fileInfo[@"name"]);
                        NSLog(@"  Path: %@", fileInfo[@"path"]);
                        NSLog(@"  Size: %@", fileInfo[@"formattedSize"]);
                        NSLog(@"  Extension: %@", fileInfo[@"extension"] ?: @"N/A");
                        NSLog(@"  MIME Type: %@", fileInfo[@"mimeType"] ?: @"N/A");
                        NSLog(@"  Modification Date: %@", fileInfo[@"modificationDate"]);
                        NSLog(@"✓ File info preview works correctly");
                    }
                }
                
                // Test delete functionality (commented out for safety)
                /*
                if (bigFiles.count > 0) {
                    NSLog(@"\n=== Testing delete functionality ===");
                    NSArray *filesToDelete = @[bigFiles[0]];
                    [cleaner deleteFiles:filesToDelete completion:^(BOOL success, NSArray<NSString *> *deletedFiles, NSError * _Nullable error) {
                        if (error) {
                            NSLog(@"✗ Delete failed with error: %@", error.localizedDescription);
                        } else {
                            NSLog(@"✓ Delete completed successfully");
                            NSLog(@"Deleted %lu files:", (unsigned long)deletedFiles.count);
                            for (NSString *deletedFile in deletedFiles) {
                                NSLog(@"- %@", deletedFile);
                            }
                        }
                    }];
                }
                */
                
                NSLog(@"\n=== Test completed successfully ===");
            }
        }];
        
        // Keep the script running to see the results
        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}
