;+ G4_CALCGF(b) 
; NAME:
;	G4_CALCGFB.PRO
;
; AUTHOR:
;	Karl Yando, Dartmouth College
;	firstname.lastname@dartmouth.edu
;
; PURPOSE: 
; 	Function to calculate geometric factor and associated error    
;
; CALLING SEQUENCE:
;	G4_CALCGFB, energy_data, data_key
;
; DESCRIPTION:
; 	11/02/2010 :: G4_CALCGF(b) will calculate geometric factor as 
;	 a function of energy, requiring Geant4-derived hit data and
; 	 nominal run parameters for an isotropic source distribution
;	 originating on an enclosing spherical surface. Padding values
;	 are of type F_NAN, and standard error is of type SE of the mean.
;
; INPUTS:
;	ENERGY_DATA - an array of energy deposit data, in the form:
;		ENERGY_DATA = [E_INCIDENT, D1_DEPOSIT, D2_DEPOSIT]x{entries} 
;	DATA_KEY - an array of run parameters (type LONG64), of form:
;		DATA_KEY = [jobID, startEnergy, nSteps, eventsPerStep, $
;				CTIME, MTIME]
;		* RESTRICTIONS: nSteps (per order magnitude) should equal 9 *
; 
; KEYWORDS:
;	INDICES - array index which points into ENERGY_DATA, primarily useful
;	 in conjunction with G4_BINHITS to calculate geometric factor for
;	 a particular energy channel 
;	ENERGY_REBIN - re-bin multiplier (of type INT) to force speculative energy
;	 binning on the basis of a REBIN-like operation
;
; OUTPUTS:
;	If successful, G4_CALCGFB will return an array of geometric factors
;	 and supporting information (per energy bin), of type:
;		[ENERGY_MIDPOINT, GEOMETRIC_FACTOR, STD_ERROR, COUNTS]
;
; SEE ALSO:
;	G4_CALCGF (original, without support for ENERGY_REBIN functionality)
;
; DEPENDENCES:
;	N/A
;
; MODIFICATION HISTORY: (MM/DD/YYYY)
;		Documented 11/02/2010, KY
;	v2.0 rc, generalized internal indexing method 06/30/2011.  Previously required 
;	   the number of steps per run (within any order of magnitude energy) to be 
;	   evenly spaced [e.g. 1 run of 9 steps, 3 runs of 3 steps].  Now accepts
;	   mixed spacing of runsteps [e.g. 1 run of 8 steps, 1 run of 1 step].
;	v1.9 rc, documentation update 11/03/2010, KY
;	v1.2 G4_CALCGFB introduce experimental ENERGY_REBIN keyword 10/26/2010, KY
;	v1.1 separated from 'G4_REFINE' 05/14/2010, KY
;	v1.0 created 05/06/2010, KY
;	BASED ON:
;		CALC_GF (in G4_REFINE), 05/06/2010, KY
;		REFINE_G4_M, 09/02/2009, KY
;		LOAD_NEW, 09/19/2008, KY
;-

;---------------------------------------------------------------
FUNCTION G4_CALCGFB, energy_data, data_key, INDICES=range, ENERGY_REBIN=multiplier
  valid = Where(data_key[0,*] NE -999L, nRuns)	;(remove padding)
 IF nRuns LE 0 THEN gfMatrix= -1 ELSE BEGIN

  IF ~KEYWORD_SET(range) THEN BEGIN
  	range = LIndGen(N_elements(energy_data)/3L)
  ENDIF 

  ; require that variable MULTIPLIER (or its reciprocal) be of type INTEGER
  IF ~KEYWORD_SET(multiplier) OR $
	((LONG(multiplier) NE multiplier) AND $
	  (LONG(1./multiplier) NE (1./multiplier))) $
	THEN multiplier = 1L

  ;(alias useful quantities)
  jobID = data_key[0,valid]
  startE = data_key[1,valid]		;(units of [keV])
  nSteps = data_key[2,valid]
  eventsPerStep = data_key[3,valid]	;(changed for multiplier != 1.0)

  ;(determine good starting point)
  ;(  NOTE: only works with 9 steps per order of magnitude; if necessary,  )
  ;(   edit data_key's entries for "nSteps" and "eventsPerStep" to comply. ) 
  ;(  UPDATE 10/26/2010: exp support for binning at a variable # of steps)
  binSize = 1000000.			;(units of [keV]; ie 1 GeV)
  hi = MAX(startE, MIN=lo)
  WHILE (binSize GT hi) DO binSize = binSize/10.

  ;(instantiate product matrices: ENERGY, GF, SEM [Std Error ot Mean], HITS)
  gfMatrix = Replicate(!Values.F_NaN, 4, 1)


  ;(array decimation)
  WHILE binSize GE lo DO BEGIN
    ;(HISTOGRAM the array)
    hitsPerBin = HISTOGRAM(energy_data[0,range], BINSIZE=binSize/multiplier, $
	MIN=binSize, MAX=binSize*10., LOCATIONS=eBreaks) 	;, REVERSE_INDICES=ri)
	; print, '> Hits Per Bin: ', hitsPerBin

    ;(helper quantities)
     ;(associated run indices)
     asc = Where((startE GE binSize) AND (startE LT binSize*10.), nAssoc)
	; print, binSize, asc, nAssoc, startE[asc] 

     ;(expanded eventsPerStep)
     nEventsDB = Replicate(!Values.F_NAN, 9L*multiplier + 1L)
     dataBasePointer = 0		;(introduced 06/30/2011 to avoid possible indexing error)
     FOR i=0, nAssoc-1 DO BEGIN
      nEventsDB[dataBasePointer] = $	;GENERALIZED (previously "nEventsDB[i*nSteps[asc[i]]*multiplier] = $"
	Replicate(eventsPerStep[asc[i]]/multiplier, nSteps[asc[i]]*multiplier)
      dataBasePointer = dataBasePointer + nSteps[asc[i]]*multiplier
     ENDFOR

     ;(storage stack)
     nBr = N_elements(eBreaks+1)	;(number of bins)
     stack = FltArr(4,nBr)		;(dummy top and bottom)
     stack[0,*] = (REFORM( REBIN(eBreaks, nBr*2),2,nBr))[1,*]
					;(copy in energies)
     stack[3,*] = REFORM(hitsPerBin, 1, nBr)
					;(copy in hitsPerBin)

    ;(calculate full-instrument GF + GF_SEM)
    f = Float(hitsPerBin)/nEventsDB
    stack[1,*] = f*(4.*(!pi^2)*(3.5)^2)	;(GF)
    stack[2,*] = (4.*(!pi^2)*(3.5)^2) * sqrt((1.-f)*(f/nEventsDB))	;(GF_SEM)

    ;ind4 = IndGen(4)			;(reference index, four elements)
    bottom = [eBreaks[0], stack[1,0], !Values.F_NAN, !Values.F_NAN]
    stack[1,nBr-1] = stack[1,nBr-2]
    stack[3,nBr-1] = !Values.F_NAN

    ;(transfer STACK contents to GFMATRIX)
    gfMatrix = [ [bottom], [stack], [gfMatrix]]
	;   print, gfMatrix

    binSize = binSize/10.
  ENDWHILE 
 ENDELSE

RETURN, gfMatrix 
END
;---------------------------------------------------------------

