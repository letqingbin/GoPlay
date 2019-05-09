//
//  CommonUtil.h
//  GoPlay
//
//  Created by dKingbin on 2018/6/21.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <sys/utsname.h>

#define kScreenWidth ([UIScreen mainScreen].bounds.size.width)
#define kScreenHeight ([UIScreen mainScreen].bounds.size.height)

@interface CommonUtil : NSObject

+ (unsigned long long)getFileSize:(NSString *)filePath;

+ (void)showMessage:(UIView *)view message:(NSString *)msg;

+ (void)showLoading:(UIView *)view animated:(BOOL)animated;
+ (void)hideLoading:(UIView *)view animated:(BOOL)animated;

+ (UILabel *)LabelWithTitle:(NSString *)title
				  textColor:(UIColor *)textColor
					bgColor:(UIColor *)bgColor
					   font:(float)font
			  textAlignment:(NSTextAlignment)textAlignment
					   Bold:(BOOL)bold;

+ (UIButton *)buttonWithTitle:(NSString *)title
					textColor:(UIColor *)textColor
					  bgColor:(UIColor *)bgColor
						 font:(float)font
						image:(UIImage *)image;

+ (CGSize)sizeWithText:(NSString *)text
			  fontSize:(CGFloat)fontSize
				 width:(CGFloat)width;

+ (NSString *)convertToJSON:(id)source options:(BOOL)plain;
+ (BOOL)validateEmail:(NSString *)email;
+ (BOOL)validatePhoneNumber:(NSString *)phone;

+ (void) removeFileAtPath:(NSString*)path;
+ (void) removeAllFilesAtPath:(NSString *)path;
+ (void) removeDiectoryAtPath:(NSString *)path;
+ (NSArray*) fetchAllFilesAtPath:(NSString *)path;

+ (void) createFileAtPath:(NSString *) filePath;
+ (void) writeToFilePath:(NSString *) filePath data:(NSData *)data;

+ (void) pasteToBoard:(NSString *)msg;

//获取设备具体型号
+ (NSString*)deviceModelName;

//设备类型
+ (NSString*)deviceType;

//设备厂家
+ (NSString *)deviceManufacturer;

+ (NSString *)uuid;

@end
