{   Public include file for the PDOC library.  This library manipulates
*   Embed photograph documentation (PDOC) files.
}
const
  pdoc_subsys_k = -34;                 {subsystem ID for PDOC library}

  pdoc_stat_nocmd_k = 1;               {new command not found where expected}
  pdoc_stat_badfmt_k = 2;              {unrecognized format character encountered}
  pdoc_stat_nfree_k = 3;               {not in free format when required}
  pdoc_stat_badtime_k = 4;             {bad time specifier token encountered}
  pdoc_stat_noname_k = 5;              {no name supplied for picture}
  pdoc_stat_nofilm_k = 6;              {no current film}
  pdoc_stat_timeorder_k = 7;           {time values are out of order}
  pdoc_stat_defloc_nfirst_k = 8;       {default location not first arg in list}
  pdoc_stat_nrefname_k = 9;            {reference name is missing}
  pdoc_stat_nfullname_k = 10;          {full person name is missing}
  pdoc_stat_name_nfound_k = 11;        {person ref name not found in list}
  pdoc_stat_nlon_k = 12;               {no longitude argument supplied}
  pdoc_stat_badcmd_k = 13;             {unrecognized PDOC stream command}
  pdoc_stat_unused_args_k = 14;        {unused arguments at end of PDOC command}
  pdoc_stat_badfmtid_k = 15;           {unrecognized format ID}
  pdoc_stat_nonamei_k = 16;            {picture has no name in internal descriptor}
  pdoc_stat_nforig_k = 17;             {image not found in the ORIG directory}
  pdoc_stat_person_dup_k = 18;         {duplicate person definition, <name>}
  pdoc_stat_pdat_nparm_k = 19;         {missing parameter to keyword in personData}
  pdoc_stat_err_keyw_k = 20;           {error on getting keyword of command}
  pdoc_stat_badkeyw_k = 21;            {invalid keyword in command}
  pdoc_stat_prevdef_k = 22;            {data previously defined}
  pdoc_stat_badparmkeyw_k = 23;        {bad parameter to keyword}
  pdoc_stat_extraparmkeyw_k = 24;      {extra parameters to keyword}
  pdoc_stat_missparmkeyw_k = 25;       {missing parameter to keyword}
  pdoc_stat_badpersid_k = 26;          {invalid or unassigned person ID, <name>}
  pdoc_stat_fnames_k = 27;             {full names mismatch}
  pdoc_stat_descs_k = 28;              {persons description text mismatch}
  pdoc_stat_portraits_k = 29;          {persons portrait file names mismatch}
  pdoc_stat_wikitrees_k = 30;          {persons WikiTree IDs mismatch}
  pdoc_stat_nestlev_k = 31;            {input file nesting too deep}
  pdoc_stat_errimgrd_k = 32;           {error reading image file}

  pdoc_maxlen_free_k = 80;             {max desired length for free format lines}
  pdoc_fmtchar_free_k = ' ';           {free format ID character}
  pdoc_fmtchar_fixed_k = ':';          {fixed format ID character}
  pdoc_maxnest_k = 16;                 {max input file nesting allowed}

