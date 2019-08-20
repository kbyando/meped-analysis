;+ G4_FINGERPRINT.PRO
; 	generic function for fingerprinting/documentation of
; 	routines / data / settings utilized in generating figures 
;	for publication
;
; AUTHOR:
;       Karl Yando, Dartmouth College
;       firstname.lastname@dartmouth.edu
;	v1.1 May 3, 2011 (no update; old code removed)
;       v1.1 March 15, 2011, Last Updated
;       v1.0 Sept 30, 2010, Last Updated
;
; ADAPTED FROM 'FINGERPRINT.PRO' v1.0
;-
FUNCTION g4_fingerprint, routines

; Acquire timestamps, etc
        timestamp = BIN_DATE(SYSTIME(0))
	hashID = String(timestamp[0], FORMAT='(1I04)') + String(timestamp[1:5], FORMAT='(5I02)')
	image_folder = 'scratch_dir/'

; Create Log File (*.log)
	hash_stem = image_folder + hashID
        OPENW, fileID, hash_stem+'.log', /GET_LUN
        PRINTF, fileID, 'Log File for Generation of ' + hashID + '.eps/txt'
        PRINTF, fileID, 'IDL Version: ' + !VERSION.RELEASE
        Print, 'LUN ID: ', fileID
        tab = '       '

        FOR i=0, N_ELEMENTS(routines)-1 DO BEGIN
          fInfo = FILE_INFO(routines[i])
          IF fInfo.EXISTS THEN BEGIN
                PRINTF, fileID, 'ROUTINE(' +StrTrim(i,2) + '): ' $
                        + routines[i]
                PRINTF, fileID, tab + 'PATH: ' + fInfo.NAME
                PRINTF, fileID, tab + 'SIZE: ' + STRING(fInfo.SIZE) + ' (Bytes)'
                PRINTF, fileID, tab + 'LAST MODIFIED: ' + SYSTIME(0, fInfo.MTIME)
                FILE_COPY, routines[i], image_folder + hashID + $
                        '_' + StrTrim(i,2) + '.dep'
          ENDIF ELSE PRINTF, fileID, 'Dependence ' + routines[i] + ' not found. '
        ENDFOR
        PRINTF, fileID, 'COMPILED ROUTINES: ' + StrJoin(ROUTINE_INFO(), ' ')
        PRINTF, fileID, ''

; Close Log File
FREE_LUN, fileID
RETURN, hash_stem
END
