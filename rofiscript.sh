#!/bin/bash
#
# rofimenu
#
thisscript="$0"

# Script that runs rofi in several custom rofi modi, emulating menu with submenus.
# Only one option should be used.
# No options starts rofi showing the first modi.
# Option "-show <modi>" starts rofi showing <modi>. The rest of command line is passed to rofi.
# Option "-only <modi>" starts rofi showing only <modi>. The rest of command line is passed to rofi.
# Option "-menu <menu>" calls menu function <menu> and prints menu labels from each line.
# It is used to define custom modi.
# Option "-menu <menu> <label>" calls menu function <menu> and executes command from line with <label>.
# Option "-desktop" shows desktop menu.
# Option "-desktop <X> <Y>" shows desktop menu at given position.

ROFIMENU_CONFIG="$HOME/.config/rofi/rofimenu.config"	# config file that defines menu structure
ROFIMENU_THEME="$HOME/.config/rofi/sidemenu2.rasi"		# theme file that defines menu look

# If there is no config file, write default config

if ! [ -f "$ROFIMENU_CONFIG" ] ; then
	mkdir -p "${ROFIMENU_CONFIG%/*}"
	cat > "$ROFIMENU_CONFIG"<<"_EOF_"
#!/bin/bash
# Configuration file for rofimenu script
#
# Top level menu consists of modi names from modilist.
# Modilist is a comma separated list of default modi (drun,run...) and/or custom modi.
# Names of default modi can be set as rofi options (e.g. -display-drun Applications).
# Custom modi format: "modi_name:modi_script".
# Menu functions from this script can be used as modi like this "<menu_name>:$thisscript -menu <menu_function>"
# pause needed for smooth transition when menu command refers to other modi
DELAY=0.06
delay() {
	sleep $DELAY
}
# define modi labels for menu"
DRUN="Applications"
MENU="Edit Menu"
EXIT="Exit"


# Location of Categories
modilist="\
$FAV:$thisscript -menu ${FAV#* },\
drun,\
$CAT:$thisscript -menu ${CAT#* },\
run,\
$MENU:$thisscript -menu Menu_settings,\
$EXIT:$thisscript -menu ${EXIT#* }"

# Menu functions print lines in format "label:command".
Menu_settings() {
	echo " Edit config:$GUI_EDITOR $ROFIMENU_CONFIG && $thisscript -show \'$MENU\'"
	echo " Reset config:rm $ROFIMENU_CONFIG && delay; $thisscript -show \'$MENU\'"
	echo "──────────────:true"
	echo " Edit theme:$GUI_EDITOR $ROFIMENU_THEME && $thisscript -show \'$MENU\'"
	echo " Reset theme:rm $ROFIMENU_THEME && delay; $thisscript -show \'$MENU\'"
}

Exit() {
	echo " lock:screenlock"
	echo " suspend:systemctl suspend"
	echo " hibernate:systemctl hibernate"
	echo " logout:xdotool key --clearmodifiers super+shift+q"
	echo " reboot:systemctl reboot"
	echo " poweroff:systemctl poweroff"
}


