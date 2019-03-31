{   Routines that deal with image file header information.
}
module pdoc_header;
define pdoc_header_add_head;
define pdoc_header_add_fnam;
%include 'pdoc2.ins.pas';
{
********************************************************************************
*
*   Subroutine PDOC_HEADER_ADD_HEAD (PIC, MEM, HEAD)
*
*   Add the image file header information in HEAD to the picture description
*   PIC.  Only those fields not set in PIC and set in HEAD will be changed.  In
*   other words, the existing data in PIC overrides new data in HEAD when both
*   exist.  New dynamic memory, if any, will be allocated under the MEM context.
*
*   A copy is made of any data from HEAD.  HEAD may be deallocated after this
*   call without harm to PIC.
}
procedure pdoc_header_add_head (       {add image file header information to picture}
  in out  pic: pdoc_pic_t;             {picture to add image file header information to}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in      head: img_head_t);           {the header information to add}
  val_param;

begin
  if                                   {copy time from header ?}
      (pic.time_p = nil) and
      (imghead_time_k in head.fieldset)
      then begin
    util_mem_grab (sizeof(pic.time_p^), mem, false, pic.time_p); {alloc new mem}
    pic.time_p^.time1 := head.time;    {set both ends of time range to the single time}
    pic.time_p^.time2 := head.time;
    end;

  if                                   {copy time zone offset from header ?}
      (not (pdoc_field_tz_k in pic.fields)) and
      (imghead_heast_k in head.fieldset)
      then begin
    pic.tzone := -head.hours_east;     {set offset of the local timezone}
    pic.fields := pic.fields + [pdoc_field_tz_k];
    end;

  if pic.iso = 0.0 then begin          {ISO sensitivity not already known ?}
    pic.iso := head.iso;               {copy it from header}
    end;

  if pic.exptime = 0.0 then begin      {get exposure time from header ?}
    pic.exptime := head.exptime;
    end;

  if pic.fstop = 0.0 then begin        {get F-stop setting from header ?}
    pic.fstop := head.fstop;
    end;

  if pic.focal = 0.0 then begin        {get actual focal length from header ?}
    pic.focal := head.focal;
    end;

  if pic.focal35 = 0.0 then begin      {get 35mm equivalent focal length from header ?}
    pic.focal35 := head.focal35;
    end;

  if                                   {get altitude from header ?}
      (not (pdoc_field_alt_k in pic.fields)) and
      (imghead_alt_k in head.fieldset)
      then begin
    pic.altitude := head.altitude;
    pic.fields := pic.fields + [pdoc_field_alt_k];
    end;

  if                                   {get header lat/lon picture taken from ?}
      (pic.gcoor_from_p = nil) and
      (imghead_latlon_k in head.fieldset)
      then begin
    util_mem_grab (sizeof(pic.gcoor_from_p^), mem, false, pic.gcoor_from_p); {alloc mem}
    pic.gcoor_from_p^.lat := head.lat; {get degrees north}
    pic.gcoor_from_p^.lon := -head.lon; {get degrees east}
    pic.gcoor_from_p^.rad := head.locrad; {get location error radius}
    end;

  if
      (pic.manuf_p = nil) and
      (head.src_manuf.len <> 0)
      then begin
    string_alloc (head.src_manuf.len, mem, false, pic.manuf_p);
    string_copy (head.src_manuf, pic.manuf_p^);
    end;

  if
      (pic.model_p = nil) and
      (head.src_model.len <> 0)
      then begin
    string_alloc (head.src_model.len, mem, false, pic.model_p);
    string_copy (head.src_model, pic.model_p^);
    end;

  if
      (pic.softw_p = nil) and
      (head.src_softw.len <> 0)
      then begin
    string_alloc (head.src_softw.len, mem, false, pic.softw_p);
    string_copy (head.src_softw, pic.softw_p^);
    end;

  if
      (pic.host_p = nil) and
      (head.src_host.len <> 0)
      then begin
    string_alloc (head.src_host.len, mem, false, pic.host_p);
    string_copy (head.src_host, pic.host_p^);
    end;

  if
      (pic.user_p = nil) and
      (head.src_user.len <> 0)
      then begin
    string_alloc (head.src_user.len, mem, false, pic.user_p);
    string_copy (head.src_user, pic.user_p^);
    end;
  end;
{
********************************************************************************
*
*   Subroutine PDOC_HEADER_ADD_FNAM (PIC, MEM, FNAM, STAT)
*
*   Add the header information from the image file indicated by FNAM to the
*   picture description PIC.  The existing information in PIC takes precedence
*   over new information in from the image file when both exist.
}
procedure pdoc_header_add_fnam (       {add info from image file to picture}
  in out  pic: pdoc_pic_t;             {picture to add image file header information to}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in      fnam: univ string_var_arg_t; {name of image to add info from}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  img: img_conn_t;                     {connection to the image file}
  head: img_head_t;                    {image comments header information}

begin
  img_open_read_img (fnam, img, stat); {open the image file}
  if sys_error(stat) then return;
  img_head_get (img.comm, head);       {extract comments header information}
  img_close (img, stat);               {close the image file}
  if sys_error(stat) then return;

  pdoc_header_add_head (pic, mem, head); {add header information to picture description}
  img_head_close (head);               {done with header information descriptor}
  end;
