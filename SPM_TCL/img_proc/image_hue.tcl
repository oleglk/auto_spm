# image_hue.tcl - hue channel analysis and manipulation

# Copyright (C) 2023 by Oleg Kosyakovsky
global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide img_proc 0.1
}


# DO NOT for utils:  set SCRIPT_DIR [file dirname [info script]]
set IMGPROC_DIR [file dirname [info script]]
set UTIL_DIR    [file join $IMGPROC_DIR ".." "ok_utils"]
source [file join $UTIL_DIR     "debug_utils.tcl"]
source [file join $UTIL_DIR     "common.tcl"]
source [file join $IMGPROC_DIR  "image_metadata.tcl"]
source [file join $IMGPROC_DIR  "image_pixeldata.tcl"]

ok_utils::ok_trace_msg "---- Sourcing '[info script]' in '$IMGPROC_DIR' ----"


# DO NOT in 'auto_spm': package require ok_utils; 
namespace import -force ::ok_utils::*
############# Done loading code ################################################


namespace eval ::img_proc:: {
    namespace export                          \
}




# Returns ordered list of {gapBegin gapEnd gapCnt} - ascending by gapCnt.
# 'gapWidth' should be divisible by histogram unit (== 1/10^'precision')
### The histogram is a dictionary of <CHANNEL-VALUE> :: <VALUE-OCCURENCE-COUNT>
### The values in histogram should be normalized to 0..1  (1 means all pixels)
## Example:  set orderedGapsList [img_proc::find_max_gaps_in_channel_histogram [img_proc::_complete_hue_histogram $hist $::FP_DIGITS] 1 0.5 0.001 {0 2.0}]
## Nice-print the result:   foreach g $gaps {lassign $g beg end cnt;  puts "\[$beg ... $end\] => $cnt"}
#### TODO: prepend 'width'/unit values with negative keys to histogram begin !!!
proc ::img_proc::find_max_gaps_in_channel_histogram {histogramDict precision \
                                        gapWidth thresholdNorm searchBounds}  {
  if { ![img_proc::_is_multiple_of_histogram_unit_width $gapWidth $precision]} {
    error "-E- Gap width of $gapWidth is incompatible with histogram precision $precision"
  }
  if { 2 != [llength $searchBounds] } {
      error "-E- Invalid structure of search bounds '$searchBounds'; should be {min max}"
  }
  lassign $searchBounds minV maxV

  # find the search-start and search-end indices
  set keysSubList [img_proc::_find_value_range_in_channel_histogram   \
                                                  $histogramDict $searchBounds]
  if { 0 == [set numKeys [llength $keysSubList]] }  {
    # no valuies in requested histogram range; message already printed
    return  [list];  # no gaps
  }
  #~ set unitSubrange [expr {  \
                #~ ([lindex $keysSubList end] - [lindex $keysSubList 0] + 1) \
                                                  #~ / [llength $keysSubList]}]
  ok_trace_msg "Search restricted to \[[lindex $keysSubList 0]...[lindex $keysSubList end]\]: {$keysSubList}"
  
  set gapNumUnits [img_proc::_calc_num_histogram_units_for_width \
                                                    $gapWidth $precision]
  ok_trace_msg "Assume $gapNumUnits histogram unit(s) in a gap of $gapWidth"
  
  if { $numKeys < $gapNumUnits }  {
    ok_warn_msg "Not enough values in the histogram - $numKeys for requested $gapNumUnits"
    return  [list]
  }
  
  set iLastOfAdvancedRange -1;  # indicates need to search for a whole new range
  for {set iFirstAfterPrevRange 0} \
      {$iFirstAfterPrevRange < [llength $keysSubList]}  {}  {
    if { $iLastOfAdvancedRange == -1 }  { ;   # no range to advance from
      # Find the next full suitable range; TODO: generalize for 3 colors
      set foundRange [list]
      set iLastOfFoundRange [img_proc::_collect_one_hue_range  \
                            $histogramDict $keysSubList \
                            $thresholdNorm $iFirstAfterPrevRange $gapNumUnits \
                            img_proc::_get_hue_unit_subrange_val__oneColor  \
                            img_proc::_push_hue_range \
                            foundRange]
      if { $iLastOfFoundRange == -1  }  {
        ok_trace_msg "No gaps of $gapWidth found in the histogram within {$searchBounds} after [lindex $keysSubList $iFirstAfterPrevRange]"
        return  [img_proc::_get_chosen_hue_ranges];  # whatever found earlier
      }
      #~ set prevRange [lindex [img_proc::_get_chosen_hue_ranges] 0]
      #~ lassign $fprevRange beginVal endVal cnt
      if { $iLastOfFoundRange >= [expr {[llength $keysSubList] - 1}] }   {
        ok_trace_msg "Last possible suitable subrange found - end reached"
        return  [img_proc::_get_chosen_hue_ranges];  # all the found ranges
      }
      set iFirstOfPrevRange    [expr $iLastOfFoundRange - $gapNumUnits + 1]
      set iLastOfPrevRange     $iLastOfFoundRange
      set iFirstAfterPrevRange [expr $iLastOfFoundRange + 1]
    }

    # Try to advance the range one unit; jump at unit with val > threshold
    set advRange [list]
    set iLastOfAdvancedRange [img_proc::_advance_hue_range_one_unit \
                $histogramDict $keysSubList    \
                $iFirstOfPrevRange $iLastOfPrevRange $foundRange \
                $thresholdNorm \
                img_proc::_get_hue_unit_subrange_val__oneColor \
                img_proc::_push_hue_range \
                advRange]
    if { $iLastOfAdvancedRange != -1 }  { ;  # will try further advance
      set iFirstAfterPrevRange [expr $iLastOfAdvancedRange + 1]
      TODO: derive/provide iFirstOfPrevRange, iLastOfPrevRange; not in advRange!
    }
    ok_trace_msg "Next iteration to start from #$iFirstAfterPrevRange out of $numKeys; try-advance=[expr ($iLastOfAdvancedRange==-1)? No:Yes]"
    # end-of-'keysSubList' will be checked by the main loop
if {"Q" == [gets stdin]}  {error "User interrupt"}; # OK_TMP
  }

  return  [img_proc::_get_chosen_hue_ranges];  # OK_TMP; list of one
}


