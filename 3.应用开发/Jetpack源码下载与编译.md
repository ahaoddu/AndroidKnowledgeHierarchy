开发环境: Ubuntu 20.04	

## 下载 repo
```bash
mkdir ~/bin
# 添加环境变量
export PATH=~/bin:$PATH
# 使用清华镜像
curl https://mirrors.tuna.tsinghua.edu.cn/git/git-repo > ~/bin/repo
chmod a+x ~/bin/repo

#repo的运行过程中会尝试访问官方的git源更新自己，
# 如果想使用tuna的镜像源进行更新，可以将如下内容复制到你的~/.bashrc 或 ~/.zshrc里
export REPO_URL='https://mirrors.tuna.tsinghua.edu.cn/git/git-repo'
```
## 源码下载
```bash
repo init -u https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/platform/manifest -b androidx-main-release

repo sync	
```

## 编译并通过 Android Studio 打开工程

```bash
# 源码提供了特定版本的 Android Studio
cd frameworks/support
./studiow m
```
## 

