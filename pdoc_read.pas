{   Top level routines for reading PDOC files.
}
module pdoc_read;
define pdoc_init;
define pdoc_read;
%include 'pdoc2.ins.pas';

type
  pictype_k_t = (                      {different types of pictures}
    pictype_frame_k,                   {one frame within a film}
    pictype_pic_k);                    {individual stand alone picture}

var
  cmds: string_var8192_t;              {command names separated by blanks}
  cmds_set: boolean := false;          {TRUE if CMDS set already}
{
********************************************************************************
*
*   Local subroutine COMMAND (NAME)
*
*   Add the command NAME to the list of commands.
}
procedure command (                    {add command to end of commands list}
  in      name: string);               {name of command to add, case sensitive}
  val_param;

var
  cmd: string_var32_t;                 {vstring version of command name}

begin
  cmd.max := size_char(cmd.str);       {init local var string}

  string_vstring (cmd, name, size_char(name)); {make vstring command name in CMD}
  if cmds.len > 0 then string_append1 (cmds, ' '); {add separator after last command}
  string_append (cmds, cmd);           {append new command to end of list}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_INIT (MEM, PDOC)
*
*   Initialize the pictures list descriptor PDOC.  This is required before using
*   it in any way, such as adding pictures to it by reading a PDOC file.  MEM is
*   the parent memory context.  A subordinate memory context will be created,
*   and all dynamic memory created for use with this PDOC descriptor will be
*   under the subordinate memory context.
}
procedure pdoc_init (                  {initialize a pictures list structure}
  in out  mem: util_mem_context_t;     {parent memory context, will make subordinate}
  out     pdoc: pdoc_t);               {structure to initialize}
  val_param;

