# spm_basics.tcl  - basic procedures for automating StereoPhotoMaker

# Assumes option 'Startup with its window maximised'
# Assumes option 'Do not save report files'

#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # YogaBook
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # MIIX-320
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # Win7 desktop

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
#                 in order to focus specific control AFTER FILENAME ENTRY
#    E.g.: press Alt-n, then count the tabstops
# For "Multi Conversion" window  this order holds only if open programmatically!
proc ::spm::_build_tabstops_dict {}   {
  variable TABSTOPS; # 2-level dict of wnd-title :: control-name :: tabstop
  set TABSTOPS [dict create]
  dict set TABSTOPS   "Multi Conversion"    "File name"                 0
  dict set TABSTOPS   "Multi Conversion"    "Input File Type"           1
  dict set TABSTOPS   "Multi Conversion"    "Cancel"                    2
  dict set TABSTOPS   "Multi Conversion"    "Convert Selected Files"    3
  dict set TABSTOPS   "Multi Conversion"    "Convert All Files"         4
  dict set TABSTOPS   "Multi Conversion"    "Multi Job"                 5
  
  dict set TABSTOPS   "Multi Conversion"    "Output File Type"          9
  dict set TABSTOPS   "Multi Conversion"    "Output File Format"        10
  dict set TABSTOPS   "Multi Conversion"    "Auto Align"                11
  dict set TABSTOPS   "Multi Conversion"    "Auto Alignment Settings"   12

  dict set TABSTOPS   "Multi Conversion"    "Auto Crop After Adjustment" 15

  dict set TABSTOPS   "Multi Conversion"    "Auto Color Adjustment"     18
  dict set TABSTOPS   "Multi Conversion"    "Gamma"                     19
  dict set TABSTOPS   "Multi Conversion"    "Gamma L"                   20
  dict set TABSTOPS   "Multi Conversion"    "Gamma R"                   21
  dict set TABSTOPS   "Multi Conversion"    "Crop"                      22
  dict set TABSTOPS   "Multi Conversion"    "Crop X1"                   23
  dict set TABSTOPS   "Multi Conversion"    "Crop Y1"                   24
  dict set TABSTOPS   "Multi Conversion"    "Crop X2"                   25
  dict set TABSTOPS   "Multi Conversion"    "Crop Y2"                   26
  dict set TABSTOPS   "Multi Conversion"    "Resize"                    27
  dict set TABSTOPS   "Multi Conversion"    "Width"                     28
  dict set TABSTOPS   "Multi Conversion"    "Height"                    29
  dict set TABSTOPS   "Multi Conversion"    "Input Side-By-Side"        30
  
  dict set TABSTOPS   "Multi Conversion"    "Add Text"                  34


  dict set TABSTOPS   "Multi Conversion"    "Output Folder"             36
  dict set TABSTOPS   "Multi Conversion"    "Output Folder Browse"      37
  
  dict set TABSTOPS   "Multi Conversion"    "Restore(File)"             39
  dict set TABSTOPS   "Multi Conversion"    "Restore"                   40
  dict set TABSTOPS   "Multi Conversion"    "Save"                      41
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
  set inpPathSeq "[file nativename $WA_ROOT]"
  twapi::send_input_text $inpPathSeq
#return  "";  # OK_TMP
  twapi::send_keys {%o}  ;  # command to change input dir; used to be {ENTER}
  if { 0 == [ok_twapi::verify_current_window_by_title "Multi Conversion" 1] }  {
    return  "";  # error already printed
  }
  puts "-I- Commanded to change input directory to '$inpPathSeq'"
  twapi::send_keys {%n};  # return focus to Filename entry - start for tabstops

# load align-all settings from 'cfgPath' - AFTER input dir(s) specified
  #~ set tabStop [_get_tabstop  "Multi Conversion"  "Restore(File)"];  # existent
  #~ set keySeqLoadCfg [format "{{{TAB} %d} {SPACE}}" $tabStop]
  set lDescr "Press 'Restore(File)' button"
  set tabsStr [_format_tabstop  "Multi Conversion"  "Restore(File)"];  # existent
  if {  ("" == [ok_twapi::_send_cmd_keys $tabsStr $lDescr 0]) || \
        ("" == [set hRF [ok_twapi::_send_cmd_keys {{SPACE}} $lDescr 0]]) }  {
    return  "";  # error already printed
  }
  # type 'cfgPath' then hit  OK by pressing Alt-o (used to be ENTER in old SPM)
  set pDescr "Specify settings-file path"
  set nativeCfgPath [file nativename $cfgPath]
  if {  ("" == [ok_twapi::_send_cmd_keys $nativeCfgPath $pDescr 0]) || \
        ("" == [set hMC2 [ok_twapi::_send_cmd_keys {%o} $pDescr 0]]) }  {
    return  "";  # error already printed
  }
  if { $hMC2 != $hMC }   {
    puts "-E- Unexpected window '[twapi::get_window_text $hMC2]' after loading multi-conversion settings"
    return  ""
  }
  return  $hMC2
}



