/************************************************************************
 * @description Create a console to print logs (text formatting supported)
 * Based on a script by someone else 
 * @file logger.ahk
 * @author Gold512
 * @date 2024/06/27
 * @version 0.0.0
 ***********************************************************************/


global is_open 
is_open := 0

global _DEBUG := false

LogMessage(str, timestamp := false, end := '`n') {
  global h_Stdout
  _DebugConsoleInitialize()  ; start console window if not yet started
  str .= end ; add line feed

  if timestamp {
    time := FormatTime(, 'hh:mm:ss')
    str := '[' time '] ' str  
  }

  ; cast string to utf8 buffer

  DllCall("WriteConsole", "uint", h_Stdout, "uint", StrPtr(str), "uint", StrLen(str), "uint", 0, "uint", 0) ; write into the console
}

DebugMessage(str) {
	global _DEBUG
	if _DEBUG == false
		return

	LogMessage('[DEBUG] ' str)
}

/**
 * Set debug state
 * @param {true|false} state 
 */
SetDebug(state) {
  global _DEBUG
  _DEBUG := state
}

_DebugConsoleInitialize() {
  global h_Stdout     ; Handle for console
  global is_open
  if (is_open == 1)     ; yes, so don't open again
    return
  
  is_open := 1	
  ; two calls to open, no error check (it's debug, so you know what you are doing)
  DllCall("AttachConsole", "int", -1, "int")
  DllCall("AllocConsole", "int")

  DllCall("SetConsoleTitle", "str", "CRKBot")    ; Set the name. Example. Probably could use a_scriptname here 
  h_Stdout := DllCall("GetStdHandle", "int", -11) ; get the handle


  ; https://learn.microsoft.com/en-us/windows/console/setconsolemode
  ; enable formatting :D
  ; 0x0001 - ENABLE_PROCESSED_OUTPUT 
  ; 0x0004 - ENABLE_VIRTUAL_TERMINAL_PROCESSING 
  DllCall('SetConsoleMode', 'uint', h_Stdout, 'int64', 0x0001 | 0x0004)

  return
}

DestroyConsole(a, b) {
	; automatically close console on close
	DllCall('FreeConsole')
}

DestroyConsoleErr(a, b) {
  global _DEBUG
  if !_DEBUG
    DestroyConsole(a, b)
}

; create sequences 
; https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences
class Seq {
  /**
   * Create a sequence from color codes
   * Example: Seq.Color(Seq.BG_Red, Seq.FG_White)
   * @param {Integer*} s color codes
   * @returns {String} 
   */
  static Color(s*) {
    result := ''
    sep := ';'

    for index, value in s {
      result .= sep . value
    }

    return chr(0x1b) '[' SubStr(result, StrLen(sep) + 1) 'm'
  }

  /**
   * Delete the next n lines starting from the cursor's position
   * @param {Integer} n 
   * @returns {String} 
   */
  static DeleteLines(n) {
    return chr(0x1b) '[' n 'M'
  }

  /**
   * 
   * @param {Integer} n 
   * @returns {String} 
   */
  static DeletePreviousLines(n := 1) {
    return chr(0x1b) '[' n 'F' chr(0x1b) '[' n 'M'
  }

  /**
   * Create foreground RGB Color code
   * Usage: Seq.Color(Seq.FG_RGB[10, 10, 10])
   * @param {Integer} r 
   * @param {Integer} g 
   * @param {Integer} b 
   * @returns {String} 
   */
  FG_RGB[r, g, b] {
    get {
      return '38 `; 2 `; ' r '`;' g '`;' b
    }
  }

  /**
   * Create background from RGB Color code
   * Usage: Seq.Color(Seq.BG_RGB[10, 10, 10])
   * @param {Integer} r 
   * @param {Integer} g 
   * @param {Integer} b 
   * @returns {String} 
   */
  BG_RGB[r, g, b] {
    get {
      return '48 `; 2 `; ' r '`;' g '`;' b
    }
  }

  static Default := 0

  static Bold := 1
  static No_Bold := 22

  static Underline := 4
  static No_Underline := 24

  static Negative := 7
  static No_Negative := 27

  static FG_Black := 30
  static FG_Red := 31
  static FG_Green := 32	
  static FG_Yellow := 33	
  static FG_Blue := 34	
  static FG_Magenta := 35	
  static FG_Cyan := 36
  static FG_White := 37

  static FG_Bright_Black := 90
  static FG_Bright_Red := 91
  static FG_Bright_Green := 92
  static FG_Bright_Yellow := 93
  static FG_Bright_Blue := 94
  static FG_Bright_Magenta := 95
  static FG_Bright_Cyan := 96
  static FG_Bright_White := 97	

  static BG_Black := 40
  static BG_Red := 41
  static BG_Green := 42
  static BG_Yellow := 43
  static BG_Blue := 44	
  static BG_Magenta := 45	
  static BG_Cyan := 46	
  static BG_White := 47

  static BG_Bright_Black := 100
  static BG_Bright_Red := 101
  static BG_Bright_Green := 102
  static BG_Bright_Yellow := 103
  static BG_Bright_Blue := 104
  static BG_Bright_Magenta := 105
  static BG_Bright_Cyan := 106
  static BG_Bright_White := 107
}

/**
 * Create a logging context with a tree like structure that automatically
 * expands
 */
class NestedLog {
  __New(msg, color := '') {
    LogMessage(color . msg . Seq.Color(Seq.Default), true)
    this.color := color
    this.prev := ''
  }

  Log(msg) {
    if this.prev {
      LogMessage(Seq.DeletePreviousLines(1),, '')
      LogMessage(this.prevTime . this.color '├╴' Seq.Color(Seq.Default) this.prev)
    }

    LogMessage(this.color '└╴' Seq.Color(Seq.Default) msg, true)
    this.prev := msg

    time := FormatTime(, 'hh:mm:ss')
    this.prevTime := '[' time '] '
  }
}

OnExit(DestroyConsole)
OnError(DestroyConsoleErr)