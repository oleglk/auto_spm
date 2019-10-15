# spm_basics.tcl  - basic procedures for automating StereoPhotoMaker

# Assumes option 'Startup with its window maximised'
# Assumes option 'Do not save report files'

#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # YogaBook
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # MIIX-320
#  set ::SPM [file normalize {C:\Program Files\StereoPhotoMaker\stphmkre.exe}];  # Win7 desktop

package require twapi;  #  TODO: check errors

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR "ok_utils" "inifile.tcl"]
source [file join $SCRIPT_DIR "ok_twapi_common.tcl"]

set SPM_SETTINGS_TEMPLATES_DIR [file join $SCRIPT_DIR ".." "SPM_INI"]

namespace eval ::spm:: {
  ### variable ORIG_PATTERN {*.tif}
  variable ORIG_PATTERN {*.jpg}
#  variable SUBDIR_INP "";  # subdirectory for to-be-aligned images - DEFAULT
  variable SUBDIR_INP "FIXED";  # subdirectory for to-be-aligned images
  variable SUBDIR_PRE "Pre";    # subdirectory for pre-aligned images
  variable SUBDIR_CFG "CONFIG";  # subdirectory for session-specific config files
  
  variable SPM_TITLE  "StereoPhoto Maker" ;   # title of the main SPM window

  
  variable WA_ROOT "";  # work-area root directory
  
  variable TABSTOPS 0; # 2-level dict of wnd-title :: control-name :: tabstop

  
  namespace export  \
    # (DO NOT EXPORT:)  start_singleton  \
    # (DO NOT EXPORT:)  fix_one_file
}


################################################################################
# Builds ::spm::TABSTOPS dictionary that tells how many times to press TAB
# in order to focus specific control.
# For "Multi Conversion" window  this order holds only if open programmatically!
proc ::spm::_build_tabstops_dict {}   {
  variable TABSTOPS; # 2-level dict of wnd-title :: control-name :: tabstop
  set TABSTOPS [dict create]
  dict set TABSTOPS   "Multi Conversion"    "File name"                 6
  dict set TABSTOPS   "Multi Conversion"    "Cancel"                    8
  dict set TABSTOPS   "Multi Conversion"    "Convert Selected Files"    9
  dict set TABSTOPS   "Multi Conversion"    "Convert All Files"         10
  dict set TABSTOPS   "Multi Conversion"    "Multi Job"                 11
  dict set TABSTOPS   "Multi Conversion"    "Output File Type"          15
  dict set TABSTOPS   "Multi Conversion"    "Output File Format"        16
  dict set TABSTOPS   "Multi Conversion"    "Crop"                      28
  dict set TABSTOPS   "Multi Conversion"    "Crop X1"                   29
  dict set TABSTOPS   "Multi Conversion"    "Crop Y1"                   30
  dict set TABSTOPS   "Multi Conversion"    "Crop X2"                   31
  dict set TABSTOPS   "Multi Conversion"    "Crop Y2"                   32
  dict set TABSTOPS   "Multi Conversion"    "Output Folder"             42
  dict set TABSTOPS   "Multi Conversion"    "Restore(File)"             45
  dict set TABSTOPS   "Multi Conversion"    "Restore"                   46
  dict set TABSTOPS   "Multi Conversion"    "Save"                      47
  #dict set TABSTOPS   "Multi Conversion"    "todo"        todo

}

# Returns tabstop number or -1 on error
proc ::spm::_get_tabstop {wndTitle controlName}   {
  variable TABSTOPS; # 2-level dict of wnd-title :: control-name :: tabstop
  if { ! [info exists TABSTOPS] }  {
    puts "-E- TABSTOPS dictionary not built yet"
    return  -1
  }
  if { ! [dict exists $TABSTOPS $wndTitle $controlName] }  {
    puts "-E- Unknown UI control '$controlName' in window '$wndTitle'"
    return  -1
  }
  return  [dict get $TABSTOPS $wndTitle $controlName]
}

