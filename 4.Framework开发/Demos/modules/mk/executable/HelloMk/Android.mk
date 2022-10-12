LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

# c flag
LOCAL_CFLAGS += \
                -Wno-error \
                -Wno-unused-parameter


#添加动态库和静态库
# LOCAL_SHARED_LIBRARIES += \
# 	libmymath 

# LOCAL_STATIC_LIBRARIES += \
# 	libmycjson 

# user: 指该模块只在user版本下才编译
# eng: 指该模块只在eng版本下才编译
# tests: 指该模块只在tests版本下才编译
# optional:指该模块在所有版本下都编译
LOCAL_MODULE_TAGS := optional
# "both": build both 32-bit and 64-bit.
# "32": build only 32-bit.
# "64": build only 64-bit.
LOCAL_MULTILIB := 64

# 编译到 vender 而不是 system
LOCAL_VENDOR_MODULE := true

# 源码
LOCAL_SRC_FILES := hello.cpp

# 模块名
LOCAL_MODULE := hellomk
# 表示当前模块是可执行程序
include $(BUILD_EXECUTABLE)