{   Routines for writing picture information in memory to a PDOC output
*   stream.
}
module pdoc_write;
define pdoc_write_pic;
define pdoc_write_pics;
%include 'pdoc2.ins.pas';
{
********************************************************************************
*
*   Local subroutine WRITE_PERSONS (OUT, LIST_P, STAT)
*
*   Write information for all the person definitions in the list pointed to by
*   LIST_P.  Only data for those definitions will be written that have a
*   assigned ID and that have not already been written.
}
procedure write_persons (              {write person definitions from list}
  in out  out: pdoc_out_t;             {output stream state}
  in      list_p: pdoc_perent_p_t;     {pointer to start of persons list}
  out     stat: sys_err_t);            {completion status code}
  val_param; internal;

var
  ent_p: pdoc_perent_p_t;              {pointer to current list entry}

begin
  ent_p := list_p;                     {init to first list entry}
  while ent_p <> nil do begin          {scan the list}
    if                                 {write out this person definition ?}
        (not ent_p^.ent_p^.wr) and     {this definition not already written ?}
        (ent_p^.ent_p^.intid > 0)      {this definition has ID assigned ?}
        then begin
      pdoc_put_person (out, ent_p^.ent_p^, stat);
      if sys_error(stat) then return;
      end;
    ent_p := ent_p^.next_p;            {advance to next entry in list}
    end;
  end;
{
***********************************************************************
*
*   Subroutine PDOC_WRITE_PIC (OUT, PICS_P, PIC, PREV_P, STAT)
*
*   Write the PDOC commands for the picture PIC to the PDOC output stream
*   identified by OUT.  If PREV_P points to a picture descriptor (not NIL)
*   then only the minimum commands required to change the state from that
*   picture will be written out.  When PREV_P is NIL, all PIC state will
*   be written explicitly.
}
procedure pdoc_write_pic (             {write PDOC commands for one picture}
  in out  out: pdoc_out_t;             {output stream state}
  in      pics_p: pdoc_picent_p_t;     {pointer to list of all pictures}
  in      pic: pdoc_pic_t;             {picture descriptor to write commands for}
  in      prev_p: pdoc_pic_p_t;        {pnt to previous pic descriptor, may be NIL}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  picent_p: pdoc_picent_p_t;           {pointer to current picture list entry}
{
********************
*
*   Local function CHANGED (OFS)
*
*   Returns TRUE if a particular field in PIC was changed from the previous
*   picture pointed to by PREV_P.  OFS is the memory address offset of the
*   selected field from the start of PIC.  It is assumed that the field is
*   a pointer.
}
function changed (                     {determine if field changed from last picture}
  in      ofs: sys_int_adr_t)          {offset of field into PIC structure}
  :boolean;

var
  new_p, old_p: ^univ_ptr;             {pnt to fields in current and previous pics}

begin
  new_p := univ_ptr(                   {make address of field within PIC}
    sys_int_adr_t(addr(pic)) + ofs);

  if prev_p = nil then begin           {there is no previous pic to compare to ?}
    changed := new_p^ <> nil;
    return;
    end;

  old_p := univ_ptr(                   {make address of filed within previous pic}
    sys_int_adr_t(prev_p) + ofs);
  changed := new_p^ <> old_p^;         {compare field values}
  end;
{
********************
*
*   Local function CHANGED_STR (OFS)
*
*   Returns TRUE if a indirect string field in PIC was changed from the previous
*   picture pointed to by PREV_P.  OFS is the memory address offset of the
*   selected field from the start of PIC.  The field itself is a pointer to a
*   var string.  If both pointers are pointing to different strings, but the
*   strings have the same content, then this function returns FALSE.
}
function changed_str (                 {determine if field changed from last picture}
  in      ofs: sys_int_adr_t)          {offset of field into PIC structure}
  :boolean;

var
  new_pp, old_pp: ^string_var_p_t;     {point to fields in the picture descriptors}
  new_p, old_p: string_var_p_t;        {point to the referenced strings}

begin
  changed_str := false;                {init to the two strings are the same}
  new_pp := univ_ptr(                  {make address of field within PIC}
    sys_int_adr_t(addr(pic)) + ofs);
  new_p := new_pp^;                    {make new string pointer}

  if prev_p = nil then begin           {there is no previous pic to compare to ?}
    changed_str := new_p <> nil;       {consider changed if string exists}
    return;
    end;

  old_pp := univ_ptr(                  {make address of filed within previous pic}
    sys_int_adr_t(prev_p) + ofs);
  old_p := old_pp^;                    {make old string pointer}

  if new_p = old_p then return;        {both pointers are the same ?}
  if (new_p <> nil) and (old_p <> nil) then begin {both pointing to strings ?}
    if string_equal(new_p^, old_p^) then return; {both strings are the same ?}
    end;

  changed_str := true;                 {the new string is different}
  end;
{
********************
*
*   Start of executable code for PDIC_WRITE_PIC.
}
begin
  if changed_str(offset(pic.namespace_p)) then begin
    pdoc_out_cmd_str (out, 'namespace', stat);
    if sys_error(stat) then return;
    pdoc_put_str (out, pic.namespace_p, stat);
    if sys_error(stat) then return;
    end;

  if changed_str(offset(pic.film_p)) and (pic.film_p <> nil) then begin
    pdoc_out_cmd_str (out, 'film', stat);
    if sys_error(stat) then return;
    pdoc_put_str (out, pic.film_p, stat);
    if sys_error(stat) then return;
    end;

  if changed(offset(pic.filmdesc_p)) and (pic.filmdesc_p <> nil) then begin
    pdoc_out_cmd_str (out, 'descFilm', stat);
    if sys_error(stat) then return;
    pdoc_put_lines (out, pic.filmdesc_p, stat);
    if sys_error(stat) then return;
    end;

  picent_p := pics_p;                  {init to first picture in list}
  while picent_p <> nil do begin       {scan the list of pictures}
    write_persons (                    {define the people that made the pictures}
      out, picent_p^.ent_p^.by_p, stat);
    if sys_error(stat) then return;
    write_persons (                    {define the people in the pictures}
      out, picent_p^.ent_p^.people_p, stat);
    if sys_error(stat) then return;
    picent_p := picent_p^.next_p;      {advance to next list entry}
    end;

  if
      (prev_p = nil) or else
      (prev_p^.tzone <> pic.tzone) or
      ((pdoc_field_tz_k in prev_p^.fields) <> (pdoc_field_tz_k in pic.fields))
      then begin
    pdoc_out_cmd_str (out, 'timezone', stat);
    if sys_error(stat) then return;
    if pdoc_field_tz_k in pic.fields then begin
      pdoc_put_fp_fixed (out, pic.tzone, 1, stat);
      if sys_error(stat) then return;
      end;
    end;

  if
      (prev_p = nil) or else
      changed(offset(pic.time_p)) or
      ((pdoc_field_time_k in prev_p^.fields) <> (pdoc_field_time_k in pic.fields))
      then begin
    if (pdoc_field_time_k in pic.fields) and (pic.time_p = nil)
      then begin                       {time is specifically unset}
        pdoc_out_cmd_str (out, 'notime', stat);
        if sys_error(stat) then return;
        end
      else begin                       {normal time either known or not}
        pdoc_out_cmd_str (out, 'time', stat);
        if sys_error(stat) then return;
        pdoc_put_timerange (out, pic.time_p, pic.tzone, stat);
        if sys_error(stat) then return;
        end
      ;
    end;

  if changed_str(offset(pic.copyright_p)) then begin
    pdoc_out_cmd_str (out, 'copyright', stat);
    if sys_error(stat) then return;
    pdoc_put_str (out, pic.copyright_p, stat);
    if sys_error(stat) then return;
    end;

  write_persons (out, pic.by_p, stat); {define all people referenced this pic}
  if sys_error(stat) then return;
  write_persons (out, pic.people_p, stat);
  if sys_error(stat) then return;

  if changed(offset(pic.by_p)) then begin
    pdoc_out_cmd_str (out, 'by', stat);
    if sys_error(stat) then return;
    pdoc_put_people (out, pic.by_p, stat);
    if sys_error(stat) then return;
    end;

  if changed(offset(pic.people_p)) then begin
    pdoc_out_cmd_str (out, 'people', stat);
    if sys_error(stat) then return;
    pdoc_put_people (out, pic.people_p, stat);
    if sys_error(stat) then return;
    end;

  if (pic.loc_of_p = pic.loc_from_p)
    then begin                         {single OF and FROM location}
      if changed(offset(pic.loc_of_p)) or changed(offset(pic.loc_from_p)) then begin
        pdoc_out_cmd_str (out, 'loc', stat);
        if sys_error(stat) then return;
        pdoc_put_loc (out, pic.loc_of_p, stat);
        if sys_error(stat) then return;
        end;
      end
    else begin                         {separate OF and FROM locations}
      if changed(offset(pic.loc_of_p)) then begin
        pdoc_out_cmd_str (out, 'locOf', stat);
        if sys_error(stat) then return;
        pdoc_put_loc (out, pic.loc_of_p, stat);
        if sys_error(stat) then return;
        end;
      if changed(offset(pic.loc_from_p)) then begin
        pdoc_out_cmd_str (out, 'locFrom', stat);
        if sys_error(stat) then return;
        pdoc_put_loc (out, pic.loc_from_p, stat);
        if sys_error(stat) then return;
        end;
      end
    ;

  if changed(offset(pic.loc_desc_p)) then begin
    pdoc_out_cmd_str (out, 'locDesc', stat);
    if sys_error(stat) then return;
    pdoc_put_lines (out, pic.loc_desc_p, stat);
    if sys_error(stat) then return;
    end;

  if (pic.gcoor_of_p = pic.gcoor_from_p)
    then begin                         {single OF and FROM coordinate}
      if changed(offset(pic.gcoor_of_p)) or changed(offset(pic.gcoor_from_p)) then begin
        pdoc_out_cmd_str (out, 'latlon', stat);
        if sys_error(stat) then return;
        pdoc_put_gcoor (out, pic.gcoor_of_p, stat);
        if sys_error(stat) then return;
        end;
      end
    else begin                         {separate OF and FROM coordinates}
      if changed(offset(pic.gcoor_of_p)) then begin
        pdoc_out_cmd_str (out, 'latlonOf', stat);
        if sys_error(stat) then return;
        pdoc_put_gcoor (out, pic.gcoor_of_p, stat);
        if sys_error(stat) then return;
        end;
      if changed(offset(pic.gcoor_from_p)) then begin
        pdoc_out_cmd_str (out, 'latlonFrom', stat);
        if sys_error(stat) then return;
        pdoc_put_gcoor (out, pic.gcoor_from_p, stat);
        if sys_error(stat) then return;
        end;
      end
    ;

  if (prev_p = nil) or else (pic.iso <> prev_p^.iso) then begin
    pdoc_out_cmd_str (out, 'iso', stat);
    if sys_error(stat) then return;
    if pic.iso > 0.0 then begin
      pdoc_put_fp_sig (out, pic.iso, 3, stat);
      if sys_error(stat) then return;
      end;
    end;

  if (prev_p = nil) or else (pic.exptime <> prev_p^.exptime) then begin
    pdoc_out_cmd_str (out, 'exptime', stat);
    if sys_error(stat) then return;
    if pic.exptime > 0.0 then begin
      pdoc_put_fp (out, pic.exptime, stat);
      if sys_error(stat) then return;
      end;
    end;

  if (prev_p = nil) or else (pic.fstop <> prev_p^.fstop) then begin
    pdoc_out_cmd_str (out, 'fstop', stat);
    if sys_error(stat) then return;
    if pic.fstop > 0.0 then begin
      pdoc_put_fp_sig (out, pic.fstop, 3, stat);
      if sys_error(stat) then return;
      end;
    end;

  if (prev_p = nil) or else (pic.focal <> prev_p^.focal) then begin
    pdoc_out_cmd_str (out, 'focal', stat);
    if sys_error(stat) then return;
    if pic.focal > 0.0 then begin
      pdoc_put_fp_sig (out, pic.focal, 4, stat);
      if sys_error(stat) then return;
      end;
    end;

  if (prev_p = nil) or else (pic.focal35 <> prev_p^.focal35) then begin
    pdoc_out_cmd_str (out, 'focal35', stat);
    if sys_error(stat) then return;
    if pic.focal35 > 0.0 then begin
      pdoc_put_fp_sig (out, pic.focal35, 4, stat);
      if sys_error(stat) then return;
      end;
    end;

  if
      (prev_p = nil) or else
      ((pdoc_field_alt_k in prev_p^.fields) <> (pdoc_field_alt_k in pic.fields)) or
      (pic.altitude <> prev_p^.altitude)
      then begin
    pdoc_out_cmd_str (out, 'altitude', stat);
    if sys_error(stat) then return;
    if pic.altitude > 0.0 then begin
      pdoc_put_fp_fixed (out, pic.altitude, 1, stat);
      if sys_error(stat) then return;
      end;
    end;

  if changed_str(offset(pic.manuf_p)) then begin
    pdoc_out_cmd_str (out, 'manuf', stat);
    if sys_error(stat) then return;
    pdoc_put_str (out, pic.manuf_p, stat);
    if sys_error(stat) then return;
    end;

  if changed_str(offset(pic.model_p)) then begin
    pdoc_out_cmd_str (out, 'model', stat);
    if sys_error(stat) then return;
    pdoc_put_str (out, pic.model_p, stat);
    if sys_error(stat) then return;
    end;

  if changed_str(offset(pic.softw_p)) then begin
    pdoc_out_cmd_str (out, 'softw', stat);
    if sys_error(stat) then return;
    pdoc_put_str (out, pic.softw_p, stat);
    if sys_error(stat) then return;
    end;

  if changed_str(offset(pic.host_p)) then begin
    pdoc_out_cmd_str (out, 'host', stat);
    if sys_error(stat) then return;
    pdoc_put_str (out, pic.host_p, stat);
    if sys_error(stat) then return;
    end;

  if changed_str(offset(pic.user_p)) then begin
    pdoc_out_cmd_str (out, 'user', stat);
    if sys_error(stat) then return;
    pdoc_put_str (out, pic.user_p, stat);
    if sys_error(stat) then return;
    end;

  if changed(offset(pic.stored_p)) then begin
    pdoc_out_cmd_str (out, 'stored', stat);
    if sys_error(stat) then return;
    pdoc_put_strlist (out, pic.stored_p, stat);
    if sys_error(stat) then return;
    end;

  if changed(offset(pic.esc_p)) then begin
    pdoc_put_cmdlist (out, pic.esc_p, stat);
    if sys_error(stat) then return;
    end;

  if changed_str(offset(pic.quick_p)) then begin
    pdoc_out_cmd_str (out, 'quick', stat);
    if sys_error(stat) then return;
    pdoc_put_str (out, pic.quick_p, stat);
    if sys_error(stat) then return;
    end;

  if changed(offset(pic.desc_p)) then begin
    pdoc_out_cmd_str (out, 'desc', stat);
    if sys_error(stat) then return;
    pdoc_put_lines (out, pic.desc_p, stat);
    if sys_error(stat) then return;
    end;

  if pic.film_p = nil
    then begin
      pdoc_out_cmd_str (out, 'pic', stat);
      end
    else begin
      pdoc_out_cmd_str (out, 'frame', stat);
      end
    ;
  if sys_error(stat) then return;
  if pic.name_p = nil then begin       {this picture has no name ?}
    sys_stat_set (pdoc_subsys_k, pdoc_stat_nonamei_k, stat);
    return;
    end;
  pdoc_put_str (out, pic.name_p, stat);
  if sys_error(stat) then return;
  pdoc_out_blank (out, stat);          {leave blank line after this picture}
  if sys_error(stat) then return;
  end;
{
***********************************************************************
*
*   Subroutine PDOC_WRITE_PICS (OUT, LIST_P, FLAGS, STAT)
*
*   Write the information for a list of pictures to a PDOC output stream.
*   LIST_P is pointing to the first list entry to write out.  FLAGS is a
*   set of option flags.  The meaningful flags are:
*
*     PDOC_WFLAG_ALL_K  -  Write the value of all fields, not just those
*       that were changed from the previous picture in the list.
}
procedure pdoc_write_pics (            {write PDOC commands for list of pictures}
  in out  out: pdoc_out_t;             {output stream state}
  in      list_p: pdoc_picent_p_t;     {pointer to start of pictures list}
  in      flags: pdoc_wflag_t;         {set of option flags}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  ent_p: pdoc_picent_p_t;              {pointer to current list entry}
  prev_p: pdoc_pic_p_t;                {pointer to previous picture descriptor}

begin
  ent_p := list_p;                     {init pointer to first list entry}
  prev_p := nil;                       {init to no previous pic state to rely on}

  while ent_p <> nil do begin          {once for each list entry}
    if pdoc_wflag_all_k in flags then begin {write all, not just modified fields ?}
      prev_p := nil;
      end;
    pdoc_write_pic (out, list_p, ent_p^.ent_p^, prev_p, stat);
    if sys_error(stat) then return;
    pdoc_out_buf (out, stat);          {finish writing any buffered output}
    if sys_error(stat) then return;
    if ent_p^.next_p <> nil then begin {another picture will follow ?}
      pdoc_out_blank (out, stat);      {write blank line before next picture}
      if sys_error(stat) then return;
      end;
    prev_p := ent_p^.ent_p;            {advance to next list entry}
    ent_p := ent_p^.next_p;
    end;                               {back to write new picture info}
  end;
