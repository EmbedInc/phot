{   Subroutine PHOT_HTM_PIC_WRITE (HOUT, PIC, NPREV, NNEXT, FLAGS, STAT)
*
*   Write the entire contents of the picture-specific HTML file.  HOUT is
*   the HTML file writing state.  PIC is the descriptor for the picture.  NPREV
*   is the name of the previous picture to link to.  No link is created when
*   NPREV is empty.  NNEXT is the name of the next picture to link to.  No link
*   is created when NNEXT is empty.
*
*   FLAGS is a set of control flags that modify the operation of this routine.
*   See the PHOT.INS.PAS file for a description of the flags.  The following
*   flags are implemented:
*
*     PHOT_HTMPIC_PREF_K  -  Add the film name followed by a dash to the front
*       of any file name references.  This can be helpful when releasing a set
*       of pictures from different films into a single directory.
*
*     PHOT_HTMPIC_NPEOPLE_K  -  Do not write names of people in picture.
*
*     PHOT_HTMPIC_NSTORED_K  -  Do not write list of locations where copies of
*       the picture are stored.
*
*     PHOT_HTMPIC_NEXP_K  -  Do not write exposure information.
*
*     PHOT_HTMPIC_INDEX_K  -  Do not generate a link to the "film" proof sheet,
*       instead make the link to a pictures "index" list.
*
*     PHOT_HTMPIC_NOBY_K  -  Do not write "Created by" information for each
*       picture, even when this information is available.
}
module phot_htm_pic_write;
define phot_htm_pic_write;
%include 'phot2.ins.pas';

procedure phot_htm_pic_write (         {write contents to HTM file for a picture}
  in out  hout: htm_out_t;             {picture HTM file writing state}
  in      pic: pdoc_pic_t;             {picture descriptor}
  in      nprev: univ string_var_arg_t; {name of previous image to link to, may be empty}
  in      nnext: univ string_var_arg_t; {name of next image to link to, may be empty}
  in      flags: phot_htmpic_t;        {set of modifier flags}
  out     stat: sys_err_t);            {completion status code}
  val_param;

const
  m_ft = 1000.0 / (25.4 * 12.0);       {mult factor for converting meters to feet}

type
  dtf_k_t = (                          {date/time field IDs, in most to least sig order}
    dtf_none_k,                        {no field}
    dtf_year_k,                        {year}
    dtf_month_k,                       {month}
    dtf_day_k,                         {day}
    dtf_hour_k,                        {hour}
    dtf_min_k,                         {minute}
    dtf_sec_k);                        {second}

var
  anch: boolean;                       {TRUE if anchor used in HTML file}
  title: string_var256_t;              {picture title}
  fpref: string_var80_t;               {film name prefix as used with all file names}
  imgsuff: string_var80_t;             {list of supported image file suffixes}
  time1, time2: sys_date_t;            {picture time range in expanded date format}
  timesame: dtf_k_t;                   {lowest field TIME1 and TIME2 are the same}
  timelow: dtf_k_t;                    {lowest time field that needs to be written}
  timehigh: dtf_k_t;                   {highest time field to write for end of range}
  tzone_id: sys_tzone_k_t;             {time zone ID}
  hours_west: real;                    {time zone hours west of CUT}
  daysave: sys_daysave_k_t;            {daylight savings time strategy}
  s: string_var8192_t;                 {scratch string}
  str_p: pdoc_strent_p_t;              {pointer to current entry in PDOC strings list}
  prev: boolean;                       {previous parameter written}

label
  done_date, done_loc, done_gcoor, done_focal;
{
********************************************************************************
*
*   Local subroutine WDATE (DATE, MSIG, LSIG)
*
*   Write a date/time in the format:
*
*     dayofweek day month year HH:MM:SS
*
*   Only the fields in the most significant to least significant range from MSIG
*   to LSIG are written.
}
procedure wdate (                      {write portion of date/time to HTML file}
  in      date: sys_date_t;            {the date/time}
  in      msig: dtf_k_t;               {ID of most significant field to write}
  in      lsig: dtf_k_t;               {ID of least significant field to write}
  out     stat: sys_err_t);            {completion status}
  val_param; internal;

var
  tk: string_var32_t;                  {scratch token}
  wr: boolean;                         {at least one field was written}

begin
  tk.max := size_char(tk.str);         {init local var string}
  sys_error_none (stat);               {init to no error}
  wr := false;                         {init to nothing written yet}

  if (ord(dtf_day_k) >= ord(msig)) and (ord(dtf_day_k) <= ord(lsig)) then begin
    sys_date_string (date, sys_dstr_daywk_abbr_k, 3, tk, stat);
    if sys_error(stat) then return;
    htm_write_vstr (hout, tk, stat);
    if sys_error(stat) then return;

    sys_date_string (date, sys_dstr_day_k, 0, tk, stat);
    if sys_error(stat) then return;
    htm_write_vstr (hout, tk, stat);
    if sys_error(stat) then return;
    wr := true;
    end;
  if (ord(dtf_month_k) >= ord(msig)) and (ord(dtf_month_k) <= ord(lsig)) then begin
    sys_date_string (date, sys_dstr_mon_abbr_k, 0, tk, stat);
    if sys_error(stat) then return;
    htm_write_vstr (hout, tk, stat);
    if sys_error(stat) then return;
    wr := true;
    end;
  if (ord(dtf_year_k) >= ord(msig)) and (ord(dtf_year_k) <= ord(lsig)) then begin
    sys_date_string (date, sys_dstr_year_k, 0, tk, stat);
    if sys_error(stat) then return;
    htm_write_vstr (hout, tk, stat);
    if sys_error(stat) then return;
    wr := true;
    end;
  if (ord(dtf_hour_k) >= ord(msig)) and (ord(dtf_hour_k) <= ord(lsig)) then begin
    sys_date_string (date, sys_dstr_hour_k, 0, tk, stat);
    if sys_error(stat) then return;
    htm_write_vstr (hout, tk, stat);
    if sys_error(stat) then return;
    wr := true;
    end;
  if (ord(dtf_min_k) >= ord(msig)) and (ord(dtf_min_k) <= ord(lsig)) then begin
    sys_date_string (date, sys_dstr_min_k, 2, tk, stat);
    if sys_error(stat) then return;
    if wr then begin
      htm_write_nopad (hout);          {inhibit space before colon}
      htm_write_str (hout, ':'(0), stat); {write the leading colon}
      htm_write_nopad (hout);          {inhibit space after the colon}
      end;
    htm_write_vstr (hout, tk, stat);
    if sys_error(stat) then return;
    wr := true;
    end;
  if (ord(dtf_sec_k) >= ord(msig)) and (ord(dtf_sec_k) <= ord(lsig)) then begin
    sys_date_string (date, sys_dstr_sec_k, 2, tk, stat);
    if sys_error(stat) then return;
    if wr then begin
      htm_write_nopad (hout);          {inhibit space before colon}
      htm_write_str (hout, ':'(0), stat); {write the leading colon}
      htm_write_nopad (hout);          {inhibit space after the colon}
      end;
    htm_write_vstr (hout, tk, stat);
    if sys_error(stat) then return;
    end;
  end;
{
********************************************************************************
*
*   Subroutine IMG_LIST_SUFF (RW, SUFFLIST)
*
*   Returns the list of valid image file name suffixes in SUFFLIST.  The list
*   is blank separated.  Each suffix is that part of the file name to remove to
*   make the generic image file name.  RW indicates whether the file types
*   implied by the suffixes must be supported for reading, writing, or both.
}
procedure img_list_suff (              {get list of supported image file suffixes}
  in      rw: file_rw_t;               {read/write mode asking about}
  in out  sufflist: univ string_var_arg_t); {suffixes, blank delimited}
  val_param; internal;

