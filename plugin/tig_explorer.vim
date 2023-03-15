" Author: iberianpig
" Created: 2017-04-03

scriptencoding utf-8

if exists('g:loaded_tig_explorer')
    finish
en
let g:loaded_tig_explorer = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

com!  -nargs=? Tig
      \  call tig_explorer#open(<q-args>)

com!  TigOpenCurrentFile
      \  call tig_explorer#open_current_file()

com!  TigOpenProjectRootDir
      \  call tig_explorer#open_project_root_dir()

com!  -nargs=? TigGrep
      \  call tig_explorer#grep(<q-args>)

com!  TigBlame
      \  call tig_explorer#blame()

com!  TigGrepResume
      \  call tig_explorer#grep_resume()

com!  TigStatus
      \  call tig_explorer#status()

com!  -bang -nargs=* TigOpenFileWithCommit
      \ call tig_explorer#open_file_with_commit("<bang>",<q-mods>,<f-args>)

let &cpoptions = s:save_cpo
unlet s:save_cpo

