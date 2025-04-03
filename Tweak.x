%hook UIApplication

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    // 确保应用程序已加载
    %orig;

    // 创建对话框
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Hello"
                                                                             message:@"This is an injected alert."
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    // 添加按钮
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alertController addAction:okAction];

    // 获取主窗口的视图控制器并显示对话框
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    [rootViewController presentViewController:alertController animated:YES completion:nil];
}

%end
