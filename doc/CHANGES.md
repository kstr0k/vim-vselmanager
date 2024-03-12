# CHANGELOG

## visualMarks version 0.1

- mark selections in unnamed buffers
- added documentation
- make all this a Pathogen-friendly Vim plugin
- save the type of visual mode (v, V, `<c-v>`)
- optional file location for the file with `g:vselmanager_DBFile`
- choose whether or not leaving visual mode after having set a mark with `g:vselmanager_exitVModeAfterMarking`
- when restoring selection in a folded block, recursively unfold to show it
- make the marks specific to each file.
- warn the user when trying to get a unexistent mark
- save the marks in a VimScript dictionary variable
