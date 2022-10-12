LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(call all-subdir-java-files)
LOCAL_VENDOR_MODULE := true
LOCAL_MODULE := libmytrianglemk
include $(BUILD_JAVA_LIBRARY)
