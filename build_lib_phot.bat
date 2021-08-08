@echo off
rem
rem   BUILD_LIB [-dbg]
rem
rem   Build the PHOT library.
rem
setlocal
call build_pasinit
set libname=phot

call src_insall %srcdir% %libname%

call src_pas %srcdir% %libname%_frame_info %1
call src_pas %srcdir% %libname%_htm_pers %1
call src_pas %srcdir% %libname%_htm_pic_write %1
call src_pas %srcdir% %libname%_whtm %1
call src_pas %srcdir% %libname%_whtm_index %1
call src_lib %srcdir% %libname%

call src_msg %srcdir% %libname%
call src_get %srcdir% phot.css
copya phot.css (cog)progs/phot/phot.css
