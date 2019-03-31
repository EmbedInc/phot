{   Routines for getting various data items from a PDOC input stream.  These
*   routines are layered on the low level routines in the PDOC_IN module.
}
module pdoc_get;
define pdoc_get_fp;
define pdoc_get_angle;
define pdoc_get_lines;
define pdoc_get_name;
define pdoc_get_semistr;
define pdoc_get_strlist;
define pdoc_get_text;
define pdoc_get_textp;
define pdoc_get_time;
define pdoc_get_timerange;
define pdoc_get_locp;
define pdoc_get_person;
define pdoc_get_personData;
define pdoc_get_people;
define pdoc_get_gcoorp;
%include 'pdoc2.ins.pas';
{
***********************************************************************
*
*   Subroutine PDOC_GET_FP (IN, FP, STAT)
*
*   Get the next PDOC stream token, interpret it as a floating point
*   number, and return its value in FP.  The PDOC format must be FREE.
}
procedure pdoc_get_fp (                {get next token as floating point value}
  in out  in: pdoc_in_t;               {input stream state}
  out     fp: double;                  {returned floating point value}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  tk: string_var256_t;                 {scratch token}

begin
  tk.max := size_char(tk.str);         {init local var string}

  pdoc_in_token (                      {get next token from PDOC input stream}
    in,                                {input stream state}
    tk,                                {returned token}
    ' ',                               {use normal space delimiter rules}
    true,                              {token may be quoted}
    stat);
  if sys_error(stat) then return;

  string_t_fp2 (tk, fp, stat);         {convert token to floating point value}
  end;
{
***********************************************************************
*
*   Subroutine PDOC_GET_ANGLE (IN, ANG, STAT)
*
*   Return the next PDOC stream token as an angle in degrees.  The token
*   format is:
*
*     <degrees>[:<minutes>[:<seconds>]]
}
procedure pdoc_get_angle (             {get next token as angle in degrees:minutes}
  in out  in: pdoc_in_t;               {input stream state}
  out     ang: double;                 {returned angle in degrees}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  tk, tk2: string_var256_t;            {scratch tokens}
  fpx: sys_fp_max_t;                   {scratch FP value}
  p: string_index_t;                   {parse index}
  unused: sys_int_machine_t;
  neg: boolean;                        {TRUE if overall value is negative}

begin
  tk.max := size_char(tk.str);         {init local var strings}
  tk2.max := size_char(tk2.str);

  pdoc_in_token (                      {get next token from PDOC input stream}
    in,                                {input stream state}
    tk,                                {returned token}
    ' ',                               {use normal space delimiter rules}
    true,                              {token may be quoted}
    stat);
  if sys_error(stat) then return;
  p := 1;                              {init TK parse index}

  neg := false;                        {assume positive number}
  if (tk.len >= 1) and (tk.str[1] = '-') then begin {found minus sign ?}
    neg := true;
    end;

  ang := 0.0;                          {init to default value}

  string_token_anyd (                  {extract degrees part into TK2}
    tk,                                {input string}
    p,                                 {parse index}
    ':', 1, 1,                         {delimiters list, N delim, first N repeat}
    [],                                {option flags}
    tk2,                               {returned token}
    unused,                            {number of main delimiter used}
    stat);
  discard( string_eos(stat) );
  if sys_error(stat) then return;

  string_t_fpmax (                     {convert degrees to floating point value}
    tk2,                               {string to convert}
    fpx,                               {output value}
    [string_tfp_null_z_k],             {null string has 0.0 value}
    stat);
  if sys_error(stat) then return;
  ang := fpx;                          {set angle value from degrees part}
  neg := neg or (fpx < 0.0);           {definitely negative if degrees part negative}

  string_token_anyd (                  {extract minutes part into TK2}
    tk,                                {input string}
    p,                                 {parse index}
    ':', 1, 1,                         {delimiters list, N delim, first N repeat}
    [],                                {option flags}
    tk2,                               {returned token}
    unused,                            {number of main delimiter used}
    stat);
  discard( string_eos(stat) );
  if sys_error(stat) then return;

  string_t_fpmax (                     {convert minutes to floating point value}
    tk2,                               {string to convert}
    fpx,                               {output value}
    [string_tfp_null_z_k],             {null string has 0.0 value}
    stat);
  if sys_error(stat) then return;
  if neg
    then begin
      ang := ang - fpx / 60.0;         {add minutes contribution to negative angle}
      end
    else begin
      ang := ang + fpx / 60.0;         {add minutes contribution to positive angle}
      end
    ;

  string_token_anyd (                  {extract seconds part into TK2}
    tk,                                {input string}
    p,                                 {parse index}
    ':', 1, 1,                         {delimiters list, N delim, first N repeat}
    [],                                {option flags}
    tk2,                               {returned token}
    unused,                            {number of main delimiter used}
    stat);
  discard( string_eos(stat) );
  if sys_error(stat) then return;

  string_t_fpmax (                     {convert seconds to floating point value}
    tk2,                               {string to convert}
    fpx,                               {output value}
    [string_tfp_null_z_k],             {null string has 0.0 value}
    stat);
  if sys_error(stat) then return;
  if neg
    then begin
      ang := ang - fpx / 3600.0;       {add seconds contribution to negative angle}
      end
    else begin
      ang := ang + fpx / 3600.0;       {add seconds contribution to positive angle}
      end
    ;
  end;
{
***********************************************************************
*
*   Subroutine PDOC_GET_LINES (IN, MEM, LINES_P, STAT)
*
*   Get the remaining data for the current command as separate lines.  New
*   dynamic memory, if any, will be allocated under the MEM context.  LINES_P
*   will be returned pointing to the start of the lines chain, or NIL if no
*   meaningful lines were encountered.  STAT will not be returned with EOS
*   status.  LINES_P is set to NIL instead.
}
procedure pdoc_get_lines (             {get remaining data as list of text lines}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  out     lines_p: pdoc_lines_p_t;     {pointer to start of chain, may be NIL}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param;

var
  line: string_var8192_t;              {one line input buffer}
  line_p: pdoc_lines_p_t;              {pointer to current line descriptor}
  last_p: pdoc_lines_p_t;              {pointer to previous line descriptor}
  fmt: pdoc_format_k_t;                {format of the last line read in}

label
  loop_line;

begin
  line.max := size_char(line.str);     {init local var string}

  lines_p := nil;                      {init to no lines returned}
  line_p := nil;                       {init to no current line descriptor}

loop_line:                             {back here to get each new input line}
  pdoc_in_line (in, line, fmt, stat);  {get the next raw data line}
  if string_eos(stat) then return;     {hit end of data lines for this command ?}
  if sys_error(stat) then return;      {hard error ?}

  last_p := line_p;                    {save pointer to previous end of chain}
  util_mem_grab (sizeof(line_p^), mem, false, line_p); {allocate new line descriptor}

  line_p^.prev_p := last_p;            {link to previous chain entry}
  line_p^.next_p := nil;               {this is last chain entry}
  if last_p = nil
    then begin                         {this is first entry in chain}
      lines_p := line_p;               {pass back pointer to start of chain}
      end
    else begin                         {there is a previous chain entry}
      last_p^.next_p := line_p;        {link from previous chain entry}
      end
    ;

  line_p^.fmt := fmt;                  {indicate format for this line}
  string_alloc (line.len, mem, false, line_p^.line_p); {allocate memory for string}
  string_copy (line, line_p^.line_p^); {copy the string}
  goto loop_line;                      {back to get next line from the input stream}
  end;
{
***********************************************************************
*
*   Subroutine PDOC_GET_NAME (IN, NAME, STAT)
*
*   Get the next <name> token from the input stream.  These tokens are
*   always in free format lines, and are separated by commas.
}
procedure pdoc_get_name (              {get next <name> token, comma separated}
  in out  in: pdoc_in_t;               {input stream state}
  in out  name: univ string_var_arg_t; {returned name token, always upper case}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  pdoc_in_token (                      {extract next token, requires free format}
    in,                                {input stream state}
    name,                              {returned token}
    ',',                               {delimiter character}
    false,                             {quotes have no special meaning}
    stat);
  if sys_error(stat) then return;
  end;
{
***********************************************************************
*
*   Subroutine PDOC_GET_SEMISTR (IN, STR, STAT)
*
*   Get the next string token.  These tokens are separated by semicolons.
*   Free format is required.
}
procedure pdoc_get_semistr (           {get next string token, semicolon separated}
  in out  in: pdoc_in_t;               {input stream state}
  in out  str: univ string_var_arg_t;  {returned string}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  pdoc_in_token (                      {extract next token, requires free format}
    in,                                {input stream state}
    str,                               {returned token}
    ';',                               {delimiter character}
    false,                             {quotes have no special meaning}
    stat);
  end;
{
***********************************************************************
*
*   Subroutine PDOC_GET_STRLIST (IN, MEM, STR_P, STAT)
*
*   Get a list of strings separated by semicolons.  Free format is required.
*   STR_P will be returned pointing to the entry for the first string in the
*   sequential list.  STR_P will be returned NIL if the list of strings is
*   empty.  New dynamic memory, if any, will be allocated under the MEM
*   context.  STAT will not be returned with EOS status and will only indicate
*   a hard error.  If no strings were found (which is legal) and there
*   were no errors, then STR_P will be NIL, STAT will indicate no error,
*   and no new memory will have been allocated.
}
procedure pdoc_get_strlist (           {get list of strings, semicolon separated}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  out     str_p: pdoc_strent_p_t;      {pnt to first list entry, NIL for empty list}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param;

var
  s: string_var8192_t;                 {single string parsed from input stream}
  last_p: pdoc_strent_p_t;             {pointer to last list entry}
  ent_p: pdoc_strent_p_t;              {scratch list entry pointer}

label
  loop_str;

begin
  s.max := size_char(s.str);           {init local var string}
  str_p := nil;                        {init to empty list returned}

loop_str:                              {back here to get each new string}
  pdoc_get_semistr (in, s, stat);      {try to get another string}
  if string_eos(stat) then return;     {hit end of command ?}
  if sys_error(stat) then return;      {hard error ?}
  if s.len <= 0 then goto loop_str;    {ignore empty strings}
  util_mem_grab (sizeof(ent_p^), mem, false, ent_p); {allocate new list entry}
  if str_p = nil
    then begin                         {this is first list entry}
      str_p := ent_p;                  {return pointer to start of entries chain}
      ent_p^.prev_p := nil;            {there is not previous entry to this one}
      end
    else begin                         {adding to end of existing chain}
      last_p^.next_p := ent_p;         {point previous entry forward to new entry}
      ent_p^.prev_p := last_p;         {point this entry backwards to previous}
      end
    ;
  ent_p^.next_p := nil;                {no entry follows new entry}
  last_p := ent_p;                     {update pointer to entry at end of chain}
  string_alloc (s.len, mem, false, ent_p^.str_p); {allocate memory for new string}
  string_copy (s, ent_p^.str_p^);      {save string in new list entry}
  goto loop_str;                       {back for next string}
  end;
{
***********************************************************************
*
*   Subroutine PDOC_GET_TEXT (IN, STR, STAT)
*
*   Get the remaining data of the current command as a text string.  Free
*   format is required.  Returns with EOS status if nothing substantive read.
}
procedure pdoc_get_text (              {get remaining free format data string}
  in out  in: pdoc_in_t;               {input stream state}
  in out  str: univ string_var_arg_t;  {returned text string}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  tk: string_var8192_t;                {individual free format token}

label
  loop_token;

begin
  tk.max := size_char(tk.str);         {init local var string}

  str.len := 0;                        {init returned string to empty}

loop_token:                            {back here for each new input string token}
  pdoc_in_token (                      {get next token, requires free format}
    in,                                {input stream state}
    tk,                                {returned token}
    ' ',                               {token delimiter character}
    false,                             {quotes have no special meaning}
    stat);
  if string_eos(stat) then begin       {exhausted data for this command ?}
    if str.len <= 0 then begin         {no tokens found at all ?}
      sys_stat_set (string_subsys_k, string_stat_eos_k, stat); {indicate EOS status}
      end;
    return;
    end;
  if sys_error(stat) then return;      {hard error ?}

  if str.len > 0 then begin            {string already contains previous tokens ?}
    case str.str[str.len] of           {what is last char of previous token ?}
'.', '?', '!': string_append1 (str, ' '); {add extra space at end of sentence}
      end;
    string_append1 (str, ' ');         {add separator before new token}
    end;
  string_append (str, tk);             {add new token to end of string}
  goto loop_token;                     {back to get next input token}
  end;
{
***********************************************************************
*
*   Subroutine PDOC_GET_TEXTP (IN, MEM, TEXT_P, STAT)
*
*   Returns TEXT_P pointing to the newly created text string from the
*   remaining data of the current PDOC command.  STAT is never returned with
*   EOS status.  TEXT_P is returned NIL instead.
}
procedure pdoc_get_textp (             {get pnt to free format text string}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  out     text_p: string_var_p_t;      {pointer to text string, may be NIL}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param;

var
  buf: string_var_max_t;               {max size buffer for holding text string}

begin
  buf.max := size_char(buf.str);       {init local var string}

  text_p := nil;                       {init to not returning a text string}

  pdoc_get_text (in, buf, stat);       {read text string into temporary buffer BUF}
  if string_eos(stat) then return;     {return without error on EOS status}
  if sys_error(stat) then return;      {hard error ?}

  string_alloc (buf.len, mem, false, text_p);
  string_copy (buf, text_p^);
  end;
{
***********************************************************************
*
*   Subroutine PDOC_GET_TIME (IN, TZONE, TIME1, TIME2, STAT)
*
*   Get the next data token for the current command and interpret it as
*   an absolute time.  Free format is required.  A time designator token
*   has the format:
*
*    YYYY/MM/DD.hh:mm:ss<+ or ->ZZ
*
*   TIME1 and TIME2 are returned as the start and end of the specified time
*   interval implicit to how the time was specified.  For example, if the
*   time token is
*
*     1999/5/27
*
*   The the interval is the whole day of 27 May 1999 in coordinated universal
*   time.
*
*   TZONE is the default time zone offset in hours west of CUT if the time
*   zone offset is not explicitly included in the time string.
}
procedure pdoc_get_time (              {get next token as an absolute time}
  in out  in: pdoc_in_t;               {input stream state}
  in      tzone: real;                 {zone to interpret time in, hours west of CUT}
  out     time1: sys_clock_t;          {start of time interval}
  out     time2: sys_clock_t;          {end of time interval}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  date1, date2: sys_date_t;            {start and end interval date descriptors}
  delim: sys_int_machine_t;            {number of definative token delimiter}
  fp: real;                            {scratch floating point value}
  token: string_var80_t;               {whole time designator token}
  p: string_index_t;                   {TOKEN parse index}
  tk: string_var80_t;                  {token parsed from TOKEN}
  neg: boolean;                        {negative value flag}

label
  do_tzone, gotdate, badtk;

begin
  token.max := size_char(token.str);   {init local var strings}
  tk.max := size_char(tk.str);

  pdoc_in_token (                      {get time specifier token}
    in,                                {input stream state}
    token,                             {returned token}
    ' ',                               {token delimiter character}
    false,                             {quotes have no special meaning}
    stat);
  if sys_error(stat) then return;
  p := 1;                              {init TOKEN parse index}

  date1.year := 2000;                  {init date descriptors}
  date1.month := 0;
  date1.day := 0;
  date1.hour := 0;
  date1.minute := 0;
  date1.second := 0;
  date1.sec_frac := 0.0;
  date1.hours_west := tzone;
  date1.tzone_id := sys_tzone_other_k;
  date1.daysave := sys_daysave_no_k;
  date1.daysave_on := false;
{
*   Year.
}
  string_token_anyd (                  {extract token}
    token, p,                          {input string and parse index}
    '/+-', 3, 0,                       {delimiters, N delimiters, N repeatable}
    [],                                {option flags}
    tk,                                {returned token}
    delim,                             {number of definative delimiter}
    stat);
  if string_eos(stat) then goto badtk;
  if sys_error(stat) then return;

  string_t_int (tk, date1.year, stat);
  if sys_error(stat) then goto badtk;

  date2 := date1;                      {update time interval end}
  date2.year := date1.year + 1;
  date2.sec_frac := -0.01;             {stay just within this interval}

  if delim > 1 then goto do_tzone;     {time zone is next token ?}
{
*   Month.
}
  string_token_anyd (                  {extract token}
    token, p,                          {input string and parse index}
    '/+-', 3, 0,                       {delimiters, N delimiters, N repeatable}
    [],                                {option flags}
    tk,                                {returned token}
    delim,                             {number of definative delimiter}
    stat);
  if string_eos(stat) then goto gotdate;
  if sys_error(stat) then return;

  string_t_int (tk, date1.month, stat);
  if sys_error(stat) then goto badtk;
  date1.month := date1.month - 1;      {offset from start of year}

  date2 := date1;                      {update time interval end}
  date2.month := date1.month + 1;
  date2.sec_frac := -0.01;             {stay just within this interval}

  if delim > 1 then goto do_tzone;     {time zone is next token ?}
{
*   Day within month.
}
  string_token_anyd (                  {extract token}
    token, p,                          {input string and parse index}
    '.+-', 3, 0,                       {delimiters, N delimiters, N repeatable}
    [],                                {option flags}
    tk,                                {returned token}
    delim,                             {number of definative delimiter}
    stat);
  if string_eos(stat) then goto gotdate;
  if sys_error(stat) then return;

  string_t_int (tk, date1.day, stat);
  if sys_error(stat) then goto badtk;
  date1.day := date1.day - 1;          {offset from start of month}

  date2 := date1;                      {update time interval end}
  date2.day := date1.day + 1;
  date2.sec_frac := -0.01;             {stay just within this interval}

  if delim > 1 then goto do_tzone;     {time zone is next token ?}
{
*   Hour within day.
}
  string_token_anyd (                  {extract token}
    token, p,                          {input string and parse index}
    ':+-', 3, 0,                       {delimiters, N delimiters, N repeatable}
    [],                                {option flags}
    tk,                                {returned token}
    delim,                             {number of definative delimiter}
    stat);
  if string_eos(stat) then goto gotdate;
  if sys_error(stat) then return;

  string_t_int (tk, date1.hour, stat);
  if sys_error(stat) then goto badtk;

  date2 := date1;                      {update time interval end}
  date2.hour := date1.hour + 1;
  date2.sec_frac := -0.01;             {stay just within this interval}

  if delim > 1 then goto do_tzone;     {time zone is next token ?}
{
*   Minute within hour.
}
  string_token_anyd (                  {extract token}
    token, p,                          {input string and parse index}
    ':+-', 3, 0,                       {delimiters, N delimiters, N repeatable}
    [],                                {option flags}
    tk,                                {returned token}
    delim,                             {number of definative delimiter}
    stat);
  if string_eos(stat) then goto gotdate;
  if sys_error(stat) then return;

  string_t_int (tk, date1.minute, stat);
  if sys_error(stat) then goto badtk;

  date2 := date1;                      {update time interval end}
  date2.minute := date1.minute + 1;
  date2.sec_frac := -0.01;             {stay just within this interval}

  if delim > 1 then goto do_tzone;     {time zone is next token ?}
{
*   Second within minute.
}
  string_token_anyd (                  {extract token}
    token, p,                          {input string and parse index}
    '+-', 2, 0,                        {delimiters, N delimiters, N repeatable}
    [],                                {option flags}
    tk,                                {returned token}
    delim,                             {number of definative delimiter}
    stat);
  if string_eos(stat) then goto gotdate;
  if sys_error(stat) then return;
  delim := delim + 1;                  {2 for plus, 3 for minus}

  string_t_int (tk, date1.second, stat);
  if sys_error(stat)
    then begin                         {conversion to integer failed}
      string_t_fpm (tk, fp, stat);     {try converting to floating point}
      if sys_error(stat) then goto badtk;
      date1.second := trunc(fp);       {set whole seconds}
      date1.sec_frac := fp - date1.second; {remaining fractional seconds}
      date2 := date1;
      end
    else begin                         {conversion to integer succeeded}
      date2 := date1;                  {update time interval end}
      date2.second := date1.second + 1;
      date2.sec_frac := -0.01;         {stay just within this interval}
      end
    ;
{
*   The next token is the time zone offset in hours west if DELIM is greater
*   than 1.  If not, then there is no next token.  DELIM indicates the
*   delimiter preceeding the time zone, which is either "+" or "-".  The
*   possible DELIM values are:
*
*     2  -  plus
*     3  -  minus
}
do_tzone:
  neg := delim >= 3;                   {set flag for negative time zone offset}

  string_token_anyd (                  {extract token}
    token, p,                          {input string and parse index}
    ' ', 1, 1,                         {delimiters, N delimiters, N repeatable}
    [],                                {option flags}
    tk,                                {returned token}
    delim,                             {number of definative delimiter}
    stat);
  if string_eos(stat) then goto gotdate;
  if sys_error(stat) then return;

  string_t_fpm (tk, date1.hours_west, stat);
  if sys_error(stat) then goto badtk;
  if neg then date1.hours_west := -date1.hours_west;

  date1.tzone_id := sys_tzone_other_k; {update time zone info}
  date1.daysave := sys_daysave_no_k;

  date2.hours_west := date1.hours_west; {copy tzone info to time interval end}
  date2.tzone_id := date1.tzone_id;
  date2.daysave := date1.daysave;

  string_token_anyd (                  {try to get another token}
    token, p,                          {input string and parse index}
    ' ', 1, 1,                         {delimiters, N delimiters, N repeatable}
    [],                                {option flags}
    tk,                                {returned token}
    delim,                             {number of definative delimiter}
    stat);
  if not string_eos(stat) then goto badtk; {additional unexpected tokens ?}
{
*   DATE1 and DATE2 have been set to the start and end of the time interval.
}
gotdate:
  time1 := sys_clock_from_date (date1); {return time values}
  time2 := sys_clock_from_date (date2);
  sys_error_none (stat);               {indicate success}
  return;

badtk:                                 {time specifier syntax error}
  sys_stat_set (pdoc_subsys_k, pdoc_stat_badtime_k, stat);
  pdoc_in_stat_lnum (in, stat);
  pdoc_in_stat_fnam (in, stat);
  sys_stat_parm_vstr (token, stat);
  end;
{
***********************************************************************
*
*   Subroutine PDOC_GET_TIMERANGE (IN, MEM, TZONE, RANGE_P, STAT)
*
*   Return RANGE_P pointing to the time range descriptor specified by the
*   next 0 to two time tokens.  On no tokens present, RANGE_P is returned
*   NIL, with STAT normal (not EOS, for example).
}
procedure pdoc_get_timerange (         {get pointer to time range specified by args}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in      tzone: real;                 {zone to interpret time in, hours west of CUT}
  out     range_p: pdoc_timerange_p_t; {pointer to time range descriptor, may be NIL}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param;

var
  time1, time2: sys_clock_t;           {scratch time values}

begin
  range_p := nil;                      {init to not returning a time range}

  pdoc_get_time (in, tzone, time1, time2, stat); {get values from first time token}
  if string_eos(stat) then return;     {no tokens supplied ?}
  if sys_error(stat) then return;      {hard error ?}

  util_mem_grab (sizeof(range_p^), mem, false, range_p); {allocate time range mem}
  range_p^.time1 := time1;             {init range descriptor from first token data}
  range_p^.time2 := time2;

  pdoc_get_time (in, tzone, time1, time2, stat); {get values from second time token}
  if string_eos(stat) then return;     {no tokens supplied ?}
  if sys_error(stat) then return;      {hard error ?}

  if sys_clock_compare (time2, range_p^.time1) = sys_compare_lt_k then begin
    sys_stat_set (pdoc_subsys_k, pdoc_stat_timeorder_k, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    return;
    end;

  range_p^.time2 := time2;             {set final time range ending time}
  end;
{
***********************************************************************
*
*   Subroutine PDOC_GET_LOCP (IN, MEM, DEF_P, LOC_P, STAT)
*
*   Return LOC_P pointing to the hierarchy location list specified by the
*   current command arguments.  DEF_P must be pointing to the default location
*   hierarchy which is referenced by a "*" as the first location name.  If
*   no arguments are present, then LOC_P will be returned NIL and STAT will
*   be normal.
}
procedure pdoc_get_locp (              {get location names hierarchy chain}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in      def_p: pdoc_strent_p_t;      {points to default location names, may be NIL}
  out     loc_p: pdoc_strent_p_t;      {pointer to location names list, may be NIL}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param;

var
  last_p: pdoc_strent_p_t;             {pointer to last loc entry in current list}
  ent_p: pdoc_strent_p_t;              {scratch location list entry pointer}
  buf: string_var8192_t;               {scratch string}
  first: boolean;                      {TRUE for first name parsed from args list}

label
  loop_name, next_name;
{
********************
*
*   Local subroutine NEWENT
*
*   Create a new list entry at the end of the list.  LAST_P must be pointing
*   to the last list entry, and will be updated.  LOC_P will be set to the
*   start of the list if no list previously existed.  The ENT_P field of
*   the new entry will not be set.
}
procedure newent;

var
  ent_p: pdoc_strent_p_t;              {pointer to newly created list entry}

begin
  util_mem_grab (sizeof(ent_p^), mem, false, ent_p); {allocate new list entry}

  ent_p^.prev_p := last_p;             {link back to previous chain entry}
  ent_p^.next_p := nil;                {this will be end of chain}
  if last_p = nil
    then begin                         {this is the start of a new list}
      loc_p := ent_p;
      end
    else begin                         {adding to an existing list}
      last_p^.next_p := ent_p;         {link to from previous entry to new entry}
      end
    ;
  last_p := ent_p;                     {update pointer to new end of chain}
  end;
{
********************
*
*   Start of main routine PDOC_GET_LOCP.
}
begin
  buf.max := size_char(buf.str);       {init local var string}

  loc_p := nil;                        {init to not returning a location names list}
  first := true;                       {next name argument will be the first}
  last_p := nil;                       {list empty, no last list entry exists}
{
*   Back here for each new location name in the list.
}
loop_name:
  pdoc_get_semistr (in, buf, stat);    {get next location name string in BUF}
  if string_eos(stat) then return;     {hit end of arguments ?}
  if sys_error(stat) then return;      {hard error ?}
  if buf.len = 0 then goto loop_name;  {ignore empty location names}

  if (buf.len = 1) and (buf.str[1] = '*') then begin {reference to default loc ?}
    if not first then begin            {this is not the first argument in the list}
      sys_stat_set (pdoc_subsys_k, pdoc_stat_defloc_nfirst_k, stat);
      pdoc_in_stat_lnum (in, stat);
      pdoc_in_stat_fnam (in, stat);
      return;
      end;
    ent_p := def_p;                    {init to start of default location list}
    while ent_p <> nil do begin        {once for each default location list entry}
      newent;                          {create new output list entry}
      last_p^.str_p := ent_p^.str_p;   {copy pointer to name for this entry}
      ent_p := ent_p^.next_p;          {advance to next entry in default loc list}
      end;                             {back to process this new default list entry}
    goto next_name;                    {advance to next argument from PDOC stream}
    end;

  newent;                              {make new location list entry}
  string_alloc (buf.len, mem, false, last_p^.str_p); {allocate mem for name string}
  string_copy (buf, last_p^.str_p^);   {write name string for this entry}
next_name:                             {done with this name arg, advance to next}
  first := false;                      {next arg will definitely not be the first}
  goto loop_name;                      {back to process next location argument}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_GET_PERSON (IN, MEM, PERS_P, STAT)
*
*   Get a full person description and create a person descriptor.  The new
*   person descriptor will be added to the end of the chain pointed to by
*   by PERS_P.  PERS_P may be NIL on entry.
}
procedure pdoc_get_person (            {get a person definition, add to list}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in out  pers_p: pdoc_perent_p_t;     {pointer to start of list, may be NIL on entry}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param;

var
  name: string_var132_t;               {short reference name}
  fname: string_var8192_t;             {full person name}
  desc_p: pdoc_lines_p_t;              {pointer to person description lines}
  dat_p: pdoc_person_p_t;              {pointer to person data}
  lastent_p: pdoc_perent_p_t;          {pointer to last entry in list}
  ent_p: pdoc_perent_p_t;              {pointer to new person list entry}

begin
  name.max := size_char(name.str);     {init local var strings}
  fname.max := size_char(fname.str);
{
*   Get person name into NAME and look for duplicate.
*
*   LASTENT_P will be left pointing to the last entry in the person list, or it
*   will be NIL if there is no existing person list.
}
  pdoc_get_semistr (in, name, stat);   {get person PDOC reference name}
  discard( string_eos(stat) );         {will be detected by empty string below}
  if sys_error(stat) then return;      {hard error ?}
  if name.len <= 0 then begin          {reference name missing ?}
    sys_stat_set (pdoc_subsys_k, pdoc_stat_nrefname_k, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    return;
    end;

  lastent_p := pers_p;                 {init to first entry in existing list}
  if lastent_p <> nil then begin       {the existing list is not empty ?}
    while true do begin
      if string_equal (lastent_p^.ent_p^.name_p^, name) then begin {found duplicate ?}
        sys_stat_set (pdoc_subsys_k, pdoc_stat_person_dup_k, stat);
        sys_stat_parm_vstr (name, stat);
        pdoc_in_stat_lnum (in, stat);
        pdoc_in_stat_fnam (in, stat);
        return;
        end;
      if lastent_p^.next_p = nil then exit; {at last list entry ?}
      lastent_p := lastent_p^.next_p;  {advance to next list entry}
      end;
    end;
{
*   Get full name into FNAME.
}
  pdoc_get_semistr (in, fname, stat);  {get person full name}
  discard( string_eos(stat) );         {will be detected by empty string below}
  if sys_error(stat) then return;      {hard error ?}
  if fname.len <= 0 then begin         {reference name missing ?}
    sys_stat_set (pdoc_subsys_k, pdoc_stat_nfullname_k, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    return;
    end;
{
*   Get description string and point DESC_P to it.  DESC_P will be NIL when
*   there is no description string.
}
  pdoc_get_lines (in, mem, desc_p, stat); {get person description lines}
  discard( string_eos(stat) );         {description text is not required}
  if sys_error(stat) then return;      {hard error ?}
{
*   Create the person description data structure and point DAT_P to it.
}
  util_mem_grab (sizeof(dat_p^), mem, false, dat_p); {allocate mem for person data}
  string_alloc (name.len, mem, false, dat_p^.name_p); {fill in reference name}
  string_copy (name, dat_p^.name_p^);
  string_alloc (fname.len, mem, false, dat_p^.fname_p); {fill in person full name}
  string_copy (fname, dat_p^.fname_p^);
  dat_p^.desc_p := desc_p;             {set pointer to description lines}
  dat_p^.pic_p := nil;                 {init to no identifying picture}
  dat_p^.wikitree_p := nil;            {init to WikiTree ID not known}
  dat_p^.intid := 0;                   {internal sequential ID not assigned yet}
  dat_p^.ref := false;                 {init to this person not referenced}
  dat_p^.wr := false;                  {init to not written to output}
{
*   Create the person list entry and add it to the chain.  LASTENT_P is pointing
*   to the last entry in the list, or is NIL if there is no existing list.
}
  util_mem_grab (sizeof(ent_p^), mem, false, ent_p); {allocate mem for list entry}
  ent_p^.prev_p := lastent_p;          {point back to previous entry}
  ent_p^.next_p := nil;                {at end of list, no next entry}
  ent_p^.ent_p := dat_p;               {point to data for this list entry}

  if lastent_p = nil
    then begin                         {there is no previous list}
      pers_p := ent_p;                 {return pointer to newly-created list}
      end
    else begin                         {adding to end of existing list}
      lastent_p^.next_p := ent_p;      {link to end of existing list}
      end
    ;
  end;
{
********************************************************************************
*
*   Subroutine PDOC_GET_PERSONDATA (IN, MEM, PERS_P, STAT)
*
*   Add the data from a "personData" command to a existing person definition.
*   Any new dynamic memory will be allocated under the MEM context.  PERS_P is
*   points to the list of existing person definitions.
}
procedure pdoc_get_personData (        {add extra data to person definition}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in      pers_p: pdoc_perent_p_t;     {points to persons list}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param;

var
  tk, tk2: string_var8192_t;           {scratch tokens}
  keyw: string_var32_t;                {subcommand name, upper case}
  ent_p: pdoc_perent_p_t;              {pointer to current persons list entry}
  dat_p: pdoc_person_p_t;              {pointer to person to add the data to}
  p: string_index_t;                   {TK parse index}
  pick: sys_int_machine_t;             {number of keyword picked from list}

label
  loop_subcommand;

begin
  tk.max := size_char(tk.str);         {init local var strings}
  tk2.max := size_char(tk2.str);
  keyw.max := size_char(keyw.str);
{
*   Get the short reference name into TK.
}
  pdoc_get_semistr (in, tk, stat);     {get person PDOC reference name}
  discard( string_eos(stat) );         {will be detected by empty string below}
  if sys_error(stat) then return;      {hard error ?}
  if tk.len <= 0 then begin            {reference name missing ?}
    sys_stat_set (pdoc_subsys_k, pdoc_stat_nrefname_k, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    return;
    end;
{
*   Point DAT_P to the person definition referenced by TK.
}
  ent_p := pers_p;                     {init to first entry in list}
  while true do begin                  {scan the list}
    if ent_p = nil then begin          {no such person ?}
      sys_stat_set (pdoc_subsys_k, pdoc_stat_name_nfound_k, stat);
      pdoc_in_stat_lnum (in, stat);
      pdoc_in_stat_fnam (in, stat);
      sys_stat_parm_vstr (tk, stat);
      return;
      end;
    dat_p := ent_p^.ent_p;             {get pointer to person descriptor}
    if string_equal (dat_p^.name_p^, tk) {found definition for this person ?}
      then exit;
    ent_p := ent_p^.next_p;            {no, go on to next list entry}
    end;
{
*   Process the subcommands.
}
loop_subcommand:                       {back here to get each new subcommand}
  pdoc_get_semistr (in, tk, stat);     {try to get next keyword and parameters}
  if sys_error(stat) then begin        {didn't get keyword ?}
    discard( string_eos(stat) );       {end of command is not error}
    return;
    end;
  p := 1;                              {init TK parse index}
  string_token (tk, p, keyw, stat);    {extract just the keyword into KEYW}
  if sys_error(stat) then begin
    sys_stat_set (pdoc_subsys_k, pdoc_stat_err_keyw_k, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    return;
    end;
  string_upcase (keyw);                {make upper case for keyword matching}
  string_tkpick80 (keyw,               {pick keyword from list}
    'PIC WIKITREE',
    pick);                             {1-N number of keyword in list}
  case pick of                         {which subcommand is it ?}
{
*   PIC pathname
}
1: begin
  if dat_p^.pic_p <> nil then begin    {previously defined ?}
    sys_stat_set (pdoc_subsys_k, pdoc_stat_prevdef_k, stat);
    sys_stat_parm_vstr (keyw, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    return;
    end;
  string_token (tk, p, tk2, stat);     {get pathname}
  if sys_error(stat) then begin
    sys_stat_set (pdoc_subsys_k, pdoc_stat_missparmkeyw_k, stat);
    sys_stat_parm_vstr (keyw, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    return;
    end;
  string_alloc (tk2.len, mem, false, dat_p^.pic_p); {allocate pathname string}
  string_copy (tk2, dat_p^.pic_p^);    {save the pathname}
  end;
{
*   WIKITREE id
}
2: begin
  if dat_p^.wikitree_p <> nil then begin {previously defined ?}
    sys_stat_set (pdoc_subsys_k, pdoc_stat_prevdef_k, stat);
    sys_stat_parm_vstr (keyw, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    return;
    end;
  string_token (tk, p, tk2, stat);     {get the WikiTree ID}
  if sys_error(stat) then begin
    sys_stat_set (pdoc_subsys_k, pdoc_stat_missparmkeyw_k, stat);
    sys_stat_parm_vstr (keyw, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    return;
    end;
  string_alloc (tk2.len, mem, false, dat_p^.wikitree_p); {allocate ID string}
  string_copy (tk2, dat_p^.wikitree_p^); {save the WikiTree ID}
  end;
{
*   Unrecognized subcommand name.
}
otherwise
    sys_stat_set (pdoc_subsys_k, pdoc_stat_badkeyw_k, stat);
    sys_stat_parm_vstr (keyw, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    return;
    end;

  string_token (tk, p, tk2, stat);     {try to get another subcommand parameter}
  if not sys_error(stat) then begin
    sys_stat_set (pdoc_subsys_k, pdoc_stat_extraparmkeyw_k, stat);
    sys_stat_parm_vstr (keyw, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    return;
    end;
  sys_error_none (stat);               {no error here}

  goto loop_subcommand;                {back to get next subcommand}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_GET_PEOPLE (IN, MEM, PEOPLE_P, LIST_P, STAT)
*
*   Build a people list from reference name arguments separated by commas.
*   PEOPLE_P must point to the complete list of known people to match the
*   reference names to.  PEOPLE_P may be NIL, in which case an error will be
*   generated on the first argument since it will not match an existing
*   reference name.  LIST_P will be returned pointing to the start of the
*   resulting people list.  It will be NIL if no names arguments are found.
}
procedure pdoc_get_people (            {get list of people from reference name args}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in      people_p: pdoc_perent_p_t;   {pointer to list of know people, may be NIL}
  out     list_p: pdoc_perent_p_t;     {pointer to resulting people list, may be NIL}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param;

var
  name: string_var132_t;               {reference name argument}
  ent_p: pdoc_perent_p_t;              {pointer to people reference list entry}
  new_p: pdoc_perent_p_t;              {pointer to new returned people list entry}
  last_p: pdoc_perent_p_t;             {poitner to last returned list entry}

label
  loop_name, found_name;

begin
  name.max := size_char(name.str);     {init local var string}

  list_p := nil;                       {init to no list generated}
  new_p := nil;                        {init to no current returned list entry}

loop_name:                             {back here for each new reference name arg}
  pdoc_get_name (in, name, stat);      {get this reference name}
  if string_eos(stat) then return;     {hit end of reference name arguments ?}
  if sys_error(stat) then return;

  ent_p := people_p;                   {init to first entry in people reference list}
  while ent_p <> nil do begin          {once for each reference list entry}
    if string_equal (name, ent_p^.ent_p^.name_p^) {ref name matches this entry ?}
      then goto found_name;
    ent_p := ent_p^.next_p;            {advance to next reference list entry}
    end;                               {back to process this new entry}

  sys_stat_set (pdoc_subsys_k, pdoc_stat_name_nfound_k, stat);
  pdoc_in_stat_lnum (in, stat);
  pdoc_in_stat_fnam (in, stat);
  sys_stat_parm_vstr (name, stat);
  return;
{
*   The reference name from the PDOC input stream matched an entry in the
*   people reference list.  ENT_P is pointing to the reference list entry
*   that matched the reference name.
}
found_name:
  last_p := new_p;                     {save pointer to old entry at end of list}
  util_mem_grab (sizeof(new_p^), mem, false, new_p); {allocate mem for new entry}
  new_p^.prev_p := last_p;             {link back to previous entry}
  if last_p = nil
    then begin                         {this is first entry in new list}
      list_p := new_p;                 {pass back pointer to list start}
      end
    else begin                         {adding to existing list}
      last_p^.next_p := new_p;         {link previous entry forwards to new entry}
      end
    ;
  new_p^.next_p := nil;                {this entry is at the end of the chain}
  new_p^.ent_p := ent_p^.ent_p;        {copy pointer to person info for this entry}
  goto loop_name;                      {back to get next reference name argument}
  end;
{
***********************************************************************
*
*   Subroutine PDOC_GET_GCOORP (IN, MEM, COOR_P, STAT)
*
*   Get geographic coordinates argument and return COOR_P pointing to the
*   resulting data.  COOR_P will be NIL if no arguments are found.
}
procedure pdoc_get_gcoorp (            {get pointer to geographic coordinate}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  out     coor_p: pdoc_gcoor_p_t;      {pointer to geographic coordinate info}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param;

var
  lat: double;                         {latitude in degrees}
  lon: double;                         {longitude in degrees}
  rad: double;                         {radius in meters}

begin
  coor_p := nil;                       {init to no coordinate arguments found}

  pdoc_get_angle (in, lat, stat);      {get latitude angle in degrees}
  if string_eos(stat) then return;     {no arguments, return with nothing ?}
  if sys_error(stat) then return;      {hard error ?}

  pdoc_get_angle (in, lon, stat);      {get longitude angle in degrees}
  if string_eos(stat) then begin       {missing longitude argument ?}
    sys_stat_set (pdoc_subsys_k, pdoc_stat_nlon_k, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    return;
    end;
  if sys_error(stat) then return;      {hard error from subroutine ?}

  pdoc_get_fp (in, rad, stat);         {get error radius in meters}
  if string_eos(stat) then rad := 0.0; {no argument, use default ?}

  util_mem_grab (sizeof(coor_p^), mem, false, coor_p); {allocate coordinate data mem}
  coor_p^.lat := lat;                  {fill in geographic coordinate descriptor}
  coor_p^.lon := lon;
  coor_p^.rad := rad;
  end;
