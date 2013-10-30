// GMCMultiImageView.m
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

#import "GMCMultiImageView.h"

@interface GMCMultiImageView ()

@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicatorView;

@property (nonatomic, strong) GMCMultiImageRendition *currentRendition;
@property (nonatomic, strong) NSMutableArray *multiImageRenditionFetches;

@end

@implementation GMCMultiImageView

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.loadingIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        self.loadingIndicatorView.frame = self.bounds;
        self.loadingIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:self.loadingIndicatorView];
        
        self.multiImageRenditionFetches = [NSMutableArray array];
    }
    return self;
}

- (void)setMultiImage:(GMCMultiImage *)multiImage {
    _multiImage = multiImage;
    
    self.currentRendition = nil;
    for (GMCMultiImageRenditionFetch *multiImageRenditionFetch in self.multiImageRenditionFetches) {
        [multiImageRenditionFetch cancel];
    }
    [self.multiImageRenditionFetches removeAllObjects];
    
    [self.loadingIndicatorView stopAnimating];
    self.image = nil;
    
    if (self.multiImage) {
        [self updateImage];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (self.multiImage) {
        [self updateImage];
    }
}

- (void)updateImage {
    CGSize desiredSize = self.bounds.size;
    
    GMCMultiImageRendition *rendition = [self.multiImage bestRenditionThatFits:desiredSize contentMode:[self multiImageContentMode]];
    if (![self.currentRendition isEqual:rendition]) {
        self.currentRendition = rendition;
        
        if (self.image == nil) {
            GMCMultiImageRendition *smallestRendition = [self.multiImage bestRenditionThatFits:CGSizeMake(55, 55) contentMode:GMCMultiImageContentModeScaleAspectFit];
            if (smallestRendition.isImageAvailable) {
                [self.loadingIndicatorView stopAnimating];
                
                // Show the smallest representation first, if available.
                // It's OK to do this on the main thread because the image is very small.
                self.image = smallestRendition.image;
            } else {
                [self.loadingIndicatorView startAnimating];
                
                // If the smallest representation is not available, go ahead and fetch it, then show it
                __block GMCMultiImageRenditionFetch *fetch = [smallestRendition fetchImageWithCompletionBlock:^(NSError *error) {
                    [self.multiImageRenditionFetches removeObject:fetch];
                    
                    if (!error) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                            if ([self.currentRendition isEqual:rendition] && self.image == nil) {
                                UIImage *image = [[self class] decompressedImageFromImage:smallestRendition.image];
                                
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    if ([self.currentRendition isEqual:rendition] && self.image == nil) {
                                        [self.loadingIndicatorView stopAnimating];
                                        
                                        self.image = image;
                                    }
                                });
                            }
                        });
                    }
                }];
                if (fetch) {
                    [self.multiImageRenditionFetches addObject:fetch];
                }
            }
        }
        
        if (!rendition.isImageAvailable) {
            GMCMultiImageRendition *bestAvailableRendition = [self.multiImage bestAvailableRenditionThatFits:desiredSize contentMode:[self multiImageContentMode]];
            if (bestAvailableRendition && ![bestAvailableRendition isEqual:rendition]) {
                // Fetch and set the best available representation, as long as the desired one hasn't been set yet.
                // Don't directly set the image, as that would cause the image to be loaded on the main thread.
                __block GMCMultiImageRenditionFetch *fetch = [bestAvailableRendition fetchImageWithCompletionBlock:^(NSError *error) {
                    [self.multiImageRenditionFetches removeObject:fetch];
                    
                    if (!error) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                            if ([self.currentRendition isEqual:rendition]) {
                                UIImage *image = [[self class] decompressedImageFromImage:bestAvailableRendition.image];
                                
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    if ([self.currentRendition isEqual:rendition]) {
                                        [self.loadingIndicatorView stopAnimating];
                                        
                                        self.image = image;
                                    }
                                });
                            }
                        });
                    }
                }];
                if (fetch) {
                    [self.multiImageRenditionFetches addObject:fetch];
                }
            }
        }
        
        // Fetch and set the desired image representation.
        // Don't directly set the image, as that would cause the image to be loaded on the main thread.
        __block GMCMultiImageRenditionFetch *fetch = [rendition fetchImageWithCompletionBlock:^(NSError *error) {
            [self.multiImageRenditionFetches removeObject:fetch];
            
            if (error) {
                if ([self.currentRendition isEqual:rendition]) {
                    [self.loadingIndicatorView stopAnimating];
                }
            } else {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                    if ([self.currentRendition isEqual:rendition]) {
                        UIImage *image = [[self class] decompressedImageFromImage:rendition.image];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if ([self.currentRendition isEqual:rendition]) {
                                [self.loadingIndicatorView stopAnimating];
                                
                                self.image = image;
                            }
                        });
                    }
                });
            }
        }];
        if (fetch) {
            [self.multiImageRenditionFetches addObject:fetch];
        }
    }
}

- (GMCMultiImageContentMode)multiImageContentMode {
    switch (self.contentMode) {
        case UIViewContentModeScaleAspectFill:
        case UIViewContentModeScaleToFill:
            return GMCMultiImageContentModeScaleAspectFill;
        case UIViewContentModeScaleAspectFit:
            return GMCMultiImageContentModeScaleAspectFit;
        default:
            return GMCMultiImageContentModeScaleAspectFit;
    }
}

// From http://ioscodesnippet.com/2011/10/02/force-decompressing-uiimage-in-background-to-achieve/
+ (UIImage *)decompressedImageFromImage:(UIImage *)image {
    CGImageRef imageRef = image.CGImage;
    
    // Create a bitmap context that will not require conversion on display
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 CGImageGetWidth(imageRef),
                                                 CGImageGetHeight(imageRef),
                                                 8,
                                                 CGImageGetWidth(imageRef) * 4,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        return nil;
    }
    
    // Draw the image
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(imageRef), CGImageGetHeight(imageRef)), imageRef);
    CGImageRef decompressedImageRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage *decompressedImage = [[UIImage alloc] initWithCGImage:decompressedImageRef];
    CGImageRelease(decompressedImageRef);
    return decompressedImage;
}

@end
