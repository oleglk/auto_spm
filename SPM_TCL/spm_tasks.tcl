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
