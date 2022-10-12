LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE_TAGS := optional

LOCAL_SRC_FILES := $(call all-java-files-under,  app/src/main/java)

LOCAL_PACKAGE_NAME := FirstSystemApp

LOCAL_SDK_VERSION := current

#LOCAL_PROGUARD_FLAG_FILES := proguard.flags
LOCAL_CERTIFICATE := platform

LOCAL_USE_AAPT2 := true


# 指定Manifest文件
LOCAL_MANIFEST_FILE := app/src/main/AndroidManifest.xml

LOCAL_RESOURCE_DIR := \
	$(addprefix $(LOCAL_PATH)/, app/src/main/res) 


# constraint-layout需要的jar
LOCAL_STATIC_JAVA_LIBRARIES := \
	androidx.appcompat_appcompat  \
	androidx.recyclerview_recyclerview \
	com.google.android.material_material \
	androidx-constraintlayout_constraintlayout \


include $(BUILD_PACKAGE)

# Use the folloing include to make our test apk.
include $(call all-makefiles-under,$(LOCAL_PATH))
