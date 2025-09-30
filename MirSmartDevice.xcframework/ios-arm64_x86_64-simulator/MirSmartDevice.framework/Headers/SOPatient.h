//
//  Patient.h
//  Predicted
//
//  Created by Marco Fiaschini on 05/02/15.
//  Copyright (c) 2015 Marco Fiaschini. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SOResults.h"
#import "SOResultsFvcPlus.h"
//*****ATS2019 ************************************
#import "SOQualityReport.h"
#import "PublicDefs.h"
//***************************************************
#import "SOResultsVc.h"


@interface SOPatient : NSObject

@property (nonatomic) NSString * _Nullable code;
@property (nonatomic) NSString * _Nullable origine;
@property (nonatomic) NSDate * _Nullable dateOfBirth;
@property (nonatomic) unsigned char ethnicCode;
@property (nonatomic) unsigned char gender;
@property (nonatomic) unsigned int predictedCode;

@property (nonatomic) double height;
@property (nonatomic) double weight;
@property (nonatomic) double age;
@property (nonatomic) double peakFlowTargetValue;
@property (nonatomic) double fev1TargetValue;
@property (nonatomic) double fvcTargetValue;
@property (nonatomic) double fev1_fvc_TargetValue;
@property (nonatomic) double predictedArea;
@property (nonatomic) double pefPersonal;
@property (nonatomic) double fev1Personal;
@property (nonatomic) double fvcPersonal;
@property (nonatomic) double fvc_fvc_Personal;
@property (nonatomic) double xPEF; // x value (volume) of the predicted PEF.

//vers 1.3 SM_13_04 ------------------------------
@property (nonatomic) double fev6TargetValue;
@property (nonatomic) double fef2575TargetValue;
//------------------------------------------------


//vers 2.9
@property (nonatomic) double FEF75TargetValue;
@property (nonatomic) double FETTargetValue;
//@property (nonatomic) double FEV6TargetValue;
@property (nonatomic) double FEV3TargetValue;
@property (nonatomic) double FEV1_FEV6TargetValue;
@property (nonatomic) double FEF25TargetValue;
@property (nonatomic) double FEF50TargetValue;
@property (nonatomic) double FIVCTargetValue;
@property (nonatomic) double FIV1TargetValue;
@property (nonatomic) double FIV1_FIVCTargetValue;
@property (nonatomic) double PIFTargetValue;
//@property (nonatomic) double FEV1_VCTargetValue;
@property (nonatomic) double FEV3_FVCTargetValue;

//SpirobankSmart 2.7.1 -- SmartOne 1.4.1 -  SmartOneOx 1.1  ------------------------------
@property (nonatomic) double fev1LLN;
@property (nonatomic) double peakFlowLLN;
@property (nonatomic) double fvcLLN;
@property (nonatomic) double fev6LLN;
@property (nonatomic) double fef2575LLN;
@property (nonatomic) double fev1_fvc_LLN;
//-------------------------------------------------------------------------------------

//vers 2.9
@property (nonatomic) double FEF75LLN;
@property (nonatomic) double FETLLN;
//@property (nonatomic) double FEV6LLN;
@property (nonatomic) double FEV3LLN;
@property (nonatomic) double FEV1_FEV6LLN;
@property (nonatomic) double FEF25LLN;
@property (nonatomic) double FEF50LLN;
@property (nonatomic) double FIVCLLN;
@property (nonatomic) double FIV1LLN;
@property (nonatomic) double FIV1_FIVCLLN;
@property (nonatomic) double PIFLLN;
//@property (nonatomic) double FEV1_VCLLN;
@property (nonatomic) double FEV3_FVCLLN;



@property (nonatomic) double FEV1_Zscore;
@property (nonatomic) double peakFlow_zScore;
@property (nonatomic) double fvc_zScore;
@property (nonatomic) double fev6_zScore;
@property (nonatomic) double fef2575_zScore;
@property (nonatomic) double fev1_fvc_zScore;
@property (nonatomic) double FEF75_zScore;
@property (nonatomic) double FET_zScore;
@property (nonatomic) double FEV3_zScore;
@property (nonatomic) double FEV1_FEV6_zScore;
@property (nonatomic) double FEF25_zScore;
@property (nonatomic) double FEF50_zScore;
@property (nonatomic) double FIVC_zScore;
@property (nonatomic) double FIV1_zScore;
@property (nonatomic) double FIV1_FIVC_zScore;
@property (nonatomic) double PIF_zScore;
@property (nonatomic) double FEV3_FVC_zScore;

//-------------------------------------------------------------------------------------


