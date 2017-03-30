" Use Vim settings, rather then Vi settings.
" This must be first, because it changes other options as a side effect.
set nocompatible

" allow backspacing over everything in insert mode
set backspace=indent,eol,start
" set background=dark

" allow 'p' to paste from clipboard, vs "+GP
" set clipboard=unnamedplus

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
  filetype plugin indent on

  " if newer filetype settings are not available, just
  " enable file type detection.
  " filetype on

  " For all text files set 'textwidth' to 78 characters.
  " autocmd FileType text setlocal textwidth=78

  " jump to the last known cursor position, if valid
  autocmd BufReadPost *
    \ if line("'\"") > 0 && line("'\"") <= line("$") |
    \   exe "normal g`\"" |
    \ endif

  " disable bell / visual bell
  autocmd VimEnter * set vb t_vb=

  " set formatoptions-=croq " doesn't work on all vim
  au FileType,BufNewFile,BufRead * se fo-=r fo-=o fo-=c fo-=q
endif " has("autocmd")

" set autoindent          " always set autoindenting on
set tabstop=4
set shiftwidth=4
set expandtab

