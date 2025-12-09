/* $XConsortium: keysym.h,v 1.15 94/04/17 20:10:55 rws Exp $ */

/***********************************************************

Copyright (c) 1987  X Consortium

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
X CONSORTIUM BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of the X Consortium shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from the X Consortium.


Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

						All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

******************************************************************/

/* $TOG: keysymdef.h /main/25 1997/06/21 10:54:51 kaleb $ */

/// *********************************************************
/// Copyright (c) 1987, 1994  X Consortium
///
/// Permission is hereby granted, free of charge, to any person obtaining
/// a copy of this software and associated documentation files (the
/// "Software"), to deal in the Software without restriction, including
/// without limitation the rights to use, copy, modify, merge, publish,
/// distribute, sublicense, and/or sell copies of the Software, and to
/// permit persons to whom the Software is furnished to do so, subject to
/// the following conditions:
///
/// The above copyright notice and this permission notice shall be included
/// in all copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
/// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
/// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
/// IN NO EVENT SHALL THE X CONSORTIUM BE LIABLE FOR ANY CLAIM, DAMAGES OR
/// OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
/// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
/// OTHER DEALINGS IN THE SOFTWARE.
///
/// Except as contained in this notice, the name of the X Consortium shall
/// not be used in advertising or otherwise to promote the sale, use or
/// other dealings in this Software without prior written authorization
/// from the X Consortium.
///
///
/// Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts
///
/// 						All Rights Reserved
///
/// Permission to use, copy, modify, and distribute this software and its
/// documentation for any purpose and without fee is hereby granted,
/// provided that the above copyright notice appear in all copies and that
/// both that copyright notice and this permission notice appear in
/// supporting documentation, and that the name of Digital not be
/// used in advertising or publicity pertaining to distribution of the
/// software without specific, written prior permission.
///
/// DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
/// ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
/// DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
/// ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
/// WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
/// ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
/// SOFTWARE.
///
/// *****************************************************************
///

import Foundation

struct Keysyms {
	static let XK_VoidSymbol: UInt32 = 0xFFFF /* void symbol */

	/*
	 * TTY Functions, cleverly chosen to map to ascii, for convenience of
	 * programming, but could have been arbitrary (at the cost of lookup
	 * tables in client code.
	 */

	static let XK_BackSpace: UInt32 = 0xFF08 /* back space, back char */
	static let XK_Tab: UInt32 = 0xFF09
	static let XK_Linefeed: UInt32 = 0xFF0A /* Linefeed, LF */
	static let XK_Clear: UInt32 = 0xFF0B
	static let XK_Return: UInt32 = 0xFF0D /* Return, enter */
	static let XK_Pause: UInt32 = 0xFF13 /* Pause, hold */
	static let XK_Scroll_Lock: UInt32 = 0xFF14
	static let XK_Sys_Req: UInt32 = 0xFF15
	static let XK_Escape: UInt32 = 0xFF1B
	static let XK_Delete: UInt32 = 0xFFFF /* Delete, rubout */

	/* International & multi-key character composition */

	static let XK_Multi_key: UInt32 = 0xFF20 /* Multi-key character compose */
	static let XK_SingleCandidate: UInt32 = 0xFF3C
	static let XK_MultipleCandidate: UInt32 = 0xFF3D
	static let XK_PreviousCandidate: UInt32 = 0xFF3E

	/* Japanese keyboard support */

	static let XK_Kanji: UInt32 = 0xFF21 /* Kanji, Kanji convert */
	static let XK_Muhenkan: UInt32 = 0xFF22 /* Cancel Conversion */
	static let XK_Henkan_Mode: UInt32 = 0xFF23 /* Start/Stop Conversion */
	static let XK_Henkan: UInt32 = 0xFF23 /* Alias for Henkan_Mode */
	static let XK_Romaji: UInt32 = 0xFF24 /* to Romaji */
	static let XK_Hiragana: UInt32 = 0xFF25 /* to Hiragana */
	static let XK_Katakana: UInt32 = 0xFF26 /* to Katakana */
	static let XK_Hiragana_Katakana: UInt32 = 0xFF27 /* Hiragana/Katakana toggle */
	static let XK_Zenkaku: UInt32 = 0xFF28 /* to Zenkaku */
	static let XK_Hankaku: UInt32 = 0xFF29 /* to Hankaku */
	static let XK_Zenkaku_Hankaku: UInt32 = 0xFF2A /* Zenkaku/Hankaku toggle */
	static let XK_Touroku: UInt32 = 0xFF2B /* Add to Dictionary */
	static let XK_Massyo: UInt32 = 0xFF2C /* Delete from Dictionary */
	static let XK_Kana_Lock: UInt32 = 0xFF2D /* Kana Lock */
	static let XK_Kana_Shift: UInt32 = 0xFF2E /* Kana Shift */
	static let XK_Eisu_Shift: UInt32 = 0xFF2F /* Alphanumeric Shift */
	static let XK_Eisu_toggle: UInt32 = 0xFF30 /* Alphanumeric toggle */
	static let XK_Zen_Koho: UInt32 = 0xFF3D /* Multiple/All Candidate(s) */
	static let XK_Mae_Koho: UInt32 = 0xFF3E /* Previous Candidate */

	/* : UInt32 = 0xFF31 through : UInt32 = 0xFF3F are under XK_KOREAN */

	/* Cursor control & motion */

	static let XK_Home: UInt32 = 0xFF50
	static let XK_Left: UInt32 = 0xFF51 /* Move left, left arrow */
	static let XK_Up: UInt32 = 0xFF52 /* Move up, up arrow */
	static let XK_Right: UInt32 = 0xFF53 /* Move right, right arrow */
	static let XK_Down: UInt32 = 0xFF54 /* Move down, down arrow */
	static let XK_Prior: UInt32 = 0xFF55 /* Prior, previous */
	static let XK_Page_Up: UInt32 = 0xFF55
	static let XK_Next: UInt32 = 0xFF56 /* Next */
	static let XK_Page_Down: UInt32 = 0xFF56
	static let XK_End: UInt32 = 0xFF57 /* EOL */
	static let XK_Begin: UInt32 = 0xFF58 /* BOL */

	/* Misc Functions */

	static let XK_Select: UInt32 = 0xFF60 /* Select, mark */
	static let XK_Print: UInt32 = 0xFF61
	static let XK_Execute: UInt32 = 0xFF62 /* Execute, run, do */
	static let XK_Insert: UInt32 = 0xFF63 /* Insert, insert here */
	static let XK_Undo: UInt32 = 0xFF65 /* Undo, oops */
	static let XK_Redo: UInt32 = 0xFF66 /* redo, again */
	static let XK_Menu: UInt32 = 0xFF67
	static let XK_Find: UInt32 = 0xFF68 /* Find, search */
	static let XK_Cancel: UInt32 = 0xFF69 /* Cancel, stop, abort, exit */
	static let XK_Help: UInt32 = 0xFF6A /* Help */
	static let XK_Break: UInt32 = 0xFF6B
	static let XK_Mode_switch: UInt32 = 0xFF7E /* Character set switch */
	static let XK_script_switch: UInt32 = 0xFF7E /* Alias for mode_switch */
	static let XK_Num_Lock: UInt32 = 0xFF7F

	/* Keypad Functions, keypad numbers cleverly chosen to map to ascii */

	static let XK_KP_Space: UInt32 = 0xFF80 /* space */
	static let XK_KP_Tab: UInt32 = 0xFF89
	static let XK_KP_Enter: UInt32 = 0xFF8D /* enter */
	static let XK_KP_F1: UInt32 = 0xFF91 /* PF1, KP_A, ... */
	static let XK_KP_F2: UInt32 = 0xFF92
	static let XK_KP_F3: UInt32 = 0xFF93
	static let XK_KP_F4: UInt32 = 0xFF94
	static let XK_KP_Home: UInt32 = 0xFF95
	static let XK_KP_Left: UInt32 = 0xFF96
	static let XK_KP_Up: UInt32 = 0xFF97
	static let XK_KP_Right: UInt32 = 0xFF98
	static let XK_KP_Down: UInt32 = 0xFF99
	static let XK_KP_Prior: UInt32 = 0xFF9A
	static let XK_KP_Page_Up: UInt32 = 0xFF9A
	static let XK_KP_Next: UInt32 = 0xFF9B
	static let XK_KP_Page_Down: UInt32 = 0xFF9B
	static let XK_KP_End: UInt32 = 0xFF9C
	static let XK_KP_Begin: UInt32 = 0xFF9D
	static let XK_KP_Insert: UInt32 = 0xFF9E
	static let XK_KP_Delete: UInt32 = 0xFF9F
	static let XK_KP_Equal: UInt32 = 0xFFBD /* equals */
	static let XK_KP_Multiply: UInt32 = 0xFFAA
	static let XK_KP_Add: UInt32 = 0xFFAB
	static let XK_KP_Separator: UInt32 = 0xFFAC /* separator, often comma */
	static let XK_KP_Subtract: UInt32 = 0xFFAD
	static let XK_KP_Decimal: UInt32 = 0xFFAE
	static let XK_KP_Divide: UInt32 = 0xFFAF

	static let XK_KP_0: UInt32 = 0xFFB0
	static let XK_KP_1: UInt32 = 0xFFB1
	static let XK_KP_2: UInt32 = 0xFFB2
	static let XK_KP_3: UInt32 = 0xFFB3
	static let XK_KP_4: UInt32 = 0xFFB4
	static let XK_KP_5: UInt32 = 0xFFB5
	static let XK_KP_6: UInt32 = 0xFFB6
	static let XK_KP_7: UInt32 = 0xFFB7
	static let XK_KP_8: UInt32 = 0xFFB8
	static let XK_KP_9: UInt32 = 0xFFB9

	/*
	 * Auxiliary Functions; note the duplicate definitions for left and right
	 * function keys;  Sun keyboards and a few other manufactures have such
	 * function key groups on the left and/or right sides of the keyboard.
	 * We've not found a keyboard with more than 35 function keys total.
	 */

