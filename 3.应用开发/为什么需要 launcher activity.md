# 【转载】为什么需要 launcher activity

## 添加背景“优化”启动速度

App 启动后我们的第一个界面是什么呢？ 很多 App 会有一个闪屏广告页，另外一些会存在一个 Launcher 页，而不会直接去主界面。这是为什么呢？

App 启动分为冷启动和热启动， 热启动比较简单，其实就是后台进程切换到前台。 但冷启动不一样，它需要创建进程、走 Application 初始化等步骤，然后才轮到 Activity 的启动。这个流程是很复杂的，也比较耗时，如果业务上又在 Application.onCreate 里做一堆初始化逻辑，那么这个过程就更慢了。

我们做优化时有一种方式是：让用户感知不到慢，一般是展示一些东西给用户，例如进度条、loading动画等。 Android 官方也采取了这种方式，就是立刻让用户看到界面，而这个界面展示什么呢？这个时候 Activity 在 theme 里提供背景图就派上用途了。

而 Activity 默认的背景就是白色，如果你没加任何处理，你会看到你的 App 冷启动时会出现闪白的情况。 因此我们需要提供一个自定义的背景图片，让用户看到更多东西，而不只是一片白色， 这就是 LauncherActivity 的一个功能。

其次，在这段时间，Activity.onCreate 都没被触发的，因此我们没办法在这段时间做沉浸式状态栏，我们会看到状态栏那里是黑色，进入主界面时，还是有不协调的感觉，特别是挖孔屏盛行后，有的手机那里特别高。 我们没有特别好的方式解决它，一般的做法是让 LauncherActivity 配置成全屏，界面切换时，就不会那么的突兀了，而独立的 LauncherActivity 也不需要我们去处理跳转到主界面后非全屏的切换问题，在 theme 里配置就行了，这就是 LauncherActivity 的第二个功能。（更新：在一些挖孔屏上，仅仅全屏，依旧会存在挖孔屏区域黑色的情况，这个时候我们需要在 theme 里加上 `<item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>`， 不过它需要放在 value-v27 目录下）

```xml
<activity  
    android:name=".LauncherActivity"
    android:theme="@style/AppTheme.Launcher">
    <intent-filter>
        <category android:name="android.intent.category.LAUNCHER"/>
        <action android:name="android.intent.action.MAIN"/>
    </intent-filter>
</activity>  
```

```xml
<style name="AppTheme.Launcher">  
    <item name="android:windowFullscreen">true</item>
    <item name="android:windowBackground">@drawable/launcher_bg</item>
</style>  
```

drawable/launcher_bg：

```xml
<?xml version="1.0" encoding="utf-8"?>  
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">  
    <item android:drawable="@color/qmui_config_color_white"/>
    <item android:drawable="@mipmap/ic_launcher" android:gravity="center"/>
</layer-list>  
```
适配 darkmode：
drawable-night/launcher_bg:

```xml
<?xml version="1.0" encoding="utf-8"?>  
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">  
    <item android:drawable="@color/qmui_config_color_pure_black"/>
    <item android:drawable="@mipmap/ic_launcher" android:gravity="center"/>
</layer-list>  
```

## A/B Test

如果我们想做主界面的 A/B Test，或者某些场景产品希望调其它的界面，针对这种场景，我们可以在 LauncherActivity 里做跳转分发逻辑，大型 App 肯定会用到的。

## 参考资料

* 本文转载自 [QMUI实战(一)—为何我们要使用 LauncherActivity?](http://blog.cgsdream.org/2019/12/08/qmui-gank-01/)，并做了简单修改。