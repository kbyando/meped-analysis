;+ G4_BIN_BY_ENERGY
; NAME:
;	G4_BIN_BY_ENERGY
;
; AUTHOR:
;	Karl Yando, Dartmouth College
;	firstname.lastname@dartmouth.edu
;	
; PURPOSE:
;	Helper function, returns an index key for elements in range
;
; CALLING SEQUENCE:
;	G4_BIN_BY_ENERGY(energy3, min, max, INDICES=range)
;
; INPUTS:
;	ENERGY3 - energy vector of type FLOAT
;
;	MIN - minimum energy to consider
;
;	MAX - maximum energy to consider
;
; KEYWORDS:
;	
;	INDICES - pass-thru an index of range subscripts
;
; OUTPUTS:
;	IF successful, G4_BIN_BY_ENERGY will return an index key
;
; SEE ALSO:
;	G4_ANALYZEFOVc.PRO - original implementation
;
; DEPENDENCES:
;	(NONE)
;
; MODIFICATION HISTORY: (MM/DD/YYYY)
;	Documented 5/03/2011
;	v1.0 adapted from G4_ANALYZEFOVC.PRO (2/26/2011)
;-

FUNCTION g4_bin_by_energy, ene3, min, max, INDICES = range
; G4_BIN_BY_ENERGY

; validate RANGE
IF ~KEYWORD_SET(range) THEN BEGIN
	print, 'G4_BINBYENERGY: caution: empty range passed'
	range = LIndGen(N_elements(ene3)/3L)
ENDIF

in_range = (ene3[0,range] GE min) AND (ene3[0,range] LT max)
RETURN, in_range

END
