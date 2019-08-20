;+ G4_PLOTBYTHETA
; NAME:
;	G4_PLOTBYTHETA.PRO
;
; AUTHOR:
;       Karl Yando, Dartmouth College
;       firstname.lastname@dartmouth.edu
;
; PURPOSE:
;       General procedure to plot hits as a function of source location,
; 	 discriminating according to incident energy and whether they 
;	 originate from within the detector field-of-view
;
; CALLING SEQUENCE:
;       G4_PLOTBYTHETA, data_structure
;
; DESCRIPTION:
;       02/26/2011 :: G4_PLOTBYTHETA will plot the source location of 
; 	 simulated hits in a polar angle coordinate systems, subject 
;	 to FOV and E specifications, requiring only a data structure 
;        which specifies the location of input data and SEM-2 MEPED
;        telescope type (see SET_MEPED_VARS.PRO or INPUTS, below).
;
; INPUTS:
;       DATA_STRUCTURE - IDL data structure, with labels as such:
;               .EFILES - array of strings which specify path and filename 
;                 for Geant4-derived incident electron data.
;               .PFILES - array of strings which  specify path and filename 
;                 for Geant4-derived incident proton data.
;               .AFILES - array of strings which specify path and filename 
;                 for Geant4-derived incident alpha particle data [validation].
;               .DESCRIPTION - string containing telescope type and other 
;                 relevant information.
;               .TYPECODE - scalar [integer] value which specifies telescope 
;                 type (1 = ptel, 2 = etel)
;
; KEYWORDS:
;
;       ENERGY_REBIN - re-bin multiplier (of type INT) to allow [non-speculative] 
;	 energy binning on the basis of a REBIN like operation
;
;	ORDER - set this keyword to an index array (of type INT) to allow specification
;	 of plot ordering / contents
;
;       PAUSE_STATE - setting this keyword will pause execution prior to exit
;
;       _REF_EXTRA - pass through for miscellaneous graphics keywords to PLOT and OPLOT
;
; OUTPUTS:
;       If successful, G4_PLOTBYTHETA will plot to the current output device
;
; SEE ALSO:
;	G4_ANALYZEFOVc.PRO - original implementation (wider-scope)
;	G4_PLOTFOV.PRO - intermediate implementation (less general)
; 
; DEPENDENCES:
;       calls (external)
;		G4_LOAD2X
;		G4_BIN_BY_ENERGY
;		G4_TRACE2APER
;		G4_TRACEFOV
;		G4_CALCTHETA
;		G4_HISTANGLE
;	calls (internal)
;		G4_PLOTANGLE
;       [requires BINREAD.PRO (Liam Gumley) via G4_LOAD2X]
;
;
; MODIFICATION HISTORY: (MM/DD/YYYY)
;               Documented 02/26/2011, KY
;	v1.2 added ORDER keywords (03/09/2011)
;	v1.1 renamed G4_PLOTBYTHETA (03/06/2011)
;		added ENERGY_REBIN, and PAUSESTATE keywords
;		most subroutines made independent
;	v1.0 adapted from G4_ANALYZEFOVC.PRO (02/26/2011)
;
;-


FUNCTION g4_plotangle, angles, y_argument, INDICES=range, _REF_EXTRA=pass_thru

  ; make sure that ANGLES and Y_ARGUMENT have the same number of elements
  IF (N_ELEMENTS(angles) NE N_ELEMENTS(y_argument)) THEN RETURN, -1
  ; NOTE: it is intended that Y_ARGUMENT is a hit histogram (by angle), but this need not be

  ; check for / set goodness of RANGE index
  IF ~KEYWORD_SET(range) THEN BEGIN
        range = LIndGen(N_elements(angles))
  ENDIF

  ; plot data
  PLOT, angles[range], y_argument[range], XSTYLE=1, XRANGE=[0.,180.], XTICKS=6, XMINOR=6, _EXTRA=pass_thru
;XTITLE='Incident Polar Angle (degrees)', 
  RETURN, 1
END


PRO g4_plotbytheta, dataset, ELECTRONS=eFlag, ALPHAS=aFlag, PROTONS=pFlag, $
	ENERGY_REBIN=multiplier, ORDER=orderIndex, PAUSE_STATE=pauseFlag, _REF_EXTRA=pass_thru

; data files (obtained from SET_MEPED_VARS and DATASET argument)
eFileNames = dataset.efiles
pFileNames = dataset.pfiles
;aFileNames = dataset.afiles
telescType = dataset.description
typeCode   = dataset.typeCode
; validity check managed in G4_LOAD2X

; specify data product request (Boolean 1 for "request", 0 for "discard")
;  options: [KEY, RUN_PARAM, ENERGY3, POSITION3, MOMENTUM3, EVENTID, HEADER]
dpReq = BytARR(7) + Byte([1,1,1,1,1,0,0])

