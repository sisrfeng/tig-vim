" Author: iberianpig
" Created: 2017-04-03

scriptencoding utf-8

if !exists('g:loaded_tig_explorer')
    finish
en
let g:loaded_tig_explorer = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

" Public

fun! tig_explorer#open(str) abort
    :call s:exec_tig_command(s:strip_commit(a:str))
endf

fun! tig_explorer#open_current_file() abort
    let current_path = expand('%:p')
    :call tig_explorer#open(current_path)
endf

fun! tig_explorer#open_project_root_dir() abort
    try
        let root_dir = s:project_root_dir()
    catch
        echoerr 'tig-explorer.vim: ' . v:exception
        return
    endt
    :call tig_explorer#open(root_dir)
endf

fun! tig_explorer#grep(str) abort
    if a:str ==# ''
        let word = s:input('Pattern: ')
    el
        let word = a:str
    en

    " if canceled
    if word ==# '0'
        return
    elseif word ==# '-1'
        return
    en

    let g:tig_explorer_last_grep_keyword = word

    " NOTE: Escape shellwords
    if !get(g:, 'tig_explorer_use_builtin_term', has('terminal'))
        let args = s:shellwords(word)
        let escaped_word = ''

        for arg in args
            let escaped_word = join([escaped_word, shellescape(arg, 1)], ' ')
        endfor
        let word = escaped_word
    en

    :call s:exec_tig_command('grep ' . word)
endf

fun! tig_explorer#grep_resume() abort
    let keyword = get(g:, 'tig_explorer_last_grep_keyword', '')
    :call tig_explorer#grep(keyword)
endf

fun! tig_explorer#blame() abort
    " extract the current commit if a path as the shape commit:file
    " which happend when using TigOpenWithCommit
    let parts = split(expand('%'), ':')
    if len(parts) == 2
        let commit = parts[0]
        let file = parts[1]
        call s:exec_tig_command('blame ' . commit .' +' . line('.') . ' -- '. file)
    el
        let root_dir = fnamemodify(s:project_root_dir(), ':p')
        let file = substitute(expand('%:p'), root_dir, "./", "")
        call s:exec_tig_command('blame +' . line('.') . ' ' . file)
    en
endf

fun! tig_explorer#status() abort
    call s:exec_tig_command('status')
endf

" Open a file for the given commit
" Usefull when editing file from tree or blame view
fun! tig_explorer#open_file_with_commit(diff, mods, commit, file, lineno)
    let commit = get(a:, 'commit', 'HEAD')
    let file = get(a:, 'file', '')
    let lineno = get(a:, 'lineno', 0)

    let file0 = ''
    " if no file is provided use the current one
    if file == ''
        let file0 = expand('%')
        let diff = 1
    el
        let file0 = expand(file)
    en
    " split commit file if needed
    echomsg file0
    let parts = split(file0, ':')
    if len(parts) == 2
        let commit = substitute(commit, '%',  parts[0],'' )
        let file = parts[1]
    el
        let file = parts[0]
        let commit = substitute(commit, '%', 'HEAD','')
    en
    if a:diff == '!'
        diffthis
    en
    let ref = commit.":".file
    echomsg ref
    if bufexists(ref)
        if a:diff == '!'
            exe  a:mods "edit" ref
        el
            exe  a:mods "split" ref
        en
    el
        let ftype=&filetype
        if a:diff == '!'
            exe  a:mods "new"
        el
            exe  a:mods "enew"
        en
        exe  "file" ref
        exe  "r !git show ".ref
        let &filetype=ftype
        setl  nomodified
        setl  nomodifiable
        setl  readonly
        exe  "+" lineno
    en
    if a:diff=='!'
        diffthis
    en
endf



" Private

fun! s:tig_available() abort
    if !executable('tig')
        echoerr 'You need to install tig.'
        return 0
    en
    return 1
endf

