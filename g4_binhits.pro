;+ 
; G4_BINHITS
; 
; AUTHOR:
;       Karl Yando, Dartmouth College
;       firstname.lastname@dartmouth.edu
;
; PURPOSE: 
;	Function to bin hits according to energy level logic 
;	 in the MEPED electron and proton telescopes 
;
; CALLING SEQUENCE: 
; 	G4_BINHITS(energy_data[, /PTELESCOPE][, /ETELESCOPE])
;
;
; DESCRIPTION:
;	10/31/2010 :: G4_BINHITS will bin energy deposits according to
;	 the energy thresholds and level logic utilized by the MEPED proton
;	 and electron telescopes, and returns an indexed structure of indices.
;
; INPUTS:
;	ENERGY_DATA - an array of energy deposit data, in the form:
;		ENERGY_DATA = [E_INCIDENT, D1_DEPOSIT, D2_DEPOSIT]
;
;	required keyword PTELESCOPE or ETELSCOPE
;
; KEYWORDS:
;	PTELESCOPE - a scalar [integer] value, of Boolean type (1=T, 0=F),
;	 selects for the energy level logic used in the PROTON telescope

;	ETELESCOPE - a scalar [integer] value, of Boolean type (1=T, 0=F),
;	 selects for the energy level logic used in the ELECTRON telescope
;
; OUTPUTS:
;	If successful, G4_BINHITS will return an indexed data structure. 
; 	 The components of this structure correspond to energy channels
;	 (P0 + P1-P6 for ptel, E0 + E1-E3 + x4-x6 for etel), where each 
;	 "channel" indexes its associated hits in ENERGY_DATA.  A null 
;	 index is indicated by scalar value [-1].
;	
; DEPENDENCES:
;	N/A
;
;
; MODIFICATION HISTORY: (MM/DD/YYYY)
;		Documented 11/01/2010, KY
;	v2.0	indexing error corrected in line 113/114 ("[1]" becomes "[1,range]"), 04/27/2011, KY
;	v1.9	rc, documentation update 11/03/2010, KY
;	v1.3 	line 44, added "range" to subscript indices ([1] became [1,range]) 09/22/2010
;	v1.2 	electron channels padded with null "x5" and "x6" 07/07/2010
;       v1.0 	defined as function 05/24/2010, KY 
;       BASED ON:
;		MEP_CHANNELS, 02/02/2008, KY
;		MEX_CHANNELS, 04/25/2008, KY
;
;-

;---------------------------------------------------------------
function g4_binhits, energy_data, PTELESCOPE=ptelFlag, ETELESCOPE=etelFlag

  typeCode = 0
  IF KEYWORD_SET(ptelFlag) THEN typeCode = typeCode + 1 
  IF KEYWORD_SET(etelFlag) THEN typeCode = typeCode - 1 

  CASE typeCode OF
    -1:	BEGIN		;(electron channels [integral])
	; Binning into discrete energy channels, in accordance with C.2.1.1-8
	;       Level   Value (keV)      Ee range (keV)
        	LS1     =25.6	;         > 30
        	LS2     =98.1	;         > 100
        	LS3     =299.	;         > 300
        	LS4     =2500.	;         (-)	

	range = LIndGen( N_elements(energy_data)/3L )

	L1 = energy_data[1,range] GT LS1
	L2 = energy_data[1,range] GT LS2
	L3 = energy_data[1,range] GT LS3
	L4 = energy_data[1,range] GT LS4

	; Energy Level Logic
	; Electron Channels (eEn, eE0 and eE4 don't exist - they show what we're missing)
	E0ind =WHERE( ~L1 AND (energy_data[1,range] GE 0.) )
	E1ind =WHERE( L1 AND ~L4 )
	E2ind =WHERE( L1 AND L2 AND ~L4 )
	E3ind =WHERE( L1 AND L3 AND ~L4 )
	E4ind =WHERE( L4 )

	retVal = {E0:E0ind, E1:E1ind, E2:E2ind, E3:E3ind, E4:E4ind, x5:[-1], x6:[-1]}
	END

     0: retVal=-1
     1: BEGIN		;(proton channels [differential])
	; Binning into discrete energy channels, in accordance with C.2.1.1-3
	;       Level   Value (keV)      Ep range (keV)
        	LS1     =21.4	;         > 30
        	LS2     =70.7	;         > 80
        	LS3     =243.	;         250-150,000
        	LS4     =796.	;         800-36,000
        	LS5     =2498.	;         2,500-6,900
        	LS6     =50.	;         >4,800

	range = LIndGen( N_elements(energy_data)/3L )

	L1 = energy_data[1,range] GT LS1
	L2 = energy_data[1,range] GT LS2
	L3 = energy_data[1,range] GT LS3
	L4 = energy_data[1,range] GT LS4
	L5 = energy_data[1,range] GT LS5
	L6 = energy_data[2,range] GT LS6

	; Energy Level Logic
	; Proton Channels (Pn and P0 don't exist - they show what we're missing)
	P0ind =WHERE( ~L1 AND (energy_data[1,range] GE 0.) )
	P1ind =WHERE( L1 AND ~L2 AND ~L6 )
	P2ind =WHERE( L1 AND L2 AND ~L3 AND ~L6 )
	P3ind =WHERE( L1 AND L3 AND ~L4 AND ~L6 )
	P4ind =WHERE( L1 AND L4 AND ~L5 AND ~L6 )
	P5ind =WHERE( L1 AND L5 )
	P6ind =WHERE( L1 AND ~L5 AND L6 )

	retVal = {P0:P0ind, P1:P1ind, P2:P2ind, P3:P3ind, P4:P4ind, P5:P5ind, P6:P6ind}
	END
     ELSE: retVal=typeCode
  ENDCASE
RETURN, retVal
END
;---------------------------------------------------------------


