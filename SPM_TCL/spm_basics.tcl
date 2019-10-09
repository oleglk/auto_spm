# spm_basics.tcl  - basic procedures for automating StereoPhotoMaker

# Assumes option 'Startup with its window maximised'
# Assumes option 'Do not save report files'

#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # YogaBook
#  set ::SPM [file normalize {C:\Program Files\StereoPhotoMaker\stphmkre.exe}];  # Win7 desktop

package require twapi;  #  TODO: check errors

namespace eval ::spm:: {
  ### variable ORIG_PATTERN {*.tif}
  variable ORIG_PATTERN {*.jpg}
#  variable SUBDIR_INP "";  # subdirectory for to-be-aligned images - DEFAULT
  variable SUBDIR_INP "FIXED";  # subdirectory for to-be-aligned images
  variable SUBDIR_PRE "Pre";    # subdirectory for pre-aligned images
  
  variable SPM_TITLE  "StereoPhoto Maker"
  
  variable PID 0;       # pid of the singletone instance of StereoPhotoMaker
  variable HWND 0;      # window handle of StereoPhotoMaker
  variable WA_ROOT "";  # work-area root directory

  
  namespace export  \
    # (DO NOT EXPORT:)  start_singleton  \
    # (DO NOT EXPORT:)  fix_one_file
}


proc ::spm::start_singleton {{workarea_rootdir ""}}  {
  variable PID
  variable HWND
  variable WA_ROOT
  variable SPM_TITLE
  if { $workarea_rootdir != "" }  {
    if { ![file isdirectory $workarea_rootdir] }  {
      puts "-E- Invalid or inexistent directory '$workarea_rootdir'"
      return  0
    }
    set WA_ROOT [file normalize $workarea_rootdir]
    puts "-I- Workarea root directory set to '$WA_ROOT'"
  }
  set execDescr "invoking StereophotoMaker"
  if { 0 < [set PID [exec $::SPM &]] }  {
    puts "-I- Success $execDescr" } else {
    puts "-E- Failed $execDescr";  return  0
  }
  set wndDescr "locating main window of StereoPhotoMaker"
  if { 0 < [set HWND [twapi::find_windows -text "$SPM_TITLE" \
                              -toplevel 1 -visible 1 -single]]  }  {
    puts "-I- Success $wndDescr" } else {
    puts "-E- Failed $wndDescr";  return  0
  }

  return  $HWND
}

proc ::spm::quit_singleton {}  {
  variable PID;       # pid of the singletone instance of StereoPhotoMaker
  variable HWND;      # window handle of StereoPhotoMaker
  set descr "quitting StereoPhotoMaker instance"
  if { ![verify_singleton_running $descr] }  {
    return  1;  # OK; warning already printed
  }
  if { 1 == [focus_singleton "::spm::quit_singleton"] }  {
    twapi::send_keys {{MENU}fx};  # choose "exit" in "file" menu
    after 200; # avoid an access denied error.
    puts "-I- Success $descr"
    return  1
  }
  puts "-E- Failed $descr"
}


# If 'targetHwnd' given, focuses it; otherwise focuses the root SPM window
proc ::spm::focus_singleton {context {targetHwnd 0}}  {
  variable HWND;      # window handle of StereoPhotoMaker
  set descr [expr {($context != "")? $context : \
                                "giving focus to StereoPhotoMaker instance"}]
  if { ![verify_singleton_running $descr] }  {
    return  0;  # warning already printed
  }
  if { $targetHwnd == 0 }  {
    set targetHwnd $HWND;   set explicitTarget 0
  } else {                  set explicitTarget 1 }
  twapi::set_focus $targetHwnd
  after 200
  set isOK [expr { ($explicitTarget == 1)? \
                        ($targetHwnd == [twapi::get_foreground_window])   : \
                        (1 == [is_current_window_spm]) }]
  if { $isOK == 1 }  {
    puts "-I- Success $descr";    return  1
  } else {
    puts "-E- Failed $descr";     return  0
  }
}


proc ::spm::verify_singleton_running {contextDescr}  {
  variable HWND;      # window handle of StereoPhotoMaker
  if { $HWND == 0 }  {
    if { $contextDescr != "" }  {
      puts "-W- StereoPhotoMaker instance not running; context: $contextDescr"
    }
    return  0
  }
  return  1
}


