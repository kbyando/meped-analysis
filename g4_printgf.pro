;+ G4_PRINTGF
; NAME:
;	G4_PRINTGF.PRO
;
; AUTHOR:
;	Karl Yando, Dartmouth College
;	firstname.lastname@dartmouth.edu
;
; PURPOSE:
;	Procedure to print geometric factor as a function of
;	 energy, calculated on the basis of output from the 
;	 Geant4 simulation of MEPED telescopes
;
; CALLING SEQUENCE:
;	G4_PRINTGFB, data_structure 
;
; DESCRIPTION:
;	11/05/2010 :: G4_PRINTGF will print a table of geometric 
;	 factor, as a function of energy, to the terminal, 
;	 requiring only a data structure which specifies the 
;	 location of input data and SEM-2 MEPED telescope type
;	 (see SET_MEPED_VARS.PRO or INPUTS, below).
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
;                 type (1 = ptel, 2 = etel);
;
; KEYWORDS:
;
;	COLUMNS - array of Boolean values, specifying which columns to print
;
;       ECHANNELS - setting this keyword plots per-channel GF due to electrons
;
;       ENERGY_REBIN - re-bin multiplier (of type INT) to force speculative energy 
;        binning on the basis of a REBIN like operation
;
;	LATEX - setting this keyword prints output formatted for a LATEX table
;
;       PAUSE_STATE - setting this keyword will pause execution prior to exit
;
;       PCHANNELS - setting this keyword plots per-channel GF due to protons
;
; OUTPUTS:
;	If successful, G4_PRINTGF will print a table of geometric factor to the 
;	 terminal
;
; SEE ALSO:
;	N/A
;
; DEPENDENCES:
;	compiles G4_PRINTWERROR
;	calls G4_LOAD2X, G4_BINHITS, G4_CALCGFB
;	[requires BINREAD.PRO (Liam Gumley) via G4_LOAD2X]
;
;
; MODIFICATION HISTORY: (MM/DD/YYYY)
;		Documented 11/05/2010, KY
;	v1.93 	rc3, introduce keyword OUTPUTSTREAM 11/09/2010
;	v1.92 	rc2, change print out of energy midpoint 11/09/2010
;	v1.9 	rc, introduce LATEX compatibility
;	v1.2 	introduced DATASET variable 07/07/2010
;	v1.1c 	derived from G4_PLOTGF 06/14/2010, KY
;	v1.1b 	specialized 05/22/2010, KY
;	v1.1a 	granularized 05/14/2010, KY
;	v1.0 	created 05/06/2010, KY
;	BASED ON:
;		G4_SUBREFINE, 05/14/2010, KY
;		REFINE_G4_M, 09/02/2009, KY
;		LOAD_NEW, 09/19/2008, KY
;-

;---------------------------------------------------------------
FUNCTION G4_PRINTWERROR, data, standard_error, MULTIPLIER = se_to_error
  ; make keywords safe
  IF ~KEYWORD_SET(se_to_error) THEN se_to_error = 1.

  ; reserve / allow definition of helper strings
  COMMON TABLE_STRS

  ; instantiate values
    nElem = N_elements(data)
    retValue = StrARR(nElem)
    data_exponent = LonARR(nElem)
    data_mantissa = FltARR(nElem)
    err_exponent = LonARR(nElem)
    err_mantissa = FltARR(nElem)

  ; find out bad data
    v = WHERE(FINITE(standard_error) AND (standard_error GT 0.), nvalid)
    nans = Where(~FINITE(standard_error), nNaNs)
    zeros = Where(standard_error EQ 0., nzeros)

  ; extract mantissa and exponent from input
    data_exponent[v] = Floor(ALOG10(data[v]))			;(extract exponent from data)
    data_mantissa[v] = data[v]/(10.^data_exponent[v])		;(extract mantissa from data)

    err_exponent[v] = Floor(ALOG10(standard_error[v]))		;(extract exponent from SE)
    err_mantissa[v] = standard_error[v]/(10.^err_exponent[v])	;(extract mantissa from SE)

  ; prototype format code
  fc = StrARR(nElem)
  decimals = (data_exponent - err_exponent)			;(number of decimals to retain)
  normal = Where(decimals GT 0, nCount, COMPLEMENT=odd, NCOMPLEMENT=oCount)
  IF (nCount GT 0) THEN fc[normal] = '(F0.' + StrTrim(decimals[normal]+1L, 2) + ')' 
  IF (oCount GT 0) THEN fc[odd] = '(F3.1)'

  ; form result
    FOR i=0, nvalid-1 DO BEGIN
      retValue[v[i]] = String( cstart + String(data_mantissa[v[i]], FORMAT= fc[v[i]]) $
	+ '(' + String(ROUND(err_mantissa[v[i]]*se_to_error*10.), FORMAT='(1I0)') + ')' $
	+ expOpen + StrTrim(data_exponent[v[i]], 2) + expClose + cJoin, FORMAT=csize )
    ENDFOR

  ; pad with NaNs and 0s
  IF (nzeros GT 0) THEN retValue[zeros] = String('0'+cjoin, FORMAT=csize)
  IF (nNaNs GT 0) THEN retValue[nans] = String('NaN'+cjoin, FORMAT=csize)

  RETURN, retValue
