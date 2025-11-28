//
//  ImageDeformViewController.m
//  cgeDemo
//
//  Created on 2024-11-28
//  Description: Demo view controller for image deformation/liquify feature
//

#import "ImageDeformViewController.h"
#import "cgeDeformFilterWrapper.h"
#import "cgeImageViewHandler.h"
#import "cgeUtilFunctions.h"
#import "demoUtils.h"
#import "cgeImageHandlerIOS.h"
#include "cgeMultipleEffects.h"

typedef NS_ENUM(NSInteger, DeformMode) {
    DeformModeRestore,
    DeformModeForward,
    DeformModeBloat,
    DeformModeWrinkle
};

@interface ImageDeformViewController() <UINavigationControllerDelegate, UIImagePickerControllerDelegate>
{
    CGEImageHandlerIOS* _imageHandler;
    CGEDeformFilterWrapper* _deformWrapper;
    DeformMode _deformMode;
    CGFloat _touchRadius;
    CGFloat _touchIntensity;
    CGPoint _lastTouchPoint;
    BOOL _isMoving;
    BOOL _hasMotion;
    BOOL _showMesh;
}

@property (nonatomic, strong) GLKView* glkView;
@property (nonatomic, strong) CGESharedGLContext* sharedContext;
@property (nonatomic, strong) UISlider* restoreSlider;
@property (nonatomic, strong) UIScrollView* buttonScrollView;
@property (nonatomic, strong) UIImage* currentImage;
@property (nonatomic) CGRect viewArea;
@property (nonatomic) CGSize imageSize;

@end

@implementation ImageDeformViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    // Default values
    _deformMode = DeformModeForward;
    _touchRadius = 100.0f;
    _touchIntensity = 0.15f;
    _showMesh = NO;
    _isMoving = NO;
    _hasMotion = NO;
    
    // Setup shared context
    _sharedContext = [CGESharedGLContext createGlobalSharedContext];
    
    // Setup UI
    [self setupUI];
    
    // Load default image
    UIImage* defaultImage = [UIImage imageNamed:@"test2.jpg"];
    if (defaultImage) {
        [self setImage:defaultImage];
    }
}

- (void)setupUI {
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    
    // Quit button
    UIButton* quitBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [quitBtn setTitle:@"Quit" forState:UIControlStateNormal];
    [quitBtn setFrame:CGRectMake(20, 50, 50, 30)];
    [quitBtn addTarget:self action:@selector(quitBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:quitBtn];
    
    // Restore slider
    _restoreSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, 90, screenRect.size.width - 40, 30)];
    _restoreSlider.minimumValue = 0.0f;
    _restoreSlider.maximumValue = 1.0f;
    _restoreSlider.value = 0.0f;
    [_restoreSlider addTarget:self action:@selector(restoreSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_restoreSlider];
    
    // GLKView for rendering
    CGFloat glkViewY = 130;
    CGFloat buttonScrollHeight = 60;
    CGFloat glkViewHeight = screenRect.size.height - glkViewY - buttonScrollHeight - 20;
    
    _glkView = [[GLKView alloc] initWithFrame:CGRectMake(0, glkViewY, screenRect.size.width, glkViewHeight)];
    [_glkView setDrawableColorFormat:GLKViewDrawableColorFormatRGBA8888];
    [_glkView setContext:[[CGESharedGLContext globalGLContext] context]];
    [_glkView setEnableSetNeedsDisplay:NO];
    [_glkView setBackgroundColor:[UIColor blackColor]];
    [self.view addSubview:_glkView];
    
    // Add touch gesture to GLKView
    UIPanGestureRecognizer* panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    [_glkView addGestureRecognizer:panGesture];
    
    // Button scroll view at the bottom
    _buttonScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, screenRect.size.height - buttonScrollHeight - 10, screenRect.size.width, buttonScrollHeight)];
    _buttonScrollView.showsHorizontalScrollIndicator = YES;
    [self.view addSubview:_buttonScrollView];
    
    // Create buttons
    NSArray* buttonTitles = @[@"Gallery", @"Save", @"Restore", @"Forward", @"RestoreMode", @"Bloat", @"Wrinkle", @"Undo", @"Redo", @"R+", @"R-", @"I+", @"I-", @"Mesh"];
    NSArray* buttonSelectors = @[@"galleryBtnClicked:", @"saveBtnClicked:", @"restoreBtnClicked:", @"forwardModeBtnClicked:", @"restoreModeBtnClicked:", @"bloatModeBtnClicked:", @"wrinkleModeBtnClicked:", @"undoBtnClicked:", @"redoBtnClicked:", @"radiusIncClicked:", @"radiusDecClicked:", @"intensityIncClicked:", @"intensityDecClicked:", @"showMeshBtnClicked:"];
    
    CGFloat buttonWidth = 80;
    CGFloat buttonHeight = 40;
    CGFloat xOffset = 10;
    
    for (NSUInteger i = 0; i < buttonTitles.count; i++) {
        UIButton* btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:buttonTitles[i] forState:UIControlStateNormal];
        [btn setFrame:CGRectMake(xOffset, 10, buttonWidth, buttonHeight)];
        [btn.layer setBorderColor:[UIColor blueColor].CGColor];
        [btn.layer setBorderWidth:1.0f];
        [btn.layer setCornerRadius:8.0f];
        [btn addTarget:self action:NSSelectorFromString(buttonSelectors[i]) forControlEvents:UIControlEventTouchUpInside];
        [_buttonScrollView addSubview:btn];
        xOffset += buttonWidth + 10;
    }
    
    _buttonScrollView.contentSize = CGSizeMake(xOffset, buttonHeight);
}