# Returns srring of repeated TAB-s (by tabstop number) or "ERROR" on error
proc ::spm::_format_tabstop  {wndTitle controlName}   {
  if { -1 == [set nTabs [_get_tabstop $wndTitle $controlName]] }  {
    return  "ERROR"
  }
  if { $nTabs == 0 }  { return "" }
  set seq "{TAB}"
  for {set i 1} {$i < $nTabs} {incr i}  { append seq " " "{TAB}"  }
  return  $seq
}

  
################################################################################


proc ::spm::start_spm {{workarea_rootdir ""}}  {
  variable WA_ROOT
  variable SPM_TITLE
  if { $workarea_rootdir != "" }  {
    if { ![file isdirectory $workarea_rootdir] }  {
      puts "-E- Invalid or inexistent directory '$workarea_rootdir'"
      return  0
    }
    if { ($::spm::TABSTOPS == 0) && (0 == [_build_tabstops_dict]) }   {
      return  0;  # error already printed
    }
    set WA_ROOT [file normalize $workarea_rootdir]
    puts "-I- Workarea root directory set to '$WA_ROOT'"
  }
  return  [::ok_twapi::start_singleton $::SPM \
                "StereoPhotoMaker" $SPM_TITLE $workarea_rootdir]
  # TODO: maximize SPM window
}


proc ::spm::quit_spm {}  {
  return  [::ok_twapi::quit_singleton ::spm::cmd__return_to_top]
}


# Returns 1 if the current foreground window is SPM-top or its descendant
proc ::spm::is_current_window_spm {} {
  return  [::ok_twapi::is_current_window_related]
}


proc ::spm::cmd__return_to_top {} {
  set descr "reach SPM top";  # [lindex [info level 0] 0]
  if { ![::ok_twapi::verify_singleton_running $descr] }  { return  0 }; # FIRST!
  if { 0 == [::ok_twapi::focus_singleton "focus to $descr" 0] }  {
    return  0;  # warning already printed
  }
  set nAttempts 30
  for {set i 1} {$i <= $nAttempts} {incr i 1}  {
    set topWnd [::ok_twapi::get_top_app_wnd]
    if { $topWnd == [set h [twapi::get_foreground_window]] }   {
      puts "-I- Success to $descr after [expr $i-1] hit(s) of ESCAPE"
      ::ok_twapi::set_latest_app_wnd $topWnd
      return  1
    }
    puts "-I- Pressing ESCAPE ($i of $nAttempts) to $descr"
    twapi::send_keys {{ESCAPE}}
    after 2000;  # wait A LOT after ESCAPE
  }
  puts "-E- Failed to $descr after $nAttempts hit(s) of ESCAPE"
  return  0
}


