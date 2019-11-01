# spm_tasks.tcl  - ultimate _processing_ commands for StereoPhotoMaker tasks

# Assumes option 'Startup with its window maximised'
# Assumes option 'Do not save report files'

#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # YogaBook
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # MIIX-320
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # Win7 desktop

package require twapi;  #  TODO: check errors

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR "ok_utils" "inifile.tcl"]
source [file join $SCRIPT_DIR "ok_twapi_common.tcl"]
source [file join $SCRIPT_DIR "spm_tabstops_def.tcl"]
source [file join $SCRIPT_DIR "spm_basics.tcl"]



# Prepares CFG, opens multi-convert GUI, loads settings from the CFG,
# starts conversion and waits for it to finish.
# Returns to the top SPM window.
# Returns 1 on success, 0 on error.
proc ::spm::cmd__align_all {inpType reuseAlignData} {
  if { ![string equal -nocase $inpType "SBS"] }  {
    puts "-E- Only SBS input type is curently supported"
    return  0
  }
  variable SUBDIR_PRE;  # subdirectory for pre-aligned images
  variable WA_ROOT
  set outDirFullPath [file normalize [file join $WA_ROOT $SUBDIR_PRE]]
  if { "" == [set cfgPath [_prepare_settings__align_all $inpType]] }  {
    return  0;  # need to abort; error already printed
  }
  set alignDir [spm::BuildAlignDirPath $inpType]
  if { [file exists $alignDir] }  {
    if { $reuseAlignData == 0 }  {
      if { [ok_utils::ok_force_delete_dir $alignDir] }  {
        puts "-I- Deleted old alignment data in '$alignDir'"
      };  # if failed to delete, error is printed
    } else {
      puts "-I- Will reuse old alignment data in '$alignDir'"
    }
  }
  # there may appear confirmation dialogs; tell to press "y" for each one
  set winTextPatternToResponseKeySeq [dict create \
    [format {^%s$} $outDirFullPath]     "y" \
    "Confirm Conversion Start"          "y" \
    {.alv$}                             "y" \
    [format {%s.*\.jpg$} $SUBDIR_PRE]   "y" \
    [format {%s.*\.tif$} $SUBDIR_PRE]   "y" \
    {^Attention}                        "{SPACE}" \
  ]
  set rc [spm::cmd__multiconvert  "alignment multi-conversion" ""         \
                                  $cfgPath $winTextPatternToResponseKeySeq]
  set spm::TABSTOPS $spm::TABSTOPS_DFL
  return  $rc
}


# Prepares CFG, opens multi-convert GUI, loads settings from the CFG,
# starts conversion and waits for it to finish.
# Returns to the top SPM window.
# Returns 1 on success, 0 on error.
proc ::spm::cmd__crop_all {inpType left top right bottom} {
  if { ![string equal -nocase $inpType "SBS"] }  {
    puts "-E- Only SBS input type is curently supported"
    return  0
  }
  variable SUBDIR_PRE;  # subdirectory for pre-aligned images - input
  variable SUBDIR_SBS;  # subdirectory for cropped images     - output
  variable WA_ROOT
  # input directory - the one with pre-aligned images
  
  set outDirFullPath [file normalize [file join $WA_ROOT $SUBDIR_SBS]]
  if { "" == [set cfgPath [_prepare_settings__crop_all $inpType   \
                                                $left $top $right $bottom]] }  {
    return  0;  # need to abort; error already printed
  }

  # there may appear confirmation dialogs; tell to press "y" for each one
  set winTextPatternToResponseKeySeq [dict create \
    [format {^%s$} $outDirFullPath]     "y" \
    "Confirm Conversion Start"          "y" \
    {.alv$}                             "y" \
    [format {%s.*\.jpg$} $SUBDIR_SBS]   "y" \
    [format {%s.*\.tif$} $SUBDIR_SBS]   "y" \
  ]
  set rc [spm::cmd__multiconvert  "cropping multi-conversion" $SUBDIR_PRE \
                                  $cfgPath $winTextPatternToResponseKeySeq]
  set spm::TABSTOPS $spm::TABSTOPS_DFL
  return  $rc
}


