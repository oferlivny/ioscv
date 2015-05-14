//
//  ViewController.m
//  ioscv
//
//  Created by Ofer Livny on 5/4/15.
//  Copyright (c) 2015 Ofer Livny. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "MyVision.h"

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


@property (nonatomic) long dropped, total;


@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureVideoDataOutput *videoDeviceOutput;
@property (nonatomic) NSDictionary *camerasDict;

@property (nonatomic) AVCamPreviewView *previewView;
@property (nonatomic) UILabel *labelVision, *labelCapture;
@property (nonatomic) UISlider *sliderAction;
@property (nonatomic) UISegmentedControl *taskSelect;
@property (nonatomic) UIView *cvview;

// Make sure only one display requested is queued at a time
@property (nonatomic) bool pendingPlot;

@property (nonatomic) VisionTask task;
@property (nonatomic) MyVision *vision;

@end


@implementation ViewController

- (void) startSession {
    // Start capture session
    // set up error and notification handling
    self.dropped = 0;
    self.total = 0;
    
    [self.vision reset];

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
    [self setVideoDeviceOutput: [AVCaptureVideoDataOutput new]];
    
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

- (void) initLabels {
    // vision label
    UILabel *label = [UILabel new];
    [self setLabelVision: label];
    [self.view addSubview:label];
    [label setAdjustsFontSizeToFitWidth:YES];
    [label setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeWidth multiplier:1 constant:50]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [label setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.3]];
    
    // capture label
    label = [UILabel new];
    [self setLabelCapture: label];
    [self.view addSubview:label];
    [label setAdjustsFontSizeToFitWidth:YES];
    [label setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeWidth multiplier:1 constant:50]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.labelVision attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [label setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.3]];
    
}

- (void) initSlider {
    UISlider *slider = [UISlider new];
    [self.view addSubview:slider];
    [self setSliderAction: slider];
    [slider setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:slider attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:slider attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:Nil attribute:NSLayoutAttributeWidth multiplier:1 constant:50]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:slider attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:slider attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.labelCapture attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [slider setMinimumValue:0];
    [slider setMaximumValue:2];
    [slider setContinuous:NO];
    [slider setValue:0];
    [slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [slider setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.3]];

    
}

- (void) initSegmentedControl {
    UISegmentedControl *segCtrl = [UISegmentedControl new];
    [self.view addSubview:segCtrl];
    [self setTaskSelect: segCtrl];
    [segCtrl setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:segCtrl attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:segCtrl attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:Nil attribute:NSLayoutAttributeWidth multiplier:1 constant:50]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:segCtrl attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:segCtrl attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.labelCapture attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [segCtrl insertSegmentWithTitle:@"None" atIndex:0 animated:NO];
    [segCtrl insertSegmentWithTitle:@"Average" atIndex:1 animated:NO];
    [segCtrl insertSegmentWithTitle:@"BlobSize" atIndex:2 animated:NO];
    [segCtrl setSelectedSegmentIndex:0];
    [segCtrl addTarget:self action:@selector(taskSelectValueChanged:) forControlEvents:UIControlEventValueChanged];
    [segCtrl setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.3]];
    
    
}

- (IBAction)sliderValueChanged:(UISlider *)sender {
    NSUInteger index = (NSUInteger)(sender.value + 0.5);
    [sender setValue:index animated:NO];
    NSLog(@"slider value = %f", sender.value);
    [self initVisionWithValue: index];
}
- (IBAction)taskSelectValueChanged:(UISegmentedControl *)sender {
    NSLog(@"slider value = %d", sender.selectedSegmentIndex);
    [self initVisionWithValue: sender.selectedSegmentIndex];
}
- (void) initCVView {
    UIView *view = [UIView new];
    [self.view addSubview:view];
    [self setCvview:view];
    [view setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:view
                                                          attribute:NSLayoutAttributeWidth
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeWidth
                                                         multiplier:0.25
                                                           constant:0]];
    
    // Height constraint, half of parent view height
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:view
                                                          attribute:NSLayoutAttributeHeight
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeHeight
                                                         multiplier:0.25
                                                           constant:0]];
    
    // Center horizontally
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:view
                                                          attribute:NSLayoutAttributeCenterX
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeCenterX
                                                         multiplier:0.5
                                                           constant:0.0]];
    
    // Center vertically
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:view
                                                          attribute:NSLayoutAttributeCenterY
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeCenterY
                                                         multiplier:0.5
                                                           constant:0.0]];
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
    AVCaptureSession *session = [AVCaptureSession new];
    [self setSession:session];

    // Create the dispatch queue
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    [self setSessionQueue:sessionQueue];
    
    // Start working at the context of the video capture
    dispatch_async(sessionQueue, ^{
        [self initCamera];
    });
    

}

- (void) initVisionWithValue: (NSInteger) value {
    if (self.task != (VisionTask) value) {
        [self setTask:(VisionTask) value];
        [self initVision];
    }
}

- (void) initVision {
    switch (self.task) {
        case kVisionTaskNone:
            self.vision = [MyVision new];
            break;
        case kVisionTaskAverage:
            self.vision = [MyVisionAverage new];
            break;
        case kVisionTaskLargestBlobSize:
            self.vision = [MyVisionBlobSize new];
            break;
        default:
            NSLog(@"Bad task!");
            break;
    };
    [self.vision reset];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setPendingPlot:NO];
    self.task = kVisionTaskNone;
    // Start capture session
    [self initSession];
    [self initPreview];
    [self initLabels];
//    [self initSlider];
    [self initSegmentedControl];
    [self initVision];
    [self initCVView];

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



- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    if (sampleBuffer == nil) {
        NSLog(@"Warning! Bad sample buffer!");
        return;
    } 
    [self.vision processBuffer:sampleBuffer];
    NSString *str_vision = [self.vision getTimingReport];
    NSString *str_capture = [NSString stringWithFormat:@"%ld captured %ld dropped", self.total,self.dropped];
    if (!self.pendingPlot) {
        [self.vision prepareOutput]; 
        [self setPendingPlot: YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.labelVision setText:str_vision];
            [self.labelCapture setText:str_capture];
            [self.vision plotToView:self.cvview];
            [self setPendingPlot: NO];
        });
    };

    self.total++;
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
