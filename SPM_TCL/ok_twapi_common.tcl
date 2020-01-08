# ok_twapi_common.tcl - common utilities for TWAPI based automation

#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # YogaBook
#  set ::SPM [file normalize {C:\Program Files (x86)\StereoPhotoMaker\stphmkre.exe}];  # Win7 desktop

package require twapi;  #  TODO: check errors

namespace eval ::ok_twapi:: {

  variable PID 0;       # pid of the singletone instance of StereoPhotoMaker
  variable HWND "";     # TOP-LEVEL window handle of the controlled singletone
  variable LATEST_APP_WND ""; # latest StereoPhotoMaker active window handle - top or child
  
  variable APP_NAME
  variable APP_TOPWND_TITLE
  
  variable OK_TWAPI__ABORT_ON_THIS_POPUP  "OK_TWAPI__ABORT_ON_THIS_POPUP"

  
  namespace export  \
    # (DO NOT EXPORT:)  start_singleton  \
    # (DO NOT EXPORT:)  fix_one_file
}



proc ::ok_twapi::start_singleton {exePath appName appWndTitle {workarea_rootdir ""}}  {
  variable PID
  variable HWND
  variable APP_TOPWND_TITLE
  variable APP_NAME

  set APP_NAME $appName
  set APP_TOPWND_TITLE $appWndTitle
  set execDescr "invoking $APP_NAME"
  if { 0 < [set PID [exec $exePath &]] }  {
    puts "-I- Success $execDescr" } else {
    puts "-E- Failed $execDescr";  return  0
  }
  set wndDescr "locating main window of $APP_NAME"
  if { 0 < [set HWND [twapi::find_windows -text "$APP_TOPWND_TITLE" \
                              -toplevel 1 -visible 1 -single]]  }  {
    puts "-I- Success $wndDescr"
    set_latest_app_wnd $HWND
  } else {
    puts "-E- Failed $wndDescr";  return  0
  }

  return  $HWND
}


proc ::ok_twapi::quit_singleton {cb__return_to_top}  {
  variable APP_NAME
  variable HWND;      # window handle of StereoPhotoMaker
  set descr "quitting $APP_NAME instance"
  if { ![verify_singleton_running $descr] }  {
    return  1;  # OK; warning already printed
  }
  if { 1 == [focus_singleton "::spm::quit_singleton"] }  {
    if { 1 == [$cb__return_to_top] }  {
      twapi::send_keys {{MENU}fx};  # choose "exit" in "file" menu
      after 200; # avoid an access denied error.
      puts "-I- Success $descr"
      set HWND 0;   forget_latest_app_wnd
      return  1
    }
  }
  puts "-E- Failed $descr"
  return  0
}


# If 'targetHwnd' given, focuses it; otherwise focuses the latest SPM window
proc ::ok_twapi::focus_singleton {context {targetHwnd 0}}  {
  variable APP_NAME
  variable LATEST_APP_WND;      # latest visited window handle of StereoPhotoMaker
  set descr [expr {($context != "")? $context : \
                                "giving focus to $APP_NAME instance"}]
  if { ![verify_singleton_running $descr] }  {
    return  0;  # warning already printed
  }
  if { $targetHwnd == 0 }  {
    # TODO: check validity of 'LATEST_APP_WND'
    set targetHwnd $LATEST_APP_WND;   set explicitTarget 0
  } else {                            set explicitTarget 1 }
  # TODO: make it in a cycle !!!
  twapi::set_foreground_window $targetHwnd
  after 200
  twapi::set_focus $targetHwnd
  after 200
  set currWnd [twapi::get_foreground_window]
  set isOK [expr { ($explicitTarget == 1)? \
                        ($currWnd == $targetHwnd)   : \
                        (1 == [is_current_window_related]) }]
  if { $isOK == 1 }  {
    puts "-I- Success $descr";    return  1
  } else {
    set currWndText [expr {($currWnd != "")? \
              "'[twapi::get_window_text $currWnd]' ($currWnd)" : "UNKNOWN"}]
    puts "-E- Focused window $currWndText instead of '[twapi::get_window_text $targetHwnd]' ($targetHwnd)"
    puts "-E- Failed $descr";     return  0
  }
}


