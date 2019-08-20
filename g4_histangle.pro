;+ G4_HISTANGLE
; NAME:
;	G4_HISTANGLE.PRO
;
; AUTHOR:
;	Karl Yando, Dartmouth College
;	firstname.lastname@dartmouth.edu
;
; PURPOSE: 
;	Helper function to histogram hits by angle
;
; CALLING SEQUENCE:
;	G4_HISTOGRAM(theta_array)
;
; DESCRIPTION:
;	05/02/2011 :: G4_HISTANGLE will return a histogram of passed-in
;	 angles (theta), utilizing 1-degree bins in the range [0,180].
;
; INPUTS:
;	THETA - array of type FLOAT, specifying the angle THETA, in degrees.
;
; KEYWORDS: 
;
;	INDICES -  pass-thru an index of range subscripts
;
;	LOCATIONS - specifies variable into which the result of HISTOGRAM's
;		LOCATION keyword is passed
;
; OUTPUTS:
;	If successful, G4_HISTANGLE will return a histogram of the input array
;
; SEE ALSO:
;	G4_ANALYZEFOVc.PRO - original implementation
;
; DEPENDECES:
;	(none)
;
; MODIFICATION HISTORY: (MM/DD/YYYY)
;	Documented 05/02/2011
;	v1.0 adapted from G4_ANALYZEFOVC.PRO (02/26/2011)
;

FUNCTION g4_histangle, theta, INDICES=range, LOCATIONS=ret_ptr
  ; HISTOGRAM hits according to their polar angle

  ; check for / set goodness of RANGE index
  IF ~KEYWORD_SET(range) THEN BEGIN
        print, 'G4_HISTANGLE: caution--empty range passed'
        range = LIndGen(N_elements(theta))
  ENDIF

  ; test for request of bin start location information
  IF ~ARG_PRESENT(ret_ptr) THEN ret_ptr = FltArr(181)

  ; no requirements on THETA-- proceed to HISTOGRAM
  hitsByAngle = HISTOGRAM(theta[range], BINSIZE=1., LOCATIONS=ret_ptr, MIN=0., MAX=180.)

  RETURN, hitsByAngle                           ; expect a 181 element result
END


