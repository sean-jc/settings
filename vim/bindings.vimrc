" Ctrl+b to add Reviewed-by in insert mode
imap <C-b> Reviewed-by: Sean Christopherson <seanjc@google.com>
imap <C-t> Tested-by: Sean Christopherson <seanjc@google.com>
imap <C-k> Acked-by: Sean Christopherson <seanjc@google.com>

imap <C-p>u Pushed to branch `current` at https://github.com/kvm-x86/linux.git.<CR>
imap <C-p>n Pushed to branch `next` at https://github.com/kvm-x86/linux.git.<CR>
imap <C-p>f Pushed to branch `future` at https://github.com/kvm-x86/linux.git.<CR>

" Don't use Ex mode, use Q for formatting.
" Revert with ":unmap Q".
map Q gq

" CTRL-U in insert mode deletes a lot.  Use CTRL-G u to first break undo,
" so that you can undo CTRL-U after inserting a line break.
" Revert with ":iunmap <C-U>".
inoremap <C-U> <C-G>u<C-U>