var
  tylist: string_var132_t;             {list of image file types}
  p: string_index_t;                   {TYLIST parse index}
  suff: string_var32_t;                {one suffix}

begin
  tylist.max := size_char(tylist.str); {init local var strings}
  suff.max := size_char(suff.str);
  img_list_types (rw, tylist);         {get raw image type names in TYLIST}
  p := 1;                              {init parse index into image types list}
  sufflist.len := 0;                   {init returned list to empty}

  while true do begin                  {back here to get each new type name}
    string_token (tylist, p, suff, stat); {get this type name into SUFF}
    if sys_error(stat) then exit;      {end of image types list ?}
    if sufflist.len > 0 then begin     {this is not first suffix in list ?}
      string_append1 (sufflist, ' ');
      end;
    string_append1 (sufflist, '.');    {add leading dot of file name suffix}
    string_append (sufflist, suff);    {add suffix name after the dot}
    end;
  end;
{
********************************************************************************
*
*   Internal subroutine MAKE_1024_HTM (NAME, DERIV, STAT)
*
*   Make the _1024.htm version of a picture file for the generic picture NAME.
*   This file will be written to the same directory where the main file is, as
*   indicate by HOUT.  DERIV indicates the generated file is for a derivative
*   picture when TRUE, and an original picture when FALSE.
*
*   This HTML file contains links for previous, next, and up, but is mostly for
*   displaying the 1024-sized version of the picture.  When a version of this
*   picture exists in the ORIG directory, then the picture becomes a link to
*   this ORIG version.  If the ORIG version does not exist, then the picture
*   will not be a link.
}
procedure make_1024_htm (              {make _1024.htm file}
  in      name: string_var_arg_t;      {generic name of image for this file}
  in      deriv: boolean;              {for derivative, not original, picture}
  out     stat: sys_err_t);            {completion status}
  val_param; internal;

var
  uname: string_leafname_t;            {upper case generic name of image file}
  tnam: string_treename_t;             {treename of this HTML output file}
  fnam: string_treename_t;             {scratch pathname}
  gnam: string_leafname_t;             {generic file name}
  onam: string_leafname_t;             {leafname of image file in ORIG directory}
  h: htm_out_t;                        {HTM file writing state}
  s: string_var8192_t;                 {scratch string}
  anch: boolean;                       {TRUE if anchor used in HTML file}
  conn: file_conn_t;                   {scratch file connection}
  finfo: file_info_t;                  {information about directory entry}

label
  have_onam;

begin
  tnam.max := size_char(tnam.str);     {init local var strings}
  uname.max := size_char(uname.str);
  fnam.max := size_char(fnam.str);
  gnam.max := size_char(gnam.str);
  onam.max := size_char(onam.str);
  s.max := size_char(s.str);

  string_copy (fpref, uname);          {make upper case image file name}
  string_append (uname, name);
  string_upcase (uname);
{
*   Set ONAM to the leafname of the image file in the ORIG or DERIV directory.
*   ONAM is set to the empty string if this target image does not exist.
}
  onam.len := 0;                       {init to original file does not exist}
  if deriv                             {get name of directory to search into TNAM}
    then string_vstring (tnam, 'deriv'(0), -1)
    else string_vstring (tnam, 'orig'(0), -1);
  file_open_read_dir (tnam, conn, stat);
  if file_not_found(stat) then goto have_onam; {ORIG (or DERIV) directory not exist ?}
  if sys_error(stat) then return;
  while true do begin                  {back here for each new directory entry}
    file_read_dir (                    {read directory entry}
      conn, [file_iflag_type_k], fnam, finfo, stat);
    if file_eof(stat) then exit;       {hit end of directory ?}
    if sys_error(stat) then begin      {hard error ?}
      file_close (conn);
      return;
      end;
    case finfo.ftype of                {what type of entry is this ?}
