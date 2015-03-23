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
#import "GMCDecompressImageOperation.h"

const CGSize GMCMultiImageViewPlaceholderSizeDefault = { 55, 55 };

@interface GMCMultiImageView ()

@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicatorView;

@property (nonatomic, strong) dispatch_queue_t synchronizationQueue;
@property (nonatomic, strong) GMCMultiImageRendition *currentRendition;
@property (nonatomic, strong) NSMutableArray *multiImageRenditionFetches;
@property (nonatomic, strong) NSMutableArray *decompressImageOperations;

@end

@implementation GMCMultiImageView

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.synchronizationQueue = dispatch_queue_create("com.galacticmegacorp.GMCMultiImageView.synchronizationQueue", DISPATCH_QUEUE_SERIAL);
        
        self.multiImageRenditionFetches = [NSMutableArray array];
        self.decompressImageOperations = [NSMutableArray array];
        
        _shouldDecompressImages = YES;
        _placeholderSize = GMCMultiImageViewPlaceholderSizeDefault;
        _scale = [UIScreen mainScreen].scale;
    }
    return self;
}

- (void)setMultiImage:(GMCMultiImage *)multiImage {
    if ([multiImage isEqual:_multiImage]) {
        return;
    }

    _multiImage = multiImage;
    
    self.currentRendition = nil;
    
    dispatch_sync(self.synchronizationQueue, ^{
        for (GMCDecompressImageOperation *decompressImageOperation in self.decompressImageOperations) {
            [decompressImageOperation cancel];
        }
        for (GMCMultiImageRenditionFetch *multiImageRenditionFetch in self.multiImageRenditionFetches) {
            [multiImageRenditionFetch cancel];
        }
        [self.decompressImageOperations removeAllObjects];
        [self.multiImageRenditionFetches removeAllObjects];
    });
    
    [self stopAnimatingLoadingIndicator];
    self.image = nil;
    
    if (self.multiImage) {
        [self updateImage];
    }
}

- (void)setLoadingIndicatorViewHidden:(BOOL)loadingIndicatorViewHidden {
    _loadingIndicatorViewHidden = loadingIndicatorViewHidden;
    
    [self stopAnimatingLoadingIndicator];
}

- (void)startAnimatingLoadingIndicator {
    if (!self.loadingIndicatorViewHidden) {
        if (!self.loadingIndicatorView) {
            self.loadingIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
            self.loadingIndicatorView.frame = self.bounds;
            self.loadingIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self addSubview:self.loadingIndicatorView];
        }
        
        [self.loadingIndicatorView startAnimating];
    }
}

- (void)stopAnimatingLoadingIndicator {
    [self.loadingIndicatorView stopAnimating];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (self.multiImage) {
        [self updateImage];
    }
}

