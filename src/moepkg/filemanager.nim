import os
import sequtils
import terminal
import strformat
import strutils
import editorstatus
import ui
import fileutils
import editorview
import gapbuffer
import exmode
import unicodeext

proc deleteFile(status: var EditorStatus, dirList: seq[(PathComponent, string)], currentLine: int) =
  let command = getCommand(status.commandWindow, proc (window: var Window, command: seq[Rune]) =
    window.erase
    window.write(0, 0, fmt"Delete file? 'y' or 'n': {$command}")
    window.refresh
  )


  if (command[0] == u8"y" or command[0] == u8"yes") and command.len == 1:
    if dirList[currentLine][0] == pcDir:
      removeDir(dirList[currentLine][1])
    else:
      removeFile(dirList[currentLine][1])
  else:
    return

  status.commandWindow.erase
  status.commandWindow.write(0, 0, "Deleted "&dirList[currentLine][1])
  status.commandWindow.refresh

proc refreshDirList(): seq[(PathComponent, string)] =
  result = newSeq[(PathComponent, string)]()
  result = @[(pcDir, "../")]
  for list in walkDir("./"):
    result.add list

proc writeFillerView(win: var Window, dirList: seq[(PathComponent, string)], currentLine: int) =
  var ch = newStringOfCap(1)
  for i in 0 ..< dirList.len:
    for j in 0 ..< dirList[i][1].len:
      if j > terminalWidth() - 2:
        if i == currentLine:
          win.write(i, j, "~", brightWhiteGreen)
        elif dirList[i][0] == pcDir:
          win.write(i, j, "~", brightGreenDefault)
        else:
          win.write(i, j, "~")
        break
      else:
        ch[0] = dirList[i][1][j]
        if i == currentLine:
          win.write(i, j, ch, brightWhiteGreen)
        elif dirList[i][0] == pcDir:
          win.write(i, j, ch, brightGreenDefault)
        else:
          win.write(i, j, ch)
        if j == dirList[i][1].len - 1 and i != 0 and dirList[i][0] == pcDir:
          if i == currentLine:
            win.write(i, j + 1, "/", brightWhiteGreen)
          else:
            win.write(i, j + 1, "/", brightGreenDefault)
  win.refresh

proc filerMode*(status: var EditorStatus) =
  setCursor(false)
  var viewUpdate = true
  var DirlistUpdate = true
  var dirList = newSeq[(PathComponent, string)]()
  var currentLine = 0

  while status.mode == Mode.filer:
    if DirlistUpdate == true:
      dirList = @[]
      dirList.add refreshDirList()
      viewUpdate = true
      DirlistUpdate = false

    if viewUpdate == true:
      status.mainWindow.erase
      writeStatusBar(status)
      status.mainWindow.writeFillerView(dirList, currentLine)
      viewUpdate = false

    let key = getKey(status.mainWindow)
    if key == ':':
      status.prevMode = status.mode
      status.mode = Mode.ex
    elif isResizekey(key):
      status.resize
      viewUpdate = true

    elif key == 'D':
      deleteFile(status, dirList, currentLine)
      DirlistUpdate = true
      viewUpdate = true
    elif (key == 'j' or isDownKey(key)) and currentLine < dirList.len - 1:
      inc(currentLine)
      viewUpdate = true
    elif (key == ord('k') or isUpKey(key)) and 0 < currentLine:
      dec(currentLine)
      viewUpdate = true
    elif isEnterKey(key):
      if dirList[currentLine][0] == pcFile:
        status = initEditorStatus()
        status.filename = dirList[currentLine][1].toRunes
        status.buffer = openFile(status.filename)
        status.view = initEditorView(status.buffer, terminalHeight()-2, terminalWidth()-status.buffer.len.intToStr.len-2)
        setCursor(true)
      elif dirList[currentLine][0] == pcDir:
        setCurrentDir(dirList[currentLine][1])
        currentLine = 0
        DirlistUpdate = true
