{   Routines that deal with external date/time information.
}
module pdoc_dtm;
define pdoc_dtm_image;
%include 'pdoc2.ins.pas';
{
********************************************************************************
*
*   Subroutine PDOC_DTM_IMAGE (PIC, MEM, FNAM, STAT)
*
*   Fill in the time information in the picture descriptor PIC from the
*   date/time stamp of the image FNAM unless the time information in PIC is
*   already set.
}
procedure pdoc_dtm_image (             {add date/time from image file if unknown}
  in out  pic: pdoc_pic_t;             {picture to add image file header information to}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in      fnam: univ string_var_arg_t; {name of image to add file system date/time from}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  img: img_conn_t;                     {connection to the image file}
  finfo: file_info_t;                  {info about a file system object}

begin
  sys_error_none (stat);               {init to no error encountered}
  if pic.time_p <> nil then return;    {time information already known ?}
  if pdoc_field_time_k in pic.fields   {time explicitly set to unknown ?}
    then return;

  img_open_read_img (fnam, img, stat); {open the image file}
  if sys_error(stat) then return;
  img_close (img, stat);               {close the image file}
  if sys_error(stat) then return;

  file_info (                          {get info about the underlying file}
    img.tnam,                          {full pathname of the file}
    [file_iflag_dtm_k],                {request file date/time}
    finfo,                             {returned information}
    stat);
  if sys_error(stat) then return;
{
*   The file date/time is in FINFO.MODIFIED.
}
  util_mem_grab (sizeof(pic.time_p^), mem, false, pic.time_p); {alloc new mem}
  pic.time_p^.time1 := finfo.modified; {set both times to the image file date/time}
  pic.time_p^.time2 := finfo.modified;
  end;