	static let XK_F1: UInt32 = 0xFFBE
	static let XK_F2: UInt32 = 0xFFBF
	static let XK_F3: UInt32 = 0xFFC0
	static let XK_F4: UInt32 = 0xFFC1
	static let XK_F5: UInt32 = 0xFFC2
	static let XK_F6: UInt32 = 0xFFC3
	static let XK_F7: UInt32 = 0xFFC4
	static let XK_F8: UInt32 = 0xFFC5
	static let XK_F9: UInt32 = 0xFFC6
	static let XK_F10: UInt32 = 0xFFC7
	static let XK_F11: UInt32 = 0xFFC8
	static let XK_L1: UInt32 = 0xFFC8
	static let XK_F12: UInt32 = 0xFFC9
	static let XK_L2: UInt32 = 0xFFC9
	static let XK_F13: UInt32 = 0xFFCA
	static let XK_L3: UInt32 = 0xFFCA
	static let XK_F14: UInt32 = 0xFFCB
	static let XK_L4: UInt32 = 0xFFCB
	static let XK_F15: UInt32 = 0xFFCC
	static let XK_L5: UInt32 = 0xFFCC
	static let XK_F16: UInt32 = 0xFFCD
	static let XK_L6: UInt32 = 0xFFCD
	static let XK_F17: UInt32 = 0xFFCE
	static let XK_L7: UInt32 = 0xFFCE
	static let XK_F18: UInt32 = 0xFFCF
	static let XK_L8: UInt32 = 0xFFCF
	static let XK_F19: UInt32 = 0xFFD0
	static let XK_L9: UInt32 = 0xFFD0
	static let XK_F20: UInt32 = 0xFFD1
	static let XK_L10: UInt32 = 0xFFD1
	static let XK_F21: UInt32 = 0xFFD2
	static let XK_R1: UInt32 = 0xFFD2
	static let XK_F22: UInt32 = 0xFFD3
	static let XK_R2: UInt32 = 0xFFD3
	static let XK_F23: UInt32 = 0xFFD4
	static let XK_R3: UInt32 = 0xFFD4
	static let XK_F24: UInt32 = 0xFFD5
	static let XK_R4: UInt32 = 0xFFD5
	static let XK_F25: UInt32 = 0xFFD6
	static let XK_R5: UInt32 = 0xFFD6
	static let XK_F26: UInt32 = 0xFFD7
	static let XK_R6: UInt32 = 0xFFD7
	static let XK_F27: UInt32 = 0xFFD8
	static let XK_R7: UInt32 = 0xFFD8
	static let XK_F28: UInt32 = 0xFFD9
	static let XK_R8: UInt32 = 0xFFD9
	static let XK_F29: UInt32 = 0xFFDA
	static let XK_R9: UInt32 = 0xFFDA
	static let XK_F30: UInt32 = 0xFFDB
	static let XK_R10: UInt32 = 0xFFDB
	static let XK_F31: UInt32 = 0xFFDC
	static let XK_R11: UInt32 = 0xFFDC
	static let XK_F32: UInt32 = 0xFFDD
	static let XK_R12: UInt32 = 0xFFDD
	static let XK_F33: UInt32 = 0xFFDE
	static let XK_R13: UInt32 = 0xFFDE
	static let XK_F34: UInt32 = 0xFFDF
	static let XK_R14: UInt32 = 0xFFDF
	static let XK_F35: UInt32 = 0xFFE0
	static let XK_R15: UInt32 = 0xFFE0

	/* Modifiers */

	static let XK_Shift_L: UInt32 = 0xFFE1 /* Left shift */
	static let XK_Shift_R: UInt32 = 0xFFE2 /* Right shift */
	static let XK_Control_L: UInt32 = 0xFFE3 /* Left control */
	static let XK_Control_R: UInt32 = 0xFFE4 /* Right control */
	static let XK_Caps_Lock: UInt32 = 0xFFE5 /* Caps lock */
	static let XK_Shift_Lock: UInt32 = 0xFFE6 /* Shift lock */

	static let XK_Meta_L: UInt32 = 0xFFE7 /* Left meta */
	static let XK_Meta_R: UInt32 = 0xFFE8 /* Right meta */
	static let XK_Alt_L: UInt32 = 0xFFE9 /* Left alt */
	static let XK_Alt_R: UInt32 = 0xFFEA /* Right alt */
	static let XK_Super_L: UInt32 = 0xFFEB /* Left super */
	static let XK_Super_R: UInt32 = 0xFFEC /* Right super */
	static let XK_Hyper_L: UInt32 = 0xFFED /* Left hyper */
	static let XK_Hyper_R: UInt32 = 0xFFEE /* Right hyper */

	/*
	 * ISO 9995 Function and Modifier Keys
	 * Byte 3 = : UInt32 = 0xFE
	 */

	static let XK_ISO_Lock: UInt32 = 0xFE01
	static let XK_ISO_Level2_Latch: UInt32 = 0xFE02
	static let XK_ISO_Level3_Shift: UInt32 = 0xFE03
	static let XK_ISO_Level3_Latch: UInt32 = 0xFE04
	static let XK_ISO_Level3_Lock: UInt32 = 0xFE05
	static let XK_ISO_Group_Shift: UInt32 = 0xFF7E /* Alias for mode_switch */
	static let XK_ISO_Group_Latch: UInt32 = 0xFE06
	static let XK_ISO_Group_Lock: UInt32 = 0xFE07
	static let XK_ISO_Next_Group: UInt32 = 0xFE08
	static let XK_ISO_Next_Group_Lock: UInt32 = 0xFE09
	static let XK_ISO_Prev_Group: UInt32 = 0xFE0A
	static let XK_ISO_Prev_Group_Lock: UInt32 = 0xFE0B
	static let XK_ISO_First_Group: UInt32 = 0xFE0C
	static let XK_ISO_First_Group_Lock: UInt32 = 0xFE0D
	static let XK_ISO_Last_Group: UInt32 = 0xFE0E
	static let XK_ISO_Last_Group_Lock: UInt32 = 0xFE0F

	static let XK_ISO_Left_Tab: UInt32 = 0xFE20
	static let XK_ISO_Move_Line_Up: UInt32 = 0xFE21
	static let XK_ISO_Move_Line_Down: UInt32 = 0xFE22
	static let XK_ISO_Partial_Line_Up: UInt32 = 0xFE23
	static let XK_ISO_Partial_Line_Down: UInt32 = 0xFE24
	static let XK_ISO_Partial_Space_Left: UInt32 = 0xFE25
	static let XK_ISO_Partial_Space_Right: UInt32 = 0xFE26
	static let XK_ISO_Set_Margin_Left: UInt32 = 0xFE27
	static let XK_ISO_Set_Margin_Right: UInt32 = 0xFE28
	static let XK_ISO_Release_Margin_Left: UInt32 = 0xFE29
	static let XK_ISO_Release_Margin_Right: UInt32 = 0xFE2A
	static let XK_ISO_Release_Both_Margins: UInt32 = 0xFE2B
	static let XK_ISO_Fast_Cursor_Left: UInt32 = 0xFE2C
	static let XK_ISO_Fast_Cursor_Right: UInt32 = 0xFE2D
	static let XK_ISO_Fast_Cursor_Up: UInt32 = 0xFE2E
	static let XK_ISO_Fast_Cursor_Down: UInt32 = 0xFE2F
	static let XK_ISO_Continuous_Underline: UInt32 = 0xFE30
	static let XK_ISO_Discontinuous_Underline: UInt32 = 0xFE31
	static let XK_ISO_Emphasize: UInt32 = 0xFE32
	static let XK_ISO_Center_Object: UInt32 = 0xFE33
	static let XK_ISO_Enter: UInt32 = 0xFE34

	static let XK_dead_grave: UInt32 = 0xFE50
	static let XK_dead_acute: UInt32 = 0xFE51
	static let XK_dead_circumflex: UInt32 = 0xFE52
	static let XK_dead_tilde: UInt32 = 0xFE53
	static let XK_dead_macron: UInt32 = 0xFE54
	static let XK_dead_breve: UInt32 = 0xFE55
	static let XK_dead_abovedot: UInt32 = 0xFE56
	static let XK_dead_diaeresis: UInt32 = 0xFE57
	static let XK_dead_abovering: UInt32 = 0xFE58
	static let XK_dead_doubleacute: UInt32 = 0xFE59
	static let XK_dead_caron: UInt32 = 0xFE5A
	static let XK_dead_cedilla: UInt32 = 0xFE5B
	static let XK_dead_ogonek: UInt32 = 0xFE5C
	static let XK_dead_iota: UInt32 = 0xFE5D
	static let XK_dead_voiced_sound: UInt32 = 0xFE5E
	static let XK_dead_semivoiced_sound: UInt32 = 0xFE5F
	static let XK_dead_belowdot: UInt32 = 0xFE60

	static let XK_First_Virtual_Screen: UInt32 = 0xFED0
	static let XK_Prev_Virtual_Screen: UInt32 = 0xFED1
	static let XK_Next_Virtual_Screen: UInt32 = 0xFED2
	static let XK_Last_Virtual_Screen: UInt32 = 0xFED4
	static let XK_Terminate_Server: UInt32 = 0xFED5

	static let XK_AccessX_Enable: UInt32 = 0xFE70
	static let XK_AccessX_Feedback_Enable: UInt32 = 0xFE71
	static let XK_RepeatKeys_Enable: UInt32 = 0xFE72
	static let XK_SlowKeys_Enable: UInt32 = 0xFE73
	static let XK_BounceKeys_Enable: UInt32 = 0xFE74
	static let XK_StickyKeys_Enable: UInt32 = 0xFE75
	static let XK_MouseKeys_Enable: UInt32 = 0xFE76
	static let XK_MouseKeys_Accel_Enable: UInt32 = 0xFE77
	static let XK_Overlay1_Enable: UInt32 = 0xFE78
	static let XK_Overlay2_Enable: UInt32 = 0xFE79
	static let XK_AudibleBell_Enable: UInt32 = 0xFE7A

	static let XK_Pointer_Left: UInt32 = 0xFEE0
	static let XK_Pointer_Right: UInt32 = 0xFEE1
	static let XK_Pointer_Up: UInt32 = 0xFEE2
	static let XK_Pointer_Down: UInt32 = 0xFEE3
	static let XK_Pointer_UpLeft: UInt32 = 0xFEE4
	static let XK_Pointer_UpRight: UInt32 = 0xFEE5
	static let XK_Pointer_DownLeft: UInt32 = 0xFEE6
	static let XK_Pointer_DownRight: UInt32 = 0xFEE7
	static let XK_Pointer_Button_Dflt: UInt32 = 0xFEE8
	static let XK_Pointer_Button1: UInt32 = 0xFEE9
	static let XK_Pointer_Button2: UInt32 = 0xFEEA
	static let XK_Pointer_Button3: UInt32 = 0xFEEB
	static let XK_Pointer_Button4: UInt32 = 0xFEEC
	static let XK_Pointer_Button5: UInt32 = 0xFEED
	static let XK_Pointer_DblClick_Dflt: UInt32 = 0xFEEE
	static let XK_Pointer_DblClick1: UInt32 = 0xFEEF
	static let XK_Pointer_DblClick2: UInt32 = 0xFEF0
	static let XK_Pointer_DblClick3: UInt32 = 0xFEF1
	static let XK_Pointer_DblClick4: UInt32 = 0xFEF2
	static let XK_Pointer_DblClick5: UInt32 = 0xFEF3
	static let XK_Pointer_Drag_Dflt: UInt32 = 0xFEF4
	static let XK_Pointer_Drag1: UInt32 = 0xFEF5
	static let XK_Pointer_Drag2: UInt32 = 0xFEF6
	static let XK_Pointer_Drag3: UInt32 = 0xFEF7
	static let XK_Pointer_Drag4: UInt32 = 0xFEF8
	static let XK_Pointer_Drag5: UInt32 = 0xFEFD

	static let XK_Pointer_EnableKeys: UInt32 = 0xFEF9
	static let XK_Pointer_Accelerate: UInt32 = 0xFEFA
	static let XK_Pointer_DfltBtnNext: UInt32 = 0xFEFB
	static let XK_Pointer_DfltBtnPrev: UInt32 = 0xFEFC

	/*
	 * 3270 Terminal Keys
	 * Byte 3 = : UInt32 = 0xFD
	 */

