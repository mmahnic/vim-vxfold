" vim:set fileencoding=utf-8 sw=3 ts=8 et:vim
"
" Author: Marko Mahnič
" Created: March 2010
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#load#IsLoaded( '#vxfold' )
   finish
endif
call vxlib#load#SetLoaded( '#vxfold', 1 )

"-----------------------------------------------------------------
" SIMPLE BOL Folding
"     folding level is defined with the number of heading
"     characters at BOL
"-----------------------------------------------------------------
function! vxfold#BolCount(lnum)
   "- n = number of consecutive '=' at start of line
   "- let n = strlen(substitute(getline(a:lnum), '^\(\**\)\(.*\)', '\1', ''))
   if exists('b:vxfold_bolcount_char') | let ch = b:vxfold_bolcount_char
   else | let ch = '*' | endif
   let n = strlen(substitute(getline(a:lnum), '\m[^' . ch . '].*', '', ''))
   return (n == 0) ? '=' : '>' . n
endfunc

function! vxfold#SetFold_BolCount(char)
   if a:char == ']' | let char = '\]'
   else | let char = a:char | endif
   let b:vxfold_bolcount_char = char
   setlocal foldexpr=vxfold#BolCount(v:lnum)
   setlocal foldmethod=expr
endfunc

function! vxfold#FoldText()
   if exists('b:vxfold_foldtext_param') | let param = b:vxfold_foldtext_param
   else | let param = [0, 3] | endif
   let tcount = ''
   if param[0]
      let lnrlen = len('' . line('$'))
      let nlines = printf('%*d', lnrlen , v:foldend - v:foldstart)
      let tcount = '+-' . v:folddashes . ' ' . nlines . ' lines: '
   endif
   let tlines = ''
   let nlines = 0
   for iline in range(v:foldstart, v:foldend)
      if nlines >= param[1] | break | endif
      let line = substitute(getline(iline), '\m^\s\+', '', '')
      if line == '' | continue | endif
      let line = substitute(line, '\m\s\+$', '', '')
      if tlines == '' | let tlines = line
      else
         let tlines = tlines . ' | ' . line
      endif
      let nlines += 1
   endfor
   return tcount . tlines
endfunc

" foldtext() is SetFoldText(1, 1)
function! vxfold#SetFoldText(showCount, maxLines)
   if a:showCount != 0 && a:maxLines < 2
      setlocal foldtext=foldtext()
      return
   endif
   if a:maxLines < 1 | let a:maxLines = 1 | endif

   let b:vxfold_foldtext_param=[a:showCount, a:maxLines]
   setlocal foldtext=vxfold#FoldText()
endfunc

"-----------------------------------------------------------------
" Fold display: first line of text
" TODO: text is indented to its heading level
"-----------------------------------------------------------------
function! vxfold#FoldTextFirstLine()
   for iline in range(v:foldstart, v:foldend)
      let line = substitute(getline(iline), '\m\s*$', '', '')
      if line == '' | continue | endif
      break
   endfor
   if foldlevel(v:foldstart) >= 10
      let line = printf('%10s| %s%120s', '', substitute(line, '\m^\s*', '', ''), '')
   else
      let line = printf('%s%120s', line, '')
   endif
   return line
endfunc

function! vxfold#SetFoldTextFirstLine()
   setlocal foldtext=vxfold#FoldTextFirstLine()
endfunc

"-----------------------------------------------------------------
" ORG Mode Folding
"     folding level is defined with the number of heading
"     characters at BOL (1-9), while text has foldlevel 10
"-----------------------------------------------------------------
function! vxfold#OrgBolCount(lnum)
   "- n = number of consecutive '=' at start of line
   "- let n = strlen(substitute(getline(a:lnum), '^\(\**\)\(.*\)', '\1', ''))
   if exists('b:vxfold_bolcount_char') | let ch = b:vxfold_bolcount_char
   else | let ch = '*' | endif
   let n = strlen(substitute(getline(a:lnum), '\m[^' . ch . '].*', '', ''))
   if n > 9 | let n = 9 | endif
   return (n == 0) ? '10' : '>' . n
endfunc

function! vxfold#SetFold_OrgBolCount(char)
   if a:char == ']' | let char = '\]'
   else | let char = a:char | endif
   let b:vxfold_bolcount_char = char
   setlocal foldexpr=vxfold#OrgBolCount(v:lnum)
   setlocal foldmethod=expr
endfunc

let s:padding = printf('%120s', ' ')
let s:texthide = printf('%40s...%80s', ' ', ' ')
function! vxfold#FoldTextOrg()
   if foldlevel(v:foldstart) >= 10
      return s:texthide
   endif
   let line = getline(v:foldstart)
   let xx = v:foldlevel
   if xx < 2
      let line = line . s:padding
   else
      let line = substitute(line[:xx-2], '.', ' ', 'g') . (line[xx-1:]) . s:padding
   endif
   return line
   "- return vxfold#FoldText()
