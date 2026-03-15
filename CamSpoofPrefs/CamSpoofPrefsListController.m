#import "CamSpoofPrefsListController.h"

#define kPrefDomain    @"com.yourname.camspoof"
#define kFakePhotoPath @"/var/mobile/Library/Application Support/CamSpoof/fake_photo.jpg"
#define kThumbPath     @"/var/mobile/Library/Application Support/CamSpoof/thumb.jpg"
#define kStorageDir    @"/var/mobile/Library/Application Support/CamSpoof"

@implementation CamSpoofPrefsListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self buildHeader];
}

- (void)buildHeader {
    CGFloat width = self.view.bounds.size.width;
    BOOL hasPhoto = [[NSFileManager defaultManager] fileExistsAtPath:kThumbPath];

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 220)];

    // Card
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(16, 16, width - 32, 160)];
    card.backgroundColor    = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 14;
    card.clipsToBounds      = YES;
    [header addSubview:card];

    // Image or placeholder
    UIImageView *iv = [[UIImageView alloc] initWithFrame:card.bounds];
    iv.contentMode   = UIViewContentModeScaleAspectFill;
    iv.clipsToBounds = YES;
    if (hasPhoto) {
        iv.image = [UIImage imageWithContentsOfFile:kThumbPath];
    }
    [card addSubview:iv];

    // Placeholder label when no photo
    if (!hasPhoto) {
        UILabel *lbl = [[UILabel alloc] initWithFrame:card.bounds];
        lbl.text          = @"No photo selected — tap Choose Photo below";
        lbl.font          = [UIFont systemFontOfSize:13];
        lbl.textColor     = [UIColor secondaryLabelColor];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.numberOfLines = 2;
        [card addSubview:lbl];
    }

    // Rotate buttons row
    CGFloat btnY = 16 + 160 + 8;
    CGFloat btnW = (width - 32 - 8) / 2;

    UIButton *rotL = [UIButton buttonWithType:UIButtonTypeSystem];
    rotL.frame              = CGRectMake(16, btnY, btnW, 36);
    rotL.backgroundColor    = [UIColor secondarySystemGroupedBackgroundColor];
    rotL.layer.cornerRadius = 10;
    rotL.clipsToBounds      = YES;
    [rotL setTitle:@"↺  Rotate Left" forState:UIControlStateNormal];
    rotL.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [rotL addTarget:self action:@selector(rotateLeft) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:rotL];

    UIButton *rotR = [UIButton buttonWithType:UIButtonTypeSystem];
    rotR.frame              = CGRectMake(16 + btnW + 8, btnY, btnW, 36);
    rotR.backgroundColor    = [UIColor secondarySystemGroupedBackgroundColor];
    rotR.layer.cornerRadius = 10;
    rotR.clipsToBounds      = YES;
    [rotR setTitle:@"Rotate Right  ↻" forState:UIControlStateNormal];
    rotR.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [rotR addTarget:self action:@selector(rotateRight) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:rotR];

    self.table.tableHeaderView = header;
}

- (void)choosePhoto {
    if (@available(iOS 14, *)) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite
                                                  handler:^(PHAuthorizationStatus s) {
            dispatch_async(dispatch_get_main_queue(), ^{ [self presentPicker]; });
        }];
    } else {
        [self presentPicker];
    }
}

- (void)presentPicker {
    if (@available(iOS 14, *)) {
        PHPickerConfiguration *cfg = [[PHPickerConfiguration alloc] init];
        cfg.filter         = [PHPickerFilter imagesFilter];
        cfg.selectionLimit = 1;
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:cfg];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.delegate   = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)clearPhoto {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Remove Photo"
                         message:@"The real camera will be used until you choose another."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Remove"
                                             style:UIAlertActionStyleDestructive
                                           handler:^(UIAlertAction *a) {
        [[NSFileManager defaultManager] removeItemAtPath:kFakePhotoPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:kThumbPath     error:nil];
        [self reloadSpecifiers];
        [self buildHeader];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)rotateLeft  { [self rotateByDegrees:-90]; }
- (void)rotateRight { [self rotateByDegrees:90];  }

- (void)rotateByDegrees:(CGFloat)degrees {
    UIImage *img = [UIImage imageWithContentsOfFile:kFakePhotoPath];
    if (!img) return;

    CGFloat rad     = degrees * M_PI / 180.0;
    CGSize  orig    = img.size;
    CGSize  newSize = CGSizeMake(orig.height, orig.width);

    UIGraphicsBeginImageContextWithOptions(newSize, NO, img.scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, newSize.width / 2, newSize.height / 2);
    CGContextRotateCTM(ctx, rad);
    [img drawInRect:CGRectMake(-orig.width / 2, -orig.height / 2, orig.width, orig.height)];
    UIImage *rotated = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (rotated) [self savePhoto:rotated];
}

- (void)picker:(PHPickerViewController *)picker
    didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14)) {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (!results.count) return;
    [results.firstObject.itemProvider
        loadObjectOfClass:[UIImage class]
        completionHandler:^(id<NSItemProviderReading> obj, NSError *err) {
            UIImage *img = (UIImage *)obj;
            if (!img) return;
            dispatch_async(dispatch_get_main_queue(), ^{ [self savePhoto:img]; });
        }];
}

- (void)imagePickerController:(UIImagePickerController *)picker
    didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    if (img) [self savePhoto:img];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)savePhoto:(UIImage *)image {
    [[NSFileManager defaultManager] createDirectoryAtPath:kStorageDir
                              withIntermediateDirectories:YES attributes:nil error:nil];

    [UIImageJPEGRepresentation(image, 0.95f) writeToFile:kFakePhotoPath atomically:YES];

    CGFloat maxDim = 480;
    CGFloat scale  = MIN(maxDim / image.size.width, maxDim / image.size.height);
    CGSize  tSize  = CGSizeMake(image.size.width * scale, image.size.height * scale);
    UIGraphicsBeginImageContextWithOptions(tSize, NO, 0);
    [image drawInRect:CGRectMake(0, 0, tSize.width, tSize.height)];
    UIImage *thumb = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [UIImageJPEGRepresentation(thumb, 0.85f) writeToFile:kThumbPath atomically:YES];

    [self reloadSpecifiers];
    [self buildHeader];
}

@end