fun! s:initialize() abort

    fun! s:set_orig_tigrc(path) abort
        if filereadable(expand(a:path))
            let s:orig_tigrc=a:path
            return 1 "true
        else
            return 0 "fail
        en
    endf

    if exists('g:tig_explorer_orig_tigrc')
        let result = s:set_orig_tigrc(g:tig_explorer_orig_tigrc)
    el
        let result = s:set_orig_tigrc('$XDG_CONFIG_HOME/tig/config') ||
               \ s:set_orig_tigrc('~/.config/tig/config') ||
               \ s:set_orig_tigrc('~/.tigrc') ||
               \ s:set_orig_tigrc('/etc/tigrc')
    en

    if !result
        echomsg  'tig-explorer.vim: tigrc is not found'
        let s:orig_tigrc = tempname() "workaround
        exec 'silent ! touch ' . s:orig_tigrc
    en

    let s:tmp_tigrc = tempname()
    let s:path_file = tempname()

    let s:keymap_edit_e  = get(g:, 'tig_explorer_keymap_edit_e',  'e')
    let s:keymap_edit    = get(g:, 'tig_explorer_keymap_edit',    '<C-o>')
    let s:keymap_tabedit = get(g:, 'tig_explorer_keymap_tabedit', '<C-t>')
    let s:keymap_split   = get(g:, 'tig_explorer_keymap_split',   '<C-s>')
    let s:keymap_vsplit  = get(g:, 'tig_explorer_keymap_vsplit',  '<C-v>')

    let s:keymap_commit_edit    = get(g:, 'tig_explorer_keymap_commit_edit',    '<ESC>o')
    let s:keymap_commit_tabedit = get(g:, 'tig_explorer_keymap_commit_tabedit', '<ESC>t')
    let s:keymap_commit_split   = get(g:, 'tig_explorer_keymap_commit_split',   '<ESC>s')
    let s:keymap_commit_vsplit  = get(g:, 'tig_explorer_keymap_commit_vsplit',  '<ESC>v')


    let s:before_exec_tig  = s:plugin_root . '/script/setup_tmp_tigrc.sh'
                        \ . ' ' . s:orig_tigrc
                        \ . ' ' . s:tmp_tigrc
                        \ . ' ' . s:path_file
                            \ . ' "' . s:keymap_edit_e  . '"'
                            \ . ' "' . s:keymap_edit    . '"'
                            \ . ' "' . s:keymap_tabedit . '"'
                            \ . ' "' . s:keymap_split   . '"'
                            \ . ' "' . s:keymap_vsplit  . '"'
                                    \ . ' "' . s:keymap_commit_edit    . '"'
                                    \ . ' "' . s:keymap_commit_tabedit . '"'
                                    \ . ' "' . s:keymap_commit_split   . '"'
                                    \ . ' "' . s:keymap_commit_vsplit  . '"'

    let s:tig_prefix = 'TIGRC_USER=' . s:tmp_tigrc . ' '
endf

fun! s:tig_callback(exit_code) abort
    if a:exit_code == 0
        if has('nvim')
            sil! Bclose!
        el
            let current_buf = bufnr('%')
            sil! buffer #
            " NOTE: Prevent to quit vim
            if winnr('$') == 1 && bufnr('%') ==# current_buf
                enew
            en
        en
    en

    try
        call s:open_file()
    endt
endf

fun! s:exec_tig_command(tig_args) abort
    if !s:tig_available()
        return
    en

    let current_dir = getcwd()
    try
        let root_dir = s:project_root_dir()
    catch
        echoerr 'tig-explorer.vim: ' . v:exception
        return
    endt
    exe  'lcd ' . fnamemodify(root_dir, ':p')
         "\ Tig command must be executeed from project root, since
             " TigBlame or Edit are broken if execute from a relative path
    if !filewritable(root_dir . '/.git')
        echoerr(".git is not writable")
        return
    en

    let command = s:tig_prefix  . 'tig' . ' ' . a:tig_args
    exec 'silent !' . s:before_exec_tig
    if has('nvim')
        enew
        call termopen(command, {
                         \ 'name'    : 'tig',
                         \ 'on_exit' : {job_id, code, event -> s:tig_callback(code)},
                        \ })
        startinsert
    elseif get(g:, 'tig_explorer_use_builtin_term', has('terminal'))
        call term_start('env ' . command, {
                 \ 'term_name': 'tig',
                 \ 'curwin': v:true,
                 \ 'term_rows' : winheight('%'),
                 \ 'term_cols' : winwidth('%'),
                 \ 'term_finish': 'close',
                 \ 'exit_cb': {status, code -> s:tig_callback(code)},
                 \ })
    el
        exec 'silent !' . command
        call s:open_file()
    en

    " NOTE: Back to current_dir
    exe  'lcd ' . fnamemodify(current_dir, ':p')
    redraw!
