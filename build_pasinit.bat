@echo off
rem
rem   Set up for building a Pascal module.
rem
call build_vars

call src_get %srcdir% phot.ins.pas
call src_get %srcdir% phot2.ins.pas
call src_get %srcdir% pdoc.ins.pas
call src_get %srcdir% pdoc2.ins.pas

call src_getbase
call src_getfrom img img.ins.pas
call src_getfrom stuff stuff.ins.pas

call src_builddate "%srcdir%"