- (void)setImage:(UIImage*)image {
    if (image == nil) return;
    
    _currentImage = image;
    _imageSize = image.size;
    
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        
        // Clean up existing handler
        if (_imageHandler != nullptr) {
            delete _imageHandler;
            _imageHandler = nullptr;
        }
        
        // Release existing deform wrapper
        if (_deformWrapper != nil) {
            [_deformWrapper releaseWithDeleteNativeFilter:YES];
            _deformWrapper = nil;
        }
        
        // Create new handler
        _imageHandler = new CGE::CGEImageHandlerIOS();
        if (!_imageHandler->initWithUIImage(image, true, true)) {
            delete _imageHandler;
            _imageHandler = nullptr;
            NSLog(@"Failed to initialize image handler");
            return;
        }
        
        CGE::TextureDrawer* drawer = _imageHandler->getResultDrawer();
        if (drawer != nullptr) {
            drawer->setFlipScale(1.0f, -1.0f);
        }
        
        // Create deform wrapper with scaled size
        int w = (int)image.size.width;
        int h = (int)image.size.height;
        float scaling = MIN(1280.0f / w, 1280.0f / h);
        if (scaling < 1.0f) {
            w = (int)(w * scaling);
            h = (int)(h * scaling);
        }
        
        _deformWrapper = [CGEDeformFilterWrapper createWithWidth:w height:h stride:10.0f];
        if (_deformWrapper) {
            [_deformWrapper setUndoSteps:200];
            
            // Add filter to handler
            CGE::CGEMutipleEffectFilter* filter = new CGE::CGEMutipleEffectFilter();
            filter->setTextureLoadFunction(cgeGlobalTextureLoadFunc, nullptr);
            filter->initCustomize();
            filter->addFilter((CGE::CGEImageFilterInterface*)[_deformWrapper nativeAddress]);
            _imageHandler->addImageFilter(filter);
            _imageHandler->processingFilters();
        }
    }];
    
    [self updateViewArea];
    [self renderImage];
}

- (void)updateViewArea {
    float viewWidth = _glkView.frame.size.width * [UIScreen mainScreen].scale;
    float viewHeight = _glkView.frame.size.height * [UIScreen mainScreen].scale;
    
    float scaling = _imageSize.width / _imageSize.height;
    float viewRatio = viewWidth / viewHeight;
    float s = scaling / viewRatio;
    
    float w, h;
    if (s < 1.0) {
        w = viewHeight * scaling;
        h = viewHeight;
    } else {
        w = viewWidth;
        h = viewWidth / scaling;
    }
    
    _viewArea = CGRectMake((viewWidth - w) / 2, (viewHeight - h) / 2, w, h);
}