# Opens multi-convert GUI, loads settings from the cfgPath,
# starts conversion and waits for it to finish.
# Returns to the top SPM window.
# Returns 1 on success, 0 on error.
proc ::spm::cmd__adjust_all {inpType cfgPath} {
  if { ![string equal -nocase $inpType "SBS"] }  {
    puts "-E- Only SBS input type is curently supported"
    return  0
  }
  if { ![file exists $cfgPath] }  {
    puts "-E- Inexistent adjustment settings file '$cfgPath'"
    return  0
  }
  variable SUBDIR_PRE;  # subdirectory for pre-aligned images - input
  variable SUBDIR_SBS;  # subdirectory for adjusted images    - output
  variable WA_ROOT
  # input directory - the one with pre-aligned images
  
  set outDirFullPath [file normalize [file join $WA_ROOT $SUBDIR_SBS]]

  # there may appear confirmation dialogs; tell to press "y" for each one
  set winTextPatternToResponseKeySeq [dict create \
    [format {^%s$} $outDirFullPath]     "y" \
    "Confirm Conversion Start"          "y" \
    [format {%s.*\.jpg$} $SUBDIR_SBS]   "y" \
    [format {%s.*\.tif$} $SUBDIR_SBS]   "y" \
    {^Attention}                        "{SPACE}" \
  ]
  set rc [spm::cmd__multiconvert  "adjust-by-example multi-conversion" $SUBDIR_PRE \
                                  $cfgPath $winTextPatternToResponseKeySeq]
  set spm::TABSTOPS $spm::TABSTOPS_DFL
  return  $rc
}


# Loads stereopair from 'imgPath', adds the border, saves under the same name as .tif .
# Example: spm::cmd__fuzzy_border_one SBS "E:/TMP/SPM/290919__Glen_Mini3D/FIXED/SBS/2019_0929_133733_001.tif" 10 70 300
proc ::spm::cmd__fuzzy_border_one {inpType imgPath width gradient corners}  {
  variable TABSTOPS_DFL
  set ADD_BORDER "Add Fuzzy Border";  # dialog name / key / description
  if { ![spm::cmd__open_stereopair_image $inpType $imgPath] }  {
    return  0;   # error already printed
  }
  set imgWnd      [twapi::get_foreground_window]
  set imgWndTitle [twapi::get_window_text $imgWnd]
  if { $imgWnd != [ok_twapi::get_latest_app_wnd] }  {
    puts "-W- Foreground SPM window ($imgWnd) differs from the latest ([ok_twapi::get_latest_app_wnd])"
  }
  set dDescr "command to open '$ADD_BORDER' dialog"
  if { "" == [ok_twapi::_send_cmd_keys {+b} $dDescr 0] }  {
    return  0;  # error already printed
  }
  set hB [ok_twapi::wait_for_window_title_to_raise $ADD_BORDER "exact"]
  if { $hB == "" } {
    puts "-E- Failed to $dDescr";    return  0;  # error details already printed
  }
  # to make tabstops available in border dialog, press Alt-TAB twice
  set fDescr "switch-from-then-back to $ADD_BORDER dialog in order to make tabstops available"
  # ?WOODOO? to send one TAB, use [ twapi::send_keys {{TAB}} ]
  # ?WOODOO? to send one Alt-TAB, use [ twapi::send_keys [list %{TAB}] ]
  twapi::send_keys [list %{TAB}];  after 300;  twapi::send_keys [list %{TAB}]
  set hB [ok_twapi::wait_for_window_title_to_raise $ADD_BORDER "exact"]
  if { $hB == "" } {
    puts "-E- Failed to $fDescr";    return  0;  # error details already printed
  }
  puts "-I- Success to $fDescr"
  after 1000; # wait after returning to the dialog

  # Go over all fields in ascending tabstops order and process each one
  set nameToStopNum [lindex [dict filter $TABSTOPS_DFL key $ADD_BORDER] 1]
  set nameToVal [dict create        \
        "Border width"    $width    \
        "Fuzzy gradient"  $gradient \
        "Round corners"   $corners  ]
  ok_twapi::_fill_fields_in_open_dialog  $nameToStopNum  $nameToVal  "'$ADD_BORDER' dialog"

  set dDescr "command to close '$ADD_BORDER' dialog"
  if { "" == [ok_twapi::_send_cmd_keys {{ENTER}} $dDescr 0] }  {
    puts "-E- Failed performing '$ADD_BORDER'"
    return  0;  # error already printed
  }
  # verify we returned to the image window (title = $imgWndTitle)
  set hI [ok_twapi::wait_for_window_title_to_raise $imgWndTitle "exact"]
  if { $hI == "" } {
    puts "-E- Failed returning to image window";  return  0; # error details printed
  }
  puts "-I- Success performing '$ADD_BORDER'"
  
  # save
  set outDirPath [file dirname $imgPath]
  set saveWithBorderDescr "save image after '$ADD_BORDER' in directory '$outDirPath'"
  if { 0 == [spm::save_current_image_as_one_tiff $outDirPath] } {
    puts "-E- Failed to $saveWithBorderDescr";  return  0
  }
  puts "-I- Success to $saveWithBorderDescr";   return  1
}


