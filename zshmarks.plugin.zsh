# ------------------------------------------------------------------------------
#          FILE:  zshmarks.plugin.zsh
#   DESCRIPTION:  oh-my-zsh plugin file.
#        AUTHOR:  Jocelyn Mallon
#       VERSION:  1.7.0
# ------------------------------------------------------------------------------

# Set BOOKMARKS_FILE if it doesn't exist to the default.
# Allows for a user-configured BOOKMARKS_FILE.
if [[ -z $BOOKMARKS_FILE ]] ; then
	export BOOKMARKS_FILE="$HOME/.bookmarks"
fi

# Check if $BOOKMARKS_FILE is a symlink.
if [[ -L $BOOKMARKS_FILE ]]; then
	BOOKMARKS_FILE=$(readlink $BOOKMARKS_FILE)
fi

# Create bookmarks_file it if it doesn't exist
if [[ ! -f $BOOKMARKS_FILE ]]; then
	touch $BOOKMARKS_FILE
fi

fzfcmd() {
   [ ${FZF_TMUX:-1} -eq 1 ] && echo "fzf -d${FZF_TMUX_HEIGHT:-40%}" || echo "fzf"
}

_zshmarks_move_to_trash(){
	if [[ $(uname) == "Linux"* || $(uname) == "FreeBSD"*  ]]; then
		label=`date +%s`
		mkdir -p ~/.local/share/Trash/info ~/.local/share/Trash/files
		\mv "${BOOKMARKS_FILE}.bak" ~/.local/share/Trash/files/bookmarks-$label
		echo "[Trash Info]
Path=/home/"$USER"/.bookmarks
DeletionDate="`date +"%Y-%m-%dT%H:%M:%S"`"
">~/.local/share/Trash/info/bookmarks-$label.trashinfo
	elif [[ $(uname) = "Darwin" ]]; then
		\mv "${BOOKMARKS_FILE}.bak" ~/.Trash/"bookmarks"$(date +%H-%M-%S)
	else
		\rm -f "${BOOKMARKS_FILE}.bak"
	fi
}

function bookmark() {
	local bookmark_name=$1
	if [[ -z $bookmark_name ]]; then
				bookmark_name="${PWD##*/}"
		fi
		cur_dir="$(pwd)"
		# Replace /home/uname with $HOME
		if [[ "$cur_dir" =~ ^"$HOME"(/|$) ]]; then
				cur_dir="\$HOME${cur_dir#$HOME}"
		fi
		# Store the bookmark as folder|name
		bookmark="$cur_dir|$(basename "$PWD")"
		if [[ -z $(grep "$bookmark" $BOOKMARKS_FILE 2>/dev/null) ]]; then
				echo $bookmark >> $BOOKMARKS_FILE
				echo "Bookmark '$bookmark_name' saved"
		else
				echo "Bookmark already existed"
				return 1
		fi
}

__zshmarks_zgrep() {
	local outvar="$1"; shift
	local pattern="$1"
	local filename="$2"
    local file_lines; mapfile -t file_lines < $filename;
	for line in "${file_lines[@]}"; do
        echo $line
		if [[ $line =~ $pattern ]]; then
			$outvar=\"$line\"
			return 0
		fi
	done
	return 1
}

function jump() {
	local bookmark_name=$1
	if [ $# -eq 0 ]; then
    	local jumpline=$(cat ${BOOKMARKS_FILE} | $(fzfcmd) --bind=ctrl-y:accept --tac)
    	eval "cd \"${jumpline%%|*}\"" && clear
	else
	local bookmark
	if ! __zshmarks_zgrep bookmark "\\|$bookmark_name\$" "$BOOKMARKS_FILE"; then
		local code_root_dirs=$(echo $CODE_ROOT_DIRS | sed 's/:/ /g')
		local search_dirs="\"$code_root_dirs\""
		while IFS='' read -r line || [[ -n "$line" ]]; do
			search_dirs+=" \"${line%%|*}\""
		done < $BOOKMARKS_FILE
        if [ $# -ne 0 ]; then
            local jumpline=$(eval "fd $bookmark_name $search_dirs -H -t d -d 4 | $(fzfcmd) --bind=ctrl-y:accept --tac")
        fi
        if [[ $jumpline ]]; then
	        eval "cd \"${jumpline:=\"$PWD\" }\"" && clear
	    else
			echo "Invalid name, please provide a valid bookmark name. For example:"
			echo "  jump foo"
			echo
			echo "To bookmark a folder, go to the folder then do this (naming the bookmark 'foo'):"
			echo "  bookmark foo"
		fi
		return 1
	else
		local dir="${bookmark%%|*}"
        echo $dir
		eval "cd \"${dir}\"" && clear
	fi
fi
}

# Show a list of the bookmarks
function showmarks() {
	local bookmark_array; mapfile -t bookmark_array < $BOOKMARKS_FILE;
	local bookmark_name bookmark_path bookmark_line
	if [[ $# -eq 1 ]]; then
		bookmark_name="*\|${1}"
		bookmark_line=${bookmark_array[(r)$bookmark_name]}
		bookmark_path="${bookmark_line%%|*}"
		bookmark_path="${bookmark_path/\$HOME/~}"
		printf "%s \n" $bookmark_path
	else
		for bookmark_line in "${bookmark_array[@]}"; do
			bookmark_path="${bookmark_line%%|*}"
			bookmark_path="${bookmark_path/\$HOME/~}"
			bookmark_name="${bookmark_line##*|}"
			printf "$bookmark_name" "$bookmark_path"
		done
	fi
}

# Delete a bookmark
function deletemark()  {
	local bookmark_name=$1
	if [[ -z $bookmark_name ]]; then
	    local marks_to_delete line
	    marks_to_delete=$(cat $BOOKMARKS_FILE | $(fzfcmd) -m --bind=ctrl-y:accept,ctrl-t:toggle-up --tac)

	    if [[ -n ${marks_to_delete} ]]; then
	        while read -r line; do
                echo $line
	            eval "sed -i '' '#${line}#d' $BOOKMARKS_FILE"
	        done <<< "$marks_to_delete"

	        echo "** The following marks were deleted **"
	        echo "${marks_to_delete}"
	    fi
	else
		local bookmark_line bookmark_search
		local bookmark_file="$(<"$BOOKMARKS_FILE")"
		local bookmark_array; bookmark_array=(${(f)bookmark_file});
		bookmark_search="*\|${bookmark_name}"
		if [[ -z ${bookmark_array[(r)$bookmark_search]} ]]; then
			eval "printf '%s\n' \"'${bookmark_name}' not found, skipping.\""
		else
			\cp "${BOOKMARKS_FILE}" "${BOOKMARKS_FILE}.bak"
			bookmark_line=${bookmark_array[(r)$bookmark_search]}
			bookmark_array=(${bookmark_array[@]/$bookmark_line})
			eval "printf '%s\n' \"\${bookmark_array[@]}\"" >! $BOOKMARKS_FILE
			_zshmarks_move_to_trash
		fi
	fi
}


_zshmark_completions() {
	COMPREPLY=()
    local session="${COMP_WORDS[COMP_CWORD]}"
    local bookmark_file="$(<"$BOOKMARKS_FILE")"
	local bookmark_array; bookmark_array=(${(f)bookmark_file});
	local bookmarks=${bookmark_array[@]##*|}

    # For autocomplete, use both existing sessions as well as directory names.
    #local sessions=( $(compgen -W "$(tmux list-sessions 2>/dev/null | awk -F: '{ print $1 }')" -- "$session") )

    COMPREPLY=( ${bookmarks[@]} )
}
