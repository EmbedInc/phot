{   Routine for writing various higher level PDOC constructs to a PDOC
*   stream.  These routines are layered on the low level output routines
*   in the PDOC_OUT module.
}
module pdoc_put;
define pdoc_put_fp;
define pdoc_put_fp_sig;
define pdoc_put_fp_fixed;
define pdoc_put_lines;
define pdoc_put_time;
define pdoc_put_timerange;
define pdoc_put_loc;
define pdoc_put_person;
define pdoc_put_people;
define pdoc_put_gcoor;
define pdoc_put_str;
define pdoc_put_strlist;
define pdoc_put_cmd;
define pdoc_put_cmdlist;
%include 'pdoc2.ins.pas';
{
********************************************************************************
*
*   Subroutine PDOC_PUT_FP (OUT, FP, STAT)
*
*   Write the floating point value FP as a free format token to the PDOC
*   output stream.
}
procedure pdoc_put_fp (                {write floating point value to PDOC stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      fp: double;                  {floating point value to write}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  tk: string_var80_t;                  {scratch string}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_fp_free (tk, fp, 7);        {make floating point value string}
  pdoc_out_token (out, tk, stat);      {write token to PDOC output stream}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PUT_FP_FIXED (OUT, FP, N, STAT)
*
*   Write the floating point value FP as a free format token to the PDOC
*   output stream.  The floating point string will have N fraction digits.
}
procedure pdoc_put_fp_fixed (          {write FP to PDOC stream, N fraction digits}
  in out  out: pdoc_out_t;             {output stream state}
  in      fp: double;                  {floating point value to write}
  in      n: sys_int_machine_t;        {fixed number of fraction digits}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  tk: string_var80_t;                  {scratch string}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_fp_fixed (tk, fp, n);       {make floating point string}
  pdoc_out_token (out, tk, stat);      {write token to PDOC output stream}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PUT_FP_SIG (OUT, FP, N, STAT)
*
*   Write the floating point value FP as a free format token to the PDOC
*   output stream.  The floating point string will have at least N significant
*   digits.
}
procedure pdoc_put_fp_sig (            {write FP to PDOC stream, N significant digits}
  in out  out: pdoc_out_t;             {output stream state}
  in      fp: double;                  {floating point value to write}
  in      n: sys_int_machine_t;        {minimum number of significant digits}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  tk: string_var80_t;                  {scratch string}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_fp_free (tk, fp, n);        {make floating point string}
  pdoc_out_token (out, tk, stat);      {write token to PDOC output stream}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PUT_LINES (OUT, LINES_P, STAT)
*
*   Write the list of data lines pointed to by LINES_P to the PDOC output
*   stream.  The first data line will start on a new PDOC line.
}
procedure pdoc_put_lines (             {write list of data lines to PDOC stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      lines_p: pdoc_lines_p_t;     {pointer to first line in list, may be NIL}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  ent_p: pdoc_lines_p_t;               {pointer to current list entry}

begin
  pdoc_out_buf (out, stat);            {make sure to start on a new line}
  if sys_error(stat) then return;

  ent_p := lines_p;                    {init pointer to first list entry}
  while ent_p <> nil do begin          {once for each line in the list}
    pdoc_out_str (                     {write this line to output stream}
      out,                             {output stream state}
      ent_p^.line_p^,                  {string to write}
      ent_p^.fmt,                      {format for this line}
      stat);
    if sys_error(stat) then return;
    ent_p := ent_p^.next_p;            {advance to next line in the list}
    end;
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PUT_TIME (OUT, TIME, TZONE, STAT)
*
*   Write the exact local time represented by TIME to the PDOC output
*   stream.  TZONE is the offset of the local time zone in hours west of
*   CUT (Greenwich).
}
procedure pdoc_put_time (              {write time specifier to PDOC stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      time: sys_clock_t;           {time to represent}
  in      tzone: real;                 {time zone in hours west of CUT}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  date: sys_date_t;                    {expanded date descriptor}
  buf: string_var80_t;                 {time token is accumulated here}
  tk: string_var80_t;                  {scratch token}

begin
  buf.max := size_char(buf.str);       {init local var strings}
  tk.max := size_char(tk.str);

  buf.len := 0;                        {init accumulated date/time string to empty}

  sys_clock_to_date (                  {create expanded date from time value}
    time,                              {time value}
    sys_tzone_other_k,                 {time zone identifier}
    tzone,                             {hours west of Greenwich}
    sys_daysave_no_k,                  {no apply daylight savings, already built into TZONE}
    date);                             {returned expanded date descriptor}

  sys_date_string (                    {make year token in TK}
    date,
    sys_dstr_year_k,
    string_fw_freeform_k,
    tk,
    stat);
  if sys_error(stat) then return;
  string_append (buf, tk);

  string_append1 (buf, '/');
  sys_date_string (                    {make month token in TK}
    date,
    sys_dstr_mon_k,
    string_fw_freeform_k,
    tk,
    stat);
  if sys_error(stat) then return;
  string_append (buf, tk);

  string_append1 (buf, '/');
  sys_date_string (                    {make day token in TK}
    date,
    sys_dstr_day_k,
    string_fw_freeform_k,
    tk,
    stat);
  if sys_error(stat) then return;
  string_append (buf, tk);

  string_append1 (buf, '.');
  sys_date_string (                    {make hour token in TK}
    date,
    sys_dstr_hour_k,
    string_fw_freeform_k,
    tk,
    stat);
  if sys_error(stat) then return;
  string_append (buf, tk);

  string_append1 (buf, ':');
  sys_date_string (                    {make minute token in TK}
    date,
    sys_dstr_min_k,
    string_fw_freeform_k,
    tk,
    stat);
  if sys_error(stat) then return;
  string_append (buf, tk);

  string_append1 (buf, ':');
  sys_date_string (                    {make seconds token in TK}
    date,
    sys_dstr_sec_frac_k,
    6,
    tk,
    stat);
  if sys_error(stat) then return;
  string_append (buf, tk);

  pdoc_out_token (out, buf, stat);     {write time string token to PDOC stream}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PUT_TIMERANGE (OUT, RANGE_P, TZONE, STAT)
*
*   Write the two time tokens specifying the range of time pointed to by
*   RANGE_P.  RANGE_P may be NIL to indicate no argument is to be written.
*   TZONE is the time zone offset to write the time values in, in hours
*   west of CUT.
}
procedure pdoc_put_timerange (         {write time range tokens to PDOC stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      range_p: pdoc_timerange_p_t; {pointer to time range descriptor}
  in      tzone: real;                 {time zone in hours west of CUT}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}
  if range_p = nil then return;        {nothing to do ?}

  pdoc_put_time (out, range_p^.time1, tzone, stat);
  if sys_error(stat) then return;
  pdoc_put_time (out, range_p^.time2, tzone, stat);
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PUT_LOC (OUT, LOC_P, STAT)
*
*   Write a location hierarchy to the PDOC output stream.  LOC_P is pointing
*   to the start of the hierarchy list.  LOC_P may be NIL to indicate nothing
*   should be written.
}
procedure pdoc_put_loc (               {write location hierarchy to PDOC stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      loc_p: pdoc_strent_p_t;      {pointer to start of location hierarchy list}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  ent_p: pdoc_strent_p_t;              {pointer to curren list entry}
  tk: string_var8192_t;                {scratch token}

begin
  tk.max := size_char(tk.str);         {init local var string}
  sys_error_none (stat);               {init to no error encountered}

  ent_p := loc_p;                      {init pointer to first list entry}
  while ent_p <> nil do begin          {once for each list entry}
    string_copy (ent_p^.str_p^, tk);   {make copy of hierarchy name}
    if ent_p^.next_p <> nil then begin {another location name will follow ?}
      string_append1 (tk, ';');        {add name terminator}
      end;
    pdoc_out_str (out, tk, pdoc_format_free_k, stat); {write name to output stream}
    if sys_error(stat) then return;
    ent_p := ent_p^.next_p;            {advance to the next list entry}
    end;                               {back and process this new list entry}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PUT_PERSON (OUT, PERS, STAT)
*
*   Write the contents of the person descriptor PERS to the PDOC output file.
}
procedure pdoc_put_person (            {write info about one person to PDOC stream}
  in out  out: pdoc_out_t;             {output stream state}
  in out  pers: pdoc_person_t;         {person information}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  tk: string_var8192_t;                {scratch token}

begin
  tk.max := size_char(tk.str);         {init local var string}
{
*   Write "person" command.
}
  pdoc_out_cmd_str (out, 'person', stat); {start a new command}
  if sys_error(stat) then return;

  tk.len := 0;
  if pers.name_p <> nil then begin     {reference name exists ?}
    string_copy (pers.name_p^, tk);
    end;
  string_append1 (tk, ';');            {add terminating character}
  pdoc_out_str (out, tk, pdoc_format_free_k, stat);
  if sys_error(stat) then return;

  tk.len := 0;
  if pers.fname_p <> nil then begin    {full name exists ?}
    string_copy (pers.fname_p^, tk);
    end;
  if pers.desc_p <> nil then begin     {another token will follow ?}
    string_append1 (tk, ';');          {add terminating character}
    end;
  pdoc_out_str (out, tk, pdoc_format_free_k, stat);
  if sys_error(stat) then return;

  if pers.desc_p <> nil then begin     {description lines exist ?}
    pdoc_put_lines (out, pers.desc_p, stat); {write description lines}
    end;
{
*   Write "personData" commands for any additional data about this person.
}
  if pers.pic_p <> nil then begin      {picture exists ?}
    pdoc_out_cmd_str (out, 'personData', stat); {start command}
    string_copy (pers.name_p^, tk);
    string_append1 (tk, ';');
    pdoc_out_str (out, tk, pdoc_format_free_k, stat); {write person short name}
    if sys_error(stat) then return;

    string_vstring (tk, 'pic'(0), -1); {PIC keyword}
    string_append_token (tk, pers.pic_p^); {append image file name}
    pdoc_out_str (out, tk, pdoc_format_free_k, stat);
    if sys_error(stat) then return;
    end;

  if pers.wikitree_p <> nil then begin {WikiTree ID exists ?}
    pdoc_out_cmd_str (out, 'personData', stat); {start command}
    string_copy (pers.name_p^, tk);
    string_append1 (tk, ';');
    pdoc_out_str (out, tk, pdoc_format_free_k, stat); {write person short name}
    if sys_error(stat) then return;

    string_vstring (tk, 'WikiTree'(0), -1); {WIKITREE keyword}
    string_append_token (tk, pers.wikitree_p^); {append WikiTree ID}
    pdoc_out_str (out, tk, pdoc_format_free_k, stat);
    if sys_error(stat) then return;
    end;

  pers.wr := true;                     {indicate person definition written to output}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PUT_PEOPLE (OUT, LIST_P, STAT)
*
*   Write the reference names for a list of people.  LIST_P points to the start
*   of the list.  LIST_P may be NIL to indicate nothing should be written.
}
procedure pdoc_put_people (            {write list of people reference names to PDOC}
  in out  out: pdoc_out_t;             {output stream state}
  in      list_p: pdoc_perent_p_t;     {pointer to first entry in the list}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  ent_p: pdoc_perent_p_t;              {pointer to current list entry}
  tk: string_var8192_t;                {scratch token}

begin
  tk.max := size_char(tk.str);         {init local var string}
  sys_error_none (stat);               {init to no error encountered}

  ent_p := list_p;                     {init to first list entry}
  while ent_p <> nil do begin          {once for each list entry}
    if ent_p^.next_p = nil
      then begin                       {this is the last list entry}
        pdoc_out_str (out, ent_p^.ent_p^.name_p^, pdoc_format_free_k, stat);
        end
      else begin                       {another name follows this one}
        string_copy (ent_p^.ent_p^.name_p^, tk);
        string_append1 (tk, ',');      {add terminating character}
        pdoc_out_str (out, tk, pdoc_format_free_k, stat);
        end
      ;
    if sys_error(stat) then return;
    ent_p := ent_p^.next_p;            {advance to next entry in the list}
    end;                               {back to do this new list entry}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PUT_GCOOR (OUT, COOR_P, STAT)
*
*   Write the geographic coordinate pointed to by COOR_P to the PDOC output
*   stream.  Nothing will be writted if COOR_P is NIL.
}
procedure pdoc_put_gcoor (             {write geographic coordinate to PDOC stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      coor_p: pdoc_gcoor_p_t;      {pointer to geographic coordinate info}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}
  if coor_p = nil then return;         {nothing to do ?}

  pdoc_put_fp_fixed (out, coor_p^.lat, 6, stat);
  if sys_error(stat) then return;
  pdoc_put_fp_fixed (out, coor_p^.lon, 6, stat);
  if sys_error(stat) then return;
  pdoc_put_fp_fixed (out, coor_p^.rad, 1, stat);
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PUT_STR (OUT, STR_P, STAT)
*
*   Write the string pointed to by STR_P to the PDOC output stream as free
*   format data.  Nothing will be written if STR_P is NIL.
}
procedure pdoc_put_str (               {write free format string to PDOC out stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      str_p: string_var_p_t;       {pointer to string}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}
  if str_p = nil then return;          {nothing to do}

  pdoc_out_str (out, str_p^, pdoc_format_free_k, stat);
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PUT_STRLIST (OUT, LIST_P, STAT)
*
*   Write the list of free format strings pointed to by LIST_P to the PDOC
*   output stream.  Nothing will be done if LIST_P is NIL.
}
procedure pdoc_put_strlist (           {write list of free format strings to PDOC out stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      list_p: pdoc_strent_p_t;     {pointer to list of strings}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  str_p: pdoc_strent_p_t;              {pointer to the current string list entry}
  sep: string_var4_t;                  {separator between strings in a list}

begin
  sys_error_none (stat);               {init to no error encountered}
  sep.max := size_char(sep.str);
  sep.str[1] := ';';
  sep.len := 1;

  str_p := list_p;                     {init pointer to first list entry}
  while str_p <> nil do begin          {once for each string in the list}
    pdoc_put_str (out, str_p^.str_p, stat);
    if sys_error(stat) then return;
    str_p := str_p^.next_p;            {advance to the next string in the list}
    if str_p <> nil then begin         {another string will follow ?}
      pdoc_out_token (out, sep, stat); {write separator between the strings}
      if sys_error(stat) then return;
      end;
    end;                               {back to do next string in list}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PUT_CMD (OUT, CMD, STAT)
*
*   Write the escape command described by CMD to the PDOC output stream OUT.
}
procedure pdoc_put_cmd (               {write one escape command to PDOC file}
  in out  out: pdoc_out_t;             {output stream state}
  in      cmd: pdoc_cmd_t;             {the escape command to write}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  tk: string_var132_t;                 {full command name}
  line_p: pdoc_lines_p_t;              {pointer to current command data lines list entry}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_vstring (tk, 'X', 1);         {first character of all escape commands}
  string_append (tk, cmd.org);         {add lower case organization name}
  string_append (tk, cmd.cmd);         {add specific command name}
  pdoc_out_cmd (out, tk, stat);        {start the new command}
  if sys_error(stat) then return;

  line_p := cmd.lines_p;               {init to first command data line in list}
  while line_p <> nil do begin         {once for each data line of this command}
    pdoc_out_str (out, line_p^.line_p^, line_p^.fmt, stat); {write this line}
    if sys_error(stat) then return;
    line_p := line_p^.next_p;          {advance to next data line in this command}
    end;                               {back to write this next data line}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PUT_CMDLIST (OUT, LIST_P, STAT)
*
*   Write the list of escape commands pointed to by LIST_P to the PDOC output
*   stream OUT.  Nothing is done if LIST_P is NIL.
}
procedure pdoc_put_cmdlist (           {write list of escape commands to PDOC file}
  in out  out: pdoc_out_t;             {output stream state}
  in      list_p: pdoc_cmdent_p_t;     {pointer to start of list, may be NIL}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  cmd_p: pdoc_cmdent_p_t;              {points to current command descriptor}

begin
  sys_error_none (stat);               {init to no error encountered}

  cmd_p := list_p;                     {init pointer to first command in list}
  while cmd_p <> nil do begin          {once for each command in the list}
    if cmd_p^.ent_p <> nil then begin
      pdoc_put_cmd (out, cmd_p^.ent_p^, stat); {write this command}
      end;
    cmd_p := cmd_p^.next_p;            {advance to next command in list}
    end;
  end;