- (void)renderImage {
    if (_imageHandler == nullptr) return;
    
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        
        [_glkView bindDrawable];
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        if (_imageHandler->getTargetTextureID() != 0) {
            glViewport(_viewArea.origin.x, _viewArea.origin.y, _viewArea.size.width, _viewArea.size.height);
            _imageHandler->drawResult();
        }
        
        [_glkView display];
    }];
}

- (CGPoint)convertTouchPointToImageCoordinates:(CGPoint)touchPoint {
    float scale = [UIScreen mainScreen].scale;
    float viewWidth = _glkView.frame.size.width * scale;
    float viewHeight = _glkView.frame.size.height * scale;
    
    // Convert to OpenGL coordinates (flip Y)
    float x = touchPoint.x * scale - _viewArea.origin.x;
    float y = (viewHeight - touchPoint.y * scale) - _viewArea.origin.y;
    
    return CGPointMake(x, y);
}

#pragma mark - Touch Handling

- (void)handlePanGesture:(UIPanGestureRecognizer*)gesture {
    if (_deformWrapper == nil) return;
    
    CGPoint touchPoint = [gesture locationInView:_glkView];
    CGPoint imagePoint = [self convertTouchPointToImageCoordinates:touchPoint];
    
    float w = _viewArea.size.width;
    float h = _viewArea.size.height;
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            _isMoving = YES;
            _lastTouchPoint = imagePoint;
            if (![_deformWrapper canUndo]) {
                [_deformWrapper pushDeformStep];
            }
            break;
            
        case UIGestureRecognizerStateChanged: {
            if (_restoreSlider.value != 0) {
                [_restoreSlider setValue:0 animated:NO];
            }
            
            [_sharedContext syncProcessingQueue:^{
                [_sharedContext makeCurrent];
                
                switch (_deformMode) {
                    case DeformModeRestore:
                        [_deformWrapper restoreWithPointX:imagePoint.x y:imagePoint.y width:w height:h radius:_touchRadius intensity:_touchIntensity];
                        break;
                    case DeformModeForward:
                        [_deformWrapper forwardDeformWithStartX:_lastTouchPoint.x startY:_lastTouchPoint.y endX:imagePoint.x endY:imagePoint.y width:w height:h radius:_touchRadius intensity:_touchIntensity];
                        break;
                    case DeformModeBloat:
                        [_deformWrapper bloatDeformWithX:imagePoint.x y:imagePoint.y width:w height:h radius:_touchRadius intensity:_touchIntensity];
                        break;
                    case DeformModeWrinkle:
                        [_deformWrapper wrinkleDeformWithX:imagePoint.x y:imagePoint.y width:w height:h radius:_touchRadius intensity:_touchIntensity];
                        break;
                }
                
                _imageHandler->revertToKeptResult();
                _imageHandler->processingFilters();
                _hasMotion = YES;
            }];
            
            [self renderImage];
            _lastTouchPoint = imagePoint;
            break;
        }
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            _isMoving = NO;
            if (_hasMotion) {
                [_sharedContext syncProcessingQueue:^{
                    [_deformWrapper pushDeformStep];
                }];
                _hasMotion = NO;
            }
            break;
            
        default:
            break;
    }
}

#pragma mark - Button Actions

- (void)quitBtnClicked:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)restoreSliderChanged:(UISlider*)slider {
    if (_deformWrapper == nil) return;
    
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        [_deformWrapper restoreWithIntensity:slider.value];
        _imageHandler->revertToKeptResult();
        _imageHandler->processingFilters();
    }];
    
    [self renderImage];
}

- (void)galleryBtnClicked:(id)sender {
    UIImagePickerController* picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    picker.delegate = self;
    picker.allowsEditing = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)saveBtnClicked:(id)sender {
    if (_imageHandler == nullptr) return;
    
    __block UIImage* resultImage = nil;
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        resultImage = _imageHandler->getResultUIImage();
    }];
    
    if (resultImage) {
        [DemoUtils saveImage:resultImage];
        [self showToast:@"Image saved!"];
    }
}

