{   Low level PDOC stream input handling routines.  All other PDOC reading
*   routines are layered on the routines in this module.
}
module pdoc_in;
define pdoc_in_file_push;
define pdoc_in_stat_fnam;
define pdoc_in_stat_lnum;
define pdoc_in_open_fnam;
define pdoc_in_close;
define pdoc_in_getline;
define pdoc_in_cmd;
define pdoc_in_line;
define pdoc_in_token;
%include 'pdoc2.ins.pas';
{
********************************************************************************
*
*   Local subroutine PDOC_IN_INIT (IN)
*
*   Initialize the PDOC_IN_T structure IN.  All fields are set to default or
*   benign values.  A PDOC_IN_T structure must be initialized before use.
}
procedure pdoc_in_init (               {init low level PDOC stream input state}
  out     in: pdoc_in_t;               {data structure to initialize}
  in out  mem: util_mem_context_t);    {parent memory, subordinate will be created}
  val_param;

begin
  util_mem_context_get (mem, in.mem_p); {create our own memory context}
  in.file_p := nil;                    {init to no input file open}
  in.level := 0;
  in.line.max := size_char(in.line.str);
  in.line.len := 0;
  in.p := 1;
  in.lful := false;
  in.cmd := false;
  in.fmt := pdoc_format_free_k;
  end;
{
********************************************************************************
*
*   Subroutine PDOC_IN_FILE_PUSH (IN, FNAM, STAT)
*
*   Switch the input stream to come from the new file.  When the end of this new
*   file is encountered, the input stream state will be restored to what it was
*   before this call.
}
procedure pdoc_in_file_push (          {open nested input file}
  in out  in: pdoc_in_t;               {input stream state}
  in      fnam: univ string_var_arg_t; {name of new file to open}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  file_p: pdoc_infile_p_t;             {points to new input file state}
  pnam: string_treename_t;             {scratch file pathname}
  stat2: sys_err_t;                    {to avoid corrupting STAT}

begin
  pnam.max := size_char(pnam.str);     {init local var string}
  sys_error_none (stat);               {init to no error encountered}

  if in.level >= pdoc_maxnest_k then begin {trying to nest too deep ?}
    sys_stat_set (pdoc_subsys_k, pdoc_stat_nestlev_k, stat);
    sys_stat_parm_int (in.level, stat);
    sys_stat_parm_int (in.file_p^.conn.lnum, stat);
    sys_stat_parm_vstr (in.file_p^.conn.tnam, stat);
    return;
    end;

  util_mem_grab (                      {allocate descriptor for this new input file}
    sizeof(file_p^), in.mem_p^, true, file_p);
{
*   Open the new input file.  This must be done from the directory of the
*   current input file, since new input file names are relative to the file they
*   are referenced from.
}
  pnam.len := 0;                       {init to no curr dir to restore to}
  if in.file_p <> nil then begin       {there is a current input file ?}
    file_currdir_get (pnam, stat);     {save current directory name}
    if sys_error(stat) then return;
    file_currdir_set (in.file_p^.dir, stat); {switch to directory of the input file}
    if sys_error(stat) then return;
    end;
  file_open_read_text (                {try to open the new input file}
    fnam,                              {new input file name}
    '.ins.pdoc .pdoc ""'(0),           {possible file name suffixes}
    file_p^.conn,                      {returned connection to the new file}
    stat);

  if pnam.len > 0 then begin           {need to restore current directory ?}
    file_currdir_set (pnam, stat2);
    if sys_error(stat2) and (not sys_error(stat)) then begin {error restoring directory ?}
      file_close (file_p^.conn);       {close the input file}
      stat := stat2;
      end;
    end;
  if sys_error(stat) then begin        {error occurred ?}
    util_mem_ungrab (file_p, in.mem_p^); {release new input file descriptor ?}
    return;                            {return with error}
    end;
{
*   The new input file has been successfully opened.
}
  file_p^.prev_p := in.file_p;         {link back to previous input file}
  file_p^.dir.max := size_char(file_p^.dir.str); {init directory string}
  string_pathname_split (              {save directory containing new input file}
    file_p^.conn.tnam, file_p^.dir, pnam);

  in.file_p := file_p;                 {switch to the new input file}
  in.level := in.level + 1;            {update input file nesting level}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_IN_STAT_FNAM (IN, STAT)
*
*   Add the current input file name as the next parameter to STAT.
}
procedure pdoc_in_stat_fnam (          {add the input file name as next parm in STAT}
  in      in: pdoc_in_t;               {PDOC reading state}
  in out  stat: sys_err_t);            {will have string parameter added}
  val_param;

