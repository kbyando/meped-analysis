;+ G4_PLOTGF(b) 
; NAME:
;	G4_PLOTGFB.PRO
; 
; AUTHOR:
;	Karl Yando, Dartmouth College
;	firstname.lastname@dartmouth.edu
;
; PURPOSE:
; 	General procedure to plot geometric factor as a function
;	 of energy, calculated on the basis of output from the 
;	 Geant4 simulation of MEPED telescopes 
;
; CALLING SEQUENCE:
;	G4_PLOTGFB, data_structure
;
; DESCRIPTION:
;	11/01/2010 :: G4_PLOTGF(b) will plot geometric factor as
;	 a function of energy, requiring only a data structure 
;	 which specifies the location of input data and SEM-2 MEPED
;	 telescope type (see SET_MEPED_VARS.PRO or INPUTS, below).
;
; INPUTS:
; 	DATA_STRUCTURE - IDL data structure, with labels as such:
;		.EFILES - array of strings which specify path and filename 
;		  for Geant4-derived incident electron data.
;		.PFILES - array of strings which  specify path and filename 
;		  for Geant4-derived incident proton data.
;		.AFILES - array of strings which specify path and filename 
;		  for Geant4-derived incident alpha particle data [validation].
;		.DESCRIPTION - string containing telescope type and other 
;		  relevant information.
;		.TYPECODE - scalar [integer] value which specifies telescope 
;		  type (1 = ptel, 2 = etel)
;
; KEYWORDS:
;	ERRBARS - setting this keyword plots error bars using ERRPLOT 
;	FFIX - setting this keyword checks for (and excludes) non-finite data values
;	ENERGY_REBIN - re-bin multiplier (of type INT) to force speculative energy 
;	 binning on the basis of a REBIN like operation
;	ECHANNELS - setting this keyword plots per-channel GF due to electrons
;	PCHANNELS - setting this keyword plots per-channel GF due to protons
;	PSYMINDEX - array of values (type INT) which specify choice of per-channel 
;	 plotting symbols (PSYM); cyclic, starting with the "x0 / null" channel
;	COLORINDEX - array of values (type INT) which specify choice of per-channel
;	 plot line color (COLOR); cyclic
;	THICKINDEX - array of values (type INT) which specify choice of per-channel
;	 plot line thickness (THICK); cyclic
;	NOOVERLAY - setting this keyword will forgo plot of raw / unprocessed GFs
;	PAUSE_STATE - setting this keyword will pause execution prior to exit
;	_REF_EXTRA - pass through for miscellaneous graphics keywords to PLOT and OPLOT
;
; OUTPUTS:
;	If successful, G4_PLOTGFB will plot to the current output device
;
; SEE ALSO:
;	G4_PLOTGF (original)
;	
; DEPENDENCES:
;	compiles G4_OPLOTGF
;	calls G4_LOAD2X, G4_BINHITS, G4_CALCGFB
;	[requires BINREAD.PRO (Liam Gumley) via G4_LOAD2X]
;
;
; MODIFICATION HISTORY: (MM/DD/YYYY)
;		Documented 11/01/2010, KY
;	v1.9b	rc, documentation update 11/03/2010, KY
;	v1.6 	define keyword ENERGY_REBIN and calls to G4_CALCGFB
;	v1.5 	define KEYWORD FFIX to check for finite values
;		 and switch to usage of ERRPLOT for error bars
;	v1.4 	define function G4_OPLOTGF / consolidate plotting
;	v1.3 	merge w/ G4_PSGF2 and G4_PLOTOVERLAY (10/04/2010):
;		 - introduced NOOVERLAY keyword 
;		 - applied ERRORBARS keyword action to channels
;		 - introduced THICKINDEX keyword
;		 - all PostScript/CT settings managed externally 
;	v1.2 	introduced DATASET variable 07/07/2010
;	v1.1b 	specialized 05/22/2010, KY
;	v1.1a 	granularized 05/14/2010, KY
;	v1.0 	created 05/06/2010, KY
;	BASED ON:
;		G4_SUBREFINE, 05/14/2010, KY
;		REFINE_G4_M, 09/02/2009, KY
;		LOAD_NEW, 09/19/2008, KY
;-


