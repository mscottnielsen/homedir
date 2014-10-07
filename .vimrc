" A vimrc file.
"
" To use it, copy it to
"     for Unix and OS/2:  ~/.vimrc
"	      for Amiga:  s:.vimrc
"  for MS-DOS and Win32:  $VIM\_vimrc
"	    for OpenVMS:  sys$login:.vimrc
"
" Use Vim settings, rather then Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible

" allow backspacing over everything in insert mode
set backspace=indent,eol,start
" set background=dark


if has("vms")
  set nobackup		" do not keep a backup file, use versions instead
else
  set backup		" keep a backup file
endif

set history=50		" keep 50 lines of command line history
set ruler		" show the cursor position all the time
set showcmd		" display incomplete commands
set incsearch		" do incremental searching
set vb t_vb=            " diable bells and whistles
set number              " line numbers

" For Win32 GUI: remove 't' flag from 'guioptions': no tearoff menu entries
" let &guioptions = substitute(&guioptions, "t", "", "g")

" Don't use Ex mode, use Q for formatting
map Q gq

" reformat text to <=66 chars per line
map MM :%s/.\{-66,\}  */&<C-V><C-M>/g

" fill out mergereq form
let @m=':%s/Yes.No.*/& No/:%s/Reviewed By.*/& No/:%s/Additional Com.*/& No//^List reviewA :r!whoamikJ/DescriptA'


" imap fn <C-n>=expand("%:t:r")<CR>
" imap <F7> <C-N>=expand("%:t")<CR>
" inoremap \fn <C-R>=expand("%:t:r")<CR>


" This is an alternative that also works in block mode, but the deleted
" text is lost and it only works for putting the current register.
"vnoremap p "_dp

" Switch syntax highlighting on, when the terminal has colors
" Also switch on highlighting the last used search pattern.
if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
endif


" Only do this part when compiled with support for autocommands.
if has("autocmd")

  " turn syntax highlighting on all the time
  syntax on

  " Enable file type detection.
  " Use the default filetype settings, so that mail gets 'tw' set to 72,
  " 'cindent' is on in C files, etc.
  " Also load indent files, to automatically do language-dependent indenting.
  " filetype plugin indent on

  " if newer filetype settings are not available, just
  " enable file type detection.
  filetype on

  " Put these in an autocmd group, so that we can delete them easily.
  augroup vimrcEx
  au!

  " For all text files set 'textwidth' to 78 characters.
  " autocmd FileType text setlocal textwidth=78

  " When editing a file, always jump to the last known cursor position.
  " Don't do it when the position is invalid or when inside an event handler
  " (happens when dropping a file on gvim).
  autocmd BufReadPost *
    \ if line("'\"") > 0 && line("'\"") <= line("$") |
    \   exe "normal g`\"" |
    \ endif

  augroup END

  " specific for goldengate parameter files
  augroup filetypedetect
    " older vim (eg, 5.7), syntax files full path
    " au BufNewFile,BufRead *.prm so ~/.vim/syntax/prm.vim
    " au BufNewFile,BufRead *.oby so ~/.vim/syntax/prm.vim

    " modern vim, syntax files ~/.vim/syntax/{filetype}.vim
    au BufNewFile,BufRead *.prm setf prm
    au BufNewFile,BufRead *.oby setf prm

    au! BufRead,BufNewFile *.vm setf velocity
    au! BufRead,BufNewFile *.pom setf xml

    au! BufNewFile,BufRead *.groovy setf groovy
    au! BufNewFile,BufRead *.gradle setf groovy
  augroup END

  " disable bell / visual bell
  autocmd VimEnter * set vb t_vb=

  " fix friggin formatoptions
  " set formatoptions-=croq " doesn't work
  au FileType,BufNewFile,BufRead * se fo-=r fo-=o fo-=c fo-=q

else

endif " has("autocmd")

" set autoindent          " always set autoindenting on
set tabstop=4
set shiftwidth=4
set expandtab

