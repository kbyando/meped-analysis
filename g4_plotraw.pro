;+ G4_PLOTRAW
; NAME:
;	G4_PLOTRAW.PRO
;
; AUTHOR:
;	Karl Yando, Dartmouth College
;	firstname.lastname@dartmouth.edu
;
; PURPOSE:
; 	Procedure to plot energy deposit information from
;	 MEPED model Geant4 data. Also functions as a [STATIC] 
;	 generator of validation plots
;
; CALLING SEQUENCE:
;	G4_PLOTRAW, data_structure
;
; DESCRIPTION:
;	01/04/2011 :: G4_PLOTRAW will plot energy deposited for hits,
;	 requiring a data structure which specifies the location of 
;	 input data and SEM-2 MEPED telescope type, and keyword args.
;	(see SET_MEPED_VARS.PRO or INPUTS, below)
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
;	ELECTRONS - setting this keyword plots electron data
;	ALPHAS - setting this keyword plots alpha particle data
;	[PROTONS] - default option, plots proton data
;	RAW - two element array of values (type INT) which specify choice 
;	 plot axes / values
;		0 - incident energy
;		1 - energy deposit in Detector 1 
;		2 - energy deposit in Detector 2 (not applicable for e-telescope)
;		3 - energy deposit in Detector 3 (Detector 1 in e-telescope)
;		example: [0,1] plots dete1 deposit (y-axis) vs incident energy (x-axis)
;	_REF_EXTRA - pass through for miscellaneous graphics keywords to PLOT and OPLOT
;
; OUTPUTS:
;	If successful, G4_PLOTRAW will plot to the current output device
;
; SEE ALSO:
;	G4_PLOTD1D2 (original)
;
; DEPENDENCES:
;	calls G4_LOAD2X, G4_BINHITS
;	[requires BINREAD.PRO (Liam Gumley) via G4_LOAD2X]
;
;
; MODIFICATION HISTORY: (MM/DD/YYYY)
;		Documented 01/04/2011, KY
;	v1.3	rc, renamed G4_PLOTRAW; documentated 01/04/2011 KY
;	v1.3 	introduce AFLAG and RAW keywords 10/13/2010
;	v1.2 	introduced DATASET variable 07/07/2010
;	v1.1b 	specialized 05/18/2010, KY
;	v1.1a 	granularized 05/14/2010, KY
;	v1.0 	created 05/06/2010, KY
;	BASED ON:
;		D1D2, 01/22/2008, KY
;		D1D2fE, 01/26/2008, KY
;		G4_SUBREFINE, 05/14/2010, KY
;		REFINE_G4_M, 09/02/2009, KY
;		LOAD_NEW, 09/19/2008, KY
;-


;---------------------------------------------------------------
PRO g4_plotraw, dataset, ELECTRONS=eFlag, ALPHAS=aFlag, RAW=energyVars,$
	_REF_EXTRA=pass_thru

; data files (obtained from SET_MEPED_VARS and DATASET argument) 
eFileNames = dataset.efiles
pFileNames = dataset.pfiles
aFileNames = dataset.afiles
telescType = dataset.description
typeCode = dataset.typeCode
; validity check managed in G4_LOAD2X


; specify data product request (Boolean 1 for "request", 0 for "discard")
;  options: [KEY, RUN_PARAM, ENERGY3, POSITION3, MOMENTUM3, EVENTID, HEADER]
dpReq = BytARR(7) + Byte([1,1,1,0,0,0,0])

