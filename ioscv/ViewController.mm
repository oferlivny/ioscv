//
//  ViewController.m
//  ioscv
//
//  Created by Ofer Livny on 5/4/15.
//  Copyright (c) 2015 Ofer Livny. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>


@class AVCaptureSession;
@interface AVCamPreviewView : UIView
@property (nonatomic) AVCaptureSession *session;
@end

@implementation AVCamPreviewView
+ (Class)layerClass{return [AVCaptureVideoPreviewLayer class];}
- (AVCaptureSession *)session{return [(AVCaptureVideoPreviewLayer *)[self layer] session];}
- (void)setSession:(AVCaptureSession *)session{[(AVCaptureVideoPreviewLayer *)[self layer] setSession:session];}
@end


@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>




@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureVideoDataOutput *videoDeviceOutput;
@property (nonatomic) NSDictionary *camerasDict;

@property (nonatomic) AVCamPreviewView *previewView;

@end


@implementation ViewController

- (void) startSession {
    // Start capture session
    // set up error and notification handling
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
                                                         multiplier:0.5
                                                           constant:0]];
    
    // Height constraint, half of parent view height
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.previewView
                                                          attribute:NSLayoutAttributeHeight
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeHeight
                                                         multiplier:0.5
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
}
                   
- (void)viewDidLoad {
    [super viewDidLoad];
    // Start capture session
    [self initSession];
    
}

- (void) viewWillAppear:(BOOL)animated {
}

- (void) viewDidAppear:(BOOL)animated {
    [self startSession];
}

- (void) viewDidDisappear:(BOOL)animated {
    [self stopSession];
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
    NSLog(@"capture output start");
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
    
    int bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
    int bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
    unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    cv::Mat image = cv::Mat(bufferHeight,bufferWidth,CV_8UC1,pixel); //put buffer in open cv, no memory copied
    //Processing here
    NSInteger intensity = [self getAverageIntensity:&image];
    //End processing
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
    NSLog(@"Intensity: %d, Image size: %dx%d",intensity, bufferWidth,bufferHeight);


}
- (void)captureOutput:(AVCaptureOutput *)captureOutput
  didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    NSLog(@"capture drop");
}

@end