################################################################################

# Returns a new histogram with 2 additions:
## - all missing subranges inserted with zero counts
## - ?? TODO: duplicate for negative range ??
proc ::img_proc::_complete_hue_histogram {histogramDict precision}  {
  set step [img_proc::_precision_to_histogram_unit_width $precision]
  # exception occurred on invalid 'precision'
  set totalCopied 0;  set totalCompleted 0
  set precSpec [format {%%.%df} $precision]
  set keys [lsort -real [dict keys $histogramDict]];  # keys are channel values
  set fullHist [dict create]
  set oneMissing [format $precSpec 0.0]
  ### (debug)  set keys [lrange  $keys 0 10];  #puts "@@ $keys @@";  #### OK_TMP
  foreach k $keys {
    set k [format $precSpec $k];  # just in case
    # complete subranges 'h' ... 'k'
    set wasFirst $oneMissing
    set nCompleted 0
    while { $oneMissing < $k }  {
      #puts "@TMP@ '$oneMissing' < '$k'"
      dict set fullHist $oneMissing 0
      ##set oneMissing [expr $h + $step]
      set oneMissing [format $precSpec [expr $oneMissing + $step]]
      incr nCompleted 1
    }
    if { $nCompleted > 0 }  {
      puts "-D- Completed $nCompleted subrange(s) '$wasFirst'...'[expr $k-$step]' (step = $step)"
      incr totalCompleted $nCompleted
    }
    dict set fullHist $k [dict get $histogramDict $k]
    set oneMissing [format $precSpec [expr $k + $step]]
    puts "-D- Copied value for subrange $k (=[dict get $fullHist $k])"
    incr totalCopied 1
  }
  set lastKey [lindex $keys end]
  set lastHueRangeStart [format $precSpec [expr 360.0 - $step]]
  if { $lastKey < $lastHueRangeStart }  {
    ##set h [expr $lastKey + $step]
    set h [format $precSpec [expr $lastKey + $step]]
    # complete subranges 'last-key' ... 'lastHueRangeStart'
    while { $h < 360 }  {
      dict set fullHist $h 0
      set lastDone $h
      set h [format $precSpec [expr $h + $step]]
      incr totalCompleted 1
    }
    puts "-D- Completed subrange(s) '[expr $lastKey + $step]'...'$lastDone' (step = $step)"
    puts "-D- Nominal last subrange = '$lastHueRangeStart' ... 360"
  }
  puts "-I- Copied $totalCopied and completed $totalCompleted subrange(s) ([expr $totalCopied + $totalCompleted] out of [expr int(360 / $step)])"
  return  $fullHist
}