Categories() {
	SUBMENU_MARK=""
	IFS='
'
	# Newline separated list, each line has format "[symbol ][alias:]category"
	# Category with alias will be shown in menu under that alias
	# The first entry below is an alias for " " so it shows all applications
desired="\
 Applications:
 Favorites
 Accessories:Utility
 Development
 Documentation
 Education
 Graphics
 Internet:Network
 Multimedia:AudioVideo
 Office
 Settings
 System"
	# determine max line length and set tab position for subcategory mark
	maxlength=0
	for line in $desired ; do
		label="${line%:*}"
		if [ ${#label} -gt $maxlength ] ; then
			maxlength=${#label}
		fi
	done
	submenu_tab=$(($maxlength+3))

	present="$(grep Categories /usr/share/applications/*.desktop \
		| cut -d'=' -f2 \
		| sed 's/;/\n/g' \
		| LC_COLLATE=POSIX sort --ignore-case --unique)"
	linenumber=0
	for line in $desired ; do
		category="${line##*[ :]}"
		label="$(echo -e ${line%:*}\\t${SUBMENU_MARK} | expand -t $submenu_tab)"	## add submenu mark
		if [ $(echo "$present"|grep -w -c "$category") -gt 0 ] ; then
			echo "$label:activate_category \"$label\" \"$category\" $linenumber"
			linenumber=$(($linenumber+1))
		fi
	done
}
# Desktop menu parameters
DT_MODI="Desktop:$thisscript -menu Desktop"
Desktop() {
	echo " Terminal:default-terminal"
	echo " File Manager:xdg-open ~"
	echo " Browser:default-browser"
	#TODO determine number of lines before categories
	addlinenumber=3
	eval $(xdotool search --class rofi getwindowgeometry --shell)
	Categories|sed "s/\$/ $addlinenumber $X $Y/"	# pass additional lines number, X, Y
	echo " Search:rofi-finder.sh"
}
DT_WIDTH=200		# pixels
##TODO determine desktop menu line height according to theme
DT_LINE_HEIGHT=23	# pixels
DT_THEME="
*{
	lines:		20;
	scrollbar:	false;
	dynamic:	true;
}
#window {
	width:		${DT_WIDTH}px;
	children:	[ dt-mainbox ];
}
#mode-switcher {
	enabled:	false;
}
#button {
	width:		${DT_WIDTH}px;
	padding:	2px 1ch;
}
#inputbar {
	enabled:	false;
}"
activate_category() {	# shows drun modi filtered with category. If no command selected, returns to categories modi
	label="${1% *}"	# remove submenu mark
	category="$2"
	linenumber="$3"
	theme=""
	goback="$thisscript -show \"$CAT\""
	if [ $# -gt 3 ] ; then	# that means categories for desktop menu, number of lines before categories, X, Y
		addlinenumber=$4
		X=$5
		Y=$6
		linenumber=$(($linenumber+$addlinenumber))
		if [ $linenumber -gt 0 ] ; then
			i=$linenumber
			dummy="true"
			dummyline="textboxdummy"
			while [ $i -gt 1 ] ; do
				dummyline="textboxdummy,$dummyline"
				i=$(($i-1))
			done
		else
			dummy="false"
		fi
		# adjust X if too close to the right side of the screen
		MAX_X=$(wattr w $(lsw -r) )
		anchor="north"
		if [ $X -gt $((${MAX_X}-${DT_WIDTH}*2)) ] ; then
			anchor="${anchor}east"
			X=$MAX_X
		else
			anchor="${anchor}west"
		fi
		theme="$DT_THEME
			* {
				x-offset:	$X;
				y-offset:	$Y;
				anchor:		$anchor;
			}
			#window {
				width:		$((${DT_WIDTH}*2));
			}
			#mode-switcher {
				enabled:	true;
			}
			#boxdummy {
				enabled:	$dummy;
				children:	[ $dummyline ];
			}"
		goback="$thisscript -desktop $X $Y"
	fi
	command=$(delay; $thisscript \
				-only drun \
				-drun-match-fields categories,name \
				-display-drun "$label" \
				-filter "$category " \
				-run-command "echo {cmd}" \
				-run-shell-command "echo {terminal} -e {cmd}" \
				-theme-str "$theme")
	if [ -n "$command" ] ; then
		eval "$command" &
		exit
	fi
	# return to categories modi. No delay needed
	eval $goback &

	if [ $linenumber -eq 0 ] ; then	# if the category is on the top line
		exit
	fi
	# move rofi selection down by linenumber
	keys=""
	while [ $linenumber -gt 0 ] ; do
		keys="$keys Tab"
		linenumber=$(($linenumber-1))
	done
	##TODO wait until rofi can take input
	delay
	delay
	xdotool search --class rofi key --delay 0 $keys
}
## rofi theme file can be set here
# ROFIMENU_THEME="$HOME/.config/rofimenu/rofimenu.rasi"
_EOF_
fi

