
[English README](https://github.com/dKingbin/GoPlay/blob/master/README.md)   |  [中文介绍](https://github.com/dKingbin/GoPlay/blob/master/image/README-chs.md)

# GoPlay 原理详解

[GoPlay](https://github.com/dKingbin/GoPlay)是一款基于FFmpeg/OpenGL ES 2.0 的iOS播放器。支持FFmpeg内嵌的所有格式。而且可以自定义各种滤镜, 包括VR、水印等。

## 前言

关于iOS视频播放，苹果提供的AVPlayer性能是非常出色的，但是有个缺点，就是支持播放的格式并不多，仅仅支持mp4/mov/ts等有限的几种格式。显然业界中比较知名的jikplayer确实弥补了这种缺陷，然而ijkplayer是在FFmpeg/ffplay的基础上进行开发的，最终是通过SDL2.0进行显示。在当前大环境下，VR、水印、贴图、九宫格等滤镜盛行，在ijkplayer中默认是支持avfilter滤镜的，但是并没有支持GPU滤镜；那么有没有一种办法可以播放AVPlayer不支持格式的视频，又能够在视频上无限制的加滤镜，例如GPUImage那么方便那么丝滑的做法呢？上面两个痛点也就是GoPlay解决的问题。

## 原理

### 关于格式支持

关于格式支持，采用了业界比较出名的FFmpeg解封装不同的视频格式；在解码阶段，如果开启了VideoToolBox硬解码，那么就采用iOS的硬解码方式，否则自动切换到FFmpeg的软解码方式。

### 关于滤镜支持

为了方便滤镜的接入，滤镜包括滤镜链的实现都采用了GPUImage类似的做法，如果使用过GPUImage，那么就可以无缝的切换到GoPlay，同时可以根据GPUImage的已有滤镜自定义滤镜，无限扩展自己的滤镜库。GoPlay和GPUImage的滤镜类比如下表。

|| GOPlay | GPUImage
---|---|---
输入 | FFMovie | GPUImageMovie
滤镜 | FFFilter | GPUImageFilter
输出显示 | FFView | GPUImageView

## 运行流程

### 基本流程

GoPlay主要有5个线程(包括主线程)，其中OpenGL ES渲染、滤镜都是在一个统一的异步线程中处理，在这方面与GPUImage的处理稍有不同。异步线程可以防止阻塞UI界面，串行可以防止线程间加锁从而导致的性能损耗。线程模型如下。

- 解封装线程 -- FFmpeg解封装，读取packet，分发到视频解码线程和音频解码线程

- 视频解码线程 -- 将packet解码成frame，并保存到队列缓存中

- 音频解码线程 --  将packet解码成frame，并保存到队列缓存中

- OpenGL ES渲染、滤镜处理线程
   - 从video缓存队列中取出数据帧，并且在GPU中从YUV转换成RGB，然后传递给下一级滤镜链，并最终显示

### 关于音视频同步

在业界中，普遍没有认识到音频视频两者的同步算法是控制学的问题，而仅仅停留在谁快谁慢的问题上。在现实中，音频和视频的PTS的误差是客观存在的，我们需要通过一种控制学算法实现音频和视频的相对同步，需要考虑到累积误差的存在，在相对范围内，同步算法是具有自我调节能力的，当超出某个范围了，那么就需要丢帧了，否则会影响观感。在这么多开源项目中，FFmpeg/ffplay实现了这种思想。

### 关于丢帧算法

如果真正理解了音视频同步算法，那么丢帧的做法就很简单了，当超出了音视频同步算法的调节范围，而且是视频帧慢于音频帧很多，那么此时就需要丢掉视频帧。

### 关于全景图像显示

全景图像是将一张平面图片映射到一个球面上。本质上也是一种滤镜处理，即要处理好顶点坐标和纹理坐标的映射关系。

### 关于ArcBall控制

ArcBall本质上是将二维平面上的滑动转换成三维立体球的转动，具体的做法以屏幕中心为球心，画一个球。在屏幕中滑动时，就将滑动的点映射到球面上，如果滑动的范围超出了球的范围，那么就映射到最靠近球面的点上。根据起始点的四元数和终点的四元数的差值(求逆)，就可以得到旋转的角度。

### 关于滤镜链

滤镜链的思路来源于GPUImage，但多路滤镜的处理情况并没有沿袭GPUImageTwoInputFilter之流的做法。在多路滤镜的处理上，水印滤镜中进行了一种尝试。

## 总结

关于GoPlay的相关原理基本上到这里结束了。感兴趣的可以在[GoPlay](https://github.com/dKingbin/GoPlay)中找到相关的实现，当然也可以提BUG一起讨论。

## 讨论

QQ交流群： 527359948 (GoPlay交流群)