;-----------------------------------
;----- KEYWORD PROCESSING ----------
;-----------------------------------
  ; if no preference for protons/electrons/alphas is specified, default to protons
  xSpecies = pFileNames
  IF KEYWORD_SET(eFlag) THEN xSpecies = eFileNames 
  IF KEYWORD_SET(aFlag) THEN xSpecies = aFileNames

  species = 'Proton'
  IF KEYWORD_SET(eFlag) THEN species = 'Electron'
  IF KEYWORD_SET(aFlag) THEN species = 'Alpha'

  ; make keywords safe
  ; if no preference for multiplier, default to 9 (bins per order of magnitude)
  IF ~KEYWORD_SET(multiplier) THEN multiplier = 1L
  ; NOTE: orderIndex protected elsewhere

;-----------------------------------
;----- INITIALIZE EXECUTION --------
;-----------------------------------
; initialize generic execution path for protons and electrons and alphas
  ; load-in binary data
  xData = G4_LOAD2X(xSpecies, dpReq)

  ;(get references [also SHIFT index to fill [*,0] with pad values])
  ene_data = SHIFT(xData.energy3, 3)
  pos_data = SHIFT(xData.position3, 3)
  mom_data = SHIFT(xData.momentum3, 3)

  jobIDs = [(xData.run_param)[0,*]]
  jobIDss = StrJoin( StrTrim(jobIDs[0,WHERE(jobIDs[0,*] NE -999)], 2), $
                              ' ', /SINGLE)
  xtel = 'xtel'
  IF (typeCode EQ 2) THEN xtel = 'e-tel' ELSE IF (typeCode EQ 1) THEN xtel = 'p-tel'

; ok, with this in hand, let's go about the business of analyzing FOV
; let's do this by energy.. hence


; specify X energy bins per order magnitude 
baseE = [10., 100., 1000., 10000.];, 100000.]				;(three orders of magnitude)
expanded_baseE = REBIN(baseE, N_ELEMENTS(baseE)*multiplier)	;(.. expand)
energies = expanded_baseE[0:(N_ELEMENTS(baseE)-1L)*multiplier]	;(.. trim)

  ; protect ORDER keyword / define orderIndex
  IF ~KEYWORD_SET(orderIndex) THEN orderIndex = LIndGen(N_ELEMENTS(energies)-1L)
  orderIndex = orderIndex MOD N_ELEMENTS(energies)		;(protect)

; filter data for VALIDITY and FOV-GOODNESS 
; ( NOTE: checking for VALIDITY here is redundant, as it is screened in BIN_BY_ENERGY)
	; valid = Where(ene_data[0,*] NE -999., nHits)  ;(remove padding)
range = LINDGEN(N_ELEMENTS(ene_data)/3L)			
fovhit_key = g4_tracefov(pos_data, mom_data, typeCode, INDICES=range)
aperhit_key = g4_trace2aper(pos_data, mom_data, typeCode, INDICES=range)
spurhit_key = ~aperhit_key 

	; prep FAR FIELD statistics
	time2ff = -10000000.d				; (-1E7 seconds, corresonding to 10km)

	; propagate initial particle velocities
	pos_ff = mom_data*time2ff + pos_data

	; calculate polar angle from positional data
	theta_array_ff = G4_CALCTHETA(pos_ff, typeCode, INDICES=range)

	; calculate extent of source areas (for normalization)
	dummy = G4_HISTANGLE( FIndGEN(180)+0.5, LOCATIONS=binBreaks, INDICES=FIndGEN(180))
	binCenters = binBreaks + 0.5
	areaByAngle = 2.*!pi*(1 - cos(binBreaks*!dtor))		; [ster] (solid angle of sph. cap)
	areaByBin = [areaByAngle[1:180]-areaByAngle[0:179],1]   ; [ster] (solid angle of strip)
	;areaByAngle = 2.*!pi*(1 - cos(binBreaks*!dtor))*(35.)^2 ; [mm2] (area of sph. cap)
	;areaByBin = [areaByAngle[1:180]-areaByAngle[0:179],1]   ; [mm2] (area of strip)

	; calculate static POLYFILL elements
	cnt = N_ELEMENTS(binBreaks)				;(number of bins)
	poly_x = REFORM(Rotate([[binBreaks],[binBreaks]],1), cnt*2)
  	poly_i = IndGen( (cnt-1)*2 )				;(index for expanded data)

