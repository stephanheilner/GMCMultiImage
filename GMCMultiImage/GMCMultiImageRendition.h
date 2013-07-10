// GMCMultiImageRendition.h
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

#import "GMCMultiImageRenditionFetch.h"

typedef void(^GMCMultiImageRenditionFetchCompletionBlock)(NSError *error);

@interface GMCMultiImageRendition : NSObject

/** Returns whether the image is available locally.
 
 This is an abstract method and subclasses must provide an implementation.
 */
- (BOOL)isImageAvailable;

/** Fetches the image from its remote source, then calls the completion block. Returns an object representing the fetch which can be cancelled.
 
 This is an abstract method and subclasses must provide an implementation.
 
 This method may be called even if the image is available locally. The subclass implementation generally should not re-fetch the image when this is the case.
 */
- (GMCMultiImageRenditionFetch *)fetchImageWithCompletionBlock:(GMCMultiImageRenditionFetchCompletionBlock)completionBlock;

#pragma mark - Standard Image

/** Returns the size of this rendition.
 
 This is an abstract method and subclasses must provide an implementation.
 */
- (CGSize)size;

/** Returns the image for this rendition.
 
 This is an abstract method and subclasses must provide an implementation.
 */
- (UIImage *)image;

#pragma mark - Square Thumbnail Image

/** Returns the size of this rendition, cropped to a square thumbnail.
 
 The default implementation of this method returns the size of the largest square that fits within the standard image size.
 
 A subclass can override this method to provide the size of a custom square thumbnail crop.
 */
- (CGSize)squareThumbnailSize;

/** Returns the image for this rendition, cropped to a square thumbnail.
 
 The default implementation of this method crops the standard image equally on opposite sides to produce the largest possible square image.
 
 A subclass can override this method to provide the image using a custom square thumbnail crop.
 */
- (UIImage *)squareThumbnailImage;

@end
