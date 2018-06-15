
#import "RCTBarcode.h"
#import "RCTBarcodeManager.h"



@interface RCTBarcodeManager ()

@end

@implementation RCTBarcodeManager

RCT_EXPORT_MODULE(RCTBarcode)

RCT_EXPORT_VIEW_PROPERTY(scannerRectWidth, NSInteger)

RCT_EXPORT_VIEW_PROPERTY(scannerRectHeight, NSInteger)

RCT_EXPORT_VIEW_PROPERTY(scannerRectTop, NSInteger)

RCT_EXPORT_VIEW_PROPERTY(scannerRectLeft, NSInteger)

RCT_EXPORT_VIEW_PROPERTY(scannerLineInterval, NSInteger)

RCT_EXPORT_VIEW_PROPERTY(scannerRectCornerColor, NSString)

RCT_EXPORT_VIEW_PROPERTY(onBarCodeRead, RCTBubblingEventBlock)

RCT_CUSTOM_VIEW_PROPERTY(barCodeTypes, NSArray, RCTBarcode) {
    self.barCodeTypes = [RCTConvert NSArray:json];
}

- (UIView *)view
{
    self.session = [[AVCaptureSession alloc]init];
#if !(TARGET_IPHONE_SIMULATOR)
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
//    self.previewLayer.needsDisplayOnBoundsChange = YES;
    #endif
    
    if(!self.barcode){
        self.barcode = [[RCTBarcode alloc] initWithManager:self];
        [self.barcode setClipsToBounds:YES];
    }
    
    SystemSoundID beep_sound_id;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"beep" ofType:@"wav"];
    if (path) {
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:path],&beep_sound_id);
        self.beep_sound_id = beep_sound_id;
    }
    
    return self.barcode;
}
- (dispatch_queue_t)sessionQueue{
    if (_sessionQueue == nil) {
        _sessionQueue = dispatch_queue_create("barCodeManagerQueue", DISPATCH_QUEUE_SERIAL);
    }
    return _sessionQueue;
}

- (void)initializeCaptureSessionInput:(NSString *)type {
    
    
    dispatch_async(self.sessionQueue, ^{
    
        [self.session beginConfiguration];
        
        NSError *error = nil;

        AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        if (captureDevice == nil) {
            return;
        }
        
        AVCaptureDeviceInput *captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
        
        if (error || captureDeviceInput == nil) {
            return;
        }
        
        [self.session removeInput:self.videoCaptureDeviceInput];

        
        if ([self.session canAddInput:captureDeviceInput]) {
            
            
            [self.session addInput:captureDeviceInput];
            
            self.videoCaptureDeviceInput = captureDeviceInput;
        }
        
        [self.session commitConfiguration];
    });
}

RCT_EXPORT_METHOD(startSession) {
    #if TARGET_IPHONE_SIMULATOR
    return;
    #endif
    dispatch_async(self.sessionQueue, ^{
        
        if(self.metadataOutput == nil) {
            
            AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
            self.metadataOutput = metadataOutput;
        
            if ([self.session canAddOutput:self.metadataOutput]) {
                [self.metadataOutput setMetadataObjectsDelegate:self queue:self.sessionQueue];
                [self.session addOutput:self.metadataOutput];
                if ([self.barCodeTypes isKindOfClass:[NSNull class]]) {
                    self.barCodeTypes = @[@"org.gs1.EAN-13"];
                }
                [self.metadataOutput setMetadataObjectTypes:self.barCodeTypes];
            }
        }
        
        [self.session startRunning];
        
        NSLog(@"开始了");
        if(self.barcode.scanLineTimer != nil) {
            //设回当前时间模拟继续效果
            [self.barcode.scanLineTimer setFireDate:[NSDate date]];
        }
        
    });
}

RCT_EXPORT_METHOD(stopSession) {
    #if TARGET_IPHONE_SIMULATOR
    return;
    #endif
    dispatch_async(self.sessionQueue, ^{
        
        [self.session commitConfiguration];
        [self.session stopRunning];
        NSLog(@"停止了");
        
        //设置大时刻来模拟暂停效果
        [self.barcode.scanLineTimer setFireDate:[NSDate distantFuture]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0),
                       dispatch_get_main_queue(),
                       ^{
                           [self.barcode.scanLine.layer removeAllAnimations];
                       });

    });
}

- (void)endSession {
    #if TARGET_IPHONE_SIMULATOR
    return;
    #endif
    dispatch_async(self.sessionQueue, ^{
        self.barcode = nil;
        [self.previewLayer removeFromSuperlayer];
        [self.session commitConfiguration];
        [self.session stopRunning];
        [self.barcode.scanLineTimer invalidate];
        self.barcode.scanLineTimer = nil;
        for(AVCaptureInput *input in self.session.inputs) {
            [self.session removeInput:input];
        }

        for(AVCaptureOutput *output in self.session.outputs) {
            [self.session removeOutput:output];
        }
        self.metadataOutput = nil;
    });
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    for (AVMetadataMachineReadableCodeObject *metadata in metadataObjects) {
        for (id barcodeType in self.barCodeTypes) {
            if ([metadata.type isEqualToString:barcodeType]) {
                if (!self.barcode.onBarCodeRead) {
                    return;
                }
                
                AudioServicesPlaySystemSound(self.beep_sound_id);
                self.barcode.onBarCodeRead(@{
                                              @"data": @{
                                                        @"type": metadata.type,
                                                        @"code": metadata.stringValue,
                                              },
                                            });
            }
        }
    }
}



@end
