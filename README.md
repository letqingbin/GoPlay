
[English README](https://github.com/dKingbin/GoPlay/blob/master/README.md) | [中文介绍](https://github.com/dKingbin/GoPlay/blob/master/image/README-chs.md)

# GoPlay
- GoPlay is a media player framework for iOS. Based on FFmpeg and OpenGL ES 2.0. support all formats and custom your own filters by GLSL.

### Build iOS

build script is based on [FFmpeg-iOS-build-script](https://github.com/kewlbear/FFmpeg-iOS-build-script)
	
* To build everything:
```
./build-ffmpeg.sh
```	
* PS
```
After compile, if you want to custom your own library, you shoud notice three points: 
1) copy ./ffmpeg-3.4.1/libavformat/avc.h  --->  ./FFmpeg-iOS/include/libavformat/
2) copy ./FFmpeg-iOS ---> ./GoPlay/GoPlay/Vendor/FFmpeg/ 
3) config: Build Settings - Header Search Paths - "$(SRCROOT)/GoPlay/Vendor/FFmpeg/FFmpeg-iOS/include"
```

## Features

- H.264/H.265(hevc) hardware accelerator (VideoToolBox)
- support FFmpeg software Decode 
- support all formats based on FFmpeg, including RTMP, RTSP, HTTP/HTTPS and so on
- support custom filter(based on OpenGL ES 2.0 glsl)
- support filter chain between source and display (refer GPUImage)
- support watermark filter
- VR video and arcball control
- accurate seek support
- powerful robust algorithm for audio and video synchronization 
- support adaptive  frame drop
- video-output: OpenGL ES 2.0 
- audio-output: AudioUnit

#### Dependencies

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

#### Basic Usage

```
PlayViewController* vc = [[PlayViewController alloc]init];
vc.url = @"";	//input video/audio url
[self.navigationController pushViewController:vc animated:YES];
```

#### Advanced Usage

```
//custom your own player based on FFPlay/FFFilter/FFView;
//PlayViewController is a demo.
```

## Screenshots
### iOS

 - plane video
 
![GoPlay_Plane](https://github.com/dKingbin/GoPlay/blob/master/image/GoPlay_Plane.png)
  
 - vr video
 
![GoPlay_VR](https://github.com/dKingbin/GoPlay/blob/master/image/GoPlay_VR.png)

 - video with watermark
 
![GoPlay_Watermark](https://github.com/dKingbin/GoPlay/blob/master/image/GoPlay_Watermark.png)
   
 
## Communication

- GitHub : [dKingbin](https://github.com/dKingbin)
- Email : loveforjyboss@163.com


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
