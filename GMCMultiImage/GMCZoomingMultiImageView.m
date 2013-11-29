// GMCZoomingMultiImageView.m
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

#import "GMCZoomingMultiImageView.h"
#import "GMCDecompressImageOperation.h"

const CGSize GMCZoomingMultiImageViewPlaceholderSizeDefault = { 55, 55 };

#define fequal(a,b) (fabs((a) - (b)) < FLT_EPSILON)

@interface GMCZoomingMultiImageView () <UIScrollViewDelegate>

@property (nonatomic, strong) UITapGestureRecognizer *doubleTapGestureRecognizer;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicatorView;

@property (nonatomic, assign) CGSize previousBoundsSize;

@property (nonatomic, strong) GMCMultiImageRendition *currentRendition;
@property (nonatomic, strong) NSMutableArray *multiImageRenditionFetches;
@property (nonatomic, strong) NSMutableArray *decompressImageOperations;

@property (nonatomic, assign) CGFloat initialZoomScale;
@property (nonatomic, assign) CGFloat otherZoomScale;

@end

@implementation GMCZoomingMultiImageView

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        self.scrollView.scrollsToTop = NO;
        self.scrollView.showsVerticalScrollIndicator = NO;
        self.scrollView.showsHorizontalScrollIndicator = NO;
        self.scrollView.delegate = self;
        self.scrollView.maximumZoomScale = 1;
        self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:self.scrollView];
        
        self.imageView = [[UIImageView alloc] init];
        [self.scrollView addSubview:self.imageView];
        
        self.loadingIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        self.loadingIndicatorView.frame = self.bounds;
        self.loadingIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:self.loadingIndicatorView];
        
        self.multiImageRenditionFetches = [NSMutableArray array];
        self.decompressImageOperations = [NSMutableArray array];
        
        self.doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
        self.doubleTapGestureRecognizer.numberOfTapsRequired = 2;
        [self addGestureRecognizer:self.doubleTapGestureRecognizer];
        
        _placeholderSize = GMCZoomingMultiImageViewPlaceholderSizeDefault;
        _scale = [UIScreen mainScreen].scale;
    }
    return self;
}

- (void)setMultiImage:(GMCMultiImage *)multiImage {
    _multiImage = multiImage;
    
    // Reset state
    self.currentRendition = nil;
    self.imageView.image = nil;
    [self.loadingIndicatorView stopAnimating];
    
    // Cancel all pending fetches and decompress image operations
    for (GMCDecompressImageOperation *decompressImageOperation in self.decompressImageOperations) {
        [decompressImageOperation cancel];
    }
    for (GMCMultiImageRenditionFetch *multiImageRenditionFetch in self.multiImageRenditionFetches) {
        [multiImageRenditionFetch cancel];
    }
    [self.decompressImageOperations removeAllObjects];
    [self.multiImageRenditionFetches removeAllObjects];
    
    // Resize image view
    CGSize fullImageSize = [self.multiImage largestRenditionSize];
    self.imageView.frame = CGRectMake(0, 0, fullImageSize.width, fullImageSize.height);
    
    // Resize scroll view and establish initial zoom and zoom limits
    self.scrollView.contentSize = fullImageSize;
    self.scrollView.minimumZoomScale = MIN(1, MIN(self.scrollView.bounds.size.width / fullImageSize.width, self.scrollView.bounds.size.height / fullImageSize.height));
    self.scrollView.zoomScale = self.scrollView.minimumZoomScale;
    
    self.initialZoomScale = self.scrollView.minimumZoomScale;
    self.otherZoomScale = 1;
    
    [self updateImage];
    [self centerImage];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (!CGSizeEqualToSize(self.previousBoundsSize, self.bounds.size)) {
        self.previousBoundsSize = self.bounds.size;
        
        CGSize fullImageSize = [self.multiImage largestRenditionSize];
        
        CGFloat previousMinimumZoomScale = self.scrollView.minimumZoomScale;
        self.scrollView.minimumZoomScale = MIN(1, MIN(self.scrollView.bounds.size.width / fullImageSize.width, self.scrollView.bounds.size.height / fullImageSize.height));
        if (self.scrollView.zoomScale == previousMinimumZoomScale) {
            self.scrollView.zoomScale = self.scrollView.minimumZoomScale;
        }
        self.scrollView.zoomScale = MAX(self.scrollView.minimumZoomScale, self.scrollView.zoomScale);
        
        self.initialZoomScale = self.scrollView.minimumZoomScale;
        
        [self updateImage];
        [self centerImage];
    }
}

- (void)centerImage {
    CGPoint center;
	center.x = roundf(self.scrollView.contentSize.width / 2 + MAX(0, (self.scrollView.bounds.size.width - self.scrollView.contentSize.width) / 2));
	center.y = roundf(self.scrollView.contentSize.height / 2 + MAX(0, (self.scrollView.bounds.size.height - self.scrollView.contentSize.height) / 2));
    self.imageView.center = center;
}

- (void)zoomToScale:(CGFloat)scale atLocation:(CGPoint)location {
	CGRect zoomRect;
    zoomRect.size.width  = self.scrollView.bounds.size.width / scale;
	zoomRect.size.height = self.scrollView.bounds.size.height / scale;
    zoomRect.origin.x = location.x - (zoomRect.size.width / 2.0);
    zoomRect.origin.y = location.y - (zoomRect.size.height / 2.0);
	[self.scrollView zoomToRect:zoomRect animated:YES];
}