proc ::ok_twapi::raise_wnd_and_send_keys {targetHwnd keySeq} {
  set descr "raising window {$targetHwnd} and sending keys {$keySeq}"
  twapi::set_foreground_window $targetHwnd
  after 200
  twapi::set_focus $targetHwnd
  after 200
  if { $targetHwnd == [twapi::get_foreground_window] }  {
    twapi::send_keys $keySeq
    puts "-I- Success $descr";  return  1
  }
  puts "-E- Failed $descr";     return  0
}


proc ::ok_twapi::get_top_app_wnd {}   {
  variable HWND;      # window handle of the controlled app
  return  $HWND
}


proc ::ok_twapi::set_latest_app_wnd_to_current {}  {
  return  [set_latest_app_wnd [twapi::get_foreground_window]]
}


proc ::ok_twapi::get_latest_app_wnd {}  {
  variable LATEST_APP_WND;      # latest visited window handle of StereoPhotoMaker
  return  $LATEST_APP_WND
}


proc ::ok_twapi::set_latest_app_wnd {hwnd}  {
  variable LATEST_APP_WND;      # latest visited window handle of StereoPhotoMaker
  set LATEST_APP_WND $hwnd
  puts "-D- Last window marker set at '[twapi::get_window_text $LATEST_APP_WND]'"
  return  $LATEST_APP_WND
}


proc ::ok_twapi::forget_latest_app_wnd {}  {
  variable LATEST_APP_WND;      # latest visited window handle of StereoPhotoMaker
  set LATEST_APP_WND ""
  puts "-D- Last window marker is reset"
}


proc ::ok_twapi::verify_singleton_running {contextDescr}  {
  variable APP_NAME
  variable HWND;      # window handle of StereoPhotoMaker
  if { ![info exists APP_NAME] || ![info exists HWND] } {
    puts "-W- App instance never ran in this terminal; context: $contextDescr"
    return  0
  }
  if { $HWND == "" }  {
    if { $contextDescr != "" }  {
      set appDescr [expr {([info exists APP_NAME])? $APP_NAME : "application"}]
      puts "-W- $appDescr instance not running; context: $contextDescr"
    }
    return  0
  }
  return  1
}


proc ::ok_twapi::verify_current_window_by_title {titleOrPattern matchType {loud 1}}  {
  set h  [twapi::get_foreground_window]
  set txt [expr {($h != "")? [twapi::get_window_text $h] : "NO-WINDOW-HANDLE"}]
  set isMatch [switch $matchType  {
    {exact}   { expr {$txt == $titleOrPattern} }
    {nocase}  { string equal -nocase $titleOrPattern $txt }
    {glob}    { string match $titleOrPattern $txt }
    {regexp}  { regexp -nocase -- $titleOrPattern $txt }
    default   { puts "-E- Unsupported matchType '$matchType'";  expr 0  }
  }]
  if { $isMatch == 0 } {
    if { $loud }  {
      puts "-I- Unexpected foreground window '$txt' - doesn't match '$titleOrPattern'"
      #ok_twapi::abort_if_key_pressed "q"
      if { 0 == [::ok_twapi::is_current_window_related] } { ; # TODO: 'loud'==0?
        puts "[_ok_callstack]"; ::ok_utils::pause; # OK_TMP
      }
    }
    return  0
  }
  return  1
}


proc ::ok_twapi::verify_current_visible_window_by_title {titleOrPattern \
                                                         matchType {loud 1}}  {
  if { 1 == [verify_current_window_by_title $titleOrPattern \
                                            $matchType $loud] }  {
    set h [twapi::get_foreground_window]
    if { ($h != "") && (1 == [twapi::window_visible $h]) }  {
      if { $loud }  {
        set titleStr [twapi::get_window_text $h]
        puts "-I- Window '$titleStr' is the current visible foreground window"
      }
      return  1
    }
  }
  return  0
}


