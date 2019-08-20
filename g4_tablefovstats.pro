;+ G4_TABLEFOVSTATS
; NAME:
;	G4_TABLEFOVSTATS.PRO
;
; AUTHOR:
;       Karl Yando, Dartmouth College
;       firstname.lastname@dartmouth.edu
;
; PURPOSE:
;       General function to calculate FOV statistics, discriminating 
;	 according to incident energy and whether they 
;	 originate from within the detector field-of-view
;
; CALLING SEQUENCE:
;       G4_TABLEFOVSTATS, data_structure
;
; DESCRIPTION:
;       03/03/2011 :: G4_TABLEFOVSTATS will generate and return an
;	 array of field-of-view statistics, based on source locations of 
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
;        energy binning on the basis of a REBIN like operation
;
; OUTPUTS:
;       If successful, G4_TABLEFOVSTATS will return an array of double-point
;	 floating values, arranged in 6 columns as follows:
;
;	[E_START, E_END, TOTAL_HITS, APER_HITS, 15-deg APER HITS, strict FOV HITS]
;	[(entry#1) x (6 columns)] 
;	[(entry#2) x (6 columns)] 
;	
;	  Energy start and finish values (E_START, E_END) are given in [kEV]
;
; SEE ALSO:
;	G4_ANALYZEFOVc.PRO - original implementation (wider-scope)
; 
; DEPENDENCES:
;       calls (external)
;		G4_LOAD2X
;		G4_BIN_BY_ENERGY
;		G4_TRACE2APER
;		G4_TRACEFOV
;		G4_HISTANGLE
;		G4_CALCTHETA
;	calls (internal)
;		G4_PLOTANGLE
;       [requires BINREAD.PRO (Liam Gumley) via G4_LOAD2X]
;
;
; MODIFICATION HISTORY: (MM/DD/YYYY)
;               Documented 06/30/2011, KY
;	v1.0 adapted from G4_PLOTFOV.PRO (03/03/2011)
;	v1.0 adapted from G4_ANALYZEFOVC.PRO (02/26/2011)
;
;-


FUNCTION g4_tablefovstats, dataset, ELECTRONS=eFlag, ALPHAS=aFlag, PROTONS=pFlag, ENERGY_REBIN=multiplier

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

  ; if no preference for multiplier, default to 9 (bins per order of magnitude)
  IF ~KEYWORD_SET(multiplier) THEN multiplier = 9L

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

; ok, with this in hand, let's go about the business of analyzing FOV
; let's do this by energy.. hence


; specify X energy bins per order magnitude 
baseE = [10., 100., 1000., 10000.]				;(three orders of magnitude)
expanded_baseE = REBIN(baseE, N_ELEMENTS(baseE)*multiplier)	;(.. expand)
energies = expanded_baseE[0:(N_ELEMENTS(baseE)-1L)*multiplier]	;(.. trim)

; initialize table for FOV statistics
fovstat_table = REPLICATE(!Values.F_NAN, 6, N_ELEMENTS(energies))
fovstat_table[0,*] = energies
fovstat_table[1,*] = SHIFT(energies,-1)
fst_legend = ['Energy Start | ', 'Energy End | ', 'ALL HITS | ', 'APER HITS | ', '(Relaxed) FOV HITS | ', '(Strict) FOV HITS']

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
;	dummy = G4_HISTANGLE( FIndGEN(180)+0.5, LOCATIONS=binBreaks, INDICES=FIndGEN(180))
;	binCenters = binBreaks + 0.5
;	areaByAngle = 2.*!pi*(1 - cos(binBreaks*!dtor))*(35.)^2 ; [mm2] (area of sph. cap)
;	areaByBin = [areaByAngle[1:180]-areaByAngle[0:179],1]   ; [mm2] (area of strip)

; calulate FOV statistics for however many bins we have
FOR i=0, N_ELEMENTS(energies) -2L DO BEGIN
;  print, energies[i], energies[i+1]				;(print relevant energies)

  ; mask for this energy bin
  allhit_key = G4_BIN_BY_ENERGY(ene_data, energies[i], energies[i+1], INDICES=range)
    ; expect that all keys have same length; process for boolean truth
    all_hits = WHERE(allhit_key, num_allhits)			;(get ALL_HITS index)
    fov_hits = WHERE(allhit_key * fovhit_key, num_fovhits)	;(get FOV_HITS index) 
    aper_hits = WHERE(allhit_key * aperhit_key, num_aperhits)	;(get APER_HITS index)
    spur_hits = WHERE(allhit_key * spurhit_key, num_spurhits)	;(get APER_HITS index)

  ; fill FOV statistics table (summary array)
  fovstat_table[2,i] = Double(num_allhits)
  fovstat_table[3,i] = Double(num_aperhits)
  fovstat_table[5,i] = Double(num_fovhits)

  ; unutilized statistics (see G4_PLOTFOV for usage)
; 	 ; calculate "HITS BY ANGLE" statistic (FAR FIELD case)
;	   all_hitsByBin_ff = Float(g4_histangle(theta_array_ff, INDICES=range[all_hits]))
;	 ; calculate "HITS BY ANGLE" statistic (FAR FIELD case)
;	   spur_hitsByBin_ff = Float(g4_histangle(theta_array_ff, INDICES=range[spur_hits]))

  IF aper_hits[0] NE -1 THEN BEGIN
	; calculate "HITS BY ANGLE" statistic (FAR FIELD case)
 	   aper_hitsByBin_ff = Float(g4_histangle(theta_array_ff, INDICES=range[aper_hits]))
	; fill FOV statistics table
	fovstat_table[4,i] = TOTAL(aper_hitsByBin_ff[IndGen(15)], /DOUBLE)
  ENDIF 
ENDFOR

print, 'G4_TABLEFOVSTATS-- Table Legend: '
print, fst_legend
; Subseqent Usage (example):
;	print, fovstat_table
;	e_center = (fovstat_table[0,*] + fovstat_table[1,*]/2.
;	plot, e_center, (fovstat_table[3,*]/fovstat_table[2,*]), /XLOG, /YLOG, YRANGE=[0.1, 1.], XTITLE='Particle Energy (keV)', YTITLE='% Aperture Hits'
;	oplot, e_center, (fovstat_table[4,*]/fovstat_table[2,*]), LINESTYLE=1
;	oplot, e_center, (fovstat_table[5,*]/fovstat_table[2,*]), LINESTYLE=2
RETURN, fovstat_table
END
