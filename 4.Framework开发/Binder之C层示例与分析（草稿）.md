## 1. binder 是什么

binder 是一个 linux 驱动，用于进程间的数据交换。

进程通信就会涉及两个概念：IPC(Inter-Process Communication),  RPC(Remote Procedure Call)：

IPC：指进程间数据交换的技术手段。

RPC：指进程间的方法调用，一般基于 IPC。

binder 驱动用于进程间交换数据，属于 IPC 技术。 binder 驱动加上应用层的封装，就构成了 binder RPC 框架，使得我们能在 A 进程访问 B 进程的方法。

## 2. binder 的基本工作流程

如果阅读了 预备知识-驱动入门 ，应该知道，访问一个驱动和访问一个磁盘上的文件流程大体一致（驱动类型不同，访问方法有些许变化），binder 驱动的基本使用流程如下：

* open 函数打开驱动
* mmap 完成映射
* 调用 ioctl 函数发送或者接收数据
* close 函数关闭驱动

当然这里会涉及到两个进程：

![](https://gitee.com/stingerzou/pic-bed/raw/master/20220917134845.png)

这里又会引出一个问题，A 进程发送的数据 x，binder 驱动是把它发送给 b 进程还是 c 进程？

为了解决这个问题，就需要引入一个管家 manager，manager 有一个编号0，其他进程把这个编号发送给 binder 驱动，驱动就知道是要发送数据给 manager。

b 进程需要事先在 manager 这里注册登记（同样使用binder通信），登记的时候需要记录一个名字,这里假设是 hello，登记完成后， b 进程会在内部记录一个编号，并将这个编号发送给驱动，这里假设这个标号是 1。流程如下图所示：

![img](https://gitee.com/stingerzou/pic-bed/raw/master/20220918101642.png)

A 进程给B进程发送数据的流程就变成了下面这样：

1. 获取到 b 进程的编号 1

![](https://gitee.com/stingerzou/pic-bed/raw/master/20220917142222.png)

2. 向 b 进程发送数据

   ![img](https://gitee.com/stingerzou/pic-bed/raw/master/20220917143751.png)

ps：以上内容，为方便理解，做了简化

以上就是 binder 框架的工作流程，总结一下就是：

* B 向 manager 注册服务hello，manager 和驱动内部记录其 handle =1；
* A 向 manager 发送查找 hello 服务请求，获得 handle=1；
* A 向 handle= 1 发送数据，驱动根据 handle 值将数据发送给 B 进程
* B 进程接收到 A 进程的数据，调用 hello 函数并返回结果

上面的流程如果每次都调用 open ioctl 等函数来使用， 程序就会显得异常的繁琐。Android 系统对 binder 的操作做了封装，以简化其操作，我们接下来看一下 c 层封装。

## 3. binder c 层封装

### 3.1 对象与流程

在 c 层，涉及到了四个对象：

* client：客户端向 servicemanager 获取到服务，通过 binder 远程执行服务中的函数
* server：向 servicemanager 注册服务，等待 client 的远程调用
* servicemamager：用于管理服务
* binder驱动

ps: 在源码的 frameworks/native/cmds/servicemanager 目录下有一个示例程序 bctest.c 可用于 c 层的学习，需要注意的是在 Android-10 上，这个程序是错误的。需要简单的修改才能正常使用，但对于我们学习仍有参考价值。

c 层的工作流程如下：

![img](https://gitee.com/stingerzou/pic-bed/raw/master/20220917154127.png)

接下来我们先了解 c 层对 binder 使用封装的 API：

### 3.2  C层API

#### binder_open

```c
struct binder_state *binder_open(const char* driver, size_t mapsize)
```

binder_open 用于打开 binder 驱动，第一个参数一般固定为 "/dev/binder"，第二个参数为驱动需要开辟的用于进程通信的内核内存的大小，单位为字节。返回值是一个结构体，本文称其为 binder 句柄：

```c
struct binder_state
{
    int fd; // "/dev/binder" 对应的句柄
    void *mapped; //用户态的内存指针，该段内存与内核中的一段内存完成了 mmap 映射
    size_t mapsize; //大小
};
```

#### binder_call

```c
int binder_call(struct binder_state *bs,
                struct binder_io *msg, struct binder_io *reply,
                uint32_t target, uint32_t code)
```

binder_call 用于发起远程函数调用（调用另一个进程中的函数），bs 是 binder 句柄。binder_io 是传输数据的格式，msg 是传出的数据，reply是收到的数据，target 用于告诉 servicemanger 我要使用那个service，即指定目标进程。code 用于表示我要调用那个函数。

#### binder_loop

用于服务端或 service_manager 进入循环读数据解析数据

```c
void binder_loop(struct binder_state *bs, binder_handler func)
```

bs 是 handler 指针，binder_handler 是函数指针，是一个收到数据的回调：

```c
typedef int (*binder_handler)(struct binder_state *bs,
                              struct binder_transaction_data_secctx *txn,
                              struct binder_io *msg,
                              struct binder_io *reply);
```

bs 是binder句柄， txn，msg 是收到的数据， reply 是我们要回复给client的数据

### 3.3 示例程序

示例程序可以在 https://github.com/ahaoddu/AndroidSourceLearn/tree/main/Demos/BinderCDemo 下载到。

#### 3.3.1 准备工作

* 参考 frameworks/native/cmds/servicemanager 目录下的程序。在目录 frameworks/native/cmds/ 下创建文件夹 MyBinderTest，将参考代码中的 binder.c binder.h 拷贝到 MyBinderTest 目录。为方便后期打 log 调试，我们将 binder.c binder.h 再复制一份，其中一份名字修改为 binder4Client.c binder4Client.h，另一份修改为 binder4Server.c binder4Server.h
* 创建 binder_client.c binder_server.c 两个文件

#### 3.3.2 Android.bp

我们需要先写一个用于构建的文件 Android.bp:

```c
cc_defaults {
    name: "bindertestflags",

    cflags: [
        "-Wall",
        "-Wextra",
        "-Werror",
        "-Wno-unused-parameter",
        "-Wno-missing-field-initializers",
        "-Wno-unused-parameter",
        "-Wno-unused-variable",
        "-Wno-incompatible-pointer-types",
        "-Wno-sign-compare",
    ],
    product_variables: {
        binder32bit: {
            cflags: ["-DBINDER_IPC_32BIT=1"],
        },
    },

    shared_libs: ["liblog"],
}

cc_binary {
    name: "binderclient",
    defaults: ["bindertestflags"],
    srcs: [
        "binder_client.c",
        "binder4Client.c",
    ],
}

cc_binary {
    name: "binderserver",
    defaults: ["bindertestflags"],
    srcs: [
        "binder_server.c",
        "binder4Server.c",
    ],
}


```

接下来我们来写服务端程序，binder_server.c：

```c
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <linux/types.h>
#include<stdbool.h>
#include <string.h>

#include <private/android_filesystem_config.h>

#include "binder4Server.h"

#define LOG_TAG "BinderServer"
#include <log/log.h>

//常量，用于确定远程调用哪个函数
#define HELLO_SVR_CMD_SAYHELLO     1
#define HELLO_SVR_CMD_SAYHELLO_TO  2

//从参考程序中拷贝过来
int svcmgr_publish(struct binder_state *bs, uint32_t target, const char *name, void *ptr)
{
    int status;
    unsigned iodata[512/4];
    struct binder_io msg, reply;

    bio_init(&msg, iodata, sizeof(iodata), 4);
    bio_put_uint32(&msg, 0);  // strict mode header
    bio_put_uint32(&msg, 0);
    bio_put_string16_x(&msg, SVC_MGR_NAME);
    bio_put_string16_x(&msg, name);
    bio_put_obj(&msg, ptr);
    bio_put_uint32(&msg, 0);
    bio_put_uint32(&msg, 0);

    if (binder_call(bs, &msg, &reply, target, SVC_MGR_ADD_SERVICE)) {
        fprintf(stderr, "svcmgr_public 远程调用失败\n");
        return -1;
    }
   
    status = bio_get_uint32(&reply); //调用成功返回0
    binder_done(bs, &msg, &reply);

    return status;
}

//定义被远程调用的函数
void sayhello(void)
{
	static int cnt = 0;
	fprintf(stderr, "say hello : %d\n", ++cnt);
}


int sayhello_to(char *name)
{
	static int cnt = 0;
	fprintf(stderr, "say hello to %s : %d\n", name, ++cnt);
	return cnt;
}


//收到消息后的回调函数
int hello_service_handler(struct binder_state *bs,
                   struct binder_transaction_data_secctx *txn_secctx,
                   struct binder_io *msg,
                   struct binder_io *reply)
{
    struct binder_transaction_data *txn = &txn_secctx->transaction_data;

	/* 根据txn->code知道要调用哪一个函数
	 * 如果需要参数, 可以从msg取出
	 * 如果要返回结果, 可以把结果放入reply
	 */

	/* sayhello
	 * sayhello_to
	 */

    uint16_t *s;
	char name[512];
    size_t len;
    //uint32_t handle;
    uint32_t strict_policy;
	int i;


    // Equivalent to Parcel::enforceInterface(), reading the RPC
    // header with the strict mode policy mask and the interface name.
    // Note that we ignore the strict_policy and don't propagate it
    // further (since we do no outbound RPCs anyway).
    strict_policy = bio_get_uint32(msg);

    switch(txn->code) {
    case HELLO_SVR_CMD_SAYHELLO:
		sayhello();
		bio_put_uint32(reply, 0); /* no exception */
        return 0;

    case HELLO_SVR_CMD_SAYHELLO_TO:
		/* 从msg里取出字符串 */
		s = bio_get_string16(msg, &len);  //"IHelloService"
		s = bio_get_string16(msg, &len);  // name
		if (s == NULL) {
			return -1;
		}
		for (i = 0; i < len; i++)
			name[i] = s[i];
		name[i] = '\0';

		/* 处理 */
		i = sayhello_to(name);

		/* 把结果放入reply */
		bio_put_uint32(reply, 0); /* no exception */
		bio_put_uint32(reply, i);

        break;

    default:
        fprintf(stderr, "unknown code %d\n", txn->code);
        return -1;
    }

    return 0;
}

//收到消息后的回调函数
int test_server_handler(struct binder_state *bs,
                struct binder_transaction_data_secctx *txn_secctx,
                struct binder_io *msg,
                struct binder_io *reply)
{
    struct binder_transaction_data *txn = &txn_secctx->transaction_data;

    int (*handler)(struct binder_state *bs,
                   struct binder_transaction_data *txn,
                   struct binder_io *msg,
                   struct binder_io *reply);
    //注册的时候 hello_service_handler 指针传给了驱动
    //驱动返回给服务器的 txn->target.ptr 会指向 hello_service_handler 函数
	handler = (int (*)(struct binder_state *bs,
                   struct binder_transaction_data *txn,
                   struct binder_io *msg,
                   struct binder_io *reply))txn->target.ptr;

	return handler(bs, txn, msg, reply);
}


int main(int argc, char **argv)
{
    struct binder_state *bs;
    uint32_t svcmgr = BINDER_SERVICE_MANAGER;
    uint32_t handle;
	int ret;

    ALOGW("BinderServer 开始启动");
  
    //打开驱动
    bs = binder_open("/dev/binder", 128*1024);
    if (!bs) {
        fprintf(stderr, "failed to open binder driver\n");
        return -1;
    }

	//添加服务
	ret = svcmgr_publish(bs, svcmgr, "hello", hello_service_handler);
    if (ret) {
        fprintf(stderr, "failed to publish hello service\n");
        return -1;
    } else {
        ALOGW("BinderServer 添加 hello service 成功");
    }
  
    ALOGW("服务器进入消息循环");
    binder_loop(bs, test_server_handler);
    ALOGW("服务器退出消息循环");
    return 0;
}
```

接下来写客户端代码 binder_client.c

```c
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <linux/types.h>
#include <stdbool.h>
#include <string.h>

#include <private/android_filesystem_config.h>

#include "binder4Client.h"

#define LOG_TAG "BinderClient"
#include <log/log.h>

#define HELLO_SVR_CMD_SAYHELLO     1
#define HELLO_SVR_CMD_SAYHELLO_TO  2

int g_handle = 0;
struct binder_state *g_bs;

//从参考代码中拷贝过来
uint32_t svcmgr_lookup(struct binder_state *bs, uint32_t target, const char *name)
{
    uint32_t handle;
    unsigned iodata[512/4];
    struct binder_io msg, reply;

    bio_init(&msg, iodata, sizeof(iodata), 4);
    bio_put_uint32(&msg, 0);  // strict mode header
    bio_put_uint32(&msg, 0);
    bio_put_string16_x(&msg, SVC_MGR_NAME);
    bio_put_string16_x(&msg, name);

    if (binder_call(bs, &msg, &reply, target, SVC_MGR_CHECK_SERVICE)) {
        ALOGW("binder client 查找服务 %s 失败", name);
        return 0;
    }

    handle = bio_get_ref(&reply);
  

    if (handle)
        binder_acquire(bs, handle);

    binder_done(bs, &msg, &reply);

    return handle;
}

void sayhello(void)
{
    unsigned iodata[512/4];
    struct binder_io msg, reply;

	/* 构造binder_io */
    bio_init(&msg, iodata, sizeof(iodata), 4);
   

	/* 放入参数 */
    bio_put_uint32(&msg, 0);  // strict mode header
    bio_put_string16_x(&msg, "IHelloService");

	/* 调用binder_call */
    if (binder_call(g_bs, &msg, &reply, g_handle, HELLO_SVR_CMD_SAYHELLO))
        return ;

	/* 从reply中解析出返回值 */
    binder_done(g_bs, &msg, &reply);

}

int main(int argc, char **argv)
{
    int fd;
    struct binder_state *bs;
    uint32_t svcmgr = BINDER_SERVICE_MANAGER;
	int ret;

    bs = binder_open("/dev/binder", 128*1024);
    if (!bs) {
        fprintf(stderr, "failed to open binder driver\n");
        return -1;
    }

    g_bs = bs;

	/* get service */
	g_handle = svcmgr_lookup(bs, svcmgr, "hello");
	if (!g_handle) {
        ALOGW("binder client 查找服务 hello 失败");
        return -1;
	} else {
        ALOGW("binder client 查找服务成功 handle = %d", g_handle);
    }

    //调用服务
    sayhello();

}
```

在项目目录下执行 mmm . 命令，程序即可编译完成。编译完成后可以在 out/target/product/generic_x86_64/system/bin/ 目录下找到可执行程序，通过 adb push 命令将其传送到模拟器的 /data/local/tmp 目录下，就可以通过 adb shell 指向我们的程序了。具体可以参考[预备知识-如何在Android平台执行C/C++程序](https://github.com/ahaoddu/AndroidSourceLearn/blob/main/2.%E9%A2%84%E5%A4%87%E7%9F%A5%E8%AF%86-%E5%A6%82%E4%BD%95%E5%9C%A8Android%E5%B9%B3%E5%8F%B0%E6%89%A7%E8%A1%8CC%20C%2B%2B%E7%A8%8B%E5%BA%8F.md)。

## 遇到的问题

示例代码 bctest.c 在 Android10 中添加服务，查询服务均失败。给 service_manager.c 打log发现 bctest 发送的数据格式与service_manager 在头部差了一个0，添加数据，问题解决。