proc ::spm::verify_current_window_by_title {title {loud 1}}  {
  set h  [twapi::get_foreground_window]
  set txt [twapi::get_window_text $h]
  if { $txt != $title } {
    if { $loud }  {
      puts "-I- Unexpected foreground window '$txt' instead of '$title'"
    }
    return  0
  }
  return  1
}


# Returns 1 if the current foreground window is SPM-top or its descendant
proc ::spm::is_current_window_spm {} {
  variable HWND;      # window handle of StereoPhotoMaker
  set descr [lindex [info level 0] 0]
  if { ![verify_singleton_running $descr] }  {
    return  0;  # warning already printed
  }
  set h [twapi::get_foreground_window]
  # can be child- or top window; go up until top reached
  while { ($h != "") && ($h != $HWND) }    {
    puts "-D- $descr passed window $h"
    set h [twapi::get_parent_window $h]
  }
  puts "-D- ending is_current_window_spm with handle '$h' (HWND == '$HWND')"
  return  [expr {$h == $HWND}]
}


proc ::spm::cmd__maximize_current_window {} {
  set h [twapi::get_foreground_window]
  # can be child- or top window
  set descr [lindex [info level 0] 0]
  if { 1 == [focus_singleton "focus for $descr" $h] }  {
    if { 0 != [_send_cmd_keys "{MENU}{SPACE}" $descr $h] }  {
      return  [expr { [_send_cmd_keys {x} $descr 0] }]
    }
  }
  return  0;  # error already printed
}


proc spm::cmd__return_to_top {} {
  variable HWND;      # window handle of StereoPhotoMaker
  set descr "reach SPM top";  # [lindex [info level 0] 0]
  if { 0 == [focus_singleton "focus to $descr" 0] }  {
    return  0;  # warning already printed
  }
  set nAttempts 30
  for {set i 1} {$i <= $nAttempts} {incr i 1}  {
    if { $HWND == [set h [twapi::get_foreground_window]] }   {
      puts "-I- Success to $descr after $i hit(s) of ESCAPE"
      return  1
    }
    puts "-I- Pressing ESCAPE ($i of $nAttempts) to $descr"
    twapi::send_keys {{ESCAPE}}
    after 2000;  # wait A LOT after ESCAPE
  }
  puts "-E- Failed to $descr after $nAttempts hit(s) of ESCAPE"
  return  0
}


# Returns handle of resulting window or "" on error.
proc spm::cmd__open_multi_conversion {} {
  variable HWND;      # window handle of StereoPhotoMaker
  set descr [lindex [info level 0] 0]
  #twapi::block_input
  # _send_cmd_keys {{MENU}f} $descr $HWND
  _open_menu_top_level "f" $descr;  # TODO: VERIFY SUCCESS"
  if { 0 == [_travel_meny_hierarchy {{m 2}{ENTER}} \
                                      $descr "Multi Conversion"] }  {
    #twapi::unblock_input
    return  "";  # error already printed
  }
  if { 0 == [cmd__maximize_current_window] }  {
    #twapi::unblock_input
    return  "";  # error already printed
  }
  #twapi::unblock_input
  return  [twapi::get_foreground_window]
}


###################### Begin: subtask utilities ################################

# Safely opens 1st level of the menu for key 'oneKey'
proc spm::_open_menu_top_level {oneKey descr} {
  variable HWND;      # window handle of StereoPhotoMaker
  ## TODO: ??? ENSURE CHILD-WINDOWS CLOSED BY PRESSING {ESC} UNTILL TOP ???
  ######set res [44 [format "{MENU}%s" $oneKey] $descr $HWND]
  if { 1 == [set res [focus_singleton "focus for $descr" $HWND]] }  {
    #### _send_timed_keys_list [list {MENU} [format "%s" $oneKey]] 2000
    twapi::send_keys {{MENU}}
    after 2000;  # wait A LOT after ALT
    twapi::send_keys [list $oneKey]
    after 1000
  }
  return  $res
}


