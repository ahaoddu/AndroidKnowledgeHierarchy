# Android Selinux 入门

## 1. 引子

Android Selinux 对进程的行为加以限制，以保证系统的安全。

## 2. 涉及的对象与流程

### 2.1 Security Context

Security Context 可以简单理解为 selinux 需要管理的对象的名字。这些对象包括了：

* 系统中的所有文件
* Android 属性系统中属性
* Binder 服务
* app


### 2.2 Security Policy
