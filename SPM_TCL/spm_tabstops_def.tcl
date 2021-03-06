# spm_tabstops_def.tcl

# Note, tabstops for windows with any kind of FILE DIALOG should assume DETAILS/TABLE mode which is the default for new folders !!


namespace eval ::spm:: {
  # TABSTOPS_XXX == 2-level dict-s of wnd-title :: control-name :: tabstop
  variable TABSTOPS_DFL 0; # tabstops for ?default? content of Multi-Convert dialog
  variable TABSTOPS_CANV 0; # tabstops for Multi-Convert dialog with resize-with-border
  
  variable TABSTOPS 0;  # should point at the current TABSTOPS_XXX; 0 == unknown
}

################################################################################
# Builds ::spm::TABSTOPS_XXX dictionaries that tell how many times to press TAB
#                 in order to focus specific control AFTER FILENAME ENTRY
#    E.g.: press Alt-n, then count the tabstops
# Negative value tells to press Shift-TAB instead 
#     (to bypass fields inserted when "Resize" is checked)
# Tabstops here assume that "Back" button (tabstop=-4) isn't greyed-out!
# For "Multi Conversion" window  this order holds only if open programmatically!
proc ::spm::_build_tabstops_dict {}   {
  ##############################################################################
  variable TABSTOPS_DFL 0; # tabstops for ?default? content of Multi-Convert dialog
  set TABSTOPS_DFL [dict create]
  dict set TABSTOPS_DFL   "Multi Conversion"    "File name"                 0
  dict set TABSTOPS_DFL   "Multi Conversion"    "Input File Type"           1
  dict set TABSTOPS_DFL   "Multi Conversion"    "Cancel"                    2
  dict set TABSTOPS_DFL   "Multi Conversion"    "Convert Selected Files"    3
  dict set TABSTOPS_DFL   "Multi Conversion"    "Convert All Files"         4
  dict set TABSTOPS_DFL   "Multi Conversion"    "Multi Job"                 5
  
  dict set TABSTOPS_DFL   "Multi Conversion"    "Output File Type"          9
  dict set TABSTOPS_DFL   "Multi Conversion"    "Output File Format"        10
  dict set TABSTOPS_DFL   "Multi Conversion"    "Auto Align"                11
  dict set TABSTOPS_DFL   "Multi Conversion"    "Auto Alignment Settings"   12

  dict set TABSTOPS_DFL   "Multi Conversion"    "Auto Crop After Adjustment" 15

  dict set TABSTOPS_DFL   "Multi Conversion"    "Auto Color Adjustment"     18
  dict set TABSTOPS_DFL   "Multi Conversion"    "Gamma"                     19
  dict set TABSTOPS_DFL   "Multi Conversion"    "Gamma L"                   20
  dict set TABSTOPS_DFL   "Multi Conversion"    "Gamma R"                   21
  dict set TABSTOPS_DFL   "Multi Conversion"    "Crop"                      22
  dict set TABSTOPS_DFL   "Multi Conversion"    "Crop X1"                   23
  dict set TABSTOPS_DFL   "Multi Conversion"    "Crop Y1"                   24
  dict set TABSTOPS_DFL   "Multi Conversion"    "Crop X2"                   25
  dict set TABSTOPS_DFL   "Multi Conversion"    "Crop Y2"                   26
  dict set TABSTOPS_DFL   "Multi Conversion"    "Resize"                    27
  dict set TABSTOPS_DFL   "Multi Conversion"    "Width"                     28
  dict set TABSTOPS_DFL   "Multi Conversion"    "Height"                    29
  dict set TABSTOPS_DFL   "Multi Conversion"    "Input Side-By-Side"        30
  
  dict set TABSTOPS_DFL   "Multi Conversion"    "Add Text"                  34


  dict set TABSTOPS_DFL   "Multi Conversion"    "Output Folder"            -11 ; # 36
  dict set TABSTOPS_DFL   "Multi Conversion"    "Output Folder Browse"      37
  
  dict set TABSTOPS_DFL   "Multi Conversion"    "Restore(File)"             -8 ; # 39
  dict set TABSTOPS_DFL   "Multi Conversion"    "Restore"                   -7 ; # 40
  dict set TABSTOPS_DFL   "Multi Conversion"    "Save"                      -6 ; # 41
  dict set TABSTOPS_DFL   "Multi Conversion"    "Back"                      -4 ; # 43?
  
  #dict set TABSTOPS_DFL   "Multi Conversion"    "todo"        todo

  ##############################################################################
  variable TABSTOPS_CANV 0; # tabstops for Multi-Convert dialog with resize-with-border
  set TABSTOPS_CANV [dict create]
  dict set TABSTOPS_CANV  "Multi Conversion"    "Convert All Files"         4
  dict set TABSTOPS_CANV  "Multi Conversion"    "Resize"                    27
  dict set TABSTOPS_CANV  "Multi Conversion"    "Output Folder"            -11
  dict set TABSTOPS_CANV  "Multi Conversion"    "Restore(File)"             -8 ; # 39
  dict set TABSTOPS_CANV  "Multi Conversion"    "Restore"                   -7 ; # 40
  dict set TABSTOPS_CANV  "Multi Conversion"    "Save"                      -6 ; # 41
  dict set TABSTOPS_CANV  "Multi Conversion"    "Back"                      -4 ; # 43?


  ##############################################################################
  # tabstops for Add-Fuzzy-Border dialog
  # assume 'TABSTOPS_DFL' is already created
  dict set TABSTOPS_DFL   "Add Fuzzy Border"    "OK"                 0
  dict set TABSTOPS_DFL   "Add Fuzzy Border"    "Cancel"             1
  dict set TABSTOPS_DFL   "Add Fuzzy Border"    "Color"              2
  dict set TABSTOPS_DFL   "Add Fuzzy Border"    "Border width"       3
  dict set TABSTOPS_DFL   "Add Fuzzy Border"    "Fuzzy gradient"     4
  dict set TABSTOPS_DFL   "Add Fuzzy Border"    "Round corners"      5
  ############################################################################## 
  

  ##############################################################################
  # tabstops for Create-Lenticular-Image dialog; start point - "File name" 
  # assume 'TABSTOPS_DFL' is already created
  dict set TABSTOPS_DFL   "Create Lenticular Image"    "File name"             0
  dict set TABSTOPS_DFL   "Create Lenticular Image"    "Files of type"         1
  dict set TABSTOPS_DFL   "Create Lenticular Image"    "Cancel"                2
  dict set TABSTOPS_DFL   "Create Lenticular Image"    "Create with Selected Files"   3
  dict set TABSTOPS_DFL   "Create Lenticular Image"    "Create with All Files" 4
  dict set TABSTOPS_DFL   "Create Lenticular Image"    "Show Preview"          5
  dict set TABSTOPS_DFL   "Create Lenticular Image"    "Lenticular Lens Pitch" 6
  dict set TABSTOPS_DFL   "Create Lenticular Image"    "Printer Resolution"    7
  dict set TABSTOPS_DFL   "Create Lenticular Image"    "Print Width"           8
  dict set TABSTOPS_DFL   "Create Lenticular Image"    "Image Direction"       9
  dict set TABSTOPS_DFL   "Create Lenticular Image"    "Create slit animation image"  10
  ############################################################################## 
  
  
  ##############################################################################
  variable TABSTOPS;  # should point at the current TABSTOPS_XXX; 0 == unknown
  set TABSTOPS $TABSTOPS_DFL;   # TODO: "reset
  ##############################################################################
}