END


;---------------------------------------------------------------
PRO g4_printgf, dataset, ECHANNELS=eFlag, PCHANNELS=pFlag, $
	PAUSE_STATE=pauseFlag, LATEX=texFlag, COLUMNS=print_columns, $
	ENERGY_REBIN=multiplier, OUTPUTSTREAM=file_unit

; make keywords safe
IF ~KEYWORD_SET(texFlag) THEN texFlag=0B
IF ~KEYWORD_SET(print_columns) THEN print_columns = IndGen(11) ELSE $
	print_columns = FLOOR(print_columns) MOD 11
IF ~KEYWORD_SET(multiplier) THEN multiplier = 1L
IF ~KEYWORD_SET(file_unit) THEN file_unit = -1

; data files (obtained from SET_MEPED_VARS and DATASET argument)
eFileNames = dataset.efiles
pFileNames = dataset.pfiles
telescType = dataset.description
typeCode   = dataset.typeCode
; validity check managed in G4_LOAD2X

; specify data product request (Boolean 1 for "request", 0 for "discard")
;  options: [KEY, RUN_PARAM, ENERGY3, POSITION3, MOMENTUM3, EVENTID, HEADER]
dpReq = BytARR(7) + Byte([1,1,1,0,0,0,0])

; one or the other, not both at once
IF KEYWORD_SET(eFlag) THEN BEGIN
	xSpecies = eFileNames
	speciesName = 'ELECTRON'
ENDIF
IF KEYWORD_SET(pFlag) THEN BEGIN
	xSpecies = pFileNames
	speciesName = 'PROTON'
ENDIF


