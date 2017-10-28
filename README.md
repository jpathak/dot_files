# dot_files

Collection of my (public) dotfiles

# What
This is a dot-file that you call in bash to increase your command line productivity.

# Why
Many commands that I use day-to-day including searching accessing and opening files in large projects. This dot_file leverages the power of Google's codesearch project (https://github.com/google/codesearch). Feel free to modify/contribute as you see fit. 

# Getting started
Follow instructions to install https://github.com/google/codesearch.
Source this script from your shell
Enjoy!

# Common commands
1) Search for a tag in the index
  f \<tag\>

2) Open the results of the search in your favorite editor ($EDITOR)
  r \<number of the result\>
  
3) Search and open a file with name \<name\>
  fo \<name\>
  Output: If there are multiple matches, then it will give you a numbered list. Use the same command again with a number to open.

4) Use any git commands with the same numbered syntax:
  All git commands including git status/branch work as expected with a combination of r/fo. In addition all git commands are shortened to the following abbreviations: (from the script)

*  alias gch='git_command checkout'
*  alias gd='git_command diff '
*  alias ga='git_command add '
*  alias gl='git_command log '
*  alias gan='git_command annotate '
*  alias gr='git_command reset '
*  alias gs='git_command status'
*  alias gb='git_command branch'
*  alias g='git'
*  alias grp='git review post'
*  alias grs='git review submit'
*  alias gro='git review open'
*  alias gsh='git show'
