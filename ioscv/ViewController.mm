//
//  ViewController.m
//  ioscv
//
//  Created by Ofer Livny on 5/4/15.
//  Copyright (c) 2015 Ofer Livny. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#include "TicToc.h"


@class AVCaptureSession;
@interface AVCamPreviewView : UIView
@property (nonatomic) AVCaptureSession *session;
@end

@implementation AVCamPreviewView
+ (Class)layerClass{return [AVCaptureVideoPreviewLayer class];}
- (AVCaptureSession *)session{return [(AVCaptureVideoPreviewLayer *)[self layer] session];}
- (void)setSession:(AVCaptureSession *)session{
    ((AVPlayerLayer *)[self layer]).videoGravity = AVLayerVideoGravityResizeAspectFill;
    ((AVPlayerLayer *)[self layer]).bounds = ((AVPlayerLayer *)[self layer]).bounds;
    [(AVCaptureVideoPreviewLayer *)[self layer] setSession:session];
}
@end


@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>


// Add to interface
@property (nonatomic) cv::Mat image;
@property (nonatomic) long dropped, total;


@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureVideoDataOutput *videoDeviceOutput;
@property (nonatomic) NSDictionary *camerasDict;

@property (nonatomic) AVCamPreviewView *previewView;
@property (nonatomic) UILabel *label;

@end


@implementation ViewController

- (void) startSession {
    // Start capture session
    // set up error and notification handling
    self.dropped = 0;
    self.total = 0;
    
    dispatch_async([self sessionQueue], ^{
        [[self session] startRunning];
    });
}

- (void) stopSession {
    // Stop capture session
    // remove error and notification handling
    dispatch_async([self sessionQueue], ^{
        [[self session] stopRunning];
    });
    
    NSLog(@"Total frames: %ld Dropped: %ld", self.total, self.dropped);
    TicToc::coutStats();

}


- (void) initCamerasDict {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *back,*front;
    for (AVCaptureDevice *device in devices) {
        NSLog(@"Device name: %@", [device localizedName]);
        if ([device position] == AVCaptureDevicePositionBack) {
            NSLog(@"Device position : back");
            back = device;
        }
        else {
            NSLog(@"Device position : front");
            front = device;
        }
    }
    [self setCamerasDict: [NSDictionary dictionaryWithObjectsAndKeys:back,@"BackCamera", front,@"FrontCamera", nil]];
}

- (void) initCamera {
    NSError *error = nil;
    
    // Initialize video sensor dictionary
    [self initCamerasDict];
    
    // Make the back cam as an input device
    [self setVideoDeviceInput: [AVCaptureDeviceInput deviceInputWithDevice:[self.camerasDict valueForKey:@"BackCamera"] error:&error]];
    
    if (error)
    {
        NSLog(@"%@", error);
    }
    
    // Add this input to our session
    if ([[self session] canAddInput:self.videoDeviceInput])
    {
        [[self session] addInput:self.videoDeviceInput];
    }
    
    // Declare a video data output
    [self setVideoDeviceOutput: [[AVCaptureVideoDataOutput alloc] init]];
    
    NSArray *pixfmts = [[self videoDeviceOutput] availableVideoCVPixelFormatTypes];
    for (NSNumber *n in pixfmts) {
        int fmt = [n intValue];
        char *fmtc = (char *)&fmt;
        NSLog(@"fmt: %c%c%c%c", fmtc[3],fmtc[2],fmtc[1],fmtc[0]);
    }

    // Add this output to our session
    if ([[self session] canAddOutput:self.videoDeviceOutput])
    {
        [[self session] addOutput:self.videoDeviceOutput];
        AVCaptureConnection *connection = [[self videoDeviceOutput] connectionWithMediaType:AVMediaTypeVideo];
        if ([connection isVideoStabilizationSupported])
            [connection setEnablesVideoStabilizationWhenAvailable:YES];
        
        // Set self as delegate for new buffers
        [self.videoDeviceOutput setSampleBufferDelegate:self queue:self.sessionQueue];
    }
}

