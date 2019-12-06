# spm_tasks.tcl  - ultimate _processing_ commands for StereoPhotoMaker tasks

# Assumes option 'Startup with its window maximised'
# Assumes option 'Do not save report files'

#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # YogaBook
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # MIIX-320
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # Win7 desktop

package require twapi;  #  TODO: check errors

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR "ok_utils" "inifile.tcl"]
source [file join $SCRIPT_DIR "ok_utils" "disk_info.tcl"]
source [file join $SCRIPT_DIR "ok_twapi_common.tcl"]
source [file join $SCRIPT_DIR "spm_tabstops_def.tcl"]
source [file join $SCRIPT_DIR "spm_basics.tcl"]



# Prepares CFG, opens multi-convert GUI, loads settings from the CFG,
# starts conversion and waits for it to finish.
# Returns to the top SPM window.
# Returns 1 on success, 0 on error.
proc ::spm::cmd__align_all {inpType reuseAlignData} {
  if { ![string equal -nocase $inpType "SBS"] }  {
    puts "-E- Only SBS input type is currently supported"
    return  0
  }
  set descr "alignment multi-conversion"
  if { ![ok_twapi::verify_singleton_running $descr] }  { return  0 }
  variable SUBDIR_PRE;  # subdirectory for pre-aligned images
  variable WA_ROOT
  set origStats [ok_utils::ok_read_all_files_stat_in_dir \
                                        $spm::WA_ROOT $spm::ORIG_PATTERN 1]
  set inpStats [ok_utils::ok_override_files_stat_time $origStats mtime \
                            [clock seconds]];   # assume originals just created
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
  # (patterns with image extensions included to force checking for input errors)
  set outDirForRegexp [ok_utils::ok_format_filepath_for_regexp $outDirFullPath]
  set winTextPatternToResponseKeySeq [dict create \
    [format {^%s$} $outDirForRegexp]    "y" \
    "Confirm Conversion Start"          "y" \
    {.alv$}                             "y" \
    [format {%s.*\.jpg$} $SUBDIR_PRE]   "y" \
    [format {%s.*\.tif$} $SUBDIR_PRE]   "y" \
    {^Attention}                        "{SPACE}" \
    {\.jpg$}                            "" \
    {\.tif$}                            "" \
  ]
  set rc [spm::cmd__multiconvert  $descr ""         \
                                  $cfgPath $winTextPatternToResponseKeySeq]
  set spm::TABSTOPS $spm::TABSTOPS_DFL
  register_phase_results [lindex [info level 0] 0] \
    [verify_output_images_vs_inputs $inpType $inpStats $outDirFullPath ".TIF"]
  return  $rc
}


# Prepares CFG, opens multi-convert GUI, loads settings from the CFG,
# starts conversion and waits for it to finish.
# Returns to the top SPM window.
# Returns 1 on success, 0 on error.
# Example for DC101: ::spm::cmd__crop_all SBS 208 256 1372 1908
proc ::spm::cmd__crop_all {inpType left top right bottom} {
  if { ![string equal -nocase $inpType "SBS"] }  {
    puts "-E- Only SBS input type is currently supported"
    return  0
  }
  set descr "cropping multi-conversion"
  if { ![ok_twapi::verify_singleton_running $descr] }  { return  0 }
  variable SUBDIR_PRE;  # subdirectory for pre-aligned images - input
  variable SUBDIR_SBS;  # subdirectory for cropped images     - output
  variable WA_ROOT
  # input directory - the one with pre-aligned images
  set inpDirFullPath [file normalize [file join $WA_ROOT $SUBDIR_PRE]]
  set inpStats [ok_utils::ok_read_all_files_stat_in_dir \
                                        $inpDirFullPath "*.TIF" 1]
  
  set outDirFullPath [file normalize [file join $WA_ROOT $SUBDIR_SBS]]
  if { "" == [set cfgPath [_prepare_settings__crop_all $inpType   \
                                                $left $top $right $bottom]] }  {
    return  0;  # need to abort; error already printed
  }

  # there may appear confirmation dialogs; tell to press "y" for each one
  # (patterns with input paths included to force checking for input errors)
  set outDirForRegexp [ok_utils::ok_format_filepath_for_regexp $outDirFullPath]
  set winTextPatternToResponseKeySeq [dict create \
    [format {^%s$} $outDirForRegexp]    "y" \
    "Confirm Conversion Start"          "y" \
    {.alv$}                             "y" \
    [format {%s.*\.jpg$} $SUBDIR_SBS]   "y" \
    [format {%s.*\.tif$} $SUBDIR_SBS]   "y" \
    [format {%s.*\.jpg$} $SUBDIR_PRE]   "" \
    [format {%s.*\.tif$} $SUBDIR_PRE]   "" \
  ]
  set rc [spm::cmd__multiconvert  $descr $SUBDIR_PRE \
                                  $cfgPath $winTextPatternToResponseKeySeq]
  set spm::TABSTOPS $spm::TABSTOPS_DFL
  
  register_phase_results [lindex [info level 0] 0] \
    [verify_output_images_vs_inputs $inpType $inpStats $outDirFullPath ".TIF"]
  return  $rc
}


