//
//  do_ImageCropView_View.m
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//
#define SCALE_FRAME_Y 100.0f
#define BOUNDCE_DURATION 0.3f

#import "do_ImageCropView_UIView.h"

#import "doInvokeResult.h"
#import "doUIModuleHelper.h"
#import "doScriptEngineHelper.h"
#import "doIScriptEngine.h"
#import "doIOHelper.h"
#import "doIPage.h"
#import "doIDataFS.h"

@interface do_ImageCropView_UIView()
@property (nonatomic,  assign) CGRect cropFrame;
@property (nonatomic, strong) UIImage *originalImage;
@property (nonatomic, retain) UIView *cropFrameView;
@property (nonatomic, retain) UIView *overlayView;
@property (nonatomic, assign) CGRect latestFrame;
@property (nonatomic, assign) CGRect largeFrame;
@property (nonatomic, assign) CGRect oldFrame;
@property (nonatomic, assign) CGFloat limitRatio;
@property (nonatomic, strong) UIImageView *showImage;
@end
@implementation do_ImageCropView_UIView
#pragma mark - doIUIModuleView协议方法（必须）
//引用Model对象
- (void) LoadView: (doUIModule *) _doUIModule
{
    _model = (typeof(_model)) _doUIModule;
    [self setMultipleTouchEnabled:YES];
    [self setUserInteractionEnabled:YES];
    self.limitRatio = 3.0f;
    self.clipsToBounds = YES;
    //默认裁剪尺寸
    self.cropFrame = CGRectMake(_model.RealWidth / 4, _model.RealHeight / 4, _model.RealWidth / 2, _model.RealHeight / 2);
    
    [self reset];
    
    //添加手势
    [self addGestureRecognizers];
}
//销毁所有的全局对象
- (void) OnDispose
{
    //自定义的全局属性,view-model(UIModel)类销毁时会递归调用<子view-model(UIModel)>的该方法，将上层的引用切断。所以如果self类有非原生扩展，需主动调用view-model(UIModel)的该方法。(App || Page)-->强引用-->view-model(UIModel)-->强引用-->view
}
//实现布局
- (void) OnRedraw
{
    //实现布局相关的修改,如果添加了非原生的view需要主动调用该view的OnRedraw，递归完成布局。view(OnRedraw)<显示布局>-->调用-->view-model(UIModel)<OnRedraw>
    
    //重新调整视图的x,y,w,h
    [doUIModuleHelper OnRedraw:_model];
    
}

#pragma mark - TYPEID_IView协议方法（必须）
#pragma mark - Changed_属性
/*
 如果在Model及父类中注册过 "属性"，可用这种方法获取
 NSString *属性名 = [(doUIModule *)_model GetPropertyValue:@"属性名"];
 
 获取属性最初的默认值
 NSString *属性名 = [(doUIModule *)_model GetProperty:@"属性名"].DefaultValue;
 */
- (void)change_cropArea:(NSString *)newValue
{
    //自己的代码实现
    NSArray *areaArray = [newValue componentsSeparatedByString:@","];
    CGFloat width = [[areaArray objectAtIndex:0] floatValue];
    CGFloat height = [[areaArray objectAtIndex:1] floatValue];
    
    if (width <= 0) {
        width = _model.RealWidth / 2;
    }
    if (height <= 0) {
        height = _model.RealHeight / 2;
    }
    width *= _model.XZoom;
    height *= _model.YZoom;
    
    CGFloat x = (_model.RealWidth - width) / 2;
    CGFloat y = (_model.RealHeight - height) / 2;
    self.cropFrame = CGRectMake(x, y,width, height);
    self.cropFrameView.frame = self.cropFrame;
    [self overlayClipping];
}

