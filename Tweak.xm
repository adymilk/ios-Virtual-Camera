#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

@interface UIViewController (VolumeExtension)
- (void)volumeChanged:(UISlider *)sender;
- (void)handlePan:(UIPanGestureRecognizer *)pan;
@end

static NSTimeInterval lastVolumeChangeTime = 0;
static int volumeChangeCount = 0;
static BOOL hasShownAlert = NO;
static BOOL hasShownInitialAlert = NO;
static MPVolumeView *volumeView = nil;
static UILabel *debugLabel = nil;
static UIViewController *currentViewController = nil;

// 提前声明函数
static void checkVolumeCombo(void);
static void resetVolumeState(void);
static void showAlert(NSString *message);
static void setupVolumeListener(UIViewController *viewController);
static void showDebugLog(NSString *message);

// 添加新的函数声明
static void showVideoSelectionMenu(void);
static void handleVideoSelection(NSString *videoName);

// 显示调试日志
static void showDebugLog(NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!debugLabel) {
            debugLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, [UIScreen mainScreen].bounds.size.width - 40, 200)];
            debugLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
            debugLabel.textColor = [UIColor whiteColor];
            debugLabel.numberOfLines = 0;
            debugLabel.font = [UIFont systemFontOfSize:12];
            debugLabel.layer.cornerRadius = 8;
            debugLabel.layer.masksToBounds = YES;
            debugLabel.userInteractionEnabled = YES;
            
            // 添加拖动手势
            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:currentViewController 
                                                                                 action:@selector(handlePan:)];
            [debugLabel addGestureRecognizer:pan];
            
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            if (!window) {
                window = [[UIApplication sharedApplication].windows firstObject];
            }
            [window addSubview:debugLabel];
        }
        
        // 添加时间戳
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm:ss";
        NSString *timestamp = [formatter stringFromDate:[NSDate date]];
        
        // 保持最新的5条日志
        NSMutableString *currentText = [debugLabel.text mutableCopy] ?: [NSMutableString string];
        NSString *newLog = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
        [currentText insertString:newLog atIndex:0];
        
        // 限制日志行数
        NSArray *lines = [currentText componentsSeparatedByString:@"\n"];
        if (lines.count > 6) {
            lines = [lines subarrayWithRange:NSMakeRange(0, 6)];
            currentText = [[lines componentsJoinedByString:@"\n"] mutableCopy];
        }
        
        debugLabel.text = currentText;
    });
}

%hook UIViewController

%new
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *view = pan.view;
    CGPoint translation = [pan translationInView:view.superview];
    view.center = CGPointMake(view.center.x + translation.x, view.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:view.superview];
}

%new
- (void)volumeChanged:(UISlider *)sender {
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    if (currentTime - lastVolumeChangeTime > 5.0) {
        resetVolumeState();
    }
    
    volumeChangeCount++;
    lastVolumeChangeTime = currentTime;
    
    showDebugLog([NSString stringWithFormat:@"音量变化: %.2f (次数: %d)", sender.value, volumeChangeCount]);
    
    if (volumeChangeCount >= 2) {
        checkVolumeCombo();
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    currentViewController = self;
    
    if (!hasShownInitialAlert) {
        hasShownInitialAlert = YES;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            setupVolumeListener(self);
            showAlert(@"插件已成功注入!");
            showDebugLog(@"插件初始化完成");
        });
    }
}

%end

// 设置音量监听
static void setupVolumeListener(UIViewController *viewController) {
    if (!volumeView) {
        volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-100, -100, 1, 1)];
        volumeView.hidden = YES;
        
        UISlider *volumeSlider = nil;
        for (UIView *view in volumeView.subviews) {
            if ([view isKindOfClass:[UISlider class]]) {
                volumeSlider = (UISlider *)view;
                break;
            }
        }
        
        if (volumeSlider) {
            [volumeSlider addTarget:viewController 
                           action:@selector(volumeChanged:) 
                 forControlEvents:UIControlEventValueChanged];
            
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            if (window) {
                [window addSubview:volumeView];
                showDebugLog(@"音量监听器设置完成");
            }
        }
    }
}

// 显示弹窗
static void showAlert(NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            showDebugLog([NSString stringWithFormat:@"显示弹窗: %@", message]);
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" 
                                                                        message:message 
                                                                 preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" 
                                                            style:UIAlertActionStyleDefault 
                                                          handler:^(UIAlertAction * action) {
                showDebugLog(@"弹窗已关闭");
            }];
            
            [alert addAction:okAction];
            
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            if (!window) {
                window = [[UIApplication sharedApplication].windows firstObject];
            }
            
            if (window) {
                UIViewController *rootVC = window.rootViewController;
                while (rootVC.presentedViewController) {
                    rootVC = rootVC.presentedViewController;
                }
                [rootVC presentViewController:alert animated:YES completion:nil];
            }
        } @catch (NSException *exception) {
            showDebugLog([NSString stringWithFormat:@"显示弹窗错误: %@", exception]);
        }
    });
}

// 重置音量状态
static void resetVolumeState(void) {
    volumeChangeCount = 0;
    lastVolumeChangeTime = 0;
    hasShownAlert = NO;
    showDebugLog(@"状态已重置");
}

// 显示视频选择菜单
static void showVideoSelectionMenu(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"xkrj5.com开源"
                                                                    message:@"已替换\n未激活\n开源版"
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
        
        // 添加选择视频的选项
        NSArray *videos = @[@"视频1", @"视频2", @"视频3", @"视频4", @"视频5"];
        for (NSString *video in videos) {
            UIAlertAction *action = [UIAlertAction actionWithTitle:video
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
                handleVideoSelection(video);
            }];
            [alert addAction:action];
        }
        
        // 添加禁用替换选项
        UIAlertAction *disableAction = [UIAlertAction actionWithTitle:@"禁用替换"
                                                              style:UIAlertActionStyleDestructive
                                                            handler:^(UIAlertAction * _Nonnull action) {
            showDebugLog(@"已禁用视频替换");
        }];
        [alert addAction:disableAction];
        
        // 添加取消操作选项
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消操作"
                                                             style:UIAlertActionStyleCancel
                                                           handler:nil];
        [alert addAction:cancelAction];
        
        // 显示菜单
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            window = [[UIApplication sharedApplication].windows firstObject];
        }
        
        if (window) {
            UIViewController *rootVC = window.rootViewController;
            while (rootVC.presentedViewController) {
                rootVC = rootVC.presentedViewController;
            }
            [rootVC presentViewController:alert animated:YES completion:nil];
        }
    });
}

// 处理视频选择
static void handleVideoSelection(NSString *videoName) {
    showDebugLog([NSString stringWithFormat:@"已选择视频: %@", videoName]);
    // 这里添加视频替换的具体实现
}

// 修改检查音量组合的函数
static void checkVolumeCombo(void) {
    if (volumeChangeCount >= 2 && !hasShownAlert) {
        hasShownAlert = YES;
        // 替换原来的 showAlert 为新的视频选择菜单
        showVideoSelectionMenu();
    }
}

%ctor {
    @autoreleasepool {
        showDebugLog([NSString stringWithFormat:@"插件已加载: %@", [NSBundle mainBundle].bundleIdentifier]);
    }
} 