	static let XK_3270_Duplicate: UInt32 = 0xFD01
	static let XK_3270_FieldMark: UInt32 = 0xFD02
	static let XK_3270_Right2: UInt32 = 0xFD03
	static let XK_3270_Left2: UInt32 = 0xFD04
	static let XK_3270_BackTab: UInt32 = 0xFD05
	static let XK_3270_EraseEOF: UInt32 = 0xFD06
	static let XK_3270_EraseInput: UInt32 = 0xFD07
	static let XK_3270_Reset: UInt32 = 0xFD08
	static let XK_3270_Quit: UInt32 = 0xFD09
	static let XK_3270_PA1: UInt32 = 0xFD0A
	static let XK_3270_PA2: UInt32 = 0xFD0B
	static let XK_3270_PA3: UInt32 = 0xFD0C
	static let XK_3270_Test: UInt32 = 0xFD0D
	static let XK_3270_Attn: UInt32 = 0xFD0E
	static let XK_3270_CursorBlink: UInt32 = 0xFD0F
	static let XK_3270_AltCursor: UInt32 = 0xFD10
	static let XK_3270_KeyClick: UInt32 = 0xFD11
	static let XK_3270_Jump: UInt32 = 0xFD12
	static let XK_3270_Ident: UInt32 = 0xFD13
	static let XK_3270_Rule: UInt32 = 0xFD14
	static let XK_3270_Copy: UInt32 = 0xFD15
	static let XK_3270_Play: UInt32 = 0xFD16
	static let XK_3270_Setup: UInt32 = 0xFD17
	static let XK_3270_Record: UInt32 = 0xFD18
	static let XK_3270_ChangeScreen: UInt32 = 0xFD19
	static let XK_3270_DeleteWord: UInt32 = 0xFD1A
	static let XK_3270_ExSelect: UInt32 = 0xFD1B
	static let XK_3270_CursorSelect: UInt32 = 0xFD1C
	static let XK_3270_PrintScreen: UInt32 = 0xFD1D
	static let XK_3270_Enter: UInt32 = 0xFD1E

	/*
	 *  Latin 1
	 *  Byte 3 = 0
	 */
	static let XK_space: UInt32 = 0x020
	static let XK_exclam: UInt32 = 0x021
	static let XK_quotedbl: UInt32 = 0x022
	static let XK_numbersign: UInt32 = 0x023
	static let XK_dollar: UInt32 = 0x024
	static let XK_percent: UInt32 = 0x025
	static let XK_ampersand: UInt32 = 0x026
	static let XK_apostrophe: UInt32 = 0x027
	static let XK_quoteright: UInt32 = 0x027 /* deprecated */
	static let XK_parenleft: UInt32 = 0x028
	static let XK_parenright: UInt32 = 0x029
	static let XK_asterisk: UInt32 = 0x02a
	static let XK_plus: UInt32 = 0x02b
	static let XK_comma: UInt32 = 0x02c
	static let XK_minus: UInt32 = 0x02d
	static let XK_period: UInt32 = 0x02e
	static let XK_slash: UInt32 = 0x02f
	static let XK_0: UInt32 = 0x030
	static let XK_1: UInt32 = 0x031
	static let XK_2: UInt32 = 0x032
	static let XK_3: UInt32 = 0x033
	static let XK_4: UInt32 = 0x034
	static let XK_5: UInt32 = 0x035
	static let XK_6: UInt32 = 0x036
	static let XK_7: UInt32 = 0x037
	static let XK_8: UInt32 = 0x038
	static let XK_9: UInt32 = 0x039
	static let XK_colon: UInt32 = 0x03a
	static let XK_semicolon: UInt32 = 0x03b
	static let XK_less: UInt32 = 0x03c
	static let XK_equal: UInt32 = 0x03d
	static let XK_greater: UInt32 = 0x03e
	static let XK_question: UInt32 = 0x03f
	static let XK_at: UInt32 = 0x040
	static let XK_A: UInt32 = 0x041
	static let XK_B: UInt32 = 0x042
	static let XK_C: UInt32 = 0x043
	static let XK_D: UInt32 = 0x044
	static let XK_E: UInt32 = 0x045
	static let XK_F: UInt32 = 0x046
	static let XK_G: UInt32 = 0x047
	static let XK_H: UInt32 = 0x048
	static let XK_I: UInt32 = 0x049
	static let XK_J: UInt32 = 0x04a
	static let XK_K: UInt32 = 0x04b
	static let XK_L: UInt32 = 0x04c
	static let XK_M: UInt32 = 0x04d
	static let XK_N: UInt32 = 0x04e
	static let XK_O: UInt32 = 0x04f
	static let XK_P: UInt32 = 0x050
	static let XK_Q: UInt32 = 0x051
	static let XK_R: UInt32 = 0x052
	static let XK_S: UInt32 = 0x053
	static let XK_T: UInt32 = 0x054
	static let XK_U: UInt32 = 0x055
	static let XK_V: UInt32 = 0x056
	static let XK_W: UInt32 = 0x057
	static let XK_X: UInt32 = 0x058
	static let XK_Y: UInt32 = 0x059
	static let XK_Z: UInt32 = 0x05a
	static let XK_bracketleft: UInt32 = 0x05b
	static let XK_backslash: UInt32 = 0x05c
	static let XK_bracketright: UInt32 = 0x05d
	static let XK_asciicircum: UInt32 = 0x05e
	static let XK_underscore: UInt32 = 0x05f
	static let XK_grave: UInt32 = 0x060
	static let XK_quoteleft: UInt32 = 0x060 /* deprecated */
	static let XK_a: UInt32 = 0x061
	static let XK_b: UInt32 = 0x062
	static let XK_c: UInt32 = 0x063
	static let XK_d: UInt32 = 0x064
	static let XK_e: UInt32 = 0x065
	static let XK_f: UInt32 = 0x066
	static let XK_g: UInt32 = 0x067
	static let XK_h: UInt32 = 0x068
	static let XK_i: UInt32 = 0x069
	static let XK_j: UInt32 = 0x06a
	static let XK_k: UInt32 = 0x06b
	static let XK_l: UInt32 = 0x06c
	static let XK_m: UInt32 = 0x06d
	static let XK_n: UInt32 = 0x06e
	static let XK_o: UInt32 = 0x06f
	static let XK_p: UInt32 = 0x070
	static let XK_q: UInt32 = 0x071
	static let XK_r: UInt32 = 0x072
	static let XK_s: UInt32 = 0x073
	static let XK_t: UInt32 = 0x074
	static let XK_u: UInt32 = 0x075
	static let XK_v: UInt32 = 0x076
	static let XK_w: UInt32 = 0x077
	static let XK_x: UInt32 = 0x078
	static let XK_y: UInt32 = 0x079
	static let XK_z: UInt32 = 0x07a
	static let XK_braceleft: UInt32 = 0x07b
	static let XK_bar: UInt32 = 0x07c
	static let XK_braceright: UInt32 = 0x07d
	static let XK_asciitilde: UInt32 = 0x07e

	static let XK_nobreakspace: UInt32 = 0x0a0
	static let XK_exclamdown: UInt32 = 0x0a1
	static let XK_cent: UInt32 = 0x0a2
	static let XK_sterling: UInt32 = 0x0a3
	static let XK_currency: UInt32 = 0x0a4
	static let XK_yen: UInt32 = 0x0a5
	static let XK_brokenbar: UInt32 = 0x0a6
	static let XK_section: UInt32 = 0x0a7
	static let XK_diaeresis: UInt32 = 0x0a8
	static let XK_copyright: UInt32 = 0x0a9
	static let XK_ordfeminine: UInt32 = 0x0aa
	static let XK_guillemotleft: UInt32 = 0x0ab /* left angle quotation mark */
	static let XK_notsign: UInt32 = 0x0ac
	static let XK_hyphen: UInt32 = 0x0ad
	static let XK_registered: UInt32 = 0x0ae
	static let XK_macron: UInt32 = 0x0af
	static let XK_degree: UInt32 = 0x0b0
	static let XK_plusminus: UInt32 = 0x0b1
	static let XK_twosuperior: UInt32 = 0x0b2
	static let XK_threesuperior: UInt32 = 0x0b3
	static let XK_acute: UInt32 = 0x0b4
	static let XK_mu: UInt32 = 0x0b5
	static let XK_paragraph: UInt32 = 0x0b6
	static let XK_periodcentered: UInt32 = 0x0b7
	static let XK_cedilla: UInt32 = 0x0b8
	static let XK_onesuperior: UInt32 = 0x0b9
	static let XK_masculine: UInt32 = 0x0ba
	static let XK_guillemotright: UInt32 = 0x0bb /* right angle quotation mark */
	static let XK_onequarter: UInt32 = 0x0bc
	static let XK_onehalf: UInt32 = 0x0bd
	static let XK_threequarters: UInt32 = 0x0be
	static let XK_questiondown: UInt32 = 0x0bf
	static let XK_Agrave: UInt32 = 0x0c0
	static let XK_Aacute: UInt32 = 0x0c1
	static let XK_Acircumflex: UInt32 = 0x0c2
	static let XK_Atilde: UInt32 = 0x0c3
	static let XK_Adiaeresis: UInt32 = 0x0c4
	static let XK_Aring: UInt32 = 0x0c5
	static let XK_AE: UInt32 = 0x0c6
	static let XK_Ccedilla: UInt32 = 0x0c7
	static let XK_Egrave: UInt32 = 0x0c8
	static let XK_Eacute: UInt32 = 0x0c9
	static let XK_Ecircumflex: UInt32 = 0x0ca
	static let XK_Ediaeresis: UInt32 = 0x0cb
	static let XK_Igrave: UInt32 = 0x0cc
	static let XK_Iacute: UInt32 = 0x0cd
	static let XK_Icircumflex: UInt32 = 0x0ce
	static let XK_Idiaeresis: UInt32 = 0x0cf
	static let XK_ETH: UInt32 = 0x0d0
	static let XK_Eth: UInt32 = 0x0d0 /* deprecated */
	static let XK_Ntilde: UInt32 = 0x0d1
	static let XK_Ograve: UInt32 = 0x0d2
	static let XK_Oacute: UInt32 = 0x0d3
	static let XK_Ocircumflex: UInt32 = 0x0d4
	static let XK_Otilde: UInt32 = 0x0d5
	static let XK_Odiaeresis: UInt32 = 0x0d6
	static let XK_multiply: UInt32 = 0x0d7
	static let XK_Ooblique: UInt32 = 0x0d8
	static let XK_Ugrave: UInt32 = 0x0d9
	static let XK_Uacute: UInt32 = 0x0da
	static let XK_Ucircumflex: UInt32 = 0x0db
	static let XK_Udiaeresis: UInt32 = 0x0dc
	static let XK_Yacute: UInt32 = 0x0dd
	static let XK_THORN: UInt32 = 0x0de
	static let XK_Thorn: UInt32 = 0x0de /* deprecated */
	static let XK_ssharp: UInt32 = 0x0df
	static let XK_agrave: UInt32 = 0x0e0
	static let XK_aacute: UInt32 = 0x0e1
	static let XK_acircumflex: UInt32 = 0x0e2
	static let XK_atilde: UInt32 = 0x0e3
	static let XK_adiaeresis: UInt32 = 0x0e4
	static let XK_aring: UInt32 = 0x0e5
	static let XK_ae: UInt32 = 0x0e6
	static let XK_ccedilla: UInt32 = 0x0e7
	static let XK_egrave: UInt32 = 0x0e8
	static let XK_eacute: UInt32 = 0x0e9
	static let XK_ecircumflex: UInt32 = 0x0ea
	static let XK_ediaeresis: UInt32 = 0x0eb
	static let XK_igrave: UInt32 = 0x0ec
	static let XK_iacute: UInt32 = 0x0ed
	static let XK_icircumflex: UInt32 = 0x0ee
	static let XK_idiaeresis: UInt32 = 0x0ef
	static let XK_eth: UInt32 = 0x0f0
	static let XK_ntilde: UInt32 = 0x0f1
	static let XK_ograve: UInt32 = 0x0f2
	static let XK_oacute: UInt32 = 0x0f3
	static let XK_ocircumflex: UInt32 = 0x0f4
	static let XK_otilde: UInt32 = 0x0f5
	static let XK_odiaeresis: UInt32 = 0x0f6
	static let XK_division: UInt32 = 0x0f7
	static let XK_oslash: UInt32 = 0x0f8
	static let XK_ugrave: UInt32 = 0x0f9
	static let XK_uacute: UInt32 = 0x0fa
	static let XK_ucircumflex: UInt32 = 0x0fb
	static let XK_udiaeresis: UInt32 = 0x0fc
	static let XK_yacute: UInt32 = 0x0fd
	static let XK_thorn: UInt32 = 0x0fe
	static let XK_ydiaeresis: UInt32 = 0x0ff

