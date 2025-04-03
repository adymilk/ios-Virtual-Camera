ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME=rootless

# 读取版本号文件，如果不存在则创建
VERSION_FILE = version.txt
VERSION = $(shell cat $(VERSION_FILE) 2>/dev/null || echo 1.0.0)

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlertTweak

AlertTweak_FILES = Tweak.xm
AlertTweak_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable
AlertTweak_FRAMEWORKS = UIKit Foundation MediaPlayer AVFoundation
AlertTweak_PRIVATE_FRAMEWORKS = MediaToolbox

include $(THEOS_MAKE_PATH)/tweak.mk

# 创建 build 目录并复制带版本号的 dylib 文件
after-all::
	@mkdir -p build
	@cp .theos/obj/debug/arm64/AlertTweak.dylib "build/AlertTweak_v$(VERSION).dylib"
	@echo "已复制 AlertTweak_v$(VERSION).dylib 到 build 目录"
	# 更新版本号
	@awk -F. '{$$NF = $$NF + 1;} 1' OFS=. $(VERSION_FILE) > $(VERSION_FILE).tmp && mv $(VERSION_FILE).tmp $(VERSION_FILE)
	@echo "版本号已更新到: $$(cat $(VERSION_FILE))"

before-all::
	@if [ ! -f $(VERSION_FILE) ]; then echo "1.0.0" > $(VERSION_FILE); fi

after-install::
	install.exec "killall -9 SpringBoard"
