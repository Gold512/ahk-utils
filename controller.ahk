/************************************************************************
 * @description read output and send input to window (tested with ldplayer)
 * this version uses true coordinates
 * @file controller.ahk
 * @author Gold512
 * @date 2024/06/21
 * @version 0.0.0
 ***********************************************************************/

#Requires AutoHotkey v2.0 
#Include logger.ahk

/**
 * Coordinates are relative to the window's client area
 * @param {number} hwnd of window control 
 * @param pc_x 
 * @param pc_y 
 * @param fmt whether to format output to hex string
 * @private
 * @returns {string|number} string if fmt else number
 */
_GetWindowPixelColor(pc_wID, pc_x, pc_y, fmt := true) {
	; xoffset := 0
	; yoffset := 0

	; ; offset by control position relative to main window 
	; ControlGetPos(&xoffset, &yoffset,,, pc_wID)
	; pc_x -= xoffset
	; pc_y -= yoffset

    if (pc_wID) {
        pc_hDC := DllCall("GetDC", "UInt", pc_wID)
        pc_c := DllCall("GetPixel", "UInt", pc_hDC, "Int", pc_x, "Int", pc_y, "UInt")
        pc_c := pc_c >> 16 & 0xff | pc_c & 0xff00 | (pc_c & 0xff) << 16
        DllCall("ReleaseDC", "UInt", pc_wID, "UInt", pc_hDC)

		if !fmt 
			return pc_c

		pc_c := Format('{:06x}', pc_c)
        return Format('{:U}', pc_c)
    }
}

hexColorToInt(hex) {
	hex := StrReplace(hex, '#', '',,, 1)
	hex := '0x' hex
	hex += 0

	return hex
}

/**
 * 
 * @param {number} c1 
 * @param {number} c2 
 */
_TolerantColorCompare(c1, c2, tolerance) {
	; if Type(c1) == 'String'
	; 	c1 := hexColorToInt(c1)

	; if Type(c2) == 'String'
	; 	c2 := hexColorToInt(c2)

	; check red 
	if Abs(((c1 >> 16) & 0xff) - ((c2 >> 16)) & 0xff) > tolerance
		return false

	; check green
	if Abs(((c1 >> 8) & 0xff) - ((c2 >> 8) & 0xff)) > tolerance
		return false
	
	; check blue
	if Abs((c1 & 0xff) - (c2 & 0xff)) > tolerance
		return false
	
	return true
}

RandomSleep(ms, variation) {
	Sleep(ms + Random(-variation, variation))
}

class Controller {
	/**
	 * 
	 * @param {Object} handle
	 */
	__New(handle) {
		this.input := handle['input']
		this.output := handle['output']
	}

	GetPixelColor(x, y) {
		return '#' _GetWindowPixelColor(this.output, x, y)
	}

	MatchPixel(x, y, color, tolerance := 3) {
		color .= ''
		color := StrReplace(color, '#', '',,, 1)
	
		c1 := _GetWindowPixelColor(this.output, x, y, false)
		return _TolerantColorCompare(c1, hexColorToInt(color), tolerance)
	}

	MatchPixelTimer(x, y, color, timeout := 1000, interval := 100, tolerance := 3) {
		color .= ''
		color := StrReplace(color, '#', '',,, 1)
		elapsed := 0
	
		while(true) {
			if (elapsed >= timeout)
				return false
		
			c1 := _GetWindowPixelColor(this.output, x, y, false)
			DebugMessage('MatchPixelTimer c1(' x ',' y '): ' _GetWindowPixelColor(this.output, x, y) ' c2(static): ' color ' match: ' _TolerantColorCompare(c1, hexColorToInt(color), tolerance))
			if _TolerantColorCompare(c1, hexColorToInt(color), tolerance)
				return true
	
			Sleep(interval)
			elapsed += interval
		}
	}
		
	/**
	 * Combination of WaitForPixelColor and ClickAround  
	 * useful for waiting for buttons 
	 * @param hwnd 
	 * @param x 
	 * @param y 
	 * @param color 
	 * @param {number} variation 
	 * @param {number} interval 
	 * @param {number} timeout 
	 */
	AwaitColorAndClick(x, y, color, variation := 5, interval := 100, timeout := 5000) {
		this.AwaitColor(x, y, color, interval, timeout)

		; small sleep to improve reliability 
		Sleep(200)

		; dont need to offset since clickaround does that 
		this.ClickAround(x, y, variation)
	}

