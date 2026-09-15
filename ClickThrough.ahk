#Requires AutoHotkey v2.0
#SingleInstance Force

; 强制设置 DPI 感知，防止高分屏缩放导致坐标错位
DllCall("SetThreadDpiAwarenessContext", "ptr", -3)

; =============================================================
; 功能：选中（激活）鼠标下方的下一层窗口
; 热键：Ctrl + Shift + 左键
; =============================================================
^+LButton::SelectWindowBelow()

SelectWindowBelow() {
    ; 1. 统一设为屏幕模式 (Screen)
    CoordMode "Mouse", "Screen"
    MouseGetPos(&x, &y, &topHwnd)
    
    if !topHwnd
        return

    winList := WinGetList()
    candidates := []
    topIndex := 0

    ; 2. 收集所有包含鼠标当前坐标的有效窗口
    for hwnd in winList {
        ; 过滤不可见窗口
        if !DllCall("IsWindowVisible", "ptr", hwnd)
            continue
            
        ; 过滤无边框/桌面/任务栏/挂起窗口
        cls := WinGetClass("ahk_id " hwnd)
        if (cls = "Progman" || cls = "WorkerW" || cls = "Shell_TrayWnd")
            continue
            
        ; 获取物理窗口精确坐标 (包含 DPI 修正)
        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
        } catch {
            continue
        }

        ; 过滤微小/无效窗口
        if (ww <= 16 || wh <= 16)
            continue

        ; 核心判断：鼠标坐标（屏幕绝对坐标）是否在窗口矩形内
        if (x >= wx && x <= wx + ww && y >= wy && y <= wy + wh) {
            candidates.Push(hwnd)
            ; 标记鼠标当前直接指着的顶层窗口在列表中的索引
            if (hwnd == topHwnd && topIndex == 0) {
                topIndex := candidates.Length
            }
        }
    }

    ; 3. 输出调试信息
    ; LogCandidates(candidates, topHwnd, x, y)

    ; 4. 确定要激活的目标窗口
    targetHwnd := 0
    if (candidates.Length > 0) {
        if (topIndex > 0 && topIndex < candidates.Length) {
            ; 找到了 topHwnd，顺延取它的下一个
            targetHwnd := candidates[topIndex + 1]
        } else if (topIndex == 0 && candidates.Length > 1) {
            ; MouseGetPos 获取的 topHwnd 不在候选列表中时，默认选第 2 个
            targetHwnd := candidates[2]
        }
    }

    ; 5. 激活目标
    if targetHwnd {
        title := WinGetTitle("ahk_id " targetHwnd)
        if (title == "") 
            title := "(" WinGetProcessName("ahk_id " targetHwnd) ")"
            
        WinActivate("ahk_id " targetHwnd)
        ToolTip("已选中: " title)
    } else {
        ToolTip("光标下没有更下层的窗口了")
    }
    SetTimer(() => ToolTip(), -1200)
}

; 调试日志打印函数
LogCandidates(candidates, topHwnd, x, y) {
    out := Format("START [坐标: {}, {}] 鼠标下方的窗口重叠清单：`n", x, y)
    out .= "Z序 | 句柄 | 位置/尺寸 | 类名 | 进程 | 标题`n"
    out .= "------------------------------------------------`n"

    for idx, hwnd in candidates {
        try {
            title := WinGetTitle("ahk_id " hwnd)
            cls   := WinGetClass("ahk_id " hwnd)
            proc  := WinGetProcessName("ahk_id " hwnd)
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
            pos   := wx "," wy " " ww "x" wh
        } catch {
            continue
        }

        if (title == "") title := "(无标题)"
        mark := (hwnd == topHwnd) ? "  <== [当前顶层]" : ""
        out .= Format("{1:2} | 0x{2:X} | {3} | {4} | {5} | {6}{7}`n"
               , idx, hwnd, pos, cls, proc, title, mark)
    }
    out .= "------------------------------------------------END`n"
    OutputDebug(out)
}