begin
  if in.file_p = nil
    then begin
      sys_stat_parm_str (''(0), stat);
      end
    else begin
      sys_stat_parm_vstr (in.file_p^.conn.tnam, stat);
      end
    ;
  end;
{
********************************************************************************
*
*   Subroutine PDOC_IN_STAT_LNUM (IN, STAT)
*
*   Add the current input file line number as the next parameter to STAT.
}
procedure pdoc_in_stat_lnum (          {add the input line number as next parm in STAT}
  in      in: pdoc_in_t;               {PDOC reading state}
  in out  stat: sys_err_t);            {will have integer parameter added}
  val_param;

begin
  if in.file_p = nil
    then begin
      sys_stat_parm_int (0, stat);
      end
    else begin
      sys_stat_parm_int (in.file_p^.conn.lnum, stat);
      end
    ;
  end;
{
********************************************************************************
*
*   Local subroutine PDOC_IN_FILE_POP (IN)
*
*   Close the current input file and restore to the parent input file.  Nothing
*   is done when there is no input file open.  IN.FILE_P will be NIL when the
*   top level input file is closed.
}
procedure pdoc_in_file_pop (           {pop back one input file level}
  in out  in: pdoc_in_t);              {PDOC input reading state}
  val_param;

var
  file_p: pdoc_infile_p_t;             {pointer to input file state}

begin
  if in.file_p <> nil then begin       {there is a current file to close ?}
    file_p := in.file_p;               {save pointer to current input file state}
    in.file_p := file_p^.prev_p;       {pop back to previous input file}
    in.level := in.level - 1;          {update input file nesting level}
    file_close (file_p^.conn);         {close the old input file}
    util_mem_ungrab (file_p, in.mem_p^); {deallocate old input file state}
    end;

(*
  if in.file_p = nil
    then begin
      writeln ('  No input file');
      end
    else begin
      writeln ('  Input file is ', in.file_p^.conn.tnam.str:in.file_p^.conn.tnam.len,
        ' in ', in.file_p^.dir.str:in.file_p^.dir.len, ' level ', in.level);
      end
    ;
*)

  end;
{
********************************************************************************
*
*   Subroutine PDOC_IN_OPEN_FNAM (FNAM, MEM, IN, STAT)
*
*   Open the PDOC file named in FNAM, and set up the PDOC input reading state
*   in IN accordingly.  The .pdoc file name suffix may be omitted in FNAM.
}
procedure pdoc_in_open_fnam (          {open PDOC file and set up input stream state}
  in      fnam: univ string_var_arg_t; {file name, .pdoc suffix may be omitted}
  in out  mem: util_mem_context_t;     {parent memory context}
  out     in: pdoc_in_t;               {returned input stream state}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  pdoc_in_init (in, mem);              {initialize input stream state structure}
  pdoc_in_file_push (in, fnam, stat);  {open top level input file}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_IN_CLOSE (IN)
*
*   Close the use of the PDOC input reading state IN.  IN will be returned
*   invalid, and must be re-initialized before any new use.
}
procedure pdoc_in_close (              {close use of PDOC input state}
  in out  in: pdoc_in_t);              {all files closed, will be invalid}
  val_param;

begin
  while in.file_p <> nil do begin      {close all input files}
    pdoc_in_file_pop (in);
    end;

  util_mem_context_del (in.mem_p);     {dealloc dynamic memory used with IN}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_IN_GETLINE (IN, STAT)