endfunc

function! vxfold#SetFoldTextOrg()
   let b:vxfold_foldtext_param=[0, 1]
   setlocal foldtext=vxfold#FoldTextOrg()
endfunc

" Assumption: text has foldelvel >= 10
" Assumption: text may be folded on the first line after heading
" Assumption: only higher level headings in block
function! s:DetectFoldState(lnstart, lnend, startlevel)
   let lnum = a:lnstart
   let lnend = a:lnend
   let lchild = a:startlevel + 1

   let headings = [0, 0] " closed, open
   let children = [0, 0] " direct children
   let texts = [0, 0]
   let textlevel = 10
   for lnn in range(lnum+1, lnend)
      let fdc = foldclosed(lnn)
      let fdl = foldlevel(lnn)
      if fdl < textlevel
         " isopen: 1 if open, 0 if closed
         let isopen = (fdc < 0 || fdc == lnn) ? 1 : 0
         let headings[isopen] += 1
         if fdl == lchild
            let children[isopen] += 1
         endif
      else
         let isopen = (fdc < 0)
         let texts[isopen] += 1
      endif
   endfor

   let [text_hid, text_vis] = texts
   let [head_hid, head_vis] = headings
   let [chld_hid, chld_vis] = children
   if text_vis==0 && head_vis==0 && head_hid!=0
      " all closed
      let curmode = 'closed'
   elseif text_hid!=0 && head_vis!=0 && head_hid==0
      " all headings visible, no text (well, some text hidden)
      let curmode = 'headingtree'
   elseif text_hid!=0 && head_vis!=0 && chld_hid==0
      " all child headings visible, no text (well, some text hidden)
      let curmode = 'headings'
   elseif text_hid!=0 && head_vis== 0 && head_hid== 0
      " no headings, only text
      let curmode = 'noheadings'
   else
      let curmode = 'all'
   endif

   "- Old code
   "-if texts[1] == 0 && headings[1] == 0 && headings[0] != 0 " all closed
   "-   let curmode = 'closed'
   "-elseif texts[0] != 0 && headings[1] != 0 && headings[0] == 0 " all headings visible, no text
   "-   let curmode = 'headings'
   "-elseif texts[0] != 0 && headings[1] != 0 && headings[0] == 0 " all headings visible, no text
   "-   let curmode = 'headings'
   "-elseif texts[0] != 0 && headings[1] == 0 && headings[0] == 0 " no headings, only text
   "-   let curmode = 'noheadings'
   "-else
   "-   let curmode = 'all'
   "-endif
   return curmode
endfunc

let s:headingmode = [1, 1] " [ headings, headingtree ]
function! s:NextFoldState(state)
   if a:state == 'closed' | let nextmode = 'headings'
   elseif a:state == 'headings' | let nextmode = 'headingtree'
   elseif a:state == 'headingtree' | let nextmode = 'all'
   elseif a:state == 'noheadings' | let nextmode = 'all'
   else | let nextmode = 'closed'
   endif
   if ! s:headingmode[0] && nextmode == 'headings'
      let nextmode = 'headingtree'
   endif
   if ! s:headingmode[1] && nextmode == 'headingtree'
      let nextmode = 'all'
   endif
   return nextmode
endfunc

function! s:ApplyFoldState(lnstart, lnend, fstate)
   let lnum = a:lnstart
   let lnend = a:lnend
   let nextmode = a:fstate
   if lnend <= lnum
      return
   endif

   " apply state
   let subheading_tree = 1 " 0 - first level only, 1 - all levels
   if nextmode == 'closed'
      exec lnum . ',' . lnend . 'foldclose'
   elseif nextmode == 'headingtree'
      exec lnum . ',' . lnend . 'foldopen!'
      for lnn in range(lnum+1, lnend)
         " all subheadings displayed
         if foldlevel(lnn) < 10 | continue | endif
         if foldclosed(lnn) < 0
            exec lnn . 'foldclose'
         endif
      endfor
   elseif nextmode == 'headings'
      exec lnum . ',' . lnend . 'foldopen!'
      for lnn in range(lnum+1, lnend)
         " only first-level headnigs displayed
         if foldclosed(lnn) < 0
            exec lnn . 'foldclose'
         endif
      endfor
   else
      exec lnum . ',' . lnend . 'foldopen!'
   endif
endfunc

