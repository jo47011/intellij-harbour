// Step 1: Add variable name capture to working debug handler
#pragma -B-
REQUEST HB_GT_STD_DEFAULT

#include <hbdebug.ch>
#include <fileio.ch>

#ifndef HB_DBG_GETENTRY
#define HB_DBG_GETENTRY       6
#define HB_DBG_ACTIVATE       7
#define HB_DBG_SHOWLINE       5
#define HB_DBG_MODULENAME     1
#define HB_DBG_LOCALNAME      2
#define HB_DBG_STATICNAME     3
#endif

// Simple debug state - minimal and safe
STATIC s_lRegistered := .F.
STATIC s_nLogHandle := -1

// Main debug entry point - proven working foundation
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3, uParam4)
   
   // Open log file once
   IF s_nLogHandle == -1
      s_nLogHandle := FCreate("/home/developer/workspace/debug_step1.log", FC_NORMAL)
   ENDIF
   
   DO CASE
   CASE nMode == HB_DBG_GETENTRY
      // Critical: This MUST work first
      IF !s_lRegistered
         ? "HB_DBG_GETENTRY - registering with VM"
         __dbgSetEntry()
         s_lRegistered := .T.
         ? "Debug handler registered successfully"
         LogEvent("GETENTRY - registered successfully")
      ENDIF
      
   CASE nMode == HB_DBG_MODULENAME
      // Now we can safely capture module/function names
      ? "MODULENAME:", uParam1
      LogEvent("MODULENAME: " + hb_CStr(uParam1))
      
   CASE nMode == HB_DBG_LOCALNAME
      // Capture local variable names
      ? "LOCALNAME:", uParam1, "index:", uParam2
      LogEvent("LOCALNAME: " + hb_CStr(uParam1) + " index:" + Str(uParam2))
      
   CASE nMode == HB_DBG_STATICNAME
      // Capture static variable names
      ? "STATICNAME:", uParam3
      LogEvent("STATICNAME: " + hb_CStr(uParam3))
      
   CASE nMode == HB_DBG_ACTIVATE
      LogEvent("ACTIVATE")
      
   CASE nMode == HB_DBG_SHOWLINE
      LogEvent("SHOWLINE")
      
   OTHERWISE
      LogEvent("Other mode: " + Str(nMode))
   ENDCASE
RETURN

// Safe logging function
STATIC PROCEDURE LogEvent(cMessage)
   IF s_nLogHandle >= 0
      FWrite(s_nLogHandle, Time() + " " + cMessage + Chr(13) + Chr(10))
   ENDIF
RETURN