# spm_basics.tcl  - basic procedures for automating StereoPhotoMaker

# Assumes option 'Startup with its window maximised'
# Assumes option 'Do not save report files'

#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # YogaBook
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # MIIX-320
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # Win7 desktop

package require twapi;  #  TODO: check errors
#package require twapi_clipboard

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR "ok_utils" "common.tcl"]
source [file join $SCRIPT_DIR "ok_utils" "inifile.tcl"]
source [file join $SCRIPT_DIR "ok_utils" "disk_info.tcl"]
source [file join $SCRIPT_DIR "ok_twapi_common.tcl"]
source [file join $SCRIPT_DIR "spm_tabstops_def.tcl"]

set SPM_SETTINGS_TEMPLATES_DIR [file join $SCRIPT_DIR ".." "SPM_INI"]

namespace eval ::spm:: {
  variable ORIG_PATTERN {*.tif};  # Except for alignment stage it always are TIFFs
  ### variable ORIG_PATTERN {*.jpg}
#  variable SUBDIR_INP "";  # subdirectory for to-be-aligned images - DEFAULT
  variable SUBDIR_INP "FIXED";  # subdirectory for to-be-aligned images
  variable SUBDIR_PRE "Pre";    # subdirectory for pre-aligned images
  variable SUBDIR_SBS "SBS";    # subdirectory for final images
  variable SUBDIR_OUTFORMAT_ROOT "FORMATTED";    # subdirectory for formated-for-outputs images
  variable SUBDIR_CFG "CONFIG";  # subdirectory for session-specific config files
  variable SUBDIR_ALIGN "alignment";  # subdirectory with old alignment data
  
  variable SPM_TITLE  "StereoPhoto Maker" ;   # title of the main SPM window
  
  ### SPM_ERR_MSGS is a list of known error patterns in SPM popup-s
  variable SPM_ERR_MSGS   {                                                   \
      {Cannot Open Image}                                                     \
      {This file type is different. This file is skipped.}                    \
  }

  
  variable WA_ROOT "";  # work-area root directory
  
  variable PER_PHASE_FAILED_IMG_PURENAMES 0;  # dict of phase-id :: list-of-failed-images
  
  
  namespace export  \
    # (DO NOT EXPORT:)  start_singleton  \
    # (DO NOT EXPORT:)  fix_one_file
}



# Returns tabstop number (zero, positive or negative) or -999 on error
#  'TABSTOPS' == 2-level dict of wnd-title :: control-name :: tabstop
proc ::spm::_get_tabstop {wndTitle controlName}   {
  variable TABSTOPS;  # should point at the current TABSTOPS_XXX; 0 == unknown
  if { $TABSTOPS == 0 }  {
    puts "-E- TABSTOPS dictionary not chosen yet"
    return  -999
  }
  if { ! [dict exists $TABSTOPS $wndTitle $controlName] }  {
    puts "-E- Unknown UI control '$controlName' in window '$wndTitle'"
    return  -999
  }
  return  [dict get $TABSTOPS $wndTitle $controlName]
}


# Returns string of repeated TAB-s (by tabstop number) or "ERROR" on error
proc ::spm::format_tabstop  {wndTitle controlName}   {
  if { -999 == [set nTabs [_get_tabstop $wndTitle $controlName]] }  {
    return  "ERROR"
  }
  if { $nTabs == 0 }  { return "" }
  set one [expr { ($nTabs > 0)?  "{TAB}"  :  "+{TAB}" }] ;  # TAB or Shift-TAB
  set seq $one
  set abs_nTabs [expr abs($nTabs)]
  for {set i 1} {$i < $abs_nTabs} {incr i}  { append seq " " $one  }
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
    if { ($::spm::TABSTOPS_DFL == 0) && (0 == [_build_tabstops_dict]) }   {
      return  0;  # error already printed
    }
    set WA_ROOT [file normalize $workarea_rootdir]
    puts "-I- Workarea root directory set to '$WA_ROOT'"
  }
  
  # workaround...
  ::ok_twapi::add_known_related_window_title_pattern {^Open Stereo Image}
  
  return  [::ok_twapi::start_singleton $::SPM \
                "StereoPhotoMaker" $SPM_TITLE $workarea_rootdir]
  # TODO: maximize SPM window
}


proc ::spm::quit_spm {}  {
  if { ![::ok_twapi::verify_singleton_running "Quit command for SPM"] }  {
    return  0;  # warning already printed
  }
  return  [::ok_twapi::quit_singleton ::spm::cmd__return_to_top]
}


# Returns 1 if the current foreground window is SPM-top or its descendant
proc ::spm::is_current_window_spm {} {
  return  [::ok_twapi::is_current_window_related]
}


