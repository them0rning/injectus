#import "CamSpoofPrefsListController.h"

#define kPrefDomain    @"com.yourname.camspoof"
#define kFakePhotoPath @"/var/mobile/Library/Application Support/CamSpoof/fake_photo.jpg"
#define kThumbPath     @"/var/mobile/Library/Application Support/CamSpoof/thumb.jpg"
#define kStorageDir    @"/var/mobile/Library/Application Support/CamSpoof"

@implementation CamSpoofPrefsListController

// ── Specifiers ────────────────────────────────────────────────────────────────

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

// ── Lifecycle ─────────────────────────────────────────────────────────────────

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"CamSpoof";
    [self buildHeader];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshPreview];
}

// ── Header UI ─────────────────────────────────────────────────────────────────

- (void)buildHeader {
    CGFloat width    = UIScreen.mainScreen.bounds.size.width;
    CGFloat cardH    = 220.0f;
    CGFloat btnH     = 44.0f;
    CGFloat padding  = 16.0f;
    CGFloat total    = padding + cardH + 8.0f + btnH + padding;

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, total)];

    // ── Card ──────────────────────────────────────────────────────────────────
    CGFloat cardW  = width - padding * 2;
    UIView *card   = [[UIView alloc] initWithFrame:CGRectMake(padding, padding, cardW, cardH)];
    card.backgroundColor    = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 16;
    card.clipsToBounds      = YES;

    // Subtle shadow on a wrapper so clipsToBounds doesn't clip it
    UIView *shadow = [[UIView alloc] initWithFrame:card.frame];
    shadow.backgroundColor          = [UIColor clearColor];
    shadow.layer.shadowColor        = [UIColor blackColor].CGColor;
    shadow.layer.shadowOpacity      = 0.18f;
    shadow.layer.shadowOffset       = CGSizeMake(0, 4);
    shadow.layer.shadowRadius       = 12;
    shadow.layer.shouldRasterize    = YES;
    shadow.layer.rasterizationScale = UIScreen.mainScreen.scale;
    [header addSubview:shadow];
    [header addSubview:card];

    // ── Image view ────────────────────────────────────────────────────────────
    self.previewImageView = [[UIImageView alloc] initWithFrame:card.bounds];
    self.previewImageView.contentMode        = UIViewContentModeScaleAspectFill;
    self.previewImageView.clipsToBounds      = YES;
    self.previewImageView.userInteractionEnabled = YES;
    self.previewImageView.backgroundColor   = [UIColor systemFillColor];
    [card addSubview:self.previewImageView];

    // Tap to change photo
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(choosePhoto)];
    [self.previewImageView addGestureRecognizer:tap];

    // ── Empty state ───────────────────────────────────────────────────────────
    self.emptyState = [[UIView alloc] initWithFrame:card.bounds];

    UIImageView *camIcon = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"camera.fill"]];
    camIcon.tintColor     = [UIColor tertiaryLabelColor];
    CGFloat iconSize      = 40;
    camIcon.frame         = CGRectMake((cardW - iconSize) / 2, (cardH - iconSize) / 2 - 16,
                                        iconSize, iconSize);
    [self.emptyState addSubview:camIcon];

    UILabel *hint = [[UILabel alloc] init];
    hint.text          = @"Tap to choose a photo";
    hint.font          = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    hint.textColor     = [UIColor tertiaryLabelColor];
    hint.textAlignment = NSTextAlignmentCenter;
    hint.frame         = CGRectMake(0, camIcon.frame.origin.y + iconSize + 8, cardW, 20);
    [self.emptyState addSubview:hint];

    [card addSubview:self.emptyState];

    // ── Rotate buttons ────────────────────────────────────────────────────────
    CGFloat btnY  = padding + cardH + 8.0f;
    CGFloat btnW  = (cardW - 8) / 2;

    UIButton *rotL = [self makeButtonTitle:@"Rotate Left"
                                      icon:@"rotate.left.fill"
                                      frame:CGRectMake(padding, btnY, btnW, btnH)
                                    action:@selector(rotateLeft)];
    UIButton *rotR = [self makeButtonTitle:@"Rotate Right"
                                      icon:@"rotate.right.fill"
                                    frame:CGRectMake(padding + btnW + 8, btnY, btnW, btnH)
                                   action:@selector(rotateRight)];

    [header addSubview:rotL];
    [header addSubview:rotR];

    self.tableView.tableHeaderView = header;
}

