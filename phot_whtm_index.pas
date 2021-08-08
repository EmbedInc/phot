{   Write parts of the INDEX.HTM file for a film.
}
module phot_whtm_index;
define phot_whtm_index_head;
define phot_whtm_index_title;
define phot_whtm_index_pic;
define phot_whtm_index_end;
%include 'phot2.ins.pas';
{
********************************************************************************
*
*   Subroutine PHOT_WHTM_INDEX_HEAD (HOUT, PDOC, STAT)
*
*   Write the header of a INDEX.HTM file.  The initial preamble, the HEAD
*   section, and the opening BODY tag is written.
}
procedure phot_whtm_index_head (       {write start of INDEX.HTM and HEAD section}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      pdoc: pdoc_t;                {the pictures of the film this file is for}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
{
*   Write HTML tag.
}
  htm_write_str (hout, '<html lang="en-US">'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
{
*   Write HEAD section.
}
  htm_write_str (hout, '<head>'(0), stat); {start HEAD}
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
  htm_write_indent (hout);

  htm_write_str (hout,                 {LINK}
    '<link rel="stylesheet" href="html/phot.css"></link>'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;

  htm_write_str (hout, '<title>'(0), stat); {TITLE start}
  if sys_error(stat) then return;
  htm_write_indent (hout);
  htm_write_nopad (hout);

  if                                   {film name is available ?}
      (pdoc.pics_p <> nil) and then
      (pdoc.pics_p^.ent_p^.film_p <> nil)
      then begin
    htm_write_str (hout, 'Film '(0), stat);
    if sys_error(stat) then return;
    htm_write_vstr (hout, pdoc.pics_p^.ent_p^.film_p^, stat);
    if sys_error(stat) then return;
    htm_write_nopad (hout);
    end;

  htm_write_str (hout, '</title>'(0), stat); {TITLE end}
  if sys_error(stat) then return;
  htm_write_undent (hout);
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;

  htm_write_str (hout, '</head>'(0), stat); {HEAD end}
  if sys_error(stat) then return;
  htm_write_undent (hout);
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
{
*   Start BODY section.
}
  htm_write_str (hout, '<body>'(0), stat); {opening BODY tag}
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;

  htm_write_newline (hout, stat);      {leave blank line before real content}
  if sys_error(stat) then return;
  end;
{
********************************************************************************
*
*   Subroutine PHOT_WHTM_INDEX_TITLE (HOUT, TITLE, STAT)
*
*   Write the visible title to the INDEX.HTM file.
}
procedure phot_whtm_index_title (      {write title to INDEX.HTM file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      title: univ string_var_arg_t; {title string to write}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  htm_write_str (hout, '<h1 class="page">'(0), stat); {start the title}
  if sys_error(stat) then return;
  htm_write_indent (hout);
  htm_write_nopad (hout);

  htm_write_vstr (hout, title, stat);  {write the title string}
  if sys_error(stat) then return;
  htm_write_nopad (hout);

  htm_write_str (hout, '</h1>'(0), stat); {end the title}
  if sys_error(stat) then return;
  htm_write_undent (hout);

  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
  end;
{
********************************************************************************
*
*   Subroutine PHOT_WHTM_INDEX_PIC (HOUT, FNAME, STAT)
*
*   Write the thumbnail picture NAME to the INDEX.HTM file.  The thumbnail will
*   be a link to the HTML page specific to that picture.  FNAME is the name of
*   the thumbnail image file name.  When this is not in the current film
*   directory, then the picture name will be shown starting with the film name
*   followed by a dash, followed by the picture name.
}
procedure phot_whtm_index_pic (        {write thumbnail picture with ref to pic page}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      fname: univ string_var_arg_t; {image file to show as thumbnail}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  tnam: string_treename_t;             {full treename of thumbnail image}
  lnam: string_leafname_t;             {image file leafname}
  gnam: string_leafname_t;             {image file generic name (no suffix)}
  film: string_leafname_t;             {film directory leafname}
  rnam: string_treename_t;             {thumbnail ref relative to this file}
  dir1, dir2: string_treename_t;       {scratch directory names}
  name: string_var80_t;                {name to show with thumbnail}

begin
  tnam.max := size_char(tnam.str);     {init local var strings}
  lnam.max := size_char(lnam.str);
  gnam.max := size_char(gnam.str);
  film.max := size_char(film.str);
  rnam.max := size_char(rnam.str);
  dir1.max := size_char(dir1.str);
  dir2.max := size_char(dir2.str);
  name.max := size_char(name.str);

  string_treename (fname, tnam);       {make full image file treename}

  string_pathname_split (              {make image file leaf name and parent dir}
    tnam, dir1, lnam);
  string_pathname_split (              {make DIR2 pathname of film dir pic is in}
    dir1, dir2, name);
  string_pathname_split (              {make image file film dir leafname}
    dir2, name, film);

  string_pathname_split (              {make DIR1 dir that this HTML file is in}
    hout.conn.tnam, dir1, name);

  string_generic_fnam (                {make generic image file name}
    lnam,                              {file name with file type suffix}
    '.jpg .tif .gif',                  {list of possible suffixes}
    gnam);                             {returned generic image name}

  if string_equal(dir1, dir2)
    then begin                         {image is local in this film dir}
      string_vstring (rnam, '200/'(0), -1); {make rel reference to image file}
      string_append (rnam, lnam);
      string_copy (gnam, name);        {show just the image generic name}
      end
    else begin                         {image is in remote film dir}
      string_copy (tnam, rnam);        {use full treename for image file name}
      string_copy (film, name);        {make image file name to display}
      string_append1 (name, '-');
      string_append (name, gnam);
      end
    ;
{
*   Start the table.
}
  htm_write_str (hout, '<table>'(0), stat); {start TABLE}
  if sys_error(stat) then return;
  htm_write_indent (hout);
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;

  htm_write_str (hout, '<tbody>'(0), stat); {start table body}
  if sys_error(stat) then return;
  htm_write_indent (hout);
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
{
*   Table row 1.  Write thumbnail image which is a link to the page for that
*   picture.
}
  htm_write_str (hout, '<tr>'(0), stat); {start this row}
  if sys_error(stat) then return;
  htm_write_indent (hout);
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;

  htm_write_str (hout, '<td>'(0), stat); {start the cell for the thumbnail picture}
  if sys_error(stat) then return;
  htm_write_indent (hout);
  htm_write_nopad (hout);

  htm_write_str (hout, '<a href="'(0), stat);
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  htm_write_str (hout, 'html/'(0), stat); {file that link references}
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  htm_write_vstr (hout, gnam, stat);
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  htm_write_str (hout, '.htm"><img src="'(0), stat);
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  htm_write_vstr (hout, rnam, stat);   {picture pathname}
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  htm_write_str (hout, '"></a>'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;

  htm_write_undent (hout);             {end this table cell}
  htm_write_undent (hout);             {end this table row}
{
*   Table row 2.  Write the picture name.
}
  htm_write_str (hout, '<tr>'(0), stat); {start this row}
  if sys_error(stat) then return;
  htm_write_indent (hout);
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;

  htm_write_str (hout, '<td>'(0), stat); {start cell for picture name}
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  htm_write_vstr (hout, name, stat);   {write picture name}
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;

  htm_write_undent (hout);             {end this table row}
{
*   End the table.
}
  htm_write_str (hout, '</tbody>'(0), stat); {end the table body}
  if sys_error(stat) then return;
  htm_write_undent (hout);
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;

  htm_write_str (hout, '</table>'(0), stat); {end the whole table}
  if sys_error(stat) then return;
  htm_write_undent (hout);
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
  end;
{
********************************************************************************
*
*   Subroutine PHOT_WHTM_INDEX_END (HOUT, PDOC, STAT)
*
*   Write the ending of the INDEX.HTM file.  This is the part after the content,
*   which is usually thumbnail pictures.
}
procedure phot_whtm_index_end (        {write ending of INDEX.HTM file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      pdoc: pdoc_t;                {the pictures of the film this file is for}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  htm_write_newline (hout, stat);      {add blank line before ending}
  if sys_error(stat) then return;

  htm_write_str (hout, '</body></html>'(0), stat); {end the BODY and whole HTML block}
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
  end;
