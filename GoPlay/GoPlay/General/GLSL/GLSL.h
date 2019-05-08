//
//  GLSL.h
//  GoPlay
//
//  Created by dKingbin on 2019/3/20.
//  Copyright © 2019 dKingbin. All rights reserved.
//

#import "FFHeader.h"
#import "FFVertexMatrix.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifndef GLSL_h
#define GLSL_h

static NSString *const kFFPassthroughVertexShaderString = FF_SHADERSTRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;

 varying vec2 textureCoordinate;

 void main()
 {
	 gl_Position = position;
	 textureCoordinate = inputTextureCoordinate.xy;
 }
 );

static NSString *const kFFPassthroughFragmentShaderString = FF_SHADERSTRING
(
 varying highp vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;

 void main()
 {
	 gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
 );

static NSString *const kFFYUV420FragmentShaderString = FF_SHADERSTRING
(
 precision highp float;

 varying highp vec2 textureCoordinate;

 uniform sampler2D texture_y;
 uniform sampler2D texture_u;
 uniform sampler2D texture_v;

 uniform mediump mat3 colorConversionMatrix;

 void main()
 {
	 mediump vec3 yuv;
	 lowp vec3 rgb;

	 yuv.x = texture2D(texture_y, textureCoordinate).r - (16.0/255.0);
	 yuv.y = texture2D(texture_u, textureCoordinate).r - 0.5;
	 yuv.z = texture2D(texture_v, textureCoordinate).r - 0.5;

	 rgb = colorConversionMatrix * yuv;

	 gl_FragColor = vec4(rgb,1.0);
 }
 );

static NSString *const kFFNV12VideoRangeFragmentShaderString = FF_SHADERSTRING
(
 varying highp vec2 textureCoordinate;

 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;

 void main()
 {
	 mediump vec3 yuv;
	 lowp vec3 rgb;

	 yuv.x = texture2D(luminanceTexture, textureCoordinate).r - (16.0/255.0);
	 yuv.yz = texture2D(chrominanceTexture, textureCoordinate).ra - vec2(0.5, 0.5);
	 rgb = colorConversionMatrix * yuv;

	 gl_FragColor = vec4(rgb, 1);
 }
 );

static NSString *const kFFBrightnessFragmentShaderString = FF_SHADERSTRING
(
 precision highp float;
 varying highp vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;

 uniform lowp float brightness;

 void main()
 {
	 lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
	 gl_FragColor = vec4((textureColor.rgb + vec3(brightness)), textureColor.w);
 }
 );

static NSString *const kFFVRVertexShaderString = FF_SHADERSTRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;

 uniform mat4 mvpMatrix;
 varying vec2 textureCoordinate;

 void main()
 {
	 gl_Position = mvpMatrix * position;
	 textureCoordinate = inputTextureCoordinate.xy;
 }
 );

static NSString *const kFFTwoInputTextureVertexShaderString = FF_SHADERSTRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 attribute vec4 inputTextureCoordinate2;

 varying vec2 textureCoordinate;
 varying vec2 textureCoordinate2;

 void main()
 {
	 gl_Position = position;
	 textureCoordinate = inputTextureCoordinate.xy;
	 textureCoordinate2 = inputTextureCoordinate2.xy;
 }
 );

static NSString *const kFFAlphaBlendFragmentShaderString = FF_SHADERSTRING
(
 varying highp vec2 textureCoordinate;
 varying highp vec2 textureCoordinate2;

 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;

 uniform lowp float mixturePercent;

 void main()
 {
	 lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
	 lowp vec4 textureColor2 = texture2D(inputImageTexture2, textureCoordinate2);

	 gl_FragColor = vec4(mix(textureColor.rgb, textureColor2.rgb, textureColor2.a * mixturePercent), textureColor.a);
 }
 );

#endif /* GLSL_h */