*
*   Get the next input line if the current input line has been used up.  Nothing
*   is done if there are still unused characters on the current input line.
*   This routine also sets the FMT and CMD fields appropriately for the new
*   line, and initializes the parse index to the first character.
*
*   Except on hard error, STAT either indicates no error or END OF FILE status.
}
procedure pdoc_in_getline (            {get next input line, unless already have it}
  in out  in: pdoc_in_t;               {input stream state}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  tk: string_var32_t;                  {scratch token}
  fnam: string_treename_t;             {scratch file name}

begin
  tk.max := size_char(tk.str);         {init local var strings}
  fnam.max := size_char(fnam.str);
  sys_error_none (stat);               {init to no error encountered}

  if in.lful and (in.p <= in.line.len) {unused characters remain on this line ?}
    then return;

  while true do begin                  {loop until get input line or end of top file}
    if in.file_p = nil then begin      {input stream exhausted ?}
      sys_stat_set (file_subsys_k, file_stat_eof_k, stat);
      return;                          {return with EOF status}
      end;
    file_read_text (                   {try to read next line from current file}
      in.file_p^.conn, in.line, stat);
    if file_eof(stat) then begin       {end of this input file ?}
      pdoc_in_file_pop (in);           {pop back to previous input file}
      next;                            {back to try reading input line again}
      end;
    if sys_error(stat) then return;    {hard error ?}
    {
    *   Check for INCLUDE command, which is handled at this low level
    *   transparently to the rest of the system.
    }
    string_unpad (in.line);            {remove trailing spaces}
    if in.line.len < 9 then exit;      {too short to be INCLUDE command ?}
    if in.line.str[1] <> 'i' then exit; {"include" doesn't start in column 1 ?}
    in.p := 1;                         {init parse index}
    string_token (in.line, in.p, tk, stat); {get command name}
    if not string_equal (tk, string_v('include'(0))) then exit; {not "include" ?}
    string_token (in.line, in.p, fnam, stat); {try to get file name}
    if sys_error(stat) then exit;      {didn't get file name ?}
    string_token (in.line, in.p, tk, stat); {try to get another token}
    if not string_eos(stat) then begin {other than hit end of string ?}
      if sys_error(stat) then return;  {hard error ?}
      sys_stat_set (pdoc_subsys_k, pdoc_stat_unused_args_k, stat);
      sys_stat_parm_int (in.file_p^.conn.lnum, stat);
      sys_stat_parm_vstr (in.file_p^.conn.tnam, stat);
      sys_stat_parm_vstr (tk, stat);
      return;                          {return with extra argument error}
      end;
    pdoc_in_file_push (in, fnam, stat); {switch the input to the include file}
    if sys_error(stat) then return;
    end;                               {back to get line from new include file}
{
*   The new input line is in IN.LINE.
}
  in.lful := true;                     {indicate an unused line is now in LINE}

  if in.line.len < 1 then begin        {no line start character available ?}
    in.line.str[1] := ' ';             {default to data line}
    end;
  if in.line.len < 2 then begin        {no format character available ?}
    in.line.str[2] := ' ';             {default to FREE format}
    end;
  in.line.len := max(in.line.len, 2);  {first two characters now always present}

  if in.line.str[1] = ' '
    then begin                         {this is a data line, no command keyword}
      in.cmd := false;
      in.p := 3;                       {init parse index for data part of line}
      case in.line.str[2] of           {check the formatting character}
' ':    in.fmt := pdoc_format_free_k;
':':    in.fmt := pdoc_format_fixed_k;
otherwise                              {unrecognized format character}
        sys_stat_set (pdoc_subsys_k, pdoc_stat_badfmt_k, stat);
        sys_stat_parm_int (in.file_p^.conn.lnum, stat);
        sys_stat_parm_vstr (in.file_p^.conn.tnam, stat);
        return;
        end;
      end
    else begin                         {this line contains a command keyword}
      in.cmd := true;
      in.p := 1;                       {init parse index for command name}
      in.fmt := pdoc_format_free_k;    {remainder of line always uses free format}
      end
    ;
  end;
{
********************************************************************************
*
*   Subroutine PDOC_IN_CMD (IN, CMD, STAT)
*
*   Get the next command name from the PDOC input stream.  It is an error if a
*   new command isn't at the start of the next line.
}
procedure pdoc_in_cmd (                {get next command name from input stream}
  in out  in: pdoc_in_t;               {input stream state}
  in out  cmd: univ string_var_arg_t;  {returned command name}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  pdoc_in_getline (in, stat);          {make sure an input line is available}
  if sys_error(stat) then return;

  if (not in.cmd) or (in.p <> 1) then begin {not at a command start ?}
    sys_stat_set (pdoc_subsys_k, pdoc_stat_nocmd_k, stat);
    sys_stat_parm_int (in.file_p^.conn.lnum, stat);
    sys_stat_parm_vstr (in.file_p^.conn.tnam, stat);
    return;
    end;

  string_token (in.line, in.p, cmd, stat); {extract command name token}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_IN_LINE (IN, LINE, FMT, STAT)
*
*   Get the next line of data for the current PDOC command.  The data line is
*   returned in LINE, and FMT is set to the format of this data line.  STAT is
*   returned END OF STRING when the end of the command is reached, in which case
*   LINE is returned empty.
*
*   Every returned line is guaranteed to be meaningful.  For example, this
*   routine will never return a blank line in FREE format.
}
procedure pdoc_in_line (               {get next data line for current command}
  in out  in: pdoc_in_t;               {input stream state}
  in out  line: univ string_var_arg_t; {returned data line}
  out     fmt: pdoc_format_k_t;        {format type of this data line}
  out     stat: sys_err_t);            {completion status code}
  val_param;

label
  eos, loop;

begin
  line.len := 0;                       {init returned data line to empty}

loop:                                  {back here if data line not meaningful}
  pdoc_in_getline (in, stat);          {make sure there is an input line available}
  if file_eof(stat) then begin         {hit end of PDOC input stream ?}
eos:                                   {jmp here to return with end of string status}
    sys_stat_set (string_subsys_k, string_stat_eos_k, stat); {report end of string}
    return;
    end;
  if sys_error(stat) then return;      {hard error ?}

  if in.cmd and (in.p = 1) then goto eos; {at the start of a new command ?}

  string_substr (in.line, in.p, in.line.len, line); {extract data part of line}
  in.lful := false;                    {cached line has now been used up}
{
*   Check for meaningless line.  If so, we jump back to LOOP to do it all again
*   until we either return EOS or a meaningful line.
}
  case in.fmt of                       {what is the format of this line ?}
pdoc_format_free_k: begin              {FREE format}
      if line.len <= 0 then goto loop; {empty line in free format ?}
      end;
    end;

  fmt := in.fmt;                       {pass back format of this line}
  end;
{
********************************************************************************
*
*   Procedure PDOC_IN_TOKEN (IN, TK, DELIM, QUOT, STAT)
*
*   Read the next data token for the current command from the PDOC input stream
*   into TK.  STAT is returned END OF STRING with TK empty when the end of the
*   command is encountered.  It is an error if the format is not FREE.
*
*   DELIM is the token delimiter character.  When DELIM is not a space, then
*   multiple spaces within the token are still collapsed to single spaces, and
*   leading and trailing spaces are eliminated.  A returned token may come from
*   multiple input lines.
*
*   When QUOT is TRUE, then text surrounded by matching quotes ("") or
*   apostrophies ('') are considered one indivisible string, with the quotes
*   removed.  When QUOT is FALSE, quote characters are treated no differently
*   from other characters.
}
procedure pdoc_in_token (              {get next data token in free format}
  in out  in: pdoc_in_t;               {input stream state}
  in out  tk: univ string_var_arg_t;   {returned token}
  in      delim: char;                 {delimiter character}
  in      quot: boolean;               {TRUE if string enclosed in quotes is a token}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  del: string;                         {list of delimiters}
  n_del: sys_int_machine_t;            {number of delimiters in DEL}
  n_del_rept: sys_int_machine_t;       {first N delimiters that may be repeated}
  flags: string_tkopt_t;               {token parsing option flags}
  delim_pick: sys_int_machine_t;       {delimiter that actually terminated token}
  s: string_var8192_t;                 {scratch string}
  gotsome: boolean;                    {at least part of a token has been extracted}

label
  eos, loop_retry;

begin
  s.max := size_char(s.str);           {init local var string}

  if quot
    then begin                         {tokens may be enclosed in quotes}
      flags := [string_tkopt_quoteq_k, string_tkopt_quotea_k];
      end
    else begin                         {quotes are not special}
      flags := [];
      end
    ;

  del[1] := ' ';                       {spaces are always low level delimiters}
  n_del := 1;                          {init number of delimiters}
  n_del_rept := 1;                     {this delimiter may be repeated}
  if delim <> ' ' then begin           {using an additional hard delimiter ?}
    del[2] := delim;                   {add this delimiter to the list}
    n_del := n_del + 1;
    end;

  tk.len := 0;                         {init returned string to empty}
  gotsome := false;                    {init to nothing has been extracted}

loop_retry:                            {back here if not found valid token yet}
  pdoc_in_getline (in, stat);          {make sure we have a valid input line}
  if file_eof(stat) then begin         {end of PDOC input stream encountered ?}
    if gotsome then return;            {return with string so far, normal STAT}
eos:                                   {jmp here to return with end of string status}
    sys_stat_set (string_subsys_k, string_stat_eos_k, stat); {report end of string}
    return;
    end;
  if sys_error(stat) then return;      {hard error ?}

  if in.cmd and (in.p = 1) then begin  {at the start of a new command ?}
    if gotsome then return;            {return with string so far, normal STAT}
    goto eos;                          {return with end of string status}
    end;

  if in.fmt <> pdoc_format_free_k then begin {not free format ?}
    sys_stat_set (pdoc_subsys_k, pdoc_stat_nfree_k, stat);
    sys_stat_parm_int (in.file_p^.conn.lnum, stat);
    sys_stat_parm_vstr (in.file_p^.conn.tnam, stat);
    return;
    end;
{
*   Handle case where only using simple blank delimiters.
}
  if n_del = 1 then begin              {using only blank as delimiter ?}
    string_token_anyd (                {parse the next token from the current line}
      in.line,                         {input string}
      in.p,                            {parse index}
      del, n_del, n_del_rept,          {delimiters, N delimiters, N repeatable}
      flags,                           {option flags}
      tk,                              {returned token}
      delim_pick,                      {number of definative delimiter (unused)}
      stat);
    if string_eos(stat) then goto loop_retry; {nothing left on this line ?}
    return;
    end;
{
*   A separate hard non-space delimiter is being used.  We assemble the real
*   token in TK from separate tokens parsed from the input stream until the
*   hard delimiter is found.
}
    string_token_anyd (                {parse the next token from the current line}
      in.line,                         {input string}
      in.p,                            {parse index}
      del, n_del, n_del_rept,          {delimiters, N delimiters, N repeatable}
      flags,                           {option flags}
      s,                               {returned token}
      delim_pick,                      {number of the definative delimiter}
      stat);
    if string_eos(stat) then goto loop_retry; {nothing left on this line ?}
    if sys_error(stat) then return;    {hard error ?}

    if s.len > 0 then begin            {got another piece of the overall token ?}
      if tk.len > 0 then begin         {there is a previous string in TK ?}
        string_append1 (tk, ' ');      {add separator before new string}
        end;
      string_append (tk, s);           {add this string to overall token}
      gotsome := true;                 {indicate there is something in TK to return}
      end;

    if delim_pick > n_del_rept         {encountered a hard delimiter ?}
      then return;
    goto loop_retry;                   {back to get next piece of overall token}
    end;
