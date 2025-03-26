//
//  SOResultsEcg.h
//  SpirobankSmartKit-Playground
//
//  Created by Davide Balistreri on 22/04/21.
//  Copyright © 2021 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SOResultsEcg : NSObject

@property (strong, nonatomic) NSString *log;
@property (strong, nonatomic) NSMutableArray<NSNumber *> *points;

// Header
@property (nonatomic) int numberOfRecord;
@property (nonatomic) int day;
@property (nonatomic) int month;
@property (nonatomic) int year;
@property (nonatomic) int hour;
@property (nonatomic) int minute;
@property (nonatomic) int infoRec;

@property (nonatomic) int testResult;
@property (nonatomic) float cv;
@property (nonatomic) float pp;
@property (nonatomic) float hr;
@property (nonatomic) int xPosition;
@property (nonatomic) int yPosition;
@property (nonatomic) int zPosition;
@property (nonatomic) int batteryLevel;

/*
   TEST RESULT:
   0 = NSR (Normal Sinus Rhythm)
   1 = Atrial Fibrillation
   2 = Tachicardia
   3 = Bradicardia
   4 = No QRS found
   5 = No QRS good found
 5+4 = No QRS good found due to no QRS - Template OK
   6 = No QRS template found
 6+4 = No QRS template found due to no QRS
   7 = No distance margin, or discrepancy between MAHALANOBIS and Linear discrimination
  30 = Supine/prone position detected
  40 = Movement detected
  50 = Lead-off detected
  60 = Saturated ECG
 
  Da visualizzare sull'app:
   0 = Scritta "Ritmo sinusale" su sfondo verde
   1 = Scritta "Possibile fibrillazione atriale" su sfondo rosso
   2 = Scritta "Tachicardia" su sfondo giallo
   3 = Scritta "Bradicardia" su sfondo giallo
   4 = Scritta "Impossibile effettuare la diagnosi"
   5 = Scritta "Impossibile effettuare la diagnosi"
   6 = Scritta "Impossibile effettuare la diagnosi"
   7 = Scritta "Impossibile effettuare la diagnosi"
   9 = Scritta "Impossibile effettuare la diagnosi"
  10 = Scritta "Impossibile effettuare la diagnosi"
  30 = Scritta "Impossibile avviare il test. Rilevata posizione del corpo prona o supina. Ripetere il test da seduti"
  40 = Scritta "Test interrotto per movimento eccessivo"
  50 = Se il lead-off avviene in fase iniziale "Impossibile avviare il test. Elettrodo non aderente al corpo. Controllare il contatto dell'elettrodo e riavviare il test"
       Se il lead-off avviene a test in corso "Test interrotto per cattivo contatto dell'elettrodo"
  60 = Scritta "Segnale saturo"
*/

@end

NS_ASSUME_NONNULL_END