# read config file
. "$ROFIMENU_CONFIG"

# if there is no theme file, write default theme file

if ! [ -f "$ROFIMENU_THEME" ] ; then
	mkdir -p "${ROFIMENU_THEME%/*}"
	cat > "$ROFIMENU_THEME"<<"_EOF_"
configuration {
	me-select-entry:	"MouseSecondary";
	me-accept-entry:	"MousePrimary";
	scroll-method:      1;
    show-icons:         true;
    sidebar-mode:		true;
    kb-custom-1:        "";
    kb-custom-2:        "";
    kb-custom-3:        "";
    kb-custom-4:        "";
    kb-custom-5:        "";
    kb-custom-6:        "";
    kb-custom-7:        "";
    kb-custom-8:        "";
    kb-custom-9:        "";
    kb-custom-10:       "";
    kb-select-1:        "Alt+1";
    kb-select-2:        "Alt+2";
    kb-select-3:        "Alt+3";
    kb-select-4:        "Alt+4";
    kb-select-5:        "Alt+5";
    kb-select-6:        "Alt+6";
    kb-select-7:        "Alt+7";
    kb-select-8:        "Alt+8";
    kb-select-9:        "Alt+9";
    kb-select-10:       "Alt+0";
}
* {
////	COLORS	////
////	uncomment to match bspwm edition theme
	background:                  #292f34FF;
	background-color:            #292f3400;
	foreground:                  #F6F9FFFF;
	selected:                    #1ABB9BFF;
	selected-foreground:         @foreground;
////	 uncomment to match Adapta Nokto theme
//	background:                  #222D32E8;
//	background-color:            #00000000;
//	foreground:                  #CFD8DCFF;
//	selected:                    #00BCD4FF;
//	selected-foreground:         #FFFFFFFF;
////	common - active and urgent
    active-background:           #3A464BFF;
    urgent-background:           #800000FF;
    urgent-foreground:           @foreground;
    selected-urgent-background:  @urgent-foreground;
    selected-urgent-foreground:  @urgent-background;
////	TEXT	////
	font:				"xos4 Terminus 18px";
//    font:				"Knack Nerd Font 16px";
    text-color:			@foreground;
////	PADDING ETC	////
	margin:				0px;
	border:				0px;
	padding:			0px;
	spacing:			0px;
	elementpadding:		2px 0px;
	elementmargin:		0px 2px;
	listmargin:			0px 2px 0px 0px;
////	SIZE	////
	windowwidth:	40ch;
	buttonwidth:	18ch;
	lines:			12;
	fixed-height:	false;
////	POSITION	////
	location:		northwest;
	anchor:			northwest;
	x-offset:		0px;
	y-offset:		24px;
////	LAYOUT	////
	scrollbar:		true;
////	uncomment to get submenu-like style
	menustyle:		[ sb-mainbox ];
	buttonpadding:	2px 1ch;
	button-bg:		@background;
	dynamic:		true;
////	uncomment to get tabs-like style
//	menustyle:		[ tb-mainbox ];
//	buttonpadding:	14px 1ch;
//	dynamic:		false;
}
//////////////////////////////////////////
window {
	width:			@windowwidth;
	children:		@menustyle;
}
//submenu-style
sb-mainbox {
	orientation:	horizontal;
	children:		[ mode-switcher, vertibox ];
}
//tabs-style
tb-mainbox {
	orientation:	vertical;
	children:		[ inputbar, horibox ];
	background-color:	@background;
}
//desktop-submenu
dt-mainbox {
	orientation:	vertical;
	children:		[ boxdummy, sb-mainbox ];
}
horibox {
	orientation:	horizontal;
	children:		[ listview, mode-switcher ];
}
mode-switcher {
	orientation:	vertical;
}
button {
	horizontal-align:	0;
	padding:		@buttonpadding;
	width:			@buttonwidth;
	background-color:	@button-bg;
	expand:			false;
}
vertibox {
	orientation:	vertical;
	children:		[ inputbar, listview ];
	background-color:	@background;
}
prompt {
	enabled:		false;
}
listview {
	margin:			@listmargin;
}
scrollbar {
	handle-width:	0.5ch;
	handle-color:	@selected;
}
boxdummy {
	enabled:		false;
	orientation:	vertical;
	expand:			false;
	children:		[ textboxdummy ];
}
textboxdummy {
	str:			" ";
}
element, inputbar, textboxdummy {
	padding:		@elementpadding;
	margin:			@elementmargin;
	width:			@elementwidth;
}
element.normal.active,
element.alternate.active {
	background-color:	@active-background;
	text-color:			@selected-foreground;
}
element.selected,
button.selected {
	background-color:	@selected;
	text-color:			@selected-foreground;
}
element.normal.urgent,
element.alternate.urgent {
	background-color:	@urgent-background;
	text-color:			@urgent-foreground;
}
element.selected.urgent {
	background-color:	@selected-urgent-background;
	text-color:			@selected-urgent-foreground;
}
_EOF_
fi

