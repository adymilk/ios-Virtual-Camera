#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@interface UIViewController (VolumeExtension)
- (void)volumeChanged:(UISlider *)sender;
- (void)handlePan:(UIPanGestureRecognizer *)pan;
@end

// 添加摄像头相关接口
@interface AVCaptureDevice (Private)
+ (id)deviceWithUniqueID:(id)arg1;
@end

static NSTimeInterval lastVolumeChangeTime = 0;
static int volumeChangeCount = 0;
static BOOL hasShownAlert = NO;
static BOOL hasShownInitialAlert = NO;
static BOOL hasShownMenuAlert = NO;
static MPVolumeView *volumeView = nil;
static UILabel *debugLabel = nil;
static UIViewController *currentViewController = nil;

// 视频替换相关变量
static BOOL isVideoReplaceEnabled = YES;
static NSString *selectedVideoPath = nil;

// 所有函数的前向声明
static void showDebugLog(NSString *message);
static void showVideoSelectionMenu(void);
static void handleVideoSelection(NSString *videoName);
static void setupVideoReplacement(void);
static void disableVideoReplacement(void);
static void resetVolumeState(void);
static void checkVolumeCombo(void);
static void showAlert(NSString *message);
static void setupStatusBarDoubleTap(UIViewController *viewController);

// 状态栏双击检测
// static NSTimeInterval lastStatusBarTapTime = 0;

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

// 重置音量状态
static void resetVolumeState(void) {
    volumeChangeCount = 0;
    lastVolumeChangeTime = 0;
    hasShownAlert = NO;
    showDebugLog(@"状态已重置");
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

// 检查音量组合
static void checkVolumeCombo(void) {
    if (volumeChangeCount >= 2 && !hasShownAlert) {
        hasShownAlert = YES;
        // 替换原来的 showAlert 为新的视频选择菜单
        showVideoSelectionMenu();
    }
}

%hook AVCaptureDevice 

+ (id)deviceWithUniqueID:(id)arg1 {
    if (isVideoReplaceEnabled && selectedVideoPath) {
        showDebugLog(@"正在替换摄像头输入...");
        // 返回自定义的视频源
        return nil; // 这里需要返回自定义的视频源
    }
    return %orig;
}

%end

%hook AVCaptureSession

- (void)startRunning {
    if (isVideoReplaceEnabled && selectedVideoPath) {
        showDebugLog(@"正在启动视频会话...");
        // 处理视频会话
        return;
    }
    %orig;
}

%end

// 设置视频替换
static void setupVideoReplacement(void) {
    if (!isVideoReplaceEnabled || !selectedVideoPath) {
        return;
    }
    
    showDebugLog(@"正在设置视频替换...");
    // 这里添加视频替换的具体实现
}

// 禁用视频替换
static void disableVideoReplacement(void) {
    isVideoReplaceEnabled = NO;
    selectedVideoPath = nil;
    showDebugLog(@"已禁用视频替换");
}

// 处理视频选择
static void handleVideoSelection(NSString *videoName) {
    showDebugLog([NSString stringWithFormat:@"已选择视频: %@", videoName]);
    
    // 设置视频路径
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *videosPath = [documentsPath stringByAppendingPathComponent:@"Videos"];
    selectedVideoPath = [videosPath stringByAppendingPathComponent:videoName];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:selectedVideoPath]) {
        isVideoReplaceEnabled = YES;
        setupVideoReplacement();
        showDebugLog(@"视频替换已启用");
    } else {
        showDebugLog(@"视频文件不存在");
    }
}