//VC TEST °°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
@property (nonatomic) double EVC_TargetValue;
@property (nonatomic) double IVC_TargetValue;
@property (nonatomic) double IC_TargetValue;
@property (nonatomic) double SETSIT_TargetValue;
@property (nonatomic) double EVC_LLN;
@property (nonatomic) double IVC_LLN;
@property (nonatomic) double IC_LLN;
@property (nonatomic) double EVC_zScore;
@property (nonatomic) double IVC_zScore;
@property (nonatomic) double IC_zScore;
//°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°

//MVV TEST °°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
@property (nonatomic) double MVV_TargetValue;
@property (nonatomic) double MVV_LLN;
@property (nonatomic) double MVV_zScore;
//°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°


@property (nonatomic) int difficultyLevel;  // difficulty level of the test
                                            // 100 = expected difficulty
                                            // < 100 = easier than normal
                                            // > 100 = harder than normal

@property (nonatomic) NSString * _Nullable Quality_bits;
@property (nonatomic) NSString * _Nullable name;


- (id _Nullable )initWithCoder:(NSCoder *_Nullable)decoder;
- (void)encodeWithCoder:(NSCoder *_Nullable)encoder;

// vers 2.5.2 - 1.2.2 for iSpirometry **********
+ (void) savePatientToNSUserDefaults:(NSUserDefaults *_Nullable) userDefaults forKey:(NSString *_Nullable) key;
+ (SOPatient *_Nullable) getPatientFromNSUserDefaults:(NSUserDefaults *_Nullable) userDefaults forKey:(NSString *_Nullable) key;
+ (void) removePatientFromNSUserDefaults:(NSUserDefaults *_Nullable) userDefaults forKey:(NSString *_Nullable) key;
// *********************************************


-(instancetype  _Null_unspecified )initWithAge:(float) age
                    height:(float) height
                    weight:(float) weight
                    ethnic:(SOEthnicGroup) ethnic
                    gender:(SOGender) gender DEPRECATED_MSG_ATTRIBUTE("use initWithDateOfBirth: height:weight:ethnic:gender  instead");

-(instancetype  _Null_unspecified)initWithAge:(float) age
                     height:(float) height
                     weight:(float) weight
                     ethnic:(SOEthnicGroup) ethnic
                     gender:(SOGender) gender
                                         name:(NSString *_Nullable) name DEPRECATED_MSG_ATTRIBUTE("use initWithDateOfBirth: height:weight:ethnic:gender:name  instead");

-(instancetype  _Null_unspecified)initWithCode: (NSString * _Nullable) code
                     age:   (float) age
                     height:(float) height
                     weight:(float) weight
                     ethnic:(SOEthnicGroup) ethnic
                     gender:(SOGender) gender
                                          name:(NSString *_Nullable) name;

- (instancetype  _Null_unspecified)updateWithAge:(float) age
                       height:(float) height
                       weight:(float) weight
                       ethnic:(SOEthnicGroup) ethnic
                       gender:(SOGender) gender DEPRECATED_MSG_ATTRIBUTE("use updateWithDateOfBirth: height:weight:ethnic:gender  instead");

- (instancetype  _Null_unspecified)updateWithAge:(float) age
                       height:(float) height
                       weight:(float) weight
                       ethnic:(SOEthnicGroup) ethnic
                       gender:(SOGender) gender
                                            name:(NSString *_Nullable) name DEPRECATED_MSG_ATTRIBUTE("use updateWithDateOfBirth: height:weight:ethnic:gender:name  instead");

//*****************************************************************************************
//vers 2.9.9 Use Birthday to build the Patient Object to avoid decimal missing in age value
- (instancetype  _Null_unspecified)initWithDateOfBirth:(NSDate *_Nonnull) birthdate
                     height:(float) height
                     weight:(float) weight
                     ethnic:(SOEthnicGroup) ethnic
                     gender:(SOGender) gender
                                                  name:(NSString *_Nonnull) name;

- (instancetype  _Null_unspecified)initWithDateOfBirth:(NSDate *_Nonnull) birthdate
                     height:(float) height
                     weight:(float) weight
                     ethnic:(SOEthnicGroup) ethnic
                     gender:(SOGender) gender;

- (instancetype  _Null_unspecified)updateWithDateOfBirth:(NSDate *_Nonnull) birthdate
                     height:(float) height
                     weight:(float) weight
                     ethnic:(SOEthnicGroup) ethnic
                     gender:(SOGender) gender
                                                    name:(NSString *_Nullable) name;

- (instancetype _Null_unspecified)updateWithDateOfBirth:(NSDate *_Nonnull) birthdate
                     height:(float) height
                     weight:(float) weight
                     ethnic:(SOEthnicGroup) ethnic
                     gender:(SOGender) gender;
//*****************************************************************************************

