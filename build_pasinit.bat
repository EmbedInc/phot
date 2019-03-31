@echo off
rem
rem   Set up for building a Pascal module.
rem
call build_vars

call src_get %srcdir% phot.ins.pas
call src_get %srcdir% phot2.ins.pas
call src_get %srcdir% pdoc.ins.pas
call src_get %srcdir% pdoc2.ins.pas

call src_go %srcdir%
call src_getfrom sys base.ins.pas
call src_getfrom sys sys.ins.pas
call src_getfrom util util.ins.pas
call src_getfrom string string.ins.pas
call src_getfrom file file.ins.pas
call src_getfrom imglib img.ins.pas
call src_getfrom stuff stuff.ins.pas

call src_builddate "%srcdir%"