- (void)reset
{
    if (self.showImage) {
        [self.showImage removeFromSuperview];
    }
    if (self.overlayView) {
        [self.overlayView removeFromSuperview];
    }
    if (self.cropFrameView) {
        [self.cropFrameView removeFromSuperview];
    }
    
    //背景图
    self.showImage = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, _model.RealWidth, _model.RealHeight)];
    self.showImage.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:self.showImage];
    //裁剪遮盖区域
    self.overlayView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _model.RealWidth, _model.RealHeight)];
    self.overlayView.alpha = .5f;
    self.overlayView.backgroundColor = [UIColor blackColor];
    self.overlayView.userInteractionEnabled = NO;
    [self addSubview:self.overlayView];
    //裁剪边框
    self.cropFrameView = [[UIView alloc] initWithFrame:self.cropFrame];
    self.cropFrameView.layer.borderColor = [UIColor yellowColor].CGColor;
    self.cropFrameView.layer.borderWidth = 1.0f;
    self.cropFrameView.autoresizingMask = UIViewAutoresizingNone;
    [self addSubview:self.cropFrameView];
    
    [self overlayClipping];
}

- (void)change_source:(NSString *)newValue
{
    //自己的代码实现
    NSString * imgPath = [doIOHelper GetLocalFileFullPath:_model.CurrentPage.CurrentApp :newValue];
    if ([[NSFileManager defaultManager] fileExistsAtPath:imgPath])
    {
        [self reset];
        UIImage *image = [UIImage imageWithContentsOfFile:imgPath];
        self.showImage.image = image;
        self.originalImage = image;
        // scale to fit the screen
        CGFloat oriWidth = self.cropFrame.size.width;
        CGFloat oriHeight = self.originalImage.size.height * (oriWidth / self.originalImage.size.width);
        CGFloat oriX = self.cropFrame.origin.x + (self.cropFrame.size.width - oriWidth) / 2;
        CGFloat oriY = self.cropFrame.origin.y + (self.cropFrame.size.height - oriHeight) / 2;
        self.oldFrame = CGRectMake(oriX, oriY, oriWidth, oriHeight);
        self.latestFrame = self.oldFrame;
        self.largeFrame = CGRectMake(0, 0, self.limitRatio * self.oldFrame.size.width, self.limitRatio * self.oldFrame.size.height);
    }
    

}

#pragma mark -
#pragma mark - 同步异步方法的实现
//异步
- (void)crop:(NSArray *)parms
{
    //异步耗时操作，但是不需要启动线程，框架会自动加载一个后台线程处理这个函数
    //参数字典_dictParas
    id<doIScriptEngine> _scritEngine = [parms objectAtIndex:1];
    //自己的代码实现

    NSString *_callbackName = [parms objectAtIndex:2];
    //回调函数名_callbackName

    UIImage *cutImage = [self getCutImage];
    self.showImage.frame = self.cropFrameView.frame;
    NSString *_fileFullName = [_scritEngine CurrentApp].DataFS.PathPrivateTemp;

    NSString *fileName = [NSString stringWithFormat:@"%@.jpg",[doUIModuleHelper stringWithUUID]];
    NSString *filePath = [NSString stringWithFormat:@"%@/do_ImageCropView/%@",_fileFullName,fileName];
    NSString *tempPath = [NSString stringWithFormat:@"%@/do_ImageCropView",_fileFullName];
    if (![doIOHelper ExistDirectory:tempPath]) {
        [doIOHelper CreateDirectory:tempPath];
    }
    [self writeImage:cutImage toFileAtPath:filePath];
    NSString *invokeStr = [NSString stringWithFormat:@"data://tmp/do_ImageCropView/%@",fileName];
    doInvokeResult *_invokeResult = [[doInvokeResult alloc] init];
    //_invokeResult设置返回值
    [_invokeResult SetResultText:invokeStr];
    [_scritEngine Callback:_callbackName :_invokeResult];
}

