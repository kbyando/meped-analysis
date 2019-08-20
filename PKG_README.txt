README.txt, last updated December 3, 2011 (Karl Yando)

Data and Software Supplement for:  
    
Yando, K., R. M. Millan, J. C. Green, and D. S. Evans (2011), A Monte Carlo simulation of the NOAA POES Medium Energy Proton and Electron Detector instrument, J. Geophys. Res., 116, A10231, doi:10.1029/2011JA016671.


Description
-----------

This directory contains simulation code, simulation output, and analysis tools for a Geant4-based simulation of the second generation (SEM-2) MEPED proton and electron telescopes flown aboard the NOAA/TIROS-N (POES) weather satellites.  

The following are brief descriptions of various top-level folders contained within this directory:
 
    /analysis/ - contains analysis routines, written in the Interactive Data Language (IDL).
   
    /g4_data/ - contains Geant4 simulation output in ASCII and binary formats.

    /g4_model/ - contains the C++ code for proton and electron telescope model geometries and simulation physics, to be compiled with a working Geant4 installation.

    /vis/ - contains an archive of IDL routines and runlogs for figures and tables used in the journal article 


Dependencies
-----------
Simulation analysis code is written in the IDL programming language.  An IDL interpreter is necessary to run this analysis code.  

The binary format utilized by these analysis routines is a non-proprietary format authored by Liam E. Gumley of the Space Science and Engineering Center, UW-Madison.  The required IDL tools BINWRITE.PRO and BINREAD.PRO may be obtained from:
http://cimss.ssec.wisc.edu/~gumley/binarytools.html


Configuration
-----------
Our Geant4 configuration employs the following versions and libraries:

    Geant4.9.3

    CLHEP 2.0.4.5

    G4NDL 3.13

    G4EMLOW 6.9

Copies of the above packages may be be found in the sister directory "/support/".  Geant4 and MEPED applications were compiled with GCC 4.1.2 under Red Hat Enterprise Server 5.6.  

IDL analysis routines were executed using IDL version 7.1 under Red Hat Enterprise Linux 5.


Authors
-----------
MEPED applications developed at Dartmouth College from example "N03" by Karl Yando (2007-2011), under the direction of Professor Robyn Millan.  

The simulation physics employed in these applications were written by Dennis H. Wright (SLAC), and may be obtained in unmodified form from:
http://www.slac.stanford.edu/comp/physics/geant4/slac_physics_lists/micro/physlistdoc.html

The simulation physics files are:
SEBosonPhysics.cc
SEDecayPhysics.cc
SEHadronPhysics.cc
SEIonPhysics.cc
SELeptonPhysics.cc
SENeutronPhysics.cc
SEPhysicsList.cc
(and their corresponding header files)

IDL analysis code developed at Dartmouth College by Karl Yando.  BINWRITE.PRO and BINREAD.PRO developed by Liam E. Gumley.  


Contacts
-----------
please report issues to the appropriate GitHub repository


Acknowledgements
-----------
This project made possible by:

    The Geant4 Collaboration (http://geant4.cern.ch/).

    Dennis H. Wright (SLAC), author of the Geant4 physics list used herein.


License
-----------
This compilation is released under an "Open Research License" (ORL), written in the spirit of the ORL proposed by Victoria Stodden.  Various components are released under either the 2-clause (Simplified) BSD license or the Creative Commons Attribution (BY) 3.0 license.  Any code derived from the Geant4 toolkit is subject to the Geant4 Software License, and copyrights for any third-party code rest with their respective rightsholders. 

Code components are served by the 2-clause BSD license:
-----------
Copyright (c) 2007-2011, Karl Yando.  All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-----------
Text, documentation, figures, and other media are served by the Creative Commons Attribution 3.0  license (CC BY 3.0), a copy of which may be found at the URL:
http://creativecommons.org/licenses/by/3.0/
-----------