- (void)updateImage {
    CGSize desiredSize = self.bounds.size;
    
    GMCMultiImageRendition *rendition = [self.multiImage bestRenditionThatFits:desiredSize scale:self.scale contentMode:[self multiImageContentMode]];
    if (![self.currentRendition isEqual:rendition]) {
        self.currentRendition = rendition;
        
        if (self.image == nil) {
            GMCMultiImageRendition *smallestRendition = [self.multiImage bestRenditionThatFits:self.placeholderSize scale:self.scale contentMode:[self multiImageContentMode]];
            if (smallestRendition.isImageAvailable) {
                [self stopAnimatingLoadingIndicator];
                
                // Show the smallest representation first, if available.
                // It's OK to do this on the main thread because the image is very small.
                self.image = smallestRendition.image;
            } else {
                [self startAnimatingLoadingIndicator];
                
                // If the smallest representation is not available, go ahead and fetch it, then show it
                __block GMCMultiImageRenditionFetch *fetch = [smallestRendition fetchImageWithCompletionBlock:^(NSError *error) {
                    if ([self.currentRendition isEqual:rendition]) {
                        dispatch_sync(self.synchronizationQueue, ^{
                            [self.multiImageRenditionFetches removeObject:fetch];
                        });
                    }
                    
                    if (!error) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                            if ([self.currentRendition isEqual:rendition] && self.image == nil) {
                                void (^setImageBlock)(UIImage *image) = ^(UIImage *image) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        if ([self.currentRendition isEqual:rendition] && self.image == nil) {
                                            [self stopAnimatingLoadingIndicator];
                                            
                                            self.image = image;
                                        }
                                    });
                                };
                                
                                if (self.shouldDecompressImages) {
                                    GMCDecompressImageOperation *operation = [[GMCDecompressImageOperation alloc] init];
                                    operation.image = smallestRendition.image;
                                    
                                    __weak GMCDecompressImageOperation *weakOperation = operation;
                                    operation.completionBlock = ^{
                                        UIImage *image = weakOperation.image;
                                        if ([self.currentRendition isEqual:rendition]) {
                                            dispatch_sync(self.synchronizationQueue, ^{
                                                [self.decompressImageOperations removeObject:weakOperation];
                                            });
                                        }
                                        
                                        setImageBlock(image);
                                    };
                                    
                                    dispatch_sync(self.synchronizationQueue, ^{
                                        [self.decompressImageOperations addObject:operation];
                                    });
                                    [[NSOperationQueue decompressImageQueue] addOperation:operation];
                                } else {
                                    setImageBlock(smallestRendition.image);
                                }
                            }
                        });
                    }
                }];
                if (fetch) {
                    dispatch_sync(self.synchronizationQueue, ^{
                        [self.multiImageRenditionFetches addObject:fetch];
                    });
                }
            }
        }
        
        if (!rendition.isImageAvailable) {
            GMCMultiImageRendition *bestAvailableRendition = [self.multiImage bestAvailableRenditionThatFits:desiredSize scale:self.scale contentMode:[self multiImageContentMode]];
            if (bestAvailableRendition && ![bestAvailableRendition isEqual:rendition]) {
                // Fetch and set the best available representation, as long as the desired one hasn't been set yet.
                // Don't directly set the image, as that would cause the image to be loaded on the main thread.
                __block GMCMultiImageRenditionFetch *fetch = [bestAvailableRendition fetchImageWithCompletionBlock:^(NSError *error) {
                    if ([self.currentRendition isEqual:rendition]) {
                        dispatch_sync(self.synchronizationQueue, ^{
                            [self.multiImageRenditionFetches removeObject:fetch];
                        });
                    }
                    
                    if (!error) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                            if ([self.currentRendition isEqual:rendition]) {
                                void (^setImageBlock)(UIImage *image) = ^(UIImage *image) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        if ([self.currentRendition isEqual:rendition]) {
                                            [self stopAnimatingLoadingIndicator];
                                            
                                            self.image = image;
                                        }
                                    });
                                };
                                
                                if (self.shouldDecompressImages) {
                                    GMCDecompressImageOperation *operation = [[GMCDecompressImageOperation alloc] init];
                                    operation.image = bestAvailableRendition.image;
                                    
                                    __weak GMCDecompressImageOperation *weakOperation = operation;
                                    operation.completionBlock = ^{
                                        UIImage *image = weakOperation.image;
                                        if ([self.currentRendition isEqual:rendition]) {
                                            dispatch_sync(self.synchronizationQueue, ^{
                                                [self.decompressImageOperations removeObject:weakOperation];
                                            });
                                        }
                                        
                                        setImageBlock(image);
                                    };
                                    
                                    dispatch_sync(self.synchronizationQueue, ^{
                                        [self.decompressImageOperations addObject:operation];
                                    });
                                    [[NSOperationQueue decompressImageQueue] addOperation:operation];
                                } else {
                                    setImageBlock(bestAvailableRendition.image);
                                }
                            }
                        });
                    }
                }];
                if (fetch) {
                    dispatch_sync(self.synchronizationQueue, ^{
                        [self.multiImageRenditionFetches addObject:fetch];
                    });
                }
            }
        }
        
        // Fetch and set the desired image representation.
        // Don't directly set the image, as that would cause the image to be loaded on the main thread.
        __block GMCMultiImageRenditionFetch *fetch = [rendition fetchImageWithCompletionBlock:^(NSError *error) {
            if ([self.currentRendition isEqual:rendition]) {
                dispatch_sync(self.synchronizationQueue, ^{
                    [self.multiImageRenditionFetches removeObject:fetch];
                });
            }
            
            if (error) {
                if ([self.currentRendition isEqual:rendition]) {
                    [self stopAnimatingLoadingIndicator];
                }
            } else {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                    if ([self.currentRendition isEqual:rendition]) {
                        void (^setImageBlock)(UIImage *image) = ^(UIImage *image) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if ([self.currentRendition isEqual:rendition]) {
                                    [self stopAnimatingLoadingIndicator];
                                    
                                    self.image = image;
                                }
                            });
                        };
                        
                        if (self.shouldDecompressImages) {
                            GMCDecompressImageOperation *operation = [[GMCDecompressImageOperation alloc] init];
                            operation.image = rendition.image;
                            
                            __weak GMCDecompressImageOperation *weakOperation = operation;
                            operation.completionBlock = ^{
                                UIImage *image = weakOperation.image;
                                if ([self.currentRendition isEqual:rendition]) {
                                    dispatch_sync(self.synchronizationQueue, ^{
                                        [self.decompressImageOperations removeObject:weakOperation];
                                    });
                                }
                                
                                setImageBlock(image);
                            };
                            
                            dispatch_sync(self.synchronizationQueue, ^{
                                [self.decompressImageOperations addObject:operation];
                            });
                            [[NSOperationQueue decompressImageQueue] addOperation:operation];
                        } else {
                            setImageBlock(rendition.image);
                        }
                    }
                });
            }
        }];
        if (fetch) {
            dispatch_sync(self.synchronizationQueue, ^{
                [self.multiImageRenditionFetches addObject:fetch];
            });
        }
    }
}

- (GMCMultiImageContentMode)multiImageContentMode {
    switch (self.contentMode) {
        case UIViewContentModeScaleAspectFill:
        case UIViewContentModeScaleToFill:
            return GMCMultiImageContentModeScaleAspectFill;
        case UIViewContentModeScaleAspectFit:
        default:
            return GMCMultiImageContentModeScaleAspectFit;
    }
}

@end