begin
{
*   Initialize the global state of this module, if this has not already been
*   done.
}
  if not cmds_set then begin           {global state not previously initialized ?}
    sys_thread_lock_enter_all;         {only one thread at a time is allowed here}
    if not cmds_set then begin         {no other thread set CMDS in the mean time ?}
      cmds.max := size_char(cmds.str); {init CMDS var string}
      cmds.len := 0;

      command ('namespace');           {1}
      command ('film');                {2}
      command ('copyright');           {3}
      command ('descFilm');            {4}
      command ('frame');               {5}
      command ('pic');                 {6}
      command ('timezone');            {7}
      command ('time');                {8}
      command ('quick');               {9}
      command ('desc');                {10}
      command ('loc');                 {11}
      command ('locDef');              {12}
      command ('locDesc');             {13}
      command ('locFrom');             {14}
      command ('locOf');               {15}
      command ('people');              {16}
      command ('person');              {17}
      command ('by');                  {18}
      command ('latlon');              {19}
      command ('latlonOf');            {20}
      command ('latlonFrom');          {21}
      command ('stored');              {22}
      command ('notime');              {23}
      command ('iso');                 {24}
      command ('exptime');             {25}
      command ('fstop');               {26}
      command ('focal');               {27}
      command ('focal35');             {28}
      command ('altitude');            {29}
      command ('manuf');               {30}
      command ('model');               {31}
      command ('softw');               {32}
      command ('host');                {33}
      command ('user');                {34}
      command ('personData');          {35}

      cmds_set := true;                {CMDS is now all set}
      end;
    sys_thread_lock_leave_all;         {OK for multiple threads to run here again}
    end;
{
*   Initialize the PDOC structure.
}
  util_mem_context_get (mem, pdoc.mem_p); {make our private subordinate memory context}
  pdoc.people_p := nil;                {init people list to empty}
  pdoc.pics_p := nil;                  {init pictures list to empty}
  pdoc.lastpic_p := nil;
  end;
{
********************************************************************************
*
*   Subroutine PDOC_READ (IN, PDOC, STAT)
*
*   Read in a PDOC stream and add the information from it to PDOC.  PDOC must
*   have been previously initialized with PDOC_INIT.  The routine can be called
*   multiple times to add the information from multiple pdoc files, for example,
*   to PDOC.
}
procedure pdoc_read (                  {read PDOC stream and build picture list}
  in out  in: pdoc_in_t;               {input stream state}
  in out  pdoc: pdoc_t;                {add info to this, previously initialized}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  fp: double;                          {scratch FP value}
  pic: pdoc_pic_t;                     {current state ready for next picture}
  locdef_p: pdoc_strent_p_t;           {pointer to default location list}
  cmdn: sys_int_machine_t;             {number of command picked from list}
  cmd: string_var132_t;                {current command name}
  buf: string_var_max_t;               {large scratch string buffer}
  tk: string_var32_t;                  {short token}
  fmt: pdoc_format_k_t;                {PDOC line format identifier}

label
  loop_command, done_command, err_extra;
{
********************************
*
*   Local subroutine PEOPLE_REFERENCED (PLIST_P)
*
*   Make sure all the people in the list pointed to by PLIST_P are marked as
*   referenced.  PLIST_P may be nil, in which case nothing is done.
}
procedure people_referenced (          {mark list of people as referenced}
  in      plist_p: pdoc_perent_p_t);   {pointer to start of list}
  val_param; internal;

var
  ent_p: pdoc_perent_p_t;              {pointer to current list entry}

begin
  ent_p := plist_p;                    {init to first list entry}

  while ent_p <> nil do begin          {scan the list}
    ent_p^.ent_p^.ref := true;         {mark this person as referenced}
    ent_p := ent_p^.next_p;            {advance to next list entry}
    end;
  end;
{
********************************
*
*   Local subroutine NEWPIC (PICTYPE)
*
*   A picture has been declared with the current state.  Create a new picture
*   descriptor and link it to the end of the chain.  PIC is set up with the
*   current state.  LAST_P is pointing to the existing end of the chain, or
*   NIL if no chain has been created yet.  LAST_P will be updated to point
*   to the newly created pictures descriptor, which will be at the end of
*   the chain.
}
procedure newpic (                     {create new picture descriptor, add to chain}
  in      pictype: pictype_k_t);       {type of picture}
  val_param;

var
  ent_p: pdoc_picent_p_t;              {pointer to new chain entry}

begin
  util_mem_grab (                      {alloc mem for the new list entry}
    sizeof(ent_p^), pdoc.mem_p^, false, ent_p);
  ent_p^.prev_p := pdoc.lastpic_p;     {link back to previous list entry}
  ent_p^.next_p := nil;                {indicate this is end of chain}
  if pdoc.lastpic_p = nil
    then begin                         {this is first chain entry}
      pdoc.pics_p := ent_p;            {set pictures list start pointer}
      end
    else begin                         {adding to existing chain}
      pdoc.lastpic_p^.next_p := ent_p; {link previous entry forward to new entry}
      end
    ;
  pdoc.lastpic_p := ent_p;             {update pointer to last list entry}

  util_mem_grab (                      {alloc pic data}
    sizeof(ent_p^.ent_p^), pdoc.mem_p^, false, ent_p^.ent_p);

  with ent_p^.ent_p^:p do begin        {P is new picture data descriptor}

    p := pic;                          {init to copy of current state}

    case pictype of                    {some picture types require special handling}
pictype_pic_k: begin                   {individual stand alone picture}
        p.film_p := nil;               {delete reference to any film}
        p.filmdesc_p := nil;
        end;
      end;                             {end of picture type cases}

    people_referenced (p.people_p);    {mark people in this picture as referenced}
    people_referenced (p.by_p);        {mark people that made this picture as referenced}

    end;                               {done with P abbreviation}

  end;
{
********************************
*
*   Start of main routine.
}
begin
  cmd.max := size_char(cmd.str);       {init local var strings}
  buf.max := size_char(buf.str);
  tk.max := size_char(tk.str);

  locdef_p := nil;                     {init to no default location list exists}
  pdoc_pic_init (pic);                 {init descriptor for this picture}
{
*   Main loop.  Come back here to get and process each new PDOC stream command.
}
loop_command:
  pdoc_in_cmd (in, cmd, stat);         {get next PDOC stream command in CMD}
  if file_eof(stat) then return;       {hit end of PDOC stream ?}
  if sys_error(stat) then return;      {hard error ?}
  string_tkpick (cmd, cmds, cmdn);     {pick command from list}
  case cmdn of                         {which command is it ?}
{
********************
*
*   Command namespace
}
1: begin                               {namespace}
  pdoc_get_textp (in, pdoc.mem_p^, pic.namespace_p, stat);
  end;
{
********************
*
*   Command film
}
2: begin                               {film}
  pdoc_get_textp (in, pdoc.mem_p^, pic.film_p, stat);
  end;
{
********************
*
*   Command copyright
}
3: begin                               {copyright}
  pdoc_get_textp (in, pdoc.mem_p^, pic.copyright_p, stat);
  end;
{
********************
*
*   Command descFilm
}
4: begin                               {descFilm}
  pdoc_get_lines (in, pdoc.mem_p^, pic.filmdesc_p, stat);
  end;
{
********************
*
*   Command frame
}
5: begin                               {frame}
  if pic.film_p = nil then begin
    sys_stat_set (pdoc_subsys_k, pdoc_stat_nofilm_k, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    return;
    end;

  pdoc_get_textp (in, pdoc.mem_p^, pic.name_p, stat);
  if pic.name_p = nil then begin
    sys_stat_set (pdoc_subsys_k, pdoc_stat_noname_k, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    return;
    end;

  newpic (pictype_frame_k);            {add new picture to returned list}
  end;
{
********************
*
*   Command pic
}
6: begin                               {pic}
  pdoc_get_textp (in, pdoc.mem_p^, pic.name_p, stat);
  if pic.name_p = nil then begin
    sys_stat_set (pdoc_subsys_k, pdoc_stat_noname_k, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    return;
    end;

  newpic (pictype_pic_k);              {add new picture to returned list}
  end;
{
********************
*
*   Command timezone
}
7: begin                               {timezone}
  pdoc_get_fp (in, fp, stat);          {get hours west of CUT}
  if string_eos(stat)
    then begin                         {timezone being unspecified}
      pic.tzone := 0.0;                {reset back to CUT default}
      pic.fields := pic.fields - [pdoc_field_tz_k]; {TZ offset not explicitly set}
      end
    else begin                         {timezone is being specified}
      pic.tzone := fp;                 {set the timezone hours west offset}
      pic.fields := pic.fields + [pdoc_field_tz_k]; {TZ offset explicitly set}
      end
    ;
  end;
{
********************
*
*   Command time
}
8: begin                               {time}
  pdoc_get_timerange (in, pdoc.mem_p^, pic.tzone, pic.time_p, stat);
  if pic.time_p = nil
    then begin                         {no time parameter}
      pic.fields := pic.fields - [pdoc_field_time_k]; {time not set}
      end
    else begin                         {time was supplied}
      pic.fields := pic.fields + [pdoc_field_time_k]; {time explicitly set}
      end
    ;
  end;
{
********************
*
*   Command quick
}
9: begin                               {quick}
  pdoc_get_textp (in, pdoc.mem_p^, pic.quick_p, stat);
  end;
{
********************
*
*   Command desc
}
10: begin                              {desc}
  pdoc_get_lines (in, pdoc.mem_p^, pic.desc_p, stat);
  end;
{
********************
*
*   Command loc
}
11: begin                              {loc}
  pdoc_get_locp (in, pdoc.mem_p^, locdef_p, pic.loc_of_p, stat);
  pic.loc_from_p := pic.loc_of_p;
  end;
{
********************
*
*   Command locDef
}
12: begin                              {locDef}
  pdoc_get_locp (in, pdoc.mem_p^, nil, locdef_p, stat);
  end;
{
********************
*
*   Command locDesc
}
13: begin                              {locDesc}
  pdoc_get_lines (in, pdoc.mem_p^, pic.loc_desc_p, stat);
  end;
{
********************
*
*   Command locFrom
}
14: begin                              {locFrom}
  pdoc_get_locp (in, pdoc.mem_p^, locdef_p, pic.loc_from_p, stat);
  end;
{
********************
*
*   Command locOf
}
15: begin                              {locOf}
  pdoc_get_locp (in, pdoc.mem_p^, locdef_p, pic.loc_of_p, stat);
  end;
{
********************
*
*   Command people
}
16: begin                              {people}
  pdoc_get_people (in, pdoc.mem_p^, pdoc.people_p, pic.people_p, stat);
  end;
{
********************
*
*   Command person
}
17: begin                              {person}
  pdoc_get_person (in, pdoc.mem_p^, pdoc.people_p, stat);
  end;
{
********************
*
*   Command by
}
18: begin                              {by}
  pdoc_get_people (in, pdoc.mem_p^, pdoc.people_p, pic.by_p, stat);
  end;
{
********************
*
*   Command latlon
}
19: begin                              {latlon}
  pdoc_get_gcoorp (in, pdoc.mem_p^, pic.gcoor_of_p, stat);
  pic.gcoor_from_p := pic.gcoor_of_p;
  end;
{
********************
*
*   Command latlonOf
}
20: begin                              {latlonOf}
  pdoc_get_gcoorp (in, pdoc.mem_p^, pic.gcoor_of_p, stat);
  end;
{
********************
*
*   Command latlonFrom
}
21: begin                              {latlonFrom}
  pdoc_get_gcoorp (in, pdoc.mem_p^, pic.gcoor_from_p, stat);
  end;
{
********************
*
*   Command stored
}
22: begin
  pdoc_get_strlist (in, pdoc.mem_p^, pic.stored_p, stat);
  end;
{
********************
*
*   Command notime
}
23: begin
  pic.time_p := nil;                   {time is unknown}
  pic.fields := pic.fields + [pdoc_field_time_k]; {indicate time explicitly set}
  end;
{
********************
*
*   Command iso
}
24: begin
  pdoc_get_fp (in, fp, stat);
  if string_eos(stat)
    then pic.iso := 0.0
    else pic.iso := fp;
  end;
{
********************
*
*   Command exptime
}
25: begin
  pdoc_get_fp (in, fp, stat);
  if string_eos(stat)
    then pic.exptime := 0.0
    else pic.exptime := fp;
  end;
{
********************
*
*   Command fstop
}
26: begin
  pdoc_get_fp (in, fp, stat);
  if string_eos(stat)
    then pic.fstop := 0.0
    else pic.fstop := fp;
  end;
{
********************
*
*   Command focal
}
27: begin
  pdoc_get_fp (in, fp, stat);
  if string_eos(stat)
    then pic.focal := 0.0
    else pic.focal := fp;
  end;
{
********************
*
*   Command focal35
}
28: begin
  pdoc_get_fp (in, fp, stat);
  if string_eos(stat)
    then pic.focal35 := 0.0
    else pic.focal35 := fp;
  end;
{
********************
*
*   Command altitude
}
29: begin
  pdoc_get_fp (in, fp, stat);
  if string_eos(stat)
    then begin
      pic.altitude := 0.0;
      pic.fields := pic.fields - [pdoc_field_alt_k];
      end
    else begin
      pic.altitude := fp;
      pic.fields := pic.fields + [pdoc_field_alt_k];
      end
    ;
  end;
{
********************
*
*   Command manuf
}
30: begin
  pdoc_get_textp (in, pdoc.mem_p^, pic.manuf_p, stat);
  end;
{
********************
*
*   Command model
}
31: begin
  pdoc_get_textp (in, pdoc.mem_p^, pic.model_p, stat);
  end;
{
********************
*
*   Command softw
}
32: begin
  pdoc_get_textp (in, pdoc.mem_p^, pic.softw_p, stat);
  end;
{
********************
*
*   Command host
}
33: begin
  pdoc_get_textp (in, pdoc.mem_p^, pic.host_p, stat);
  end;
{
********************
*
*   Command user
}
34: begin
  pdoc_get_textp (in, pdoc.mem_p^, pic.user_p, stat);
  end;
{
********************
*
*   Command personData
}
35: begin                              {personData}
  pdoc_get_personData (in, pdoc.mem_p^, pdoc.people_p, stat);
  end;
{
********************
*
*   Unexpected command name.  The command name is in CMD.
}
otherwise
    if (cmd.len > 1) and (cmd.str[1] = 'X') then begin {private extension command ?}
      goto loop_command;               {not implemented yet, ignore for now}
      end;
    sys_stat_set (pdoc_subsys_k, pdoc_stat_badcmd_k, stat);
    pdoc_in_stat_lnum (in, stat);
    pdoc_in_stat_fnam (in, stat);
    sys_stat_parm_vstr (cmd, stat);
    return;
    end;

done_command:
{
*   Done processing this command.
*
********************
}
  if sys_error(stat) then return;      {error processing the command ?}

  pdoc_in_line (in, buf, fmt, stat);   {try to get more data for this command}
  if string_eos(stat)                  {command data exhausted as it should be ?}
    then goto loop_command;            {back for next PDOC stream command}

err_extra:
  buf.len := min(buf.len, 32);         {truncate extra data to max len for err msg}
  sys_stat_set (pdoc_subsys_k, pdoc_stat_unused_args_k, stat);
  pdoc_in_stat_lnum (in, stat);
  pdoc_in_stat_fnam (in, stat);
  sys_stat_parm_vstr (buf, stat);
  end;                                 {return with error}
