# spm_interlace.tcl

#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # YogaBook
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # MIIX-320
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # Win7 desktop


# set ::IM_DIR "C:/Program Files (x86)/ImageMagick-7.0.8-20";   set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];    # YogaBook


package require twapi;  #  TODO: check errors
#package require twapi_clipboard

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR "ok_utils" "common.tcl"]
source [file join $SCRIPT_DIR "ok_utils" "inifile.tcl"]
source [file join $SCRIPT_DIR "ok_utils" "disk_info.tcl"]
source [file join $SCRIPT_DIR "ok_twapi_common.tcl"]
source [file join $SCRIPT_DIR "spm_tabstops_def.tcl"]


namespace eval ::spm:: {
}


# The procedure:
### assumptions:
### - "Image direction (from left to right)" checkbox is checked 
### - "Create slit animation image" checkbox is not checked 
# (delete "TMP_FRAME_l.TIF", "TMP_FRAME_r.TIF" to avoid popup)
# - Open the stereopair
# (delete "TMP_FRAME_l.TIF", "TMP_FRAME_r.TIF" to avoid popup)
# - Save as left- and right images - "TMP_FRAME_l.TIF", "TMP_FRAME_r.TIF" - by Ctrl-S
### Alternatively first ensure any image is open - to make Edit menu predictable.
# Open "Create lenticular image" - by Edit -> 5 * {UP}
# Focus filename field by Alt-N and type: "TMP_FRAME_l.TIF" "TMP_FRAME_r.TIF"
# Fill fields "Lenticular Lens Pitch", "Printer Resolution", "Print Width" from call parameters using tabstop traversal
# Press TAB until "Create With Selected Files" reached and press SPACE

# TODO


## Example: spm::interlace_listed_stereopairs_at_integer_lpi SBS [lindex [glob -nocomplain -directory "FIXED/SBS" "*.TIF"] 0] 60 "TMP"
proc ::spm::interlace_listed_stereopairs_at_integer_lpi {inpType inpPathList lpi \
                                                          outDirPath}  {
  variable TABSTOPS_DFL
  set INTERLACE "Create Lenticular Image";  # dialog name / key / description
  
  if { 0 == [set nPairs [llength $inpPathList]] }  {
    puts "-W- No images specified for $INTERLACE";  return  0
  }
  if { ![ok_twapi::verify_singleton_running $INTERLACE] } { return  0 }
  
  # load the 1st image before dialog-open command - to make Edit menu predictable
  set imgPath [lindex $inpPathList 0]
  # TODO: need full path !
  if { ![spm::cmd__open_stereopair_image $inpType $imgPath] }  {
    return  0;   # error already printed
  }
  set imgWnd      [twapi::get_foreground_window]

  puts "Begin: $INTERLACE for $nPairs stereopair(s)"
  foreach imgPath $inpPathList {
    # open "Create Lenticular Image" dialog for each image
    if { 0 == [::ok_twapi::open_menu_top_level "e" $INTERLACE] }  {
      return  "";  # error already printed
    }
    if { "" == [::ok_twapi::travel_meny_hierarchy \
                {{{UP} {UP} {UP} {UP} {UP}}{ENTER}}  $INTERLACE $INTERLACE] }  {
      #twapi::unblock_input
      return  0;  # error already printed
    }
    return  1;  #OK_TMP
    # TODO
  }
  return  1;  # TODO: $cntDone
}
