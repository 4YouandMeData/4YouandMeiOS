/*
 Copyright (c) 2015, Apple Inc. All rights reserved.
 Copyright (c) 2015-2016, Ricardo Sánchez-Sáez.

 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1.  Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2.  Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.
 
 3.  Neither the name of the copyright holder(s) nor the names of any contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission. No license is granted to the trademarks of
 the copyright holders even if such marks are included in this software.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


@import UIKit;
#import <ResearchKit/ORKTypes.h>
#import <ResearchKit/ORKHelpers_Private.h>
#import <ResearchKit/ORKErrors.h>
#import <Foundation/Foundation.h>
#import <os/log.h>


NS_ASSUME_NONNULL_BEGIN

ORK_EXTERN BOOL ORKLoggingEnabled;

#define ORK_Log(format, ...) __extension__({ \
     if (ORKLoggingEnabled) { \
         os_log(OS_LOG_DEFAULT, format, ##__VA_ARGS__); \
     } \
 })

#define ORK_Log_Info(format, ...) __extension__({ \
     if (ORKLoggingEnabled) { \
         os_log_info(OS_LOG_DEFAULT, format, ##__VA_ARGS__); \
     } \
 })

#define ORK_Log_Debug(format, ...) __extension__({ \
     if (ORKLoggingEnabled) { \
         os_log_debug(OS_LOG_DEFAULT, format, ##__VA_ARGS__); \
     } \
 })

#define ORK_Log_Error(format, ...) __extension__({ \
     if (ORKLoggingEnabled) { \
         os_log_error(OS_LOG_DEFAULT, format, ##__VA_ARGS__); \
     } \
 })

#define ORK_Log_Fault(format, ...) __extension__({ \
     if (ORKLoggingEnabled) { \
         os_log_fault(OS_LOG_DEFAULT, format, ##__VA_ARGS__); \
     } \
 })

#define ORK_NARG(...) ORK_NARG_(__VA_ARGS__,ORK_RSEQ_N())
#define ORK_NARG_(...)  ORK_ARG_N(__VA_ARGS__)
#define ORK_ARG_N( _1, _2, _3, _4, _5, _6, _7, _8, _9,_10, N, ...) N
#define ORK_RSEQ_N()   10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0

#define ORK_DECODE_OBJ(d,x)  _ ## x = [d decodeObjectForKey:@ORK_STRINGIFY(x)]
#define ORK_ENCODE_OBJ(c,x)  [c encodeObject:_ ## x forKey:@ORK_STRINGIFY(x)]
#define ORK_ENCODE_URL(c,x)  [c encodeObject:ORKRelativePathForURL(_ ## x) forKey:@ORK_STRINGIFY(x)]
#define ORK_ENCODE_URL_BOOKMARK(c, x) [c encodeObject:ORKBookmarkDataFromURL(_ ## x) forKey:@ORK_STRINGIFY(x)]

#define ORK_DECODE_OBJ_CLASS(d,x,cl)  _ ## x = (cl *)[d decodeObjectOfClass:[cl class] forKey:@ORK_STRINGIFY(x)]
#define ORK_DECODE_OBJ_ARRAY(d,x,cl)  _ ## x = (NSArray *)[d decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class],[cl class], nil] forKey:@ORK_STRINGIFY(x)]
#define ORK_DECODE_OBJ_MUTABLE_ORDERED_SET(d,x,cl)  _ ## x = [(NSOrderedSet *)[d decodeObjectOfClasses:[NSSet setWithObjects:[NSOrderedSet class],[cl class], nil] forKey:@ORK_STRINGIFY(x)] mutableCopy]
#define ORK_DECODE_OBJ_MUTABLE_DICTIONARY(d,x,kcl,cl)  _ ## x = [(NSDictionary *)[d decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class],[kcl class],[cl class], nil] forKey:@ORK_STRINGIFY(x)] mutableCopy]

#define ORK_ENCODE_COND_OBJ(c,x)  [c encodeConditionalObject:_ ## x forKey:@ORK_STRINGIFY(x)]

#define ORK_DECODE_IMAGE(d,x)  _ ## x = (UIImage *)[d decodeObjectOfClass:[UIImage class] forKey:@ORK_STRINGIFY(x)]
#define ORK_ENCODE_IMAGE(c,x)  { if (_ ## x) { UIImage * orkTemp_ ## x = [UIImage imageWithCGImage:[_ ## x CGImage] scale:[_ ## x scale] orientation:[_ ## x imageOrientation]]; [c encodeObject:orkTemp_ ## x forKey:@ORK_STRINGIFY(x)]; } }

#define ORK_DECODE_URL(d,x)  _ ## x = ORKURLForRelativePath((NSString *)[d decodeObjectOfClass:[NSString class] forKey:@ORK_STRINGIFY(x)])
#define ORK_DECODE_URL_BOOKMARK(d,x)  _ ## x = ORKURLFromBookmarkData((NSData *)[d decodeObjectOfClass:[NSData class] forKey:@ORK_STRINGIFY(x)])

#define ORK_DECODE_BOOL(d,x)  _ ## x = [d decodeBoolForKey:@ORK_STRINGIFY(x)]
#define ORK_ENCODE_BOOL(c,x)  [c encodeBool:_ ## x forKey:@ORK_STRINGIFY(x)]

#define ORK_DECODE_DOUBLE(d,x)  _ ## x = [d decodeDoubleForKey:@ORK_STRINGIFY(x)]
#define ORK_ENCODE_DOUBLE(c,x)  [c encodeDouble:_ ## x forKey:@ORK_STRINGIFY(x)]

#define ORK_DECODE_INTEGER(d,x)  _ ## x = [d decodeIntegerForKey:@ORK_STRINGIFY(x)]
#define ORK_ENCODE_INTEGER(c,x)  [c encodeInteger:_ ## x forKey:@ORK_STRINGIFY(x)]

#define ORK_ENCODE_UINT32(c,x)  [c encodeObject:[NSNumber numberWithUnsignedLongLong:_ ## x] forKey:@ORK_STRINGIFY(x)]
#define ORK_DECODE_UINT32(d,x)  _ ## x = (uint32_t)[(NSNumber *)[d decodeObjectForKey:@ORK_STRINGIFY(x)] unsignedLongValue]

#define ORK_DECODE_ENUM(d,x)  _ ## x = [d decodeIntegerForKey:@ORK_STRINGIFY(x)]
#define ORK_ENCODE_ENUM(c,x)  [c encodeInteger:(NSInteger)_ ## x forKey:@ORK_STRINGIFY(x)]

#define ORK_DECODE_CGRECT(d,x)  _ ## x = [d decodeCGRectForKey:@ORK_STRINGIFY(x)]
#define ORK_ENCODE_CGRECT(c,x)  [c encodeCGRect:_ ## x forKey:@ORK_STRINGIFY(x)]

#define ORK_DECODE_CGSIZE(d,x)  _ ## x = [d decodeCGSizeForKey:@ORK_STRINGIFY(x)]
#define ORK_ENCODE_CGSIZE(c,x)  [c encodeCGSize:_ ## x forKey:@ORK_STRINGIFY(x)]

#define ORK_DECODE_CGPOINT(d,x)  _ ## x = [d decodeCGPointForKey:@ORK_STRINGIFY(x)]
#define ORK_ENCODE_CGPOINT(c,x)  [c encodeCGPoint:_ ## x forKey:@ORK_STRINGIFY(x)]

#define ORK_DECODE_UIEDGEINSETS(d,x)  _ ## x = [d decodeUIEdgeInsetsForKey:@ORK_STRINGIFY(x)]
#define ORK_ENCODE_UIEDGEINSETS(c,x)  [c encodeUIEdgeInsets:_ ## x forKey:@ORK_STRINGIFY(x)]

#define ORK_DECODE_COORDINATE(d,x)  _ ## x = CLLocationCoordinate2DMake([d decodeDoubleForKey:@ORK_STRINGIFY(x.latitude)],[d decodeDoubleForKey:@ORK_STRINGIFY(x.longitude)])
#define ORK_ENCODE_COORDINATE(c,x)  [c encodeDouble:_ ## x.latitude forKey:@ORK_STRINGIFY(x.latitude)];[c encodeDouble:_ ## x.longitude forKey:@ORK_STRINGIFY(x.longitude)];

/*
 * Helpers for completions which call the block only if non-nil
 *
 */
