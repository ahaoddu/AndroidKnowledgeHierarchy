
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>

#define LOG_TAG "SeTest"
#include <log/log.h>

int main(int argc, char *argv[])
{
	
	int fd  = -1;
	int ret = -1;
	char *content = "hello test for selinux";
	char *dev_name = "/dev/myse_dev";
	fd = open(dev_name, O_RDWR);
	if(fd < 0)
	{
		ALOGE("open %s error: %s", dev_name, strerror(errno));
		return -1;
	}

	ret = write(fd, content, strlen(content));	
	if(ret < 0)
	{
		ALOGE("write testfile error: %s", strerror(errno));
		return -1;
	}else
	{
		ALOGD("write testfile ok: %d",  ret);
	}
	
	while(1);

	close(fd);

	return 0;
}
