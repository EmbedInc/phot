{   Program BFILM [<directory>]
*
*   Quick hack program to set up a full film directory given the original
*   scans and the PDOC file for the film.
}
program bfilm;
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'img.ins.pas';
%include 'stuff.ins.pas';
%include 'pdoc.ins.pas';
%include 'phot.ins.pas';

const
  max_msg_parms = 1;                   {max parameters we can pass to a message}

var
  dir: string_treename_t;              {name of directory to run in}
  name: string_treename_t;             {scratch name string}
  tnam: string_treename_t;             {scratch treename}
  dnam: string_treename_t;             {film directory name}
  fnam: string_treename_t;             {scratch file name}
  lnam: string_leafname_t;             {full leafname of current image in ORIG directory}
  film: string_var80_t;                {default film name, from directory leafname}
  opt: string_treename_t;              {upcased command line option}
  parm: string_treename_t;             {command line option parameter}
  fn1, fn2: string_leafname_t;         {scratch file names}
  nprev, ncurr, nnext: string_var80_t; {previous, current, and next picture names}
  s: string_var8192_t;                 {scratch string}
  tk: string_var256_t;                 {scratch string token}
  imgsuff: string_var80_t;             {list of image file type suffixes}
  p: string_index_t;                   {string parse index}
  in: pdoc_in_t;                       {PDOC file input state}
  pout: pdoc_out_t;                    {PDOC file writing state}
  mem_p: util_mem_context_p_t;         {pointer to our private mem context}
  pdpic_p: pdoc_picent_p_t;            {pointer to current picture in PDOC list}
  pic_p: pdoc_pic_p_t;                 {points to description of current picture}
  pic_prev_p: pdoc_pic_p_t;            {pointer to previous picture}
  pic_next_p: pdoc_pic_p_t;            {pointer to next picture}
  perent_p: pdoc_perent_p_t;           {pointer to current person list entry}
  conn: file_conn_t;                   {scratch I/O connection}
  info: file_info_t;                   {info about a directory entry}
  origs: string_list_t;                {list of original image file names}
  deriv: string_list_t;                {list of images derived from originals}
  wlist: string_list_t;                {list of images in the order to write them out}
  hout_ind: htm_out_t;                 {INDEX.HTM writing state}
  hout_pic: htm_out_t;                 {writing state for specific picture HTM file}
  deriv_p: pdoc_strent_p_t;            {pointer to derived image list entry}
  t1: sys_clock_t;                     {scratch file timestamp}
  pick: sys_int_machine_t;             {number of token picked from list}
  nextid: sys_int_machine_t;           {next unique ID to assign}
  pdoc: pdoc_t;                        {data from PDOC file}
  wpdoc: boolean;                      {write PDOC output file}
  tf: boolean;                         {TRUE/FALSE value returned by program}
  make: boolean;                       {need to make filtered images}
  exstat: sys_sys_exstat_t;            {program exit status code}

  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status code}

label
  next_opt, err_parm, parm_bad, done_opts,
  done_pdoc_read, loop_imgtypes, done_imgtypes, loop_readorig, done_readorig,
  loop_readderiv, done_readderiv, done_makederiv,
  loop_pics, done_picw, done_pics;
{
********************************************************************************
*
*   Subroutine ASSIGN_PEOPLE_IDS (LIST_P)
*
*   Assign unique sequential IDs to each person definition in the list that is
*   referenced but does not already have unique ID assigned
}
procedure assign_people_ids (          {assign unique IDs to person definitions}
  in      list_p: pdoc_perent_p_t);    {pointer to start of persons list}
  val_param; internal;

var
  ent_p: pdoc_perent_p_t;              {pointer to current list entry}

begin
  ent_p := list_p;                     {init to first list entry}
  while ent_p <> nil do begin          {scan the list}
    if
        ent_p^.ent_p^.ref and          {this person was referenced ?}
        (ent_p^.ent_p^.intid = 0)      {but does not have ID assigned ?}
        then begin
      ent_p^.ent_p^.intid := nextid;   {assign the next ID to this person}
      nextid := nextid + 1;            {update the ID to assign next time}
      end;
    ent_p := ent_p^.next_p;            {advane to next list entry}
    end;
  end;
{
********************************************************************************
*
*   Subroutine GET_PIC (NAME, PREV_P, PIC_P)
*
*   Return PIC_P pointing to the picture descriptor for the picture with generic
*   name NAME.  The descriptor read from the PDOC file will be used if
*   available.  If not, a simple picture descriptor with most fields not present
*   is created and PIC_P is passed back pointing to it.  PREV_P must point to
*   the descriptor for the previous picture, and may be NIL to indicate there is
*   no previous picture.  The previous picture information may be used to fill
*   in default information when no explicit PDOC information is available.
*
*   The list of derived image names in DERIV is searched, and a list of derived
*   images for this image is created if any are found.
}
procedure get_pic (                    {get picture descriptor from picture name}
  in      name: univ string_var_arg_t; {picture name from ORIG directory}
  in      prev_p: pdoc_pic_p_t;        {pointer to previous picture, may be NIL}
  out     pic_p: pdoc_pic_p_t);        {returned pointing to the picture descriptor}
  val_param; internal;