# Builds and returns full path of alignment subdirectory
proc ::spm::BuildAlignDirPath {inpType}  {
  variable WA_ROOT;  variable SUBDIR_ALIGN
  set alignDir [switch -nocase $inpType {
    SBS   {file join $WA_ROOT $SUBDIR_ALIGN}
    LR    {file join $WA_ROOT "L" $SUBDIR_ALIGN}
    default {
      puts "-E- Unknown input type '$inpType'";   set alignDir ""
    }
  }]
  return  $alignDir
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
# 'inpSubDir' is subdirectory name under work-area root or "" for root directory
# Returns handle of resulting window or "" on error.
proc ::spm::cmd__open_multi_conversion {{inpSubDir ""} {cfgPath ""}} {
  variable WA_ROOT
  puts -nonewline "-I- Commanded to open multi-convert GUI"
  if { $cfgPath == "" }  { puts ""
  } else {                 puts " and load settings from '$cfgPath'" }
  set descr [lindex [info level 0] 0]
  if { ![::ok_twapi::verify_singleton_running $descr] }  { return  ""}; # FIRST!
  #twapi::block_input
  # build and validate the ultimate input dir path ('inpSubDir' MUST BE subdir)
  set inpDirPath [file join $WA_ROOT $inpSubDir]
  if { ($inpSubDir != "") && \
       (! [ok_utils::ok_filepath_is_existent_dir $inpDirPath]) }  {
    puts "-E- Invalid or inexistent multi-convert input directory '$inpDirPath'"
    return  ""
  }
  # _send_cmd_keys {{MENU}f} $descr [::ok_twapi::get_top_app_wnd]
  if { 0 == [::ok_twapi::open_menu_top_level "f" $descr] }  {
    return  "";  # error already printed
  }
  if { "" == [::ok_twapi::travel_meny_hierarchy {{m 2}{ENTER}} \
                                      $descr "Multi Conversion"] }  {
    #twapi::unblock_input
    return  "";  # error already printed
  }
  #~ if { 0 == [::ok_twapi::cmd__maximize_current_window] }  {
    #~ #twapi::unblock_input
    #~ return  "";  # error already printed
  #~ }
  #twapi::unblock_input
  set hMC [::ok_twapi::set_latest_app_wnd_to_current]
  # change input directory
  if { $hMC == "" }  { return  "" };  # error already printed
#return  "";  # OK_TMP
  # multi-convert GUI is open in FG; focus "File Name" textbox and type input dir path
  # do it twice to force expected tabstop order ---woodoo----
  for {set di 1}  {$di <= 2}  {incr di 1}  {
    puts "-I- Change input directory - commamd #$di of 2"
    twapi::send_keys {%n};  # in a raw twapi way - since Alt should be held down
    set inpPathSeq "[file nativename $inpDirPath]"
    twapi::send_input_text $inpPathSeq
  #return  "";  # OK_TMP
    twapi::send_keys {%o}  ;  # command to change input dir; used to be {ENTER}
    if { 0 == [ok_twapi::verify_current_window_by_title   "Multi Conversion" \
                                                          "exact" 1] }  {
      return  "";  # error already printed
    }
    after 500
  }
after 5000
  # TODO: consider cleaning filename field
  puts "-I- Commanded to change input directory to '$inpPathSeq'"
  puts "-I- (Note, 'BACK' button became accessible and accounted for by tabstops"
  if { $cfgPath == "" }  {  return  $hMC }
  
  twapi::send_keys {%n};  # return focus to Filename entry - start for tabstops
#return  "";  # OK_TMP

# load align-all settings from 'cfgPath' - AFTER input dir(s) specified
  #~ set tabStop [_get_tabstop  "Multi Conversion"  "Restore(File)"];  # existent
  #~ set keySeqLoadCfg [format "{{{TAB} %d} {SPACE}}" $tabStop]
  set lDescr "Press 'Restore(File)' button"
  #~ set tabsStr [format_tabstop  "Multi Conversion"  "Restore(File)"];  # existent
  #~ if {  ("" == [ok_twapi::_send_cmd_keys $tabsStr $lDescr 0]) || \
        #~ ("" == [set hRF [ok_twapi::_send_cmd_keys {{SPACE}} $lDescr 0]]) }  {
    #~ return  "";  # error already printed
  #~ }
  if { (0 == [ok_twapi::send_tabs_to_reach_subwindow_in_open_dialog   \
                                                      "Restore(File)" 1]) ||  \
       ("" == [set hRF [ok_twapi::_send_cmd_keys {{SPACE}} $lDescr 0]])    }  {
    puts "-E- Faled to $lDescr";  return  ""
  }
  # type 'cfgPath' then hit  OK by pressing Alt-o (used to be ENTER in old SPM)
  set pDescr "Specify settings-file path"
  set nativeCfgPath [file nativename $cfgPath]
  if {  ("" == [ok_twapi::_send_cmd_keys $nativeCfgPath $pDescr 0]) }   {
     return  "";  # error already printed
  }
 #return  "";  # OK_TMP
  if { ("" == [set hMC2 [ok_twapi::_send_cmd_keys {%o} $pDescr 0]]) }  {
    return  "";  # error already printed
  }
#return  "";  # OK_TMP
  set expTitle [twapi::get_window_text $hMC]
  if { "" == [ok_twapi::wait_for_window_title_to_raise $expTitle "exact"] }  {
    puts "-E- Unexpected window '[twapi::get_window_text $hMC2]' after loading multi-conversion settings from '$cfgPath'"
    return  ""
  }
  return  $hMC2
}



# Opens multi-convert GUI, loads settings from 'cfgPath',
# starts conversion and waits for it to finish.
# 'inpSubDir' is subdirectory name under work-area root or "" for root directory
# 'winTextPatternToResponseKeySeq' tells how to respond
#          to (optional) confirmation dialogs
# Returns to the top SPM window.
# Returns 1 on success, 0 on error.
proc ::spm::cmd__multiconvert {descr inpSubDir cfgPath \
                                winTextPatternToResponseKeySeq} {
  variable SPM_ERR_MSGS;  # list of known error patterns in SPM popup-s
  set actDescr "$descr; config in '$cfgPath'"
  
  if { ![set numThreads [_predict_multiconversion_num_of_threads $inpSubDir]]} {
    return  0;  # need to abort; error already printed
  }
 
  if { "" == [set hMC1 [cmd__open_multi_conversion $inpSubDir $cfgPath]] }  {
    return  0;  # need to abort; error already printed
  }
  #~ # de-maximize to help popups be visible
  #~ twapi::restore_window $hMC1 -sync
  
  # arrange for commanding to start multi-conversion
  twapi::send_keys {%n};  # return focus to Filename entry - start for tabstops
  set sDescr "Press 'Convert All Files' button"
  set tabsStr [format_tabstop  "Multi Conversion"  "Convert All Files"]; # safe
  if {  ("" == [ok_twapi::_send_cmd_keys $tabsStr $sDescr 0]) || \
        ("" == [set h [ok_twapi::_send_cmd_keys {{SPACE}} $sDescr 0]]) }  {
    return  0;  # error already printed
  }
  puts "-I- Commanded to start $actDescr"
  # now there may appear multiple confirmation dialogs; press "y" for each one
  # - press Alt-F4 when ----- (the below is unachievable good wish) :( ---------
  #   (a) no more confirmation dialogs (with "Yes" button) left
  #   (b) dialog with "Exit" button appeared
  # ?TODO:? save val for 'maxIdleTimeSec' is 30 (sec)
  if { 0 == [ok_twapi::respond_to_popup_windows_based_on_text                 \
              $winTextPatternToResponseKeySeq $SPM_ERR_MSGS                   \
              3 10 10 $descr                                                  \
              "::spm::_is_multiconversion_most_likely_finished" $numThreads] } {
    # popup processing had errors, but maybe some were confirmed by 2nd attempt
    if { 0 == [spm::_is_multiconversion_most_likely_finished \
                    [dict keys $winTextPatternToResponseKeySeq] $numThreads] } {
      puts "[_ok_callstack]";  ::ok_utils::pause; # OK_TMP
      return  0;  # error already printed
    }
    puts "-I- Though popup processing had errors, multiconversion appears to be finished; allowed to proceed"
  }
  # at this point the job should be done
  ####return  0;  #OK_TMP
  
  # Wait for _NEW_ window(s), both "Back" and "Exit", to appear.
  # Timeout is very high to allow for long processing - 1 hour
  set timeWaitSec [expr {10 * 60}]; # TODO: [expr {60 * 60}]
  set pollPeriodSec 10
  if { 0 == [_wait_for_end_of_multiconversion   $numThreads \
                                        $timeWaitSec $pollPeriodSec $hMC1] }  {
    puts "[_ok_callstack]";  ::ok_utils::pause; # OK_TMP
    return  0;  # abort; error already printed
  }
  #### End-of multi-conversion indicator did appear
  #return  999;  #OK_TMP
  
  # Verify there exist non-original multi-conversion window(s) with "Exit" button
  # This stage seems unnecessary; the only benefit - printing button count
  #TODO: for some reason it sees two windows with "Exit" and sends {SPACE} to filename entry; not a big deal for now
  set bDescr "multi-conversion windows with 'Exit' buttons"
  set attempts 5
  while { 0 == [dict size [set wndsWithExit                                    \
          [dict filter                                                         \
              [set mcWndToButtons [_find_multiconversion_buttons $hMC1]]       \
                                    value {*Exit*}]]] }  {
    if { $attempts == 0 } {
      puts "-E- No $bDescr found after finishing multi-conversion - FATAL error"
      puts "[_ok_callstack]";  ::ok_utils::pause; # OK_TMP
      return  0
    }
    after 2000;   incr attempts -1
    puts "-I- Found [dict size $wndsWithExit] $bDescr"
  }
  #return  888;  #OK_TMP
   
  set maxNumOfExitButtons 2;  # 1 or 2; all should be ready at this point
  set maxAttempts [expr {3 * $maxNumOfExitButtons}]
  # ------- Press {SPACE} at each _NEW_ "Exit" window ------
  while { ("" != [set wndOfExit \
                  [_find_first_multiconversion_button "Exit" $hMC1]])   &&  \
          ($maxNumOfExitButtons > 0) && ($maxAttempts > 0) }   {
    puts "-D- Click at 'Exit' button ($wndOfExit); attempts left: $maxAttempts"
    if { 1 == [ok_twapi::raise_wnd_and_send_keys $wndOfExit {{SPACE}}] }  {
      incr maxNumOfExitButtons -1
    }
    incr maxAttempts -1;  after 2000
  }
  # ------- (Breaks OS; DO NOT:) Close each _NEW_ window with "Exit" button ------
  #~ while { ("" != [set wndWithExit \
                #~ [_find_first_multiconversion_button_window "Exit" $hMC1]]) && \
          #~ ($maxNumOfExitButtons > 0) }   {
    #~ puts "-D- Close window with 'Exit' button ($wndWithExit)"
    #~ twapi::close_window $wndWithExit
    #~ after 2000;   incr maxNumOfExitButtons -1
  #~ }
  
  #return  777;  #OK_TMP
    
  #~ # expect returning to top-SPM or original MC window; press {ESCAPE} key in the latter
  #~ while { 0 != [llength [set mcList [::twapi::find_windows \
                  #~ -match string -text "Multi Conversion"]]] }   {
    #~ puts "-I- After pressing all 'Back' and 'Exit' buttons found [llength $mcList] 'Multi Conversion' window(s)"
    #~ set h [lindex $mcList 0]
    #~ puts "-I- Send {ESC} to 'Multi Conversion' window ($h)"
    #~ twapi::set_focus $h;  twapi::send_keys {{ESCAPE}};  after 2000
  #~ }

  # verify the oringinal multi-conversion window is already closed
  for {set attempts 5}  {$attempts > 0}  {incr attempts -1}  {
    if { 0 == [llength [set mcList [::twapi::find_windows \
                                  -match string -text "Multi Conversion"]]] } {
      break;  # no multi-conversion windows left
    }
    after 2000
  }
  if { $attempts == 0 }   {
    puts "-E- Failed closing 'Multi Conversion' window(s); [llength $mcList] left"
    puts "[_ok_callstack]";  ::ok_utils::pause; # OK_TMP
    return  0;  # abort
  }
  puts "-I- Success closing 'Multi Conversion' window(s)"
  
  # go to the top SPM window
  if { 1 == [ok_twapi::focus_singleton "finished multi-conversion" \
                                        [ok_twapi::get_top_app_wnd]] }  {
    ok_twapi::set_latest_app_wnd_to_current;  # should be the top SPM window
  } ;   # else error is printed
  if { [ok_twapi::get_latest_app_wnd] != [ok_twapi::get_top_app_wnd] }  {
    puts "-W- Unexpected window '[twapi::get_window_text [ok_twapi::get_top_app_wnd]]' after multi-conversion is finished. Should be the top SPM window"
  }
  puts "-I- Finished $actDescr"
  return  1;  # success
}


proc ::spm::cmd__open_stereopair_image {inpType imgPath}  {
  variable SPM_ERR_MSGS;  # list of known error patterns in SPM popup-s
  set lDescr "open stereopair in '$imgPath'"
  if { ![string equal -nocase $inpType "SBS"] }  {
    puts "-E- Only SBS input type is currently supported"
    puts "-E- Failed to $lDescr";    return  0;  # error details already printed
  }
  if { ![::ok_twapi::verify_singleton_running $lDescr] }  { return  0}; # FIRST!
    if { 0 == [::ok_twapi::focus_singleton "focus to $lDescr" 0] }  {
    puts "-E- Failed to $lDescr";    return  0;  # error details already printed
  }
  set fullPath [file normalize $imgPath]
  if { ![file exists $fullPath] }  {
    puts "-E- Inexistent input image file '$imgPath' ($fullPath)";    return  0
  }
  set hSPM [ok_twapi::get_top_app_wnd];      # window handle of StereoPhotoMaker
  if { "" == [ok_twapi::_send_cmd_keys "w" $lDescr 0] }  {
    puts "-E- Failed to $lDescr";    return  0;  # error details already printed
  }
  # type 'fullPath' then hit OK by pressing Alt-o (used to be ENTER in old SPM)
  set pDescr "specify stereopair-file path"
  set nativeFullPath [file nativename $fullPath]
  if { "" == [ok_twapi::_send_cmd_keys $nativeFullPath $pDescr 0] }   {
    puts "-E- Failed to $lDescr";    return  0;  # error details already printed
  }
 #return  "";  # OK_TMP
  set hSPM2 [ok_twapi::_send_cmd_keys {%o} $pDescr 0]
  
  # react to errors if requested
  # "Open Stereo Image" is the current open dialog; wait to close before seeking popups
  set targetWndTitle [build_image_window_title_regexp_pattern sbs $fullPath]
  set winTextPatternToResponseKeySeq [dict create                              \
    [format {%s$} [file tail $fullPath]]  ""                                   \
    {Open Stereo Image}                   "OK_TWAPI__WAIT_ABORT_ON_THIS_POPUP" \
  ]
  if { 0 == [ok_twapi::respond_to_popup_windows_based_on_text  \
          $winTextPatternToResponseKeySeq $SPM_ERR_MSGS 2 10 3 $lDescr  \
          "::ok_twapi::is_current_visible_window_by_title" $targetWndTitle] } {
    puts "-E- Failed to $lDescr";    return  0;  # error details already printed
  }
  
  set hSPM2 [ok_twapi::wait_for_window_title_to_raise $targetWndTitle "regexp"]
  if { $hSPM2 == "" } {
    puts "-E- Failed to $lDescr";    return  0;  # error details already printed
  }

#return  "";  # OK_TMP
  if { $hSPM2 != $hSPM }   {
    puts "-E- Unexpected window '[twapi::get_window_text $hSPM2]' after loading stereopair from '$fullPath'"
    puts "-E- Failed to $lDescr";    return  0;  # error details already printed
  }
  puts "-I- Success to $lDescr"
  return  1
}


# Commands to save current image in 'outDirPath' as SBS TIFF
# If 'outNameNoExt' given, it overrides the filename
proc ::spm::save_current_image_as_one_tiff {dialogTitle outDirPath \
                                            {outNameNoExt ""}}   {
  variable SPM_ERR_MSGS;  # list of known error patterns in SPM popup-s
  if { ! [ok_utils::ok_filepath_is_existent_dir $outDirPath] }  {
    puts "-E- Invalid or inexistent save-to directory '$outDirPath'"
    return  ""
  }
  set sDescr "save current image"
  if { $outNameNoExt != "" }  { append sDescr " as '$outNameNoExt'" }

  if { ![::ok_twapi::verify_singleton_running $sDescr] }  { return  0}; # FIRST!
    if { 0 == [::ok_twapi::focus_singleton "focus to $sDescr" 0] }  {
    puts "-E- Failed to $sDescr";    return  0;  # error details already printed
  }
  # memorize the image window for further return
  set imgWnd      [twapi::get_foreground_window]
  set imgWndTitle [twapi::get_window_text $imgWnd]
  if { $imgWnd != [ok_twapi::get_latest_app_wnd] }  {
    puts "-W- Foreground SPM window ($imgWnd) differs from the latest ([ok_twapi::get_latest_app_wnd])"
  }
  
  if { $outNameNoExt != "" }  { ;   # window title will change with output name
    set ovrdImgWndTitleGlob [format "Image(%s.TIF - *" $outNameNoExt]
  }
  
  # open "Save Stereo Image" dialog
  if { "" == [ok_twapi::_send_cmd_keys "s" $sDescr 0] }  {
    puts "-E- Failed commanding to $sDescr";    return  0;  # error details already printed
  }
  set hS [ok_twapi::wait_for_window_title_to_raise $dialogTitle "exact"]
  if { $hS == "" } {
    puts "-E- Failed opening '$dialogTitle' dialog";  return  0
  }
  
  ### To avoid saving as <dir-name>.TIF, first set output format, then directory
  # image name should appear in the field; change output format to TIFF
  puts "-I- Changing output image format to TIFF"
  twapi::send_keys {%t};  # focus file-type entry
  after 300
  twapi::send_keys {t};  # select TIFF format - the only option starting from T
  after 300
  
  if { $outNameNoExt == "" }  {
    puts "-I- Prepending output filename with output directory path '$outDirPath'"
  } else {
    set outPath [file join $outDirPath [format "%s.TIF" $outNameNoExt]]
    puts "-I- Setting output file path to '$outPath'"
  }
  twapi::send_keys {%n};  # focus filename entry; filename should become selected
  after 300
  if { $outNameNoExt == "" }  {
    twapi::send_keys {{HOME}};  # stay at the beginning of filename string
    after 300
    set outPathSeq "[file nativename $outDirPath][file separator]"; # only dir
  } else {
    set outPathSeq "[file nativename [file normalize $outPath]]"  ; # dir & file
  }
  twapi::send_input_text $outPathSeq
  puts "-I- Commanding to apply output-path change AND perform the save"
  twapi::send_keys {{ENTER}}; # perform directory/name change and save the image
  after 300
  ## no need for Alt-S (command to save the image) - saving already done by {ENTER}

  #~ if { $hS != [set hC [twapi::get_foreground_window]] }  {
    #~ puts "-W- Focus jumped from window '[twapi::get_window_text $hS]' to '[twapi::get_window_text $hC]'; refocusing"
    #~ twapi::set_focus $hS
  #~ }
  #~ puts "-I- Commanding to perform the save...";   # after 1000
  #~ twapi::send_keys {%s};  # command to save the image
  
  # confirm save if requested
  set winTextPatternToResponseKeySeq [dict create   "Confirm Save As"  "y"]
  ok_twapi::respond_to_popup_windows_based_on_text  \
                      $winTextPatternToResponseKeySeq $SPM_ERR_MSGS 2 10 10 $sDescr
  # do not check for errors since the proc is finished
  # verify we returned to the image window
  # (title = $imgWndTitle - case can change)
  set hI [expr {($outNameNoExt == "")?  \
      [ok_twapi::wait_for_window_title_to_raise $imgWndTitle "nocase"] :      \
      [ok_twapi::wait_for_window_title_to_raise $ovrdImgWndTitleGlob "glob"] }]
  if { $hI == "" } {
    puts "-E- Failed returning to image window";  return  0; # error details printed
  }
  
  puts "-I- Success performing '$sDescr'"
  return  1
}


proc ::spm::change_input_dir_in_open_dialog {inpDirPath keySeqToConfirm}  {
  set h [twapi::get_foreground_window]
  set wTitle [expr {($h!="")? [twapi::get_window_text $h] : "NO-WINDOW-HANDLE"}]
  set descr "change input directory to '$inpDirPath' for '$wTitle'"
  set inpDirPathNorm [file normalize $inpDirPath]
  if { ![ok_utils::ok_filepath_is_existent_dir $inpDirPathNorm] } {
    puts "-E- Invalid or inexistent input directory for $wTitle - '$inpDirPath'"
    return  0
  }
  # do it twice to force expected tabstop order ---woodoo----
  for {set di 1}  {$di <= 2}  {incr di 1}  {
    puts "-I- $descr  - commamd #$di of 2"
    twapi::send_keys {%n};  # in a raw twapi way - since Alt should be held down
    set inpPathSeq "[file nativename $inpDirPathNorm]"
    twapi::send_input_text $inpPathSeq
  #return  0;  # OK_TMP
    twapi::send_keys $keySeqToConfirm ;  # command to change input dir; {%o} or {ENTER}
    # TODO: invalid path is not detected, though we checked for it
    if { 0 == [ok_twapi::verify_current_window_by_title $wTitle "exact" 1] }  {
      return  0;  # error already printed
    }
    after 500
  }
  puts "-I- Success to $descr";    return  1
}


# Splits SBS image 'inpPath' into 'nameNoExt_L', nameNoExt_R' TIFFs
# Saves in 'outDirPath' or in the same dir as the input.
# Example:  spm::split_sbs_image_into_lr_tiffs FIXED/SBS/2019_0929_133733_001.TIF  2019_0929_133733_001_L  2019_0929_133733_001_R  TMP/
proc ::spm::split_sbs_image_into_lr_tiffs {inpPath nameNoExt_L nameNoExt_R \
                                                            {outDirPath ""}}  {
 set descr "splitting SBS image '$inpPath' into L/R"
  if { ![file exists $inpPath] }  {
    puts "-E- Missing SBS image for splitting '$inpPath'";  return  0
  }
  if { $outDirPath == "" }  { set outDirPath [file dirname $inpPath] }
  if { ![ok_utils::ok_filepath_is_existent_dir [file normalize $outDirPath]] }  {
    puts "-E- Invalid or inexistent output directory for left/right images - '$outDirPath'"
    return  0
  }
  # Example:
  # exec "$::IM_DIR/convert.exe" FIXED/SBS/2019_0929_133733_001.TIF  -crop 50%x100% +repage  -compress LZW fixed/SBS/LR/TMP_FRAME%02d.TIF
  set IMCONVERT [file join $::IM_DIR "convert.exe"]
  set nameBase [file rootname [file tail $inpPath]]
  set outPath  [file join $outDirPath "$nameBase%02d.TIF"]
  set cmdList [list "$IMCONVERT" [file nativename $inpPath]  -crop 50%x100% \
                      +repage  -compress LZW   [file nativename $outPath]]
  if { 0 == [ok_utils::ok_run_silent_os_cmd $cmdList] }  {
    puts "-E- Failed $descr; command: {$cmdList}";    return  0
  }
  set tmpNameNoExt_L [format "%s00" $nameBase]
  set tmpNameNoExt_R [format "%s01" $nameBase]
  if { $tmpNameNoExt_L != $nameNoExt_L }  {
    set tmp [file join $outDirPath "$tmpNameNoExt_L.TIF"]
    set ult [file join $outDirPath "$nameNoExt_L.TIF"]
    file rename -force -- $tmp $ult;  puts "-I- Renamed '$tmp' into '$ult'"
  }
  if { $tmpNameNoExt_R != $nameNoExt_R }  {
    set tmp [file join $outDirPath "$tmpNameNoExt_R.TIF"]
    set ult [file join $outDirPath "$nameNoExt_R.TIF"]
    file rename -force -- $tmp $ult;  puts "-I- Renamed '$tmp' into '$ult'"
  }
  puts "-I- Success $descr; output in ('$nameNoExt_L.TIF', '$nameNoExt_R.TIF'), directory '$outDirPath'"
  return  1
}


# 
proc ::spm::build_image_window_title_regexp_pattern {inpType imgPath}  {
  if { ![string equal -nocase $inpType "SBS"] }  {
    puts "-E- Only SBS input type is currently supported"
    return  "ERROR: unsupported"
  }
  set imgName [file tail $imgPath]
  set targetWndTitlePattern [format {^Left Image[(]%s - .*Right Image[(]%s - } \
                                    $imgName $imgName]
  return  $targetWndTitlePattern
}


#################### Begin: error monitoring ###################################

# Detects output images that are either invalid or older than their inputs;
#   and returns as a list of purenames (no extension).
# In case of fatal error returns "ERROR".
### Example:
###   set inpStats [ok_utils::ok_read_all_files_stat_in_dir $spm::WA_ROOT "*.TIF" 1];
###   set badListOrErr [spm::verify_output_images_vs_inputs SBS $inpStats "$spm::WA_ROOT/Pre" ".TIF"]
proc ::spm::verify_output_images_vs_inputs {inpType inpFileStatsDict \
                                             outDirPath outExt}   {
  if { ![string equal -nocase $inpType "SBS"] }  {
    puts "-E- Only SBS input type is currently supported"
    return  "ERROR"
  }
  set descr "verifying output images vs inputs"
  if { 0 == [dict size $inpFileStatsDict] }  {
    puts "-E- Missing input-images' attributes for $descr"
    return  "ERROR"
  }
  set outFileStatsDict [ok_utils::ok_read_all_files_stat_in_dir $outDirPath \
                                                                "*$outExt" 1]
  if { 0 == [dict size $outFileStatsDict] }  {
    puts "-E- Failed reading output-images' attributes for $descr;  directory='$outDirPath', pattern='*$outExt'"
    return  "ERROR"
  }
  set badList [list]
  foreach imgPureName [dict keys $inpFileStatsDict] {
    set inpStats [dict get $inpFileStatsDict $imgPureName]
    set outName "$imgPureName$outExt"
    set outDescr "'$outName' ([file join $outDirPath $outName])"
    if { ![dict exists $outFileStatsDict $imgPureName] }  {
      puts "-E- Missing output image $outDescr for $descr"
      lappend badList $imgPureName;  continue
    }
    set outStats [dict get $outFileStatsDict $imgPureName]
    if { [dict get $outStats size] < 2e+05 }  {
      puts "-E- Output image $outDescr is too small"
      lappend badList $imgPureName;  continue
    }
    set inpTime [dict get $inpStats mtime]
    set outTime [dict get $outStats mtime] 
    if { $inpTime >= $outTime }  {
      puts "-E- Output image $outDescr is older than the original ($outTime vs $inpTime)"
      lappend badList $imgPureName;  continue
    } 
  }
  set allGood [expr {0 == [llength $badList]}]
  set msg "Finished $descr for [dict size $inpFileStatsDict] input image(s); [llength $badList] error(s) occured."
  if { $allGood }  { puts "-I- $msg" }  else  { puts "-E- $msg" }
  return  $badList
}


proc ::spm::init_phase_results {} {
  variable PER_PHASE_FAILED_IMG_PURENAMES;  # dict of phase-id :: list-of-failed-images
  set PER_PHASE_FAILED_IMG_PURENAMES [dict create]
}


proc ::spm::are_phase_results_initialized {} {
  variable PER_PHASE_FAILED_IMG_PURENAMES;  # dict of phase-id :: list-of-failed-images
  return  [expr { [info exists PER_PHASE_FAILED_IMG_PURENAMES] &&   \
                  ($PER_PHASE_FAILED_IMG_PURENAMES != 0) }]
}


proc ::spm::register_phase_results {phaseId badPurenamesList} {
  variable PER_PHASE_FAILED_IMG_PURENAMES;  # dict of phase-id :: list-of-failed-images
  if { $PER_PHASE_FAILED_IMG_PURENAMES == 0 }   {
    puts "-E- spm::PER_PHASE_FAILED_IMG_PURENAMES uninitialized upon set-call for phase '$phaseId'"
    return  0
  }
  dict set PER_PHASE_FAILED_IMG_PURENAMES $phaseId $badPurenamesList
  return  1
}


proc ::spm::register_phase_as_invalid {phaseId} {
  variable PER_PHASE_FAILED_IMG_PURENAMES;  # dict of phase-id :: list-of-failed-images
  if { $PER_PHASE_FAILED_IMG_PURENAMES == 0 }   {
    puts "-E- spm::PER_PHASE_FAILED_IMG_PURENAMES uninitialized upon set-call for phase '$phaseId'"
    return  0
  }
  dict set PER_PHASE_FAILED_IMG_PURENAMES $phaseId [list "***WHOLE-PHASE-INVALID***"]
  return  1
}


proc ::spm::get_phase_errors {phaseId} {
  variable PER_PHASE_FAILED_IMG_PURENAMES;  # dict of phase-id :: list-of-failed-images
  if { $PER_PHASE_FAILED_IMG_PURENAMES == 0 }   {
    puts "-E- spm::PER_PHASE_FAILED_IMG_PURENAMES uninitialized upon get-call for phase '$phaseId'"
    return  "ERROR"
  }
  if { ![dict exists $PER_PHASE_FAILED_IMG_PURENAMES $phaseId] }   {
    puts "-E- Missing error data for phase '$phaseId'; this phase may not have been run"
    return  "ERROR"
  }
  set badPurenamesList [dict get $PER_PHASE_FAILED_IMG_PURENAMES $phaseId]
  if { $badPurenamesList == [list "***WHOLE-PHASE-INVALID***"] }  {
    puts "-E- Total failure of phase '$phaseId'; this phase may have lacked inputs"
    return  "ERROR"
  }
  return  $badPurenamesList
}


proc ::spm::get_phase_list {} {
  variable PER_PHASE_FAILED_IMG_PURENAMES;  # dict of phase-id :: list-of-failed-images
  if { $PER_PHASE_FAILED_IMG_PURENAMES == 0 }   {
    puts "-E- spm::PER_PHASE_FAILED_IMG_PURENAMES uninitialized upon list-call for phases"
    return  "ERROR"
  }
  return  [dict keys $PER_PHASE_FAILED_IMG_PURENAMES]
}

#################### End:   error monitoring ###################################


# Builds INI file with settings from existent "standard" template 'cfgName'.
# Changes from the template performed by 'modifierCB' callback procedure:
#         proc modifierCB {inpType iniArrName}  {}
# Returns new CFG file path on success, "" on error.
proc ::spm::_make_settings_file_from_template {inpType cfgName \
                      modifierCB descr {optionalParamForCB ""}}  {
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
  set ret [expr { ($optionalParamForCB == "")?                                \
                            [$modifierCB $inpType iniArr]   :                 \
                            [$modifierCB $inpType iniArr $optionalParamForCB] }]
  if { $ret == 0 }  { return  ""  };  # need to abort; error already printed

  set cfgPath [file join $WA_ROOT $SUBDIR_CFG $cfgName]
  if { 0 == [ok_utils::ini_arr_to_ini_file iniArr $cfgPath 1] }  {
    return  "";  # need to abort; error already printed
  }
  puts "-I- Ultimate settings file for $descr written into '$cfgPath'"
  return  $cfgPath
}


# Waits for _NEW_ window(s), both "Back" and "Exit", to appear.
# Note, timeout should be very high to allow for long processing >= 1 hour
proc ::spm::_wait_for_end_of_multiconversion {numThreads \
                                    timeWaitSec pollPeriodSec {origMCWnd ""}}  {
  set timeToEndSec [expr {[clock seconds] + $timeWaitSec}]

  set waitForStartDescr "waiting $timeWaitSec (sec) for ANY multi-conversion-progress window to appear"
  set mcWndToButtons [dict create];   set cntStartedMC 0
  puts "-I- Begin $waitForStartDescr. Time=[clock seconds](sec)"
  while { [expr { ([clock seconds] < $timeToEndSec) && ($cntStartedMC == 0) }] }  {
    after 1000
    set mcWndToButtons [_find_multiconversion_buttons $origMCWnd]
    set cntStartedMC [dict size $mcWndToButtons]
    #ok_twapi::abort_if_key_pressed "q"
  }
  if { $cntStartedMC == 0 } {
    puts "-I- Failed $waitForStartDescr - timeout. Time=[clock seconds](sec)"
    return  0;  # failure
  }
  puts "-I- End   $waitForStartDescr. Time=[clock seconds](sec)"
  
  set waitForStopDescr "waiting for ALL 'Stop' buttons in multi-conversion-progress windows to disappear"
  set cntStop 77; # dummy init
  puts "-I- Begin $waitForStopDescr. Time=[clock seconds](sec)"
  while { [expr { ([clock seconds] < $timeToEndSec) && ($cntStop > 0) }] }  {
    # sometimes it catches no windows; make several attempts
    for {set attempts 3} {$attempts > 0} {incr attempts -1}   {
      set mcWndToButtons [_find_multiconversion_buttons $origMCWnd]
      if { [dict size $mcWndToButtons] > 0 }  { break } ; # found some window(s)
      after 2000
    }
    puts "-D- Wait for 'Stop' ABSENT in {$mcWndToButtons}"
    if { 0 == [dict size $mcWndToButtons] } {
      puts "-D- No more multi-conversion-progress windows found while $waitForStopDescr"
      set cntStop 0;  break;  # happens when converting in single thread
    }
    set cntStop [dict size [dict filter $mcWndToButtons value {*Stop*}]]
  }
  if { $cntStop > 0 } {
    puts "-I- Failed $waitForStopDescr - timeout. Time=[clock seconds](sec)"
    return  0;  # failure
  }
  puts "-I- End   $waitForStopDescr. Time=[clock seconds](sec)"

  set waitForExitDescr "waiting for $numThreads multi-conversion-progress window(s) to expose 'Exit' button(s)"
  set wndsWithExit [dict create];   # for MC windows with 'Exit' button
  set cntWnds 77;                   # count of all MC windows
  set cntWndsWithExit 0;            # count of MC windows with 'Exit' button
  puts "-I- Begin $waitForExitDescr. Time=[clock seconds](sec)"
  while { [expr { ([clock seconds] < $timeToEndSec) && \
                  ($cntWndsWithExit < $numThreads) }] }  {
    set mcWndToButtons [_find_multiconversion_buttons $origMCWnd]
    puts "-D- Wait for 'Exit' PRESENT in {$mcWndToButtons}"
    if { 0 == [dict size $mcWndToButtons] } {
      puts "-E- No multi-conversion-progress windows found while $waitForExitDescr - FATAL error"
      return  0
    }
    set cntWnds [dict size $mcWndToButtons]
    set wndsWithExit [dict filter $mcWndToButtons value {*Exit*}]
    set cntWndsWithExit [dict size $wndsWithExit]
    puts "-D- Found $cntWndsWithExit window(s) while $waitForExitDescr"
  }
  if { $cntWndsWithExit < $numThreads } {
    puts "-E- Failed $waitForExitDescr - timeout. Time=[clock seconds](sec)"
    return  0;  # failure
  }
  puts "-I- End   $waitForExitDescr. Time=[clock seconds](sec)"
  
  puts "-I- Multi-conversion is ended."
  return  1;    # success
}


# Looks for _VISIBLE_ window(s), with text "Stop", "Back" and "Exit"
# that are descendants of any "Multi Conversion" window".
# Returns dict of {mc-window-handle : name (Stop|Back|Exit) : button-wnd-handle}
# If 'origMCWnd' given, MC window with this handle is ignored as original
proc ::spm::_find_multiconversion_buttons {{origMCWnd ""}}  {
  set mcWndToButtonWnds [dict create]
  foreach mcWnd [concat \
              [::twapi::find_windows -match string -text "Multi Conversion"] \
              [::twapi::find_windows -match regexp -text "^Now reading\.\..*"]  \
              [::twapi::find_windows -match regexp -text "^Now writing\.\..*"]  \
                ]    {
    if { $mcWnd == $origMCWnd }   { continue };   # skip the original MC-window
    foreach btn [set btns [twapi::get_descendent_windows $mcWnd]] {
      set tclExecResult [catch { ;  # catch exceptions to skip invalid handles
        set title [twapi::get_window_text $btn]
        #puts "-D- Check MC descendent '$title' ($btn)"
        foreach btnName {"Stop" "Back" "Exit"}  {
          if { ($title == $btnName) && [ok_twapi::is_window_visible $btn] }   {
            dict set mcWndToButtonWnds $mcWnd $title $btn
          }
        }
      }  evalExecResult]
      if { $tclExecResult != 0 } {
        puts "-D- Ignoring invalid button-window handle ($btn)";  continue
      }
    }
  }
  return  $mcWndToButtonWnds
}


proc ::spm::_find_first_multiconversion_button_window {btnTitle \
                                                        {origMCWnd ""}}  {
  set mcWndToButtonWnds [_find_multiconversion_buttons $origMCWnd]
  set pattern [format {*%s*} $btnTitle]
  set wndsWithBtn [dict filter $mcWndToButtonWnds value $pattern]
  set cntWndsWithBtn [dict size $wndsWithBtn]
  if { $cntWndsWithBtn == 0 }   { return  "" }
  set wndHandle [lindex [dict keys $wndsWithBtn] 0]
  puts "-D- Picked first MC window with button {$wndHandle [dict get $wndsWithBtn $wndHandle]} out of $cntWndsWithBtn"
  return  $wndHandle
}


proc ::spm::_find_first_multiconversion_button {btnTitle {origMCWnd ""}}  {
  set mcWndToButtonWnds [_find_multiconversion_buttons $origMCWnd]
  set pattern [format {*%s*} $btnTitle]
  set wndsWithBtn [dict filter $mcWndToButtonWnds value $pattern]
  set cntWndsWithBtn [dict size $wndsWithBtn]
  if { $cntWndsWithBtn == 0 }   { return  "" }
  set titleAndHandle [lindex [dict values $wndsWithBtn] 0]
  puts "-D- Picked first button {$titleAndHandle} out of $cntWndsWithBtn"
  set handle [lindex $titleAndHandle 1]
  return  $handle
}


proc ::spm::_is_multiconversion_most_likely_finished {knownPopupTitles \
                                            {origMCWnd ""} {numThreads -1}}  {
  set firstIter 1
  set maxVerifyAttempts 3;  # TODO:? ? safe is 15 ?
  for  {set attempts $maxVerifyAttempts}  {$attempts > 0}  {incr attempts -1}  {
    if { ! $firstIter }   { after 2000;   set firstIter 0 }
    # some of the known titles may pop up before start of multi-conversion
    foreach title $knownPopupTitles  {
      if { 0 != [llength [set stList [::twapi::find_windows \
                                -child false -match regexp -text $title]]] }   {
        puts "-D- Multi-conversion not finished - popup detected; re-verification attempts not used: $attempts"
        return  0;  # multi-conversion may not yet have started
      }
    }
    if { "" != [_find_first_multiconversion_button "Stop" $origMCWnd] }   {
      puts "-D- Multi-conversion not finished - MC window with visible 'Stop' detected; re-verification attempts not used: $attempts"
      return  0;  # MC window with visible "Stop" button; not finished for sure
    }
    set numWndsWihExitAtEnd [expr {($numThreads > 0)? $numThreads : 1}]
    set backOk [expr {"" != \
                   [_find_first_multiconversion_button "Back" $origMCWnd]}]
    set exitOk [expr {$numWndsWihExitAtEnd <= [dict size                      \
                  [dict filter                                                \
                   [_find_multiconversion_buttons $origMCWnd] value {*Exit*}]]}]
    if { $backOk && $exitOk  }   {
      puts "-D- Multi-conversion appears finished - 'Back' and 'Exit' buttons detected; re-verification attempts left: $attempts"
    } else {
      puts "-E- Unexpected case of multi-conversion: 'Stop', 'Back' and 'Exit' buttons missing; no popups - multi-conversion may not have started; re-verification attempts left: $attempts"
    }
  }
  set done [expr {($backOk && $exitOk)? 1 : 0}]
  puts "-D- Multi-conversion finish IS [expr {$done? {   } : {NOT}}] detected"
  return  $done
}


# Returns expected number of threads in multiconversion - depends on num of inputs
# The result is 1 or 2, or 0 on error. TODO: read config.
proc ::spm::_predict_multiconversion_num_of_threads {inpSubDir}  {
  variable WA_ROOT
  set inpDirPath [file join $WA_ROOT $inpSubDir]
  if { ($inpSubDir != "") && \
       (! [ok_utils::ok_filepath_is_existent_dir $inpDirPath]) }  {
    puts "-E- Invalid or inexistent multi-convert input directory '$inpDirPath'"
    return  0
  }
  set cnt 0
  foreach inpPattern { "*.jpg"  "*.tif" }  {
    set lst [glob -nocomplain -directory $inpDirPath $inpPattern]
    incr cnt [llength $lst]
  }
  set numThreads [expr {($cnt <= 3)? 1 : 2}]
  puts "-I- SPM multiconversion in '$inpDirPath' should use '$numThreads' thread(s)"
  return  $numThreads
}