type
  pdoc_format_k_t = (                  {IDs for each of the PDOC line formats}
    pdoc_format_free_k,                {arbitrary wrapping, line break = space}
    pdoc_format_fixed_k);              {no wrapping, display exactly as written}

  pdoc_infile_p_t = ^pdoc_infile_t;
  pdoc_infile_t = record               {data about one PDOC input file}
    prev_p: pdoc_infile_p_t;           {points to parent input file, NIL at top}
    conn: file_conn_t;                 {connection to the input file}
    dir: string_treename_t;            {start directory for relative file names}
    end;

  pdoc_in_t = record                   {low level reading input stream state}
    mem_p: util_mem_context_p_t;       {context for all dynamic memory referenced here}
    file_p: pdoc_infile_p_t;           {pointer to current input file data}
    level: sys_int_machine_t;          {nesting level, 0 for no input open}
    line: string_var8192_t;            {last complete line read from input stream}
    p: string_index_t;                 {LINE parse index}
    fmt: pdoc_format_k_t;              {format for data part of line, if any}
    lful: boolean;                     {TRUE if LINE contains a yet unused line}
    cmd: boolean;                      {LINE contains a command}
    end;
  pdoc_in_p_t = ^pdoc_in_t;

  pdoc_lines_p_t = ^pdoc_lines_t;
  pdoc_lines_t = record                {multiple text lines with any formatting}
    prev_p: pdoc_lines_p_t;            {pnt to previous line, NIL for first}
    next_p: pdoc_lines_p_t;            {pnt to next line, NIL for last}
    fmt: pdoc_format_k_t;              {format for this line}
    line_p: string_var_p_t;            {pointer to the text for this line}
    end;

  pdoc_person_t = record               {info about one person}
    name_p: string_var_p_t;            {pnt to PDOC quick reference name, case-sensitive}
    fname_p: string_var_p_t;           {pnt to full name string}
    desc_p: pdoc_lines_p_t;            {pnt to lines describing person}
    pic_p: string_var_p_t;             {pointer to pathname of person's picture}
    wikitree_p: string_var_p_t;        {WikiTree ID, like Smith-495}
    intid: sys_int_machine_t;          {1-N internal ID, 0 not assigned yet}
    ref: boolean;                      {this person is referenced from other data}
    wr: boolean;                       {TRUE if person definition written to output}
    end;
  pdoc_person_p_t = ^pdoc_person_t;

  pdoc_perent_p_t = ^pdoc_perent_t;
  pdoc_perent_t = record               {linked list entry for one person}
    prev_p: pdoc_perent_p_t;           {points to previous person, NIL for first}
    next_p: pdoc_perent_p_t;           {points to next person in list, NIL for last}
    ent_p: pdoc_person_p_t;            {points to info about this person}
    end;

  pdoc_perslist_t = record             {person list, separate from PDOC file data}
    mem_p: util_mem_context_p_t;       {context for all dynamic memory referenced here}
    first_p: pdoc_perent_p_t;          {points to first list entry}
    last_p: pdoc_perent_p_t;           {points to last list entry}
    nextid: sys_int_machine_t;         {1-N ID to assign to next person}
    end;

  pdoc_gcoor_t = record                {info about one geographic coordinate}
    lat: double;                       {latitude in degrees north of the equator}
    lon: double;                       {longitude in degrees west of Greenwich}
    rad: real;                         {err tolerance from exact coordinate, meters}
    end;
  pdoc_gcoor_p_t = ^pdoc_gcoor_t;

  pdoc_cmd_t = record                  {info about one "escape" command}
    org: string_var80_t;               {organization name, always lower case}
    cmd: string_var32_t;               {command name within org, first char upper case}
    lines_p: pdoc_lines_p_t;           {pointer to command parameter lines}
    end;
  pdoc_cmd_p_t = ^pdoc_cmd_t;

  pdoc_cmdent_p_t = ^pdoc_cmdent_t;
  pdoc_cmdent_t = record               {linked list entry for one "escape" command}
    prev_p: pdoc_cmdent_p_t;           {points to previous entry, NIL for first}
    next_p: pdoc_cmdent_p_t;           {points to next entry, NIL for last}
    ent_p: pdoc_cmd_p_t;               {points to info for this escape command}
    end;

  pdoc_timerange_t = record            {range of time}
    time1: sys_clock_t;                {earliest time of range}
    time2: sys_clock_t;                {latest time of range}
    end;
  pdoc_timerange_p_t = ^pdoc_timerange_t;

  pdoc_strent_p_t = ^pdoc_strent_t;
  pdoc_strent_t = record               {one string in sequential list of strings}
    prev_p: pdoc_strent_p_t;           {points to previous entry, NIL for first}
    next_p: pdoc_strent_p_t;           {points to next entry, NIL for last}
    str_p: string_var_p_t;             {points to this string}
    end;

  pdoc_field_k = (                     {list of fields can't tell if present by value}
    pdoc_field_time_k,                 {time set, TIME_P NIL for specifically unknown}
    pdoc_field_tz_k,                   {time zone hours offset}
    pdoc_field_alt_k);                 {altitude}
  pdoc_field_k_t = set of pdoc_field_k;

  pdoc_pic_t = record                  {info about one picture}
    name_p: string_var_p_t;            {pnt to name of this picture, within film if any}
    namespace_p: string_var_p_t;       {pnt to film name space name string}
    film_p: string_var_p_t;            {pnt to film name string}
    filmdesc_p: pdoc_lines_p_t;        {pnt to film description lines}
    copyright_p: string_var_p_t;       {pnt to copyright owner string}
    tzone: real;                       {time zone hours west of CUT}
    time_p: pdoc_timerange_p_t;        {pnt to time interval picture taken within}
    quick_p: string_var_p_t;           {pnt to quick description string}
    desc_p: pdoc_lines_p_t;            {pnt to long description lines}
    stored_p: pdoc_strent_p_t;         {pnt to list of places this image is stored}
    loc_of_p: pdoc_strent_p_t;         {pnt to loc names list for picture subject}
    loc_from_p: pdoc_strent_p_t;       {pnt to loc names list where taken from}
    loc_desc_p: pdoc_lines_p_t;        {pnt to location description lines}
    people_p: pdoc_perent_p_t;         {pnt to chain of people in this picture}
    by_p: pdoc_perent_p_t;             {pnt to chain of people created this picture}
    gcoor_of_p: pdoc_gcoor_p_t;        {pnt to geographic coor of subject}
    gcoor_from_p: pdoc_gcoor_p_t;      {pnt to geographic coor taken from}
    esc_p: pdoc_cmdent_p_t;            {pnt to chain of escape commands that apply}
    deriv_p: pdoc_strent_p_t;          {pnt to generic names of images derived from this one}
    iso: real;                         {ISO film speed or equiv, 0 = unknown}
    exptime: real;                     {exposure time in seconds, 0 = unknown}
    fstop: real;                       {F-stop number, 0 = unknown}
    focal: real;                       {lens focal length, 0 = unknown}
    focal35: real;                     {35mm equivalent focal length, 0 = unknown}
    altitude: real;                    {meters above sea level}
    manuf_p: string_var_p_t;           {pnt to source equipment manufacturer string}
    model_p: string_var_p_t;           {pnt to source equipment model string}
    softw_p: string_var_p_t;           {pnt to source software name string}
    host_p: string_var_p_t;            {pnt to name of computer originated on}
    user_p: string_var_p_t;            {pnt to user name on host system originated by}
    fields: pdoc_field_k_t;            {indicates which fields without illegal values are set}
    end;
  pdoc_pic_p_t = ^pdoc_pic_t;

  pdoc_picent_p_t = ^pdoc_picent_t;
  pdoc_picent_t = record               {chain entry for one picture in list}
    prev_p: pdoc_picent_p_t;           {points to previous entry, NIL for first}
    next_p: pdoc_picent_p_t;           {points to next entry, NIL for last}
    ent_p: pdoc_pic_p_t;               {points to info about this picture}
    end;

  pdoc_t = record                      {info from a PDOC file}
    mem_p: util_mem_context_p_t;       {points to private memory context}
    people_p: pdoc_perent_p_t;         {points to list of people}
    pics_p: pdoc_picent_p_t;           {points to list of pictures}
    lastpic_p: pdoc_picent_p_t;        {points to last entry in list of pictures}
    end;

  pdoc_out_t = record                  {low level state for writing PDOC out stream}
    conn_p: file_conn_p_t;             {pnt to raw output stream connection}
    buf: string_var8192_t;             {one line output buffer}
    fmt: pdoc_format_k_t;              {format of the current line in BUF}
    end;
  pdoc_out_p_t = ^pdoc_out_t;

  pdoc_wflag_k_t = (                   {flags to modify writing of picture data}
    pdoc_wflag_all_k);                 {write all field vals, not just modified ones}
  pdoc_wflag_t = set of pdoc_wflag_k_t; {all the writing flags in one set}
{
*   Public entry points.
}
procedure pdoc_dbg_person (            {write person info to standard output}
  in      p: pdoc_person_t);           {person descriptor}
  val_param; extern;

procedure pdoc_dtm_image (             {add date/time from image file if unknown}
  in out  pic: pdoc_pic_t;             {picture to add image file header information to}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in      fnam: univ string_var_arg_t; {name of image to add file system date/time from}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure pdoc_find_pic_name (         {find picture by name}
  in      list_p: pdoc_picent_p_t;     {pointer to start of pictures list}
  in      name: univ string_var_arg_t; {picture name, case insensitive}
  out     pic_p: pdoc_pic_p_t);        {will point to picture, NIL = not found}
  val_param; extern;

procedure pdoc_get_angle (             {get next token as angle in degrees:minutes}
  in out  in: pdoc_in_t;               {input stream state}
  out     ang: double;                 {returned angle in degrees}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_get_fp (                {get next token as floating point value}
  in out  in: pdoc_in_t;               {input stream state}
  out     fp: double;                  {returned floating point value}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_get_gcoorp (            {get pointer to geographic coordinate}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  out     coor_p: pdoc_gcoor_p_t;      {pointer to geographic coordinate info}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param; extern;

procedure pdoc_get_lines (             {get remaining data as list of text lines}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  out     lines_p: pdoc_lines_p_t;     {pointer to start of chain, may be NIL}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param; extern;

procedure pdoc_get_locp (              {get location names hierarchy chain}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in      def_p: pdoc_strent_p_t;      {points to default location names, may be NIL}
  out     loc_p: pdoc_strent_p_t;      {pointer to location names list, may be NIL}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param; extern;

procedure pdoc_get_name (              {get next <name> token, comma separated}
  in out  in: pdoc_in_t;               {input stream state}
  in out  name: univ string_var_arg_t; {returned name token, always upper case}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_get_people (            {get list of people from reference name args}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in      people_p: pdoc_perent_p_t;   {pointer to list of known people, may be NIL}
  out     list_p: pdoc_perent_p_t;     {pointer to resulting people list, may be NIL}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param; extern;

procedure pdoc_get_person (            {get a person definition, add to list}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in out  pers_p: pdoc_perent_p_t;     {pointer to start of list, may be NIL on entry}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param; extern;

procedure pdoc_get_personData (        {add extra data to person definition}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in      pers_p: pdoc_perent_p_t;     {points to persons list}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param; extern;

procedure pdoc_get_semistr (           {get next string token, semicolon separated}
  in out  in: pdoc_in_t;               {input stream state}
  in out  str: univ string_var_arg_t;  {returned string}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_get_strlist (           {get list of strings, semicolon separated}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  out     str_p: pdoc_strent_p_t;      {pnt to first list entry, NIL for empty list}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param; extern;

procedure pdoc_get_text (              {get remaining free format data string}
  in out  in: pdoc_in_t;               {input stream state}
  in out  str: univ string_var_arg_t;  {returned text string}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_get_textp (             {get pnt to free format text string}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  out     text_p: string_var_p_t;      {pointer to text string, may be NIL}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param; extern;

procedure pdoc_get_time (              {get next token as an absolute time}
  in out  in: pdoc_in_t;               {input stream state}
  in      tzone: real;                 {zone to interpret time in, hours west of CUT}
  out     time1: sys_clock_t;          {start of time interval}
  out     time2: sys_clock_t;          {end of time interval}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_get_timerange (         {get pointer to time range specified by args}
  in out  in: pdoc_in_t;               {input stream state}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in      tzone: real;                 {zone to interpret time in, hours west of CUT}
  out     range_p: pdoc_timerange_p_t; {pointer to time range descriptor, may be NIL}
  out     stat: sys_err_t);            {completion status code, no error on EOS}
  val_param; extern;

procedure pdoc_header_add_fnam (       {add info from image file to picture}
  in out  pic: pdoc_pic_t;             {picture to add image file header information to}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in      fnam: univ string_var_arg_t; {name of image to add info from}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure pdoc_header_add_head (       {add info from header descriptor to picture}
  in out  pic: pdoc_pic_t;             {picture to add image file header information to}
  in out  mem: util_mem_context_t;     {mem context for any newly allocated memory}
  in      head: img_head_t);           {the header information to add}
  val_param; extern;

procedure pdoc_in_close (              {close stream opened with PDOC_IN_OPEN_FNAM}
  in out  in: pdoc_in_t);              {will close stream, deallocate resources}
  val_param; extern;

procedure pdoc_in_cmd (                {get next command name from input stream}
  in out  in: pdoc_in_t;               {input stream state}
  in out  cmd: univ string_var_arg_t;  {returned command name}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_in_file_push (          {open nested input file}
  in out  in: pdoc_in_t;               {input stream state}
  in      fnam: univ string_var_arg_t; {name of new file to open}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure pdoc_in_getline (            {get next input line, unless already have it}
  in out  in: pdoc_in_t;               {input stream state}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_in_line (               {get next data line, or rest of curr line}
  in out  in: pdoc_in_t;               {input stream state}
  in out  line: univ string_var_arg_t; {returned data line}
  out     fmt: pdoc_format_k_t;        {format type of this data line}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_in_open_fnam (          {open PDOC file and set up input stream state}
  in      fnam: univ string_var_arg_t; {file name, .pdoc suffix may be omitted}
  in out  mem: util_mem_context_t;     {parent memory context}
  out     in: pdoc_in_t;               {returned input stream state}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_in_stat_fnam (          {add the input file name as next parm in STAT}
  in      in: pdoc_in_t;               {PDOC reading state}
  in out  stat: sys_err_t);            {will have string parameter added}
  val_param; extern;

procedure pdoc_in_stat_lnum (          {add the input line number as next parm in STAT}
  in      in: pdoc_in_t;               {PDOC reading state}
  in out  stat: sys_err_t);            {will have integer parameter added}
  val_param; extern;

procedure pdoc_in_token (              {get next data token in free format}
  in out  in: pdoc_in_t;               {input stream state}
  in out  tk: univ string_var_arg_t;   {returned token}
  in      delim: char;                 {delimiter character}
  in      quot: boolean;               {TRUE if string enclosed in quotes is a token}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_init (                  {initialize a pictures list structure}
  in out  mem: util_mem_context_t;     {parent memory context, will make subordinate}
  out     pdoc: pdoc_t);               {structure to initialize}
  val_param; extern;

procedure pdoc_out_blank (             {write blank line to PDOC stream output}
  in out  out: pdoc_out_t;             {output stream state}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_out_buf (               {output all remaining buffered data}
  in out  out: pdoc_out_t;             {output stream state}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_out_close (             {close stream opened with PDOC_OUT_OPEN_xxx}
  in out  out: pdoc_out_t;             {output stream state}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_out_cmd (               {start new command in PDOC output stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      cmd: univ string_var_arg_t;  {command name vstring}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_out_cmd_str (           {start new command in PDOC output stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      cmd: string;                 {comand name, NULL term or blank pad, 80 max}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_out_init (              {init low level PDOC stream output state}
  out     out: pdoc_out_t);            {data structure to initialize}
  val_param; extern;

procedure pdoc_out_open_fnam (         {open PDOC file and set up output stream state}
  in      fnam: univ string_var_arg_t; {file name, .pdoc suffix may be omitted}
  out     out: pdoc_out_t;             {returned output stream state}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_out_str (               {write string to PDOC output stream, any fmt}
  in out  out: pdoc_out_t;             {output stream state}
  in      str: univ string_var_arg_t;  {string to write}
  in      fmt: pdoc_format_k_t;        {format to apply to STR}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_out_token (             {add free format parameter token to PDOC out}
  in out  out: pdoc_out_t;             {output stream state}
  in      tk: univ string_var_arg_t;   {token to add to PDOC out stream in free fmt}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

function pdoc_pers_desc_same (         {check person descriptions for being same}
  in      pers1, pers2: pdoc_person_t) {the two people to check}
  :boolean;                            {no differences found in long descriptions}
  val_param; extern;

procedure pdoc_perslist_add (          {add person to persons list, if not duplicate}
  in out  perslist: pdoc_perslist_t;   {persons list to add person to}
  in out  perent: pdoc_perent_t;       {entry in other list of person to add}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure pdoc_perslist_close (        {deallocate resources of a separate persons list}
  in out  perslist: pdoc_perslist_t);  {returned unusable, must be initialized before use}
  val_param; extern;

procedure pdoc_perslist_init (         {initialize a separate persons list}
  out     perslist: pdoc_perslist_t;   {the list structure to initialize}
  in out  mem: util_mem_context_t);    {parent mem context, will make sub-context}
  val_param; extern;

procedure pdoc_pic_init (              {init a picture descriptor to all default or empty}
  out     pic: pdoc_pic_t);            {all fields will be initialized default or empty}
  val_param; extern;

procedure pdoc_put_cmd (               {write one escape command to PDOC file}
  in out  out: pdoc_out_t;             {output stream state}
  in      cmd: pdoc_cmd_t;             {the escape command to write}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_put_cmdlist (           {write list of escape commands to PDOC file}
  in out  out: pdoc_out_t;             {output stream state}
  in      list_p: pdoc_cmdent_p_t;     {pointer to start of list, may be NIL}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_put_fp (                {write floating point value to PDOC stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      fp: double;                  {floating point value to write}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_put_fp_fixed (          {write FP to PDOC stream, N fraction digits}
  in out  out: pdoc_out_t;             {output stream state}
  in      fp: double;                  {floating point value to write}
  in      n: sys_int_machine_t;        {fixed number of fraction digits}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_put_fp_sig (            {write FP to PDOC stream, N significant digits}
  in out  out: pdoc_out_t;             {output stream state}
  in      fp: double;                  {floating point value to write}
  in      n: sys_int_machine_t;        {minimum number of significant digits}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_put_gcoor (             {write geographic coordinate to PDOC stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      coor_p: pdoc_gcoor_p_t;      {pointer to geographic coordinate info}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_put_lines (             {write list of data lines to PDOC stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      lines_p: pdoc_lines_p_t;     {pointer to first line in list, may be NIL}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_put_loc (               {write location hierarchy to PDOC stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      loc_p: pdoc_strent_p_t;      {pointer to start of location hierarchy list}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_put_people (            {write list of people reference names to PDOC}
  in out  out: pdoc_out_t;             {output stream state}
  in      list_p: pdoc_perent_p_t;     {pointer to first entry in the list}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_put_person (            {write info about one person to PDOC stream}
  in out  out: pdoc_out_t;             {output stream state}
  in out  pers: pdoc_person_t;         {person information}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_put_str (               {write free format string to PDOC out stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      str_p: string_var_p_t;       {pointer to string}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_put_strlist (           {write list of free format strings to PDOC out stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      list_p: pdoc_strent_p_t;     {pointer to list of strings}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_put_time (              {write time specifier to PDOC stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      time: sys_clock_t;           {time to represent}
  in      tzone: real;                 {time zone in hours west of CUT}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_put_timerange (         {write time range tokens to PDOC stream}
  in out  out: pdoc_out_t;             {output stream state}
  in      range_p: pdoc_timerange_p_t; {pointer to time range descriptor}
  in      tzone: real;                 {time zone in hours west of CUT}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_read (                  {read PDOC stream and build picture list}
  in out  in: pdoc_in_t;               {input stream state}
  in out  pdoc: pdoc_t;                {add info to this, previously initialized}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_release (               {release all resources allocated to PDOC structure}
  in out  pdoc: pdoc_t);               {returned invalid, must be initialized before next use}
  val_param; extern;

procedure pdoc_write_pic (             {write PDOC commands for one picture}
  in out  out: pdoc_out_t;             {output stream state}
  in      pics_p: pdoc_picent_p_t;     {pointer to list of all pictures}
  in      pic: pdoc_pic_t;             {picture descriptor to write commands for}
  in      prev_p: pdoc_pic_p_t;        {pnt to previous pic descriptor, may be NIL}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure pdoc_write_pics (            {write PDOC commands for list of pictures}
  in out  out: pdoc_out_t;             {output stream state}
  in      list_p: pdoc_picent_p_t;     {pointer to start of pictures list}
  in      flags: pdoc_wflag_t;         {set of option flags}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;
