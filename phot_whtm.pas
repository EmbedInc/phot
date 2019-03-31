{   Module of routines to write higher level data structures to an HTML
*   output file.  These routines are layered on the low level HTML output
*   routines in the STUFF library.
}
module phot_whtm;
define phot_whtm_lines;
define phot_whtm_loc;
define phot_whtm_people;
define phot_whtm_geoang;
define phot_whtm_geocoor;
define phot_whtm_strlist;
%include 'phot2.ins.pas';
{
****************************************************************************
*
*   Subroutine PHOT_WHTM_LINES (HOUT, LINES_P, STAT);
*
*   Write the data lines pointed to by LINES_P to an HTML output file.
*   LINES_P may be NIL, in which case nothing is written.  HOUT is the
*   HTML file writing state.
}
procedure phot_whtm_lines (            {write PDOC data lines to HTML file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      lines_p: pdoc_lines_p_t;     {pointer to start of lines list, may be NIL}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  ent_p: pdoc_lines_p_t;               {pointer to current lines list entry}

label
  next_line;

begin
  sys_error_none (stat);               {init to no error encountered}
  if lines_p = nil then return;        {nothing to do ?}

  htm_write_newline (hout, stat);      {start any new text on a new line}
  if sys_error(stat) then return;

  ent_p := lines_p;                    {init to first lines list entry}
  while ent_p <> nil do begin          {once for each line in the lines list}
    case ent_p^.fmt of                 {what is the format of this line ?}
{
*   Handle fixed format line.  This is written as HTML PRE (pre-formatted)
*   text.
}
pdoc_format_fixed_k: begin
  if                                   {check for special case of single blank line}
      ((ent_p^.prev_p = nil) or else   {previous line has different format ?}
        (ent_p^.prev_p^.fmt <> ent_p^.fmt)) and
      ((ent_p^.next_p = nil) or else   {next line has different format ?}
        (ent_p^.next_p^.fmt <> ent_p^.fmt)) and
      (ent_p^.line_p^.len <= 0)        {this line is empty ?}
      then begin
    htm_write_buf (hout, stat);        {write previous partial line, if any}
    if sys_error(stat) then return;
    htm_write_str (hout, '<p>', stat); {write HTML tag to start a new paragraph}
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);    {force line to be closed now}
    if sys_error(stat) then return;
    goto next_line;                    {done with this line, on to next}
    end;
  if (ent_p^.prev_p = nil) or else (ent_p^.prev_p^.fmt <> ent_p^.fmt)
      then begin                       {previous line wasn't in this format ?}
    htm_write_pre_start (hout, stat);  {set up for writing preformatted text}
    if sys_error(stat) then return;
    end;
  htm_write_pre_line (hout, ent_p^.line_p^, stat); {write preformatted line to HTML file}
  if sys_error(stat) then return;
  if (ent_p^.next_p = nil) or else (ent_p^.next_p^.fmt <> ent_p^.fmt)
      then begin                       {next line isn't in this format ?}
    htm_write_pre_end (hout, stat);    {exit preformatted text mode}
    if sys_error(stat) then return;
    end;
  end;
{
*   Handle all remaining format types as free format.
}
otherwise
      htm_write_vstr (hout, ent_p^.line_p^, stat); {write line as free format text}
      if sys_error(stat) then return;
      end;

next_line:                             {done processing the current line}
    ent_p := ent_p^.next_p;            {advance to next line in the list}
    end;                               {back to do this new list entry}
  end;
{
****************************************************************************
*
*   PHOT_WHTM_LOC (HOUT, LOC_P, STAT)
*
*   Write location names hierarchy to the HTML file open on HOUT.  LOC_P may
*   be NIL, in which case nothing is written.
}
procedure phot_whtm_loc (              {write PDOC location hierarchy to HTM file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      loc_p: pdoc_strent_p_t;      {pointer to start of loc list, may be NIL}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  ent_p: pdoc_strent_p_t;              {pointer to current list entry}

begin
  sys_error_none (stat);               {init to no error encountered}

  ent_p := loc_p;                      {init to first entry in location names list}
  while ent_p <> nil do begin          {once for each entry in the list}
    if ent_p^.prev_p <> nil then begin {this is not first hierarchy level ?}
      htm_write_str (hout, '&gt;'(0), stat); {write separator after previous level}
      if sys_error(stat) then return;
      end;
    htm_write_vstr (hout, ent_p^.str_p^, stat); {write name of this hierarchy level}
    if sys_error(stat) then return;
    ent_p := ent_p^.next_p;            {advance to next location name list entry}
    end;
  end;
{
********************************************************************************
*
*   Subroutine PHOT_WHTM_PEOPLE (HOUT, PEOPLE_P, STAT)
*
*   Write people names to the HTML output file open on HOUT.  PEOPLE_P points
*   to the start of the people list.  It may be NIL, in which case nothing
*   is done.
}
procedure phot_whtm_people (           {write PDOC people names to HTM file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      people_p: pdoc_perent_p_t;   {pointer to start of people list, may be NIL}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  ent_p: pdoc_perent_p_t;              {pointer to current list entry}

begin
  sys_error_none (stat);               {init to no error encountered}

  htm_write_indent (hout);             {indent any wrapped lines}

  ent_p := people_p;                   {init to first entry in list}
  while ent_p <> nil do begin          {once for each entry in the list}
    if ent_p^.prev_p <> nil then begin {this is not first name in the list ?}
      htm_write_nopad (hout);          {no break before next string}
      htm_write_str (hout, ','(0), stat); {write separator after previous name}
      if sys_error(stat) then return;
      end;
    phot_htm_persref_write (           {write full name, may be link}
      hout, ent_p^.ent_p^, stat);
    if sys_error(stat) then return;
    ent_p := ent_p^.next_p;            {advance to next list entry}
    end;

  htm_write_undent (hout);             {restore original indentation level}
  end;
{
****************************************************************************
*
*   Subroutine PHOT_WHTM_GEOANG (HOUT, ANG, STAT)
*
*   Write the geographic coordinate angle ANG to the HTML output file open
*   on HOUT.
}
procedure phot_whtm_geoang (           {write geographic angle to HTML file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      ang: double;                 {angle in degrees, will write absolute value}
  in      nfrac: sys_int_machine_t;    {number of fraction digits}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  tk: string_var32_t;                  {scratch token for number conversion}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_fp_fixed (tk, abs(ang), nfrac); {make angle string}
  string_appends (tk, '&deg;'(0));
  htm_write_vstr (hout, tk, stat);     {write it to the HTML file}
  end;
{
****************************************************************************
*
*   Subroutine PHOT_WHTM_GEOCOOR (HOUT, GCOOR, STAT)
*
*   Write the geographics coordinate specified by GCOOR to the HTML output
*   file open on HOUT.
*
*   The earth's circumference is about 40.075Mm, so 1 degree of a great arc
*   is 111.3Km (69.17 miles) for a worst case lat-lon location rounding
*   error of 78.7Km (48.91 miles).  The worst case error is the resolution
*   divided by the square root of 2 because of the error contributions from
*   each dimension.
}
procedure phot_whtm_geocoor (          {write geographic coordinate to HTML file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      gcoor: pdoc_gcoor_t;         {description of geographic coordinate}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  tk: string_var32_t;                  {scratch token for number conversion}
  ndig: sys_int_machine_t;             {fraction digits to write degrees with}

begin
  tk.max := size_char(tk.str);         {init local var string}

  ndig := 4;                           {default fraction digits for no err radius}
  if gcoor.rad > 0.0 then begin        {there is an error radius ?}
    htm_write_str (hout, 'Within'(0), stat);
    if sys_error(stat) then return;
    string_f_fp (                      {convert FP value to a string}
      tk,                              {output string}
      gcoor.rad,                       {input value}
      0, 0,                            {use free format for mantissa and exponent}
      2,                               {minimum required significant digits}
      7,                               {max digits allowed left of decimal point}
      0,                               {minimum digits required right of point}
      3,                               {max digits allowed right of point}
      [ string_ffp_exp_eng_k,          {use engineering notation if exp used}
        string_ffp_group_k],           {use digits grouping character}
      stat);
    if sys_error(stat) then return;
    htm_write_vstr (hout, tk, stat);
    if sys_error(stat) then return;
    htm_write_str (hout, 'meters of'(0), stat);
    if sys_error(stat) then return;

    ndig := 2;                         {init to minimum fraction digits, 800m error}
    if gcoor.rad < 8000.0 then ndig := 3; {3 digit worst case error = 80m}
    if gcoor.rad < 800.0 then ndig := 4; {4 digit worst case error = 8m}
    if gcoor.rad < 80.0 then ndig := 5; {5 digit worst case error = 800mm}
    end;

  phot_whtm_geoang (hout, gcoor.lat, ndig, stat); {write latitude angle}
  if sys_error(stat) then return;
  if gcoor.lat >= 0.0
    then begin                         {north}
      htm_write_nopad (hout);
      htm_write_str (hout, 'N,'(0), stat);
      if sys_error(stat) then return;
      end
    else begin                         {south}
      htm_write_nopad (hout);
      htm_write_str (hout, 'S,'(0), stat);
      if sys_error(stat) then return;
      end
    ;

  phot_whtm_geoang (hout, gcoor.lon, ndig, stat); {write longitude angle}
  if sys_error(stat) then return;
  if gcoor.lon >= 0.0
    then begin                         {west}
      htm_write_nopad (hout);
      htm_write_str (hout, 'W'(0), stat);
      if sys_error(stat) then return;
      end
    else begin                         {east}
      htm_write_nopad (hout);
      htm_write_str (hout, 'E'(0), stat);
      if sys_error(stat) then return;
      end
    ;
  end;
{
****************************************************************************
*
*   Subroutine PHOT_WHTM_STRLIST (HOUT, FIRST, STAT)
*
*   Write the list of strings starting at FIRST to the HTML output file.
*   If the list contains only one string, then it is written directly
*   to the current location.  If the list contains more than one string
*   then each string is written to appear as a separate indented line
*   as viewed in the final HTML document.
}
procedure phot_whtm_strlist (          {write list of PDOC strings to HTM file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      first: pdoc_strent_t;        {first strings list entry}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  ent_p: pdoc_strent_p_t;              {pointer to current list entry}

begin
{
*   Handle special case of the list contains only a single string.  In this
*   case the string is just written to the current location.
}
  if first.next_p = nil then begin     {list contains only one string ?}
    htm_write_vstr (hout, first.str_p^, stat); {write the string}
    if sys_error(stat) then return;
    htm_write_nopad (hout);
    htm_write_str (hout, '<br>'(0), stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    return;
    end;
{
*   The list contains two or more entries.
}
  htm_write_str (hout, '<br>'(0), stat); {force first string to start on new line}
  if sys_error(stat) then return;
  htm_write_newline (hout, stat);
  if sys_error(stat) then return;
{
*   Write each of the strings in the list.
}
  ent_p := addr(first);                {init to first entry in the list}
  while ent_p <> nil do begin          {once for each list entry}
    htm_write_str (hout, '&nbsp;&nbsp;&nbsp;&nbsp;'(0), stat);
    if sys_error(stat) then return;
    htm_write_nopad (hout);
    htm_write_vstr (hout, ent_p^.str_p^, stat); {write this string}
    if sys_error(stat) then return;
    htm_write_nopad (hout);
    htm_write_str (hout, '<br>'(0), stat);
    if sys_error(stat) then return;
    htm_write_newline (hout, stat);
    if sys_error(stat) then return;
    ent_p := ent_p^.next_p;            {advance to next list entry}
    end;
  end;
