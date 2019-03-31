{   Public include file for the PHOT library.  This library manipulates
*   collections of images and photographs.
}
const
  phot_subsys_k = -35;                 {subsystem ID for PHOT library}
  phot_col_back = 0.10;                {page background gray level}
  phot_col_text = 0.50;                {normal text gray level}
  phot_col_gray = 0.25;                {"grayed out" text gray level}
  phot_portrait_dim = 400;             {max pixels dim for portraits in person pages}

type
  phot_htmpic_k_t = (                  {flags for writing HTML about specific picture}
    phot_htmpic_pref_k,                {prepend "<film name>-" to picture file names}
    phot_htmpic_npeople_k,             {don't write names of people in picture}
    phot_htmpic_nstored_k,             {don't write where copies of the picture are stored}
    phot_htmpic_nexp_k,                {don't write exposure information (F-stop, shutter, etc)}
    phot_htmpic_n1024_k,               {don't create separate HTML file for 1024 versions}
    phot_htmpic_index_k,               {write link to "index" instead of film proof sheet}
    phot_htmpic_noby_k);               {don't write "Created by" information}

  phot_htmpic_t = set of phot_htmpic_k_t; {all the flags in one set}
{
********************
*
*   Subroutines.
}
procedure phot_frame_info (            {get info about a particular picture}
  in      filmdir: univ string_var_arg_t; {pathname of film directory containing this frame}
  in      frame: univ string_var_arg_t; {name of frame inquiring about within the film}
  in      pdoc_p: pdoc_picent_p_t;     {pointer to PDOC info for film, may be NIL}
  in out  mem: util_mem_context_t;     {context to allocate any new memory under}
  out     pic_p: pdoc_pic_p_t;         {returned pointer to frame info, never NIL}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure phot_htm_pers_write (        {write HTM file for a person, if sufficient info}
  in      pers: pdoc_person_t;         {person info}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure phot_htm_persref_write (     {write person reference, will be link if info known}
  in out  hout: htm_out_t;             {HTM file writing state}
  in      pers: pdoc_person_t;         {person info}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure phot_htm_pic_write (         {write contents to HTM file for a picture}
  in out  hout: htm_out_t;             {picture HTM file writing state}
  in      pic: pdoc_pic_t;             {picture descriptor}
  in      nprev: univ string_var_arg_t; {name of previous image to link to, may be empty}
  in      nnext: univ string_var_arg_t; {name of next image to link to, may be empty}
  in      flags: phot_htmpic_t;        {set of modifier flags}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

function phot_pers_page (              {find if person should have private web page}
  in      pers: pdoc_person_t)         {the person inquiring about}
  :boolean;                            {this person should have a web page}
  val_param; extern;

procedure phot_link_wikitree_end (     {end link to WikiTree, if target is known}
  in out  hout: htm_out_t;             {HTML writing state}
  in      pers: pdoc_person_t;         {person info}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure phot_link_wikitree_start (   {start link to WikiTree, if target is known}
  in out  hout: htm_out_t;             {HTML writing state}
  in      pers: pdoc_person_t;         {person info}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure phot_whtm_geoang (           {write geographic angle to HTML file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      ang: double;                 {angle in degrees, will write absolute value}
  in      nfrac: sys_int_machine_t;    {number of fraction digits}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure phot_whtm_geocoor (          {write geographic coordinate to HTML file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      gcoor: pdoc_gcoor_t;         {description of geographic coordinate}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure phot_whtm_lines (            {write PDOC data lines to HTML file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      lines_p: pdoc_lines_p_t;     {pointer to start of lines list, may be NIL}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure phot_whtm_loc (              {write PDOC location hierarchy to HTM file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      loc_p: pdoc_strent_p_t;      {pointer to start of loc list, may be NIL}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure phot_whtm_people (           {write PDOC people names to HTM file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      people_p: pdoc_perent_p_t;   {pointer to start of people list, may be NIL}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure phot_whtm_strlist (          {write list of PDOC strings to HTM file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      first: pdoc_strent_t;        {first strings list entry}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;
