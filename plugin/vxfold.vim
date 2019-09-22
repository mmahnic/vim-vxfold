if vxlib#load#IsLoaded( 'vxfold' )
   finish
endif
call vxlib#load#SetLoaded( 'vxfold', 1 )

command! VxFoldOrg call vxfold#SetMode('org')
command! VxFoldTvo call vxfold#SetMode('tvo')
command! VxFoldViki call vxfold#SetMode('viki')
command! VxFoldVimWiki call vxfold#SetMode('vimwiki')
