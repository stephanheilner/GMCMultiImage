// GMCMultiImageRendition.m
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

#import "GMCMultiImageRendition.h"

@implementation GMCMultiImageRendition

- (BOOL)isImageAvailable {
    if ([self class] == [GMCMultiImageRendition class]) {
        [self doesNotRecognizeSelector:_cmd];
    }
    return NO;
}

- (GMCMultiImageRenditionFetch *)fetchImageWithCompletionBlock:(GMCMultiImageRenditionFetchCompletionBlock)completionBlock {
    if ([self class] == [GMCMultiImageRendition class]) {
        [self doesNotRecognizeSelector:_cmd];
    }
    return nil;
}

#pragma mark - Standard Image

- (CGSize)size {
    if ([self class] == [GMCMultiImageRendition class]) {
        [self doesNotRecognizeSelector:_cmd];
    }
    return CGSizeZero;
}

- (UIImage *)image {
    if ([self class] == [GMCMultiImageRendition class]) {
        [self doesNotRecognizeSelector:_cmd];
    }
    return nil;
}

#pragma mark - Square Thumbnail Image

- (CGSize)squareThumbnailSize {
    CGSize size = [self size];
    CGFloat shortestSideLength = MIN(size.width, size.height);
    return CGSizeMake(shortestSideLength, shortestSideLength);
}

- (UIImage *)squareThumbnailImage {
    UIImage *uncroppedImage = [self image];
    
    CGFloat shortestSideLength = MIN(uncroppedImage.size.width, uncroppedImage.size.height);
    CGRect cropRect = CGRectMake(floorf((uncroppedImage.size.width - shortestSideLength) / 2),
                                 floorf((uncroppedImage.size.height - shortestSideLength) / 2),
                                 shortestSideLength,
                                 shortestSideLength);
    
    CGImageRef croppedImageRef = CGImageCreateWithImageInRect(uncroppedImage.CGImage, cropRect);
    UIImage *croppedImage = [UIImage imageWithCGImage:croppedImageRef scale:1 orientation:uncroppedImage.imageOrientation];
    CGImageRelease(croppedImageRef);
    
    return croppedImage;
}

@end
