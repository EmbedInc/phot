{   Program PHOT_EXPORT ilist
*
*   Export list of pictures from /IMG directory into the local RELEASE directory.
}
program phot_export;
%include 'base.ins.pas';
%include 'img.ins.pas';
%include 'stuff.ins.pas';
%include 'pdoc.ins.pas';
%include 'phot.ins.pas';

const
  reldir = 'release';                  {name of output directory to create}
  max_msg_args = 2;                    {max arguments we can pass to a message}

var
  fnam:                                {scratch file name}
    %include '(cog)lib/string_treename.ins.pas';
  nprev, name, nnext:                  {names of next, curr, and previous images}
    %include '(cog)lib/string_leafname.ins.pas';
  film:                                {film name, upper case}
    %include '(cog)lib/string80.ins.pas';
  lfilm:                               {film name, original case}
    %include '(cog)lib/string80.ins.pas';
  frame:                               {frame name within film of current image}
    %include '(cog)lib/string80.ins.pas';
  suffrd:                              {list of readable image file name suffixes}
    %include '(cog)lib/string80.ins.pas';
  conn: file_conn_t;                   {connection to pictures list input file}
  ilist: string_list_t;                {list of image names from input file}
  p: string_index_t;                   {string parse index}
  hind: htm_out_t;                     {state for writing to top level index HTML file}
  hout: htm_out_t;                     {state for writing HTML file for current image}
  pdoc_in: pdoc_in_t;                  {state for reading a PDOC file}
  pdoc: pdoc_t;                        {info from a PDOC file}
  pic_p: pdoc_pic_p_t;                 {points to info about current image}
  mem_p: util_mem_context_p_t;         {pointer to memory context for current image}
  dr_p: pdoc_strent_p_t;               {pointer to current derivatives list entry}
  pent_p: pdoc_perent_p_t;             {pointer to current persons list entry}
  pers_p: pdoc_person_p_t;             {pointer to current person descriptor}
  perslist: pdoc_perslist_t;           {list of all people referenced}
  wflags: phot_htmpic_t;               {flags to modify writing of picture HTML file}
  orig: boolean;                       {create output ORIG directory}
  s:                                   {scratch long string}
    %include '(cog)lib/string8192.ins.pas';

  opt:                                 {upcased command line option}
    %include '(cog)lib/string_treename.ins.pas';
  parm:                                {command line option parameter}
    %include '(cog)lib/string_treename.ins.pas';
  pick: sys_int_machine_t;             {number of token picked from list}
  msg_parm:                            {references arguments passed to a message}
    array[1..max_msg_args] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status}

label
  next_opt, err_parm, parm_bad, done_opts,
  found_dash;
{
********************************************************************************
*
*   Subroutine GET_JPG (SUBDIR, GNAM, STAT)
*
*   Get the image GNAM from the SUBDIR subdirectory in the current film source
*   directory into the release being built.  The current source film name is
*   indicated by the global variables FILM and LFILM.  SUBDIR is the name of one
*   of the standard subdirectories within a film directory, like "1024", "orig",
*   etc.  The generic pathname of the source image is therefore
*   /img/<lfilm>/<subdir>/<gnam>.
*
*   The image will be written into SUBDIR within the current directory.  The
*   destination image will always be JPEG format.  The pathname of the
*   destination image is therefore <subdir>/<lfilm>-<gnam>.jpg.
*
*   If the source image is already in JPEG format, the file will be copied
*   directly.  If not, the source image is converterd to JPEG format and the
*   destination will be a newly created file.
}
procedure get_jpg (                    {get image from /img, convert to JPG if needed}
  in      subdir: string;              {source subdirectory within film directory}
  in      gnam: univ string_var_arg_t; {generic image name}
  out     stat: sys_err_t);            {completion status}
  val_param; internal;

var
  f: string_var8192_t;                 {scratch filename and command line string}
  f1, f2: string_treename_t;           {source and destination file names}
  suff: string_var32_t;                {source image file name suffix}
  p: string_index_t;                   {SUFFRD string parse index}
  tf: boolean;                         {True/False program exit status}
  exstat: sys_sys_exstat_t;            {program exit status}