var
  last_p: pdoc_strent_p_t;             {pointer to last entry in derived list}
  ent_p: pdoc_strent_p_t;              {scratch pointer to derived list entry}
  uname: string_leafname_t;            {upper case version of generic picture name}
  dname: string_leafname_t;            {upper case version of generic DERIV picture name}
  tnam: string_treename_t;             {scratch treename}
  lnam: string_leafname_t;             {generic leafname of the image}
  stat: sys_err_t;                     {completion status}

label
  loop_deriv;

begin
  uname.max := size_char(uname.str);   {init local var strings}
  dname.max := size_char(dname.str);
  tnam.max := size_char(tnam.str);
  lnam.max := size_char(lnam.str);

  string_fnam_unextend (name, imgsuff.str, lnam); {make generic leafname of this image}
{
*   Set PIC_P pointing to a valid picture descriptor with at least the picture
*   name filled in.
}
  pdoc_find_pic_name (pdoc.pics_p, lnam, pic_p); {look for picture descriptor from PDOC file}

  if pic_p = nil then begin            {no such picture described in PDOC file ?}
    util_mem_grab (sizeof(pic_p^), mem_p^, false, pic_p); {allocate memory for pic desc}
    pdoc_pic_init (pic_p^);            {initialize it to empty}
    string_alloc (lnam.len, mem_p^, false, pic_p^.name_p); {alloc mem for image name string}
    string_copy (lnam, pic_p^.name_p^); {save image name}
    pic_p^.film_p := univ_ptr(addr(film)); {init to default film name}

    if prev_p <> nil then begin        {previous picture exists to take defaults from ?}
      pic_p^.namespace_p := prev_p^.namespace_p;
      pic_p^.film_p := prev_p^.film_p;
      pic_p^.filmdesc_p := prev_p^.filmdesc_p;
      pic_p^.copyright_p := prev_p^.copyright_p;
      pic_p^.stored_p := prev_p^.stored_p;
      pic_p^.by_p := prev_p^.by_p;
      pic_p^.manuf_p := prev_p^.manuf_p;
      pic_p^.model_p := prev_p^.model_p;
      pic_p^.softw_p := prev_p^.softw_p;
      pic_p^.host_p := prev_p^.host_p;
      pic_p^.user_p := prev_p^.user_p;
      end;
    end;
{
*   Add information from the ORIG and RAW images, if they exist.
}
  string_vstring (tnam, 'orig/'(0), -1); {make image file name in ORIG directory}
  string_append (tnam, name);
  pdoc_header_add_fnam (pic_p^, mem_p^, tnam, stat); {add info from ORIG image}
  discard( file_not_found(stat) );     {ignore if image not found}
  sys_error_abort (stat, '', '', nil, 0);

  string_vstring (tnam, 'raw/'(0), -1); {make image file name in RAW directory}
  string_append (tnam, lnam);
  pdoc_header_add_fnam (pic_p^, mem_p^, tnam, stat); {add info from RAW image}
  discard( file_not_found(stat) );     {ignore if image not found}
  sys_error_abort (stat, '', '', nil, 0);

  pdoc_dtm_image (pic_p^, mem_p^, tnam, stat); {get time from RAW file if unknown}
  discard( file_not_found(stat) );     {ignore if image not found}
  sys_error_abort (stat, '', '', nil, 0);

  string_vstring (tnam, 'orig/'(0), -1); {make image file name in ORIG directory}
  string_append (tnam, name);
  pdoc_dtm_image (pic_p^, mem_p^, tnam, stat); {get time from ORIG file if unknown}
  discard( file_not_found(stat) );     {ignore if image not found}
  sys_error_abort (stat, '', '', nil, 0);
{
*   Now create the list of pictures derived from this one.  DERIV is the list of
*   derived picture generic names.  A picture is considered derived from this one
*   if the derived name starts with the generic picture name, followed by an
*   underscore, followed by additional text.  If any derived pictures are found
*   their names are linked to the picture descriptor in the order they appear in
*   DERIV.
}
  last_p := nil;                       {init to derived picture list is empty}
  string_copy (lnam, uname);           {make upper case generic picture name}
  string_upcase (uname);
  string_list_pos_start (deriv);       {position to before first derived name}