#pragma mark - 私有方法
//裁剪区域外的阴影
- (void)overlayClipping
{
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    CGMutablePathRef path = CGPathCreateMutable();
    // Left side of the ratio view
    CGPathAddRect(path, nil, CGRectMake(0, 0,
                                        self.cropFrameView.frame.origin.x,
                                        self.overlayView.frame.size.height));
    // Right side of the ratio view
    CGPathAddRect(path, nil, CGRectMake(
                                        self.cropFrameView.frame.origin.x + self.cropFrameView.frame.size.width,
                                        0,
                                        self.overlayView.frame.size.width - self.cropFrameView.frame.origin.x - self.cropFrameView.frame.size.width,
                                        self.overlayView.frame.size.height));
    // Top side of the ratio view
    CGPathAddRect(path, nil, CGRectMake(0, 0,
                                        self.overlayView.frame.size.width,
                                        self.cropFrameView.frame.origin.y));
    // Bottom side of the ratio view
    CGPathAddRect(path, nil, CGRectMake(0,
                                        self.cropFrameView.frame.origin.y + self.cropFrameView.frame.size.height,
                                        self.overlayView.frame.size.width,
                                        self.overlayView.frame.size.height - self.cropFrameView.frame.origin.y + self.cropFrameView.frame.size.height));
    maskLayer.path = path;
    self.overlayView.layer.mask = maskLayer;
    self.overlayView.layer.masksToBounds = YES;
    CGPathRelease(path);
}
// register all gestures
- (void) addGestureRecognizers
{
    // add pinch gesture
    UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchView:)];
    [self addGestureRecognizer:pinchGestureRecognizer];
    
    // add pan gesture
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panView:)];
    [self addGestureRecognizer:panGestureRecognizer];
}
// pinch gesture handler
- (void) pinchView:(UIPinchGestureRecognizer *)pinchGestureRecognizer
{
    UIView *view = self.showImage;
    if (pinchGestureRecognizer.state == UIGestureRecognizerStateBegan || pinchGestureRecognizer.state == UIGestureRecognizerStateChanged) {
        view.transform = CGAffineTransformScale(view.transform, pinchGestureRecognizer.scale, pinchGestureRecognizer.scale);
        pinchGestureRecognizer.scale = 1;
    }
    else if (pinchGestureRecognizer.state == UIGestureRecognizerStateEnded) {
//        CGRect newFrame = self.showImage.frame;
//        newFrame = [self handleScaleOverflow:newFrame];
//        newFrame = [self handleBorderOverflow:newFrame];
//        [UIView animateWithDuration:BOUNDCE_DURATION animations:^{
//            self.showImage.frame = newFrame;
//            self.latestFrame = newFrame;
//        }];
    }
}
- (CGRect)handleScaleOverflow:(CGRect)newFrame {
    // bounce to original frame
    CGPoint oriCenter = CGPointMake(newFrame.origin.x + newFrame.size.width/2, newFrame.origin.y + newFrame.size.height/2);
    if (newFrame.size.width < self.oldFrame.size.width) {
        newFrame = self.oldFrame;
    }
    if (newFrame.size.width > self.largeFrame.size.width) {
        newFrame = self.largeFrame;
    }
    newFrame.origin.x = oriCenter.x - newFrame.size.width/2;
    newFrame.origin.y = oriCenter.y - newFrame.size.height/2;
    return newFrame;
}

