param(
    [ValidateSet('Capture','Menus','Click','Command','Key','Controls','SetText','Choices','Choose','Invoke','CloseDialog')][string]$Action='Capture',
    [string]$Output='evidence/simulator.png', [int]$X=0,[int]$Y=0,[int]$CommandId=0,[int]$VirtualKey=0,[int]$ControlId=0,[string]$Text,[int]$Index=0,[switch]$MainWindow
)
# Explicitly authorized fallback only when Computer Use is unavailable.
# Targets exactly the installed Garmin simulator executable; never other apps.
$ErrorActionPreference='Stop'
$sdk=(Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim()
$expected=[IO.Path]::GetFullPath((Join-Path $sdk 'bin\simulator.exe'))
$targets=@(Get-Process simulator -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $expected})
if($targets.Count -ne 1){throw 'Expected exactly one installed Garmin simulator process.'}
$target=$targets[0]
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class GarminWindow {
 [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left,Top,Right,Bottom; }
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out Rect r);
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h,IntPtr dc,uint flags);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 [StructLayout(LayoutKind.Sequential)] public struct Point { public int X,Y; }
 [StructLayout(LayoutKind.Sequential)] public struct GuiInfo { public int size,flags; public IntPtr active,focus,capture,menuOwner,moveSize,caret; public Rect caretRect; }
 public delegate bool EnumChild(IntPtr h,IntPtr p);
 [DllImport("user32.dll")] public static extern IntPtr GetLastActivePopup(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr ChildWindowFromPointEx(IntPtr h,Point p,uint flags);
 [DllImport("user32.dll")] public static extern int MapWindowPoints(IntPtr from,IntPtr to,ref Point p,uint n);
 [DllImport("user32.dll")] public static extern bool GetGUIThreadInfo(uint t,ref GuiInfo i);
 [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h,EnumChild f,IntPtr p);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumChild f,IntPtr p);
 [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h,StringBuilder s,int max);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h,StringBuilder s,int max);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h,uint msg,IntPtr w,string l);
 [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h,uint msg,IntPtr w,IntPtr l);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h,uint msg,IntPtr w,StringBuilder l);
 [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
 [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetSubMenu(IntPtr h,int n);
 [DllImport("user32.dll")] public static extern uint GetMenuItemID(IntPtr h,int n);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetMenuString(IntPtr h,uint n,StringBuilder s,int max,uint flags);
}
"@
$script:mainWindows=New-Object 'System.Collections.Generic.List[object]'
$windowCallback=[GarminWindow+EnumChild]{param($h,$unused)
    $ownerPid=[uint32]0; [void][GarminWindow]::GetWindowThreadProcessId($h,[ref]$ownerPid)
    if($ownerPid -eq $target.Id){
        $title=New-Object Text.StringBuilder 256; [void][GarminWindow]::GetWindowText($h,$title,256)
        if($title.ToString() -like 'CIQ Simulator*'){$script:mainWindows.Add([PSCustomObject]@{Handle=$h;Title=$title.ToString()})}
    }
    return $true
}
[void][GarminWindow]::EnumWindows($windowCallback,[IntPtr]::Zero)
if($script:mainWindows.Count -ne 1){throw 'Expected exactly one observed CIQ Simulator main window.'}
$main=$script:mainWindows[0].Handle; $handle=$main
if($Action -notin @('Command','Menus') -and -not $MainWindow){
    for($depth=0;$depth -lt 10;$depth++){
        $popup=[GarminWindow]::GetLastActivePopup($handle); $popupPid=[uint32]0
        [void][GarminWindow]::GetWindowThreadProcessId($popup,[ref]$popupPid)
        if($popup -eq [IntPtr]::Zero -or $popup -eq $handle -or $popupPid -ne $target.Id -or -not [GarminWindow]::IsWindowVisible($popup)){break}
        $handle=$popup
    }
}
if($Action -in @('Controls','SetText','Choices','Choose','Invoke')){
    $script:controlRows=New-Object 'System.Collections.Generic.List[object]'
    $callback=[GarminWindow+EnumChild]{param($h,$unused)
        $label=New-Object Text.StringBuilder 256; $class=New-Object Text.StringBuilder 128
        [void][GarminWindow]::GetWindowText($h,$label,256); [void][GarminWindow]::GetClassName($h,$class,128)
        $rect=New-Object GarminWindow+Rect; [void][GarminWindow]::GetWindowRect($h,[ref]$rect)
        $script:controlRows.Add([PSCustomObject]@{Handle=$h;Id=[GarminWindow]::GetDlgCtrlID($h);Class=$class.ToString();Text=$label.ToString();Visible=[GarminWindow]::IsWindowVisible($h);Rect=$rect})
        return $true
    }
    [void][GarminWindow]::EnumChildWindows($handle,$callback,[IntPtr]::Zero)
    if($Action -eq 'Controls'){$script:controlRows | Select-Object Id,Class,Text,Visible; exit}
    if($Action -in @('Choices','Choose')){
        $lists=@($script:controlRows | Where-Object {$_.Id -eq $ControlId -and $_.Class -in @('ComboBox','ListBox') -and $_.Visible})
        if($lists.Count -ne 1){throw 'Expected one observed Garmin selection control.'}
        $control=$lists[0]; $combo=$control.Class -eq 'ComboBox'; $countMsg=if($combo){0x146}else{0x18B}; $textMsg=if($combo){0x148}else{0x189}
        $count=[GarminWindow]::SendMessage($control.Handle,$countMsg,[IntPtr]0,[IntPtr]0).ToInt32()
        if($Action -eq 'Choices'){
            for($i=0;$i -lt $count;$i++){ $label=New-Object Text.StringBuilder 512; [void][GarminWindow]::SendMessage($control.Handle,$textMsg,[IntPtr]$i,$label); [PSCustomObject]@{Index=$i;Text=$label.ToString()} }; exit
        }
        if($Index -lt 0 -or $Index -ge $count){throw 'Choice index is outside the observed selection list.'}
        $setMsg=if($combo){0x14E}else{0x186}; [void][GarminWindow]::SendMessage($control.Handle,$setMsg,[IntPtr]$Index,[IntPtr]0)
        [void][GarminWindow]::PostMessage([GarminWindow]::GetParent($control.Handle),0x111,[IntPtr]((1 -shl 16) -bor ($ControlId -band 0xFFFF)),$control.Handle); exit
    }
    if($Action -eq 'Invoke'){
        if($ControlId -notin @(1,11,5100,5101)){throw 'Only observed Open/Load, playback, OK or Cancel buttons are allowed.'}
        $buttons=@($script:controlRows | Where-Object {$_.Id -eq $ControlId -and $_.Class -eq 'Button' -and $_.Visible})
        if($buttons.Count -ne 1){throw 'Expected one observed Garmin dialog button.'}
        [void][GarminWindow]::PostMessage($buttons[0].Handle,0xF5,[IntPtr]0,[IntPtr]0); exit
    }
    $matches=@($script:controlRows | Where-Object {$_.Id -eq $ControlId -and $_.Class -match 'Edit' -and $_.Visible})
    if($matches.Count -ne 1){throw 'Expected one observed simulator edit control.'}
    [void][GarminWindow]::SendMessage($matches[0].Handle,0xC,[IntPtr]0,$Text); exit
}
if($Action -eq 'CloseDialog'){
    if($handle -eq $main){throw 'Refusing to close simulator main window.'}
    [void][GarminWindow]::PostMessage($handle,0x10,[IntPtr]0,[IntPtr]0); exit
}
if($Action -eq 'Menus'){
    function Read-Menu([IntPtr]$menu,[string]$prefix){
        for($i=0;$i -lt [GarminWindow]::GetMenuItemCount($menu);$i++){
            $label=New-Object Text.StringBuilder 256
            [void][GarminWindow]::GetMenuString($menu,$i,$label,256,0x400)
            $path=$prefix+'/'+$label.ToString(); $sub=[GarminWindow]::GetSubMenu($menu,$i)
            if($sub -ne [IntPtr]::Zero){Read-Menu $sub $path}
            else{[PSCustomObject]@{Id=[GarminWindow]::GetMenuItemID($menu,$i);Path=$path}}
        }
    }
    Read-Menu ([GarminWindow]::GetMenu($handle)) ''; exit
}
if($Action -eq 'Click'){
    if($X -lt 0 -or $X -gt 1000 -or $Y -lt 0 -or $Y -gt 1400){throw 'Click is outside simulator client bounds.'}
        [void][GarminWindow]::SetForegroundWindow($handle)
    $local=New-Object GarminWindow+Point; $local.X=$X; $local.Y=$Y
    for($depth=0;$depth -lt 10;$depth++){
        $child=[GarminWindow]::ChildWindowFromPointEx($handle,$local,3)
        if($child -eq [IntPtr]::Zero -or $child -eq $handle){break}
        [void][GarminWindow]::MapWindowPoints($handle,$child,[ref]$local,1); $handle=$child
    }
    $point=[IntPtr](($local.Y -shl 16) -bor ($local.X -band 0xFFFF))
    [void][GarminWindow]::PostMessage($handle,0x201,[IntPtr]1,$point)
    [void][GarminWindow]::PostMessage($handle,0x202,[IntPtr]0,$point); exit
}
if($Action -eq 'Command'){
    if($CommandId -notin @(5003,6005,6048,6167,6170,10003)){throw 'Invalid observed Garmin menu command.'}
    [void][GarminWindow]::PostMessage($handle,0x111,[IntPtr]$CommandId,[IntPtr]0); exit
}
if($Action -eq 'Key'){
    if($VirtualKey -notin @(13,27,38,40,112,113,114,115,116)){throw 'Only navigation keys are permitted.'}
    [void][GarminWindow]::SetForegroundWindow($handle)
    $gui=New-Object GarminWindow+GuiInfo; $gui.size=[Runtime.InteropServices.Marshal]::SizeOf($gui)
    $owner=[uint32]0; $thread=[GarminWindow]::GetWindowThreadProcessId($handle,[ref]$owner)
    if([GarminWindow]::GetGUIThreadInfo($thread,[ref]$gui) -and $gui.focus -ne [IntPtr]::Zero){
        $focusPid=[uint32]0; [void][GarminWindow]::GetWindowThreadProcessId($gui.focus,[ref]$focusPid)
        if($focusPid -eq $target.Id){$handle=$gui.focus}
    }
    [void][GarminWindow]::PostMessage($handle,0x100,[IntPtr]$VirtualKey,[IntPtr]0)
    [void][GarminWindow]::PostMessage($handle,0x101,[IntPtr]$VirtualKey,[IntPtr]0); exit
}
$r=New-Object GarminWindow+Rect
[void][GarminWindow]::GetWindowRect($handle,[ref]$r)
$width=$r.Right-$r.Left; $height=$r.Bottom-$r.Top
if($width -lt 100 -or $height -lt 100 -or $width -gt 3000 -or $height -gt 3000){throw 'Invalid simulator window geometry.'}
$bitmap=New-Object Drawing.Bitmap $width,$height
$graphics=[Drawing.Graphics]::FromImage($bitmap); $dc=$graphics.GetHdc()
try { if(-not [GarminWindow]::PrintWindow($handle,$dc,2)){throw 'Garmin window capture failed.'} }
finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
try { $path=[IO.Path]::GetFullPath((Join-Path (Get-Location) $Output)); $bitmap.Save($path,[Drawing.Imaging.ImageFormat]::Png); $path }
finally { $bitmap.Dispose() }
