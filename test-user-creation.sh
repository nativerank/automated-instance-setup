if [[ -z "$2" ]]; then
   printf -- "\n Must provide temporary password! \n"
   exit 64
fi

printf -- "\n Creating user \n"
wp user create admin websupport@nativerank.com --role=administrator >> launch_script_output.txt
printf -- "\n Updating user password \n"
wp user update 2 --user_pass="$2" >> launch_script_output.txt