- (UIButton *)makeButtonTitle:(NSString *)title
                         icon:(NSString *)iconName
                        frame:(CGRect)frame
                       action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = frame;
    btn.backgroundColor    = [UIColor secondarySystemGroupedBackgroundColor];
    btn.layer.cornerRadius = 12;
    btn.tintColor          = [UIColor labelColor];

    UIImage *icon = [UIImage systemImageNamed:iconName];
    UIImageView *iv = [[UIImageView alloc] initWithImage:icon];
    iv.tintColor = [UIColor labelColor];
    CGFloat iconS = 16;
    iv.frame = CGRectMake(14, (frame.size.height - iconS) / 2, iconS, iconS);
    [btn addSubview:iv];

    UILabel *lbl = [[UILabel alloc] init];
    lbl.text      = title;
    lbl.font      = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    lbl.textColor = [UIColor labelColor];
    lbl.frame     = CGRectMake(iconS + 22, 0, frame.size.width - iconS - 30, frame.size.height);
    [btn addSubview:lbl];

    // Shadow
    btn.layer.shadowColor   = [UIColor blackColor].CGColor;
    btn.layer.shadowOpacity = 0.10f;
    btn.layer.shadowOffset  = CGSizeMake(0, 2);
    btn.layer.shadowRadius  = 6;

    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    // Highlight on press
    [btn addTarget:self action:@selector(btnDown:) forControlEvents:UIControlEventTouchDown];
    [btn addTarget:self action:@selector(btnUp:)   forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];

    return btn;
}

- (void)btnDown:(UIButton *)btn {
    [UIView animateWithDuration:0.1 animations:^{ btn.alpha = 0.6f; btn.transform = CGAffineTransformMakeScale(0.97, 0.97); }];
}

- (void)btnUp:(UIButton *)btn {
    [UIView animateWithDuration:0.15 animations:^{ btn.alpha = 1.0f; btn.transform = CGAffineTransformIdentity; }];
}

// ── Preview ───────────────────────────────────────────────────────────────────

- (void)refreshPreview {
    UIImage *thumb = [UIImage imageWithContentsOfFile:kThumbPath];
    if (thumb) {
        [UIView transitionWithView:self.previewImageView
                          duration:0.25
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{ self.previewImageView.image = thumb; }
                        completion:nil];
        self.emptyState.hidden = YES;
    } else {
        self.previewImageView.image = nil;
        self.emptyState.hidden = NO;
    }
}

// ── Rotate ────────────────────────────────────────────────────────────────────

- (void)rotateLeft  { [self rotateByDegrees:-90]; }
- (void)rotateRight { [self rotateByDegrees:90];  }

- (void)rotateByDegrees:(CGFloat)degrees {
    UIImage *img = [UIImage imageWithContentsOfFile:kFakePhotoPath];
    if (!img) return;

    CGFloat  rad      = degrees * M_PI / 180.0;
    CGSize   orig     = img.size;
    CGSize   newSize  = CGSizeMake(orig.height, orig.width);

    UIGraphicsBeginImageContextWithOptions(newSize, NO, img.scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, newSize.width / 2, newSize.height / 2);
    CGContextRotateCTM(ctx, rad);
    [img drawInRect:CGRectMake(-orig.width / 2, -orig.height / 2, orig.width, orig.height)];
    UIImage *rotated = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (rotated) [self savePhoto:rotated];
}

// ── Choose photo ──────────────────────────────────────────────────────────────

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

// ── Clear photo ───────────────────────────────────────────────────────────────

- (void)clearPhoto {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Remove Photo"
                         message:@"The real camera will be used until you choose another photo."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Remove"
                                             style:UIAlertActionStyleDestructive
                                           handler:^(UIAlertAction *a) {
        [[NSFileManager defaultManager] removeItemAtPath:kFakePhotoPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:kThumbPath     error:nil];
        [self refreshPreview];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

// ── PHPickerViewControllerDelegate ────────────────────────────────────────────

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

// ── UIImagePickerControllerDelegate ───────────────────────────────────────────

- (void)imagePickerController:(UIImagePickerController *)picker
    didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    if (img) [self savePhoto:img];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

// ── Save ──────────────────────────────────────────────────────────────────────

- (void)savePhoto:(UIImage *)image {
    [[NSFileManager defaultManager] createDirectoryAtPath:kStorageDir
                              withIntermediateDirectories:YES attributes:nil error:nil];

    // Full resolution for the tweak hooks
    NSData *jpeg = UIImageJPEGRepresentation(image, 0.95f);
    [jpeg writeToFile:kFakePhotoPath atomically:YES];

    // Thumbnail (maintains aspect ratio, fits in 480px box)
    CGFloat maxDim = 480;
    CGFloat scale  = MIN(maxDim / image.size.width, maxDim / image.size.height);
    CGSize  thumbS = CGSizeMake(image.size.width * scale, image.size.height * scale);
    UIGraphicsBeginImageContextWithOptions(thumbS, NO, 0);
    [image drawInRect:CGRectMake(0, 0, thumbS.width, thumbS.height)];
    UIImage *thumb = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [UIImageJPEGRepresentation(thumb, 0.85f) writeToFile:kThumbPath atomically:YES];

    [self refreshPreview];
}

@end