loop_deriv:                            {back here each new derived list entry}
  string_list_pos_rel (deriv, 1);      {advance to new derived name}
  if deriv.str_p = nil then return;    {hit end of derived names list ?}
  string_copy (deriv.str_p^, dname);   {make upper case generic derived picture name}
  string_upcase (dname);
{
*   The upper case original picture name is in UNAME, and the upper case derived
*   picture name is in DNAME.  Jump to LOOP_DERIV if the derived picture is not
*   derived from this original picture.
}
  if dname.len < (uname.len + 2) then goto loop_deriv; {derived name too short ?}
  if dname.str[uname.len+1] <> '_' then goto loop_deriv; {no "_" at required place ?}
  if not string_match (uname, dname) then goto loop_deriv; {not start with right string ?}
{
*   This derived image is derived from the original image.
}
  util_mem_grab (                      {allocate memory for new derived list entry}
    sizeof(ent_p^), mem_p^, false, ent_p);
  ent_p^.str_p := deriv.str_p;         {set pointer to derived image name in DERIV}
  if last_p = nil
    then begin                         {this is first list entry}
      pic_p^.deriv_p := ent_p;         {set pointer to start of chain}
      ent_p^.prev_p := nil;            {indicate this entry is at start of chain}
      end
    else begin                         {adding to end of existing chain}
      last_p^.next_p := ent_p;         {link forwards from previous entry}
      ent_p^.prev_p := last_p;         {link backwards from this entry}
      end
    ;
  ent_p^.next_p := nil;                {new entry is at end of chain}
  last_p := ent_p;                     {update pointer to last entry in chain}
  goto loop_deriv;                     {back to check next derived picture name}
  end;
{
********************************************************************************
*
*   Start of main program.
}
begin
  name.max := size_char(name.str);     {init local var strings}
  tnam.max := size_char(tnam.str);
  dnam.max := size_char(dnam.str);
  fnam.max := size_char(fnam.str);
  lnam.max := size_char(lnam.str);
  film.max := size_char(film.str);
  opt.max := size_char(opt.str);
  parm.max := size_char(parm.str);
  fn1.max := size_char(fn1.str);
  fn2.max := size_char(fn2.str);
  s.max := size_char(s.str);
  tk.max := size_char(tk.str);
  imgsuff.max := size_char(imgsuff.str);
  dir.max := size_char(dir.str);
  nprev.max := size_char(nprev.str);
  ncurr.max := size_char(ncurr.str);
  nnext.max := size_char(nnext.str);
{
*   Initialize before reading the command line.
}
  string_cmline_init;                  {init for reading the command line}
  dir.len := 0;                        {init to film directory name not specified}
  wpdoc := true;                       {init to write PDOC output file}
{
*   Back here each new command line option.
}
next_opt:
  string_cmline_token (opt, stat);     {get next command line option name}
  if string_eos(stat) then goto done_opts; {exhausted command line ?}
  sys_error_abort (stat, 'string', 'cmline_opt_err', nil, 0);
  if (opt.len >= 1) and (opt.str[1] <> '-') then begin {implicit pathname token ?}
    if dir.len = 0 then begin          {film directory not set yet ?}
      string_treename(opt, dir);       {set film directory name}
      goto next_opt;
      end;
    sys_msg_parm_vstr (msg_parm[1], opt);
    sys_message_bomb ('string', 'cmline_opt_conflict', msg_parm, 1);
    end;
  string_upcase (opt);                 {make upper case for matching list}
  string_tkpick80 (opt,                {pick command line option name from list}
    '-DIR -NU',
    pick);                             {number of keyword picked from list}
  case pick of                         {do routine for specific option}
{
*   -DIR filename
}
1: begin
  if dir.len > 0 then begin            {film directory name already set ?}
    sys_msg_parm_vstr (msg_parm[1], opt);
    sys_message_bomb ('string', 'cmline_opt_conflict', msg_parm, 1);
    end;
  string_cmline_token (opt, stat);
  string_treename (opt, dir);
  end;
{
*   -NU
}
2: begin
  wpdoc := false;                      {inhibit writing PDOC output file}
  end;
{
*   Unrecognized command line option.
}
otherwise
    string_cmline_opt_bad;             {unrecognized command line option}
    end;                               {end of command line option case statement}

err_parm:                              {jump here on error with parameter}
  string_cmline_parm_check (stat, opt); {check for bad command line option parameter}
  goto next_opt;                       {back for next command line option}

parm_bad:                              {jump here on got illegal parameter}
  string_cmline_reuse;                 {re-read last command line token next time}
  string_cmline_token (parm, stat);    {re-read the token for the bad parameter}
  sys_msg_parm_vstr (msg_parm[1], parm);
  sys_msg_parm_vstr (msg_parm[2], opt);
  sys_message_bomb ('string', 'cmline_parm_bad', msg_parm, 2);

