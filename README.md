# chbuf.vim

## What is it?

A way of jumping to loaded buffers, elements of `v:oldfiles` and `:lcd`'ing
optimised for minimal number of key strokes.

## Status

Ready to use.

## Installation

Assuming you have Pathogen up and running:

    $ cd ~/.vim/bundle
    $ git clone git://github.com/adaszko/chbuf.vim

## Setup

Simply add a mapping of your choice to `.vimrc`, e.g.:

    noremap <silent> <Leader>b :ChangeBuffer<CR>
    noremap <silent> <Leader>B :ChangeMixed<CR>
    noremap <silent> <Leader>f :ChangeFile<CR>
    noremap <silent> <Leader>c :ChangeDirectory<CR>

Note that functions above respect `ignorecase`, `wildignore` and `suffixes`
where appropriate.

## Bugs

It's generally slower on Windows.

## To Do

 * getline.txt help file
 * chbuf.txt help file
 * Tiny GIF screencast

## License

BSD3
