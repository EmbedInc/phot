{   Low level PDOC output stream handling routines.  All other PDOC writing
*   routines are layered on the routines in this module.
}
module pdoc_out;
define pdoc_out_init;
define pdoc_out_open_fnam;
define pdoc_out_close;
define pdoc_out_buf;
define pdoc_out_blank;
define pdoc_out_cmd;
define pdoc_out_cmd_str;
define pdoc_out_token;
define pdoc_out_line;
define pdoc_out_str;
%include 'pdoc2.ins.pas';
{
***********************************************************************
*
*   Subroutine PDOC_OUT_INIT (OUT)
*
*   Initialize a low level PDOC library output stream state descriptor.
*   Applications shouls always use this routine to initialize the descriptor
*   to minimize compatibility problems between versions.
}
procedure pdoc_out_init (              {init low level PDOC stream output state}
  out     out: pdoc_out_t);            {data structure to initialize}
  val_param;

begin
  out.conn_p := nil;
  out.buf.max := size_char(out.buf.str);
  out.buf.len := 0;
  out.fmt := pdoc_format_free_k;
  end;
{
***********************************************************************
*
*   Subroutine PDOC_OUT_OPEN_FNAM (FNAM, OUT, STAT)
*
*   Open a PDOC output stream to the file of name FNAM.  The .pdoc file name
*   suffix may be omitted from FNAM.  OUT will be returned fully initialized.
*
*   PDOC_OUT_CLOSE must be called to close the stream when done.
}
procedure pdoc_out_open_fnam (         {open PDOC file an set up output stream state}
  in      fnam: univ string_var_arg_t; {file name, .pdoc suffix may be omitted}
  out     out: pdoc_out_t;             {returned output stream state}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  pdoc_out_init (out);                 {initialize output stream state}
  sys_mem_alloc (sizeof(out.conn_p^), out.conn_p); {allocate file connection info}
  sys_mem_error (out.conn_p, 'pdoc', 'nomem_out_open_fnam', nil, 0);

  file_open_write_text (               {open PDOC output file}
    fnam, '.pdoc',                     {file name and suffix}
    out.conn_p^,                       {returned connection to file}
    stat);
  if sys_error(stat) then begin        {error on open PDOC file ?}
    sys_mem_dealloc (out.conn_p);      {deallocate connection descriptor}
    return;
    end;
  end;
{
***********************************************************************
*
*   Subroutine PDOC_OUT_CLOSE (OUT, STAT)
*
*   Close the PDOC output stream opened with one of the PDOC_OUT_OPEN_xxx
*   routines.  This routine closes and deallocates any additional resources
*   allocated in the OPEN routine.
}
procedure pdoc_out_close (             {close stream opened with PDOC_OUT_OPEN_xxx}
  in out  out: pdoc_out_t;             {output stream state}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  pdoc_out_buf (out, stat);            {write any buffered data to the output stream}
  file_close (out.conn_p^);            {close output stream}
  sys_mem_dealloc (out.conn_p);        {release output stream connection descriptor}
  end;
{
***********************************************************************
*
*   Subroutine PDOC_OUT_BUF (OUT, STAT)
*
*   Write all remaining buffered output data to the output stream.  This call
*   does nothing if there is no buffered output data to write.
}
procedure pdoc_out_buf (               {output all remaining buffered data}
  in out  out: pdoc_out_t;             {output stream state}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  sys_error_none(stat);                {init to no error occurred}

  if out.buf.len <= 0 then return;     {nothing to output ?}

  file_write_text (                    {write the string to the output stream}
    out.buf,                           {string to write}
    out.conn_p^,                       {connection to output stream}
    stat);
  if sys_error(stat) then return;

  out.buf.len := 0;                    {reset output buffer to empty}
  end;
{
***********************************************************************
*
*   Subroutine PDOC_OUT_BLANK (OUT, STAT)
*
*   Write a blank line to the PDOC output stream.
}
procedure pdoc_out_blank (             {write blank line to PDOC stream output}
  in out  out: pdoc_out_t;             {output stream state}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  pdoc_out_buf (out, stat);            {write out any previously buffered data}
  if sys_error(stat) then return;

  file_write_text (                    {write the blank line to the output}
    out.buf,                           {string to write, empty}
    out.conn_p^,                       {connection to output stream}
    stat);
  end;
{
***********************************************************************
*
*   Subroutine PDOC_OUT_CMD (OUT, CMD, STAT)
*
*   Start a new PDOC output stream command.  CMD is the command name.
}
procedure pdoc_out_cmd (               {start new command in PDOC output stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      cmd: univ string_var_arg_t;  {command name vstring}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  pdoc_out_buf (out, stat);            {write anything already in the output buffer}
  if sys_error(stat) then return;

  string_copy (cmd, out.buf);          {start new line with command in column 1}
  out.fmt := pdoc_format_free_k;       {command lines are always free format}
  end;
{
***********************************************************************
*
*   Subroutine PDOC_OUT_CMD_STR (OUT, CMD, STAT)
*
*   Like PDOC_OUT_CMD, except that CMD is a normal string, not a var string.
*   CMD may be blank padded or NULL terminated, but must not be more than 80
*   characters (including the NULL).
}
procedure pdoc_out_cmd_str (           {start new command in PDOC output stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      cmd: string;                 {comand name, NULL term or blank pad, 80 max}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  vcmd: string_var80_t;                {var string copy of command name}

begin
  vcmd.max := size_char(vcmd.str);     {init local var string}

  string_vstring (vcmd, cmd, size_char(cmd)); {convert command name to var string}
  pdoc_out_cmd (out, vcmd, stat);      {call low level routine with var string}
  end;
{
***********************************************************************
*
*   Subroutine PDOC_OUT_TOKEN (OUT, TK, STAT)
*
*   Add the token TK to the PDOC output stream in free format.
}
procedure pdoc_out_token (             {add free format parameter token to PDOC out}
  in out  out: pdoc_out_t;             {output stream state}
  in      tk: univ string_var_arg_t;   {token to add to PDOC out stream in free fmt}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  sp: sys_int_machine_t;               {number of spaces before previous token}

label
  loop_line;

begin
  sys_error_none (stat);               {init to no error occurred}

  if out.fmt <> pdoc_format_free_k then begin {current line is not free format ?}
    pdoc_out_buf (out, stat);          {empty the buffer}
    if sys_error(stat) then return;
    end;

loop_line:                             {back here to try with a new line}
  if out.buf.len = 0 then begin        {starting with an empty line ?}
    out.buf.str[1] := ' ';             {this is not a command line}
    out.buf.str[2] := pdoc_fmtchar_free_k; {specify free format}
    out.buf.len := 2;
    out.fmt := pdoc_format_free_k;     {new line will be in free format}
    end;

  if (out.buf.len = 2) and (out.buf.str[1] = ' ') then begin {no previous token ?}
    string_append (out.buf, tk);       {start data part of line with the new token}
    return;
    end;
{
*   There are previous tokens on the line.  Add the new token to the line
*   if it fits, otherwise write the current line and start a new line.
}
  sp := 1;                             {init number of spaces before previous token}
  case out.buf.str[out.buf.len] of     {check special case token ending chars}
'.', '!', '?': sp := 2;
    end;

  if (out.buf.len + sp + tk.len) > pdoc_maxlen_free_k then begin {new tk not fit ?}
    pdoc_out_buf (out, stat);          {write existing line}
    if sys_error(stat) then return;
    goto loop_line;                    {go back with empty output line}
    end;

  string_appendn (out.buf, '    ', sp); {add spaces before new token}
  string_append (out.buf, tk);         {add the new token}
  end;
{
***********************************************************************
*
*   Subroutine PDOC_OUT_STR (OUT, STR, FMT, STAT)
*
*   Write the string STR to the PDOC output stream using the format specified
*   in FMT.  For free format, the string is wrapped to multiple lines as
*   appropriate.  For fixed format, STR is written as one line.
}
procedure pdoc_out_str (               {write string to PDOC output stream, any fmt}
  in out  out: pdoc_out_t;             {output stream state}
  in      str: univ string_var_arg_t;  {string to write}
  in      fmt: pdoc_format_k_t;        {format to apply to STR}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  tk: string_var8192_t;                {token parsed from STR}
  p: string_index_t;                   {STR parse index}
  ii: sys_int_machine_t;

label
  loop_free;

begin
  tk.max := size_char(tk.str);         {init local var string}

  sys_error_none (stat);               {init to no error occurred}

  case fmt of                          {what format is specified}
{
*   Free format.
}
pdoc_format_free_k: begin
  p := 1;                              {init STR parse index}
loop_free:                             {back here each new token parse from STR}
  string_token_anyd (                  {get next blank-separated group of characters}
    str,                               {input string}
    p,                                 {parse index}
    ' ', 1,                            {list of delimiters}
    1,                                 {first N delimiters that may be repeated}
    [],                                {no options}
    tk,                                {returned token}
    ii,                                {index of ending delimiter}
    stat);
  if string_eos(stat) then return;     {exhausted input string ?}
  if sys_error(stat) then return;
  pdoc_out_token (out, tk, stat);      {write this token to PDOC output stream}
  if sys_error(stat) then return;
  goto loop_free;                      {back for next token from input string}
  end;
{
*   Fixed format.
}
pdoc_format_fixed_k: begin
  pdoc_out_buf (out, stat);            {make sure the one line buffer is empty}
  if sys_error(stat) then return;
  out.buf.str[1] := ' ';               {this is not command line}
  out.buf.str[2] := pdoc_fmtchar_fixed_k; {indicate fixed format}
  out.buf.len := 2;
  out.fmt := pdoc_format_fixed_k;      {indicate buffer contains fixed format info}
  string_append (out.buf, str);        {copy data string to output line}
  end;
{
*   Unrecognized format.
}
otherwise
    sys_stat_set (pdoc_subsys_k, pdoc_stat_badfmtid_k, stat);
    sys_stat_parm_int (ord(fmt), stat);
    end;
  end;