# Sends menu shortcut keys to travel pre-open menu
# Returns handle of resulting window or "" on error.
proc  ::spm::_travel_meny_hierarchy {keySeqStr descr {targetWndTitle ""}}  {
  if { ("" == [set h [_send_cmd_keys $keySeqStr $descr 0]]) }  {
    return  "";  # error already printed
  }
  if { $targetWndTitle == "" }  { return  $h }; # done; no verification requested
  set h [_wait_for_window_title_to_raise "Multi Conversion"]
  puts "-D- Key sequence '$keySeqStr' lead to window '[twapi::get_window_text $h]'"
  return  $h
}


# Waits with active polling
proc ::spm::_wait_for_window_title_to_raise {titleStr}  {
  return  [_wait_for_window_title_to_raise__configurable $titleStr 500 5000]
}


# Waits with active polling - configurable
# Returns handle of resulting window or "" on error.
proc ::spm::_wait_for_window_title_to_raise__configurable { \
                                        titleStr pollPeriodMsec maxWaitMsec}  {
  if { $titleStr == "" }  {
    puts "-E- No title provided for [lindex [info level 0] 0]";   return  ""
  }
  set nAttempts [expr {int( ceil(1.0 * $maxWaitMsec / $pollPeriodMsec) )}]
  if { $nAttempts == 0 }  { set nAttempts 1 }
  ### after 2000 ;  # unfortunetly need to wait
  for {set i 1} {$i <= $nAttempts} {incr i 1}   {
    if { 1 == [verify_current_window_by_title $titleStr] }  {
      set h [twapi::get_foreground_window]
      if { ($h != "") && (1 == [twapi::window_visible $h]) }  {
        puts "-I- Window '$titleStr' did appear after [expr {$i * $pollPeriodMsec}] msec"
        return  $h
      }
    }
    after $pollPeriodMsec
  }
  puts "-E- Window '$titleStr' did not appear after [expr {$nAttempts * $pollPeriodMsec}] msec"
  return  ""
}



# Sends given keys while taking care of occurences of {MENU}.
# If 'targetHwnd' given, first focuses this window
# Returns handle of resulting window or 0 on error.
proc ::spm::_send_cmd_keys {keySeqStr descr {targetHwnd 0}} {
  set descr "sending key-sequence {$keySeqStr} for '$descr'"
  set subSeqList [_split_key_seq_at_alt $keySeqStr]
  if { ($targetHwnd == 0) || \
        (1 == [focus_singleton "focus for $descr" $targetHwnd]) }  {
    after 1000
    if { 0 == [llength $subSeqList] }   {
      twapi::send_keys $keySeqStr
     } else {
      foreach subSeq $subSeqList  {
        twapi::send_keys {{MENU}}
        after 1000;  # wait A LOT after ALT
        twapi::send_keys $subSeq
      }
     }
    after 200; # avoid an access denied error
    puts "-I- Success $descr";      return  [twapi::get_foreground_window]
  }
  puts "-E- Cannot $descr";         return  0
}


# Sends given keys while taking care of occurences of {MENU}.
# If 'targetHwnd' given, first focuses this window
# Returns handle of resulting window or 0 on error.
proc ::spm::_send_timed_keys_list {keysList descr {intervalMiliSec 0}} {
  set descr "sending keys-list {$keysList} with interval $intervalMiliSec msec for '$descr'"
  foreach k $keysList {
    twapi::send_keys [list $k]
    if { $intervalMiliSec != 0 }    {
      after $intervalMiliSec
    }
  }
  puts "-I- Done $descr"
}


# Returns list of subsequences that follow occurences of {MENU}/{ALT}
# In the case of no occurences of {MENU}/{ALT}, returns empty list
proc ::spm::_split_key_seq_at_alt {keySeqStr} {
  # the idea:  set list [split [string map [list $substring $splitchar] $string] $splitchar]
  set tmp [string map {\{MENU\} \uFFFF  \{ALT\} \uFFFF} $keySeqStr]
  if { [string equal $tmp $keySeqStr] }   {
    return  [list];   # no occurences of {MENU}/{ALT}
  }
  set tmpList [split $tmp \uFFFF];  # may have empty elements
  set subSeqList [list]
  foreach el $tmpList {
    if { $el != "" }  { lappend subSeqList $el }
  }
  return  $subSeqList
}
######################   End: subtask utilities ################################


proc ::spm::align_all {}  {
  variable ORIG_PATTERN
  variable SUBDIR_INP;  # subdirectory for to-be-aligned images
  variable SUBDIR_PRE;  # subdirectory for pre-aligned images
  
}