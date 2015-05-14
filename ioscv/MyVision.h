//
//  MyVision.h
//  ioscv
//
//  Created by Ofer Livny on 5/13/15.
//  Copyright (c) 2015 Ofer Livny. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
#import "MySimpleBlobDetector.h"
#endif


typedef enum task_ {
    kVisionTaskNone,
    kVisionTaskAverage,
    kVisionTaskLargestBlobSize
} VisionTask;


@interface MyVision : NSObject
// Add to interface
- (void) processBuffer: (CMSampleBufferRef) sampleBuffer;
- (void) prepareOutput;
- (NSString *) getTimingReport;
- (void) reset;
- (void) plotToView: (UIView *) view;
@end


@interface MyVisionAverage: MyVision
@property (nonatomic) NSInteger intensity;
@end
@interface MyVisionBlobSize: MyVision
@property (nonatomic) NSInteger blobSize;
@end