# Returns the value if below threshold; otherwise returns -1
proc img_proc::_get_hue_unit_subrange_val__oneColor {histogramDict unitKey  \
                                                      oneColorThresholdNorm}   {
  set uV [dict get $histogramDict $unitKey]
  return  [expr {($uV < $oneColorThresholdNorm)? $uV : -1}]
}


########################################################
# A structure to store so-far minimal value range(s)
set ::_MIN_CNT_RANGE_1 [dict create "FIRST" -1  "LAST" -1  "CNT" 1.1]
proc img_proc::_push_hue_range {firstKey lastKey val}  {
  set oldVal [dict get $::_MIN_CNT_RANGE_1  "CNT" ]
  if { $val < $oldVal }   {
    set ::_MIN_CNT_RANGE_1 [dict create \
                      "FIRST" $firstKey  "LAST" $lastKey  "CNT" $val]
    ok_trace_msg "Range \[$firstKey...$lastKey\] registered as minimal (count=$val)"
    return  1
  }
  return  0;  # the range is ignored
}


# Returns ascending list of min hue ranges
proc img_proc::_get_chosen_hue_ranges {}  {
  return [list \
            [list [dict get $::_MIN_CNT_RANGE_1 "FIRST"]  \
                  [dict get $::_MIN_CNT_RANGE_1 "LAST"]   \
                  [dict get $::_MIN_CNT_RANGE_1 "CNT"]    ]]
}
########################################################


# Searches the histogram for a consequent range of 'rangeNumUnits'
#   SUITABLE units from the beginning of 'keysList' (ordered sublist of keys)
# Returns the last index of the found range in 'keysList' or -1 if none found.
### The histogram is a dictionary of <CHANNEL-VALUE> :: <VALUE-OCCURENCE-COUNT>
### The values in histogram should be normalized to 0..1  (1 means all pixels)
# TODO: generalize to parallel eval of N ranges
proc ::img_proc::_collect_one_hue_range {histogramDict keysList thresholdNorm \
                  firstKeyIdx rangeNumUnits \
                  getHueUnitSubrangeVal_CB pushHueRange_CB foundRangeOrEmpty} {
  upvar $foundRangeOrEmpty foundRange
  set numKeys [llength $keysList]
  if { $numKeys < $rangeNumUnits }  {
    ok_warn_msg "Not enough values in the histogram range - $numKeys for requested $rangeNumUnits"
    return  -1
  }
  set nextKeyIdx $firstKeyIdx
  set total 0.0
  set cntUnitsInCurrentRange 0
  while { ($cntUnitsInCurrentRange < $rangeNumUnits) && \
          ($nextKeyIdx < ($numKeys - $rangeNumUnits)) }  {
    # try to collect range ['nextKeyIdx' ... 'nextKeyIdx'+'rangeNumUnits'-1]
    set lastKeyIdx [expr $nextKeyIdx + $rangeNumUnits - 1]
    ok_trace_msg "Try to collect range \[$nextKeyIdx...$lastKeyIdx\] ..."
    for  {set i $nextKeyIdx}  {$i <= $lastKeyIdx}  {incr i 1}   {
      set nextKeyIdx [expr $i + 1];   # anyway
      set uK [lindex $keysList $i]
      set uV [$getHueUnitSubrangeVal_CB $histogramDict $uK $thresholdNorm]
      if { $uV == -1 }  { # no gap can include key_#i; restart from 'nextKeyIdx'
        ok_trace_msg "Range \[[expr $nextKeyIdx-1]...$lastKeyIdx\] aborted at #$i (key=$uK)"
        set total 0.0
        set cntUnitsInCurrentRange 0
        break
      }
      incr cntUnitsInCurrentRange 1
      set total [expr $total + $uV]
    }
  }
  if { $cntUnitsInCurrentRange == $rangeNumUnits }  {
    set firstIdxInRange [expr $lastKeyIdx - $rangeNumUnits + 1]
    set key1 [lindex $keysList $firstIdxInRange]
    set key2 [lindex $keysList $lastKeyIdx]
    ok_info_msg "Range \[$key1...$key2\] accepted; range-total=$total"
    $pushHueRange_CB $key1 $key2 $total
    set foundRange [list $key1 $key2 $total]
    return  $lastKeyIdx
  }
  ok_info_msg "No range accepted after index $firstKeyIdx (channel-value [lindex $keysList $firstKeyIdx]"
  return  -1
}