;---------------------------------------------------------------
FUNCTION g4_oplotgf, gf, ERRBARS=ebFlag, FFIX=ffFlag, _EXTRA=extra
  IF ffFlag THEN valid = WHERE(FINITE(gf[2,*])) $
	ELSE valid = LIndGen(N_elements(gf[1,*]))
  oPlot, gf[0,valid], gf[1,valid], _EXTRA=extra
  IF ebFlag THEN BEGIN
    ; check for acceptability of keywords
    IF (N_ELEMENTS(extra) NE 0) THEN extra.psym = -3 $
	ELSE extra = {PSYM:-3}
    ; 95% confidence interval ( +/- 1.96*(standard error) )
    errPlot, gf[0,valid], (gf[1,valid] - 1.96*gf[2,valid]), $
	(gf[1,valid] + 1.96*gf[2,valid]), WIDTH=0.005, _EXTRA=extra
  ENDIF
  RETURN, 1
END

PRO g4_plotgfb, dataset, ERRORBARS=errBarFlag, $
	FFIX=ffFlag, ENERGY_REBIN=multiplier,$
	ECHANNELS=eFlag, PCHANNELS=pFlag, $
	PSYMINDEX=psym_index, COLORINDEX=color_index, $
	THICKINDEX=thick_index,	NOOVERLAY=noOverlayFlag, $
	PAUSE_STATE=pauseFlag, _REF_EXTRA=pass_thru

; parse optional plot settings: ERRORBARS, FFIX, ENERGY_REBIN, PSYM, COLOR, THICK
  IF ~KEYWORD_SET(errBarFlag) THEN errBarFlag=0
  IF ~KEYWORD_SET(ffFlag) THEN ffFlag=0
  IF ~KEYWORD_SET(multiplier) THEN multiplier = 1L
  IF KEYWORD_SET(psym_index) THEN psym_mod=N_elements(psym_index) $
    ELSE BEGIN
	psym_mod=1
	psym_index=-3
    ENDELSE
  IF KEYWORD_SET(color_index) THEN color_mod=N_elements(color_index) $
    ELSE BEGIN
	color_mod=1
	color_index=-1
    ENDELSE
  IF KEYWORD_SET(thick_index) THEN thick_mod=N_elements(thick_index) $
    ELSE BEGIN
	thick_mod=1
	thick_index=-1
    ENDELSE

; data files (obtained from SET_MEPED_VARS and DATASET argument)
eFileNames = dataset.efiles
pFileNames = dataset.pfiles
telescType = dataset.description
typeCode   = dataset.typeCode
; validity check managed in G4_LOAD2X


; specify data product request (Boolean 1 for "request", 0 for "discard")
;  options: [KEY, RUN_PARAM, ENERGY3, POSITION3, MOMENTUM3, EVENTID, HEADER]
dpReq = BytARR(7) + Byte([1,1,1,0,0,0,0])

; load-in binary data
eData = G4_LOAD2X(eFileNames, dpReq) 
pData = G4_LOAD2X(pFileNames, dpReq)

  ;(get references)
  eData_energy3 = Temporary(eData.energy3)
  pData_energy3 = Temporary(pData.energy3)
  jobIDs = [[(eData.run_param)[0,*]], [(pData.run_param)[0,*]]]
  jobIDss = StrJoin( StrTrim(jobIDs[0,WHERE(jobIDs[0,*] NE -999)], 2), $
	' ', /SINGLE)

  ; call function G4_CALCGF: output [KEV_ENERGY, GF, GF_SIGMA, HITS]
  eGF = G4_CALCGFB(eData_energy3, eData.run_param, ENERGY_REBIN=multiplier)
  pGF = G4_CALCGFB(pData_energy3, pData.run_param, ENERGY_REBIN=multiplier)