- (void)restoreBtnClicked:(id)sender {
    if (_deformWrapper == nil) return;
    
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        [_deformWrapper restore];
        _imageHandler->revertToKeptResult();
        _imageHandler->processingFilters();
    }];
    
    [self renderImage];
    [self showToast:@"Restored to original"];
}

- (void)forwardModeBtnClicked:(id)sender {
    _deformMode = DeformModeForward;
    [self showToast:@"Forward mode"];
}

- (void)restoreModeBtnClicked:(id)sender {
    _deformMode = DeformModeRestore;
    [self showToast:@"Restore mode"];
}

- (void)bloatModeBtnClicked:(id)sender {
    _deformMode = DeformModeBloat;
    [self showToast:@"Bloat mode"];
}

- (void)wrinkleModeBtnClicked:(id)sender {
    _deformMode = DeformModeWrinkle;
    [self showToast:@"Wrinkle mode"];
}

- (void)undoBtnClicked:(id)sender {
    if (_deformWrapper == nil) return;
    
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        if ([_deformWrapper undo]) {
            _imageHandler->revertToKeptResult();
            _imageHandler->processingFilters();
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"Nothing to undo"];
            });
        }
    }];
    
    [self renderImage];
}

- (void)redoBtnClicked:(id)sender {
    if (_deformWrapper == nil) return;
    
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        if ([_deformWrapper redo]) {
            _imageHandler->revertToKeptResult();
            _imageHandler->processingFilters();
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"Nothing to redo"];
            });
        }
    }];
    
    [self renderImage];
}

- (void)radiusIncClicked:(id)sender {
    _touchRadius += 20.0f;
    if (_touchRadius > 400.0f) _touchRadius = 400.0f;
    [self showToast:[NSString stringWithFormat:@"Radius: %.0f", _touchRadius]];
}

- (void)radiusDecClicked:(id)sender {
    _touchRadius -= 20.0f;
    if (_touchRadius < 20.0f) _touchRadius = 20.0f;
    [self showToast:[NSString stringWithFormat:@"Radius: %.0f", _touchRadius]];
}

- (void)intensityIncClicked:(id)sender {
    _touchIntensity += 0.05f;
    if (_touchIntensity > 0.9f) _touchIntensity = 0.9f;
    [self showToast:[NSString stringWithFormat:@"Intensity: %.2f", _touchIntensity]];
}

- (void)intensityDecClicked:(id)sender {
    _touchIntensity -= 0.05f;
    if (_touchIntensity < 0.02f) _touchIntensity = 0.02f;
    [self showToast:[NSString stringWithFormat:@"Intensity: %.2f", _touchIntensity]];
}

- (void)showMeshBtnClicked:(id)sender {
    _showMesh = !_showMesh;
    
    [_sharedContext syncProcessingQueue:^{
        [_sharedContext makeCurrent];
        [_deformWrapper showMesh:_showMesh];
        _imageHandler->revertToKeptResult();
        _imageHandler->processingFilters();
    }];
    
    [self renderImage];
    [self showToast:_showMesh ? @"Mesh shown" : @"Mesh hidden"];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info {
    UIImage* image = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    if (image) {
        // Scale down if needed
        int w = (int)image.size.width;
        int h = (int)image.size.height;
        float s = MAX(w / 2048.0f, h / 2048.0f);
        
        if (s > 1.0f) {
            w = (int)(w / s);
            h = (int)(h / s);
            image = [self scaleImage:image toSize:CGSizeMake(w, h)];
        }
        
        [self setImage:image];
    }
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (UIImage*)scaleImage:(UIImage*)image toSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;
}

#pragma mark - Helper Methods

- (void)showToast:(NSString*)message {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

- (void)dealloc {
    if (_imageHandler != nullptr) {
        [_sharedContext syncProcessingQueue:^{
            [_sharedContext makeCurrent];
            delete _imageHandler;
            _imageHandler = nullptr;
        }];
    }
    
    if (_deformWrapper != nil) {
        // Don't delete native filter as it's owned by the handler's filter chain
        [_deformWrapper releaseWithDeleteNativeFilter:NO];
        _deformWrapper = nil;
    }
}

@end