	/**
	 * Wait until a color is at a specific x or y coords
	 * @param hwnd 
	 * @param x 
	 * @param y 
	 * @param {string} color 
	 * @param {number} interval 
	 * @param {number} timeout 
	 * @returns {void} 
	 */
	AwaitColor(x, y, color, interval := 100, timeout := 10000, tolerance := 3) {
		elapsed := 0
		color .= ''
		color := StrReplace(color, '#', '',,, 1)

		while (true) {
			if elapsed >= timeout { 
				throw Error('AwaitColor timeout')
			}

			c1 := _GetWindowPixelColor(this.output, x, y, false)
			DebugMessage('AwaitColor c1(' x ',' y '): ' _GetWindowPixelColor(this.output, x, y) ' c2(static): ' color ' match: ' _TolerantColorCompare(c1, hexColorToInt(color), tolerance))

			if _TolerantColorCompare(c1, hexColorToInt(color), tolerance) {
				; extra delay for reliability
				Sleep(200)
				return true
			}

			Sleep(interval)
			elapsed += interval
		}
	}

		
	/**
	 * Scroll right in menu
	 */
	ScrollRight(distance, y, variation, offset := 50) {
		Lerp(a, b, t) {
			return Round(a + (b - a) * t)
		}

		; xpos := 0
		; ypos := 0
		; ControlGetPos(&xpos, &ypos, , , this.input)

		offset += Random(-variation, variation)
		x1 := offset + distance
		x2 := offset

		y += Random(-variation, variation)

		opt1 := Format('d NA x{} y{}', x1, y)
		ControlClick(this.input, , , , , opt1)

		total := Floor(distance / 50)
		loop total {
			t := A_Index / total
			x := Lerp(x1, x2, t)
			Sleep(2)
			; WM-mousemove
			; https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-mousemove
			SendMessage(0x0200, 0x0001, y << 16 | x, this.input)
		}

		Sleep(2)
		SendMessage(0x0200, 0x0001, y << 16 | x2, this.input)

		Sleep(2)
		opt2 := Format('u NA x{} y{}', x2, y)
		ControlClick(this.input, , , , , opt2)
	}


	/**
	 * Scroll left in menu
	 */
	ScrollLeft(distance, y, variation, offset := 50) {
		Lerp(a, b, t) {
			return Round(a + (b - a) * t)
		}

		; xpos := 0
		; ypos := 0
		; ControlGetPos(&xpos, &ypos, , , this.input)

		offset += Random(-variation, variation)
		x1 := offset
		x2 := offset + distance

		y += Random(-variation, variation)

		opt1 := Format('d NA x{} y{}', x1, y)
		ControlClick(this.input, , , , , opt1)

		total := Floor(distance / 50)
		loop total {
			t := A_Index / total
			x := Lerp(x1, x2, t)
			Sleep(2)
			; WM-mousemove
			; https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-mousemove
			SendMessage(0x0200, 0x0001, y << 16 | x, this.input)
		}

		Sleep(2)
		SendMessage(0x0200, 0x0001, y << 16 | x2, this.input)

		Sleep(2)
		opt2 := Format('u NA x{} y{}', x2, y)
		ControlClick(this.input, , , , , opt2)
	}

	DragClick(x1, y1, x2, y2, variation := 3) {
		Lerp(a, b, t) {
			return Round(a + (b - a) * t)
		}

		; xpos := 0
		; ypos := 0
		; ControlGetPos(&xpos, &ypos, , , this.input)

		offset := Random(-variation, variation)
		x1 += offset
		x2 += offset
		y1 += offset
		y2 += offset

		; y += Random(-variation, variation) - ypos

		Sleep(100)

		; WM-mousedown 
		SendMessage(0x0201, 0x0001, x1 | y1 << 16, this.input)

		total := Floor(Sqrt((x1 - x2) ** 2 + (y1 - y2) ** 2) / 30)
		; ((x1 - x2) ' ' total ' ' (y1 - y2))
		loop total {
			t := (A_Index) / total
			x := Lerp(x1, x2, t)
			y := Lerp(y1, y2, t)
			Sleep(30)

			; WM-mousemove
			; https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-mousemove
			
			SendMessage(0x0200, 0x0001, x | y << 16, this.input)
		}

		loop 20 {
			Sleep(30)
			SendMessage(0x0200, 0x0001, x2 | y2 << 16, this.input)
		}

		Sleep(30)
		
		; WM-mousedown 
		; SendMessage(0x0201, 0x0001, x2 | y2 << 16, this.input)
		; Sleep(30)

		; WM-mouseup
		SendMessage(0x0202, 0x0001, x2 | y2 << 16, this.input)

		Sleep(50)
	}

	ClickAround(x, y, variation := 5) {
		; xpos := 0
		; ypos := 0
		; ControlGetPos(&xpos, &ypos, , , this.input)
		
		opt := Format('x{} y{} NA', x + Random(-variation, variation), y + Random(-variation, variation))
		ControlClick(this.input,,,,, opt)
		Sleep(400)
	}
}