; plot however many bins we have
FOR j=0, N_ELEMENTS(orderIndex) -1L DO BEGIN

  i = orderIndex[j]
  
  ; generate useful bin information
  print, energies[i], energies[i+1]				;(print relevant energies)
  title_id = xtel + ' / ' + species + 's ' + StrTrim(Long(energies[i]),2) + '-' + StrTrim(Long(energies[i+1]),2) + ' keV'

  ; mask for this energy bin
  allhit_key = G4_BIN_BY_ENERGY(ene_data, energies[i], energies[i+1], INDICES=range)
    all_hits = WHERE(allhit_key, num_allhits)			;(get ALL_HITS index)
    fov_hits = WHERE(allhit_key * fovhit_key, num_fovhits)	;(get FOV_HITS index) 
    aper_hits = WHERE(allhit_key * aperhit_key, num_aperhits)	;(get APER_HITS index)
    spur_hits = WHERE(allhit_key * spurhit_key, num_spurhits)	;(get APER_HITS index)

  ; treat the total of all hits, regardless of origin
  IF all_hits[0] NE -1 THEN BEGIN
	; calculate "HITS BY ANGLE" statistic (FAR FIELD case)
	   all_hitsByBin_ff = Float(g4_histangle(theta_array_ff, INDICES=range[all_hits]))

  	; prep for hits by incident angle 
  	plot2_init = G4_PLOTANGLE(binCenters, all_hitsByBin_ff/areaByBin, /NODATA, $
		TITLE=title_id, XRANGE=[0,180], /YLOG, MIN_VALUE=1.e-3, $
		YTITLE='[Normalized] Counts per Degree Polar Angle',$
		XTITLE='Incident Polar Angle (degrees)', $ 
		_EXTRA=pass_thru)

	; plot hits by angle
	OPLOT, binCenters, all_hitsByBin_ff/areaByBin, PSYM=10, THICK=2	;(far field)

  	; print auxiliary information
;  	XYOUTS, 0.6, 0.85, '(strict) FOV: ' + String(num_fovhits*100./num_allhits, $
;		FORMAT='(F5.1)') + ' %', ALIGNMENT=0.5, /NORMAL, CHARSIZE=1.5
;  	XYOUTS, 0.6, 0.75, '(loose) FOV: ' + String(num_aperhits*100./num_allhits, $
;		FORMAT='(F5.1)') + ' %', ALIGNMENT=0.5, /NORMAL, CHARSIZE=1.5
  ENDIF ELSE BEGIN
	Print, 'Null Entry: ALL E(', energies[i], ',', energies[i+1], ')'
  ENDELSE

  ; collect useful ranging and indexing information
  ymins = 10.^(!Y.CRANGE[0])

  ; treat the case of spurious (non-FOV) hits
  IF spur_hits[0] NE -1 THEN BEGIN
	; calculate "HITS BY ANGLE" statistic (FAR FIELD case)
 	   spur_hitsByBin_ff = Float(g4_histangle(theta_array_ff, INDICES=range[spur_hits]))

	; plot hits by angle
	poly_y = REFORM(Rotate([[spur_hitsByBin_ff/areaByBin],[spur_hitsByBin_ff/areaByBin]],1), cnt*2) > ymins
	POLYFILL, poly_x, [ymins, poly_y[poly_i], ymins], COLOR=230;, /LINE_FILL, ORIENTATION=45., SPACING=0.2
	OPLOT, binCenters, spur_hitsByBin_ff/areaByBin, COLOR=190, PSYM=10, LINESTYLE=0, THICK=2	;(far field)
  ENDIF

  ; treat the case of aperture-derived hits
  IF aper_hits[0] NE -1 THEN BEGIN
	; calculate "HITS BY ANGLE" statistic (FAR FIELD case)
 	   aper_hitsByBin_ff = Float(g4_histangle(theta_array_ff, INDICES=range[aper_hits]))

	; plot hits by angle
	poly_y = REFORM(Rotate([[aper_hitsByBin_ff/areaByBin],[aper_hitsByBin_ff/areaByBin]],1), cnt*2) > ymins
	POLYFILL, poly_x, [ymins, poly_y[poly_i], ymins], COLOR=200, /LINE_FILL, ORIENTATION=-45., SPACING=0.2
	OPLOT, binCenters, aper_hitsByBin_ff/areaByBin, PSYM=10, LINESTYLE=0, THICK=2	;(far field)

	; print auxiliary information
;	XYOUTS, 0.6, 0.80, '(15deg) FOV: ' + String(TOTAL(aper_hitsByBin_ff[indgen(15)])*100./num_allhits, $
;		FORMAT='(F5.1)') + ' %', ALIGNMENT=0.5, /NORMAL, CHARSIZE=1.5
  ENDIF 

  ; plot / overplot useful reference information
  OPLOT, [15., 15.], [1.e-9, 1.e9], LINESTYLE=1		;(plot 15-degree nominal FOV marker)
  IF all_hits[0] NE -1 THEN BEGIN
	OPLOT, binCenters, all_hitsByBin_ff/areaByBin, PSYM=10, THICK=2	;(refresh)
	;AXIS, /XAXIS, /YAXIS
  ENDIF

  ; artificial stopping point
  IF KEYWORD_SET(pauseFlag) THEN STOP
ENDFOR

END