	/*
	 *   Latin 2
	 *   Byte 3 = 1
	 */

	static let XK_Aogonek: UInt32 = 0x1a1
	static let XK_breve: UInt32 = 0x1a2
	static let XK_Lstroke: UInt32 = 0x1a3
	static let XK_Lcaron: UInt32 = 0x1a5
	static let XK_Sacute: UInt32 = 0x1a6
	static let XK_Scaron: UInt32 = 0x1a9
	static let XK_Scedilla: UInt32 = 0x1aa
	static let XK_Tcaron: UInt32 = 0x1ab
	static let XK_Zacute: UInt32 = 0x1ac
	static let XK_Zcaron: UInt32 = 0x1ae
	static let XK_Zabovedot: UInt32 = 0x1af
	static let XK_aogonek: UInt32 = 0x1b1
	static let XK_ogonek: UInt32 = 0x1b2
	static let XK_lstroke: UInt32 = 0x1b3
	static let XK_lcaron: UInt32 = 0x1b5
	static let XK_sacute: UInt32 = 0x1b6
	static let XK_caron: UInt32 = 0x1b7
	static let XK_scaron: UInt32 = 0x1b9
	static let XK_scedilla: UInt32 = 0x1ba
	static let XK_tcaron: UInt32 = 0x1bb
	static let XK_zacute: UInt32 = 0x1bc
	static let XK_doubleacute: UInt32 = 0x1bd
	static let XK_zcaron: UInt32 = 0x1be
	static let XK_zabovedot: UInt32 = 0x1bf
	static let XK_Racute: UInt32 = 0x1c0
	static let XK_Abreve: UInt32 = 0x1c3
	static let XK_Lacute: UInt32 = 0x1c5
	static let XK_Cacute: UInt32 = 0x1c6
	static let XK_Ccaron: UInt32 = 0x1c8
	static let XK_Eogonek: UInt32 = 0x1ca
	static let XK_Ecaron: UInt32 = 0x1cc
	static let XK_Dcaron: UInt32 = 0x1cf
	static let XK_Dstroke: UInt32 = 0x1d0
	static let XK_Nacute: UInt32 = 0x1d1
	static let XK_Ncaron: UInt32 = 0x1d2
	static let XK_Odoubleacute: UInt32 = 0x1d5
	static let XK_Rcaron: UInt32 = 0x1d8
	static let XK_Uring: UInt32 = 0x1d9
	static let XK_Udoubleacute: UInt32 = 0x1db
	static let XK_Tcedilla: UInt32 = 0x1de
	static let XK_racute: UInt32 = 0x1e0
	static let XK_abreve: UInt32 = 0x1e3
	static let XK_lacute: UInt32 = 0x1e5
	static let XK_cacute: UInt32 = 0x1e6
	static let XK_ccaron: UInt32 = 0x1e8
	static let XK_eogonek: UInt32 = 0x1ea
	static let XK_ecaron: UInt32 = 0x1ec
	static let XK_dcaron: UInt32 = 0x1ef
	static let XK_dstroke: UInt32 = 0x1f0
	static let XK_nacute: UInt32 = 0x1f1
	static let XK_ncaron: UInt32 = 0x1f2
	static let XK_odoubleacute: UInt32 = 0x1f5
	static let XK_udoubleacute: UInt32 = 0x1fb
	static let XK_rcaron: UInt32 = 0x1f8
	static let XK_uring: UInt32 = 0x1f9
	static let XK_tcedilla: UInt32 = 0x1fe
	static let XK_abovedot: UInt32 = 0x1ff

	/*
	 *   Latin 3
	 *   Byte 3 = 2
	 */

	static let XK_Hstroke: UInt32 = 0x2a1
	static let XK_Hcircumflex: UInt32 = 0x2a6
	static let XK_Iabovedot: UInt32 = 0x2a9
	static let XK_Gbreve: UInt32 = 0x2ab
	static let XK_Jcircumflex: UInt32 = 0x2ac
	static let XK_hstroke: UInt32 = 0x2b1
	static let XK_hcircumflex: UInt32 = 0x2b6
	static let XK_idotless: UInt32 = 0x2b9
	static let XK_gbreve: UInt32 = 0x2bb
	static let XK_jcircumflex: UInt32 = 0x2bc
	static let XK_Cabovedot: UInt32 = 0x2c5
	static let XK_Ccircumflex: UInt32 = 0x2c6
	static let XK_Gabovedot: UInt32 = 0x2d5
	static let XK_Gcircumflex: UInt32 = 0x2d8
	static let XK_Ubreve: UInt32 = 0x2dd
	static let XK_Scircumflex: UInt32 = 0x2de
	static let XK_cabovedot: UInt32 = 0x2e5
	static let XK_ccircumflex: UInt32 = 0x2e6
	static let XK_gabovedot: UInt32 = 0x2f5
	static let XK_gcircumflex: UInt32 = 0x2f8
	static let XK_ubreve: UInt32 = 0x2fd
	static let XK_scircumflex: UInt32 = 0x2fe

	/*
	 *   Latin 4
	 *   Byte 3 = 3
	 */

	static let XK_kra: UInt32 = 0x3a2
	static let XK_kappa: UInt32 = 0x3a2 /* deprecated */
	static let XK_Rcedilla: UInt32 = 0x3a3
	static let XK_Itilde: UInt32 = 0x3a5
	static let XK_Lcedilla: UInt32 = 0x3a6
	static let XK_Emacron: UInt32 = 0x3aa
	static let XK_Gcedilla: UInt32 = 0x3ab
	static let XK_Tslash: UInt32 = 0x3ac
	static let XK_rcedilla: UInt32 = 0x3b3
	static let XK_itilde: UInt32 = 0x3b5
	static let XK_lcedilla: UInt32 = 0x3b6
	static let XK_emacron: UInt32 = 0x3ba
	static let XK_gcedilla: UInt32 = 0x3bb
	static let XK_tslash: UInt32 = 0x3bc
	static let XK_ENG: UInt32 = 0x3bd
	static let XK_eng: UInt32 = 0x3bf
	static let XK_Amacron: UInt32 = 0x3c0
	static let XK_Iogonek: UInt32 = 0x3c7
	static let XK_Eabovedot: UInt32 = 0x3cc
	static let XK_Imacron: UInt32 = 0x3cf
	static let XK_Ncedilla: UInt32 = 0x3d1
	static let XK_Omacron: UInt32 = 0x3d2
	static let XK_Kcedilla: UInt32 = 0x3d3
	static let XK_Uogonek: UInt32 = 0x3d9
	static let XK_Utilde: UInt32 = 0x3dd
	static let XK_Umacron: UInt32 = 0x3de
	static let XK_amacron: UInt32 = 0x3e0
	static let XK_iogonek: UInt32 = 0x3e7
	static let XK_eabovedot: UInt32 = 0x3ec
	static let XK_imacron: UInt32 = 0x3ef
	static let XK_ncedilla: UInt32 = 0x3f1
	static let XK_omacron: UInt32 = 0x3f2
	static let XK_kcedilla: UInt32 = 0x3f3
	static let XK_uogonek: UInt32 = 0x3f9
	static let XK_utilde: UInt32 = 0x3fd
	static let XK_umacron: UInt32 = 0x3fe

	/*
	 * Katakana
	 * Byte 3 = 4
	 */

	static let XK_overline: UInt32 = 0x47e
	static let XK_kana_fullstop: UInt32 = 0x4a1
	static let XK_kana_openingbracket: UInt32 = 0x4a2
	static let XK_kana_closingbracket: UInt32 = 0x4a3
	static let XK_kana_comma: UInt32 = 0x4a4
	static let XK_kana_conjunctive: UInt32 = 0x4a5
	static let XK_kana_middledot: UInt32 = 0x4a5 /* deprecated */
	static let XK_kana_WO: UInt32 = 0x4a6
	static let XK_kana_a: UInt32 = 0x4a7
	static let XK_kana_i: UInt32 = 0x4a8
	static let XK_kana_u: UInt32 = 0x4a9
	static let XK_kana_e: UInt32 = 0x4aa
	static let XK_kana_o: UInt32 = 0x4ab
	static let XK_kana_ya: UInt32 = 0x4ac
	static let XK_kana_yu: UInt32 = 0x4ad
	static let XK_kana_yo: UInt32 = 0x4ae
	static let XK_kana_tsu: UInt32 = 0x4af
	static let XK_kana_tu: UInt32 = 0x4af /* deprecated */
	static let XK_prolongedsound: UInt32 = 0x4b0
	static let XK_kana_A: UInt32 = 0x4b1
	static let XK_kana_I: UInt32 = 0x4b2
	static let XK_kana_U: UInt32 = 0x4b3
	static let XK_kana_E: UInt32 = 0x4b4
	static let XK_kana_O: UInt32 = 0x4b5
	static let XK_kana_KA: UInt32 = 0x4b6
	static let XK_kana_KI: UInt32 = 0x4b7
	static let XK_kana_KU: UInt32 = 0x4b8
	static let XK_kana_KE: UInt32 = 0x4b9
	static let XK_kana_KO: UInt32 = 0x4ba
	static let XK_kana_SA: UInt32 = 0x4bb
	static let XK_kana_SHI: UInt32 = 0x4bc
	static let XK_kana_SU: UInt32 = 0x4bd
	static let XK_kana_SE: UInt32 = 0x4be
	static let XK_kana_SO: UInt32 = 0x4bf
	static let XK_kana_TA: UInt32 = 0x4c0
	static let XK_kana_CHI: UInt32 = 0x4c1
	static let XK_kana_TI: UInt32 = 0x4c1 /* deprecated */
	static let XK_kana_TSU: UInt32 = 0x4c2
	static let XK_kana_TU: UInt32 = 0x4c2 /* deprecated */
	static let XK_kana_TE: UInt32 = 0x4c3
	static let XK_kana_TO: UInt32 = 0x4c4
	static let XK_kana_NA: UInt32 = 0x4c5
	static let XK_kana_NI: UInt32 = 0x4c6
	static let XK_kana_NU: UInt32 = 0x4c7
	static let XK_kana_NE: UInt32 = 0x4c8
	static let XK_kana_NO: UInt32 = 0x4c9
	static let XK_kana_HA: UInt32 = 0x4ca
	static let XK_kana_HI: UInt32 = 0x4cb
	static let XK_kana_FU: UInt32 = 0x4cc
	static let XK_kana_HU: UInt32 = 0x4cc /* deprecated */
	static let XK_kana_HE: UInt32 = 0x4cd
	static let XK_kana_HO: UInt32 = 0x4ce
	static let XK_kana_MA: UInt32 = 0x4cf
	static let XK_kana_MI: UInt32 = 0x4d0
	static let XK_kana_MU: UInt32 = 0x4d1
	static let XK_kana_ME: UInt32 = 0x4d2
	static let XK_kana_MO: UInt32 = 0x4d3
	static let XK_kana_YA: UInt32 = 0x4d4
	static let XK_kana_YU: UInt32 = 0x4d5
	static let XK_kana_YO: UInt32 = 0x4d6
	static let XK_kana_RA: UInt32 = 0x4d7
	static let XK_kana_RI: UInt32 = 0x4d8
	static let XK_kana_RU: UInt32 = 0x4d9
	static let XK_kana_RE: UInt32 = 0x4da
	static let XK_kana_RO: UInt32 = 0x4db
	static let XK_kana_WA: UInt32 = 0x4dc
	static let XK_kana_N: UInt32 = 0x4dd
	static let XK_voicedsound: UInt32 = 0x4de
	static let XK_semivoicedsound: UInt32 = 0x4df
	static let XK_kana_switch: UInt32 = 0xFF7E /* Alias for mode_switch */