/*!
 *  @method sharedPatient:
 *  @discussion             This method must be invoked only after having instantiate the SOPatient using initWithAge:height:weight:ethnic:gender: It retrievs the existing instance of SOPatient
 */
+(instancetype _Null_unspecified) sharedPatient;

/*!
 *  @method actualPercentageOfTargetWithFlow:volumeStep:isFirstPackage:
 *  @param flow             use the flow value received from method {@link soDevice:didUpdateFlowValue:isFirstPackage:}
 *  @param volumeStep       get this value from SODevice
 *  @param isFirstPackage   It is == YES when the received value (flow) is the first one of the tes
 *  @discussion             This method is invoked to get the percentage of target reached with the flow passed as parameter
 */
-(float) actualPercentageOfTargetWithFlow:(float) flow volumeStep:(NSInteger) volumeStep isFirstPackage:(BOOL)isFirstPackage;


/*!
 *  @method actualPercentageOfTargetWithFlow:volumeStep:isFirstPackage:
 *  @param flow             use the flow value received from method {@link soDevice:didUpdateFlowValue:isFirstPackage:}
 *  @param volumeStep       get this value from SODevice
 *  @param isFirstPackage   It is == YES when the received value (flow) is the first one of the test
 *  @discussion             This method is invoked to get the percentage of target that was expected to be reached with the flow passed as parameter
 */
-(float) predictedPercentageOfTargetWithFlow:(float) flow volumeStep:(NSInteger) volumeStep isFirstPackage:(BOOL)isFirstPackage;


/*!
 *  @method qualityMessageForResults:
 *  @param results          The results received from the method {@link soDevice:didUpdateResults:}
 *  @discussion             This method is invoked to get the quality message code.
 */
-(SOQualityMessage) qualityMessageForResults:(SOResults *_Nullable) results DEPRECATED_MSG_ATTRIBUTE("for ATS2019 compliance use QualityReportForResults");


/*!
 *  @method qualityMessageForResultsFvcPlus:
 *  @param results          The results received from the method {@link soDevice:didUpdateResultsFvcplus:}
 *  @discussion             This method is invoked to get the quality message code.
 */
-(SOQualityMessage) qualityMessageForResultsFvcPlus:(SOResultsFvcPlus *_Nullable) results DEPRECATED_MSG_ATTRIBUTE("for ATS2019 compliance use QualityReportForResultsFvcPlus");



/*!
*  @method CalculateZscore:
*  @param results        The results received from the method {@link soDevice:didUPdateFvcPlusResults:}
*  @discussion             This method is invoked to upgrade the calculation of predicted values so that they wil  include  the zScore values.
*/
-(void) CalculateZscore: (SOResultsFvcPlus * _Nullable ) results;

/*!
*  @method CalculateZscoreForAnySpirometryResults:
*  @param results        The results received from the method {@link soDevice:didUpdateResults:} {@link soDevice:didUPdateFvcPlusResults:} {@link  soDevice:didUPdateVcResults:}
*  @discussion             This method is invoked to upgrade the calculation of predicted values so that they wil  include  the zScore values.
*/
-(void) CalculateZscoreForAnySpirometryResults: (NSObject * _Nullable ) anySOResults;

//*****ATS2019 ************************************
/*!
*  @methods QualityReportForResults and SOQualityReportFvcPlus:
*  @param results          The results received from the method {@link soDevice:didUpdateResults:}
*  @discussion             These methods are invoked to get a complete Quality Report {@link SOQualityReport}
*/
-(SOQualityReport *_Nullable) QualityReportForResults:(SOResults *_Nonnull) results;
-(SOQualityReport *_Nullable) QualityReportForResultsFvcPlus:(SOResultsFvcPlus *_Nonnull) results;
/*!
*  @methods QualityReportForResults: WithSessionLargestFvcValue_L: and SOQualityReportFvcPlus: WithSessionLargestFvcValue_L:
*  @param results          The results received from the method {@link soDevice:didUpdateResults:}
*  @param bestSessionFvc_L The largest FVC value of the session to be compared with the current FVC in order to verify a new criteria for          acceptability
*  @discussion             These methods are overload of the above methods.
*/
-(SOQualityReport *_Nullable) QualityReportForResults:(SOResults *_Nonnull) results WithSessionLargestFvcValue_L: (float)bestSessionFvc_L;
-(SOQualityReport *_Nullable) QualityReportForResultsFvcPlus:(SOResultsFvcPlus *_Nonnull)results WithSessionLargestFvcValue_L: (float) bestSessionFvc_L;
//***************************************************

-(SOQualityReport *_Nullable) QualityReportForResultsVc:(SOResultsVc *_Nonnull)results;

@end
