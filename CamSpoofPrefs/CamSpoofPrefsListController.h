#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <PhotosUI/PhotosUI.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

@interface CamSpoofPrefsListController : PSListController
    <PHPickerViewControllerDelegate,
     UIImagePickerControllerDelegate,
     UINavigationControllerDelegate>

@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UIView      *emptyState;

@end