	/*
	 *  Arabic
	 *  Byte 3 = 5
	 */

	static let XK_Arabic_comma: UInt32 = 0x5ac
	static let XK_Arabic_semicolon: UInt32 = 0x5bb
	static let XK_Arabic_question_mark: UInt32 = 0x5bf
	static let XK_Arabic_hamza: UInt32 = 0x5c1
	static let XK_Arabic_maddaonalef: UInt32 = 0x5c2
	static let XK_Arabic_hamzaonalef: UInt32 = 0x5c3
	static let XK_Arabic_hamzaonwaw: UInt32 = 0x5c4
	static let XK_Arabic_hamzaunderalef: UInt32 = 0x5c5
	static let XK_Arabic_hamzaonyeh: UInt32 = 0x5c6
	static let XK_Arabic_alef: UInt32 = 0x5c7
	static let XK_Arabic_beh: UInt32 = 0x5c8
	static let XK_Arabic_tehmarbuta: UInt32 = 0x5c9
	static let XK_Arabic_teh: UInt32 = 0x5ca
	static let XK_Arabic_theh: UInt32 = 0x5cb
	static let XK_Arabic_jeem: UInt32 = 0x5cc
	static let XK_Arabic_hah: UInt32 = 0x5cd
	static let XK_Arabic_khah: UInt32 = 0x5ce
	static let XK_Arabic_dal: UInt32 = 0x5cf
	static let XK_Arabic_thal: UInt32 = 0x5d0
	static let XK_Arabic_ra: UInt32 = 0x5d1
	static let XK_Arabic_zain: UInt32 = 0x5d2
	static let XK_Arabic_seen: UInt32 = 0x5d3
	static let XK_Arabic_sheen: UInt32 = 0x5d4
	static let XK_Arabic_sad: UInt32 = 0x5d5
	static let XK_Arabic_dad: UInt32 = 0x5d6
	static let XK_Arabic_tah: UInt32 = 0x5d7
	static let XK_Arabic_zah: UInt32 = 0x5d8
	static let XK_Arabic_ain: UInt32 = 0x5d9
	static let XK_Arabic_ghain: UInt32 = 0x5da
	static let XK_Arabic_tatweel: UInt32 = 0x5e0
	static let XK_Arabic_feh: UInt32 = 0x5e1
	static let XK_Arabic_qaf: UInt32 = 0x5e2
	static let XK_Arabic_kaf: UInt32 = 0x5e3
	static let XK_Arabic_lam: UInt32 = 0x5e4
	static let XK_Arabic_meem: UInt32 = 0x5e5
	static let XK_Arabic_noon: UInt32 = 0x5e6
	static let XK_Arabic_ha: UInt32 = 0x5e7
	static let XK_Arabic_heh: UInt32 = 0x5e7 /* deprecated */
	static let XK_Arabic_waw: UInt32 = 0x5e8
	static let XK_Arabic_alefmaksura: UInt32 = 0x5e9
	static let XK_Arabic_yeh: UInt32 = 0x5ea
	static let XK_Arabic_fathatan: UInt32 = 0x5eb
	static let XK_Arabic_dammatan: UInt32 = 0x5ec
	static let XK_Arabic_kasratan: UInt32 = 0x5ed
	static let XK_Arabic_fatha: UInt32 = 0x5ee
	static let XK_Arabic_damma: UInt32 = 0x5ef
	static let XK_Arabic_kasra: UInt32 = 0x5f0
	static let XK_Arabic_shadda: UInt32 = 0x5f1
	static let XK_Arabic_sukun: UInt32 = 0x5f2
	static let XK_Arabic_switch: UInt32 = 0xFF7E /* Alias for mode_switch */

	/*
	 * Cyrillic
	 * Byte 3 = 6
	 */
	static let XK_Serbian_dje: UInt32 = 0x6a1
	static let XK_Macedonia_gje: UInt32 = 0x6a2
	static let XK_Cyrillic_io: UInt32 = 0x6a3
	static let XK_Ukrainian_ie: UInt32 = 0x6a4
	static let XK_Ukranian_je: UInt32 = 0x6a4 /* deprecated */
	static let XK_Macedonia_dse: UInt32 = 0x6a5
	static let XK_Ukrainian_i: UInt32 = 0x6a6
	static let XK_Ukranian_i: UInt32 = 0x6a6 /* deprecated */
	static let XK_Ukrainian_yi: UInt32 = 0x6a7
	static let XK_Ukranian_yi: UInt32 = 0x6a7 /* deprecated */
	static let XK_Cyrillic_je: UInt32 = 0x6a8
	static let XK_Serbian_je: UInt32 = 0x6a8 /* deprecated */
	static let XK_Cyrillic_lje: UInt32 = 0x6a9
	static let XK_Serbian_lje: UInt32 = 0x6a9 /* deprecated */
	static let XK_Cyrillic_nje: UInt32 = 0x6aa
	static let XK_Serbian_nje: UInt32 = 0x6aa /* deprecated */
	static let XK_Serbian_tshe: UInt32 = 0x6ab
	static let XK_Macedonia_kje: UInt32 = 0x6ac
	static let XK_Byelorussian_shortu: UInt32 = 0x6ae
	static let XK_Cyrillic_dzhe: UInt32 = 0x6af
	static let XK_Serbian_dze: UInt32 = 0x6af /* deprecated */
	static let XK_numerosign: UInt32 = 0x6b0
	static let XK_Serbian_DJE: UInt32 = 0x6b1
	static let XK_Macedonia_GJE: UInt32 = 0x6b2
	static let XK_Cyrillic_IO: UInt32 = 0x6b3
	static let XK_Ukrainian_IE: UInt32 = 0x6b4
	static let XK_Ukranian_JE: UInt32 = 0x6b4 /* deprecated */
	static let XK_Macedonia_DSE: UInt32 = 0x6b5
	static let XK_Ukrainian_I: UInt32 = 0x6b6
	static let XK_Ukranian_I: UInt32 = 0x6b6 /* deprecated */
	static let XK_Ukrainian_YI: UInt32 = 0x6b7
	static let XK_Ukranian_YI: UInt32 = 0x6b7 /* deprecated */
	static let XK_Cyrillic_JE: UInt32 = 0x6b8
	static let XK_Serbian_JE: UInt32 = 0x6b8 /* deprecated */
	static let XK_Cyrillic_LJE: UInt32 = 0x6b9
	static let XK_Serbian_LJE: UInt32 = 0x6b9 /* deprecated */
	static let XK_Cyrillic_NJE: UInt32 = 0x6ba
	static let XK_Serbian_NJE: UInt32 = 0x6ba /* deprecated */
	static let XK_Serbian_TSHE: UInt32 = 0x6bb
	static let XK_Macedonia_KJE: UInt32 = 0x6bc
	static let XK_Byelorussian_SHORTU: UInt32 = 0x6be
	static let XK_Cyrillic_DZHE: UInt32 = 0x6bf
	static let XK_Serbian_DZE: UInt32 = 0x6bf /* deprecated */
	static let XK_Cyrillic_yu: UInt32 = 0x6c0
	static let XK_Cyrillic_a: UInt32 = 0x6c1
	static let XK_Cyrillic_be: UInt32 = 0x6c2
	static let XK_Cyrillic_tse: UInt32 = 0x6c3
	static let XK_Cyrillic_de: UInt32 = 0x6c4
	static let XK_Cyrillic_ie: UInt32 = 0x6c5
	static let XK_Cyrillic_ef: UInt32 = 0x6c6
	static let XK_Cyrillic_ghe: UInt32 = 0x6c7
	static let XK_Cyrillic_ha: UInt32 = 0x6c8
	static let XK_Cyrillic_i: UInt32 = 0x6c9
	static let XK_Cyrillic_shorti: UInt32 = 0x6ca
	static let XK_Cyrillic_ka: UInt32 = 0x6cb
	static let XK_Cyrillic_el: UInt32 = 0x6cc
	static let XK_Cyrillic_em: UInt32 = 0x6cd
	static let XK_Cyrillic_en: UInt32 = 0x6ce
	static let XK_Cyrillic_o: UInt32 = 0x6cf
	static let XK_Cyrillic_pe: UInt32 = 0x6d0
	static let XK_Cyrillic_ya: UInt32 = 0x6d1
	static let XK_Cyrillic_er: UInt32 = 0x6d2
	static let XK_Cyrillic_es: UInt32 = 0x6d3
	static let XK_Cyrillic_te: UInt32 = 0x6d4
	static let XK_Cyrillic_u: UInt32 = 0x6d5
	static let XK_Cyrillic_zhe: UInt32 = 0x6d6
	static let XK_Cyrillic_ve: UInt32 = 0x6d7
	static let XK_Cyrillic_softsign: UInt32 = 0x6d8
	static let XK_Cyrillic_yeru: UInt32 = 0x6d9
	static let XK_Cyrillic_ze: UInt32 = 0x6da
	static let XK_Cyrillic_sha: UInt32 = 0x6db
	static let XK_Cyrillic_e: UInt32 = 0x6dc
	static let XK_Cyrillic_shcha: UInt32 = 0x6dd
	static let XK_Cyrillic_che: UInt32 = 0x6de
	static let XK_Cyrillic_hardsign: UInt32 = 0x6df
	static let XK_Cyrillic_YU: UInt32 = 0x6e0
	static let XK_Cyrillic_A: UInt32 = 0x6e1
	static let XK_Cyrillic_BE: UInt32 = 0x6e2
	static let XK_Cyrillic_TSE: UInt32 = 0x6e3
	static let XK_Cyrillic_DE: UInt32 = 0x6e4
	static let XK_Cyrillic_IE: UInt32 = 0x6e5
	static let XK_Cyrillic_EF: UInt32 = 0x6e6
	static let XK_Cyrillic_GHE: UInt32 = 0x6e7
	static let XK_Cyrillic_HA: UInt32 = 0x6e8
	static let XK_Cyrillic_I: UInt32 = 0x6e9
	static let XK_Cyrillic_SHORTI: UInt32 = 0x6ea
	static let XK_Cyrillic_KA: UInt32 = 0x6eb
	static let XK_Cyrillic_EL: UInt32 = 0x6ec
	static let XK_Cyrillic_EM: UInt32 = 0x6ed
	static let XK_Cyrillic_EN: UInt32 = 0x6ee
	static let XK_Cyrillic_O: UInt32 = 0x6ef
	static let XK_Cyrillic_PE: UInt32 = 0x6f0
	static let XK_Cyrillic_YA: UInt32 = 0x6f1
	static let XK_Cyrillic_ER: UInt32 = 0x6f2
	static let XK_Cyrillic_ES: UInt32 = 0x6f3
	static let XK_Cyrillic_TE: UInt32 = 0x6f4
	static let XK_Cyrillic_U: UInt32 = 0x6f5
	static let XK_Cyrillic_ZHE: UInt32 = 0x6f6
	static let XK_Cyrillic_VE: UInt32 = 0x6f7
	static let XK_Cyrillic_SOFTSIGN: UInt32 = 0x6f8
	static let XK_Cyrillic_YERU: UInt32 = 0x6f9
	static let XK_Cyrillic_ZE: UInt32 = 0x6fa
	static let XK_Cyrillic_SHA: UInt32 = 0x6fb
	static let XK_Cyrillic_E: UInt32 = 0x6fc
	static let XK_Cyrillic_SHCHA: UInt32 = 0x6fd
	static let XK_Cyrillic_CHE: UInt32 = 0x6fe
	static let XK_Cyrillic_HARDSIGN: UInt32 = 0x6ff