#define ORK_BLOCK_EXEC(block, ...) if (block) { block(__VA_ARGS__); };

#define ORK_DISPATCH_EXEC(queue, block, ...) if (block) { dispatch_async(queue, ^{ block(__VA_ARGS__); } ); }

/*
 * For testing background delivery
 *
 */
#if ORK_BACKGROUND_DELIVERY_TEST
#  define ORK_HEALTH_UPDATE_FREQUENCY HKUpdateFrequencyImmediate
#else
#  define ORK_HEALTH_UPDATE_FREQUENCY HKUpdateFrequencyDaily
#endif

// Find the first object of the specified class, using method as the iterator
#define ORKFirstObjectOfClass(C,p,method) ({ id v = p; while (v != nil) { if ([v isKindOfClass:[C class]]) { break; } else { v = [v method]; } }; v; })

#define ORKStrongTypeOf(x) __strong __typeof(x)
#define ORKWeakTypeOf(x) __weak __typeof(x)

// Bundle for video assets
NSBundle *ORKAssetsBundle(void);
NSBundle *ORKBundle(void);
NSBundle *ORKDefaultLocaleBundle(void);

// Pass 0xcccccc and get color #cccccc
UIColor *ORKRGB(uint32_t x);
UIColor *ORKRGBA(uint32_t x, CGFloat alpha);