endf

fun! s:open_file() abort
    if !filereadable(s:path_file)
        return
    en

    let current_dir = getcwd()
    try
        exe  'lcd ' . fnamemodify(s:project_root_dir(), ':p')
        for f in readfile(s:path_file)
            exec f
        endfor
    finally
        call delete(s:path_file)
        exe  'lcd ' . fnamemodify(current_dir, ':p')
    endt
endf

fun! s:project_root_dir() abort
    let current_file_dir = expand('%:p:h')
    let git_dir = findfile('.git', current_file_dir . ';')
    if git_dir ==# ''
        let git_dir = finddir('.git', current_file_dir . ';')

        if git_dir ==# ''
            throw 'Not a git repository: ' . current_file_dir
        en

        let git_module_dir = finddir('modules', current_file_dir . ';')
        if git_module_dir !=# ''
            let git_module_dir_git = finddir('.git', fnamemodify(git_module_dir, ':p') . ';')
            if fnamemodify(git_module_dir_git, ':p') ==# fnamemodify(git_dir, ':p')
                " Now in submodule's config dir

                let git_submodule_index = findfile('index', current_file_dir . ';')
                if git_submodule_index !=# ''
                    let git_submodule_dir = fnamemodify(git_submodule_index, ':p:h')
                    let git_submodule_workdir = trim(system('cd ' . git_submodule_dir . '&& git config --get core.worktree'))
                    if git_submodule_workdir !=# ''
                        let git_submodule_workdir = glob(git_submodule_dir . '/' . git_submodule_workdir)
                    en
                en
            en
        en
    en

    if exists("git_submodule_workdir") && git_submodule_workdir !=# ''
        let root_dir = git_submodule_workdir
    el
        if isdirectory(git_dir)
            " XXX:  `:p` fullpath-conversion attaches `/` in the tail of dir path, e.g. `dir/.git/` .
            "       Due to this, give one more `:h` modifier to remove the last part or `.git` .
            let root_dir = fnamemodify(git_dir, ':p:h:h')
        el
            let root_dir = fnamemodify(git_dir, ':p:h')
        en
    en

    if !isdirectory(root_dir)
        return current_file_dir
    en
    return root_dir
endf

fun! s:shellwords(str) abort "make list by splitting the string by whitespace
    let words = split(a:str, '\%(\([^ \t\''"]\+\)\|''\([^\'']*\)''\|"\(\%([^\"\\]\|\\.\)*\)"\)\zs\s*\ze')
    let words = map(words, 'substitute(v:val, ''\\\([\\ ]\)'', ''\1'', "g")')
    let words = map(words, 'matchstr(v:val, ''^\%\("\zs\(.*\)\ze"\|''''\zs\(.*\)\ze''''\|.*\)$'')')
    return words
endf


" return 0 (<ESC>) or -1 (<Ctrl-c>)
fun! s:input(...) abort
    new
    cno  <buffer> <silent> <Esc> __CANCELED__<CR>
    try
        let input = call('input', a:000)
        let input = input =~# '__CANCELED__$' ? 0 : input
    catch /^Vim:Interrupt$/
        let input = -1
    finally
        bwipeout!
        redraw!
        return input
    endt
endf

fun! s:strip_commit(path)
    return substitute(a:path, '^[^:]*:','','')
endf
" Initialize

" NOTE: '<sfile>' must be called top level
let s:plugin_root=expand('<sfile>:p:h:h')

call s:initialize()

let &cpoptions = s:save_cpo
unlet s:save_cpo