- (void) initLabel {
    UILabel *label = [[UILabel alloc]init];
    [self setLabel: label];
    [self.view addSubview:label];
    [self.label setAdjustsFontSizeToFitWidth:YES];
    [self.label setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.label attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.label attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:0.5 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.label attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.label attribute:NSLayoutAttributeBaseline relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBaseline multiplier:1 constant:0]];
    [self.label setText:@"Test"];
    
    
}
- (void) initPreview {
    // Setup the preview view
    CGRect applicationFrame = [[UIScreen mainScreen] applicationFrame];
    [self setPreviewView: [[AVCamPreviewView alloc] initWithFrame:applicationFrame]];
    [self.view addSubview:self.previewView];
    [self.previewView setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    // Width constraint, half of parent view width
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.previewView
                                                          attribute:NSLayoutAttributeWidth
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeWidth
                                                         multiplier:1.0
                                                           constant:0]];
    
    // Height constraint, half of parent view height
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.previewView
                                                          attribute:NSLayoutAttributeHeight
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeHeight
                                                         multiplier:1.0
                                                           constant:0]];
    
    // Center horizontally
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.previewView
                                                          attribute:NSLayoutAttributeCenterX
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeCenterX
                                                         multiplier:1.0
                                                           constant:0.0]];
    
    // Center vertically
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.previewView
                                                          attribute:NSLayoutAttributeCenterY
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeCenterY
                                                         multiplier:1.0
                                                           constant:0.0]];

    [[self previewView] setSession:self.session];

}

- (void) initSession {
    // Create the AVCaptureSession
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    [self setSession:session];

    // Create the dispatch queue
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    [self setSessionQueue:sessionQueue];
    
    // Start working at the context of the video capture
    dispatch_async(sessionQueue, ^{
        [self initCamera];
    });
    
    [self initPreview];
    [self initLabel];
}
                   
- (void)viewDidLoad {
    [super viewDidLoad];
    // Start capture session
    [self initSession];
    
}

-(void)appWillResignActive:(NSNotification*)note
{
    [self stopSession];
}

- (void) viewWillAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];

}

- (void) viewDidAppear:(BOOL)animated {
    [self startSession];
}

- (void) viewWillDisappear:(BOOL)animated {
    [self stopSession];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
}
- (void) viewDidDisappear:(BOOL)animated {

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (NSInteger) getAverageIntensity: (cv::Mat *) grayImage {
    //computes mean over roi
    NSAssert(grayImage->channels()==1, @"Expecting gray scale image (single channel)");
    cv::Scalar avgPixelIntensity = cv::mean( *grayImage );
    return avgPixelIntensity.val[0];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
    
    int bufferWidth = static_cast<int>(CVPixelBufferGetWidth(pixelBuffer));
    int bufferHeight = static_cast<int>(CVPixelBufferGetHeight(pixelBuffer));
    unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    cv::Mat image_orig = cv::Mat(bufferHeight,bufferWidth,CV_8UC1,pixel); //put buffer in open cv, no memory copied
    // Put in captureOutput...
    if (_image.rows == 0) {
        _image = cv::Mat((int)bufferHeight,(int)bufferWidth,CV_8UC1);
    }
    //    [IOS_Neon neon_memcpy:image.ptr() to:image_copy.ptr() size:image.step*image.rows];
    
//    SW_START("copy");
    NSInteger intensity;
    {
        TICTOC all("all");
        {
            TICTOC t("copy");
            image_orig.copyTo(self.image);
        }
        
        {
            TICTOC t("avg");
            intensity = [self getAverageIntensity:&_image];
        }
    }
//    SW_STOP("getAverage");
    
    //End processing
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
//    NSLog(@"Intensity: %ld, Image size: %dx%d",intensity, bufferWidth,bufferHeight);

    TicToc::Stats s = TicToc::getStatsForTag("all");
    NSString *string = [NSString stringWithFormat:@"Avg: %.0f Min: %.0f Max: %.0f | Total / Dropped %ld/%ld",
                        s.sum/s.count / 1e6 ,
                        s.min / 1e6, s.max / 1e6,
                        self.total, self.dropped];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.label setText:string];
    });

    self.total++;
    if (self.total % 100 == 0) {
        TicToc::coutStats();
    }
}
- (void)captureOutput:(AVCaptureOutput *)captureOutput
  didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    NSLog(@"capture drop");
    self.dropped++;
    self.total++;
}

@end
