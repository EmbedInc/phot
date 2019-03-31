@echo off
rem
rem   BUILD_LIB_PDOC [-dbg]
rem
rem   Build the PHOT library.
rem
setlocal
call build_pasinit
set libname=pdoc

call src_insall %srcdir% %libname%

call src_pas phot %libname%_dtm %1
call src_pas phot %libname%_find %1
call src_pas phot %libname%_get %1
call src_pas phot %libname%_header %1
call src_pas phot %libname%_in %1
call src_pas phot %libname%_init %1
call src_pas phot %libname%_out %1
call src_pas phot %libname%_perslist %1
call src_pas phot %libname%_put %1
call src_pas phot %libname%_read %1
call src_pas phot %libname%_write %1

call src_lib %srcdir% %libname%
call src_msg %srcdir% %libname%

call src_doc %srcdir% %libname%.txt
