//
//  YVLGLView.h
//  HDRiOSTest
//
//  Created by ashawn on 2021/9/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface YVLGLView : UIView

-(void)renderWithBuffer:(CVPixelBufferRef)pixelBuffer width:(int)width height:(int)height;
-(void)renderWithYBuffer:(uint16_t*)YData UVBuffer:(uint16_t*)UVData width:(int)width height:(int)height;
-(void)renderWithYUVBuffer:(CVPixelBufferRef)pixelBuffer width:(int)width height:(int)height;

@end

NS_ASSUME_NONNULL_END
