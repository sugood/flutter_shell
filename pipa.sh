#!/bin/sh

#当前工程绝对路径
project_path=$(pwd)

#xCode build 出来的APP文件有所优化，比Flutter build ios 的Runner.app要小
#------------------必须修改：XCODE工程导出路径----------------#
runner_path=~/Library/Developer/Xcode/DerivedData/Runner-bsrdqyyshhsictbeoknvquvcxcsm/Build/Products/Release-iphoneos/Runner.app

#-------------------可选：自己的plist配置路径------------------#
export_plist_path=${project_path}/shell/scriptTest.plist

#-------------------可选：修改为自己的APP名称------------------#
app_name="APP名称"

#----------------可选：将Runner替换成自己的工程名---------------#
project_name=Runner

#----------------可选：将Runner替换成自己的sheme名--------------#
scheme_name=Runner

#打包模式 Debug/Release
development_mode=Release

#导出.ipa文件所在路径
ipa_path=${project_path}/prod/ipa/

#导出签名.ipa文件所在路径
sign_path=${ipa_path}/sign

#导出未签名.ipa文件所在路径
unsign_path=${ipa_path}/unsign

#导出未签名.Payload文件所在路径
payload_path=${unsign_path}/Payload

clean_tips="执行flutter clean(默认:n) [ y/n ]"
echo $clean_tips
read  -t 5 is_clean
if [  ! -n "${is_clean}" ];then
	is_clean="n"
fi
while([[ $is_clean != "y" ]] && [[ $is_clean != "n" ]])
do
  echo "错误!只能输入[ y/n ] ！！！"
  echo $clean_tips
  read is_clean
done

echo "请输入选择模式(默认:0) [ UnSign: 0 AdHoc: 1 ] "
read  -t 5 number
if [  ! -n "${number}" ];then
	number=0
fi
while([[ $number != 0 ]] && [[ $number != 1 ]])
do
  echo "错误!只能输入0或者1！！！"
  echo "请输入选择模式? [ UnSign: 0 AdHoc: 1 ] "
  read number
done

if [ ${is_clean} = "y" ];then
  echo "=============== 开始清理 ==============="
	flutter clean
fi

echo "=============== 构建FLUTTER_IOS工程 ==============="
if [ $number == 0 ];then
  flutter build ios --release --no-codesign
else
  flutter build ios
fi
#flutter build ios --release --no-codesign --obfuscate --split-debug-info=./symbols

#如果有product/ipa文件夹则删除，然后再创建一个空文件夹
if [ -d ${ipa_path} ]; then
  rm -rf ${ipa_path}
fi
#创建目录
mkdir -p ${ipa_path}

#rm -rf ${ipa_path}

if [ $number == 0 ];then
  #无签名打包
  echo "=============== 正在编译XCODE工程:${development_mode} ==============="
  xcodebuild build -workspace ios/${project_name}.xcworkspace -scheme ${scheme_name} -configuration ${development_mode}

  mkdir -p ${payload_path}

  cp -r ${runner_path} ${payload_path}

  cd ${unsign_path}

  echo "=============== 读取APP信息 ==============="
  #info.plist路径
  info_plist="Payload/Runner.app/info.plist"
  version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$info_plist")
  build=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$info_plist")
  time=$(date "+%Y%m%d_%H%M")
  appName="$app_name""_v$version""_b$build""_$time.ipa"

  echo "=============== 优化Framework大小 ==============="
  xcrun bitcode_strip ${payload_path}/Runner.app/Frameworks/Flutter.framework/Flutter -r -o ${payload_path}/Runner.app/Frameworks/Flutter.framework/Flutter
  xcrun bitcode_strip ${payload_path}/Runner.app/Frameworks/AgoraRtcKit.framework/AgoraRtcKit -r -o ${payload_path}/Runner.app/Frameworks/AgoraRtcKit.framework/AgoraRtcKit
  xcrun bitcode_strip ${payload_path}/Runner.app/Frameworks/App.framework/App -r -o ${payload_path}/Runner.app/Frameworks/App.framework/App

  echo "=============== 生成IPA(压缩Payload文件并修改文件名为IPA) ==============="
  zip -r ${appName} *

  if [ -e $unsign_path/$appName ]; then
    echo "=============== IPA包已导出:$unsign_path/$appName ==============="
    open $unsign_path
  else
    echo '=============== IPA包导出失败 ==============='
    exit 1
  fi

else
  #Ad hoc 打包
  echo "=============== 正在编译工程:${development_mode} ==============="
  xcodebuild \
  archive -workspace ${project_path}/ios/${project_name}.xcworkspace \
  -scheme ${scheme_name} \
  -configuration ${development_mode} \
  -archivePath ${ipa_path}/${project_name}.xcarchive  -quiet  || exit

  echo ''
  echo '=============== 开始IPA打包 ==============='
  xcodebuild -exportArchive -archivePath ${ipa_path}/${project_name}.xcarchive \
  -configuration ${development_mode} \
  -exportPath ${sign_path} \
  -exportOptionsPlist ${export_plist_path} \
  -quiet || exit

  if [ -e $sign_path/$app_name.ipa ]; then
    echo "=============== IPA包已导出:$sign_path/$app_name.ipa ==============="
    open $sign_path
  else
    echo '=============== IPA包导出失败 ==============='
    exit 1
  fi
fi
exit 0