;-----------------------------------
;----- KEYWORD PROCESSING ----------
;-----------------------------------
  ; if no preference for protons/electrons/alphas is specified, default to protons
  IF KEYWORD_SET(eFlag) THEN xSpecies = eFileNames ELSE xSpecies = pFileNames
  IF KEYWORD_SET(aFlag) THEN xSpecies = aFileNames

  IF KEYWORD_SET(eFlag) THEN species = 'Electron' ELSE species = 'Proton'
  IF KEYWORD_SET(aFlag) THEN species = 'Alpha'

  	; axis titles
	title0 = 'Incident '+species+' Energy [keV]'
	title1 = 'Deposited Energy [keV] (D1)'
	title2 = 'Deposited Energy [keV] (D2)'
	title3 = 'Deposited Energy [keV] (D3)' 


  ; check for specification of RAW flag / parameters
  IF ~KEYWORD_SET(energyVars) THEN BEGIN 
 	rawFlag = 0			;bin by channels
	energyVars = [0,1]		;default to plot type 'E vs D1 (and D2)' 
  ENDIF ELSE rawFlag = 1

  ; validity check #1 (make sure we have a 2-element pair)
    CASE N_ELEMENTS(energyVars) OF
	1: energyVars = [0,1] 		;standard RAW output
	2: 				;ok
	ELSE: BEGIN & Print, 'G4_PLOTD1D2: keyword RAW (xy axes) of type [INTEGER,INTEGER]' & RETURN & END
    ENDCASE

  ; validity check #2 (make sure the elements of our pair make sense)
    CASE Fix(energyVars[0]) OF
	0: x_title = title0		;ok
	1: x_title = title1		;ok
	2: x_title = title2		;ok 
	3: BEGIN
		x_title = title3	;ok
		energyVars[0] = 1 	;map to D1
	   END
	ELSE: BEGIN & Print, 'G4_PLOTD1D2: elements of XYPAIR must specify type of ENERGY3 vector: (0)=total energy, (1)=D1 deposit, (2)=D2 deposit, (3)=D3 deposit' & RETURN & END
    ENDCASE
    CASE Fix(energyVars[1]) OF
	0: y_title = title0		;ok
	1: y_title = title1		;ok
	2: y_title = title2		;ok
	3: BEGIN
		y_title=title3		;ok
		energyVars[1] = 1 	;map to D1
	   END
	ELSE: BEGIN & Print, 'G4_PLOTD1D2: elements of XYPAIR must specify type of ENERGY3 vector: (0)=total energy, (1)=D1 deposit, (2)=D2 deposit, (3)=D3 deposit' & RETURN & END
    ENDCASE
  energyVars = Fix(energyVars)
;-----------------------------------


;-----------------------------------
;----- INITIALIZE EXECUTION --------
;-----------------------------------
; initialize generic execution path for protons and electrons and alphas
  ; load-in binary data
  xData = G4_LOAD2X(xSpecies, dpReq) 	

  ;(get references)
  xData_energy3 = Temporary(xData.energy3)	
  xData_jobIDs = StrJoin( StrTrim((xData.run_param)[0,WHERE( (xData.run_param)[0,*] NE -999)], 2), $
	' ', /SINGLE)

  ; bin hits (or don't!)
  IF KEYWORD_SET(rawFlag) THEN BEGIN
	xHits = {ch0:WHERE(xData_energy3[0,*] NE -999), $
		x1:[-1], x2:[-1], x3:[-1], x4:[-1], x5:[-1], x6:[-1]} 
  ENDIF ELSE BEGIN
    CASE typeCode OF
	1: xHits = G4_BINHITS(xData_energy3, /PTEL)
	2: xHits = G4_BINHITS(xData_energy3, /ETEL)
	ELSE: BEGIN
		Print, 'In-Valid Type Code'
		RETURN
	      END
    ENDCASE
  ENDELSE


  ; prepare plot window
  plot, [10,10000], [10,10000], /nodata, /xlog, /ylog, _EXTRA=pass_thru, $
	TITLE='Energy Deposit in the ' + telescType + ' (Geant4 Simulation)', $
;	XTITLE='Incident '+species+' Energy [keV]', YTITLE='Deposited Energy [keV]',$
	XTITLE=x_title, YTITLE=y_title,$
	SUBTITLE='Plot Generated '+Systime() +' (RUN IDs: '+xData_jobIDs+')'

  ; loop over lower 5 channels of the proton telescope (QUITS after element [0] if 'RAW' engaged)
  FOR chan= 0, 5 DO BEGIN 
    IF (xHits.(chan))[0] NE -1 THEN $
	oPlot, xData_energy3[ energyVars[0], xHits.(chan)], xData_energy3[ energyVars[1], xHits.(chan)], $
	PSYM=3, _EXTRA=pass_thru
  ENDFOR

  ; include the sixth (D2) energy channel (only active for 'RAW' NOT engaged)
  IF (xHits.(chan))[0] NE -1 THEN $
	oPlot, xData_energy3[0,xHits.(chan)], xData_energy3[2,xHits.(chan)], $
	PSYM=3, _EXTRA=pass_thru

	; DIAGNOSTICS
  	;h = HISTOGRAM(xData_energy3[0,xHits.(0)], BINSIZE=1., MIN=0., MAX=10000.)
	;print, MAX(xData_energy3[0,xHits.(0)], MIN=george), george, WHERE(xData_energy3[0,xHits.(0)] LE 0.)
	;plot, h, /xlog, XRANGE=[1,10000] 
  ; done!

;(clean up pointer references)
PTR_FREE, xData.header
END
;---------------------------------------------------------------

