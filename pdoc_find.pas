{   Routines to find particular pictures in list of pictures.
}
module pdoc_find;
define pdoc_find_pic_name;
%include 'pdoc2.ins.pas';
{
***********************************************************************
*
*   Subroutine PDOC_FIND_PIC_NAME (LIST_P, NAME, PIC_P)
*
*   Find a picture by name in a list of pictures.  LIST_P is pointing to
*   the start of a pictures list.  LIST_P may be NIL, in which case PIC_P
*   is always returned NIL.  NAME is the name of the picture to
*   find.  The name comparion will be case-insensitive.  PIC_P will
*   be returned pointing to the descriptor of the selected picture when
*   it is found, or NIL if no matching picture was found.
}
procedure pdoc_find_pic_name (         {find picture by name}
  in      list_p: pdoc_picent_p_t;     {pointer to start of pictures list}
  in      name: univ string_var_arg_t; {picture name, case insensitive}
  out     pic_p: pdoc_pic_p_t);        {will point to picture, NIL = not found}
  val_param;

var
  ent_p: pdoc_picent_p_t;              {pointer to current list entry}
  uname: string_var132_t;              {upper case NAME}
  unp: string_var132_t;                {upper case name of current picture}

begin
  uname.max := size_char(uname.str);   {init local var strings}
  unp.max := size_char(unp.str);

  string_copy (name, uname);           {make loca upper case copy of NAME}
  string_upcase (uname);

  ent_p := list_p;                     {init to first list entry}
  while ent_p <> nil do begin          {once for each list entry}
    pic_p := ent_p^.ent_p;             {make pointer to picture for this list entry}
    if pic_p^.name_p^.len = uname.len then begin {name lengths match ?}
      string_copy (pic_p^.name_p^, unp); {make local upper case copy of pic name}
      string_upcase (unp);
      if string_equal (unp, uname) then return; {found picture with matching name ?}
      end;
    ent_p := ent_p^.next_p;            {advance to next entry in pictures list}
    end;                               {back to check out next list entry}
  pic_p := nil;                        {indicate no matching picture found}
  end;