_Nullable id ORKFindInArrayByKey(NSArray *array, NSString *key, id value);

NSString *ORKSignatureStringFromDate(NSDate *date);

NSURL *ORKCreateRandomBaseURL(void);

// Marked extern so it is accessible to unit tests
ORK_EXTERN NSString *ORKFileProtectionFromMode(ORKFileProtectionMode mode);

CGFloat ORKExpectedLabelHeight(UILabel *label);

// build a image with color
UIImage *ORKImageWithColor(UIColor *color);

void ORKEnableAutoLayoutForViews(NSArray *views);

NSDateComponentsFormatter *ORKTimeIntervalLabelFormatter(void);
NSDateComponentsFormatter *ORKDurationStringFormatter(void);

NSDateFormatter *ORKTimeOfDayLabelFormatter(void);
NSCalendar *ORKTimeOfDayReferenceCalendar(void);

NSDateComponents *ORKTimeOfDayComponentsFromDate(NSDate *date);
NSDate *ORKTimeOfDayDateFromComponents(NSDateComponents *dateComponents);

BOOL ORKCurrentLocalePresentsFamilyNameFirst(void);

UIFont *ORKTimeFontForSize(CGFloat size);
UIFontDescriptor *ORKFontDescriptorForLightStylisticAlternative(UIFontDescriptor *descriptor);

CGFloat ORKFloorToViewScale(CGFloat value, UIView *view);

ORK_INLINE bool
ORKEqualObjects(id o1, id o2) {
    return (o1 == o2) || (o1 && o2 && [o1 isEqual:o2]);
}

ORK_INLINE BOOL
ORKEqualFileURLs(NSURL *url1, NSURL *url2) {
    return ORKEqualObjects(url1, url2) || ([url1 isFileURL] && [url2 isFileURL] && [[url1 absoluteString] isEqualToString:[url2 absoluteString]]);
}

ORK_INLINE NSMutableOrderedSet *
ORKMutableOrderedSetCopyObjects(NSOrderedSet *a) {
    if (!a) {
        return nil;
    }
    NSMutableOrderedSet *b = [NSMutableOrderedSet orderedSetWithCapacity:a.count];
    [a enumerateObjectsUsingBlock:^(id obj, __unused NSUInteger idx, __unused BOOL *stop) {
        [b addObject:[obj copy]];
    }];
    return b;
}

