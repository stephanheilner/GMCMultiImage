// GMCMultiImage.h
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

typedef enum {
    GMCMultiImageContentModeScaleAspectFit,
    GMCMultiImageContentModeScaleAspectFill,
} GMCMultiImageContentMode;

@interface GMCMultiImage : NSObject

/** Returns all renditions in an arbitrary order.
 
 This is an abstract method and subclasses must provide an implementation.
 */
- (NSArray *)renditions;

/** Returns the size of the largest rendition.
 
 The default implementation of this method finds the largest rendition and returns it. Subsequent calls return a cached size.
 
 This method is provided as a convenience, and in many cases as a performance optimization. For example, a subclass could override this method
 to return a precomputed size to avoid a potentially expensive search for the largest rendition.
 */
- (CGSize)largestRenditionSize;

/** Returns the smallest rendition.
 */
- (GMCMultiImageRendition *)smallestRendition;

/** Returns the largest rendition.
 */
- (GMCMultiImageRendition *)largestRendition;

/** Returns the rendition that best fits or fills the given size.
 */
- (GMCMultiImageRendition *)bestRenditionThatFits:(CGSize)size contentMode:(GMCMultiImageContentMode)contentMode;

/** Returns the rendition that best fits or fills the given size and is available.
 */
- (GMCMultiImageRendition *)bestAvailableRenditionThatFits:(CGSize)size contentMode:(GMCMultiImageContentMode)contentMode;

/** Returns the rendition whose square thumbnail best fits the given size.
 */
- (GMCMultiImageRendition *)bestRenditionForSquareThumbnailThatFits:(CGSize)size;

@end
