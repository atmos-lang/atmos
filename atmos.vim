" Vim syntax file
" Language:     Atmos
" Maintainer:   Francisco Sant'Anna <francisco.santanna@gmail.com>
" Last Change:  2025 May

if exists("b:current_syntax")
    finish
endif

syn iskeyword 33,39,45,46,63,95,97-122

syn match   Comment   ";;.*$"
syn region  Comment   start=/;;;$/ end=/;;;$/

syn region  String    start=/\v"/ skip=/\v(\\[\\"]){-1}/ end=/\v"/
syn match   String    "'.'"
"syntax region String start=/\v'/ skip=/\v(\\[\\"]){-1}/ end=/\v'/

syn match   Constant  '\d\+'
syn keyword Constant  false nil true

syn keyword Function  dump error pub
syn keyword Function  print require type

syn keyword Function  copy
"syn match   Function  '\<\(to\|random\|math\)'
"syn match   Function  '\<\(pico\|iup\)'

syn match   Type      ':[a-zA-Z0-9'?!\.\-]\+'

syn match   Statement '[\+\-\*\/\%\>\<\=\|\&\~]'

syn keyword Statement await break catch coro defer do
syn keyword Statement else emit escape every false func if ifs
syn keyword Statement in loop nil par par_and par_or
syn keyword Statement pin resume return set spawn status task tasks
syn keyword Statement throw true until val var yield with while

syn keyword Statement toggle test data match
syn keyword Statement resume-yield-all
syn keyword Statement skip thus
syn keyword Statement watching where
syn keyword Statement coroutine

syn keyword Todo      TODO FIXME XXX
syn region  String    start='"' end='"'