begin
  f1.max := size_char(f1.str);         {init local var strings}
  f2.max := size_char(f2.str);
  f.max := size_char(f.str);
  suff.max := size_char(suff.str);

  string_vstring (f1, '/img/'(0), -1); {make source directory treename in F}
  string_append (f1, lfilm);
  string_append1 (f1, '/');
  string_appends (f1, subdir);
  string_append1 (f1, '/');
  string_append (f1, gnam);
  string_downcase (f1);
  string_treename (f1, f);
{
*   Find the specific image source file within the source directory.  F is the
*   full treename of the source directory.  SUFFRD contains the list of possible
*   file name suffixes for the image file types that are supported for reading.
*   Each suffix is a separate token in SUFFRD, separated from the others by a
*   space.  These suffixes do not include the "." between the name file name and
*   the suffix.
*
*   This section will return with error if no suitable image file is found at
*   all.  Otherwise, it will set F1 to the complete pathname of the source image
*   and SUFF to the source image file type suffix without the preceeding ".".
}
  string_append1 (f, '.');             {make source pathnam right up to suffix}
  string_copy (f, f1);                 {init fixed part of each source pathname}
  p := 1;                              {init SUFFRD parse index}
  while true do begin                  {back here each new suffix to try}
    f1.len := f.len;                   {init to just fixed part of pathname}
    string_token (suffrd, p, suff, stat); {get next possible suffix}
    if sys_error(stat) then begin
      sys_stat_set (file_subsys_k, file_stat_not_found_k, stat);
      sys_stat_parm_vstr (f1, stat);
      sys_stat_parm_vstr (suffrd, stat);
      return;                          {no such source image}
      end;
    string_append (f1, suff);          {make full source image pathname}
    if file_exists (f1) then exit;
    end;
{
*   F1 contains the full source image pathname, and SUFF its image file name
*   suffix.
*
*   If the source file is of type JPEG (suffix "jpg"), then copy the file
*   directly.  If it is any other image file type, copy the image data while
*   converting to a JPEG file.
}
  string_vstring (f, './'(0), -1);     {build destination file name in F2}
  string_appends (f, subdir);
  string_append1 (f, '/');
  string_append (f, lfilm);
  string_append1 (f, '-');
  string_append (f, gnam);
  string_appends (f, '.jpg'(0));
  string_treename (f, f2);

  string_upcase (suff);                {make upper case suffix for string matching}
  if string_equal(suff, string_v('JPG'(0))) then begin {source is JPEG file ?}
    file_copy (                        {copy the image file directly}
      f1,                              {source file name}
      f2,                              {destination file name}
      [file_copy_replace_k],           {allow copying over existing file}
      stat);
    return;
    end;
{
*   The source image is not a JPEG file.  Copy the image data into the
*   destination file.
}
  string_vstring (f, 'image_copy'(0), -1); {build the command line to run}
  string_append_token (f, f1);
  string_append_token (f, f2);
  string_appends (f, ' -form "-qual 100"'(0));
  sys_run_wait_stdsame (               {run the copy command}
    f,                                 {command line to run}
    tf,                                {true/false program exit status}
    exstat,                            {full exit status}
    stat);
  end;
{
********************************************************************************
*
*   Start of main routine.
}
begin
{
*   Initialize before reading the command line.
}
  string_cmline_init;                  {init for reading the command line}
  orig := true;
  wflags := [];                        {set options for writing picture HTML files}
  wflags := wflags + [phot_htmpic_pref_k]; {start picture fnams with film name}
  wflags := wflags - [phot_htmpic_npeople_k]; {write list of people in each picture}
  wflags := wflags + [phot_htmpic_nstored_k]; {don't show where each picure is stored}
  wflags := wflags + [phot_htmpic_nexp_k]; {don't write exposure information}
  wflags := wflags - [phot_htmpic_n1024_k]; {create separate HTML file for 1024 size}
  wflags := wflags + [phot_htmpic_index_k]; {link up to "index" instead of "film"}
  wflags := wflags + [phot_htmpic_noby_k]; {don't write "Created by" information}
{
*   Back here each new command line option.
}
next_opt:
  string_cmline_token (opt, stat);     {get next command line option name}
  if string_eos(stat) then goto done_opts; {exhausted command line ?}
  sys_error_abort (stat, 'string', 'cmline_opt_err', nil, 0);
  if (opt.len >= 1) and (opt.str[1] <> '-') then begin {implicit pathname token ?}
    string_treename(opt, fnam);        {set input file name}
    goto next_opt;
    end;
  string_upcase (opt);                 {make upper case for matching list}
  string_tkpick80 (opt,                {pick command line option name from list}
    '-NORIG',
    pick);                             {number of keyword picked from list}
  case pick of                         {do routine for specific option}
{
*   -NORIG -BY
}
1: begin
  orig := false;
  end;
{
*   -BY
}
2: begin
  wflags := wflags - [phot_htmpic_noby_k]; {allow "Created by" to be written}
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
  if fnam.len <= 0 then begin          {no images list file name supplied}
    sys_message_bomb ('phot', 'imglist_nsuppl', nil, 0);
    end;

  img_list_types (                     {get list of readable image file types}
    [file_rw_read_k], suffrd);
{
*   Read the list of images into ILIST.
}
  file_open_read_text (fnam, '.txt ""', conn, stat); {open the list input file}
  sys_error_abort (stat, 'file', 'open_input_read_text', msg_parm, 1);

  string_list_init (ilist, util_top_mem_context); {init the images list}
  while true do begin                  {loop for each input file line}
    file_read_text (conn, s, stat);    {read next image name from list input file}
    if file_eof(stat) then exit;       {hit end of images list file ?}
    sys_error_abort (stat, '', '', nil, 0);
    string_unpad (s);                  {delete any trailing spaces}
    if s.len = 0 then next;            {ignore blank lines}
    p := 1;                            {init parse index}
    while s.str[p] = ' ' do p := p + 1; {skip over leading blanks}
    if s.str[p] = '*' then next;       {this is a comment line ?}
    string_token (s, p, parm, stat);   {extract this frame name into PARM}
    sys_error_abort (stat, '', '', nil, 0);
    string_unpad (parm);               {remove trailing spaces from frame name}
    if parm.len = 0 then next;         {ignore empty frame names}
    ilist.size := parm.len;            {set size of new list entry to create}
    string_list_line_add (ilist);      {create the new list entry}
    string_copy (parm, ilist.str_p^);  {save this image name in the string list}
    end;                               {back to get next name from list input file}
  file_close (conn);                   {close the list input file}
{
*   Create the required directory structure.
}
  string_vstring (fnam, reldir, sizeof(reldir)); {make release directory var string}
  file_delete_tree (fnam, [], stat);   {delete release directory if exists}
  file_create_dir (fnam, [], stat);    {create new empty release directory}
  sys_error_abort (stat, '', '', nil, 0);
  file_currdir_set (fnam, stat);       {go into the release directory}
  sys_error_abort (stat, '', '', nil, 0);

  file_create_dir (string_v('200'), [], stat); {create the subdirectories}
  sys_error_abort (stat, '', '', nil, 0);
  file_create_dir (string_v('600'), [], stat);
  sys_error_abort (stat, '', '', nil, 0);
  file_create_dir (string_v('1024'), [], stat);
  sys_error_abort (stat, '', '', nil, 0);
  file_create_dir (string_v('deriv'), [], stat);
  sys_error_abort (stat, '', '', nil, 0);
  if orig then begin
    file_create_dir (string_v('orig'), [], stat);
    sys_error_abort (stat, '', '', nil, 0);
    end;
  file_create_dir (string_v('html'), [], stat);
  sys_error_abort (stat, '', '', nil, 0);
{
*   Create and initialize the INDEX.HTM file in the top level directory.
}
  htm_open_write_name (hind, string_v('index.htm'), stat); {create top level index file}
  sys_error_abort (stat, '', '', nil, 0);

  htm_write_str (hind, '<html>'(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_newline (hind, stat);
  sys_error_abort (stat, '', '', nil, 0);

  htm_write_str (hind, '<head>'(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_indent (hind);
  htm_write_newline (hind, stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_str (hind, '</head>'(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_undent (hind);
  htm_write_newline (hind, stat);
  sys_error_abort (stat, '', '', nil, 0);

  htm_write_str (hind, '<body bgcolor='(0), stat);
  if sys_error(stat) then return;
  htm_write_color_gray (hind, phot_col_back, stat);
  if sys_error(stat) then return;
  htm_write_nopad (hind);
  htm_write_str (hind, '><font color='(0), stat);
  if sys_error(stat) then return;
  htm_write_color_gray (hind, phot_col_text, stat);
  if sys_error(stat) then return;
  htm_write_nopad (hind);
  htm_write_str (hind, '>'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (hind, stat);
  sys_error_abort (stat, '', '', nil, 0);
{
*   Loop thru each image in the list.
}
  pdoc_perslist_init (perslist, util_top_mem_context); {init referenced people list}
  name.len := 0;                       {init "current" image name to none}
  string_list_pos_abs (ilist, 1);      {init to first list entry}

  while ilist.str_p <> nil do begin    {once for each image in the list}
    string_copy (name, nprev);         {old current name becomes new previous}
    string_copy (ilist.str_p^, name);  {save current image name}
    writeln (name.str:name.len);
    string_list_pos_rel (ilist, 1);    {set list position to next image name}
    nnext.len := 0;                    {init to there is no next image}
    if ilist.str_p <> nil then begin   {there is a next image ?}
      string_copy (ilist.str_p^, nnext);
      end;

    util_mem_context_get (             {create private memory context for this image}
      util_top_mem_context, mem_p);
    pdoc_init (mem_p^, pdoc);          {init PDOC structure}
{
*   Determine the film and frame names of this image and save them in FILM,
*   LFILM, and FRAME.
}
  p := 2;                              {init parse index}
  while p < name.len do begin          {scan thru the composite image name string}
    if name.str[p] = '-' then goto found_dash; {found the dash separator ?}
    p := p + 1;
    end;
  writeln ('Unable to find film and frame names in ', name.str:name.len);
  sys_bomb;

found_dash:                            {p is index into NAME of "-" character}
  string_substr (name, 1, p-1, film);  {extract film name}
  string_substr (name, p+1, name.len, frame); {extract frame name within this film}
  string_copy (film, lfilm);
  string_upcase (film);
{
*   Get PIC_P pointing to whatever information is available about this frame.
}
  string_vstring (fnam, '/img/'(0), -1); {build PDOC file pathname for this film}
  string_append (fnam, lfilm);
  string_append1 (fnam, '/');
  string_append (fnam, lfilm);

  pdoc_in_open_fnam (fnam, mem_p^, pdoc_in, stat); {open PDOC file for reading}
  if not file_not_found(stat) then begin {other than PDOC file doesn't exist ?}
    sys_error_abort (stat, '', '', nil, 0); {abort on hard error}
    pdoc_read (pdoc_in, pdoc, stat);   {read the PDOC file}
    sys_error_abort (stat, '', '', nil, 0);
    pdoc_in_close (pdoc_in);           {close the file}
    end;

  string_vstring (fnam, '/img/'(0), -1); {build film directory name}
  string_append (fnam, lfilm);
  phot_frame_info (                    {get available info for this picture}
    fnam,                              {film directory name}
    frame,                             {name of frame within the film}
    pdoc.pics_p,                       {list of frames in this film}
    mem_p^,                            {context to allocate any new memory under}
    pic_p,                             {returned pointing to info about this frame}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
{
*   Add any people in this frame to the global people list.
}
  pent_p := pic_p^.people_p;           {init to first person reference by this frame}
  while pent_p <> nil do begin         {scan the list of referenced people}
    pdoc_perslist_add (perslist, pent_p^, stat); {add this person to global list}
    sys_error_abort (stat, '', '', nil, 0);
    pent_p := pent_p^.next_p;          {advance to next person in the list}
    end;
{
*   Write the index file entry for this image.
}
  htm_write_str (hind, '<a'(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_indent (hind);
  htm_write_str (hind, 'href='(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_nopad (hind);
  s.len := 0;
  string_appends (s, 'html/'(0));
  string_append (s, name);
  string_appends (s, '.htm'(0));
  htm_write_vstr (hind, s, stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_nopad (hind);
  htm_write_str (hind, '>'(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_nopad (hind);
  htm_write_str (hind, '<img src='(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_nopad (hind);
  s.len := 0;
  string_appends (s, '200/'(0));
  string_append (s, name);
  string_appends (s, '.jpg'(0));
  htm_write_vstr (hind, s, stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_str (hind, 'border=0 vspace=5 align=top></a>'(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_nopad (hind);
  htm_write_vstr (hind, name, stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_newline (hind, stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_undent (hind);
{
*   Copy the various versions of this image into the release directory.  The sizes
*   used are 200, 600, 1024, orig, and deriv.
}
  get_jpg ('200', frame, stat);
  sys_error_abort (stat, '', '', nil, 0);
  get_jpg ('600', frame, stat);
  sys_error_abort (stat, '', '', nil, 0);
  get_jpg ('1024', frame, stat);
  sys_error_abort (stat, '', '', nil, 0);
  if orig then begin
    get_jpg ('orig', frame, stat);
    sys_error_abort (stat, '', '', nil, 0);
    end;

  dr_p := pic_p^.deriv_p;              {init pointer to first derived image list entry}
  while dr_p <> nil do begin           {once for each derived image list entry}
    get_jpg ('deriv', dr_p^.str_p^, stat);
    sys_error_abort (stat, '', '', nil, 0);
    get_jpg ('1024', dr_p^.str_p^, stat);
    sys_error_abort (stat, '', '', nil, 0);
    get_jpg ('600', dr_p^.str_p^, stat);
    sys_error_abort (stat, '', '', nil, 0);
    dr_p := dr_p^.next_p;              {advance to next entry in derived images list}
    end;
{
*   Create the HTML file for this frame.
}
  string_vstring (fnam, 'html/'(0), -1); {build HTML file name for this image}
  string_append (fnam, lfilm);
  string_append1 (fnam, '-');
  string_append (fnam, frame);
  string_appends (fnam, '.htm'(0));
  htm_open_write_name (hout, fnam, stat); {open HTML output file for this image}

  phot_htm_pic_write (                 {write the HTML file for this image}
    hout,                              {low level HTML file writing state}
    pic_p^,                            {descriptor for the picture to write}
    nprev, nnext,                      {names of previous and next images to link to}
    wflags,                            {option flags}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  htm_close_write (hout, stat);
  sys_error_abort (stat, '', '', nil, 0);
{
*   Clean up handling this source image and advance to the next.
}
    pdoc_release (pdoc);               {release pictures list}
    util_mem_context_del (mem_p);      {delete private memory context for this image}
    end;                               {back to do next image in list}

  string_list_kill (ilist);            {delete the list of input images}
{
*   Finish the HTML index file.
}
  htm_write_str (hind, '</body>'(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_write_newline (hind, stat);
  sys_error_abort (stat, '', '', nil, 0);
  htm_close_write (hind, stat);
  sys_error_abort (stat, '', '', nil, 0);
{
*   Write the person HTML files.
}
  pent_p := perslist.first_p;          {init to first person in list}
  while pent_p <> nil do begin         {scan the list of referenced people}
    pers_p := pent_p^.ent_p;           {get pointer to this person descriptor}
    phot_htm_pers_write (pers_p^, stat);
    sys_error_abort (stat, '', '', nil, 0);
    pent_p := pent_p^.next_p;
    end;

  end.