"- Texts have foldlevel 10, headings 1 - 9
"- All folds closed, cursor on heading
"-    * TAB: show all subheadings (foldlevel < 10)
"-    * TAB: show texts (foldlevel > current)
"-    * TAB: hide everything below heading (foldlevel < current)
"-function! vxfold#CycleBolFoldVisibilityHere()
"-   if exists('b:vxfold_bolcount_char') | let ch = b:vxfold_bolcount_char
"-   else | let ch = '*' | endif
"-
"-   let hexpr =  '\m^[' . ch . ']'
"-   " must be on a heading
"-   if match(getline('.'), hexpr) != 0
"-      echom 'Fold-Cycle works only on a [' . ch . '] heading.'
"-      return
"-   endif
"-
"-   " find current section limits
"-   let lnstart = line('.')
"-   let hlevel = foldlevel(lnstart)
"-   let hexpr_stop = hexpr . '\{1,' . hlevel . '}\%([^' . ch . ']\|$\)'
"-   let lnend = search(hexpr_stop, 'nW') - 1
"-   if lnend < 1 | let lnend = line('$') | endif
"-
"-   " select next fold state
"-   let curstate = s:DetectFoldState(lnstart, lnend, hlevel)
"-   let nextstate = s:NextFoldState(curstate)
"-   echo lnstart . ' ' . lnend . ' state=' . curstate . ' nextstate=' . nextstate
"-   call s:ApplyFoldState(lnstart, lnend, nextstate)
"-endfunc

" Texts have foldlevel 10, headings 1 - 9
" No special marks needed.
function! vxfold#CycleFoldVisibilityHere()
   let lnstart = line('.')
   let hlevel = foldlevel(lnstart)
   if hlevel < 1 || hlevel >= 10
      echom 'Fold-Cycle works only on a heading.'
      return
   endif

   " find current section limits
   let lnend = lnstart + 1
   let lnstop = line('$')
   let fll = foldlevel(lnend)
   while fll > hlevel && lnend < lnstop
      let lnend += 1
      let fll = foldlevel(lnend)
   endwhile
   if foldlevel(lnend) <= hlevel
      let lnend -= 1
   endif

   let curstate = s:DetectFoldState(lnstart, lnend, hlevel)
   let nextstate = s:NextFoldState(curstate)
   "- echo lnstart . ' ' . lnend . ' state=' . curstate . ' nextstate=' . nextstate
   call s:ApplyFoldState(lnstart, lnend, nextstate)
endfunc

function! vxfold#CycleBolFoldVisibilityAll()
   let lnstart = 1
   let lnend = line('$')
   while lnstart < lnend && foldlevel(lnstart) >= 10
      let lnstart += 1
   endwhile

   " select next fold state
   let curstate = s:DetectFoldState(lnstart-1, lnend, 0)
   let nextstate = s:NextFoldState(curstate)
   "- echo lnstart . ' ' . lnend . ' state=' . curstate . ' nextstate=' . nextstate
   call s:ApplyFoldState(lnstart, lnend, nextstate)
endfunc


function! vxfold#Test()
   call vxfold#SetFold_OrgBolCount('*')
   call vxfold#SetFoldTextOrg()
   nmap <buffer> <tab> :call vxfold#CycleBolFoldVisibilityHere()<cr>
   nmap <buffer> za :call vxfold#CycleFoldVisibilityHere()<cr>
   nmap <buffer> <s-tab> :call vxfold#CycleBolFoldVisibilityAll()<cr>
   nmap <buffer> zA :call vxfold#CycleBolFoldVisibilityAll()<cr>
   nmap <buffer> <F9> :echo foldlevel('.')<cr>
endfunc

function! vxfold#TestMap()
   "- nmap <buffer> <tab> :call vxfold#CycleBolFoldVisibilityHere()<cr>
   nmap <buffer> <tab> :call vxfold#CycleFoldVisibilityHere()<cr>
   nmap <buffer> za :call vxfold#CycleFoldVisibilityHere()<cr>
   nmap <buffer> <s-tab> :call vxfold#CycleBolFoldVisibilityAll()<cr>
   nmap <buffer> zA :call vxfold#CycleBolFoldVisibilityAll()<cr>
   nmap <buffer> <F9> :echo foldlevel('.')<cr>
endfunc

function! s:MapZa()
   nmap <silent> <buffer> za :call vxfold#CycleFoldVisibilityHere()<cr>
   nmap <silent> <buffer> zA :call vxfold#CycleBolFoldVisibilityAll()<cr>
endfunc

function! s:MapTab()
   nmap <silent> <buffer> <tab> :call vxfold#CycleFoldVisibilityHere()<cr>
   nmap <silent> <buffer> <s-tab> :call vxfold#CycleBolFoldVisibilityAll()<cr>
endfunc

function! vxfold#SetMode(modename)
   if a:modename == 'tvo'
   elseif a:modename == 'org'
      call vxfold#SetFold_OrgBolCount('*')
      call vxfold#SetFoldTextOrg()
   elseif a:modename == 'viki'
      call vxfold#SetFold_OrgBolCount('*')
      call vxfold#SetFoldTextFirstLine()
   elseif a:modename == 'vimwiki'
      call vxfold#SetFold_OrgBolCount('=')
      call vxfold#SetFoldTextFirstLine()
   else
      echom 'Unknown VxFold mode "' . a:modename . '"'
   endif
   call s:MapTab()
endfunc

