//
//  MyVision.m
//  ioscv
//
//  Created by Ofer Livny on 5/13/15.
//  Copyright (c) 2015 Ofer Livny. All rights reserved.
//

#import "MyVision.h"

#include "TicToc.h"
#include "sauvola.h"

using namespace cv;

@interface MyVision()
@property (nonatomic) Mat image;
- (void) processImage: (Mat) gray_image ;
+ (UIImage *) MatToUIImage: (Mat *) mat ;
@property (atomic) NSLock * cvlock;
@end

@implementation MyVision

// for OpenCV function
+ (UIImage*) MatToUIImage:(cv::Mat *) mat_p  {
    Mat &mat = *mat_p;
    NSAssert(mat.depth() == CV_8U, @"Bad type");
    NSData *data = [NSData dataWithBytes:mat.data length:mat.elemSize()*mat.total()];
    CGColorSpaceRef colorSpace = mat.channels() == 1 ?
    CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGBitmapInfo alphaInfo = mat.channels() == 1 ?
    kCGImageAlphaNone : kCGImageAlphaNoneSkipLast;
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(mat.cols, mat.rows, mat.elemSize1()*8, mat.elemSize()*8,
                                        mat.step[0], colorSpace, alphaInfo | kCGBitmapByteOrderDefault,
                                        provider, NULL, false, kCGRenderingIntentDefault);
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    return finalImage;
}

- (id) init {
    if (self = [super init]) {
        self.cvlock=[NSLock new] ;
    }
    return self;
}

- (void) reset {
    TicToc::clearStats();
}

- (void) plotToView: (UIView *) view{
 // placeholder
}
- (void) processImage: (Mat) gray_image {
// place holder
    NSLog(@"MyVision base class does nothing");
}

- (void) processBuffer: (CMSampleBufferRef) sampleBuffer{
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
    
    int bufferWidth = static_cast<int>(CVPixelBufferGetWidth(pixelBuffer));
    int bufferHeight = static_cast<int>(CVPixelBufferGetHeight(pixelBuffer));
    unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    NSAssert(pixel != NULL, @"cannot convert pixel buffer to pointer");
    cv::Mat image_orig = cv::Mat(bufferHeight,bufferWidth,CV_8UC1,pixel); //put buffer in open cv, no memory copied
    // Put in captureOutput...
    if (self.image.rows == 0) {
        self.image = cv::Mat((int)bufferHeight,(int)bufferWidth,CV_8UC1);
    }
    {
        TICTOC all("all");
        {
            TICTOC t("copy");
            image_orig.copyTo(self.image);
        }
        {
            TICTOC t("process");
            [self processImage:self.image];
        }
    }
    //End processing
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );

}
- (void) prepareOutput {
    // placeholder
}

- (NSString *) getTimingReport {
    TicToc::Stats s = TicToc::getStatsForTag("all");
        NSString *string = [NSString stringWithFormat:@"Avg: %.0f Min: %.0f Max: %.0f",
                            (s.sum/s.count) / 1e6 ,
                            (s.min / 1e6),
                            (s.max / 1e6)];
    return string;
}

@end

@interface MyVisionAverage()
@end
@implementation MyVisionAverage
- (NSString *) getTimingReport {
    TicToc::Stats s = TicToc::getStatsForTag("all");
    NSString *string = [NSString stringWithFormat:@"Intensity: %d, Avg: %.0f Min: %.0f Max: %.0f",
                        self.intensity,
                        (s.sum/s.count) / 1e6 ,
                        (s.min / 1e6),
                        (s.max / 1e6)];
    return string;
}
- (NSInteger) getAverageIntensity: (Mat) grayImage {
    //computes mean over roi
    NSAssert(grayImage.channels()==1, @"Expecting gray scale image (single channel)");
    Scalar avgPixelIntensity = cv::mean( grayImage );
    return avgPixelIntensity.val[0];
}

- (void) processImage: (Mat) gray_image {
    self.intensity = [self getAverageIntensity:gray_image];

}

@end

@interface MyVisionBlobSize()
@property (nonatomic) cv::KeyPoint maxkp;
@property (nonatomic) UIImageView *kpImageView;
@property (nonatomic) cv::Mat output_image;
@property (nonatomic) UIImage * displayImage;
@property (nonatomic) int cv_w,cv_h;
@end
@implementation MyVisionBlobSize
- (NSString *) getTimingReport {
    NSString *string = [NSString stringWithFormat:@"Blob center (%.1f,%.1f) size %.1f",self.maxkp.pt.x,self.maxkp.pt.y,self.maxkp.size];
    return string;
};
- (id) init {
    if ([super init]) {
        self.cv_w = 180;
        self.cv_h = 120;
        self.output_image = Mat(self.cv_h,self.cv_w,CV_8UC1);
    }
    return self;
}
- (void) processImage: (Mat) gray_image {
//    float optk = 0.5;
//    float dR = 128;
//    int winw = 10;
//    int winh = 10;
//    Mat output(yuv_image->size(), CV_8UC1);
//    Binarize (*yuv_image, output, kBinarizeVersionSauvola,
//                                   winw, winh, optk, dR) ;
    
    cv::resize(gray_image,_output_image, cv::Size(self.cv_w,self.cv_h));

    cv::SimpleBlobDetector::Params params;
    params.minThreshold = 10;
    params.maxThreshold = 200;
    params.thresholdStep = 50;
    params.minDistBetweenBlobs = 50.0f;
    params.filterByInertia = false;
    params.filterByConvexity = false;
    params.filterByColor = false;
    params.filterByCircularity = false;
    params.filterByArea = true;
    params.minArea = 20.0f;
    params.maxArea = 50000.0f;
    // ... any other params you don't want default value
    
    // set up and create the detector using the parameters
    MySimpleBlobDetector blob_detector(params);
    // or cv::Ptr<cv::SimpleBlobDetector> detector = cv::SimpleBlobDetector::create(params)
    
    // detect!
    vector<cv::KeyPoint> keypoints;
    blob_detector.detect(self.output_image, keypoints);
//    NSLog(@"Found %zu blobs",keypoints.size());
    if (keypoints.size()) {
        self.maxkp = keypoints[0];
        for (size_t i=1;i<keypoints.size();i++) {
            if (self.maxkp.size < keypoints[i].size) self.maxkp = keypoints[i];
        };
    }
    
    
}
- (void) prepareOutput {
//    [self.cvlock lock];
    cv::circle(_output_image, self.maxkp.pt,10, cv::Scalar(255,255,255,255),3);
    [self setDisplayImage:[MyVision MatToUIImage: &_output_image]];
//    [self.cvlock unlock];
}

- (void) plotToView: (UIView *) view{
    if (self.kpImageView == nil) {
        self.kpImageView = [UIImageView new];
    }
    if(![[self kpImageView] isDescendantOfView:view]) {
        NSLog(@"Adding image view for cv preview");
        [view addSubview: self.kpImageView];
        [self.kpImageView setFrame:[view bounds]];
        self.kpImageView.contentMode = UIViewContentModeBottomLeft; // This determines position of image
        self.kpImageView.clipsToBounds = YES;
    }
    [self.kpImageView setContentMode:UIViewContentModeScaleAspectFill];
    [self.kpImageView setClipsToBounds:YES];
    [self.kpImageView setImage:self.displayImage];
    
}
@end