file_type_data_k: ;                    {ordinary data file}
file_type_link_k: ;                    {symbolic link}
otherwise
      next;                            {can't be image file, skip it}
      end;
    string_fnam_unextend (fnam, imgsuff.str, gnam); {remove suffix if image file}
    if gnam.len = fnam.len then next;  {not image file ?}
    string_upcase (gnam);              {make upper case generic name}
    if string_equal (gnam, uname) then begin {found the particular image file ?}
      string_copy (fnam, onam);        {save this full leafname in ONAM}
      exit;
      end;
    end;                               {back to check next directory entry}
  file_close (conn);                   {close the directory}
have_onam:                             {ONAM is all set}

  string_pathname_split (hout.conn.tnam, tnam, fnam); {build this HTML file name in TNAM}
  string_append1 (tnam, '/');
  string_append (tnam, fpref);
  string_append (tnam, name);
  string_appends (tnam, '_1024.htm'(0));
  htm_open_write_name (h, tnam, stat); {open the HTML output file}
  if sys_error(stat) then return;
{
*   Write HTML startup stuff.
}
  htm_write_str (h, '<html>'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (h, stat);
  if sys_error(stat) then return;
  htm_write_str (h, '<head>'(0), stat);
  if sys_error(stat) then return;
  htm_write_indent (h);
  htm_write_newline (h, stat);
  if sys_error(stat) then return;
  htm_write_str (h, '</head>'(0), stat);
  if sys_error(stat) then return;
  htm_write_undent (h);
  htm_write_newline (h, stat);
  if sys_error(stat) then return;

  htm_write_str (h, '<body bgcolor='(0), stat);
  if sys_error(stat) then return;
  htm_write_color_gray (h, phot_col_back, stat);
  if sys_error(stat) then return;
  htm_write_nopad (h);
  htm_write_str (h, '><font color='(0), stat);
  if sys_error(stat) then return;
  htm_write_color_gray (h, phot_col_text, stat);
  if sys_error(stat) then return;
  htm_write_nopad (h);
  htm_write_str (h, '>'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (h, stat);
  if sys_error(stat) then return;
{
*   Write previous, up, and next click targets.
}
  {
  *   Click target for previous picture.
  }
  anch := nprev.len <> 0;
  if anch
    then begin                         {previous picture is clickable}
      htm_write_str (h, '<a href='(0), stat);
      if sys_error(stat) then return;
      htm_write_nopad (h);
      htm_write_indent (h);
      s.len := 0;
      string_append (s, nprev);
      string_appends (s, '_1024.htm'(0));
      htm_write_vstr (h, s, stat);
      if sys_error(stat) then return;
      htm_write_str (h, 'accesskey="p" title="ALT-P">'(0), stat);
      if sys_error(stat) then return;
      end
    else begin                         {no previous picture is available}
      htm_write_str (h, '<font color='(0), stat);
      if sys_error(stat) then return;
      htm_write_indent (h);
      htm_write_color_gray (h, phot_col_gray, stat);
      if sys_error(stat) then return;
      htm_write_nopad (h);
      htm_write_str (h, '>'(0), stat);
      if sys_error(stat) then return;
      end
    ;
  htm_write_nopad (h);
  htm_write_str (h, 'Previous'(0), stat);
  if sys_error(stat) then return;
  htm_write_nopad (h);
  if anch
    then begin                         {previous picture is clickable}
      htm_write_str (h, '</a>'(0), stat);
      if sys_error(stat) then return;
      end
    else begin                         {no previous picture is available}
      htm_write_str (h, '<font color='(0), stat);
      if sys_error(stat) then return;
      htm_write_color_gray (h, phot_col_text, stat);
      if sys_error(stat) then return;
      htm_write_nopad (h);
      htm_write_str (h, '>'(0), stat);
      if sys_error(stat) then return;
      end
    ;
  htm_write_str (h, ' --'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (h, stat);
  if sys_error(stat) then return;
  htm_write_undent (h);
  {
  *   Click target for UP.
  }
  htm_write_str (h, '<a href='(0), stat);
  if sys_error(stat) then return;
  htm_write_nopad (h);
  htm_write_indent (h);
  s.len := 0;
  string_append (s, fpref);
  string_append (s, pic.name_p^);
  string_appends (s, '.htm'(0));
  htm_write_vstr (h, s, stat);
  if sys_error(stat) then return;
  htm_write_nopad (h);
  htm_write_str (h, '>Up</a> --'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (h, stat);
  if sys_error(stat) then return;
  htm_write_undent (h);
  {
  *   Click target for next picture.
  }
  anch := nnext.len <> 0;
  if anch
    then begin                         {next picture is clickable}
      htm_write_str (h, '<a href='(0), stat);
      if sys_error(stat) then return;
      htm_write_nopad (h);
      htm_write_indent (h);
      s.len := 0;
      string_append (s, nnext);
      string_appends (s, '_1024.htm'(0));
      htm_write_vstr (h, s, stat);
      if sys_error(stat) then return;
      htm_write_str (h, 'accesskey="n" title="ALT-N">'(0), stat);
      if sys_error(stat) then return;
      end
    else begin                         {no next picture is available}
      htm_write_str (h, '<font color='(0), stat);
      if sys_error(stat) then return;
      htm_write_indent (h);
      htm_write_color_gray (h, phot_col_gray, stat);
      if sys_error(stat) then return;
      htm_write_nopad (h);
      htm_write_str (h, '>'(0), stat);
      if sys_error(stat) then return;
      end
    ;
  htm_write_nopad (h);
  htm_write_str (h, 'Next'(0), stat);
  if sys_error(stat) then return;
  htm_write_nopad (h);
  if anch
    then begin                         {next picture is clickable}
      htm_write_str (h, '</a>'(0), stat);
      if sys_error(stat) then return;
      end
    else begin                         {no next picture is available}
      htm_write_str (h, '<font color='(0), stat);
      if sys_error(stat) then return;
      htm_write_color_gray (h, phot_col_text, stat);
      if sys_error(stat) then return;
      htm_write_nopad (h);
      htm_write_str (h, '>'(0), stat);
      if sys_error(stat) then return;
      end
    ;
  htm_write_newline (h, stat);
  if sys_error(stat) then return;
  htm_write_undent (h);

  htm_write_str (h, '<br>'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (h, stat);
  if sys_error(stat) then return;
{
*   Show image.  If the original of this picture exists, this image will be a
*   link to it.
}
  htm_write_str (h, '<center>'(0), stat);
  if sys_error(stat) then return;
  htm_write_indent (h);
  if onam.len > 0 then begin
    htm_write_str (h, '<a'(0), stat);
    if sys_error(stat) then return;
    htm_write_str (h, 'href='(0), stat);
    if sys_error(stat) then return;
    htm_write_nopad (h);
    s.len := 0;
    if deriv
      then begin                       {link to derivative image}
        string_appends (s, '../deriv/'(0));
        end
      else begin                       {link to original image}
        string_appends (s, '../orig/'(0));
        end
      ;
    string_append (s, onam);
    htm_write_vstr (h, s, stat);
    if sys_error(stat) then return;
    htm_write_nopad (h);
    htm_write_str (h, '>'(0), stat);
    if sys_error(stat) then return;
    htm_write_nopad (h);
    end;
  htm_write_str (h, '<img src='(0), stat);
  if sys_error(stat) then return;
  htm_write_nopad (h);
  s.len := 0;
  string_appends (s, '../1024/'(0));
  string_append (s, fpref);
  string_append (s, name);
  string_appends (s, '.jpg'(0));
  htm_write_vstr (h, s, stat);
  if sys_error(stat) then return;
  htm_write_str (h, 'border=0 vspace=5>'(0), stat);
  if sys_error(stat) then return;
  if onam.len > 0 then begin
    htm_write_nopad (h);
    htm_write_str (h, '</a>'(0), stat);
    if sys_error(stat) then return;
    end;
  if sys_error(stat) then return;
  htm_write_str (h, '</center>'(0), stat);
  if sys_error(stat) then return;
  htm_write_undent (h);
  htm_write_newline (h, stat);
  if sys_error(stat) then return;
{
*   Finish and close the HTML file.
}
  htm_write_str (h, '</body></html>'(0), stat);
  if sys_error(stat) then return;

  htm_close_write (h, stat);
  end;
{
********************************************************************************
*
*   Start of main routine.
}
begin
  title.max := size_char(title.str);   {init local var string}
  fpref.max := size_char(fpref.str);
  imgsuff.max := size_char(imgsuff.str);
  s.max := size_char(s.str);

  img_list_suff ([file_rw_read_k], imgsuff); {make list of image file suffixes}
  string_terminate_null (imgsuff);
{
*   Set FPREF to the prefix to use for all file name references.  This will be
*   the empty string except when the PHOT_HTMPIC_PREF_K flag is set.  In that
*   case it will be the lower case film name followed by a dash (-).
}
  fpref.len := 0;                      {init to not write any prefix}
  if phot_htmpic_pref_k in flags then begin {add film name prefix to file names ?}
    if pic.film_p <> nil then begin    {there is a file name ?}
      string_copy (pic.film_p^, fpref); {init prefix with the film name}
      string_downcase (fpref);
      string_append1 (fpref, '-');     {separate from picture names with dash}
      end;
    end;
{
*   Write HTML start.
}
  htm_write_newline (hout, stat);      {make sure new data will start on a new line}
  if sys_error(stat) then return;
  htm_write_str (hout, '<html>'(0), stat);
  if sys_error(stat) then return;
  htm_write_buf (hout, stat);
  if sys_error(stat) then return;
{
*   Write HTML <head> section and start <body>.
}
  title.len := 0;                      {init picture name string to empty}
  if pic.film_p = nil
    then begin                         {this picture is not part of a film}
      string_appends (title, 'Picture '(0));
      string_append (title, pic.name_p^);
      end
    else begin                         {this picture is a frame in a film}
      string_appends (title, 'Photograph '(0));
      string_append (title, pic.film_p^);
      string_appends (title, '-');
      string_append (title, pic.name_p^);
      end
    ;

  htm_write_str (hout, '<head><title>', stat); {<head><title>}
  if sys_error(stat) then return;
  htm_write_indent (hout);
  htm_write_nopad (hout);
  htm_write_vstr (hout, title, stat);  {add complete picture name}
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  htm_write_str (hout, '</title></head>'(0), stat); {</title></head>}
  if sys_error(stat) then return;
  htm_write_undent (hout);
  htm_write_newline (hout, stat);      {close current line}
  if sys_error(stat) then return;

  htm_write_str (hout, '<body bgcolor='(0), stat);
  if sys_error(stat) then return;
  htm_write_color_gray (hout, phot_col_back, stat);
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  htm_write_str (hout, '><font color='(0), stat);
  if sys_error(stat) then return;
  htm_write_color_gray (hout, phot_col_text, stat);
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  htm_write_str (hout, '>'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;

  htm_write_bline (hout, stat);
  if sys_error(stat) then return;
{
*   Write click targets.
}
  htm_write_str (hout, 'Click to go to:'(0), stat); {write click targets list}
  if sys_error(stat) then return;
  htm_write_indent (hout);
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
  {
  *   Click target for previous picture.
  }
  anch := nprev.len <> 0;
  if anch
    then begin                         {previous picture is clickable}
      htm_write_str (hout, '<a href='(0), stat);
      if sys_error(stat) then return;
      htm_write_nopad (hout);
      htm_write_indent (hout);
      s.len := 0;
      string_append (s, nprev);
      string_appends (s, '.htm accesskey="p" title="ALT-P">'(0));
      htm_write_vstr (hout, s, stat);
      if sys_error(stat) then return;
      end
    else begin                         {no previous picture is available}
      htm_write_str (hout, '<font color='(0), stat);
      if sys_error(stat) then return;
      htm_write_indent (hout);
      htm_write_color_gray (hout, phot_col_gray, stat);
      if sys_error(stat) then return;
      htm_write_nopad (hout);
      htm_write_str (hout, '>'(0), stat);
      if sys_error(stat) then return;
      end
    ;
  htm_write_nopad (hout);
  htm_write_str (hout, 'Previous Picture'(0), stat);
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  if anch
    then begin                         {previous picture is clickable}
      htm_write_str (hout, '</a>'(0), stat);
      if sys_error(stat) then return;
      end
    else begin                         {no previous picture is available}
      htm_write_str (hout, '<font color='(0), stat);
      if sys_error(stat) then return;
      htm_write_color_gray (hout, phot_col_text, stat);
      if sys_error(stat) then return;
      htm_write_nopad (hout);
      htm_write_str (hout, '>'(0), stat);
      if sys_error(stat) then return;
      end
    ;
  htm_write_str (hout, ' --'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
  htm_write_undent (hout);
  {
  *   Click target for next picture.
  }
  anch := nnext.len <> 0;
  if anch
    then begin                         {next picture is clickable}
      htm_write_str (hout, '<a href='(0), stat);
      if sys_error(stat) then return;
      htm_write_nopad (hout);
      htm_write_indent (hout);
      s.len := 0;
      string_append (s, nnext);
      string_appends (s, '.htm accesskey="n" title="ALT-N">'(0));
      htm_write_vstr (hout, s, stat);
      if sys_error(stat) then return;
      end
    else begin                         {no next picture is available}
      htm_write_str (hout, '<font color='(0), stat);
      if sys_error(stat) then return;
      htm_write_indent (hout);
      htm_write_color_gray (hout, phot_col_gray, stat);
      if sys_error(stat) then return;
      htm_write_nopad (hout);
      htm_write_str (hout, '>'(0), stat);
      if sys_error(stat) then return;
      end
    ;
  htm_write_nopad (hout);
  htm_write_str (hout, 'next Picture'(0), stat);
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  if anch
    then begin                         {next picture is clickable}
      htm_write_str (hout, '</a>'(0), stat);
      if sys_error(stat) then return;
      end
    else begin                         {no next picture is available}
      htm_write_str (hout, '<font color='(0), stat);
      if sys_error(stat) then return;
      htm_write_color_gray (hout, phot_col_text, stat);
      if sys_error(stat) then return;
      htm_write_nopad (hout);
      htm_write_str (hout, '>'(0), stat);
      if sys_error(stat) then return;
      end
    ;
  htm_write_str (hout, ' --'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
  htm_write_undent (hout);
  {
  *   Click target for the film proof sheet.
  }
  anch := true;
  if anch
    then begin                         {film is clickable}
      htm_write_str (hout, '<a href='(0), stat);
      if sys_error(stat) then return;
      htm_write_nopad (hout);
      htm_write_indent (hout);
      htm_write_str (hout, '../index.htm>'(0), stat);
      if sys_error(stat) then return;
      end
    else begin                         {no film available}
      htm_write_str (hout, '<font color='(0), stat);
      if sys_error(stat) then return;
      htm_write_indent (hout);
      htm_write_color_gray (hout, phot_col_gray, stat);
      if sys_error(stat) then return;
      htm_write_nopad (hout);
      htm_write_str (hout, '>'(0), stat);
      if sys_error(stat) then return;
      end
    ;
  htm_write_nopad (hout);
  if phot_htmpic_index_k in flags
    then begin                         {link to general INDEX page}
      htm_write_str (hout, 'Index'(0), stat);
      end
    else begin                         {link to film proof sheet}
      htm_write_str (hout, 'Film'(0), stat);
      end
    ;
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  if anch
    then begin                         {film is clickable}
      htm_write_str (hout, '</a>'(0), stat);
      if sys_error(stat) then return;
      end
    else begin                         {no film is available}
      htm_write_str (hout, '<font color='(0), stat);
      if sys_error(stat) then return;
      htm_write_color_gray (hout, phot_col_text, stat);
      if sys_error(stat) then return;
      htm_write_nopad (hout);
      htm_write_str (hout, '>'(0), stat);
      if sys_error(stat) then return;
      end
    ;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
  htm_write_undent (hout);
  htm_write_str (hout, '<br>'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
  htm_write_undent (hout);
{
*   Write the picture title.  This, the quick description, and the picture
*   are all centered.
}
  htm_write_str (hout, '<center>', stat);
  if sys_error(stat) then return;
  htm_write_indent (hout);
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;

  htm_write_str (hout, '<h1>', stat);
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  htm_write_vstr (hout, title, stat);
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  htm_write_str (hout, '</h1>', stat);
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
{
*   Write the quick description.
}
  if pic.quick_p <> nil then begin     {quick description ?}
    htm_write_vstr (hout, pic.quick_p^, stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    htm_write_str (hout, '<p>'(0), stat);
    if sys_error(stat) then return;
    htm_write_nopad (hout);
    end;
{
*   Show the picture, which is also clickable to bring up the 1024 size version.
}
  htm_write_str (hout, '<a href='(0), stat);
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  htm_write_indent (hout);
  s.len := 0;
  string_append (s, fpref);
  string_append (s, pic.name_p^);
  string_appends (s, '_1024.htm'(0));
  htm_write_vstr (hout, s, stat);
  if sys_error(stat) then return;
  htm_write_str (hout, 'title="Click to see larger image">'(0), stat);
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  htm_write_str (hout, '<img src='(0), stat);
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  s.len := 0;
  string_appends (s, '../600/'(0));
  string_append (s, fpref);
  string_append (s, pic.name_p^);
  string_appends (s, '.jpg'(0));
  htm_write_vstr (hout, s, stat);
  if sys_error(stat) then return;
  htm_write_str (hout, 'border=0 vspace=5><br clear=all></a>'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
  htm_write_undent (hout);

  make_1024_htm (pic.name_p^, false, stat); {make HTML page for 1024 size version}
  if sys_error(stat) then return;
{
*   Set TIME1 (if picture time specified) and TIME2.  TIME2 is used for the copyright
*   year in addition to the picture time, so it is determined before either.  If no
*   creation time is specified for the picture, then TIME2 will be set to the current
*   time.  TIME1 is only set if a creation time is specified.
}
  timesame := dtf_none_k;              {init to no common high level fields in TIME1,TIME2}

  if pic.time_p = nil
    then begin                         {no time is available for this picture}
      sys_timezone_here (              {get local time zone information}
        tzone_id, hours_west, daysave);
      sys_clock_to_date (              {make expanded date from current time}
        sys_clock,                     {current time}
        tzone_id, hours_west, daysave, {time zone information}
        time2);                        {returned time descriptor}

      end
    else begin                         {this picture has time stamp information}
      sys_clock_to_date (              {make expanded starting time}
        pic.time_p^.time1,             {time value to expand}
        sys_tzone_other_k,             {time zone ID}
        pic.tzone,                     {time zone hours west of CUT}
        sys_daysave_no_k,              {not apply daylight savings, already built into TZONE}
        time1);                        {returned expanded start time}
      sys_clock_to_date (              {make expanded ending time}
        pic.time_p^.time2,             {time value to expand}
        sys_tzone_other_k,             {time zone ID}
        pic.tzone,                     {time zone hours west of CUT}
        sys_daysave_no_k,              {not apply daylight savings, already built into TZONE}
        time2);                        {returned expanded end time}
      while true do begin              {block to exit when TIMESAME set}
        if time2.year <> time1.year then exit;
        timesame := dtf_year_k;
        if time2.month <> time1.month then exit;
        timesame := dtf_month_k;
        if time2.day <> time1.day then exit;
        timesame := dtf_day_k;
        if time2.hour <> time1.hour then exit;
        timesame := dtf_hour_k;
        if time2.minute <> time1.minute then exit;
        timesame := dtf_min_k;
        if time2.second <> time1.second then exit;
        timesame := dtf_sec_k;
        exit;
        end;
      end
    ;
{
*   Write the copyright.  This also ends the centered content.
}
  if pic.copyright_p <> nil then begin {we have copyright owner name ?}
    htm_write_str (hout, '&copy; Copyright '(0), stat);
    if sys_error(stat) then return;
    sys_date_string (time2, sys_dstr_year_k, 0, s, stat);
    if sys_error(stat) then return;
    htm_write_vstr (hout, s, stat);
    if sys_error(stat) then return;
    htm_write_nopad (hout);
    htm_write_str (hout, ', '(0), stat);
    if sys_error(stat) then return;
    htm_write_vstr (hout, pic.copyright_p^, stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    end;

  htm_write_str (hout, '</center><p>'(0), stat); {close centered content}
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
  htm_write_undent (hout);
{
*   Write creators list.
}
  if                                   {write creators list ?}
      (pic.by_p <> nil) and            {the information exists ?}
      (not (phot_htmpic_noby_k in flags)) {not inhibited ?}
      then begin
    htm_write_str (hout, '<b>Created by:</b> '(0), stat);
    if sys_error(stat) then return;

    phot_whtm_people (hout, pic.by_p, stat); {write list of people}
    if sys_error(stat) then return;

    htm_write_nopad (hout);
    htm_write_str (hout, '<br>'(0), stat);
    if sys_error(stat) then return;

    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    end;
{
*   Write picture created time.  If a picture time has been supplied (PIC.TIME_P
*   not NIL), then TIME1 and TIME2 have been set to the expanded date of the
*   start and end time of the time range, respectively.  In that case, TIMESAME
*   is also set indicating the least significant field that both time
*   descriptors have the same value for from there to the most significant field.
*   For example, if TIMESAME indicates the day, then the year, month, and day of
*   both time descriptors is guaranteed to be the same.
}
  if pic.time_p <> nil then begin      {time exists for this picture ?}
    {
    *   Determine the least significant time field that needs to be written.
    *   A full time string is YEAR MONTH DAY HH:MM:SS.  If a single time was
    *   specified for the picture only down to the minute, for example, then the
    *   seconds range will be the maximum possible, which is 0 to 59.  In this
    *   case is it unnecessary (and distracting) to write the seconds.  This
    *   section of code sets TIMELOW to the ID of the lowest field that needs to
    *   be written, which would be minutes in the example above.
    }
    timelow := dtf_sec_k;              {init to write down to most detailed field}
    while true do begin                {block to exit when TIMELOW all set}
      if (time1.second > 1) or (time2.second < 59) then exit;
      timelow := dtf_min_k;
      if (time1.minute > 0) or (time2.minute < 59) then exit;
      timelow := dtf_hour_k;
      if (time1.hour > 0) or (time2.hour < 23) then exit;
      timelow := dtf_day_k;
      if (time1.day > 0) or (time2.day < 27) then exit;
      timelow := dtf_month_k;
      if (time1.month > 0) or (time2.month < 11) then exit;
      timelow := dtf_year_k;
      exit;
      end;
    if timelow = dtf_hour_k then timelow := dtf_min_k; {never write just hour}

    htm_write_str (hout, '<b>Date:</b>'(0), stat); {start the date/time text}
    if sys_error(stat) then return;
    htm_write_indent (hout);
    {
    *   Handle special case of a month range within the same year.  In this
    *   case, the range is written first, followed by the year.
    }
    if
        (time1.year = time2.year) and  {range is within the same year ?}
        (timelow = dtf_month_k)        {least significant field is month ?}
        then begin
      if (time2.month <> time1.month) then begin {month range, not single month ?}
        wdate (time1, dtf_month_k, dtf_month_k, stat); {write starting month}
        if sys_error(stat) then return;
        htm_write_str (hout, '-'(0), stat);
        if sys_error(stat) then return;
        end;
      wdate (time2, dtf_year_k, dtf_month_k, stat); {write ending month and year}
      if sys_error(stat) then return;
      goto done_date;
      end;
    wdate (time1, dtf_year_k, timelow, stat); {write starting time value}
    if sys_error(stat) then return;

    if timelow <> timesame then begin  {need to write second time of time range ?}
      htm_write_str (hout, '-'(0), stat);
      if sys_error(stat) then return;
      timehigh := succ(timesame);      {make ID of first different time field}
      if ord(timehigh) > ord(dtf_hour_k) {start with hour if anything past changed}
        then timehigh := dtf_hour_k;
      if timehigh = dtf_day_k then timehigh := dtf_month_k; {don't start with day number}
      wdate (time2, timehigh, timelow, stat); {write ending time value}
      if sys_error(stat) then return;
      end;

done_date:                             {done writing date/time range}
    htm_write_nopad (hout);
    htm_write_str (hout, '<br>'(0), stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    htm_write_undent (hout);
    end;
{
*   Write location names hierarchy.
}
  if pic.loc_of_p <> nil then begin    {subject location exists ?}

    if pic.loc_of_p = pic.loc_from_p then begin {just one location ?}
      htm_write_str (hout, '<b>Location:</b>'(0), stat);
      if sys_error(stat) then return;
      htm_write_newline (hout, stat);
      if sys_error(stat) then return;
      htm_write_indent (hout);
      phot_whtm_loc (hout, pic.loc_of_p, stat);
      if sys_error(stat) then return;
      htm_write_str (hout, '<br>'(0), stat);
      if sys_error(stat) then return;
      htm_write_newline (hout, stat);
      if sys_error(stat) then return;
      htm_write_undent (hout);
      goto done_loc;
      end;

    htm_write_str (hout, '<b>Location of Subject:</b>'(0), stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    htm_write_indent (hout);
    phot_whtm_loc (hout, pic.loc_of_p, stat);
    if sys_error(stat) then return;
    htm_write_str (hout, '<br>'(0), stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    htm_write_undent (hout);
    end;

  if pic.loc_from_p <> nil then begin  {source location exists ?}
    htm_write_str (hout, '<b>Location Picture Created:</b>'(0), stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    htm_write_indent (hout);
    phot_whtm_loc (hout, pic.loc_from_p, stat);
    if sys_error(stat) then return;
    htm_write_str (hout, '<br>'(0), stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    htm_write_undent (hout);
    end;

done_loc:                              {done writing location names}
{
*   Write location description.
}
  if pic.loc_desc_p <> nil then begin  {location description exists ?}
    htm_write_str (hout, '<b>Location description:</b>'(0), stat);
    if sys_error(stat) then return;
    htm_write_indent (hout);
    phot_whtm_lines (hout, pic.loc_desc_p, stat);
    if sys_error(stat) then return;
    htm_write_str (hout, '<br>'(0), stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    htm_write_undent (hout);
    end;
{
*   Write list of people appearing in the picture.
}
  if (not (phot_htmpic_npeople_k in flags)) and
      (pic.people_p <> nil)
      then begin
    htm_write_str (hout, '<b>People:</b> '(0), stat);
    if sys_error(stat) then return;

    phot_whtm_people (hout, pic.people_p, stat); {write names}
    if sys_error(stat) then return;

    htm_write_str (hout, '<br>'(0), stat);
    if sys_error(stat) then return;

    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    end;
{
*   Write geographic coordinates.
}
  if pic.gcoor_of_p <> nil then begin  {OF coordinate ?}

    if pic.gcoor_from_p = pic.gcoor_of_p then begin {one coordinate only ?}
      htm_write_str (hout, '<b>Coordinates:</b>'(0), stat);
      if sys_error(stat) then return;
      htm_write_indent (hout);
      phot_whtm_geocoor (hout, pic.gcoor_of_p^, stat);
      if sys_error(stat) then return;
      htm_write_nopad (hout);
      if pdoc_field_alt_k in pic.fields then begin {altitude available ?}
        htm_write_nopad (hout);
        htm_write_str (hout, ', altitude'(0), stat);
        if sys_error(stat) then return;
        string_f_fp_fixed (s, pic.altitude * m_ft, 0);
        htm_write_vstr (hout, s, stat); {write altitude in feet}
        if sys_error(stat) then return;
        htm_write_str (hout, 'ft ('(0), stat);
        if sys_error(stat) then return;
        htm_write_nopad (hout);
        string_f_fp_fixed (s, pic.altitude, 0);
        htm_write_vstr (hout, s, stat); {write altitude in meters}
        if sys_error(stat) then return;
        htm_write_str (hout, 'm)'(0), stat);
        if sys_error(stat) then return;
        end;
      htm_write_nopad (hout);
      htm_write_str (hout, '<br>'(0), stat);
      if sys_error(stat) then return;
      htm_write_newline (hout, stat);
      if sys_error(stat) then return;
      htm_write_undent (hout);
      goto done_gcoor;
      end;

    htm_write_str (hout, '<b>Coordinates of subject:</b>'(0), stat);
    if sys_error(stat) then return;
    htm_write_indent (hout);
    phot_whtm_geocoor (hout, pic.gcoor_of_p^, stat);
    if sys_error(stat) then return;
    htm_write_nopad (hout);
    htm_write_str (hout, '<br>'(0), stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    htm_write_undent (hout);
    end;

  if pic.gcoor_from_p <> nil then begin {FROM coordinate exists ?}
    htm_write_str (hout, '<b>Taken from:</b>'(0), stat);
    if sys_error(stat) then return;
    htm_write_indent (hout);
    phot_whtm_geocoor (hout, pic.gcoor_from_p^, stat);
    if sys_error(stat) then return;
    if pdoc_field_alt_k in pic.fields then begin {altitude available ?}
      htm_write_nopad (hout);
      htm_write_str (hout, ', altitude'(0), stat);
      if sys_error(stat) then return;
      string_f_fp_fixed (s, pic.altitude * m_ft, 0);
      htm_write_vstr (hout, s, stat);  {write altitude in feet}
      if sys_error(stat) then return;
      htm_write_str (hout, 'ft ('(0), stat);
      if sys_error(stat) then return;
      htm_write_nopad (hout);
      string_f_fp_fixed (s, pic.altitude, 0);
      htm_write_vstr (hout, s, stat);  {write altitude in meters}
      if sys_error(stat) then return;
      htm_write_str (hout, 'm)'(0), stat);
      if sys_error(stat) then return;
      end;
    htm_write_nopad (hout);
    htm_write_str (hout, '<br>'(0), stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    htm_write_undent (hout);
    end;

done_gcoor:
{
*   Write exposure information.
}
  if
      (not (phot_htmpic_nexp_k in flags)) and (
        (pic.iso <> 0.0) or
        (pic.exptime <> 0.0) or
        (pic.fstop <> 0.0) or
        (pic.focal <> 0.0) or
        (pic.focal35 <> 0.0)
        )
      then begin
    htm_write_str (hout, '<b>Exposure:</b>'(0), stat);
    if sys_error(stat) then return;
    htm_write_indent (hout);
    prev := false;

    if pic.iso <> 0 then begin
      if prev then begin
        htm_write_nopad (hout);
        htm_write_str (hout, ','(0), stat);
        if sys_error(stat) then return;
        end;
      prev := true;
      htm_write_str (hout, 'ISO'(0), stat);
      if sys_error(stat) then return;
      string_f_fp_free (s, pic.iso, 2);
      htm_write_vstr (hout, s, stat);
      if sys_error(stat) then return;
      end;

    if pic.exptime <> 0.0 then begin
      if prev then begin
        htm_write_nopad (hout);
        htm_write_str (hout, ','(0), stat);
        if sys_error(stat) then return;
        end;
      prev := true;
      if pic.exptime <= 0.5
        then begin                     {1/2 second or less}
          htm_write_str (hout, '1/'(0), stat);
          if sys_error(stat) then return;
          htm_write_nopad (hout);
          string_f_fp_free (s, 1.0/pic.exptime, 2);
          htm_write_vstr (hout, s, stat);
          if sys_error(stat) then return;
          end
        else begin                     {longer than 1/2 second}
          string_f_fp_free (s, pic.exptime, 2);
          htm_write_vstr (hout, s, stat);
          if sys_error(stat) then return;
          end
        ;
      htm_write_str (hout, 's'(0), stat);
      if sys_error(stat) then return;
      end;

    if pic.fstop <> 0 then begin
      if prev then begin
        htm_write_nopad (hout);
        htm_write_str (hout, ','(0), stat);
        if sys_error(stat) then return;
        end;
      prev := true;
      htm_write_str (hout, 'f/'(0), stat);
      if sys_error(stat) then return;
      htm_write_nopad (hout);
      string_f_fp_free (s, pic.fstop, 2);
      htm_write_vstr (hout, s, stat);
      if sys_error(stat) then return;
      end;

    if
        (pic.focal <> 0.0) or
        (pic.focal35 <> 0.0)
        then begin
      if prev then begin
        htm_write_nopad (hout);
        htm_write_str (hout, ','(0), stat);
        if sys_error(stat) then return;
        end;
      prev := true;
      if pic.focal = pic.focal35 then begin {actual and 35mm-equiv are the same ?}
        string_f_fp_free (s, pic.focal, 2);
        htm_write_vstr (hout, s, stat);
        if sys_error(stat) then return;
        htm_write_nopad (hout);
        htm_write_str (hout, 'mm'(0), stat);
        if sys_error(stat) then return;
        goto done_focal;
        end;
      if                               {different actual and 35mm focal lengths ?}
          (pic.focal <> 0.0) and
          (pic.focal35 <> 0.0)
          then begin
        string_f_fp_free (s, pic.focal, 2);
        htm_write_vstr (hout, s, stat);
        if sys_error(stat) then return;
        htm_write_nopad (hout);
        htm_write_str (hout, 'mm actual ('(0), stat);
        if sys_error(stat) then return;
        htm_write_nopad (hout);
        string_f_fp_free (s, pic.focal35, 2);
        htm_write_vstr (hout, s, stat);
        if sys_error(stat) then return;
        htm_write_nopad (hout);
        htm_write_str (hout, 'mm 35mm-equiv)'(0), stat);
        if sys_error(stat) then return;
        goto done_focal;
        end;
      if pic.focal <> 0.0 then begin   {only actual focal length available}
        string_f_fp_free (s, pic.focal, 2);
        htm_write_vstr (hout, s, stat);
        if sys_error(stat) then return;
        htm_write_nopad (hout);
        htm_write_str (hout, 'mm actual'(0), stat);
        if sys_error(stat) then return;
        goto done_focal;
        end;
      if pic.focal35 <> 0.0 then begin {only 35mm-equiv focal length available}
        string_f_fp_free (s, pic.focal35, 2);
        htm_write_vstr (hout, s, stat);
        if sys_error(stat) then return;
        htm_write_nopad (hout);
        htm_write_str (hout, 'mm (35mm-equiv)'(0), stat);
        if sys_error(stat) then return;
        goto done_focal;
        end;
done_focal:                            {done writing lens focal length}
      end;

    htm_write_nopad (hout);
    htm_write_str (hout, '<br>'(0), stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    htm_write_undent (hout);
    end;
{
*   Write list of locations where copies of this picture are stored.
}
  if (not (phot_htmpic_nstored_k in flags)) and
      (pic.stored_p <> nil)
      then begin
    htm_write_str (hout, '<b>Stored:</b>'(0), stat);
    if sys_error(stat) then return;
    htm_write_indent (hout);
    str_p := pic.stored_p;             {init to first string in list}
    while str_p <> nil do begin        {once for each string}
      htm_write_vstr (hout, str_p^.str_p^, stat);
      if sys_error(stat) then return;
      str_p := str_p^.next_p;          {point to next string}
      if str_p <> nil then begin       {another string will follow this one ?}
        htm_write_nopad (hout);
        htm_write_str (hout, ','(0), stat);
        if sys_error(stat) then return;
        end;
      end;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    htm_write_undent (hout);
    end;
{
*   Write description text.
}
  if pic.desc_p <> nil then begin      {description text exists ?}
    htm_write_str (hout, '<p>'(0), stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    phot_whtm_lines (hout, pic.desc_p, stat);
    end;

  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
{
*   Write information about other pictures derived from this picture.
}
  str_p := pic.deriv_p;                {init to first derived image in the list}

  while str_p <> nil do begin          {once for each derived image}
    htm_write_str (hout, '<center><h2>Derived image'(0), stat); {write the title}
    if sys_error(stat) then return;
    htm_write_indent (hout);
    s.len := 0;
    if pic.film_p <> nil then begin
      string_append (s, pic.film_p^);
      string_append1 (s, '-');
      end;
    string_append (s, str_p^.str_p^);  {add generic derived image name}
    htm_write_vstr (hout, s, stat);
    if sys_error(stat) then return;
    htm_write_nopad (hout);
    htm_write_str (hout, '</h2>'(0), stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;

    htm_write_str (hout, '<a href='(0), stat);
    if sys_error(stat) then return;
    htm_write_nopad (hout);
    s.len := 0;
    string_append (s, fpref);
    string_append (s, str_p^.str_p^);
    string_appends (s, '_1024.htm'(0));
    htm_write_vstr (hout, s, stat);
    if sys_error(stat) then return;
    htm_write_str (hout, 'title="Click to see larger image"><img src='(0), stat);
    if sys_error(stat) then return;
    htm_write_nopad (hout);
    s.len := 0;
    string_appends (s, '../600/'(0));
    string_append (s, fpref);
    string_append (s, str_p^.str_p^);
    string_appends (s, '.jpg'(0));
    htm_write_vstr (hout, s, stat);
    if sys_error(stat) then return;
    htm_write_str (hout, 'border=0 vspace=5></a><br clear=all>'(0), stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    htm_write_undent (hout);

    make_1024_htm (str_p^.str_p^, true, stat); {make page for 1024 size version}
    if sys_error(stat) then return;

    str_p := str_p^.next_p;            {advance to next derived image}
    end;
{
*   Finish up the HTML output file for this picture.
}
  htm_write_str (hout, '</body></html>', stat);
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
  end;
