
[English README](https://github.com/dKingbin/GoPlay/blob/master/README.md)   |  [原理详解](https://github.com/dKingbin/GoPlay/blob/master/image/GoPlay-Principle-chs.md)

# GoPlay

- GoPlay 是一款基于FFmpeg/OpenGL ES 2.0 的iOS播放器。支持FFmpeg内嵌的所有格式。而且可以自定义各种滤镜, 包括VR、水印等。

### 编译方式

编译脚本基于 [FFmpeg-iOS-build-script](https://github.com/kewlbear/FFmpeg-iOS-build-script)进行了一部分改动。

* 默认编译:
```
./build-ffmpeg.sh
```	
* 自定义编译:
```
如果要自定义FFmpeg脚本功能, 那么注意以下三点:
1) 拷贝 ./ffmpeg-3.4.1/libavformat/avc.h  到  ./FFmpeg-iOS/include/libavformat/
2) 拷贝 ./FFmpeg-iOS 到 ./GoPlay/GoPlay/Vendor/FFmpeg/ 
3) 配置工程项目的FFmpeg头文件路径: Build Settings - Header Search Paths - "$(SRCROOT)/GoPlay/Vendor/FFmpeg/FFmpeg-iOS/include"
```

## 功能特点

- 支持 H.264 硬件解码（VideoToolBox）。
- 支持FFmpeg软解码
- 支持FFmpeg所有的内嵌格式, 包括RTMP, RTSP, HTTP/HTTPS等
- 支持自定义滤镜(基于OpenGL ES 2.0 GLSL)
- 支持自定义滤镜链(可以参考GPUImage)
- 支持水印滤镜
- 支持VR视频播放和ArcBall控制视频转动
- 支持精准Seek操作
- 鲁棒性非常好的音视频同步算法
- 支持自适应丢帧算法
- 视频输出: OpenGL ES 2.0 
- 音频输出: AudioUnit

#### 相关依赖库

```
// iOS
- AVFoundation.framework
- AudioToolBox.framework
- VideoToolBox.framework
- libiconv.tbd
- libbz2.tbd
- libz.tbd

- FFmpeg 3.4.1
```

#### 基本用法

```
PlayViewController* vc = [[PlayViewController alloc]init];
vc.url = @"";	//input video/audio url
[self.navigationController pushViewController:vc animated:YES];
```

#### 高级用法

```
//代码中的PlayViewController仅仅是一个Demo.
//可以在FFPlay/FFFilter/FFView 基础上自定义自己的播放器
```

## 视频截图
### iOS

- 正常播放视频

![GoPlay_Plane](https://github.com/dKingbin/GoPlay/blob/master/image/GoPlay_Plane.png)

- VR视频

![GoPlay_VR](https://github.com/dKingbin/GoPlay/blob/master/image/GoPlay_VR.png)

- 水印滤镜

![GoPlay_Watermark](https://github.com/dKingbin/GoPlay/blob/master/image/GoPlay_Watermark.png)


## 联系方式

- GitHub : [dKingbin](https://github.com/dKingbin)
- Email : loveforjyboss@163.com
- QQ群 : 527359948 (GoPlay交流群)

### License

```
Copyright (c) 2019 dKingbin
Licensed under LGPLv2.1 or later
```

GoPlay required features are based on or derives from projects below:
- LGPL
  - [FFmpeg](http://git.videolan.org/?p=ffmpeg.git)
  - [ijkplayer](https://github.com/bilibili/ijkplayer)
  - [kxmovie](https://github.com/kolyvan/kxmovie)

- GNU v3.0
  - [SGPlay](https://github.com/libobjc/SGPlayer)

- BSD 3-Clause
  - [GPUImage](https://github.com/BradLarson/GPUImage)

- MIT
  - [FFmpeg-iOS-build-script](https://github.com/kewlbear/FFmpeg-iOS-build-script)
