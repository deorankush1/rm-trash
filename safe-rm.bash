#!/bin/bash

# TODO : handle sudo  , handle directories

NOOPERAND=1
NOSUCHFILE=2

TRASHPATH="/home/$USER/.local/share/Trash"
TRASHPATHROOT="/root/.local/share/Trash"

RECURSIVE_FLAG=0
OPTIONAL_ARGS=()
FILE_ARGS=()
NO_BACKUP_FLAG=0


usage(){
# $1 = error code ,  $2 = any file or argument name to be shown(like a file name when getting NOSUCHFILE error)
    case $1 in

    "$NOOPERAND")
        echo "$0 : missing operand" ;
        echo "Try '$0 --help' for more information" ;;
    
    "$NOSUCHFILE")
        echo "rm: cannot remove '$2': No such file or directory" ;;

    "help")
        echo "
Usage: $0 [OPTION]... [FILE]...

Remove (unlink) the FILE(s).

  --no-trash            Don't put the files in the trash , directly give all the options and files to rm command to remove them.

  -f, --force           ignore nonexistent files and arguments, never prompt
  -i                    prompt before every removal
  -I                    prompt once before removing more than three files, or
                          when removing recursively; less intrusive than -i,
                          while still giving protection against most mistakes
      --interactive[=WHEN]  prompt according to WHEN: never, once (-I), or
                          always (-i); without WHEN, prompt always
      --one-file-system  when removing a hierarchy recursively, skip any
                          directory that is on a file system different from
                          that of the corresponding command line argument
      --no-preserve-root  do not treat '/' specially
      --preserve-root   do not remove '/' (default)
  -r, -R, --recursive   remove directories and their contents recursively
  -d, --dir             remove empty directories
  -v, --verbose         explain what is being done
      --help     display this help and exit
      --version  output version information and exit

By default, safe-rm does not remove directories.  Use the --recursive (-r or -R)
option to remove each listed directory, too, along with all of its contents.

To remove a file whose name starts with a '-', for example '-foo',
use one of these commands:
  $0 -- -foo

  $0 ./-foo

Note that if you use safe-rm to remove a file it can be recovered from trash.
For greater assurance that the contents are truly unrecoverable, consider using shred. " ;;


    esac
}



deleteFromTrash(){
    if [ -e "$TRASHPATH/files/$filebasename" ]; then 
        rm -r "$TRASHPATH/files/$filebasename" ; 
        rm "$TRASHPATH/info/$filebasename.trashinfo"
    fi
}



copyToTrashAndWriteInfo(){

# $1 = relative filepath that is exisiting in the filesystem

echo "Args = $@"
filebasename="$(basename $1)"
filefullpath="$(realpath $1)"
filedirname="$(dirname $filefullpath)"

filename="$1"  # Original filename

copyToTrash(){
    # $1 = relative filepath that is exisiting in the filesystem

    if ! test -e $filename
    then echo $filename does not exist ! ; return 1
    fi

    # start the copy process
    duplicateNumber=0

    while test 1 -eq 1
    do
    echo "duplicate Number = $duplicateNumber"

    # first time try to move to trash
    if test "$duplicateNumber" -eq 0
        then
            if ! test -e "$TRASHPATH/files/$filebasename"
            then
                cp -r "$filename"  "$TRASHPATH/files/$filebasename" -n
                if test $? -eq 0
                    then 
                    return 0 ; 
                else 
                    echo "Error copying the $filename to trash. Trying to move $filename with the name $filename ($duplicateNumber)"
                    return 1 ; 
                fi
            fi

    # if file already present write duplicate filenames followed by duplicate Number
        else
            if ! test -e "$TRASHPATH/files/$filebasename ($duplicateNumber)"
            then
                cp -r "$filename" "$TRASHPATH/files/$filebasename ($duplicateNumber)"
                if test $? -eq 0
                then
                    filebasename="$filebasename ($duplicateNumber)" 
                    filefullpath="$(realpath $filedirname/"$filebasename")"
                    return 0 ; 
                else
                    echo "Error copying the $filename to trash. Trying to move $filename with the name $filename ($duplicateNumber)"
                    return 1 ; 
                fi
            fi
    fi
    
    ((duplicateNumber++))

    done
    }

    writeTrashInfo(){
        #function Depends on variables filefullpath , filebasename
        # The filefullpath can also be modified filename with the duplicate number
        # The filebasename can  also be modified filename with the duplicate number

        trashmsg="[Trash Info]\nPath=$(realpath $filename)\nDeletionDate=$(date -Is)"
        echo -e "$trashmsg" | tee "$TRASHPATH/info/$filebasename.trashinfo"
    }

    copyToTrash  &&  writeTrashInfo  # main calls
}



main(){

    echo "RECURSION : $RECURSIVE_FLAG" ; 
    LOOPENTERFLAG=0

    for file in ${FILE_ARGS[@]}
    do
        LOOPENTERFLAG=1
        echo "file =$file"
        if test -e "$file" && test -r "$file" ; then

            if test -d "$file" && test "$RECURSIVE_FLAG" == "0" ; then 
                rm ${OPTIONAL_ARGS[@]} "$file"
                continue ;
            fi
            copyToTrashAndWriteInfo "$file"
            rm ${OPTIONAL_ARGS[@]} "$file"  || deleteFromTrash

        else
            rm ${OPTIONAL_ARGS[@]} "$file"
        fi

    done

    if [ $LOOPENTERFLAG -eq 0 ] ; then 
        rm ${OPTIONAL_ARGS[@]}
    fi
}


handleArguments(){
    # requires the argument array of the script $@

    if [ $# -eq 0 ] ; then 
        usage 1
        exit 1
    fi

    for arg in $@ ; do 

        if [ "${arg:0:1}" == '-' ] ; then
            if [ "$arg" == "--no-trash" ] ;then 
                NO_BACKUP_FLAG=1
                continue ; 
            fi
            
            OPTIONAL_ARGS+=($arg)
        else 
            FILE_ARGS+=($arg)
        fi

        case "$arg" in 
            '--help') 
                usage 'help'
                exit 0 ;;

            '--recursive') RECURSIVE_FLAG=1 ;; 

            *)
                if [ "${arg:0:1}" == '-' -a "${arg:1:1}" != '-' ] ;then
                    for (( i=0; i<${#arg}; i++ )) ; do

                        case "${arg:$i:1}" in

                            r|R) RECURSIVE_FLAG=1 ;; 

                        esac
                    done
                fi
        esac
    done

    if [ $NO_BACKUP_FLAG -eq 1 ] ; then 
        rm ${OPTIONAL_ARGS[@]} "${FILE_ARGS[@]}"
        exit 0
    fi
}



handleArguments $@
echo ${OPTIONAL_ARGS[@]}
echo ${FILE_ARGS[@]}
main $@