# Prepares CFG, opens multi-convert GUI, loads settings from the CFG,
# starts conversion and waits for it to finish.
# Returns to the top SPM window.
# Returns 1 on success, 0 on error.
# Example: (for DC101)  ::spm::cmd__window_crop_all  SBS  527  -10.0  208 356  1372 1908
# !!! Note, rotation-angle here should be x10 of that of SPM easy-adjustment !!!
proc ::spm::cmd__window_crop_all {inpType horizPos rotAngle \
                                  left top right bottom} {
  if { ![string equal -nocase $inpType "SBS"] }  {
    puts "-E- Only SBS input type is currently supported"
    return  0
  }
  set descr "window, rotate and crop"
  if { ![ok_twapi::verify_singleton_running $descr] }  { return  0 }
  variable SUBDIR_PRE;  # subdirectory for pre-aligned images     - input
  variable SUBDIR_SBS;  # subdirectory with finished stereopairs  - output
  variable WA_ROOT
  set inpDirFullPath [file normalize [file join $WA_ROOT $SUBDIR_PRE]]
  set inpStats [ok_utils::ok_read_all_files_stat_in_dir \
                                        $inpDirFullPath "*.TIF" 1]

  # Output directory name is hardcoded inside 'settingsModifierCB'
  #   AND should be 'SUBDIR_SBS'
  if { "" == [set cfgPath [_prepare_settings__window_crop_all $inpType \
                            $horizPos $rotAngle $left $top $right $bottom]] }  {
    return  0;  # need to abort; error already printed
  }
 
  set res [cmd__adjust_all $inpType $cfgPath $SUBDIR_PRE $SUBDIR_SBS]
  
  set outDirFullPath [file normalize [file join $WA_ROOT $SUBDIR_SBS]]
  register_phase_results [lindex [info level 0] 0] \
    [verify_output_images_vs_inputs $inpType $inpStats $outDirFullPath ".TIF"]
  return  $res
}


