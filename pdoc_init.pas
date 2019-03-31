{   Initialization routines.
}
module pdoc_init;
define pdoc_pic_init;
define pdoc_release;
%include 'pdoc2.ins.pas';
{
********************************************************************************
*
*   Subroutine PDOC_PIC_INIT (PIC)
*
*   Initialize all the fields of the picture descriptor PIC to default or empty
*   values.  Any previous information in PIC is lost.
*
*   This routine should always be called to initialize a picture descriptor because
*   it will be updated as new fields are added.  Applications call PDOC_PIC_INIT
*   and then only access the fields they know and care about without danger of
*   new fields being uninitialized.
}
procedure pdoc_pic_init (              {init a picture descriptor to all default or empty}
  out     pic: pdoc_pic_t);            {all fields will be initialized default or empty}
  val_param;

begin
  pic.name_p := nil;                   {init state for next picture}
  pic.namespace_p := nil;
  pic.film_p := nil;
  pic.filmdesc_p := nil;
  pic.copyright_p := nil;
  pic.tzone := 0.0;
  pic.time_p := nil;
  pic.quick_p := nil;
  pic.desc_p := nil;
  pic.stored_p := nil;
  pic.loc_of_p := nil;
  pic.loc_from_p := nil;
  pic.loc_desc_p := nil;
  pic.people_p := nil;
  pic.by_p := nil;
  pic.gcoor_of_p := nil;
  pic.gcoor_from_p := nil;
  pic.esc_p := nil;
  pic.deriv_p := nil;
  pic.iso := 0.0;
  pic.exptime := 0.0;
  pic.fstop := 0.0;
  pic.focal := 0.0;
  pic.focal35 := 0.0;
  pic.altitude := 0.0;
  pic.manuf_p := nil;
  pic.model_p := nil;
  pic.softw_p := nil;
  pic.host_p := nil;
  pic.user_p := nil;
  pic.fields := [];
  end;
{
********************************************************************************
*
*   Subroutine PDOC_RELEASE (PDOC)
*
*   Release all resources allocated to the picture list PDOC.  PDOC is returned
*   invalid, and must be inialized again before any new use.
}
procedure pdoc_release (               {release all resources allocated to PDOC structure}
  in out  pdoc: pdoc_t);               {returned invalid, must be initialized before next use}
  val_param;

begin
  util_mem_context_del (pdoc.mem_p);   {deallocate all dynamic memory}
  pdoc.people_p := nil;                {remove links to the deallocated memory}
  pdoc.pics_p := nil;
  pdoc.lastpic_p := nil;
  end;
