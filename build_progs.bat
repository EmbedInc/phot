@echo off
rem
rem   BUILD_PROGS [-dbg]
rem
rem   Build the executable programs from this source directory.
rem
setlocal
call build_pasinit

call src_prog %srcdir% bfilm %1
call src_prog %srcdir% phot_export %1
call src_prog %srcdir% test_pdoc %1
