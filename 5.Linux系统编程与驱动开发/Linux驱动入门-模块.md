# Linux驱动入门-模块

Framework 层的学习需要我们对驱动的开发流程有基本的认识，这里做基本的入门科普。驱动入门一共分为了两篇文章：

- [Linux驱动入门-模块](https://github.com/dducd/AndroidSourceLearn/blob/main/2.Linux%E9%A9%B1%E5%8A%A8%E5%85%A5%E9%97%A8-%E6%A8%A1%E5%9D%97.md)
- [Linux驱动入门-驱动](https://github.com/dducd/AndroidSourceLearn/blob/main/3.Linux%E9%A9%B1%E5%8A%A8%E5%85%A5%E9%97%A8-%E9%A9%B1%E5%8A%A8.md)

## 1. 编写一个简单的 Linux 内核模块

首先，我们需要理解什么是内核模块？`<br />`简单来说，内核模块是一段 "固定格式" 的代码，linux 内核可以动态的加载并执行这段代码，也可以把这段代码编译进内核，在内核启动的时候来执行这段代码。

下面我们写一个简单的 linux 模块：`<br />`准备工作：

```bash
sudo apt install build-essential linux-headers-`uname -r`
```

创建我们的项目目录：

```bash
mkdir HelloModule
cd HelloModule
```

在 HelloModule 中添加 hello_module.c

```c
#include <linux/module.h>
#include <linux/init.h>

/**
 * __init 是一个宏，表示 hello_init 是一个初始化函数，会放到编译后目标文件的初始化段中
 */ 
static int __init hello_init(void)
{
	//printk 是内核中的日志打印函数
	printk("Hello world!\n");
	return 0;
}
 
/**
 * __exit 是一个宏，表示 hello_exit 是一个初始化函数，会放到编译后目标文件的初始化段中
 */ 
static void __exit hello_exit(void)
{
	printk("hello exit\n");
}

/**
 * hello_init 是当前模块的启动函数
 */ 
module_init(hello_init);
/*
 * hello_exit 是当前模块的退出函数
 */
module_exit(hello_exit);
```

`<a name="bkQOa"></a>`

## 2. 将模块编译进内核

Linux系统将设备分为三大类：字符设备、块设备和网络设备。字符设备是其中较为基础的一类，它的读写操作需要一个字节一个字节的进行，不能随机读取设备中的某一数据，即要按照先后顺序。举例来说，比较常见的字符设备有鼠标、键盘、串口等。字符设备的驱动程序称之为字符驱动。Linux中驱动程序就是一个模块，这里假设我们需要编写的模块是一个字符驱动程序（实际只是输出一些字符信息，无实际硬件操作）。

在内核源码中，drivers/char 目录下，保存了内核的字符驱动。

把 hello_module 移动到内核的 /drivers/char 目录:

```bash
cp hello_module.c  kernel目录/drivers/char
```

编译 linux 内核时，有时需要使用 make menuconfig 来配置编译选项。这些编译选项来自于源码中 Kconfig。`<br />`接下来我们修改 /drivers/char/Kconfig 文件，使得我们的 hello 模块，能出现在内核的编译选择中。

在 /drivers/char 中的 Kconfig 文件中添加：

```bash
config HELLO_MODULE
	bool "hello module support"
	default y
```

然后在 /drivers/char 中的 Makefile 文件中添加：

```bash
obj-$(CONFIG_HELLO_MODULE)       += hello_module.o
```

当在编译菜单中选中了hello module support， CONFIG_HELLO_MODULE 的值是 y，没有选中值是 m。

obj-y  += hello_module.o 的意思是将 hello_module.o 编译进内核 `<br />`obj-m += hello_module.o 的意思文件 hello_module.o 作为"模块"进行编译，不会编译到内核，但是会生成一个独立的 "test.ko" 文件

最后配置内核：

```bash
cp ./arch/x86/configs/x86_64_ranchu_defconfig .config
make menuconfig
```

进入 Device Drivers 选项：`<br />`![image.png](https://cdn.nlark.com/yuque/0/2022/png/2613680/1662557901188-23ce73c8-a34d-400d-9c19-33490437650b.png#clientId=u0070c139-bb8d-4&crop=0&crop=0&crop=1&crop=1&from=paste&height=428&id=ue1b12fba&margin=%5Bobject%20Object%5D&name=image.png&originHeight=642&originWidth=1164&originalType=binary&ratio=1&rotation=0&showTitle=false&size=80471&status=done&style=none&taskId=uae32179e-f2f1-44db-b325-3e71c4c9ae1&title=&width=776) `<br />`进入 Character devices `<br />`![image.png](https://cdn.nlark.com/yuque/0/2022/png/2613680/1662558029286-d2534d22-52a8-4334-b1c4-c2eea9ee1ab7.png#clientId=u0070c139-bb8d-4&crop=0&crop=0&crop=1&crop=1&from=paste&height=428&id=u20673e5f&margin=%5Bobject%20Object%5D&name=image.png&originHeight=642&originWidth=1164&originalType=binary&ratio=1&rotation=0&showTitle=false&size=82925&status=done&style=none&taskId=u7e3f5225-fd84-4d5f-9512-707b6c22834&title=&width=776) `<br />`这里就可以看见我们刚才添加的选项，默认是选上的。`<br />`![image.png](https://cdn.nlark.com/yuque/0/2022/png/2613680/1662558063879-2b6f4df0-dd8f-4e2b-90ea-864847d76919.png#clientId=u0070c139-bb8d-4&crop=0&crop=0&crop=1&crop=1&from=paste&height=428&id=uab442630&margin=%5Bobject%20Object%5D&name=image.png&originHeight=642&originWidth=1164&originalType=binary&ratio=1&rotation=0&showTitle=false&size=97602&status=done&style=none&taskId=u5e3be462-1b42-4cb6-9019-fcb7b3c8726&title=&width=776)

然后执行编译：

```bash
#执行之前的编译脚本
sh build.sh
```

启动模拟器：

```bash
source build/envsetup.sh
lunch aosp_x86_64-eng
emulator -kernel ~/kernel/goldfish/arch/x86_64/boot/bzImage
```

查看开机信息：

```bash
// dmesg 用于显示开机信息
adb shell dmesg
```

![image.png](https://cdn.nlark.com/yuque/0/2022/png/2613680/1662559485632-002e4a02-467a-4f70-8e0f-a00632e4fbca.png#clientId=u3bfde1f0-c045-4&crop=0&crop=0&crop=1&crop=1&from=paste&height=113&id=u0f3be0b1&margin=%5Bobject%20Object%5D&name=image.png&originHeight=169&originWidth=529&originalType=binary&ratio=1&rotation=0&showTitle=false&size=105704&status=done&style=none&taskId=u8d197ca4-64e7-4d03-b6c0-7c9e2f9c24c&title=&width=352.6666666666667)

`<a name="cQ2jo"></a>`

## 总结

本文简单介绍了 linux 模块相关的入门知识，如果你对 linux 内核，驱动感兴趣，这里推荐：

- [Linux 内核分析与应用](https://www.xuetangx.com/course/XIYOU08091001441/12423765) ：陈莉君教授的 mooc 课程，免费
- 韦东山老师的《嵌入式Linux应用开发完全手册第2版》： 链接：[https://pan.baidu.com/s/1sNezVPu3J8BMdifd-06EoA](https://pan.baidu.com/s/1sNezVPu3J8BMdifd-06EoA) 提取码：p1l5

`<a name="lmSbO"></a>`

## 源码

你可在我的 github 仓库 https://github.com/dducd/AndroidSourceLearn/tree/main/Demos/HelloModule 中下载到示例代码。

## 参考资料

- [如何编写一个简单的 Linux 内核模块](https://www.oschina.net/translate/writing-a-simple-linux-kernel-module?print)
- [如何将内核模块编译进linux内核](https://blog.csdn.net/bhniunan/article/details/104083963)
- [奔跑吧 Linux内核 入门篇](https://book.douban.com/subject/30645390/)
- [Linux设备驱动开发详解](https://book.douban.com/subject/26600201/)

## 关于我

- 我叫阿豪，目前定居成都
- 2012 年开始从事 Android 系统定制和应用开发相关的工作
- 2015 年毕业于国防科技大学，毕业后从事 Android 相关的开发和研究工作
- 2019年初开始创业，从事 Android 系统开发工作
- 如果你对 Android 系统源码感兴趣可以扫码添加我的微信，相互学习交流。

![27c7e38ee991b9d1fb42cb3bdf352a7.jpg](https://cdn.nlark.com/yuque/0/2022/jpeg/2613680/1662174041146-53015bfc-12f7-4023-9131-0a9e51fd00a2.jpeg#clientId=u0593d637-e239-4&crop=0&crop=0&crop=1&crop=1&from=drop&id=ud527bf55&margin=%5Bobject%20Object%5D&name=27c7e38ee991b9d1fb42cb3bdf352a7.jpg&originHeight=430&originWidth=430&originalType=binary&ratio=1&rotation=0&showTitle=false&size=42506&status=done&style=none&taskId=uf620381e-5767-4559-867e-093d91d3256&title=#crop=0&crop=0&crop=1&crop=1&id=qxLzV&originHeight=430&originWidth=430&originalType=binary&ratio=1&rotation=0&showTitle=false&status=done&style=none&title=)
