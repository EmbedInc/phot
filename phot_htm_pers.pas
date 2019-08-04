{   Routines for writing people information to HTML files.
}
module phot_htm_pers;
define phot_pers_page;
define phot_link_wikilink_start;
define phot_link_wikilink_end;
define phot_htm_persref_write;
define phot_htm_pers_write;
%include 'phot2.ins.pas';
{
********************************************************************************
*
*   Function PHOT_PERS_PAGE (PERS)
*
*   Returns TRUE if the person description contains enough information such that
*   a web page for this person should be created.
}
function phot_pers_page (              {find if person should have private web page}
  in      pers: pdoc_person_t)         {the person inquiring about}
  :boolean;                            {this person should have a web page}
  val_param;

begin
  phot_pers_page :=
    (pers.desc_p <> nil) or            {description text exists ?}
    (pers.pic_p <> nil);               {portrait exists ?}
  end;
{
********************************************************************************
*
*   Local subroutine PHOT_LINK_WIKITREE_START (HOUT, PERS, STAT)
*
*   Write the start of a HTML link to the WikiTree profile, if the WikiTree URL
*   is known.  HOUT is the HTML writing state, and PERS is the person
*   descriptor.
}
procedure phot_link_wikitree_start (   {start link to WikiTree, if target is known}
  in out  hout: htm_out_t;             {HTML writing state}
  in      pers: pdoc_person_t;         {person info}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  fnam: string_treename_t;

begin
  fnam.max := size_char(fnam.str);     {init local var string}
  sys_error_none (stat);               {init to no error encountered}

  if pers.wikitree_p = nil then return; {no link info, nothing to do ?}

  string_vstring (                     {build URL in quotes}
    fnam, '"https://www.wikitree.com/wiki/'(0), -1);
  string_append (fnam, pers.wikitree_p^);
  string_append1 (fnam, '"');

  htm_write_str (hout, '<a href='(0), stat);
  if sys_error(stat) then return;
  htm_write_vstr (hout, fnam, stat);
  if sys_error(stat) then return;

  htm_write_str (hout, ' title="Click to go to WikiTree profile">'(0), stat);
  htm_write_nopad (hout);
  end;
{
********************************************************************************
*
*   Local subroutine PHOT_LINK_WIKITREE_END (HOUT, PERS, STAT)
*
*   End the HTML link started with PHOT_LINK_WIKITREE_START, if any.
}
procedure phot_link_wikitree_end (     {end link to WikiTree, if target is known}
  in out  hout: htm_out_t;             {HTML writing state}
  in      pers: pdoc_person_t;         {person info}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}

  htm_write_nopad (hout);
  if pers.wikitree_p = nil then return; {no link info, nothing to do ?}

  htm_write_str (hout, '</a>'(0), stat);
  htm_write_nopad (hout);
  end;
{
********************************************************************************
*
*   Subroutine PHOT_HTM_PERSREF_WRITE (HOUT, PERS, STAT)
*
*   Write the reference to a person in a HTML output file.  The person's full
*   name will always be shown.  This will be a clickable link to the person's
*   specific page if one exists, or a link to their WikiTree page if no specific
*   page for the person exists but the WikiTree ID is known.
}
procedure phot_htm_persref_write (     {write person reference, will be link if info known}
  in out  hout: htm_out_t;             {HTM file writing state}
  in      pers: pdoc_person_t;         {person info}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  fnam: string_treename_t;
  tk: string_var32_t;                  {scratch token}

begin
  fnam.max := size_char(fnam.str);     {init local var strings}
  tk.max := size_char(tk.str);
  sys_error_none (stat);               {init to no error encountered}

  if pers.fname_p = nil then return;   {no full name, nothing to write ?}
{
*   Write link to our specific page for this person, if such a page exists.
}
  if phot_pers_page (pers) then begin  {link to specific page for this person ?}

    string_vstring (fnam, '"pers'(0), -1); {build URL in quotes}
    string_f_int (tk, pers.intid);
    string_append (fnam, tk);
    string_appends (fnam, '.htm"'(0));

    htm_write_str (hout, '<a href='(0), stat);
    if sys_error(stat) then return;
    htm_write_nopad (hout);
    htm_write_vstr (hout, fnam, stat);
    if sys_error(stat) then return;

    htm_write_nopad (hout);
    htm_write_str (hout, '>'(0), stat);
    if sys_error(stat) then return;
    htm_write_vstr (hout, pers.fname_p^, stat);
    if sys_error(stat) then return;
    htm_write_nopad (hout);
    htm_write_str (hout, '</a>'(0), stat);
    return;
    end;
{
*   Write the name wrapped in a link to the WikiTree profile page, if this
*   page is known.  If not, just the bare name is written without being in a
*   link.
}
  phot_link_wikitree_start (hout, pers, stat); {start link to WikiTree, if known}
  if sys_error(stat) then return;
  htm_write_vstr (hout, pers.fname_p^, stat); {write the person name}
  if sys_error(stat) then return;
  phot_link_wikitree_end (hout, pers, stat); {write link end if wrote link start}
  end;
{
********************************************************************************
*
*   Subroutine PHOT_HTM_PERS_WRITE (PERS, STAT)
*
*   Write the HTML file for a specific person, if there is enough information
*   about the person to make this worthwhile.
*
*   The file for a person will be in the HTML subdirectory, and will have the
*   name PERSxx.HTM.  XX is the unique integer ID of the person in this system.
*   These numbers are arbitrarily assigned, but unique per person.  This ID
*   must be assigned before this routine is called.
*
*   The current directory is assumed to be one level above the HTML directory.
*   Specifically, the pathname of the person page will be "html/pers<id>.htm",
*   such as "html/pers27.htm" for example.
}
procedure phot_htm_pers_write (        {write HTM file for a person, if sufficient info}
  in      pers: pdoc_person_t;         {person info}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  pid: string_var32_t;                 {person ID string}
  tk: string_var8192_t;                {scratch long string}
  tk2: string_var32_t;                 {scratch short string}
  hout: htm_out_t;                     {HTML file writing state}
  tf: boolean;                         {TRUE/FALSE value returned by program}
  exstat: sys_sys_exstat_t;            {program exit status code}

begin
  pid.max := size_char(pid.str);       {init local var strings}
  tk.max := size_char(tk.str);
  tk2.max := size_char(tk2.str);
  sys_error_none (stat);               {init to no error encountered}

  if not phot_pers_page (pers) then return; {not enough info to write page ?}

  if pers.intid <= 0 then begin        {ID not assigned or invalid ?}
    sys_stat_set (pdoc_subsys_k, pdoc_stat_badpersid_k, stat);
    sys_stat_parm_vstr (pers.name_p^, stat);
    return;
    end;
  string_f_int (pid, pers.intid);      {make unique person ID string}
{
*   Open HTML file for writing.
}
  string_vstring (tk, 'html/pers'(0), -1); {init HTML file name}
  string_append (tk, pid);             {add person unique ID number}
  htm_open_write_name (hout, tk, stat); {open HTML file for writing to it}
  if sys_error(stat) then return;
{
*   Start HTML file, write HEAD and TITLE.
}
  htm_write_str (hout, '<html><head><title>'(0), stat);
  if sys_error(stat) then return;
  htm_write_nopad (hout);
  if pers.fname_p <> nil then begin    {full name ?}
    htm_write_vstr (hout, pers.fname_p^, stat);
    if sys_error(stat) then return;
    htm_write_nopad (hout);
    end;
  htm_write_str (hout, '</title></head>'(0), stat);
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
{
*   Start BODY, set forground and background colors.
}
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
  htm_write_bline (hout, stat);
  if sys_error(stat) then return;
{
*   Show picture, if available.
}
  if pers.pic_p <> nil then begin      {picture is available ?}
    {
    *   Make the protrait image of this person.
    }
    writeln ('Creating portrait image from ', pers.pic_p^.str:pers.pic_p^.len);

    string_vstring (tk, 'image_resize -in '(0), -1); {build the IMAGE_RESIZE command line}
    string_append_token (tk, pers.pic_p^);
    string_appends (tk, ' -out html/pers'(0));
    string_append (tk, pid);
    string_appends (tk, '.jpg -fit'(0));
    string_f_int (tk2, phot_portrait_dim);
    string_append_token (tk, tk2);
    string_append_token (tk, tk2);
    string_appends (tk, ' -form "-qual 100"'(0));
    sys_run_wait_stdsame (             {run the command line in TK}
      tk, tf, exstat, stat);
    if sys_error(stat) then return;
    {
    *   Write a reference to the portrait image to the HTM file.  This will be a
    *   link to the person's WikiTree page, if known.
    }
    htm_write_str (hout, '<center>'(0), stat);
    if sys_error(stat) then return;
    htm_write_indent (hout);
    phot_link_wikitree_start (hout, pers, stat); {start link to WikiTree profile}
    if sys_error(stat) then return;

    string_vstring (tk, '"pers'(0), -1); {build URL in quotes}
    string_append (tk, pid);
    string_appends (tk, '.jpg"'(0));

    htm_write_str (hout, '<img src='(0), stat);
    if sys_error(stat) then return;
    htm_write_vstr (hout, tk, stat);
    if sys_error(stat) then return;
    htm_write_str (hout, ' border=0 vspace=5>'(0), stat);
    if sys_error(stat) then return;
    phot_link_wikitree_end (hout, pers, stat); {end link to WikiTree profile}
    if sys_error(stat) then return;
    htm_write_str (hout, '<br clear=all></center>'(0), stat);
    if sys_error(stat) then return;
    htm_write_undent (hout);
    htm_write_bline (hout, stat);
    if sys_error(stat) then return;
    end;
{
*   Write full name.  This will also be a clickable link to the person's
*   WikiTree profile, if known.
}
  if pers.fname_p <> nil then begin    {full name ?}
    htm_write_str (hout, '<br><p><h2>'(0), stat);
    htm_write_indent (hout);
    if sys_error(stat) then return;
    phot_link_wikitree_start (hout, pers, stat); {start link to WikiTree profile}
    if sys_error(stat) then return;
    htm_write_vstr (hout, pers.fname_p^, stat);
    if sys_error(stat) then return;
    phot_link_wikitree_end (hout, pers, stat); {end link to WikiTree profile}
    if sys_error(stat) then return;
    htm_write_str (hout, '</h2>'(0), stat);
    if sys_error(stat) then return;
    htm_write_undent (hout);
    htm_write_bline (hout, stat);
    if sys_error(stat) then return;
    end;
{
*   Write descrition, if available.
}
  if pers.desc_p <> nil then begin     {there is a description ?}
    htm_write_str (hout, '<br><p>'(0), stat);
    if sys_error(stat) then return;
    htm_write_indent (hout);
    phot_whtm_lines (hout, pers.desc_p, stat);
    if sys_error(stat) then return;
    htm_write_undent (hout);
    htm_write_bline (hout, stat);
    if sys_error(stat) then return;
    end;
{
*   End the HTML file and close it.
}
  htm_write_str (hout, '</body></html>'(0), stat);
  if sys_error(stat) then return;

  htm_close_write (hout, stat);
  if sys_error(stat) then return;
  end;
