{   Routines that manipulate person lists that are independent of PDOC file
*   data.
}
module pdoc_perslist;
define pdoc_dbg_person;
define pdoc_pers_desc_same;
define pdoc_perslist_init;
define pdoc_perslist_close;
define pdoc_perslist_add;
%include 'pdoc2.ins.pas';
{
********************************************************************************
*
*   Subroutine PDOC_DBG_PERSON (P)
*
*   Write the information about person P to standard output.  This is intended
*   for debugging.
}
procedure pdoc_dbg_person (            {write person info to standard output}
  in      p: pdoc_person_t);           {person descriptor}
  val_param;

var
  line_p: pdoc_lines_p_t;              {pointer to current description line}

begin
  writeln;

  write ('Person: ');
  if p.name_p <> nil then begin
    write (p.name_p^.str:p.name_p^.len);
    end;
  writeln;

  write ('  Full name: ');
  if p.fname_p = nil
    then write ('-- none --')
    else write (p.fname_p^.str:p.fname_p^.len);
  writeln;

  if p.desc_p = nil
    then begin
      writeln ('  Desc: -- none --');
      end
    else begin
      writeln ('  Desc:');
      line_p := p.desc_p;
      while line_p <> nil do begin
        write ('   ');
        case line_p^.fmt of
pdoc_format_fixed_k: write (':');
otherwise
          write (' ');
          end;
        writeln (line_p^.line_p^.str:line_p^.line_p^.len);
        line_p := line_p^.next_p;
        end;
      end
    ;

  write ('  Pic: ');
  if p.pic_p = nil
    then write ('-- none --')
    else write (p.pic_p^.str:p.pic_p^.len);
  writeln;

  write ('  WikiTree: ');
  if p.wikitree_p = nil
    then write ('-- none --')
    else write (p.wikitree_p^.str:p.wikitree_p^.len);
  writeln;

  writeln ('  ID: ', p.intid);

  write ('  Ref: ');
  if p.ref
    then write ('Yes')
    else write ('No');
  writeln;

  write ('  Written: ');
  if p.wr
    then write ('Yes')
    else write ('No');
  writeln;
  end;
{
********************************************************************************
*
*   Function PDOC_PERS_DESC_SAME (PERS1, PERS2)
*
*   Compares the description lines for the two people and returns TRUE iff no
*   differences are found.
}
function pdoc_pers_desc_same (         {check person descriptions for being same}
  in      pers1, pers2: pdoc_person_t) {the two people to check}
  :boolean;                            {no differences found in long descriptions}
  val_param;

var
  line1_p, line2_p: pdoc_lines_p_t;    {current description line for each person}

begin
  pdoc_pers_desc_same := false;        {init to descriptions not the same}

  line1_p := pers1.desc_p;             {init pointers to first description lines}
  line2_p := pers2.desc_p;
  while true do begin                  {scan the description lines}
    if (line1_p = nil) and (line2_p = nil) {both descriptions end here ?}
      then exit;
    if (line1_p = nil) or (line2_p = nil) {different number of description lines ?}
      then return;
    if line1_p^.fmt <> line2_p^.fmt    {different format of this line ?}
      then return;
    if not string_equal(line1_p^.line_p^, line2_p^.line_p) {different text ?}
      then return;
    line1_p := line1_p^.next_p;        {advance to next lines}
    line2_p := line2_p^.next_p;
    end;                               {back to compare these new lines}

  pdoc_pers_desc_same := true;         {everything matched}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PERSLIST_INIT (PERSLIST, MEM)
*
*   Initialize a persons list.  All previous data and allocated resources of the
*   list are lost.  A persons list must be initialized before use.  MEM is the
*   parent memory context.  A subordinate memory context will be created, which
*   will be used for all dynamic memory allocated to the list.
}
procedure pdoc_perslist_init (         {initialize a separate persons list}
  out     perslist: pdoc_perslist_t;   {the list structure to initialize}
  in out  mem: util_mem_context_t);    {parent mem context, will make sub-context}
  val_param;

begin
  util_mem_context_get (mem, perslist.mem_p); {create private mem context for the list}
  perslist.first_p := nil;             {init the list to empty}
  perslist.last_p := nil;
  perslist.nextid := 1;                {init ID to assign to next new person}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PERLIST_CLOSE (PERLIST)
*
*   Release any resources allocated to the persons list PERLIST.  The list must
*   have been previously initialized.  It will be unusable without being
*   initialized before any new use.
}
procedure pdoc_perslist_close (        {deallocate resources of a separate persons list}
  in out  perslist: pdoc_perslist_t);  {returned unusable, must be initialized before use}
  val_param;

