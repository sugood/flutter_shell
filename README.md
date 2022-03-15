# 系统信息
- System version: MacOS 12
- Flutter version: 1.22.5
- Dart version: 2.10.4
- Android Studio version: 4.1.1

# 介绍

- APK优化包体大小
- APK多渠道打包
- APK一键打包脚本


- IPA优化包体大小
- IPA无签名打包
- IPA一键打包脚本




# 安卓

## APK优化包体大小

1. 优化图片等资源大小，删除无用资源
2. 只选择保留必要的so库。第三方SDK也尽量只里保留必要的so库，优化后的包体至少减少几十兆

参考修改android/app/build.gradle 文件
```
    buildTypes {
        release {
            ndk{
                //"armeabi","armeabi-v7a","arm64-v8a","x86_64","x86"  //x86是兼容模拟器的
                abiFilters "armeabi","armeabi-v7a","arm64-v8a"  //手机没什么x86框架的,只包含arm32和arm64即可
            }
        }
    }
```

## 安卓多渠道配置与打包

### 一、原理与介绍
- 从 Flutter v1.17 开始，Flutter 命令工具增加了自定义参数的功能 --dart-define，我们可以用这个命令参数在打包或运行 App 时设置参数。这样我们就能在Flutter代码和原生代码中获取传过来的参数，从而实现多渠道功能。
- 假设我们设置5个渠道 1、应用宝， 2、华为商店， 3、小米商店，4、OPPO商店 5、VIVO商店


#### 二、Flutter代码配置


**1、获取参数**


配置文件路径：lib/main.dart 

```
/// 这里定义环境变量配置
class EnvironmentConfig {
  static const CHANNEL = String.fromEnvironment('CHANNEL');
  //DEBUG = Y 是调试模式，其他为生产模式
  static const DEBUG = String.fromEnvironment('DEBUG');
}

```

**2、任意的地方使用参数**


```
#获取CHANNEL 参数值
String appMarket = EnvironmentConfig.CHANNEL；
#获取DEBUG 参数值
String debug = EnvironmentConfig.DEBUG；
```

### 三、Android代码配置

**1、获取参数**


配置文件路径：android/app/build.gradle 
```
/// 获取渠道参数使用,这里设置一下默认值
def dartEnvironmentVariables = [
        CHANNEL: 'YYB',
        DEBUG: '',
]

if (project.hasProperty('dart-defines')) {
    dartEnvironmentVariables = dartEnvironmentVariables + project.property('dart-defines')
            .split(',')
            .collectEntries { entry ->
                def pair = URLDecoder.decode(entry).split('=')
                [(pair.first()): pair.last()]
            }
}

```


**2、使用**

配置文件路径：android/app/build.gradle 

```
//例子：打包APK时修改文件名带上渠道参数，还有一些SDK也可以通过这种方式设置参数
//dartEnvironmentVariables.CHANNEL 使用参数
android{
   android.applicationVariants.all {
        variant ->
            variant.outputs.all {
                output ->
                    def outputFile = output.outputFile
                    if (outputFile.name.contains("release")) {
                        outputFileName = "APP_${getDateTime()}_${dartEnvironmentVariables.CHANNEL}.apk"
                    }
            }
    }
}

```

### 四、多渠道调试与打包指令

```
# 调试例子1：设置渠道为应用宝。
flutter run --dart-define=CHANNEL=YYB

# 调试例子2：设置渠道为应用宝。DEBUG参数是Y
flutter run --dart-define=CHANNEL=YYB --dart-define=DEBUG=Y

#打包例子1：打包应用宝渠道包
flutter build apk --dart-define=CHANNEL=YYB

#打包例子2：打包应用宝渠道包,DEBUG参数是Y
flutter build apk --dart-define=CHANNEL=YYB --dart-define=DEBUG=Y

```



## 安卓一键打包脚本

### 一、简单介绍


通过上面的配置和优化后我们就能开始执行脚本打包了，本脚本主要实现了以下功能

1. 可控制是否执行 flutter clean 清理指令（回车或者5秒无指令输入默认不清理）
2. 可控制只打某个渠道包或者全部渠道包（回车或者5秒无指令输入默认打全部包）
3. 可设置渠道种类数组，可无限扩展
4. 成功打包后自动打开文件夹
5. 实现无人值守打包

### 二、项目路径结构

**1、shell 目录存放脚本文件 ，papk.sh 是安卓脚本**

**2、prod 目录导出打包文件**

