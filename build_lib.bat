@echo off
rem
rem   BUILD_LIB [-dbg]
rem
rem   Build the PHOT library.
rem
setlocal
call build_lib_pdoc
call build_lib_phot
