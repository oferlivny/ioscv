//
//  ViewController.m
//  ioscv
//
//  Created by Ofer Livny on 5/4/15.
//  Copyright (c) 2015 Ofer Livny. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()


@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureVideoDataOutput *videoDeviceOutput;
@property (nonatomic) NSDictionary *camerasDict;

@end

@implementation ViewController

- (void) initCamerasDict {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    self.camerasDict = [NSDictionary dictionary];
    AVCaptureDevice *back,*front;
    for (AVCaptureDevice *device in devices) {
        NSLog(@"Device name: %@", [device localizedName]);
        if ([device position] == AVCaptureDevicePositionBack) {
            NSLog(@"Device position : back");
            back = device;
            [self.camerasDict setValue:device forKey:@"BackCamera"];
        }
        else {
            NSLog(@"Device position : front");
            front = device;
            [self.camerasDict setValue:device forKey:@"FrontCamera"];
        }
    }
    self.camerasDict = [NSDictionary dictionaryWithObjectsAndKeys:back,@"BackCamera", front,@"FrontCamera", nil];
}

- (void) initCamera {
    NSError *error = nil;
    
    // Initialize video sensor dictionary
    [self initCamerasDict];
    
    // Make the back cam as an input device
    self.videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:[self.camerasDict valueForKey:@"BackCamera"] error:&error];
    
    if (error)
    {
        NSLog(@"%@", error);
    }
    
    // Add this input to our session
    if ([self.session canAddInput:self.videoDeviceInput])
    {
        [self.session addInput:self.videoDeviceInput];
    }
    
    // Declare a video data output
    self.videoDeviceOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    // Add this output to our session
    if ([self.session canAddOutput:self.videoDeviceOutput])
    {
        [self.session addOutput:self.videoDeviceOutput];
        AVCaptureConnection *connection = [self.videoDeviceOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([connection isVideoStabilizationSupported])
            [connection setEnablesVideoStabilizationWhenAvailable:YES];
    }
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
}
                   
- (void)viewDidLoad {
    [super viewDidLoad];
    // Start capture session
    [self initSession];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
