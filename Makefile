THEOS ?= /home/runner/theos
THEOS_MAKE_PATH = $(THEOS)/makefiles

THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CamSpoof
CamSpoof_FILES = Tweak.x
CamSpoof_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-deprecated-declarations
CamSpoof_FRAMEWORKS = UIKit AVFoundation CoreMedia CoreVideo Photos PhotosUI

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += CamSpoofPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
