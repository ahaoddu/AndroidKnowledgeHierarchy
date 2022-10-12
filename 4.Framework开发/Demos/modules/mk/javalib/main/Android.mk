LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_JAVA_LIBRARIES := libmytrianglemk

LOCAL_VENDOR_MODULE := true

LOCAL_SRC_FILES := $(call all-subdir-java-files)
LOCAL_MODULE := TriangleDemomk
include $(BUILD_JAVA_LIBRARY)