# Adds the border to all stereopair(s) in 'imgDirPath',
#   saves them under the same names, but as .tif .
# Example: spm::cmd__fuzzy_border_all SBS "E:/TMP/SPM/290919__Glen_Mini3D/FIXED/SBS" 10 70 300
proc ::spm::cmd__fuzzy_border_all {inpType imgDirPath width gradient corners}  {
  set ADD_BORDER "Add Fuzzy Border";  # action description
  if { ! [ok_utils::ok_filepath_is_existent_dir $imgDirPath] }  {
    puts "-E- Invalid or inexistent images' input/output directory '$imgDirPath'"
    return  0
  }
  set imgPaths [concat  [glob -nocomplain -directory $imgDirPath -- "*.jpg"]  \
                        [glob -nocomplain -directory $imgDirPath -- "*.tif"]  ]
  set imgPaths [lsort $imgPaths]
  set cntImgs [llength $imgPaths]
  set addBorderAllDescr "'$ADD_BORDER' to $cntImgs image(s) in directory '$imgDirPath'"
  set errCnt 0
  puts "-I- Start to $addBorderAllDescr"
  foreach imgPath $imgPaths {
    if { 0 == [cmd__fuzzy_border_one  $inpType $imgPath \
                                      $width $gradient $corners] } {
      incr errCnt 1;  # error already printed
    }
  }
  if { $errCnt == 0 }   {
    puts "-I- Finished to $addBorderAllDescr; no errors occurred"
  } elseif { $errCnt == $cntImgs }  {
    puts "-E- Failed to $addBorderAllDescr; error(s) occurred for all $cntImgs image(s)"
  } else   {
    puts "-W- Finished to $addBorderAllDescr; $errCnt error(s) occurred"
  }
  return  [expr {$errCnt == 0}]
}


########### Begin: procedures to prepare SPM settings' files per task ########## 
# Builds INI file with settings for align-all action
# Returns new CFG file path on success, "" on error.
proc ::spm::_prepare_settings__align_all {inpType}  {
  # name of settings' file is the same as action templates' name
  set cfgName [format "align_%s.mcv" [string tolower $inpType]]
  return  [spm::_make_settings_file_from_template $inpType $cfgName \
                      "::spm::_align_all__SettingsModifierCB"  "align-all"]
}


proc ::spm::_align_all__SettingsModifierCB {inpType iniArrName}  {
  # TODO: take 'inpType' into consideration
  variable WA_ROOT
  variable SUBDIR_PRE;  # subdirectory for pre-aligned images
  upvar $iniArrName iniArr
  # should filepath be converted into native format? Works in TCL format too...
  set iniArr(-\[Data\]__OutputFolder)  [file join $WA_ROOT $SUBDIR_PRE]
  return  1
}


# Builds INI file with settings for align-all action
# Returns new CFG file path on success, "" on error.
proc ::spm::_prepare_settings__crop_all {inpType left top right bottom}  {
  # name of settings' file is the same as action templates' name
  set cfgName [format "crop_%s.mcv" [string tolower $inpType]]
  return  [spm::_make_settings_file_from_template $inpType $cfgName \
                      "::spm::_crop_all__SettingsModifierCB"  "crop-all" \
                      $left $top $right $bottom]
}


proc ::spm::_crop_all__SettingsModifierCB {inpType iniArrName \
                                            left top right bottom}  {
  # TODO: take 'inpType' into consideration
  variable WA_ROOT
  variable SUBDIR_SBS;  # subdirectory for final images
  upvar $iniArrName iniArr
  # should filepath be converted into native format? Works in TCL format too...
  set iniArr(-\[Data\]__OutputFolder)  [file join $WA_ROOT $SUBDIR_SBS]
  #
  set iniArr(-\[Data\]__Crop)       1
  set iniArr(-\[Data\]__CropLeft)   $left
  set iniArr(-\[Data\]__CropTop)    $top
  set iniArr(-\[Data\]__CropRight)  $right
  set iniArr(-\[Data\]__CropBottom) $bottom
  return  1
}
########### End:   procedures to prepare SPM settings' files per task ########## 