begin
  util_mem_context_del (perslist.mem_p); {deallocate dynamic memory of the list}
  perslist.first_p := nil;             {reset list to empty}
  perslist.last_p := nil;
  perslist.nextid := 0;                {set next person ID to invalid}
  end;
{
********************************************************************************
*
*   Subroutine PDOC_PERSLIST_ADD (PERSLIST, PERENT, STAT)
*
*   Make sure a person is in the persons list PERSLIST.  PERENT is the entry of
*   a person in a different persons lists, such as a list resulting from reading
*   a PDOC file.
*
*   If the person is not already in PERSLIST, then a new entry is made in
*   PERSLIST and the person information copied into it.  In that case, the next
*   person ID is assigned to this person.
*
*   In either case, the PERENT list entry is pointed to the entry in PERSLIST.
}
procedure pdoc_perslist_add (          {add person to persons list, if not duplicate}
  in out  perslist: pdoc_perslist_t;   {persons list to add person to}
  in out  perent: pdoc_perent_t;       {entry in other list of person to add}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  ent_p: pdoc_perent_p_t;              {pointer to current list entry}
  pers_p: pdoc_person_p_t;             {pointer to person of list entry}
  inpr_p: pdoc_person_p_t;             {pointer to source person descriptor}
  linen_p: pdoc_lines_p_t;             {pointer to new person description line}
  linel_p: pdoc_lines_p_t;             {pointer to description line of list entry}
  linelp_p: pdoc_lines_p_t;            {pointer to previous description line in list}

label
  next_ent, have_ent;

begin
  sys_error_none (stat);               {init to no error encountered}
  inpr_p := perent.ent_p;              {save pointer to person source data}

(*
  writeln;
  writeln ('Adding ', inpr_p^.name_p^.str:inpr_p^.name_p^.len, ' to list');
  pdoc_dbg_person (inpr_p^);
*)

{
*   Scan the list looking for existing entry.
}
  ent_p := perslist.first_p;           {init to first entry in existing list}
  while ent_p <> nil do begin          {back here each successive list entry}
    pers_p := ent_p^.ent_p;            {get pointer to person data of this list entry}
    if pers_p = inpr_p                 {exact same person descriptor ?}
      then return;                     {nothing more to do}

    if                                 {both have WikiTree IDs ?}
        (pers_p^.wikitree_p <> nil) and
        (inpr_p^.wikitree_p <> nil)
        then begin
      if pers_p^.wikitree_p = inpr_p^.wikitree_p
        then goto have_ent             {same WikiTree ID}
        else goto next_ent;            {different WikiTree IDs}
      end;

    if                                 {both have portrait pictures ?}
        (pers_p^.pic_p <> nil) and
        (inpr_p^.pic_p <> nil)
        then begin
      if pers_p^.pic_p = inpr_p^.pic_p
        then goto have_ent             {same portrait picture}
        else goto next_ent;            {different portrait pictures}
      end;

    if not string_equal(pers_p^.fname_p^, inpr_p^.fname_p^)
      then goto next_ent;              {different full names ?}

    if                                 {one or both has no description ?}
        (pers_p^.desc_p = nil) or
        (inpr_p^.desc_p = nil)
      then goto have_ent;              {descriptions don't disagree}

    if pdoc_pers_desc_same (pers_p^, inpr_p^) {same description ?}
      then goto have_ent;

next_ent:                              {this list entry is not a match, advance to next}
    ent_p := ent_p^.next_p;
    end;                               {back to check this new entry}
{
*   No existing entry was found for this person.  Create a blank one.
}
  util_mem_grab (                      {allocate new list entry}
    sizeof(ent_p^), perslist.mem_p^, false, ent_p);
  util_mem_grab (                      {allocate new person descriptor}
    sizeof(pers_p^), perslist.mem_p^, false, pers_p);
  {
  *   Fill in the new list entry and link it to the end of the list.
  }
  ent_p^.prev_p := perslist.last_p;    {fill in new list entry}
  ent_p^.next_p := nil;
  ent_p^.ent_p := pers_p;
  if perslist.first_p = nil            {link new entry into list}
    then begin
      perslist.first_p := ent_p;
      end
    else begin
      perslist.last_p^.next_p := ent_p;
      end
    ;
  perslist.last_p := ent_p;
  {
  *   Init the person data to blank.
  }
  pers_p^.name_p := nil;
  pers_p^.fname_p := nil;
  pers_p^.desc_p := nil;
  pers_p^.pic_p := nil;
  pers_p^.wikitree_p := nil;
  pers_p^.intid := 0;
  pers_p^.ref := true;
  pers_p^.wr := false;
{
*   PERS_P is pointing to the person data in the list for the person at INPR_P.
*   Information about the input person not in the list person data is copied.
*   Information present in both is checked for consistancy.  It is a error if
*   both specify some piece of information, but that piece is different.
}
have_ent:
  if pers_p^.fname_p = nil
    then begin                         {no full name, save source if available}
      if inpr_p^.fname_p <> nil then begin
        string_alloc (
          inpr_p^.fname_p^.len, perslist.mem_p^, false, pers_p^.fname_p);
        string_copy (inpr_p^.fname_p^, pers_p^.fname_p^);
        end;
      end
    else begin                         {full name exists, verify it}
      if inpr_p^.fname_p <> nil then begin
        if not string_equal(pers_p^.fname_p^, inpr_p^.fname_p^) then begin
          sys_stat_set (pdoc_subsys_k, pdoc_stat_fnames_k, stat);
          sys_stat_parm_vstr (inpr_p^.fname_p^, stat);
          sys_stat_parm_vstr (pers_p^.fname_p^, stat);
          return;
          end;
        end;
      end
    ;

  if (inpr_p^.desc_p <> nil) and (pers_p^.desc_p = nil)
    then begin                         {copy description text}
      linel_p := nil;                  {init to no current desc line in list}
      linen_p := inpr_p^.desc_p;       {init pointer to first source desc line}
      while linen_p <> nil do begin    {loop over description lines}
        linelp_p := linel_p;           {save pointer to previous desc line in list}
        util_mem_grab (                {allocate new description lines list entry}
          sizeof(linel_p^), perslist.mem_p^, false, linel_p);
        if linelp_p = nil
          then begin                   {there is no previous line in the list}
            pers_p^.desc_p := linel_p; {save pointer to first description line}
            end
          else begin                   {there is a previous line in the list}
            linelp_p^.next_p := linel_p; {set forward pointer in previous line}
            end
          ;
        linel_p^.prev_p := linelp_p;   {point back to previous line}
        linel_p^.next_p := nil;        {init to last line in list}
        linel_p^.fmt := linen_p^.fmt;  {copy format ID for this line}
        string_alloc (                 {save text of this line}
          linen_p^.line_p^.len, perslist.mem_p^, false, linel_p^.line_p);
        string_copy (linen_p^.line_p^, linel_p^.line_p^);
        linen_p := linen_p^.next_p;    {advance to next source line}
        end;                           {back to save this next source line}
      end
    else begin                         {check desciption text}
      if not pdoc_pers_desc_same (inpr_p^, pers_p^) then begin
        sys_stat_set (pdoc_subsys_k, pdoc_stat_descs_k, stat);
        sys_stat_parm_vstr (pers_p^.desc_p^, stat);
        return;
        end;
      end
    ;

  if pers_p^.pic_p = nil
    then begin                         {no portrait, save source if available}
      if inpr_p^.pic_p <> nil then begin
        string_alloc (
          inpr_p^.pic_p^.len, perslist.mem_p^, false, pers_p^.pic_p);
        string_copy (inpr_p^.pic_p^, pers_p^.pic_p^);
        end;
      end
    else begin                         {portrait exists, verify it}
      if inpr_p^.pic_p <> nil then begin
        if not string_equal(pers_p^.pic_p^, inpr_p^.pic_p^) then begin
          sys_stat_set (pdoc_subsys_k, pdoc_stat_portraits_k, stat);
          sys_stat_parm_vstr (pers_p^.fname_p^, stat);
          sys_stat_parm_vstr (inpr_p^.pic_p^, stat);
          sys_stat_parm_vstr (pers_p^.pic_p^, stat);
          return;
          end;
        end;
      end
    ;

  if pers_p^.wikitree_p = nil
    then begin                         {no WikiTree ID, save source if available}
      if inpr_p^.wikitree_p <> nil then begin
        string_alloc (
          inpr_p^.wikitree_p^.len, perslist.mem_p^, false, pers_p^.wikitree_p);
        string_copy (inpr_p^.wikitree_p^, pers_p^.wikitree_p^);
        end;
      end
    else begin                         {WikiTree ID exists, verify it}
      if inpr_p^.wikitree_p <> nil then begin
        if not string_equal(pers_p^.wikitree_p^, inpr_p^.wikitree_p^) then begin
          sys_stat_set (pdoc_subsys_k, pdoc_stat_wikitrees_k, stat);
          sys_stat_parm_vstr (pers_p^.fname_p^, stat);
          sys_stat_parm_vstr (inpr_p^.wikitree_p^, stat);
          sys_stat_parm_vstr (pers_p^.wikitree_p^, stat);
          return;
          end;
        end;
      end
    ;

  if pers_p^.intid <= 0 then begin     {unique person ID not assigned yet ?}
    pers_p^.intid := perslist.nextid;  {assign it}
    perslist.nextid := perslist.nextid + 1; {update ID to assign next time}
    end;

  pers_p^.ref := true;                 {this person is referenced}
{
*   PERS_P is pointing to the person descriptor in the list, which is all set.
}
  perent.ent_p := pers_p;              {point source entry to entry in list}
  end;