# Opens multi-convert GUI, loads settings from the cfgPath,
# starts conversion and waits for it to finish.
# Returns to the top SPM window.
# Returns 1 on success, 0 on error.
# Example:  spm::cmd__adjust_all SBS [file normalize {D:\DC_TMP\TRY_AUTO\DC101\290919__Glen_Mini3D\CONFIG\window_crop__sbs.mcv}] "Pre" "SBS"
proc ::spm::cmd__adjust_all {inpType cfgPath inpSubdirName outSubdirName} {
  if { ![string equal -nocase $inpType "SBS"] }  {
    puts "-E- Only SBS input type is currently supported"
    return  0
  }
  set descr "adjust-by-example multi-conversion"
  if { ![ok_twapi::verify_singleton_running $descr] }  { return  0 }
  if { ![file exists $cfgPath] }  {
    puts "-E- Inexistent adjustment settings file '$cfgPath'"
    return  0
  }

  variable WA_ROOT
  
  set outDirFullPath [file normalize [file join $WA_ROOT $outSubdirName]]

  # there may appear confirmation dialogs; tell to press "y" for each one
  set outDirForRegexpFP [ok_utils::ok_format_filepath_for_regexp $outDirFullPath]
  set outDirForRegexpRP [ok_utils::ok_format_filepath_for_regexp $outSubdirName]
  set winTextPatternToResponseKeySeq [dict create \
    [format {^%s$} $outDirForRegexpFP]        "y" \
    "Confirm Conversion Start"                "y" \
    [format {%s.*\.jpg$} $outDirForRegexpRP]  "y" \
    [format {%s.*\.tif$} $outDirForRegexpRP]  "y" \
    {^Attention}                        "{SPACE}" \
  ]
  # (patterns with input paths included to force checking for input errors)
  if { $inpSubdirName != $outSubdirName } {
    dict set winTextPatternToResponseKeySeq  [format {%s.*\.jpg$} $inpSubdirName]  ""
    dict set winTextPatternToResponseKeySeq  [format {%s.*\.tif$} $inpSubdirName]  ""
  }
  set rc [spm::cmd__multiconvert  $descr $inpSubdirName \
                                  $cfgPath $winTextPatternToResponseKeySeq]
  set spm::TABSTOPS $spm::TABSTOPS_DFL
  return  $rc
}


# Formats ready stereopairs for one output type (viewer).
# Prepares CFG, opens multi-convert GUI, loads settings from the CFG,
# starts conversion and waits for it to finish.
# Returns to the top SPM window.
# Returns 1 on success, 0 on error.
proc ::spm::cmd__format_all {inpType settingsTemplateName settingsModifierCB \
                                             outSubdirName descr {phaseId ""}} {
  if { ![string equal -nocase $inpType "SBS"] }  {
    puts "-E- Only SBS input type is currently supported"
    return  0
  }
  if { ![ok_twapi::verify_singleton_running $descr] }  { return  0 }
  variable SUBDIR_SBS;  # subdirectory with inputs - finished stereopairs
  variable SUBDIR_OUTFORMAT_ROOT; # subdirectory for formated-for-outputs images
  variable WA_ROOT
  if { $phaseId == "" }   {
    set phaseId [format "%s--%s--%s"  [lindex [info level 0] 0] \
                                    $settingsTemplateName $settingsModifierCB]
  }
  set inpDirFullPath [file normalize [file join $WA_ROOT $SUBDIR_SBS]]
  set inpStats [ok_utils::ok_read_all_files_stat_in_dir \
                                        $inpDirFullPath "*.TIF" 1]
 
  # name of settings' file is the same as action templates' name
  set cfgName $settingsTemplateName

  set outSubdirRelPath [file join $SUBDIR_OUTFORMAT_ROOT $outSubdirName]
  # Output directory relative-path is hardcoded inside 'settingsModifierCB'
  #   AND should match 'outSubdirRelPath'
  if { "" == [set cfgPath [spm::_make_settings_file_from_template \
                      $inpType $cfgName $settingsModifierCB $descr]] } {
    return  0;  # need to abort; error already printed
  }
 
  set res [cmd__adjust_all $inpType $cfgPath $SUBDIR_SBS $outSubdirRelPath]
  
  set outDirFullPath [file normalize [file join $WA_ROOT $outSubdirRelPath]]
  register_phase_results $phaseId \
    [verify_output_images_vs_inputs $inpType $inpStats $outDirFullPath ".JPG"]
  return  $res
}


proc ::spm::cmd__format_all__SBS_3840x2160 {inpType} {
  return  [cmd__format_all  $inpType "convert_sbs_to_sbs_3840x2160.mcv"     \
                            "::spm::_out_format_4KSBS__SettingsModifierCB"  \
                            "4KSBS" "convert into 4K SBS, 3840x2160"        \
                            [lindex [info level 0] 0]]
}


proc ::spm::cmd__format_all__HAB_1920x1080 {inpType} {
  return  [cmd__format_all  $inpType "convert_sbs_to_hab_1920x1080.mcv"   \
                            "::spm::_out_format_HAB__SettingsModifierCB"  \
                            "HAB" "convert into HAB, 1920x1080"           \
                            [lindex [info level 0] 0]]
}

