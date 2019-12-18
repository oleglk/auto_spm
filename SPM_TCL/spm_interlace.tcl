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
  if { ![spm::cmd__open_stereopair_image $inpType $imgPath] }  {
    return  0;   # error already printed
  }
  set imgWnd      [twapi::get_foreground_window]

  set errCnt 0
  puts "Begin: $INTERLACE for $nPairs stereopair(s)"
  foreach imgPath $inpPathList {
    # open and drive "Create Lenticular Image" dialog for each image
    if { 0 == [cmd__interlace_one $inpType $imgPath $lpi $outDirPath] } {
      incr errCnt 1;  # error already printed
    }
    return  1;  #OK_TMP
    # TODO
  }
  return  1;  # TODO: $cntDone
}



# Splits stereopair from 'imgPath' into LR,
#  creates interlace off these 2 frames, saves under the same name as .tif .
# Returns path of the resulting image or "" on error.
# Assumes "Image Direction (from left to right) is checked" 
# Example: spm::cmd__interlace_one SBS "E:/TMP/SPM/290919__Glen_Mini3D/FIXED/SBS/2019_0929_133733_001.tif" 60 600 347
proc ::spm::cmd__interlace_one {inpType imgPath outDirPath \
                                lensLPI printDPI printWidth}  {
  variable TABSTOPS_DFL
  set INTERLACE "Create Lenticular Image";  # dialog name / key / description
  if { ![ok_twapi::verify_singleton_running $INTERLACE] } { return  0 }
  #~ if { TODO:![spm::any_image_is_open] }  {; # Edit menu depends on whether anything open
    #~ if { ![spm::cmd__open_stereopair_image $inpType $imgPath] }  {
      #~ return  "";   # error already printed
    #~ }
  #~ }
  set imgWnd      [twapi::get_foreground_window]
  set imgWndTitle [twapi::get_window_text $imgWnd]
  if { $imgWnd != [ok_twapi::get_latest_app_wnd] }  {
    puts "-W- Foreground SPM window ($imgWnd) differs from the latest ([ok_twapi::get_latest_app_wnd])"
  }
  # split into LR
  if { 0 == [split_sbs_image_into_lr_tiffs $imgPath "FRAME_L" "FRAME_R"] } {
    puts "-E- Aborted $INTERLACE for '$imgPath'";   return  ""
  }
  set lentWndTitleGlob "Image(Lenticular Image *"; # expected interlaced-image window title
  set dDescr "command to open '$INTERLACE' dialog"
  if { 0 == [::ok_twapi::open_menu_top_level "e" $INTERLACE] }  {
    return  0;  # error already printed
  }
  if { "" == [::ok_twapi::travel_meny_hierarchy \
              {{UP} {UP} {UP} {UP} {UP} {ENTER}}  $dDescr $INTERLACE] }  {
    return  "";  # error already printed
  }
  set hB [ok_twapi::wait_for_window_title_to_raise $INTERLACE "exact"]
  if { $hB == "" } {
    puts "-E- Failed to $dDescr";    return  "";  # error details already printed
  }
  twapi::send_keys {%n};  # return focus to Filename entry - start for tabstops
  # TODO: paste L/R frame file names

  # Go over all fields in ascending tabstops order and process each one
  set nameToStopNum [lindex [dict filter $TABSTOPS_DFL key $INTERLACE] 1]
  set nameToVal [dict create        \
        "Lenticular Lens Pitch"   $lensLPI    \
        "Printer Resolution"      $printDPI \
        "Print Width"             $printWidth  ]
  ok_twapi::_fill_fields_in_open_dialog  $nameToStopNum  $nameToVal  "'$INTERLACE' dialog"

  set dDescr "command to close '$INTERLACE' dialog and start interlacing"
  if { "" == [ok_twapi::_send_cmd_keys {{ENTER}} $dDescr 0] }  {
    puts "-E- Failed performing '$INTERLACE'"
    return  0;  # error already printed
  }
  # verify we returned to the image window (NEW title = $lentWndTitleGlob)
  set hI [ok_twapi::wait_for_window_title_to_raise $lentWndTitleGlob "glob"]
  if { $hI == "" } {
    puts "-E- Failed returning to image window";  return  0; # error details printed
  }
  puts "-I- Success performing '$INTERLACE'"
  
  # save
  set outDirPath [file dirname $imgPath]
  set saveWithBorderDescr "save image after '$INTERLACE' in directory '$outDirPath'"
  if { 0 == [spm::save_current_image_as_one_tiff $outDirPath] } {
    puts "-E- Failed to $saveWithBorderDescr";  return  0
  }
  puts "-I- Success to $saveWithBorderDescr";   return  1
}