;-----------------------------------
;----- INITIALIZE EXECUTION --------
;-----------------------------------
; initialize generic execution path

  ; load-in binary data
  xData = G4_LOAD2X(xSpecies, dpReq) 

  ;(get references)
  xData_energy3 = Temporary(xData.energy3)
  xData_jobIDs = StrJoin( StrTrim((xData.run_param)[0,WHERE( (xData.run_param)[0,*] NE -999)], 2), ' ', /SINGLE) 

  ; call function G4_BINHITS for per-channel hit indices
    CASE typeCode OF
	1: BEGIN
		xHits = G4_BINHITS(xData_energy3, /PTEL)
		telescopeLabel = ['','','',REPLICATE('P',6), '','']
		total_gf_key = [0,1,1,1,1,1,1]	;(differential; P1-P6 must be added together)
	   END
	2: BEGIN
		xHits = G4_BINHITS(xData_energy3, /ETEL)
		telescopeLabel = ['','','',REPLICATE('E',3), '','','','','']
		total_gf_key = [0,1,0,0,0,0,0]	;(integral; E1 catchs all telemetered hits)
	   END
	ELSE: BEGIN
		Print, 'Invalid Type Code (neither electron nor proton telescope)'
		RETURN
	      END
    ENDCASE

  ; call function G4_CALCGF: output [KEV_ENERGY, GF, GF_SIGMA, HITS]
  xGF = G4_CALCGFB(xData_energy3, xData.run_param, ENERGY_REBIN=multiplier)

  ; dump xGF table to terminal
  Print, 'Geometric Factor for the ' + telescType +' (Geant4 Simulation; generated '+Systime()+' (RUN IDs: '+xData_jobIDs+')'
  Print, 'Incident Particle Energy [keV] | Geometric Factor [cm2 sr] | Std Error | Counts'
  Print, ''
  Print, '--------' + speciesName + ':'
  Print, xGF
  Print, ''

  ;-----------------------------------
  ;-- instantiate helper variables ---
  ;-----------------------------------
  COMMON TABLE_STRS, cstart, cjoin, expOpen, expClose, pm, endline, csize
	cstart = ''		;(cell start)
	cjoin 	= ''		;(cell join)
	expopen = 'x10^'	;(exponential notation / open)
	expclose= ''		;(exponential notation / close)
	pm	= '+/-'		;(plus or minus)
	endline = ''		;(endline)
	csize	= '(A18)'	;(cell size)
	heading	= ['Midpoint','RAW','0','1','2','3','4','5','6','TOTAL']
    IF texFlag THEN BEGIN
	cstart 	= '$'
	cjoin  	= '&'
	expopen = '\times 10^{'
	expclose= '}$'
	pm 	= '\pm'
	endline = '\\'
	csize	= '(A28)'
    ENDIF
	heading = telescopeLabel + [heading+cjoin, endline]


  ;-----------------------------------
  ;--- dimension/fill GF table -------
  ;-----------------------------------
    dim = Size(xGF, /DIMENSIONS)
    gf_table = strArr(11,dim[1])
      depth = IndGen(dim[1])
    gf_table[0,depth] = STRING(xGF[0,depth]) + cjoin	;(copy energy midpoints)
    gf_table[1,depth] = G4_PRINTWERROR(xGF[1,depth], xGF[2,depth], MULTIPLIER=1.)	;(raw GF)
    gf_table[10,depth] = REPLICATE(endline,dim[1])

 
    ; hit index for total hit count [telemetered, not RAW]
    total_hits = REPLICATE(-1L, N_elements(xData_energy3)/3L)	
    hit_tracker = 0L

    ; per channel calculation of GF
    FOR chan= 0, 6 DO BEGIN
      IF (xHits.(chan))[0] NE -1 THEN BEGIN
	xContrGF = G4_CALCGFB(xData_energy3, xData.run_param, INDICES=xHits.(chan), $
		ENERGY_REBIN=multiplier) 
	;  print, 'Channel ', chan & print, xContrGF
	;  print, chan, hit_tracker
	gf_table[chan+2,depth] = G4_PRINTWERROR(xContrGF[1,depth], xContrGF[2,depth], MULTIPLIER=1.)
      	IF total_gf_key[chan] THEN BEGIN
		total_hits[hit_tracker] = xHits.(chan)
		hit_tracker = hit_tracker + N_elements(xHits.(chan))
      	ENDIF
      ENDIF ELSE gf_table[chan+2,depth] = String('0'+cjoin, FORMAT=csize) 
    ENDFOR

    ; subtract out dummy entries and submit to G4_CALCGFB
    ind = LIndGen(hit_tracker)
    xTotalGF = G4_CALCGFB(xData_energy3, xData.run_param, INDICES=total_hits[ind], ENERGY_REBIN=multiplier) 
    gf_table[9,depth] = G4_PRINTWERROR(xTotalGF[1,depth], xTotalGF[2,depth], MULTIPLIER=1.)

    PrintF, file_unit, '*********************************************************************************************************************' 
    PrintF, file_unit, 'Geometric Factor for the ' + telescType +' (Geant4 Simulation; generated ' $
	+ Systime() + ' (RUN IDs: ' + xData_jobIDs + ')'
    PrintF, file_unit, telescType + ': ' + speciesName + ' Contributions'
    full_matrix =[[heading],[gf_table]]
    PrintF, file_unit, full_matrix[print_columns,*]
    PrintF, file_unit, '*********************************************************************************************************************' 
    PrintF, file_unit, ''

IF KEYWORD_SET(pauseFlag) THEN STOP

;(clean up pointer references)
PTR_FREE, xData.header
END
;---------------------------------------------------------------