# Opens multi-convert GUI; if 'cfgPath' given, loads settings from it.
# Returns handle of resulting window or "" on error.
proc ::spm::cmd__open_multi_conversion {{cfgPath ""}} {
  variable WA_ROOT
  puts -nonewline "-I- Commanded to open multi-convert GUI"
  if { $cfgPath == "" }  { puts ""
  } else {                 puts " and load settings from '$cfgPath'" }
  set descr [lindex [info level 0] 0]
  if { ![::ok_twapi::verify_singleton_running $descr] }  { return  ""}; # FIRST!
  #twapi::block_input
  # _send_cmd_keys {{MENU}f} $descr [::ok_twapi::get_top_app_wnd]
  if { 0 == [::ok_twapi::open_menu_top_level "f" $descr] }  {
    return  "";  # error already printed
  }
  if { "" == [::ok_twapi::travel_meny_hierarchy {{m 2}{ENTER}} \
                                      $descr "Multi Conversion"] }  {
    #twapi::unblock_input
    return  "";  # error already printed
  }
  if { 0 == [::ok_twapi::cmd__maximize_current_window] }  {
    #twapi::unblock_input
    return  "";  # error already printed
  }
  #twapi::unblock_input
  set hMC [::ok_twapi::set_latest_app_wnd_to_current]
  if { $cfgPath == "" }  {  return  $hMC }
  if { $hMC == "" }  { return  "" };  # error already printed
  # multi-convert GUI is open in FG; focus "File Name" textbox and type input dir path
  set iDescr "specify input directory"
  twapi::send_keys {%n};  # in a raw twapi way - since Alt should be held down
  set inpPathSeq "[file nativename $WA_ROOT]{ENTER}"
  if { "" == [ok_twapi::_send_cmd_keys $inpPathSeq $iDescr $hMC] }  {
    return  "";  # error already printed
  }
  # load align-all settings from 'cfgPath' - AFTER input dir(s) specified
  #~ set tabStop [_get_tabstop  "Multi Conversion"  "Restore(File)"];  # existent
  #~ set keySeqLoadCfg [format "{{{TAB} %d} {SPACE}}" $tabStop]
  set lDescr "Press 'Restore(File)' button"
  set tabsStr [_format_tabstop  "Multi Conversion"  "Restore(File)"];  # existent
  if {  ("" == [ok_twapi::_send_cmd_keys $tabsStr $lDescr 0]) || \
        ("" == [set hRF [ok_twapi::_send_cmd_keys {{SPACE}} $lDescr 0]]) }  {
    return  "";  # error already printed
  }
  ####### TODO: IT SEEMS TO PRESS "SAVE" instead of "RESTORE"
  # type 'cfgPath' then hit OK
  set pDescr "Specify settings-file path"
  set nativeCfgPath [file nativename $cfgPath]
  if {  ("" == [ok_twapi::_send_cmd_keys $nativeCfgPath $pDescr 0]) || \
        ("" == [set hMC2 [ok_twapi::_send_cmd_keys {{ENTER}} $pDescr 0]]) }  {
    return  "";  # error already printed
  }
  if { $hMC2 != $hMC }   {
    puts "-E- Unexpected window '[twapi::get_window_text $hMC2]' after loading multi-conversion settings"
    return  ""
  }
  return  $hMC2
}


# Builds INI file with settings for align-all action
proc ::spm::_prepare_settings__align_all {inpType}  {
  variable WA_ROOT
  variable ORIG_PATTERN
  variable SUBDIR_INP;  # subdirectory for to-be-aligned images
  variable SUBDIR_PRE;  # subdirectory for pre-aligned images
  variable SUBDIR_CFG;  # subdirectory for session-specific config files
  if { 0 == [ok_utils::ok_create_absdirs_in_list \
                    [list [file join $WA_ROOT $SUBDIR_CFG]] \
                    [list "subdirectory for session-specific config files"]] } {
    return  0;  # need to abort; error already printed
  }
  # name of settings' file is the same as action teplates' name
  set cfgName [format "align_%s.mcv" [string tolower $inpType]]
  # load settings' template - everything but directory paths
  set templatePath [file join $::SPM_SETTINGS_TEMPLATES_DIR $cfgName]
  if { 0 == [ok_utils::ini_file_to_ini_arr $templatePath iniArr] }  {
    return  0;  # need to abort; error already printed
  }
  puts "-I- Align-all settings template loaded from '$templatePath'"
  set iniArr(-\[Data\]__OutputFolder)  [file join $WA_ROOT $SUBDIR_PRE]
  set cfgPath [file join $WA_ROOT $SUBDIR_CFG $cfgName]
  if { 0 == [ok_utils::ini_arr_to_ini_file iniArr $cfgPath 1] }  {
    return  0;  # need to abort; error already printed
  }
  puts "-I- Align-all settings written into '$cfgPath'"
#### In the caller:
  #~ puts "-I- Open multi-convert GUI and load align-all settings from '$cfgPath'"
  #~ cmd__open_multi_conversion $cfgPath
  return  1
}