// 修改视频选择菜单
static void showVideoSelectionMenu(void) {
    showDebugLog(@"showVideoSelectionMenu 被调用 - 尝试新的方法");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // 使用警告样式而不是操作表，更可靠
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"xkrj5.com开源"
                                                                    message:@"请选择一个视频或操作"
                                                             preferredStyle:UIAlertControllerStyleAlert];
        
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
            disableVideoReplacement();
        }];
        [alert addAction:disableAction];
        
        // 添加取消操作选项
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                             style:UIAlertActionStyleCancel
                                                           handler:nil];
        [alert addAction:cancelAction];
        
        // 尝试获取前台应用的关键窗口和根视图控制器
        UIWindow *keyWindow = nil;
        
        // iOS 13及以上
        if (@available(iOS 13.0, *)) {
            NSSet *connectedScenes = [UIApplication sharedApplication].connectedScenes;
            for (UIScene *scene in connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *window in windowScene.windows) {
                        if (window.isKeyWindow) {
                            keyWindow = window;
                            break;
                        }
                    }
                    if (keyWindow) break;
                }
            }
        } else {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
        
        // 如果还是找不到，尝试获取第一个窗口
        if (!keyWindow) {
            keyWindow = [UIApplication sharedApplication].windows.firstObject;
        }
        
        showDebugLog([NSString stringWithFormat:@"找到窗口: %@", keyWindow ? @"是" : @"否"]);
        
        if (keyWindow) {
            UIViewController *topController = keyWindow.rootViewController;
            
            // 获取最顶层的视图控制器
            while (topController.presentedViewController) {
                topController = topController.presentedViewController;
            }
            
            showDebugLog([NSString stringWithFormat:@"找到顶层控制器: %@", topController ? [topController description] : @"否"]);
            
            if (topController) {
                // 直接使用这个控制器
                [topController presentViewController:alert animated:YES completion:^{
                    showDebugLog(@"警告已显示！");
                }];
            } else {
                showDebugLog(@"没有找到顶层控制器！");
            }
        } else {
            showDebugLog(@"没有找到活动窗口！");
        }
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

// 确保 setupStatusBarDoubleTap 函数在钩子外部
// 删除当前在 UIViewController 钩子内部的函数定义

// 先删除错误位置的函数
// 然后在这里重新定义它
static void setupStatusBarDoubleTap(UIViewController *viewController) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            window = [[UIApplication sharedApplication].windows firstObject];
        }
        
        if (window) {
            // 创建一个更大更明显的视图覆盖整个顶部
            UIView *tapView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, window.bounds.size.width, 100)];
            tapView.backgroundColor = [[UIColor blueColor] colorWithAlphaComponent:0.2]; // 更明显的蓝色
            tapView.tag = 12345;
            tapView.userInteractionEnabled = YES; // 确保可接收触摸事件
            
            // 移除旧的视图
            for (UIView *subview in window.subviews) {
                if (subview.tag == 12345) {
                    [subview removeFromSuperview];
                    break;
                }
            }
            
            // 添加一个简单的单击手势，看能否响应
            UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:viewController action:@selector(tapViewTapped:)];
            [tapView addGestureRecognizer:tapGesture];
            
            [window addSubview:tapView];
            [window bringSubviewToFront:tapView]; // 确保在最前面
            
            showDebugLog(@"新的点击区域设置完成 - 请点击顶部蓝色区域");
        }
    });
}

// 修改点击处理函数
%new
- (void)tapViewTapped:(UITapGestureRecognizer *)gestureRecognizer {
    showDebugLog(@"点击区域被点击 - 尝试显示简单弹窗测试");
    
    // 先尝试显示一个简单的提示来测试
    showAlert(@"点击测试\n这是一个测试弹窗");
    
    // 延迟2秒后再尝试显示菜单
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        showDebugLog(@"延迟2秒后尝试显示菜单");
        showVideoSelectionMenu();
    });
}

// 移除 statusBarDoubleTapped 方法（不再使用）

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    currentViewController = self;
    
    if (!hasShownInitialAlert) {
        hasShownInitialAlert = YES;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            setupStatusBarDoubleTap(self);
            showAlert(@"插件已成功注入!\n点击顶部蓝色区域可触发功能菜单");
            showDebugLog(@"插件初始化完成");
        });
    }
}

%end

%ctor {
    @autoreleasepool {
        showDebugLog([NSString stringWithFormat:@"插件已加载: %@", [NSBundle mainBundle].bundleIdentifier]);
    }
} 