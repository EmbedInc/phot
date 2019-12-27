{   Subroutine PHOT_FRAME_INFO (FILMDIR, FRAME, PDOC_P, MEM, PIC_P)
*
*   Return all the available information about a frame within a film.  FILMDIR
*   is the pathname of the film directory.  FRAME is the name of the frame that
*   is being inquired about within the film.  PDOC_P points to the information
*   from the film PDOC file.  PDOC_P may be NIL to indicate no such information
*   is available.  MEM is a memory context to allocate any new dynamic memory
*   under, if needed.  PIC_P is returned pointing to information about the
*   frame.  PIC_P will point to the info about the frame in the PDOC information
*   if it exists there.  Otherwise a new structure is created and filled in
*   with the information that is known.  PIC_P is never returned NIL, but may
*   only be dereferenced while the PDOC information and MEM are still valid.
*   If no PDOC information is available for the frame, only the frame name, film
*   name, and list of derivative pictures will be filled in.  The remaining
*   fields pointed to by PIC_P will be NIL or default.
}
module phot_frame_info;
define phot_frame_info;
%include 'phot2.ins.pas';

procedure phot_frame_info (            {get info about a particular picture}
  in      filmdir: univ string_var_arg_t; {pathname of film directory containing this frame}
  in      frame: univ string_var_arg_t; {name of frame inquiring about within the film}
  in      pdoc_p: pdoc_picent_p_t;     {pointer to PDOC info for film, may be NIL}
  in out  mem: util_mem_context_t;     {context to allocate any new memory under}
  out     pic_p: pdoc_pic_p_t;         {returned pointer to frame info, never NIL}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  i: sys_int_machine_t;                {scratch integer and loop counter}
  lnam: string_leafname_t;             {scratch leafname}
  gnam: string_leafname_t;             {scratch generic file name}
  tnam: string_treename_t;             {scratch arbitrary pathname}
  uframe: string_var80_t;              {upper case frame name}
  dr_p: pdoc_strent_p_t;               {pointer to current derivatives list entry}
  drend_p: pdoc_strent_p_t;            {pointer to last entry in derivative pictures list}
  conn: file_conn_t;                   {connection to derivative images directory}
  finfo: file_info_t;                  {additional info about directory entry}

label
  loop_deriv;

begin
  tnam.max := size_char(tnam.str);     {init local var strings}
  lnam.max := size_char(lnam.str);
  gnam.max := size_char(gnam.str);
  uframe.max := size_char(uframe.str);
  sys_error_none (stat);               {init to returning with no error}

  pic_p := nil;                        {init to no PDOC info for this frame}
  if pdoc_p <> nil then begin          {PDOC info is available for the film ?}
    pdoc_find_pic_name (pdoc_p, frame, pic_p); {look for info available from PDOC}
    end;

  if pic_p = nil then begin            {no PDOC info available for this frame ?}
    util_mem_grab (                    {allocate picture descriptor}
      sizeof(pic_p^), mem, false, pic_p);
    pdoc_pic_init (pic_p^);            {init descriptor to default or empty values}

    string_alloc (frame.len, mem, false, pic_p^.name_p); {create frame name string}
    string_copy (frame, pic_p^.name_p^); {fill in frame name}

    string_pathname_split (filmdir, tnam, lnam); {make film directory leafname in LNAM}
    string_alloc (lnam.len, mem, false, pic_p^.film_p); {create film name string}
    string_copy (lnam, pic_p^.film_p^); {fill in film name string}
    end;
{
*   Look for pictures derived from this frame and create the derivatives list.
*   PIC_P^.DERIV_P is currently NIL indicating there are no derivative pictures.
}
  if pic_p^.deriv_p <> nil then return; {already have derivative images list ?}

  string_copy (filmdir, tnam);         {build pathname of derived images directory}
  string_appends (tnam, '/deriv'(0));
  file_open_read_dir (tnam, conn, stat); {try to open derived images directory}
  if file_not_found (stat) then return; {no derivatives directory, return with no error ?}
  if sys_error(stat) then return;
  string_copy (frame, uframe);         {make upper case copy of frame name}
  string_upcase (uframe);

loop_deriv:                            {back here each new file in DERIV directory}
  file_read_dir (                      {get next directory entry}
    conn,                              {connection to the directory}
    [],                                {no additional info requested}
    lnam,                              {returned directory entry name}
    finfo,                             {returned additional info}
    stat);
  if file_eof(stat) then begin         {hit end of directory ?}
    file_close (conn);                 {close the directory}
    return;
    end;
  if sys_error(stat) then return;
  string_generic_fnam (lnam, '.tif .jpg .gif .tga', gnam); {make derived image generic name}
  if gnam.len < (frame.len + 2)        {too short to be derived from this image ?}
    then goto loop_deriv;
  string_copy (lnam, tnam);            {make upper case entry name to match with frame name}
  string_upcase (tnam);
  for i := 1 to frame.len do begin     {compare start of directory entry with frame}
    if tnam.str[i] <> uframe.str[i] then goto loop_deriv; {this directory entry not match ?}
    end;
  if lnam.str[frame.len + 1] <> '_' then goto loop_deriv; {name not followed by "_" ?}

  util_mem_grab (                      {allocate derivatives list entry for this name}
    sizeof(dr_p^), mem, false, dr_p);
  string_alloc (gnam.len, mem, false, dr_p^.str_p); {create derivative name string}
  string_copy (gnam, dr_p^.str_p^);    {fill in this derivative name}
  dr_p^.next_p := nil;                 {indicate this entry is at end of chain}
  if pic_p^.deriv_p = nil
    then begin                         {this is first entry in chain}
      pic_p^.deriv_p := dr_p;          {set start of chain pointer}
      dr_p^.prev_p := nil;             {there is no previous entry}
      end
    else begin                         {adding to end of existing chain}
      drend_p^.next_p := dr_p;         {link forwards from previous entry}
      dr_p^.prev_p := drend_p;         {link backwards to previous entry}
      end
    ;
  drend_p := dr_p;                     {update pointer to last link in chain}
  goto loop_deriv;                     {back to process next directory entry}
  end;
