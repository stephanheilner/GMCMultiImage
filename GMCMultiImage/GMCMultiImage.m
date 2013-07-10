// GMCMultiImage.m
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

#import "GMCMultiImage.h"

@interface GMCMultiImage ()

@property (nonatomic, strong) NSValue *cachedLargestRenditionSize;

@end

@implementation GMCMultiImage

- (NSArray *)renditions {
    if ([self class] == [GMCMultiImage class]) {
        [self doesNotRecognizeSelector:_cmd];
    }
    return nil;
}

- (CGSize)largestRenditionSize {
    if (!self.cachedLargestRenditionSize) {
        self.cachedLargestRenditionSize = [NSValue valueWithCGSize:[self largestRendition].size];
    }
    return [self.cachedLargestRenditionSize CGSizeValue];
}

- (GMCMultiImageRendition *)smallestRendition {
    GMCMultiImageRendition *smallestRendition = nil;
    for (GMCMultiImageRendition *rendition in self.renditions) {
        if (!smallestRendition || smallestRendition.size.width > rendition.size.width || smallestRendition.size.height > rendition.size.height) {
            smallestRendition = rendition;
        }
    }
    return smallestRendition;
}

- (GMCMultiImageRendition *)largestRendition {
    GMCMultiImageRendition *largestRendition = nil;
    for (GMCMultiImageRendition *rendition in self.renditions) {
        if (!largestRendition || largestRendition.size.width < rendition.size.width || largestRendition.size.height < rendition.size.height) {
            largestRendition = rendition;
        }
    }
    return largestRendition;
}

- (GMCMultiImageRendition *)bestRenditionThatFits:(CGSize)size contentMode:(GMCMultiImageContentMode)contentMode {
    return [self bestRenditionThatFits:size contentMode:contentMode mustBeAvailable:NO];
}

- (GMCMultiImageRendition *)bestAvailableRenditionThatFits:(CGSize)size contentMode:(GMCMultiImageContentMode)contentMode {
    return [self bestRenditionThatFits:size contentMode:contentMode mustBeAvailable:YES];
}

- (GMCMultiImageRendition *)bestRenditionThatFits:(CGSize)size contentMode:(GMCMultiImageContentMode)contentMode mustBeAvailable:(BOOL)mustBeAvailable {
    // Adjust the size to account for retina displays
    CGSize adjustedSize = CGSizeMake(size.width * [UIScreen mainScreen].scale, size.height * [UIScreen mainScreen].scale);
    
    switch (contentMode) {
        case GMCMultiImageContentModeScaleAspectFill: {
            GMCMultiImageRendition *bestRendition = nil;
            GMCMultiImageRendition *largestRendition = nil;
            for (GMCMultiImageRendition *rendition in self.renditions) {
                if (mustBeAvailable && !rendition.isImageAvailable) {
                    continue;
                }
                
                // A viable ideal rendition must be larger than the desired size in both dimensions
                if (rendition.size.width >= adjustedSize.width && rendition.size.height >= adjustedSize.height) {
                    // Of the viable ideal renditions, the smallest one is best
                    if (!bestRendition || bestRendition.size.width > rendition.size.width || bestRendition.size.height > rendition.size.height) {
                        bestRendition = rendition;
                    }
                }
                // Find the largest rendition as well, just in case there is no ideal rendition
                if (!largestRendition || (largestRendition.size.width <= rendition.size.width && largestRendition.size.height <= rendition.size.height)) {
                    largestRendition = rendition;
                }
            }
            return (bestRendition ?: largestRendition);
        }
        case GMCMultiImageContentModeScaleAspectFit: {
            GMCMultiImageRendition *bestRendition = nil;
            GMCMultiImageRendition *largestRendition = nil;
            for (GMCMultiImageRendition *rendition in self.renditions) {
                if (mustBeAvailable && !rendition.isImageAvailable) {
                    continue;
                }
                
                // A viable ideal rendition must be larger than the desired size in at least one dimension
                if (rendition.size.width >= adjustedSize.width || rendition.size.height >= adjustedSize.height) {
                    // Of the viable ideal renditions, the smallest one is best
                    if (!bestRendition || bestRendition.size.width > rendition.size.width || bestRendition.size.height > rendition.size.height) {
                        bestRendition = rendition;
                    }
                }
                // Find the largest rendition as well, just in case there is no ideal rendition
                if (!largestRendition || (largestRendition.size.width <= rendition.size.width && largestRendition.size.height <= rendition.size.height)) {
                    largestRendition = rendition;
                }
            }
            return (bestRendition ?: largestRendition);
        }
    }
}

- (GMCMultiImageRendition *)bestRenditionForSquareThumbnailThatFits:(CGSize)size {
    // Adjust the size to account for retina displays
    CGSize adjustedSize = CGSizeMake(size.width * [UIScreen mainScreen].scale, size.height * [UIScreen mainScreen].scale);
    
    GMCMultiImageRendition *bestRendition = nil;
    GMCMultiImageRendition *largestRendition = nil;
    for (GMCMultiImageRendition *rendition in self.renditions) {
        // A viable ideal rendition must be larger than the desired size in both dimensions
        if (rendition.squareThumbnailSize.width >= adjustedSize.width && rendition.squareThumbnailSize.height >= adjustedSize.height) {
            // Of the viable ideal renditions, the smallest one is best
            if (!bestRendition || bestRendition.squareThumbnailSize.width > rendition.squareThumbnailSize.width || bestRendition.squareThumbnailSize.height > rendition.squareThumbnailSize.height) {
                bestRendition = rendition;
            }
        }
        // Find the largest rendition as well, just in case there is no ideal rendition
        if (!largestRendition || largestRendition.squareThumbnailSize.width < rendition.squareThumbnailSize.width || largestRendition.squareThumbnailSize.height < rendition.squareThumbnailSize.height) {
            largestRendition = rendition;
        }
    }
    return (bestRendition ?: largestRendition);
}

@end
