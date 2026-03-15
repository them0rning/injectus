#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

#define kFakePhotoPath @"/var/mobile/Library/Application Support/CamSpoof/fake_photo.jpg"
// Read directly from the plist file — CFPreferences doesn't work in sandboxed apps
#define kPrefsPath     @"/var/mobile/Library/Preferences/com.yourname.camspoof.plist"

// ─── Helpers ──────────────────────────────────────────────────────────────────

static BOOL isEnabled(void) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    return [prefs[@"enabled"] boolValue];
}

static UIImage *getFakeImage(void) {
    static UIImage *cached    = nil;
    static NSDate  *cachedMod = nil;

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:kFakePhotoPath]) return nil;

    NSDictionary *attrs = [fm attributesOfItemAtPath:kFakePhotoPath error:nil];
    NSDate *mod = attrs[NSFileModificationDate];
    if (!cached || ![mod isEqualToDate:cachedMod]) {
        cached    = [UIImage imageWithContentsOfFile:kFakePhotoPath];
        cachedMod = mod;
    }
    return cached;
}

// ─── Hook 1: AVCapturePhoto — modern iOS 11+ capture path ────────────────────
// Covers Camera.app, Instagram, Snapchat, WhatsApp, and everything modern

%hook AVCapturePhoto

- (NSData *)fileDataRepresentation {
    if (!isEnabled()) return %orig;
    UIImage *fake = getFakeImage();
    if (!fake) return %orig;
    return UIImageJPEGRepresentation(fake, 0.95f) ?: %orig;
}

- (CGImageRef)CGImageRepresentation {
    if (!isEnabled()) return %orig;
    UIImage *fake = getFakeImage();
    return fake ? fake.CGImage : %orig;
}

- (CGImageRef)previewCGImageRepresentation {
    if (!isEnabled()) return %orig;
    UIImage *fake = getFakeImage();
    return fake ? fake.CGImage : %orig;
}

%end

// ─── Hook 2: UIImagePickerController — older / simpler apps ──────────────────

%hook UIImagePickerController

- (void)takePicture {
    if (!isEnabled()) { %orig; return; }
    UIImage *fake = getFakeImage();
    if (!fake) { %orig; return; }

    id<UIImagePickerControllerDelegate> del = self.delegate;
    if (![del respondsToSelector:
            @selector(imagePickerController:didFinishPickingMediaWithInfo:)]) {
        %orig; return;
    }
    NSDictionary *info = @{
        UIImagePickerControllerOriginalImage: fake,
        UIImagePickerControllerEditedImage:   fake,
        UIImagePickerControllerMediaType:     @"public.image",
    };
    dispatch_async(dispatch_get_main_queue(), ^{
        [del imagePickerController:self didFinishPickingMediaWithInfo:info];
    });
}

%end

// ─── Hook 3: AVCaptureStillImageOutput — legacy pre-iOS 10 apps ──────────────

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

%hook AVCaptureStillImageOutput

- (void)captureStillImageAsynchronouslyFromConnection:(AVCaptureConnection *)connection
                                    completionHandler:(void (^)(CMSampleBufferRef, NSError *))handler {
    if (!isEnabled()) { %orig(connection, handler); return; }
    UIImage *fake = getFakeImage();
    if (!fake)        { %orig(connection, handler); return; }

    NSData *jpeg = UIImageJPEGRepresentation(fake, 0.95f);
    CMBlockBufferRef  blockBuffer  = NULL;
    CMSampleBufferRef sampleBuffer = NULL;

    OSStatus s = CMBlockBufferCreateWithMemoryBlock(
        kCFAllocatorDefault,
        (void *)jpeg.bytes, jpeg.length,
        kCFAllocatorNull,
        NULL, 0, jpeg.length, 0,
        &blockBuffer);

    if (s == noErr && blockBuffer) {
        const size_t sz = jpeg.length;
        CMFormatDescriptionRef fmt = NULL;
        CMVideoFormatDescriptionCreate(
            kCFAllocatorDefault, kCMVideoCodecType_JPEG,
            (int32_t)fake.size.width, (int32_t)fake.size.height,
            NULL, &fmt);
        CMSampleTimingInfo timing = kCMTimingInfoInvalid;
        CMSampleBufferCreate(
            kCFAllocatorDefault, blockBuffer, YES,
            NULL, NULL, fmt,
            1, 1, &timing, 1, &sz, &sampleBuffer);
        if (fmt) CFRelease(fmt);
        CFRelease(blockBuffer);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (sampleBuffer) {
            handler(sampleBuffer, nil);
            CFRelease(sampleBuffer);
        } else {
            handler(NULL, [NSError errorWithDomain:@"CamSpoof" code:-1 userInfo:nil]);
        }
    });
}

%end

#pragma clang diagnostic pop

// ─── Constructor ──────────────────────────────────────────────────────────────

%ctor {
    [[NSFileManager defaultManager]
        createDirectoryAtPath:@"/var/mobile/Library/Application Support/CamSpoof"
  withIntermediateDirectories:YES attributes:nil error:nil];
}
