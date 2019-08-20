;+ 
; NAME:
;	G4_LOAD2X
;
; AUTHOR:
;	Karl Yando, Dartmouth College
;	firstname.lastname@dartmouth.edu
;
; PURPOSE:
;	Function to restore variables from binary save files.
;
; CALLING SEQUENCE:
;	G4_LOAD2X(filenames, dp_request)
;
; DESCRIPTION:
;       10/31/2010 :: G4_LOAD2X will read-in the binary save 
;	 files created by G4_LOAD2B, which stores in a binary
;	 format described by Liam E. Gumley. Data from multiple
;	 save files will be compiled into a single structure of 
;	 data products.
;
; INPUTS:
;	FILENAMES - a string or string array specifying the 
;	 path and filenames of G4_LOAD2B created data files
;
;	DP_REQUEST - a 7-element integer array, normally 
;	 of Boolean values (1=TRUE, 0=FALSE), which specifies
;	 the requested data products according to the following:
;		DP_REQUEST[0]= KEY (byte-encoded ASCII help string)
;		DP_REQUEST[1]= run parameters
;		DP_REQUEST[2]= ENERGY3 (energy data)
;		DP_REQUEST[3]= POSITION3 (position data)
;		DP_REQUEST[4]= MOMENTUM3 (momentum direction data)
;		DP_REQUEST[5]= EVENTID (associated eventID)
;		DP_REQUEST[6]= HEADER (header data; a string array)
;
; KEYWORDS:
;	N/A
;
; OUTPUT:
; 	If successful, G4_LOAD2X will return a data structure
;	 containing the requested data products compiled from
;	 the specified binary save files.
;
; SEE ALSO:
;	G4_LOAD2B
;
; DEPENDENCES:
;	requires BINREAD.PRO (Liam Gumley)
;
;
; MODIFICATION HISTORY: (MM/DD/YYYY)
;		Documented 10/31/2010, KY
;	v1.9b 	rc, documentation update 11/02/2010, KY
;	v1.1 	separated from 'G4_REFINE' 05/14/2010, KY
;	v1.0 	created 05/06/2010, KY
;	BASED ON:
;		LOAD_BINDATA (in G4_REFINE), 05/06/2010, KY
;		REFINE_G4_M, 09/02/2009, KY
;		LOAD_NEW, 09/19/2008, KY
;-


;---------------------------------------------------------------
FUNCTION G4_LOAD2X, filenames, dp_request
  ;(build indexes)
  dpIndex = Where(dp_request, dpCount)
  fileInfo = File_Info(filenames)
  fileIndex = Where( (fileInfo[*]).EXISTS, fileNum)

  storSize = Total( Long64((fileInfo[*]).SIZE), /INTEGER) 
  nStorLines = storSize/(4L*10L)

  ;initialize storage variables [overlarge]
  stor_key = '[NOTE: padding appears as -999]'	;(KEY)
  stor_rnp = Make_Array(6, fileNum+1, VALUE=-999L, /L64)
					 	;(RUN_PARAMS)
  stor_en3 = Replicate(-999., 3, nStorLines+1L)	;(ENERGY3)
  stor_ps3 = stor_en3				;(POSITION3)
  stor_mm3 = stor_en3				;(MOMENTUM3)
  stor_eID = Replicate(-999L, 1, nStorLines+1L)	;(EVENTID)
  stor_hdr = PtrARR(fileNum)			;(HEADER)
  lineMarker = LonArr(7)			;(line pointer)


  ;(loop over files in record)
  FOR file=0, fileNum-1 DO BEGIN
    ;(open file)
    GET_LUN, lun
    OPENR, lun, filenames[fileIndex[file]] 

    ;(loop until we have all requested data products)
    FOR dp=0, dpIndex[dpCount-1] DO BEGIN
      	BINREAD, lun, transferVar 
	trSize = SIZE(transferVar)

	IF dp_request[dp] THEN CASE dp OF
	  0: BEGIN
		transferVar = String(transferVar)
		stor_key = [transferVar[N_elements(transferVar)-1], stor_key]
	     END
	  1: BEGIN
		trIndex = LIndGen(trSize(trSize[0]+2)) + lineMarker[dp]
		stor_rnp[trIndex] = transferVar
	     END
	  2: BEGIN
;		print, MAX(transferVar[0,*], MIN=oomin), oomin, N_ELEMENTS(transferVar)/3L
		trIndex = LIndGen(trSize(trSize[0]+2)) + lineMarker[dp]
		stor_en3[trIndex] = transferVar
	     END
	  3: BEGIN
		trIndex = LIndGen(trSize(trSize[0]+2)) + lineMarker[dp]
		stor_ps3[trIndex] = transferVar 
	     END
	  4: BEGIN
		trIndex = LIndGen(trSize(trSize[0]+2)) + lineMarker[dp]
		stor_mm3[trIndex] = transferVar
	     END
	  5: BEGIN
		trIndex = LIndGen(trSize(trSize[1]+2)) + lineMarker[dp]
		stor_eID[trIndex] = transferVar
	     END
	  6: stor_hdr[fileIndex[file]] = Ptr_New( String(transferVar) )
	  ELSE: Print, 'LOAD_BINDATA: Unknown Data Product ' + String(dp) 
	ENDCASE

	lineMarker[dp] = lineMarker[dp] + trSize(trSize[0]+2)
    ENDFOR 	;(dp loop)

    FREE_LUN, lun
  ENDFOR	;(file loop)

  ;(build return value data structure)
  ;(note: possible to trim excess lines using lineMarker[dp])
  returnVar = {$
    KEY:stor_key, $
    RUN_PARAM:stor_rnp, $
    ENERGY3:stor_en3, $
    POSITION3:stor_ps3, $
    MOMENTUM3:stor_mm3, $
    EVENTID:stor_eID, $
    HEADER:stor_hdr $
    }


RETURN, returnVar
END
;---------------------------------------------------------------

