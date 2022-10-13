LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(call all-subdir-java-files)
LOCAL_MODULE := libmytrianglemk
LOCAL_PRODUCT_MODULE := true
include $(BUILD_JAVA_LIBRARY)