	/*
	 * Greek
	 * Byte 3 = 7
	 */

	static let XK_Greek_ALPHAaccent: UInt32 = 0x7a1
	static let XK_Greek_EPSILONaccent: UInt32 = 0x7a2
	static let XK_Greek_ETAaccent: UInt32 = 0x7a3
	static let XK_Greek_IOTAaccent: UInt32 = 0x7a4
	static let XK_Greek_IOTAdieresis: UInt32 = 0x7a5
	static let XK_Greek_OMICRONaccent: UInt32 = 0x7a7
	static let XK_Greek_UPSILONaccent: UInt32 = 0x7a8
	static let XK_Greek_UPSILONdieresis: UInt32 = 0x7a9
	static let XK_Greek_OMEGAaccent: UInt32 = 0x7ab
	static let XK_Greek_accentdieresis: UInt32 = 0x7ae
	static let XK_Greek_horizbar: UInt32 = 0x7af
	static let XK_Greek_alphaaccent: UInt32 = 0x7b1
	static let XK_Greek_epsilonaccent: UInt32 = 0x7b2
	static let XK_Greek_etaaccent: UInt32 = 0x7b3
	static let XK_Greek_iotaaccent: UInt32 = 0x7b4
	static let XK_Greek_iotadieresis: UInt32 = 0x7b5
	static let XK_Greek_iotaaccentdieresis: UInt32 = 0x7b6
	static let XK_Greek_omicronaccent: UInt32 = 0x7b7
	static let XK_Greek_upsilonaccent: UInt32 = 0x7b8
	static let XK_Greek_upsilondieresis: UInt32 = 0x7b9
	static let XK_Greek_upsilonaccentdieresis: UInt32 = 0x7ba
	static let XK_Greek_omegaaccent: UInt32 = 0x7bb
	static let XK_Greek_ALPHA: UInt32 = 0x7c1
	static let XK_Greek_BETA: UInt32 = 0x7c2
	static let XK_Greek_GAMMA: UInt32 = 0x7c3
	static let XK_Greek_DELTA: UInt32 = 0x7c4
	static let XK_Greek_EPSILON: UInt32 = 0x7c5
	static let XK_Greek_ZETA: UInt32 = 0x7c6
	static let XK_Greek_ETA: UInt32 = 0x7c7
	static let XK_Greek_THETA: UInt32 = 0x7c8
	static let XK_Greek_IOTA: UInt32 = 0x7c9
	static let XK_Greek_KAPPA: UInt32 = 0x7ca
	static let XK_Greek_LAMDA: UInt32 = 0x7cb
	static let XK_Greek_LAMBDA: UInt32 = 0x7cb
	static let XK_Greek_MU: UInt32 = 0x7cc
	static let XK_Greek_NU: UInt32 = 0x7cd
	static let XK_Greek_XI: UInt32 = 0x7ce
	static let XK_Greek_OMICRON: UInt32 = 0x7cf
	static let XK_Greek_PI: UInt32 = 0x7d0
	static let XK_Greek_RHO: UInt32 = 0x7d1
	static let XK_Greek_SIGMA: UInt32 = 0x7d2
	static let XK_Greek_TAU: UInt32 = 0x7d4
	static let XK_Greek_UPSILON: UInt32 = 0x7d5
	static let XK_Greek_PHI: UInt32 = 0x7d6
	static let XK_Greek_CHI: UInt32 = 0x7d7
	static let XK_Greek_PSI: UInt32 = 0x7d8
	static let XK_Greek_OMEGA: UInt32 = 0x7d9
	static let XK_Greek_alpha: UInt32 = 0x7e1
	static let XK_Greek_beta: UInt32 = 0x7e2
	static let XK_Greek_gamma: UInt32 = 0x7e3
	static let XK_Greek_delta: UInt32 = 0x7e4
	static let XK_Greek_epsilon: UInt32 = 0x7e5
	static let XK_Greek_zeta: UInt32 = 0x7e6
	static let XK_Greek_eta: UInt32 = 0x7e7
	static let XK_Greek_theta: UInt32 = 0x7e8
	static let XK_Greek_iota: UInt32 = 0x7e9
	static let XK_Greek_kappa: UInt32 = 0x7ea
	static let XK_Greek_lamda: UInt32 = 0x7eb
	static let XK_Greek_lambda: UInt32 = 0x7eb
	static let XK_Greek_mu: UInt32 = 0x7ec
	static let XK_Greek_nu: UInt32 = 0x7ed
	static let XK_Greek_xi: UInt32 = 0x7ee
	static let XK_Greek_omicron: UInt32 = 0x7ef
	static let XK_Greek_pi: UInt32 = 0x7f0
	static let XK_Greek_rho: UInt32 = 0x7f1
	static let XK_Greek_sigma: UInt32 = 0x7f2
	static let XK_Greek_finalsmallsigma: UInt32 = 0x7f3
	static let XK_Greek_tau: UInt32 = 0x7f4
	static let XK_Greek_upsilon: UInt32 = 0x7f5
	static let XK_Greek_phi: UInt32 = 0x7f6
	static let XK_Greek_chi: UInt32 = 0x7f7
	static let XK_Greek_psi: UInt32 = 0x7f8
	static let XK_Greek_omega: UInt32 = 0x7f9
	static let XK_Greek_switch: UInt32 = 0xFF7E /* Alias for mode_switch */

	/*
	 * Technical
	 * Byte 3 = 8
	 */

	static let XK_leftradical: UInt32 = 0x8a1
	static let XK_topleftradical: UInt32 = 0x8a2
	static let XK_horizconnector: UInt32 = 0x8a3
	static let XK_topintegral: UInt32 = 0x8a4
	static let XK_botintegral: UInt32 = 0x8a5
	static let XK_vertconnector: UInt32 = 0x8a6
	static let XK_topleftsqbracket: UInt32 = 0x8a7
	static let XK_botleftsqbracket: UInt32 = 0x8a8
	static let XK_toprightsqbracket: UInt32 = 0x8a9
	static let XK_botrightsqbracket: UInt32 = 0x8aa
	static let XK_topleftparens: UInt32 = 0x8ab
	static let XK_botleftparens: UInt32 = 0x8ac
	static let XK_toprightparens: UInt32 = 0x8ad
	static let XK_botrightparens: UInt32 = 0x8ae
	static let XK_leftmiddlecurlybrace: UInt32 = 0x8af
	static let XK_rightmiddlecurlybrace: UInt32 = 0x8b0
	static let XK_topleftsummation: UInt32 = 0x8b1
	static let XK_botleftsummation: UInt32 = 0x8b2
	static let XK_topvertsummationconnector: UInt32 = 0x8b3
	static let XK_botvertsummationconnector: UInt32 = 0x8b4
	static let XK_toprightsummation: UInt32 = 0x8b5
	static let XK_botrightsummation: UInt32 = 0x8b6
	static let XK_rightmiddlesummation: UInt32 = 0x8b7
	static let XK_lessthanequal: UInt32 = 0x8bc
	static let XK_notequal: UInt32 = 0x8bd
	static let XK_greaterthanequal: UInt32 = 0x8be
	static let XK_integral: UInt32 = 0x8bf
	static let XK_therefore: UInt32 = 0x8c0
	static let XK_variation: UInt32 = 0x8c1
	static let XK_infinity: UInt32 = 0x8c2
	static let XK_nabla: UInt32 = 0x8c5
	static let XK_approximate: UInt32 = 0x8c8
	static let XK_similarequal: UInt32 = 0x8c9
	static let XK_ifonlyif: UInt32 = 0x8cd
	static let XK_implies: UInt32 = 0x8ce
	static let XK_identical: UInt32 = 0x8cf
	static let XK_radical: UInt32 = 0x8d6
	static let XK_includedin: UInt32 = 0x8da
	static let XK_includes: UInt32 = 0x8db
	static let XK_intersection: UInt32 = 0x8dc
	static let XK_union: UInt32 = 0x8dd
	static let XK_logicaland: UInt32 = 0x8de
	static let XK_logicalor: UInt32 = 0x8df
	static let XK_partialderivative: UInt32 = 0x8ef
	static let XK_function: UInt32 = 0x8f6
	static let XK_leftarrow: UInt32 = 0x8fb
	static let XK_uparrow: UInt32 = 0x8fc
	static let XK_rightarrow: UInt32 = 0x8fd
	static let XK_downarrow: UInt32 = 0x8fe

	/*
	 *  Special
	 *  Byte 3 = 9
	 */

	static let XK_blank: UInt32 = 0x9df
	static let XK_soliddiamond: UInt32 = 0x9e0
	static let XK_checkerboard: UInt32 = 0x9e1
	static let XK_ht: UInt32 = 0x9e2
	static let XK_ff: UInt32 = 0x9e3
	static let XK_cr: UInt32 = 0x9e4
	static let XK_lf: UInt32 = 0x9e5
	static let XK_nl: UInt32 = 0x9e8
	static let XK_vt: UInt32 = 0x9e9
	static let XK_lowrightcorner: UInt32 = 0x9ea
	static let XK_uprightcorner: UInt32 = 0x9eb
	static let XK_upleftcorner: UInt32 = 0x9ec
	static let XK_lowleftcorner: UInt32 = 0x9ed
	static let XK_crossinglines: UInt32 = 0x9ee
	static let XK_horizlinescan1: UInt32 = 0x9ef
	static let XK_horizlinescan3: UInt32 = 0x9f0
	static let XK_horizlinescan5: UInt32 = 0x9f1
	static let XK_horizlinescan7: UInt32 = 0x9f2
	static let XK_horizlinescan9: UInt32 = 0x9f3
	static let XK_leftt: UInt32 = 0x9f4
	static let XK_rightt: UInt32 = 0x9f5
	static let XK_bott: UInt32 = 0x9f6
	static let XK_topt: UInt32 = 0x9f7
	static let XK_vertbar: UInt32 = 0x9f8

	/*
	 *  Publishing
	 *  Byte 3 = a
	 */