- (void)updateImage {
    if (!self.multiImage) {
        return;
    }
    
    CGSize fullImageSize = [self.multiImage largestRenditionSize];
    CGSize desiredSize = CGSizeMake(fullImageSize.width * self.scrollView.zoomScale, fullImageSize.height * self.scrollView.zoomScale);
    
    GMCMultiImageRendition *rendition = [self.multiImage bestRenditionThatFits:desiredSize scale:self.scale contentMode:GMCMultiImageContentModeScaleAspectFit];
    if (![self.currentRendition isEqual:rendition]) {
        self.currentRendition = rendition;
        
        if (self.imageView.image == nil) {
            GMCMultiImageRendition *smallestRendition = [self.multiImage bestRenditionThatFits:self.placeholderSize scale:self.scale contentMode:GMCMultiImageContentModeScaleAspectFit];
            if (smallestRendition.isImageAvailable) {
                [self.loadingIndicatorView stopAnimating];
                
                // Show the smallest representation first, if available.
                // It's OK to do this on the main thread because the image is very small.
                self.imageView.image = smallestRendition.image;
            } else {
                [self.loadingIndicatorView startAnimating];
                
                // If the smallest representation is not available, go ahead and fetch it, then show it
                __block GMCMultiImageRenditionFetch *fetch = [smallestRendition fetchImageWithCompletionBlock:^(NSError *error) {
                    if ([self.multiImageRenditionFetches containsObject:fetch]) {
                        [self.multiImageRenditionFetches removeObject:fetch];
                    }
                    
                    if (!error) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                            if ([self.currentRendition isEqual:rendition] && self.imageView.image == nil) {
                                GMCDecompressImageOperation *operation = [[GMCDecompressImageOperation alloc] init];
                                operation.image = smallestRendition.image;
                                
                                __weak GMCDecompressImageOperation *weakOperation = operation;
                                operation.completionBlock = ^{
                                    UIImage *image = weakOperation.image;
                                    if ([self.decompressImageOperations containsObject:weakOperation]) {
                                        [self.decompressImageOperations removeObject:weakOperation];
                                    }
                                    
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        if ([self.currentRendition isEqual:rendition] && self.imageView.image == nil) {
                                            [self.loadingIndicatorView stopAnimating];
                                            
                                            self.imageView.image = image;
                                        }
                                    });
                                };
                                
                                [self.decompressImageOperations addObject:operation];
                                [[NSOperationQueue decompressImageQueue] addOperation:operation];
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
            GMCMultiImageRendition *bestAvailableRendition = [self.multiImage bestAvailableRenditionThatFits:desiredSize scale:self.scale contentMode:GMCMultiImageContentModeScaleAspectFit];
            if (bestAvailableRendition && ![bestAvailableRendition isEqual:rendition]) {
                // Fetch and set the best available representation, as long as the desired one hasn't been set yet.
                // Don't directly set the image, as that would cause the image to be loaded on the main thread.
                __block GMCMultiImageRenditionFetch *fetch = [bestAvailableRendition fetchImageWithCompletionBlock:^(NSError *error) {
                    if ([self.multiImageRenditionFetches containsObject:fetch]) {
                        [self.multiImageRenditionFetches removeObject:fetch];
                    }
                    
                    if (!error) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                            if ([self.currentRendition isEqual:rendition]) {
                                GMCDecompressImageOperation *operation = [[GMCDecompressImageOperation alloc] init];
                                operation.image = bestAvailableRendition.image;
                                
                                __weak GMCDecompressImageOperation *weakOperation = operation;
                                operation.completionBlock = ^{
                                    UIImage *image = weakOperation.image;
                                    if ([self.decompressImageOperations containsObject:weakOperation]) {
                                        [self.decompressImageOperations removeObject:weakOperation];
                                    }
                                    
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        if ([self.currentRendition isEqual:rendition]) {
                                            [self.loadingIndicatorView stopAnimating];
                                            
                                            self.imageView.image = image;
                                        }
                                    });
                                };
                                
                                [self.decompressImageOperations addObject:operation];
                                [[NSOperationQueue decompressImageQueue] addOperation:operation];
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
            if ([self.multiImageRenditionFetches containsObject:fetch]) {
                [self.multiImageRenditionFetches removeObject:fetch];
            }
            
            if (error) {
                if ([self.currentRendition isEqual:rendition]) {
                    [self.loadingIndicatorView stopAnimating];
                }
            } else {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                    if ([self.currentRendition isEqual:rendition]) {
                        GMCDecompressImageOperation *operation = [[GMCDecompressImageOperation alloc] init];
                        operation.image = rendition.image;
                        
                        __weak GMCDecompressImageOperation *weakOperation = operation;
                        operation.completionBlock = ^{
                            UIImage *image = weakOperation.image;
                            if ([self.decompressImageOperations containsObject:weakOperation]) {
                                [self.decompressImageOperations removeObject:weakOperation];
                            }
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if ([self.currentRendition isEqual:rendition]) {
                                    [self.loadingIndicatorView stopAnimating];
                                    
                                    self.imageView.image = image;
                                }
                            });
                        };
                        
                        [self.decompressImageOperations addObject:operation];
                        [[NSOperationQueue decompressImageQueue] addOperation:operation];
                    }
                });
            }
        }];
        if (fetch) {
            [self.multiImageRenditionFetches addObject:fetch];
        }
    }
}

#pragma mark - Gesture Recognizers

- (void)doubleTap:(UITapGestureRecognizer *)gestureRecognizer {
    CGPoint location = [gestureRecognizer locationInView:self.imageView];
    if (!fequal(self.scrollView.zoomScale, self.initialZoomScale)) {
        [self zoomToScale:self.initialZoomScale atLocation:location];
    } else if (!fequal(self.initialZoomScale, self.otherZoomScale)) {
        [self zoomToScale:self.otherZoomScale atLocation:location];
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale {
    [self updateImage];
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self centerImage];
}

@end
