LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_SRC_FILES:= \
        my_math.c

LOCAL_MODULE:= libmymathmk

LOCAL_MULTILIB := 64
	
LOCAL_MODULE_TAGS := optional

LOCAL_VENDOR_MODULE := true

#动态库
include $(BUILD_SHARED_LIBRARY)