ORK_INLINE NSMutableDictionary *
ORKMutableDictionaryCopyObjects(NSDictionary *a) {
    if (!a) {
        return nil;
    }
    NSMutableDictionary *b = [NSMutableDictionary dictionaryWithCapacity:a.count];
    [a enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL *stop) {
        b[key] = [obj copy];
    }];
    return b;
}

#define ORKSuppressPerformSelectorWarning(PerformCall) \
do { \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
PerformCall; \
_Pragma("clang diagnostic pop") \
} while (0)

UIFont *ORKThinFontWithSize(CGFloat size);
UIFont *ORKLightFontWithSize(CGFloat size);
UIFont *ORKMediumFontWithSize(CGFloat size);

NSURL *ORKURLFromBookmarkData(NSData *data);
NSData *ORKBookmarkDataFromURL(NSURL *url);

NSString *ORKPathRelativeToURL(NSURL *url, NSURL *baseURL);
NSURL *ORKURLForRelativePath(NSString *relativePath);
NSString *ORKRelativePathForURL(NSURL *url);

_Nullable id ORKDynamicCast_(id x, Class objClass);

#define ORKDynamicCast(x, c) ((c *) ORKDynamicCast_(x, [c class]))

extern const CGFloat ORKScrollToTopAnimationDuration;

ORK_INLINE CGFloat
ORKCGFloatNearlyEqualToFloat(CGFloat f1, CGFloat f2) {
    const CGFloat ORKCGFloatEpsilon = 0.01; // 0.01 should be safe enough when dealing with screen point and pixel values
    return (ABS(f1 - f2) <= ORKCGFloatEpsilon);
}

#define ORKThrowMethodUnavailableException()  @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"method unavailable" userInfo:nil];
#define ORKThrowInvalidArgumentExceptionIfNil(argument)  if (!argument) { @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@#argument" cannot be nil." userInfo:nil]; }

void ORKValidateArrayForObjectsOfClass(NSArray *array, Class expectedObjectClass, NSString *exceptionReason);

void ORKRemoveConstraintsForRemovedViews(NSMutableArray *constraints, NSArray *removedViews);

extern const double ORKDoubleInvalidValue;

extern const CGFloat ORKCGFloatInvalidValue;

void ORKAdjustPageViewControllerNavigationDirectionForRTL(UIPageViewControllerNavigationDirection *direction);

NSString *ORKPaddingWithNumberOfSpaces(NSUInteger numberOfPaddingSpaces);

NSNumberFormatter *ORKDecimalNumberFormatter(void);

ORK_INLINE double ORKFeetAndInchesToInches(double feet, double inches) {
    return (feet * 12) + inches;
}

ORK_INLINE void ORKInchesToFeetAndInches(double inches, double *outFeet, double *outInches) {
    if (outFeet == NULL || outInches == NULL) {
        return;
    }
    *outFeet = floor(inches / 12);
    *outInches = round(fmod(inches, 12));
}

ORK_INLINE double ORKInchesToCentimeters(double inches) {
    return inches * 2.54;
}

ORK_INLINE double ORKCentimetersToInches(double centimeters) {
    return centimeters / 2.54;
}

ORK_INLINE void ORKCentimetersToFeetAndInches(double centimeters, double *outFeet, double *outInches) {
    double inches = ORKCentimetersToInches(centimeters);
    ORKInchesToFeetAndInches(inches, outFeet, outInches);
}

ORK_INLINE double ORKFeetAndInchesToCentimeters(double feet, double inches) {
    return ORKInchesToCentimeters(ORKFeetAndInchesToInches(feet, inches));
}

ORK_INLINE void ORKKilogramsToWholeAndFraction(double kilograms, double *outWhole, double *outFraction) {
    if (outWhole == NULL || outFraction == NULL) {
        return;
    }
    *outWhole = floor(kilograms);
    *outFraction = round((kilograms - floor(kilograms)) * 100);
}