proc ::spm::cmd__format_all__HSBS_1920x1080 {inpType} {
  return  [cmd__format_all  $inpType "convert_sbs_to_hsbs_1920x1080.mcv"    \
                            "::spm::_out_format_HSBS__SettingsModifierCB"   \
                            "HSBS" "convert into HSBS, 1920x1080"           \
                            [lindex [info level 0] 0]]
}

# Loads stereopair from 'imgPath', adds the border, saves under the same name as .tif .
# Example: spm::cmd__fuzzy_border_one SBS "E:/TMP/SPM/290919__Glen_Mini3D/FIXED/SBS/2019_0929_133733_001.tif" 10 70 300
proc ::spm::cmd__fuzzy_border_one {inpType imgPath width gradient corners}  {
  variable TABSTOPS_DFL
  set ADD_BORDER "Add Fuzzy Border";  # dialog name / key / description
  if { ![ok_twapi::verify_singleton_running $ADD_BORDER] } { return  0 }
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
# Example: spm::cmd__fuzzy_border_all  SBS  [file join $::spm::WA_ROOT "SBS"]  10 70 300
proc ::spm::cmd__fuzzy_border_all {inpType imgDirPath width gradient corners}  {
  set ADD_BORDER "Add Fuzzy Border";  # action description
  if { ![ok_twapi::verify_singleton_running $ADD_BORDER] } { return  0 }
  if { ! [ok_utils::ok_filepath_is_existent_dir $imgDirPath] }  {
    puts "-E- Invalid or inexistent images' input/output directory '$imgDirPath'"
    return  0
  }
  set inpStats_JPG [ok_utils::ok_read_all_files_stat_in_dir \
                                        $imgDirPath "*.JPG" 1]
  set inpStats_TIF [ok_utils::ok_read_all_files_stat_in_dir \
                                        $imgDirPath "*.TIF" 1]
  set inpStats [dict merge $inpStats_JPG $inpStats_TIF] 

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
  
  register_phase_results [lindex [info level 0] 0] \
    [verify_output_images_vs_inputs $inpType $inpStats $imgDirPath ".TIF"]
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
  # Do convert filepath into native format! TCL format OK for win10, not win7
  set iniArr(-\[Data\]__OutputFolder)  [file nativename [file join $WA_ROOT $SUBDIR_PRE]]
  return  1
}


# Builds INI file with settings for window-and-crop-all action
# Returns new CFG file path on success, "" on error.
proc ::spm::_prepare_settings__window_crop_all {inpType \
                                    horizPoz rotAngle left top right bottom}  {
  # name of settings' file is the same as action templates' name
  set cfgName [format "window_crop_%s.mcv" [string tolower $inpType]]
  set paramDict [dict create                                                  \
        "Position_H"        $horizPoz                                         \
        "Rotation_Angle"    $rotAngle                                         \
        "CropCoords_LTRB"   [list $left $top $right $bottom] ]
  
  return  [spm::_make_settings_file_from_template $inpType $cfgName         \
                      "::spm::_window_rotate_crop_all__SettingsModifierCB"  \
                      "window-rotate-and-crop-all" $paramDict]
}


proc ::spm::_window_rotate_crop_all__SettingsModifierCB {inpType iniArrName \
                                                         posAndCoordDict}  {
  # TODO: take 'inpType' into consideration
  upvar $iniArrName iniArr
  set horizPoz  [dict get $posAndCoordDict "Position_H"]
  set rotAngle  [dict get $posAndCoordDict "Rotation_Angle"]
  set coordList [dict get $posAndCoordDict "CropCoords_LTRB"]
  set iniArr(-\[Data\]__ValueAlignOn)       1
  set iniArr(-\[Data\]__ValueAlignOn)       1
  set iniArr(-\[Data\]__Rotation_L)         $rotAngle
  set iniArr(-\[Data\]__Rotation_R)         $rotAngle
  set iniArr(-\[Data\]__Position_H)         $horizPoz
  # run the callback for pure crop - it will set both crop coords and output dir
  return  [_crop_all__SettingsModifierCB $inpType iniArr $coordList]
}


# Builds INI file with settings for crop-all action
# Returns new CFG file path on success, "" on error.
proc ::spm::_prepare_settings__crop_all {inpType left top right bottom}  {
  # name of settings' file is the same as action templates' name
  set cfgName [format "crop_%s.mcv" [string tolower $inpType]]
  return  [spm::_make_settings_file_from_template $inpType $cfgName \
                      "::spm::_crop_all__SettingsModifierCB"  "crop-all" \
                      [list $left $top $right $bottom]]
}


proc ::spm::_crop_all__SettingsModifierCB {inpType iniArrName coordList_LTRB}  {
  # TODO: take 'inpType' into consideration
  variable WA_ROOT
  variable SUBDIR_SBS;  # subdirectory for final images
  upvar $iniArrName iniArr
  set left  [lindex $coordList_LTRB 0];  set top    [lindex $coordList_LTRB 1]
  set right [lindex $coordList_LTRB 2];  set bottom [lindex $coordList_LTRB 3]
  # Do convert filepath into native format! TCL format OK for win10, not win7
  set iniArr(-\[Data\]__OutputFolder)  [file nativename [file join $WA_ROOT $SUBDIR_SBS]]
  #
  set iniArr(-\[Data\]__Crop)       1
  set iniArr(-\[Data\]__CropLeft)   $left
  set iniArr(-\[Data\]__CropTop)    $top
  set iniArr(-\[Data\]__CropRight)  $right
  set iniArr(-\[Data\]__CropBottom) $bottom
  return  1
}


proc ::spm::_out_format_4KSBS__SettingsModifierCB {inpType iniArrName}  {
  # TODO: take 'inpType' into consideration
  upvar $iniArrName iniArr
  variable SUBDIR_OUTFORMAT_ROOT; # subdirectory for formated-for-outputs images
  return  [_set_outdir_in_settings_modifier iniArr \
                                    [file join $SUBDIR_OUTFORMAT_ROOT "4KSBS"]]
}

proc ::spm::_out_format_HAB__SettingsModifierCB {inpType iniArrName}  {
  # TODO: take 'inpType' into consideration
  upvar $iniArrName iniArr
  variable SUBDIR_OUTFORMAT_ROOT; # subdirectory for formated-for-outputs images
  return  [_set_outdir_in_settings_modifier iniArr  \
                                    [file join $SUBDIR_OUTFORMAT_ROOT "HAB"]]
}

proc ::spm::_out_format_HSBS__SettingsModifierCB {inpType iniArrName}  {
  # TODO: take 'inpType' into consideration
  upvar $iniArrName iniArr
  variable SUBDIR_OUTFORMAT_ROOT; # subdirectory for formated-for-outputs images
  return  [_set_outdir_in_settings_modifier iniArr  \
                                    [file join $SUBDIR_OUTFORMAT_ROOT "HSBS"]]
}
  

# Common-use config-modification utility that only sets output path 
proc ::spm::_set_outdir_in_settings_modifier {iniArrName outSubdirName}  {
  # TODO: take 'inpType' into consideration
  variable WA_ROOT
  upvar $iniArrName iniArr
  # Do convert filepath into native format! TCL format OK for win10, not win7
  set iniArr(-\[Data\]__OutputFolder)  [file nativename [file join $WA_ROOT $outSubdirName]]
  #
  return  1
}


#~ # Builds INI file with settings for format-to-HAB-1920x1080 action
#~ # Returns new CFG file path on success, "" on error.
#~ proc ::spm::_prepare_settings__format_all__HAB_1920x1080 {inpType outDirPath}  {
  #~ # name of settings' file is the same as action templates' name
  #~ set cfgName [format "format_%s__HAB_1920x1080.mcv" [string tolower $inpType]]
  #~ # TODO:implement. ??? How to send 'outDirPath'???
  #~ return  [spm::_make_settings_file_from_template $inpType $cfgName \
            #~ "::spm::_set_outdir__SettingsModifierCB"  "format-to-HAB-1920x1080"]
#~ }


########### End:   procedures to prepare SPM settings' files per task ########## 
