@echo off
rem
rem   Define the variables for running builds from this source library.
rem
set srcdir=phot
set buildname=
call treename_var "(cog)source/phot" sourcedir
set libname=phot
set fwname=
call treename_var "(cog)src/%srcdir%/debug_%fwname%.bat" tnam
make_debug "%tnam%"
call "%tnam%"
