;+ G4_TRACE2APER
; NAME:
;	G4_TRACE2APER.PRO
;
; AUTHOR: 
;	Karl Yando, Dartmouth College
;	firstname.lastname@dartmouth.edu
;
; PURPOSE:
; 	Geant4/SEM-2 routine to propagate particle trajectories 
;	 and determine eligibility for passage into the instrument
; 	 collimator via the outermost aperture.
;
; CALLING SEQUENCE:
;	G4_TRACE2APER(position3, momentum3, typeCode, [INDICES=range])
;
; DESCRIPTION:
;	02/25/2011 :: G4_TRACE2APER will return a 1-D vector of 
;	 type BOOLEAN corresponding to the optional indexing 
;	 parameter RANGE.  Values "1" indicate that a particle 
;	 trajectory will propagate into the collimator in the 
;	 usual sense (positive time, forwards velocity); values "0"
;	 indicate that the propagated particle trajectory fails
;	 to meet necessary criteria.
; 
; INPUTS:
;	POSITION3 - matrix of size (3 x N) and type FLOAT,
;	  containing initial spatial coordinates [x,y,z] for 
;	  a particle trajectory.
; 	MOMENTUM3 - matrix of size (3 x N) and type FLOAT,
;	  containing initial momentum vector [p_x, p_y, p_z] for
;	  a particle trajectory.
;	TYPECODE - scalar value of type INTEGER which specifies
;	  SEM2 telescope type (1 = ptel, 2 = etel)
;
; KEYWORDS:
;	INDICES - specify a range with which to address entries
;	  in POSITION3 and MOMENTUM3.
;
; OUTPUTS:
;	If successful, G4_TRACE2APER will return a truth vector of 
;	  type BOOLEAN, for subsequent use with the WHERE() function.
;
; SEE ALSO:
;	G4_TRACEFOV.PRO - "raytrace" for (strict) FOV requirements
; 	G4_ANALYZEFOV.PRO - use of G4_TRACE2APER.PRO
;
; DEPENDENCES:
;	(NONE)
;
; MODIFICATION HISTORY:
;		Documented 02/25/2011, KY
;	v1.2 documentation (02/25/2011)
;	v1.1 added TYPECODE argument, allowances for different geometries 
;	v1.0 adapted from G4_TRACEFOV.PRO
;-


FUNCTION g4_trace2aper, pos3, vel3, typeCode, INDICES=range
; requires POSITION3 and MOMENTUM3 as input, and that they be valid

IF ~KEYWORD_SET(range) THEN BEGIN
	print, 'G4_TRACEFOV: caution: empty range passed'
	range = LIndGen(N_elements(pos3)/3L)
ENDIF

; define geometric considerations (absolute coordinates)
IF (typeCode EQ 1) THEN BEGIN           ; p-tel specific
	x_oaperture = (-0.9255)*25.4	; [mm] placement of outer aperture
ENDIF ELSE IF (typeCode EQ 2) THEN BEGIN ; e-tel specific
        x_oaperture = (-0.8755)*25.4    ; [mm] placement of outer aperture
ENDIF ELSE RETURN, -1           ; fail
; Now, consider shared specifications
                                ; shared specifications
r_oaperture = (0.462/2.)*25.4	; [mm] radius of outer aperture
;       note: we exploit axial symmetry, as 
;               sqrt(y_target^2 + z_target^2) <= r_aperture


; propagate initial particle velocities
; 1. calculate time (arbitrary units) to known points
time2o = (x_oaperture - pos3[0,range])/vel3[0,range]

; 2. calculate y / z positions at x = x_aperture
y_final_o = vel3[1,range]*time2o + pos3[1,range]	; (y-coordinate)
z_final_o = vel3[2,range]*time2o + pos3[2,range]	; (z-coordinate)
							; (x-coords known)
; 3. conditional testing
; 3a. test for passage through bottleneck
pass_thru_o = (y_final_o^2. + z_final_o^2.) LE (r_oaperture^2.)
; 3b. require passage in positive time
positivet_o = (time2o GT 0.)
; 3c. require positive velocity
into_scope = vel3[0,range] GT 0.
;	note: returns arrays of 1s (TRUE) and 0s (FALSE)

; 4. field-of-view (FOV) defined by passage through aperture in positive time
;   and with appropriate direction
fov = pass_thru_o * positivet_o * into_scope

RETURN, fov

END