- (CGRect)handleBorderOverflow:(CGRect)newFrame {
    // horizontally
    if (newFrame.origin.x > self.cropFrame.origin.x) newFrame.origin.x = self.cropFrame.origin.x;
    if (CGRectGetMaxX(newFrame) < self.cropFrame.size.width +  self.cropFrame.origin.x)
    {
        newFrame.origin.x = self.cropFrame.origin.x + self.cropFrame.size.width - newFrame.size.width;
    }
    // vertically
    if (newFrame.origin.y > self.cropFrame.origin.y) newFrame.origin.y = self.cropFrame.origin.y;
    if (CGRectGetMaxY(newFrame) < self.cropFrame.origin.y + self.cropFrame.size.height) {
        newFrame.origin.y = self.cropFrame.origin.y + self.cropFrame.size.height - newFrame.size.height;
    }
    // adapt horizontally rectangle
    if (self.frame.size.width > self.frame.size.height && newFrame.size.height <= self.cropFrame.size.height) {
        newFrame.origin.y = self.cropFrame.origin.y + (self.cropFrame.size.height - newFrame.size.height) / 2;
    }
    return newFrame;
}
// pan gesture handler
- (void) panView:(UIPanGestureRecognizer *)panGestureRecognizer
{
    UIView *view = self.showImage;
    if (panGestureRecognizer.state == UIGestureRecognizerStateBegan || panGestureRecognizer.state == UIGestureRecognizerStateChanged) {
        // calculate accelerator
        CGFloat absCenterX = self.cropFrame.origin.x + self.cropFrame.size.width / 2;
        CGFloat absCenterY = self.cropFrame.origin.y + self.cropFrame.size.height / 2;
        CGFloat scaleRatio = self.frame.size.width / self.cropFrame.size.width;
        CGFloat acceleratorX = 1 - ABS(absCenterX - view.center.x) / (scaleRatio * absCenterX);
        CGFloat acceleratorY = 1 - ABS(absCenterY - view.center.y) / (scaleRatio * absCenterY);
        CGPoint translation = [panGestureRecognizer translationInView:view.superview];
        [view setCenter:(CGPoint){view.center.x + translation.x * acceleratorX, view.center.y + translation.y * acceleratorY}];
        [panGestureRecognizer setTranslation:CGPointZero inView:view.superview];
    }
    else if (panGestureRecognizer.state == UIGestureRecognizerStateEnded) {
        // bounce to original frame
//        CGRect newFrame = self.showImage.frame;
//        newFrame = [self handleBorderOverflow:newFrame];
//        [UIView animateWithDuration:BOUNDCE_DURATION animations:^{
//            self.showImage.frame = newFrame;
//            self.latestFrame = newFrame;
//        }];
    }
}
//得到裁剪图片
-(UIImage *)getCutImage{
    CGRect rect = CGRectZero;
    double scale = [UIScreen mainScreen].scale;
    rect = CGRectMake((CGRectGetMinX(self.cropFrame)+2)*scale, (CGRectGetMinY(self.cropFrame)+1.5)*scale, (CGRectGetWidth(self.cropFrame)-4)*scale, (CGRectGetHeight(self.cropFrame)-4)*scale);
    UIGraphicsBeginImageContextWithOptions(self.frame.size, NO, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [self.layer renderInContext:context];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CGImageRef sourceImageRef = [img CGImage];
    CGImageRef newImageRef = CGImageCreateWithImageInRect(sourceImageRef, rect);
    UIImage *newImage = [UIImage imageWithCGImage:newImageRef];
    return newImage;
}
//写入文件
- (BOOL)writeImage:(UIImage*)image toFileAtPath:(NSString*)aPath
{
    if ((image == nil) || (aPath == nil) || ([aPath isEqualToString:@""]))
    {
        return NO;
    }
    @try
    {
        NSData *imageData = nil;
        NSString *ext = [aPath pathExtension];
        if ([ext isEqualToString:@"png"])
        {
            imageData = UIImagePNGRepresentation(image);
        }
        else  
        {
            // the rest, we write to jpeg
            
            // 0. best, 1. lost. about compress.
            imageData = UIImageJPEGRepresentation(image, 0);
        }
        
        
        if ((imageData == nil) || ([imageData length] <= 0))
        {
            return NO;
        }
        [imageData writeToFile:aPath atomically:YES];
        return YES;
    }
    @catch (NSException *e)
    {
        NSLog(@"create thumbnail exception.");
    }
    return NO;
}
#pragma mark - doIUIModuleView协议方法（必须）<大部分情况不需修改>
- (BOOL) OnPropertiesChanging: (NSMutableDictionary *) _changedValues
{
    //属性改变时,返回NO，将不会执行Changed方法
    return YES;
}
- (void) OnPropertiesChanged: (NSMutableDictionary*) _changedValues
{
    //_model的属性进行修改，同时调用self的对应的属性方法，修改视图
    [doUIModuleHelper HandleViewProperChanged: self :_model : _changedValues ];
}
- (BOOL) InvokeSyncMethod: (NSString *) _methodName : (NSDictionary *)_dicParas :(id<doIScriptEngine>)_scriptEngine : (doInvokeResult *) _invokeResult
{
    //同步消息
    return [doScriptEngineHelper InvokeSyncSelector:self : _methodName :_dicParas :_scriptEngine :_invokeResult];
}
- (BOOL) InvokeAsyncMethod: (NSString *) _methodName : (NSDictionary *) _dicParas :(id<doIScriptEngine>) _scriptEngine : (NSString *) _callbackFuncName
{
    //异步消息
    return [doScriptEngineHelper InvokeASyncSelector:self : _methodName :_dicParas :_scriptEngine: _callbackFuncName];
}
- (doUIModule *) GetModel
{
    //获取model对象
    return _model;
}

@end
