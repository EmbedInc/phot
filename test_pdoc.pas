{   Program TEST_PDOC <fnam>
*
*   Test a PDOC file and the PDOC reading library by dumping the interpreted
*   contents of the PDOC file to standard output.
}
program test_pdoc;
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'img.ins.pas';
%include 'pdoc.ins.pas';

const
  max_msg_parms = 1;                   {max parameters we can pass to a message}

var
  fnam: string_treename_t;             {file name argument from command line}
  in: pdoc_in_t;                       {PDOC file input state}
  out: pdoc_out_t;                     {PDOC file output state}
  pdoc: pdoc_t;                        {info from PDOC file}
  conn: file_conn_t;                   {I/O stream connection}
  wflags: pdoc_wflag_t;                {set of picture writing option flags}

  opt: string_treename_t;              {command line option name}
  pick: sys_int_machine_t;             {number of token picked from list}
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status code}

label
  next_opt, err_parm, done_opts;

begin
  fnam.max := size_char(fnam.str);     {init local var strings}
  opt.max := size_char(opt.str);

  fnam.len := 0;                       {init to PDOC file name not given}
  wflags := [];                        {init to no picture writing flags set}
{
*   Back here each new command line option.
}
next_opt:
  string_cmline_token (opt, stat);     {get next command line option name}
  if string_eos(stat) then goto done_opts; {exhausted command line ?}
  sys_error_abort (stat, 'string', 'cmline_opt_err', nil, 0);
  if (opt.len >= 1) and (opt.str[1] <> '-') then begin {implicit pathname token ?}
    if fnam.len = 0 then begin         {input file name not set yet ?}
      string_copy (opt, fnam);         {set input file name}
      goto next_opt;
      end;
    sys_msg_parm_vstr (msg_parm[1], opt);
    sys_message_bomb ('string', 'cmline_opt_conflict', msg_parm, 1);
    end;
  string_upcase (opt);                 {make upper case for matching list}
  string_tkpick80 (opt,                {pick command line option name from list}
    '-ALL',
    pick);                             {number of keyword picked from list}
  case pick of                         {do routine for specific option}
{
*   -ALL
}
1: begin
  wflags := wflags + [pdoc_wflag_all_k];
  end;
{
*   Unrecognized command line option.
}
otherwise
    string_cmline_opt_bad;             {unrecognized command line option}
    end;                               {end of command line option case statement}

err_parm:                              {jump here on error with parameter}
  string_cmline_parm_check (stat, opt); {check for bad command line option parameter}
  goto next_opt;                       {back for next command line option}

done_opts:                             {done with all the command line options}
  if fnam.len = 0 then begin
    sys_message_bomb ('pdoc', 'no_in_fnam', nil, 0);
    end;
{
*   Open the PDOC input file and build data structures from its contents.
}
  pdoc_in_open_fnam (fnam, util_top_mem_context, in, stat); {open PDOC file, init input state}
  sys_msg_parm_vstr (msg_parm[1], fnam);
  sys_error_abort (stat, 'pdoc', 'open_pdoc_in', msg_parm, 1);

  pdoc_init (util_top_mem_context, pdoc); {initialize PDOC file info structure}
  pdoc_read (in, pdoc, stat);          {read PDOC file, create mem structures}
  sys_error_abort (stat, 'pdoc', 'read_pdoc_file', nil, 0);
  pdoc_in_close (in);                  {close PDOC input file}
{
*   Write the PDOC file information to standard output.
}
  file_open_stream_text (              {create connection to system stream}
    sys_sys_iounit_stdout_k,           {system stream ID}
    [file_rw_write_k],                 {read/write access to the stream}
    conn,                              {returned connection to stream}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  pdoc_out_init (out);                 {init PDOC output stream state}
  out.conn_p := addr(conn);            {set pointer to stream connection}

  pdoc_write_pics (                    {write in-memory info to PDOC output stream}
    out,                               {PDOC output stream state}
    pdoc.pics_p,                       {pointer to first picture in list}
    wflags,                            {set of option flags}
    stat);
  sys_error_abort (stat, 'pdoc', 'write_pdoc_stream', nil, 0);

  file_close (conn);                   {close connection to output stream}
{
*   Clean up before exiting.
}
  pdoc_release (pdoc);                 {release PDOC data resources}
  end.
