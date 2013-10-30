// GMCDecompressImageOperation.m
//
// Copyright (c) 2013 Hilton Campbell
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "GMCDecompressImageOperation.h"

@implementation NSOperationQueue (GMCDecompressImageOperation)

+ (NSOperationQueue *)decompressImageQueue {
    static NSOperationQueue *decompressImageQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        decompressImageQueue = [[NSOperationQueue alloc] init];
        decompressImageQueue.maxConcurrentOperationCount = 2;
    });
    return decompressImageQueue;
}

@end



@implementation GMCDecompressImageOperation

- (void)main {
    // Exit early if possible
    if (self.isCancelled) {
        self.image = nil;
        return;
    }
    
    // Draw the image decompressed
    UIGraphicsBeginImageContextWithOptions(self.image.size, YES, 1);
    [self.image drawAtPoint:CGPointZero];
    
    // Exit early if possible
    if (self.isCancelled) {
        UIGraphicsEndImageContext();
        self.image = nil;
        return;
    }
    
    // Get the decompressed image
    self.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Lose the image early if possible
    if (self.isCancelled) {
        self.image = nil;
    }
}

@end
