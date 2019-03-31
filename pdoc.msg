/*   Messages related to the PDOC library.
/*
msg err1
  lan english -def
    A new PDOC command was not found as expected.
    Error occurred on line %p1i of file %p2s.
msg err2
  lan english -def
    Unrecognized format character encountered
    on line %p1i of PDOC file %p2s.
msg err3
  lan english -def
    Not free format.  A PDOC line with other than free format was encountered
    where only free format is allowed.
    Error occurred on line %p1i of PDOC file %p2s.
msg err4
  lan english -def
    Bad time specifier token "%p3s" encountered.
    Error occurred on line %p1i of file %p2s.
msg err5
  lan english -def
    No name parameter given for picture.
    Error occurred on line %p1i of file %p2s.
msg err6
  lan english -def
    FRAME command encountered without a current film declared.
    Error occurred on line %p1i of file %p2s.
msg err7
  lan english -def
    Time values are out of order.  The end of the second time value is earlier
    than the start of the first time value.
    Error occurred on line %p1i of file %p2s.
msg err8
  lan english -def
    A reference to the default location was encountered other than at the beginning
    of a location hierarchy names list.
    Error occurred on line %p1i of file %p2s.
msg err9
  lan english -def
    The short reference name parameter is missing.
    Error occurred on line %p1i of file %p2s.
msg err10
  lan english -def
    Person full name parameter is missing.
    Error occurred on line %p1i of file %p2s.
msg err11
  lan english -def
    The person reference name "%p3s" was not previously declared.
    Error occurred on line %p1i of file %p2s.
msg err12
  lan english -def
    Missing longitude argument.
    Error occurred on line %p1i of file %p2s.
msg err13
  lan english -def
    Unrecognized PDOC command "%p3s" encountered
    on line %p1i of file %p2s.
msg err14
  lan english -def
    Extraneous arguments starting with "%p3s" encountered after end of PDOC command.
    Error occurred on line %p1i of file %p2s.
msg err15
  lan english -def
    Illegal, unexpected, or unimplemented PDOC line format ID encountered with
    ordinal value %p1i.
msg err16
  lan english -def
    Internal PDOC picture descriptor has no name.  Each picture must
    have a name.
msg err17
  lan english -def
    The generic image file %p1s was not found in the ORIG directory.
msg err18
  lan english -def
    Duplicate definition of person "%p1s" encountered on line %p2i of file %p3s.
msg err19
  lan english -def
    Missing parameter to keyword %p1s in personData command on line %p2i of file %p3s.
msg err20
  lan english -def
    Error parsing keyword on line %p1i of file %p2s.
msg err21
  lan english -def
    Invalid keyword %p1s encountered on line %p2i of file %p3s.
msg err22
  lan english -def
    Data associated with subcommand %p1s was previously defined.  The error
    occurred on line %p2i of file %p3s.
msg err23
  lan english -def
    Bad parameter to subcommand %p1s on line %p2i of file %p3s.
msg err24
  lan english -def
    Extra parameter to subcommand %p1s on line %p2i of file %p3s.
msg err25
  lan english -def
    Missing parameter to subcommand %p1s on line %p2i of file %p3s.
msg err26
  lan english -def
    Invalid or unassigned person ID encountered in routine
    PHOT_HTM_PERS_WRITE for person with short reference name "%p1s".
msg err27
  lan english -def
    Person full names "%p1s" and "%p2s" are not the same.
msg err28
  lan english -def
    Multiple definitions of person "%p1s" have different description text.
msg err29
  lan english -def
    Multiple portrait file names "%p2s" and "%p3s" found for person "%p1s".
msg err30
  lan english -def
    Multiple WikiTree IDs "%p2s" and "%p3s" found for person "%p1s".
msg err31
  lan english -def
    Attempt to nest input files more than %p1i deep.  Error occurred on line %p2i of
    file %p3s.
/*
/*   Messages referenced directly by PDOC library code.
/*
msg nomem_in_open_fnam
  lan english -def
    Insufficient dynamic memory available in PDOC_IN_OPEN_FNAM.
msg nomem_out_open_fnam
  lan english -def
    Insufficient dynamic memory available in PDOC_OUT_OPEN_FNAM.
msg open_pdoc_in
  lan english -def
    Error occurred on attempt to open PDOC file "%p1s" for input.
msg read_pdoc_file
  lan english -def
    Error encountered on attempt to read contents of PDOC file.
/*
/*   Messages used in applications.
/*
msg err_fp_gcrad
  lan english -def
    Error occurred on attempt to convert geographics coordinate tolerance
    radius value to a string.
msg img_duplicate
  lan english -def
    Duplicate image files %p1s" encountered.  Each image file must have a unique
    generic name.
msg no_in_fnam
  lan english -def
    No input PDOC file name supplied.  A PDOC input file name is required.
msg no_orig_dir
  lan english -def
    No "orig" directory found in the current directory.  An orig directory
    is required, and contains the original images for each frame of the film.
msg no_orig_images
  lan english -def
    No images were found in the "orig" directory.
msg write_pdoc_stream
  lan english -def
    Error encountered on attempt to write information to a PDOC output stream.

