# Binder之C层示例与分析

binder 是一个 linux 驱动，是 Android 中高效的跨进程通信方案。用于 Android 中的跨进程函数调用。

## 1.涉及的对象与流程

binder 基于 CS 模型，参与跨进程通信的对象包括了：

* client：客户端
* server：服务端
* servicemamager：用于管理服务
* binder驱动：提供跨进程的数据传输功能


其工作流程如下：
* server 通过 binder 驱动向 servicemanager 发送注册服务请求
* client 通过 binder 驱动向 servicemanager 发送获取服务请求，获取到服务的句柄 handle
* client 通过 binder 驱动向 server 发送调用函数的请求
* server 收到 client 的请求，执行函数并将函数执行结果返回给 client
* client 解析收到返回结果

![](https://gitee.com/stingerzou/pic-bed/raw/master/img/20221025113210.png)
    

## 2.编程实践

这里主要参考了源码 `frameworks/native/cmds/servicemanager` 中的示例。源码可以在[这里](https://github.com/ahaoddu/AndroidKnowledgeHierarchy/tree/main/4.Framework%E5%BC%80%E5%8F%91/Demos/binder/BinderCDemo)下载到。

binder 在内核中注册为杂项驱动，要使用 binder 就需要调用 open write read ioctl 等 linux 中的文件操作函数。使用起来较为繁琐。为了简化程序的编写，示例程序对 binder 中的常用操作做了封装，这些封装主要保存在 binder.c binder.h 文件中。

在 `aosp/device/mycompamy/product` 目录下创建项目结构如下：

```bash
BinderTest
├── Android.bp
├── binder.c
├── binder.h
├── client.cpp
└── server.cpp
```

其中 binder.c binder.h 拷贝自 `frameworks/native/cmds/servicemanager` 中的示例。


### 2.1 server 端程序编写

我们需要先把 server.cpp 服务端程序写好，server 主要工作流程如下：

* 打开 open 驱动，完成 mmap 映射
* 定义 hello service
* 添加服务
* 进入 loop， 等待 client 请求服务

server 的 main 函数结构如下：

```cpp
int main(int argc, char **argv)
{
    struct binder_state *bs;
    uint32_t svcmgr = BINDER_SERVICE_MANAGER;
    uint32_t handle;
	int ret;
    
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
    }
    
    binder_loop(bs, test_server_handler);
    return 0;
}
```
接下来，我们来分析 server 端程序：

其中 `struct binder_state *bs` 结构如下：

```cpp
struct binder_state
{
    int fd;
    void *mapped;
    size_t mapsize;
};
```
用于保存 binder_open 的返回结果。binder_open 实现如下：

```cpp
// driver 通常是 "/dev/binder"
// mapsize 是需要 mmap 的内存的大小，不超过 4M，即 4*1024*1024
struct binder_state *binder_open(const char* driver, size_t mapsize)
{
    struct binder_state *bs; //用于存需要返回的值
    struct binder_version vers; 

    bs = malloc(sizeof(*bs)); 
    if (!bs) {
        errno = ENOMEM;
        return NULL;
    }

    bs->fd = open(driver, O_RDWR | O_CLOEXEC); //打开 /dev/binder，拿到内核返回的句柄
    if (bs->fd < 0) {
        fprintf(stderr,"binder: cannot open %s (%s)\n",
                driver, strerror(errno));
        goto fail_open;
    }

    //版本验证
    if ((ioctl(bs->fd, BINDER_VERSION, &vers) == -1) ||
        (vers.protocol_version != BINDER_CURRENT_PROTOCOL_VERSION)) {
        fprintf(stderr,
                "binder: kernel driver version (%d) differs from user space version (%d)\n",
                vers.protocol_version, BINDER_CURRENT_PROTOCOL_VERSION);
        goto fail_open;
    }

    //完成内存映射
    bs->mapsize = mapsize;
    bs->mapped = mmap(NULL, mapsize, PROT_READ, MAP_PRIVATE, bs->fd, 0);
    if (bs->mapped == MAP_FAILED) {
        fprintf(stderr,"binder: cannot map device (%s)\n",
                strerror(errno));
        goto fail_map;
    }

    return bs;

fail_map:
    close(bs->fd);
fail_open:
    free(bs);
    return NULL;
}
```

接下来需要定义我们的 hello 服务：

```cpp
//hello 服务提供的函数1
void sayhello(void)
{
	static int cnt = 0;
	fprintf(stderr, "say hello : %d\n", ++cnt);
}

//hello 服务提供的函数2
int sayhello_to(char *name)
{
	static int cnt = 0;
	fprintf(stderr, "say hello to %s : %d\n", name, ++cnt);
	return cnt;
}


//server 收到 client 远程函数调用后的回调函数，用于处理收到的信息
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


    strict_policy = bio_get_uint32(msg);

    switch(txn->code) {
    //调用函数1
    case HELLO_SVR_CMD_SAYHELLO:
		sayhello();
		bio_put_uint32(reply, 0); /* no exception */
        return 0;
    //调用函数2
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
```

接下来调用 `svcmgr_publish` 添加服务：

```cpp
//bs 是 binder_open 的返回值
//svcmgr 是一个整型常量 0，代表要发送信息给 sevice_manager
//hello_service_handler 是server收到数据后的回调函数，用于处理收到的信息
//当 server 收到远程调用时，hello_service_handler 会存储在 binder_transaction_data->target.ptr 指针中
ret = svcmgr_publish(bs, svcmgr, "hello", hello_service_handler);
```

`svcmgr_publish` 定义在示例代码中的客户端中，这里我们把它拷贝到 binder.c binder.h 中，其具体内容如下：

```cpp
/*
 * target 用于表示要访问的对象，这里都是传 0 ，表示 servicemanager
 * name 表示远程服务的名字
 * ptr 是一个回调函数，当 server 收到数据时，可以回调这个函数
 */
int svcmgr_publish(struct binder_state *bs, uint32_t target, const char *name, void *ptr)
{
    int status;

    unsigned iodata[512/4];
    struct binder_io msg, reply;

    //构造需要发送的数据
    bio_init(&msg, iodata, sizeof(iodata), 4);
    bio_put_uint32(&msg, 0);  // strict mode header
    bio_put_uint32(&msg, 0);
    bio_put_string16_x(&msg, SVC_MGR_NAME);
    bio_put_string16_x(&msg, name);
    bio_put_obj(&msg, ptr);
    bio_put_uint32(&msg, 0);
    bio_put_uint32(&msg, 0);

    //binder_call 发起远程调用
    if (binder_call(bs, &msg, &reply, target, SVC_MGR_ADD_SERVICE)) {
        fprintf(stderr, "svcmgr_public 远程调用失败\n");
        return -1;
    }
   
    //获取返回数据
    status = bio_get_uint32(&reply); //调用成功返回0
    //通知驱动，调用完成
    binder_done(bs, &msg, &reply);

    return status;
}
```

其中最核心的函数是 `binder_call`,该函数用于发起远程调用，其定义如下：

```cpp
int binder_call(struct binder_state *bs,
                struct binder_io *msg, struct binder_io *reply,
                uint32_t target, uint32_t code)
{
    int res;
    //ioctl 向驱动发送的数据格式为  binder_write_read
    struct binder_write_read bwr;

    struct {
        uint32_t cmd;
        struct binder_transaction_data txn;
    } __attribute__((packed)) writebuf;

    unsigned readbuf[32];

    if (msg->flags & BIO_F_OVERFLOW) {
        fprintf(stderr,"binder: txn buffer overflow\n");
        goto fail;
    }

    writebuf.cmd = BC_TRANSACTION;
    writebuf.txn.target.handle = target;
    writebuf.txn.code = code;
    writebuf.txn.flags = 0;
    writebuf.txn.data_size = msg->data - msg->data0;
    writebuf.txn.offsets_size = ((char*) msg->offs) - ((char*) msg->offs0);
    //数据存在这里
    writebuf.txn.data.ptr.buffer = (uintptr_t)msg->data0;
    writebuf.txn.data.ptr.offsets = (uintptr_t)msg->offs0;

    bwr.write_size = sizeof(writebuf);
    bwr.write_consumed = 0;
    bwr.write_buffer = (uintptr_t) &writebuf;

    hexdump(msg->data0, msg->data - msg->data0);
    for (;;) {
        bwr.read_size = sizeof(readbuf);
        bwr.read_consumed = 0;
        bwr.read_buffer = (uintptr_t) readbuf;

        //发起数据传输请求
        res = ioctl(bs->fd, BINDER_WRITE_READ, &bwr);

        if (res < 0) {
            fprintf(stderr,"binder: ioctl failed (%s)\n", strerror(errno));
            goto fail;
        }

        //解析收到的数据
        res = binder_parse(bs, reply, (uintptr_t) readbuf, bwr.read_consumed, 0);
        if (res == 0) {
            return 0;
        }
        if (res < 0) {
            goto fail;
        }
        }
fail:
    memset(reply, 0, sizeof(*reply));
    reply->flags |= BIO_F_IOERROR;
    return -1;
}

```

ioctl 向驱动发送的数据格式为 binder_write_read：

```cpp
struct binder_write_read {
	binder_size_t		write_size;	/* bytes to write */
	binder_size_t		write_consumed;	/* bytes consumed by driver */
	binder_uintptr_t	write_buffer;
	binder_size_t		read_size;	/* bytes to read */
	binder_size_t		read_consumed;	/* bytes consumed by driver */
	binder_uintptr_t	read_buffer;
};

//write_buffer read_buffer 的结构如下
struct {
    uint32_t cmd;
    struct binder_transaction_data txn;
} __attribute__((packed)) writebuf;

//binder_transaction_data 结构如下
struct binder_transaction_data {
	union {
		/* target descriptor of command transaction */
        //写数据，用 handle，表示目标进程
		__u32	handle;
		/* target descriptor of return transaction */
        //收到数据，用 ptr，表示注册时的回调函数地址
		binder_uintptr_t ptr;
	} target;
	binder_uintptr_t	cookie;	/* target object cookie */
    //code 表示要调用那个函数
	__u32		code;		/* transaction command */

	/* General information about the transaction. */
	__u32	        flags;
	pid_t		sender_pid;
	uid_t		sender_euid;
	binder_size_t	data_size;	/* number of bytes of data */
	binder_size_t	offsets_size;	/* number of bytes of offsets */

	/* If this transaction is inline, the data immediately
	 * follows here; otherwise, it ends with a pointer to
	 * the data buffer.
	 */
    //传输的数据
	union {
		struct {
			/* transaction data */
			binder_uintptr_t	buffer;
			/* offsets from buffer to flat_binder_object structs */
			binder_uintptr_t	offsets;
		} ptr;
		__u8	buf[8];
	} data;
};

```
结构稍微有点复杂，涉及的主要数据整理如下：

![](https://gitee.com/stingerzou/pic-bed/raw/master/img/20221025140117.png)

binder_call 的前部分主要是将 binder_io 转换为 binder_write_read，以适应 ioctl 要求的数据格式。接下来的重点就是解析收到的数据：

```cpp
int binder_parse(struct binder_state *bs, struct binder_io *bio,
                 uintptr_t ptr, size_t size, binder_handler func)
{
    int r = 1;
    uintptr_t end = ptr + (uintptr_t) size;

    while (ptr < end) {
        uint32_t cmd = *(uint32_t *) ptr;
        ptr += sizeof(uint32_t);
#if TRACE
        fprintf(stderr,"%s:\n", cmd_name(cmd));
#endif
        switch(cmd) {
        case BR_NOOP:
            break;
        case BR_TRANSACTION_COMPLETE:
            break;
        case BR_INCREFS:
        case BR_ACQUIRE:
        case BR_RELEASE:
        case BR_DECREFS:
#if TRACE
            fprintf(stderr,"  %p, %p\n", (void *)ptr, (void *)(ptr + sizeof(void *)));
#endif
            ptr += sizeof(struct binder_ptr_cookie);
            break;
        case BR_TRANSACTION_SEC_CTX:
        case BR_TRANSACTION: {
            struct binder_transaction_data_secctx txn;
            if (cmd == BR_TRANSACTION_SEC_CTX) {
                if ((end - ptr) < sizeof(struct binder_transaction_data_secctx)) {
                    ALOGE("parse: txn too small (binder_transaction_data_secctx)!\n");
                    return -1;
                }
                memcpy(&txn, (void*) ptr, sizeof(struct binder_transaction_data_secctx));
                ptr += sizeof(struct binder_transaction_data_secctx);
            } else /* BR_TRANSACTION */ {
                if ((end - ptr) < sizeof(struct binder_transaction_data)) {
                    ALOGE("parse: txn too small (binder_transaction_data)!\n");
                    return -1;
                }
                memcpy(&txn.transaction_data, (void*) ptr, sizeof(struct binder_transaction_data));
                ptr += sizeof(struct binder_transaction_data);

                txn.secctx = 0;
            }

            binder_dump_txn(&txn.transaction_data);
            if (func) {
                unsigned rdata[256/4];
                struct binder_io msg;
                struct binder_io reply;
                int res;

                bio_init(&reply, rdata, sizeof(rdata), 4);
                bio_init_from_txn(&msg, &txn.transaction_data);
                res = func(bs, &txn, &msg, &reply);
                if (txn.transaction_data.flags & TF_ONE_WAY) {
                    binder_free_buffer(bs, txn.transaction_data.data.ptr.buffer);
                } else {
                    binder_send_reply(bs, &reply, txn.transaction_data.data.ptr.buffer, res);
                }
            }
            break;
        }
        //收到数据会走这里
        case BR_REPLY: {
            struct binder_transaction_data *txn = (struct binder_transaction_data *) ptr;
            if ((end - ptr) < sizeof(*txn)) {
                ALOGE("parse: reply too small!\n");
                return -1;
            }
            binder_dump_txn(txn);
            if (bio) {
                //将收到的数据转换为 binder_io 格式，并保存到 bio 指向的内存中
                bio_init_from_txn(bio, txn);
                bio = 0;
            } else {
                /* todo FREE BUFFER */
            }
            ptr += sizeof(*txn);
            r = 0;
            break;
        }
        case BR_DEAD_BINDER: {
            struct binder_death *death = (struct binder_death *)(uintptr_t) *(binder_uintptr_t *)ptr;
            ptr += sizeof(binder_uintptr_t);
            death->func(bs, death->ptr);
            break;
        }
        case BR_FAILED_REPLY:
            r = -1;
            break;
        case BR_DEAD_REPLY:
            r = -1;
            break;
        default:
            ALOGE("parse: OOPS %d\n", cmd);
            return -1;
        }
    }

    return r;
}
```

接下来，服务会调用 binder_loop 进入循环等待 client 的请求信息：

```cpp
void binder_loop(struct binder_state *bs, binder_handler func)
{
    int res;
    struct binder_write_read bwr;
    uint32_t readbuf[32];

    bwr.write_size = 0;
    bwr.write_consumed = 0;
    bwr.write_buffer = 0;

    readbuf[0] = BC_ENTER_LOOPER;
    binder_write(bs, readbuf, sizeof(uint32_t));

    for (;;) {
        bwr.read_size = sizeof(readbuf);
        bwr.read_consumed = 0;
        bwr.read_buffer = (uintptr_t) readbuf;

        res = ioctl(bs->fd, BINDER_WRITE_READ, &bwr);

        if (res < 0) {
            ALOGE("binder_loop: ioctl failed (%s)\n", strerror(errno));
            break;
        }

        res = binder_parse(bs, 0, (uintptr_t) readbuf, bwr.read_consumed, func);
        if (res == 0) {
            ALOGE("binder_loop: unexpected reply?!\n");
            break;
        }
        if (res < 0) {
            ALOGE("binder_loop: io error %d %s\n", res, strerror(errno));
            break;
        }
    }
}
```

```cpp
int binder_parse(struct binder_state *bs, struct binder_io *bio,
                 uintptr_t ptr, size_t size, binder_handler func)
{
    int r = 1;
    uintptr_t end = ptr + (uintptr_t) size;

    while (ptr < end) {
        uint32_t cmd = *(uint32_t *) ptr;
        ptr += sizeof(uint32_t);
#if TRACE
        fprintf(stderr,"%s:\n", cmd_name(cmd));
#endif
        switch(cmd) {
        case BR_NOOP:
            break;
        case BR_TRANSACTION_COMPLETE:
            break;
        case BR_INCREFS:
        case BR_ACQUIRE:
        case BR_RELEASE:
        case BR_DECREFS:
#if TRACE
            fprintf(stderr,"  %p, %p\n", (void *)ptr, (void *)(ptr + sizeof(void *)));
#endif
            ptr += sizeof(struct binder_ptr_cookie);
            break;
        case BR_TRANSACTION_SEC_CTX:
        //读到数据会走这里
        case BR_TRANSACTION: {
            struct binder_transaction_data_secctx txn;
            if (cmd == BR_TRANSACTION_SEC_CTX) {
                if ((end - ptr) < sizeof(struct binder_transaction_data_secctx)) {
                    ALOGE("parse: txn too small (binder_transaction_data_secctx)!\n");
                    return -1;
                }
                //收到的数据拷贝到 ptr 中
                memcpy(&txn, (void*) ptr, sizeof(struct binder_transaction_data_secctx));
                ptr += sizeof(struct binder_transaction_data_secctx);
            } else /* BR_TRANSACTION */ {
                if ((end - ptr) < sizeof(struct binder_transaction_data)) {
                    ALOGE("parse: txn too small (binder_transaction_data)!\n");
                    return -1;
                }
                //收到的数据拷贝到 ptr 中
                memcpy(&txn.transaction_data, (void*) ptr, sizeof(struct binder_transaction_data));
                ptr += sizeof(struct binder_transaction_data);

                txn.secctx = 0;
            }

            binder_dump_txn(&txn.transaction_data);
            //调用回调函数
            if (func) {
                unsigned rdata[256/4];
                struct binder_io msg;
                struct binder_io reply;
                int res;

                bio_init(&reply, rdata, sizeof(rdata), 4);
                bio_init_from_txn(&msg, &txn.transaction_data);
                res = func(bs, &txn, &msg, &reply);
                if (txn.transaction_data.flags & TF_ONE_WAY) {
                    binder_free_buffer(bs, txn.transaction_data.data.ptr.buffer);
                } else {
                    binder_send_reply(bs, &reply, txn.transaction_data.data.ptr.buffer, res);
                }
            }
            break;
        }
        case BR_REPLY: {
            struct binder_transaction_data *txn = (struct binder_transaction_data *) ptr;
            if ((end - ptr) < sizeof(*txn)) {
                ALOGE("parse: reply too small!\n");
                return -1;
            }
            binder_dump_txn(txn);
            if (bio) {
                
                bio_init_from_txn(bio, txn);
                bio = 0;
            } else {
                /* todo FREE BUFFER */
            }
            ptr += sizeof(*txn);
            r = 0;
            break;
        }
        case BR_DEAD_BINDER: {
            struct binder_death *death = (struct binder_death *)(uintptr_t) *(binder_uintptr_t *)ptr;
            ptr += sizeof(binder_uintptr_t);
            death->func(bs, death->ptr);
            break;
        }
        case BR_FAILED_REPLY:
            r = -1;
            break;
        case BR_DEAD_REPLY:
            r = -1;
            break;
        default:
            ALOGE("parse: OOPS %d\n", cmd);
            return -1;
        }
    }

    return r;
}
```

到这里，server 端就写好了，binder.c 其实已经很大程度简化了应用程序的编写，深入到 binder.c 内部发现其数据结构和流程都是非常复杂的。

### 2.2 client 端程序编写

接下来开始写客户端 client.cpp，client 的主要工作流程如下：

* 打开 open 驱动，完成 mmap 映射
* 查询服务，获取到服务句柄 handle
* 通过句柄调用远程方法

在 binder.c binder.h 中添加 svcmgr_lookup 用于查找服务

```c++
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
```

接下来定义远程方法调用：

```cpp
int g_handle = 0;
struct binder_state *g_bs;

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
```

实现 main 函数：

```cpp
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
        return -1;
	} 

    //调用服务
    sayhello();

}
```

### 2.3 servicemanager 源码分析

```cpp
int main(int argc, char** argv)
{
    struct binder_state *bs;
    union selinux_callback cb;
    char *driver;

    if (argc > 1) {
        driver = argv[1];
    } else {
        driver = "/dev/binder";
    }
    
    //打开驱动
    bs = binder_open(driver, 128*1024);
    if (!bs) {
#ifdef VENDORSERVICEMANAGER
        ALOGW("failed to open binder driver %s\n", driver);
        while (true) {
            sleep(UINT_MAX);
        }
#else
        ALOGE("failed to open binder driver %s\n", driver);
#endif
        return -1;
    }
    
    //告诉驱动，我是 servicemanager
    if (binder_become_context_manager(bs)) {
        ALOGE("cannot become context manager (%s)\n", strerror(errno));
        return -1;
    }
    //selinux 相关配置，暂时不管它
    cb.func_audit = audit_callback;
    selinux_set_callback(SELINUX_CB_AUDIT, cb);
#ifdef VENDORSERVICEMANAGER
    cb.func_log = selinux_vendor_log_callback;
#else
    cb.func_log = selinux_log_callback;
#endif
    selinux_set_callback(SELINUX_CB_LOG, cb);

#ifdef VENDORSERVICEMANAGER
    sehandle = selinux_android_vendor_service_context_handle();
#else
    sehandle = selinux_android_service_context_handle();
#endif
    selinux_status_open(true);

    if (sehandle == NULL) {
        ALOGE("SELinux: Failed to acquire sehandle. Aborting.\n");
        abort();
    }

    if (getcon(&service_manager_context) != 0) {
        ALOGE("SELinux: Failed to acquire service_manager context. Aborting.\n");
        abort();
    }


    //进入循环
    binder_loop(bs, svcmgr_handler);

    return 0;
}

```

其中循环的回调函数 `svcmgr_handler` 如下:

```cpp
int svcmgr_handler(struct binder_state *bs,
                   struct binder_transaction_data_secctx *txn_secctx,
                   struct binder_io *msg,
                   struct binder_io *reply)
{
    struct svcinfo *si;
    uint16_t *s;
    size_t len;
    uint32_t handle;
    uint32_t strict_policy;
    int allow_isolated;
    uint32_t dumpsys_priority;

    struct binder_transaction_data *txn = &txn_secctx->transaction_data;

    //ALOGI("target=%p code=%d pid=%d uid=%d\n",
    //      (void*) txn->target.ptr, txn->code, txn->sender_pid, txn->sender_euid);

    if (txn->target.ptr != BINDER_SERVICE_MANAGER)
        return -1;

    if (txn->code == PING_TRANSACTION)
        return 0;

    // Equivalent to Parcel::enforceInterface(), reading the RPC
    // header with the strict mode policy mask and the interface name.
    // Note that we ignore the strict_policy and don't propagate it
    // further (since we do no outbound RPCs anyway).
    strict_policy = bio_get_uint32(msg);
    bio_get_uint32(msg);  // Ignore worksource header.
    s = bio_get_string16(msg, &len);
    if (s == NULL) {
        return -1;
    }

    if ((len != (sizeof(svcmgr_id) / 2)) ||
        memcmp(svcmgr_id, s, sizeof(svcmgr_id))) {
        fprintf(stderr,"invalid id %s\n", str8(s, len));
        return -1;
    }

    if (sehandle && selinux_status_updated() > 0) {
#ifdef VENDORSERVICEMANAGER
        struct selabel_handle *tmp_sehandle = selinux_android_vendor_service_context_handle();
#else
        struct selabel_handle *tmp_sehandle = selinux_android_service_context_handle();
#endif
        if (tmp_sehandle) {
            selabel_close(sehandle);
            sehandle = tmp_sehandle;
        }
    }

    switch(txn->code) {
    //获取服务
    case SVC_MGR_GET_SERVICE:
    case SVC_MGR_CHECK_SERVICE:
        s = bio_get_string16(msg, &len);
        if (s == NULL) {
            return -1;
        }
        handle = do_find_service(s, len, txn->sender_euid, txn->sender_pid,
                                 (const char*) txn_secctx->secctx);
        if (!handle)
            break;
        bio_put_ref(reply, handle);
        return 0;
    //添加服务
    case SVC_MGR_ADD_SERVICE:
        s = bio_get_string16(msg, &len);
        if (s == NULL) {
            return -1;
        }
        handle = bio_get_ref(msg);
        allow_isolated = bio_get_uint32(msg) ? 1 : 0;
        dumpsys_priority = bio_get_uint32(msg);
        if (do_add_service(bs, s, len, handle, txn->sender_euid, allow_isolated, dumpsys_priority,
                           txn->sender_pid, (const char*) txn_secctx->secctx))
            return -1;
        break;

    case SVC_MGR_LIST_SERVICES: {
        uint32_t n = bio_get_uint32(msg);
        uint32_t req_dumpsys_priority = bio_get_uint32(msg);

        if (!svc_can_list(txn->sender_pid, (const char*) txn_secctx->secctx, txn->sender_euid)) {
            ALOGE("list_service() uid=%d - PERMISSION DENIED\n",
                    txn->sender_euid);
            return -1;
        }
        si = svclist;
        // walk through the list of services n times skipping services that
        // do not support the requested priority
        while (si) {
            if (si->dumpsys_priority & req_dumpsys_priority) {
                if (n == 0) break;
                n--;
            }
            si = si->next;
        }
        if (si) {
            bio_put_string16(reply, si->name);
            return 0;
        }
        return -1;
    }
    default:
        ALOGE("unknown code %d\n", txn->code);
        return -1;
    }

    bio_put_uint32(reply, 0);
    return 0;
}
```

主要是使用链表的方式来管理注册的服务。

## Android.bp

最后编写 Android.bp

```bash
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
        "client.cpp",
        "binder.c",
    ],
}

cc_binary {
    name: "binderserver",
    defaults: ["bindertestflags"],
    srcs: [
        "server.cpp",
        "binder.c",
    ],
}

```

通过 mm 编译后，参考 [预备知识-如何在Android平台执行C/C++程序](https://github.com/ahaoddu/AndroidSourceLearn/blob/main/2.%E9%A2%84%E5%A4%87%E7%9F%A5%E8%AF%86-%E5%A6%82%E4%BD%95%E5%9C%A8Android%E5%B9%B3%E5%8F%B0%E6%89%A7%E8%A1%8CC%20C%2B%2B%E7%A8%8B%E5%BA%8F.md)即可执行 server，client 程序。

## 参考资料
* [Binder系列1—Binder Driver初探](http://gityuan.com/2015/11/01/binder-driver/)