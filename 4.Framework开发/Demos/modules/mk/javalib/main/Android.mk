LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_JAVA_LIBRARIES := libmytrianglemk 

LOCAL_SRC_FILES := $(call all-subdir-java-files)
LOCAL_MODULE := TriangleDemomk
# 编译到 product 分区
LOCAL_PRODUCT_MODULE := true
include $(BUILD_JAVA_LIBRARY)