![paste image](http://imgs.sugood.xyz/1647312989715gwh7br6b.png?imageslim)



### 三、脚本内容，papk.sh

### 四、脚本使用步骤

- 1、在项目根目录创建一个shell文件夹
- 2、在shell目录粘贴papk.sh文件。修改channels渠道数组变量值为自己的，然后保存脚本
- 3、项目根目录执行命令添加执行权限： chmod u+x shell/papk.sh
- 4、项目根目录执行命令：./shell/papk.sh


# 苹果


## 优化包体大小


### 一、常规优化（分发到 App Store 或者 打Ad hoc 测试包）


1. 优化图片等资源大小，删除无用资源，比较简单，而且对于一般的app来说优化效果不大，这里就不详细说明了。
2. 只选择保留必要的指令集类型。xcode 12以上默认是包含armv7和arm64位两种指令集。我们打Release包时可以排除armv7指令集。只保留arm64指令集就可以了 看图操作：

![paste image](http://imgs.sugood.xyz/16473166518576kxhdemn.png?imageslim)

** 如果担心兼容性的，下面再附一张指令集对应手机型号的图 **

![paste image](http://imgs.sugood.xyz/1647316944404xfb2nl60.png?imageslim)

### 二、非常规优化
一般情况下我们使用xcode分发的时候，xcode还会帮我们优化一次代码大小的，包体大概能减少一半以上。然鹅，如果需要自己导出一个无签名的IPA包时我们应该怎么优化包体大小？下面是我总结的操作步骤

#### 1、Flutter导出IPA（共4步）

1. 执行flutter build ios --release 生成Runner.app文件
2. 在Runner.app目录下新建一个Payload文件夹, 并将该 app 拖进去
3. 右键->压缩"Payload"为Payload.zip
4. 将生成的 Payload.zip 文件更名为 xxx.ipa 即可得到 ipa 安装包


#### 2、第一次优化包体大小（共5步）

上面生成的ipa大的离谱。动不动就几百兆。所以，我们需要利用Xcode来帮忙优化一下Runner.app。总体步骤比上面的打包多了一步。

1. 执行flutter build ios --release 生成Runner.app文件
2. ✅ 使用xcode打开项目，然后点击product->build。成功后生成一个新的Runner.app。
3. 在Runner.app目录下新建一个Payload文件夹, 并将该 app 拖进去
4. 右键->压缩"Payload"为Payload.zip
5. 将生成的 Payload.zip 文件更名为 xxx.ipa 即可得到 ipa 安装包


一顿操作后，包体大概能减少几十或者上百兆。看着很可观，但是由于原来的包实在太大，即使减了这么多，可能最终还有一百来兆。

#### 3、第二次优化包体大小（共6步）

1. 执行flutter build ios --release 生成Runner.app文件
2. ✅ 使用xcode打开项目，然后点击product->build。成功后生成一个新的Runner.app。
3. ✅ Runner.app目录下执行指令： xcrun bitcode_strip Runner.app/Frameworks/Flutter.framework/Flutter -r -o Runner.app/Frameworks/Flutter.framework/Flutter
4. 在Runner.app目录下新建一个Payload文件夹, 并将该 app 拖进去
5. 右键->压缩"Payload"为Payload.zip
6. 将生成的 Payload.zip 文件更名为 xxx.ipa 即可得到 ipa 安装包

再一顿操作下来后，包体大概又能减少几十或者上百兆。终于基本优化到一百兆以内，接近用Ad hoc分发的ipa包的大小


#### 4、一些说明

1、 Flutter生成Runner.app比较大的原因

**ios的Flutter二进制文件增加了对bitcode的支持，从而导致体积增大** 

2、 如何优化

执行 xcrun bitcode_strip 指令就能去掉bitcode

xcrun bitcode_strip 指令大家可以自行网上搜索。详细的使用我就不细说了


## 苹果一键打包脚本


### 一、简单介绍


通过上面的”常规优化“后我们就能开始执行脚本打包了，本脚本主要实现了以下功能

1. 可控制是否执行 flutter clean 清理指令（回车或者5秒无指令输入默认不清理）
2. 可控制选择打无签名包还是Ad hoc测试包（回车或者5秒无指令输入默认无签名包）
3. 成功打包后自动打开文件夹
4. 实现无人值守打包
5. 如果要导出无签名包，脚本中添加了”非常规的优化“相关的操作

### 二、项目路径结构

**1、shell 目录存放脚本和plist文件， pipa.sh 是苹果脚本,**

**2、prod 目录导出打包文件**

![paste image](http://imgs.sugood.xyz/16473315418727h0909te.png?imageslim)


### 三、脚本内容，pipa.sh

### 四、plist文件，scriptTest.plist

### 五、脚本使用步骤

- 1、在项目根目录创建一个shell文件夹
- 2、在shell目录粘贴papk.sh文件。修改runner_path变量值为自己xcode导出Runner.app的路劲，然后保存并关闭
- 3、在shell目录粘贴scriptTest.plist文件。修改自己的signingCertificate和teamID的值，然后保存并关闭
- 4、项目根目录执行命令添加执行权限： chmod u+x shell/pipa.sh
- 5、项目根目录执行命令：./shell/papk.sh

