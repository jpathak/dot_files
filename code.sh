#!/usr/bin/env bash

# WARNING: WIP!!

# Feature requeest: 1) Add fr: Ability to search in set of files specified by previous search results


# Check if csearch exists
if [[ ! $(which csearch) =~ "csearch" ]]; then
    echo "csearch not found! Please install csearch "
        "(https://github.com/google/codesearch) before continuing"
fi

#
# Function f 'find' (a tag in code)
# Use the command cindex to generate the index
# and the env var CSEARCHINDEX to be able to locate it
# Usage:
# f <text to find> [filetype]
# If this is a git repository, then it will build an index and
# search it in the index. If not, it will use the usual grep
csr=()
print_f_command_output=1
function f() {

    is_git_command=0
    # Update CSEARCHINDEX
    update_csearch
    csr=()
    extension='*'
    if (( "$#" == 2 )) ; then
        extension="*.$2"
    fi
    OLDIFS=$IFS

    # using "script" preserves color formatting
    # which can be then piped into the csr array
    # Regular search runs on grep
    echo "Searching files of type (regex): $extension"
    if [[ ! -e $CSEARCHINDEX ]]; then
        echo "Using regular search..."
        extension="$extension"
        echo "Extension is $extension"
        IFS=$'\n' csr=($(find . -name "$extension" -exec grep -H -rnie "$1" {} \; | nl -b a))
    else
        echo "Using indexed search, index=$CSEARCHINDEX"
        # "Fast" search runs on csearch
        IFS=$'\n' csr=($(csearch -f ".$extension\$" -n "$1" | grep --color=always "$1" | nl -b a -d '\n'))
    fi

    if [[ $print_f_command_output == 1 ]]; then
        printf '%s\n' "${csr[@]}"
    fi
    print_f_command_output=1
    IFS=$OLDIFS

    # If only one result, take me there already!
    if [ ${#csr[@]} -eq 1 ]; then
        r 1
    fi
}

# f with grep for convenience but which stores csr correctly
# This does a two level pass by searching *within*  the results provided by f <tag>.
# With f <tag>, if you get too many results and pipe them to a regular grep,
# you cannot search and then open the result (f <tag> | grep "foo" and then subsequent
# fo 2 doesn't work) since there is currently a bug with result numbering. (Result numbering
# doesn't get stored if the results of f <tag> are piped to any other command). A possible fix
# for this is to pipe it to a file and not keep it in memory, but there are pros and cons to that.
function ff()
{
    echo "args: $1 $2"
    print_f_command_output=0
    f $1 && f $1 | grep $2
}

function update_csearch() {
    # Check if this is a git repository
    if [[ $(git rev-parse --show-toplevel) ]]; then

        # Set csearchindex to the top of the development directory of this
        # git repo
        export CSEARCHINDEX="$(git rev-parse --show-toplevel)"/.csearchindex

        # Create the search index if it doesn't exist already in the repo path
        if [[ ! -e $CSEARCHINDEX ]] || [[ $1 ]]; then
            echo "Updating code search index. Use CTRL-C to cancel if necessary!"
            pushd $(git rev-parse --show-toplevel)
            cindex .
            popd

            # Exclude search index from git changes
            printf ".csearchindex\n" >> "$(git rev-parse --show-toplevel)"/.git/info/exclude
        fi
    else
        CSEARCHINDEX=""
    fi
}

# Reference the code results generated above in f()
# Usage:
# r <number against line number of result>
function r() {
    OLDIFS=$IFS
    IFS=$' '
    openEditorAt $(resolve $1)``
    IFS=$OLDIFS
}

# Utility function to get the filename at line number
# from the catch-all array csr
function resolve() {
    with_linenum=${2:-1}
    if [[ $is_git_command == 1 ]]; then
        if [[ $previous_command_type == "blame" ]]; then
            # Tell resolve how to parse blame output
            echo ${csr[$1 - 1]} | awk '{print $2}'
        else
            temp=$(echo ${csr[$1 - 1]} | sed -E "s/.*( .*)/\1/g")
            echo $temp | sed "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | awk '{ print $NF }' | tr -d '[[:cntrl:]]'
        fi
    else
        temp=$(echo ${csr[$1 - 1]} | sed -E "s/"$'\E'"\[([0-9]{1,3}((;[0-9]{1,3})*)?)?[m|K]//g")
        if [[ $with_linenum == 1 ]]; then
            # echo $temp | sed "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | perl -pe's/^\s*[0-9]+\s+([^\s:]*):*([0-9]+)*:*.*$/\1 \2/'
            echo $temp | sed "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | sed -rn "s/^[^\/]+([^:]+):([0-9]+):.*/\1 \2/p"
        else
            echo $temp | sed "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | perl -pe's/^\s*[0-9]+\s+([^\s:]*):*([0-9]+)*:*.*$/\1/'
        fi
    fi
}

# function resolve() {
#     with_linenum=${2:-1}
#     if [[ $is_git_command == 1 ]]; then
#         temp=$(echo ${csr[$1 - 1]} | sed -E "s/.*( .*)/\1/g")
#         echo $temp | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | awk '{ print $NF }' | tr -d '[[:cntrl:]]'
#     else
#         temp=$(echo ${csr[$1 - 1]} | sed -E "s/"$'\E'"\[([0-9]{1,3}((;[0-9]{1,3})*)?)?[m|K]//g")
#         if [[ $with_linenum == 1 ]]; then
#             echo $temp | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | perl -pe's/^\s*[0-9]+\s+([^\s:]*):*([0-9]+)*:*.*$/\1 \2/'
#         else
#             echo $temp | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | perl -pe's/^\s*[0-9]+\s+([^\s:]*):*([0-9]+)*:*.*$/\1/'
#         fi
#     fi
# }

# Utility function to open a file at line number
# Usage:
# openEditorAt <file> <lineno>
function openEditorAt() {
    if [[ -z $2 ]]; then
        $EDITOR $1
    else
        if [[ "$EDITOR" =~ "subl" ]]; then
            $EDITOR $1:$2
        else
            $EDITOR +$2 $1
        fi
    fi
}

# Utility function to compare versions
function compare_version_lesser() {
    test "$(echo "$@" | tr " " "\n" | sort -nr | head -n 1)" != "$1";
}

# With all the stuff around bash and colors,
# this command is useful to find out what exactly being
# displayed on the terminal
# Usage:
# ls | show_hidden
alias show_hidden="tr -dc '[:print:]' | od -c"
alias ci='CSEARCHINDEX="$(git rev-parse --show-toplevel)"/.csearchindex; cindex .'

# Is the argument a number ?
is_num_result=""
function is_num() {
    if [[ $1 =~ ^[0-9]+$ ]]; then
        is_num_result="yes"
    else
        is_num_result="no"
    fi
}

# Is the command being run a generating command
# (from which a further action may be performed:
# git status gives a list of modified files and
# you choose a file to open or diff, or
# git branch gives a list of branches to checkout)
is_generating_command="no"
function is_gen_command() {
    # Currently only two generating command trees
    # f and git status | show | log | branch.
    arg=$1
    if [[ $1 =~ -- ]]; then
        arg=$2
    fi
    if [[ $arg == "status" ||
          $arg == "show" ||
          $arg == "log" ||
          $arg == "cpplint" ||
          $arg == "branch" ]]; then
        if [[ $arg == "cpplint" ]]; then
            is_git_command=0
        fi
        is_generating_command="yes"
    else
        is_generating_command="no"
    fi
}

# Is my workspace dirty ? (for this branch)
clean="no"
function is_workspace_dirty() {
    if [[ ${csr[@]} =~ "working directory clean" ]]; then
        clean="yes"; else clean="no";
    fi
}

# Run a git command with special conditions
# Examples of conditions include:
# 1) Is this a generating command ? (command which produces output
#   from which you would need to perform further actions)
# 2) Is the argument to the command a number ?
is_git_command=0
previous_command_type=""
function git_command() {
    is_git_command=1
    is_generating_command="no"
    numbered_command $@
    previous_command_type=$1
}

# TODO : get color back
function git_generating_command() {
    is_git_command=1
    is_generating_command="yes"
    numbered_command $@
    previous_command_type=$1
}

function numbered_generating_command() {
    is_generating_command="yes"
    is_git_command=0
    numbered_command $@
    previous_command_type=$1
}

function numbered_command() {
    clean="yes"
    #is_gen_command $@
    OLDIFS=$IFS
    command=$1
    # Either there was a git generating command or
    # a f() generating command
    if [[ $is_generating_command == "yes" ]]; then
        if [[ $is_git_command == 1 ]]; then
            command='git'
        fi
        arg=$@
        is_num ${@: -1}
        if [[ $is_num_result == "yes" ]]; then
            arg="${@:1:$(($#-1))} $(resolve ${@: -1})"
        fi
        IFS=$' ' rarg=($arg) IFS=$OLDIFS
        IFS=$'\n' csr=($($command ${rarg[@]} | nl -b a))
        is_workspace_dirty
        if [[ $1 == "status" && $clean == "yes" ]]; then
            $command $@;
        else
            printf '%s\n' "${csr[@]}"
        fi
    else
        is_num $2
        if [[ $is_git_command == 1 ]]; then
            command='git'
        fi
        # $3 is any other options which were given
        if [[ $is_num_result == "yes" ]]; then
            # TODO make a better system to accept numbered arguments
            $command $1 $3 $(resolve $2 0)
        else
            $command ${@}
        fi
    fi
    is_generating_command=0
    is_num_result=""
    IFS=$OLDIFS
}

# Function to find (and open if found) files
# Arguments can include the filename or
# optionally a number which is an option
# from a previously run generating command.
# Example usage would be:
# >fo foo*
# 1 foo.cpp
# 2 foo1.cpp
# 3 foo.h
# > fo 2
# <Opens foo1.cpp>
function fo() {
    is_num $1
    # open dir option only applicable for numbered arguments
    # since there can be many matches for an arbitrary filename
    open_dir=${2:-0}
    if [[ $is_num_result == "yes" ]]; then
        if [[ $open_dir == 1 ]]; then
            pushd $(dirname $(resolve $1 0))
        else
            openEditorAt $(resolve $1)
        fi
    else
        OLDIFS=$IFS
        IFS=$'\n' csr=($(find . -name "$1" | nl -b a))
        printf '%s\n' "${csr[@]}"
        IFS=$OLDIFS
        #
        # If only one result, take me there already!
        #
        if [ ${#csr[@]} -eq 1 ]; then
            if [[ $open_dir == 1 ]]; then
                pushd $(dirname $(resolve 1 0))
            else
                r 1
            fi
        fi
    fi
}

_codeComplete()
{
    local cur=${COMP_WORDS[COMP_CWORD]}
    arr=($(find $PWD -path $SPLUNK_SOURCE/contrib -prune -o -name $cur* -exec  basename {} \;))
    arr1=$(echo ${arr[@]})
    COMPREPLY=( $(compgen -W "$arr1" -- $cur) )
}

_codeCompleteEditor()
{
    local cur=${COMP_WORDS[COMP_CWORD]}
    # arr=($(find $PWD -path $SPLUNK_SOURCE/contrib -prune -o -name $cur* -exec  basename {} \;))
    # arr=($(find $PWD -path $SPLUNK_SOURCE/contrib -prune -o -name $cur* -exec  basename {} \;))
    # arr1=$(echo ${arr[@]})
    arr1=$(fzf $cur)
    COMPREPLY=( $(compgen -W "$arr1" -- $cur) )
}

# Code completion for the fo command
# This searches, recursively under $PWD for the filename
# starting with the text completed so far
# This is different from linux code complete for ls and so on
# in that the search is recursive under the current directory
complete -F _codeComplete fo

complete -F _codeCompleteEditor gl
complete -F _codeCompleteEditor gch

# Find definition of:
function fd() {
    f "class .*$1 " h
}

function grm() {
    rm $(resolve $1 0)
}

######################################################################
# GIT COMMANDS -
# A repository of git commands wrapped in a number-referencing wrapper
# which makes it easy to run subsequent commands
# Usage:
# <command> [optional line number] <arguments that may follow the
# original command>
######################################################################
function gchb {
    # arc feature $USER/$1
    git checkout -b $USER/$1
}

function gcm() {
    git commit -a -m "$@"
}

# alias gro='git review open'
function gro() {
    # TODO Find out how you can filter for this pull request
    stash browse pull-requests
}

# Function to squash git commits
function gsq() {
    parent_branch="develop"
    if [[ $1 != "" ]]; then
        parent_branch=$1
    fi

    branch=$(git rev-parse --abbrev-ref HEAD)
    echo "Squashing branch $branch... to parent branch=$parent_branch"
    # IMPORTANT
    # git merge --squash returns a non-zero return code as expected when the merge fails
    # When this happens, you need to fix conflicts manually and then execute the remaining commands manually
    git pull && git reset --hard origin/$parent_branch && git merge --squash origin/$branch && git commit && git push origin --delete $branch && git push -u origin $branch
}

function gbl() {
    is_num $1
    if [[ $is_num_result == "yes" ]]; then
        git_generating_command blame $1
    else
        git_generating_command blame $(find . -name $1)
    fi
}

complete -F _codeComplete gbl

alias gch='git_command checkout'
alias gfch='gf; gch'
alias gbch='git checkout -b'
alias gd='git_command diff '
alias ga='git_command add '
#normal git log
alias gl='git_command log'
# git log for numbered access
alias glp='git_generating_command --no-pager log -5'
alias gan='git_command annotate '
alias gr='git_command reset '
alias gsr='git reset --soft HEAD~'
alias gs='git_generating_command status'
alias gb='git_generating_command branch'
alias gb2='git_command branch'
alias g='git'
# alias grp='git review post'
# alias grp='EDITOR=emacs arc diff --browse'
# alias grs='EDITOR=emacs git review submit'
# alias grs='EDITOR=emacs arc land'
alias gsh='git show'
alias gshn='git_generating_command show --name-only'
alias gp='git remote prune origin && git pull && update_csearch 1'
alias gpu='git push'
alias gtl='pushd $(git rev-parse --show-toplevel)'
alias gsc='git_generating_command diff master --name-only'
alias gcl='numbered_command cpplint'
alias gm='git merge'
alias gf='git_command fetch'
