
LOCAL_PATH:= $(call my-dir)

include $(CLEAR_VARS)

LOCAL_SRC_FILES:= \
		main.c

LOCAL_C_INCLUDES += \
		$(LOCAL_PATH)/../libmath \
		$(LOCAL_PATH)/../libmath2


LOCAL_SHARED_LIBRARIES += \
	libmymathmk 

LOCAL_STATIC_LIBRARIES += \
	libmymath2mk 

LOCAL_VENDOR_MODULE := true

LOCAL_CFLAGS += \
		-Wno-error \
		-Wno-unused-parameter

LOCAL_MODULE:= mymathtestmk 

LOCAL_MODULE_TAGS := optional


LOCAL_MULTILIB := 64


include $(BUILD_EXECUTABLE)


