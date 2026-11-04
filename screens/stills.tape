Source common.tape
Output scratch.gif
Set Height 1200
Hide
Type ". ./setup.sh"
Enter
Sleep 1s
Show
Sleep 800ms
Hide
Type "kiban up redis >/dev/null 2>&1; clear"
Enter
Sleep 30s
Show
Sleep 800ms
Type "kiban status"
Enter
Sleep 10s
Screenshot status.png
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "kiban logs redis"
Enter
Sleep 5s
Screenshot logs.png
Sleep 1s
Ctrl+C
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "kiban config"
Enter
Sleep 5s
Screenshot config.png
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "kiban up nosql"
Enter
Sleep 3s
Screenshot error.png
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "kiban reset redis"
Enter
Sleep 5s
Sleep 3s
Type "redis"
Sleep 3s
Screenshot reset.png
Enter
Sleep 10s
Screenshot reset-done.png
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "kiban doctor"
Enter
Sleep 10s
Screenshot doctor.png
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "for t in kodougu catppuccin-mocha dracula nord gruvbox tokyo-night; do kiban --theme $t version; done"
Enter
Sleep 8s
Screenshot themes.png
Sleep 1s
Sleep 1s
