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
  variable FRAMES_SUBDIR_NAME "FRAMES_TMP"
  variable FRAME_L_NOEXT      "FRAME_L"
  variable FRAME_R_NOEXT      "FRAME_R"
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


## Example: spm::interlace_listed_stereopairs_at_integer_lpi SBS [lindex [glob -nocomplain -directory "FIXED/SBS" "*.TIF"] 0] "TMP" 60 600 347
##  ('printWidth' units: 1/100 inch)
proc ::spm::interlace_listed_stereopairs_at_integer_lpi {inpType inpPathList   \
                                      outDirPath lensLPI printDPI printWidth}  {
  variable TABSTOPS_DFL
  set INTERLACE "Create Lenticular Image";  # dialog name / key / description
  
  if { 0 == [set nPairs [llength $inpPathList]] }  {
    puts "-W- No images specified for $INTERLACE";  return  0
  }
  if { ![ok_twapi::verify_singleton_running $INTERLACE] } { return  0 }

  set errCnt 0
  puts "-I- Begin: $INTERLACE for $nPairs stereopair(s)"
  foreach imgPath $inpPathList {
    # open and drive "Create Lenticular Image" dialog for each image
    if { 0 == [cmd__interlace_one_at_integer_lpi $inpType $imgPath \
                                $outDirPath $lensLPI $printDPI $printWidth] }  {
      incr errCnt 1;  # error already printed
    }
    #return  1;  #OK_TMP
    # TODO?
  }
  puts "-I- End: $INTERLACE for $nPairs stereopair(s);  $errCnt error(s) occured"
  return  1;  # TODO: $cntDone
}



# Splits stereopair from 'imgPath' into LR,
#  creates interlace off these 2 frames, saves under the same name as .tif .
# Returns path of the resulting image or "" on error.
# Assumes "Image Direction (from left to right) is checked" 
# Example: spm::cmd__interlace_one_at_integer_lpi SBS "E:/TMP/SPM/290919__Glen_Mini3D/FIXED/SBS/2019_0929_133733_001.tif" 60 600 347
proc ::spm::cmd__interlace_one_at_integer_lpi {inpType imgPath outDirPath \
                                lensLPI printDPI printWidth}  {
  variable TABSTOPS_DFL
  set INTERLACE "Create Lenticular Image";  # dialog name / key / description
  if { ![ok_twapi::verify_singleton_running $INTERLACE] } { return  "" }
  # load the SBS image before dialog-open command - to make Edit menu predictable
  if { 1 }  { ; # ??? TODO:![spm::any_image_is_open] ???
    if { ![spm::cmd__open_stereopair_image $inpType $imgPath] }  {
      return  "";   # error already printed
    }
  }
  set imgWnd      [twapi::get_foreground_window]
  set imgWndTitle [twapi::get_window_text $imgWnd]
  if { $imgWnd != [ok_twapi::get_latest_app_wnd] }  {
    puts "-W- Foreground SPM window ($imgWnd) differs from the latest ([ok_twapi::get_latest_app_wnd])"
  }
  # save with the same name as input image - to facilitate phase error checking
  #~ set outImgName [spm::build_name_for_interlace $imgPath                      \
                                                #~ $lensLPI $printDPI $printWidth]
  set outImgNameNoExt [file rootname [file tail $imgPath]]
  set outImgName      [format "%s.TIF" $outImgNameNoExt]
  if { [file normalize [file dirname $imgPath]] == \
                                          [file normalize $outDirPath] }  {
    puts "-E- Interlaced image with same name as the original needs different directory"
    return  ""
  }
  # split into LR
  if { "" == [set framesDirPath [::spm::_make_lr_frames_in_their_subdir \
                                                  $imgPath $outDirPath]] }   {
    puts "-E- Aborted $INTERLACE for '$imgPath'";   return  ""
  }
#ok_utils::pause;  #OK_TMP

  # open and drive "Create Lenticular Image" dialog
  set lentWndTitleGlob "Image(Lenticular Image *"; # expected interlaced-image window title
  set dDescr "command to open '$INTERLACE' dialog"
  if { 0 == [::ok_twapi::open_menu_top_level "e" $INTERLACE] }  {
    return  "";  # error already printed
  }
  if { "" == [::ok_twapi::travel_meny_hierarchy \
              {{UP} {UP} {UP} {UP} {UP} {ENTER}}  $dDescr $INTERLACE] }  {
    return  "";  # error already printed
  }
  set hB [ok_twapi::wait_for_window_title_to_raise $INTERLACE "exact"]
  if { $hB == "" } {
    puts "-E- Failed to $dDescr";    return  "";  # error details already printed
  }
  if { 0 == [spm::change_input_dir_in_open_dialog $framesDirPath {%o}] }   {
    puts "-E- Failed to $dDescr";    return  "";  # error details already printed
  }
  twapi::send_keys {%n};  # return focus to Filename entry - start for tabstops
  #return  "";  # OK_TMP

  # Go over all fields in ascending tabstops order and process each one
  set nameToStopNum [lindex [dict filter $TABSTOPS_DFL key $INTERLACE] 1]
  set nameToVal [dict create                    \
        "Lenticular Lens Pitch"   $lensLPI      \
        "Printer Resolution"      $printDPI     \
        "Print Width"             $printWidth  ]
  ok_twapi::_fill_fields_in_open_dialog  $nameToStopNum  $nameToVal  "'$INTERLACE' dialog"

  set dDescr "command to close '$INTERLACE' dialog and start interlacing"
  if { (0 == [ok_twapi::send_tabs_to_reach_subwindow_in_open_dialog   \
                                      "Create with All Files" 1]) ||  \
       ("" == [set hRF [ok_twapi::_send_cmd_keys {{SPACE}} $dDescr 0]])    }  {
    puts "-E- Failed to $dDescr";    return  ""
  }
  # verify we returned to the image window (NEW title = $lentWndTitleGlob)
  set hI [ok_twapi::wait_for_window_title_to_raise $lentWndTitleGlob "glob"]
  if { $hI == "" } {
    puts "-E- Failed returning to image window"; return ""; # error details printed
  }
  puts "-I- Success performing '$INTERLACE' ... now need to save the result"
  
  # save
#ok_utils::pause;  #OK_TMP
  set saveInterlaceDescr "save result of '$INTERLACE' in directory '$outDirPath'"
  if { 0 == [spm::save_current_image_as_one_tiff "Save Image" $outDirPath \
                                                          $outImgNameNoExt] } {
    puts "-E- Failed to $saveInterlaceDescr";  return  ""
  }
  puts "-I- Success to $saveInterlaceDescr"
  return  [file join $outDirPath $outImgName]
}


