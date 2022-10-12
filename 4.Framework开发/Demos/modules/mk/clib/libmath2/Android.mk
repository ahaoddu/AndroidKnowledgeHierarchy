
LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_SRC_FILES:= \
    my_math2.c \

LOCAL_MODULE:= libmymath2mk
LOCAL_MULTILIB := 64

LOCAL_MODULE_TAGS := optional
LOCAL_VENDOR_MODULE := true

# 静态库
include $(BUILD_STATIC_LIBRARY)