done_opts:                             {done with all the command line options}
  if dir.len > 0 then begin            {specific directory name was given ?}
    file_currdir_set (dir, stat);      {go to that directory}
    sys_error_abort (stat, '', '', nil, 0);
    end;

  util_mem_context_get (util_top_mem_context, mem_p); {make our own memory context}

  file_currdir_get (dnam, stat);       {get current directory name}
  sys_error_abort (stat, '', '', nil, 0);
  string_pathname_split (dnam, tnam, name); {get film directory leaf name in NAME}
  string_upcase (name);
  string_copy (name, film);            {set default film name}
{
*   Read the PDOC file for this film.
}
  pdoc_init (mem_p^, pdoc);            {init pictures list descriptor}

  string_copy (name, tnam);            {init PDOC file name to assumed generic name}
  string_downcase (tnam);
  pdoc_in_open_fnam (tnam, mem_p^, in, stat); {open PDOC file for input}
  if file_not_found(stat) then begin   {PDOC file doesn't exist ?}
    goto done_pdoc_read;
    end;
  sys_error_abort (stat, '', '', nil, 0);
  string_copy (in.file_p^.conn.tnam, tnam); {save full pathname of the PDOC file}

  pdoc_read (in, pdoc, stat);          {read PDOC file, make pictures list}
  sys_error_abort (stat, '', '', nil, 0);
  pdoc_in_close (in);                  {close PDOC file}

done_pdoc_read:                        {skip to here on PDOC file not found}
{
*   Open the PDOC file for writing.  It will be overwritten with the actual
*   values used.  These may differ from those in the PDOC file when those values
*   were defaulted and actual values taken from other places, like data in the
*   image files.  There may also not be a PDOC file at all when this program is
*   run.
*
*   TNAM is the name of the PDOC file.
}
  if wpdoc then begin
    pdoc_out_open_fnam (tnam, pout, stat); {open the PDOC file for writing}
    sys_error_abort (stat, '', '', nil, 0);
    end;
{
*   Make list of image file suffixes with the leading dots in IMGSUFF.
}
  img_list_types ([file_rw_read_k], s); {get raw image type names in S}
  p := 1;                              {init parse index into image types list}
  imgsuff.len := 0;                    {init list of suffixes with leading dots}
loop_imgtypes:                         {back here each new image file type}
  string_token (s, p, tk, stat);       {parse next image file type from list into TK}
  if sys_error(stat) then goto done_imgtypes; {end of image types list ?}
  if imgsuff.len > 0 then begin        {this is not first suffix in list ?}
    string_append1 (imgsuff, ' ');
    end;
  string_append1 (imgsuff, '.');       {add leading dot of file name suffix}
  string_append (imgsuff, tk);         {add suffix name after the dot}
  goto loop_imgtypes;                  {back to get next image type from list}
done_imgtypes:                         {done getting all the image file types}
  string_fill (imgsuff);               {fill unused string space with blanks}
{
*   Make a list of all image files in the ORIG directory, in alphabetical order.
*   The string list ORIGS will contain the full leafname of all the image files.
}
  file_open_read_dir (                 {open originals directory for reading}
    string_v('orig'),                  {directory name}
    conn,                              {returned I/O connection}
    stat);
  if file_not_found(stat) then begin
    sys_message_bomb ('pdoc', 'no_orig_dir', nil, 0);
    end;
  sys_error_abort (stat, '', '', nil, 0);

  string_list_init (origs, mem_p^);    {create list for original image file names}

loop_readorig:                         {back here to read each originals dir entry}
  file_read_dir (                      {read next directory entry}
    conn,                              {I/O connection}
    [],                                {list of information needed about dir entry}
    tnam,                              {returned directory entry name}
    info,                              {returned info about this entry}
    stat);
  if file_eof(stat) then goto done_readorig; {hit end of directory ?}
  sys_error_abort (stat, '', '', nil, 0);

  string_fnam_unextend (tnam, imgsuff.str, fnam); {try remove image file type suffix}
  if fnam.len = tnam.len then goto loop_readorig; {this is not an image file ?}
  if fnam.len < 1 then goto loop_readorig; {file name too short ?}
  {
  *   Make sure this is not a duplicate image.
  }
  string_copy (fnam, fn1);             {make upper case generic file name}
  string_upcase (fn1);

  string_list_pos_abs (origs, 1);      {go to first entry in existing list}
  while origs.str_p <> nil do begin    {loop over each existing file}
    string_fnam_unextend (origs.str_p^, imgsuff.str, fn2); {generic list entry name}
    string_upcase (fn2);               {upper case for comparison}
    if string_equal (fn1, fn2) then begin {found duplicate ?}
      sys_msg_parm_vstr (msg_parm[1], fn1);
      sys_message_bomb ('pdoc', 'img_duplicate', msg_parm, 1);
      end;
    string_list_pos_rel (origs, 1);    {advance to next existing list entry}
    end;
  {
  *   Add the full leafname of this image file in the ORIG directory to the
  *   ORIGS list.  The full leafname is in TNAM.
  }
  string_list_pos_last (origs);        {go to where can add new line to end of list}
  origs.size := tnam.len;              {create new list entry}
  string_list_line_add (origs);
  string_copy (tnam, origs.str_p^);    {copy file name into list entry}
  goto loop_readorig;                  {back to read next originals directory entry}

done_readorig:                         {done reading ORIG directory entries}
  file_close (conn);                   {close I/O connection to directory}
  if origs.n <= 0 then begin
    sys_message_bomb ('pdoc', 'no_orig_images', nil, 0);
    end;

  string_list_sort (                   {sort the list of original images}
    origs,                             {list to sort}
    [ string_comp_ncase_k,             {case-insensitive}
      string_comp_num_k]);             {sort numeric fields numerically}
{
*   Make a list of all files in the DERIV directory, in alphabetical order.
*   The generic image files in the DERIV directory will be left in the
*   DERIV images list.
}
  string_list_init (deriv, mem_p^);    {init list of derived image file gnames}
  deriv.deallocable := false;          {won't individually deallocate list entries}

  file_open_read_dir (                 {open derived images directory for reading}
    string_v('deriv'),                 {directory name}
    conn,                              {returned I/O connection}
    stat);
  if file_not_found(stat) then goto done_makederiv; {no derived images directory ?}
  sys_error_abort (stat, '', '', nil, 0);

loop_readderiv:                        {back here to read each directory entry}
  file_read_dir (                      {read next directory entry}
    conn,                              {I/O connection}
    [],                                {list of information needed about dir entry}
    tnam,                              {returned directory entry name}
    info,                              {returned info about this entry}
    stat);
  if file_eof(stat) then goto done_readderiv; {hit end of directory ?}
  sys_error_abort (stat, '', '', nil, 0);

  string_fnam_unextend (tnam, imgsuff.str, fnam); {try remove image file type suffix}
  if string_equal(fnam, tnam) then goto loop_readderiv; {this is not an image file ?}
  if fnam.len < 1 then goto loop_readderiv; {file name too short ?}

  deriv.size := fnam.len;              {create new list entry}
  string_list_line_add (deriv);
  string_copy (fnam, deriv.str_p^);    {copy generic file name into list entry}
  goto loop_readderiv;                 {back to read next originals directory entry}
done_readderiv:                        {done reading originals directory entries}
  file_close (conn);                   {close I/O connection to directory}
  string_list_sort (                   {sort the list of original images}
    deriv,                             {list to sort}
    [string_comp_ncase_k]);            {ignore character case in collating sequence}
done_makederiv:                        {done making DERIV string list}
{
*   Make sure the other directories exist.
}
  file_create_dir (string_v('1024'), [file_crea_keep_k], stat);
  file_create_dir (string_v('600'), [file_crea_keep_k], stat);
  file_create_dir (string_v('200'), [file_crea_keep_k], stat);
  file_create_dir (string_v('66'), [file_crea_keep_k], stat);
  file_create_dir (string_v('html'), [file_crea_keep_k], stat);
  sys_error_none (stat);
{
*   Write initial preamble to the INDEX.HTM file for this film directory.
}
  htm_open_write_name (hout_ind, string_v('index'), stat); {open HTML file for the film}
  sys_error_abort (stat, '', '', nil, 0);

  htm_write_str (hout_ind, '<html>'(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_newline (hout_ind, stat);

  sys_error_abort (stat, '', '', nil, 0); {write HEAD section}
  htm_write_str (hout_ind, '<head><title>Film'(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_indent (hout_ind);
  htm_write_vstr (hout_ind, name, stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_nopad (hout_ind);
  htm_write_str (hout_ind, '</title></head>'(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_newline (hout_ind, stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_undent (hout_ind);

  htm_write_str (hout_ind, '<body bgcolor='(0), stat);
  if sys_error(stat) then return;
  htm_write_color_gray (hout_ind, phot_col_back, stat);
  if sys_error(stat) then return;
  htm_write_nopad (hout_ind);
  htm_write_str (hout_ind, '><font color='(0), stat);
  if sys_error(stat) then return;
  htm_write_color_gray (hout_ind, phot_col_text, stat);
  if sys_error(stat) then return;
  htm_write_nopad (hout_ind);
  htm_write_str (hout_ind, '>'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (hout_ind, stat);
  sys_error_abort (stat, '', '', nil, 0);

  htm_write_bline (hout_ind, stat);
  sys_error_abort (stat, '', '', nil, 0);

  htm_write_str (hout_ind, '<center><h1>Film'(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_indent (hout_ind);
  htm_write_vstr (hout_ind, name, stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_nopad (hout_ind);
  htm_write_str (hout_ind, '</h1></center>'(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_newline (hout_ind, stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_undent (hout_ind);

  if pdoc.pics_p <> nil then begin
    phot_whtm_lines (hout_ind, pdoc.pics_p^.ent_p^.filmdesc_p, stat); {write film description}
    sys_error_abort (stat, '', '', nil, 0);
    htm_write_newline (hout_ind, stat);
    sys_error_abort (stat, '', '', nil, 0);
    htm_write_line_str (hout_ind, '<p>', stat);
    sys_error_abort (stat, '', '', nil, 0);
    htm_write_newline (hout_ind, stat);
    sys_error_abort (stat, '', '', nil, 0);
    end;
{
*   Create WLIST, which is the list of pictures to write out in order.  This
*   will be the pictures from the PDOC file, then the remaining images without
*   PDOC entries in the ORIGS directory in alphabetical order.
}
  string_list_init (wlist, mem_p^);    {create list of images to write out}
  wlist.deallocable := false;          {will not individually deallocate list entries}

  pdpic_p := pdoc.pics_p;              {init to first picture in PDOC list}
  while pdpic_p <> nil do begin        {once for every PDOC entry in order}
    string_copy (pdpic_p^.ent_p^.name_p^, ncurr); {make copy of this picture name}
    string_upcase (ncurr);             {make upper case for name matching}
    string_list_pos_abs (origs, 1);    {go to first existing picture list name}
    while origs.str_p <> nil do begin  {scan ORIGS list looking for this picture}
      string_fnam_unextend (origs.str_p^, imgsuff.str, s); {get generic ORIGS name}
      string_upcase (s);               {make upper case for matching}
      if string_equal (s, ncurr) then begin {found ORIGS entry for current picture ?}
        wlist.size := origs.str_p^.len; {set size of new WLIST entry}
        string_list_line_add (wlist);  {create WLIST entry for this picture}
        string_copy (origs.str_p^, wlist.str_p^); {add full ORIG leafname to WLIST}
        string_list_line_del (origs, true); {delete this entry from the ORIGS list}
        exit;                          {done with ORIGS entry for this picture}
        end;
      string_list_pos_rel (origs, 1);  {advance to next ORIGS list entry}
      end;                             {back and check this new ORIGS list entry}
    pdpic_p := pdpic_p^.next_p;        {advance to next picture in PDOC list}
    end;                               {back to do next PDOC list entry}

  string_list_pos_abs (origs, 1);      {go to start of remaining pictures in ORIGS list}
  while origs.str_p <> nil do begin    {scan remaining pictures not in PDOC list}
    wlist.size := origs.str_p^.len;    {copy this ORIGS entry WLIST}
    string_list_line_add (wlist);
    string_copy (origs.str_p^, wlist.str_p^);
    string_list_pos_rel (origs, 1);    {advance to next ORIGS list entry}
    end;

  string_list_kill (origs);            {all done with the raw picture files list}
{
********************
*
*   Scan all the person definitions that were actually referenced.  Assign them
*   unique IDs and create the specific page for each person as appropriate.
}
  nextid := 1;                         {init number of next ID to assign}
  assign_people_ids (pdoc.people_p);   {assign IDs to all referenced people}

  perent_p := pdoc.people_p;           {init to first person in list}
  while perent_p <> nil do begin       {loop thru the list of people}
    if perent_p^.ent_p^.ref then begin {this person was reference ?}
      phot_htm_pers_write (perent_p^.ent_p^, stat); {write page for this person}
      sys_error_abort (stat, '', '', nil, 0);
      end;
    perent_p := perent_p^.next_p;      {advance to next person in the list}
    end;
{
********************
*
*   Loop thru all the pictures in the WLIST list.  For each picture, an entry
*   is written to the film HTML file, and a separate picture HTML file is
*   created in the HTML directory.  The WLIST entries are the full leafnames of
*   the source images in the ORIG directory.
}
  sys_msg_parm_int (msg_parm[1], wlist.n); {show number of pictures to process}
  sys_message_parms ('pdoc', 'npic_proc', msg_parm, 1);

  string_list_pos_abs (wlist, 1);      {position to first list entry}
  if wlist.str_p = nil then goto done_pics; {no pictures to process at all ?}
  pic_p := nil;                        {init to no current picture}
  get_pic (wlist.str_p^, pic_p, pic_next_p); {get pointer to descriptor for this picture}

loop_pics:                             {back here for each new picture in the list}
  pic_prev_p := pic_p;                 {old current picture becomes previous}
  pic_p := pic_next_p;                 {old next picture becomes current}
  if pic_p = nil then goto done_pics;  {all done with the list of pictures ?}

  string_copy (wlist.str_p^, lnam);    {save full leafname of source image in ORIG dir}
  string_list_pos_rel (wlist, 1);      {advance to the next entry in the list}
  pic_next_p := nil;                   {init to there is no next picture}
  if wlist.str_p <> nil then begin     {there is a next picture ?}
    get_pic (wlist.str_p^, pic_p, pic_next_p); {get pointer to descriptor for the next picture}
    end;
{
*   PIC_P is pointing to the PDOC descriptor for this image.  PIC_PREV_P and
*   PIC_NEXT_P are pointing to the PDOC descriptors for the previous and next
*   pictures in the sequence.  PIC_PREV_P and PIC_NEXT_P may be NIL.  LNAM is
*   the full leafname of the current source image in the ORIG directory.
}
  sys_msg_parm_vstr (msg_parm[1], pic_p^.name_p^); {show name of this picture}
  sys_message_parms ('pdoc', 'pic_proc', msg_parm, 1);

  if wpdoc then begin
    pdoc_write_pic (                   {write PDOC file entry for this picture}
      pout,                            {PDOC file writing state}
      pdoc.pics_p,                     {pointer to the whole list of pictures}
      pic_p^,                          {descriptor for the picture to write info for}
      pic_prev_p,                      {pointer to descriptor for previous picture, if any}
      stat);
    sys_msg_parm_vstr (msg_parm[1], pic_p^.name_p^);
    sys_error_abort (stat, 'pdoc', 'write_pdoc_img', msg_parm, 1);
    end;
{
*   Write entry to film HTML file.
}
  sys_msg_parm_vstr (msg_parm[1], hout_ind.conn.tnam);

  htm_write_str (hout_ind, '<a href='(0), stat);
  sys_error_abort (stat, 'pdoc', 'write_htm', msg_parm, 1);
  htm_write_indent (hout_ind);
  htm_write_nopad (hout_ind);
  s.len := 0;
  string_appends (s, 'html/'(0));
  string_append (s, pic_p^.name_p^);
  string_appends (s, '.htm'(0));
  htm_write_vstr (hout_ind, s, stat);
  sys_error_abort (stat, 'pdoc', 'write_htm', msg_parm, 1);
  htm_write_nopad (hout_ind);
  htm_write_str (hout_ind, '><img src='(0), stat);
  sys_error_abort (stat, 'pdoc', 'write_htm', msg_parm, 1);
  htm_write_nopad (hout_ind);
  s.len := 0;
  string_appends (s, '200/'(0));
  string_append (s, pic_p^.name_p^);
  string_appends (s, '.jpg'(0));
  htm_write_vstr (hout_ind, s, stat);
  sys_error_abort (stat, 'pdoc', 'write_htm', msg_parm, 1);
  htm_write_str (hout_ind, 'border=0 vspace=5 align=top></a>'(0), stat);
  sys_error_abort (stat, 'pdoc', 'write_htm', msg_parm, 1);
  htm_write_nopad (hout_ind);
  htm_write_vstr (hout_ind, pic_p^.name_p^, stat);
  sys_error_abort (stat, 'pdoc', 'write_htm', msg_parm, 1);
  htm_write_newline (hout_ind, stat);
  sys_error_abort (stat, 'pdoc', 'write_htm', msg_parm, 1);
  htm_write_undent (hout_ind);
{
*   Make sure the various size filtered vesions of the original exist.
*   These are created if needed.
}
  string_vstring (tnam, 'orig/'(0), -1); {build source image name}
  string_append (tnam, lnam);
  file_info (                          {get information about the source image}
    tnam,                              {file name asking about}
    [file_iflag_dtm_k],                {get date/time of last modification}
    info,                              {returned info about the file}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  t1 := info.modified;                 {save time of ORIG image in T1}
  {
  *   TNAM is name of the ORIG image file (with suffix), and T1 is the time it
  *   was last modified.
  }
  make := true;                        {init to make all downsized images}

  string_vstring (fnam, '1024/'(0), -1); {make 1024 size file name}
  string_append (fnam, pic_p^.name_p^);
  string_appends (fnam, '.jpg'(0));
  file_info (                          {get info on the 1024 file}
    fnam,                              {name of file asking about}
    [file_iflag_dtm_k],                {get date/time of last modification}
    info,                              {returned info about the file}
    stat);
  if not sys_error(stat) then begin    {file exists and got requested info ?}
    make := not                        {1024 image not later than ORIG image ?}
      (sys_clock_compare(info.modified, t1) = sys_compare_gt_k);
    end;
  sys_error_none (stat);

  if make then begin                   {need to make 1024 sized version ?}
    writeln ('Creating image file ', fnam.str:fnam.len);
    string_vstring (s, 'image_resize -in '(0), -1);
    string_append_token (s, tnam);
    string_appends (s, ' -out '(0));
    string_append_token (s, fnam);
    string_appends (s, ' -fit 1024 1024 -form "-qual 100"'(0));
    sys_run_wait_stdsame (             {run program to create this image file}
      s, tf, exstat, stat);
    sys_error_abort (stat, '', '', nil, 0);
    end;

  string_vstring (fnam, '600/'(0), -1); {make 600 size file name}
  string_append (fnam, pic_p^.name_p^);
  string_appends (fnam, '.jpg'(0));
  if make or not file_exists (fnam) then begin {need to make this size ?}
    writeln ('Creating image file ', fnam.str:fnam.len);
    string_vstring (s, 'image_resize -in '(0), -1);
    string_append_token (s, tnam);
    string_appends (s, ' -out '(0));
    string_append_token (s, fnam);
    string_appends (s, ' -fit 600 600 -form "-qual 100"'(0));
    sys_run_wait_stdsame (             {run program to create this image file}
      s, tf, exstat, stat);
    sys_error_abort (stat, '', '', nil, 0);
    end;

  string_vstring (name, '1024/'(0), -1); {make source image name from now on}
  string_append (name, pic_p^.name_p^);

  string_vstring (fnam, '200/'(0), -1); {make 200 size file name}
  string_append (fnam, pic_p^.name_p^);
  string_appends (fnam, '.jpg'(0));
  if make or not file_exists (fnam) then begin {need to make this size ?}
    writeln ('Creating image file ', fnam.str:fnam.len);
    string_vstring (s, 'image_resize -in '(0), -1);
    string_append_token (s, name);
    string_appends (s, ' -out '(0));
    string_append_token (s, fnam);
    string_appends (s, ' -fit 200 200 -form "-qual 100"'(0));
    sys_run_wait_stdsame (             {run program to create this image file}
      s, tf, exstat, stat);
    sys_error_abort (stat, '', '', nil, 0);
    end;

  string_vstring (fnam, '66/'(0), -1); {make 66 size file name}
  string_append (fnam, pic_p^.name_p^);
  string_appends (fnam, '.jpg'(0));
  if make or not file_exists (fnam) then begin {need to make this size ?}
    writeln ('Creating image file ', fnam.str:fnam.len);
    string_vstring (s, 'image_resize -in '(0), -1);
    string_append_token (s, name);
    string_appends (s, ' -out '(0));
    string_append_token (s, fnam);
    string_appends (s, ' -fit 66 66 -form "-qual 100"'(0));
    sys_run_wait_stdsame (             {run program to create this image file}
      s, tf, exstat, stat);
    sys_error_abort (stat, '', '', nil, 0);
    end;
{
*   Make sure the various size filtered versions of any derivatives of this picture
*   exist.  They are created if not already existing.
}
  deriv_p := pic_p^.deriv_p;           {init to first derived image in the list}
  while deriv_p <> nil do begin        {once for each image derived from this main image}
    make := true;                      {init to make all downsized versions}

    string_vstring (name, 'deriv/'(0), -1); {make source image filename}
    string_append (name, deriv_p^.str_p^);
    string_appends (name, '.jpg'(0));
    file_info (                        {get info on this DERIV image}
      name,                            {name of file asking about}
      [file_iflag_dtm_k],              {get date/time of last modification}
      info,                            {returned info about the file}
      stat);
    sys_error_abort (stat, '', '', nil, 0);
    t1 := info.modified;               {save time of DERIV source image}

    string_vstring (fnam, '1024/'(0), -1); {make 1024 size image name}
    string_append (fnam, deriv_p^.str_p^);
    string_appends (fnam, '.jpg'(0));
    file_info (                        {get info on the 1024 file}
      fnam,                            {name of file asking about}
      [file_iflag_dtm_k],              {get date/time of last modification}
      info,                            {returned info about the file}
      stat);
    if not sys_error(stat) then begin  {file exists and got requested info ?}
      make := not                      {1024 image not later than DERIV image ?}
        (sys_clock_compare(info.modified, t1) = sys_compare_gt_k);
      end;
    sys_error_none (stat);

    string_vstring (name, 'deriv/'(0), -1); {make source image filename}
    string_append (name, deriv_p^.str_p^);

    if make then begin                 {make 1024 sized version ?}
      writeln ('Creating image file ', fnam.str:fnam.len);
      string_vstring (s, 'image_resize -in '(0), -1);
      string_append_token (s, name);
      string_appends (s, ' -out '(0));
      string_append_token (s, fnam);
      string_appends (s, ' -fit 1024 1024 -form "-qual 100"'(0));
      sys_run_wait_stdsame (           {run program to create this image file}
        s, tf, exstat, stat);
      sys_error_abort (stat, '', '', nil, 0);
      end;

    string_vstring (fnam, '600/'(0), -1); {make 600 size image file name}
    string_append (fnam, deriv_p^.str_p^);
    string_appends (fnam, '.jpg'(0));
    if make or else not file_exists(fnam) then begin {make 600 sized version ?}
      writeln ('Creating image file ', fnam.str:fnam.len);
      string_vstring (s, 'image_resize -in '(0), -1);
      string_append_token (s, name);
      string_appends (s, ' -out '(0));
      string_append_token (s, fnam);
      string_appends (s, ' -fit 600 600'(0));
      sys_run_wait_stdsame (           {run program to create this image file}
        s, tf, exstat, stat);
      sys_error_abort (stat, '', '', nil, 0);
      end;

    string_vstring (name, '1024/'(0), -1); {source for subsequent low res copies}
    string_append (name, deriv_p^.str_p^);

    string_vstring (fnam, '200/'(0), -1); {make 200 size image file name}
    string_append (fnam, deriv_p^.str_p^);
    string_appends (fnam, '.jpg'(0));
    if make or else not file_exists(fnam) then begin {make 200 sized version ?}
      writeln ('Creating image file ', fnam.str:fnam.len);
      string_vstring (s, 'image_resize -in '(0), -1);
      string_append_token (s, name);
      string_appends (s, ' -out '(0));
      string_append_token (s, fnam);
      string_appends (s, ' -fit 200 200 -form "-qual 100"'(0));
      sys_run_wait_stdsame (           {run program to create this image file}
        s, tf, exstat, stat);
      sys_error_abort (stat, '', '', nil, 0);
      end;

    string_vstring (fnam, '66/'(0), -1); {make 66 size image file name}
    string_append (fnam, deriv_p^.str_p^);
    string_appends (fnam, '.jpg'(0));
    if make or else not file_exists(fnam) then begin {make 66 sized version ?}
      writeln ('Creating image file ', fnam.str:fnam.len);
      string_vstring (s, 'image_resize -in '(0), -1);
      string_append_token (s, name);
      string_appends (s, ' -out '(0));
      string_append_token (s, fnam);
      string_appends (s, ' -fit 66 66 -form "-qual 100"'(0));
      sys_run_wait_stdsame (           {run program to create this image file}
        s, tf, exstat, stat);
      sys_error_abort (stat, '', '', nil, 0);
      end;

    deriv_p := deriv_p^.next_p;        {advance to next derived image for this main image}
    end;                               {back to process this new derived image}
{
*   Create the HTML file specific to this picture.
}
  string_vstring (fnam, 'html/'(0), -1); {make picture HTML file name}
  string_append (fnam, pic_p^.name_p^);
  htm_open_write_name (hout_pic, fnam, stat); {open the picture HTML output file}
  sys_error_abort (stat, '', '', nil, 0);

  if pic_p = nil then begin            {no picture description available ?}
    goto done_picw;                    {done writing HTML file for this picture}
    end;

  nprev.len := 0;                      {make name of previous picture to link to}
  if (pic_prev_p <> nil) and then (pic_prev_p^.name_p <> nil) then begin
    string_copy (pic_prev_p^.name_p^, nprev);
    end;
  nnext.len := 0;                      {make name of next picture to link to}
  if (pic_next_p <> nil) and then (pic_next_p^.name_p <> nil) then begin
    string_copy (pic_next_p^.name_p^, nnext);
    end;

  phot_htm_pic_write (                 {write the picture HTML file contents}
    hout_pic,                          {handle to HTML output connection}
    pic_p^,                            {picture descriptor}
    nprev, nnext,                      {names of previous and next pictures to link to}
    [],                                {modifier flags}
    stat);
  sys_msg_parm_vstr (msg_parm[1], hout_pic.conn.tnam);
  sys_error_abort (stat, 'pdoc', 'write_htm', msg_parm, 1);

done_picw:                             {done writing HTML file for the picture}
  htm_close_write (hout_pic, stat);    {close HTML file specific to this picture}
  sys_error_abort (stat, 'pdoc', 'write_htm_close', msg_parm, 1);
  goto loop_pics;                      {done with this picture, on to next}
{
*   Done running thru the list of pictures.
}
done_pics:                             {done with the list of pictures in WLIST}
{
*   Clean up and close the various files.
}
  if wpdoc then begin
    pdoc_out_close (pout, stat);       {close the PDOC file begin written}
    sys_error_abort (stat, '', '', nil, 0);
    end;

  htm_write_bline (hout_ind, stat);    {leave blank line after pictures info}
  htm_write_str (hout_ind, '</body></html>'(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_close_write (hout_ind, stat);    {close HTML file for the whole film}
  sys_error_abort (stat, '', '', nil, 0);

  util_mem_context_del (mem_p);        {deallocate all our dynamic memory}
  end.