ORK_INLINE void ORKKilogramsToPoundsAndOunces(double kilograms, double * _Nullable outPounds, double * _Nullable outOunces) {
    const double ORKPoundsPerKilogram = 2.20462262;
    double fractionalPounds = kilograms * ORKPoundsPerKilogram;
    double pounds = floor(fractionalPounds);
    double ounces = round((fractionalPounds - pounds) * 16);
    if (ounces == 16) {
        pounds += 1;
        ounces = 0;
    }
    if (outPounds != NULL) {
        *outPounds = pounds;
    }
    if (outOunces != NULL) {
        *outOunces = ounces;
    }
}

ORK_INLINE double ORKKilogramsToPounds(double kilograms) {
    double pounds;
    ORKKilogramsToPoundsAndOunces(kilograms, &pounds, NULL);
    return pounds;
}

ORK_INLINE double ORKWholeAndFractionToKilograms(double whole, double fraction) {
    double kg = (whole + (fraction / 100));
    return (round(100 * kg) / 100);
}

ORK_INLINE double ORKPoundsAndOuncesToKilograms(double pounds, double ounces) {
    const double ORKKilogramsPerPound = 0.45359237;
    double kg = (pounds + (ounces / 16)) * ORKKilogramsPerPound;
    return (round(100 * kg) / 100);
}

ORK_INLINE double ORKPoundsToKilograms(double pounds) {
    return ORKPoundsAndOuncesToKilograms(pounds, 0);
}

ORK_INLINE UIColor *ORKOpaqueColorWithReducedAlphaFromBaseColor(UIColor *baseColor, NSUInteger colorIndex, NSUInteger totalColors) {
    UIColor *color = baseColor;
    if (totalColors > 1) {
        CGFloat red = 0.0;
        CGFloat green = 0.0;
        CGFloat blue = 0.0;
        CGFloat alpha = 0.0;
        if ([baseColor getRed:&red green:&green blue:&blue alpha:&alpha]) {
            // Avoid a pure transparent color (alpha = 0)
            CGFloat targetAlphaFactor = ((1.0 / totalColors) * colorIndex);
            return [UIColor colorWithRed:red + ((1.0 - red) * targetAlphaFactor)
                                   green:green + ((1.0 - green) * targetAlphaFactor)
                                    blue:blue + ((1.0 - blue) * targetAlphaFactor)
                                   alpha:alpha];
        }
    }
    return color;
}

// Localization
ORK_EXTERN NSBundle *ORKBundle(void) ORK_AVAILABLE_DECL;
ORK_EXTERN NSBundle *ORKDefaultLocaleBundle(void);
ORK_EXTERN NSBundle *ORKLocalizedBundle(void);

// Search inside ResearchKit strings using the value specified in CFBundleDevelopmentRegion (info.plist). If no string is found, return an empty string
#define ORKDefaultLocalizedValue(key) \
[ORKDefaultLocaleBundle() localizedStringForKey:key value:@"" table:@"ResearchKit"]

// Search inside ResearchKit strings using the current locale. If no string is found, search using the value specified in CFBundleDevelopmentRegion (info.plist)
#define ORKAppLocalizedValue(key) \
[ORKBundle() localizedStringForKey:key value:ORKDefaultLocalizedValue(key) table:@"ResearchKit"]

// Search inside ResearchKit strings using the custom locale. If no string is found, search with the current locale
#define ORKCustomLocalizedValue(key) \
[ORKLocalizedBundle() localizedStringForKey:key value:ORKAppLocalizedValue(key) table:@"ResearchKit"]

// [DEFAULT BEHAVIOUR] Search inside the custom strings. If no string is found, search inside ResearchKit strings using the custom locale
#define ORKLocalizedString(key, comment) \
ORKCustomText(key, ORKCustomLocalizedValue(key))

#define ORKLocalizedStringFromNumber(number) \
[NSNumberFormatter localizedStringFromNumber:number numberStyle:NSNumberFormatterNoStyle]

void ORKCustomLanguageCodeSetLanguageCode(NSString *languageCode);

NSString* ORKSwiftLocalizedString(NSString *key, NSString *comment);

void ORKCustomTextSetCustomForKey(NSString *key, NSString *text);
NSString *ORKCustomText(NSString *textKey, NSString* defaultText);

NS_ASSUME_NONNULL_END
