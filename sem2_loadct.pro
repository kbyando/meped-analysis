;+ 
; NAME:
;	SEM2_LOADCT.PRO
;
; AUTHOR:
; 	Karl Yando, Dartmouth College
;	firstname.lastname@dartmouth.edu
;
; 	Colors from www.ColorBrewer.org (http://colorbrewer2.org)
;	 by Cynthia A. Brewer, Geography, 
;	    Pennsylvania State University.
;
; PURPOSE:
; 	Loads a reds/blues color table of HCL colors
;
; CALLING SEQUENCE:
;	SEM2_LOADCT
;
; DESCRIPTION:
;	11/01/2010 :: SEM2_LOADCT will load an indexed palette of 
;	 256 colors for use with IDL programs:
;		proton_scale 	= [1,122] (121, as YlOrRd)
;		electron_scale 	= [123,182] (61, as YlGnBu)
;		gray_scale 	= [183,255] (REMAINDER)
;
;	 Usage: 20*[channel number], where P1-P6=1-6, E1-E3=7-9
;
; INPUTS:
;	N/A
;
; KEYWORDS:
;	N/A
;
; OUTPUTS:
;	loaded color table
;
; SEE ALSO:
; 	Color tables derived from http://colorbrewer2.org
; 
; MODIFICATION HISTORY: (MM/DD/YYYY)
;	- add Violet to (compressed) YlOrRd, 05/02/2010
;	Documented 11/01/2010
;-

PRO sem2_loadct
	; RGB vectors for the YlOrBr color scheme (6+1 channels)
	;p6_redVector = [255,254,254,254,236,204,140]
	;p6_greenVector = [255,227,196,153,112,76,45]
	;p6_blueVector = [212,145,79,41,20,2,4]

	; RGB vectors for the YlOrRd color scheme (6+1 channels)
	;p6_redVector = [255,254,254,253,252,227,177]
	;p6_greenVector = [255,217,178,141,78,26,0]
	;p6_blueVector = [178,118,76,60,42,28,38]

; RGB vectors for the YlOrRd+Violet color scheme (6+1 channels)
p6_redVector = [255,254,254,253,252,177,84]
p6_greenVector = [255,217,178,141,78,0,39]
p6_blueVector = [178,118,76,60,42,38,136]


; RGB vectors for the YlGnBu color scheme (3+1 channels)
e3_redVector = [255,161,65,34]
e3_greenVector = [255,218,182,94]
e3_blueVector = [204,180,196,168]

	; expand vectors using REBIN
	;     (index = channel*20)
	p6bv = REBIN(p6_blueVector,140)
	p6gv = REBIN(p6_greenVector,140)
	p6rv = REBIN(p6_redVector,140)  
	;
	e3bv = REBIN(e3_blueVector,80)
	e3gv = REBIN(e3_greenVector,80)
	e3rv = REBIN(e3_redVector,80)
	;
	; stack vectors, w/ black on zero value
	p_regular = IndGEN( (N_elements(p6_redVector)-1)*20 ) + 1
	e_regular = IndGEN( (N_elements(e3_redVector)-1)*20 ) + 1
	redVector = [0, p6rv[p_regular],e3rv[e_regular]]
	greenVector = [0, p6gv[p_regular],e3gv[e_regular]]
	blueVector = [0, p6bv[p_regular],e3bv[e_regular]]
	;
	; load color table
	TVLCT, redVector, greenVector, blueVector
	;
	; fill upper 25 values with compressed grayscale
	nc = 255 - N_elements(redVector)
	LOADCT, 0, BOTTOM=255-nc, NCOLORS=nc
END