# Returns 1 if the current foreground window is the controlled app top or its descendant
proc ::ok_twapi::is_current_window_related {} {
  variable APP_NAME
  variable HWND;      # window handle of StereoPhotoMaker
  variable LATEST_APP_WND
  set descr [lindex [info level 0] 0]
  if { ![verify_singleton_running $descr] }  {
    return  0;  # warning already printed
  }
  set h [twapi::get_foreground_window];  set txt [twapi::get_window_text $h]
  set isIt [expr {($h == $HWND) || ($h == $LATEST_APP_WND)}]  
  set doesOrNot [expr {$isIt ?  "does" : "does not"}]
  # puts "-D- Window '$txt' $doesOrNot belong to SPM application"
  puts "-D- Window '$txt' ($h) $doesOrNot belong to $APP_NAME application"
  return  $isIt
  ### Approaches that DO NOT WORK:
  ### (1) Comparing [twapi::get_window_application [twapi::get_foreground_window]]
  ###         with  [twapi::get_window_application $::spm::HWND]
  ### (2) Traversing windows upwards using [twapi::get_parent_window] until top
  ##
  #~ set isIt [expr {[twapi::get_window_application $h] == \
                                #~ [twapi::get_window_application $HWND]}]
  ##
  #~ # can be child- or top window; go up until top reached
  #~ while { ($h != "") && ($h != $HWND) }    {
    #~ puts "-D- $descr passed window $h ([twapi::get_window_text $h]) while searching for '$HWND' ([twapi::get_window_text $HWND])"
    #~ set h [twapi::get_parent_window $h]
  #~ }
  #~ puts "-D- ending is_current_window_related with handle '$h' (HWND == '$HWND')"
  #~ return  [expr {$h == $HWND}]
}


proc ::ok_twapi::cmd__maximize_current_window {} {
  set h [twapi::get_foreground_window]
  # can be child- or top window
  set descr "maximize window '[twapi::get_window_text $h]'";   # [lindex [info level 0] 0]
  if { 1 == [focus_singleton "focus for $descr" $h] }  {
    puts "-I- Commanding to $descr"
    set wasVisible [twapi::maximize_window $h -sync];  # succeeds or gets stuck
    return  1
    #~ if { 0 != [_send_cmd_keys "{MENU}{SPACE}" $descr $h] }  {
      #~ return  [expr { [_send_cmd_keys {x} $descr 0] }]
    #~ }
  }
  return  0;  # error already printed
}

