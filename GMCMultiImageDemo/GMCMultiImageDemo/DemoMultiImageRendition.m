// DemoMultiImageRendition.m
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

#import "DemoMultiImageRendition.h"

@interface DemoMultiImageRendition ()

@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, assign) CGSize size;

@end

@implementation DemoMultiImageRendition

- (id)initWithURL:(NSURL *)URL size:(CGSize)size {
    if ((self = [super init])) {
        self.URL = URL;
        self.size = size;
    }
    return self;
}

- (BOOL)isImageAvailable {
    BOOL isImageAvailable = [[NSFileManager defaultManager] fileExistsAtPath:[[self class] cachePathForURL:self.URL]];
    return isImageAvailable;
}

- (GMCMultiImageRenditionFetch *)fetchImageWithCompletionBlock:(GMCMultiImageRenditionFetchCompletionBlock)completionBlock {
    if ([self isImageAvailable]) {
        if (completionBlock) {
            completionBlock(nil);
        }
        return nil;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSError *error = nil;
        NSData *data = [NSData dataWithContentsOfURL:self.URL options:0 error:&error];
        [data writeToFile:[[self class] cachePathForURL:self.URL] atomically:YES];
        if (completionBlock) {
            completionBlock(error);
        }
    });
    return nil;
}

- (UIImage *)image {
    UIImage *image = [UIImage imageWithContentsOfFile:[[self class] cachePathForURL:self.URL]];
    return image;
}

+ (NSString *)cachePathForURL:(NSURL *)URL {
    NSString *cachePath = [[self cacheDirectory] stringByAppendingPathComponent:[[URL absoluteString] lastPathComponent]];
    return cachePath;
}

+ (NSString *)cacheDirectory {
    return NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
}

@end
