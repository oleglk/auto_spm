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
source [file join $SCRIPT_DIR "spm_basics.tcl"]



# Prepares CFG, opens multi-convert GUI, loads settings from the CFG,
# starts conversion and waits for it to finish.
# Returns to the top SPM window.
# Returns 1 on success, 0 on error.
proc ::spm::cmd__align_all {inpType origExt} {
  # TODO: take 'origExt' into consideration
  if { ![string equal -nocase $inpType "SBS"] }  {
    puts "-E- Only SBS input type is curently supported"
    return  0
  }
  variable SUBDIR_PRE;  # subdirectory for pre-aligned images
  if { "" == [set cfgPath [_prepare_settings__align_all $inpType]] }  {
    return  0;  # need to abort; error already printed
  }
  # there may appear confirmation dialogs; tell to press "y" for each one
  set winTextPatternToResponseKeySeq [dict create \
    "Confirm Conversion Start"          "y" \
    {.alv$}                             "y" \
    [format {%s.*\.jpg$} $SUBDIR_PRE]   "y" \
    [format {%s.*\.tif$} $SUBDIR_PRE]   "y" \
  ]
  return  [spm::cmd__multiconvert "alignment multi-conversion" $cfgPath \
                                  $origExt $winTextPatternToResponseKeySeq]
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
########### End:   procedures to prepare SPM settings' files per task ########## 