# Safely opens 1st level of the menu for key 'oneKey'
proc ::ok_twapi::open_menu_top_level {oneKey descr} {
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


# Detects emerging popup windows by regexp patters in 'winTextPatternToResponseKeySeq'.
# Sends specified confirmation key to each.
# Error reported when a (listed!) popup has child window
#      with text (not title) matching any pattern in 'errPatternList'.
# Finishes after 'maxIdleTimeCbFiredSec' if 'cbWhenToStop' callback returns 1
#    or after 'maxIdleTimeCbNotFiredSec' seconds of no new pop-ups
#         if 'cbWhenToStop' not given.
proc ::ok_twapi::respond_to_popup_windows_based_on_text {                     \
        winTextPatternToResponseKeySeq errPatternList                         \
        pollPeriodSec maxIdleTimeCbNotFiredSec maxIdleTimeCbFiredSec descr    \
        {cbWhenToStop 0} {last_arg_for__cbWhenToStop ""}}                     {
  set winTextPatternToCntResponded  [dict create]
  set winTextPatternToCntErrors     [dict create]
  set startTime [clock seconds]
  set lastActionTime $startTime
  set cbFired 0
  set abortRequested 0
  #~ set maxIdleTimeSec [expr {                                                   \
                        #~ ($maxIdleTimeCbNotFiredSec > $maxIdleTimeCbFiredSec)?  \
                         #~ $maxIdleTimeCbNotFiredSec : $maxIdleTimeCbFiredSec}]
  # routinely search for windows of each listed "type"-
  #   until none appears during 'maxIdleTimeCbNotFiredSec' OR the callback allows to finish
  while { ([set elapsedSec [expr {[clock seconds] - $lastActionTime}]]  \
                            < $maxIdleTimeCbNotFiredSec)  \
                            ||    ($cbWhenToStop != 0) }   {
    set cbFired [expr {($cbWhenToStop != 0)?                                  \
                  [$cbWhenToStop [dict keys $winTextPatternToResponseKeySeq]  \
                                  $last_arg_for__cbWhenToStop]            : 0}]
    if { ($cbFired  && ($elapsedSec >= $maxIdleTimeCbFiredSec)) ||   \
         (($cbWhenToStop == 0) && ($elapsedSec >= $maxIdleTimeCbNotFiredSec))} {
      break;  # early stop; intended for cases when CB did fire
    }
    puts "-D- Continue processing popups for $descr; time passed: $elapsedSec second(s)"
    
    ## TODO:MAJOR-CHANGE:
    ##  - run cycle of searching for windows with titles matching ANY specified pattern
    ##  - among the found windows pick the 1st one for which
    ##       (a pattern with) non-empty response exists and reply to it
    ##  - whether such a window found or not, rerun the search
    ##  (discard the 2nd pass)
    #~ set winToListOfResponses [_find_windows_for_patterns \
                                              #~ $winTextPatternToResponseKeySeq]
    #~ while { 0 != [set hwnd [_choose_popup_window_to_respond \
                                              #~ $winToListOfResponses]] }   {
    #~ }

    #ok_twapi::abort_if_key_pressed "q"
    # make 2 passes over 'winTextPatternToResponseKeySeq':
    # - 1st with non-empty response key sequences - known popups
    # - 2nd with empty response key sequences     - unexpected popups
    for {set pass 1} {$pass <= 2} {incr pass 1}   {
      dict for {pattern keySeq} $winTextPatternToResponseKeySeq {
        if { ($pass == 1) && ($keySeq == "") }  { continue }
        if { ($pass == 2) && ($keySeq != "") && \
             ($keySeq != $ok_twapi::OK_TWAPI__ABORT_ON_THIS_POPUP) }  { continue }
        while { 0 != [llength [set hList [twapi::find_windows \
                                -child false -match regexp -text $pattern]]] }  {
          set hwnd [lindex $hList 0]
          set st [twapi::get_window_style $hwnd]
          puts "-D- Checking window '[twapi::get_window_text $hwnd]' (styles={$st}) for being popup (pattern: {$pattern}, response-key-seq={$keySeq})"
          #ok_twapi::abort_if_key_pressed "q"
          # first(!) check for error message in any child window
          if { $keySeq == $ok_twapi::OK_TWAPI__ABORT_ON_THIS_POPUP }  {
            puts "-E- Window '[twapi::get_window_text $hwnd]' at pass #$pass triggers abort of processing popups for $descr"
            set abortRequested 1;   break
          }
          if { "" != [set errResponseSeq [_is_error_popup \
                                                      $hwnd $errPatternList]] }  {
            set keySeq $errResponseSeq; # error alreay printed
          }
          set wText [twapi::get_window_text $hwnd]
          set wDescr "respond to {$wText} for $descr"
          #ok_utils::pause "@@@ Paused in respond_to_popup_windows_based_on_text - 01 @@@";  # OK_TMP
          if { $keySeq == "" }  { ;   # either it was a dummy for error checking,
            # TODO: if the title of the window matches a pattern with defined response, do respond
            dict for {pt ks} $winTextPatternToResponseKeySeq {
              if { $ks == "" }  { continue  }
              if { [regexp -- $pt $wText] } {
                set keySeq $ks
                puts "-D- 2nd-chance response {$ks} found for window '$wText'"
                ::ok_utils::pause; # OK_TMP
              }
            }
            if { $keySeq == "" }  { ;   # no pattern with response found
              continue ;  # or real message caught by too-generic dummy pattern
            }
          } ;    # Continuing gives it a chance to match an expected popup pattern
          if { ("" != [ok_twapi::focus_then_send_keys $keySeq $wDescr $hwnd]) && \
               ($errResponseSeq == "") }  {
            dict incr winTextPatternToCntResponded $pattern 1  ; # count successes
            set lastActionTime [clock seconds]
          } else {
            dict incr winTextPatternToCntErrors $pattern 1     ; # count errors
          }
        }
        if { $abortRequested }  { break; }
      }
      if { $abortRequested }  { break; }
    }
    if { $abortRequested }  { break; }
    after [expr {1000 * $pollPeriodSec}]
  }
  set abortReason [expr {$cbFired?  "callback has fired" : \
                          [expr {$abortRequested? \
                                    "explicit abort request" : "timeout"}]}]
  puts "-I- Stopped detecting popup-s for $descr - $abortReason"

  set cntGood 0;  set cntBad 0
  foreach n [dict values $winTextPatternToCntResponded]   { incr cntGood $n }
  foreach n [dict values $winTextPatternToCntErrors]      { incr cntBad  $n }
  set msg "Responded to $cntGood pop-up(s) for $descr; $cntBad error(s) occured"
  if { 0 == $cntBad } {
    puts "-I- $msg" }  else  { puts "-W- $msg" }
  puts "-D- winTextPatternToCntResponded = {$winTextPatternToCntResponded}"
  puts "-D- winTextPatternToCntErrors    = {$winTextPatternToCntErrors}"
  # ultimately if no relevant windows left, it's a success
  #  - some were closed by repeated attempts
  set badList [list]
  foreach pattern [dict keys $winTextPatternToResponseKeySeq] {
    set badList [concat $badList \
              [::twapi::find_windows -child false -match regexp -text $pattern]]
  }
  set cntLeft [llength $badList]
  if { $cntLeft == 0 }   {
    puts "-I- Success responding to all pop-up(s) for $descr"
  } else {
    puts "-E- Failed responding to $cntLeft pop-up(s) for $descr"
  }
  return  [expr {$cntLeft == 0}]
}


# Adapts verify_current_visible_window_by_title for callback-when-to-stop
proc ::ok_twapi::is_current_visible_window_by_title {dummyArg titleRegexp} {
  return  [verify_current_visible_window_by_title $titleRegexp "regexp" 1]
}


###################### Begin: subtask utilities ################################

# Returns dictionary of win-handle :: list-of-response-key-sequences
proc ::ok_twapi::_find_windows_for_patterns {winTextPatternToResponseKeySeq} {
  set winToListOfResponses [dict create]; # win-handle :: {keySeq1 ... keySeq3}
  dict for {pattern keySeq} $winTextPatternToResponseKeySeq {
    while { 0 != [llength [set hList [twapi::find_windows \
                            -child false -match regexp -text $pattern]]] }  {
      set hwnd [lindex $hList 0]
      if { [dict exists $winToListOfResponses $hwnd] }  { ; # append to record
        set oldList [dict get $winToListOfResponses $hwnd]
        if { -1 == [lsearch -exact $oldList $keySeq] }  {
          dict lappend winToListOfResponses $hwnd $keySeq
        }
      } else { ;                                            # add new record
        dict set winToListOfResponses $hwnd $keySeq
      }
    }
  }
  return  $winToListOfResponses
}

# Checks for error message in any child window - by patterns in 'errPatternList'.
# If error found, returns key-sequence to respond to it; otherwise returns "".
proc ::ok_twapi::_is_error_popup {hwnd errPatternList}  {
  set children [::twapi::get_descendent_windows $hwnd]
  foreach w $children {
    set txt [::twapi::get_window_text $w]
    foreach errPattern $errPatternList  {
      if { 1 == [regexp -- $errPattern $txt] }  {
        puts "-E- Error popup detected;  title: '[::twapi::get_window_text $hwnd]',  message: '$txt'"
        # TODO: search for underlying buttons to determine the response
        return  "{SPACE}";  # TODO: {SPACE} is typical response to error - OK buton
      }
    }
  }
  return  ""; # not an error popup
}


# Sends menu shortcut keys to travel pre-open menu
# Returns handle of resulting window or "" on error.
proc  ::ok_twapi::travel_meny_hierarchy {keySeqStr descr {targetWndTitle ""}}  {
  if { ("" == [set h [_send_cmd_keys $keySeqStr $descr 0]]) }  {
    return  "";  # error already printed
  }
  if { $targetWndTitle == "" }  { return  $h }; # done; no verification requested
  set h [wait_for_window_title_to_raise $targetWndTitle "exact"]
  set wndText [expr {($h != "")? [twapi::get_window_text $h] : "NONE"}]
  puts "-D- Key sequence '$keySeqStr' led to window '$wndText'"
  return  [expr {($wndText == $targetWndTitle)? $h : ""}]
}


# Waits with active polling
# Returns handle of resulting window or "" on error.
proc ::ok_twapi::wait_for_window_title_to_raise {titleStr matchType}  {
  return  [wait_for_window_title_to_raise__configurable $titleStr $matchType 500 20000]
}


# Waits with active polling - configurable
# Returns handle of resulting window or "" on error.
proc ::ok_twapi::wait_for_window_title_to_raise__configurable { \
                                        titleStr matchType pollPeriodMsec maxWaitMsec}  {
  if { $titleStr == "" }  {
    puts "-E- No title provided for [lindex [info level 0] 0]";   return  ""
  }
  set nAttempts [expr {int( ceil(1.0 * $maxWaitMsec / $pollPeriodMsec) )}]
  if { $nAttempts == 0 }  { set nAttempts 1 }
  ### after 2000 ;  # unfortunetly need to wait
  for {set i 1} {$i <= $nAttempts} {incr i 1}   {
    if { 1 == [verify_current_window_by_title $titleStr $matchType 0] }  {
      set h [twapi::get_foreground_window]
      if { ($h != "") && (1 == [twapi::window_visible $h]) }  {
        puts "-I- Window '$titleStr' did appear after [expr {$i * $pollPeriodMsec}] msec"
        return  $h
      }
    }
    puts "-D- still waiting for window '$titleStr' - attempt $i of $nAttempts"
    after $pollPeriodMsec
  }
  puts "-E- Window '$titleStr' did not appear after [expr {$nAttempts * $pollPeriodMsec}] msec"
  set h [twapi::get_foreground_window]
  set currTitle [expr {($h != "")? [twapi::get_window_text $h]  :  "NONE"}]
  puts "-E- (The foreground window is '$currTitle')"
  return  ""
}


# Sends given keys while taking care of occurences of {MENU}.
# If 'targetHwnd' given, first focuses this window
# Returns handle of resulting window or "" on error.
# TODO: The sequence of {press-Alt, release-Alt, press-Cmd-Key} is not universal
proc ::ok_twapi::_send_cmd_keys {keySeqStr descr {targetHwnd 0}} {
  set descr "sending key-sequence {$keySeqStr} for '$descr'"
  set subSeqList [_split_key_seq_at_alt $keySeqStr]
  if { ($targetHwnd == 0) || \
        (1 == [focus_singleton "focus for $descr" $targetHwnd]) }  {
    set wndBefore [expr {($targetHwnd == 0)? [twapi::get_foreground_window] : \
                                        $targetHwnd}];   # to detect focus loss
    after 1000
    if { [complain_if_focus_moved $wndBefore $descr 1] }  { return  "" }
    if { 0 == [llength $subSeqList] }   {
      twapi::send_keys $keySeqStr
     } else {
      foreach subSeq $subSeqList  {
        twapi::send_keys {{MENU}}
        after 1000;  # wait A LOT after ALT
        twapi::send_keys $subSeq
      }
     }
    after 500; # avoid an access denied error
    puts "-I- Success $descr";      return  [twapi::get_foreground_window]
  }
  puts "-E- Cannot $descr";         return  ""
}


proc ::ok_twapi::complain_if_focus_moved {wndBefore context mustExist}  {
  set wndNow [twapi::get_foreground_window]
  if { $wndBefore == $wndNow }  { return  0 } ;   # OK - didn't move
  if { !$mustExist && ![twapi::window_exists $wndBefore] }  {
    puts "-W- Focus moved from deleted window while $context"
    return  0
  }
  puts "-E- Focus moved while $context - from '[twapi::get_window_text $wndBefore]' to '[twapi::get_window_text $wndNow]'"
  return  1
}


proc ::ok_twapi::focus_then_send_keys {keySeqStr descr targetHwnd} {
  set descr "send key-sequence {$keySeqStr} for $descr"
  if { 1 == [focus_singleton "focus for $descr" $targetHwnd] }  {
    set wndBefore [expr {($targetHwnd == 0)? [twapi::get_foreground_window] : \
                                        $targetHwnd}];   # to detect focus loss
    after 1000
    if { [complain_if_focus_moved $wndBefore $descr 1] }  { return  "" }
    twapi::send_keys $keySeqStr
    after 200; # avoid an access denied error
    puts "-I- Success to $descr";     return  [twapi::get_foreground_window]
  }
  puts "-E- Cannot $descr";           return  ""
}


proc ::ok_twapi::is_window_visible {hwnd} {
  if { $hwnd == "" }  { return  0 }
  set styles [twapi::get_window_style $hwnd]
  return  [expr {0 <= [lsearch -exact $styles "visible"]}]
}


proc ::ok_twapi::send_tabs_to_reach_subwindow_in_open_dialog {wndText \
                                                               {goBack 0}}  {
  set keySeqStr [expr { ($goBack==0)? {{TAB}} : {+{TAB}} }]
  set fgWnd [twapi::get_foreground_window]
  set tid [twapi::get_window_thread $fgWnd]
  set initWnd [twapi::get_focus_window_for_thread $tid]
  set maxAttempts 200
  for {set i 0}  {$i < $maxAttempts}  {incr i 1}   {
    set currWnd [twapi::get_focus_window_for_thread $tid]
    set currText [twapi::get_window_text $currWnd]
    puts "-D- Search for '$wndText' visits window '$currText'"
    if { $currText == $wndText }  {
      puts "-D- Window '$wndText' found at tabstop $i";   return  1
    }
    if { ($i > 0) && ($currWnd == $initWnd) }   {
      puts "-E- Window '$wndText' not found after $i tabstops";   return  0
    }
    twapi::send_keys $keySeqStr
    after 200
  }
  puts "-E- Window '$wndText' not found after $maxAttempts tabstop(s)"
  return  0
}


# Goes over all fields of the current foreground (and focused) window
#   in ascending-tabstops order and fills relevant fields
# Example:
##  #(set nameToStopNum [lindex [dict filter $TABSTOPS_DFL key "Add Fuzzy Border"] 1])
##  set nameToStopNum [dict create "OK" 0  "Cancel" 1  "Border width" 10  "Fuzzy gradient" 70 "Round corners" 300] 
##  set nameToVal [dict create "Border width" 10 "Fuzzy gradient" 70 "Round corners" 300]
##  set isOK [ok_twapi::_fill_fields_in_open_dialog  $nameToStopNum  $nameToVal  "'border' dialog"]
proc ::ok_twapi::_fill_fields_in_open_dialog {tabStopsNameToNum \
                                              tabStopsNameToVal descr} {
  set nStops [expr [llength $tabStopsNameToNum] / 2]
  puts "-D- There are $nStops tabstop(s) in $descr"

  set numToName [dict create]
  dict for {name num} $tabStopsNameToNum  { dict set numToName $num $name }
  
  for {set num 0} {$num < $nStops} {incr num 1}  {
    set name [dict get $numToName $num]
    if { [dict exists $tabStopsNameToVal $name] }   {
      set val [dict get $tabStopsNameToVal $name]
      puts "-I- Typing '$val' for '$name' in stop #$num of $descr"
      twapi::send_input_text $val
    } else {
      puts "-D- Skipping '$name' in stop #$num of $descr"
    }
    after 500
    # ?WOODOO? to send one TAB, use [ twapi::send_keys {{TAB}} ]
    # ?WOODOO? to send one Alt-TAB, use [ twapi::send_keys [list %{TAB}] ]
    twapi::send_keys {{TAB}};  after 300;  # go to the next tabstop
  }
}

# Sends given keys while taking care of occurences of {MENU}.
# If 'targetHwnd' given, first focuses this window
# Returns handle of resulting window or 0 on error.
proc ::ok_twapi::_send_timed_keys_list {keysList descr {intervalMiliSec 0}} {
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
proc ::ok_twapi::_split_key_seq_at_alt {keySeqStr} {
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

proc ::ok_twapi::abort_if_key_pressed {singleKeyCharNoModofier}  {
  set hkId [twapi::register_hotkey $singleKeyCharNoModofier {
    puts "[_ok_callstack]"
    error "**ABORT**"
    }]
  after 500
  twapi::unregister_hotkey $hkId
}
