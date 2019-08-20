PRO G4_LOAD2B, src
;+ 
; NAME:
;       G4_LOAD2B.PRO
;
; AUTHOR: 
;       Karl Yando, Dartmouth College, Hanover, NH 03755
;       firstname.lastname@dartmouth.edu
;
; PURPOSE:
;       Read-in and structure Geant4 data from ASCII text files in a
;       given directory for storage in an intermediate binary file.
; 
; CALLING SEQUENCE:
;       G4_LOAD2B, source_directory
;
; DESCRIPTION:
;       04/18/2010 :: G4_LOAD2B will read-in and structure the Geant4
;        output stored in *.o* ASCII text files of a specified direct-
;        -ory, compiling metadata as appropriate and forming from these
;        inputs an intermediate binary data file (based on the binary
;	 format described by Liam E. Gumley).   
;
;       Of note, no "loss" of data occurs, as the only conversion is 
;        from ASCII format to an IDL binary file, and all expected data
;        products are preserved.
;
; INPUTS: 
;       SOURCE_DIRECTORY - a scalar string, specifying the path of a
;        directory containing ASCII data generated by MExxD_v1.4(+)
;
; KEYWORDS:
;
;	N/A
;
; OUTPUTS:
;       If successful, G4_LOAD2B creates a binary file in the same
;        directory as the ASCII files specified by the SOURCE_DIRECTORY
;        argument given it.  This file is given a name of the form:
;               <Telescope>_<Species><StartEnergy>_<nSteps>[.<totalSteps>]x<EventsPerStep>.bin
; 
;               (e.g., 'ptel_p1.0MeV_9x1.E+06.bin')
;
;       When implemented as a function, G4_LOAD2B will return either a
;        string containing the full path of this SAVE file, or the byte
;        value '0B' (ie, 'FAIL').
;
;       All save files created by G4_LOAD2B will contain a byte-encoded 
;	 descripter string and data products of a form described by Liam
;	 Gumley <http://cimss.ssec.wisc.edu/~gumley/binarytools.html>.
;
;			  KEY<	[byte-encoded ASCII array]
;				KEY[*]< [file description]
;				KEY[8]<	[ASCII string, specifying]
;					SRC_NAME (source file name)
;					SRC_SIZE (source file size [bytes])
;					SRC_CTIME (source file creation time)
;					VERSION (G4_LOAD2B revision control)
;					TIMESTAMP (*.bin creation time)
;		     RUN_PARAM<	[long integer array]
;				JOB_ID
;				START_ENERGY (keV)
;				N_STEPS (in the job specified by JOB_ID)
;				EVENTS_PER_STEP
;				CTIME (source file creation time)
;				MTIME (source file modification time)
;				TOTAL_STEPS (per order magnitude)
;		       ENERGY3< [float array]
;				E_INCIDENT (initial keV energy of particle)
;				D1_DEPOSIT (energy [keV] deposited in D1/D3)
;				D2_DEPOSIT (energy [keV] deposited in D2/--)
;		     POSITION3<	[float array]
;				X/Y/Z (initial particle position [mm])
;		     MOMENTUM3< [float array]
;				PX/PY/PZ (initial particle momentum [normalized])
;		       EVENTID<	[long integer array]
;				EVENT_ID (event ID #, as generated by Geant4)
;		        HEADER< [byte-encoded ASCII array]
;				HEADER< [Geant4 runtime header]
;
; SEE ALSO:
;       REFINE_G4_B (for calculation of Geometric Factor and Efficiencies)
;
; MODIFICATION HISTORY: (MM/DD/YYYY) 
;               Documented 09/02/2009, updated 11/02/2010 KY
;	v 1.9b 	rc, documentation update 11/02/2010, KY
;	v b1.1b renamed 'G4_LOAD2B', KY (from 'LOAD_G4_B')
;	v b1.1a	large array bug-fixes (2) implemented 05/11/2010, KY
;	v b1.0  binary-version created 04/18/2010, KY (from 'LOAD_G4_M')
;       v m1.0  created 09/01/2009, KY (from 'extractG4run' and 'load_new')
;-


; Initialize Variables 
src = String(src)
tab = String(9B)
userInitials = ''
file_count = 0

  ; obtain user signature
  Print, 'LOAD_G4_B:  Welcome!  Please input the following:  '
  READ, userInitials, PROMPT= StrCompress(tab+'User Initials:  ')



; test user-input (source) for valid files
IF FILE_TEST(src, /READ, /REGULAR) THEN BEGIN
  data_file = src	;(assume good data)
  file_count = 1
ENDIF ELSE IF FILE_TEST(src, /DIRECTORY) THEN BEGIN
  ; search for contents (*.o[jobID])
  any_file = src + '*.o*'
  Print, 'LOAD_G4_B:  Searching for: "', any_file, '"...'
  data_file = FILE_SEARCH(any_file, COUNT=file_count)
  Print, tab, 'Number of files found: ', file_count
ENDIF

IF file_count EQ 0 THEN Print, tab + 'Invalid Data Source'



; Read In Pertinent Data Files
FOR i=0, file_count-1 DO BEGIN

    ; instantiate data products
    COMMON RUN_PARAMS, species, telescopeType, jobID, nSteps, eventsPerStep, startEnergy
    species = 'u'
    telescopeType = 'utel'
    jobID = 0L
    nSteps = 0L		;(NOTE v1.9: also something we can extract from ss_marker)
    eventsPerStep = 0.
    startEnergy = 0.


    ; attempt to extract run-information from filename
    runInfo = StrSplit(FILE_BASENAME(data_file[i]), '_x', COUNT=nDPs, /EXTRACT)

    IF (nDPs EQ 4) THEN BEGIN
	extractOK = MINE_FILENAMES(runInfo)
    ENDIF ELSE BEGIN
	Print, 'LOAD_G4 [' + FILE_BASENAME(data_file[i]) + ']:'	
	Print, tab+'Could not extract run parameters'
    ENDELSE


    ; Get Source File Information
    OPENR, /GET_LUN, unit, data_file[i]
    f_info = FSTAT(unit)

    src_name = f_info.NAME
    src_size = f_info.SIZE
    src_ctime = SYSTIME(0, f_info.CTIME, /UTC) + 'UTC'
    src_mtime = SYSTIME(0, f_info.MTIME, /UTC) + 'UTC'


    ; Construct RUN_PARAMETERS
    run_parameters = [jobID, Long(startEnergy), nSteps, eventsPerStep, f_info.CTIME, f_info.MTIME]
    key = ['ASCII_README: binary-encoded datafile.  Extract using BINREAD.PRO. Data Products: ',$
	'1: key (byte-encoded ASCII)  ', $
	'2: run_param (LONG64[jobID, startEnergy (keV), nSteps, eventsPerStep, CTIME, MTIME, total_steps])  ', $
	'3: energies (FLOAT[energy_initial, energyDep_d1/3, energyDep_d2/-])  ', $
	'4: position (FLOAT[x,y,z])  ', $
	'5: momentum (FLOAT[px,py,pz])  ', $
	'6: eventID (LONG)  ', $
	'7: header (byte-encoded ASCII)  ', $
	'Created, ' + Systime(0, /UTC) + ' by ' + userInitials + '.  Source file: ' + src_name $
		+ ', created ' + src_ctime + ' (' + String(src_size) + 'B).  G4_LOAD2B v1.9']

    ; Auto-Read-In
	ss_marker = 0L			;(data start/stop marker)
	ss_byteIndex = Lon64ARR(2,1001)	;(big, for start/stop pointer refs)
	ss_lineIndex = LonARR(2,1001)	;(big, for start/stop line numbers)
	line_count = 0L			;(number of lines [absolute])
	str=''				;(empty string)


	; peruse contents (no copy; locate information)
	WHILE (~EOF(unit)) DO BEGIN
	  READF, unit, str		;(read-in line)
	  IF StrCmp(str,'%D',2) THEN BEGIN	;(test for data start/stop)
		ss_lineIndex[ss_marker] = ++line_count	;(store line #)
;	print, ss_marker, line_count, ss_lineIndex[ss_marker]
		POINT_LUN, -unit, byteID		;(get byte ID)
		ss_byteIndex[ss_marker++] = byteID	;(store byte ID) 
;	print, byteID, ss_byteIndex[ss_marker-1L]
	  ENDIF	ELSE ++line_count		;(increment line count)
	ENDWHILE	

	; test for a complete dataset (expect a whole number of DATA BEGIN / DATA END pairs)
	IF ss_marker MOD 2 THEN Print, 'LOAD_G4_B: LOAD ERROR!  Truncated file??'

	  dataset_ref = (ss_lineIndex[1,*] - ss_lineIndex[0,*]) - 1L 
					;(lines of data per runtime event)
	  set_index = Where(dataset_ref > 0, dataset_count)	;(returns non-null sets)
	IF (dataset_count LE 0L) THEN Print, 'LOAD_G4_B: Empty Set in file' + src_name
;	print, dataset_count


	; instantiate empty data frame (overbuild)
	data = Replicate(-999., 10L, LONG(TOTAL(dataset_ref[set_index]))+1L);line_count)
	putPos = 0L

	; form data frame, begin extraction (per runtime event) 
	FOR j=0L, dataset_count-1L DO BEGIN
	  	frame = FltARR(10, dataset_ref[set_index[j]])	;(array)
		POINT_LUN, unit, ss_byteIndex[2L*set_index[j]]
;	print, ss_byteIndex[2L*set_index[j]], str
		READF, unit, frame	;(read-in data)
		putIndex = LIndGen( N_elements(frame) ) + putPos
		data[putIndex] = frame
		putPos = putPos + N_elements(frame)
;print, '>> ', dataset_ref[set_index[j]], N_ELEMENTS(frame), putPos, N_elements(WHERE(data[*] EQ -999.)), line_count*10L - putPos
	ENDFOR


	; extract header
	IF (dataset_count GE 0L) THEN BEGIN
	  header = StrARR(1, ss_lineIndex[0]-1L)
	  POINT_LUN, unit, 0L		;("rewind" file)
	  READF, unit, header
	ENDIF

	; free lun
	FREE_LUN, unit

	; restructure DATA array
	nColumns = 10L
	nRows = (N_elements(data))/nColumns
	rows = LIndGen(nRows)

	eventID = Long(data[0,rows])
	position3 = data[1:3,rows]
	momentum3 = data[4:6,rows]
	energy3 = data[7:9,rows]

;	help, eventID, position3, momentum3, /structure

	; write out results (binary format)
	outputFile = telescopeType + '_' + runInfo[0] + '_' + String(jobID) + '.bin'
	OpenW, lun, outputFile, /get_lun
	BinWRITE, lun, Byte(key)			;([ASCII] byte key for run_parameters)
	BinWRITE, lun, run_parameters			;(run parameters) 
	BinWRITE, lun, energy3				;(energy data)
	BinWRITE, lun, position3			;(support data)
	BinWRITE, lun, momentum3			;(support data)
	BinWRITE, lun, eventID				;(support data)
	BinWRITE, lun, Byte(header)			;([ASCII] support data)
	FREE_LUN, lun
ENDFOR
	
END

FUNCTION MINE_FILENAMES, runInfoStrArr
  ; filename has been subjected to STRSPLIT(file, '_x', /EXTRACT) 
  ;   and is found to have FOUR components (argument "runInfoStrArr" = StrARR[4])

  COMMON RUN_PARAMS

  ;(runInfoStrArr[0]-- species, energy, energy unit)
  species = StrMID(runInfoStrArr[0], 0, 1)		;(species- "p" or "e")
  eUnits = StrMID(runInfoStrArr[0], 2, /REVERSE_OFFSET)	;(units of energy)
  energy = StrMID(runInfoStrArr[0], 1, N_elements(Byte(runInfoStrArr[0])) - 4)

  IF StrCmp(eUnits, 'keV', /FOLD_CASE) THEN startEnergy = float(energy) $ ;(keV is our default)
    ELSE IF StrCmp(eUnits, 'MeV', /FOLD_CASE) THEN startEnergy = float(energy)*1.e3 $
    ELSE IF StrCmp(eUnits, 'GeV', /FOLD_CASE) THEN startEnergy = float(energy)*1.e6 $
    ELSE IF StrCmp(eUnits, '0eV', /FOLD_CASE) THEN startEnergy = float(energy)*1.e-3 $
    ELSE RETURN, 3		;(unrecognized units-- FAIL) 

  ;(runInfo[1]--  number of runs ["steps"] in file)
  nSteps = Long(runInfoStrArr[1])

  ;(runInfo[2]--  number of events)
  eventsPerStep = Long(Float(runInfoStrArr[2]))

  ;(runInfo[3]--  telescope type and jobID)
  typeID = StrSplit(runInfoStrArr[3], '.', COUNT=nSubDPs, /EXTRACT)
  telescopeType = typeID[0]
  jobID = StrMID(typeID[nSubDPS-1], 1)

;help, species, telescopeType, jobId, nSteps, eventsPerStep, startEnergy, /structure
  RETURN, 0 	;(everything OK)
END