# Opens multi-convert GUI, loads settings from 'cfgPath',
# starts conversion and waits for it to finish.
# 'winTextPatternToResponseKeySeq' tells how to respond
#          to (optional) confirmation dialogs
# Returns to the top SPM window.
# Returns 1 on success, 0 on error.
proc ::spm::cmd__multiconvert {descr cfgPath \
                                winTextPatternToResponseKeySeq} {
  set actDescr "$descr; config in '$cfgPath'"
 
  if { "" == [set hMC1 [cmd__open_multi_conversion $cfgPath]] }  {
    return  0;  # need to abort; error already printed
  }
  # arrange for commanding to start alignment multi-conversion
  twapi::send_keys {%n};  # return focus to Filename entry - start for tabstops
  set sDescr "Press 'Convert All Files' button"
  set tabsStr [_format_tabstop  "Multi Conversion"  "Convert All Files"]; # safe
  if {  ("" == [ok_twapi::_send_cmd_keys $tabsStr $sDescr 0]) || \
        ("" == [set h [ok_twapi::_send_cmd_keys {{SPACE}} $sDescr 0]]) }  {
    return  0;  # error already printed
  }
  puts "-I- Commanded to start $actDescr"
  # now there may appear multiple confirmation dialogs; press "y" for each one
  # - press Alt-F4 when:
  #   (a) no more confirmation dialogs (with "Yes" button) left
  #   (b) dialog with "Exit" button appeared
  ok_twapi::respond_to_popup_windows_based_on_text  \
                                  $winTextPatternToResponseKeySeq 3 20 $descr
  # there should be up to 3 windows titled "Multi Conversion"; close all but original
  set hList [::twapi::find_windows -match string -text "Multi Conversion"]
  set cntErr 0
  foreach hwnd $hList {
    if { $hwnd == [ok_twapi::get_latest_app_wnd] }  { continue } ;# skip original
    set wDescr "close {[twapi::get_window_text $hwnd]}"
    if { "" != [ok_twapi::focus_then_send_keys {%{F4}} $wDescr $hwnd] }  {
      set lastActionTime [clock seconds];   # success
    } else {
      incr cntErr 1                     ;   # error
    }
  }
  ok_twapi::set_latest_app_wnd_to_current;  # should be the top SPM window
  if { [ok_twapi::get_latest_app_wnd] != [ok_twapi::get_top_app_wnd] }  {
    puts "-W- Unexpected window '[twapi::get_window_text [ok_twapi::get_top_app_wnd]]' after multi-conversion is finished. Should be the top SPM window"
  }
  puts "-I- Finished $actDescr"
  return  [expr {$cntErr == 0}];  # OK_TMP
}


# Builds INI file with settings from existent "standard" template 'cfgName'.
# Changes from the template performed by 'modifierCB' callback procedure:
#         proc modifierCB {inpType iniArrName}  {}
# Returns new CFG file path on success, "" on error.
proc ::spm::_make_settings_file_from_template {inpType cfgName \
                                              modifierCB descr}  {
  variable WA_ROOT
#  variable ORIG_PATTERN
#  variable SUBDIR_INP;  # subdirectory for to-be-aligned images
#  variable SUBDIR_PRE;  # subdirectory for pre-aligned images
  variable SUBDIR_CFG;  # subdirectory for session-specific config files
  if { 0 == [ok_utils::ok_create_absdirs_in_list \
                    [list [file join $WA_ROOT $SUBDIR_CFG]] \
                    [list "subdirectory for session-specific config files"]] } {
    return  "";  # need to abort; error already printed
  }
  # name of settings' file is the same as action templates' name
  # load settings' template - everything but directory paths
  set templatePath [file join $::SPM_SETTINGS_TEMPLATES_DIR $cfgName]
  if { 0 == [ok_utils::ini_file_to_ini_arr $templatePath iniArr] }  {
    return  "";  # need to abort; error already printed
  }
  puts "-I- Settings template for $descr loaded from '$templatePath'"
  # 'modifierCB' procedure alters "iniArr' as needed
  if { 0 == [$modifierCB $inpType iniArr] }  {
    return  "";  # need to abort; error already printed
  }
  set cfgPath [file join $WA_ROOT $SUBDIR_CFG $cfgName]
  if { 0 == [ok_utils::ini_arr_to_ini_file iniArr $cfgPath 1] }  {
    return  "";  # need to abort; error already printed
  }
  puts "-I- Settings template for $descr written into '$cfgPath'"
  return  $cfgPath
}
