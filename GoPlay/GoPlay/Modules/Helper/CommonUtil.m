//
//  CommonUtil.m
//  GoPlay
//
//  Created by dKingbin on 2018/6/21.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "CommonUtil.h"
#import "MBProgressHUD.h"
#import "LoadingUtil.h"

@implementation CommonUtil

+ (UILabel *)LabelWithTitle:(NSString *)title
				  textColor:(UIColor *)textColor
					bgColor:(UIColor *)bgColor
					   font:(float)font
			  textAlignment:(NSTextAlignment)textAlignment
					   Bold:(BOOL)bold
{
	UILabel* label = [[UILabel alloc]init];
	label.backgroundColor = bgColor;

	if(bold)
	{
		label.font = [UIFont boldSystemFontOfSize:font];
	}
	else
	{
		label.font = [UIFont systemFontOfSize:font];
	}

	title = title ? title : @"";
	
	label.text = title;
	label.textColor = textColor;
	label.textAlignment = textAlignment;
	[label sizeToFit];

	return label;
}

+ (UIButton *)buttonWithTitle:(NSString *)title
					textColor:(UIColor *)textColor
					  bgColor:(UIColor *)bgColor
						 font:(float)font
						image:(UIImage *)image
{
	UIButton* btn = [[UIButton alloc]init];

	if(title.length > 0)
	{
		[btn setTitle:title forState:UIControlStateNormal];
		[btn setTitleColor:textColor forState:UIControlStateNormal];
		btn.titleLabel.font = [UIFont systemFontOfSize:font];
	}

	[btn setBackgroundColor:bgColor];

	if(image)
	{
		[btn setImage:image forState:UIControlStateNormal];
	}

	return btn;
}

+ (CGSize)sizeWithText:(NSString *)text
			  fontSize:(CGFloat)fontSize
				 width:(CGFloat)width
{
	NSDictionary * dict = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont systemFontOfSize:fontSize], NSFontAttributeName,nil];
	CGSize size = CGSizeMake(width, INT_MAX);
	size = [text boundingRectWithSize:size options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:dict context:nil].size;
	return CGSizeMake(size.width, ceil(size.height));
}

+ (void)showLoading:(UIView *)view animated:(BOOL)animated
{
	[MBProgressHUD showHUDAddedTo:view animated:animated];
}

+ (void)hideLoading:(UIView *)view animated:(BOOL)animated
{
	[MBProgressHUD hideHUDForView:view animated:animated];
}

+ (void)showMessage:(UIView *)view message:(NSString *)msg
{
	if(msg.length <= 0) return;

	[view.window endEditing:YES];

	UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
	[MBProgressHUD hideHUDForView:keyWindow animated:NO];
	if(view)
	{
		[MBProgressHUD hideHUDForView:view animated:NO];
	}

	UIView* showView = view == nil ? keyWindow : view;
	MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:showView animated:YES];
	hud.mode = MBProgressHUDModeText;
	hud.margin = 10.f;
	hud.label.text = msg;
	hud.removeFromSuperViewOnHide = YES;

	[hud hideAnimated:YES afterDelay:2.0f];
}

+ (NSString *)convertToJSON:(id)source options:(BOOL)plain
{
	if ([NSJSONSerialization isValidJSONObject:source])
	{
		NSError *error;
		NSData *data = [NSJSONSerialization dataWithJSONObject:source options:plain?kNilOptions:NSJSONWritingPrettyPrinted error:&error];

		if (!error)
		{
			return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		}
	}
	return nil;
}

+ (unsigned long long)getFileSize:(NSString *)filePath
{
	NSFileManager *fileManager = [NSFileManager defaultManager];

	if ([fileManager fileExistsAtPath:filePath])
	{
		unsigned long long fileSize = [[fileManager attributesOfItemAtPath:filePath
																	 error:nil]fileSize];
		return fileSize;
	}

	return 0;
}

+ (BOOL)validateEmail:(NSString *)email
{
	NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
	NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
	return [emailTest evaluateWithObject:email];
}

+ (BOOL)validatePhoneNumber:(NSString *)phone
{
	NSString *phoneRegex = @"^1[0-9]{10}$";
	NSPredicate *phoneTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", phoneRegex];
	return [phoneTest evaluateWithObject:phone];
}

+ (void)removeFileAtPath:(NSString*)path
{
	BOOL isDir = NO;
	NSFileManager * fileManager = [NSFileManager defaultManager];
	BOOL isExist = [fileManager fileExistsAtPath:path isDirectory:&isDir];
	if (isExist && !isDir)
	{
		[fileManager removeItemAtPath:path error:nil];
	}
}

+ (void)removeAllFilesAtPath:(NSString *)path
{
	if([[NSFileManager defaultManager] fileExistsAtPath:path])
	{
		NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];

		for (NSString *fileName in enumerator)
		{
			[[NSFileManager defaultManager] removeItemAtPath:[path stringByAppendingPathComponent:fileName] error:nil];
		}
	}
}

+ (void) removeDiectoryAtPath:(NSString *)path
{
	if([[NSFileManager defaultManager] fileExistsAtPath:path])
	{
		[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	}
}

+ (NSArray*) fetchAllFilesAtPath:(NSString *)path
{
	NSMutableArray* files = [NSMutableArray array];
	NSFileManager* fileManager = [NSFileManager defaultManager];
	NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:path];

	NSString *fileName = @"";
	while((fileName = [enumerator nextObject]) != nil)
	{
		[files addObject:[path stringByAppendingPathComponent:fileName]];
	}

	return [files copy];
}

+ (void) createFileAtPath:(NSString *) filePath
{
	NSFileManager* fileManager = [NSFileManager defaultManager];

	if([fileManager fileExistsAtPath:filePath])
	{
		[fileManager removeItemAtPath:filePath error:nil];
	}

	[fileManager createFileAtPath:filePath contents:nil attributes:nil];
}

+ (void) writeToFilePath:(NSString *) filePath data:(NSData *)data
{
	if(!data) return;

	NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:filePath];
	[handle seekToEndOfFile];
	[handle writeData:data];
}

+ (void) pasteToBoard:(NSString *)msg
{
	UIPasteboard *util = [UIPasteboard generalPasteboard];
	util.string = msg;
}

+ (NSString*)deviceModelName
{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    return deviceModel;
}

+ (NSString*)deviceType
{
    return [[UIDevice currentDevice] model];
}

+ (NSString *)deviceManufacturer
{
    return @"apple";
}

+ (NSString *)uuid
{
    NSString* key = @"com.player.uuid.key";
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    NSString* value = [userDefault stringForKey:key];
    if(value.length > 0)
    {
        return value;
    }
    
    NSString *result;
    CFUUIDRef uuid;
    CFStringRef uuidStr;
    uuid = CFUUIDCreate(NULL);
    uuidStr = CFUUIDCreateString(NULL, uuid);
    result = [NSString stringWithFormat:@"%@", uuidStr];
    CFRelease(uuidStr);
    CFRelease(uuid);
    
    [userDefault setObject:result forKey:key];
    
    return result;
}

@end
