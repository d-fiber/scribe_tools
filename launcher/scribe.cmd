@echo off
REM Copyright (C) 2026 Fiber
REM
REM This Source Code Form is subject to the terms of the Mozilla Public License,
REM v. 2.0. If a copy of the MPL was not distributed with this file, You can
REM obtain one at https://mozilla.org/MPL/2.0/.
REM
REM What you may do:
REM - Use this software for any purpose, including commercially, and build and
REM   sell your own products on top of it.
REM - Change it, and create new works based on it.
REM - Distribute copies of it, with or without your changes.
REM - Combine it with files under any other licence, proprietary ones included,
REM   and licence that larger work on your own terms.
REM
REM What you must do in return:
REM - Keep this notice on every file you received it on.
REM - Publish, under these same terms, the source of every file covered by them
REM   that you distribute, including the ones you changed, so that whoever
REM   receives your version can obtain that source.
REM - Leave Fiber out of it: the name "Fiber", its branding, its logos and its
REM   trademarks may not be used to endorse or promote what you build, and this
REM   licence grants no right to them.
REM
REM Disclaimer:
REM AS FAR AS THE LAW ALLOWS, THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
REM OR CONDITION OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
REM WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
REM NON-INFRINGEMENT. IN NO EVENT SHALL FIBER BE LIABLE FOR ANY DIRECT, INDIRECT,
REM INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT
REM LIMITED TO LOSS OF USE, DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT
REM OF OR RELATED TO THESE TERMS OR THE USE OR NATURE OF THE SOFTWARE, UNDER ANY
REM KIND OF LEGAL CLAIM.
REM
REM This header is a summary written for convenience. Where it differs from the
REM LICENSE file, the LICENSE file governs.

setlocal
set "SCRIBE_BINARY=%~dp0scribe_windows.exe"

if not exist "%SCRIBE_BINARY%" (
  echo scribe: %SCRIBE_BINARY% is missing. Run the installer again from Git Bash: 1>&2
  echo   sh -c "$(curl -fsSL https://raw.githubusercontent.com/d-fiber/scribe_tools/main/install.sh)" 1>&2
  exit /b 1
)

"%SCRIBE_BINARY%" %*
exit /b %ERRORLEVEL%