; PLOT subroutine for GEOMETRIC FACTOR

  ; prepare plot window
  plot, eGF[0,*], eGF[1,*], /nodata, /XLOG, /YLOG, _EXTRA=pass_thru, $	
	TITLE='Geometric Factor of the ' + telescType + ' (Geant4 Simulation)', $
	XTITLE='Incident Particle Energy [keV]', YTITLE='Geometric Factor [cm2 sr]', $
	SUBTITLE='Plot Generated '+Systime()+'!C (RUN IDs: '+jobIDss+')'

  IF KEYWORD_SET(noOverlayFlag) THEN Print, 'G4_PLOTGF: "No Overlay" Flag Set' ELSE $
    BEGIN
  	; HISTOGRAM electrons, protons (implemented using PSYMINDEX)

 	; LINEPLOT (w/ optional error bars) electrons/protons
	retVal = g4_oplotgf(eGF, ERRBARS=errbarFlag, FFIX=ffFlag, $
		PSYM=psym_index[0], $
		COLOR=color_index[0], THICK=thick_index[0])
	retVal = g4_oplotgf(pGF, ERRBARS=errbarFlag, FFIX=ffFlag, $
		PSYM=psym_index[0], $
		COLOR=color_index[0], THICK=thick_index[0])
    ENDELSE

  ; PLOT geometric factor by requested channel (ECHAN / PCHAN + PSYMINDEX)
  IF KEYWORD_SET(eFlag) THEN BEGIN 
    CASE typeCode OF
	1:  eChannels = G4_BINHITS(eData_energy3, /PTEL)
	2:  eChannels = G4_BINHITS(eData_energy3, /ETEL)
	ELSE: BEGIN
		Print, 'G4_PLOTGF: Invalid Type Code (neither electron nor proton telescope)'
		RETURN
	      END
    ENDCASE
    FOR chan= 0, 6 DO BEGIN
      IF (eChannels.(chan))[0] NE -1 THEN BEGIN
	; Calculate Geometric Factor by Channel
	eChGF = G4_CALCGFB(eData_energy3, eData.run_param, INDICES=eChannels.(chan), $
		ENERGY_REBIN=multiplier) 
	; Prep / Send data for Plotting
	sym = psym_index[chan MOD psym_mod]
	colour = color_index[chan MOD color_mod]
	thickness = thick_index[chan MOD thick_mod]
	retVal = g4_oplotgf(eChGF, ERRBARS=errbarFlag, FFIX=ffFlag, PSYM=sym, COLOR=colour, THICK=thickness)
      ENDIF
    ENDFOR
  ENDIF

  IF KEYWORD_SET(pFlag) THEN BEGIN
    CASE typeCode OF
	1: pChannels = G4_BINHITS(pData_energy3, /PTEL)
	2: pChannels = G4_BINHITS(pData_energy3, /ETEL)
	ELSE: BEGIN
		Print, 'Invalid Type Code (neither electron nor proton telscope)'
		RETURN
	      END
    ENDCASE
    FOR chan= 0, 6 DO BEGIN
      IF (pChannels.(chan))[0] NE -1 THEN BEGIN
	; Calculate Geometric Factor by Channel
	pChGF = G4_CALCGFB(pData_energy3, pData.run_param, INDICES=pChannels.(chan),$
		ENERGY_REBIN=multiplier)
	; Prep / Send data for Plotting
	sym = psym_index[chan MOD psym_mod]
	colour = color_index[chan MOD color_mod]
	thickness = thick_index[chan MOD thick_mod]
	retVal = g4_oplotgf(pChGF, ERRBARS=errbarFlag, FFIX=ffFlag, PSYM=sym, COLOR=colour, THICK=thickness)
      ENDIF
    ENDFOR
  ENDIF

IF KEYWORD_SET(pauseFlag) THEN STOP

;(clean up pointer references)
PTR_FREE, eData.header
PTR_FREE, pData.header
END
;---------------------------------------------------------------