# Advances the given consequent range over the histogram
#   to the next suitable range of the same size
# Returns the last index of the found range in 'keysList' or -1 if none found.
### The histogram is a dictionary of <CHANNEL-VALUE> :: <VALUE-OCCURENCE-COUNT>
### The values in histogram should be normalized to 0..1  (1 means all pixels)
# TODO: generalize to parallel eval of N ranges
proc ::img_proc::_advance_hue_range_one_unit {histogramDict keysList    \
                iFirstOfPrevRange iLastOfPrevRange prevRange \
                thresholdNorm getHueUnitSubrangeVal_CB pushHueRange_CB  \
                foundRangeOrEmpty} {
  upvar $foundRangeOrEmpty foundRange
  lassign $prevRange prevBeginVal prevEndVal prevCost
  if { $iLastOfPrevRange >= [expr {[llength $keysList] - 1}] }   {
    ok_trace_msg "Reached end of histogram"
    return  -1
  }
  set prevRangeDescr "\[$prevBeginVal...$prevEndVal\]"

  set iFirstAfterPrevRange [expr $iLastOfPrevRange + 1]
  set unitStep [expr {[lindex $keysList $iFirstAfterPrevRange]  \
                   - [lindex $keysList $iLastOfPrevRange]}]
  set rangeNumUnits [expr {int( ($prevEndVal - $prevBeginVal +1) / $unitStep )}]
  ok_trace_msg "Will try to advance from $prevRangeDescr by one unit"

  # try to move one unit; if unsuitable (val > thresahold), report failure
  set iFirstOfNewRange $iFirstAfterPrevRange
  set iLastOfNewRange [expr $iLastOfPrevRange + 1];  # verified to be within bounds
  set newLastUK [lindex $keysList $iLastOfNewRange]
  set newLastUV [$getHueUnitSubrangeVal_CB \
                      $histogramDict $newLastUK $thresholdNorm]
  if { $newLastUV == -1 }  { # no gap can include key_#iFirstAfterPrevRange
    ok_trace_msg "Cannot advance range $prevRangeDescr to #$iFirstAfterPrevRange (key=$iFirstAfterPrevRange)"
    return  -1
  }
  set prevFirstUK [lindex $keysList $iFirstOfPrevRange]
  set prevFirstUV [$getHueUnitSubrangeVal_CB \
                      $histogramDict $prevFirstUK $thresholdNorm]
  set cost [expr $prevCost - $prevFirstUV + $newLastUV];  # update for advance

  set newFirstUK [lindex $keysList $iFirstOfNewRange]
  ok_info_msg "Range \[$newFirstUK...$newLastUK\] accepted; range-total-cost=$cost"
  $pushHueRange_CB $newFirstUK $newLastUK $cost
  set foundRange [list $newFirstUK $newLastUK $cost]

  return  $iLastOfNewRange
}