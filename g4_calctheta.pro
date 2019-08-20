;+ G4_CALCTHETA
; NAME:
;       G4_CALCTHETA.PRO
;
; AUTHOR:
;       Karl Yando, Dartmouth College
;       firstname.lastname@dartmouth.edu
;
; PURPOSE: 
;       Helper function to calculate theta from input arrays
;
; CALLING SEQUENCE:
;       G4_CALCTHETA(POSITION3, TYPECODE)
;
; DESCRIPTION:
;       05/02/2011 :: G4_CALCTHETA will return an array of angle values
;	 (type FLOAT) corresponding to the polar angle THETA associated
;	 with the position vectors given in POSITION3. Return array has 
;	 implicit units of type DEGREES, and range [0,180].   
;
; INPUTS:
;       POSITION3 - array of type FLOAT, specifying the angle THETA, in degrees.
;
; KEYWORDS: 
;
;       INDICES -  pass-thru an index of range subscripts
;
;       LOCATIONS - specifies variable into which the result of HISTOGRAM's
;               LOCATION keyword is passed
;
; OUTPUTS:
;       If successful, G4_HISTANGLE will return a histogram of the input array
;
; SEE ALSO:
;       G4_ANALYZEFOVc.PRO - original implementation
;
; DEPENDECES:
;       (none)
;
; MODIFICATION HISTORY: (MM/DD/YYYY)
;       Documented 05/02/2011
;       v1.0 adapted from G4_ANALYZEFOVC.PRO (02/26/2011)
;-

FUNCTION g4_calctheta, pos3, typecode, INDICES=range
  ; calculate polar angle of source point from focus
  ; (SEM-2 MEPED proton and electron telescopes)

  ; check for / set goodness of RANGE index
  IF ~KEYWORD_SET(range) THEN BEGIN
        print, 'SEM2_CALCTHETA: caution--empty range passed'
        range = LIndGen(N_elements(pos3)/3L)
  ENDIF

  ; define geometric considerations (absolute coordinates)
  IF (typecode EQ 1) THEN BEGIN                 ; p-tel specific
        focus = (-0.0634)*25.4                  ; [mm] (abs. location of focus)
  ENDIF ELSE IF (typecode EQ 2) THEN BEGIN      ; e-tel specific
        focus = (-0.0153)*25.4                  ; [mm] (abs. location of focus)
  ENDIF ELSE RETURN, -1
  ;     note: the placement of these foci is imperfect, but the error in theta
  ;       becomes diminishingly small as we consider far field sources 

  ; require that POS3 be a 3 x N dimensional array of form [x, y, z]
  IF ((SIZE(pos3))[0] EQ 2) AND ((SIZE(pos3))[1] EQ 3) THEN BEGIN
        ; calculate polar angle of source point (from focus of 30-deg full width cone)

        ; utilizing cos(theta) = adj/hyp
        adj = pos3[0,range] - focus             ; [mm] (distance from focus of x-coord)
        hypotenuse = SQRT((adj)^2. + (pos3[1,range])^2. + (pos3[2,range])^2.)
        theta = (1./!dtor)*ACOS( (-1.*adj) / hypotenuse)

        RETURN, theta                           ; expect theta = [0,180] degrees
  ENDIF ELSE RETURN, -1
END