	static let XK_emspace: UInt32 = 0xaa1
	static let XK_enspace: UInt32 = 0xaa2
	static let XK_em3space: UInt32 = 0xaa3
	static let XK_em4space: UInt32 = 0xaa4
	static let XK_digitspace: UInt32 = 0xaa5
	static let XK_punctspace: UInt32 = 0xaa6
	static let XK_thinspace: UInt32 = 0xaa7
	static let XK_hairspace: UInt32 = 0xaa8
	static let XK_emdash: UInt32 = 0xaa9
	static let XK_endash: UInt32 = 0xaaa
	static let XK_signifblank: UInt32 = 0xaac
	static let XK_ellipsis: UInt32 = 0xaae
	static let XK_doubbaselinedot: UInt32 = 0xaaf
	static let XK_onethird: UInt32 = 0xab0
	static let XK_twothirds: UInt32 = 0xab1
	static let XK_onefifth: UInt32 = 0xab2
	static let XK_twofifths: UInt32 = 0xab3
	static let XK_threefifths: UInt32 = 0xab4
	static let XK_fourfifths: UInt32 = 0xab5
	static let XK_onesixth: UInt32 = 0xab6
	static let XK_fivesixths: UInt32 = 0xab7
	static let XK_careof: UInt32 = 0xab8
	static let XK_figdash: UInt32 = 0xabb
	static let XK_leftanglebracket: UInt32 = 0xabc
	static let XK_decimalpoint: UInt32 = 0xabd
	static let XK_rightanglebracket: UInt32 = 0xabe
	static let XK_marker: UInt32 = 0xabf
	static let XK_oneeighth: UInt32 = 0xac3
	static let XK_threeeighths: UInt32 = 0xac4
	static let XK_fiveeighths: UInt32 = 0xac5
	static let XK_seveneighths: UInt32 = 0xac6
	static let XK_trademark: UInt32 = 0xac9
	static let XK_signaturemark: UInt32 = 0xaca
	static let XK_trademarkincircle: UInt32 = 0xacb
	static let XK_leftopentriangle: UInt32 = 0xacc
	static let XK_rightopentriangle: UInt32 = 0xacd
	static let XK_emopencircle: UInt32 = 0xace
	static let XK_emopenrectangle: UInt32 = 0xacf
	static let XK_leftsinglequotemark: UInt32 = 0xad0
	static let XK_rightsinglequotemark: UInt32 = 0xad1
	static let XK_leftdoublequotemark: UInt32 = 0xad2
	static let XK_rightdoublequotemark: UInt32 = 0xad3
	static let XK_prescription: UInt32 = 0xad4
	static let XK_minutes: UInt32 = 0xad6
	static let XK_seconds: UInt32 = 0xad7
	static let XK_latincross: UInt32 = 0xad9
	static let XK_hexagram: UInt32 = 0xada
	static let XK_filledrectbullet: UInt32 = 0xadb
	static let XK_filledlefttribullet: UInt32 = 0xadc
	static let XK_filledrighttribullet: UInt32 = 0xadd
	static let XK_emfilledcircle: UInt32 = 0xade
	static let XK_emfilledrect: UInt32 = 0xadf
	static let XK_enopencircbullet: UInt32 = 0xae0
	static let XK_enopensquarebullet: UInt32 = 0xae1
	static let XK_openrectbullet: UInt32 = 0xae2
	static let XK_opentribulletup: UInt32 = 0xae3
	static let XK_opentribulletdown: UInt32 = 0xae4
	static let XK_openstar: UInt32 = 0xae5
	static let XK_enfilledcircbullet: UInt32 = 0xae6
	static let XK_enfilledsqbullet: UInt32 = 0xae7
	static let XK_filledtribulletup: UInt32 = 0xae8
	static let XK_filledtribulletdown: UInt32 = 0xae9
	static let XK_leftpointer: UInt32 = 0xaea
	static let XK_rightpointer: UInt32 = 0xaeb
	static let XK_club: UInt32 = 0xaec
	static let XK_diamond: UInt32 = 0xaed
	static let XK_heart: UInt32 = 0xaee
	static let XK_maltesecross: UInt32 = 0xaf0
	static let XK_dagger: UInt32 = 0xaf1
	static let XK_doubledagger: UInt32 = 0xaf2
	static let XK_checkmark: UInt32 = 0xaf3
	static let XK_ballotcross: UInt32 = 0xaf4
	static let XK_musicalsharp: UInt32 = 0xaf5
	static let XK_musicalflat: UInt32 = 0xaf6
	static let XK_malesymbol: UInt32 = 0xaf7
	static let XK_femalesymbol: UInt32 = 0xaf8
	static let XK_telephone: UInt32 = 0xaf9
	static let XK_telephonerecorder: UInt32 = 0xafa
	static let XK_phonographcopyright: UInt32 = 0xafb
	static let XK_caret: UInt32 = 0xafc
	static let XK_singlelowquotemark: UInt32 = 0xafd
	static let XK_doublelowquotemark: UInt32 = 0xafe
	static let XK_cursor: UInt32 = 0xaff

	/*
	 *  APL
	 *  Byte 3 = b
	 */

	static let XK_leftcaret: UInt32 = 0xba3
	static let XK_rightcaret: UInt32 = 0xba6
	static let XK_downcaret: UInt32 = 0xba8
	static let XK_upcaret: UInt32 = 0xba9
	static let XK_overbar: UInt32 = 0xbc0
	static let XK_downtack: UInt32 = 0xbc2
	static let XK_upshoe: UInt32 = 0xbc3
	static let XK_downstile: UInt32 = 0xbc4
	static let XK_underbar: UInt32 = 0xbc6
	static let XK_jot: UInt32 = 0xbca
	static let XK_quad: UInt32 = 0xbcc
	static let XK_uptack: UInt32 = 0xbce
	static let XK_circle: UInt32 = 0xbcf
	static let XK_upstile: UInt32 = 0xbd3
	static let XK_downshoe: UInt32 = 0xbd6
	static let XK_rightshoe: UInt32 = 0xbd8
	static let XK_leftshoe: UInt32 = 0xbda
	static let XK_lefttack: UInt32 = 0xbdc
	static let XK_righttack: UInt32 = 0xbfc

	/*
	 * Hebrew
	 * Byte 3 = c
	 */

	static let XK_hebrew_doublelowline: UInt32 = 0xcdf
	static let XK_hebrew_aleph: UInt32 = 0xce0
	static let XK_hebrew_bet: UInt32 = 0xce1
	static let XK_hebrew_beth: UInt32 = 0xce1 /* deprecated */
	static let XK_hebrew_gimel: UInt32 = 0xce2
	static let XK_hebrew_gimmel: UInt32 = 0xce2 /* deprecated */
	static let XK_hebrew_dalet: UInt32 = 0xce3
	static let XK_hebrew_daleth: UInt32 = 0xce3 /* deprecated */
	static let XK_hebrew_he: UInt32 = 0xce4
	static let XK_hebrew_waw: UInt32 = 0xce5
	static let XK_hebrew_zain: UInt32 = 0xce6
	static let XK_hebrew_zayin: UInt32 = 0xce6 /* deprecated */
	static let XK_hebrew_chet: UInt32 = 0xce7
	static let XK_hebrew_het: UInt32 = 0xce7 /* deprecated */
	static let XK_hebrew_tet: UInt32 = 0xce8
	static let XK_hebrew_teth: UInt32 = 0xce8 /* deprecated */
	static let XK_hebrew_yod: UInt32 = 0xce9
	static let XK_hebrew_finalkaph: UInt32 = 0xcea
	static let XK_hebrew_kaph: UInt32 = 0xceb
	static let XK_hebrew_lamed: UInt32 = 0xcec
	static let XK_hebrew_finalmem: UInt32 = 0xced
	static let XK_hebrew_mem: UInt32 = 0xcee
	static let XK_hebrew_finalnun: UInt32 = 0xcef
	static let XK_hebrew_nun: UInt32 = 0xcf0
	static let XK_hebrew_samech: UInt32 = 0xcf1
	static let XK_hebrew_samekh: UInt32 = 0xcf1 /* deprecated */
	static let XK_hebrew_ayin: UInt32 = 0xcf2
	static let XK_hebrew_finalpe: UInt32 = 0xcf3
	static let XK_hebrew_pe: UInt32 = 0xcf4
	static let XK_hebrew_finalzade: UInt32 = 0xcf5
	static let XK_hebrew_finalzadi: UInt32 = 0xcf5 /* deprecated */
	static let XK_hebrew_zade: UInt32 = 0xcf6
	static let XK_hebrew_zadi: UInt32 = 0xcf6 /* deprecated */
	static let XK_hebrew_qoph: UInt32 = 0xcf7
	static let XK_hebrew_kuf: UInt32 = 0xcf7 /* deprecated */
	static let XK_hebrew_resh: UInt32 = 0xcf8
	static let XK_hebrew_shin: UInt32 = 0xcf9
	static let XK_hebrew_taw: UInt32 = 0xcfa
	static let XK_hebrew_taf: UInt32 = 0xcfa /* deprecated */
	static let XK_Hebrew_switch: UInt32 = 0xFF7E /* Alias for mode_switch */

	/*
	 * Thai
	 * Byte 3 = d
	 */

	static let XK_Thai_kokai: UInt32 = 0xda1
	static let XK_Thai_khokhai: UInt32 = 0xda2
	static let XK_Thai_khokhuat: UInt32 = 0xda3
	static let XK_Thai_khokhwai: UInt32 = 0xda4
	static let XK_Thai_khokhon: UInt32 = 0xda5
	static let XK_Thai_khorakhang: UInt32 = 0xda6
	static let XK_Thai_ngongu: UInt32 = 0xda7
	static let XK_Thai_chochan: UInt32 = 0xda8
	static let XK_Thai_choching: UInt32 = 0xda9
	static let XK_Thai_chochang: UInt32 = 0xdaa
	static let XK_Thai_soso: UInt32 = 0xdab
	static let XK_Thai_chochoe: UInt32 = 0xdac
	static let XK_Thai_yoying: UInt32 = 0xdad
	static let XK_Thai_dochada: UInt32 = 0xdae
	static let XK_Thai_topatak: UInt32 = 0xdaf
	static let XK_Thai_thothan: UInt32 = 0xdb0
	static let XK_Thai_thonangmontho: UInt32 = 0xdb1
	static let XK_Thai_thophuthao: UInt32 = 0xdb2
	static let XK_Thai_nonen: UInt32 = 0xdb3
	static let XK_Thai_dodek: UInt32 = 0xdb4
	static let XK_Thai_totao: UInt32 = 0xdb5
	static let XK_Thai_thothung: UInt32 = 0xdb6
	static let XK_Thai_thothahan: UInt32 = 0xdb7
	static let XK_Thai_thothong: UInt32 = 0xdb8
	static let XK_Thai_nonu: UInt32 = 0xdb9
	static let XK_Thai_bobaimai: UInt32 = 0xdba
	static let XK_Thai_popla: UInt32 = 0xdbb
	static let XK_Thai_phophung: UInt32 = 0xdbc
	static let XK_Thai_fofa: UInt32 = 0xdbd
	static let XK_Thai_phophan: UInt32 = 0xdbe
	static let XK_Thai_fofan: UInt32 = 0xdbf
	static let XK_Thai_phosamphao: UInt32 = 0xdc0
	static let XK_Thai_moma: UInt32 = 0xdc1
	static let XK_Thai_yoyak: UInt32 = 0xdc2
	static let XK_Thai_rorua: UInt32 = 0xdc3
	static let XK_Thai_ru: UInt32 = 0xdc4
	static let XK_Thai_loling: UInt32 = 0xdc5
	static let XK_Thai_lu: UInt32 = 0xdc6
	static let XK_Thai_wowaen: UInt32 = 0xdc7
	static let XK_Thai_sosala: UInt32 = 0xdc8
	static let XK_Thai_sorusi: UInt32 = 0xdc9
	static let XK_Thai_sosua: UInt32 = 0xdca
	static let XK_Thai_hohip: UInt32 = 0xdcb
	static let XK_Thai_lochula: UInt32 = 0xdcc
	static let XK_Thai_oang: UInt32 = 0xdcd
	static let XK_Thai_honokhuk: UInt32 = 0xdce
	static let XK_Thai_paiyannoi: UInt32 = 0xdcf
	static let XK_Thai_saraa: UInt32 = 0xdd0
	static let XK_Thai_maihanakat: UInt32 = 0xdd1
	static let XK_Thai_saraaa: UInt32 = 0xdd2
	static let XK_Thai_saraam: UInt32 = 0xdd3
	static let XK_Thai_sarai: UInt32 = 0xdd4
	static let XK_Thai_saraii: UInt32 = 0xdd5
	static let XK_Thai_saraue: UInt32 = 0xdd6
	static let XK_Thai_sarauee: UInt32 = 0xdd7
	static let XK_Thai_sarau: UInt32 = 0xdd8
	static let XK_Thai_sarauu: UInt32 = 0xdd9
	static let XK_Thai_phinthu: UInt32 = 0xdda
	static let XK_Thai_maihanakat_maitho: UInt32 = 0xdde
	static let XK_Thai_baht: UInt32 = 0xddf
	static let XK_Thai_sarae: UInt32 = 0xde0
	static let XK_Thai_saraae: UInt32 = 0xde1
	static let XK_Thai_sarao: UInt32 = 0xde2
	static let XK_Thai_saraaimaimuan: UInt32 = 0xde3
	static let XK_Thai_saraaimaimalai: UInt32 = 0xde4
	static let XK_Thai_lakkhangyao: UInt32 = 0xde5
	static let XK_Thai_maiyamok: UInt32 = 0xde6
	static let XK_Thai_maitaikhu: UInt32 = 0xde7
	static let XK_Thai_maiek: UInt32 = 0xde8
	static let XK_Thai_maitho: UInt32 = 0xde9
	static let XK_Thai_maitri: UInt32 = 0xdea
	static let XK_Thai_maichattawa: UInt32 = 0xdeb
	static let XK_Thai_thanthakhat: UInt32 = 0xdec
	static let XK_Thai_nikhahit: UInt32 = 0xded
	static let XK_Thai_leksun: UInt32 = 0xdf0
	static let XK_Thai_leknung: UInt32 = 0xdf1
	static let XK_Thai_leksong: UInt32 = 0xdf2
	static let XK_Thai_leksam: UInt32 = 0xdf3
	static let XK_Thai_leksi: UInt32 = 0xdf4
	static let XK_Thai_lekha: UInt32 = 0xdf5
	static let XK_Thai_lekhok: UInt32 = 0xdf6
	static let XK_Thai_lekchet: UInt32 = 0xdf7
	static let XK_Thai_lekpaet: UInt32 = 0xdf8
	static let XK_Thai_lekkao: UInt32 = 0xdf9