###############################
##  MAIN SCRIPT STARTS HERE  ##
###############################

if [ $# -gt 0 ] ; then
	option="$1"
	shift
else
	option="-no"
fi

case "$option" in
	"-no"|"-show"|"-only"|"-desktop")

	case "$option" in
		"-no")
			showmodi="${modilist%%,*}"	# first modi from list
			showmodi="${showmodi%%:*}"	# modi name if modi is custom
			;;
		"-show")
			showmodi="$1"
			shift
			;;
		"-only")			## show only this modi
			modilist=$(echo $modilist|grep -o "${1}[^,]*")
			showmodi="$1"
			shift
			;;
		"-desktop")			## show desktop menu
			modilist="$DT_MODI"
			showmodi="${DT_MODI%:*}"	# desktop modi name
			if [ $# -gt 0 ] ; then
				X=$1
				Y=$2
				shift 2
			else
				eval $(xdotool getmouselocation --shell)
			fi

			# adjust X and Y if too close to the right side or the bottom of the screen
			MAX_X=$(wattr w $(lsw -r) )
			MAX_Y=$(wattr h $(lsw -r) )
			linesnumber=$(Desktop | wc -l)
			anchor="north"
			if [ $Y -gt $(( $MAX_Y - $DT_LINE_HEIGHT * $linesnumber )) ] ; then
				anchor="south"
				Y=$MAX_Y
			fi
			if [ $X -gt $(( $MAX_X - $DT_WIDTH )) ] ; then
				anchor="${anchor}east"
				X=$MAX_X
			else
				anchor="${anchor}west"
			fi

			rofitheme="$DT_THEME
				* {
					x-offset:	$X;
					y-offset:	$Y;
					anchor:		$anchor;
				}"
			;;
	esac

	##TODO determine element length and modi lenght

	## wait until rofi exits
	while pgrep -x rofi >/dev/null 2>&1 ; do
		delay;
	done

			# the rest of command line is passed to rofi
	rofi	"$@" \
			-modi "$modilist" \
			-show "$showmodi" \
			-config "$ROFIMENU_THEME" \
			-display-run "$RUN" \
			-display-drun "$DRUN" \
			-theme-str "$rofitheme" &
	exit
	;;

	###################################
	# option "-menu"
	"-menu")
		case $# in
			0)	exit 1	# must have menu function name
				;;
			1)	# "-menu <menu>" and no more parameters calls <menu> function and prints labels from each line
				$1 \
				| while read line; do
					echo "${line%%:*}"
				  done
				  exit
				;;
			*)	# "-menu <menu> <label>" calls <menu> function and executes command from line with <label>
				$1 \
				| while read line; do
					if [ "$2" = "${line%%:*}" ] ; then
						command="${line#*:}"
						eval "$command" &
						exit
					fi
				  done >/dev/null 2>&1
		esac
		;;

	################
	# unknown option
	*)	exit 1
esac
