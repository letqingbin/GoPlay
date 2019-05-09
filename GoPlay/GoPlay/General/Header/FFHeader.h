//
//  FFHeader.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/4.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#ifndef FFHeader_H_
#define FFHeader_H_

#include <stdio.h>
#import <UIKit/UIKit.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import "avformat.h"
#import "FFState.h"
#import "FFQueueContext.h"

typedef enum {
    FFFrameTypeAudio = 0,
    FFFrameTypeVideoYUV420 ,
    FFFrameTypeVideoNV12 ,
} FFFrameType;

typedef struct FFGPUTextureOptions {
	GLenum minFilter;
	GLenum magFilter;
	GLenum wrapS;
	GLenum wrapT;
	GLenum internalFormat;
	GLenum format;
	GLenum type;
} FFGPUTextureOptions;

typedef struct {
	double	frame_timer;
	double	frame_last_pts;
	double	frame_last_delay;
	double  audio_pts;
	double  audio_duration;
	double  actual_delay;

	// audio pts - current time
	// clock base minus time at which we updated the clock
	double audio_pts_drift;
} FFTimeContext;

typedef enum {
	FFRotationMode_R0 = 0,
	FFRotationMode_R90  ,
	FFRotationMode_R180 ,
	FFRotationMode_R270 ,
} FFRotationMode;

typedef enum {
    FillModePreserveAspectRatio = 0,
    FillModeStretch  ,
    FillModePreserveAspectRatioAndFill ,
	FillModeLandscape16_9 ,		//16:9
	FillModeLandscape4_3 ,		//4:3
	FillModePortrait9_16 ,		//9:16
	FillModePortrait3_4  ,		//3:4
} FFFillMode;

//texture matrix
typedef struct {
	float vertices[8];
	float texture[8];
} render_param_t;

#if DEBUG
#define glError() { \
GLenum err = glGetError(); \
if (err != GL_NO_ERROR) { \
printf("glError: %04x caught at %s:%u\n", err, __FILE__, __LINE__); \
} \
}

#define __FILENAME__ (strrchr(__FILE__,'/')+1)
#define LOG_ERROR(format, ...) FFLog_(__FILENAME__, __LINE__, __FUNCTION__, @"Error:", format, ##__VA_ARGS__)
#define LOG_WARNING(format, ...) FFLog_(__FILENAME__, __LINE__, __FUNCTION__, @"Warning:", format, ##__VA_ARGS__)
#define LOG_INFO(format, ...) FFLog_(__FILENAME__, __LINE__, __FUNCTION__, @"Info:", format, ##__VA_ARGS__)
#define LOG_DEBUG(format, ...) FFLog_(__FILENAME__, __LINE__, __FUNCTION__, @"Debug:", format, ##__VA_ARGS__)

#define FFLog_(file, line, func, prefix, format, ...) {	\
NSString *aMessage = [NSString stringWithFormat:@"%@ %@",prefix, [NSString stringWithFormat:format, ##__VA_ARGS__, nil]]; \
NSLog(@"%@",aMessage);	\
}
#else
#define glError(){}

#define LOG_ERROR(format, ...) {}
#define LOG_WARNING(format, ...) {}
#define LOG_INFO(format, ...) {}
#define LOG_DEBUG(format, ...) {}
#endif

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define FF_SHADERSTRING(text) @ STRINGIZE2(text)

#define kFFPlaySeekingVideoDidCompletedNotification @"kFFPlaySeekingVideoDidCompletedNotification"
#define kFFPlaySeekingAudioDidCompletedNotification @"kFFPlaySeekingAudioDidCompletedNotification"
#define kFFPlayVideoNotificationKey @"kFFPlayVideoNotificationKey"
#define kFFPlayAudioNotificationKey @"kFFPlayAudioNotificationKey"
#define kFFPlayReadyToPlayNotificationKey @"kFFPlayReadyToPlayNotificationKey"
#define kFFPeriodicTimeNotificationKey @"kFFPeriodicTimeNotificationKey"
#define kFFSeekCompletedNotificationKey @"kFFSeekCompletedNotificationKey"
#define kFrameRenderedNotificationKey @"kFrameRenderedNotificationKey"

#endif /* FFHeader_H_ */