	/*
	 *   Korean
	 *   Byte 3 = e
	 */
	static let XK_Hangul: UInt32 = 0xff31 /* Hangul start/stop(toggle) */
	static let XK_Hangul_Start: UInt32 = 0xff32 /* Hangul start */
	static let XK_Hangul_End: UInt32 = 0xff33 /* Hangul end, English start */
	static let XK_Hangul_Hanja: UInt32 = 0xff34 /* Start Hangul->Hanja Conversion */
	static let XK_Hangul_Jamo: UInt32 = 0xff35 /* Hangul Jamo mode */
	static let XK_Hangul_Romaja: UInt32 = 0xff36 /* Hangul Romaja mode */
	static let XK_Hangul_Codeinput: UInt32 = 0xff37 /* Hangul code input mode */
	static let XK_Hangul_Jeonja: UInt32 = 0xff38 /* Jeonja mode */
	static let XK_Hangul_Banja: UInt32 = 0xff39 /* Banja mode */
	static let XK_Hangul_PreHanja: UInt32 = 0xff3a /* Pre Hanja conversion */
	static let XK_Hangul_PostHanja: UInt32 = 0xff3b /* Post Hanja conversion */
	static let XK_Hangul_SingleCandidate: UInt32 = 0xff3c /* Single candidate */
	static let XK_Hangul_MultipleCandidate: UInt32 = 0xff3d /* Multiple candidate */
	static let XK_Hangul_PreviousCandidate: UInt32 = 0xff3e /* Previous candidate */
	static let XK_Hangul_Special: UInt32 = 0xff3f /* Special symbols */
	static let XK_Hangul_switch: UInt32 = 0xFF7E /* Alias for mode_switch */

	/* Hangul Consonant Characters */
	static let XK_Hangul_Kiyeog: UInt32 = 0xea1
	static let XK_Hangul_SsangKiyeog: UInt32 = 0xea2
	static let XK_Hangul_KiyeogSios: UInt32 = 0xea3
	static let XK_Hangul_Nieun: UInt32 = 0xea4
	static let XK_Hangul_NieunJieuj: UInt32 = 0xea5
	static let XK_Hangul_NieunHieuh: UInt32 = 0xea6
	static let XK_Hangul_Dikeud: UInt32 = 0xea7
	static let XK_Hangul_SsangDikeud: UInt32 = 0xea8
	static let XK_Hangul_Rieul: UInt32 = 0xea9
	static let XK_Hangul_RieulKiyeog: UInt32 = 0xeaa
	static let XK_Hangul_RieulMieum: UInt32 = 0xeab
	static let XK_Hangul_RieulPieub: UInt32 = 0xeac
	static let XK_Hangul_RieulSios: UInt32 = 0xead
	static let XK_Hangul_RieulTieut: UInt32 = 0xeae
	static let XK_Hangul_RieulPhieuf: UInt32 = 0xeaf
	static let XK_Hangul_RieulHieuh: UInt32 = 0xeb0
	static let XK_Hangul_Mieum: UInt32 = 0xeb1
	static let XK_Hangul_Pieub: UInt32 = 0xeb2
	static let XK_Hangul_SsangPieub: UInt32 = 0xeb3
	static let XK_Hangul_PieubSios: UInt32 = 0xeb4
	static let XK_Hangul_Sios: UInt32 = 0xeb5
	static let XK_Hangul_SsangSios: UInt32 = 0xeb6
	static let XK_Hangul_Ieung: UInt32 = 0xeb7
	static let XK_Hangul_Jieuj: UInt32 = 0xeb8
	static let XK_Hangul_SsangJieuj: UInt32 = 0xeb9
	static let XK_Hangul_Cieuc: UInt32 = 0xeba
	static let XK_Hangul_Khieuq: UInt32 = 0xebb
	static let XK_Hangul_Tieut: UInt32 = 0xebc
	static let XK_Hangul_Phieuf: UInt32 = 0xebd
	static let XK_Hangul_Hieuh: UInt32 = 0xebe

	/* Hangul Vowel Characters */
	static let XK_Hangul_A: UInt32 = 0xebf
	static let XK_Hangul_AE: UInt32 = 0xec0
	static let XK_Hangul_YA: UInt32 = 0xec1
	static let XK_Hangul_YAE: UInt32 = 0xec2
	static let XK_Hangul_EO: UInt32 = 0xec3
	static let XK_Hangul_E: UInt32 = 0xec4
	static let XK_Hangul_YEO: UInt32 = 0xec5
	static let XK_Hangul_YE: UInt32 = 0xec6
	static let XK_Hangul_O: UInt32 = 0xec7
	static let XK_Hangul_WA: UInt32 = 0xec8
	static let XK_Hangul_WAE: UInt32 = 0xec9
	static let XK_Hangul_OE: UInt32 = 0xeca
	static let XK_Hangul_YO: UInt32 = 0xecb
	static let XK_Hangul_U: UInt32 = 0xecc
	static let XK_Hangul_WEO: UInt32 = 0xecd
	static let XK_Hangul_WE: UInt32 = 0xece
	static let XK_Hangul_WI: UInt32 = 0xecf
	static let XK_Hangul_YU: UInt32 = 0xed0
	static let XK_Hangul_EU: UInt32 = 0xed1
	static let XK_Hangul_YI: UInt32 = 0xed2
	static let XK_Hangul_I: UInt32 = 0xed3

	/* Hangul syllable-final (JongSeong) Characters */
	static let XK_Hangul_J_Kiyeog: UInt32 = 0xed4
	static let XK_Hangul_J_SsangKiyeog: UInt32 = 0xed5
	static let XK_Hangul_J_KiyeogSios: UInt32 = 0xed6
	static let XK_Hangul_J_Nieun: UInt32 = 0xed7
	static let XK_Hangul_J_NieunJieuj: UInt32 = 0xed8
	static let XK_Hangul_J_NieunHieuh: UInt32 = 0xed9
	static let XK_Hangul_J_Dikeud: UInt32 = 0xeda
	static let XK_Hangul_J_Rieul: UInt32 = 0xedb
	static let XK_Hangul_J_RieulKiyeog: UInt32 = 0xedc
	static let XK_Hangul_J_RieulMieum: UInt32 = 0xedd
	static let XK_Hangul_J_RieulPieub: UInt32 = 0xede
	static let XK_Hangul_J_RieulSios: UInt32 = 0xedf
	static let XK_Hangul_J_RieulTieut: UInt32 = 0xee0
	static let XK_Hangul_J_RieulPhieuf: UInt32 = 0xee1
	static let XK_Hangul_J_RieulHieuh: UInt32 = 0xee2
	static let XK_Hangul_J_Mieum: UInt32 = 0xee3
	static let XK_Hangul_J_Pieub: UInt32 = 0xee4
	static let XK_Hangul_J_PieubSios: UInt32 = 0xee5
	static let XK_Hangul_J_Sios: UInt32 = 0xee6
	static let XK_Hangul_J_SsangSios: UInt32 = 0xee7
	static let XK_Hangul_J_Ieung: UInt32 = 0xee8
	static let XK_Hangul_J_Jieuj: UInt32 = 0xee9
	static let XK_Hangul_J_Cieuc: UInt32 = 0xeea
	static let XK_Hangul_J_Khieuq: UInt32 = 0xeeb
	static let XK_Hangul_J_Tieut: UInt32 = 0xeec
	static let XK_Hangul_J_Phieuf: UInt32 = 0xeed
	static let XK_Hangul_J_Hieuh: UInt32 = 0xeee

	/* Ancient Hangul Consonant Characters */
	static let XK_Hangul_RieulYeorinHieuh: UInt32 = 0xeef
	static let XK_Hangul_SunkyeongeumMieum: UInt32 = 0xef0
	static let XK_Hangul_SunkyeongeumPieub: UInt32 = 0xef1
	static let XK_Hangul_PanSios: UInt32 = 0xef2
	static let XK_Hangul_KkogjiDalrinIeung: UInt32 = 0xef3
	static let XK_Hangul_SunkyeongeumPhieuf: UInt32 = 0xef4
	static let XK_Hangul_YeorinHieuh: UInt32 = 0xef5

	/* Ancient Hangul Vowel Characters */
	static let XK_Hangul_AraeA: UInt32 = 0xef6
	static let XK_Hangul_AraeAE: UInt32 = 0xef7

	/* Ancient Hangul syllable-final (JongSeong) Characters */
	static let XK_Hangul_J_PanSios: UInt32 = 0xef8
	static let XK_Hangul_J_KkogjiDalrinIeung: UInt32 = 0xef9
	static let XK_Hangul_J_YeorinHieuh: UInt32 = 0xefa

	/* Korean currency symbol */
	static let XK_Korean_Won: UInt32 = 0xeff

	/* Euro currency symbol */
	static let XK_EuroSign: UInt32 = 0x20ac
}
