//
//  do_ImageCropView_View.h
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "do_ImageCropView_IView.h"
#import "do_ImageCropView_UIModel.h"
#import "doIUIModuleView.h"

@interface do_ImageCropView_UIView : UIView<do_ImageCropView_IView, doIUIModuleView>
//可根据具体实现替换UIView
{
	@private
		__weak do_ImageCropView_UIModel *_model;
}

@end
