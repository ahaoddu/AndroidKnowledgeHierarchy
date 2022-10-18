LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_SRC_FILES:= \
    myse_test.c

LOCAL_SHARED_LIBRARIES := \
    libcutils \
    liblog \

LOCAL_CFLAGS += -Wno-unused-parameter
LOCAL_VENDOR_MODULE := true
#LOCAL_PRODUCT_MODULE := true
LOCAL_MODULE:= myse_test

include $(BUILD_EXECUTABLE)

