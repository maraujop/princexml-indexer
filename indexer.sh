#!/bin/bash
# Author: Miguel Araujo Pérez @maraujop
# http://www.github.com/maraujop/

usage()
{
   cat << EOF
   usage: $0 file.xml

   Injects index references in an XML file and echoes the correspondent index entries for the file.

   OPTIONS:
      -h      Shows script help
EOF
}

while getopts "h" OPTION
do
     case $OPTION in
         h)
             usage
             exit 0
             ;;
     esac
done

if [ $# -ne 1 ] 
then
    usage
    exit 1
fi

titles=`tempfile`
cat $1 | egrep "<h[1-6][^<]*>" > $titles
filename=`basename $1`
filename=${filename%.*} 
number_lines=`cat $titles | wc -l`

for i in `seq 1 $number_lines`
do
    # We grab the line, the title and the heading's number
    current_line=`cat $titles | head -$i | tail -1 | sed -e 's/^ *//g' | sed -e 's/ *$//g'`
    current_title=`echo $current_line | sed -r -e 's+<h[1-6][^<]*>(.*)</h[1-6]>+\1+'`
    current_number=`echo $current_line | egrep -o "<h[1-6]" | grep -o "[1-6]"`

    next_line=`cat $titles | head -$(($i+1)) | tail -1 | sed -e 's/^ *//g' | sed -e 's/ *$//g'`
    next_title=`echo $next_line | sed -r -e 's+<h[1-6][^<]*>(.*)</h[1-6]>+\1+'`
    next_number=`echo $next_line | egrep -o "<h[1-6]" | grep -o "[1-6]"`


    # Inject reference in text file if it's not already there
    reference=`echo $current_line | grep -o "id=[\"\'].*[\"\']" | sed "s+id=[\"\']\(.*\)[\"\']+\1+"`
    if [ -z "$reference" ]; then
        new_line=`echo $current_line | sed -e "s+\([^<]*\)>+\1 id=\"$filename-h$i\">+"`
        sed -i "s+$current_line+$new_line+" $1
    else
        # if there is a reference and it doesn't match the current one, we need to redo the reference
        if [ "$reference" != "$filename-h$i" ]; then
            line_to_replace=`cat $1 | grep -n "$current_line" | tail -1 | cut -d ":" -f 1`
            sed -i -e "$line_to_replace s+$reference+$filename-h$i+" $1
        fi
    fi


    # We need to look ahead, to see how to handle tags 
    if [ $current_number -lt $next_number ]; then
        if [ $current_number -eq 1 ]; then
            echo "<li class=\"chapter\"><a href=\"#$filename-h$i\">$current_title</a><ul>"
        else 
            echo "<li><a href=\"#$filename-h$i\">$current_title</a><ul>"
        fi

    elif [ $current_number -eq $next_number ]; then
        if [ $current_number -eq 1 ]; then
            echo "<li class=\"chapter\"><a href=\"#$filename-h$i\">$current_title</a><ul>"
        else
            echo "<li><a href=\"#$filename-h$i\">$current_title</a></li>"
        fi
        
    elif [ $current_number -gt $next_number ]; then
        echo "<li><a href=\"#$filename-h$i\">$current_title</a></li>"
        for i in `seq 1 $(( $current_number - $next_number ))`
        do
            echo "</ul></li>"
        done
    fi


    # Closes the last open tags, at the end of the file
    if [ $i -eq $number_lines ]
    then
        for i in `seq 1 $(( $current_number -1 ))`
        do
            echo "</ul></li>"
        done
    fi
done