# Makes TIFF files with L/R frames of 'inpSbsPath'
#   in subdir FRAMES_TMP/ of 'outRootDirPath'
# Ensures their are no other images in the output subdirectory
# Returns path of the output subdirectory or "" on error
proc ::spm::_make_lr_frames_in_their_subdir {inpSbsPath outRootDirPath} {
  variable FRAMES_SUBDIR_NAME
  variable FRAME_L_NOEXT
  variable FRAME_R_NOEXT
  set descr "split SBS stereopair '$inpSbsPath' into L/R frames"
  # provide empty output directory
  set outDirPath [file join $outRootDirPath $FRAMES_SUBDIR_NAME]
  set dDescr "frames subdirectory '$outDirPath'"
  # TODO: check for non-directory file with the same name 'outDirPath'
  if { [file exists $outDirPath] }  {
    puts "-I- Cleaning pre-existent $dDescr"
    file delete -force --  {*}[glob -nocomplain -directory $outDirPath *.*]
  } else {
    puts "-I- Creating new $dDescr"
    file mkdir $outDirPath
  }
  
  if { 0 == [spm::split_sbs_image_into_lr_tiffs $inpSbsPath \
                                $FRAME_L_NOEXT $FRAME_R_NOEXT $outDirPath] }  {
    puts "-E- Failed to $descr";    return  ""
  }
  puts "-I- Success to $descr; frame images are under '$outDirPath'"
  return  $outDirPath
}


#~ proc ::spm::build_name_for_interlace {imgPath lensLPI printDPI printWidth}  {
  #~ # TODO: implement
  #~ set outImgName [format "%s__il_lpi%s_dpi%s_wd%s" \
                          #~ [file rootname [file tail $imgPath]] \
                          #~ $lensLPIStr $printDPIStr $printWidthStr]
#~ }



#~ proc ::spm::UNUSED__build_native_frame_paths_sequence {inpNamesNoDir inpDirPath} {
  #~ set inpFramesSeq ""
  #~ foreach inpName $inpNamesNoDir {
    #~ set framePath [file nativename [file join $inpDirPath $inpName]]
    #~ append inpFramesSeq " " $framePath
  #~ }
  #~ return [string trim $inpFramesSeq]
#~ }
