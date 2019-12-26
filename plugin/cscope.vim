" This tests to see if vim was configured with the '--enable-cscope' option
" when it was compiled.  If it wasn't, time to recompile vim... 
if ! has("cscope")
    finish
endif

" use both cscope and ctag for 'ctrl-]', ':ta', and 'vim -t'
set cscopetag

" check cscope for definition of a symbol before checking ctags: set to 1
" if you want the reverse search order.
set cscopetagorder=0

" determines how many components of a file's path to display
set cscopepathcomp=3

" disable the early complains
set nocscopeverbose

" add any cscope database in current directory
if filereadable("cscope.out")
    cs add cscope.out
" else add the database pointed to by environment variable 
elseif $CSCOPE_DB != ""
    cs add $CSCOPE_DB
endif

" show msg when any other cscope db added
set cscopeverbose

" Default key mappings
"
"   's'   symbol: find all references to the token under cursor
"   'g'   global: find global definition(s) of the token under cursor
"   'c'   calls:  find all calls to the function name under cursor
"   't'   text:   find all instances of the text under cursor
"   'e'   egrep:  egrep search for the word under cursor
"   'f'   file:   open the filename under cursor
"   'i'   includes: find files that include the filename under cursor
"   'd'   called: find functions that function under cursor calls

nnoremap <C-\>s :cs find s <C-R>=expand("<cword>")<CR><CR>
nnoremap <C-\>g :cs find g <C-R>=expand("<cword>")<CR><CR>
nnoremap <C-\>c :cs find c <C-R>=expand("<cword>")<CR><CR>
nnoremap <C-\>t :cs find t <C-R>=expand("<cword>")<CR><CR>
nnoremap <C-\>e :cs find e <C-R>=expand("<cword>")<CR><CR>
nnoremap <C-\>f :cs find f <C-R>=expand("<cfile>")<CR><CR>
nnoremap <C-\>i :cs find i ^<C-R>=expand("<cfile>")<CR>$<CR>
nnoremap <C-\>d :cs find d <C-R>=expand("<cword>")<CR><CR>
vnoremap <C-\>t y:cs find t <C-R>=escape(@",'\\/.*$^~[]')<CR><CR>

" See below about creating the cscope.files file.
" This autocmd will remove the entries from within
" a file that cscope cannot deal with, or does not
" make sense indexing.
autocmd BufReadPost cscope.files
            \ let before_lines = line('$') |
            \ silent! exec 'silent! g/\(cscope\|\.\(gif\|bmp\|png\|jpg\|swp\)\)/d' |
            \ silent! exec 'silent! v/\./d' |
            \ let before_lines = before_lines - line('$') |
            \ if before_lines > 0 |
            \   call confirm( 'Removed ' . before_lines . ' lines from file.  ' .
            \           'These were any of the following: ' .
            \           "\n".'- image and swap files ' .
            \           "\n".'- directories ' .
            \           "\n".'- any cscope files.' .
            \           "\n\n".'Press u to recover these lines.'
            \           ) |
            \ endif

" func: CSRefreshAllConns
" {
function! CSRefreshAllConns()

    " Check if there are any cscope connections
    let saveA = @a
    redir  @a
    silent! exec 'cs show'
    redir END
    let cs_conns = @a
    let @a = saveA

    if cs_conns !~? 'no cscope connections'
        let match_regex = '\(\d\+\s\+\d\+\s\+\S\+\s\+\S\+\)'
        let index = match(cs_conns, match_regex)

        while index > -1
            " Retrieve the name of option
            let cs_conn_num = matchstr(cs_conns, '^\d\+', index)
            if strlen(cs_conn_num) > 0
                let index = (index + strlen(cs_conn_num)) 
                let cs_db_name = matchstr(cs_conns,
                            \ '\s\+\d\+\s\+\zs\S\+',
                            \ index
                            \ )
                let index = index + strlen(cs_conn_num)
                            \     + strlen(cs_db_name)
                let cs_db_path = matchstr(cs_conns,
                            \ '\s\+\zs\S\+',
                            \ index
                            \ )
                if cs_db_path =~ "<none>" || cs_db_path =~ '""'
                    let cs_db_path = ''
                endif
                let index = index + strlen(cs_conn_num)
                            \     + strlen(cs_db_name)
                            \     + strlen(cs_db_path)
                            \     + 1
                call CSReloadDB( cs_conn_num, cs_db_name, cs_db_path)
            endif
            let index = index + 1
            let index = match(cs_conns, match_regex, index)
        endwhile
    else
        if filereadable("cscope.out")
            cs add cscope.out
        endif
    endif

endfunction
" }

" func: CSReloadDB
" {
function! CSReloadDB(cs_conn_num, cs_db_name, cs_db_path)
    exec 'cs kill ' . a:cs_conn_num

    let cs_db_fullpath = fnamemodify(a:cs_db_name,":p")

    if filereadable(cs_db_fullpath)
        call CSRebuildDB(cs_db_fullpath)
        let cs_cmd = 'cs add '.cs_db_fullpath
        exec cs_cmd
    else
        echohl WarningMsg
        echomsg 'CSReloadDB - Cannot find: '.cs_db_fullpath
        echohl None
    endif
endfunction
" }

" func: CSRebuildDB
" {
function! CSRebuildDB(cs_db_fullpath)
    let cscope_files = fnamemodify(a:cs_db_fullpath,":p:h").'/cscope.files'
    if !filereadable(cscope_files)
        let csfile_cmd = 'find . -path "*/.svn" -prune -o '.
                \ '-iname "*.cpp" -o -iname "*.c" '.
                \ '-o -iname "*.h" -o -iname "*.hpp" >'
                \ .cscope_files
        let csfile_out = system(csfile_cmd)
        if v:shell_error
            echo csfile_out
        endif
    endif

    let cs_cmd = 'cscope -b '.
                \ '-f '.a:cs_db_fullpath.
                \ ' -i '.cscope_files
    let cs_out = system(cs_cmd)

    if v:shell_error
        echo cs_out
    else
        echo 'Rebuilt cscope database: ' . a:cs_db_fullpath
    endif
endfunction
" }

" Refresh cscope database
command! CSRefresh :call CSRefreshAllConns()

" vim: foldmethod=marker foldlevel=0
